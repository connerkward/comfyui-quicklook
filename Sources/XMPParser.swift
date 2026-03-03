import Foundation

struct ComfyXMP {
    var workflow: String?
    var prompt: String?
    var models: String?
    var json: String?
    var layers: String?
}

/// One XMP element: namespace URI, local name, text value.
struct XMPEntry: Encodable {
    let ns: String
    let name: String
    let value: String
}

/// Result of parsing XMP: ComfyUI fields (if any) plus every element with text for "All XMP" tab.
struct XMPParseResult {
    var comfy: ComfyXMP?
    var allEntries: [XMPEntry]
}

private class XMPParserDelegate: NSObject, XMLParserDelegate {
    var result = ComfyXMP()
    var allEntries: [XMPEntry] = []
    private var currentNamespace: String?
    private var currentElement: String?
    private var currentText = ""
    private static let comfyElementNames: Set<String> = ["workflow", "prompt", "models", "json", "layers"]

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentNamespace = namespaceURI
        currentElement = elementName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            allEntries.append(XMPEntry(
                ns: namespaceURI ?? "",
                name: elementName,
                value: text
            ))
        }
        if Self.comfyElementNames.contains(elementName) {
            switch elementName {
            case "workflow": result.workflow = currentText
            case "prompt":   result.prompt   = currentText
            case "models":   result.models   = currentText
            case "json":     result.json     = currentText
            case "layers":   result.layers   = currentText
            default: break
            }
        }
        currentNamespace = nil
        currentElement = nil
        currentText = ""
    }
}

enum XMPParser {
    static func parse(string: String) -> ComfyXMP? {
        parseFull(string: string).comfy
    }

    static func parse(data: Data) -> ComfyXMP? {
        parseFull(data: data).comfy
    }

    /// Parse XMP and return both ComfyUI fields and all elements (for ComfyUI tab + All XMP tab).
    static func parseFull(string: String) -> XMPParseResult {
        guard let data = string.data(using: .utf8) else { return XMPParseResult(comfy: nil, allEntries: []) }
        return parseFull(data: data)
    }

    static func parseFull(data: Data) -> XMPParseResult {
        let delegate = XMPParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        _ = parser.parse()
        let comfy: ComfyXMP? = {
            let r = delegate.result
            guard r.workflow != nil || r.prompt != nil || r.models != nil || r.json != nil else { return nil }
            return r
        }()
        return XMPParseResult(comfy: comfy, allEntries: delegate.allEntries)
    }
}
