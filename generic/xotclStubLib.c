/*
 * xotclStubLib.c --
 *
 *      Stub object that will be statically linked into extensions of XOTcl
 *
 * Copyright (c) 2001-2008 Gustaf Neumann, Uwe Zdun
 * Copyright (c) 1998 Paul Duffin.
 *
 * See the file "tcl-license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 */

/*
 * We need to ensure that we use the stub macros so that this file contains
 * no references to any of the stub functions.  This will make it possible
 * to build an extension that references Tcl_InitStubs but doesn't end up
 * including the rest of the stub functions.
 */

#ifndef USE_TCL_STUBS
# define USE_TCL_STUBS
#endif
#undef USE_TCL_STUB_PROCS

/*
 * This ensures that the Xotcl_InitStubs has a prototype in
 * xotcl.h and is not the macro that turns it into Tcl_PkgRequire
 */

#ifndef USE_XOTCL_STUBS
# define USE_XOTCL_STUBS
#endif

#include "xotclInt.h"

#if defined(PRE86)
extern XotclStubs *xotclStubsPtr;
#else
MODULE_SCOPE const XotclStubs *xotclStubsPtr;
MODULE_SCOPE const XotclIntStubs *xotclIntStubsPtr;
#endif
CONST86 XotclStubs *xotclStubsPtr = NULL;
CONST86 XotclIntStubs *xotclIntStubsPtr = NULL;


/*
 *----------------------------------------------------------------------
 *
 * Xotcl_InitStubs --
 *
 *      Tries to initialise the stub table pointers and ensures that
 *      the correct version of XOTcl is loaded.
 *
 * Results:
 *      The actual version of XOTcl that satisfies the request, or
 *      NULL to indicate that an error occurred.
 *
 * Side effects:
 *      Sets the stub table pointers.
 *
 *----------------------------------------------------------------------
 */

CONST char *
Xotcl_InitStubs (Tcl_Interp *interp, CONST char *version, int exact) {
    CONST char *actualVersion;
    const char *packageName = "XOTcl";
    ClientData clientData = NULL;

    actualVersion = Tcl_PkgRequireEx(interp, "XOTcl", version, exact,
        &clientData);

    if (clientData == NULL) {
      Tcl_ResetResult(interp);
      Tcl_AppendResult(interp, "Error loading ", packageName, " package; ",
                         "package not present or incomplete", NULL);
        return NULL;
    } else {
      CONST86 XotclStubs * const stubsPtr = clientData;
      CONST86 XotclIntStubs * const intStubsPtr = stubsPtr->hooks ?
        stubsPtr->hooks->xotclIntStubs : NULL;

      if (actualVersion == NULL) {
        return NULL;
      }

      if (!stubsPtr || !intStubsPtr) {
        static char *errMsg = "missing stub table pointer";
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "Error loading ", packageName, " package",
                         " (requested version '", version, "', loaded version '",
                         actualVersion, "'): ", errMsg, NULL);
        return NULL;
      }

      xotclStubsPtr = stubsPtr;
      xotclIntStubsPtr = intStubsPtr;

      return actualVersion;
    }
}
