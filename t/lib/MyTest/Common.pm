package MyTest::Common;

use strict;
use warnings FATAL => 'all';

use Apache::Scoreboard;

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

sub num_of_tests {
    return 5;
}

sub test {
    my $image = shift;

    {
        t_debug "constants";
        ok Apache::Constants::HARD_SERVER_LIMIT;
        ok Apache::Scoreboard::REMOTE_SCOREBOARD_TYPE;
    }

    # quick check
    ok image_is_ok($image);

    my $ok = 1;
    for (my $parent = $image->parent; $parent; $parent = $parent->next) {

        my $ok = 1;
        next if score_is_ok($parent);

        die "failed score check for pid: " . $parent->pid;
    }

    ok $ok;

    my $pids = $image->pids;
    error $pids;
    ok @$pids;
}

my @methods = qw(status access_count request client
                 bytes_served conn_bytes conn_count times start_time
                 stop_time req_time);

# vhost is not available outside mod_perl, since it requires a call to
# an Apache method
push @methods, "vhost" if $ENV{MOD_PERL};

sub score_is_ok {
    my $parent = shift;

    my $ok = 1;
    $ok = 0 unless $parent->pid;

    my $server = $parent->server; # Apache::ServerScore object
    for (@methods) {
        no strict 'refs';
        my $val = $server->$_;
        #error "$_ [$val]";
        $ok = 0 unless defined $val;
    }

    return $ok;
}

# try to access various underlying datastructures to test that the
# image is valid
sub image_is_ok {
    my ($image) = shift;
    my $status = 1;
    $status = 0 unless $image && 
        ref($image) eq 'Apache::Scoreboard' &&
        $image->pids &&
        $image->servers(0) &&
        $image->parent(0)->pid;

    return $status;
}

1;
