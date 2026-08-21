#!/usr/bin/env node
// CLI wrapper for yzane/vscode-markdown-pdf: shims the `vscode` module so the
// extension bundle (dist/extension.js) runs headless under plain Node.
//
// Usage:
//   markdown-pdf-cli [--type pdf|html|png|jpeg|all] [--settings file.json] [-o outdir] <file.md>...
//
// Env:
//   MARKDOWN_PDF_EXT_ROOT      path to the built vscode-markdown-pdf checkout (required unless default exists)
//   MARKDOWN_PDF_CLI_SETTINGS  path to a JSON settings file (VS Code flat keys or nested)

'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const Module = require('module');
const { pathToFileURL, fileURLToPath } = require('url');

// ---------- argv ----------
const argv = process.argv.slice(2);
const files = [];
let optType = 'pdf';
let settingsPath = process.env.MARKDOWN_PDF_CLI_SETTINGS || '';
let outputDir = '';
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  const nextValue = () => {
    const v = argv[++i];
    if (v === undefined) { console.error('error: ' + a + ' requires a value. See --help'); process.exit(2); }
    return v;
  };
  if (a === '--type' || a === '-t') { optType = nextValue(); }
  else if (a === '--settings' || a === '-s') { settingsPath = nextValue(); }
  else if (a === '--output-dir' || a === '-o') { outputDir = nextValue(); }
  else if (a === '--help' || a === '-h') {
    console.log('Usage: markdown-pdf-cli [--type pdf|html|png|jpeg|all|pdf,html,...] [--settings file.json] [-o outdir] <file.md>...');
    console.log('Exit codes: 0 success, 1 export error, 2 usage/settings error, 3 completed with warnings');
    process.exit(0);
  } else if (a.startsWith('-')) {
    console.error('error: unknown option ' + a + '. See --help');
    process.exit(2);
  } else { files.push(a); }
}
if (files.length === 0) {
  console.error('error: no input files. See --help');
  process.exit(2);
}

const EXT_ROOT = process.env.MARKDOWN_PDF_EXT_ROOT
  || path.join(os.homedir(), '.cache', 'markdown-pdf-cli', 'vscode-markdown-pdf');
const DIST = path.join(EXT_ROOT, 'dist', 'extension.js');
if (!fs.existsSync(DIST)) {
  console.error('error: extension bundle not found: ' + DIST);
  console.error('Set MARKDOWN_PDF_EXT_ROOT to a built checkout of yzane/vscode-markdown-pdf.');
  process.exit(2);
}

// ---------- configuration (defaults from package.json + user settings) ----------
const extPkg = JSON.parse(fs.readFileSync(path.join(EXT_ROOT, 'package.json'), 'utf8'));
function flatDefaults() {
  const conf = extPkg.contributes && extPkg.contributes.configuration;
  const props = {};
  const entries = Array.isArray(conf) ? conf : [conf];
  for (const e of entries) Object.assign(props, (e && e.properties) || {});
  const flat = {};
  for (const [k, v] of Object.entries(props)) flat[k] = v.default;
  return flat;
}
function stripJsonComments(s) {
  // Two character-by-character passes that track string state, so template
  // values like "<style>/* centered */</style>" or "page // total" survive
  // intact. Comments go first, trailing commas second: the common VS Code
  // pattern of a comment between a comma and its bracket ("v", // note \n })
  // only reads as a trailing comma once the comment is gone
  let noComments = '';
  let inString = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (inString) {
      noComments += c;
      if (c === '\\') { noComments += s[++i] ?? ''; continue; }
      if (c === '"') inString = false;
      continue;
    }
    if (c === '"') { inString = true; noComments += c; continue; }
    if (c === '/' && s[i + 1] === '/') { while (i < s.length && s[i] !== '\n') i++; noComments += '\n'; continue; }
    if (c === '/' && s[i + 1] === '*') { i += 2; while (i < s.length && !(s[i] === '*' && s[i + 1] === '/')) i++; i++; continue; }
    noComments += c;
  }
  let out = '';
  inString = false;
  for (let i = 0; i < noComments.length; i++) {
    const c = noComments[i];
    if (inString) {
      out += c;
      if (c === '\\') { out += noComments[++i] ?? ''; continue; }
      if (c === '"') inString = false;
      continue;
    }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === ',') {
      // trailing comma: look past whitespace for a closing bracket
      let j = i + 1;
      while (j < noComments.length && /\s/.test(noComments[j])) j++;
      if (noComments[j] === '}' || noComments[j] === ']') continue;
    }
    out += c;
  }
  return out;
}
function loadUserSettings(p) {
  if (!p) return {};
  const raw = fs.readFileSync(p, 'utf8');
  let json;
  // strict JSON first so valid input is never rewritten; fall back to comment
  // stripping only when plain parsing fails (JSONC-style settings)
  try { json = JSON.parse(raw); }
  catch { json = JSON.parse(stripJsonComments(raw)); }
  if (json === null || typeof json !== 'object' || Array.isArray(json)) {
    // guard: a scalar/array top level would flatten into meaningless keys and
    // silently leave every default untouched
    throw new Error('settings must be a JSON object, got ' + (Array.isArray(json) ? 'array' : typeof json));
  }
  const flat = {};
  const flatten = (obj, prefix) => {
    for (const [k, v] of Object.entries(obj)) {
      const key = prefix ? prefix + '.' + k : k;
      const isPlainObject = v !== null && typeof v === 'object' && !Array.isArray(v);
      // The extension schema has object-valued leaves only at depth >= 4
      // (markdown-pdf.math.katex.macros); shallower objects are sections.
      // Flattening sections to dotted keys makes user values merge with the
      // dotted defaults per-key, like VS Code's deep-merge, instead of an
      // object value replacing a whole defaults subtree
      const isSection = isPlainObject && key.split('.').length < 4;
      if (isSection) flatten(v, key);
      else flat[key] = v;
    }
  };
  // top-level keys may be dotted ("markdown-pdf.format") or bare sections
  // ({"markdown-pdf": {...}}); flatten handles both via total key depth
  flatten(json, '');
  return flat;
}

