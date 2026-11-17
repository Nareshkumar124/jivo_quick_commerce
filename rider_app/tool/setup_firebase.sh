#!/usr/bin/env bash
# Places the Firebase Android config (google-services.json) for a flavor.
#
# Every environment uses the same mechanism (D-19): the flavor's own
# android/app/src/<flavor>/google-services.json, which the google-services
# Gradle plugin turns into resources at build time. Only the file differs:
#
#   env      Firebase project        flavor   application id
#   dev      jivo-quick (dev)        dev      in.jivo.rider.dev
#   staging  (not created yet)       staging  in.jivo.rider.staging
#   prod     (not created yet)       prod     in.jivo.rider
#
# One google-services.json per Firebase project holds both apps (customer
# in.jivo.quick*, rider in.jivo.rider*); customer_app/tool/setup_firebase.sh
# copies the same file for the customer app.
#
# The files are private: they live outside the repo in
# ~/.config/jivo-quick-commerce/firebase/<env>/google-services.json (or
# $FIREBASE_CONFIG_DIR/<env>/) and are gitignored in the app. Without a
# flavor's file the app still builds and runs with push off.
#
# Usage (from anywhere):
#   rider_app/tool/setup_firebase.sh --copy                 # dev (default)
#   rider_app/tool/setup_firebase.sh --copy --env staging
#   rider_app/tool/setup_firebase.sh --copy --env all       # every env that has a file
#   rider_app/tool/setup_firebase.sh --remove [--env dev|staging|prod|all]
#
# The script prints file names only, never their contents. It never reads
# service-account.json (a server credential kept in the same folder).
set -euo pipefail

mode=""
env_name="dev"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy) mode="copy" ;;
    --remove) mode="remove" ;;
    --env)
      [[ $# -ge 2 ]] || { echo "--env needs a value: dev, staging, prod or all" >&2; exit 2; }
      env_name="$2"
      shift
      ;;
    --env=*) env_name="${1#--env=}" ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (use --copy, --remove, --env or --help)" >&2; exit 2 ;;
  esac
  shift
done
if [[ -z "$mode" ]]; then
  echo "Say what to do: --copy or --remove (see --help)." >&2
  exit 2
fi

case "$env_name" in
  dev|staging|prod) envs=("$env_name") ;;
  all) envs=(dev staging prod) ;;
  *) echo "Unknown env: $env_name (use dev, staging, prod or all)" >&2; exit 2 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "$script_dir/.." && pwd)"
config_root="${FIREBASE_CONFIG_DIR:-$HOME/.config/jivo-quick-commerce/firebase}"

# The flavor that uses an env's Firebase project (one flavor per env).
flavor_for() { echo "$1"; }

# The Android application id of a flavor (android/app/build.gradle.kts).
package_for() {
  case "$1" in
    dev) echo "in.jivo.rider.dev" ;;
    staging) echo "in.jivo.rider.staging" ;;
    prod) echo "in.jivo.rider" ;;
  esac
}

if [[ "$mode" == "remove" ]]; then
  for env in "${envs[@]}"; do
    flavor="$(flavor_for "$env")"
    dest="$app_dir/android/app/src/$flavor/google-services.json"
    if [[ -e "$dest" ]]; then
      rm -f -- "$dest"
      echo "Removed android/app/src/$flavor/google-services.json"
    else
      echo "Nothing to remove for the $flavor flavor"
    fi
  done
  echo "Done. Rebuild the app: flavors without a file build with push off."
  exit 0
fi

copied=0
for env in "${envs[@]}"; do
  flavor="$(flavor_for "$env")"
  src="$config_root/$env/google-services.json"
  rel="android/app/src/$flavor/google-services.json"
  dest="$app_dir/$rel"

  if [[ ! -f "$src" ]]; then
    if [[ "$env_name" == "all" ]]; then
      echo "Skipped $env: no $src"
      continue
    fi
    echo "Firebase config not found: $src" >&2
    echo "Download google-services.json for the $env Firebase project (Android" >&2
    echo "app $(package_for "$flavor")) and put it there, or set FIREBASE_CONFIG_DIR." >&2
    exit 1
  fi

  # The file must register this flavor's application id, or the Gradle
  # plugin fails ("No matching client found for package name").
  package="$(package_for "$flavor")"
  if ! grep -Eq "\"package_name\"[[:space:]]*:[[:space:]]*\"${package//./\\.}\"" "$src"; then
    echo "$src does not register the Android app $package; refusing to copy." >&2
    echo "Add that app to the $env Firebase project and download the file again." >&2
    exit 1
  fi

  # Refuse to place the file where git would pick it up.
  if git -C "$app_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    if ! git -C "$app_dir" check-ignore -q "$rel"; then
      echo "$rel is not gitignored; refusing to continue." >&2
      exit 1
    fi
  fi

  mkdir -p "$(dirname "$dest")"
  install -m 600 "$src" "$dest"
  echo "Copied $env google-services.json -> $rel"
  copied=1
done

if [[ $copied == 0 ]]; then
  echo "No Firebase config found under $config_root; nothing copied." >&2
  exit 1
fi
echo "Done. Rebuild the app (flutter clean is not needed)."
