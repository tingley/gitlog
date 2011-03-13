#!/usr/bin/perl -w

use Git;
use GitLog;
use GitUtil;
use Data::Dumper;

# Script to generate information about available patches for a release
# branch

my $sincefile = "patch_since";

my $since = GitUtil::get_since($sincefile);
my $latestCommit = undef;

# TODO: take on command-line
my $repo = Git->repository (Directory => '/cygdrive/c/src/globalsight');

my $log = new GitLog($repo, $since, \&entry_callback);
$log->init;
$log->next;

# Update timestamp
GitUtil::update_since($sincefile, $latestCommit);

# The better way to do this is probably to show the individual 
# commits with --name-only

sub entry_callback($) {
    my $entry = shift;

    $latestCommit = $entry->{commit} unless defined $latestCommit;

    if ($entry->is_merge) {
        print "Skipping merge commit " . $entry->{commit} . "\n";
        return;
    }

    print $entry->{comment};
    print "Files:\n";
    my ($pipe, $c) = $repo->command_output_pipe('show', 
                                                '--name-only',
                                                $entry->{commit});
    while (<$pipe>) {
        print $_;
    }
    $repo->command_close_pipe($pipe, $c);
}
