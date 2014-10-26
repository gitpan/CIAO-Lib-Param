use Test::More tests => 55;

use File::Path;
BEGIN { use_ok('CIAO::Lib::Param') };

use strict;
use warnings;

CIAO::Lib::Param->import(':all');

rmtree('tmp');
$ENV{PFILES} = "tmp;param";
mkdir( 'tmp', 0755 );

# brute force read of parameters to compare against the
# real interface.
my @pnames = pnames( "param/surface_intercept.par" );

our $pf;
our $value;

# check for non-existent parameter file
eval { 
     $pf = CIAO::Lib::Param->new( "foo.par" ); 
};
ok( $@, "new: non-existent file" );

eval { 
     $pf = CIAO::Lib::Param->new( "surface_intercept", "rH" );
};
ok( !$@, "new" )
  or diag($@);

is( $pf->get( 'dfm2_filename'), 'perfect.DFR', 'get' );

# make sure boolean transformations in get() work like in getb()
ok( 1 == $pf->getb( 'onlygoodrays' ), "getb: true" );
ok( 1 == $pf->get( 'onlygoodrays' ),  "get boolean: true" );
ok( 0 == $pf->getb( 'help' ), "getb: false" );
ok( 0 == $pf->get( 'help' ),  "get boolean: false" );


# check out pmatch
{
  my @lnames = @pnames;
  my $pm = $pf->match( '*' );

  while( my $pname = $pm->next )
  {
    my $lname = (shift @lnames)->{name};
    is( $pname, $lname, "pnext: $lname" );
  }
}

# close the parameter file.
undef $pf;

#--------------------------------------------------------
# check if two filename new works
eval {
  $pf = CIAO::Lib::Param->new([ "surface_intercept", undef ], "rH");
};
ok ( !$@ && 1 == $pf->get('onlygoodrays'), "[filename,undef] open" )
  or diag($@);

eval {
  $pf = CIAO::Lib::Param->new([ undef, "surface_intercept" ], "rH");
};
ok ( !$@ && 1 == $pf->get('onlygoodrays'), "[undef,filename] open" )
  or diag($@);

undef $pf;


#--------------------------------------------------------
# check if command line arguments work
eval {
  $pf = CIAO::Lib::Param->new( "surface_intercept", "rH", "help+" );
};
ok ( !$@, "new with arguments" )
  or diag($@);

ok ( 1 == $pf->get( 'help' ), "command line set" );

undef $pf;

#--------------------------------------------------------
# check out reading everything with pget
{
  my %list = pget( 'surface_intercept' );

  for my $par ( @pnames )
  {
    my $value = $par->{value};
    $value = { yes => 1, no => 0 }->{$par->{value}} if 'b' eq $par->{type};
    if ( $par->{type} eq 's' )
    {
      is ( $list{$par->{name}}, $value, "pget all: $par->{name}" );
    }
    else
    {
       ok( $list{$par->{name}} == $value, "pget all: $par->{name}" );
     }
  }

}

#--------------------------------------------------------
# test pset of a single value
eval {
  pset( 'surface_intercept', input => 'SnackFud' );
};
ok( !$@, "pset: single" ) or diag($@);

#--------------------------------------------------------
# test pget of a single value
is( pget( 'surface_intercept', 'input' ), 'SnackFud', "pget: single" );

#--------------------------------------------------------
# test pset of multiple values
eval {
  pset( 'surface_intercept', input => 'YoMama', output => 'YoDaddy' );
};
ok( !$@, "pset: multiple" ) or diag($@);

#--------------------------------------------------------
# test pget of multiple values
eval {
  my ( $input, $output ) = pget( 'surface_intercept', qw/ input output / );
  ok ( $input eq 'YoMama' && $output eq 'YoDaddy', "pget: multiple" );
};
ok( !$@, "pget: multiple" ) or diag $@;


#--------------------------------------------------------
# check if command line arguments work with pget
eval {
  is ( pget( 'surface_intercept', [ 'help+'], 'help' ), 1, "pget: argv" );
};
ok ( !$@, "pget: argv" )
  or diag($@);
undef $pf;

#--------------------------------------------------------
sub pnames
{
  my ( $filename ) = @_;

  open PFILE, $filename
    or die( "unable to open $filename!\n" );

  my @pnames;
  while( <PFILE> )
  {
    next if /^\#/;
    my @l = split(',');
    $l[3] =~ s/^"//;
    $l[3] =~ s/"$//;
    push @pnames, { name => $l[0], 
		    type => $l[1],
		    value => $l[3] };
  }

  @pnames;
}
