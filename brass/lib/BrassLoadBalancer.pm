package BrassLoadBalancer;

# Load Balancer for Brass - Distributes memento aggregation across multiple nodes
# Created for Warrick Brass interface rework (Issue #34)

use strict;
use warnings;
use YAML::Tiny;
use LWP::UserAgent;
use Time::HiRes qw(time);

# Constructor
sub new {
    my ($class, $config_file) = @_;

    my $self = {
        config_file => $config_file || 'brass_config.yml',
        nodes => [],
        current_index => 0,
        node_stats => {},
        ua => LWP::UserAgent->new(timeout => 10),
        debug => 0
    };

    bless $self, $class;
    $self->load_config();
    $self->initialize_node_stats();

    return $self;
}

# Load configuration from YAML file
sub load_config {
    my ($self) = @_;

    unless (-e $self->{config_file}) {
        die "Configuration file $self->{config_file} not found\n";
    }

    my $yaml = YAML::Tiny->read($self->{config_file});
    $self->{config} = $yaml->[0];

    # Load enabled nodes
    foreach my $node (@{$self->{config}->{aggregator_nodes}}) {
        if ($node->{enabled}) {
            push @{$self->{nodes}}, $node;
        }
    }

    if (@{$self->{nodes}} == 0) {
        die "No enabled aggregator nodes found in configuration\n";
    }

    $self->debug_print("Loaded " . scalar(@{$self->{nodes}}) . " enabled nodes");
}

# Initialize statistics for each node
sub initialize_node_stats {
    my ($self) = @_;

    foreach my $node (@{$self->{nodes}}) {
        $self->{node_stats}->{$node->{name}} = {
            active_connections => 0,
            total_requests => 0,
            failed_requests => 0,
            last_health_check => 0,
            is_healthy => 1,
            avg_response_time => 0
        };
    }
}

# Get next node using configured load balancing strategy
sub get_next_node {
    my ($self) = @_;

    my $strategy = $self->{config}->{load_balancing_strategy} || 'round_robin';

    if ($strategy eq 'round_robin') {
        return $self->round_robin();
    } elsif ($strategy eq 'least_connections') {
        return $self->least_connections();
    } elsif ($strategy eq 'random') {
        return $self->random_node();
    } elsif ($strategy eq 'weighted_round_robin') {
        return $self->weighted_round_robin();
    } else {
        $self->debug_print("Unknown strategy $strategy, using round_robin");
        return $self->round_robin();
    }
}

# Round Robin load balancing
sub round_robin {
    my ($self) = @_;

    my $attempts = 0;
    my $max_attempts = scalar(@{$self->{nodes}});

    while ($attempts < $max_attempts) {
        my $node = $self->{nodes}->[$self->{current_index}];
        $self->{current_index} = ($self->{current_index} + 1) % scalar(@{$self->{nodes}});

        if ($self->is_node_available($node)) {
            $self->debug_print("Round robin selected: $node->{name}");
            return $node;
        }

        $attempts++;
    }

    # If all nodes are unavailable, return the first one anyway
    $self->debug_print("Warning: All nodes appear unavailable, using first node");
    return $self->{nodes}->[0];
}

# Least Connections load balancing
sub least_connections {
    my ($self) = @_;

    my $selected_node = undef;
    my $min_connections = 999999;

    foreach my $node (@{$self->{nodes}}) {
        next unless $self->is_node_available($node);

        my $connections = $self->{node_stats}->{$node->{name}}->{active_connections};

        if ($connections < $min_connections) {
            $min_connections = $connections;
            $selected_node = $node;
        }
    }

    $selected_node = $self->{nodes}->[0] unless defined $selected_node;
    $self->debug_print("Least connections selected: $selected_node->{name} (connections: $min_connections)");

    return $selected_node;
}

# Random load balancing
sub random_node {
    my ($self) = @_;

    my @available_nodes = grep { $self->is_node_available($_) } @{$self->{nodes}};

    if (@available_nodes == 0) {
        @available_nodes = @{$self->{nodes}};
    }

    my $node = $available_nodes[int(rand(@available_nodes))];
    $self->debug_print("Random selected: $node->{name}");

    return $node;
}

