import AppKit

/// Icon trạng thái trên menu bar.
/// - Click trái: bật/tắt bộ gõ (toggle VI/EN).
/// - Click phải: mở menu (VI/EN, Thoát).
final class StatusBar: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem(title: "Gõ tiếng Việt", action: nil, keyEquivalent: "")
    private let freeStyleItem = NSMenuItem(title: "Gõ tự do (đặt dấu cuối từ)", action: nil, keyEquivalent: "")
    private let debugItem = NSMenuItem(title: "Debug log gõ phím", action: nil, keyEquivalent: "")

    /// Gọi khi muốn bật/tắt (click trái hoặc chọn trong menu).
    var onToggle: (() -> Void)?
    /// Gọi khi bật/tắt chế độ gõ tự do (đặt dấu mũ sau phụ âm cuối).
    var onToggleFreeStyle: (() -> Void)?
    /// Gọi khi bật/tắt debug log gõ phím trong menu.
    var onToggleDebug: (() -> Void)?

    override init() {
        super.init()
        item.isVisible = false   // ẩn cho tới khi có quyền Accessibility
        if let b = item.button {
            b.target = self
            b.action = #selector(clicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        buildMenu()
    }

    private func buildMenu() {
        toggleItem.target = self
        toggleItem.action = #selector(toggleFromMenu)
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        freeStyleItem.target = self
        freeStyleItem.action = #selector(toggleFreeStyleFromMenu)
        menu.addItem(freeStyleItem)
        menu.addItem(.separator())
        debugItem.target = self
        debugItem.action = #selector(toggleDebugFromMenu)
        menu.addItem(debugItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Thoát", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let isRight = (NSApp.currentEvent?.type == .rightMouseUp)
            || (NSApp.currentEvent?.modifierFlags.contains(.control) ?? false)
        if isRight {
            // Mở menu tạm thời rồi gỡ ra để click trái vẫn gọi action.
            item.menu = menu
            sender.performClick(nil)
            item.menu = nil
        } else {
            onToggle?()
        }
    }

    @objc private func toggleFromMenu() { onToggle?() }
    @objc private func toggleFreeStyleFromMenu() { onToggleFreeStyle?() }
    @objc private func toggleDebugFromMenu() { onToggleDebug?() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// Hiện icon trạng thái VI/EN. Chỉ gọi khi đã có quyền Accessibility.
    func show(enabled: Bool) {
        item.isVisible = true
        item.button?.title = enabled ? "VI" : "EN"
        toggleItem.state = enabled ? .on : .off
    }

    /// Cập nhật trạng thái checkmark của mục debug log.
    func setDebug(enabled: Bool) {
        debugItem.state = enabled ? .on : .off
    }

    /// Cập nhật trạng thái checkmark của mục gõ tự do.
    func setFreeStyle(enabled: Bool) {
        freeStyleItem.state = enabled ? .on : .off
    }
}
