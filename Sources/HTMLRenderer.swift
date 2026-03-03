import Foundation

struct WorkflowSummary {
    var model: String?
    var sampler: String?
    var steps: String?
    var cfg: String?
    var seed: String?
    var positivePrompt: String?
}

struct HTMLRenderer {
    private static let nsPrefix: [String: String] = [
        "http://ns.adobe.com/xap/1.0/": "xmp",
        "http://purl.org/dc/elements/1.1/": "dc",
        "http://ns.adobe.com/photoshop/1.0/": "photoshop",
        "http://ns.adobe.com/exif/1.0/": "exif",
        "http://ns.adobe.com/tiff/1.0/": "tiff",
        "http://ns.adobe.com/camera-raw-settings/1.0/": "crs",
        "http://ns.adobe.com/xmp/type/1.0/": "xmpMM",
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#": "rdf",
        "urn:comfy:xmp:v1": "comfy"
    ]
    private static func xmpDisplayKey(ns: String, name: String) -> String {
        let prefix = nsPrefix[ns] ?? (ns.split(separator: "/").last.map(String.init) ?? "ns")
        return "\(prefix):\(name)"
    }
    private static func buildAllXMPHTML(_ entries: [XMPEntry]) -> String {
        entries.map { e in
            let key = xmpDisplayKey(ns: e.ns, name: e.name)
            let valHTML = compactJSONHTML(e.value)
            return "<div class='kv-row' style='align-items:flex-start'><span class='kv-key'>\(escapeHTML(key))</span><span class='kv-val'>\(valHTML)</span></div>"
        }.joined()
    }

