#!/usr/bin/perl -w

# Find all the files in a tree that need to be updated as part of the 
# hotfix process.
# This assumes everything is built -- 'ant dist' is the easiest way to
# ensure this.

use Git;
use GitUtil;

sub update_files($$@);
sub run($);

# TODO: this will not handle jars correctly

my @ALLOWED = (
    'main6/envoy/src/jsp/',
    'main6/envoy/src/java/',
    'main6/diplomat/dev/src/java/',
    'main6/ling/',
    'main6/tools/lib/'
);

# TODO: remove hardcode.  this is the merge-base of spartan-hotfix-8.2
# and master
my $MERGE_BASE = "bbcbc1cb6e507e41b82df55150560ab7f02928b6";
my $GS_HOME = "/home/chase/test";
my $DRY_RUN = 0; 

if (scalar @ARGV < 1 || scalar @ARGV > 2) {
    print STDERR "Usage: $0 [repository] [commit]\n";
    exit 1;
}

my $repoPath = $ARGV[0];
chdir($repoPath) || die $!;

my $commit = $ARGV[1] || $MERGE_BASE;

my $repo = Git->repository(Directory => $repoPath);

print "Head is " . GitUtil::get_head($repo) . "\n";

(my $log, $command) = 
    $repo->command_output_pipe('diff',
                               '--name-only',
                               $commit . "..HEAD");

my @modified = ();
LINE: while (<$log>) {
    # Lines start 'main6'
    chomp;
    foreach my $prefix (@ALLOWED) {
        if (/^$prefix/) {
            (my $s = $_) =~ s/^$prefix//;
            push @modified, $s;
            next LINE;
        }
    }
    print "Ignoring: $_\n";
}

$repo->command_close_pipe($log, $command);

update_files($GS_HOME . "/jboss", 
             $repoPath . "/main6/tools/build",
             @modified);

sub update_files($$@) {
    my ($jboss, $buildDirectory, @files) = @_;

    my @filesToCopy = ();
    foreach my $f (@files) {
        if ($f =~ /\.java$/) {
            print "Skipping Java file: $f\n";
            next;
        }
        # ./capclasses/globalsight.ear/lib/classes
        push @filesToCopy, $buildDirectory . 
                        '/capclasses/globalsight.ear/lib/classes/' .
                        $f;
    }

# Remapping 
# ./capclasses/globalsight.ear/lib/classes/com/globalsight/resources/messages/LocaleResource.properties
# to 
# jboss/jboss_server/server/default/deploy/globalsight.ear/lib/classes/com/globalsight/resources/messages/LocaleResource.properties
#
# ie, 
#  ./capclasses/[PATH]
# to 
# [jboss]/jboss_server/server/default/deploy/[PATH]

    my $capRoot = $buildDirectory . "/capclasses";
    my $capPath = $capRoot . "/globalsight.ear/lib/classes/";
    my $destRoot = $jboss . "/jboss_server/server/default/deploy";

    # Make sure everthing is in a location we know about
    print "== Found Files to Update ==\n";
    foreach my $path (@filesToCopy) {
        unless ($path =~ /^$capPath/) {
            print "Unknown location: $path\n";
        }
        else {
            print "$path\n";
        }
    }

    my @commands = ();
    foreach my $path (@filesToCopy) {
        (my $dest = $path) =~ s/^$capRoot/$destRoot/;
        my $cmd = "cp $path $dest";
        push @commands, $cmd;
    }

    print "== Applying Changes ==\n";
    foreach my $c (@commands) {
        run($c);
    }
    print "== Updating globalsight.jar ==\n";
    my $p = 'globalsight.ear/lib/globalsight.jar';
    run("cp $capRoot/$p $destRoot/$p");
}

sub run($) {
    my $cmd = shift;
    print "$cmd\n";
    unless ($DRY_RUN) {
        unless (system($cmd) == 0) {
            die "Commandfailed: $!";
        }
    }
}

