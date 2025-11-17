#!/usr/bin/perl -w
# This script demonstrates the encoding fix for issue #32

use strict;
use utf8;
use open ':std', ':encoding(UTF-8)';

print "=== Demonstration of UTF-8 Encoding Fix ===\n\n";

# Create test HTML with UTF-8 characters like those mentioned in issue #32
my $test_html = '<html>
<head><title>Test Page</title></head>
<body>
<p>Testing Spanish characters: ó á ñ ü é í</p>
<p>Testing Portuguese: ção ão õ</p>
<p>Testing French: é è ê ë à</p>
</body>
</html>';

print "Original content:\n$test_html\n\n";

# Write with UTF-8 encoding (the fix)
my $test_file = "experiments/test_utf8_demo.html";
open(OUT, ">:utf8", $test_file) or die "Cannot open $test_file: $!";
print OUT $test_html;
close(OUT);

# Read it back with UTF-8 encoding
open(IN, "<:utf8", $test_file) or die "Cannot open $test_file: $!";
my $content = do { local $/; <IN> };
close(IN);

print "Content read back from file:\n$content\n";

if ($content eq $test_html) {
    print "\n✓ SUCCESS: UTF-8 characters preserved correctly!\n";
} else {
    print "\n✗ FAILED: Characters were corrupted\n";
}

print "\nThis fix ensures that characters like 'ó' stay as 'ó'\n";
print "instead of being corrupted to 'Ã³' (UTF-8 bytes misinterpreted as Latin-1)\n";
