#!/bin/bash
# Orphus AV - nightly cron wrapper: update signatures, scan, alert by exit code.
#
#   0 3 * * * /opt/orphus/cron-scan.sh
#
# Settings (env vars, or edit the defaults below):
#   SCAN_DIR    what to scan                        (default: /home)
#   MAIL_TO     where to send alerts; empty = syslog only (default: empty)
#   SCAN_ARGS   extra orphus-av.sh options          (default: -q --low-priority)
#   LOG_FILE    full console output of the last run (default: /var/log/orphus-last.log)
#
# Exit codes of orphus-av.sh:
#   0 clean -> silent (unless the signature update failed)
#   1 threats found -> alert "THREATS"
#   2 error or INCOMPLETE scan (bad option, no signatures/YARA, worker died,
#     a file YARA could not check) -> alert "INCOMPLETE": the result can't be
#     trusted as clean
#   other (130 = interrupted, ...) -> alert "ERROR"

SCAN_DIR="${SCAN_DIR:-/home}"
MAIL_TO="${MAIL_TO:-}"
SCAN_ARGS="${SCAN_ARGS:--q --low-priority}"
LOG_FILE="${LOG_FILE:-/var/log/orphus-last.log}"

AV="$(cd "$(dirname "$0")" && pwd)/orphus-av.sh"

"$AV" -u > "$LOG_FILE" 2>&1
upd=$?
# shellcheck disable=SC2086  # SCAN_ARGS is a list of options
"$AV" -d "$SCAN_DIR" $SCAN_ARGS >> "$LOG_FILE" 2>&1
rc=$?

case $rc in
    0) [ "$upd" -eq 0 ] && exit 0
       subject="Orphus AV: signature update FAILED on $(hostname) (exit $upd), scan was clean" ;;
    1) subject="Orphus AV: THREATS found on $(hostname) ($SCAN_DIR)" ;;
    2) subject="Orphus AV: scan INCOMPLETE or error on $(hostname) (exit 2)" ;;
    *) subject="Orphus AV: scan ERROR on $(hostname) (exit $rc)" ;;
esac
[ "$upd" -ne 0 ] && [ "$rc" -ne 0 ] && subject="$subject [signature update exit $upd]"

logger -t orphus-av "$subject -- see $LOG_FILE" 2>/dev/null
if [ -n "$MAIL_TO" ] && command -v mail >/dev/null 2>&1; then
    mail -s "$subject" "$MAIL_TO" < "$LOG_FILE"
fi
exit "$rc"
