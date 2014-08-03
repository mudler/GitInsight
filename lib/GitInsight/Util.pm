package GitInsight::Util;
use base 'Exporter';
use GitInsight::Obj -strict;
use Time::Local;
use PDL::LiteF;
use PDL::Lite;
use PDL::Stats;

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

our %CA_COLOURS = (
    +NO_CONTRIBUTIONS()     => [ 238, 238, 238 ],
    +FEW_CONTRIBUTIONS()    => [ 214, 230, 133 ],
    +NORMAL_CONTRIBUTIONS() => [ 140, 198, 101 ],
    +MORE_CONTRIBUTIONS()   => [ 68,  163, 64 ],
    +HIGH_CONTRIBUTIONS()   => [ 30,  104, 35 ]
);

our $label_step;

# LABEL DIMENSION, STARTING TO 0

use constant LABEL_DIM => 4;    # D:5 0 to 4

our @EXPORT    = qw(info error warning);
our @EXPORT_OK = (
    qw(markov_prob markov gen_m_mat dim gen_trans_mat markov_list LABEL_DIM wday label prob

        ),
    @EXPORT
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

sub wday {    # 2014-03-15 -> DayName  ( Dayname element of @wday )
    my ( $mday, $mon, $year ) = reverse( split( /-/, shift ) );
    return
        $wday[ ( localtime( timelocal( 0, 0, 0, $mday, $mon - 1, $year ) ) )
        [6] - 1 ];
}

sub gen_trans_mat {
    my $no_day_stats = shift || 0;
    return zeroes scalar(@CONTRIBS), scalar(@CONTRIBS)
        if ($no_day_stats);
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
    my $a   = shift;
    my $b   = shift;
    my $pow = shift || 1;
    return ( $pow != 1 ) ? $a x ( $b**$pow ) : $a x $b;
}

sub markov_list {
    my $a   = shift;
    my $b   = shift;
    my $pow = shift || 1;
    return [ list( ( $pow != 1 ) ? $a x ( $b**$pow ) : $a x $b ) ];

}

sub markov_prob {
    my $a      = shift;
    my $b      = shift;
    my $pow    = shift || 1;
    my $markov = &markov( $a, $b, $pow );
    my $index  = maximum_ind($markov)->at(0);
    return ( $index, $markov->slice("$index,0")->at( 0, 0 ) );
}

sub label {

    # XXX: i'm not really sure about that
    local $label_step = $label_step || 5;
    return NO_CONTRIBUTIONS if ( $_[0] == 0 );
    return FEW_CONTRIBUTIONS if ( $_[0] > 0 and $_[0] <= $label_step );
    return NORMAL_CONTRIBUTIONS
        if ( $_[0] > $label_step and $_[0] <= $label_step * 2 );
    return MORE_CONTRIBUTIONS
        if ( $_[0] >= $label_step * 2 and $_[0] <= $label_step * 3 );
    return HIGH_CONTRIBUTIONS if ( $_[0] > $label_step * 3 );
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

1;
