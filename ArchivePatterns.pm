#!/usr/bin/perl -w
#
# ArchivePatterns.pm
#
# Module for loading and managing archive URI rewriting patterns
# and branding removal patterns from configuration files.
#
# This module addresses issue #33 by providing a configurable way
# to handle archive-specific URI formats without hardcoding patterns.
#
# Copyright (C) 2025
# Licensed under GPL v2 or later
#

package ArchivePatterns;

use strict;
use warnings;
use Carp;

our $VERSION = '1.0';

# Constructor
sub new {
    my ($class, $config_file) = @_;

    my $self = {
        config_file => $config_file,
        uri_rewrite_patterns => [],
        branding_removal_patterns => [],
        loaded => 0,
    };

    bless $self, $class;

    # Load patterns if config file was provided
    if (defined $config_file && -e $config_file) {
        $self->load_patterns($config_file);
    }

    return $self;
}

# Load patterns from configuration file
sub load_patterns {
    my ($self, $config_file) = @_;

    $config_file = $self->{config_file} unless defined $config_file;

    unless (-e $config_file) {
        carp "Warning: Archive patterns config file not found: $config_file\n";
        return 0;
    }

    open(my $fh, '<', $config_file) or do {
        carp "Warning: Cannot open archive patterns config file: $config_file: $!\n";
        return 0;
    };

    my $current_section = {};
    my $section_name = '';

    while (my $line = <$fh>) {
        chomp $line;

        # Skip comments and empty lines
        next if $line =~ /^\s*#/ || $line =~ /^\s*$/;

        # New section header
        if ($line =~ /^\[([^\]]+)\]/) {
            # Save previous section if it exists
            if ($section_name && exists $current_section->{type}) {
                $self->_add_pattern($current_section);
            }

            # Start new section
            $section_name = $1;
            $current_section = { name => $section_name };
        }
        # Key-value pair
        elsif ($line =~ /^\s*(\w+)\s*=\s*(.+)\s*$/) {
            my ($key, $value) = ($1, $2);
            $current_section->{$key} = $value;
        }
    }

    # Don't forget the last section
    if ($section_name && exists $current_section->{type}) {
        $self->_add_pattern($current_section);
    }

    close($fh);

    $self->{loaded} = 1;
    return 1;
}

# Internal method to add a pattern to the appropriate array
sub _add_pattern {
    my ($self, $pattern_data) = @_;

    return unless exists $pattern_data->{type} && exists $pattern_data->{pattern};

    my $pattern_entry = {
        name => $pattern_data->{name} || 'unknown',
        pattern => $pattern_data->{pattern},
        description => $pattern_data->{description} || '',
        flags => $pattern_data->{flags} || '',
    };

    if ($pattern_data->{type} eq 'uri_rewrite') {
        push @{$self->{uri_rewrite_patterns}}, $pattern_entry;
    }
    elsif ($pattern_data->{type} eq 'branding_removal') {
        push @{$self->{branding_removal_patterns}}, $pattern_entry;
    }
}

# Get all URI rewrite patterns
sub get_uri_rewrite_patterns {
    my ($self) = @_;
    return @{$self->{uri_rewrite_patterns}};
}

# Get all branding removal patterns
sub get_branding_removal_patterns {
    my ($self) = @_;
    return @{$self->{branding_removal_patterns}};
}

# Apply URI rewrite patterns to a file using sed
sub apply_uri_rewrites {
    my ($self, $target_file) = @_;

    my $count = 0;

    foreach my $pattern_entry (@{$self->{uri_rewrite_patterns}}) {
        my $pattern = $pattern_entry->{pattern};
        my $desc = $pattern_entry->{description};

        # Execute sed command
        my $result = `sed -i '$pattern' "$target_file" 2>&1`;

        if ($? == 0) {
            $count++;
        } else {
            carp "Warning: Failed to apply URI rewrite pattern '$desc': $result\n" if $result;
        }
    }

    return $count;
}

