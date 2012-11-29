#!/usr/bin/env perl -w
use strict;
system('mkdir -p source/meta');
for my $i (3109..4010) {
    system("sh ./list $i > source/meta/$i.html");
    sleep(1);
}
