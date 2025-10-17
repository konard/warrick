#!/usr/bin/perl -w
#
# Simple test script to verify the fix for issue #17
# Tests the regex pattern that strips filenames from paths
#

use strict;

sub test_path_stripping {
    my ($path, $expected) = @_;

    my $basePath = $path;
    # Remove filename from path, keeping only the directory portion
    $basePath =~ s/[^\/]+$//;
    $basePath = '/' if $basePath eq '';

    my $result = ($basePath eq $expected) ? "PASS" : "FAIL";
    print "$result: Input: '$path' => Expected: '$expected', Got: '$basePath'\n";

    return ($basePath eq $expected);
}

print "Testing path filename stripping for issue #17\n";
print "=" x 60 . "\n\n";

my $passed = 0;
my $failed = 0;

# Test case 1: File in root
if (test_path_stripping("/2000.html", "/")) {
    $passed++;
} else {
    $failed++;
}

# Test case 2: File in root (another example)
if (test_path_stripping("/index.html", "/")) {
    $passed++;
} else {
    $failed++;
}

# Test case 3: File in subdirectory
if (test_path_stripping("/dir1/dir2/page.html", "/dir1/dir2/")) {
    $passed++;
} else {
    $failed++;
}

# Test case 4: File in single subdirectory
if (test_path_stripping("/images/logo.png", "/images/")) {
    $passed++;
} else {
    $failed++;
}

# Test case 5: Deep nested directory
if (test_path_stripping("/a/b/c/page.html", "/a/b/c/")) {
    $passed++;
} else {
    $failed++;
}

# Test case 6: Root path only
if (test_path_stripping("/", "/")) {
    $passed++;
} else {
    $failed++;
}

# Test case 7: Empty string (should become /)
my $empty = "";
$empty =~ s/[^\/]+$//;
$empty = '/' if $empty eq '';
if ($empty eq '/') {
    print "PASS: Empty string => '/'\n";
    $passed++;
} else {
    print "FAIL: Empty string => Expected: '/', Got: '$empty'\n";
    $failed++;
}

print "\n" . "=" x 60 . "\n";
print "Test Results: $passed passed, $failed failed\n";

if ($failed == 0) {
    print "All tests PASSED! ✓\n";
    exit 0;
} else {
    print "Some tests FAILED! ✗\n";
    exit 1;
}
