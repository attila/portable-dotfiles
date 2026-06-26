#!/bin/sh

set -u

fail() {
    printf 'nono node shim smoke test failed: %s\n' "$1" >&2
    exit 1
}

script_dir="$(cd "$(dirname "$0")" && pwd)"
wrapper_dir="${script_dir}/bin"
wrapper="${wrapper_dir}/node"
bootstrap="${script_dir}/proxy-bootstrap.mjs"
module_home="$(cd "${script_dir}/../../.." && pwd)"

[ -x "$wrapper" ] || fail "expected executable wrapper at ${wrapper}"
[ -r "$bootstrap" ] || fail "expected readable proxy bootstrap at ${bootstrap}"

path_without_wrapper=""
old_ifs=$IFS
IFS=:
for dir in $PATH; do
    [ "$dir" = "$wrapper_dir" ] && continue
    [ -z "$path_without_wrapper" ] \
        && path_without_wrapper="$dir" \
        || path_without_wrapper="${path_without_wrapper}:$dir"
done
IFS=$old_ifs

if ! PATH="$path_without_wrapper" command -v node >/dev/null 2>&1; then
    printf 'nono node shim smoke test skipped: node is not installed or not on PATH after removing %s\n' "$wrapper_dir"
    exit 0
fi

plain_node_options="$(
    HOME="$module_home" \
    PATH="${wrapper_dir}:${path_without_wrapper}" \
    HTTPS_PROXY= \
    https_proxy= \
    NODE_OPTIONS= \
    "$wrapper" -p 'process.env.NODE_OPTIONS || ""'
)" || fail "wrapper could not start node without HTTPS_PROXY"

[ -z "$plain_node_options" ] \
    || fail "wrapper injected NODE_OPTIONS without HTTPS_PROXY: ${plain_node_options}"

proxy_node_options="$(
    HOME="$module_home" \
    PATH="${wrapper_dir}:${path_without_wrapper}" \
    HTTPS_PROXY="http://127.0.0.1:9" \
    https_proxy= \
    NODE_OPTIONS= \
    "$wrapper" -p 'process.env.NODE_OPTIONS || ""'
)" || fail "wrapper could not start node with HTTPS_PROXY"

expected_import="--import=${bootstrap}"
case "$proxy_node_options" in
    *"$expected_import"*) ;;
    *)
        fail "wrapper did not inject ${expected_import}; got: ${proxy_node_options}"
        ;;
esac

printf 'nono node shim smoke test passed: transparent without HTTPS_PROXY, injects proxy bootstrap with HTTPS_PROXY\n'
