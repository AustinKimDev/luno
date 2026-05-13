#if canImport(AppKit) && canImport(MetalKit)
import AppKit
import CoreGraphics
import MetalKit

public enum WallpaperRuntimeError: Error, LocalizedError {
    case metalUnavailable
    case shaderSourceUnreadable(URL)
    case textureUnreadable(URL, String)
    case shaderCompilationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .metalUnavailable:
            "Metal is not available on this Mac."
        case .shaderSourceUnreadable(let url):
            "Could not read shader source at \(url.path)."
        case .textureUnreadable(let url, let message):
            "Could not load texture at \(url.path): \(message)"
        case .shaderCompilationFailed(let message):
            "Metal shader compilation failed: \(message)"
        }
    }
}

@MainActor
public final class WallpaperRuntime {
    private var controllers: [CGDirectDisplayID: WallpaperWindowController] = [:]
    private var spaceChangeObserver: NSObjectProtocol?

    public init() {
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reorderFront()
            }
        }
    }

    deinit {
        if let observer = spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    public var activeDisplayIDs: [CGDirectDisplayID] {
        Array(controllers.keys).sorted()
    }

    private func reorderFront() {
        for controller in controllers.values {
            controller.show()
        }
    }

    public func show(
        package: LunoPackageRecord,
        preset: WallpaperPreset?,
        displayID: CGDirectDisplayID?,
        frameRate: Int,
        audioProvider: @escaping @MainActor () -> AudioFeatures
    ) throws {
        let screens = targetScreens(displayID: displayID)
        for screen in screens {
            guard let screenDisplayID = screen.lunoDisplayID else { continue }
            stop(displayID: screenDisplayID)

            let controller = try WallpaperWindowController(
                screen: screen,
                package: package,
                preset: preset,
                frameRate: frameRate,
                audioProvider: audioProvider
            )
            controllers[screenDisplayID] = controller
            controller.show()
        }
    }

    public func stop(displayID: CGDirectDisplayID? = nil) {
        if let displayID {
            controllers.removeValue(forKey: displayID)?.close()
            return
        }

        for controller in controllers.values {
            controller.close()
        }
        controllers.removeAll()
    }

    public func refreshDisplayLayout() {
        for (displayID, controller) in controllers {
            guard let screen = NSScreen.screens.first(where: { $0.lunoDisplayID == displayID }) else {
                controller.close()
                controllers.removeValue(forKey: displayID)
                continue
            }
            controller.updateFrame(for: screen)
        }
    }

    private func targetScreens(displayID: CGDirectDisplayID?) -> [NSScreen] {
        if let displayID {
            return NSScreen.screens.filter { $0.lunoDisplayID == displayID }
        }
        return NSScreen.screens
    }
}

@MainActor
private final class WallpaperWindowController {
    private let window: NSWindow

    init(
        screen: NSScreen,
        package: LunoPackageRecord,
        preset: WallpaperPreset?,
        frameRate: Int,
        audioProvider: @escaping @MainActor () -> AudioFeatures
    ) throws {
        let geometry = WallpaperWindowGeometry(screenFrame: screen.frame)
        let configuration = WallpaperWindowConfiguration()
        let contentView = try MetalWallpaperView(
            frame: geometry.contentFrame,
            package: package,
            preset: preset,
            frameRate: frameRate,
            audioProvider: audioProvider
        )

        window = NSWindow(
            contentRect: geometry.windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.backgroundColor = .black
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.animationBehavior = .none
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = configuration.collectionBehavior
    }

    func show() {
        window.orderFrontRegardless()
    }

    func close() {
        (window.contentView as? MetalWallpaperView)?.prepareForRemoval()
        window.contentView = nil
        window.orderOut(nil)
        window.close()
    }

    func updateFrame(for screen: NSScreen) {
        window.setFrame(screen.frame, display: true)
    }
}

private final class MetalWallpaperView: MTKView {
    private var wallpaperRenderer: MetalWallpaperRenderer?

    init(
        frame: NSRect,
        package: LunoPackageRecord,
        preset: WallpaperPreset?,
        frameRate: Int,
        audioProvider: @escaping @MainActor () -> AudioFeatures
    ) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw WallpaperRuntimeError.metalUnavailable
        }

