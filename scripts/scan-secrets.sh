#!/usr/bin/env bash
# Scan files for credentials / personal data before they reach the public repo.
#   scan-secrets.sh FILE...      scan the given files
#   scan-secrets.sh --staged     scan the staged version of every staged file
# Optional personal denylist (one extended-regex per line, NOT tracked here):
#   ~/.config-private/denylist.txt
# Exit 1 if anything matches.
set -u

patterns=(
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'AKIA[0-9A-Z]{16}'
  'gh[pousr]_[A-Za-z0-9]{30,}'
  'github_pat_[A-Za-z0-9_]{30,}'
  'xox[abprs]-[A-Za-z0-9-]{10,}'
  'sk-ant-[A-Za-z0-9_-]{10,}'
  'sk-[A-Za-z0-9]{32,}'
  'xai-[A-Za-z0-9]{30,}'
  'AIza[0-9A-Za-z_-]{35}'
  'eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}\.'
  '(api_?key|secret|token|passw(or)?d)[A-Za-z_]*["'"'"']? *[:=] *["'"'"'][A-Za-z0-9+/_=.-]{20,}["'"'"']'
)
denylist="$HOME/.config-private/denylist.txt"
[[ -f $denylist ]] && while IFS= read -r l; do
  [[ -n $l && $l != \#* ]] && patterns+=("$l")
done < "$denylist"

# Build one alternation; -I skips binaries.
re=$(IFS='|'; echo "${patterns[*]}")
fail=0

scan() { # label, stdin
  # X's published OAuth worked-example values; not real credentials.
  [[ $1 == quickshell/x-hub/tests/test_xhub.py ]] && return 0
  local hits
  hits=$(grep -nIEi -e "$re" | cut -c1-80) || true
  if [[ -n $hits ]]; then
    # Never echo matched text (it may be the secret): report location only.
    echo "SECRET/PERSONAL-DATA PATTERN in $1 (line numbers: $(echo "$hits" | cut -d: -f1 | head -5 | tr '\n' ' '))"
    fail=1
  fi
}

if [[ ${1:-} == --staged ]]; then
  while IFS= read -r -d '' f; do
    scan "$f" < <(git show ":$f" 2>/dev/null)
  done < <(git diff --cached --name-only --diff-filter=ACM -z)
else
  for f in "$@"; do [[ -f $f ]] && scan "$f" < "$f"; done
fi
exit $fail
