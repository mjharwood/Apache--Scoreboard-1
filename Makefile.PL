use ExtUtils::MakeMaker;

use strict;
use Apache::src ();

my $src = Apache::src->new;

# enable 'make test|clean'
use Apache::TestMM qw(test clean);
# prerequisites

my %require = (
    "Apache::Test" => "1.10", # ipv6 fixes
    "mod_perl"     => "1.18",
);

my @scripts = qw(t/TEST);

# accept the configs from command line
Apache::TestMM::filter_args();
Apache::TestMM::generate_script('t/TEST');

WriteMakefile(
    NAME         => 'Apache::Scoreboard',
    VERSION_FROM => 'Scoreboard.pm',
    PREREQ_PM    => \%require,
    INC          => $src->inc,
    DEFINE       => $src->define,
    TYPEMAPS     => $src->typemaps,
    clean        => {
        FILES => "@{ clean_files() }",
    }
);

sub clean_files {
    return \@scripts;
}

sub MY::postamble {
    return <<'EOF';

cvs_tag :
	cvs -d $(CVSROOT) tag v$(VERSION_SYM) .
	@echo update Scoreboard.pm VERSION now
EOF
}

sub MY::top_targets {
    my $self = shift;
    my $string = $self->MM::top_targets;

    $string .= <<'EOF';
dummy:
	cd Dummy && $(PERL) Makefile.PL -g

EOF

    $string;
}
