use ExtUtils::MakeMaker;

use strict;
use Apache::src ();

my $src = Apache::src->new;

WriteMakefile(
    'NAME'	=> 'Apache::Scoreboard',
    'VERSION_FROM' => 'Scoreboard.pm',
    'INC'       => $src->inc,
    'DEFINE' => $src->define,
    'TYPEMAPS' => $src->typemaps,
    'dist'    => {
        #PREOP => 'pod2text Scoreboard.pm > README',
    },
);

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
