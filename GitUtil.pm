package GitUtil;

use strict;

sub get_since($) {
    my $name = shift;
    die "get_since() requires a filename" unless defined $name;
    open(SINCE, "<", $name) || return undef;
    my $line = <SINCE>;
    close SINCE;
    if (defined $line) {
        chomp $line;
        return $line if $line =~ /^[a-f0-9]+$/;
    }
    return undef;
}

sub update_since($$) {
    my ($name, $newSince) = @_;

    die "update_since() requires a filename" unless defined $name;

    unless (defined $newSince) {
        print "No new commits\n";
        return;
    }

    open(SINCE, ">", $name) || die "Could not open '$name' for writing";
    # TODO This breaks if there is no new commit
    print SINCE $newSince;
    close SINCE;

    print "Last commit is now $newSince\n";
}

1;
