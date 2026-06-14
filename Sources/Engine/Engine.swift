import Foundation

/// Engine Telex: buffer phím thô (raw) + chuỗi hiển thị (text), mỗi phím thử
/// dấu đôi/mũ móc/thanh rồi đặt dấu theo luật tiếng Việt, khôi phục khi kết từ.
final class VietTelex {
    private var raw: [Character] = []
    private var text: [Character] = []
    private var toneIndex: Int = -1
    private var lastOutput: [Character] = []

    /// Bật khi phát hiện chuỗi không phải tiếng Việt (vd hai phím dấu liền nhau):
    /// phần còn lại của từ giữ nguyên literal tới khi kết từ. Reset ở reset().
    private var literalMode = false

    var autoRestore = true

    /// Gõ tự do (free-style): cho phép đặt dấu mũ aa/ee/oo SAU phụ âm cuối, vd
    /// "nguyenex"->nguyễn, "vietje"->việt. Tắt đi để giữ Telex chặt (mũ phải gõ
    /// liền nguyên âm), thân thiện hơn khi xen lẫn từ tiếng Anh.
    var freeStyleMarks = true

    func reset() {
        raw.removeAll(keepingCapacity: true)
        text.removeAll(keepingCapacity: true)
        lastOutput.removeAll(keepingCapacity: true)
        toneIndex = -1
        literalMode = false
    }

    /// Nạp 1 ký tự -> (xoá, chèn) so với lần render trước.
    func input(_ ch: Character) -> (delete: Int, insert: String) {
        replayKey(ch)
        return diffUpdate()
    }

    /// Kết từ (space/dấu câu): khôi phục tiếng Anh / nhả dấu nếu sai cấu trúc, rồi reset.
    func breakWord() -> (delete: Int, insert: String) {
        var result: (Int, String) = (0, "")
        // Chỉ khôi phục khi text CÒN dấu tiếng Việt (xử lý nhầm cần gỡ): "kiro"->"kỉo"->"kiro".
        // Nếu đã escape (gõ dấu đôi) thành text không dấu thì giữ nguyên, không bung lại raw
        // -> "gorri"->"gori", "kirr"->"kir" (Telex thuần, gộp dấu đôi).
        if !raw.isEmpty, autoRestore, VC.hasVietMark(text[...]) {
            var textLo: [Character] = []      // giữ mũ/móc -> validate cấu trúc âm tiết
            var textAscii: [Character] = []   // ascii thuần -> dò tiếng Anh
            for c in text {
                let s = VC.toLower(VC.stripTone(c))
                if VC.isAlpha(s) || s == "đ" || VC.isVowel(s) {
                    textLo.append(s)
                    textAscii.append(VC.toLower(VC.stripToneAndAccent(c)))
                }
            }
            if !textLo.isEmpty, !Self.isCompleteSyllable(textLo) {
                if Self.isLikelyEnglish(textAscii) {
                    result = (text.count, String(raw))               // tiếng Anh -> raw thô
                } else if let demoted = demoteToneToLiteral() {
                    result = (text.count, demoted)                   // "đừing" -> "đưingf"
                }
            }
        }
        reset()
        return result
    }

    /// Bỏ dấu thanh trên text, đẩy phím dấu xuống cuối thành chữ; nil nếu không có dấu.
    private func demoteToneToLiteral() -> String? {
        for i in 0..<text.count {
            let t = VC.toneOf(text[i])
            guard t > 0, let key = Self.toneKey(t) else { continue }
            var out = text
            out[i] = VC.stripTone(text[i])
            out.append(key)
            return String(out)
        }
        return nil
    }

    private static func toneKey(_ t: Int) -> Character? {
        switch t {
        case 1: return "f"; case 2: return "s"; case 3: return "r"; case 4: return "x"; case 5: return "j"
        default: return nil
        }
    }

    func backspace(removeLast n: Int = 1) {
        reset()
    }

    // MARK: - Diff

    private func diffUpdate() -> (delete: Int, insert: String) {
        var common = 0
        let lim = min(lastOutput.count, text.count)
        while common < lim && lastOutput[common] == text[common] { common += 1 }
        let del = lastOutput.count - common
        let ins = String(text[common...])
        lastOutput = text
        return (del, ins)
    }

    // MARK: - ReplayKey

