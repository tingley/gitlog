#!/usr/bin/perl -w

use Git;
use GitLog;
use Data::Dumper;

sub get_since() {
    open(SINCE, "<", "since") || return undef;
    my $line = <SINCE>;
    close SINCE;
    if (defined $line) {
        chomp $line;
        return $line if $line =~ /^[a-f0-9]+$/;
    }
    return undef;
}

sub update_since($) {
    my $newSince = shift;

    unless (defined $newSince) {
        print "No new commits\n";
        exit 0;
    }

    open(SINCE, ">", "since") || die "Could not open 'since' for writing";
    # TODO This breaks if there is no new commit
    print SINCE $newSince;
    close SINCE;

    print "Last commit is now $newSince\n";
}

my $since = get_since();

print "since is $since\n" if defined $since;

# TODO: take on command-line
my $repo = Git->repository (Directory => '/home/chase/git');

# Hacky
mkdir 'patches' unless -d 'patches';

my $latestCommit = undef;

my $log = new GitLog($repo, $since, \&entry_callback);
$log->init;
$log->next;

# Now update the since value
update_since($latestCommit);

sub entry_callback($) {
    my $entry = shift;

    $latestCommit = $entry->{commit} unless defined $latestCommit;

    if ($entry->is_merge) {
        print "Skipping merge commit " . $entry->{commit} . "\n";
        return;
    }

    if ($entry->{comment} =~ /(GBS-\d+)/) {
        print "Found $1\n";
        my $dir = "patches/$1";
        write_commit_to_file($dir, $entry->{commit}, $repo);
    }
    else {
        # Unknown
        print "Unknown commit " . $entry->{commit} . "\n";
        # TODO: beef up
    }
}

sub write_commit_to_file($$$) {
    my ($dir, $commit, $repo) = @_;
    mkdir $dir unless -d $dir;
    my $commit_abbrev = substr $commit, 0, 10;
    my $file = "$dir/$commit_abbrev.diff";
    open OUT, ">", $file;
    my ($pipe, $c) = $repo->command_output_pipe('show', $commit);
    while (<$pipe>) {
        print OUT $_;
    }
    close OUT;
    $repo->command_close_pipe($pipe, $c);
    print "Wrote $file\n";
}

