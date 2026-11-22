#!/usr/bin/env bash
# Packs every module directory into <module>.zip for Magisk.
# usage: ./build.sh [module...]   (default: all modules)
set -euo pipefail
cd "$(dirname "$0")"
mods=("$@")
[[ ${#mods[@]} -gt 0 ]] || mapfile -t mods < <(find . -mindepth 2 -maxdepth 2 -name module.prop -printf '%h\n' | sed 's#^\./##' | sort)
mkdir -p out
for m in "${mods[@]}"; do
  [[ -f $m/module.prop ]] || { echo "no module.prop in $m" >&2; exit 1; }
  rm -f "out/$m.zip"
  (cd "$m" && zip -qr -X "../out/$m.zip" .)
  echo "out/$m.zip"
done
