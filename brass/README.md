# Brass - Distributed Web Interface for Warrick

## Overview

Brass is a web-based queueing manager for Warrick that provides distributed website reconstruction using load balancing across multiple memento aggregators. It simplifies the process of recovering lost websites by providing an easy-to-use web interface and automatic job management.

## Features

- **Web Interface**: Easy-to-use CGI-based interface for job submission and monitoring
- **Load Balancing**: Distributes memento discovery across multiple aggregator nodes
- **Multiple Strategies**: Round-robin, least-connections, random, and weighted load balancing
- **Health Monitoring**: Automatic health checks on memento aggregator nodes
- **Job Queue**: Manages reconstruction jobs with status tracking
- **Email Notifications**: Notifies users when reconstructions complete
- **Concurrent Processing**: Processes multiple jobs simultaneously
- **Auto-Retry**: Automatically retries failed requests on different nodes

## Architecture

```
┌─────────────────┐
│  Web Interface  │  (brass.cgi)
│   (User Input)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Job Queue     │  (JSON files)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Brass Daemon   │  (brass_daemon.pl)
│  (Job Processor)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Load Balancer   │  (BrassLoadBalancer.pm)
└────────┬────────┘
         │
    ┌────┴────┬─────────┬─────────┐
    ▼         ▼         ▼         ▼
┌────────┐┌────────┐┌────────┐┌────────┐
│ Node 1 ││ Node 2 ││ Node 3 ││ Node N │
│Memento ││Memento ││Memento ││Memento │
│Aggregtr││Aggregtr││Aggregtr││Aggregtr│
└────────┘└────────┘└────────┘└────────┘
```

## Components

### Web Interface (`brass/cgi-bin/brass.cgi`)
CGI script that provides the web-based user interface for:
- Submitting new reconstruction jobs
- Viewing job queue and status
- Monitoring job progress

### Load Balancer (`brass/lib/BrassLoadBalancer.pm`)
Perl module that implements load balancing across multiple memento aggregators:
- Round-robin distribution
- Least-connections algorithm
- Random selection
- Weighted round-robin
- Health monitoring
- Connection tracking

### Job Processor (`brass/lib/BrassJobProcessor.pm`)
Manages job execution:
- Reads jobs from queue
- Assigns jobs to available nodes
- Monitors job completion
- Sends notifications
- Handles failures and retries

### Daemon (`brass/brass_daemon.pl`)
Background service that:
- Continuously monitors the job queue
- Processes jobs using the load balancer
- Runs health checks on nodes
- Manages concurrent job execution

### Configuration (`brass_config.yml`)
YAML configuration file defining:
- Memento aggregator nodes
- Load balancing strategy
- Health check settings
- Queue parameters
- Email settings

## Load Balancing Strategies

### Round Robin
Distributes requests evenly across all available nodes in sequence.
```yaml
load_balancing_strategy: round_robin
```
**Best for**: Equal-capacity nodes with similar workloads

### Least Connections
Sends requests to the node with fewest active connections.
```yaml
load_balancing_strategy: least_connections
```
**Best for**: Varying job complexity or node capacity

### Random
Randomly selects an available node for each request.
```yaml
load_balancing_strategy: random
```
**Best for**: Simple distribution without tracking

### Weighted Round Robin
Uses node weights to distribute requests proportionally.
```yaml
load_balancing_strategy: weighted_round_robin

aggregator_nodes:
  - name: powerful_node
    weight: 3  # Gets 3x more requests
  - name: standard_node
    weight: 1
```
**Best for**: Nodes with different capacities

## Quick Start

### 1. Configure Nodes

Edit `brass_config.yml`:
```yaml
aggregator_nodes:
  - name: node1
    host: mementoproxy1.cs.odu.edu
    port: 80
    timegate_path: /aggr/timegate
    weight: 1
    enabled: true
```

### 2. Install Dependencies

```bash
perl -MCPAN -e 'install YAML::Tiny'
perl -MCPAN -e 'install JSON'
perl -MCPAN -e 'install LWP::UserAgent'
```

### 3. Start the Daemon

```bash
cd brass
perl brass_daemon.pl --debug
```

### 4. Access Web Interface

Navigate to: `http://your-server/brass`

### 5. Submit a Job

1. Enter the website URL to reconstruct
2. Provide your email address
3. Click "Submit Reconstruction Job"

## Configuration Examples

### Single Node (Development)
```yaml
aggregator_nodes:
  - name: dev_node
    host: localhost
    port: 8080
    timegate_path: /aggr/timegate
    enabled: true
```

### Three-Node Production Cluster
```yaml
load_balancing_strategy: least_connections

aggregator_nodes:
  - name: aggr1
    host: memento1.example.com
    port: 80
    timegate_path: /aggr/timegate
    weight: 1
    enabled: true
    max_connections: 100

  - name: aggr2
    host: memento2.example.com
    port: 80
    timegate_path: /aggr/timegate
    weight: 1
    enabled: true
    max_connections: 100

  - name: aggr3
    host: memento3.example.com
    port: 80
    timegate_path: /aggr/timegate
    weight: 1
    enabled: true
    max_connections: 100
```

