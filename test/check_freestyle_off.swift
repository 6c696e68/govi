import Foundation

func applyEdit(_ s: [Character], _ del: Int, _ ins: String) -> [Character] {
    var a = s
    if del > 0 { a.removeLast(min(del, a.count)) }
    a.append(contentsOf: Array(ins))
    return a
}

func typeWord(_ keys: String, freeStyle: Bool) -> String {
    let p = VietTelex()
    p.freeStyleMarks = freeStyle
    var buf: [Character] = []
    for ch in keys where ch.isASCII && ch.isLetter {
        let r = p.input(ch)
        buf = applyEdit(buf, r.delete, r.insert)
    }
    let r = p.breakWord()
    buf = applyEdit(buf, r.delete, r.insert)
    return String(buf)
}

// Khi TẮT free-style: gõ inline chuẩn vẫn đúng; gõ dấu sau phụ âm cuối -> KHÔNG ăn
// (giữ Telex chặt), trả về chuỗi thô như cũ.
let cases: [(String, String)] = [
    ("nguyeenx", "nguyễn"),   // inline vẫn phải đúng khi tắt
    ("vieejt",   "việt"),
    ("ddoongf",  "đồng"),
    ("tieengs",  "tiếng"),
    ("nguyenex", "nguyenex"), // free-style tắt -> không ăn dấu cuối từ
    ("vietje",   "vietje"),
    ("ddongfo",  "ddongfo"),
]

var ok = true
for (inp, exp) in cases {
    let got = typeWord(inp, freeStyle: false)
    let mark = got == exp ? "[PASS]" : "[FAIL]"
    if got != exp { ok = false }
    print("\(mark) OFF '\(inp)' got='\(got)' exp='\(exp)'")
}
exit(ok ? 0 : 1)
