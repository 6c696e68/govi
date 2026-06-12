import AppKit

// Tạo icon Govi: squircle gradient indigo + chữ "ô" trắng (nguyên âm tiếng Việt),
// phong cách tối giản. Xuất PNG 1024.
let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let radius = rect.width * 0.2237
let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

let top = NSColor(srgbRed: 0.40, green: 0.45, blue: 1.00, alpha: 1)
let bottom = NSColor(srgbRed: 0.36, green: 0.20, blue: 0.83, alpha: 1)
let grad = NSGradient(starting: top, ending: bottom)!
grad.draw(in: squircle, angle: -90)

let glyph = "V" as NSString
var font = NSFont.systemFont(ofSize: S * 0.55, weight: .bold)
if let d = NSFont.systemFont(ofSize: S * 0.55, weight: .bold).fontDescriptor.withDesign(.rounded),
   let rounded = NSFont(descriptor: d, size: S * 0.55) {
    font = rounded
}
let para = NSMutableParagraphStyle(); para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: font, .foregroundColor: NSColor.white, .paragraphStyle: para,
]
let tsize = glyph.size(withAttributes: attrs)
glyph.draw(at: NSPoint(x: (S - tsize.width) / 2, y: (S - tsize.height) / 2 - S * 0.01), withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/govi_icon_1024.png"))
print("wrote /tmp/govi_icon_1024.png")
