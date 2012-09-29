#!/bin/perl

use warnings;
use strict;

use lib `pwd`;
use WebsiteGet;

$\ = "\n\n\n\n";

my $wg = WebsiteGet->new();
$wg->userAgent("This is my header");
print $wg->getSite("http://www.google.com");
