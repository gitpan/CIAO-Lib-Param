#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* Global Data */

#define MY_CXT_KEY "CIAO::Lib::Param::_guts" XS_VERSION

typedef struct {
  int parerr;
  char* errmsg;
} my_cxt_t;

START_MY_CXT



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


static SV*
carp_shortmess( char* message )
{
  SV* sv_message = newSVpv( message, 0 );
  SV* short_message;
  int count;

  dSP;
  ENTER ;
  SAVETMPS ;
    
  PUSHMARK(SP);
  XPUSHs( sv_message );
  PUTBACK;

  /* make sure there's something to work with */
  count = call_pv( "Carp::shortmess", G_SCALAR );
    
  SPAGAIN ;

  if ( 1 != count )
    croak( "internal error passing message to Carp::shortmess" );

  short_message = newSVsv( POPs );

  PUTBACK ;
  FREETMPS ;
  LEAVE ;

  return short_message;
}


/* propagate the cxcparam error value up to Perl.
   this is used to cause a croak at the Perl level (see Param.pm for
*/
static void
set_parerr( void )
{
  dMY_CXT;

  SV *sv;

  /* use parerr if specified; else use MY_CXT.parerr.  The latter is
     available if c_paramerr was called. some cxcparam routines
     don't call c_paramerr
  */

  if ( parerr )
    MY_CXT.parerr = parerr;

  if ( MY_CXT.parerr )
  {
    SV* sv_error;
    HV* hash = newHV();
    char *errstr = paramerrstr();
    char *error = MY_CXT.errmsg ? MY_CXT.errmsg : errstr;


    /* construct exception object prior to throwing exception */

    hv_store( hash, "errno" , 5, newSViv(MY_CXT.parerr), 0 );
    hv_store( hash, "error" , 5, carp_shortmess(error), 0 );
    hv_store( hash, "errstr", 6, newSVpv(errstr, 0), 0 );
    hv_store( hash, "errmsg", 6, MY_CXT.errmsg ? newSVpv(MY_CXT.errmsg, 0) : &PL_sv_undef, 0 );

    /* reset internal parameter error */
    parerr = MY_CXT.parerr = 0;
    Safefree( MY_CXT.errmsg );
    MY_CXT.errmsg = NULL;
    
    /* setup exception object and throw it*/
    {
      SV* errsv = get_sv("@", TRUE);
      sv_setsv( errsv, sv_bless( newRV_noinc((SV*) hash),
				 gv_stashpv("CIAO::Lib::Param::Error", 1 ) ) );
    }
    croak( Nullch );

  }
  

}

/* The replacement error message handling routine for cxcparam.
   This is put in place in the BOOT: section
   Note that both paramerrstr() and c_paramerr reset parerr,
   so we need to keep a local copy.  ugh.
*/
static void
perl_paramerr( int level, char *message, char *name )
{
  dMY_CXT;
  SV* sv;
  char *errstr;

  /* save parerr before call to paramerrstr(), as that will
     reset it */
  MY_CXT.parerr = parerr;
  errstr = paramerrstr();

  int len = strlen(errstr) + strlen(message) + strlen(name) + 5;

  if ( MY_CXT.errmsg )
    Renew( MY_CXT.errmsg, len, char );
  else
    New( 0, MY_CXT.errmsg, len, char );

  sprintf( MY_CXT.errmsg, "%s: %s: %s", message, paramerrstr(), name );
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
{
  	MY_CXT_INIT;
	MY_CXT.parerr = 0;
	MY_CXT.errmsg = NULL;
	set_paramerror(0);	/* Don't exit on error */
	paramerract((vector) perl_paramerr);
}

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
	setstr = 1
  CLEANUP:
  	set_parerr();	

void
put(pfile, pname, value)
	CIAO_Lib_ParamPtr	pfile
	char *	pname
	SV*	value
  ALIAS:
	set = 1
  PREINIT:
	char type[SZ_PFLINE];
  CODE:
        /* if the parameter exists and is a boolean,
	   translate from numerics to string if it looks like a
	   number, else let pset handle it
	*/
	if ( ParamInfo( pfile, pname, NULL, type, NULL, NULL, NULL, NULL ) &&
	     0 == strcmp( "b", type ) && 
	     ( value == &PL_sv_undef || looks_like_number( value ) )
	     )
	{
	  pputb(pfile, pname, SvOK(value) ? SvIV(value) : 0);
	}
	else
	{
	  pputstr(pfile, pname, SvOK(value) ? (char*)SvPV_nolen(value) : (char*)NULL );
	}
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


