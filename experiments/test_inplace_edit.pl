#!/usr/bin/perl
use strict;
use warnings;

# Test script to verify Perl in-place editing works correctly
# This tests the replacement of sed system calls with Perl's native stream editing

# Create a test file
my $test_file = "experiments/test_input.html";
open(my $fh, '>', $test_file) or die "Cannot create test file: $!";
print $fh <<'EOF';
<html>
<a href="http://www.example.com/page1">Link 1</a>
<a href="http://www.example.com/page2">Link 2</a>
<img src="http://wayback.archive-it.org/1234/abc.jpg/image.jpg">
<script src="http://webarchive.loc.gov/./scripts/main.js"></script>
<link href="http://www.webarchive.org.uk/wayback/archive/20080101/style.css">
</html>
EOF
close($fh);

print "Original file content:\n";
system("cat $test_file");
print "\n" . "=" x 60 . "\n";

# Test the in-place editing approach
my $host = "http:\\/\\/www\\.example\\.com";
my $replace = "../..";

{
	local @ARGV = ($test_file);
	local $^I = '';  # in-place editing
	while (<>) {
		# Replace the host name
		s/$host/$replace/g;

		# Get rid of the web archive's local links to the repository
		s/http:\/\/wayback\.archive-it\.org\/[0-9]*\/[0-9a-z]*\.\///g;
		s/http:\/\/webarchive\.loc\.gov\/\.\/*\///g;
		s/http:\/\/www\.webarchive\.org\.uk\/wayback\/archive\/[0-9a-z]*\///g;

		print;
	}
}

print "\nModified file content:\n";
system("cat $test_file");
print "\n" . "=" x 60 . "\n";

# Cleanup
unlink($test_file);
print "\nTest completed successfully!\n";
