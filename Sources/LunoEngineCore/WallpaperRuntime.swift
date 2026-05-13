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

    public init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reorderFront()
            }
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
        audioProvider: @escaping @MainActor () -> AudioScalars
    ) throws {
        try show(
            package: package,
            preset: preset,
            displayID: displayID,
            frameRate: frameRate,
            audioProvider: {
                audioProvider().featuresForRuntime
            },
            audioReactorPreferencesProvider: {
                .defaults
            },
            usesAudioReactor: false
        )
    }

    public func show(
        package: LunoPackageRecord,
        preset: WallpaperPreset?,
        displayID: CGDirectDisplayID?,
        frameRate: Int,
        audioProvider: @escaping @MainActor () -> AudioFeatures,
        audioReactorPreferencesProvider: @escaping @MainActor () -> AudioReactorPreferences
    ) throws {
        try show(
            package: package,
            preset: preset,
            displayID: displayID,
            frameRate: frameRate,
            audioProvider: audioProvider,
            audioReactorPreferencesProvider: audioReactorPreferencesProvider,
            usesAudioReactor: true
        )
    }

    private func show(
        package: LunoPackageRecord,
        preset: WallpaperPreset?,
        displayID: CGDirectDisplayID?,
        frameRate: Int,
        audioProvider: @escaping @MainActor () -> AudioFeatures,
        audioReactorPreferencesProvider: @escaping @MainActor () -> AudioReactorPreferences,
        usesAudioReactor: Bool
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
                audioProvider: audioProvider,
                audioReactorPreferencesProvider: audioReactorPreferencesProvider,
                usesAudioReactor: usesAudioReactor
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
        audioProvider: @escaping @MainActor () -> AudioFeatures,
        audioReactorPreferencesProvider: @escaping @MainActor () -> AudioReactorPreferences,
        usesAudioReactor: Bool
    ) throws {
        let geometry = WallpaperWindowGeometry(screenFrame: screen.frame)
        let configuration = WallpaperWindowConfiguration()
        let contentView = try MetalWallpaperView(
            frame: geometry.contentFrame,
            package: package,
            preset: preset,
            frameRate: frameRate,
            audioProvider: audioProvider,
            audioReactorPreferencesProvider: audioReactorPreferencesProvider,
            usesAudioReactor: usesAudioReactor
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
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
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
        audioProvider: @escaping @MainActor () -> AudioFeatures,
        audioReactorPreferencesProvider: @escaping @MainActor () -> AudioReactorPreferences,
        usesAudioReactor: Bool
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
            audioProvider: audioProvider,
            audioReactorPreferencesProvider: audioReactorPreferencesProvider,
            usesAudioReactor: usesAudioReactor
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
    private static let overlayBarCount = 32

    private let commandQueue: any MTLCommandQueue
    private let pipelineState: any MTLRenderPipelineState
    private let overlayPipelineState: (any MTLRenderPipelineState)?
    private let startTime = CACurrentMediaTime()
    private var lastTime = CACurrentMediaTime()
    private var viewportSize = SIMD2<Float>(1, 1)
    private var overlaySpectrum = Array(repeating: Float(0), count: MetalWallpaperRenderer.overlayBarCount)
    private let displayScale: Float
    private let parameterPack: ShaderParameterPack
    private let backgroundTexture: (any MTLTexture)?
    private let samplerState: (any MTLSamplerState)?
    private let audioProvider: @MainActor () -> AudioFeatures
    private let audioReactorPreferencesProvider: @MainActor () -> AudioReactorPreferences
    private let usesAudioReactor: Bool

    init(
        view: MTKView,
        package: LunoPackageRecord,
        preset: WallpaperPreset?,
        audioProvider: @escaping @MainActor () -> AudioFeatures,
        audioReactorPreferencesProvider: @escaping @MainActor () -> AudioReactorPreferences,
        usesAudioReactor: Bool
    ) throws {
        guard let device = view.device,
              let commandQueue = device.makeCommandQueue()
        else {
            throw WallpaperRuntimeError.metalUnavailable
        }

        self.commandQueue = commandQueue
        self.audioProvider = audioProvider
        self.audioReactorPreferencesProvider = audioReactorPreferencesProvider
        self.usesAudioReactor = usesAudioReactor
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
            overlayPipelineState = usesAudioReactor
                ? try Self.makeOverlayPipelineState(device: device, colorPixelFormat: view.colorPixelFormat)
                : nil
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
        let rawAudio = audioProvider()
        let audioReactorPreferences = audioReactorPreferencesProvider()
        let audio = usesAudioReactor ? shapedScalars(rawAudio, preferences: audioReactorPreferences) : rawAudio.scalars
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

        if usesAudioReactor,
           audioReactorPreferences.shouldDrawOverlay,
           let overlayPipelineState {
            downsampleShapedSpectrum(rawAudio.spectrum, preferences: audioReactorPreferences)
            var overlayUniforms = LunoOverlayUniforms(
                resolution: viewportSize,
                rms: audio.rms,
                bass: audio.bass,
                mid: audio.mid,
                treble: audio.treble,
                overlayOpacity: Float(AudioReactorPreferences.clamp(audioReactorPreferences.overlayOpacity)),
                bassPulseStrength: Float(AudioReactorPreferences.clamp(audioReactorPreferences.bassPulseStrength)),
                flags: audioReactorPreferences.overlayFlags,
                barCount: UInt32(Self.overlayBarCount)
            )

            encoder.setRenderPipelineState(overlayPipelineState)
            encoder.setFragmentBytes(&overlayUniforms, length: MemoryLayout<LunoOverlayUniforms>.stride, index: 0)
            overlaySpectrum.withUnsafeBufferPointer { buffer in
                if let baseAddress = buffer.baseAddress {
                    encoder.setFragmentBytes(baseAddress, length: MemoryLayout<Float>.stride * buffer.count, index: 1)
                }
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func shapedScalars(
        _ features: AudioFeatures,
        preferences: AudioReactorPreferences
    ) -> AudioScalars {
        guard preferences.isEnabled else { return .silent }
        return AudioScalars(
            rms: preferences.shaped(features.rms),
            bass: preferences.shaped(features.bass),
            mid: preferences.shaped(features.mid),
            treble: preferences.shaped(features.treble)
        )
    }

    private func downsampleShapedSpectrum(
        _ spectrum: [Float],
        preferences: AudioReactorPreferences
    ) {
        preferences.writeDownsampledSpectrum(spectrum, into: &overlaySpectrum)
    }

    private static func makeOverlayPipelineState(
        device: any MTLDevice,
        colorPixelFormat: MTLPixelFormat
    ) throws -> any MTLRenderPipelineState {
        do {
            let library = try device.makeLibrary(source: LunoOverlayShaderSource.source, options: nil)
            guard let vertex = library.makeFunction(name: "lunoOverlayVertex"),
                  let fragment = library.makeFunction(name: "lunoOverlayFragment")
            else {
                throw WallpaperRuntimeError.shaderCompilationFailed("Overlay shader must define lunoOverlayVertex and lunoOverlayFragment.")
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            let attachment = descriptor.colorAttachments[0]!
            attachment.pixelFormat = colorPixelFormat
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.sourceAlphaBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch let runtimeError as WallpaperRuntimeError {
            throw runtimeError
        } catch {
            throw WallpaperRuntimeError.shaderCompilationFailed("Overlay shader compilation failed: \(error.localizedDescription)")
        }
    }

}

internal enum LunoOverlayShaderSource {
    internal static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct OverlayUniforms {
        float2 resolution;
        float rms;
        float bass;
        float mid;
        float treble;
        float overlayOpacity;
        float bassPulseStrength;
        uint flags;
        uint barCount;
    };

    struct OverlayVertexOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex OverlayVertexOut lunoOverlayVertex(uint vertexID [[vertex_id]]) {
        float2 positions[3] = {
            float2(-1.0, -1.0),
            float2(3.0, -1.0),
            float2(-1.0, 3.0)
        };

        OverlayVertexOut out;
        out.position = float4(positions[vertexID], 0.0, 1.0);
        out.uv = positions[vertexID] * 0.5 + 0.5;
        return out;
    }

    static float sampleSpectrum(constant float *spectrum, uint count, float x) {
        if (count == 0) {
            return 0.0;
        }
        if (count == 1) {
            return clamp(spectrum[0], 0.0, 1.0);
        }

        float scaled = clamp(x, 0.0, 1.0) * float(count - 1);
        uint left = uint(floor(scaled));
        uint right = min(left + 1, count - 1);
        return mix(clamp(spectrum[left], 0.0, 1.0), clamp(spectrum[right], 0.0, 1.0), fract(scaled));
    }

    fragment half4 lunoOverlayFragment(
        OverlayVertexOut in [[stage_in]],
        constant OverlayUniforms &uniforms [[buffer(0)]],
        constant float *spectrum [[buffer(1)]]
    ) {
        float2 uv = in.uv;
        float opacity = clamp(uniforms.overlayOpacity, 0.0, 1.0);
        uint count = min(uniforms.barCount, 32u);
        float3 color = float3(0.38 + uniforms.treble * 0.35, 0.72 + uniforms.mid * 0.22, 1.0);
        float alpha = 0.0;

        if ((uniforms.flags & 1u) != 0u) {
            float aspect = max(uniforms.resolution.x / max(uniforms.resolution.y, 1.0), 0.1);
            float2 centered = (uv - 0.5) * float2(aspect, 1.0);
            float distanceFromCenter = length(centered);
            float strength = clamp(uniforms.bassPulseStrength, 0.0, 1.0);
            float radius = 0.16 + uniforms.bass * 0.18 * strength;
            float width = 0.008 + uniforms.rms * 0.022;
            float ring = 1.0 - smoothstep(width, width * 2.1, abs(distanceFromCenter - radius));
            float glow = (1.0 - smoothstep(0.0, 0.24, abs(distanceFromCenter - radius))) * 0.22;
            alpha = max(alpha, (ring + glow) * (0.2 + uniforms.bass * 0.8) * strength);
        }

        if (((uniforms.flags & 2u) != 0u) && count > 0) {
            float scaledX = uv.x * float(count);
            uint index = min(uint(floor(scaledX)), count - 1);
            float localX = fract(scaledX);
            float value = clamp(spectrum[index], 0.0, 1.0);
            float baseY = 0.045;
            float height = 0.035 + value * 0.24;
            float insideBar = step(0.12, localX) * step(localX, 0.88) * step(baseY, uv.y) * step(uv.y, baseY + height);
            alpha = max(alpha, insideBar * (0.18 + value * 0.55));
        }

        if (((uniforms.flags & 4u) != 0u) && count > 0) {
            float value = sampleSpectrum(spectrum, count, uv.x);
            float waveY = 0.2 + value * 0.24;
            float lineWidth = 0.004 + uniforms.rms * 0.012;
            float line = 1.0 - smoothstep(lineWidth, lineWidth * 2.0, abs(uv.y - waveY));
            alpha = max(alpha, line * (0.22 + value * 0.5));
        }

        alpha = clamp(alpha * opacity, 0.0, 1.0);
        return half4(half3(color), half(alpha));
    }
    """
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

private struct LunoOverlayUniforms {
    var resolution: SIMD2<Float>
    var rms: Float
    var bass: Float
    var mid: Float
    var treble: Float
    var overlayOpacity: Float
    var bassPulseStrength: Float
    var flags: UInt32
    var barCount: UInt32
}

private extension AudioScalars {
    var featuresForRuntime: AudioFeatures {
        AudioFeatures(
            rms: rms,
            bass: bass,
            mid: mid,
            treble: treble,
            spectrum: AudioFeatures.silent.spectrum
        )
    }
}

private extension AudioReactorPreferences {
    var shouldDrawOverlay: Bool {
        isEnabled
            && Self.clamp(overlayOpacity) > 0
            && (showsPulseRing || showsSpectrumBars || showsWaveLine)
    }

    var overlayFlags: UInt32 {
        var flags: UInt32 = 0
        if showsPulseRing {
            flags |= 1 << 0
        }
        if showsSpectrumBars {
            flags |= 1 << 1
        }
        if showsWaveLine {
            flags |= 1 << 2
        }
        return flags
    }
}

public extension NSScreen {
    var lunoDisplayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}
#endif