    private func replayKey(_ ch: Character) {
        let lo = VC.toLower(ch)
        raw.append(ch)

        // Đã xác định không phải tiếng Việt -> phần còn lại của từ giữ literal.
        if literalMode { text.append(ch); return }

        // Dấu thanh chỉ đặt được lên nguyên âm. Phím dấu (f/s/r/x/j/z) chỉ được coi là
        // "dấu" khi buffer đã có nguyên âm; chưa có nguyên âm (vd "j" trong "json",
        // "rs" trong "rss") thì nó là chữ literal, KHÔNG được gỡ/đặt lại dấu — nếu không
        // sẽ nuốt ký tự đứng trước của từ tiếng Anh.
        let hasVowel = text.contains { VC.isVowel(VC.stripTone($0)) }

        // Hai phím dấu thanh KHÁC NHAU gõ liền nhau (phím raw ngay trước cũng là phím
        // dấu): tiếng Việt không có (mỗi âm tiết chỉ 1 thanh) -> đây là tiếng Anh, nhả
        // cả buffer về đúng chuỗi đã gõ thay vì "đổi dấu". Vd "vers" (r+s) -> "vers",
        // "verrs" (r+r đã undo + s) -> "verrs", "users" (r+s) -> "users".
        // Phím dấu LẶP cùng loại (rr/ss) vẫn là undo, không vào đây (prevKey == lo).
        if hasVowel, VC.toneIndex(lo) >= 0, raw.count >= 2 {
            let prevKey = VC.toLower(raw[raw.count - 2])
            if VC.toneIndex(prevKey) >= 0, prevKey != lo {
                // Còn dấu -> phím dấu trước ĐẶT dấu (vd "vers", "users"): dựng lại từ raw
                // để khôi phục phím dấu đã bị "ăn" vào thanh.
                // Hết dấu -> phím dấu trước là UNDO (vd gõ lại "r" để gỡ "vẻ" -> "ver"):
                // chỉ nối phím hiện tại vào text, tránh nhân đôi phím undo ("verrs"->"vers").
                if VC.hasVietMark(text[...]) {
                    text = raw
                } else {
                    text.append(ch)
                }
                literalMode = true
                return
            }
        }

        // Gõ lại dấu: nếu ký tự cuối là phím dấu thừa của lần trước (vd "tichx"),
        // bỏ nó để đặt lại dấu cho đúng -> "tích", khỏi xoá hết.
        // Nhưng nếu spam ĐÚNG phím dấu vừa nhả ra (vd "ki" + r + r + r...), thì các
        // lần sau chỉ thêm ký tự thường, KHÔNG bật lại dấu (tránh toggle dấu).
        if hasVowel, VC.toneIndex(lo) >= 0, let last = text.last, VC.toneIndex(VC.toLower(last)) >= 0 {
            if VC.toLower(last) == lo {
                text.append(ch)
                return
            }
            text.removeLast()
        }

        let bypass = shouldBypass()
        var applied = false
        let isDouble = (lo == "a" || lo == "e" || lo == "o" || lo == "d")
        let isHook = (lo == "w")

        if !bypass, isDouble, !text.isEmpty, applyDoubleKeys(ch) { applied = true }
        // Free-style mũ vẫn thử cả khi bị bypass: hàm tự validate (chỉ commit nếu ra
        // âm tiết hoàn chỉnh) nên không phá từ tiếng Anh, nhưng cứu được ca mà phụ âm
        // cuối khiến buffer chưa hợp lệ, vd "benhe"->bênh ("e"+nh bắt buộc có mũ).
        if bypass, !applied, freeStyleMarks, isDouble, !text.isEmpty, applyDoubleFreeStyle(ch) { applied = true }
        if !bypass, !applied, isHook, !text.isEmpty, applyHookKeys(ch) { applied = true }
        if !bypass, !applied {
            let ti = VC.toneIndex(lo)
            if ti >= 0, !text.isEmpty, applyToneMarks(ti) { applied = true }
        }
        if !applied { text.append(ch) }

        // Bù dấu ư cho "uơ" khi có ký tự sau ơ.
        if !bypass, text.count >= 3 {
            var i = 0
            while i < text.count - 1 {
                let v1 = VC.toLower(VC.stripTone(text[i]))
                let v2 = VC.toLower(VC.stripTone(text[i + 1]))
                if v1 == "u" && v2 == "ơ" && (i + 1 < text.count - 1) {
                    let up = text[i].isUppercase
                    let t = VC.toneOf(text[i])
                    let nb: Character = up ? "Ư" : "ư"
                    text[i] = t > 0 ? (VC.toneMark(nb, t) ?? nb) : nb
                }
                i += 1
            }
        }
    }

