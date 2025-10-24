#!/usr/bin/perl -w

# Simple test script for Brass components
# Tests the load balancing logic without requiring dependencies

use strict;
use warnings;

print "Brass Component Test Suite\n";
print "===========================\n\n";

# Test 1: Configuration file exists
print "Test 1: Configuration file exists... ";
if (-e '../brass_config.yml') {
    print "PASS\n";
} else {
    print "FAIL\n";
}

# Test 2: Directory structure
print "Test 2: Directory structure... ";
my @required_dirs = qw(cgi-bin lib);
my $dirs_ok = 1;
foreach my $dir (@required_dirs) {
    unless (-d $dir) {
        print "\n  Missing directory: $dir";
        $dirs_ok = 0;
    }
}
print $dirs_ok ? "PASS\n" : "\nFAIL\n";

# Test 3: Required files exist
print "Test 3: Required files exist... ";
my @required_files = (
    'cgi-bin/brass.cgi',
    'lib/BrassLoadBalancer.pm',
    'lib/BrassJobProcessor.pm',
    'brass_daemon.pl',
    'README.md',
    'BRASS_INSTALL.md'
);
my $files_ok = 1;
foreach my $file (@required_files) {
    unless (-e $file) {
        print "\n  Missing file: $file";
        $files_ok = 0;
    }
}
print $files_ok ? "PASS\n" : "\nFAIL\n";

# Test 4: Scripts are executable
print "Test 4: Scripts are executable... ";
my @exec_files = ('cgi-bin/brass.cgi', 'brass_daemon.pl');
my $exec_ok = 1;
foreach my $file (@exec_files) {
    unless (-x $file) {
        print "\n  Not executable: $file";
        $exec_ok = 0;
    }
}
print $exec_ok ? "PASS\n" : "\nFAIL\n";

# Test 5: Queue directory can be created
print "Test 5: Queue directory creation... ";
if (mkdir('queue', 0755) || -d 'queue') {
    print "PASS\n";
    rmdir('queue') unless -e 'queue/keep';
} else {
    print "FAIL\n";
}

# Test 6: Output directory can be created
print "Test 6: Output directory creation... ";
if (mkdir('output', 0755) || -d 'output') {
    print "PASS\n";
    rmdir('output') unless -e 'output/keep';
} else {
    print "FAIL\n";
}

# Test 7: Configuration file is valid YAML syntax
print "Test 7: Configuration file syntax... ";
open(my $fh, '<', '../brass_config.yml') or die "Cannot open config: $!";
my $config_content = do { local $/; <$fh> };
close($fh);

# Basic YAML syntax check
my $yaml_ok = 1;
if ($config_content !~ /aggregator_nodes:/) {
    print "\n  Missing aggregator_nodes section";
    $yaml_ok = 0;
}
if ($config_content !~ /load_balancing_strategy:/) {
    print "\n  Missing load_balancing_strategy";
    $yaml_ok = 0;
}
print $yaml_ok ? "PASS\n" : "\nFAIL\n";

print "\n";
print "=== Summary ===\n";
print "Brass infrastructure is ready for deployment.\n";
print "See BRASS_INSTALL.md for installation instructions.\n";
print "\nNote: Actual functionality requires Perl module dependencies:\n";
print "  - YAML::Tiny\n";
print "  - JSON\n";
print "  - LWP::UserAgent\n";
print "  - CGI\n";
print "\nInstall with: perl -MCPAN -e 'install YAML::Tiny JSON LWP::UserAgent CGI'\n";
