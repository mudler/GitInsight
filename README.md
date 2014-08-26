# NAME

GitInsight - Predict your github contributions using Bayesian inference and Markov chain

# SYNOPSIS

    gitinsight --username [githubusername] (--nodaystats) (--accuracy) #using the shipped bin

    #or using the module

    my $Insight= GitInsight->new(no_day_stats=>0);
    $Insight->contrib_calendar("markov"); #specify here the github username
    my $Result= $Insight->process;
    $Result = $Insight->{result};
    # $Result contains the next week predictions and is an arrayref of arrayrefs    [  [ 'Sat', 1, '2014-07-1', [ 0 ,  '0.151515151515152', '0.0606060606060606', '0.0404040404040404',  0  ]  ],   ..   [            'DayofWeek',      'winner_label',  'day' ,  [             probability_label_0,  probability_label_1,              probability_label_2,          probability_label_3,              probability_label_4            ]          ]]

# DESCRIPTION

GitInsight is module that allow you to predict your github contributions in the "calendar contribution" style of github (the table of contribution that you see on your profile page).

# HOW DOES IT WORK?

GitInsight generates a transation probrability matrix from your github contrib\_calendar to compute the possibles states for the following days. Given that GitHub split the states thru 5 states (or here also called label), the probability can be inferenced by using Bayesian methods to update the beliefs of the possible state transition, while markov chain is used to predict the states. The output of the submitted data is then plotted using Cellular Automata.

## THEORY

We trace the transitions states in a matrix and increasing the count as far as we observe a transition ([https://en.wikipedia.org/wiki/Transition\_matrix](https://en.wikipedia.org/wiki/Transition_matrix)), then we inference the probabilities using Bayesan method [https://en.wikipedia.org/wiki/Bayesian\_inference](https://en.wikipedia.org/wiki/Bayesian_inference) [https://en.wikipedia.org/wiki/Examples\_of\_Markov\_chains](https://en.wikipedia.org/wiki/Examples_of_Markov_chains).

# INSTALLATION

GitInsight requires the installation of gsl (GNU scientific library), gd(http://libgd.org/), PDL and PDL::Stats  (to be installed after the gsl library set).

on Debian:

        apt-get install gsl-bin libgs10-devt
        apt-get install pdl libpdl-stats-perl libgd2-xpm-dev

It's reccomended to use cpanm to install all the required deps, install it thru your package manager or just do:

    cpan App::cpanminus

After the installation of gsl, you can install all the dependencies with cpanm:

    cpanm --installldeps .

# OPTIONS

## username

required, it's the GitHub username used to calculate the prediction

## ca\_output

you can enable/disable the cellular autmata output using this option (1/0)

## no\_day\_stats

setting this option to 1, will slightly change the prediction: it will be calculated a unique transition matrix instead one for each day

## left\_cutoff

used to cut the days from the start (e.g. if you want to delete the first 20 days from the prediction, just set this to 20)

## cutoff\_offset

used to select a range where the prediction happens (e.g. if you want to calculate the prediction of a portion of your year of contribution)

## file\_output

here you can choose the file output name for ca.

## accuracy

Enable/disable accuracy calculation (1/0)

## verbose

Enable/disable verbosity (1/0)

# METHODS

## contrib\_calendar($username)

Fetches the github contrib\_calendar of the specified user

## process

Calculate the predictions and generate the CA

## start\_day

Returns the first day of the contrib\_calendar

## last\_day

Returns the last day of the contrib calendar (prediction included)

## prediction\_start\_day

Returns the first day of the prediction (7 days of predictions)

# AUTHOR

mudler <mudler@dark-lab.net>

# COPYRIGHT

Copyright 2014- mudler

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

[GitInsight::Util](https://metacpan.org/pod/GitInsight::Util), [PDL](https://metacpan.org/pod/PDL)
