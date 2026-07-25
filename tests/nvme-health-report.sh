#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
report=$repo_root/bin/.local/bin/nvme-health-report
fixtures=$repo_root/tests/fixtures/nvme-health-report
tests_run=0
test_tmp_root=$repo_root/tmp
test_tmp_root_created=false

if [ ! -d "$test_tmp_root" ]; then
    mkdir "$test_tmp_root"
    test_tmp_root_created=true
fi

invalid_json_dir=$(mktemp -d "$test_tmp_root/nvme-health-report-test.XXXXXX")
leading_dash_dir=$invalid_json_dir/-snapshots
invalid_date_dir=$invalid_json_dir/invalid-date

cleanup()
{
    rm -f "$invalid_json_dir/2026-07-25T00-00-00Z.json"
    rm -f "$leading_dash_dir/2026-07-25T00-00-00Z.json"
    rm -f "$invalid_date_dir/2026-02-30T00-00-00Z.json"
    rmdir "$leading_dash_dir" "$invalid_date_dir"
    rmdir "$invalid_json_dir"

    if [ "$test_tmp_root_created" = true ]; then
        rmdir "$test_tmp_root"
    fi
}

trap cleanup EXIT HUP INT TERM

cp \
    "$fixtures/invalid-json/invalid-json.txt" \
    "$invalid_json_dir/2026-07-25T00-00-00Z.json"
mkdir "$leading_dash_dir" "$invalid_date_dir"
cp \
    "$fixtures/single/2026-07-25T00-00-00Z.json" \
    "$leading_dash_dir/2026-07-25T00-00-00Z.json"
cp \
    "$fixtures/single/2026-07-25T00-00-00Z.json" \
    "$invalid_date_dir/2026-02-30T00-00-00Z.json"

fail()
{
    echo "not ok $tests_run - $1" >&2
    exit 1
}

assert_contains()
{
    description=$1
    output=$2
    expected=$3
    tests_run=$((tests_run + 1))

    if printf '%s\n' "$output" | grep -F "$expected" >/dev/null; then
        echo "ok $tests_run - $description"
    else
        printf '%s\n' "$output" >&2
        fail "$description"
    fi
}

assert_equals()
{
    description=$1
    actual=$2
    expected=$3
    tests_run=$((tests_run + 1))

    if [ "$actual" = "$expected" ]; then
        echo "ok $tests_run - $description"
    else
        printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
        fail "$description"
    fi
}

assert_fails_with()
{
    description=$1
    directory=$2
    expected=$3
    tests_run=$((tests_run + 1))

    if output=$("$report" "$directory" 2>&1); then
        printf '%s\n' "$output" >&2
        fail "$description"
    fi

    if printf '%s\n' "$output" | grep -F "$expected" >/dev/null; then
        echo "ok $tests_run - $description"
    else
        printf '%s\n' "$output" >&2
        fail "$description"
    fi
}

help_output=$("$report" --help)
assert_contains \
    "help documents the source-directory contract" \
    "$help_output" \
    "usage: nvme-health-report <snapshot-directory>"
assert_contains \
    "help documents reset markers" \
    "$help_output" \
    "RESET   a monotonic counter regressed"
assert_contains \
    "help documents the snapshot filename contract" \
    "$help_output" \
    "YYYY-MM-DDTHH-MM-SSZ.json"
assert_contains \
    "help documents output columns" \
    "$help_output" \
    "WRITE_GB_DAY"

header=$(printf 'TIMESTAMP\tTEMP_C\tTOTAL_WRITTEN_GB\tINTERVAL_H\tWRITE_GB_DAY\tUSED_PCT\tCRITICAL_WARNING\tMEDIA_ERRORS\tUNSAFE_SHUTDOWNS\tERROR_LOG_ENTRIES\tWARNING_TEMP_TIME\tCRITICAL_TEMP_TIME')
single_output=$("$report" "$fixtures/single")
single_expected=$(printf '%s\n%s' \
    "$header" \
    "$(printf '2026-07-25T00-00-00Z\t43.9\t512\t-\t-\t0\t-\t-\t-\t-\t-\t-')")
assert_equals \
    "single snapshot output is exact" \
    "$single_output" \
    "$single_expected"

irregular_output=$("$report" "$fixtures/irregular")
irregular_expected=$(printf '%s\n%s\n%s\n%s' \
    "$header" \
    "$(printf '2026-07-25T00-00-00Z\t43.9\t512\t-\t-\t0\t-\t-\t-\t-\t-\t-')" \
    "$(printf '2026-07-25T12-00-00Z\t44.9\t512.512\t12\t1.024\t1\t0->1\t0\t0\t0\t0\t0')" \
    "$(printf '2026-07-27T00-00-00Z\t45.9\t514.048\t36\t1.024\t1\t0\t+2\t+1\t+3\t+4\t+5')")
assert_equals \
    "irregular snapshots produce exact sorted output" \
    "$irregular_output" \
    "$irregular_expected"

reset_output=$("$report" "$fixtures/reset")
reset_expected=$(printf '%s\n%s\n%s' \
    "$header" \
    "$(printf '2026-07-25T00-00-00Z\t43.9\t512\t-\t-\t10\t-\t-\t-\t-\t-\t-')" \
    "$(printf '2026-07-26T00-00-00Z\t43.9\t0.512\t24\tRESET\t0\t1->0\tRESET\tRESET\tRESET\tRESET\tRESET')")
assert_equals \
    "counter resets produce exact output" \
    "$reset_output" \
    "$reset_expected"

leading_dash_output=$(
    CDPATH= cd "$invalid_json_dir"
    "$report" -snapshots
)
assert_equals \
    "a leading-dash directory is treated as a path" \
    "$leading_dash_output" \
    "$single_expected"

assert_fails_with \
    "a missing field names the offending file" \
    "$fixtures/missing-field" \
    "2026-07-25T00-00-00Z.json: missing field: media_errors"
assert_fails_with \
    "invalid JSON names the offending file" \
    "$invalid_json_dir" \
    "2026-07-25T00-00-00Z.json"
assert_fails_with \
    "an invalid filename is rejected" \
    "$fixtures/invalid-filename" \
    "snapshot.json: invalid snapshot filename"
assert_fails_with \
    "an impossible calendar date is rejected" \
    "$invalid_date_dir" \
    "2026-02-30T00-00-00Z.json: invalid timestamp"

echo "1..$tests_run"

trap - EXIT HUP INT TERM
cleanup
