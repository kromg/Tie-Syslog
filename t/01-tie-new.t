#!perl -T

use Test::More tests => 3;
use Tie::Syslog;
no warnings qw(once);

$Tie::Syslog::ident  = 'Tie::Syslog newstyle test';
$Tie::Syslog::logopt = 'pid,ndelay';

eval {
    tie *FAIL, "Tie::Syslog", {};
};

ok( $@, "Parameters check" );

eval {
    tie *TEST, "Tie::Syslog", {
        'priority' => 'LOG_DEBUG',
        'facility' => 'LOG_LOCAL0',
    };
};

ok ( ! $@, "Tying test ($@)" );

eval {
    print TEST "Built!";
};

ok ( ! $@, "Print test ($@)" );

