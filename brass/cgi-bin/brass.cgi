#!/usr/bin/perl -w

# Brass - Web Interface for Warrick
# A queueing manager for distributed website reconstruction
# Created for Issue #34 - Brass rework with load balancing

use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use File::Path qw(make_path);
use File::Basename;
use JSON;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);

use FindBin;
use lib "$FindBin::Bin/../../";
use lib "$FindBin::Bin/../lib";

# Initialize CGI
my $cgi = CGI->new();

# Configuration
my $QUEUE_DIR = "$FindBin::Bin/../queue";
my $OUTPUT_DIR = "$FindBin::Bin/../output";
my $CONFIG_FILE = "$FindBin::Bin/../../brass_config.yml";

# Ensure directories exist
make_path($QUEUE_DIR, $OUTPUT_DIR) unless -d $QUEUE_DIR && -d $OUTPUT_DIR;

# Main dispatcher
my $action = $cgi->param('action') || 'home';

if ($action eq 'home') {
    show_home();
} elsif ($action eq 'submit') {
    submit_job();
} elsif ($action eq 'status') {
    show_status();
} elsif ($action eq 'queue') {
    show_queue();
} elsif ($action eq 'download') {
    download_result();
} else {
    show_error("Unknown action: $action");
}

exit(0);

# Display home page
sub show_home {
    print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
    print <<'HTML';
<!DOCTYPE html>
<html>
<head>
    <title>Brass - Warrick Web Interface</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #555;
        }
        input[type="text"], input[type="email"], textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
            font-size: 14px;
        }
        textarea {
            min-height: 100px;
            resize: vertical;
        }
        button {
            background-color: #4CAF50;
            color: white;
            padding: 12px 30px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #45a049;
        }
        .info {
            background-color: #e7f3fe;
            border-left: 4px solid #2196F3;
            padding: 15px;
            margin-bottom: 20px;
        }
        .nav {
            margin-bottom: 20px;
        }
        .nav a {
            margin-right: 15px;
            color: #4CAF50;
            text-decoration: none;
        }
        .nav a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Brass - Warrick Website Reconstruction</h1>

        <div class="nav">
            <a href="?action=home">Submit Job</a>
            <a href="?action=queue">View Queue</a>
        </div>

        <div class="info">
            <strong>About Brass:</strong> This is a distributed queueing system for Warrick that uses load balancing
            across multiple memento aggregators to efficiently reconstruct lost websites from web archives.
        </div>

        <form method="POST" action="?action=submit">
            <div class="form-group">
                <label for="url">Website URL to Reconstruct:</label>
                <input type="text" id="url" name="url"
                       placeholder="http://example.com"
                       required>
            </div>

            <div class="form-group">
                <label for="email">Email Address (for notification):</label>
                <input type="email" id="email" name="email"
                       placeholder="your.email@example.com"
                       required>
            </div>

            <div class="form-group">
                <label for="options">Additional Warrick Options:</label>
                <textarea id="options" name="options"
                          placeholder="e.g., -l 3 -nc">-k -nc</textarea>
                <small>Common options: -k (convert links), -nc (no clobber), -l N (limit directory depth)</small>
            </div>

            <div class="form-group">
                <button type="submit">Submit Reconstruction Job</button>
            </div>
        </form>
    </div>
</body>
</html>
HTML
}

