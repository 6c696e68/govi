import AppKit
import CoreGraphics

// Govi - bộ gõ tiếng Việt Telex cho macOS. App accessory: không Dock, không
// cửa sổ, chỉ hiện diện qua icon trạng thái trên status bar.

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class AppController: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBar()
    private let keyTap = KeyTap()
    private let hotkey = Hotkey()
    private let injector = Injector()
    private let parser = VietTelex()
    private var accessPoll: Timer?

    private var enabled = true   // chỉ truy cập trên thread của tap
    private var debugLog = false // log gõ phím; chỉ truy cập trên thread của tap
    private var freeStyle = true // gõ tự do (đặt dấu cuối từ); truy cập trên thread tap

    private static let freeStyleKey = "govi.freeStyleMarks"

    func applicationDidFinishLaunching(_ note: Notification) {
        // Chặn chạy nhiều bản.
        let me = Bundle.main.bundleIdentifier ?? "org.govi.app"
        if NSRunningApplication.runningApplications(withBundleIdentifier: me).count > 1 {
            NSApp.terminate(nil); return
        }
        // Nạp tuỳ chọn đã lưu (mặc định bật nếu chưa từng đặt).
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.freeStyleKey) != nil {
            freeStyle = defaults.bool(forKey: Self.freeStyleKey)
        }
        parser.freeStyleMarks = freeStyle
        statusBar.onToggle = { [weak self] in self?.toggleMode() }
        statusBar.onToggleFreeStyle = { [weak self] in self?.toggleFreeStyle() }
        statusBar.onToggleDebug = { [weak self] in self?.toggleDebug() }
        statusBar.setFreeStyle(enabled: freeStyle)
        LoginItem.enableOnce()
        if ProcessInfo.processInfo.environment["GOVI_DEBUG"] == "1"
            || CommandLine.arguments.contains("--debug") {
            debugLog = true
            DebugLog.shared.start()
        }
        if Accessibility.isTrusted { startEngine() }
        else { Accessibility.prompt(); waitForAccessibility() }
    }

    private func waitForAccessibility() {
        accessPoll = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self, Accessibility.isTrusted else { return }
            t.invalidate(); self.accessPoll = nil; self.startEngine()
        }
    }

    private func startEngine() {
        hotkey.onToggle = { [weak self] in self?.toggleMode() }
        keyTap.onEvent = { [weak self] type, event, proxy in
            guard let self else { return event }   // self mất -> cho qua
            return self.handle(type: type, event: event, proxy: proxy) // nil = nuốt phím
        }
        guard keyTap.start() else { NSLog("Govi: không tạo được event tap"); return }
        refreshStatus()
        NSLog("Govi engine ready")
    }

    /// Bật/tắt bộ gõ. Chạy trên thread tap để serialize với xử lý phím.
    private func toggleMode() {
        keyTap.perform { [weak self] in
            guard let self else { return }
            self.enabled.toggle()
            self.parser.reset()
            self.refreshStatus()
        }
    }

    /// Bật/tắt gõ tự do (đặt dấu mũ sau phụ âm cuối). Chạy trên thread tap để
    /// serialize với xử lý phím; lưu lựa chọn vào UserDefaults.
    private func toggleFreeStyle() {
        keyTap.perform { [weak self] in
            guard let self else { return }
            self.freeStyle.toggle()
            let on = self.freeStyle
            self.parser.freeStyleMarks = on
            self.parser.reset()
            UserDefaults.standard.set(on, forKey: Self.freeStyleKey)
            NSLog("Govi free-style: %@", on ? "ON" : "OFF")
            DispatchQueue.main.async { [weak self] in self?.statusBar.setFreeStyle(enabled: on) }
        }
    }

    /// Bật/tắt debug log gõ phím. Chạy trên thread tap để serialize với xử lý phím.
    private func toggleDebug() {
        keyTap.perform { [weak self] in
            guard let self else { return }
            self.debugLog.toggle()
            let on = self.debugLog
            if on {
                DebugLog.shared.start()
            } else {
                DebugLog.shared.stop()
                let path = DebugLog.shared.path
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))   // mở file log để xem
                }
            }
            NSLog("Govi debug log: %@ -> %@", on ? "ON" : "OFF", DebugLog.shared.path)
            DispatchQueue.main.async { [weak self] in self?.statusBar.setDebug(enabled: on) }
        }
    }

    /// Chạy trên thread tap. Trả về event (cho qua) hoặc nil (nuốt phím).
    private func handle(type: CGEventType, event: CGEvent, proxy: CGEventTapProxy) -> CGEvent? {
        switch type {
        case .flagsChanged:
            hotkey.flags(event.flags)
            injector.invalidate()        // đổi modifier thường đi trước đổi focus/app
            return event

        case .leftMouseDown, .rightMouseDown:
            parser.reset()
            injector.invalidate()
            return event

        case .keyDown:
            hotkey.keyInterrupt()
            guard enabled else { return event }
            injector.refresh()
            if injector.isPassthrough { parser.reset(); return event }

            let mods = event.flags
            if mods.contains(.maskCommand) || mods.contains(.maskControl) || mods.contains(.maskAlternate) {
                parser.reset(); return event
            }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if debugLog {
                let ar = event.getIntegerValueField(.keyboardEventAutorepeat)
                let ud = event.getIntegerValueField(.eventSourceUserData)
                let chs = character(of: event).map { String($0) } ?? "?"
                DebugLog.shared.log("RAW keyDown code=\(code) char='\(chs)' autorepeat=\(ar) userData=\(ud)")
            }
            if code == 51 { parser.backspace(); return event } // Backspace

            if let ch = character(of: event), ch.isASCII, ch.isLetter {
                // Auto-repeat (giữ phím / nhịp giữ tự nhiên): KHÔNG đưa vào engine. Mỗi
                // keyDown lặp lại nếu xử như lần gõ mới sẽ làm phím dấu (r/s/x...) tự
                // undo/đổi dấu -> "version" hoá "verrsion". Nuốt luôn cho khỏi lặp ký tự.
                if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                    if debugLog { DebugLog.shared.log("key '\(ch)' [autorepeat] -> bỏ qua") }
                    return nil
                }
                let r = parser.input(ch)
                if debugLog {
                    NSLog("Govi key '%@' -> delete=%d insert='%@'", String(ch), r.delete, r.insert)
                    DebugLog.shared.log("key '\(ch)' -> delete=\(r.delete) insert='\(r.insert)'")
                }
                if r.delete > 0 || !r.insert.isEmpty {
                    injector.inject(delete: r.delete, insert: r.insert, proxy: proxy)
                }
                return nil
            }

            // Phím ngắt từ (space, dấu câu, Enter, mũi tên...).
            let r = parser.breakWord()
            if debugLog {
                let brk = character(of: event).map { String($0) } ?? "<ctrl>"
                NSLog("Govi break '%@' -> delete=%d insert='%@'", brk, r.delete, r.insert)
                DebugLog.shared.log("break '\(brk)' -> delete=\(r.delete) insert='\(r.insert)'")
            }
            if let bc = character(of: event), let a = bc.asciiValue, a >= 0x20, a < 0x7F {
                // Không có gì để khôi phục (buffer rỗng / từ đã hợp lệ) -> để phím native
                // đi qua tự nhiên. Tự inject lại số/dấu câu qua HID sẽ kích hoạt auto-format
                // của các field đặc biệt (vd ô nhập số thẻ) làm nuốt/thay thế ký tự.
                if r.delete == 0, r.insert.isEmpty {
                    return event
                }
                // Có khôi phục: inject đồng bộ cùng ký tự ngắt để giữ đúng thứ tự
                // (tránh đua giữa phím native và text inject qua HID).
                injector.inject(delete: r.delete, insert: r.insert + String(bc), proxy: proxy)
                return nil
            }
            // Enter/Tab/phím điều khiển: khôi phục nếu cần rồi cho qua.
            if r.delete > 0 || !r.insert.isEmpty {
                injector.inject(delete: r.delete, insert: r.insert, proxy: proxy)
            }
            return event

        default:
            return event
        }
    }

    private func character(of event: CGEvent) -> Character? {
        var len = 0
        var buf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &buf)
        guard len > 0 else { return nil }
        return String(utf16CodeUnits: buf, count: len).first
    }

    private func refreshStatus() {
        let on = enabled
        DispatchQueue.main.async { [weak self] in self?.statusBar.show(enabled: on) }
    }
}

let controller = AppController()
app.delegate = controller
app.run()
