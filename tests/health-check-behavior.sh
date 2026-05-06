#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

cp "$repo_root/health-check.sh" "$workdir/health-check.sh"
cat > "$workdir/urls.cfg" <<'URLS'
测试站点=https://example.invalid
URLS
mkdir -p "$workdir/bin"
cat > "$workdir/bin/git" <<'GIT'
#!/usr/bin/env bash
case "$1 $2" in
  "remote get-url") echo "https://github.com/dingjiai/status.git" ;;
  "config --global") exit 0 ;;
  "add -A") exit 0 ;;
  "commit -m") exit 0 ;;
  "push ") exit 0 ;;
  *) exit 0 ;;
esac
GIT
cat > "$workdir/bin/curl" <<'CURL'
#!/usr/bin/env bash
exit 28
CURL
chmod +x "$workdir/bin/git" "$workdir/bin/curl"

run_check() {
  (cd "$workdir" && PATH="$workdir/bin:$PATH" bash ./health-check.sh >/dev/null)
}

run_check
grep -q 'suspected' "$workdir/logs/测试站点_report.log"
! grep -q 'failed' "$workdir/logs/测试站点_report.log"

run_check
suspected_count=$(grep -c 'suspected' "$workdir/logs/测试站点_report.log")
[ "$suspected_count" -eq 2 ]
! grep -q 'failed' "$workdir/logs/测试站点_report.log"

run_check
grep -q 'failed' "$workdir/logs/测试站点_report.log"
grep -q 'consecutive_failures=3' "$workdir/logs/测试站点_report.log"
