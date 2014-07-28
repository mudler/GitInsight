package GitInsight::Util;
use base 'Exporter';
use GitInsight::Obj -strict;
use Time::Local;
use PDL::LiteF;
use PDL::Lite;
use PDL::Stats;
use PDL::Graphics::Simple;

# EVENTS LABELS:
use constant NO_CONTRIBUTIONS     => 0;
use constant FEW_CONTRIBUTIONS    => 1;
use constant NORMAL_CONTRIBUTIONS => 2;
use constant MORE_CONTRIBUTIONS   => 3;
use constant HIGH_CONTRIBUTIONS   => 4;

# LABEL ARRAY:
our @CONTRIBS = (
    NO_CONTRIBUTIONS,     FEW_CONTRIBUTIONS,
    NORMAL_CONTRIBUTIONS, MORE_CONTRIBUTIONS,
    HIGH_CONTRIBUTIONS
);

# LABEL DIMENSION, STARTING TO 0

use constant LABEL_DIM => 4;    # D:5

our @EXPORT    = qw(info error warning);
our @EXPORT_OK = (
    qw( markov gen_m_mat dim gen_trans_mat LABEL_DIM wday label prob plot), @EXPORT
);
our @wday = qw/Mon Tue Wed Thu Fri Sat Sun/;

sub info {
    print "[info] - @_  \n";
}

sub error {
    print STDERR "[error] - @_  \n";
}

sub warning {
    print "[warning] - @_  \n";
}

sub wday {    # 2014-03-15 -> DayName
    my ( $mday, $mon, $year ) = reverse( split( /-/, shift ) );
    return
        $wday[ ( localtime( timelocal( 0, 0, 0, $mday, $mon - 1, $year ) ) )
        [6] - 1 ];
}

sub gen_trans_mat {
    my $h = {};
    $h->{$_} = zeroes scalar(@CONTRIBS), scalar(@CONTRIBS) for @wday;
    return $h;
}

sub gen_m_mat {
    my $label = shift;
    my $h = zeroes( scalar(@CONTRIBS), 1 );
    $h->slice("$label,0") .= 1;
    return $h;
}

sub markov {
    my $a      = shift;
    my $b      = shift;
    my $markov = $a x $b;
    my $index=maximum_ind($markov)->at(0);
    return ($index,$markov->slice("$index,0")->at(0,0));
}

sub label {
    return NO_CONTRIBUTIONS     if ( $_[0] == 0 );
    return FEW_CONTRIBUTIONS    if ( $_[0] > 0 and $_[0] <= 5 );
    return NORMAL_CONTRIBUTIONS if ( $_[0] >= 6 and $_[0] <= 11 );
    return MORE_CONTRIBUTIONS   if ( $_[0] >= 12 and $_[0] <= 17 );
    return HIGH_CONTRIBUTIONS   if ( $_[0] >= 18 );
}

sub prob {
    my $n     = shift;
    my $event = shift;
    my $x = zeroes(100)->xlinvals( 0, 1 );  # 0 padding from 0->1 of 100 steps
    return $x->index(    #find the index within the matrix probs
        maximum_ind(     #takes the maximum index of the funct
            pdf_beta( $x, ( 1 + $event ),
                ( 1 + $n - $event ) )    #y: happens vs not happens
        )
    );
}

sub plot {
    my $n     = shift;
    my $event = shift;
    my $x     = zeroes(100)->xlinvals( 0.01, 0.99 )
        ;                                # 0 padding from 0->1 of 100 steps
    info "N: $n , event $event";
    my $y = pdf_beta( $x, ( 1 + $event ), ( 1 + $n - $event ) );
    line $x, $y;
    info "Maximum: " . maximum_ind(      #takes the maximum index of the funct
        $y
    );
    info "\$x ->" . $x->index(    #find the index within the matrix probs
        maximum_ind(              #takes the maximum index of the funct
            $y
        )
    );
    sleep 200;
}

1;
