#!/usr/bin/perl -w
# Test script to verify TimeGate connectivity
# Tests various archive endpoints to ensure they're accessible

use strict;
use LWP::UserAgent;
use HTTP::Request;

print "Testing TimeGate Connectivity\n";
print "=" x 50 . "\n\n";

my $ua = LWP::UserAgent->new(
    timeout => 10,
    agent => 'Warrick/2.2.2 Testing Script'
);

# Test configurations
my @tests = (
    {
        name => "Internet Archive TimeGate",
        url => "http://web.archive.org/web/http://www.cs.odu.edu/",
        datetime => "Thu, 31 May 2007 20:35:00 GMT",
        expected_status => 302,
    },
);

my $passed = 0;
my $failed = 0;

foreach my $test (@tests) {
    print "Testing: $test->{name}\n";
    print "  URL: $test->{url}\n";

    my $request = HTTP::Request->new('HEAD', $test->{url});
    $request->header('Accept-Datetime' => $test->{datetime});

    my $response = $ua->request($request);

    if ($response->code == $test->{expected_status}) {
        print "  ✓ PASS - Status: " . $response->code . "\n";
        if ($response->header('Location')) {
            print "    Memento: " . $response->header('Location') . "\n";
        }
        $passed++;
    } else {
        print "  ✗ FAIL - Status: " . $response->code . "\n";
        print "    Expected: $test->{expected_status}\n";
        $failed++;
    }
    print "\n";
}

print "=" x 50 . "\n";
print "Results: $passed passed, $failed failed\n";

exit($failed > 0 ? 1 : 0);
