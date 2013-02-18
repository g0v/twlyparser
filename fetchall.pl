#!/usr/bin/env perl -w
use strict;
system('mkdir -p source/meta');
my ($from, $to) = @ARGV;
die "usage: $0 <from> [to]\n" unless $from;
$to ||= $from;
for my $i ($from..$to) {
    -e "source/meta/$i.html" || system("sh ./list $i > source/meta/$i.html");
    system("./node_modules/.bin/lsc ./parse-list.ls source/meta/$i.html");
    system("./node_modules/.bin/lsc ./prepare-source.ls --gazette $i");
    system("./node_modules/.bin/lsc ./get-source.ls --gazette $i");
    system("./node_modules/.bin/lsc ./get-source.ls --gazette $i");
    system("./node_modules/.bin/lsc ./get-source.ls --gazette $i");
    system("env LC_ALL=en_US.UTF-8 LANG=zh_TW.UTF-8 ./node_modules/.bin/lsc populate-sitting.ls --meta --force --gazette $i");
    system("env LC_ALL=en_US.UTF-8 LANG=zh_TW.UTF-8 ./node_modules/.bin/lsc populate-sitting.ls --meta --force --gazette $i --type committee");
}
