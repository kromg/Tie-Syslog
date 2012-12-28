#!perl -T

use Test::More tests => 4;
use Tie::Syslog;
no warnings qw(once);

eval {
    tie *DEF, "Tie::Syslog";
};

ok( ! $@, "Tying with defaults ($@)" );

eval {
    print DEF "Built!";
};

ok ( ! $@, "Print test with defaults ($@)" );


eval {
    tie *TEST, "Tie::Syslog", 'local0.debug';
};

ok ( ! $@, "Tying with old style syntax ($@)" );

eval {
    print TEST "Built!";
};

ok ( ! $@, "Print test ($@)" );

