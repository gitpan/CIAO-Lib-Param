#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#ifdef FLAT_INCLUDES
#include <parameter.h>
#else
#include <cxcparam/parameter.h>
#endif

/* yes, this is gross, but it beats including pfile.h */
extern int parerr;

/* no choice here; the's aren't prototyped anywhere from pfile.c */
typedef void (*vector)();
vector paramerract( void (*newact)() );

/* needed for typemap magic */
typedef paramfile  CIAO_Lib_ParamPtr;
typedef pmatchlist CIAO_Lib_Param_MatchPtr;

/* use Perl to get temporary space in interface routines; it'll
   get garbage collected automatically */
static void *
get_mortalspace( int nbytes )
{
  SV *mortal = sv_2mortal( NEWSV(0, nbytes ) );
  return SvPVX(mortal);
}

/* propagate the cxcparam error value up to Perl.
   this is used to cause a croak at the Perl level (see Param.pm for
   more info */
static void
set_parerr( void )
{
  /* save, as paramerrstr resets parerr */
  int s_parerr = parerr;
  SV *sv;

  /* push error string up to Perl*/
  sv = get_sv( "CIAO::Lib::Param::_errstr", 1 );
  if ( parerr )
    sv_setpv( sv, paramerrstr() );
  else
    sv_setsv( sv, &PL_sv_undef );

  /* push error code up to Perl.  do this last
     as a non-zero value will cause a croak,
     and errstr should be set before that */
  sv = get_sv( "CIAO::Lib::Param::_errno", 1 );
  sv_setiv( sv, s_parerr );
  SvSETMAGIC(sv);
}

/* The replacement error message handling routine for cxcparam.
   This is put in place in the BOOT: section */
static void
perl_paramerr( int level, char *message, char *name )
{
  SV* sv;

  /* paramerrstr resets parerr */
  int s_parerr = parerr;

  sv_setpvf( get_sv( "CIAO::Lib::Param::_errmsg", 1 ),
	     "%s: %s: %s", message, paramerrstr(), name );

  parerr = s_parerr;
}


MODULE = CIAO::Lib::Param::Match	PACKAGE = CIAO::Lib::Param::Match	PREFIX = pmatch

void
DESTROY(mlist)
	CIAO_Lib_Param_MatchPtr	mlist
  CODE:
	pmatchclose(mlist);

MODULE = CIAO::Lib::Param::Match	PACKAGE = CIAO::Lib::Param::MatchPtr	PREFIX = pmatch

int
pmatchlength(mlist)
	CIAO_Lib_Param_MatchPtr	mlist

char *
pmatchnext(mlist)
	CIAO_Lib_Param_MatchPtr	mlist


void
pmatchrewind(mlist)
	CIAO_Lib_Param_MatchPtr	mlist


MODULE = CIAO::Lib::Param		PACKAGE = CIAO::Lib::Param

BOOT:
	set_paramerror(0);	/* Don't exit on error */
	paramerract((vector) perl_paramerr);

CIAO_Lib_ParamPtr
open(filename, mode, ...)
	char *	filename
	const char *	mode
  PREINIT:
	int argc = 0;
  	char **argv = NULL;
  CODE:
        argc = items - 2;
	if ( argc )
	{
	  int i;
	  argv = get_mortalspace( argc * sizeof(*argv) );
	  for ( i = 2 ; i < items ; i++ )
	  {
	    argv[i-2] = SvOK(ST(i)) ? (char*)SvPV_nolen(ST(i)) : (char*)NULL;
	  }
	}
	RETVAL = paramopen(filename, argv, argc, mode);
	if ( NULL == RETVAL )
	  set_parerr();	
  OUTPUT:
  	RETVAL

char *
pfind(name, mode, extn, path)
	char *	name
	char *	mode
	char *	extn
	char *	path
  CODE:
	RETVAL = paramfind( name, mode, extn, path );
  	set_parerr();	
  OUTPUT:
	RETVAL

MODULE = CIAO::Lib::Param	PACKAGE = CIAO::Lib::ParamPtr

void
DESTROY(pfile)
	CIAO_Lib_ParamPtr	pfile
  CODE:
	paramclose(pfile);
  	set_parerr();	
 	
