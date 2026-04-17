#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
TOOL="$REPO_DIR/bin/req2pyproject.sh"

assert_file_contains() {
    file=$1
    needle=$2
    if ! grep -Fq "$needle" "$file"; then
        printf 'assertion failed: expected %s to contain %s\n' "$file" "$needle" >&2
        exit 1
    fi
}

assert_file_not_contains() {
    file=$1
    needle=$2
    if grep -Fq "$needle" "$file"; then
        printf 'assertion failed: expected %s to not contain %s\n' "$file" "$needle" >&2
        exit 1
    fi
}

assert_equals() {
    expected=$1
    actual=$2
    if [ "$expected" != "$actual" ]; then
        printf 'assertion failed: expected [%s], got [%s]\n' "$expected" "$actual" >&2
        exit 1
    fi
}

make_workspace() {
    fixture_name=$1
    workspace=$(mktemp -d "${TMPDIR:-/tmp}/req2pyproject-test.XXXXXX")
    cp -R "$FIXTURES_DIR/$fixture_name/." "$workspace/"
    printf '%s\n' "$workspace"
}

test_create_missing_pyproject() {
    workspace=$(make_workspace create_missing_pyproject)
    (
        cd "$workspace"
        "$TOOL"
    )

    assert_file_contains "$workspace/pyproject.toml" '[project]'
    assert_file_contains "$workspace/pyproject.toml" '"requests==2.31.0",'
    assert_file_contains "$workspace/pyproject.toml" '"flask>=2.3",'
    rm -rf "$workspace"
}

test_update_existing_dependencies() {
    workspace=$(make_workspace update_existing_dependencies)
    (
        cd "$workspace"
        "$TOOL"
    )

    assert_file_contains "$workspace/pyproject.toml" 'name = "demo"'
    assert_file_contains "$workspace/pyproject.toml" '"requests==2.31.0",'
    assert_file_contains "$workspace/pyproject.toml" '"urllib3<3",'
    assert_file_not_contains "$workspace/pyproject.toml" '"oldpkg==0.1",'
    rm -rf "$workspace"
}

test_preserve_unrelated_sections() {
    workspace=$(make_workspace preserve_unrelated_sections)
    (
        cd "$workspace"
        "$TOOL"
    )

    assert_file_contains "$workspace/pyproject.toml" '[build-system]'
    assert_file_contains "$workspace/pyproject.toml" 'requires = ["setuptools>=61"]'
    assert_file_contains "$workspace/pyproject.toml" '[tool.black]'
    assert_file_contains "$workspace/pyproject.toml" 'line-length = 88'
    assert_file_contains "$workspace/pyproject.toml" 'version = "0.1.0"'
    assert_file_contains "$workspace/pyproject.toml" '"click~=8.1",'
    rm -rf "$workspace"
}

test_skip_unsupported_specifiers() {
    workspace=$(make_workspace skip_unsupported_specifiers)
    stderr_file="$workspace/stderr.txt"
    (
        cd "$workspace"
        "$TOOL" 2>"$stderr_file"
    )

    assert_file_contains "$workspace/pyproject.toml" '"flask>=2.0",'
    assert_file_not_contains "$workspace/pyproject.toml" 'requests[security]'
    assert_file_not_contains "$workspace/pyproject.toml" 'git+https://example.com/pkg.git'
    warning_count=$(grep -c '^warning: skipping unsupported requirement line:' "$stderr_file")
    assert_equals '3' "$warning_count"
    rm -rf "$workspace"
}

test_dry_run_and_backup_flags() {
    workspace=$(make_workspace update_existing_dependencies)
    output_file="$workspace/stdout.txt"
    (
        cd "$workspace"
        "$TOOL" --dry-run --backup >"$output_file"
    )

    assert_file_contains "$output_file" '"requests==2.31.0",'
    assert_file_contains "$workspace/pyproject.toml" '"oldpkg==0.1",'
    if [ -e "$workspace/pyproject.toml.bak" ]; then
        printf 'assertion failed: dry-run should not create a backup file\n' >&2
        exit 1
    fi

    (
        cd "$workspace"
        "$TOOL" --backup
    )

    assert_file_contains "$workspace/pyproject.toml.bak" '"oldpkg==0.1",'
    assert_file_contains "$workspace/pyproject.toml" '"urllib3<3",'
    rm -rf "$workspace"
}

chmod +x "$TOOL"

test_create_missing_pyproject
test_update_existing_dependencies
test_preserve_unrelated_sections
test_skip_unsupported_specifiers
test_dry_run_and_backup_flags

printf 'ok\n'
