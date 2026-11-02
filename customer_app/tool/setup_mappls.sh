#!/usr/bin/env bash
# Links the Mappls (MapmyIndia) Android SDK config into the app module.
#
# The config is a pair of secret files, <appId>.a.olf and <appId>.a.conf,
# bound to the app's package names and signing certificate in the Mappls
# console. They live outside the repo and are never committed (root and
# customer_app .gitignore). The mappls_gl Gradle plugin looks for them next
# to the app module, i.e. customer_app/android/app/.
#
# Usage (from anywhere):
#   customer_app/tool/setup_mappls.sh            # symlink (default)
#   customer_app/tool/setup_mappls.sh --copy     # copy instead (chmod 600)
#   customer_app/tool/setup_mappls.sh --remove   # remove the links/copies
#
# Source folder: $MAPPLS_CONFIG_DIR, default
# ~/.config/jivo-quick-commerce/mappls. Without the files the app still
# builds and shows a "map unavailable" fallback.
#
# The script prints file names only, never their contents.
set -euo pipefail

mode="link"
case "${1:-}" in
  "") ;;
  --copy) mode="copy" ;;
  --remove) mode="remove" ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  *) echo "Unknown option: $1 (use --copy, --remove or --help)" >&2; exit 2 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "$script_dir/.." && pwd)"
target_dir="$app_dir/android/app"
source_dir="${MAPPLS_CONFIG_DIR:-$HOME/.config/jivo-quick-commerce/mappls}"

if [[ "$mode" == "remove" ]]; then
  shopt -s nullglob
  removed=0
  for f in "$target_dir"/*.a.olf "$target_dir"/*.a.conf; do
    rm -f -- "$f"
    echo "Removed $(basename "$f")"
    removed=1
  done
  # Copies the mappls_gl Gradle plugin made from the config during builds:
  # without removing them, the next build would still embed the old config.
  for f in "$target_dir"/src/*/assets/mappls-conf.txt; do
    rm -f -- "$f"
    echo "Removed generated ${f#"$app_dir"/}"
    removed=1
  done
  generated="$app_dir/build/generated/res/mappls-flutter-services"
  if [[ -d "$generated" ]]; then
    rm -rf -- "$generated"
    echo "Removed generated build/generated/res/mappls-flutter-services"
    removed=1
  fi
  [[ $removed == 1 ]] || echo "Nothing to remove in $target_dir"
  exit 0
fi

if [[ ! -d "$source_dir" ]]; then
  echo "Mappls config folder not found: $source_dir" >&2
  echo "Set MAPPLS_CONFIG_DIR or create it with the .a.olf/.a.conf pair." >&2
  exit 1
fi

shopt -s nullglob
olf_files=("$source_dir"/*.a.olf)
if [[ ${#olf_files[@]} -ne 1 ]]; then
  echo "Expected exactly one *.a.olf in $source_dir, found ${#olf_files[@]}." >&2
  exit 1
fi
olf="${olf_files[0]}"
conf="${olf%.a.olf}.a.conf"
if [[ ! -f "$conf" ]]; then
  echo "Missing $(basename "$conf") next to $(basename "$olf") in $source_dir" >&2
  exit 1
fi

# Refuse to place secrets where git would pick them up.
if git -C "$app_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  for name in "$(basename "$olf")" "$(basename "$conf")"; do
    if ! git -C "$app_dir" check-ignore -q "android/app/$name"; then
      echo "android/app/$name is not gitignored; refusing to continue." >&2
      exit 1
    fi
  done
fi

# Only one config pair may sit next to the module (the plugin takes the
# first *.a.olf it finds).
for f in "$target_dir"/*.a.olf "$target_dir"/*.a.conf; do
  rm -f -- "$f"
done

for src in "$olf" "$conf"; do
  dest="$target_dir/$(basename "$src")"
  if [[ "$mode" == "copy" ]]; then
    install -m 600 "$src" "$dest"
  else
    ln -s "$src" "$dest"
  fi
  if [[ "$mode" == "copy" ]]; then verb="Copied"; else verb="Linked"; fi
  echo "$verb $(basename "$src") -> android/app/"
done
echo "Done. Rebuild the app (flutter clean is not needed)."
