package GitInsight;


# XXX: Add behavioural change detection, focusing on that period for predictions
# XXX: CA output

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
    qw(markov markov_list LABEL_DIM gen_m_mat gen_trans_mat info error warning wday label prob);
use List::Util qw(max);

use LWP::UserAgent;

has 'username';
has 'contribs';
has 'no_day_stats' => sub {0};
has 'statistics'   => sub {0};

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

# first argument is the data:
# it should be a string in the form [ [2013-01-20, 9], ....    ] a stringified form of arrayref. each element must be an array ref containing in the first position the date, and in the second the commits .
sub decode {
    my $self       = shift;
    my $response   = eval(shift);
    my $max_commit = max( map { $_->[1] } @{$response} ); #Calculating label steps
    $GitInsight::Util::label_step=int($max_commit/LABEL_DIM);  #XXX: i'm not 100% sure of that
    info "Step is ".$GitInsight::Util::label_step.", detected $max_commit of maximum commit in one day";
    my $min = shift || 0;
    $min = 0 if ( $min < 0 );    # avoid negative numbers
    my $max = shift || ( scalar( @{$response} ) - $min );
    $max = scalar( @{$response} )
        if $max > scalar( @{$response} )
        ;    # maximum cutoff boundary it's array element number
    $self->{transition} = gen_trans_mat( $self->no_day_stats );
    my $last;
    my %hash;

    # $self->{max_commit} =0;

    %hash = $self->no_day_stats
        ? map {
        my $l = label( $_->[1] );
        $last = $l if ( !$last );

        $self->{stats}->{$l}++
            if $self->statistics == 1;    #filling stats hashref
        $self->{transition_hash}->{$last}->{$l}++;    #filling stats hashref
        $self->{transition_hash}->{t}++;    #total of transitions for each day
        $self->{transition}->slice("$last,$l")++;   #filling transition matrix
            #$self->{max_commit} = $_->[1] if ($_->[1]>$self->{max_commit});
        $last = $l;
        $_->[0] => {
            c => $_->[1],    #commits
            l => $l          #label
            }

        } ( $min != 0 || $max != scalar @{$response} )
            ? splice( @{$response}, $min, $max )
            : @{$response}
        : map {
        my $w = wday( $_->[0] );
        my $l = label( $_->[1] );
        $last = $l if ( !$last );

        $self->{stats}->{$w}->{$l}++
            if $self->statistics == 1;    #filling stats hashref
        $self->{transition_hash}->{$w}->{$last}
            ->{$l}++;                     #filling stats hashref
        $self->{transition_hash}->{$w}
            ->{t}++;                      #total of transitions for each day
        $self->{transition}->{$w}
            ->slice("$last,$l")++;        #filling transition matrix
        $last = $l;
        $_->[0] => {
            c => $_->[1],                 #commits
            d => $w,                      #day in the week
            l => $l                       #label
            }

        } ( $min != 0 || $max != scalar @{$response} )
        ? splice( @{$response}, $min, $max )
        : @{$response};
    $self->{last_week}
        = [ map { [ $_->[0], label( $_->[1] ) ] } @{$response}[ -7 .. -1 ] ]
        ; # cutting the last week from the answer and substituting the label instead of the commit number
          #print( $self->{transition}->{$_} ) for ( keys $self->{transition} );
    $self->contribs(%hash);
    return %hash;
}

sub process {
    my $self = shift;

    #  $self->display_stats;

    $self->_transition_matrix;
    return $self->_markov;

    #print( $self->{transition}->{$_} ) for ( keys $self->{transition} );

    #  use Data::Dumper;
    # print Dumper( $self->{stats} );

}

sub display_stats {
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

}

sub _markov {
    my $self = shift;
    info "Markov chain phase";
    my $dayn = 1;
    foreach my $day ( @{ $self->{last_week} } ) {
        my $wd = wday( $day->[0] );
        my $ld = $day->[1];

        # my ( $label, $prob ) = markov_prob(
        #     gen_m_mat($ld),
        #     $self->no_day_stats
        #     ? $self->{transition}
        #     : $self->{transition}->{$wd},
        #     $dayn
        # );

        my $M = markov_list(
            gen_m_mat($ld),
            $self->no_day_stats
            ? $self->{transition}
            : $self->{transition}->{$wd},
            $dayn
        );

        push( @{ $self->{result} }, [ $wd, $M ] );

        info "for $wd:";
        info $_. " ---- " . sprintf "%.2f", $M->[$_] * 100
            for 0 .. scalar(@$M) - 1;

            my $label=0;
            $M->[$label] > $M->[$_] or $label = $_ for 1 .. scalar(@$M) - 1;
            info "Is likely that $label is going to happen";

        #     $prob = sprintf "%.2f", $prob * 100;
        #   info "Day: $wd  $prob \% of probability for Label $label";
        $dayn++ if $self->no_day_stats;
    }

    return $self->{result};

}

sub _transition_matrix {

#transition matrix, sum all the transitions occourred in each day,  and do prob(sumtransiction ,current transation occurrance )
    my $self = shift;
    info "Going to build transation matrix probabilities";
    if ( $self->no_day_stats ) {
        map {
            foreach my $c ( 0 .. LABEL_DIM ) {
                $self->{transition}->slice("$_,$c")
                    .= prob( # slice of the single element of the matrix , calculating bayesian inference
                    $self->{transition_hash}->{t}
                    ,        #contains the transiactions sum
                    $self->{transition}->slice("$_,$c")
                    );       # all the transation occurred, current transation
            }
        } ( 0 .. LABEL_DIM );
    }
    else {
        foreach my $k ( keys %{ $self->{transition} } ) {
            map {
                foreach my $c ( 0 .. LABEL_DIM ) {
                    $self->{transition}->{$k}->slice("$_,$c")
                        .= prob( # slice of the single element of the matrix , calculating bayesian inference
                        $self->{transition_hash}->{$k}->{t}
                        ,        #contains the transiactions sum over the day
                        $self->{transition}->{$k}->slice("$_,$c")
                        )
                        ; # all the transation occurred in those days, current transation
                }
            } ( 0 .. LABEL_DIM );
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

GitInsight - Predict your github contributions using Bayesian inference and Markov chain

=head1 SYNOPSIS

    gitinsight --username [githubusername] (--nodaystats) #using the shipped bin

    #or using the module

    my $Insight= GitInsight->new(no_day_stats=>0);
    $Insight->contrib_calendar("markov"); #specify here the github username
    my $Result= $Insight->process;
    $Result = $Insight->{result};
    # $Result contains the next week predictions and is an arrayref of arrayrefs    [  [ 'Sat', [ 0 ,  '0.151515151515152', '0.0606060606060606', '0.0404040404040404',  0  ]  ],   ..   [            'DayofWeek',            [             probability_label_0,  probability_label_1,              probability_label_2,          probability_label_3,              probability_label_4            ]          ]]


=head1 DESCRIPTION

GitInsight is module that allow you to predict your github contributions in the "calendar contribution" style of github (the table of contribution that you see on your profile page).

=head1 INSTALLATION

GitInsight requires the installation of gsl (GNU scientific library), PDL, PGPLOT (for plotting) and PDL::Stats  (to be installed after the gsl library set).

It's reccomended to use cpanm to install all the required deps, install it thru your package manager or just do:

    cpan App::cpanminus

After the installation of gsl, you can install all the dependencies with cpanm:
    cpanm --installldeps .


=head1 AUTHOR

mudler E<lt>mudler@dark-lab.netE<gt>

=head1 COPYRIGHT

Copyright 2014- mudler

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
