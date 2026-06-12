import CoreGraphics
import ApplicationServices
import Foundation

/// Các cách phát phím/Unicode tới ứng dụng. Mọi event tự sinh gắn marker để
/// KeyTap bỏ qua. proxy != nil -> post đồng bộ vào pipeline tap (đúng thứ tự).
enum Strategies {
    private static let kDelete: CGKeyCode = 51
    private static let kForwardDelete: CGKeyCode = 117
    private static let kLeft: CGKeyCode = 123

    private static func postKey(_ code: CGKeyCode, flags: CGEventFlags = [], proxy: CGEventTapProxy? = nil) {
        guard let dn = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { return }
        for e in [dn, up] {
            e.setIntegerValueField(.eventSourceUserData, value: KeyTap.marker)
            if !flags.isEmpty { e.flags = flags }
        }
        if let proxy { dn.tapPostEvent(proxy); up.tapPostEvent(proxy) }
        else { dn.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap) }
    }

    private static func postText(_ text: String, delay: UInt32 = 0, proxy: CGEventTapProxy? = nil, chunk: Int = 20) {
        let units = Array(text.utf16)
        guard !units.isEmpty else { return }
        var i = 0
        while i < units.count {
            let end = min(i + chunk, units.count)
            var slice = Array(units[i..<end])
            // CHỈ keyDown mang chuỗi Unicode. Nếu set cả keyUp -> nhiều app chèn 2 lần.
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { return }
            e.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: &slice)
            e.setIntegerValueField(.eventSourceUserData, value: KeyTap.marker)
            if let proxy { e.tapPostEvent(proxy) } else { e.post(tap: .cghidEventTap) }
            if delay > 0 { usleep(delay) }
            i = end
        }
    }

    // MARK: - Strategies

    static func backspace(_ del: Int, _ insert: String, _ d: Delays, charByChar: Bool, emptyPrefix: Bool) {
        var del = del
        if emptyPrefix {
            postText("\u{202F}")            // phá highlight autocomplete
            usleep(d.bs > 0 ? d.bs : 1000)
            del += 1
        }
        for _ in 0..<del { postKey(kDelete); if d.bs > 0 { usleep(d.bs) } }
        if del > 0 && d.mid > 0 { usleep(d.mid) }
        postText(insert, delay: d.text, chunk: charByChar ? 1 : 20)
    }

    static func selection(_ del: Int, _ insert: String, _ d: Delays) {
        let sel = d.bs > 0 ? d.bs : 1000, wait = d.mid > 0 ? d.mid : 3000, td = d.text > 0 ? d.text : 2000
        if del > 0 {
            if insert.isEmpty {
                for _ in 0..<del { postKey(kDelete); usleep(sel) }
            } else {
                for _ in 0..<del { postKey(kLeft, flags: .maskShift); usleep(sel) }
            }
            usleep(wait)
        }
        postText(insert, delay: td)
    }

    static func proxy(_ del: Int, _ insert: String, _ proxy: CGEventTapProxy) {
        for _ in 0..<del { postKey(kDelete, proxy: proxy) }
        postText(insert, proxy: proxy)
    }

    static func axDirect(_ del: Int, _ insert: String, _ proxy: CGEventTapProxy) {
        for attempt in 0..<3 {
            if attempt > 0 { usleep(5000) }
            if axWrite(del, insert) { return }
        }
        // fallback: Forward-Delete dọn gợi ý + synthetic
        postKey(kForwardDelete, proxy: proxy); usleep(3000)
        for _ in 0..<del { postKey(kDelete, proxy: proxy); usleep(1000) }
        if del > 0 { usleep(5000) }
        postText(insert, proxy: proxy)
    }

    /// Ghi trực tiếp text field qua AX (Spotlight). true nếu thành công.
    private static func axWrite(_ del: Int, _ insert: String) -> Bool {
        let sys = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(sys, 0.1)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused else { return false }
        let element = el as! AXUIElement

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let full = valueRef as? String else { return false }

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let r = rangeRef else { return false }
        var range = CFRange()
        guard AXValueGetValue(r as! AXValue, .cfRange, &range), range.location >= 0 else { return false }

        let u = Array(full.utf16)
        let cursor = min(range.location, u.count)
        // selection > 0: phần sau con trỏ là gợi ý -> chỉ giữ tới con trỏ
        let userU = range.length > 0 ? Array(u[0..<cursor]) : u
        let delU = min(del, cursor)
        let prefix = String(utf16CodeUnits: Array(userU[0..<(cursor - delU)]), count: cursor - delU)
        let suffixStart = min(cursor, userU.count)
        let suffix = String(utf16CodeUnits: Array(userU[suffixStart...]), count: userU.count - suffixStart)
        let newText = (prefix + insert + suffix).precomposedStringWithCanonicalMapping

        guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef) == .success
        else { return false }

        var newCursor = CFRange(location: prefix.utf16.count + insert.utf16.count, length: 0)
        if let nr = AXValueCreate(.cfRange, &newCursor) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, nr)
        }
        return true
    }
}
