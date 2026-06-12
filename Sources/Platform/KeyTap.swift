import CoreGraphics
import Foundation

/// CGEventTap chạy trên thread riêng (QoS user-interactive) với CFRunLoop riêng,
/// để các delay khi inject không block main thread/UI.
final class KeyTap {
    /// Đánh dấu event do Govi tự sinh ('GOVI') để bỏ qua, tránh vòng lặp.
    static let marker: Int64 = 0x47_4F_56_49

    /// Trả về event để cho đi tiếp, hoặc nil để nuốt phím.
    var onEvent: ((CGEventType, CGEvent, CGEventTapProxy) -> CGEvent?)?

    private var tap: CFMachPort?
    private var thread: Thread?
    private var runLoop: CFRunLoop?

    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let me = Unmanaged<KeyTap>.fromOpaque(refcon!).takeUnretainedValue()
            return me.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap

        let t = Thread { [weak self] in
            guard let self, let tap = self.tap else { return }
            self.runLoop = CFRunLoopGetCurrent()
            let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        t.qualityOfService = .userInteractive
        t.name = "org.govi.keytap"
        t.start()
        thread = t
        return true
    }

    /// Chạy block trên thread của tap (serialize với callback).
    func perform(_ block: @escaping () -> Void) {
        guard let runLoop else { block(); return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker {
            return Unmanaged.passUnretained(event)
        }
        if let out = onEvent?(type, event, proxy) {
            return Unmanaged.passUnretained(out)
        }
        return nil
    }
}
