#!/usr/bin/env bash
# Regenerates the Dart API client package `jivo_api` from the backend's
# OpenAPI contract `backend/openapi/schema.yaml` (decision D-13).
#
# Usage (works from any directory):
#   packages/tool/generate_api.sh [--schema PATH] [--out DIR]
#
#   --schema PATH  OpenAPI file to read. Default: backend/openapi/schema.yaml
#                  in the nearest ancestor directory of this script that has it.
#   --out DIR      package to regenerate. Default: ../jivo_api, relative to
#                  this script's directory (packages/jivo_api).
#
# Requirements: Java 11+ (17 recommended), python3 (standard library only),
# curl, sha256sum (or shasum), and Flutter on PATH.
#
# What it does:
#   1. Downloads the pinned openapi-generator-cli jar into the user cache
#      (verified by SHA-256) unless it is already there.
#   2. Converts the schema to JSON, applies normalize_openapi.py (collapses
#      same-type oneOf such as drf-spectacular's blank-allowed EmailField into
#      a plain string), then generates a `dart-dio` client with
#      json_serializable models into a temp dir. `format: decimal` is mapped
#      to String: money is never a double.
#      Enums get an unknown-value fallback, because additive API changes
#      (new enum values) are allowed in v1 and must not crash older apps.
#   3. Replaces DIR/lib and DIR/build.yaml with the generated ones and writes
#      DIR/pubspec.yaml (with `resolution: workspace` only if DIR is inside a
#      pub workspace; the repo has none). DIR/README.md and
#      DIR/analysis_options.yaml are project-owned and left alone.
#   4. Runs `flutter pub get` in DIR (respecting DIR/pubspec.lock), build_runner
#      for the `.g.dart` parts, `dart format`, and `flutter analyze` on DIR.
#      Afterwards run `flutter pub get` in each app that depends on jivo_api.
#
# Never hand-edit the generated package. Change the schema (backend) or this
# script, then regenerate.
#
# Using the client: pass the shared jivo_core Dio and an explicit interceptor
# list, otherwise the generated constructor adds its own auth interceptors to
# that Dio:
#   JivoApi(dio: dio, interceptors: const [])
set -euo pipefail

GENERATOR_VERSION="7.26.0"
GENERATOR_SHA256="1760050094997b9cc790cc1350be095f15da8c08a996b184d3eadc4ccda5e35e"
GENERATOR_URL="https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${GENERATOR_VERSION}/openapi-generator-cli-${GENERATOR_VERSION}.jar"

# Runtime dependencies the generated code imports. If a generator bump changes
# this set, the script fails below; update it and the pubspec template together.
EXPECTED_DEPENDENCIES="copy_with_extension dio json_annotation"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths are derived from this script's location, so the script keeps working
# if the repo moves.
SCHEMA=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
  if [[ -f "$search_dir/backend/openapi/schema.yaml" ]]; then
    SCHEMA="$search_dir/backend/openapi/schema.yaml"
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
OUT_DIR="$(dirname "$SCRIPT_DIR")/jivo_api"

die() { echo "generate_api.sh: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema) SCHEMA="${2:?--schema needs a path}"; shift 2 ;;
    --out) OUT_DIR="${2:?--out needs a directory}"; shift 2 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[[ -n "$SCHEMA" && -f "$SCHEMA" ]] || die "schema not found: ${SCHEMA:-backend/openapi/schema.yaml above $SCRIPT_DIR}"
[[ -f "$OUT_DIR/pubspec.yaml" ]] || die "not a package (no pubspec.yaml): $OUT_DIR"
SCHEMA="$(cd "$(dirname "$SCHEMA")" && pwd)/$(basename "$SCHEMA")"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

command -v java >/dev/null || die "java not found (Java 11+ required)"
command -v python3 >/dev/null || die "python3 not found"
command -v flutter >/dev/null || die "flutter not found on PATH"

# The pub workspace root is the nearest ancestor whose pubspec has
# `workspace:`. Without one, the package resolves on its own.
WORKSPACE_ROOT="$(dirname "$OUT_DIR")"
while [[ "$WORKSPACE_ROOT" != "/" ]] && ! grep -q '^workspace:' "$WORKSPACE_ROOT/pubspec.yaml" 2>/dev/null; do
  WORKSPACE_ROOT="$(dirname "$WORKSPACE_ROOT")"
done
if [[ "$WORKSPACE_ROOT" == "/" ]]; then
  PUB_ROOT="$OUT_DIR"
  RESOLUTION_LINE=""
else
  PUB_ROOT="$WORKSPACE_ROOT"
  RESOLUTION_LINE="resolution: workspace"
fi