void
info( pfile, name )
	CIAO_Lib_ParamPtr	pfile
	char * name
  PREINIT:
	char *	mode = get_mortalspace( SZ_PFLINE );
	char *	type = get_mortalspace( SZ_PFLINE );
	char *	value = get_mortalspace( SZ_PFLINE );
	char *	min = get_mortalspace( SZ_PFLINE );
	char *	max = get_mortalspace( SZ_PFLINE );
	char *	prompt = get_mortalspace( SZ_PFLINE );
	int result;
  PPCODE:
	if ( ParamInfo( pfile, name, mode, type, 
			    value, min, max, prompt ) )
	{
	  EXTEND(SP, 6);
	  PUSHs(sv_2mortal(newSVpv(mode, 0)));
	  PUSHs(sv_2mortal(newSVpv(type, 0)));
	  PUSHs(sv_2mortal(newSVpv(value, 0)));
	  PUSHs(sv_2mortal(newSVpv(min, 0)));
	  PUSHs(sv_2mortal(newSVpv(max, 0)));
	  PUSHs(sv_2mortal(newSVpv(prompt, 0)));
	}
	else
	{
	  croak( "parameter %s doesn't exist", name );
	}
  	set_parerr();	


CIAO_Lib_Param_MatchPtr
match(pfile, ptemplate)
	CIAO_Lib_ParamPtr	pfile
	char *	ptemplate
  CODE:
	RETVAL = pmatchopen( pfile, ptemplate );
  	set_parerr();	
  OUTPUT:
  	RETVAL



MODULE = CIAO::Lib::Param	PACKAGE = CIAO::Lib::ParamPtr	PREFIX = param


char *
paramgetpath(pfile)
	CIAO_Lib_ParamPtr	pfile
  CLEANUP:
	if (RETVAL) Safefree(RETVAL);
	set_parerr();


MODULE = CIAO::Lib::Param PACKAGE = CIAO::Lib::ParamPtr	PREFIX = p

int
paccess(pfile, pname)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  CLEANUP:
  	set_parerr();	

SV*
pgetb(pfile, pname)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  CODE:
  	ST(0) = sv_newmortal();
	sv_setsv( ST(0), pgetb( pfile, pname ) ? &PL_sv_yes : &PL_sv_no );
  	set_parerr();	

short
pgets(pfile, pname)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  CLEANUP:
  	set_parerr();	

int
pgeti(pfile, pname)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  CLEANUP:
  	set_parerr();	

float
pgetf(pfile, pname)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  CLEANUP:
  	set_parerr();	

double
pgetd(pfile, pname)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  CLEANUP:
  	set_parerr();	

SV*
get(pfile, pname)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  PREINIT:
	char type[SZ_PFLINE];
  CODE:
  	ST(0) = sv_newmortal();
	if ( ParamInfo( pfile, pname, NULL, type, NULL, NULL, NULL, NULL ))
	{
	  if ( 0 == strcmp( "b", type ) )
	  {
	    sv_setsv( ST(0), 
		      pgetb( pfile, pname ) ? &PL_sv_yes : &PL_sv_no );
	  }
	  else
	  {
	    char* str = get_mortalspace( SZ_PFLINE );
	    pgetstr( pfile, pname, str, SZ_PFLINE );
	    sv_setpv(ST(0), str );
	  }
	}
	else
	  XSRETURN_UNDEF;
  CLEANUP:
  	set_parerr();	


char *
pgetstr(pfile, pname )
	CIAO_Lib_ParamPtr	pfile
	char *	pname
  PREINIT:
	char* str = get_mortalspace( SZ_PFLINE );
  CODE:
	RETVAL = NULL;
	if ( pgetstr( pfile, pname, str, SZ_PFLINE ) )
	  RETVAL = str;
  	set_parerr();	
  OUTPUT:
	RETVAL

void
pputb(pfile, pname, bvalue)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
	int	bvalue
  ALIAS:
	setb = 1	
  CLEANUP:
  	set_parerr();	
	

void
pputd(pfile, pname, dvalue)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
	double	dvalue
  ALIAS:
	setd = 1	
  CLEANUP:
  	set_parerr();	

void
pputi(pfile, pname, ivalue)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
	int	ivalue
  ALIAS:
	seti = 1	
  CLEANUP:
  	set_parerr();	

void
pputs(pfile, pname, svalue)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
	short	svalue
  ALIAS:
	sets = 1	
  CLEANUP:
  	set_parerr();	

void
pputstr(pfile, pname, string)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
	char *	string
  ALIAS:
	set = 1
	put = 2
  CLEANUP:
  	set_parerr();	

char *
evaluateIndir(pf, name, val)
	CIAO_Lib_ParamPtr	pf
	char *	name
	char *	val
  CLEANUP:
  	if ( RETVAL ) Safefree( RETVAL );
  	set_parerr();	


