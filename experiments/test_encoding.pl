#!/usr/bin/perl -w
# Test script to demonstrate UTF-8 encoding issue and fix

use strict;
use warnings;

print "=== Testing UTF-8 Encoding Issue ===\n\n";

# Simulate what happens without UTF-8 handling
print "WITHOUT binmode UTF-8:\n";
my $test_file = "experiments/test_without_utf8.html";
open(OUT, ">$test_file");
print OUT "<html><body>Testing: ó á ñ ü</body></html>\n";
close(OUT);

# Read it back
open(IN, $test_file);
my @lines = <IN>;
close(IN);
print "Content: " . join("", @lines) . "\n\n";

# Now WITH UTF-8 handling
print "WITH binmode UTF-8:\n";
my $test_file2 = "experiments/test_with_utf8.html";
open(OUT2, ">:utf8", $test_file2);
print OUT2 "<html><body>Testing: ó á ñ ü</body></html>\n";
close(OUT2);

# Read it back
open(IN2, "<:utf8", $test_file2);
my @lines2 = <IN2>;
close(IN2);
print "Content: " . join("", @lines2) . "\n\n";

print "=== Test Complete ===\n";
