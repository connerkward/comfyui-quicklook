import Foundation

enum WebPReader {
    static func extractXMP(from data: Data) -> ComfyXMP? {
        guard data.count > 12 else { return nil }
        guard String(bytes: data[0..<4], encoding: .ascii) == "RIFF",
              String(bytes: data[8..<12], encoding: .ascii) == "WEBP" else { return nil }

        var offset = 12
        while offset + 8 <= data.count {
            let fourCC = String(bytes: data[offset..<offset+4], encoding: .ascii) ?? ""
            let chunkSize = data[offset+4..<offset+8].withUnsafeBytes {
                Int($0.load(as: UInt32.self).littleEndian)
            }
            offset += 8
            guard offset + chunkSize <= data.count else { break }

            if fourCC == "XMP " {
                let xmpData = data[offset..<offset+chunkSize]
                return XMPParser.parse(data: xmpData)
            }

            offset += chunkSize + (chunkSize & 1)  // pad to even
        }
        return nil
    }
}
