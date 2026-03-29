package main

import (
	"embed"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// version is set at build time via -ldflags
var version = "dev"

const defaultPattern = "error|fatal|panic|exception|failed|failure|critical"

//go:embed awk/core.awk
var awkFS embed.FS

type Config struct {
	Input             string
	Mode              string
	Pattern           string
	StartPattern      string
	EndPattern        string
	Dedup             bool
	DedupStrip        string
	DedupFields       string
	DedupIgnoreFields string
	CaseSensitive     bool
}

func main() {
	cfg := parseFlags()

	if noInputProvided(cfg) {
		fmt.Fprintln(os.Stderr, "logparser: no input provided (use -i/--input or pipe data)")
		flag.Usage()
		os.Exit(1)
	}

	if err := run(cfg); err != nil {
		fmt.Fprintln(os.Stderr, "logparser:", err)
		os.Exit(3)
	}
}

func parseFlags() Config {
	cfg := Config{}

	showVersion := flag.Bool("version", false, "show version")
	flag.BoolVar(showVersion, "v", false, "show version (shorthand)")

	flag.StringVar(&cfg.Input, "input", "", "input file (default: stdin)")
	flag.StringVar(&cfg.Input, "i", "", "input file (shorthand)")

	flag.StringVar(&cfg.Mode, "mode", "line", "mode: line | block | count")
	flag.StringVar(&cfg.Mode, "m", "line", "mode shorthand: line | block | count")

	flag.StringVar(&cfg.Pattern, "pattern", "", "match pattern for line/count mode (default: common error keywords)")
	flag.StringVar(&cfg.Pattern, "p", "", "match pattern shorthand for line/count mode")

	flag.StringVar(&cfg.StartPattern, "start", "", "block start pattern")
	flag.StringVar(&cfg.StartPattern, "s", "", "block start pattern (shorthand)")

	flag.StringVar(&cfg.EndPattern, "end", "", "block end pattern")
	flag.StringVar(&cfg.EndPattern, "e", "", "block end pattern (shorthand)")

	flag.BoolVar(&cfg.Dedup, "dedup", true, "enable deduplication (default: true)")
	flag.BoolFunc("no-dedup", "disable deduplication", func(string) error {
		cfg.Dedup = false
		return nil
	})
	flag.BoolFunc("d", "disable deduplication (shorthand)", func(string) error {
		cfg.Dedup = false
		return nil
	})

	flag.StringVar(&cfg.DedupStrip, "dedup-strip", "", "awk regex to strip before dedup comparison")
	flag.StringVar(&cfg.DedupStrip, "D", "", "awk regex to strip before dedup comparison (shorthand)")

	flag.StringVar(&cfg.DedupFields, "dedup-fields", "", "comma-separated 1-based fields to use for dedup comparison")
	flag.StringVar(&cfg.DedupFields, "F", "", "comma-separated 1-based fields to use for dedup comparison (shorthand)")

	flag.StringVar(&cfg.DedupIgnoreFields, "dedup-ignore-fields", "", "comma-separated 1-based fields to ignore for dedup comparison")
	flag.StringVar(&cfg.DedupIgnoreFields, "I", "", "comma-separated 1-based fields to ignore for dedup comparison (shorthand)")

	flag.BoolVar(&cfg.CaseSensitive, "case-sensitive", false, "enable case-sensitive matching")
	flag.BoolVar(&cfg.CaseSensitive, "c", false, "enable case-sensitive matching (shorthand)")

	flag.Usage = func() {
		out := flag.CommandLine.Output()
		fmt.Fprintf(out, "Usage: %s [options]\n\n", filepath.Base(os.Args[0]))
		fmt.Fprintln(out, "Short and long flags are both supported.")
		fmt.Fprintln(out, "")
		fmt.Fprintf(out, "Default line/count pattern: %q\n", defaultPattern)
		fmt.Fprintln(out, "Defaults: case-insensitive matching, deduplication enabled.")
		fmt.Fprintln(out, "")
		fmt.Fprintln(out, "Examples:")
		fmt.Fprintln(out, `  logparser -i /var/log/app.log`)
		fmt.Fprintln(out, `  logparser -i /var/log/app.log --no-dedup`)
		fmt.Fprintln(out, `  logparser -i /var/log/app.log -p "error|fatal"`)
		fmt.Fprintln(out, `  logparser -i /var/log/app.log --dedup-strip '^[0-9/ :]+'`)
		fmt.Fprintln(out, `  logparser -i users.log -F 1,3,4`)
		fmt.Fprintln(out, `  logparser -i users.log -I 2`)
		fmt.Fprintln(out, `  logparser --input /var/log/app.log --mode count --pattern "error|fatal"`)
		fmt.Fprintln(out, `  logparser -i stack.log -m block -s "^Exception" -e "^$" --no-dedup`)
		fmt.Fprintln(out, "")
		fmt.Fprintln(out, "Options:")
		flag.PrintDefaults()
	}

	flag.Parse()

	if *showVersion {
		fmt.Printf("logparser %s\n", version)
		os.Exit(0)
	}

	if cfg.Mode != "block" && strings.TrimSpace(cfg.Pattern) == "" {
		cfg.Pattern = defaultPattern
	}

	if strings.TrimSpace(cfg.DedupStrip) != "" || strings.TrimSpace(cfg.DedupFields) != "" || strings.TrimSpace(cfg.DedupIgnoreFields) != "" {
		cfg.Dedup = true
	}

	return cfg
}

func noInputProvided(cfg Config) bool {
	if cfg.Input != "" {
		return false
	}

	stat, err := os.Stdin.Stat()
	if err != nil {
		return true
	}

	stdinIsTerminal := (stat.Mode() & os.ModeCharDevice) != 0
	return stdinIsTerminal
}

func run(cfg Config) error {
	if err := validate(cfg); err != nil {
		return err
	}

	awkPath, cleanup, err := writeEmbeddedAWK()
	if err != nil {
		return fmt.Errorf("prepare awk script: %w", err)
	}
	defer cleanup()

	args := buildAWKArgs(cfg, awkPath)
	cmd := exec.Command("awk", args...)

	if cfg.Input != "" {
		f, err := os.Open(cfg.Input)
		if err != nil {
			return fmt.Errorf("open input file: %w", err)
		}
		defer f.Close()
		cmd.Stdin = f
	} else {
		cmd.Stdin = os.Stdin
	}

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("run awk: %w", err)
	}

	return nil
}