### Weighted Distribution
```yaml
load_balancing_strategy: weighted_round_robin

aggregator_nodes:
  - name: powerful_server
    host: memento-powerful.example.com
    weight: 5  # 5x capacity
    enabled: true

  - name: standard_server
    host: memento-standard.example.com
    weight: 1
    enabled: true
```

## Usage Examples

### Submit Job via Web Interface

1. Navigate to `http://your-server/brass`
2. Fill in the form:
   - **URL**: `http://www.example.com`
   - **Email**: `user@example.com`
   - **Options**: `-k -nc -l 3`
3. Click "Submit Reconstruction Job"

### Run Daemon in Debug Mode

```bash
cd brass
perl brass_daemon.pl --debug --interval=30
```

### Run Daemon as Service

```bash
perl brass_daemon.pl --daemon --interval=60 --max-concurrent=10
```

### Check Job Status

Navigate to: `http://your-server/brass?action=queue`

### View Load Balancer Stats

```bash
# In debug mode, stats are displayed automatically
perl brass_daemon.pl --debug
```

Output:
```
Stats:
  Active jobs: 3
  Load balancer nodes:
    node1: active=2, total=145, failed=3, healthy=yes
    node2: active=1, total=138, failed=1, healthy=yes
    node3: active=0, total=142, failed=0, healthy=yes
```

## Integration with Warrick

Brass integrates with Warrick through:

1. **MementoThread.pm**: Enhanced to support load balancing
   ```perl
   use BrassLoadBalancer;

   my $lb = BrassLoadBalancer->new('brass_config.yml');
   my $node = $lb->get_next_node();
   my $timegate = $lb->get_timegate_url($node);
   ```

2. **Environment Variables**: Daemon sets `BRASS_TIMEGATE` for warrick.pl

3. **Job Files**: Queue jobs as JSON files processed by the daemon

## Monitoring and Maintenance

### Check Daemon Status
```bash
ps aux | grep brass_daemon
```

### View Logs
```bash
tail -f /var/log/brass_daemon.log
```

### Monitor Queue
```bash
ls -la brass/queue/
cat brass/queue/[job-id].json
```

### Test Node Health
```bash
curl -I http://node1.example.com/aggr/timegate/
```

### Clean Old Jobs
```bash
# Remove completed jobs older than 30 days
find brass/queue -name "*.json" -mtime +30 -delete
```

## Troubleshooting

### Jobs Not Processing
- Check daemon is running: `ps aux | grep brass_daemon`
- Verify queue directory exists and is writable
- Check daemon logs for errors

### Load Balancer Not Working
- Verify brass_config.yml syntax
- Test node connectivity with curl
- Enable debug mode to see node selection

### Web Interface Error
- Check web server error logs
- Verify CGI permissions (755 for .cgi files)
- Ensure required Perl modules are installed

## Performance Tuning

### Increase Concurrent Jobs
```bash
perl brass_daemon.pl --max-concurrent=20
```

### Adjust Check Interval
```bash
perl brass_daemon.pl --interval=10  # Check every 10 seconds
```

### Configure Node Capacity
```yaml
aggregator_nodes:
  - name: node1
    max_connections: 200  # Increase capacity
```

## Security

- Web interface validates all input
- Job IDs are generated using MD5 hashing
- Queue files stored outside web root
- Email addresses validated before use
- Configure web server rate limiting

## Development

### Project Structure
```
brass/
├── cgi-bin/
│   └── brass.cgi          # Web interface
├── lib/
│   ├── BrassLoadBalancer.pm    # Load balancing
│   └── BrassJobProcessor.pm    # Job processing
├── queue/                 # Job queue (created at runtime)
├── output/                # Job output (created at runtime)
├── brass_daemon.pl        # Background daemon
├── BRASS_INSTALL.md       # Installation guide
└── README.md             # This file
```

### Adding New Load Balancing Strategy

Edit `BrassLoadBalancer.pm`:

```perl
sub get_next_node {
    my ($self) = @_;
    my $strategy = $self->{config}->{load_balancing_strategy};

    if ($strategy eq 'my_custom_strategy') {
        return $self->my_custom_strategy();
    }
    # ... existing strategies
}

sub my_custom_strategy {
    my ($self) = @_;
    # Implement your strategy
    return $selected_node;
}
```

## License

This software follows the same license as Warrick (GNU GPL v2 or later).

## Credits

- **Original Brass Concept**: Frank McCown, Amine Benjelloun, Michael L. Nelson (ODU)
- **Load Balancing Implementation**: Created for Issue #34
- **Warrick**: Frank McCown (ODU), Justin F. Brunelle (ODU)

## References

- [Warrick Project](https://github.com/oduwsdl/warrick)
- [Memento Protocol](http://www.mementoweb.org/)
- [MemGator - Memento Aggregator](https://github.com/oduwsdl/MemGator)
- [Original Brass Paper](https://digitalcommons.odu.edu/computerscience_fac_pubs/150/)

## Support

For installation help, see `BRASS_INSTALL.md`.

For issues:
1. Check the troubleshooting section
2. Review daemon logs
3. Test components individually
4. Verify configuration syntax
