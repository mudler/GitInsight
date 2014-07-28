package GitInsight;

BEGIN {
    $|  = 1;
    $^W = 1;
}
our $VERSION = '0.01';

use Carp::Always;
use GitInsight::Obj -base;
use strict;
use warnings;
use 5.008_005;
use Data::Dumper;

use GitInsight::Util
    qw(LABEL_DIM gen_trans_mat info error warning wday label prob);

use LWP::UserAgent;

has 'username';
has 'contribs';

sub new {
    my $self = shift;
    $self = $self->SUPER::new(@_);
    $self->{transition} = gen_trans_mat;
    return $self;
}

sub contrib_calendar {
    my $self     = shift;
    my $username = shift || $self->username;
    my $ua       = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    my $response
        = $ua->get( 'https://github.com/users/'
            . $username
            . '/contributions_calendar_data' );

    if ( $response->is_success ) {
        $self->decode( $response->decoded_content );
        return $self->contribs;
    }
    else {
        die $response->status_line;
    }
}

sub decode {
    my $self     = shift;
    my $response = eval(shift);
    my $last;
    my %hash = map {
        my $w = wday( $_->[0] );
        my $l = label( $_->[1] );
        $last = $l if ( !$last );

        $self->{stats}->{$w}->{$l}++;    #filling stats hashref
        $self->{transition_hash}->{$w}->{$last}
            ->{$l}++;                    #filling stats hashref
        $self->{transition_hash}->{$w}
            ->{t}++;                     #total of transitions for each day
        $self->{transition}->{$w}
            ->slice("$last,$l")++;       #filling transition matrix
        $last = $l;
        $_->[0] => {
            c => $_->[1],                #commits
            d => $w,                     #day in the week
            l => $l                      #label
            }

    } @{$response};
    print Dumper( \%hash );
    $self->{last_week} = map { [ $_->[0], label( $_->[1] ) ] }
        @{$response}[ -7 .. -1 ]
        ; # cutting the last week from the answer and substituting the label instead of the commit number
    info "some stats";
    print Dumper( $self->{stats} );
    info "Transition table is";
    print Dumper( $self->{transition_hash} );
    print( $self->{transition}->{$_} ) for ( keys $self->{transition} );
    $self->contribs(%hash);
    return %hash;
}

sub process {
    my $self = shift;
    my $sum;

    foreach my $k ( keys %{ $self->{stats} } ) {
        $sum = 0;
        $sum += $_ for values %{ $self->{stats}->{$k} };
        map {
            info "Calculating probability for $k -> label $_  $sum /  "
                . $self->{stats}->{$k}->{$_};
            my $prob = prob( $sum, $self->{stats}->{$k}->{$_} );
            info "Is: $prob";
            $self->{stats}->{$k}->{$_} = sprintf "%.5f", $prob;
        } ( keys %{ $self->{stats}->{$k} } );
    }

    $self->transition_matrix;
    $self->markov;

    print( $self->{transition}->{$_} ) for ( keys $self->{transition} );

    use Data::Dumper;
    print Dumper( $self->{stats} );

}

sub markov{

}

sub transition_matrix {

#transition matrix, sum all the transitions occourred,  and do prob(sumtransiction ,current transation occurrance )
    my $self = shift;
    info "Going to calculate transation probabilities";
    foreach my $k ( keys %{ $self->{transition} } ) {
        info "There are "
            . $self->{transition}->{$k}->nelem
            . " elements in $k";
        map {
            foreach my $c ( 0 .. LABEL_DIM ) {
                $self->{transition}->{$k}->slice("$_,$c") .= prob(
                    $self->{transition_hash}->{$k}->{t},
                    $self->{transition}->{$k}->slice("$_,$c")
                    )
                    ; # all the transation occurred in those days, current transation
            }
        } ( 0 .. LABEL_DIM );
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

GitInsight - Blah blah blah

=head1 SYNOPSIS

  use GitInsight;

=head1 DESCRIPTION

GitInsight is
Needs pgplot and PDL PGPLOT PDL::Stats sci-libs/gsl-1.15

=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
