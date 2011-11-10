#!/usr/bin/perl -w

use strict;

# Copy over all non-globalsight.jar files

# TODO: 
# - automatically fetch file list from git log rather than hardcode
# - include globalsight.jar
# - parameterize source and dest locations
# - sanity checks?

# Point it to the jboss directory
my $jboss = "/home/chase/test/jboss";
my $buildDirectory = "/home/chase/globalsight/main6/tools/build";

my @files = qw(
    com/globalsight/persistence/hibernate/xml/TargetPage.hbm.xml
    com/globalsight/persistence/hibernate/xml/WorkflowImpl.hbm.xml
    com/globalsight/resources/messages/LocaleResource.properties
    com/globalsight/resources/messages/LocaleResource_de_DE.properties
    com/globalsight/resources/messages/LocaleResource_en_US.properties
    com/globalsight/resources/messages/LocaleResource_es_ES.properties
    com/globalsight/resources/messages/LocaleResource_fr_FR.properties
    com/globalsight/resources/messages/LocaleResource_ja_JP.properties
    com/globalsight/resources/messages/LocaleResource_zh_CN.properties
);

chdir($buildDirectory) || die $!;

my @filenames = ();

foreach my $f (@files) {
    my @parts = split /\//, $f;
    push @filenames, $parts[$#parts];
}

my @filesToCopy = ();
foreach my $name (@filenames) {
    open(my $fh, "find . -name $name|") || die $!;
    my @lines = <$fh>;
    if (scalar @lines > 1) {
        print STDERR "Ambiguous filename '$name':\n";
        foreach my $l (@lines) {
            print STDERR "$l\n";
        }
        die;
    }
    my $path = $lines[0];
    chomp $path;
    push @filesToCopy, $path;
}

# Make sure everthing is in a location we know about
foreach my $path (@filesToCopy) {
    unless ($path =~ /^.\/capclasses\/globalsight.ear\/lib\/classes\//) {
        print "Unknown location: $path\n";
    }
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

my @commands = ();
foreach my $path (@filesToCopy) {
    (my $dest = $path) =~ s/^.*capclasses\//$jboss\/jboss_server\/server\/default\/deploy\//;
    my $cmd = "cp $path $dest";
    push @commands, $cmd;
}

foreach my $c (@commands) {
    print "$c\n";
    unless (system($c) == 0) {
        die "Command failed: $!";
    }
}
