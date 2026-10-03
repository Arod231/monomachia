// The small piece of Markdown the plan and spec use: paragraphs, headings,
// nested "-" lists, checkboxes, **bold**, *italic*, `code` and [links](url).
// Everything is escaped first; links are kept only for http(s), # and relative URLs.
export function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// Browsers ignore control characters around (and inside) a URL scheme, so any of them means "not safe".
const SAFE_URL = (u) => !/[\u0000-\u0020\u007f-\u009f]/.test(u)
  && (/^https?:\/\//i.test(u) || u.startsWith('#') || !/^[a-z][a-z0-9+.-]*:/i.test(u));

const emphasis = (s) => s
  .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
  .replace(/(^|[^*\w])\*([^*\s][^*]*?)\*(?!\*)/g, '$1<em>$2</em>');

function inline(text) {
  return String(text).split(/(`[^`]+`)/).map((part) => {
    if (/^`[^`]+`$/.test(part)) return `<code>${escapeHtml(part.slice(1, -1))}</code>`;
    // Links become placeholders first, so emphasis markers in a URL can't rewrite the href.
    const links = [];
    const withSlots = escapeHtml(part).replace(/\[([^\]]+)\]\(((?:[^()\s]|\([^()\s]*\))+)\)/g, (_, t, u) => {
      links.push(SAFE_URL(u) ? `<a href="${u}">${emphasis(t)}</a>` : emphasis(t));
      return `\u0000${links.length - 1}\u0000`;
    });
    return emphasis(withSlots).replace(/\u0000(\d+)\u0000/g, (_, i) => links[Number(i)]);
  }).join('');
}

function item(text) {
  const m = text.match(/^\[([ xX])\]\s+(.*)$/);
  if (!m) return inline(text);
  return `<input type="checkbox" disabled${m[1] === ' ' ? '' : ' checked'}> ${inline(m[2])}`;
}

export function renderMarkdown(src) {
  const lines = String(src ?? '').replace(/[\r\u0000]/g, '').split('\n');
  let html = '';
  let para = [];
  const stack = []; // indents of the open lists, each with an open <li>
  const flush = () => { if (para.length) { html += `<p>${inline(para.join(' '))}</p>`; para = []; } };
  const closeAll = () => { while (stack.length) { html += '</li></ul>'; stack.pop(); } };
  for (const line of lines) {
    if (!line.trim()) { flush(); continue; }
    const indent = line.match(/^\s*/)[0].length;
    const li = line.match(/^\s*[-*]\s+(.*)$/);
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) { flush(); closeAll(); html += `<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`; continue; }
    if (li) {
      flush();
      if (!stack.length || indent > stack.at(-1)) { html += '<ul>'; stack.push(indent); }
      else {
        while (stack.length > 1 && indent < stack.at(-1)) { html += '</li></ul>'; stack.pop(); }
        html += '</li>';
      }
      html += `<li>${item(li[1])}`;
      continue;
    }
    if (stack.length && indent > 0) { html += ` ${inline(line.trim())}`; continue; }
    closeAll();
    para.push(line.trim());
  }
  flush();
  closeAll();
  return html;
}
