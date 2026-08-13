# Cursor / VS Code integrated terminal: activate project .venv on every new shell.
# Used by .vscode/settings.json terminal profile "bash (venv)".
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source /etc/bash.bashrc 2>/dev/null || true
# shellcheck source=/dev/null
source "$HOME/.bashrc" 2>/dev/null || true
if [[ -f "$ROOT/.venv/bin/activate" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT/.venv/bin/activate"
fi
cd "$ROOT" || true
