#!perl -T

use Test::More tests => 3;
use Tie::Syslog;

$Tie::Syslog::ident  = 'Tie::Syslog newstyle test';
$Tie::Syslog::logopt = 'pid,ndelay';

ok(
    ! do {
        tie *FAIL, "Tie::Syslog", {};
    }, "Tying failure"
);

ok (
    do { 
        tie *TEST, "Tie::Syslog", {
            'priority' => 'LOG_DEBUG',
            'facility' => 'LOG_LOCAL0',
        };
    }, "Tying test" 
);

ok (
    do { print TEST "Built!" }, 
    "Print test"
);