    // MARK: - Apply double keys (aa/ee/oo/dd)

    private func applyDoubleKeys(_ key: Character) -> Bool {
        if applyDoubleAdjacent(key) { return true }
        if freeStyleMarks, applyDoubleFreeStyle(key) { return true }
        return false
    }

    /// Free-style: mũ aa/ee/oo gõ SAU phụ âm cuối. Quét lùi qua phụ âm (giống
    /// applyHookKeys) tới nguyên âm đầu tiên; chỉ đặt mũ khi nguyên âm đó khớp phím
    /// và kết quả là âm tiết hoàn chỉnh, nếu không trả về để xử như ký tự thường.
    private func applyDoubleFreeStyle(_ key: Character) -> Bool {
        let loKey = VC.toLower(key)
        guard loKey == "a" || loKey == "e" || loKey == "o" else { return false }
        var j = text.count - 1
        while j >= 0 {
            let target = text[j]
            let base = VC.stripTone(target)
            if VC.isVowel(base) {
                // 'â'/'ô'/'ơ' (đã có mũ/móc) -> loBase khác loKey -> không đụng (undo
                // chỉ làm ở bản liền trước). Nguyên âm đầu tiên không khớp -> literal.
                guard VC.toLower(base) == loKey else { return false }

                // Không bridge freestyle qua 1 phụ âm cuối đơn (c/m/n/p/t) khi âm tiết
                // CÓ phụ âm đầu: phụ âm đơn đóng âm tiết mạnh, nguyên âm kế gần như
                // chắc chắn bắt đầu phần mới (vd "data", "camo", "banana").
                // Nếu KHÔNG có phụ âm đầu (vd "ama"->âm, "ana"->ân) thì cho phép
                // freestyle — đây là case gõ tắt hợp lệ.
                // Bridge qua cụm ≥2 phụ âm (ng/nh/ch) luôn cho phép (vd "benhe"->bênh).
                let consonantsAfter = text.count - 1 - j
                if consonantsAfter == 1, j > 0, !VC.isVowel(VC.stripTone(text[0])) {
                    let fc = VC.toLower(VC.stripTone(text[j + 1]))
                    if fc == "c" || fc == "m" || fc == "n" || fc == "p" || fc == "t" {
                        return false
                    }
                }
                let up = base.isUppercase
                let tone = VC.toneOf(target)
                let circ: Character
                switch loKey {
                case "a": circ = up ? "Â" : "â"
                case "e": circ = up ? "Ê" : "ê"
                default:  circ = up ? "Ô" : "ô"
                }
                let newCh = tone > 0 ? (VC.toneMark(circ, tone) ?? circ) : circ
                func strip(_ t: [Character]) -> [Character] { t.map { VC.toLower(VC.stripTone($0)) } }
                let saved = text
                text[j] = newCh
                if Self.isCompleteSyllable(strip(text)) { return true }
                // Dấu thanh gõ TRƯỚC mũ bị kẹt thành ký tự cuối (f/s/r/x/j không bao giờ
                // là phụ âm cuối tiếng Việt) -> gỡ ra, đặt mũ xong đặt lại dấu đúng chỗ,
                // vd "benhje"->bệnh, "echse"->ếch.
                if let last = text.last, VC.toneIndex(VC.toLower(last)) > 0 {
                    let tk = VC.toneIndex(VC.toLower(last))
                    text.removeLast()
                    if Self.isCompleteSyllable(strip(text)), applyToneMarks(tk) { return true }
                }
                text = saved
                return false
            }
            j -= 1
        }
        return false
    }

