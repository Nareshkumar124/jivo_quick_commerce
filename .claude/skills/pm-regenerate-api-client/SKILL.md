---
name: pm-regenerate-api-client
description: "Regenerate the Dart API client packages/jivo_api from backend/openapi/schema.yaml, on develop after a backend merge or inside an app worktree to unblock app work early, then pub get, the shared-version check and the customer contract_examples fixtures. Use whenever the API schema changed, an app agent needs new endpoints, or jivo_api/pubspec.lock look stale."
---

# Regenerate `jivo_api`

Generated code is never hand-edited. Needs Java 17 + python3 (the script downloads a pinned openapi-generator jar). Flutter is `/c/dev/flutter/bin/flutter` (the normal path has a space and breaks native-asset hooks). Don't run this while a `flutter build` is running in the same checkout.

## A. On develop (after a backend merge)
```bash
R=/c/jivo_projects/jivo_quick_commerce
cd $R/backend && unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
uv run python manage.py spectacular --file openapi/schema.yaml    # only if the merge didn't already carry a fresh export
git -C $R diff --stat -- backend/openapi/schema.yaml
PATH="/c/dev/flutter/bin:$PATH" bash $R/packages/tool/generate_api.sh
```
Then go to **C**. Commit on develop as `chore(api): regenerate jivo_api for <change>` (packages/jivo_api, any pubspec.lock changes, contract_examples.dart).

## B. Into an app worktree (backend not merged yet)
Use when the customer/rider agent needs the new contract before the backend branch merges.
```bash
W=$R/.worktrees/customer          # or rider
cp $R/.worktrees/<backend-wt>/backend/openapi/schema.yaml $W/backend/openapi/schema.yaml
PATH="/c/dev/flutter/bin:$PATH" bash $W/packages/tool/generate_api.sh
```
- The worktree's script reads the worktree's schema and writes the worktree's `packages/jivo_api`.
- **Leave `backend/openapi/schema.yaml` out of the app commit**: before committing, `git -C $W checkout -- backend/openapi/schema.yaml`. The backend branch owns it.
- When the backend later merges, regenerate on develop (A); the app branch's `jivo_api` should then match (no diff, or CRLF only).

## C. After generating (both cases)
```bash
for d in packages/jivo_api packages/jivo_core customer_app rider_app; do
  (cd $ROOT/$d && /c/dev/flutter/bin/flutter pub get --enforce-lockfile) || echo "LOCK DRIFT in $d"
done
cd $ROOT && python3 packages/tool/check_shared_versions.py
```
(`ROOT` = `$R` or `$W`.) If `--enforce-lockfile` fails because the generated pubspec changed a dependency, run plain `flutter pub get` in that folder, then re-run the version check; all four lockfiles must agree and get committed (CI uses `--enforce-lockfile`).

Customer contract fixtures (needs PyYAML, so use the backend venv):
```bash
cd $ROOT/backend && uv run python ../customer_app/tool/gen_contract_examples.py
```
It rewrites `customer_app/test/fixtures/contract_examples.dart` from the `cart_*`, `orders_*` and `payments_razorpay_verify` examples.

Verify:
```bash
cd $ROOT/customer_app && /c/dev/flutter/bin/flutter analyze && /c/dev/flutter/bin/flutter test
cd $ROOT/rider_app    && /c/dev/flutter/bin/flutter analyze && /c/dev/flutter/bin/flutter test
```
Zero analyzer issues required. New enum values are safe (unknown-value fallback); removed/renamed fields break the apps: tell the owning app agent.

## Huge diff?
`core.autocrlf=true` often makes regeneration look like every file changed. Check the real size:
```bash
git -C $ROOT diff --ignore-cr-at-eol --stat -- packages/jivo_api | tail -3
```
or `git add packages/jivo_api && git diff --cached --stat` (staging normalises line endings). Review only the real changes before committing.
