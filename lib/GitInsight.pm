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

use GitInsight::Util qw(info error warning wday label prob);

use LWP::UserAgent;

has 'username';
has 'contribs';

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
        use Data::Dumper;
        my %hash = map {
            my $w = wday( $_->[0] );
            my $l = label( $_->[1] );
            $self->{stats}->{$w}->{$l}++;    #filling stats hashref
            $_->[0] => {
                c => $_->[1],                #commits
                d => $w,                     #day in the week
                l => $l                      #label
                }

        } @{ eval( $response->decoded_content ) };
        print Dumper( \%hash );
        print Dumper( $self->{stats} );

        $self->contribs(%hash);
        return $self->contribs;
    }
    else {
        die $response->status_line;
    }
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


    ##next: estimation of transition matrix : https://stackoverflow.com/questions/16845199/estimate-markov-chain-transition-matrix-in-matlab-with-different-state-sequence

    #https://stackoverflow.com/questions/11072206/constructing-a-multi-order-markov-chain-transition-matrix-in-matlab

    #https://www.imf.org/external/pubs/ft/wp/2005/wp05219.pdf
    #http://www.zweigmedia.com/RealWorld/Summary8.html
    #http://freakonometrics.hypotheses.org/6803
    #    http://www.mathworks.com/matlabcentral/newsreader/view_thread/278292

    use Data::Dumper;
    print Dumper( $self->{stats} );

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
