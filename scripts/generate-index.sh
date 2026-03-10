#!/usr/bin/env bash
# generate-index.sh — Create a clean HTML landing page for the APT repo
set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-your-github-username}"
REPO_SLUG="${GITHUB_REPOSITORY:-your-github-username/rustdesk-apt}"
REPO_NAME="${REPO_SLUG##*/}"
PAGES_URL="https://${REPO_OWNER}.github.io/${REPO_NAME}"
UPDATED=$(date -u '+%Y-%m-%d %H:%M UTC')

mkdir -p docs

cat > docs/index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>RustDesk APT Repository</title>
  <style>
    :root {
      --bg: #0d1117; --surface: #161b22; --border: #30363d;
      --text: #c9d1d9; --muted: #8b949e; --accent: #58a6ff;
      --green: #3fb950; --yellow: #d29922; --code-bg: #1c2128;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg); color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      line-height: 1.6; padding: 2rem 1rem;
    }
    .container { max-width: 860px; margin: 0 auto; }
    header { border-bottom: 1px solid var(--border); padding-bottom: 1.5rem; margin-bottom: 2rem; }
    h1 { font-size: 1.8rem; color: #e6edf3; }
    h1 span { color: var(--accent); }
    .badge {
      display: inline-block; padding: .2em .6em; border-radius: 2em;
      font-size: .75rem; font-weight: 600; margin-left: .5rem;
      background: #238636; color: #fff;
    }
    h2 { font-size: 1.15rem; color: #e6edf3; margin: 1.8rem 0 .8rem; }
    p { color: var(--muted); margin-bottom: .8rem; }
    .card {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 8px; padding: 1.25rem 1.5rem; margin-bottom: 1.2rem;
    }
    .card-title { font-weight: 600; color: #e6edf3; margin-bottom: .6rem; }
    pre {
      background: var(--code-bg); border: 1px solid var(--border);
      border-radius: 6px; padding: 1rem 1.2rem; overflow-x: auto;
      font-size: .875rem; color: #e6edf3; margin: .5rem 0;
    }
    code { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; }
    .comment { color: var(--muted); }
    .step { display: flex; gap: .75rem; align-items: flex-start; margin-bottom: .5rem; }
    .step-num {
      min-width: 1.6rem; height: 1.6rem; border-radius: 50%;
      background: var(--accent); color: #fff;
      display: flex; align-items: center; justify-content: center;
      font-size: .8rem; font-weight: 700; margin-top: .15rem;
    }
    .arch-table { width: 100%; border-collapse: collapse; font-size: .875rem; }
    .arch-table th, .arch-table td {
      padding: .5rem .75rem; text-align: left;
      border-bottom: 1px solid var(--border);
    }
    .arch-table th { color: var(--muted); font-weight: 600; }
    .ok { color: var(--green); } .warn { color: var(--yellow); }
    footer { margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid var(--border);
      font-size: .8rem; color: var(--muted); }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    .warn-box {
      background: #2d1f00; border: 1px solid #6e4c00;
      border-radius: 6px; padding: .75rem 1rem; margin: 1rem 0;
      font-size: .875rem; color: #e3b341;
    }
  </style>
</head>
<body>
<div class="container">
  <header>
    <h1>🖥️ <span>RustDesk</span> APT Repository <span class="badge">v${VERSION}</span></h1>
    <p style="margin-top:.5rem">
      Unofficial APT mirror — automatically synced from
      <a href="https://github.com/rustdesk/rustdesk/releases">github.com/rustdesk/rustdesk</a>.
      Last updated: <strong>${UPDATED}</strong>.
    </p>
  </header>

  <h2>Quick Install</h2>
  <div class="card">
    <div class="card-title">One-liner (recommended)</div>
    <pre><code>curl -fsSL ${PAGES_URL}/rustdesk-apt.gpg | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list
sudo apt update && sudo apt install rustdesk</code></pre>
  </div>

  <h2>Step-by-step Setup</h2>

  <div class="card">
    <div class="step">
      <div class="step-num">1</div>
      <div>
        <div class="card-title">Add the signing key</div>
        <pre><code>curl -fsSL ${PAGES_URL}/rustdesk-apt.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step">
      <div class="step-num">2</div>
      <div>
        <div class="card-title">Add the repository</div>
        <p>Choose the line matching your architecture:</p>
        <pre><code><span class="comment"># amd64 (x86-64)</span>
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list

<span class="comment"># arm64 (AArch64 / Raspberry Pi 64-bit)</span>
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list

<span class="comment"># armhf (ARMv7 32-bit)</span>
echo "deb [arch=armhf signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step">
      <div class="step-num">3</div>
      <div>
        <div class="card-title">Install RustDesk</div>
        <pre><code>sudo apt update && sudo apt install rustdesk</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step">
      <div class="step-num">4</div>
      <div>
        <div class="card-title">Keep RustDesk updated</div>
        <pre><code>sudo apt upgrade rustdesk</code></pre>
        <p style="margin-top:.4rem">Future releases will be automatically picked up by <code>apt upgrade</code>.</p>
      </div>
    </div>
  </div>

  <h2>Available Packages</h2>
  <div class="card">
    <table class="arch-table">
      <tr><th>Architecture</th><th>APT arch</th><th>Version</th><th>Status</th></tr>
      <tr><td>x86-64</td>    <td><code>amd64</code></td> <td>${VERSION}</td><td class="ok">✓ Available</td></tr>
      <tr><td>AArch64</td>   <td><code>arm64</code></td> <td>${VERSION}</td><td class="ok">✓ Available</td></tr>
      <tr><td>ARMv7</td>     <td><code>armhf</code></td> <td>${VERSION}</td><td class="ok">✓ Available</td></tr>
    </table>
  </div>

  <h2>No GPG key? (unsigned repo)</h2>
  <div class="warn-box">
    ⚠️ If this repository is not GPG-signed, add <code>trusted=yes</code> to your sources entry:
  </div>
  <pre><code>echo "deb [arch=amd64 trusted=yes] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>

  <h2>Repository Details</h2>
  <div class="card">
    <table class="arch-table">
      <tr><th>Property</th><th>Value</th></tr>
      <tr><td>Repository URL</td>   <td><a href="${PAGES_URL}">${PAGES_URL}</a></td></tr>
      <tr><td>Distribution</td>     <td><code>stable</code></td></tr>
      <tr><td>Component</td>        <td><code>main</code></td></tr>
      <tr><td>Current version</td>  <td><code>${VERSION}</code></td></tr>
      <tr><td>Source</td>           <td><a href="https://github.com/${REPO_SLUG}">github.com/${REPO_SLUG}</a></td></tr>
      <tr><td>Upstream releases</td><td><a href="https://github.com/rustdesk/rustdesk/releases">github.com/rustdesk/rustdesk/releases</a></td></tr>
    </table>
  </div>

  <footer>
    <p>
      This is an unofficial community mirror. RustDesk is developed by
      <a href="https://rustdesk.com">RustDesk Ltd</a> and licensed under AGPL-3.0.
      This mirror is not affiliated with the RustDesk project.
      &nbsp;·&nbsp;
      <a href="https://github.com/${REPO_SLUG}">View source on GitHub</a>
    </p>
  </footer>
</div>
</body>
</html>
HTMLEOF

echo "==> Landing page written to docs/index.html"