        super.init(frame: frame, device: device)
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        framebufferOnly = true
        preferredFramesPerSecond = frameRate
        enableSetNeedsDisplay = false
        isPaused = false

        let renderer = try MetalWallpaperRenderer(
            view: self,
            package: package,
            preset: preset,
            audioProvider: audioProvider
        )
        delegate = renderer
        wallpaperRenderer = renderer
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForRemoval() {
        isPaused = true
        delegate = nil
        wallpaperRenderer = nil
    }
}

@MainActor
private final class MetalWallpaperRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: any MTLCommandQueue
    private let pipelineState: any MTLRenderPipelineState
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()
    private var viewportSize = SIMD2<Float>(1, 1)
    private let displayScale: Float
    private let parameterPack: ShaderParameterPack
    private let backgroundTexture: (any MTLTexture)?
    private let samplerState: (any MTLSamplerState)?
    private let audioProvider: @MainActor () -> AudioFeatures

    init(
        view: MTKView,
        package: LunoPackageRecord,
        preset: WallpaperPreset?,
        audioProvider: @escaping @MainActor () -> AudioFeatures
    ) throws {
        guard let device = view.device,
              let commandQueue = device.makeCommandQueue()
        else {
            throw WallpaperRuntimeError.metalUnavailable
        }

        self.commandQueue = commandQueue
        self.audioProvider = audioProvider
        self.displayScale = Float(view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        self.parameterPack = ShaderParameterPack.make(manifest: package.manifest, preset: preset)

        if let assetPath = package.manifest.assets.first {
            let textureURL = package.packageURL.appending(path: assetPath)
            do {
                backgroundTexture = try MTKTextureLoader(device: device).newTexture(
                    URL: textureURL,
                    options: [
                        .SRGB: false,
                        .origin: MTKTextureLoader.Origin.topLeft
                    ]
                )
            } catch {
                throw WallpaperRuntimeError.textureUnreadable(textureURL, error.localizedDescription)
            }
        } else {
            backgroundTexture = nil
        }

        if backgroundTexture != nil {
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.mipFilter = .linear
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
            samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
        } else {
            samplerState = nil
        }

        let shaderURL = package.packageURL.appending(path: package.manifest.entryShader)
        guard let shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8) else {
            throw WallpaperRuntimeError.shaderSourceUnreadable(shaderURL)
        }

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let vertex = library.makeFunction(name: "lunoVertex"),
                  let fragment = library.makeFunction(name: "lunoFragment")
            else {
                throw WallpaperRuntimeError.shaderCompilationFailed("Shader must define lunoVertex and lunoFragment.")
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch let runtimeError as WallpaperRuntimeError {
            throw runtimeError
        } catch {
            throw WallpaperRuntimeError.shaderCompilationFailed(error.localizedDescription)
        }

        super.init()
        viewportSize = SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height))
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = SIMD2(Float(size.width), Float(size.height))
    }

    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        let now = CACurrentMediaTime()
        let audio = audioProvider()
        var uniforms = LunoShaderUniforms(
            time: Float(now - startTime),
            deltaTime: Float(now - lastTime),
            resolution: viewportSize,
            displayScale: displayScale,
            audioRMS: audio.rms,
            audioBass: audio.bass,
            audioMid: audio.mid,
            audioTreble: audio.treble,
            parameter0: parameterPack.numeric,
            colorParameter0: parameterPack.color0,
            colorParameter1: parameterPack.color1,
            colorParameter2: parameterPack.color2,
            colorParameter3: parameterPack.color3
        )
        lastTime = now

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LunoShaderUniforms>.stride, index: 0)
        if let backgroundTexture {
            encoder.setFragmentTexture(backgroundTexture, index: 0)
        }
        if let samplerState {
            encoder.setFragmentSamplerState(samplerState, index: 0)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

}

private struct LunoShaderUniforms {
    var time: Float
    var deltaTime: Float
    var resolution: SIMD2<Float>
    var displayScale: Float
    var audioRMS: Float
    var audioBass: Float
    var audioMid: Float
    var audioTreble: Float
    var parameter0: SIMD4<Float>
    var colorParameter0: SIMD4<Float>
    var colorParameter1: SIMD4<Float>
    var colorParameter2: SIMD4<Float>
    var colorParameter3: SIMD4<Float>
}

public extension NSScreen {
    var lunoDisplayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}
#endif
