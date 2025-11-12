#!/usr/bin/perl
#
# This script demonstrates the bug in warrick.pl line 3477
# that causes incomplete dumps (Issue #21)
#
# The bug: lister.o file is downloaded to a specific directory
# but then opened from the wrong path, causing it to fail silently

use strict;
use warnings;

print "=== Demonstrating Issue #21 Bug ===\n\n";

# Simulate the buggy code
my $directory = "/tmp/test_recovery";
my $listerOut = "$directory/lister.o";

print "Bug demonstration:\n";
print "  File downloaded to: $listerOut\n";
print "  File opened from:   lister.o (wrong!)\n\n";

# This is what happens in the buggy code:
# 1. Download to $listerOut (full path)
print "Step 1: Download file to $listerOut\n";
system("mkdir -p $directory");
system("echo 'test content' > $listerOut");
print "  File created: $listerOut\n";

# 2. Try to open just "lister.o" (wrong path)
print "\nStep 2: Try to open 'lister.o' (buggy code):\n";
if (open(FILE, "lister.o")) {
    print "  SUCCESS: File opened (shouldn't happen unless we're in that dir)\n";
    close(FILE);
} else {
    print "  FAILED: Cannot open 'lister.o' (expected - wrong path!)\n";
    print "  This is the bug! The file exists at $listerOut\n";
    print "  but the code tries to open 'lister.o' in current directory\n";
}

# 3. Show the fix
print "\nStep 3: Open with correct path (fixed code):\n";
if (open(FILE, $listerOut)) {
    print "  SUCCESS: File opened using \$listerOut variable\n";
    my @data = <FILE>;
    close(FILE);
    print "  Read " . scalar(@data) . " lines\n";
} else {
    print "  FAILED: Cannot open $listerOut\n";
}

print "\n=== Impact ===\n";
print "When the file fails to open:\n";
print "  - \@data array is empty\n";
print "  - No links extracted from Internet Archive listing\n";
print "  - Frontier not populated with all archived pages\n";
print "  - Result: INCOMPLETE DUMP!\n";

# Cleanup
system("rm -rf $directory");
print "\nCleanup done.\n";
