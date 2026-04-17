#!/bin/sh

set -eu

usage() {
    cat <<'EOF'
Usage: req2pyproject.sh [-r FILE] [-p FILE] [--dry-run] [--backup]

Sync supported requirement lines into [project].dependencies in pyproject.toml.
Defaults to ./requirements.txt and ./pyproject.toml in the current directory.
EOF
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

requirements_file='requirements.txt'
pyproject_file='pyproject.toml'
dry_run=0
backup=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        -r|--requirements)
            [ "$#" -ge 2 ] || die "missing value for $1"
            requirements_file=$2
            shift 2
            ;;
        -p|--pyproject)
            [ "$#" -ge 2 ] || die "missing value for $1"
            pyproject_file=$2
            shift 2
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        --backup)
            backup=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

[ -f "$requirements_file" ] || die "requirements file not found: $requirements_file"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/req2pyproject.XXXXXX")
deps_items_file="$tmpdir/deps-items.txt"
deps_block_file="$tmpdir/deps-block.txt"
new_pyproject_file="$tmpdir/pyproject.toml"

cleanup() {
    rm -rf "$tmpdir"
}

trap cleanup EXIT HUP INT TERM

normalize_requirement() {
    printf '%s\n' "$1" | sed 's/[[:space:]]*\(==\|>=\|<=\|~=\|>\|<\)[[:space:]]*/\1/g'
}

parse_requirements() {
    : > "$deps_items_file"

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line=$(printf '%s\n' "$raw_line" | tr -d '\r' | sed 's/[[:space:]]*$//')

        case "$line" in
            ''|'#'*)
                continue
                ;;
        esac

        line=$(printf '%s\n' "$line" | sed 's/[[:space:]]\{1,\}#.*$//')
        normalized=$(normalize_requirement "$line")

        if printf '%s\n' "$normalized" | grep -Eq '^[A-Za-z0-9_.-]+((==|>=|<=|~=|>|<)[A-Za-z0-9*_.+-]+)?$'; then
            printf '  "%s",\n' "$normalized" >> "$deps_items_file"
        else
            warn "skipping unsupported requirement line: $raw_line"
        fi
    done < "$requirements_file"
}

build_dependencies_block() {
    printf 'dependencies = [\n' > "$deps_block_file"
    while IFS= read -r dep_line || [ -n "$dep_line" ]; do
        printf '%s\n' "$dep_line" >> "$deps_block_file"
    done < "$deps_items_file"
    printf ']\n' >> "$deps_block_file"
}

write_minimal_pyproject() {
    printf '[project]\n' > "$new_pyproject_file"
    while IFS= read -r block_line || [ -n "$block_line" ]; do
        printf '%s\n' "$block_line" >> "$new_pyproject_file"
    done < "$deps_block_file"
}

rewrite_existing_pyproject() {
    awk -v depsfile="$deps_block_file" '
        function emit_deps( line) {
            while ((getline line < depsfile) > 0) {
                print line
            }
            close(depsfile)
            inserted = 1
        }

        function is_section_header(line) {
            return line ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/
        }

        BEGIN {
            in_project = 0
            seen_project = 0
            inserted = 0
            skipping_deps = 0
        }

        {
            if (skipping_deps) {
                if ($0 ~ /\]/) {
                    skipping_deps = 0
                }
                next
            }

            if (is_section_header($0)) {
                if (in_project && !inserted) {
                    emit_deps()
                }

                print

                if ($0 ~ /^[[:space:]]*\[project\][[:space:]]*$/) {
                    in_project = 1
                    seen_project = 1
                    inserted = 0
                } else {
                    in_project = 0
                }
                next
            }

            if (in_project && $0 ~ /^[[:space:]]*dependencies[[:space:]]*=/) {
                emit_deps()
                if ($0 !~ /\]/) {
                    skipping_deps = 1
                }
                next
            }

            print
        }

        END {
            if (in_project && !inserted) {
                emit_deps()
            }

            if (!seen_project) {
                if (NR > 0) {
                    print ""
                }
                print "[project]"
                emit_deps()
            }
        }
    ' "$pyproject_file" > "$new_pyproject_file"
}

write_output() {
    if [ "$dry_run" -eq 1 ]; then
        while IFS= read -r out_line || [ -n "$out_line" ]; do
            printf '%s\n' "$out_line"
        done < "$new_pyproject_file"
        return
    fi

    if [ -f "$pyproject_file" ] && [ "$backup" -eq 1 ]; then
        cp "$pyproject_file" "$pyproject_file.bak"
    fi

    mv "$new_pyproject_file" "$pyproject_file"
}

parse_requirements
build_dependencies_block

if [ -f "$pyproject_file" ]; then
    rewrite_existing_pyproject
else
    write_minimal_pyproject
fi

write_output
