# logparser

A fast, minimal CLI tool for parsing and filtering logs using simple patterns.

Built for manual use to remove noise and duplicates from huge log files.

---

## Features

- Line-based and block-based parsing
- Regex pattern matching
- Sensible default error matching for line/count mode
- Deduplication enabled by default
- Regex-based dedup with dynamic-value stripping
- Field-based dedup using selected or ignored columns
- Case-insensitive matching by default
- Works with files or stdin (pipes)
- Single portable Go binary (AWK embedded)

---

> [!IMPORTANT]
> `logparser` uses **AWK (POSIX ERE)** regular expressions, not PCRE.

This matters especially for `--pattern`, `--start`, `--end`, and `--dedup-strip`.

Some common PCRE features will **not** work as expected:

- `\b` word boundaries
- `\d`, `\w`, `\s`
- lookaheads / lookbehinds
- non-capturing groups like `(?:...)`

Use AWK-style patterns instead:

- `[0-9]` instead of `\d`
- `[[:space:]]` instead of `\s`
- explicit character classes instead of `\b`

Example:

```bash
# PCRE-ish (wrong for awk)
logparser -i error.log --dedup-strip '\b[0-9]+#[0-9]+\b|\*[0-9]+'

# AWK-compatible
logparser -i error.log --dedup-strip '[0-9]+#[0-9]+|[*][0-9]+'
```

---

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

Optional: add it to `$PATH`

```bash
mkdir -p ~/.local/bin
mv logparser ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"
```

To make this permanent, add the export line to your `~/.bashrc`, `~/.zshrc`, or `~/.profile`.

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
logparser -i /var/log/app.log

# from pipe
journalctl -u nginx | logparser
```

---

## Matching

- `-p, --pattern` → regex pattern for line/count mode
- `-c, --case-sensitive` → enable case-sensitive matching

Default behavior for line/count mode:

- pattern: `error|fatal|panic|exception|failed|failure|critical`
- case-insensitive matching

```bash
logparser -i app.log
logparser -i app.log -p "error|fatal"
logparser -i app.log -p error -c
```

---

## Deduplication

Deduplication is enabled by default.

- `--no-dedup` → disable deduplication
- `-d` → shorthand to disable deduplication

```bash
logparser -i app.log
logparser -i app.log --no-dedup
logparser -i app.log -d
```

### Regex-based dedup

- `-D, --dedup-strip` → AWK regex to strip dynamic values before dedup comparison

Useful when the same error repeats with changing IDs, timestamps, request paths, or other noisy values.

```bash
logparser -i app.log --dedup-strip '[0-9]+'
```

Example with nginx-style noise:

```bash
logparser -i error.log --dedup-strip '^[0-9/ :]+|[0-9]+#[0-9]+: [*][0-9]+|[0-9]+ bytes|client: [^,]+, |server: [^,]+, |request: "[^"]+"|upstream: "[^"]+"|host: "[^"]+"'
```

### Field-based dedup

Useful when the log structure is stable, but one or more whitespace-separated fields are noisy.

- `-F, --dedup-fields` → only use these 1-based fields for dedup comparison
- `-I, --dedup-ignore-fields` → ignore these 1-based fields for dedup comparison

Examples:

```bash
# compare only fields 1, 3, and 4
logparser -i users.log -F 1,3,4

# compare all fields except field 2
logparser -i users.log -I 2
```

Example input:

```text
[ERROR] user=asöldfggd776dköw34 got rekt
[ERROR] user=asöld234wröw34 got rekt
[ERROR] user=asöldölasdwesadköw34 got rekt
```

This collapses cleanly with:

```bash
logparser -i users.log -I 2
```

---

## Modes

- `-m, --mode` → parsing mode

| Mode  | Description |
|------|-------------|
| line | Match individual lines (default) |
| block | Match multi-line blocks |
| count | Output number of matches |

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
logparser -i app.log -m count
logparser -i app.log -m count -p error
```

---

## Examples

```bash
# default error search
logparser -i /var/log/app.log

# custom search
logparser -i /var/log/app.log -p "timeout|denied|refused"

# case-sensitive search
logparser -i app.log -p error -c

# count matches
logparser -i app.log -m count

# disable dedup
logparser -i app.log --no-dedup

# strip dynamic values before dedup
logparser -i app.log --dedup-strip '[0-9]+'

# dedup using only selected fields
logparser -i users.log -F 1,3,4

# dedup while ignoring a noisy field
logparser -i users.log -I 2

# block parsing (stack traces)
logparser -i stack.log -m block -s '^Exception' -e '^$'

# pipe input
cat app.log | logparser
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

```text
.
├── main.go        # CLI entrypoint
├── awk/           # core parsing logic
├── tests/         # test cases
├── tool/          # (future automation version)
├── Makefile       # build + release helpers
```

---

## Version

```bash
logparser --version
```

---

## Requirements

- `awk` must be available on the system

---
