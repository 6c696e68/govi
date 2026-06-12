import ApplicationServices

/// Quyền Accessibility — bắt buộc để chặn/độ phím qua CGEventTap.
enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Hiện dialog hệ thống xin quyền (không chặn luồng).
    static func prompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
