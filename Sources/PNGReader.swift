import Foundation

struct PNGChunkReader {
    private static let pngSignature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    static func readTextChunks(from data: Data) -> [String: String]? {
        let bytes = [UInt8](data)
        guard bytes.count > 8, bytes.prefix(8).elementsEqual(pngSignature) else { return nil }

        var result: [String: String] = [:]
        var offset = 8

        while offset + 12 <= bytes.count {
            let length = Int(UInt32(bytes[offset]) << 24 | UInt32(bytes[offset+1]) << 16 |
                            UInt32(bytes[offset+2]) << 8 | UInt32(bytes[offset+3]))
            let typeBytes = bytes[(offset+4)..<(offset+8)]
            let chunkType = String(bytes: typeBytes, encoding: .ascii) ?? ""
            let dataStart = offset + 8
            let dataEnd = dataStart + length
            guard dataEnd + 4 <= bytes.count else { break }

            if chunkType == "tEXt" {
                let chunkData = bytes[dataStart..<dataEnd]
                if let nullIdx = chunkData.firstIndex(of: 0) {
                    let keyword = String(bytes: chunkData[chunkData.startIndex..<nullIdx], encoding: .isoLatin1) ?? ""
                    let valueBytes = chunkData[(nullIdx+1)...]
                    let value = String(bytes: valueBytes, encoding: .utf8)
                        ?? String(bytes: valueBytes, encoding: .isoLatin1) ?? ""
                    result[keyword] = value
                }
            } else if chunkType == "iTXt" {
                let chunkData = bytes[dataStart..<dataEnd]
                // iTXt: keyword \0 compression_flag compression_method language_tag \0 translated_keyword \0 text
                if let nullIdx = chunkData.firstIndex(of: 0) {
                    let keyword = String(bytes: chunkData[chunkData.startIndex..<nullIdx], encoding: .isoLatin1) ?? ""
                    var pos = nullIdx + 1
                    guard pos + 2 <= chunkData.endIndex else { offset = dataEnd + 4; continue }
                    // skip compression_flag, compression_method
                    pos += 2
                    // skip language tag (to next \0)
                    if let langEnd = chunkData[pos...].firstIndex(of: 0) { pos = langEnd + 1 }
                    // skip translated keyword (to next \0)
                    if let tKeyEnd = chunkData[pos...].firstIndex(of: 0) { pos = tKeyEnd + 1 }
                    let valueBytes = chunkData[pos...]
                    let value = String(bytes: valueBytes, encoding: .utf8)
                        ?? String(bytes: valueBytes, encoding: .isoLatin1) ?? ""
                    result[keyword] = value
                }
            }

            offset = dataEnd + 4 // skip CRC
        }

        let relevant = result.filter { k, _ in k == "workflow" || k == "prompt" || k == "XML:com.adobe.xmp" }
        return relevant.isEmpty ? nil : relevant
    }
}
