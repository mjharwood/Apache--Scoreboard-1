#!/usr/bin/perl -w

use strict;
use warnings FATAL => 'all';

local $| = 1;

use MyTest::Common ();

use Apache::Test;
use Apache::TestRequest ();
use Apache::TestTrace;

use File::Spec::Functions qw(catfile);

my $tests_local  = 0;
my $tests_common = MyTest::Common::num_of_tests();

plan tests => $tests_local + $tests_common;

my $cfg = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($cfg);
my $retrieve_url = "http://$hostport/scoreboard";

my $image = Apache::Scoreboard->fetch($retrieve_url);

die "no image fetched" unless $image;

MyTest::Common::test($image);
