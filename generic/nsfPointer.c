/* 
 *  
 *  Next Scripting Framework
 *
 *  Copyright (C) 1999-2010 Gustaf Neumann, Uwe Zdun
 *
 *
 *  nsfPointer.c --
 *  
 *  C-level converter to opaque structures
 *  
 */

#include "nsfInt.h"

static Tcl_HashTable pointerHashTable, *pointerHashTablePtr = &pointerHashTable;
static NsfMutex pointerMutex = 0;

/*
 *----------------------------------------------------------------------
 *
 * Nsf_PointerAdd --
 *
 *      Add an entry to our locally maintained hash table and set its
 *      value to the provided valuePtr. The keys are generated based on
 *      the passed type and the counter obtained from the type
 *      registration.
 *
 * Results:
 *      Tcl result code
 *
 * Side effects:
 *      None.
 *
 *----------------------------------------------------------------------
 */
int
Nsf_PointerAdd(Tcl_Interp *interp, char *buffer, CONST char *typeName, void *valuePtr) {
  Tcl_HashEntry *hPtr;
  int isNew, *counterPtr;
  Tcl_DString ds, *dsPtr = &ds;

  counterPtr = Nsf_PointerTypeLookup(interp, typeName);
  if (counterPtr) {
    Tcl_DStringInit(dsPtr);
    Tcl_DStringAppend(dsPtr, typeName, -1);
    Tcl_DStringAppend(dsPtr, ":%d", 3);
    NsfMutexLock(&pointerMutex);
    sprintf(buffer, Tcl_DStringValue(dsPtr), (*counterPtr)++);
    hPtr = Tcl_CreateHashEntry(pointerHashTablePtr, buffer, &isNew);
    NsfMutexUnlock(&pointerMutex);
    Tcl_SetHashValue(hPtr, valuePtr);
    Tcl_DStringFree(dsPtr);
  } else {
    return NsfPrintError(interp, "no type converter for %s registered", typeName);
  }
  return TCL_OK;
}


/*
 *----------------------------------------------------------------------
 *
 * Nsf_PointerGet --
 *
 *      Get an entry to our locally maintained hash table and make sure
 *      that the prefix matches (this ensures that the right type of
 *      entry is obtained). If the prefix does not match, or there is no
 *      such entry in the table, the function returns NULL.
 *
 * Results:
 *      valuePtr or NULL.
 *
 * Side effects:
 *      None.
 *
 *----------------------------------------------------------------------
 */
