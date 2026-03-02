import AppKit
import WebKit
import UniformTypeIdentifiers

private func appDbg(_ msg: String) {
    let line = "\(Date()): \(msg)\n"
    if let data = line.data(using: .utf8) {
        if let fh = FileHandle(forWritingAtPath: "/tmp/comfyql_app.log") {
            fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
        } else {
            try? data.write(to: URL(fileURLWithPath: "/tmp/comfyql_app.log"))
        }
    }
    NSLog("ComfyQL: %@", msg)
}

// @objc name must match NSDocumentClass in Info.plist exactly
@objc(ImageDocument)
class ImageDocument: NSDocument {
    override func read(from data: Data, ofType typeName: String) throws {}
    override func makeWindowControllers() {
        appDbg("makeWindowControllers called for \(fileURL?.lastPathComponent ?? "nil")")
        guard let url = fileURL else { return }
        (NSApp.delegate as? AppDelegate)?.openURLPublic(url)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var window: NSWindow?
    var webView: WKWebView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appDbg("applicationDidFinishLaunching")
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "tiffTool"
        win.center()
        win.setFrameAutosaveName("ComfyQLMain")

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "comfydownload")
        let wv = WKWebView(frame: win.contentView!.bounds, configuration: cfg)
        wv.autoresizingMask = [.width, .height]
        win.contentView!.addSubview(wv)
        win.makeKeyAndOrderFront(nil)
        self.window = win
        self.webView = wv
        appDbg("window created and shown, args=\(CommandLine.arguments.count)")

        // Handle CLI argument (drag-to-app or shell usage)
        if CommandLine.arguments.count > 1 {
            openURLPublic(URL(fileURLWithPath: CommandLine.arguments[1]))
        } else {
            showWelcome()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "comfydownload", let json = message.body as? String else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "workflow.json"
        panel.allowedContentTypes = [UTType.json]
        panel.beginSheetModal(for: window!) { response in
            guard response == .OK, let url = panel.url else { return }
            try? json.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Core

    func openURLPublic(_ url: URL) {
        window?.title = url.lastPathComponent
        guard let data = try? Data(contentsOf: url) else {
            showHTML("<p style='color:#c00'>Could not read file.</p>"); return
        }

        let ext = url.pathExtension.lowercased()
        let html: Data

        if ext == "tiff" || ext == "tif" {
            let pages = TIFFReader.extractAllPagesPNG(from: data)
            guard !pages.isEmpty else {
                showHTML("<p style='color:#c00'>Could not render TIFF preview.</p>"); return
            }
            guard let xmp = TIFFReader.extractXMP(from: data) else {
                showImageFallback(data: pages[0], mime: "image/png"); return
            }
            let layerNames = xmp.layers.map { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } } ?? []
            html = HTMLRenderer.generateTIFFHTML(pages: pages, layerNames: layerNames, xmp: xmp)
        } else if ext == "webp" {
            guard let xmp = WebPReader.extractXMP(from: data) else {
                showImageFallback(data: data, mime: "image/webp"); return
            }
            html = HTMLRenderer.generateHTML(imageData: data, chunks: [:], xmp: xmp, imageMIME: "image/webp")
        } else {
            guard let chunks = PNGChunkReader.readTextChunks(from: data) else {
                showImageFallback(data: data, mime: "image/png"); return
            }
            let xmp = chunks["XML:com.adobe.xmp"].flatMap { XMPParser.parse(string: $0) }
            html = HTMLRenderer.generateHTML(imageData: data, chunks: chunks, xmp: xmp)
        }

        webView?.loadHTMLString(String(data: html, encoding: .utf8) ?? "", baseURL: nil)
    }

    private func showImageFallback(data: Data, mime: String) {
        let b64 = data.base64EncodedString()
        showHTML("""
            <div style='display:flex;align-items:center;justify-content:center;
                        height:100vh;background:#111'>
              <img src='data:\(mime);base64,\(b64)'
                   style='max-width:100%;max-height:100vh;object-fit:contain'>
            </div>
            """)
    }

    private func showWelcome() {
        showHTML("""
            <div style='font-family:system-ui;padding:60px;color:#555;max-width:600px;margin:0 auto'>
              <h2 style='color:#222'>tiffTool</h2>
              <p>Drag a ComfyUI PNG, WebP, or TIFF file here, or use
                 <strong>Finder → right-click → Open With → tiffTool</strong>.</p>
              <p style='color:#999;font-size:13px'>
                Files without ComfyUI workflow metadata are shown as plain images.</p>
            </div>
            """)
    }

    private func showHTML(_ body: String) {
        let page = """
            <!DOCTYPE html><html><body style='margin:0;font-family:system-ui'>
            \(body)
            </body></html>
            """
        webView?.loadHTMLString(page, baseURL: nil)
    }
}
