# NAME

GitInsight - Predict your github contributions using Bayesian inference and Markov chain

# SYNOPSIS

    gitinsight --username [githubusername] (--nodaystats) #using the shipped bin

    #or using the module

    my $Insight= GitInsight->new(no_day_stats=>0);
    $Insight->contrib_calendar("markov"); #specify here the github username
    my $Result= $Insight->process;
    $Result = $Insight->{result};
    # $Result contains the next week predictions and is an arrayref of arrayrefs    [  [ 'Sat', [ 0 ,  '0.151515151515152', '0.0606060606060606', '0.0404040404040404',  0  ]  ],   ..   [            'DayofWeek',            [             probability_label_0,  probability_label_1,              probability_label_2,          probability_label_3,              probability_label_4            ]          ]]

# DESCRIPTION

GitInsight is module that allow you to predict your github contributions in the "calendar contribution" style of github (the table of contribution that you see on your profile page).

# INSTALLATION

GitInsight requires the installation of gsl (GNU scientific library), gd(http://libgd.org/), PDL, PGPLOT (for plotting) and PDL::Stats  (to be installed after the gsl library set).

It's reccomended to use cpanm to install all the required deps, install it thru your package manager or just do:

    cpan App::cpanminus

After the installation of gsl, you can install all the dependencies with cpanm:

    cpanm --installldeps .

# AUTHOR

mudler <mudler@dark-lab.net>

# COPYRIGHT

Copyright 2014- mudler

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO
