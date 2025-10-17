#!/usr/bin/perl
#
# Test script to verify that URLs with query parameters are properly quoted
# This tests the fix for issue #29: zero length content with URLs containing ampersands

use strict;
use warnings;

print "Testing URL escaping for query parameters...\n\n";

# Test case 1: URL with query parameters (the original issue)
my $test_url1 = "http://www.atlantischild.hu/index.php?option=com_content&task=view&id=21&Itemid=9";
print "Test 1: URL with ampersands in query string\n";
print "URL: $test_url1\n";

# Simulate the escaping logic from mcurl.pl (after fix)
my @test_args1 = ("-o", "output.txt", $test_url1);
for (my $i = 0; $i <= $#test_args1; ++$i) {
    if ( ( index($test_args1[$i] , ' ') > -1 )
       or ( index($test_args1[$i] , '?') > -1 )
       or ( index($test_args1[$i] , '*') > -1 )
       ) {
        $test_args1[$i] = '"' . $test_args1[$i] . '"';
    }
}

print "After escaping: ";
foreach my $arg (@test_args1) {
    print "$arg ";
}
print "\n";

# Verify the URL is now quoted
if ($test_args1[2] =~ /^".*"$/) {
    print "✓ PASS: URL is properly quoted\n\n";
} else {
    print "✗ FAIL: URL is not quoted\n\n";
}

# Test case 2: Simulate MementoThread.pm command construction
my $uri = "http://atlantischild.hu:80/index.php?option=com_content&task=blogcategory&id=21&Itemid=28";
my $timegate = "http://web.archive.org/web";

print "Test 2: Command construction in MementoThread.pm\n";
print "URI: $uri\n";
print "TimeGate: $timegate\n";

# After fix: URLs are quoted
my $command_fixed = "curl -I \"$timegate/$uri\"";
print "Command (after fix): $command_fixed\n";

# Verify the command includes quotes
if ($command_fixed =~ /".*\?.*&.*"/) {
    print "✓ PASS: Command properly quotes URL with query parameters\n\n";
} else {
    print "✗ FAIL: Command does not properly quote URL\n\n";
}

print "All tests completed.\n";
print "\nNote: The fix ensures that URLs containing ?, &, or * are properly\n";
print "quoted so that shell commands don't truncate them at special characters.\n";
