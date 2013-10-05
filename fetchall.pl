#!/usr/bin/env perl -w
use strict;
system('mkdir -p source/meta');
my ($from, $to) = @ARGV;
die "usage: $0 <from> [to]\n" unless $from;
$to ||= $from;

system("./node_modules/.bin/lsc ./update-data-json.ls --from $from --to $to");

for my $i ($from..$to) {
    system("./node_modules/.bin/lsc ./get-source.ls --gazette $i");
    system("./node_modules/.bin/lsc ./get-source.ls --gazette $i");
    system("./node_modules/.bin/lsc ./get-source.ls --gazette $i");
    system("env LC_ALL=en_US.UTF-8 LANG=zh_TW.UTF-8 ./node_modules/.bin/lsc populate-sitting.ls --meta --force --gazette $i");
    system("env LC_ALL=en_US.UTF-8 LANG=zh_TW.UTF-8 ./node_modules/.bin/lsc populate-sitting.ls --meta --force --gazette $i --type committee");
}