const settings = flatDefaults();
try { Object.assign(settings, loadUserSettings(settingsPath)); }
catch (e) { console.error('error: failed to read settings ' + settingsPath + ': ' + e.message); process.exit(2); }

// CLI overrides
if (outputDir) {
  // upstream getOutputDir() only auto-creates "~"-prefixed or relative dirs;
  // absolute paths must exist beforehand
  const absOut = path.resolve(outputDir);
  fs.mkdirSync(absOut, { recursive: true });
  settings['markdown-pdf.outputDirectory'] = absOut;
}
if (optType.includes(',')) { settings['markdown-pdf.type'] = optType.split(',').map(s => s.trim()); optType = 'settings'; }

// default executablePath: prefer an installed Chrome when nothing configured,
// so no headless-chromium download is needed
if (!settings['markdown-pdf.executablePath']) {
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
  ];
  const found = candidates.find(p => fs.existsSync(p));
  if (found) settings['markdown-pdf.executablePath'] = found;
}

function sectionConfig(section) {
  // build nested object for a section from flat dotted keys
  const out = {};
  const prefix = section + '.';
  for (const [k, v] of Object.entries(settings)) {
    if (!k.startsWith(prefix)) continue;
    const parts = k.slice(prefix.length).split('.');
    let cur = out;
    for (let i = 0; i < parts.length - 1; i++) cur = (cur[parts[i]] = cur[parts[i]] || {});
    cur[parts[parts.length - 1]] = v;
  }
  Object.defineProperty(out, 'get', {
    enumerable: false,
    value: (key, dflt) => {
      let cur = out;
      for (const p of key.split('.')) {
        if (cur == null || typeof cur !== 'object') return dflt;
        cur = cur[p];
      }
      return cur === undefined ? dflt : cur;
    },
  });
  return out;
}

