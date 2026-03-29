# FileHandler.pm
# Handles operations related to file management when LogParser.pl is processing a directory.
# Includes functions for retrieving all files within a directory excluding hidden files.

package FileHandler;

use strict;
use warnings;
use File::Basename;

sub get_files_in_directory {
    my ($directory) = @_;
    my @files;

    opendir(my $dh, $directory) or die "Cannot open directory $directory: $!";

    while (my $file = readdir($dh)) {
        next if $file =~ /^\./;
        use File::Spec;
        my $full_path = File::Spec->catfile($directory, $file);
        push @files, $full_path if -f $full_path;
    }

    closedir($dh);

    return @files;
}

1;

