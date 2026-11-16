import Foundation

struct FortuneQuote: Codable {
    let id: String
    let english: String
}

struct FortuneLibrary: Decodable {
    let quotes: [FortuneQuote]
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let libraryURL = root.appendingPathComponent("Sources/MorningFolder/Resources/fortunes.json")
let outputURL = root.appendingPathComponent("Docs/fortune-review.html")
let library = try JSONDecoder().decode(FortuneLibrary.self, from: Data(contentsOf: libraryURL))
let quoteData = try JSONEncoder().encode(library.quotes)
let quoteJSON = String(data: quoteData, encoding: .utf8)!

let document = """
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Morning · Fortune Cookie 内容审阅</title>
  <style>
    :root { --ink:#11110d; --muted:#726f66; --line:#e7e3d9; --canvas:#f1efe8; --paper:#fffefa; --accent:#20201c; --warm:#eee9dc; }
    * { box-sizing:border-box; }
    body { margin:0; background:var(--canvas); color:var(--ink); font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif; }
    header { position:sticky; top:0; z-index:10; background:rgba(241,239,232,.94); backdrop-filter:blur(16px); border-bottom:1px solid var(--line); padding:28px max(28px,calc((100vw - 1240px)/2)); }
    h1 { margin:0; font-size:24px; letter-spacing:-.5px; } p { margin:7px 0 0; color:var(--muted); font-size:13px; }
    .toolbar { display:flex; gap:10px; align-items:center; margin-top:20px; flex-wrap:wrap; }
    input[type=search] { width:320px; max-width:100%; border:1px solid var(--line); border-radius:10px; background:var(--paper); padding:10px 12px; color:var(--ink); font:14px inherit; outline:none; }
    input[type=search]:focus, textarea:focus { border-color:#888276; box-shadow:0 0 0 3px rgba(95,89,76,.12); }
    label { color:var(--muted); font-size:13px; display:flex; gap:7px; align-items:center; }
    button { border:0; border-radius:10px; background:var(--accent); color:#fff; padding:10px 13px; font:600 13px inherit; cursor:pointer; }
    button.secondary { background:var(--warm); color:var(--ink); } button:hover { filter:brightness(.95); }
    #count { margin-left:auto; color:var(--muted); font-size:13px; }
    main { width:min(1240px,calc(100% - 56px)); margin:26px auto 64px; }
    .columns, .row { display:grid; grid-template-columns:104px minmax(300px,1fr) minmax(300px,1fr); gap:18px; }
    .columns { color:var(--muted); font-size:12px; font-weight:700; letter-spacing:.08em; padding:0 16px 10px; }
    .row { background:var(--paper); border:1px solid var(--line); border-radius:15px; padding:17px 16px; margin-bottom:10px; align-items:start; box-shadow:0 8px 20px rgba(36,32,23,.035); }
    .id { color:var(--muted); font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace; padding-top:3px; }
    .english { font:500 15px/1.5 Georgia,"Times New Roman",serif; }
    textarea { display:block; width:100%; min-height:92px; resize:vertical; border:1px solid var(--line); border-radius:10px; background:#fbfaf5; padding:11px 12px; color:var(--ink); font:14px/1.55 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif; outline:none; }
    .empty { padding:46px; text-align:center; color:var(--muted); }
    @media (max-width:760px) { header { padding:22px 18px; } main { width:calc(100% - 28px); margin-top:18px; } .columns { display:none; } .row { grid-template-columns:1fr; gap:12px; } .id { padding:0; } #count { width:100%; margin-left:0; } }
  </style>
</head>
<body>
  <header>
    <h1>Fortune Cookie 内容审阅</h1>
    <p>左侧是当前英文 quote；右侧写下替换文本、删改建议或备注。输入会自动保存在此浏览器。</p>
    <div class="toolbar">
      <input id="search" type="search" placeholder="搜索编号或英文…">
      <label><input id="changedOnly" type="checkbox"> 仅看已修改</label>
      <button class="secondary" id="copy">复制修改清单</button>
      <button id="download">下载修改清单</button>
      <button class="secondary" id="clear">清空本机修改</button>
      <span id="count"></span>
    </div>
  </header>
  <main>
    <div class="columns"><span>编号</span><span>Quote（English）</span><span>修改输入</span></div>
    <div id="rows"></div>
  </main>
  <script>
    const quotes = \(quoteJSON);
    const storageKey = 'morning-fortune-review-v3-english';
    const notes = JSON.parse(localStorage.getItem(storageKey) || '{}');
    const rows = document.getElementById('rows');
    const search = document.getElementById('search');
    const changedOnly = document.getElementById('changedOnly');
    const count = document.getElementById('count');
    function changedEntries() { return quotes.filter(q => (notes[q.id] || '').trim()).map(q => ({ id:q.id, english:q.english, change:notes[q.id].trim() })); }
    function persist() { localStorage.setItem(storageKey, JSON.stringify(notes)); }
    function render() {
      const term = search.value.trim().toLowerCase();
      const filtered = quotes.filter(q => {
        const matches = !term || [q.id,q.english].join(' ').toLowerCase().includes(term);
        return matches && (!changedOnly.checked || (notes[q.id] || '').trim());
      });
      count.textContent = `显示 ${filtered.length} / ${quotes.length} 条 · 已修改 ${changedEntries().length} 条`;
      rows.replaceChildren();
      if (!filtered.length) { rows.innerHTML = '<div class="empty">没有符合条件的 quote。</div>'; return; }
      for (const q of filtered) {
        const row = document.createElement('article'); row.className = 'row';
        const id = document.createElement('div'); id.className = 'id'; id.textContent = q.id;
        const quote = document.createElement('div');
        const english = document.createElement('div'); english.className = 'english'; english.textContent = q.english;
        quote.append(english);
        const editor = document.createElement('textarea'); editor.placeholder = '例如：\\n替换为…\\n或写下修改原因'; editor.value = notes[q.id] || '';
        editor.addEventListener('input', () => { notes[q.id] = editor.value; persist(); count.textContent = `显示 ${filtered.length} / ${quotes.length} 条 · 已修改 ${changedEntries().length} 条`; });
        row.append(id, quote, editor); rows.append(row);
      }
    }
    search.addEventListener('input', render); changedOnly.addEventListener('change', render);
    document.getElementById('copy').addEventListener('click', async () => { const text = JSON.stringify(changedEntries(), null, 2); await navigator.clipboard.writeText(text); alert(`已复制 ${changedEntries().length} 条修改。`); });
    document.getElementById('download').addEventListener('click', () => { const blob = new Blob([JSON.stringify(changedEntries(), null, 2)], {type:'application/json'}); const link = document.createElement('a'); link.href = URL.createObjectURL(blob); link.download = 'morning-fortune-edits.json'; link.click(); URL.revokeObjectURL(link.href); });
    document.getElementById('clear').addEventListener('click', () => { if (confirm('确定清空这台设备上所有尚未导出的修改吗？')) { Object.keys(notes).forEach(key => delete notes[key]); persist(); render(); } });
    render();
  </script>
</body>
</html>
"""

try document.write(to: outputURL, atomically: true, encoding: .utf8)
print("Wrote review page for \(library.quotes.count) fortunes to \(outputURL.path)")
