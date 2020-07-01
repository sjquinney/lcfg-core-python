#!/usr/bin/python3

import collections.abc
from datetime import datetime
import sys

cimport lcfg_core.c_packages as c_pkgs

from libc.time   cimport time_t
from libc.stdio  cimport fdopen, FILE, fflush
from libc.string cimport strdup

from .common import LCFGStatus, LCFGChange, LCFGOption, LCFGMergeRule

from cpython.mem cimport PyMem_Free
from cpython.object cimport PyObject_AsFileDescriptor

from enum import Enum, IntFlag
class LCFGPkgStyle(IntFlag):
    SPEC = 0
    RPM  = 1
    CPP  = 2
    XML  = 3
    SUMMARY = 4
    EVAL = 5
    DEB  = 6

class LCFGPkgPrefix:
    NONE   = '\0'
    ADD    = '+'
    REMOVE = '-'
    UPDATE = '?'
    PIN    = '!'
    ANY    = '~'
    MIN    = '>' 

class LCFGPkgListPK(IntFlag):
    NAME = 1
    ARCH = 2
    CTX  = 4

class LCFGPkgSourceType(Enum):
    RPMLIST = 1
    RPMDIR  = 2
    RPMCFG  = 3
    DEBIDX  = 4

cpdef bint is_empty(object value):
    return value is None or value == ''

cpdef str default_architecture():
    cdef:
        str result
        const char * as_c = c_pkgs.default_architecture()

    result = as_c

    return result

cpdef int compare_vstrings(v1, v2):

    cdef:
        const char * v1_as_c = v1
        const char * v2_as_c = v2

    return c_pkgs.compare_vstrings(v1_as_c,v2_as_c)

