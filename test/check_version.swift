import Foundation

func applyEdit(_ s: [Character], _ del: Int, _ ins: String) -> [Character] {
    var a = s
    if del > 0 { a.removeLast(min(del, a.count)) }
    a.append(contentsOf: Array(ins))
    return a
}

// Gõ từng phím, in trạng thái hiển thị sau mỗi phím + sau breakWord (space).
func trace(_ keys: String) {
    let p = VietTelex()
    var buf: [Character] = []
    print("=== gõ '\(keys)' ===")
    for ch in keys where ch.isASCII && ch.isLetter {
        let r = p.input(ch)
        buf = applyEdit(buf, r.delete, r.insert)
        print("  key '\(ch)' -> del=\(r.delete) ins='\(r.insert)'  hiển thị='\(String(buf))'")
    }
    let r = p.breakWord()
    buf = applyEdit(buf, r.delete, r.insert)
    print("  [breakWord] del=\(r.delete) ins='\(r.insert)'  KẾT QUẢ='\(String(buf))'")
}

let words = ["version", "versions", "reset", "first", "test", "users", "parser", "verrs", "verr", "verrsion"]
for w in words { trace(w) }
