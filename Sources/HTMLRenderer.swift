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

    // TIFF: layer switcher left, combined info panel right (no tabs — single scrollable pane)
    static func generateTIFFHTML(pages: [Data], layerNames: [String], xmp: ComfyXMP) -> Data {
        let pagesJS = pages.map { "'\($0.base64EncodedString())'" }.joined(separator: ",")
        let names = layerNames.isEmpty
            ? pages.indices.map { "Layer \($0 + 1)" }
            : layerNames + (pages.count > layerNames.count ? (layerNames.count..<pages.count).map { "Layer \($0 + 1)" } : [])
        let namesJS = names.map { "'\(escapeJS($0))'" }.joined(separator: ",")
        let workflowJSON = xmp.workflow ?? xmp.prompt ?? "{}"

        let html = """
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;display:flex;height:100vh;overflow:hidden;background:#1c1c1e;color:#f2f2f7}
.img-pane{flex:1;display:flex;flex-direction:column;overflow:hidden;background:#000}
.layer-bar{display:flex;align-items:center;gap:6px;padding:8px 12px;background:#2c2c2e;border-bottom:1px solid #3a3a3c;overflow-x:auto;flex-shrink:0}
.layer-btn{padding:5px 12px;border-radius:6px;background:#3a3a3c;color:#ebebf5;border:none;cursor:pointer;font-size:12px;font-weight:500;white-space:nowrap;transition:background .12s}
.layer-btn.active{background:#0a84ff;color:#fff}
.img-wrap{flex:1;display:flex;align-items:center;justify-content:center;overflow:hidden}
.img-wrap img{max-width:100%;max-height:100%;object-fit:contain}
.panel{flex:0 0 340px;display:flex;flex-direction:column;background:#2c2c2e;border-left:1px solid #3a3a3c;overflow:hidden}
.panel-body{flex:1;overflow-y:auto;padding:16px}
.kv-row{display:flex;gap:8px;padding:6px 0;border-bottom:1px solid #3a3a3c}
.kv-key{font-size:12px;color:#8e8e93;min-width:90px;font-weight:500;text-transform:uppercase;letter-spacing:.5px;flex-shrink:0}
.kv-val{font-size:13px;color:#f2f2f7;word-break:break-word;-webkit-user-select:text;user-select:text}
.kv-hash{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;color:#60a5fa;flex:1}
.cp-btn{flex-shrink:0;background:none;border:1px solid #3a3a3c;border-radius:5px;color:#8e8e93;cursor:pointer;padding:2px 4px;display:flex;align-items:center;transition:border-color .15s,color .15s}
.cp-btn:hover{color:#f2f2f7;border-color:#8e8e93}
.cp-btn .ico-check{display:none}
.cp-btn.copied{border-color:#34d399;color:#34d399}
.cp-btn.copied .ico-clip{display:none}
.cp-btn.copied .ico-check{display:block}
.section-label{font-size:11px;color:#8e8e93;text-transform:uppercase;letter-spacing:.5px;font-weight:500;margin:12px 0 4px}
.json-pre{background:#1c1c1e;color:#d1d1d6;font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.5;white-space:pre-wrap;word-break:break-word;border-radius:8px;padding:12px;-webkit-user-select:text;user-select:text}
.dl-btn{display:block;width:100%;margin-top:16px;padding:10px;border-radius:8px;background:#0a84ff;color:#fff;border:none;cursor:pointer;font-size:13px;font-weight:600;text-align:center}
.dl-btn:hover{background:#0070e0}
@media(prefers-color-scheme:light){body{background:#f2f2f7}.panel{background:#fff;border-color:#d1d1d6}.layer-bar{background:#f2f2f7;border-color:#d1d1d6}.layer-btn{background:#e5e5ea;color:#1c1c1e}.kv-val{color:#333}.kv-key{color:#666}.json-pre{background:#f8f8f8;color:#333}}
</style></head>
<body>
<script>var _wfJSON="\(escapeJSDouble(workflowJSON))";</script>
<div class="img-pane">
  <div class="layer-bar" id="layerBar"></div>
  <div class="img-wrap"><img id="mainImg" src=""></div>
</div>
<div class="panel">
  <div class="panel-body">
    <div style="margin-bottom:14px;border-radius:8px;overflow:hidden;background:#111;border:1px solid #3a3a3c">
      <canvas id="fp" width="600" height="220" style="width:100%;display:block"></canvas>
    </div>
    \(buildXMPContent(xmp))
    <button class="dl-btn" onclick="_dlJSON()">&#8595; Download Workflow JSON</button>
  </div>
</div>
<script>
var pages=[\(pagesJS)],names=[\(namesJS)],cur=0;
function init(){
  var bar=document.getElementById('layerBar');
  names.forEach(function(n,i){
    var b=document.createElement('button');
    b.className='layer-btn'+(i===0?' active':'');
    b.textContent=n;b.onclick=function(){select(i)};
    bar.appendChild(b);
  });
  select(0);
}
function select(i){
  cur=i;
  document.getElementById('mainImg').src='data:image/png;base64,'+pages[i];
  document.querySelectorAll('.layer-btn').forEach(function(b,j){b.classList.toggle('active',j===i);});
}
document.addEventListener('keydown',function(e){
  if(e.key==='ArrowLeft')select(Math.max(0,cur-1));
  else if(e.key==='ArrowRight')select(Math.min(pages.length-1,cur+1));
});
\(fingerprintFn())
\(downloadFn())
\(copyFn())
init();
renderFP('fp');
</script>
</body></html>
"""
        return Data(html.utf8)
    }

    // PNG/WebP: image left, Summary tab + combined Workflow tab right
    static func generateHTML(imageData: Data, chunks: [String: String], xmp: ComfyXMP? = nil, imageMIME: String = "image/png") -> Data {
        let b64 = imageData.base64EncodedString()
        let workflowJSON = chunks["workflow"] ?? chunks["prompt"] ?? xmp?.workflow ?? xmp?.prompt ?? "{}"
        let summary = extractSummary(from: workflowJSON)
        let summaryHTML = buildSummaryHTML(summary)
        let xmpContent = xmp.map { buildXMPContent($0) } ?? ""

        let html = """
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;display:flex;height:100vh;overflow:hidden;background:#1c1c1e;color:#f2f2f7}
.img-pane{flex:0 0 55%;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#000}
.img-pane img{max-width:100%;max-height:100%;object-fit:contain}
.panel{flex:1;display:flex;flex-direction:column;background:#2c2c2e;border-left:1px solid #3a3a3c;overflow:hidden}
.tabs{display:flex;border-bottom:1px solid #3a3a3c;flex-shrink:0}
.tab-btn{flex:1;padding:10px 0;background:#2c2c2e;color:#8e8e93;border:none;cursor:pointer;font-size:13px;font-weight:500;transition:all .15s}
.tab-btn.active{background:#0a84ff;color:#fff}
.tab-content{display:none;flex:1;overflow-y:auto;padding:16px}
.tab-content.active{display:block}
.kv-row{display:flex;gap:8px;padding:6px 0;border-bottom:1px solid #3a3a3c}
.kv-key{font-size:12px;color:#8e8e93;min-width:90px;font-weight:500;text-transform:uppercase;letter-spacing:.5px;flex-shrink:0}
.kv-val{font-size:13px;color:#f2f2f7;word-break:break-word;-webkit-user-select:text;user-select:text}
.kv-hash{font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;color:#60a5fa;flex:1}
.cp-btn{flex-shrink:0;background:none;border:1px solid #3a3a3c;border-radius:5px;color:#8e8e93;cursor:pointer;padding:2px 4px;display:flex;align-items:center;transition:border-color .15s,color .15s}
.cp-btn:hover{color:#f2f2f7;border-color:#8e8e93}
.cp-btn .ico-check{display:none}
.cp-btn.copied{border-color:#34d399;color:#34d399}
.cp-btn.copied .ico-clip{display:none}
.cp-btn.copied .ico-check{display:block}
.section-label{font-size:11px;color:#8e8e93;text-transform:uppercase;letter-spacing:.5px;font-weight:500;margin:12px 0 4px}
.prompt-box{margin-top:8px;padding:10px;background:#1c1c1e;border-radius:8px;font-size:12px;line-height:1.5;color:#d1d1d6;font-style:italic;-webkit-user-select:text;user-select:text}
.json-pre{background:#1c1c1e;color:#d1d1d6;font-family:"SF Mono",Menlo,Monaco,monospace;font-size:11px;line-height:1.5;white-space:pre-wrap;word-break:break-word;border-radius:8px;padding:12px;-webkit-user-select:text;user-select:text}
.dl-btn{display:block;width:100%;margin-top:16px;padding:10px;border-radius:8px;background:#0a84ff;color:#fff;border:none;cursor:pointer;font-size:13px;font-weight:600;text-align:center}
.dl-btn:hover{background:#0070e0}
@media(prefers-color-scheme:light){body{background:#f2f2f7}.panel{background:#fff;border-color:#d1d1d6}.tab-btn{background:#f2f2f7;color:#1c1c1e}.tab-btn.active{background:#007aff;color:#fff}.kv-val{color:#333}.kv-key{color:#666}.prompt-box{background:#e5e5ea;color:#333}.json-pre{background:#f8f8f8;color:#333}}
</style></head>
<body>
<script>var _wfJSON="\(escapeJSDouble(workflowJSON))";</script>
<div class="img-pane"><img src="data:\(imageMIME);base64,\(b64)"></div>
<div class="panel">
  <div class="tabs">
    <button class="tab-btn active" onclick="show('sum',this)">Summary</button>
    <button class="tab-btn" onclick="show('wf',this)">Workflow</button>
  </div>
  <div id="sum" class="tab-content active">\(summaryHTML)</div>
  <div id="wf" class="tab-content">
    <div style="margin-bottom:14px;border-radius:8px;overflow:hidden;background:#111;border:1px solid #3a3a3c">
      <canvas id="fp" width="600" height="220" style="width:100%;display:block"></canvas>
    </div>
    \(xmpContent)
    <button class="dl-btn" onclick="_dlJSON()">&#8595; Download Workflow JSON</button>
  </div>
</div>
<script>
function show(id,btn){
  document.querySelectorAll('.tab-content').forEach(function(e){e.classList.remove('active');});
  document.querySelectorAll('.tab-btn').forEach(function(e){e.classList.remove('active');});
  document.getElementById(id).classList.add('active');
  btn.classList.add('active');
  if(id==='wf')renderFP('fp');
}
\(fingerprintFn())
\(downloadFn())
\(copyFn())
</script>
</body></html>
"""
        return Data(html.utf8)
    }

    // Named JS function renderFP(cid) — reads from _wfJSON global, lazy-safe (called when canvas is visible)
    private static func fingerprintFn() -> String {
"""
function renderFP(cid){
  try{
    var wf=JSON.parse(_wfJSON),nodes=wf.nodes||[],links=wf.links||[];
    if(!nodes.length)return;
    var cv=document.getElementById(cid);if(!cv)return;
    var ctx=cv.getContext('2d'),W=cv.width,H=cv.height,pad=10;
    var nm={},x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
    nodes.forEach(function(n){
      if(!n.pos)return;
      var w=(n.size&&n.size[0])||100,h=(n.size&&n.size[1])||50;
      nm[n.id]={x:n.pos[0],y:n.pos[1],w:w,h:h,t:(n.type||'').toLowerCase()};
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
    nodes.forEach(function(n){
      var v=nm[n.id];if(!v)return;
      var t=v.t;
      ctx.fillStyle=t.includes('ksampler')?'#5b21b6':t.includes('loader')?'#1e40af':t.includes('clip')||t.includes('textencode')?'#9a3412':t.includes('save')||t.includes('preview')||t.includes('image')?'#065f46':t==='reroute'?'#27272a':'#44403c';
      ctx.fillRect(px(v.x),py(v.y),Math.max(v.w*sc,2),Math.max(v.h*sc,2));
    });
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

    // XMP fields inline content — author + models + extra
    private static func buildXMPContent(_ xmp: ComfyXMP) -> String {
        var html = ""
        if let author = xmp.author, !author.isEmpty {
            html += "<div class='kv-row'><span class='kv-key'>Author</span><span class='kv-val'>\(escapeHTML(author))</span></div>"
        }
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
        if let extra = xmp.extra, !extra.isEmpty {
            let pretty: String
            if let data = extra.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data),
               let p = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let s = String(data: p, encoding: .utf8) { pretty = escapeHTML(s) }
            else { pretty = escapeHTML(extra) }
            html += "<div class='section-label'>Extra</div><pre class='json-pre'>\(pretty)</pre>"
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