    /// Render JSON string as compact tree; non-JSON returns escaped inline.
    private static func compactJSONHTML(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" else { return escapeHTML(raw) }
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return escapeHTML(raw) }
        return jsonToCompactHTML(obj, indent: 0)
    }

    private static func jsonToCompactHTML(_ val: Any, indent: Int = 0) -> String {
        switch val {
        case let d as [String: Any]:
            if d.isEmpty { return "<span class='json-tree'>{}</span>" }
            let parts = d.sorted(by: { $0.key < $1.key }).map { k, v in
                "<div class='json-tree nested'><span class='k'>\(escapeHTML(k))</span>: \(jsonToCompactHTML(v))</div>"
            }
            return "<span class='json-tree'> {</span>" + parts.joined() + "<span class='json-tree'>}</span>"
        case let a as [Any]:
            if a.isEmpty { return "<span class='json-tree'>[]</span>" }
            let parts = a.prefix(15).map { jsonToCompactHTML($0) }
            let more = a.count > 15 ? " <span class='k'>…+\(a.count - 15)</span>" : ""
            return "<span class='json-tree'>[</span>" + parts.joined(separator: ", ") + more + "<span class='json-tree'>]</span>"
        case let s as String:
            let esc = escapeHTML(s)
            return "<span class='v'>\(esc.count > 120 ? String(esc.prefix(117)) + "…" : esc)</span>"
        case let n as NSNumber:
            return "<span class='v'>\(n.stringValue)</span>"
        case is NSNull:
            return "<span class='v'>null</span>"
        default:
            return "<span class='v'>\(escapeHTML("\(val)"))</span>"
        }
    }

    // TIFF: layer switcher left, panel right with tabs ComfyUI | All XMP
    static func generateTIFFHTML(pages: [Data], layerNames: [String], parseResult: XMPParseResult, totalFileSize: Int, layerInfos: [LayerFileInfo]) -> Data {
        let pagesJS = pages.map { "'\($0.base64EncodedString())'" }.joined(separator: ",")
        let names = layerNames.isEmpty
            ? pages.indices.map { "Layer \($0 + 1)" }
            : layerNames + (pages.count > layerNames.count ? (layerNames.count..<pages.count).map { "Layer \($0 + 1)" } : [])
        let namesJS = names.map { "'\(escapeJS($0))'" }.joined(separator: ",")
        let xmp = parseResult.comfy ?? ComfyXMP()
        let workflowJSON = xmp.workflow ?? xmp.prompt ?? "{}"
        let fileMeta = fileMetaFromEntries(parseResult.allEntries)
        let comfyBody = buildComfyPanelBody(xmp: xmp, totalFileSize: totalFileSize, layerInfos: layerInfos.isEmpty ? nil : layerInfos, layerNames: names, fileMeta: fileMeta)
        let allXMPBody = buildAllXMPHTML(parseResult.allEntries)

        let html = """
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:100%;max-width:100%;height:100vh;overflow:hidden}
body{font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;display:flex;background:#1c1c1e;color:#f2f2f7}
.img-pane{flex:1;min-width:0;display:flex;flex-direction:column;overflow:hidden;background:#000}
.layer-bar{display:flex;align-items:center;gap:6px;padding:8px 12px;background:#2c2c2e;border-bottom:1px solid #3a3a3c;overflow-x:auto;flex-shrink:0}
.layer-btn{padding:5px 12px;border-radius:6px;background:#3a3a3c;color:#ebebf5;border:none;cursor:pointer;font-size:12px;font-weight:500;white-space:nowrap;transition:background .12s}
.layer-btn.active{background:#0a84ff;color:#fff}
.img-wrap{flex:1;display:flex;align-items:center;justify-content:center;overflow:hidden}
.img-wrap img{max-width:100%;max-height:100%;object-fit:contain}
.panel{flex:0 0 340px;min-width:0;display:flex;flex-direction:column;background:#2c2c2e;border-left:1px solid #3a3a3c;overflow:hidden}
.tabs{display:flex;border-bottom:1px solid #3a3a3c;flex-shrink:0}
.tab-btn{flex:1;padding:10px 0;background:#2c2c2e;color:#8e8e93;border:none;cursor:pointer;font-size:13px;font-weight:500;transition:all .15s}
.tab-btn.active{background:#0a84ff;color:#fff}
.tab-content{display:none;flex:1;min-width:0;overflow-x:hidden;overflow-y:auto;padding:16px;word-break:break-word}
.tab-content.active{display:block}
.panel-body{flex:1;min-width:0;overflow-x:hidden;overflow-y:auto;padding:16px;word-break:break-word}
.kv-row{display:flex;gap:8px;padding:6px 0;border-bottom:1px solid #3a3a3c;min-width:0}
.kv-key{font-size:12px;color:#8e8e93;min-width:90px;font-weight:500;text-transform:uppercase;letter-spacing:.5px;flex-shrink:0}
.kv-val{font-size:13px;color:#f2f2f7;word-break:break-word;-webkit-user-select:text;user-select:text}
.kv-hash{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;color:#60a5fa;flex:1;min-width:0;overflow-wrap:break-word}
.cp-btn{flex-shrink:0;background:none;border:1px solid #3a3a3c;border-radius:5px;color:#8e8e93;cursor:pointer;padding:2px 4px;display:flex;align-items:center;transition:border-color .15s,color .15s}
.cp-btn:hover{color:#f2f2f7;border-color:#8e8e93}
.cp-btn .ico-check{display:none}
.cp-btn.copied{border-color:#34d399;color:#34d399}
.cp-btn.copied .ico-clip{display:none}
.cp-btn.copied .ico-check{display:block}
.section-label{font-size:11px;color:#8e8e93;text-transform:uppercase;letter-spacing:.5px;font-weight:500;margin:12px 0 4px}
.json-pre{background:#1c1c1e;color:#d1d1d6;font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.5;white-space:pre-wrap;word-break:break-word;border-radius:8px;padding:12px;-webkit-user-select:text;user-select:text}
.json-tree-wrap{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.45;padding:8px 0;-webkit-user-select:text;user-select:text}
.dl-btn{display:block;width:100%;margin-top:8px;padding:8px 10px;border-radius:6px;background:#0a84ff;color:#fff;border:none;cursor:pointer;font-size:12px;font-weight:600;text-align:center}
.dl-btn:hover{background:#0070e0}
.fp-block{border-radius:8px;overflow:hidden;background:#111;border:1px solid #3a3a3c;padding:0 0 10px 0;margin-bottom:14px}
.layer-row{transition:background .15s}
.layer-row.current-layer{background:#3a3a3c}
.json-tree{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.4;color:#d1d1d6}
.json-tree .k{color:#8e8e93}
.json-tree .v{color:#f2f2f7}
.json-tree .nested{margin-left:10px;border-left:1px solid #3a3a3c;padding-left:6px}
#fpTooltip{position:fixed;pointer-events:none;background:rgba(0,0,0,.85);color:#fff;padding:4px 8px;border-radius:4px;font-size:11px;max-width:200px;z-index:9999;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.layer-tbl{overflow-x:auto}
.layer-tbl table{min-width:0}
@media(prefers-color-scheme:light){body{background:#f2f2f7;color:#1c1c1e}.panel{background:#fff;border-color:#d1d1d6;color:#1c1c1e}.tab-content,.panel-body{color:#1c1c1e}.layer-bar{background:#f2f2f7;border-color:#d1d1d6}.layer-btn{background:#e5e5ea;color:#1c1c1e}.tab-btn{background:#f2f2f7;color:#1c1c1e}.tab-btn.active{background:#007aff;color:#fff}.kv-val,.kv-hash{color:#1c1c1e}.kv-key{color:#666}.prompt-box{background:#e5e5ea;color:#333}.json-pre{background:#f8f8f8;color:#333}.layer-tbl table,.layer-tbl th,.layer-tbl td{border-color:#d1d1d6 !important;color:#1c1c1e}.layer-tbl .layer-row.current-layer{background:#e5e5ea;color:#1c1c1e}.json-tree{color:#1c1c1e}.json-tree .k{color:#666}.json-tree .v{color:#1c1c1e}.json-tree .nested{border-color:#d1d1d6}.fp-block{background:#f8f8f8;border-color:#d1d1d6}#fpTooltip{background:rgba(0,0,0,.9)}}
@media(max-width:800px){.panel{flex:0 0 280px}.kv-key{min-width:70px;font-size:11px}.kv-val{font-size:12px}.layer-tbl table{font-size:10px}}
@media(max-width:560px){body{flex-direction:column;overflow:auto}.img-pane{flex:none;height:40vh;min-height:180px}.panel{flex:none;border-left:none;border-top:1px solid #3a3a3c}.layer-bar{flex-wrap:wrap}}
</style></head>
<body>
<div id="fpTooltip" style="display:none"></div>
<script>var _wfJSON="\(escapeJSDouble(workflowJSON))";</script>
<div class="img-pane">
  <div class="layer-bar" id="layerBar"></div>
  <div class="img-wrap"><img id="mainImg" src=""></div>
</div>
<div class="panel">
  <div class="tabs">
    <button class="tab-btn active" onclick="showTab('comfy',this)">ComfyUI</button>
    <button class="tab-btn" onclick="showTab('allxmp',this)">All XMP</button>
  </div>
  <div id="comfy" class="tab-content active">\(comfyBody)</div>
  <div id="allxmp" class="tab-content"><div class="panel-body">\(allXMPBody)</div></div>
</div>
<script>
var pages=[\(pagesJS)],names=[\(namesJS)],cur=0;
function showTab(id,btn){
  document.querySelectorAll('.tab-content').forEach(function(e){e.classList.remove('active');});
  document.querySelectorAll('.tab-btn').forEach(function(e){e.classList.remove('active');});
  document.getElementById(id).classList.add('active');
  btn.classList.add('active');
  if(id==='comfy')renderFP('fp');
}
\(fingerprintFn())
\(downloadFn())
\(copyFn())
var init=function(){
  var bar=document.getElementById('layerBar');
  names.forEach(function(n,i){
    var b=document.createElement('button');
    b.className='layer-btn'+(i===0?' active':'');
    b.textContent=n;b.onclick=function(){select(i)};
    bar.appendChild(b);
  });
  select(0);
};
function select(i){
  cur=i;
  document.getElementById('mainImg').src='data:image/png;base64,'+pages[i];
  document.querySelectorAll('.layer-btn').forEach(function(b,j){b.classList.toggle('active',j===i);});
  document.querySelectorAll('.layer-row').forEach(function(tr,j){tr.classList.toggle('current-layer',j===i);});
}
document.addEventListener('keydown',function(e){
  if(e.key==='ArrowLeft')select(Math.max(0,cur-1));
  else if(e.key==='ArrowRight')select(Math.min(pages.length-1,cur+1));
});
init();
renderFP('fp');
var _rT;window.addEventListener('resize',function(){clearTimeout(_rT);_rT=setTimeout(function(){renderFP('fp');},150);});
</script>
</body></html>
"""
        return Data(html.utf8)
    }

    /// Build file meta dict for ComfyUI tab from XMP allEntries (dc:creator, xmp:CreateDate, etc.).
    static func fileMetaFromEntries(_ entries: [XMPEntry]) -> [String: String] {
        let want: [(ns: String, name: String, label: String)] = [
            ("http://purl.org/dc/elements/1.1/", "creator", "Creator"),
            ("http://ns.adobe.com/xap/1.0/", "CreateDate", "Created"),
            ("http://ns.adobe.com/xap/1.0/", "CreatorTool", "Creator tool"),
        ]
        var out: [String: String] = [:]
        for e in entries where !e.value.isEmpty {
            if let match = want.first(where: { $0.ns == e.ns && $0.name == e.name }) {
                out[match.label] = e.value
            }
        }
        return out
    }

    private static func formatByteCount(_ n: Int) -> String {
        if n < 1024 { return "\(n) B" }
        if n < 1024 * 1024 { return String(format: "%.1f KB", Double(n) / 1024) }
        return String(format: "%.1f MB", Double(n) / (1024 * 1024))
    }

    private static func buildFileInfoSection(totalFileSize: Int?, layerInfos: [LayerFileInfo]?, layerNames: [String], fileMeta: [String: String]) -> String {
        let hasFile = totalFileSize != nil || !fileMeta.isEmpty || (layerInfos.map { !$0.isEmpty } ?? false)
        guard hasFile else { return "" }
        var html = "<div class='section-label'>File &amp; layers</div>"
        if let size = totalFileSize {
            html += "<div class='kv-row'><span class='kv-key'>Total size</span><span class='kv-val'>\(escapeHTML(formatByteCount(size)))</span></div>"
        }
        for (k, v) in fileMeta.sorted(by: { $0.key < $1.key }) {
            html += "<div class='kv-row'><span class='kv-key'>\(escapeHTML(k))</span><span class='kv-val'>\(escapeHTML(v))</span></div>"
        }
        if let infos = layerInfos, !infos.isEmpty {
            html += "<div class='section-label' style='margin-top:12px'>Per layer</div>"
            html += "<div class='layer-tbl'><table style='width:100%;border-collapse:collapse;font-size:11px'><thead><tr style='border-bottom:1px solid #3a3a3c'><th style='text-align:left;padding:4px 6px;color:#8e8e93'>Layer</th><th style='text-align:right;padding:4px 6px;color:#8e8e93'>Size</th><th style='text-align:right;padding:4px 6px;color:#8e8e93'>Resolution</th><th style='text-align:center;padding:4px 6px;color:#8e8e93'>Aspect</th><th style='text-align:left;padding:4px 6px;color:#8e8e93'>Compression</th></tr></thead><tbody>"
            for (i, info) in infos.enumerated() {
                let name = i < layerNames.count ? layerNames[i] : "Layer \(i + 1)"
                html += "<tr class='layer-row' style='border-bottom:1px solid #2c2c2e'><td style='padding:4px 6px'>\(escapeHTML(name))</td><td style='text-align:right;padding:4px 6px'>\(escapeHTML(formatByteCount(info.byteSize)))</td><td style='text-align:right;padding:4px 6px'>\(info.width)×\(info.height)</td><td style='text-align:center;padding:4px 6px'>\(escapeHTML(info.aspectRatio))</td><td style='padding:4px 6px'>\(escapeHTML(info.compression))</td></tr>"
            }
            html += "</tbody></table></div>"
        }
        return html
    }

    private static func buildComfyPanelBody(xmp: ComfyXMP, totalFileSize: Int? = nil, layerInfos: [LayerFileInfo]? = nil, layerNames: [String] = [], fileMeta: [String: String] = [:]) -> String {
        var html = "<div class='fp-block'><canvas id=\"fp\" style=\"width:100%;display:block\"></canvas>"
        if xmp.workflow != nil || xmp.prompt != nil {
            html += "<div style='padding:0 10px'><button class=\"dl-btn\" onclick=\"_dlJSON()\">&#8595; Download Workflow JSON</button></div>"
        }
        html += "</div>"
        if totalFileSize != nil || !fileMeta.isEmpty || (layerInfos.map { !$0.isEmpty } ?? false) {
            html += buildFileInfoSection(totalFileSize: totalFileSize, layerInfos: layerInfos, layerNames: layerNames, fileMeta: fileMeta)
            html += "<div class='section-label' style='margin-top:14px'>Details</div>"
        }
        if xmp.workflow != nil || xmp.prompt != nil || xmp.models != nil || xmp.json != nil {
            html += buildXMPContent(xmp)
        } else if xmp.workflow == nil && xmp.prompt == nil {
            html += "<p style='color:#8e8e93;font-size:13px'>No ComfyUI workflow metadata in this file.</p>"
        }
        return html
    }

    // PNG/WebP: same as TIFF — image left, panel right with tabs ComfyUI | All XMP
    static func generateHTML(imageData: Data, chunks: [String: String], xmp: ComfyXMP? = nil, allXMPEntries: [XMPEntry] = [], totalFileSize: Int? = nil, imageLayerInfo: LayerFileInfo? = nil, imageMIME: String = "image/png") -> Data {
        let b64 = imageData.base64EncodedString()
        let workflowJSON = chunks["workflow"] ?? chunks["prompt"] ?? xmp?.workflow ?? xmp?.prompt ?? "{}"
        let summary = extractSummary(from: workflowJSON)
        let summaryHTML = buildSummaryHTML(summary)
        let xmpContent = xmp.map { buildXMPContent($0) } ?? ""
        let fileMeta = fileMetaFromEntries(allXMPEntries)
        let layerInfos = imageLayerInfo.map { [$0] }
        let fileInfoBlock = buildFileInfoSection(totalFileSize: totalFileSize, layerInfos: layerInfos, layerNames: layerInfos != nil ? ["Image"] : [], fileMeta: fileMeta)
        let hasWorkflow = (chunks["workflow"] ?? chunks["prompt"] ?? xmp?.workflow ?? xmp?.prompt) != nil
        let comfyBody = """
    <div class="fp-block"><canvas id="fp" style="width:100%;display:block"></canvas>
    \(hasWorkflow ? "<div style='padding:0 10px'><button class=\"dl-btn\" onclick=\"_dlJSON()\">&#8595; Download Workflow JSON</button></div>" : "")
    </div>
    \(totalFileSize != nil || imageLayerInfo != nil || !fileMeta.isEmpty ? fileInfoBlock + "<div class='section-label' style='margin-top:14px'>Details</div>" : "")
    \(summaryHTML)
    \(xmpContent)
    """
        let allXMPBody = buildAllXMPHTML(allXMPEntries)

        let html = """
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:100%;max-width:100%;height:100vh;overflow:hidden}
body{font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;display:flex;background:#1c1c1e;color:#f2f2f7}
.img-pane{flex:1;min-width:0;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#000}
.img-pane img{max-width:100%;max-height:100%;object-fit:contain}
.panel{flex:0 0 340px;min-width:0;display:flex;flex-direction:column;background:#2c2c2e;border-left:1px solid #3a3a3c;overflow:hidden}
.tabs{display:flex;border-bottom:1px solid #3a3a3c;flex-shrink:0}
.tab-btn{flex:1;padding:10px 0;background:#2c2c2e;color:#8e8e93;border:none;cursor:pointer;font-size:13px;font-weight:500;transition:all .15s}
.tab-btn.active{background:#0a84ff;color:#fff}
.tab-content{display:none;flex:1;min-width:0;overflow-x:hidden;overflow-y:auto;padding:16px;word-break:break-word}
.tab-content.active{display:block}
.panel-body{flex:1;min-width:0;overflow-x:hidden;overflow-y:auto;padding:16px;word-break:break-word}
.kv-row{display:flex;gap:8px;padding:6px 0;border-bottom:1px solid #3a3a3c;min-width:0}
.kv-key{font-size:12px;color:#8e8e93;min-width:90px;font-weight:500;text-transform:uppercase;letter-spacing:.5px;flex-shrink:0}
.kv-val{font-size:13px;color:#f2f2f7;word-break:break-word;-webkit-user-select:text;user-select:text}
.kv-hash{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;color:#60a5fa;flex:1;min-width:0;overflow-wrap:break-word}
.cp-btn{flex-shrink:0;background:none;border:1px solid #3a3a3c;border-radius:5px;color:#8e8e93;cursor:pointer;padding:2px 4px;display:flex;align-items:center;transition:border-color .15s,color .15s}
.cp-btn:hover{color:#f2f2f7;border-color:#8e8e93}
.cp-btn .ico-check{display:none}
.cp-btn.copied{border-color:#34d399;color:#34d399}
.cp-btn.copied .ico-clip{display:none}
.cp-btn.copied .ico-check{display:block}
.section-label{font-size:11px;color:#8e8e93;text-transform:uppercase;letter-spacing:.5px;font-weight:500;margin:12px 0 4px}
.prompt-box{margin-top:8px;padding:10px;background:#1c1c1e;border-radius:8px;font-size:12px;line-height:1.5;color:#d1d1d6;font-style:italic;-webkit-user-select:text;user-select:text}
.json-pre{background:#1c1c1e;color:#d1d1d6;font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.5;white-space:pre-wrap;word-break:break-word;border-radius:8px;padding:12px;-webkit-user-select:text;user-select:text}
.json-tree-wrap{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.45;padding:8px 0;-webkit-user-select:text;user-select:text}
.dl-btn{display:block;width:100%;margin-top:8px;padding:8px 10px;border-radius:6px;background:#0a84ff;color:#fff;border:none;cursor:pointer;font-size:12px;font-weight:600;text-align:center}
.dl-btn:hover{background:#0070e0}
.fp-block{border-radius:8px;overflow:hidden;background:#111;border:1px solid #3a3a3c;padding:0 0 10px 0;margin-bottom:14px}
.json-tree{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.4;color:#d1d1d6}
.json-tree .k{color:#8e8e93}
.json-tree .v{color:#f2f2f7}
.json-tree .nested{margin-left:10px;border-left:1px solid #3a3a3c;padding-left:6px}
#fpTooltip{position:fixed;pointer-events:none;background:rgba(0,0,0,.85);color:#fff;padding:4px 8px;border-radius:4px;font-size:11px;max-width:200px;z-index:9999;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media(prefers-color-scheme:light){body{background:#f2f2f7;color:#1c1c1e}.panel{background:#fff;border-color:#d1d1d6;color:#1c1c1e}.tab-content,.panel-body{color:#1c1c1e}.tab-btn{background:#f2f2f7;color:#1c1c1e}.tab-btn.active{background:#007aff;color:#fff}.kv-val,.kv-hash{color:#1c1c1e}.kv-key{color:#666}.prompt-box{background:#e5e5ea;color:#333}.json-pre{background:#f8f8f8;color:#333}.json-tree{color:#1c1c1e}.json-tree .k{color:#666}.json-tree .v{color:#1c1c1e}.json-tree .nested{border-color:#d1d1d6}.fp-block{background:#f8f8f8;border-color:#d1d1d6}#fpTooltip{background:rgba(0,0,0,.9)}}
@media(max-width:800px){.panel{flex:0 0 280px}.kv-key{min-width:70px;font-size:11px}.kv-val{font-size:12px}}
@media(max-width:560px){body{flex-direction:column;overflow:auto}.img-pane{flex:none;height:40vh;min-height:180px}.panel{flex:none;border-left:none;border-top:1px solid #3a3a3c}}
</style></head>
<body>
<div id="fpTooltip" style="display:none"></div>
<script>var _wfJSON="\(escapeJSDouble(workflowJSON))";</script>
<div class="img-pane"><img src="data:\(imageMIME);base64,\(b64)"></div>
<div class="panel">
  <div class="tabs">
    <button class="tab-btn active" onclick="showTab('comfy',this)">ComfyUI</button>
    <button class="tab-btn" onclick="showTab('allxmp',this)">All XMP</button>
  </div>
  <div id="comfy" class="tab-content active">\(comfyBody)</div>
  <div id="allxmp" class="tab-content"><div class="panel-body">\(allXMPBody)</div></div>
</div>
<script>
function showTab(id,btn){
  document.querySelectorAll('.tab-content').forEach(function(e){e.classList.remove('active');});
  document.querySelectorAll('.tab-btn').forEach(function(e){e.classList.remove('active');});
  document.getElementById(id).classList.add('active');
  btn.classList.add('active');
  if(id==='comfy')renderFP('fp');
}
\(fingerprintFn())
\(downloadFn())
\(copyFn())
renderFP('fp');
var _rT;window.addEventListener('resize',function(){clearTimeout(_rT);_rT=setTimeout(function(){renderFP('fp');},150);});
</script>
</body></html>
"""
        return Data(html.utf8)
    }

    // Named JS function renderFP(cid) — reads from _wfJSON global, node hover shows name
    private static func fingerprintFn() -> String {
"""
function renderFP(cid){
  try{
    var wf=JSON.parse(_wfJSON),nodes=wf.nodes||[],links=wf.links||[];
    if(!nodes.length)return;
    var cv=document.getElementById(cid);if(!cv)return;
    var dpr=window.devicePixelRatio||1;
    var rect=cv.parentElement.getBoundingClientRect();
    var cw=Math.round(rect.width)||600;
    var ch=Math.min(Math.round(cw*0.37),220);
    cv.width=cw*dpr;cv.height=ch*dpr;
    cv.style.width=cw+'px';cv.style.height=ch+'px';
    var ctx=cv.getContext('2d');
    ctx.scale(dpr,dpr);
    var W=cw,H=ch,pad=10;
    var nm={},x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
    nodes.forEach(function(n){
      if(!n.pos)return;
      var w=(n.size&&n.size[0])||100,h=(n.size&&n.size[1])||50;
      var disp=(n.properties&&n.properties['Node name for S&R'])||n.type||('Node '+n.id);
      nm[n.id]={x:n.pos[0],y:n.pos[1],w:w,h:h,t:(n.type||'').toLowerCase(),label:disp};
      x0=Math.min(x0,n.pos[0]);y0=Math.min(y0,n.pos[1]);
      x1=Math.max(x1,n.pos[0]+w);y1=Math.max(y1,n.pos[1]+h);
    });
    var sc=Math.min((W-pad*2)/(x1-x0||1),(H-pad*2)/(y1-y0||1));
    function px(x){return pad+(x-x0)*sc;}
    function py(y){return pad+(y-y0)*sc;}
    var tc={LATENT:'#a78bfa',IMAGE:'#34d399',CONDITIONING:'#fb923c',MODEL:'#60a5fa',VAE:'#fbbf24',CLIP:'#f472b6',MASK:'#94a3b8'};
    ctx.lineWidth=0.9;ctx.globalAlpha=0.5;
    links.forEach(function(lk){
      var s=nm[lk[1]],d=nm[lk[3]];if(!s||!d)return;
      ctx.strokeStyle=tc[lk[5]]||'#6b7280';
      var sx=px(s.x+s.w),sy=py(s.y+s.h*.5),dx=px(d.x),dy=py(d.y+d.h*.5),cp=Math.abs(dx-sx)*.45;
      ctx.beginPath();ctx.moveTo(sx,sy);ctx.bezierCurveTo(sx+cp,sy,dx-cp,dy,dx,dy);ctx.stroke();
    });
    ctx.globalAlpha=0.9;
    var hitList=[];
    nodes.forEach(function(n){
      var v=nm[n.id];if(!v)return;
      var t=v.t;
      var cx=px(v.x),cy=py(v.y),cw=Math.max(v.w*sc,2),ch=Math.max(v.h*sc,2);
      ctx.fillStyle=t.includes('ksampler')?'#5b21b6':t.includes('loader')?'#1e40af':t.includes('clip')||t.includes('textencode')?'#9a3412':t.includes('save')||t.includes('preview')||t.includes('image')?'#065f46':t==='reroute'?'#27272a':'#44403c';
      ctx.fillRect(cx,cy,cw,ch);
      hitList.push({x:cx,y:cy,w:cw,h:ch,label:v.label});
    });
    var tip=document.getElementById('fpTooltip');
    if(!tip)return;
    cv.addEventListener('mousemove',function(e){
      var r=cv.getBoundingClientRect();
      var mx=(e.clientX-r.left)/r.width*W,my=(e.clientY-r.top)/r.height*H;
      var found=hitList.find(function(b){return mx>=b.x&&mx<=b.x+b.w&&my>=b.y&&my<=b.y+b.h;});
      if(found){tip.textContent=found.label;tip.style.display='block';tip.style.left=(e.clientX+10)+'px';tip.style.top=(e.clientY+10)+'px';}
      else tip.style.display='none';
    });
    cv.addEventListener('mouseleave',function(){tip.style.display='none';});
  }catch(e){}
}
"""
    }

    // Click-to-copy — toggles .copied class on button to show checkmark SVG, reverts after 1.4s
    private static func copyFn() -> String {
"""
function _cpBtn(btn){
  var hash=btn.previousElementSibling;
  try{navigator.clipboard.writeText(hash.textContent);}catch(e){
    var r=document.createRange();r.selectNode(hash);window.getSelection().removeAllRanges();window.getSelection().addRange(r);
  }
  btn.classList.add('copied');btn.disabled=true;
  setTimeout(function(){btn.classList.remove('copied');btn.disabled=false;},1400);
}
"""
    }

    // Download via webkit message handler; clipboard fallback for QL extension context
    private static func downloadFn() -> String {
"""
function _dlJSON(){
  if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.comfydownload){
    window.webkit.messageHandlers.comfydownload.postMessage(_wfJSON);
  } else {
    var el=document.createElement('textarea');
    el.value=_wfJSON;el.style.cssText='position:fixed;top:-9999px;opacity:0';
    document.body.appendChild(el);el.select();document.execCommand('copy');document.body.removeChild(el);
  }
}
"""
    }

    // XMP fields inline content — models + json metadata
    private static func buildXMPContent(_ xmp: ComfyXMP) -> String {
        var html = ""
        if let modelsJSON = xmp.models, !modelsJSON.isEmpty {
            if let data = modelsJSON.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !arr.isEmpty {
                html += "<div class='section-label'>Models</div>"
                for m in arr {
                    let name = (m["name"] as? String ?? m["filename"] as? String ?? "").components(separatedBy: "/").last ?? ""
                    let hash = m["sha256"] as? String ?? m["hash"] as? String ?? ""
                    let type = m["type"] as? String ?? "model"
                    if !name.isEmpty {
                        html += "<div class='kv-row'><span class='kv-key'>\(escapeHTML(type))</span><span class='kv-val'>\(escapeHTML(name))</span></div>"
                    }
                    if !hash.isEmpty {
                        html += "<div class='kv-row' style='align-items:center'><span class='kv-key'>hash</span><span class='kv-val kv-hash'>\(escapeHTML(hash))</span><button class='cp-btn' onclick='_cpBtn(this)' title='Copy hash'><svg class='ico-clip' width='13' height='13' viewBox='0 0 16 16' fill='none' stroke='currentColor' stroke-width='1.5'><rect x='5' y='5' width='9' height='9' rx='1.5'/><path d='M11 5V3.5A1.5 1.5 0 0 0 9.5 2H3.5A1.5 1.5 0 0 0 2 3.5v6A1.5 1.5 0 0 0 3.5 11H5'/></svg><svg class='ico-check' width='13' height='13' viewBox='0 0 16 16' fill='none' stroke='#34d399' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><polyline points='2.5,8.5 6.5,12.5 13.5,4'/></svg></button></div>"
                    }
                }
            }
        }
        if let jsonMeta = xmp.json, !jsonMeta.isEmpty {
            let jsonHTML = compactJSONHTML(jsonMeta)
            html += "<div class='section-label'>JSON</div><div class='json-tree-wrap'>\(jsonHTML)</div>"
        }
        return html
    }

    private static func extractSummary(from json: String) -> WorkflowSummary {
        var s = WorkflowSummary()
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return s }
        func walk(_ val: Any) {
            if let dict = val as? [String: Any] {
                if let inputs = dict["inputs"] as? [String: Any] {
                    let ct = dict["class_type"] as? String ?? ""
                    if ct.contains("CheckpointLoader") || ct.contains("UNETLoader") {
                        s.model = inputs["ckpt_name"] as? String ?? inputs["unet_name"] as? String
                    }
                    if ct.contains("KSampler") {
                        s.sampler = inputs["sampler_name"] as? String
                        if let v = inputs["steps"] { s.steps = "\(v)" }
                        if let v = inputs["cfg"] { s.cfg = "\(v)" }
                        if let v = inputs["seed"] ?? inputs["noise_seed"] { s.seed = "\(v)" }
                    }
                    if ct.contains("CLIPTextEncode") && s.positivePrompt == nil {
                        s.positivePrompt = inputs["text"] as? String
                    }
                    for v in inputs.values { walk(v) }
                }
                for v in dict.values { walk(v) }
            } else if let arr = val as? [Any] { for v in arr { walk(v) } }
        }
        walk(obj)
        return s
    }

    private static func buildSummaryHTML(_ s: WorkflowSummary) -> String {
        var rows = ""
        func row(_ k: String, _ v: String?) {
            guard let v = v, !v.isEmpty else { return }
            rows += "<div class='kv-row'><span class='kv-key'>\(k)</span><span class='kv-val'>\(escapeHTML(v))</span></div>"
        }
        row("Model", s.model); row("Sampler", s.sampler)
        row("Steps", s.steps); row("CFG", s.cfg); row("Seed", s.seed)
        let prompt = s.positivePrompt.map { "<div class='kv-key' style='margin-top:12px'>Positive Prompt</div><div class='prompt-box'>\(escapeHTML($0))</div>" } ?? ""
        return rows + prompt
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "'", with: "\\'")
         .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func escapeJSDouble(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "")
         .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
         .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
