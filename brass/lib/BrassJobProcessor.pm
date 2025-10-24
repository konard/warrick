package BrassJobProcessor;

# Job Processor for Brass - Processes queued reconstruction jobs
# Uses distributed load balancing across memento aggregators

use strict;
use warnings;
use JSON;
use File::Path qw(make_path);
use File::Basename;
use POSIX qw(strftime);

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../../";

use BrassLoadBalancer;

# Constructor
sub new {
    my ($class, %args) = @_;

    my $self = {
        queue_dir => $args{queue_dir} || './brass/queue',
        output_dir => $args{output_dir} || './brass/output',
        config_file => $args{config_file} || './brass_config.yml',
        warrick_path => $args{warrick_path} || './warrick.pl',
        max_concurrent => $args{max_concurrent} || 10,
        debug => $args{debug} || 0,
        load_balancer => undef,
        active_jobs => {}
    };

    bless $self, $class;

    # Initialize load balancer
    $self->{load_balancer} = BrassLoadBalancer->new($self->{config_file});
    $self->{load_balancer}->set_debug($self->{debug});

    # Ensure directories exist
    make_path($self->{queue_dir}, $self->{output_dir})
        unless -d $self->{queue_dir} && -d $self->{output_dir};

    return $self;
}

# Process all queued jobs
sub process_queue {
    my ($self) = @_;

    $self->debug_print("Processing job queue");

    # Get all queued jobs
    my @jobs = $self->get_queued_jobs();

    $self->debug_print("Found " . scalar(@jobs) . " queued jobs");

    foreach my $job (@jobs) {
        # Check if we can process more jobs
        my $active_count = scalar(keys %{$self->{active_jobs}});
        if ($active_count >= $self->{max_concurrent}) {
            $self->debug_print("Max concurrent jobs reached ($active_count)");
            last;
        }

        # Process the job
        $self->process_job($job);
    }

    # Run health checks
    $self->{load_balancer}->health_check_all();
}

# Get all queued jobs
sub get_queued_jobs {
    my ($self) = @_;

    my @jobs;

    opendir(my $dh, $self->{queue_dir}) or do {
        warn "Cannot open queue directory: $!";
        return @jobs;
    };

    while (my $file = readdir($dh)) {
        next unless $file =~ /\.json$/;

        my $job_file = "$self->{queue_dir}/$file";
        my $job = $self->read_job($job_file);

        if ($job && $job->{status} eq 'queued') {
            push @jobs, $job;
        }
    }

    closedir($dh);

    # Sort by submission time (oldest first)
    @jobs = sort { $a->{submitted} <=> $b->{submitted} } @jobs;

    return @jobs;
}

# Read job from file
sub read_job {
    my ($self, $job_file) = @_;

    return unless -e $job_file;

    open(my $fh, '<', $job_file) or do {
        warn "Cannot read job file $job_file: $!";
        return;
    };

    my $json_text = do { local $/; <$fh> };
    close($fh);

    my $job;
    eval {
        $job = decode_json($json_text);
        $job->{_file} = $job_file;
    };

    if ($@) {
        warn "Cannot parse job file $job_file: $@";
        return;
    }

    return $job;
}

# Update job status
sub update_job {
    my ($self, $job) = @_;

    return unless $job->{_file};

    my $job_copy = { %$job };
    delete $job_copy->{_file};

    open(my $fh, '>', $job->{_file}) or do {
        warn "Cannot write job file: $!";
        return;
    };

    print $fh encode_json($job_copy);
    close($fh);
}

