package Tie::Syslog;

our $VERSION = '0.00_04';

use 5.006;
use strict;
use warnings;
use Carp qw/croak confess/;
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

# 'Globals'
my @openlog_opts = ('ident', 'logopt', 'facility');
my %open_handles;

# ------------------------------------------------------------------------------
# Handle tying methods - see 'perldoc perltie' and 'perldoc Tie::Handle'
# ------------------------------------------------------------------------------

sub TIEHANDLE {
    my $pkg = shift;

    # Die if called as an instance method:
    croak "Wrong initialization: not an instance method" 
        if ref($pkg); 
    
    # Wrong initialization 
    croak "Odd number of elements in hash options"
        if @_ % 2;

    my $self = bless { @_ }, $pkg;

    # Wrong initialization
    for (@openlog_opts, 'priority') {
        croak "You must provide values for '$_' option"
            unless $self->{$_};
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
    openlog(@self->{@openlog_opts}) 
        unless _connected;
    # CLOSE will call closelog() only when there are no more open tied handles.
    $open_handles{$self} = 1;
    return $self->{'is_open'} = 1;
}

sub CLOSE {
    my $self = shift;
    delete $open_handles{$self};
    return scalar(keys(%open_handles)) ? 1 : closelog();
}

sub PRINT {
    my $self = shift;
    syslog $self->{'priority'}, @_;
}

sub PRINTf {
    my $self = shift;
    my $format = shift;
    syslog $self->{'priority'}, $format, $_;
}


# This peeks a little into Sys:Syslog internals, so it might break sooner or 
# later. Expect this to happen. 
#   fileno() of socket if available
#   -1 if connected but fileno() said nothing (happens with "native" connection
#       and maybe other)
#   undef otherwise
sub FILENO {
    my $fd = fileno(*Sys::Syslog::SYSLOG);
    return              defined($fd) ? $fd  :
             $Sys::Syslog::connected ?  -1  :
                                       undef;
}


# ------------------------------------------------------------------------------
# 'Private' methods
# ------------------------------------------------------------------------------
sub _connected() {
    return $Sys::Syslog::connected;
}

# ------------------------------------------------------------------------------
# Provide a graceful fallback for not-yet-implemented methods
# ------------------------------------------------------------------------------
sub AUTOLOAD {
    my $self = shift;
    my $name = (split '::', our $AUTOLOAD)[-1];
    return if $name eq 'DESTROY';

    my $err = "$name operation not (yet?) supported";

    # See if errors are fatals
    my $errors_are_fatals = ref($self) ? $self->{'errors_are_fatals'} : 1;
    confess $err if $errors_are_fatals;

    # Install a handler for this operation if errors are nonfatal
    {
        no strict 'refs';
        *$name = sub {
            print "$name operation not (yet?) supported";
        }
    }

    $self->$name;
}

1; # End of Tie::Syslog
__END__

=head1 NAME

Tie::Syslog - The great new Tie::Syslog!

=head1 VERSION

Version 0.00_04


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Tie::Syslog;

    my $foo = Tie::Syslog->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1


=head2 function2


=head1 AUTHOR

Giacomo Montagner, C<< <kromg at entirelyunlike.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tie-syslog at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tie-Syslog>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tie::Syslog


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Tie-Syslog>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Tie-Syslog>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Tie-Syslog>

=item * Search CPAN

L<http://search.cpan.org/dist/Tie-Syslog/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Giacomo Montagner.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut


