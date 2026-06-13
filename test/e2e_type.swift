import AppKit
import CoreGraphics
import ApplicationServices

// E2E: gõ phím thật qua CGEvent vào TextEdit (Govi đang chạy sẽ chặn & xử lý),
// đọc kết quả qua clipboard (Cmd+A, Cmd+C, pbpaste). In tiến trình từng bước.

let codes: [Character: CGKeyCode] = [
    "v": 9, "e": 14, "r": 15, "s": 1, "i": 34, "o": 31, "n": 45,
    "u": 32, "a": 0, "t": 17,
]

func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags = []) {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    if !flags.isEmpty { e.flags = flags }
    e.post(tap: .cghidEventTap)
}

func tap(_ code: CGKeyCode, flags: CGEventFlags = []) {
    post(code, down: true, flags: flags); usleep(8000); post(code, down: false, flags: flags)
}

func typeChar(_ ch: Character) {
    guard let c = codes[ch] else { return }
    tap(c)
}

func clipboard() -> String {
    NSPasteboard.general.clearContents()
    usleep(30000)
    tap(0, flags: .maskCommand)   // Cmd+A
    usleep(60000)
    tap(8, flags: .maskCommand)   // Cmd+C (c=8)
    usleep(120000)
    return NSPasteboard.general.string(forType: .string) ?? "<empty>"
}

guard AXIsProcessTrusted() else { print("test KHÔNG có quyền Accessibility"); exit(3) }

let te = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit")!
let sem = DispatchSemaphore(value: 0)
NSWorkspace.shared.openApplication(at: te, configuration: NSWorkspace.OpenConfiguration()) { _, _ in sem.signal() }
sem.wait(); sleep(2)
tap(45, flags: .maskCommand)   // Cmd+N doc mới
sleep(1)

for w in ["version", "vers", "users"] {
    tap(0, flags: .maskCommand); usleep(40000)          // Cmd+A
    post(51, down: true); usleep(8000); post(51, down: false)  // Delete
    usleep(200000)
    for ch in w { typeChar(ch); usleep(70000) }
    usleep(250000)
    print(">>> gõ '\(w)' -> hiển thị: '\(clipboard())'")
    fflush(stdout)
}
