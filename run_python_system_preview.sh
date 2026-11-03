#!/bin/bash
# Python-first menu preview; saves stay in build/system_tools/python_card.img.
set -e
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec .venv/bin/python tools/python_system_preview.py "$@"
