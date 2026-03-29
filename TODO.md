## TODO

- Add tests for:
  - default pattern behavior
  - default dedup behavior
  - `--no-dedup`
  - `--dedup-strip`
  - `--dedup-fields`
  - `--dedup-ignore-fields`
  - invalid `--dedup-fields` / `--dedup-ignore-fields` values
  - precedence when multiple dedup options are used together

- Split `main.go` into smaller files/modules:
  - `flags.go`
  - `validate.go`
  - `run.go`
  - `awk.go`
