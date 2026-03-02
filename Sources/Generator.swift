import Foundation
import QuickLook

private let logPath = "/tmp/comfyql_debug.log"
private func dbg(_ msg: String) {
    let line = "\(Date()): \(msg)\n"
    if let data = line.data(using: .utf8),
       let fh = FileHandle(forWritingAtPath: logPath) {
        fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
    } else {
        try? line.data(using: .utf8)?.write(to: URL(fileURLWithPath: logPath))
    }
}

@_cdecl("GeneratePreviewForURL")
public func GeneratePreviewForURL(
    _ thisInterface: UnsafeRawPointer,
    _ preview: QLPreviewRequest,
    _ url: CFURL,
    _ uti: CFString,
    _ options: CFDictionary
) -> OSStatus {
    let fileURL = url as URL
    dbg("GeneratePreviewForURL called: \(fileURL.lastPathComponent)")

    guard let data = try? Data(contentsOf: fileURL) else {
        dbg("failed to read file")
        return OSStatus(unimpErr)
    }

    let html: Data
    let ext = fileURL.pathExtension.lowercased()

    if ext == "tiff" || ext == "tif" {
        guard let xmp = TIFFReader.extractXMP(from: data) else {
            dbg("no ComfyUI XMP in TIFF → unimpErr")
            return OSStatus(unimpErr)
        }
        let pages = TIFFReader.extractAllPagesPNG(from: data)
        guard !pages.isEmpty else {
            dbg("TIFF page extraction failed → unimpErr")
            return OSStatus(unimpErr)
        }
        dbg("TIFF \(pages.count) pages found, generating HTML")
        let layerNames = xmp.layers.map { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } } ?? []
        html = HTMLRenderer.generateTIFFHTML(pages: pages, layerNames: layerNames, xmp: xmp)
    } else if ext == "webp" {
        guard let xmp = WebPReader.extractXMP(from: data) else {
            dbg("no XMP in WebP → unimpErr (fallback to native)")
            return OSStatus(unimpErr)
        }
        dbg("WebP XMP found, generating HTML")
        html = HTMLRenderer.generateHTML(imageData: data, chunks: [:], xmp: xmp, imageMIME: "image/webp")
    } else {
        guard let chunks = PNGChunkReader.readTextChunks(from: data) else {
            dbg("no workflow chunks → unimpErr (fallback to native)")
            return OSStatus(unimpErr)
        }
        dbg("PNG chunks found, generating HTML")
        let xmp = chunks["XML:com.adobe.xmp"].flatMap { XMPParser.parse(string: $0) }
        html = HTMLRenderer.generateHTML(imageData: data, chunks: chunks, xmp: xmp)
    }
    let props: [CFString: Any] = [
        kQLPreviewPropertyTextEncodingNameKey: "UTF-8" as CFString,
        kQLPreviewPropertyMIMETypeKey: "text/html" as CFString
    ]
    QLPreviewRequestSetDataRepresentation(preview, html as CFData, kUTTypeHTML, props as CFDictionary)
    dbg("HTML preview set OK")
    return noErr
}

@_cdecl("GenerateThumbnailForURL")
public func GenerateThumbnailForURL(
    _ thisInterface: UnsafeRawPointer,
    _ thumbnail: QLThumbnailRequest,
    _ url: CFURL,
    _ uti: CFString,
    _ options: CFDictionary,
    _ maxSize: CGSize
) -> OSStatus {
    return OSStatus(unimpErr)
}