# Weighted Round Robin load balancing
sub weighted_round_robin {
    my ($self) = @_;

    # Simple implementation: repeat nodes based on weight
    my @weighted_nodes;
    foreach my $node (@{$self->{nodes}}) {
        next unless $self->is_node_available($node);
        my $weight = $node->{weight} || 1;
        for (1..$weight) {
            push @weighted_nodes, $node;
        }
    }

    if (@weighted_nodes == 0) {
        return $self->{nodes}->[0];
    }

    my $node = $weighted_nodes[$self->{current_index} % scalar(@weighted_nodes)];
    $self->{current_index}++;

    $self->debug_print("Weighted round robin selected: $node->{name}");
    return $node;
}

# Check if node is available
sub is_node_available {
    my ($self, $node) = @_;

    my $stats = $self->{node_stats}->{$node->{name}};

    # Check if node is healthy
    return 0 unless $stats->{is_healthy};

    # Check if node has capacity
    my $max_conn = $node->{max_connections} || 100;
    return 0 if $stats->{active_connections} >= $max_conn;

    return 1;
}

# Build TimeGate URL for a node
sub get_timegate_url {
    my ($self, $node) = @_;

    my $protocol = ($node->{port} == 443) ? 'https' : 'http';
    my $url = sprintf("%s://%s:%d%s",
        $protocol,
        $node->{host},
        $node->{port},
        $node->{timegate_path}
    );

    return $url;
}

# Perform health check on a node
sub health_check {
    my ($self, $node) = @_;

    my $stats = $self->{node_stats}->{$node->{name}};
    my $timegate_url = $self->get_timegate_url($node);

    $self->debug_print("Health check: $node->{name} -> $timegate_url");

    my $start_time = time();
    my $response = $self->{ua}->head($timegate_url);
    my $elapsed = time() - $start_time;

    $stats->{last_health_check} = time();

    if ($response->is_success || $response->code == 302 || $response->code == 400) {
        # 400 is acceptable for timegate without params
        # 302 is acceptable for redirect
        $stats->{is_healthy} = 1;
        $stats->{avg_response_time} = $elapsed;
        $self->debug_print("Health check passed: $node->{name} (${elapsed}s)");
        return 1;
    } else {
        $stats->{is_healthy} = 0;
        $self->debug_print("Health check failed: $node->{name} - " . $response->status_line);
        return 0;
    }
}

# Run health checks on all nodes
sub health_check_all {
    my ($self) = @_;

    return unless $self->{config}->{health_check}->{enabled};

    $self->debug_print("Running health checks on all nodes");

    foreach my $node (@{$self->{nodes}}) {
        $self->health_check($node);
    }
}

# Increment active connections for a node
sub increment_connections {
    my ($self, $node) = @_;
    $self->{node_stats}->{$node->{name}}->{active_connections}++;
    $self->{node_stats}->{$node->{name}}->{total_requests}++;
}

# Decrement active connections for a node
sub decrement_connections {
    my ($self, $node) = @_;
    $self->{node_stats}->{$node->{name}}->{active_connections}--;
    $self->{node_stats}->{$node->{name}}->{active_connections} = 0
        if $self->{node_stats}->{$node->{name}}->{active_connections} < 0;
}

# Record a failed request
sub record_failure {
    my ($self, $node) = @_;
    $self->{node_stats}->{$node->{name}}->{failed_requests}++;
}

# Get statistics for all nodes
sub get_stats {
    my ($self) = @_;
    return $self->{node_stats};
}

# Enable debug mode
sub set_debug {
    my ($self, $debug) = @_;
    $self->{debug} = $debug;
}

# Debug print
sub debug_print {
    my ($self, $message) = @_;
    print "DEBUG [BrassLoadBalancer]: $message\n" if $self->{debug};
}

1;