    private func applyDoubleAdjacent(_ key: Character) -> Bool {
        let loKey = VC.toLower(key)
        // Telex: aa/ee/oo/dd chỉ ghép với ký tự LIỀN TRƯỚC (quét cả buffer sẽ ghép
        // bắc cầu sai: academic->âc, ngoeo->ngôe).
        let j = text.count - 1
        guard j >= 0 else { return false }
        let target = text[j]
        let baseTarget = VC.stripTone(target)
        let loBase = VC.toLower(baseTarget)
        let up = baseTarget.isUppercase
        let tone = VC.toneOf(target)

        func setBase(_ b: Character) { text[j] = tone > 0 ? (VC.toneMark(b, tone) ?? b) : b }

        // Undo
        if loKey == "a", loBase == "â" || loBase == "ă" {
            setBase(up ? "A" : "a"); text.append(key); return true
        }
        if loKey == "e", loBase == "ê" { setBase(up ? "E" : "e"); text.append(key); return true }
        if loKey == "o", loBase == "ô" || loBase == "ơ" {
            setBase(up ? "O" : "o"); text.append(key); return true
        }
        if loKey == "d", loBase == "đ" { setBase(up ? "D" : "d"); text.append(key); return true }

        // Apply
        if loKey == "a", loBase == "a" { setBase(up ? "Â" : "â"); return true }
        if loKey == "e", loBase == "e" { setBase(up ? "Ê" : "ê"); return true }
        if loKey == "o", loBase == "o" { setBase(up ? "Ô" : "ô"); return true }
        if loKey == "d", loBase == "d" { text[j] = up ? "Đ" : "đ"; return true }

        return false
    }

    // MARK: - Apply hook keys ('w')

    private func applyHookKeys(_ key: Character) -> Bool {
        var j = text.count - 1
        while j >= 0 {
            let target = text[j]
            let baseTarget = VC.stripTone(target)
            let loBase = VC.toLower(baseTarget)
            let up = baseTarget.isUppercase
            let tone = VC.toneOf(target)

            func toned(_ b: Character, _ t: Int) -> Character { t > 0 ? (VC.toneMark(b, t) ?? b) : b }

            // 1) Undo ă/ơ/ư
            if loBase == "ă" || loBase == "ơ" || loBase == "ư" {
                if loBase == "ơ", j > 0, VC.toLower(VC.stripTone(text[j - 1])) == "ư" {
                    let pb = VC.stripTone(text[j - 1])
                    let pUp = pb.isUppercase
                    let pT = VC.toneOf(text[j - 1])
                    text[j - 1] = toned(pUp ? "U" : "u", pT)
                    text[j] = toned(up ? "O" : "o", tone)
                } else {
                    let nb: Character = (loBase == "ă") ? (up ? "A" : "a")
                        : (loBase == "ơ") ? (up ? "O" : "o") : (up ? "U" : "u")
                    text[j] = toned(nb, tone)
                }
                text.append(key); return true
            }
            if loBase == "u", j > 0, VC.toLower(VC.stripTone(text[j - 1])) == "ư" {
                let pb = VC.stripTone(text[j - 1]); let pUp = pb.isUppercase; let pT = VC.toneOf(text[j - 1])
                text[j - 1] = toned(pUp ? "U" : "u", pT)
                text.append(key); return true
            }

            // 2) Apply: cụm u/ư + o/ơ -> ươ (hoặc uơ ngoại lệ th/h/q/kh không phụ âm cuối)
            if (loBase == "o" || loBase == "ơ"), j > 0,
               (VC.toLower(VC.stripTone(text[j - 1])) == "u" || VC.toLower(VC.stripTone(text[j - 1])) == "ư") {
                var uoException = false
                let hasAfter = (j < text.count - 1)
                if !hasAfter {
                    let uIndex = j - 1
                    if uIndex > 0 {
                        let p1 = VC.toLower(VC.stripTone(text[uIndex - 1]))
                        if p1 == "h" {
                            uoException = true
                            if uIndex > 1 {
                                let p2 = VC.toLower(VC.stripTone(text[uIndex - 2]))
                                if p2 == "t" || p2 == "k" { uoException = true }
                                else if p2 >= "a" && p2 <= "z" { uoException = false }
                            }
                        } else if p1 == "q" { uoException = true }
                    }
                }
                let pb = VC.stripTone(text[j - 1]); let pUp = pb.isUppercase; let pT = VC.toneOf(text[j - 1])
                if uoException {
                    text[j - 1] = toned(pUp ? "U" : "u", pT)
                    text[j] = toned(up ? "Ơ" : "ơ", tone)
                } else {
                    text[j - 1] = toned(pUp ? "Ư" : "ư", pT)
                    text[j] = toned(up ? "Ơ" : "ơ", tone)
                }
                return true
            }
            if loBase == "a", j > 0, VC.toLower(VC.stripTone(text[j - 1])) == "u" {
                let isQu = (j >= 2 && VC.toLower(text[j - 2]) == "q")
                if !isQu {
                    let pb = VC.stripTone(text[j - 1]); let pUp = pb.isUppercase; let pT = VC.toneOf(text[j - 1])
                    text[j - 1] = toned(pUp ? "Ư" : "ư", pT)
                    return true
                }
            }
            if loBase == "u", j > 0, VC.toLower(VC.stripTone(text[j - 1])) == "u" {
                let pb = VC.stripTone(text[j - 1]); let pUp = pb.isUppercase; let pT = VC.toneOf(text[j - 1])
                text[j - 1] = toned(pUp ? "Ư" : "ư", pT)
                return true
            }
            // 'u' cuối nhưng trước là nguyên âm khác (ou,au,eu,iu) -> lùi tiếp
            if loBase == "u", j > 0 {
                let pb = VC.toLower(VC.stripTone(text[j - 1]))
                let isGi = (pb == "i" && j > 1 && VC.toLower(VC.stripTone(text[j - 2])) == "g")
                if !isGi && (VC.isVowel(pb) || pb == "q") { j -= 1; continue }
            }

            if let hr = VC.hookRule(baseTarget) {
                text[j] = toned(hr, tone); return true
            }
            // Quét qua phụ âm được (hỗ trợ 'w' cuối từ: "duongw"->đương) nhưng dừng
            // ở nguyên âm không móc được, tránh bắc cầu ("ai"+w không thành "ăi").
            if VC.isVowel(baseTarget) { break }
            j -= 1
        }
        return false
    }

