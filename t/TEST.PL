#!perl

use strict;
use warnings FATAL => 'all';

use lib qw(t/lib lib ../Apache-Test/lib);

MyTest->new->run(@ARGV);

# sub-class Apache::TestRunPerl
package MyTest;

use base qw(Apache::TestRunPerl);

# have a few servers to have better testing
use constant MIN_CLIENTS => 3;

# subclass new_test_config to add some config vars which will be
# replaced in generated httpd.conf
sub new_test_config {
    my $self = shift;

    $self->{conf_opts}->{minclients} ||= MIN_CLIENTS;

    return $self->SUPER::new_test_config;
}

sub bug_report {
    my $self = shift;

    print <<EOI;
+--------------------------------------------------------+
| Please file a bug report: http://perl.apache.org/bugs/ |
+--------------------------------------------------------+
EOI
}
