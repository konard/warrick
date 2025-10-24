# Brass Installation and Deployment Guide

## Overview

Brass is a distributed web interface and queueing manager for Warrick that provides load balancing across multiple memento aggregators. This guide covers installation and deployment of the Brass system.

## Architecture

The Brass system consists of:

1. **Web Interface** (`brass.cgi`) - CGI-based web interface for job submission and monitoring
2. **Job Processor** (`BrassJobProcessor.pm`) - Processes queued reconstruction jobs
3. **Load Balancer** (`BrassLoadBalancer.pm`) - Distributes work across multiple memento aggregators
4. **Daemon** (`brass_daemon.pl`) - Background service that processes the job queue
5. **Configuration** (`brass_config.yml`) - Central configuration file

## Prerequisites

### Required Software
- Perl 5.10 or later
- Web server with CGI support (Apache, nginx, etc.)
- All Warrick dependencies (see main INSTALL file)

### Required Perl Modules
```bash
# Install via CPAN
perl -MCPAN -e 'install YAML::Tiny'
perl -MCPAN -e 'install JSON'
perl -MCPAN -e 'install LWP::UserAgent'
perl -MCPAN -e 'install CGI'
```

Or via system package manager:
```bash
# Debian/Ubuntu
apt-get install libyaml-tiny-perl libjson-perl libwww-perl libcgi-pm-perl

# RedHat/CentOS
yum install perl-YAML-Tiny perl-JSON perl-libwww-perl perl-CGI
```

## Installation Steps

### 1. Configure Memento Aggregator Nodes

Edit `brass_config.yml` to configure your memento aggregator nodes:

```yaml
aggregator_nodes:
  - name: node1
    host: mementoproxy1.cs.odu.edu
    port: 80
    timegate_path: /aggr/timegate
    weight: 1
    enabled: true
    max_connections: 100

  - name: node2
    host: mementoproxy2.cs.odu.edu
    port: 80
    timegate_path: /aggr/timegate
    weight: 1
    enabled: true
    max_connections: 100
```

**Important**: Update the `host` values to match your actual memento aggregator servers.

### 2. Configure Load Balancing Strategy

Choose a load balancing strategy in `brass_config.yml`:

- `round_robin` - Distributes requests evenly across nodes (default)
- `least_connections` - Sends requests to node with fewest active connections
- `random` - Randomly selects a node
- `weighted_round_robin` - Uses node weights for distribution

```yaml
load_balancing_strategy: round_robin
```

### 3. Set Up Web Interface

#### For Apache:

1. Copy the brass directory to your web server:
```bash
cp -r brass /var/www/html/
```

2. Configure Apache to execute CGI scripts:
```apache
<Directory /var/www/html/brass/cgi-bin>
    Options +ExecCGI
    AddHandler cgi-script .cgi
    Require all granted
</Directory>

ScriptAlias /brass /var/www/html/brass/cgi-bin/brass.cgi
```

3. Restart Apache:
```bash
systemctl restart apache2  # Debian/Ubuntu
systemctl restart httpd    # RedHat/CentOS
```

#### For nginx with fcgiwrap:

1. Install fcgiwrap:
```bash
apt-get install fcgiwrap  # Debian/Ubuntu
yum install fcgiwrap      # RedHat/CentOS
```

2. Configure nginx:
```nginx
location /brass {
    gzip off;
    root /var/www/html;
    fastcgi_pass unix:/var/run/fcgiwrap.socket;
    include /etc/nginx/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /var/www/html/brass/cgi-bin/brass.cgi;
}
```

3. Restart nginx:
```bash
systemctl restart nginx
```

### 4. Create Required Directories

```bash
mkdir -p brass/queue
mkdir -p brass/output
chmod 755 brass/queue brass/output
```

If running under a web server user (e.g., www-data), ensure permissions:
```bash
chown -R www-data:www-data brass/queue brass/output
```

### 5. Start the Brass Daemon

The daemon processes jobs from the queue:

```bash
# Test mode (foreground with debug)
cd brass
perl brass_daemon.pl --debug

# Production mode (background daemon)
perl brass_daemon.pl --daemon --interval=60 --max-concurrent=10
```

### 6. Set Up Daemon Auto-Start

#### Using systemd:

Create `/etc/systemd/system/brass.service`:

```ini
[Unit]
Description=Brass Job Queue Processor
After=network.target

[Service]
Type=forking
User=www-data
Group=www-data
WorkingDirectory=/var/www/html/brass
ExecStart=/usr/bin/perl /var/www/html/brass/brass_daemon.pl --daemon --interval=60
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
systemctl enable brass
systemctl start brass
systemctl status brass
```

#### Using init.d script:

Create `/etc/init.d/brass`:

```bash
#!/bin/bash
# chkconfig: 345 99 01
# description: Brass Job Queue Processor

DAEMON=/var/www/html/brass/brass_daemon.pl
PIDFILE=/var/run/brass.pid

case "$1" in
  start)
    echo "Starting Brass daemon..."
    perl $DAEMON --daemon --interval=60
    ;;
  stop)
    echo "Stopping Brass daemon..."
    kill $(cat $PIDFILE 2>/dev/null) 2>/dev/null
    ;;
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac
```