    // MARK: - Apply tone marks (s/f/r/x/j/z)

    private func applyToneMarks(_ ti: Int) -> Bool {
        if text.isEmpty { return false }

        // Smart bypass: nguyên âm rời rạc (vd remix) -> không bỏ dấu.
        var firstV = -1, lastV = -1, vc = 0
        for i in 0..<text.count where VC.isVowel(text[i]) {
            if firstV == -1 { firstV = i }
            lastV = i; vc += 1
        }
        if vc > 1 && (lastV - firstV >= vc) { return false }

        // Chuẩn hoá u/ư + o/ơ -> ươ trên BẢN SAO rồi validate; chỉ commit vào text khi
        // âm tiết hợp lệ. Commit vô điều kiện sẽ phá từ tiếng Anh có "uo" sinh ra do đặt
        // dấu (vd "aurora": "ảuo" -> "ảươ" rồi rớt dấu thành "aươrar").
        let norm = Self.normalizedUoToUow(text)
        var struc: [Character] = []
        for c in norm { struc.append(VC.toLower(VC.stripTone(c))) }
        if !Self.isCompleteSyllable(struc) { return false }
        text = norm

        var currentTone = 0, tonePos = -1
        for i in 0..<text.count {
            let t = VC.toneOf(text[i])
            if t > 0 { tonePos = i; currentTone = t; break }
        }

        if ti == 0 {
            if currentTone > 0 { text[tonePos] = VC.stripTone(text[tonePos]); toneIndex = -1; return true }
            return false
        }
        if currentTone == ti {
            // Gõ lại ĐÚNG phím dấu vừa đặt = "gỡ dấu". Đây là tín hiệu mạnh người dùng
            // không muốn dấu ở từ này (tiếng Anh): bỏ dấu + giữ literal phần còn lại của
            // từ. Vd "trans"(s gỡ sắc)+action -> "transaction", "ver"(r gỡ hỏi)+sion.
            text[tonePos] = VC.stripTone(text[tonePos]); toneIndex = -1
            literalMode = true
            return false
        }

        // Auto uo -> ươ đã chuẩn hoá ở normalizeUoToUow() phía trên.

        let target = (tonePos >= 0) ? tonePos : findTonePosition()
        if target >= 0 {
            let orig = text[target]
            let up = orig.isUppercase
            let base = VC.stripTone(orig)
            if let toned = VC.toneMark(base, ti) {
                text[target] = up ? Character(String(toned).uppercased()) : toned
                toneIndex = ti
                return true
            }
        }
        return false
    }

    // MARK: - Normalize uo/ưo -> ươ

    /// Trả về bản sao đã chuẩn hoá cụm u/ư + o/ơ thành ươ (giữ nguyên dấu thanh nếu có).
    /// Ngoại lệ uơ cho th/h/q không phụ âm cuối (vd "thuở", "quở"). Chỉ đụng cặp nguyên
    /// âm đầu tiên. Hàm thuần, KHÔNG sửa text — caller tự quyết có commit hay không.
    private static func normalizedUoToUow(_ src: [Character]) -> [Character] {
        var text = src
        var i = 0
        while i < text.count - 1 {
            let v1 = VC.toLower(VC.stripTone(text[i]))
            let v2 = VC.toLower(VC.stripTone(text[i + 1]))
            if (v1 == "u" || v1 == "ư") && (v2 == "o" || v2 == "ơ") {
                var uoException = false
                let hasAfter = (i + 1 < text.count - 1)
                if !hasAfter, i > 0 {
                    let p1 = VC.toLower(VC.stripTone(text[i - 1]))
                    if p1 == "h" {
                        uoException = true
                        if i > 1 {
                            let p2 = VC.toLower(VC.stripTone(text[i - 2]))
                            if p2 == "t" || p2 == "k" { uoException = true }
                            else if p2 >= "a" && p2 <= "z" { uoException = false }
                        }
                    } else if p1 == "q" { uoException = true }
                }
                let up1 = text[i].isUppercase, up2 = text[i + 1].isUppercase
                let t1 = VC.toneOf(text[i]), t2 = VC.toneOf(text[i + 1])
                func toned(_ b: Character, _ t: Int) -> Character { t > 0 ? (VC.toneMark(b, t) ?? b) : b }
                if uoException {
                    if !(v1 == "u" && v2 == "ơ") {
                        text[i] = toned(up1 ? "U" : "u", t1); text[i + 1] = toned(up2 ? "Ơ" : "ơ", t2)
                    }
                } else {
                    if !(v1 == "ư" && v2 == "ơ") {
                        text[i] = toned(up1 ? "Ư" : "ư", t1); text[i + 1] = toned(up2 ? "Ơ" : "ơ", t2)
                    }
                }
                break
            }
            i += 1
        }
        return text
    }

    // MARK: - Find tone position
    private func findTonePosition() -> Int {
        if text.isEmpty { return -1 }
        var first = -1, last = -1, count = 0
        for i in 0..<text.count where VC.isVowel(text[i]) {
            if first == -1 { first = i }
            last = i; count += 1
        }
        if count == 0 { return -1 }
        if count == 1 { return first }

        var hasFinal = false
        if last + 1 < text.count {
            for i in (last + 1)..<text.count where VC.isAlpha(text[i]) && !VC.isVowel(text[i]) {
                hasFinal = true; break
            }
        }
        func bv(_ c: Character) -> Character { VC.toLower(VC.baseAscii(c)) }

        if count == 2 {
            if hasFinal { return last }
            let v1 = bv(text[first]), v2 = bv(text[last])
            if v1 == "o" && (v2 == "a" || v2 == "e") { return last }
            if v1 == "u" && (v2 == "e" || v2 == "y" || v2 == "o") { return last }
            if v1 == "i" && v2 == "e" { return last }
            if v1 == "u" && first > 0 && VC.toLower(text[first - 1]) == "q" { return last }
            if v1 == "i" && first > 0 && VC.toLower(text[first - 1]) == "g" { return last }
            return first
        }
        if count >= 3 {
            if hasFinal { return last }
            let v1 = bv(text[first]), v2 = bv(text[first + 1]), v3 = bv(text[last])
            if v1 == "u" && v2 == "y" && v3 == "e" { return last }
            if v1 == "i" && v2 == "u" && v3 == "o" { return last }
            return first + 1
        }
        return last
    }

    // MARK: - ShouldBypassWord

