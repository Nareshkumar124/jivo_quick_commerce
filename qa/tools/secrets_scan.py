"""Secrets scan of the git-TRACKED files at a commit (default HEAD). Read-only git plumbing.
Prints file:line and the rule only, never the matched value.

    cd qa && uv run python tools/secrets_scan.py [commit]
"""

from __future__ import annotations

import math
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RULES = {
    "private-key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
    "aws-access-key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "google-api-key": re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b"),
    "github-token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"),
    "slack-token": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"),
    "razorpay-key": re.compile(r"\brzp_(?:live|test)_[A-Za-z0-9]{10,}\b"),
    "jwt": re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
    "db-url-with-password": re.compile(r"\b(?:postgres(?:ql)?|redis|mysql)://[^\s:/@]+:[^\s@/]{3,}@"),
    "assigned-secret": re.compile(
        r"""(?i)\b(?:password|passwd|secret(?:_key)?|api_key|apikey|token|auth_key|private_key)\b\s*[:=]\s*["']([^"'\s]{8,})["']"""
    ),
}
SKIP_SUFFIX = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".ico", ".ttf", ".otf", ".jar", ".lock", ".pdf")
# Known, reviewed non-secrets (documented placeholders / dev-only fallbacks), path -> rule.
ALLOW = {
    ("backend/config/settings/local.py", "assigned-secret"),  # dev-only fallback key, see report
}


def entropy(s: str) -> float:
    counts = Counter(s)
    return -sum(c / len(s) * math.log2(c / len(s)) for c in counts.values())


def main() -> None:
    commit = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
    files = subprocess.run(
        ["git", "-C", str(REPO), "ls-tree", "-r", "--name-only", commit],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    env_files = [f for f in files if re.search(r"(^|/)\.env($|\.)", f) and not f.endswith(".example")]
    findings = []
    for path in files:
        if path.endswith(SKIP_SUFFIX) or "/generated/" in path:
            continue
        blob = subprocess.run(
            ["git", "-C", str(REPO), "show", f"{commit}:{path}"], capture_output=True
        ).stdout
        try:
            text = blob.decode()
        except UnicodeDecodeError:
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for rule, rx in RULES.items():
                m = rx.search(line)
                if not m:
                    continue
                value = m.group(1) if m.groups() else m.group(0)
                if rule == "assigned-secret" and (
                    entropy(value) < 3.0
                    or re.search(r"(?i)example|changeme|placeholder|dummy|xxx|redacted|your[-_]|<|\$\{|env\(|test", value)
                ):
                    continue
                allowed = (path, rule) in ALLOW
                findings.append((path, lineno, rule, allowed))
    print(f"commit {commit}: {len(files)} tracked files scanned")
    print(f"tracked .env files (non-example): {env_files or 'none'}")
    for path, lineno, rule, allowed in findings:
        print(f"{'ALLOWED ' if allowed else 'FINDING '}{path}:{lineno} [{rule}]")
    print(f"{sum(1 for f in findings if not f[3])} unreviewed finding(s), {sum(1 for f in findings if f[3])} allow-listed")


if __name__ == "__main__":
    main()
