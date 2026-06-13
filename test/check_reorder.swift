import Foundation

// Quét tổ hợp âm tiết tiếng Việt, gõ theo nhiều THỨ TỰ phím khác nhau (đặc biệt là
// đặt dấu mũ/móc/thanh SAU phụ âm cuối — kiểu "free-style telex"), và kiểm tra engine
// luôn ra đúng 1 kết quả. Oracle = chuỗi telex inline chuẩn; bỏ qua tổ hợp không hợp lệ.

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

let toneKeyToInt: [String: Int] = ["": 0, "f": 1, "s": 2, "r": 3, "x": 4, "j": 5]

// nucleus: (phím gốc, phím dấu mũ/móc, ký tự đã mang dấu mũ/móc thường)
struct Nuc { let base: String; let shape: String; let ch: Character }
let nuclei: [Nuc] = [
    Nuc(base: "a", shape: "",  ch: "a"),
    Nuc(base: "a", shape: "a", ch: "â"),
    Nuc(base: "a", shape: "w", ch: "ă"),
    Nuc(base: "e", shape: "",  ch: "e"),
    Nuc(base: "e", shape: "e", ch: "ê"),
    Nuc(base: "o", shape: "",  ch: "o"),
    Nuc(base: "o", shape: "o", ch: "ô"),
    Nuc(base: "o", shape: "w", ch: "ơ"),
    Nuc(base: "u", shape: "",  ch: "u"),
    Nuc(base: "u", shape: "w", ch: "ư"),
    Nuc(base: "i", shape: "",  ch: "i"),
]

let initials = ["", "b", "c", "d", "h", "l", "m", "n", "t", "v", "x",
                "ch", "kh", "ng", "nh", "ph", "th", "tr"]
let finals = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]
let tones = ["", "f", "s", "r", "x", "j"]

func expectedString(_ ini: String, _ nuc: Nuc, _ fin: String, _ tone: String) -> String {
    let t = toneKeyToInt[tone]!
    let v: Character = t > 0 ? (VC.toneMark(nuc.ch, t) ?? nuc.ch) : nuc.ch
    return ini + String(v) + fin
}

// Sinh các thứ tự gõ khác nhau cho 1 âm tiết. Trả (keys, shapeSauPhuAmCuoi).
func variants(_ ini: String, _ nb: String, _ shape: String, _ fin: String, _ tone: String) -> [(String, Bool)] {
    var seen = Set<String>()
    var out: [(String, Bool)] = []
    func add(_ s: String, _ shapeAfterFinal: Bool) {
        if seen.insert(s).inserted { out.append((s, shapeAfterFinal)) }
    }
    let hasFin = !fin.isEmpty
    add(ini + nb + shape + fin + tone, false)     // inline chuẩn (oracle)
    add(ini + nb + fin + shape + tone, hasFin)     // mũ sau phụ âm cuối, thanh cuối
    add(ini + nb + fin + tone + shape, hasFin)     // thanh trước mũ, cả hai ở cuối
    add(ini + nb + shape + tone + fin, false)      // mũ + thanh trước phụ âm cuối
    add(ini + nb + tone + shape + fin, false)      // thanh + mũ trước phụ âm cuối
    add(ini + nb + tone + fin + shape, hasFin)     // thanh giữa, mũ ở cuối
    return out
}

var totalSyll = 0, skipped = 0
var passV = 0, failV = 0, shownFail = 0
var batch = 0
// Phân loại lỗi: theo loại dấu mũ/móc và vị trí.
var failByShape: [String: Int] = [:]
var failShapeAfterFinal = 0, failOther = 0
// PASS theo loại để so sánh (w-hook so với double-key)
var passShapeAfterFinal = 0

for ini in initials {
    for nuc in nuclei {
        for fin in finals {
            for tone in tones {
                let inline = ini + nuc.base + nuc.shape + fin + tone
                let expected = expectedString(ini, nuc, fin, tone)
                // Oracle: chỉ nhận tổ hợp mà engine gõ inline ra đúng âm tiết (lọc tổ hợp sai cấu trúc).
                if typeWord(inline) != expected { skipped += 1; continue }
                totalSyll += 1
                for (keys, shapeAfterFinal) in variants(ini, nuc.base, nuc.shape, fin, tone) {
                    let got = typeWord(keys)
                    if got == expected {
                        passV += 1
                        if shapeAfterFinal { passShapeAfterFinal += 1 }
                    } else {
                        failV += 1
                        let shapeName = nuc.shape.isEmpty ? "(none)" : nuc.shape
                        failByShape[shapeName, default: 0] += 1
                        if shapeAfterFinal { failShapeAfterFinal += 1 } else { failOther += 1 }
                        if shownFail < 40 {
                            print("[FAIL] '\(keys)' got='\(got)' exp='\(expected)'")
                            shownFail += 1
                        }
                    }
                }
            }
        }
        batch += 1
        if batch % 40 == 0 {
            print("... progress: syllables=\(totalSyll) variantsPASS=\(passV) variantsFAIL=\(failV)")
            fflush(stdout)
        }
    }
}

print("================================================")
print("Âm tiết hợp lệ test: \(totalSyll) (bỏ qua tổ hợp không hợp lệ: \(skipped))")
print("Biến thể thứ tự gõ:  PASS=\(passV)  FAIL=\(failV)  (tổng \(passV + failV))")
print("------------------------------------------------")
print("FAIL theo loại dấu mũ/móc: \(failByShape.sorted { $0.key < $1.key })")
print("FAIL khi 'mũ/móc đặt SAU phụ âm cuối': \(failShapeAfterFinal)  | PASS cùng nhóm: \(passShapeAfterFinal)")
print("FAIL ở vị trí khác:                    \(failOther)")
print("================================================")
exit(failV == 0 ? 0 : 1)
