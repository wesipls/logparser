# logparser

A fast, minimal CLI tool for parsing and filtering logs using simple patterns.

Built for manual use to remove noise and duplicates from huge log files.

---

## Features

- Line-based and block-based parsing
- Regex pattern matching
- Deduplication of repeated log entries
- Case-insensitive matching by default
- Works with files or stdin (pipes)
- Single portable Go binary (AWK embedded)

---

> [!IMPORTANT]
> logparser uses AWK (POSIX ERE) regular expressions, not PCRE.

## Installation

### Download prebuilt binary

Grab the latest release from GitHub Releases and make it executable:

```bash
chmod +x logparser
```

---

### Build from source

```bash
git clone https://github.com/wesipls/logparser
cd logparser
make build
```

Or manually:

```bash
go build -o logparser .
```

Optional, add it to $PATH
```bash
mkdir -p ~/.local/bin
mv logparser ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"
```
To make it permantent, add the export command to your ~/.bashrc or ~/.profile.

---

## Usage

```bash
logparser [options]
```

If no input is provided, the tool will exit and show usage.

---

## Input

- `-i, --input` → input file
- stdin (pipe) is supported

```bash
# from file
logparser -i /var/log/app.log -p error

# from pipe
journalctl -u nginx | logparser -p error
```

---

## Matching

- `-p, --pattern` → regex pattern (default: `.`)
- `-c, --case-sensitive` → enable case-sensitive matching

Default behavior is **case-insensitive**.

```bash
logparser -i app.log -p "error|fatal"
logparser -i app.log -p error -c
```

---

## Deduplication

- `-d, --dedup` → enable deduplication
- `-D, --dedup-strip` → strip dynamic values before comparison

```bash
logparser -i app.log -p error -d
```

Ignore dynamic numbers:

```bash
logparser -i app.log -p error -D '[0-9]+'
```

---

## Modes

- `-m, --mode` → parsing mode

| Mode   | Description |
|--------|------------|
| line   | Match individual lines (default) |
| block  | Match multi-line blocks |
| count  | Output number of matches |

---

## Block Mode

Used for stack traces and grouped logs.

- `-s, --start` → block start pattern
- `-e, --end` → block end pattern

```bash
logparser -i stack.log -m block -s '^Exception' -e '^$'
```

---

## Count Mode

Only outputs the number of matches:

```bash
logparser -i app.log -m count -p error
```

---

## Examples

```bash
# find errors
logparser -i /var/log/app.log -p "error|fatal"

# case-sensitive search
logparser -i app.log -p error -c

# count matches
logparser -i app.log -m count -p error

# deduplicate repeated errors
logparser -i app.log -p error -d

# strip dynamic values before dedup
logparser -i app.log -p error -D '[0-9]+'

# block parsing (stack traces)
logparser -i stack.log -m block -s '^Exception' -e '^$'

# pipe input
cat app.log | logparser -p error
```

---

## Testing

Run tests using the included script:

```bash
make test
```

or:

```bash
cd tests
./run.sh
```

---

## Project Structure

```
.
├── main.go        # CLI entrypoint
├── awk/           # core parsing logic
├── tests/         # test cases
├── tool/          # (future automation version)
├── Makefile       # build + release helpers
```

---

## Roadmap

This CLI is intentionally minimal and focused on **manual usage**.

A future version will introduce:

- Automation-oriented workflows
- Monitoring integrations (e.g. Zabbix)
- Config-driven execution

The automation layer is being developed separately in `tool/`, keeping this CLI fast and simple.

---

## Version

```bash
logparser --version
```

---

## Requirements

- `awk` must be available on the system

---
