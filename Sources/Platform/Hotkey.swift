import CoreGraphics

/// Nhận diện phím tắt Control+Shift (nhấn cả hai rồi nhả, không kèm Cmd/Alt,
/// không có phím gõ xen ngang) để bật/tắt bộ gõ.
final class Hotkey {
    private var armed = false
    var onToggle: (() -> Void)?

    /// Gọi mỗi khi flagsChanged.
    func flags(_ flags: CGEventFlags) {
        let ctrl = flags.contains(.maskControl)
        let shift = flags.contains(.maskShift)
        let other = flags.contains(.maskCommand) || flags.contains(.maskAlternate)
        if ctrl && shift && !other {
            armed = true
        } else if armed {
            armed = false
            onToggle?()
        }
    }

    /// Có phím thường gõ giữa chừng -> huỷ, không tính là toggle.
    func keyInterrupt() { armed = false }
}