sha256_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/jivo/openapi-generator"
JAR="${CACHE_DIR}/openapi-generator-cli-${GENERATOR_VERSION}.jar"
if [[ ! -f "$JAR" ]] || [[ "$(sha256_of "$JAR")" != "$GENERATOR_SHA256" ]]; then
  echo "Downloading openapi-generator-cli ${GENERATOR_VERSION}..."
  mkdir -p "$CACHE_DIR"
  curl -fsSL -o "${JAR}.part" "$GENERATOR_URL"
  [[ "$(sha256_of "${JAR}.part")" == "$GENERATOR_SHA256" ]] \
    || { rm -f "${JAR}.part"; die "checksum mismatch for the downloaded generator jar"; }
  mv "${JAR}.part" "$JAR"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
GEN_DIR="${TMP_DIR}/gen"

echo "Generating jivo_api from ${SCHEMA}..."
java -jar "$JAR" generate --input-spec "$SCHEMA" --generator-name openapi \
  --output "${TMP_DIR}/spec" > "${TMP_DIR}/convert.log" 2>&1 \
  || { cat "${TMP_DIR}/convert.log" >&2; die "could not read the schema"; }
python3 -I "${SCRIPT_DIR}/normalize_openapi.py" \
  "${TMP_DIR}/spec/openapi.json" "${TMP_DIR}/spec/normalized.json" \
  || die "normalize_openapi.py failed"

java -jar "$JAR" generate \
  --input-spec "${TMP_DIR}/spec/normalized.json" \
  --generator-name dart-dio \
  --output "$GEN_DIR" \
  --additional-properties=pubName=jivo_api,pubLibrary=jivo_api,serializationLibrary=json_serializable,enumUnknownDefaultCase=true \
  --type-mappings=decimal=String \
  --global-property=apiTests=false,modelTests=false,apiDocs=false,modelDocs=false \
  > "${TMP_DIR}/generator.log" 2>&1 \
  || { cat "${TMP_DIR}/generator.log" >&2; die "openapi-generator failed"; }

# Fail loudly if the generated code needs dependencies this script doesn't add.
GENERATED_DEPENDENCIES="$(awk '
  /^dependencies:/ { in_deps = 1; next }
  /^[^ #]/         { in_deps = 0 }
  in_deps && /^  [a-z_]+:/ { sub(":.*", "", $1); print $1 }
' "${GEN_DIR}/pubspec.yaml" | sort | tr '\n' ' ' | sed 's/ $//')"
[[ "$GENERATED_DEPENDENCIES" == "$EXPECTED_DEPENDENCIES" ]] || die \
  "generator ${GENERATOR_VERSION} needs dependencies [${GENERATED_DEPENDENCIES}] but this script adds [${EXPECTED_DEPENDENCIES}]; update the pubspec template"

rm -rf "${OUT_DIR}/lib"
cp -R "${GEN_DIR}/lib" "${OUT_DIR}/lib"
cp "${GEN_DIR}/build.yaml" "${OUT_DIR}/build.yaml"

# Generated code can't be fixed by hand, so style lints are silenced per file
# (the standard marker for generated code). Compile errors and other warnings
# still fail the analyze step below.
find "${OUT_DIR}/lib" -name '*.dart' -print0 | while IFS= read -r -d '' f; do
  { echo '// ignore_for_file: type=lint, unused_import, duplicate_ignore'; cat "$f"; } > "${f}.tmp"
  mv "${f}.tmp" "$f"
done

# cat -s drops the blank lines left when RESOLUTION_LINE is empty.
cat -s > "${OUT_DIR}/pubspec.yaml" <<PUBSPEC
# GENERATED by packages/tool/generate_api.sh. Do not edit by hand.
name: jivo_api
description: >-
  Dart API client and models for the Jivo Quick Commerce backend, generated
  from backend/openapi/schema.yaml. Do not edit by hand.
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.13.7
  flutter: ">=3.47.9"

${RESOLUTION_LINE}

dependencies:
  copy_with_extension: ^7.1.0
  dio: ^5.11.1
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.5.0
  copy_with_extension_gen: ^7.1.0
  flutter_lints: ^6.0.0
  json_serializable: ^6.9.3
PUBSPEC

echo "Resolving dependencies in ${PUB_ROOT}..."
(cd "$PUB_ROOT" && flutter pub get >/dev/null)

echo "Running build_runner..."
(cd "$OUT_DIR" && dart run build_runner build --delete-conflicting-outputs >/dev/null) \
  || die "build_runner failed (run it in ${OUT_DIR} to see why)"

dart format "${OUT_DIR}/lib" >/dev/null

echo "Analyzing jivo_api..."
(cd "$PUB_ROOT" && flutter analyze --no-pub "$OUT_DIR") \
  || die "generated client has analyzer issues"

echo "jivo_api regenerated from ${SCHEMA} (openapi-generator ${GENERATOR_VERSION})."
