#!/usr/bin/perl -w

# Brass Daemon - Processes queued reconstruction jobs
# Runs continuously and processes jobs from the queue

use strict;
use warnings;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/..";

use BrassJobProcessor;

# Configuration
my $queue_dir = "$FindBin::Bin/queue";
my $output_dir = "$FindBin::Bin/output";
my $config_file = "$FindBin::Bin/../brass_config.yml";
my $warrick_path = "$FindBin::Bin/../warrick.pl";
my $check_interval = 30;  # seconds
my $debug = 0;
my $max_concurrent = 5;
my $daemon_mode = 0;

# Parse command line options
GetOptions(
    'queue-dir=s' => \$queue_dir,
    'output-dir=s' => \$output_dir,
    'config=s' => \$config_file,
    'warrick=s' => \$warrick_path,
    'interval=i' => \$check_interval,
    'max-concurrent=i' => \$max_concurrent,
    'debug' => \$debug,
    'daemon' => \$daemon_mode,
    'help' => sub { print_help(); exit(0); }
) or die("Error in command line arguments\n");

print "Brass Daemon Starting\n";
print "=====================\n";
print "Queue directory: $queue_dir\n";
print "Output directory: $output_dir\n";
print "Config file: $config_file\n";
print "Warrick path: $warrick_path\n";
print "Check interval: $check_interval seconds\n";
print "Max concurrent: $max_concurrent\n";
print "Debug mode: " . ($debug ? "ON" : "OFF") . "\n";
print "Daemon mode: " . ($daemon_mode ? "ON" : "OFF") . "\n";
print "\n";

# Daemonize if requested
if ($daemon_mode) {
    print "Daemonizing...\n";
    daemonize();
}

# Create job processor
my $processor = BrassJobProcessor->new(
    queue_dir => $queue_dir,
    output_dir => $output_dir,
    config_file => $config_file,
    warrick_path => $warrick_path,
    max_concurrent => $max_concurrent,
    debug => $debug
);

# Set up signal handlers
$SIG{INT} = \&shutdown;
$SIG{TERM} = \&shutdown;

my $running = 1;

print "Brass daemon is now running. Press Ctrl+C to stop.\n\n";

# Main loop
while ($running) {
    eval {
        # Process new jobs in the queue
        $processor->process_queue();

        # Check for completed jobs
        $processor->check_completed_jobs();

        # Display stats if in debug mode
        if ($debug) {
            my $stats = $processor->get_stats();
            print "\nStats:\n";
            print "  Active jobs: $stats->{active_jobs}\n";

            if ($stats->{load_balancer_stats}) {
                print "  Load balancer nodes:\n";
                foreach my $node_name (sort keys %{$stats->{load_balancer_stats}}) {
                    my $node_stats = $stats->{load_balancer_stats}->{$node_name};
                    print "    $node_name: ";
                    print "active=$node_stats->{active_connections}, ";
                    print "total=$node_stats->{total_requests}, ";
                    print "failed=$node_stats->{failed_requests}, ";
                    print "healthy=" . ($node_stats->{is_healthy} ? "yes" : "no") . "\n";
                }
            }
        }
    };

    if ($@) {
        warn "Error in main loop: $@\n";
    }

    # Sleep before next iteration
    sleep($check_interval);
}

print "Brass daemon shutting down.\n";
exit(0);

# Signal handler
sub shutdown {
    my ($signal) = @_;
    print "\nReceived $signal signal. Shutting down...\n";
    $running = 0;
}

# Daemonize process
sub daemonize {
    use POSIX qw(setsid);

    # Fork and exit parent
    my $pid = fork();
    exit(0) if $pid;
    die "Cannot fork: $!" unless defined $pid;

    # Become session leader
    setsid() or die "Cannot start a new session: $!";

    # Fork again to ensure we're not session leader
    $pid = fork();
    exit(0) if $pid;
    die "Cannot fork: $!" unless defined $pid;

    # Change working directory
    chdir('/');

    # Clear file creation mask
    umask(0);

    # Close standard file descriptors
    close(STDIN);
    close(STDOUT);
    close(STDERR);

    # Reopen to /dev/null
    open(STDIN, '<', '/dev/null');
    open(STDOUT, '>>', '/var/log/brass_daemon.log');
    open(STDERR, '>>', '/var/log/brass_daemon.log');
}

# Print help
sub print_help {
    print <<'HELP';
Brass Daemon - Job Queue Processor for Warrick

Usage: brass_daemon.pl [OPTIONS]

Options:
    --queue-dir=DIR       Queue directory (default: ./queue)
    --output-dir=DIR      Output directory (default: ./output)
    --config=FILE         Config file (default: ../brass_config.yml)
    --warrick=FILE        Warrick script path (default: ../warrick.pl)
    --interval=SECONDS    Check interval in seconds (default: 30)
    --max-concurrent=N    Max concurrent jobs (default: 5)
    --debug               Enable debug output
    --daemon              Run as daemon
    --help                Show this help message

Example:
    perl brass_daemon.pl --debug
    perl brass_daemon.pl --daemon --interval=60 --max-concurrent=10

HELP
}