static void *
Nsf_PointerGet(char *key, CONST char *prefix) {
  Tcl_HashEntry *hPtr;
  void *valuePtr = NULL;

  /* make sure to return the right type of hash entry */
  if (strncmp(prefix, key, strlen(prefix)) == 0) {

    NsfMutexLock(&pointerMutex);
    hPtr = Tcl_CreateHashEntry(pointerHashTablePtr, key, NULL);
    
    if (hPtr) {
      valuePtr = Tcl_GetHashValue(hPtr);
    }
    NsfMutexUnlock(&pointerMutex);
  }
  return valuePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Nsf_PointerGetHptr --
 *
 *      Find for a pointer the associated key. The current (static)
 *      implementaiton is quite slow in case there are a high number of
 *      pointer values registered (which should not be the case for the
 *      current usage patterns).  It could certainly be improved by a
 *      second hash table. The function should be run under a callers
 *      mutex.
 *
 * Results:
 *      key or NULL.
 *
 * Side effects:
 *      None.
 *
 *----------------------------------------------------------------------
 */
static char *
Nsf_PointerGetHptr(void *valuePtr) {
  Tcl_HashEntry *hPtr;
  Tcl_HashSearch hSrch;
  
  for (hPtr = Tcl_FirstHashEntry(pointerHashTablePtr, &hSrch); hPtr;
       hPtr = Tcl_NextHashEntry(&hSrch)) {
    void *ptr = Tcl_GetHashValue(hPtr);
    if (ptr == valuePtr) {
      return hPtr;
    }
  }
  return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * Nsf_PointerDelete --
 *
 *      Delete an hash entry from our locally maintained hash table
 *      free the associated memory, if valuePtr is provided.
 *
 * Results:
 *      valuePtr or NULL.
 *
 * Side effects:
 *      None.
 *
 *----------------------------------------------------------------------
 */
int
Nsf_PointerDelete(void *valuePtr) {
  Tcl_HashEntry *hPtr;
  int result;

  NsfMutexLock(&pointerMutex);

  hPtr = Nsf_PointerGetHptr(valuePtr);
  if (hPtr) {
    ckfree((char *)valuePtr);
    Tcl_DeleteHashEntry(hPtr);
    result = TCL_OK;
  } else {
    result = TCL_ERROR;
  }

  NsfMutexUnlock(&pointerMutex);
  return result;
}


/*
 *----------------------------------------------------------------------
 * Nsf_ConvertToPointer --
 *
 *    Nsf_TypeConverter setting the client data (passed to C functions)
 *    to the valuePtr of the opaque structure. This nsf type converter
 *    checks the passed value via the internally maintained pointer hash
 *    table.
 *
 * Results:
 *    Tcl result code, *clientData and **outObjPtr
 *
 * Side effects:
 *    None.
 *
 *----------------------------------------------------------------------
 */

int
Nsf_ConvertToPointer(Tcl_Interp *interp, Tcl_Obj *objPtr,  Nsf_Param CONST *pPtr,
		     ClientData *clientData, Tcl_Obj **outObjPtr) {
  void *valuePtr;

  *outObjPtr = objPtr;
  valuePtr = Nsf_PointerGet(ObjStr(objPtr), pPtr->type);
  if (valuePtr) {
    *clientData = valuePtr;
    return TCL_OK;
  }
  return NsfObjErrType(interp, NULL, objPtr, pPtr->type, (Nsf_Param *)pPtr);
}

/*
 *----------------------------------------------------------------------
 * Nsf_PointerTypeRegister --
 *
 *    Register a pointer type which is identified by the type string
 *
 * Results:
 *    Tcl result code.
 *
 * Side effects:
 *    None.
 *
 *----------------------------------------------------------------------
 */

int
Nsf_PointerTypeRegister(Tcl_Interp *interp, CONST char* typeName, int *counterPtr) {
  Tcl_HashEntry *hPtr;
  int isNew;

  NsfMutexLock(&pointerMutex);
  hPtr = Tcl_CreateHashEntry(pointerHashTablePtr, typeName, &isNew);
  NsfMutexUnlock(&pointerMutex);
  
  if (isNew) {
    Tcl_SetHashValue(hPtr, counterPtr);
    return TCL_OK;
  } else {
    return NsfPrintError(interp, "type converter %s is already registered", typeName);
  }
}

/*
 *----------------------------------------------------------------------
 * Nsf_PointerTypeLookup --
 *
 *    Lookup of type name. If the type name is registed, return the
 *    converter or NULL otherwise.
 *
 * Results:
 *    TypeConverter on success or NULL
 *
 * Side effects:
 *    None.
 *
 *----------------------------------------------------------------------
 */

void *
Nsf_PointerTypeLookup(Tcl_Interp *interp, CONST char* typeName) {
  Tcl_HashEntry *hPtr;
  int isNew;

  NsfMutexLock(&pointerMutex);
  hPtr = Tcl_CreateHashEntry(pointerHashTablePtr, typeName, &isNew);
  NsfMutexUnlock(&pointerMutex);
  
  if (hPtr) {
    return Tcl_GetHashValue(hPtr);
  }
  return NULL;
}

/*
 *----------------------------------------------------------------------
 * Nsf_PointerInit --
 *
 *    Initialize the Pointer converter
 *
 * Results:
 *    void
 *
 * Side effects:
 *    None.
 *
 *----------------------------------------------------------------------
 */

void
Nsf_PointerInit(Tcl_Interp *interp) {

    NsfMutexLock(&pointerMutex);
    Tcl_InitHashTable(pointerHashTablePtr, TCL_STRING_KEYS);
    NsfMutexUnlock(&pointerMutex);

}

/*
 *----------------------------------------------------------------------
 * Nsf_PointerExit --
 *
 *    Exit handler fr the Pointer converter
 *
 * Results:
 *    void
 *
 * Side effects:
 *    None.
 *
 *----------------------------------------------------------------------
 */

void
Nsf_PointerExit(Tcl_Interp *interp) {
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch hSrch;

    NsfMutexLock(&pointerMutex);
    for (hPtr = Tcl_FirstHashEntry(pointerHashTablePtr, &hSrch); hPtr;
         hPtr = Tcl_NextHashEntry(&hSrch)) {
      char *key = Tcl_GetHashKey(pointerHashTablePtr, hPtr);
      void *valuePtr = Tcl_GetHashValue(hPtr);
     
      fprintf(stderr, "Nsf_PointerExit: we have still an entry %s with value %p\n", key, valuePtr);
    }
    Tcl_DeleteHashTable(pointerHashTablePtr);
    NsfMutexUnlock(&pointerMutex);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 2
 * fill-column: 72
 * End:
 */