    private func shouldBypass() -> Bool {
        if raw.isEmpty { return false }
        let n = min(raw.count, 15)
        var rawLo: [Character] = []
        for i in 0..<n { rawLo.append(VC.toLower(raw[i])) }

        // Strict tone-final consonant rule
        if !text.isEmpty {
            var textLo: [Character] = []
            for c in text { textLo.append(VC.toLower(VC.stripTone(c))) }
            let lastC = textLo[textLo.count - 1]
            var endsPtkc = false
            if lastC == "c" || lastC == "p" || lastC == "t" { endsPtkc = true }
            else if textLo.count >= 2 && textLo[textLo.count - 2] == "c" && textLo[textLo.count - 1] == "h" { endsPtkc = true }
            if endsPtkc {
                if toneIndex == 1 || toneIndex == 3 || toneIndex == 4 { return true }
                if let lastKey = rawLo.last, lastKey == "f" || lastKey == "r" || lastKey == "x" { return true }
            }
        }

        if VC.hasVietMark(text[...]) { return false }

        // LEVEL 1: hard filter phụ âm đầu
        if rawLo[0] == "w" || rawLo[0] == "f" || rawLo[0] == "j" || rawLo[0] == "z" { return true }

        if n >= 2 {
            if rawLo[0] == "q" && rawLo[1] != "u" { return true }
            if rawLo[0] == "p" && rawLo[1] != "h" { return true }
            func isCons(_ c: Character) -> Bool {
                guard c >= "a" && c <= "z" else { return false }
                return c != "a" && c != "e" && c != "i" && c != "o" && c != "u" && c != "y"
            }
            if isCons(rawLo[0]) && isCons(rawLo[1]) {
                let r0 = rawLo[0], r1 = rawLo[1]
                let valid =
                    (r0 == "c" && r1 == "h") || (r0 == "g" && r1 == "h") || (r0 == "k" && r1 == "h") ||
                    (r0 == "n" && (r1 == "g" || r1 == "h")) || (r0 == "p" && r1 == "h") ||
                    (r0 == "t" && (r1 == "h" || r1 == "r")) || (r0 == "d" && r1 == "d")
                if !valid { return true }
            }
            if rawLo[0] == "c" && (rawLo[1] == "i" || rawLo[1] == "e" || rawLo[1] == "y") { return true }
            if rawLo[0] == "k" && !(rawLo[1] == "h" || rawLo[1] == "i" || rawLo[1] == "e" || rawLo[1] == "y") { return true }
            if rawLo[0] == "g" && (rawLo[1] == "e" || rawLo[1] == "y") { return true }
            if n >= 3 && rawLo[0] == "g" && rawLo[1] == "h" {
                if rawLo[2] != "i" && rawLo[2] != "e" && rawLo[2] != "y" { return true }
            }
            if n >= 3 && rawLo[0] == "n" && rawLo[1] == "g" && rawLo[2] != "h" {
                if rawLo[2] == "i" || rawLo[2] == "e" || rawLo[2] == "y" { return true }
            }
            if n >= 4 && rawLo[0] == "n" && rawLo[1] == "g" && rawLo[2] == "h" {
                if rawLo[3] != "i" && rawLo[3] != "e" && rawLo[3] != "y" { return true }
            }
        }

        // LEVEL 2: structural
        var hasVowel = false
        for c in text where VC.isVowel(c) { hasVowel = true; break }
        if hasVowel {
            var textLo: [Character] = []
            for c in text { textLo.append(VC.toLower(VC.stripTone(c))) }
            if !Self.isCompleteSyllable(textLo) { return true }
        } else {
            if text.count >= 5 { return true }
        }
        return false
    }

    // MARK: - Validators (static)

    static func isLikelyEnglish(_ t: [Character]) -> Bool {
        if t.count < 2 { return false }
        var hasVowel = false, consec = 0
        for i in 0..<t.count {
            let c = t[i]
            if c < "a" || c > "z" { return false }
            let isV = (c == "a" || c == "e" || c == "i" || c == "o" || c == "u" || c == "y")
            if isV { hasVowel = true; consec = 0 }
            else { consec += 1; if consec > 4 { return false } }
            if i < t.count - 1 && c == t[i + 1] {
                if c == "q" || c == "h" || c == "j" || c == "k" || c == "x" || c == "v" || c == "w" || c == "y" { return false }
            }
        }
        return hasVowel
    }

