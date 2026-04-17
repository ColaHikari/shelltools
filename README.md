# shelltools

`shelltools` is a small repository for reusable shell utilities. The first tool in the repo is `bin/req2pyproject.sh`, a standalone POSIX shell script that syncs dependencies from `requirements.txt` into `pyproject.toml` under `[project].dependencies`.

## Overview

`req2pyproject.sh` auto-detects `requirements.txt` and `pyproject.toml` in the current directory by default. It rewrites only the PEP 621 `[project].dependencies` array, supports dry-run and backup modes, and does not require Python or any TOML parser at runtime.

## Features

- Auto-detects `requirements.txt` and `pyproject.toml` in the current working directory
- Explicit path flags for custom input locations
- Optional backup of existing `pyproject.toml` before modification
- Dry-run mode to preview changes without writing files
- PEP 621 compliant output only

## Installation

### Direct download (no installation required)

```sh
# Download and run directly from raw GitHub
curl -fsSL https://raw.githubusercontent.com/<your-user>/shelltools/main/bin/req2pyproject.sh | sh -s -- --help

# Or save to a local path and run
curl -fsSL https://raw.githubusercontent.com/<your-user>/shelltools/main/bin/req2pyproject.sh -o /usr/local/bin/req2pyproject
chmod +x /usr/local/bin/req2pyproject
```

### From cloned repository

```sh
git clone https://github.com/<your-user>/shelltools.git
cd shelltools
./bin/req2pyproject.sh --help
```

## Usage

### Auto-detection mode

Runs with defaults, scanning the current directory for `requirements.txt` or `pyproject.toml`:

```sh
./bin/req2pyproject.sh
```

### Explicit paths

```sh
./bin/req2pyproject.sh -r requirements.txt -p pyproject.toml
```

### Dry-run mode

Preview what would be written without modifying any files:

```sh
./bin/req2pyproject.sh --dry-run
```

### Backup control

Create a backup before writing:

```sh
./bin/req2pyproject.sh --backup
```

## Options

| Option | Description |
|--------|-------------|
| `-r, --requirements <path>` | Path to requirements.txt (default: ./requirements.txt) |
| `-p, --pyproject <path>` | Path to pyproject.toml (default: ./pyproject.toml) |
| `--backup` | Create `pyproject.toml.bak` before overwriting an existing file |
| `--dry-run` | Print result to stdout instead of writing file |
| `-h, --help` | Show help message |

## Supported requirement syntax

The tool parses `requirements.txt` and extracts packages into PEP 621 `[project].dependencies` format.

**Supported:**

- Package names with versions: `requests>=2.28.0`
- Package names only: `pytest`
- Hyphenated names: `some-package`
- Underscore names: `some_package`

**Unsupported syntax (warned and skipped):**

- URLs: `git+https://github.com/user/repo.git`
- File paths: `./local/package`
- Environment markers: `package; python_version >= "3.8"`
- Extras: `package[extra1,extra2]>=1.0`
- Comments (lines starting with `#`)
- Requirements that are not valid PEP 508 names

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
## Requirements

- POSIX-compliant shell (`sh`, `dash`, `bash`, `zsh` in sh-compatible mode)
- `awk`, `grep`, `sed`, `cp`, `mv`, and `mktemp`
- `shellcheck` (optional, only for linting/CI)

No Python, Node.js, or other runtime dependencies required.

## Testing

The test harness uses a local shell script that validates the tool's behavior:

```sh
sh test/test_req2pyproject.sh
```

For CI, this is run via:

```sh
shellcheck bin/req2pyproject.sh && sh test/test_req2pyproject.sh
```

## Scope and limitations

- Only reads and writes `[project].dependencies` in `pyproject.toml`
- Does not modify `[project.optional-dependencies]` or other tables
- Does not support Poetry-style `tool.poetry.dependencies`
- Supports only simple requirement forms such as `name`, `name==1.2.3`, `name>=1.0`, `name~=2.0`
- Does not install or manage packages
- Does not handle requirements with extras, environment markers, local paths, or URLs
