import AppKit
import WebKit
import UniformTypeIdentifiers
import ImageIO

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
        if let del = NSApp.delegate as? AppDelegate {
            del.openURLPublic(url)
            del.window?.makeKeyAndOrderFront(nil)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var window: NSWindow?
    var webView: WKWebView?
    /// File to open once the window exists (e.g. when opened via "Open With" before launch finished)
    private var pendingURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appDbg("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        setupMainMenu()
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

        // Handle CLI argument (drag-to-app or shell usage) or pending "Open With" file
        if let url = pendingURL {
            pendingURL = nil
            openURLPublic(url)
        } else if CommandLine.arguments.count > 1 {
            openURLPublic(URL(fileURLWithPath: CommandLine.arguments[1]))
        } else {
            showWelcome()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Handle "Open With" from Finder (file may be delivered here instead of via document)
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        appDbg("application(openFile:) \(filename)")
        let url = URL(fileURLWithPath: filename)
        if window != nil {
            openURLPublic(url)
            window?.makeKeyAndOrderFront(nil)
        } else {
            pendingURL = url
        }
        return true
    }

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

    // MARK: - Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About ComfyQL", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide ComfyQL", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ComfyQL", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
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
            let parseResult = TIFFReader.extractXMPParseResult(from: data) ?? XMPParseResult(comfy: nil, allEntries: [])
            let layerInfos = TIFFReader.extractPerLayerMetadata(from: data)
            let xmpLayerNames: [String] = parseResult.comfy?.layers.map { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } } ?? []
            let tagPageNames = layerInfos.compactMap(\.pageName)
            let layerNames = xmpLayerNames.isEmpty ? tagPageNames : xmpLayerNames
            html = HTMLRenderer.generateTIFFHTML(pages: pages, layerNames: layerNames, parseResult: parseResult, totalFileSize: data.count, layerInfos: layerInfos)
        } else if ext == "webp" {
            let parseResult = WebPReader.extractXMPParseResult(from: data) ?? XMPParseResult(comfy: nil, allEntries: [])
            let imageInfo = Self.imageLayerInfo(from: data)
            html = HTMLRenderer.generateHTML(imageData: data, chunks: [:], xmp: parseResult.comfy, allXMPEntries: parseResult.allEntries, totalFileSize: data.count, imageLayerInfo: imageInfo, imageMIME: "image/webp")
        } else {
            guard let chunks = PNGChunkReader.readTextChunks(from: data) else {
                showImageFallback(data: data, mime: "image/png"); return
            }
            let xmpString = chunks["XML:com.adobe.xmp"]
            let parseResult = xmpString.map { XMPParser.parseFull(string: $0) } ?? XMPParseResult(comfy: nil, allEntries: [])
            let xmp = parseResult.comfy
            let imageInfo = PNGChunkReader.dimensions(from: data).map { LayerFileInfo(width: $0.width, height: $0.height, byteSize: 0, compression: "Deflate") }
            html = HTMLRenderer.generateHTML(imageData: data, chunks: chunks, xmp: xmp, allXMPEntries: parseResult.allEntries, totalFileSize: data.count, imageLayerInfo: imageInfo)
        }

        webView?.loadHTMLString(String(data: html, encoding: .utf8) ?? "", baseURL: nil)
    }

    /// Single-image dimensions for WebP (or any ImageIO-supported format) for File & layers row.
    private static func imageLayerInfo(from data: Data) -> LayerFileInfo? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(src) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return LayerFileInfo(width: cgImage.width, height: cgImage.height, byteSize: 0, compression: "VP8")
    }

    private func showImageFallback(data: Data, mime: String) {
        let b64 = data.base64EncodedString()
        showHTML("""
            <style>
            *{box-sizing:border-box;margin:0;padding:0}
            html,body{width:100%;max-width:100%;height:100vh;overflow:hidden}
            body{font-family:-apple-system,sans-serif;display:flex;background:#1c1c1e;color:#f2f2f7}
            .img-pane{flex:1;min-width:0;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#000}
            .img-pane img{max-width:100%;max-height:100%;object-fit:contain}
            .panel{flex:0 0 340px;min-width:340px;background:#2c2c2e;border-left:1px solid #3a3a3c;padding:20px;overflow-y:auto}
            .panel p{color:#8e8e93;font-size:13px;line-height:1.5}
            </style>
            <div class="img-pane"><img src='data:\(mime);base64,\(b64)'></div>
            <div class="panel">
              <p><strong>No ComfyUI metadata</strong></p>
              <p style="margin-top:12px">This image has no embedded workflow, prompt, or XMP. Use ComfyUI's Save (e.g. Save Image) to embed metadata.</p>
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
