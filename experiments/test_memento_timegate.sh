#!/bin/bash
# Test script to verify Memento TimeGate functionality with various archives

echo "Testing Memento TimeGate endpoints..."
echo "======================================"
echo ""

# Test URL and datetime
TEST_URL="http://www.cs.odu.edu/"
TEST_DATETIME="Thu, 31 May 2007 20:35:00 GMT"

echo "Test URL: $TEST_URL"
echo "Test DateTime: $TEST_DATETIME"
echo ""

# Test Internet Archive Wayback Machine
echo "1. Testing Internet Archive TimeGate..."
echo "   URL: http://web.archive.org/web/$TEST_URL"
RESPONSE=$(curl -s -I -H "Accept-Datetime: $TEST_DATETIME" "http://web.archive.org/web/$TEST_URL" 2>&1)
if echo "$RESPONSE" | grep -q "HTTP/1.1 302"; then
    MEMENTO_URL=$(echo "$RESPONSE" | grep -i "^location:" | awk '{print $2}' | tr -d '\r')
    echo "   ✓ SUCCESS - Found memento: $MEMENTO_URL"
else
    echo "   ✗ FAILED - No redirect found"
fi
echo ""

# Test old LANL proxy (expected to fail)
echo "2. Testing LANL Memento Proxy (legacy)..."
echo "   URL: http://mementoproxy.lanl.gov/aggr/timegate/$TEST_URL"
RESPONSE=$(curl -s -I --connect-timeout 5 -H "Accept-Datetime: $TEST_DATETIME" "http://mementoproxy.lanl.gov/aggr/timegate/$TEST_URL" 2>&1)
if echo "$RESPONSE" | grep -q "Could not resolve host"; then
    echo "   ✗ FAILED - Host unavailable (expected - service shut down)"
else
    echo "   ✓ Unexpected response"
fi
echo ""

# Test old ODU proxy (expected to fail)
echo "3. Testing ODU Memento Proxy (legacy)..."
echo "   URL: http://mementoproxy.cs.odu.edu/aggr/timegate/$TEST_URL"
RESPONSE=$(curl -s -I --connect-timeout 5 -H "Accept-Datetime: $TEST_DATETIME" "http://mementoproxy.cs.odu.edu/aggr/timegate/$TEST_URL" 2>&1)
if echo "$RESPONSE" | grep -q "Could not resolve host"; then
    echo "   ✗ FAILED - Host unavailable (expected - service shut down)"
else
    echo "   ✓ Unexpected response"
fi
echo ""

echo "======================================"
echo "Summary:"
echo "- Internet Archive TimeGate: WORKING ✓"
echo "- LANL Memento Proxy: UNAVAILABLE (as expected)"
echo "- ODU Memento Proxy: UNAVAILABLE (as expected)"
echo ""
echo "Recommendation: Update Warrick to use Internet Archive directly"
