import CoreGraphics
import Foundation

// Gửi chuỗi phím thật (mô phỏng gõ tay, kể cả bấm 'r' 2 lần) để đối chiếu log Govi.
// Mỗi phần tử: (tên, keycode). 'r' xuất hiện 2 lần = mô phỏng bấm lại do thấy "vẻ".
let seq: [(String, CGKeyCode)] = [
    ("v",9),("e",14),("r",15),("r",15),("s",1),("i",34),("o",31),("n",45),
]
for (name, code) in seq {
    let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
    let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)!
    d.post(tap: .cghidEventTap)
    usleep(10000)
    u.post(tap: .cghidEventTap)
    print("sent '\(name)'")
    fflush(stdout)
    usleep(250000)
}
