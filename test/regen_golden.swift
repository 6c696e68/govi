import Foundation

// Đọc golden.tsv, tính lại cột kết quả từ engine hiện tại, ghi đè (giữ thứ tự + input).
// Dùng khi engine đổi hành vi có chủ đích; in ra các dòng thay đổi để soi lại.

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

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "test/golden.tsv"
let content = try! String(contentsOfFile: path, encoding: .utf8)
var out = "", changed = 0
for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
    let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { out += line + "\n"; continue }
    let input = String(parts[0]), oldExp = String(parts[1])
    let got = typeWord(input)
    if got != oldExp { print("CHANGE '\(input)': '\(oldExp)' -> '\(got)'"); changed += 1 }
    out += "\(input)\t\(got)\n"
}
try! out.write(toFile: path, atomically: true, encoding: .utf8)
print("== cập nhật \(changed) dòng ==")
