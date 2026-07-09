import Cocoa
import WebKit

let FULL = NSSize(width: 420, height: 600)
let PET  = NSSize(width: 170, height: 170)

// 自定义 scheme 处理器：把 app://app/xxx 映射到 App 包内的 Resources 文件。
// 用自定义 scheme 而非 file://，是为了让 WKWebView 拥有“真实源”，
// 但注意：自定义源的 localStorage 在 WKWebView 下不可靠（不透明源会抛 SecurityError / 不持久化），
// 因此数据持久化改用原生桥接（load/save → Application Support 下的文件）。
final class FileSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "quickboard", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "bad url"]))
            return
        }
        let resDir = Bundle.main.resourceURL!
        let fileURL = resDir.appendingPathComponent(url.path)
        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(NSError(domain: "quickboard", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "not found: \(url.path)"]))
            return
        }
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mimeType(for: fileURL.pathExtension),
                           "Content-Length": "\(data.count)"])!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "js", "mjs":   return "application/javascript"
        case "json":        return "application/json"
        case "css":         return "text/css"
        case "png":         return "image/png"
        case "svg":         return "image/svg+xml"
        default:            return "application/octet-stream"
        }
    }
}

// 渲染进程通过 window.webkit.messageHandlers.<name>.postMessage(...) 调用这里
final class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var app: AppDelegate?
    init(app: AppDelegate) { self.app = app }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        app?.handleMessage(message)
    }
}

// 无边框窗口默认 canBecomeKey 返回 false，导致窗口永远成不了 key window，
// WKWebView 里的文本框（搜索框、新建弹窗等）收不到键盘事件、无法输入。
// 子类强制返回 true，键盘输入才能正常到达网页。
final class QuickBoardWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: QuickBoardWindow!
    var webView: WKWebView!

    // ----- 拖拽状态（原生驱动，杜绝抖动）-----
    var dragging = false
    var grabOffset = NSPoint.zero          // 窗口原点相对光标的偏移
    var dragMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        let handler = ScriptMessageHandler(app: self)
        for name in ["copy", "min", "max", "close", "dragStart", "dragEnd", "load", "save", "export"] {
            userContent.add(handler, name: name)
        }
        config.userContentController = userContent
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.setURLSchemeHandler(FileSchemeHandler(), forURLScheme: "app")

        webView = WKWebView(frame: NSRect(origin: .zero, size: FULL), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")   // 透明背景
        webView.navigationDelegate = self

        window = QuickBoardWindow(contentRect: NSRect(origin: .zero, size: FULL),
                                  styleMask: [.borderless],
                                  backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovable = false                 // 由我们的原生监听器接管拖动
        window.level = .floating                 // 置顶（alwaysOnTop）
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)

        // 兜底：鼠标松开时无论如何结束拖拽（即使网页侧没收到 mouseup）
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] ev in
            if self?.dragging == true { self?.stopDrag() }
            return ev
        }

        if let url = URL(string: "app://app/index.html") {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - 来自网页的桥接调用
    func handleMessage(_ message: WKScriptMessage) {
        switch message.name {
        case "copy":
            if let text = message.body as? String {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
            }
        case "export":
            if let json = message.body as? String {
                let fm = FileManager.default
                if let dl = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                    // 加时间戳，避免多次导出相互覆盖
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyyMMdd-HHmmss"
                    let ts = fmt.string(from: Date())
                    let file = dl.appendingPathComponent("snippets-\(ts).json")
                    try? json.write(to: file, atomically: true, encoding: .utf8)
                }
            }
        case "min":  resize(to: PET)    // 缩小成桌面宠物（雪人）
        case "max":  resize(to: FULL)   // 恢复完整窗口
        case "close": NSApplication.shared.terminate(nil)
        case "dragStart": startDrag()
        case "dragEnd":  stopDrag()
        case "load":
            // 网页请求读取数据 → 原生读文件后回调用 evaluateJavaScript
            guard let key = message.body as? String else { break }
            let raw = readStorage(key: key)
            let arg = raw == nil ? "null" : jsString(raw!)
            let js = "window.__qbLoad(\(jsString(key)), \(arg))"
            webView.evaluateJavaScript(js, completionHandler: nil)
        case "save":
            guard let o = message.body as? [String: Any],
                  let key = o["k"] as? String,
                  let val = o["v"] as? String else { break }
            writeStorage(key: key, value: val)
        default:
            break
        }
    }

    // MARK: - 原生鼠标拖拽（无桥接往返，GPU 合成，丝滑不抖）
    func startDrag() {
        dragging = true
        let m = NSEvent.mouseLocation                  // 全局光标（屏幕坐标，原点左下）
        let o = window.frame.origin
        grabOffset = NSPoint(x: o.x - m.x, y: o.y - m.y)
        if dragMonitor == nil {
            dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] ev in
                guard let self = self, self.dragging, let w = self.window else { return ev }
                let loc = NSEvent.mouseLocation
                w.setFrameOrigin(NSPoint(x: loc.x + self.grabOffset.x,
                                         y: loc.y + self.grabOffset.y))
                return ev
            }
        }
    }

    func stopDrag() {
        dragging = false
        if let m = dragMonitor { NSEvent.removeMonitor(m); dragMonitor = nil }
    }

    // 居中缩放，避免漂移（与原 Electron 版行为一致）
    func resize(to size: NSSize) {
        var f = window.frame
        let cx = f.midX, cy = f.midY
        f.size = size
        f.origin.x = cx - size.width / 2
        f.origin.y = cy - size.height / 2
        window.setFrame(f, display: true, animate: false)
    }

    // MARK: - 原生持久化（替代不可靠的 localStorage）
    func storageURL(for key: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("QuickBoard", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let file = key == "sn" ? "snippets.json" : (key == "th" ? "theme.txt" : "\(key).dat")
        return base.appendingPathComponent(file)
    }

    func writeStorage(key: String, value: String) {
        try? value.write(to: storageURL(for: key), atomically: true, encoding: .utf8)
    }

    func readStorage(key: String) -> String? {
        let url = storageURL(for: key)
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return s
    }

    /// 把 Swift String 转成合法的 JS 字符串字面量（手写转义，避免 NSJSONSerialization 只能序列化数组/字典的限制）
    func jsString(_ s: String) -> String {
        var out = "\""
        for ch in s {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                let v = ch.unicodeScalars.first!.value
                if v < 0x20 { out += String(format: "\\u%04x", v) }
                else { out.append(ch) }
            }
        }
        out += "\""
        return out
    }
}

extension AppDelegate: WKNavigationDelegate {}

// 入口
let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)   // 无 Dock 图标、无菜单栏，像桌面小组件
app.delegate = delegate
app.run()
