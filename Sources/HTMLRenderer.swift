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

    static func generateHTML(imageData: Data, chunks: [String: String]) -> Data {
        let b64 = imageData.base64EncodedString()
        let workflowJSON = chunks["workflow"] ?? chunks["prompt"] ?? "{}"
        let summary = extractSummary(from: workflowJSON)
        let summaryHTML = buildSummaryHTML(summary)
        let prettyJSON = prettyPrint(workflowJSON)

        let html = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;display:flex;height:100vh;overflow:hidden;background:#1c1c1e;color:#f2f2f7}
@media(prefers-color-scheme:light){body{background:#f2f2f7;color:#1c1c1e}.panel{background:#ffffff;border-left:1px solid #d1d1d6}.tab-btn{background:#f2f2f7;color:#1c1c1e}.tab-btn.active{background:#007aff;color:#fff}.kv-val{color:#333}.kv-key{color:#666}.json-pre{background:#f8f8f8;color:#333}}
.img-pane{flex:0 0 55%;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#000}
.img-pane img{max-width:100%;max-height:100%;object-fit:contain}
.panel{flex:1;display:flex;flex-direction:column;background:#2c2c2e;border-left:1px solid #3a3a3c;overflow:hidden}
.tabs{display:flex;border-bottom:1px solid #3a3a3c;flex-shrink:0}
.tab-btn{flex:1;padding:10px 0;background:#2c2c2e;color:#8e8e93;border:none;cursor:pointer;font-size:13px;font-weight:500;transition:all .15s}
.tab-btn.active{background:#0a84ff;color:#fff}
.tab-content{display:none;flex:1;overflow:auto;padding:16px}
.tab-content.active{display:block}
.kv-row{display:flex;gap:8px;padding:6px 0;border-bottom:1px solid #3a3a3c}
.kv-key{font-size:12px;color:#8e8e93;min-width:90px;font-weight:500;text-transform:uppercase;letter-spacing:.5px;flex-shrink:0}
.kv-val{font-size:13px;color:#f2f2f7;word-break:break-word}
.prompt-box{margin-top:8px;padding:10px;background:#1c1c1e;border-radius:8px;font-size:12px;line-height:1.5;color:#d1d1d6;font-style:italic}
@media(prefers-color-scheme:light){.prompt-box{background:#e5e5ea;color:#333}}
.json-pre{background:#1c1c1e;color:#d1d1d6;font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.5;white-space:pre-wrap;word-break:break-word;border-radius:8px;padding:12px}
@media(prefers-color-scheme:light){.json-pre{background:#f8f8f8;color:#333}}
.badge{display:inline-block;background:#0a84ff22;color:#0a84ff;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:600}
</style>
</head>
<body>
<div class="img-pane">
  <img src="data:image/png;base64,\(b64)">
</div>
<div class="panel">
  <div class="tabs">
    <button class="tab-btn active" onclick="show('sum',this)">Summary</button>
    <button class="tab-btn" onclick="show('json',this)">Workflow JSON</button>
  </div>
  <div id="sum" class="tab-content active">
    \(summaryHTML)
  </div>
  <div id="json" class="tab-content">
    <pre class="json-pre">\(prettyJSON)</pre>
  </div>
</div>
<script>
function show(id,btn){
  document.querySelectorAll('.tab-content').forEach(e=>e.classList.remove('active'));
  document.querySelectorAll('.tab-btn').forEach(e=>e.classList.remove('active'));
  document.getElementById(id).classList.add('active');
  btn.classList.add('active');
}
</script>
</body>
</html>
"""
        return Data(html.utf8)
    }

    private static func extractSummary(from json: String) -> WorkflowSummary {
        var s = WorkflowSummary()
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return s }

        // Walk all nodes regardless of structure depth
        func walk(_ val: Any) {
            if let dict = val as? [String: Any] {
                // ComfyUI workflow node format: inputs dict inside node
                if let inputs = dict["inputs"] as? [String: Any] {
                    let classType = dict["class_type"] as? String ?? ""
                    if classType.contains("CheckpointLoader") || classType.contains("UNETLoader") {
                        s.model = inputs["ckpt_name"] as? String ?? inputs["unet_name"] as? String
                    }
                    if classType.contains("KSampler") {
                        s.sampler = inputs["sampler_name"] as? String
                        if let v = inputs["steps"] { s.steps = "\(v)" }
                        if let v = inputs["cfg"] { s.cfg = "\(v)" }
                        if let v = inputs["seed"] ?? inputs["noise_seed"] { s.seed = "\(v)" }
                    }
                    if classType.contains("CLIPTextEncode") && s.positivePrompt == nil {
                        s.positivePrompt = inputs["text"] as? String
                    }
                    for v in inputs.values { walk(v) }
                }
                for v in dict.values { walk(v) }
            } else if let arr = val as? [Any] {
                for v in arr { walk(v) }
            }
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
        row("Model", s.model)
        row("Sampler", s.sampler)
        row("Steps", s.steps)
        row("CFG", s.cfg)
        row("Seed", s.seed)
        let prompt = s.positivePrompt.map { "<div class='kv-key' style='margin-top:12px'>Positive Prompt</div><div class='prompt-box'>\(escapeHTML($0))</div>" } ?? ""
        return rows + prompt
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func prettyPrint(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return escapeHTML(json) }
        return escapeHTML(str)
    }
}
