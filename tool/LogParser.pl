#!/usr/bin/perl

# LogParser.pl
# A Perl script for analyzing and processing log files. This script parses single files or entire directories containing logs.
# Utilizes configuration files to allow dynamic behavior and external awk parsers for log processing logic.

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use lib 'lib';
use ConfigLoader;
use FileHandler;
use ParserExecutor;

# Main entry point of the script
sub main {

    # Parse command-line arguments
    my ( $file_to_parse, $config_file ) = parse_arguments();

    # Load configuration file
    my %config = eval { ConfigLoader::load_config($config_file) }
      or die "Failed to load configuration: $@\n";

    # Determine input type and process files accordingly
    if ( -d $file_to_parse ) {
        process_directory( $file_to_parse, \%config );
    }
    elsif ( -f $file_to_parse ) {
        process_file( $file_to_parse, \%config );
    }
    else {
        die "Error: '$file_to_parse' is neither a file nor a directory.\n";
    }
}

# Parse and validate command-line arguments
sub parse_arguments {
    my $config_file = 'parser.conf';
    my $file_to_parse;

    GetOptions(
        "file=s"   => \$file_to_parse,
        "config=s" => \$config_file
    ) or die "Usage: $0 --file=<file|directory> [--config=<config_file>]\n";

    die
"Error: Missing --file argument. Use --file=<file|directory> to specify the target.\n"
      unless $file_to_parse;

    return ( $file_to_parse, $config_file );
}

# Process all files within a specified directory
sub process_directory {
    my ( $directory, $config ) = @_;

    my @files = eval { FileHandler::get_files_in_directory($directory) }
      or die "Failed to read directory '$directory': $@\n";

    for my $file (@files) {
        process_file( $file, $config );
    }
}

# Process a single log file
sub process_file {
    my ( $file, $config ) = @_;

    unless ( -f $file ) {
        warn
          "File '$file' does not exist or is not a regular file. Skipping...\n";
        return;
    }

    my $mode = $config->{"mode"}
      or die "Error: 'mode' not defined in configuration file.\n";

    eval { ParserExecutor::execute_parser( $mode, $config, $file ); }
      or warn "Failed to process file '$file': $@\n";
}

# Execute the main function
main();
