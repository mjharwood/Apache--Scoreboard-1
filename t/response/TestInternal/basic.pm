package TestInternal::basic;

use Apache::Test;
use Apache::TestRequest ();
use Apache::TestTrace;

use File::Spec::Functions qw(catfile);

use Apache::Scoreboard ();
use MyTest::Common ();

use Apache::Constants qw(:common);

my $tests_local  = 0;
my $tests_common = MyTest::Common::num_of_tests();

my $store_file = catfile $vars->{documentroot}, "scoreboard";
my $hostport = Apache::TestRequest::hostport($cfg);
my $retrieve_url = "http://$hostport/scoreboard";

sub handler {
    my $r = shift;

    plan $r, tests => $tests_local + $tests_common*2;

    my $cfg = Apache::Test::config();
    my $vars = $cfg->{vars};

    my @images = (
        Apache::Scoreboard->fetch($retrieve_url),
        Apache::Scoreboard->image(),
    );

    for my $image (@images) {
        die "no image fetched" unless $image;
        MyTest::Common::test($image);
    }

    return OK;
}
