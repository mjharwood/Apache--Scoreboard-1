package Apache::DummyScoreboard;

use strict;
use DynaLoader ();

BEGIN {
    use mod_perl;
    die "mod_perl < 2.0 is required" unless $mod_perl::VERSION < 1.99;
}

{
    no strict;
    $VERSION = '0.04';
    @ISA = qw(DynaLoader);
    __PACKAGE__->bootstrap($VERSION);
}

1;
__END__
