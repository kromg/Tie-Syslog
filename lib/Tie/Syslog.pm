package Tie::Syslog;

our $VERSION = '0.00_07';

use 5.006;
use strict;
use warnings;
use Carp qw/carp croak confess/;
use Sys::Syslog qw/:standard :macros/;
# Define all default handle-tying subs, so that they can be autoloaded if 
# necessary.
use subs qw(
    TIEHANDLE
    WRITE
    PRINT
    PRINTF
    READ
    READLINE
    GETC
    CLOSE
    OPEN
    BINMODE
    EOF
    TELL
    SEEK
    UNTIE
    FILENO
);

# 'Public Globals'
$Tie::Syslog::ident = (split '/', $0)[-1];

# 'Private Globals'
my @openlog_opts   = ('ident', 'logopt', 'facility');
my @mandatory_opts = (@openlog_opts, 'priority');
my %open_handles;

# ------------------------------------------------------------------------------
# 'Private' functions
# ------------------------------------------------------------------------------

sub _get_params {

    my $params;

    if (ref($_[0]) eq 'HASH') {
        # New-style configuration 
        # Copy values so we don't risk changing an existing reference
        $params = { 
            %{ shift() },
            ident => $Tie::Syslog::ident,
        };
    } else {
        my ($facility, $priority) = split '\.', $_[0];
        $Tie::Syslog::ident = $_[1] if $_[1];
        $params = {
            facility => $facility,
            priority => $priority,
            logopt   => ( join ',' => @_[2..$#_] ),
            ident    => $Tie::Syslog::ident,
        };
    }

    # Normalize names
    for ('facility', 'priority') {
        next unless $params->{ $_ };
        $params->{ $_ } = uc( $params->{ $_ } );
        $params->{ $_ } = 'LOG_' . $params->{ $_ }
            unless $params->{ $_ } =~ /^LOG_/;
    }

    return $params;
}

sub _is_open {
    my ($facility, $priority, $define_it) = @_;
    $open_handles{$facility}{$priority} = 1 if $define_it;
    return $open_handles{$facility}{$priority};
}

# ------------------------------------------------------------------------------
# Accessors/mutators
# ------------------------------------------------------------------------------

for my $opt (@mandatory_opts) {
    no strict 'refs';
    *$opt = sub {
        my $self = shift;
        $self->{$opt} = shift if @_;
        return $self->{$opt};
    };
}

# ------------------------------------------------------------------------------
# Handle tying methods - see 'perldoc perltie' and 'perldoc Tie::Handle'
# ------------------------------------------------------------------------------

sub TIEHANDLE {
    my ($pkg, $self);
    if (my $ref = ref($_[0])) {
        # Use a copy-constructor, providing support for 
        # single-parameter-override via the @_
        $pkg = $ref;
        my $prototype = shift;
        my $other_parameters = _get_params @_;
        $self = bless {
                %$prototype, 
                %$other_parameters,
            }, $pkg;
    } else {
        # Called as a class method
        $pkg = shift;
    
        my $parameters = _get_params @_;

        $self = bless $parameters, $pkg;

        # Wrong initialization
        for (@mandatory_opts) {
            croak "You must provide values for '$_' option"
                unless $self->{$_};
        }
    }

    # Now openlog() if needed, by calling our own open()
    $self->OPEN();

    # Finally return 
    return $self;
}

sub OPEN {
    my $self = shift;
    # Ignore any parameter passed, since we just call openlog() with parameters
    # got from initialization
    # openlog() croaks if it can't get a connection, so there is no need to 
    # check for errors
    openlog(@{$self}{@openlog_opts})
        unless _is_open($self->facility, $self->priority);
    $self->{'is_open'} = 1;
    return _is_open($self->facility, $self->priority, 1);
}

# Stub - since we can have multiple facility/priority pairs, we could have many
# connections (in general); since Sys::Syslog does NOT allow user to select 
# which channel to close, we really have nothing to do here. 
sub CLOSE {
    my $self = shift;
    $self->{'is_open'} = 0;
    return 1;
}

sub PRINT {
    my $self = shift;
    carp "Cannot PRINT to a closed filehandle!" unless $self->{'is_open'};
    eval { syslog $self->facility."|".$self->priority, @_ };
    croak "PRINT failed with errors: $@"
        if $@;
}

sub PRINTF {
    my $self = shift;
    carp "Cannot PRINTF to a closed filehandle!" unless $self->{'is_open'};
    my $format = shift;
    eval { syslog $self->facility."|".$self->priority, $format, @_ };
    croak "PRINTF failed with errors: $@"
        if $@;
}


# This peeks a little into Sys:Syslog internals, so it might break sooner or 
# later. Expect this to happen. 
#   fileno() of socket if available
#   -1 if connected but fileno() said nothing (happens with "native" connection
#       and maybe other)
#   undef otherwise
sub FILENO {
    my $fd = fileno(*Sys::Syslog::SYSLOG);
    return defined($fd) ? $fd  : -1;
}

sub DESTROY {
    my $self = shift;
    return 1 unless $self;
    $self->CLOSE();
    undef $self;
}

sub UNTIE {
    my $self = shift;
    return 1 unless $self;
    $self->DESTROY;
}


# ------------------------------------------------------------------------------
# Provide a graceful fallback for not(-yet?)-implemented methods
# ------------------------------------------------------------------------------
sub AUTOLOAD {
    my $self = shift;
    my $name = (split '::', our $AUTOLOAD)[-1];
    return if $name eq 'DESTROY';

    my $err = "$name operation not (yet?) supported";

    # See if errors are fatals
    my $errors_are_fatal = ref($self) ? $self->{'errors_are_fatal'} : 1;
    confess $err if $errors_are_fatal;

    # Install a handler for this operation if errors are nonfatal
    {
        no strict 'refs';
        *$name = sub {
            print "$name operation not (yet?) supported";
        }
    }

    $self->$name;
}


# ------------------------------------------------------------------------------
# Compatibility with previous module
# ------------------------------------------------------------------------------
# die() and warn() print to STDERR
sub ExtendedSTDERR {
    return 1;
}

'End of Tie::Syslog'
__END__
