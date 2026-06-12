import ServiceManagement
import Foundation

/// Đăng ký mở cùng OS (một lần). Dùng SMAppService (macOS 13+).
enum LoginItem {
    private static let key = "govi.loginRegistered"

    static func enableOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            defaults.set(true, forKey: key)
        } catch {
            NSLog("Govi: đăng ký login item thất bại: \(error)")
        }
    }
}
