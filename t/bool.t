use Test::More tests => 12;

use File::Path;
BEGIN { use_ok('CIAO::Lib::Param') };

use strict;
use warnings;

rmtree('tmp');
$ENV{PFILES} = "tmp;param";
mkdir( 'tmp', 0755 );

our $pf;
our $value;

eval { 
     $pf = CIAO::Lib::Param->new( "surface_intercept", "rH" );
};
ok( !$@, "new" )
  or diag($@);

# make sure boolean transformations in get() work like in getb()
ok( 1 == $pf->getb( 'onlygoodrays' ), "getb: true" );
ok( 1 == $pf->get( 'onlygoodrays' ),  "get boolean: true" );
ok( 0 == $pf->getb( 'help' ), "getb: false" );
ok( 0 == $pf->get( 'help' ),  "get boolean: false" );

# now try different ways of setting booleans. Since the parameter file
# has been opened in non-prompt mode (H), we'll get croaks on error

eval { 
     $pf->set('help', 'frob');
};
ok( $@,  "set boolean: bad string" );

eval { 
     $pf->set('help', 'yes');
};
ok( !$@ && 1 == $pf->get('help'),  'set: yes' );

eval { 
     $pf->set('help', 'no');
};
ok( !$@ && 0 == $pf->get('help'),  'set: no' );


# now try boolean numerics to test automatic conversion
$pf->set( 'help', 'yes' );
eval {
     $pf->set('help', 0 );
};
ok( !$@ && 0 == $pf->get('help'),  'set: 0' );

$pf->set( 'help', 'no' );
eval {
     $pf->set('help', 1 );
};
ok( !$@ && 1 == $pf->get('help'),  'set: 1' );

$pf->set( 'help', 'yes' );
eval {
     $pf->set('help', undef );
};
ok( !$@ && 0 == $pf->get('help'),  'set: undef' );


