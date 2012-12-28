package Tie::Syslog;

our $VERSION = '2.00_09a';

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
$Tie::Syslog::logopt = 'pid,ndelay';

# 'Private Globals'
my @mandatory_opts = ('facility', 'priority');
my %open_connections;

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
        };
    } else {
        my ($facility, $priority) = @_ ? split '\.', shift : ('LOG_LOCAL0', 'LOG_ERR');
        $Tie::Syslog::ident  = shift if @_;
        $Tie::Syslog::logopt = ( join ',' => @_) if @_;
        $params = {
            facility => $facility,
            priority => $priority,
        };
    }

    # Normalize names
    for ('facility', 'priority') {
        next unless $params->{ $_ };
        $params->{ $_ } =  uc( $params->{ $_ } );
        $params->{ $_ } =~ s/EMERGENCY/EMERG/;
        $params->{ $_ } =~ s/ERROR/ERR/;
        $params->{ $_ } =~ s/CRITICAL/CRIT/;
        $params->{ $_ } =  'LOG_' . $params->{ $_ }
            unless $params->{ $_ } =~ /^LOG_/;
    }

    return $params;
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
            croak "You must provide value for '$_' option"
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
    my $f = $self->facility;
    # Ignore any parameter passed, since we just call openlog() with parameters
    # got from initialization
    eval { 
        openlog($Tie::Syslog::ident, $Tie::Syslog::logopt, $self->facility)
            unless $open_connections{ $f };
    };
    croak "openlog() failed with errors: $@"
        if $@;
    $open_connections{ $f } = 1;
    return $self->{'is_open'} = 1;
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

# Provide a fallback method for write
sub WRITE {
    my $self = shift;
    my $string = shift;
    my $length = shift || length $string;
    my $offset = shift; # Ignored

    $self->PRINT(substr($string, 0, $length));

    return $length;
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
