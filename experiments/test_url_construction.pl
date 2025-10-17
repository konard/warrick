#!/usr/bin/perl -w
#
# Test script to verify the fix for issue #17 - Crash Recovery URL construction
#
# This script tests that relative URLs are correctly resolved to absolute URLs
# without creating malformed paths like http://site.org/file.html/path/file.html
#

use strict;
use URI::URL;

sub trim {
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

sub test_url_construction {
    my ($base_url, $relative_url, $expected) = @_;

    my $tempURI = new URI::URL $base_url;
    my $url1 = $relative_url;

    # This is the OLD buggy code (commented out):
    # $url1 = "http://" . trim($tempURI->host) . "" . $tempURI->path . $url1;

    # This is the NEW fixed code:
    my $basePath = $tempURI->path;
    # Remove filename from path, keeping only the directory portion
    $basePath =~ s/[^\/]+$//;
    $basePath = '/' if $basePath eq '';
    $url1 = "http://" . trim($tempURI->host) . "" . $basePath . $url1;

    my $result = ($url1 eq $expected) ? "PASS" : "FAIL";
    print "$result: Base: $base_url + Relative: $relative_url\n";
    print "       Expected: $expected\n";
    print "       Got:      $url1\n";
    print "\n";

    return ($url1 eq $expected);
}

print "Testing URL construction fix for issue #17\n";
print "=" x 60 . "\n\n";

my $passed = 0;
my $failed = 0;

# Test case 1: The original problem from issue #17
if (test_url_construction(
    "http://etpv.org/2000.html",
    "2000/example1.html",
    "http://etpv.org/2000/example1.html"
)) {
    $passed++;
} else {
    $failed++;
}

# Test case 2: Another case from issue #17
if (test_url_construction(
    "http://etpv.org/2000.html",
    "2000/example2.html",
    "http://etpv.org/2000/example2.html"
)) {
    $passed++;
} else {
    $failed++;
}

# Test case 3: File in subdirectory
if (test_url_construction(
    "http://example.com/dir1/dir2/page.html",
    "image.jpg",
    "http://example.com/dir1/dir2/image.jpg"
)) {
    $passed++;
} else {
    $failed++;
}

# Test case 4: File in root
if (test_url_construction(
    "http://example.com/index.html",
    "about.html",
    "http://example.com/about.html"
)) {
    $passed++;
} else {
    $failed++;
}

# Test case 5: Relative path with subdirectory
if (test_url_construction(
    "http://example.com/page.html",
    "images/logo.png",
    "http://example.com/images/logo.png"
)) {
    $passed++;
} else {
    $failed++;
}

# Test case 6: Deep nested directory
if (test_url_construction(
    "http://example.com/a/b/c/page.html",
    "d/file.html",
    "http://example.com/a/b/c/d/file.html"
)) {
    $passed++;
} else {
    $failed++;
}

print "=" x 60 . "\n";
print "Test Results: $passed passed, $failed failed\n";

if ($failed == 0) {
    print "All tests PASSED!\n";
    exit 0;
} else {
    print "Some tests FAILED!\n";
    exit 1;
}
