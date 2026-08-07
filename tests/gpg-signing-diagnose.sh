#!/bin/sh
set -u

repo_root=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
diagnose=$repo_root/bin/.local/bin/gpg-signing-diagnose
mock_command=$repo_root/tests/fixtures/gpg-signing-diagnose/mock-command
tests_run=0
failures=0
test_tmp_root=$repo_root/tmp
test_tmp_root_created=false

if [ ! -d "$test_tmp_root" ]; then
    mkdir "$test_tmp_root"
    test_tmp_root_created=true
fi

work=$(mktemp -d "$test_tmp_root/gpg-signing-diagnose-test.XXXXXX")
mock_bin=$work/bin
limited_bin=$work/limited-bin
mock_log=$work/commands.log
hang_pid_file=$work/hang.pid
agent_socket=$work/S.gpg-agent
socket_fixture_pid=
mkdir "$mock_bin" "$limited_bin"
: > "$mock_log"

/usr/bin/nc -lU "$agent_socket" >/dev/null 2>&1 &
socket_fixture_pid=$!
fixture_ticks=0
while [ ! -S "$agent_socket" ] && [ "$fixture_ticks" -lt 50 ]; do
    sleep 0.1
    fixture_ticks=$((fixture_ticks + 1))
done
kill "$socket_fixture_pid" 2>/dev/null || :
wait "$socket_fixture_pid" 2>/dev/null || :
socket_fixture_pid=

if [ ! -S "$agent_socket" ]; then
    printf '%s\n' "gpg-signing-diagnose.sh: failed to create socket fixture" >&2
    exit 1
fi

cleanup()
{
    if [ -n "$socket_fixture_pid" ]; then
        kill "$socket_fixture_pid" 2>/dev/null || :
        wait "$socket_fixture_pid" 2>/dev/null || :
    fi
    rm -f "$mock_bin/git" "$mock_bin/gpg" "$mock_bin/gpg-format" \
        "$mock_bin/gpgconf" "$mock_bin/gpg-connect-agent" \
        "$mock_bin/uname" "$mock_bin/pgrep" "$mock_bin/lsof" \
        "$mock_bin/sleep" "$mock_log" "$hang_pid_file" "$agent_socket"
    rm -f "$limited_bin/date" "$limited_bin/sed" "$limited_bin/ls" \
        "$limited_bin/stat" "$limited_bin/cat"
    rmdir "$mock_bin" "$limited_bin" "$work"

    if [ "$test_tmp_root_created" = true ]; then
        rmdir "$test_tmp_root"
    fi
}

trap cleanup EXIT HUP INT TERM

for command_name in git gpg gpg-format gpgconf gpg-connect-agent uname pgrep lsof sleep; do
    ln -s "$mock_command" "$mock_bin/$command_name"
done
for command_path in /bin/date /usr/bin/sed /bin/ls /usr/bin/stat /bin/cat; do
    ln -s "$command_path" "$limited_bin/${command_path##*/}"
done

assert_contains()
{
    description=$1
    actual=$2
    expected=$3
    tests_run=$((tests_run + 1))

    if printf '%s\n' "$actual" | grep -F "$expected" >/dev/null; then
        printf 'ok %s - %s\n' "$tests_run" "$description"
    else
        printf '%s\n' "$actual" >&2
        printf 'not ok %s - %s\n' "$tests_run" "$description" >&2
        failures=$((failures + 1))
    fi
}

if [ ! -x "$diagnose" ]; then
    printf 'gpg-signing-diagnose.sh: helper not executable at %s\n' \
        "$diagnose" >&2
    exit 1
fi

output=$(PATH="$mock_bin:/usr/bin:/bin" MOCK_LOG="$mock_log" \
    MOCK_FORMAT_PROGRAM=gpg-format GNUPGHOME=/test/gnupg \
    MOCK_AGENT_SOCKET="$agent_socket" GPG_TTY=/dev/ttys001 "$diagnose" 2>&1)
status=$?

assert_contains "diagnostic exits successfully" "$status" "0"
assert_contains \
    "output includes a paste-ready prompt" \
    "$output" \
    "Diagnose this GPG commit-signing failure from the evidence below."
assert_contains \
    "raw socket probe is reported" \
    "$output" \
    "agent_probe_exit=0"
assert_contains \
    "failed signing probe is reported" \
    "$output" \
    "signing_probe_exit=2"
assert_contains \
    "signing probe failure output is retained" \
    "$output" \
    "[GNUPG:] FAILURE sign test"
assert_contains \
    "reachable agent is classified" \
    "$output" \
    "agent_classification=agent-reachable"
assert_contains \
    "listener exit status is direct" \
    "$output" \
    "agent_socket_lsof_exit=0"

command_log=$(cat "$mock_log")
assert_contains \
    "agent probe addresses the existing socket directly" \
    "$command_log" \
    "$(printf 'gpg-connect-agent\t--raw-socket\t%s' "$agent_socket")"
assert_contains \
    "signing probe forbids agent autostart" \
    "$command_log" \
    "$(printf 'gpg-format\t--no-autostart\t--status-fd=2\t-bsau\tTEST-SIGNING-KEY')"
