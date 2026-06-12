import CoreGraphics
import AppKit
import ApplicationServices

typealias Delays = (bs: UInt32, mid: UInt32, text: UInt32)

enum Method { case fast, slow, charByChar, selection, axDirect, emptyCharPrefix, syncProxy, passthrough }

/// Chọn cách inject theo app/role đang focus + cache để tránh query AX mỗi phím.
final class Injector {
    private var cachedMethod: Method = .fast
    private var cachedDelays: Delays = (1000, 3000, 1500)
    private var cacheStamp: CFAbsoluteTime = 0
    private let ttl: CFAbsoluteTime = 0.2

    func invalidate() { cacheStamp = 0 }

    var isPassthrough: Bool { cachedMethod == .passthrough }

    /// Phát hiện (có cache). Gọi đầu mỗi keyDown.
    func refresh() {
        let now = CFAbsoluteTimeGetCurrent()
        if now - cacheStamp < ttl { return }
        let (m, d) = Self.detect()
        cachedMethod = m; cachedDelays = d; cacheStamp = now
    }

    func inject(delete: Int, insert: String, proxy: CGEventTapProxy) {
        switch cachedMethod {
        case .axDirect:        Strategies.axDirect(delete, insert, proxy)
        case .selection:       Strategies.selection(delete, insert, cachedDelays)
        case .emptyCharPrefix: Strategies.backspace(delete, insert, cachedDelays, charByChar: false, emptyPrefix: true)
        case .charByChar:      Strategies.backspace(delete, insert, cachedDelays, charByChar: true, emptyPrefix: false)
        case .syncProxy:       Strategies.proxy(delete, insert, proxy)
        case .slow, .fast:     Strategies.backspace(delete, insert, cachedDelays, charByChar: false, emptyPrefix: false)
        case .passthrough:     break
        }
        usleep(cachedMethod == .slow ? 20000 : 5000)
    }

    // MARK: - Phát hiện app/role

    private static func detect() -> (Method, Delays) {
        let sys = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(sys, 0.1)

        var role: String?
        var bundleId: String?
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let el = focused {
            let element = el as! AXUIElement
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success {
                role = roleRef as? String
            }
            var pid: pid_t = 0
            if AXUIElementGetPid(element, &pid) == .success {
                bundleId = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            }
        }
        if bundleId == nil { bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
        guard let id = bundleId else { return (.fast, (1000, 3000, 1500)) }
        return classify(bundleId: id, role: role)
    }

    private static let passthroughApps: Set<String> = [
        "com.apple.ScreenContinuity", "com.carriez.rustdesk",
        "com.philandro.anydesk", "com.teamviewer.TeamViewer",
    ]
    private static let browsers: Set<String> = [
        "company.thebrowser.Browser", "company.thebrowser.Arc", "company.thebrowser.dia",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly",
        "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta",
        "org.chromium.Chromium", "com.brave.Browser", "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
        "com.duckduckgo.macos.browser", "ai.perplexity.comet", "com.openai.atlas",
        "app.zen-browser.zen", "com.kagi.kagimacOS",
    ]
    private static let slowApps: Set<String> = [
        "com.microsoft.Excel", "com.microsoft.Word", "notion.id",
        "com.microsoft.VSCode", "com.todesktop.cursor", "com.visualstudio.code.oss",
        "dev.warp.Warp-Stable", "com.mitchellh.ghostty", "net.kovidgoyal.kitty",
        "com.apple.Terminal", "com.googlecode.iterm2", "io.alacritty",
        "com.github.wez.wezterm", "dev.zed.Zed", "com.sublimetext.4",
    ]

    private static func classify(bundleId: String, role: String?) -> (Method, Delays) {
        if passthroughApps.contains(bundleId) { return (.passthrough, (0, 0, 0)) }
        if role == "AXComboBox" || role == "AXSearchField" { return (.selection, (0, 0, 0)) }
        if bundleId == "com.apple.Spotlight" || bundleId == "com.apple.systemuiserver" {
            return (.axDirect, (0, 0, 0))
        }
        if bundleId == "com.apple.Safari" {
            return role == "AXTextField"
                ? (.emptyCharPrefix, (3000, 8000, 3000))
                : (.charByChar, (3000, 8000, 3000))
        }
        if browsers.contains(bundleId) { return (.emptyCharPrefix, (3000, 8000, 3000)) }
        if slowApps.contains(bundleId) || bundleId.hasPrefix("com.jetbrains") {
            return (.slow, (8000, 20000, 8000))
        }
        if bundleId.hasPrefix("com.riotgames") { return (.syncProxy, (0, 0, 0)) }
        return (.fast, (1000, 3000, 1500))
    }
}