Make executable and enable:
```bash
chmod +x /etc/init.d/brass
chkconfig brass on  # RedHat/CentOS
update-rc.d brass defaults  # Debian/Ubuntu
```

## Configuration Options

### Queue Configuration

```yaml
queue:
  max_jobs: 1000              # Maximum jobs in queue
  max_concurrent_jobs: 10     # Max jobs running simultaneously
  job_timeout_hours: 24       # Timeout for jobs
  retry_attempts: 3           # Number of retry attempts
```

### Health Check Configuration

```yaml
health_check:
  enabled: true               # Enable health checks
  interval_seconds: 30        # How often to check
  timeout_seconds: 5          # Health check timeout
  failure_threshold: 3        # Failures before marking unhealthy
```

### Email Notification Configuration

```yaml
email:
  enabled: true
  smtp_server: localhost
  smtp_port: 25
  from_address: brass@cs.odu.edu
```

## Testing the Installation

### 1. Test Load Balancer

```bash
cd brass/lib
perl -e 'use BrassLoadBalancer; my $lb = BrassLoadBalancer->new("../../brass_config.yml"); $lb->set_debug(1); my $node = $lb->get_next_node(); print "Selected: $node->{name}\n";'
```

### 2. Test Web Interface

Navigate to: `http://your-server/brass`

You should see the Brass job submission interface.

### 3. Submit Test Job

1. Access the web interface
2. Enter a test URL (e.g., `http://example.com`)
3. Enter your email address
4. Submit the job
5. Check the queue: `http://your-server/brass?action=queue`

### 4. Check Queue Directory

```bash
ls -la brass/queue/
```

You should see a `.json` file for your job.

### 5. Check Daemon Logs

```bash
tail -f /var/log/brass_daemon.log
```

## Deployment on Multiple Machines

To deploy Brass across multiple machines with separate memento aggregators:

### Machine 1: Memento Aggregator + Brass

```bash
# Install MemGator (or your memento aggregator)
# Configure and start memento aggregator on port 8080

# Install Brass
cp -r brass /var/www/html/

# Configure brass_config.yml with this machine as node1
# Start Brass daemon
```

### Machine 2: Memento Aggregator Only

```bash
# Install and configure memento aggregator
# Add this machine to brass_config.yml on Machine 1:
#   - name: node2
#     host: machine2.example.com
#     port: 8080
#     ...
```

### Machine 3: Additional Aggregator

```bash
# Same as Machine 2
# Add to brass_config.yml as node3
```

## Monitoring

### Check Load Balancer Statistics

The daemon in debug mode shows statistics:

```bash
perl brass_daemon.pl --debug
```

### Monitor Queue

```bash
# Count queued jobs
ls brass/queue/*.json 2>/dev/null | wc -l

# View job status
cat brass/queue/[job-id].json | python -m json.tool
```

### Check Node Health

```bash
# Test node connectivity
curl -I http://mementoproxy1.cs.odu.edu/aggr/timegate/
```

## Troubleshooting

### Jobs Not Processing

1. Check daemon is running:
   ```bash
   ps aux | grep brass_daemon
   ```

2. Check daemon logs:
   ```bash
   tail -f /var/log/brass_daemon.log
   ```

3. Verify queue directory permissions:
   ```bash
   ls -la brass/queue/
   ```

### Web Interface Not Loading

1. Check web server error logs:
   ```bash
   tail -f /var/log/apache2/error.log  # Apache
   tail -f /var/log/nginx/error.log    # nginx
   ```

2. Verify CGI permissions:
   ```bash
   ls -la brass/cgi-bin/brass.cgi
   ```

3. Test CGI script directly:
   ```bash
   cd brass/cgi-bin
   perl brass.cgi
   ```

### Load Balancer Issues

1. Test configuration:
   ```bash
   perl -MYAML::Tiny -e 'my $y=YAML::Tiny->read("brass_config.yml"); print "OK\n"'
   ```

2. Check node connectivity:
   ```bash
   perl -e 'use LWP::UserAgent; my $ua=LWP::UserAgent->new; my $r=$ua->head("http://node1.example.com/aggr/timegate/"); print $r->status_line, "\n";'
   ```

## Security Considerations

1. **Rate Limiting**: Configure web server rate limiting to prevent abuse
2. **Input Validation**: The CGI script validates URLs and emails, but consider additional checks
3. **File Permissions**: Ensure queue and output directories are not web-accessible
4. **Email Validation**: Only send emails to verified addresses
5. **Resource Limits**: Set appropriate limits in brass_config.yml

## Maintenance

### Cleanup Old Jobs

```bash
# Remove completed jobs older than 30 days
find brass/queue -name "*.json" -mtime +30 -exec grep -l '"status":"completed"' {} \; -delete
find brass/output -type d -mtime +30 -exec rm -rf {} \;
```

### Backup Configuration

```bash
# Backup queue and configuration
tar czf brass-backup-$(date +%Y%m%d).tar.gz brass/queue brass_config.yml
```

## Support

For issues or questions:
- Check the Warrick documentation
- Review logs in `/var/log/brass_daemon.log`
- Test components individually as shown in Testing section
