#!/usr/bin/env perl -w
use strict;
system('mkdir -p meta');
for my $i (3109..4008) {
    system("sh ./list $i > source/meta/$i.html");
    sleep(1);
}
