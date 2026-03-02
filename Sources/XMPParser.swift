import Foundation

struct ComfyXMP {
    var workflow: String?
    var prompt: String?
    var models: String?
    var extra: String?
}

private class XMPParserDelegate: NSObject, XMLParserDelegate {
    var result = ComfyXMP()
    private var currentElement: String?
    private var currentText = ""
    private let cflNS = "http://ns.conward.io/comfyui/1.0/"

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if namespaceURI == cflNS {
            currentElement = elementName
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement != nil { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard namespaceURI == cflNS, let el = currentElement, el == elementName else { return }
        switch el {
        case "workflow": result.workflow = currentText
        case "prompt":   result.prompt   = currentText
        case "models":   result.models   = currentText
        case "extra":    result.extra    = currentText
        default: break
        }
        currentElement = nil
        currentText = ""
    }
}

enum XMPParser {
    static func parse(string: String) -> ComfyXMP? {
        guard let data = string.data(using: .utf8) else { return nil }
        return parse(data: data)
    }

    static func parse(data: Data) -> ComfyXMP? {
        let delegate = XMPParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        guard parser.parse() else { return nil }
        let r = delegate.result
        // Return nil if no cfl fields found (not our XMP)
        guard r.workflow != nil || r.prompt != nil || r.models != nil || r.extra != nil else { return nil }
        return r
    }
}
