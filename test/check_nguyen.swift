import Foundation

func applyEdit(_ s: [Character], _ del: Int, _ ins: String) -> [Character] {
    var a = s
    if del > 0 { a.removeLast(min(del, a.count)) }
    a.append(contentsOf: Array(ins))
    return a
}

func typeWord(_ keys: String) -> String {
    let p = VietTelex()
    var buf: [Character] = []
    for ch in keys where ch.isASCII && ch.isLetter {
        let r = p.input(ch)
        buf = applyEdit(buf, r.delete, r.insert)
    }
    let r = p.breakWord()
    buf = applyEdit(buf, r.delete, r.insert)
    return String(buf)
}

// Các kiểu gõ "nguyễn" + vài từ có ê/â/ô đặt dấu mũ ở cuối từ.
let cases: [(String, String)] = [
    ("nguyeenx", "nguyễn"),   // chuẩn: ee liền nhau
    ("nguyeexn", "nguyễn"),   // dấu trước n
    ("nguyenxe", "nguyễn"),   // mũ ở cuối, sau tone
    ("nguyenex", "nguyễn"),   // mũ trước, tone cuối
    ("nguyexne", "nguyễn"),   // tone giữa, mũ cuối
    ("tieengs",  "tiếng"),
    ("tienesg",  "tiếng"),    // mũ + tone đặt cuối
    ("vieejt",   "việt"),
    ("vietje",   "việt"),     // mũ cuối
    ("ddoongf",  "đồng"),
    ("ddongfo",  "đồng"),     // mũ cuối
]

for (inp, exp) in cases {
    let got = typeWord(inp)
    let mark = got == exp ? "[PASS]" : "[FAIL]"
    print("\(mark) '\(inp)' got='\(got)' exp='\(exp)'")
}
