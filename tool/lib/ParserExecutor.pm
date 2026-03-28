# ParserExecutor.pm
# Executes awk parsers for processing logs based on the specified mode ('single_line' or 'multi_line').
# Handles dynamic arguments based on the provided configuration, validates execution success, and provides error handling.

package ParserExecutor;

use strict;
use warnings;

sub execute_parser {
    my ($mode, $config, $file_path) = @_;

    # Validate mode
    unless ($mode eq 'single_line' || $mode eq 'multi_line') {
        die "Error: mode '$mode' is not recognized. Please use 'single_line' or 'multi_line'.\n";
    }

    # Construct AWK arguments from config
    my $args = join(' ', map { "-v $_=\"$config->{$_}\"" } grep { $_ ne 'mode' } keys %{$config});
    $args .= " $file_path";

    print "\n=== Start of file: $file_path ===\n";

    # Select parser based on mode
    my $parser_script = $mode eq 'single_line' ? 'parsers/single_line.awk' : 'parsers/multi_line.awk';

    # Check if parser exists
    unless (-e $parser_script) {
        die "Error: Parser script '$parser_script' not found.\n";
    }

    # Run AWK system command and capture output
    my $command = "awk -f $parser_script $args";
    my $output = `$command 2>&1`;
    my $exit_status = $?;

    if ($exit_status != 0) {
        die "Error: Failed to execute $mode parser on $file_path. Exit status: $exit_status\nCommand: $command\nError: $output\n";
    }

    print $output;  # Print the output of the AWK script if needed
    print "=== End of file: $file_path ===\n";
}

1;