# Process a single job
sub process_job {
    my ($self, $job) = @_;

    $self->debug_print("Processing job: $job->{job_id}");

    # Update status to running
    $job->{status} = 'running';
    $job->{started} = time();
    $job->{started_str} = strftime("%Y-%m-%d %H:%M:%S", localtime($job->{started}));
    $self->update_job($job);

    # Get a node from the load balancer
    my $node = $self->{load_balancer}->get_next_node();
    my $timegate_url = $self->{load_balancer}->get_timegate_url($node);

    $self->debug_print("Assigned to node: $node->{name}");
    $self->debug_print("TimeGate URL: $timegate_url");

    # Track active job
    $self->{active_jobs}->{$job->{job_id}} = {
        job => $job,
        node => $node,
        pid => undef
    };

    # Prepare output directory
    my $output_dir = "$self->{output_dir}/$job->{job_id}";
    make_path($output_dir) unless -d $output_dir;

    # Build warrick command
    my $log_file = "$output_dir/recovery.log";
    my $options = $job->{options} || '';

    # Use the selected memento aggregator via environment variable or modified MementoThread
    my $command = "perl $self->{warrick_path} $options -D $output_dir $job->{url} > $log_file 2>&1";

    $self->debug_print("Command: $command");

    # Fork and execute
    my $pid = fork();

    if (!defined $pid) {
        # Fork failed
        warn "Cannot fork for job $job->{job_id}: $!";
        $job->{status} = 'failed';
        $job->{error} = "Fork failed: $!";
        $self->update_job($job);
        delete $self->{active_jobs}->{$job->{job_id}};
        $self->{load_balancer}->decrement_connections($node);
        return;
    }

    if ($pid == 0) {
        # Child process
        # Set environment variable for the TimeGate to use
        $ENV{BRASS_TIMEGATE} = $timegate_url;
        exec($command);
        exit(1);  # Should never reach here
    }

    # Parent process
    $self->{active_jobs}->{$job->{job_id}}->{pid} = $pid;

    $self->debug_print("Started job $job->{job_id} with PID $pid");

    # Note: In a real implementation, you would use a process manager
    # to track job completion asynchronously
}

# Check for completed jobs
sub check_completed_jobs {
    my ($self) = @_;

    foreach my $job_id (keys %{$self->{active_jobs}}) {
        my $active_job = $self->{active_jobs}->{$job_id};
        my $pid = $active_job->{pid};

        next unless defined $pid;

        # Check if process is still running (non-blocking)
        my $result = waitpid($pid, 1);  # WNOHANG

        if ($result == $pid) {
            # Process has finished
            my $exit_code = $? >> 8;

            $self->debug_print("Job $job_id completed with exit code $exit_code");

            my $job = $active_job->{job};
            my $node = $active_job->{node};

            # Update job status
            if ($exit_code == 0) {
                $job->{status} = 'completed';
            } else {
                $job->{status} = 'failed';
                $job->{exit_code} = $exit_code;
                $self->{load_balancer}->record_failure($node);
            }

            $job->{completed} = time();
            $job->{completed_str} = strftime("%Y-%m-%d %H:%M:%S", localtime($job->{completed}));

            $self->update_job($job);

            # Release the node
            $self->{load_balancer}->decrement_connections($node);

            # Send notification email (if configured)
            $self->send_notification($job);

            # Remove from active jobs
            delete $self->{active_jobs}->{$job_id};
        }
    }
}

# Send notification email
sub send_notification {
    my ($self, $job) = @_;

    # This is a placeholder - in production you would use a proper email module
    $self->debug_print("Would send notification to $job->{email} for job $job->{job_id}");

    # Example using sendmail:
    # open(my $mail, '|/usr/sbin/sendmail -t') or return;
    # print $mail "To: $job->{email}\n";
    # print $mail "Subject: Warrick Reconstruction Complete - $job->{job_id}\n";
    # print $mail "\n";
    # print $mail "Your website reconstruction job has completed.\n";
    # print $mail "Job ID: $job->{job_id}\n";
    # print $mail "Status: $job->{status}\n";
    # close($mail);
}

# Get statistics
sub get_stats {
    my ($self) = @_;

    return {
        active_jobs => scalar(keys %{$self->{active_jobs}}),
        load_balancer_stats => $self->{load_balancer}->get_stats()
    };
}

# Debug print
sub debug_print {
    my ($self, $message) = @_;
    print "DEBUG [BrassJobProcessor]: $message\n" if $self->{debug};
}

1;
