import Foundation
import ImageIO

enum TIFFReader {

    static func extractXMP(from data: Data) -> ComfyXMP? {
        guard let xmpData = extractXMPData(from: data) else { return nil }
        return XMPParser.parse(data: xmpData)
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