# Apply branding removal patterns to HTML content
sub apply_branding_removals {
    my ($self, $html_ref) = @_;

    return 0 unless ref($html_ref) eq 'SCALAR';

    my $count = 0;

    foreach my $pattern_entry (@{$self->{branding_removal_patterns}}) {
        my $pattern = $pattern_entry->{pattern};
        my $flags = $pattern_entry->{flags} || '';
        my $desc = $pattern_entry->{description};

        # Apply pattern with appropriate flags using eval for dynamic regex
        my $success = 0;
        eval {
            # Special handling for line removal patterns
            if ($desc =~ /line removal/) {
                # This requires special handling - remove entire line
                my @lines = split(/\n/, $$html_ref);
                my @filtered_lines;
                foreach my $line (@lines) {
                    # Use eval for dynamic pattern matching
                    my $matched = 0;
                    if ($flags) {
                        $matched = eval "\$line =~ /\$pattern/$flags";
                    } else {
                        $matched = eval "\$line =~ /\$pattern/";
                    }

                    if ($matched) {
                        $count++;
                    } else {
                        push @filtered_lines, $line;
                    }
                }
                $$html_ref = join("\n", @filtered_lines);
                $success = 1;
            }
            else {
                # Normal regex substitution using eval
                if ($flags) {
                    $success = eval "\$\$html_ref =~ s/\$pattern//$flags";
                } else {
                    $success = eval "\$\$html_ref =~ s/\$pattern//";
                }
                $count++ if $success;
            }
        };

        if ($@) {
            carp "Warning: Failed to apply pattern '$desc': $@\n";
            next;
        }
    }

    return $count;
}

# Check if patterns are loaded
sub is_loaded {
    my ($self) = @_;
    return $self->{loaded};
}

# Get statistics about loaded patterns
sub get_stats {
    my ($self) = @_;

    return {
        uri_rewrite_count => scalar @{$self->{uri_rewrite_patterns}},
        branding_removal_count => scalar @{$self->{branding_removal_patterns}},
        total_count => scalar(@{$self->{uri_rewrite_patterns}}) + scalar(@{$self->{branding_removal_patterns}}),
        loaded => $self->{loaded},
    };
}

1;

__END__

=head1 NAME

ArchivePatterns - Configurable archive pattern management for Warrick

=head1 SYNOPSIS

  use ArchivePatterns;

  # Create new instance with config file
  my $patterns = ArchivePatterns->new('archive_patterns.conf');

  # Apply URI rewrites to a file
  $patterns->apply_uri_rewrites($target_file);

  # Apply branding removal to HTML content
  my $html = "<html>...</html>";
  $patterns->apply_branding_removals(\$html);

  # Get statistics
  my $stats = $patterns->get_stats();
  print "Loaded $stats->{total_count} patterns\n";

=head1 DESCRIPTION

ArchivePatterns provides a configurable way to manage archive-specific
URI rewriting patterns and branding removal patterns. This addresses
issue #33 by eliminating hardcoded patterns and allowing easy updates
when archive formats change.

=head1 METHODS

=over 4

=item new($config_file)

Create a new ArchivePatterns object and optionally load patterns from
the specified configuration file.

=item load_patterns($config_file)

Load patterns from a configuration file.

=item get_uri_rewrite_patterns()

Returns an array of URI rewrite pattern entries.

=item get_branding_removal_patterns()

Returns an array of branding removal pattern entries.

=item apply_uri_rewrites($target_file)

Apply all URI rewrite patterns to the specified file using sed.
Returns the number of patterns successfully applied.

=item apply_branding_removals(\$html)

Apply all branding removal patterns to the HTML content (passed as
a scalar reference). Returns the number of patterns successfully applied.

=item is_loaded()

Returns true if patterns have been successfully loaded.

=item get_stats()

Returns a hash reference with statistics about loaded patterns.

=back

=head1 CONFIGURATION FILE FORMAT

The configuration file uses INI-style format:

  [section_name]
  type = uri_rewrite|branding_removal
  pattern = pattern_string
  description = description
  flags = regex_flags (optional, for branding_removal only)

=head1 AUTHOR

Warrick Development Team

=head1 LICENSE

GPL v2 or later

=cut
