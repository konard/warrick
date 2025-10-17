# Makefile for Warrick distribution

VERSION = 2.5
PACKAGE = warrick-$(VERSION)
DIST_FILE = $(PACKAGE).tar.gz

# Core files to include in distribution
CORE_FILES = warrick.pl \
             README \
             INSTALL \
             TEST \
             resetCache.sh

# Perl modules
PM_FILES = CachedUrls.pm \
           Logger.pm \
           MementoThread.pm \
           mementoParser.pm \
           UrlUtil.pm

# Python scripts
PY_FILES = getWCpage.py \
           mcurl.pl

# Directories to include
DIRS = StoredResources \
       WebRepos \
       TEST_FILES \
       TestResources \
       timegates

# Files to exclude from distribution (patterns)
EXCLUDE_PATTERNS = *.log \
                   *.save \
                   *recoveryLog.out \
                   curl.exe \
                   MAKEFILE \
                   Yahoo \
                   .git \
                   .gitignore \
                   CLAUDE.md \
                   Makefile

.PHONY: all clean dist test install

all:
	@echo "Warrick $(VERSION)"
	@echo "Available targets:"
	@echo "  make clean - Clean up temporary and log files"
	@echo "  make dist  - Create distribution archive"
	@echo "  make test  - Run tests"

# Clean up temporary files and logs
clean:
	@echo "Cleaning temporary files..."
	rm -f *.log
	rm -f *.save
	rm -f *recoveryLog.out
	rm -f logfile.o
	rm -f MAKEFILE/logfile.o
	rm -f TestResources/lptexasorg/logfile
	@echo "Clean complete"

# Create distribution archive
dist: clean
	@echo "Creating distribution archive $(DIST_FILE)..."
	@# Create temporary directory for distribution
	@mkdir -p /tmp/$(PACKAGE)
	@# Copy core files
	@for file in $(CORE_FILES); do \
		if [ -f $$file ]; then \
			cp -p $$file /tmp/$(PACKAGE)/; \
			chmod 644 /tmp/$(PACKAGE)/$$file; \
		fi; \
	done
	@# Copy Perl modules
	@for file in $(PM_FILES); do \
		if [ -f $$file ]; then \
			cp -p $$file /tmp/$(PACKAGE)/; \
			chmod 644 /tmp/$(PACKAGE)/$$file; \
		fi; \
	done
	@# Copy Python scripts
	@for file in $(PY_FILES); do \
		if [ -f $$file ]; then \
			cp -p $$file /tmp/$(PACKAGE)/; \
			chmod 644 /tmp/$(PACKAGE)/$$file; \
		fi; \
	done
	@# Make executable scripts executable
	@chmod 755 /tmp/$(PACKAGE)/warrick.pl
	@chmod 755 /tmp/$(PACKAGE)/TEST
	@chmod 755 /tmp/$(PACKAGE)/INSTALL
	@chmod 755 /tmp/$(PACKAGE)/resetCache.sh
	@chmod 755 /tmp/$(PACKAGE)/getWCpage.py
	@chmod 755 /tmp/$(PACKAGE)/mcurl.pl
	@# Copy directories recursively
	@for dir in $(DIRS); do \
		if [ -d $$dir ]; then \
			cp -rp $$dir /tmp/$(PACKAGE)/; \
		fi; \
	done
	@# Fix permissions in copied directories
	@find /tmp/$(PACKAGE) -type f -name "*.pm" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.py" -exec chmod 755 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.pl" ! -name "warrick.pl" ! -name "mcurl.pl" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.txt" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.html" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.htm" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.css" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.js" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.gif" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.jpg" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.png" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.swf" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.asp" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.aspx" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.php" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.jsp" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.shtml" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.mhtml" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.cfm" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type f -name "*.out" -exec chmod 644 {} \;
	@find /tmp/$(PACKAGE) -type d -exec chmod 755 {} \;
	@# Remove log files from distribution
	@find /tmp/$(PACKAGE) -name "*.log" -delete
	@find /tmp/$(PACKAGE) -name "*recoveryLog.out" -delete
	@find /tmp/$(PACKAGE) -name "*.save" -delete
	@find /tmp/$(PACKAGE) -name "logfile.o" -delete
	@find /tmp/$(PACKAGE) -name "logfile" -delete
	@# Create tarball
	@cd /tmp && tar czf $(DIST_FILE) $(PACKAGE)
	@mv /tmp/$(DIST_FILE) .
	@rm -rf /tmp/$(PACKAGE)
	@echo "Distribution archive created: $(DIST_FILE)"
	@echo "Contents:"
	@tar tzf $(DIST_FILE) | head -20
	@echo "..."
	@echo "Total files: $$(tar tzf $(DIST_FILE) | wc -l)"

test:
	@echo "Running tests..."
	./TEST

install:
	@echo "Installing dependencies..."
	./INSTALL
