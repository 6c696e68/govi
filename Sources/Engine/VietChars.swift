import Foundation

// Tiện ích ký tự tiếng Việt, dựng/bóc dấu bằng NFD/NFC (khớp NFC chuẩn).
enum VC {
    static let toneComb: [Int: Unicode.Scalar] = [
        1: "\u{0300}", 2: "\u{0301}", 3: "\u{0309}", 4: "\u{0303}", 5: "\u{0323}",
    ]
    static let toneSet: Set<UInt32> = [0x300, 0x301, 0x309, 0x303, 0x323]

    static func isAlpha(_ c: Character) -> Bool {
        guard let a = c.asciiValue else { return false }
        return (a >= 97 && a <= 122) || (a >= 65 && a <= 90)
    }

    static func baseAscii(_ c: Character) -> Character {
        if c == "đ" { return "d" }
        if c == "Đ" { return "D" }
        let up = c.isUppercase
        for s in String(c).decomposedStringWithCanonicalMapping.unicodeScalars {
            let v = s.value
            if (v >= 97 && v <= 122) || (v >= 65 && v <= 90) {
                let lower = Unicode.Scalar(v | 0x20)!
                return up ? Character(String(Character(lower)).uppercased()) : Character(lower)
            }
        }
        return c
    }

    static func stripTone(_ c: Character) -> Character {
        let nfd = String(c).decomposedStringWithCanonicalMapping
        var out = String.UnicodeScalarView()
        for s in nfd.unicodeScalars where !toneSet.contains(s.value) { out.append(s) }
        return String(out).precomposedStringWithCanonicalMapping.first ?? c
    }

    static func toneOf(_ c: Character) -> Int {
        for s in String(c).decomposedStringWithCanonicalMapping.unicodeScalars {
            switch s.value {
            case 0x300: return 1
            case 0x301: return 2
            case 0x309: return 3
            case 0x303: return 4
            case 0x323: return 5
            default: break
            }
        }
        return 0
    }

    static func toneMark(_ base: Character, _ tone: Int) -> Character? {
        let plain = baseAscii(base)
        if !isVowelBase(plain) { return nil }
        if tone == 0 { return base }
        var sv = String.UnicodeScalarView()
        for s in String(base).decomposedStringWithCanonicalMapping.unicodeScalars where !toneSet.contains(s.value) {
            sv.append(s)
        }
        sv.append(toneComb[tone]!)
        return String(sv).precomposedStringWithCanonicalMapping.first
    }

    static func isVowelBase(_ c: Character) -> Bool {
        switch c { case "a", "e", "i", "o", "u", "y", "A", "E", "I", "O", "U", "Y": return true; default: return false }
    }

    static func isVowel(_ c: Character) -> Bool { isVowelBase(baseAscii(c)) }

    static func hookRule(_ c: Character) -> Character? {
        switch c {
        case "a", "â": return "ă"
        case "A", "Â": return "Ă"
        case "o": return "ơ"
        case "O": return "Ơ"
        case "u": return "ư"
        case "U": return "Ư"
        default: return nil
        }
    }

    static func toneIndex(_ key: Character) -> Int {
        switch key {
        case "z", "Z": return 0
        case "f", "F": return 1
        case "s", "S": return 2
        case "r", "R": return 3
        case "x", "X": return 4
        case "j", "J": return 5
        default: return -1
        }
    }

    static func stripToneAndAccent(_ c: Character) -> Character {
        if c == "đ" { return "d" }
        if c == "Đ" { return "D" }
        return baseAscii(c)
    }

    static func hasVietMark(_ text: ArraySlice<Character>) -> Bool {
        for c in text where stripToneAndAccent(c) != c { return true }
        return false
    }

    static func toLower(_ c: Character) -> Character { Character(c.lowercased()) }
}
