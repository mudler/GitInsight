package GitInsight;

# XXX: Add behavioural change detection, focusing on that period for predictions

BEGIN {
    $|  = 1;
    $^W = 1;
}
our $VERSION = '0.03';

use Carp::Always;
use GitInsight::Obj -base;
use strict;
use warnings;
use 5.008_005;
use GD::Simple;

use POSIX;
use Time::Local;
use GitInsight::Util
    qw(markov markov_list LABEL_DIM gen_m_mat gen_trans_mat info error warning wday label prob label_step);
use List::Util qw(max);

use LWP::UserAgent;
use POSIX qw(strftime ceil);

has 'username';
has 'contribs';
has 'no_day_stats' => sub {0};
has 'statistics'   => sub {0};
has 'ca_output'    => sub {1};
has [qw(left_cutoff cutoff_offset file_output)];

sub contrib_calendar {
    my $self = shift;
    my $username = shift || $self->username;
    $self->username($username) if !$self->username;
    my $ua = LWP::UserAgent->new;
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

sub draw_ca {
    my $self = shift;
    my @CA   = @_;
    my $cols = ceil( $#CA / 7 ) + 1;
    my $rows = 7;

    my $cell_width  = 50;
    my $cell_height = 50;
    my $border      = 3;
    my $width       = $cols * $cell_width;
    my $height      = $rows * $cell_height;

    my $img = GD::Simple->new( $width, $height );

    $img->font(gdSmallFont);    #i'll need that later
    for ( my $c = 0; $c < $cols; $c++ ) {
        for ( my $r = 0; $r < $rows; $r++ ) {
            my $color = $CA[ $c * $rows + $r ]
                or
                next; #infering ca from sequences of colours generated earlier
            my @topleft = ( $c * $cell_width, $r * $cell_height );
            my @botright = (
                $topleft[0] + $cell_width - $border,
                $topleft[1] + $cell_height - $border
            );
            $img->bgcolor( @{$color} );
            $img->fgcolor( @{$color} );
            $img->rectangle( @topleft, @botright );
            $img->moveTo( $topleft[0] + 2, $botright[1] + 2 );
            $img->fgcolor("red")
                and $img->rectangle( @topleft, @botright )
                if ( $c * $rows + $r >= ( scalar(@CA) - 7 ) );
            $img->fgcolor('black')
                and $img->string( $GitInsight::Util::wday[$r] )
                if ( $c == 0 );
        }
    }
    if ( defined $self->file_output ) {
        my $filename = $self->file_output . ".png";

        #. "/"
        #. join( "_", $self->start_day, $self->last_day ) . "_"
        #. $self->username . "_"
        #. scalar(@CA) .
        open my $PNG, ">" . $filename;
        binmode($PNG);
        print $PNG $img->png;
        close $PNG;
        info "File written in : " . $filename;
        return $filename;
    }
    else {
        return $img->png;
    }

}

# useful when interrogating the object
sub start_day            { shift->{first_day}->{data} }
sub last_day             { @{ shift->{result} }[-1]->[2] }
sub prediction_start_day { @{ shift->{result} }[0]->[2] }

# first argument is the data:
# it should be a string in the form [ [2013-01-20, 9], ....    ] a stringified form of arrayref. each element must be an array ref containing in the first position the date, and in the second the commits .
sub decode {
    my $self     = shift;
    my $response = eval(shift);
    my %commits_count;
    my $min = $self->left_cutoff || 0;
    $min = 0 if ( $min < 0 );    # avoid negative numbers
    info $min;
    my $max
        = $self->cutoff_offset || ( scalar( @{$response} ) - 1 );
    info "$min -> $max portion";
        my $max_commit
        = max( map { $_->[1] } @{$response} );    #Calculating label steps
            label_step( 0 .. $max_commit ); #calculating quartiles over commit count

        info("Max commit is: ".$max_commit);
    $max = scalar( @{$response} )
        if $max > scalar( @{$response} )
        ;    # maximum cutoff boundary it's array element number
    $self->{first_day}->{day} = wday( $response->[0]->[0] )
        ; #getting the first day of the commit calendar, it's where the ca will start

    my ($index)
        = grep { $GitInsight::Util::wday[$_] eq $self->{first_day}->{day} }
        0 .. $#GitInsight::Util::wday;
    $self->{first_day}->{index} = $index;
    $self->{first_day}->{data}  = $response->[$min]->[0];
    push( @{ $self->{ca} }, [ 255, 255, 255 ] )
        for (
        0 .. scalar(@GitInsight::Util::wday)    #white fill for labels
        + ( $index - 1 )
        );                                      #white fill for no contribs

    $self->{transition} = gen_trans_mat( $self->no_day_stats );
    my $last;
    $self->{last_week}
        = [ map { [ $_->[0], label( $_->[1] ) ] }
            ( @{$response} )[ ( $max - 6 ) .. $max ] ]
        ; # cutting the last week from the answer and substituting the label instead of the commit number
          #print( $self->{transition}->{$_} ) for ( keys $self->{transition} );
          # $self->{max_commit} =0;
    info "Decoding .." . scalar( @{$response} );

    $self->contribs(
        $self->no_day_stats
        ? map {
            my $l = label( $_->[1] );
            push( @{ $self->{ca} }, $GitInsight::Util::CA_COLOURS{$l} )
                ;    #building the ca
            $last = $l if ( !$last );
        #    $commits_count{ $_->[1] } = 1;
            $self->{stats}->{$l}++
                if $self->statistics == 1;    #filling stats hashref
            $self->{transition_hash}->{$last}->{$l}++
                ; #filling transition_hash hashref from $last (last seen label) to current label
            $self->{transition_hash}
                ->{t}++;    #total of transitions for each day
            $self->{transition}
                ->slice("$last,$l")++;    #filling transition matrix
              #$self->{max_commit} = $_->[1] if ($_->[1]>$self->{max_commit});
            $last = $l;
            $_->[0] => {
                c => $_->[1],    #commits
                l => $l          #label
                }

            } splice( @{$response}, $min, ( $max + 1 ) )
        : map {
            my $w = wday( $_->[0] );
            my $l = label( $_->[1] );
            push( @{ $self->{ca} }, $GitInsight::Util::CA_COLOURS{$l} );
            $last = $l if ( !$last );
         #   $commits_count{ $_->[1] } = 1;
            $self->{stats}->{$w}->{$l}++
                if $self->statistics == 1;    #filling stats hashref
            $self->{transition_hash}->{$w}->{$last}
                ->{$l}++;                     #filling stats hashref
            $self->{transition_hash}->{$w}
                ->{t}++;    #total of transitions for each day
            $self->{transition}->{$w}
                ->slice("$last,$l")++;    #filling transition matrix
            $last = $l;
            $_->[0] => {
                c => $_->[1],             #commits
                d => $w,                  #day in the week
                l => $l                   #label
                }

        } splice( @{$response}, $min, ( $max + 1 ) )
    );

    return $self->contribs;
}

sub process {
    my $self = shift;
    $self->_transition_matrix;
    $self->_markov;
    $self->{png} = $self->draw_ca( @{ $self->{ca} } )
        if ( $self->ca_output == 1 );
    return $self;
}

sub _markov {
    my $self = shift;
    info "Markov chain phase";
    my $dayn = 1;
    info "Calculating predictions for "
        . ( scalar( @{ $self->{last_week} } ) ) . " days";

    foreach my $day ( @{ $self->{last_week} } ) {    #cycling the last week
        my $wd = wday( $day->[0] );                  #computing the weekday
        my $ld = $day->[1];                          #getting the label
        my $M  = markov_list(
            gen_m_mat($ld),
            $self->no_day_stats
            ? $self->{transition}
            : $self->{transition}->{$wd},
            $dayn
        );    #Computing the markov for the state

        my $label = 0;
        $M->[$label] > $M->[$_] or $label = $_ for 1 .. scalar(@$M) - 1;
        push( @{ $self->{ca} }, $GitInsight::Util::CA_COLOURS{$label} )
            ;    #adding the predictions to ca

        my ( $mday, $mon, $year )
            = reverse( split( /-/, $day->[0] ) );    #splitting date

        push(
            @{ $self->{result} },
            [   $wd, $label,
                $day->[0] = strftime(
                    '%Y-%m-%d',
                    localtime(
                        timelocal( 0, 0, 0, $mday, $mon - 1, $year )
                            + 7 * 86_400
                    )
                    ) #adding 7 days to the date, and adding the result to $self->{result}
                ,
                $M
            ]
        );
        info "$wd: "
            . $label . " has "
            . ( sprintf "%.2f", $M->[$label] * 100 )
            . "% of probability to happen";
        info "\t" . $_ . " ---- " . ( sprintf "%.2f", $M->[$_] * 100 ) . "%"
            for 0 .. scalar(@$M) - 1;

        ############# TREEMAP GENERATION #############
        $self->{'treemap'}->{'name'} = "day";
        my $hwd = { name => $day->[0], children => [] };
        push(
            @{ $hwd->{children} },
            { name => $_, size => $M->[$_] * 10000 }
        ) for 0 .. scalar(@$M) - 1;
        push( @{ $self->{'treemap'}->{"children"} }, $hwd );
        ################################################

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
                        ||= 0,    #contains the transiactions sum
                    $self->{transition}->slice("$_,$c")
                    );    # all the transation occurred, current transation
            }
        } ( 0 .. LABEL_DIM );
    }
    else {
        foreach my $k ( keys %{ $self->{transition} } ) {
            map {
                foreach my $c ( 0 .. LABEL_DIM ) {
                    $self->{transition}->{$k}->slice("$_,$c")
                        .= prob( # slice of the single element of the matrix , calculating bayesian inference
                        $self->{transition_hash}->{$k}->{t} ||= 0
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

GitInsight requires the installation of gsl (GNU scientific library), gd(http://libgd.org/), PDL, PGPLOT (for plotting) and PDL::Stats  (to be installed after the gsl library set).

on Debian:

        apt-get install gsl-bin libgs10-devt apt-get install pdl libpdl-stats-perl libgd2-xpm-dev

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
