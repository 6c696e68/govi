import CoreGraphics
import Foundation

// Gửi chuỗi phím thật, mỗi phím 1 keyDown+keyUp, cách 200ms. Đối chiếu log Govi.
let map: [Character: CGKeyCode] = [
    "t":17,"r":15,"a":0,"n":45,"s":1,"c":8,"i":34,"o":31,"e":14,"v":9,"d":2,
]
let word = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "transaction"
for ch in word {
    guard let code = map[ch] else { continue }
    let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
    let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)!
    d.post(tap: .cghidEventTap); usleep(10000); u.post(tap: .cghidEventTap)
    print("sent '\(ch)'"); fflush(stdout)
    usleep(200000)
}
