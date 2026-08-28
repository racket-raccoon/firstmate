#!/usr/bin/env bash
set -eu

root=${1:?usage: verify-codex-harness-ancestry.sh <firstmate-root>}
fixture=$(mktemp -d "${TMPDIR:-/tmp}/fm-codex-ancestry-evidence.XXXXXX")
trap 'find "$fixture" -depth -delete' EXIT

fakebin="$fixture/fakebin"
home="$fixture/home"
mkdir -p "$fakebin" "$home/state"

cat > "$fakebin/ps" <<'SH'
#!/usr/bin/env bash
set -u
field=
pid=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) field=$2; shift 2 ;;
    -p) pid=$2; shift 2 ;;
    *) shift ;;
  esac
done
case "$pid:$field" in
  1:comm=) printf '%s\n' codex ;;
  1:args=) printf '%s\n' 'codex-linux-sandbox --sandbox-policy-cwd /repo' ;;
  1:ppid=) printf '%s\n' 0 ;;
  *:comm=) printf '%s\n' bash ;;
  *:args=) printf '%s\n' 'bash -c firstmate-tool-call' ;;
  *:ppid=) printf '%s\n' 1 ;;
esac
SH
chmod +x "$fakebin/ps"

base_path=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}

printf '$ bin/fm-harness.sh  # shell -> codex-linux-sandbox (PID 1)\n'
classification=$(env -u CLAUDECODE -u PI_CODING_AGENT -u FM_PI_HARNESS \
  -u GROK_AGENT -u CURSOR_AGENT -u CURSOR_INVOKED_AS \
  PATH="$fakebin:$base_path" "$root/bin/fm-harness.sh")
printf '%s\n' "$classification"
[ "$classification" = codex ]

printf '\n$ bin/fm-lock.sh  # same namespace-local PID-1 ancestry\n'
set +e
lock_output=$(env -u CLAUDECODE -u PI_CODING_AGENT -u FM_PI_HARNESS \
  -u GROK_AGENT -u CURSOR_AGENT -u CURSOR_INVOKED_AS \
  FM_HOME="$home" PATH="$fakebin:$base_path" "$root/bin/fm-lock.sh" 2>&1)
lock_status=$?
set -e
printf '%s\n' "$lock_output"
printf 'exit status: %s\n' "$lock_status"
[ "$lock_status" -eq 1 ]
[ ! -e "$home/state/.lock" ]

printf '\n$ bin/fm-lock.sh status\n'
FM_HOME="$home" PATH="$fakebin:$base_path" "$root/bin/fm-lock.sh" status

printf '\nResult: PID 1 classifies Codex for display/supervision selection, but is not persisted as session-lock ownership.\n'