# Submit a new job
sub submit_job {
    my $url = $cgi->param('url');
    my $email = $cgi->param('email');
    my $options = $cgi->param('options') || '';

    # Validate input
    unless ($url && $email) {
        show_error("URL and email are required");
        return;
    }

    # Validate URL format
    unless ($url =~ m{^https?://}) {
        show_error("Invalid URL format. Must start with http:// or https://");
        return;
    }

    # Validate email format
    unless ($email =~ m{^[^@]+@[^@]+\.[^@]+$}) {
        show_error("Invalid email format");
        return;
    }

    # Create job ID
    my $job_id = generate_job_id($url, $email);
    my $timestamp = time();

    # Create job file
    my $job_data = {
        job_id => $job_id,
        url => $url,
        email => $email,
        options => $options,
        status => 'queued',
        submitted => $timestamp,
        submitted_str => strftime("%Y-%m-%d %H:%M:%S", localtime($timestamp))
    };

    my $job_file = "$QUEUE_DIR/$job_id.json";
    open(my $fh, '>', $job_file) or die "Cannot create job file: $!";
    print $fh encode_json($job_data);
    close($fh);

    # Show confirmation
    print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
    print <<HTML;
<!DOCTYPE html>
<html>
<head>
    <title>Job Submitted - Brass</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .success {
            background-color: #d4edda;
            border: 1px solid #c3e6cb;
            color: #155724;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        .job-info {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .job-info p {
            margin: 5px 0;
        }
        a {
            color: #4CAF50;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Job Submitted Successfully</h1>

        <div class="success">
            <strong>✓ Your reconstruction job has been queued</strong>
        </div>

        <div class="job-info">
            <p><strong>Job ID:</strong> $job_id</p>
            <p><strong>URL:</strong> $url</p>
            <p><strong>Email:</strong> $email</p>
            <p><strong>Submitted:</strong> $job_data->{submitted_str}</p>
        </div>

        <p>You will receive an email at <strong>$email</strong> when your reconstruction is complete.</p>

        <p><a href="?action=status&job_id=$job_id">Check job status</a> |
           <a href="?action=queue">View queue</a> |
           <a href="?action=home">Submit another job</a></p>
    </div>
</body>
</html>
HTML
}

# Show job queue
sub show_queue {
    print $cgi->header(-type => 'text/html', -charset => 'UTF-8');

    my @jobs;
    opendir(my $dh, $QUEUE_DIR) or die "Cannot open queue directory: $!";
    while (my $file = readdir($dh)) {
        next unless $file =~ /\.json$/;
        my $job_file = "$QUEUE_DIR/$file";
        open(my $fh, '<', $job_file) or next;
        my $json_text = do { local $/; <$fh> };
        close($fh);
        my $job = decode_json($json_text);
        push @jobs, $job;
    }
    closedir($dh);

    # Sort by submission time (newest first)
    @jobs = sort { $b->{submitted} <=> $a->{submitted} } @jobs;

    print <<'HTML';
<!DOCTYPE html>
<html>
<head>
    <title>Job Queue - Brass</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1000px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #4CAF50;
            color: white;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .status-queued { color: #ff9800; }
        .status-running { color: #2196F3; }
        .status-completed { color: #4CAF50; }
        .status-failed { color: #f44336; }
        a {
            color: #4CAF50;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Job Queue</h1>
        <p><a href="?action=home">← Back to home</a></p>
HTML

    if (@jobs) {
        print "<table>\n";
        print "<tr><th>Job ID</th><th>URL</th><th>Status</th><th>Submitted</th><th>Actions</th></tr>\n";

        foreach my $job (@jobs) {
            my $status_class = "status-" . $job->{status};
            print "<tr>\n";
            print "  <td><code>$job->{job_id}</code></td>\n";
            print "  <td>$job->{url}</td>\n";
            print "  <td class='$status_class'>$job->{status}</td>\n";
            print "  <td>$job->{submitted_str}</td>\n";
            print "  <td><a href='?action=status&job_id=$job->{job_id}'>Details</a></td>\n";
            print "</tr>\n";
        }

        print "</table>\n";
    } else {
        print "<p>No jobs in queue.</p>\n";
    }

    print <<'HTML';
    </div>
</body>
</html>
HTML
}

# Show job status
sub show_status {
    my $job_id = $cgi->param('job_id');

    unless ($job_id) {
        show_error("Job ID required");
        return;
    }

    my $job_file = "$QUEUE_DIR/$job_id.json";
    unless (-e $job_file) {
        show_error("Job not found: $job_id");
        return;
    }

    open(my $fh, '<', $job_file) or die "Cannot read job file: $!";
    my $json_text = do { local $/; <$fh> };
    close($fh);
    my $job = decode_json($json_text);

    print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
    print <<HTML;
<!DOCTYPE html>
<html>
<head>
    <title>Job Status - Brass</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .job-info {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        .job-info p {
            margin: 8px 0;
        }
        a {
            color: #4CAF50;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Job Status</h1>
        <p><a href="?action=home">← Back to home</a> | <a href="?action=queue">View queue</a></p>

        <div class="job-info">
            <p><strong>Job ID:</strong> $job->{job_id}</p>
            <p><strong>URL:</strong> $job->{url}</p>
            <p><strong>Email:</strong> $job->{email}</p>
            <p><strong>Status:</strong> $job->{status}</p>
            <p><strong>Options:</strong> $job->{options}</p>
            <p><strong>Submitted:</strong> $job->{submitted_str}</p>
        </div>
    </div>
</body>
</html>
HTML
}

# Show error page
sub show_error {
    my ($message) = @_;

    print $cgi->header(-type => 'text/html', -charset => 'UTF-8');
    print <<HTML;
<!DOCTYPE html>
<html>
<head>
    <title>Error - Brass</title>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .error {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Error</h1>
        <div class="error">$message</div>
        <p><a href="?action=home">← Back to home</a></p>
    </div>
</body>
</html>
HTML
}

# Generate unique job ID
sub generate_job_id {
    my ($url, $email) = @_;
    my $timestamp = time();
    my $random = int(rand(10000));
    return substr(md5_hex("$url$email$timestamp$random"), 0, 12);
}
