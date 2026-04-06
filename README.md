# Personal APT Repository

Multi-app APT repository hosted on GitHub Pages. Mirrors `.deb` packages from upstream GitHub releases for easy installation via `apt`.

## Included Apps

| App | Upstream | Architectures |
|-----|----------|---------------|
| [RustDesk](https://rustdesk.com) | [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk) | amd64, arm64, armhf |
| [Mattermost Desktop](https://mattermost.com) | [mattermost/desktop](https://github.com/mattermost/desktop) | amd64, arm64 |

## How it works

```
apps.json (app definitions)
        ↓
  GitHub Actions
  ┌──────────────────────────────────────┐
  │ 1. Check each app for new releases   │
  │ 2. Download .deb → docs/pool/        │
  │ 3. dpkg-scanpackages → Packages.gz   │
  │ 4. Generate Release + InRelease      │
  │ 5. Deploy to GitHub Pages            │
  └──────────────────────────────────────┘
        ↓
  https://babico.github.io/apt-packages
```

**Auto-bootstrap:** on the very first push (when tracking files are empty), the workflow automatically downloads **all** historical releases for every app. No manual trigger needed.

---

## Using this repository

### Quick setup

```bash
curl -fsSL https://babico.github.io/apt-packages/apt-repo.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/personal-apt.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/personal-apt.gpg] \
  https://babico.github.io/apt-packages stable main" \
  | sudo tee /etc/apt/sources.list.d/personal-apt.list

sudo apt update
```

### Install apps

```bash
sudo apt install rustdesk
sudo apt install mattermost-desktop
```

### Install a specific version

```bash
sudo apt install rustdesk=1.4.5
sudo apt install mattermost-desktop=6.1.0
```

### Hold / downgrade

```bash
sudo apt-mark hold rustdesk            # prevent upgrades
sudo apt install rustdesk=1.4.4        # downgrade
sudo apt-mark unhold rustdesk          # re-enable upgrades
```

---

## Adding a new app

1. Edit `apps.json` and add a new entry:

```json
{
  "name": "my-app",
  "display_name": "My App",
  "description": "Description of the app",
  "homepage": "https://example.com",
  "github_repo": "owner/repo",
  "pool_letter": "m",
  "architectures": {
    "amd64": "amd64.deb"
  },
  "download_url": "https://example.com/releases/${VERSION}/my-app_${VERSION}_${SUFFIX}",
  "deb_pattern": "my-app_${VERSION}_${SUFFIX}",
  "version_prefix": "v"
}
```

2. Push to `main` — the workflow will auto-detect the new app and download all releases.

---

## Setting up your own fork

### 1. Fork this repo

```bash
gh repo create apt-packages --public --clone
```

### 2. Enable GitHub Pages

Settings → Pages → Source: **GitHub Actions**

### 3. (Optional) GPG signing

```bash
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: Personal APT Mirror
Name-Email: noreply@example.com
Expire-Date: 0
EOF

gpg --armor --export-secret-keys "Personal APT Mirror" > private.key
gpg --armor --export "Personal APT Mirror" > docs/apt-repo.gpg
git add docs/apt-repo.gpg && git commit -m "add gpg pubkey"
```

Add these secrets in Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `GPG_PRIVATE_KEY` | Content of `private.key` |
| `GPG_PASSPHRASE` | Key passphrase (blank if `%no-protection`) |

### 4. Push — bootstrap runs automatically

```bash
git push origin main
```

---

## Workflow inputs (manual dispatch)

| Input | Default | Description |
|-------|---------|-------------|
| `force_rebuild` | false | Re-index without re-downloading |
| `backfill` | false | Force re-fetch all historical versions for all apps |
| `backfill_limit` | 0 | Limit backfill count per app (0 = all) |
| `specific_app` | — | Target a single app by name |
| `specific_version` | — | Add a single version (requires `specific_app`) |

---

## Storage

Each app version varies in size. GitHub Pages soft limit: **1 GB**.
Use `backfill_limit` to stay under if needed.

> Note: `.deb` files are in `docs/pool/` which is **gitignored** — they are downloaded fresh on each CI run and never committed to git history.

---

## Repository structure

```
apps.json                          # App definitions (name, URL patterns, archs)
tracked_versions/
  rustdesk.json                    # Per-app version tracking
  mattermost-desktop.json
scripts/
  download-debs.sh                 # Generic .deb downloader (reads apps.json)
  update-tracked-versions.sh       # Per-app version tracker
  build-repo.sh                    # APT index builder (all apps)
  generate-index.sh                # HTML landing page generator
docs/
  pool/main/{letter}/{app}/        # .deb files (gitignored)
  dists/stable/                    # APT metadata
  index.html                       # Landing page
  apt-repo.gpg                     # GPG public key
```

---

MIT license. Upstream projects retain their own licenses.