func validate(cfg Config) error {
	switch cfg.Mode {
	case "line", "block", "count":
	default:
		return fmt.Errorf("invalid mode %q (must be: line, block, count)", cfg.Mode)
	}

	if cfg.Mode == "block" {
		if cfg.StartPattern == "" {
			return errors.New("block mode requires -s/--start")
		}
		if cfg.EndPattern == "" {
			return errors.New("block mode requires -e/--end")
		}
	} else {
		if strings.TrimSpace(cfg.Pattern) == "" {
			return errors.New("line/count mode requires -p/--pattern")
		}
	}

	if err := validateFieldList("dedup-fields", cfg.DedupFields); err != nil {
		return err
	}
	if err := validateFieldList("dedup-ignore-fields", cfg.DedupIgnoreFields); err != nil {
		return err
	}

	return nil
}

func validateFieldList(name, raw string) error {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}

	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			return fmt.Errorf("%s must be a comma-separated list of 1-based field numbers", name)
		}
		n, err := strconv.Atoi(part)
		if err != nil || n <= 0 {
			return fmt.Errorf("%s must be a comma-separated list of 1-based field numbers", name)
		}
	}

	return nil
}

func buildAWKArgs(cfg Config, awkPath string) []string {
	args := []string{
		"-v", "mode=" + cfg.Mode,
		"-v", "pattern=" + cfg.Pattern,
		"-v", "start_pattern=" + cfg.StartPattern,
		"-v", "end_pattern=" + cfg.EndPattern,
		"-v", "dedup=" + boolToAwk(cfg.Dedup),
		"-v", "dedup_strip=" + cfg.DedupStrip,
		"-v", "dedup_fields=" + cfg.DedupFields,
		"-v", "dedup_ignore_fields=" + cfg.DedupIgnoreFields,
		"-v", "ignore_case=" + boolToAwk(!cfg.CaseSensitive),
		"-f", awkPath,
	}

	return args
}

func boolToAwk(v bool) string {
	if v {
		return "1"
	}
	return "0"
}

func writeEmbeddedAWK() (string, func(), error) {
	data, err := awkFS.ReadFile("awk/core.awk")
	if err != nil {
		return "", func() {}, err
	}

	tmp, err := os.CreateTemp("", "logparser-*.awk")
	if err != nil {
		return "", func() {}, err
	}

	cleanup := func() {
		_ = os.Remove(tmp.Name())
	}

	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		cleanup()
		return "", func() {}, err
	}

	if err := tmp.Close(); err != nil {
		cleanup()
		return "", func() {}, err
	}

	return tmp.Name(), cleanup, nil
}
