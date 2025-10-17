WARRICK TESTING FRAMEWORK
=========================

This document describes the restructured testing system for Warrick.

BACKGROUND
----------
The original testing feature was broken due to:
1. Memento aggregator services (LANL, ODU) being shut down on September 5, 2025
2. Bash compatibility issues in the TEST script (using /bin/sh with bash syntax)
3. Outdated TimeGate endpoints in timegates.o files
4. Missing variable references ($c4, $c1, $c2) in conditional statements

WHAT WAS FIXED
--------------
1. Updated all timegates.o files to use working Internet Archive endpoints
2. Fixed TEST script shebang from #!/bin/sh to #!/bin/bash
3. Fixed variable references in TEST script conditional statements
4. Created experiments/ folder with modern test scripts

CURRENT STATUS OF WEB ARCHIVES (as of October 2025)
----------------------------------------------------
- Internet Archive (web.archive.org): ✓ OPERATIONAL
  * Memento TimeGate: http://web.archive.org/web/
  * Fully supports Memento protocol with datetime negotiation

- LANL Memento Proxy: ✗ UNAVAILABLE (service shut down)
- ODU Memento Proxy: ✗ UNAVAILABLE (service shut down)

RUNNING TESTS
-------------

1. Main Integration Test:
   ./TEST

   This runs a full recovery test of http://www.cs.odu.edu/ using the Internet
   Archive and compares results with baseline files in TEST_FILES/

2. TimeGate Connectivity Test (Bash):
   bash experiments/test_memento_timegate.sh

   Quick test to verify TimeGate endpoints are responding correctly.

3. TimeGate Connectivity Test (Perl):
   perl experiments/test_timegate_connectivity.pl

   Perl-based connectivity test using LWP::UserAgent.

TEST FILES STRUCTURE
--------------------
TEST                       - Main integration test script
TEST_FILES/               - Baseline test results for comparison
  ├─ MAKEFILE_recoveryLog.out
  └─ TESTHEADERS.out

TestResources/            - Test data and resources
experiments/              - New test scripts and experiments
  ├─ test_memento_timegate.sh
  ├─ test_timegate_connectivity.pl
  └─ README_TESTING.txt (this file)

REQUIREMENTS
------------
For the main Warrick tests to work, you need:
- Perl 5.x with modules: LWP::UserAgent, HTTP::Cookies, HTTP::Status, etc.
- curl
- Internet connectivity
- See INSTALL file for complete dependency list

FUTURE IMPROVEMENTS
-------------------
1. Add unit tests for individual Perl modules (UrlUtil.pm, CachedUrls.pm, etc.)
2. Create mock TimeGate server for offline testing
3. Add CI/CD integration with GitHub Actions
4. Create automated regression test suite
5. Add performance benchmarking tests
6. Support for additional web archives as they become available

TROUBLESHOOTING
---------------
If tests fail:
1. Check internet connectivity
2. Verify Perl dependencies are installed (see INSTALL)
3. Check that timegates.o files point to working endpoints
4. Ensure TEST_FILES/ directory contains baseline files
5. Run experiments/test_memento_timegate.sh to verify TimeGate connectivity

For more information, see:
- Memento Protocol: https://mementoweb.org/guide/rfc/
- Internet Archive API: https://archive.org/help/wayback_api.php
