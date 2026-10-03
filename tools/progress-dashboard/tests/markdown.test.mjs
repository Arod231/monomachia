import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderMarkdown as md, escapeHtml } from '../markdown.mjs';

test('escapes HTML everywhere', () => {
  assert.equal(escapeHtml(`<a href="x">'&`), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;');
  assert.equal(md('<script>alert(1)</script>'), '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>');
});

test('inline: bold, italic, code (no emphasis inside code), links', () => {
  assert.equal(md('**b** *i* `a*b*c`'), '<p><strong>b</strong> <em>i</em> <code>a*b*c</code></p>');
  assert.equal(md('[doc](#task-7.1)'), '<p><a href="#task-7.1">doc</a></p>');
  assert.equal(md('[x](https://e.com/a?b=1&c=2)'), '<p><a href="https://e.com/a?b=1&amp;c=2">x</a></p>');
});

test('unsafe link schemes are dropped to their text', () => {
  assert.equal(md('[x](javascript:alert(1))'), '<p>x</p>');
  assert.equal(md('[x](data:text/html,hi)'), '<p>x</p>');
});

test('nested lists, continuation lines and checkboxes', () => {
  const src = '- [ ] **7.1 Title.** Text\n  - Check: a\n    more\n  - Blocked by: none\n- [x] next';
  assert.equal(md(src),
    '<ul><li><input type="checkbox" disabled> <strong>7.1 Title.</strong> Text' +
    '<ul><li>Check: a more</li><li>Blocked by: none</li></ul></li>' +
    '<li><input type="checkbox" disabled checked> next</li></ul>');
});

test('paragraphs and headings', () => {
  assert.equal(md('one\ntwo\n\n### H'), '<p>one two</p><h3>H</h3>');
});

test('hostile inputs stay inert', () => {
  // A control character in front of the scheme is stripped by browsers, so it must not pass as "relative".
  assert.equal(md('[x](\u0001javascript:alert(1))'), '<p>x</p>');
  assert.equal(md('[x](\u0000javascript:alert(1))'), '<p>x</p>');
  assert.equal(md('[x](JaVaScRiPt:alert(1))'), '<p>x</p>');
  assert.equal(md('[x](vbscript:msgbox(1))'), '<p>x</p>');
  // A quote can't break out of the href attribute.
  assert.equal(md('[x](http://a/"onmouseover=alert(1))'), '<p><a href="http://a/&quot;onmouseover=alert(1)">x</a></p>');
  // Markup in link text and in headings and list items is escaped.
  assert.equal(md('[<img src=x onerror=alert(1)>](#a)'), '<p><a href="#a">&lt;img src=x onerror=alert(1)&gt;</a></p>');
  assert.equal(md('# <b>h</b>'), '<h1>&lt;b&gt;h&lt;/b&gt;</h1>');
  assert.equal(md('- <img src=x onerror=alert(1)>'), '<ul><li>&lt;img src=x onerror=alert(1)&gt;</li></ul>');
  // Emphasis markers inside a URL are left alone, so they can't rewrite the attribute.
  assert.equal(md('[x](http://a/**b**/*c*)'), '<p><a href="http://a/**b**/*c*">x</a></p>');
  // Entities written by hand are shown as text, not decoded.
  assert.equal(md('&lt;script&gt; &#106;avascript:'), '<p>&amp;lt;script&amp;gt; &amp;#106;avascript:</p>');
});
