#!/bin/bash
# Install (or update) this skill into Hermes Agent: ~/.hermes/skills/finance/credit-report-pull
# Usage: scripts/install_hermes.sh [hermes_home]   (default: $HERMES_HOME or ~/.hermes)
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
HH="${1:-${HERMES_HOME:-$HOME/.hermes}}"
DEST="$HH/skills/finance/credit-report-pull"
[ -d "$HH" ] || { echo "Hermes home not found: $HH" >&2; exit 1; }
mkdir -p "$DEST"
rsync -a --delete --exclude .git --exclude .DS_Store --exclude '*.pdf' "$SRC/" "$DEST/"
chmod +x "$DEST"/scripts/*.sh
echo "installed credit-report-pull -> $DEST"
command -v op >/dev/null || echo "note: 1Password CLI (op) not found - brew install 1password-cli" >&2
python3 -c "import playwright" 2>/dev/null || echo "note: run: python3 -m pip install playwright" >&2
