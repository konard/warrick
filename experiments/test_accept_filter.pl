#!/usr/bin/perl
# Test script for URL accept filtering feature
# This script tests the accept pattern matching logic

use strict;
use warnings;

# Test URLs
my @test_urls = (
    'http://example.com/photo1.jpg',
    'http://example.com/photo2.jpeg',
    'http://example.com/photo3.JPG',
    'http://example.com/index.html',
    'http://example.com/page.php?id=123',
    'http://example.com/gallery/image.png',
    'http://example.com/downloads/file.pdf',
);

# Test patterns (simulating content from accept file)
my @patterns = (
    '\.jpg$',
    '\.jpeg$',
);

print "Testing Accept Pattern Matching\n";
print "=" x 50 . "\n\n";

print "Patterns:\n";
foreach my $p (@patterns) {
    print "  - $p\n";
}
print "\n";

print "Test URLs:\n";
foreach my $url (@test_urls) {
    my $matched = 0;
    my $matched_pattern = "";

    foreach my $pattern (@patterns) {
        if ($url =~ /$pattern/i) {
            $matched = 1;
            $matched_pattern = $pattern;
            last;
        }
    }

    if ($matched) {
        print "  ✓ ACCEPTED: $url (matched: $matched_pattern)\n";
    } else {
        print "  ✗ REJECTED: $url (no match)\n";
    }
}

print "\n" . "=" x 50 . "\n";
print "Test completed.\n";
