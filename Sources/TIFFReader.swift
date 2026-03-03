import Foundation
import ImageIO

/// Per-layer (per-IFD) file metadata for the ComfyUI tab.
struct LayerFileInfo {
    var width: Int
    var height: Int
    var byteSize: Int
    var compression: String
    var pageName: String?
    var aspectRatio: String { formatAspectRatio(width: width, height: height) }
}

private func formatAspectRatio(width: Int, height: Int) -> String {
    guard height > 0 else { return "—" }
    let g = gcd(width, height)
    let w = width / g, h = height / g
    if w == h { return "1:1" }
    return "\(w):\(h)"
}
private func gcd(_ a: Int, _ b: Int) -> Int {
    var a = abs(a), b = abs(b)
    while b != 0 { (a, b) = (b, a % b) }
    return a
}

enum TIFFReader {

    static func extractXMP(from data: Data) -> ComfyXMP? {
        extractXMPParseResult(from: data)?.comfy
    }

    /// Full XMP parse for ComfyUI tab + All XMP tab. Returns nil only when the file has no XMP (tag 700).
    static func extractXMPParseResult(from data: Data) -> XMPParseResult? {
        guard let xmpData = extractXMPData(from: data) else { return nil }
        return XMPParser.parseFull(data: xmpData)
    }

    /// Per-IFD metadata: width, height, byte size (strip bytes), compression. For ComfyUI tab layer table.
    static func extractPerLayerMetadata(from data: Data) -> [LayerFileInfo] {
        guard data.count > 8 else { return [] }
        let isLE = data[0] == 0x49 && data[1] == 0x49
        guard isLE || (data[0] == 0x4D && data[1] == 0x4D) else { return [] }
        func u16(_ i: Int) -> Int {
            guard i + 1 < data.count else { return 0 }
            return isLE ? Int(data[i]) | (Int(data[i+1]) << 8) : (Int(data[i]) << 8) | Int(data[i+1])
        }
        func u32(_ i: Int) -> Int {
            guard i + 3 < data.count else { return 0 }
            return isLE ? Int(data[i])|(Int(data[i+1])<<8)|(Int(data[i+2])<<16)|(Int(data[i+3])<<24)
                : (Int(data[i])<<24)|(Int(data[i+1])<<16)|(Int(data[i+2])<<8)|Int(data[i+3])
        }
        guard u16(2) == 42 else { return [] }
        var results: [LayerFileInfo] = []
        var ifdOffset = u32(4)
        while ifdOffset > 0 && ifdOffset + 2 <= data.count {
            let n = u16(ifdOffset)
            var width = 0, height = 0, compressionCode = 1, stripByteSum = 0, pageName: String? = nil
            var pos = ifdOffset + 2
            for _ in 0..<n {
                guard pos + 12 <= data.count else { break }
                let tag = u16(pos)
                let type_ = u16(pos + 2)
                let count = u32(pos + 4)
                let typeSize = [2:1, 3:2, 4:4, 5:8, 6:1, 7:1, 8:2, 9:4, 10:8, 11:4, 12:8][type_] ?? 1
                let total = Int(count) * typeSize
                let inlineVal = total <= 4
                let off = inlineVal ? pos + 8 : u32(pos + 8)
                switch tag {
                case 256: width = (type_ == 3 && inlineVal) ? u16(off) : u32(off)
                case 257: height = (type_ == 3 && inlineVal) ? u16(off) : u32(off)
                case 259: compressionCode = (type_ == 3) ? u16(off) : (inlineVal ? u32(off) : (off + 3 < data.count ? u32(off) : 1))
                case 279:
                    if inlineVal { stripByteSum = Int(u32(off)) }
                    else { for i in 0..<Int(count) where off + i * 4 + 3 < data.count { stripByteSum += u32(off + i * 4) } }
                case 285:
                    let strOff = total <= 4 ? off : off
                    let end = min(strOff + total, data.count)
                    if let s = String(data: data[strOff..<end], encoding: .ascii) {
                        pageName = s.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                    }
                default: break
                }
                pos += 12
            }
            let compName: String = {
                switch compressionCode {
                case 1: return "None"
                case 2: return "CCITT RLE"
                case 3: return "CCITT Fax3"
                case 4: return "CCITT Fax4"
                case 5: return "LZW"
                case 6: return "JPEG (old)"
                case 7: return "JPEG"
                case 8, 32946: return "Deflate"
                case 32773: return "PackBits"
                case 34712: return "JPEG 2000"
                case 34925: return "LZMA"
                case 50000: return "ZSTD"
                case 50001: return "WebP"
                default: return "Codec \(compressionCode)"
                }
            }()
            results.append(LayerFileInfo(width: width, height: height, byteSize: stripByteSum, compression: compName, pageName: pageName))
            ifdOffset = (pos + 4 <= data.count) ? u32(pos) : 0
        }
        return results
    }

    // Returns PNG data for each IFD page.
    static func extractAllPagesPNG(from data: Data) -> [Data] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return [] }
        let count = CGImageSourceGetCount(source)
        var pages: [Data] = []
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let out = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(out, "public.png" as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, cgImage, nil)
            guard CGImageDestinationFinalize(dest) else { continue }
            pages.append(out as Data)
        }
        return pages
    }

    static func extractPreviewPNG(from data: Data) -> Data? {
        extractAllPagesPNG(from: data).first
    }

    // Parses TIFF IFD for tag 700 (XMP) in either endianness.
    private static func extractXMPData(from data: Data) -> Data? {
        guard data.count > 8 else { return nil }
        let isLE = data[0] == 0x49 && data[1] == 0x49
        guard isLE || (data[0] == 0x4D && data[1] == 0x4D) else { return nil }

        func u16(_ i: Int) -> Int {
            guard i + 1 < data.count else { return 0 }
            return isLE ? Int(data[i]) | (Int(data[i+1]) << 8)
                        : (Int(data[i]) << 8) | Int(data[i+1])
        }
        func u32(_ i: Int) -> Int {
            guard i + 3 < data.count else { return 0 }
            return isLE ? Int(data[i])|(Int(data[i+1])<<8)|(Int(data[i+2])<<16)|(Int(data[i+3])<<24)
                        : (Int(data[i])<<24)|(Int(data[i+1])<<16)|(Int(data[i+2])<<8)|Int(data[i+3])
        }

        guard u16(2) == 42 else { return nil }
        let ifdOffset = u32(4)
        guard ifdOffset + 2 <= data.count else { return nil }

        let n = u16(ifdOffset)
        var pos = ifdOffset + 2
        for _ in 0..<n {
            guard pos + 12 <= data.count else { break }
            let tag = u16(pos)
            let type_ = u16(pos + 2)
            let count = u32(pos + 4)
            if tag == 700 {
                let typeSize = [2:1, 3:2, 4:4, 5:8, 6:1, 7:1, 8:2, 9:4, 10:8, 11:4, 12:8][type_] ?? 1
                let total = count * typeSize
                let off = total <= 4 ? pos + 8 : u32(pos + 8)
                guard off + total <= data.count else { break }
                return data[off..<off+total]
            }
            pos += 12
        }
        return nil
    }
}
