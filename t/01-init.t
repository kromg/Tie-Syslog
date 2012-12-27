#!perl -T

use Test::More tests => 2;
use Tie::Syslog;

ok (
    do { tie *TEST, "Tie::Syslog", 
        'ident'    => 'build test',
        'logopt'   => 'pid,ndelay',
        'priority' => 'LOG_WARNING',
        'facility' => 'LOG_LOCAL0',
    }, "Tying test" 
);

ok (
    do { print TEST "Built!" }, 
    "Print test"
);

