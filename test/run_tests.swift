import Foundation

// Test engine VietTelex bằng golden file tĩnh (đáp án đã chốt).
// Mỗi dòng golden: <chuỗi phím><TAB><kết quả mong đợi sau khi gõ xong từ>.
// Mô phỏng: gõ từng phím rồi kết từ (breakWord) — khớp hành vi thật.

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
    let r = p.breakWord()           // kết từ (như nhấn space)
    buf = applyEdit(buf, r.delete, r.insert)
    return String(buf)
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "test/golden.tsv"
guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
    FileHandle.standardError.write("Không đọc được \(path)\n".data(using: .utf8)!)
    exit(2)
}

var pass = 0, fail = 0, shown = 0
for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
    let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { continue }
    let input = String(parts[0])
    let expected = String(parts[1])
    let got = typeWord(input)
    if got == expected {
        pass += 1
    } else {
        fail += 1
        if shown < 40 { print("[FAIL] '\(input)' got='\(got)' exp='\(expected)'"); shown += 1 }
    }
}
print("== \(pass)/\(pass + fail) PASS ==")
exit(fail == 0 ? 0 : 1)
