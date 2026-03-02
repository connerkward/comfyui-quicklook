import AppKit
import WebKit

// Global strong reference so the delegate isn't released while app.run() blocks
private var _appDelegate: AppDelegate?

@main
struct ComfyQL {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        _appDelegate = AppDelegate()
        app.delegate = _appDelegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [ViewerWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Handle direct CLI invocation: ComfyQL /path/to/file.png
        if CommandLine.arguments.count > 1 {
            let url = URL(fileURLWithPath: CommandLine.arguments[1])
            openFile(url: url)
            if windows.isEmpty { NSApp.terminate(nil) }
        }
    }

    // Called by Finder "Open With" and drag-to-dock-icon
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { openFile(url: url) }
        if windows.isEmpty { NSApp.terminate(nil) }
    }

    func openFile(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let chunks = PNGChunkReader.readTextChunks(from: data) else {
            // Not a ComfyUI PNG — pass to system default (Preview.app)
            NSWorkspace.shared.open(url)
            return
        }
        let html = HTMLRenderer.generateHTML(imageData: data, chunks: chunks)
        let wc = ViewerWindowController(html: html, title: url.lastPathComponent)
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        windows.append(wc)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

class ViewerWindowController: NSWindowController {
    init(html: Data, title: String) {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1400, height: 900))
        webView.autoresizingMask = [.width, .height]
        let vc = NSViewController()
        vc.view = webView
        let w = NSWindow(contentViewController: vc)
        w.title = title
        w.setContentSize(NSSize(width: 1400, height: 900))
        w.center()
        w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        super.init(window: w)
        webView.loadHTMLString(String(data: html, encoding: .utf8) ?? "", baseURL: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
}
