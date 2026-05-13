// Sources/LunoApp/Settings/SettingsSidebar.swift
import AppKit

@MainActor
protocol SettingsSidebarDelegate: AnyObject {
    func sidebar(_ sidebar: SettingsSidebar, didSelect section: SettingsSection)
}

@MainActor
final class SettingsSidebar: NSObject {
    let scrollView: NSScrollView
    let outlineView: NSOutlineView
    weak var delegate: SettingsSidebarDelegate?

    private let column: NSTableColumn

    override init() {
        scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 12
        outlineView.style = .sourceList
        outlineView.allowsMultipleSelection = false
        outlineView.focusRingType = .none
        outlineView.intercellSpacing = NSSize(width: 0, height: 4)

        column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.title = "Section"
        column.minWidth = 140
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        super.init()

        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.expandItem(nil, expandChildren: true)
    }

    func selectInitialItem() {
        outlineView.expandItem(nil, expandChildren: true)
        if outlineView.numberOfRows > 0 {
            outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
}

extension SettingsSidebar: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return SettingsOutline.nodes.count }
        if let node = item as? SettingsOutlineNode {
            switch node {
            case .group(_, let children): return children.count
            case .leaf: return 0
            }
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return SettingsOutline.nodes[index] }
        if let node = item as? SettingsOutlineNode, case .group(_, let children) = node {
            return SettingsOutlineNode.leaf(children[index])
        }
        return SettingsOutlineNode.leaf(.library)
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? SettingsOutlineNode, case .group = node {
            return true
        }
        return false
    }
}

extension SettingsSidebar: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SettingsOutlineNode else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("Cell")
        let cell: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = node.title
        switch node {
        case .group:
            cell.textField?.font = .systemFont(ofSize: 11, weight: .semibold)
            cell.textField?.textColor = .secondaryLabelColor
        case .leaf(let section):
            cell.textField?.font = .systemFont(ofSize: 13)
            cell.textField?.textColor = .labelColor
            _ = section // reserved for future per-section glyph
        }
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        if let node = item as? SettingsOutlineNode, case .group = node {
            return false
        }
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard outlineView.selectedRow >= 0,
              let node = outlineView.item(atRow: outlineView.selectedRow) as? SettingsOutlineNode,
              case .leaf(let section) = node
        else { return }
        delegate?.sidebar(self, didSelect: section)
    }
}