// ---------- vscode shim ----------
class Uri {
  constructor(scheme, fsPath, raw) { this.scheme = scheme; this.fsPath = fsPath; this._raw = raw; }
  static file(p) { return new Uri('file', path.resolve(p)); }
  static parse(s) {
    const m = /^([a-z][a-z0-9+.-]*):/i.exec(s);
    const scheme = m ? m[1].toLowerCase() : '';
    if (scheme === 'file') { try { return new Uri('file', fileURLToPath(s), s); } catch { return new Uri('file', s.replace(/^file:\/\//, ''), s); } }
    return new Uri(scheme, s, s);
  }
  toString() { return this.scheme === 'file' ? pathToFileURL(this.fsPath).toString() : (this._raw || this.fsPath); }
}

let exitCode = 0;
let warnCount = 0;
const log = (level, msg) => console.error(`[${level}] ${msg}`);

const vscodeShim = {
  version: extPkg.engines && extPkg.engines.vscode ? extPkg.engines.vscode.replace('^', '') + '-cli' : 'cli',
  Uri,
  ProgressLocation: { Notification: 15 },
  Disposable: class { dispose() {} },
  workspace: {
    getConfiguration: (section) => sectionConfig(section || ''),
    // cwd is the CLI's workspace root: without this, upstream resolves relative
    // outputDirectory/styles (relativePathFile=false) against the md file's own
    // directory instead of the project root like VS Code does
    getWorkspaceFolder: (resource) => {
      const root = process.cwd();
      const isUnderRoot = resource && typeof resource.fsPath === 'string'
        && (resource.fsPath === root || resource.fsPath.startsWith(root + path.sep));
      if (!isUnderRoot) return undefined;
      return { uri: Uri.file(root), name: path.basename(root), index: 0 };
    },
    onDidSaveTextDocument: () => ({ dispose() {} }),
  },
  window: {
    activeTextEditor: undefined, // set per file below
    showInformationMessage: (m) => { log('info', m); return Promise.resolve(undefined); },
    // warnings never flip exit 1 (sanitize summary etc. fire on successful
    // exports), but every warning — toast or channel — bumps warnCount and
    // surfaces as exit 3, because some mark degraded output (INCLUDE ERROR,
    // KaTeX <code> fallback, missing stylesheet) that exit 0 would hide
    showWarningMessage: (m) => { log('warn', m); warnCount++; return Promise.resolve(undefined); },
    showErrorMessage: (m) => { log('error', m); exitCode = 1; return Promise.resolve(undefined); },
    setStatusBarMessage: (m) => { if (m) log('status', m.replace(/^\$\([a-z-]+\) /, '')); return { dispose() {} }; },
    withProgress: (opts, task) => { if (opts && opts.title) log('info', opts.title); return Promise.resolve(task({ report() {} })); },
    createOutputChannel: () => ({
      info: (m) => log('info', m),
      warn: (m) => { log('warn', m); warnCount++; },
      error: (m) => { log('error', m); exitCode = 1; },
      show() {}, dispose() {},
    }),
  },
  commands: {
    _registry: new Map(),
    registerCommand(id, fn) { vscodeShim.commands._registry.set(id, fn); return { dispose() {} }; },
    executeCommand() { return Promise.resolve(); },
  },
  env: {
    language: (process.env.LANG || 'en-US').split('.')[0].replace('_', '-'),
    openExternal: () => Promise.resolve(true),
  },
};

// intercept require('vscode')
const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === 'vscode') return vscodeShim;
  return origLoad.call(this, request, parent, isMain);
};

// ---------- fake ExtensionContext + activate ----------
const cacheDir = path.join(os.homedir(), '.cache', 'markdown-pdf-cli', 'chromium');
fs.mkdirSync(cacheDir, { recursive: true });
const context = {
  subscriptions: { push() {} },
  globalStorageUri: { fsPath: cacheDir },
  globalStoragePath: cacheDir,
  extension: { packageJSON: extPkg },
};

const ext = require(DIST);
// suppress activation-time Chromium auto-download: upstream's fire-and-forget
// init() would race the export-time resolver for the same cache dir, and its
// network errors would flip exit 1 even for HTML-only runs that never need a
// browser. installChromium() checks autoDownload synchronously before
// activate() returns, and the export-time resolver re-reads the setting, so
// restoring it right after keeps first-run downloads working (once, lazily)
const userAutoDownload = settings['markdown-pdf.chromium.autoDownload'];
settings['markdown-pdf.chromium.autoDownload'] = false;
ext.activate(context);
settings['markdown-pdf.chromium.autoDownload'] = userAutoDownload;

// ---------- run ----------
(async () => {
  const command = vscodeShim.commands._registry.get('extension.markdown-pdf.' + optType);
  if (!command) {
    console.error('error: unknown type "' + optType + '" (pdf|html|png|jpeg|all|settings)');
    process.exit(2);
  }
  for (const f of files) {
    const abs = path.resolve(f);
    if (!fs.existsSync(abs)) { log('error', 'no such file: ' + abs); exitCode = 1; continue; }
    vscodeShim.window.activeTextEditor = {
      document: {
        uri: Uri.file(abs),
        fileName: abs,
        languageId: 'markdown',
        isUntitled: false,
        getText: () => fs.readFileSync(abs, 'utf8'),
      },
    };
    await command();
  }
  // no process.exit() here: upstream's exportHtml() uses an un-awaited
  // callback fs.writeFile, and a hard exit kills the pending write (0-byte
  // .html); letting the event loop drain flushes it. The final exit code is
  // computed in the 'exit' handler below, AFTER those late callbacks ran —
  // a write failure reported after this line must still yield exit 1.
  // Failsafe: upstream gives up on a stuck browser.close() after 5s and only
  // logs, leaving a live Chromium that pins the event loop forever. The
  // unref'd timer never delays a clean exit, but force-exits a pinned one
  // (the 'exit' handler still computes the real code).
  setTimeout(() => {
    log('warn', 'forced exit: a stray handle (likely Chromium) kept the process alive');
    process.exit();
  }, 30_000).unref();
})().catch((e) => { console.error(e); exitCode = 1; });

process.on('exit', () => {
  // assigning here would clobber explicit process.exit(2) usage errors with 0,
  // so only override when there is actually an error/warning to surface
  const computed = exitCode || (warnCount > 0 ? 3 : 0);
  if (computed !== 0) process.exitCode = computed;
});
