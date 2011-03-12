#!/usr/bin/perl -w
package GitLog;

use strict;
use Data::Dumper;

{
    package GitLog::Entry;
    package GitLog::Parser;
}

sub new {
    my ($class, $repo, $sinceCommitId, $entry_callback) = @_;
    bless {
        repo => $repo,
        since => $sinceCommitId,
        parser => new GitLog::Parser($entry_callback),
        nextVal => undef,
        log => undef
    }, $class;
}

sub init($) {
    my $self = shift;
    ($self->{log}, $self->{command}) = 
                    $self->{repo}->command_output_pipe('log',
                                                       '--pretty=raw', 
                                                       $self->revisions);
}

sub revisions($) {
    my $self = shift;
    return $self->{since} . ".." . "HEAD";
}

sub has_next($) {
    my $self = shift;
    return 1 if defined $self->{nextVal};

    $self->init unless defined $self->{log};

    my $fh = $self->{log}; # TODO: remove this
    while (<$fh>) {
        #print ("Line: $_");
        $self->{parser}->line($_);
    }
    $self->{parser}->flush();
    $self->{repo}->command_close_pipe($self->{log}, $self->{command});
    $self->{log} = undef;
}

sub next($) {
    my $self = shift;
    return $self->has_next ? $self->{nextVal} : undef;
}

#
#   Entry
#
{ 
package GitLog::Entry;

sub new {
    my ($class) = @_;
    my @foo = (); # TODO: remove this
    return bless {
        commit => undef,
        tree => undef,
        parent => \@foo, # merge parents
        author => undef,
        comment => ''
    }, $class;
}
sub is_merge($) {
    my ($self) = @_;
    return scalar @{$self->{parent}} > 1;
}
sub commit($$) { 
    my ($self, $id) = @_;
    $self->{commit} = $id;
}
sub tree($$) { 
    my ($self, $id) = @_;
    $self->{tree} = $id;
}
sub parent($$) { 
    my ($self, $id) = @_;
    push @{$self->{parent}}, $id;
}
sub author($$) { 
    my ($self, $id) = @_;
    $self->{author} = $id;
}
sub committer($$) { 
    my ($self, $id) = @_;
    $self->{committer} = $id;
}
sub comment($$) {
    my ($self, $comment) = @_;
    $self->{comment} .= $comment;
}

}

#
# Parser
#
{
package GitLog::Parser;
use feature 'switch';
use Data::Dumper;

sub new {
    my ($class, $callback) = @_;
    return bless {
        state => 'INITIAL',
        entry => undef,
        entry_callback => $callback
    }, $class;
}

sub line ($$) {
    my ($self, $line) = @_;
    $self->{entry} = new GitLog::Entry() unless defined $self->{entry};

    #print ("line, state=" . $self->{state} . ", line=$line");
    given ($self->{state}) {
        when ('INITIAL') {
            if ($line =~ /^commit ([a-f0-9]+)/) {
                $self->{entry}->commit($1);
                $self->state("COMMIT");
            }
        }
        when ('COMMIT') {
            $self->handleCommitLine($line);
        }
        when ('COMMENT') {
            # TODO: strip leading, trailing newline
            if ($line =~ /^commit ([a-f0-9]+)/) {
                $self->flush();
                $self->{entry}->commit($1);
                $self->state("COMMIT");
            }
            else {
                $self->{entry}->comment($line);
            }
        }
    }
}

sub flush($) {
    my $self = shift;
    &{$self->{entry_callback}}($self->{entry}) 
            if defined $self->{entry}->{commit};
    $self->{entry} = new GitLog::Entry();
}

sub handleCommitLine($$) {
    my ($self, $line) = @_;
    #print ("handleCommit: $line");
    given ($line) {
        when (/^tree ([a-f0-9]+)/) {
            $self->{entry}->tree($1);
        }
        when (/^parent ([a-f0-9]+)/) {
            $self->{entry}->parent($1);
        }
        when (/^author (.+)/) {
            $self->{entry}->author(parse_user($1));
        }
        when (/^committer (.+)/) {
            $self->{entry}->committer(parse_user($1));
            $self->state('COMMENT');
        }
    }
}

sub state($$) {
    my ($self, $state) = @_;
    #print ($self->{state} . " --> " . $state . "\n");
    $self->{state} = $state;
}

sub parse_user($) {
    my ($raw) = @_;
    
    # Format: User Name <email> 1293068662 +0000

    if ($raw =~ /(.*) <([^>]+)> (\d+) \+(\d\d\d\d)/) {
        return {
                name => $1,
                email => $2,
                timestamp => $3,
                tz => $4
        };
    }
    die "Failed to parse $raw";
    return undef;
}

}


1;