assert_contains \
    "format-specific program takes precedence" \
    "$command_log" \
    "$(printf 'git\tconfig\t--get\tgpg.openpgp.program')"

: > "$mock_log"
dead_output=$(PATH="$mock_bin:/usr/bin:/bin" MOCK_LOG="$mock_log" \
    MOCK_AGENT_MODE=unreachable MOCK_LISTENER_MODE=none \
    MOCK_AGENT_SOCKET="$agent_socket" GNUPGHOME=/test/gnupg \
    "$diagnose" 2>&1)
assert_contains "failed raw probe retains its direct status" "$dead_output" \
    "agent_probe_exit=2"
assert_contains "absent listener retains lsof status" "$dead_output" \
    "agent_socket_lsof_exit=1"
assert_contains "orphaned socket is classified" "$dead_output" \
    "agent_classification=dead-agent-or-stale-socket"

: > "$mock_log"
binding_output=$(PATH="$mock_bin:/usr/bin:/bin" MOCK_LOG="$mock_log" \
    MOCK_AGENT_MODE=unreachable MOCK_LISTENER_MODE=listener \
    MOCK_AGENT_SOCKET="$agent_socket" GNUPGHOME=/test/gnupg \
    "$diagnose" 2>&1)
assert_contains "visible listener retains lsof status" "$binding_output" \
    "agent_socket_lsof_exit=0"
assert_contains "failed connection with listener is classified" "$binding_output" \
    "agent_classification=socket-access-or-binding"

rm -f "$mock_bin/pgrep" "$mock_bin/lsof"
unavailable_output=$(PATH="$mock_bin:$limited_bin" MOCK_LOG="$mock_log" \
    MOCK_AGENT_MODE=unreachable MOCK_AGENT_SOCKET="$agent_socket" \
    GNUPGHOME=/test/gnupg "$diagnose" 2>&1)
assert_contains "missing pgrep is explicit" "$unavailable_output" \
    "gpg_agent_pgrep_skipped=unavailable"
assert_contains "missing lsof is explicit" "$unavailable_output" \
    "agent_socket_lsof_skipped=unavailable"
assert_contains "missing listener tools stay ambiguous" "$unavailable_output" \
    "agent_classification=undetermined"
ln -s "$mock_command" "$mock_bin/pgrep"
ln -s "$mock_command" "$mock_bin/lsof"

: > "$mock_log"
linux_output=$(PATH="$mock_bin:/usr/bin:/bin" MOCK_LOG="$mock_log" \
    MOCK_OS=Linux MOCK_AGENT_MODE=unreachable MOCK_LISTENER_MODE=listener \
    MOCK_AGENT_SOCKET="$agent_socket" GNUPGHOME=/test/gnupg \
    "$diagnose" 2>&1)
assert_contains "Linux skips pgrep" "$linux_output" \
    "gpg_agent_pgrep_skipped=non-Darwin"
assert_contains "Linux skips lsof" "$linux_output" \
    "agent_socket_lsof_skipped=non-Darwin"
assert_contains "Linux failed probe remains unclassified" "$linux_output" \
    "agent_classification=undetermined"
linux_log=$(cat "$mock_log")
tests_run=$((tests_run + 1))
if printf '%s\n' "$linux_log" | grep -E '^(pgrep|lsof)' >/dev/null; then
    printf 'not ok %s - Linux invokes no listener inspection commands\n' "$tests_run" >&2
    failures=$((failures + 1))
else
    printf 'ok %s - Linux invokes no listener inspection commands\n' "$tests_run"
fi

tests_run=$((tests_run + 1))
if grep -F -- "--kill" "$mock_log" >/dev/null; then
    printf 'not ok %s - diagnostic does not kill the agent\n' "$tests_run" >&2
    failures=$((failures + 1))
else
    printf 'ok %s - diagnostic does not kill the agent\n' "$tests_run"
fi

: > "$mock_log"
timeout_output=$(PATH="$mock_bin:/usr/bin:/bin" MOCK_LOG="$mock_log" \
    MOCK_SIGNING_MODE=hang MOCK_HANG_PID_FILE="$hang_pid_file" \
    MOCK_AGENT_SOCKET="$agent_socket" GNUPGHOME=/test/gnupg \
    GPG_TTY=/dev/ttys001 "$diagnose" 2>&1)
timeout_status=$?

assert_contains "timeout diagnostic exits successfully" "$timeout_status" "0"
assert_contains \
    "hung signing probe is bounded" \
    "$timeout_output" \
    "probe_timeout=10s"

tests_run=$((tests_run + 1))
hang_pid=$(cat "$hang_pid_file")
if kill -0 "$hang_pid" 2>/dev/null; then
    printf 'not ok %s - timed-out probe is reaped\n' "$tests_run" >&2
    failures=$((failures + 1))
else
    printf 'ok %s - timed-out probe is reaped\n' "$tests_run"
fi

printf '1..%s\n' "$tests_run"

if [ "$failures" -ne 0 ]; then
    exit 1
fi

trap - EXIT HUP INT TERM
cleanup
