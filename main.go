package main

import (
	"embed"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

//go:embed awk/core.awk
var awkFS embed.FS

type Config struct {
	Input         string
	Mode          string
	Pattern       string
	StartPattern  string
	EndPattern    string
	Dedup         bool
	DedupStrip    string
	CaseSensitive bool
}

func main() {
	cfg := parseFlags()

	if noInputProvided(cfg) {
		fmt.Fprintln(os.Stderr, "logparser: no input provided (use -input or pipe data)")
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

	flag.StringVar(&cfg.Input, "input", "", "input file (default: stdin)")
	flag.StringVar(&cfg.Mode, "mode", "line", "mode: line | block | count")
	flag.StringVar(&cfg.Pattern, "pattern", ".", "match pattern for line/count mode")
	flag.StringVar(&cfg.StartPattern, "start", "", "block start pattern")
	flag.StringVar(&cfg.EndPattern, "end", "", "block end pattern")
	flag.BoolVar(&cfg.Dedup, "dedup", false, "enable deduplication")
	flag.StringVar(&cfg.DedupStrip, "dedup-strip", "", "regex to strip before dedup comparison")
	flag.BoolVar(&cfg.CaseSensitive, "case-sensitive", false, "enable case-sensitive matching")

	flag.Usage = func() {
		out := flag.CommandLine.Output()
		fmt.Fprintf(out, "Usage: %s [options]\n\n", filepath.Base(os.Args[0]))
		fmt.Fprintln(out, "Examples:")
		fmt.Fprintln(out, `  logparser -input /var/log/app.log -pattern "error|fatal"`)
		fmt.Fprintln(out, `  logparser -input /var/log/app.log -pattern "error|fatal" -case-sensitive`)
		fmt.Fprintln(out, `  logparser -input /var/log/app.log -mode count -pattern "error|fatal"`)
		fmt.Fprintln(out, `  logparser -input stack.log -mode block -start "^Exception" -end "^$" -dedup`)
		fmt.Fprintln(out, "")
		fmt.Fprintln(out, "Options:")
		flag.PrintDefaults()
	}

	flag.Parse()
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
			return errors.New("block mode requires -start")
		}
		if cfg.EndPattern == "" {
			return errors.New("block mode requires -end")
		}
	} else {
		if strings.TrimSpace(cfg.Pattern) == "" {
			return errors.New("line/count mode requires -pattern")
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
		"-v", "ignore_case=" + boolToAwk(!cfg.CaseSensitive),
		"-f", awkPath,
	}

	// awk reads from stdin because we attach file/stdin there.
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