    private static let initials = ["ngh", "gh", "gi", "ng", "nh", "ph", "qu", "th", "tr", "ch", "kh", "đ",
                                   "b", "c", "d", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "x", ""]
    private static let nuclei = ["iêu", "yêu", "ươu", "uôi", "ươi", "oai", "oay", "uya", "uyê", "ieu", "yeu",
                                 "uoi", "uou", "oao", "oeo", "uyu", "uye",
                                 "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iê", "ie", "iu",
                                 "oa", "oai", "oă", "oe", "oi", "oo", "ôi", "ơi",
                                 "ua", "uâ", "uê", "ui", "uô", "uy", "uo", "ue", "uơ",
                                 "ưa", "ưi", "ưu", "ươ", "ya", "yê", "ye",
                                 "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y"]
    private static let finals = ["ng", "nh", "ch", "c", "m", "n", "p", "t", ""]

    /// Bán nguyên âm cuối (-i/-y/-o/-u) chỉ hợp lệ sau một số nguyên âm nhất định.
    /// Vd: "ai/ao/au/ay" hợp lệ, nhưng "io" (kiro), "eu", "ôu"… thì không -> để
    /// chuỗi như "kiro" rơi về khôi phục tiếng Anh thay vì nhận dấu thành "kỉo".
    private static func isValidOffGlide(_ lastVowel: Character, _ glide: Character) -> Bool {
        switch glide {
        case "i": return "aoôơuư".contains(lastVowel)   // ai, oi, ôi, ơi, ui, ưi, oai, uôi, ươi
        case "y": return lastVowel == "a" || lastVowel == "â"  // ay, ây, oay, uây
        case "o": return lastVowel == "a" || lastVowel == "e"  // ao, eo
        case "u": return "aâêiươ".contains(lastVowel)   // au, âu, êu, iu, ưu, iêu, yêu, ươu
        default: return false
        }
    }

    /// Nhân được phép có phụ âm cuối. Nhân khép (ưi, ui, ai, ơi, ưu, ươu, uôi…) thì không.
    private static let nucleiOpenToFinal: Set<String> = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y", "oo",
        "iê", "ie", "yê", "ye", "uô", "uo", "ươ", "uâ",
        "oa", "oă", "oe", "uê", "ue", "uy", "uyê", "uye",
    ]

    static func isCompleteSyllable(_ s: [Character]) -> Bool {
        if s.isEmpty || s.count > 20 { return false }
        var pos = 0
        let end = s.count
        func match(_ p: String) -> Bool {
            let pc = Array(p)
            if pos + pc.count > end { return false }
            for i in 0..<pc.count where s[pos + i] != pc[i] { return false }
            return true
        }
        var matchedInitial: String? = nil
        for ini in initials {
            if ini.isEmpty { matchedInitial = ""; break }
            if match(ini) { pos += ini.count; matchedInitial = ini; break }
        }
        // gi đặc biệt: nếu phần còn lại không bắt đầu bằng nguyên âm -> 'i' là nhân
        if let mi = matchedInitial, mi == "gi" {
            if pos == end || !VC.isVowel(VC.stripTone(s[pos])) { pos -= 1 }
        }
        if matchedInitial == nil { return false }

        var matchedNucleus: String? = nil
        for nu in nuclei where match(nu) { pos += nu.count; matchedNucleus = nu; break }
        guard let nucleus = matchedNucleus else { return false }

        var matchedFinal: String? = nil
        for f in finals {
            if f.isEmpty { matchedFinal = ""; break }
            if match(f) { pos += f.count; matchedFinal = f; break }
        }

        if let f = matchedFinal, !f.isEmpty {
            // Nhân khép (đôi/ba kết thúc bằng bán nguyên âm) không nhận phụ âm cuối.
            if !Self.nucleiOpenToFinal.contains(nucleus) { return false }
            if f == "nh" || f == "ch" {
                let ok = ["a", "i", "ê", "y", "oa", "uy", "uê"].contains(nucleus)
                if !ok { return false }
            }
            if f == "ng" || f == "c" {
                if ["i", "ê", "y"].contains(nucleus) { return false }
            }
        }

        if matchedFinal == nil || matchedFinal!.isEmpty {
            // Bán nguyên âm cuối: chỉ nhận 1 ký tự glide hợp lệ với nguyên âm trước đó.
            if pos < end, pos > 0, Self.isValidOffGlide(s[pos - 1], s[pos]) {
                pos += 1
            }
        }
        return pos == end
    }
}
