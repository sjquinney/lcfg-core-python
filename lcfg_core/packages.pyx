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

cdef class LCFGPackage:
    fields = [ 'name', 'arch',\
               'version', 'release',\
               'flags', 'context', 'derivation',\
               'category', 'prefix', 'priority' ]

    cdef:
        c_pkgs.LCFGPackageStruct* _pkg
        char * __str_buf
        size_t __buf_size

    def __init__( self, spec=None, style=None, **kwargs ):
        for attr in self.fields:
            if attr in kwargs: setattr( self, attr, kwargs[attr] )

    def __cinit__( self, full_init=True, **kwargs ):

        # For speed a buffer is maintained which can be reused for
        # various stringification tasks.

        self.__str_buf  = NULL
        self.__buf_size = 0

        self._pkg == NULL

        if not full_init: return

        self._pkg = c_pkgs.lcfgpackage_new()
        if self._pkg == NULL:
            raise RuntimeError("Failed to create new package")

        return

    @staticmethod
    cdef init_with_struct( c_pkgs.LCFGPackageStruct *pkg ):

        cdef LCFGPackage new_obj = LCFGPackage(full_init=False)
        new_obj._pkg = pkg

        return new_obj

    def update( self, **kwargs ):
        for attr in self.fields:
            if attr in kwargs: setattr( self, attr, kwargs[attr] )

    # name

    @property
    def name(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_name():
            as_c = c_pkgs.lcfgpackage_get_name(self._pkg)
            if as_c != NULL: result = as_c

        return result

    @name.setter
    def name(self, str value):
        if is_empty(value):
            raise ValueError("Invalid name: empty string")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_name(as_c):
            raise ValueError(f"Invalid name '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_pkgs.lcfgpackage_set_name( self._pkg, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Invalid name '{value}'")

    cpdef bint has_name(self):
        return c_pkgs.lcfgpackage_has_name( self._pkg )

    # architecture

    @property
    def arch(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_arch():
            as_c = c_pkgs.lcfgpackage_get_arch(self._pkg)
            if as_c != NULL: result = as_c

        return result

    @arch.setter
    def arch(self, str value):
        if is_empty(value):
            raise ValueError("Invalid architecture: empty string")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_arch(as_c):
            raise ValueError(f"Invalid architecture '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_pkgs.lcfgpackage_set_arch( self._pkg, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Invalid architecture '{value}'")

    cpdef bint has_arch(self):
        return c_pkgs.lcfgpackage_has_arch( self._pkg )

    # version

    @property
    def version(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_version():
            as_c = c_pkgs.lcfgpackage_get_version(self._pkg)
            if as_c != NULL: result = as_c

        return result

    @version.setter
    def version(self, value):

        # In case we get passed an integer
        value = str(value)

        if is_empty(value):
            raise ValueError("Invalid version: empty string")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_version(as_c):
            raise ValueError(f"Invalid version '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_pkgs.lcfgpackage_set_version( self._pkg, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Invalid version '{value}'")

    cpdef bint has_version(self):
        return c_pkgs.lcfgpackage_has_version( self._pkg )

    cpdef int epoch(self):
        cdef int result = c_pkgs.lcfgpackage_get_epoch( self._pkg )
        return result

    # release

    @property
    def release(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_release():
            as_c = c_pkgs.lcfgpackage_get_release(self._pkg)
            if as_c != NULL: result = as_c

        return result

    @release.setter
    def release(self, value):

        # In case we get passed an integer
        value = str(value)

        if is_empty(value):
            raise ValueError("Invalid release: empty string")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_release(as_c):
            raise ValueError(f"Invalid release '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_pkgs.lcfgpackage_set_release( self._pkg, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Invalid release '{value}'")

    cpdef bint has_release(self):
        return c_pkgs.lcfgpackage_has_release( self._pkg )

    # flags

    @property
    def flags(self):
        cdef str result = None

        cdef const char * as_c
        if self.has_flags():
            as_c   = c_pkgs.lcfgpackage_get_flags(self._pkg)
            if as_c != NULL:
                result = as_c

        return result

    @flags.setter
    def flags(self, str value):

        if is_empty(value):
            self.clear_flags()
            return

        as_bytes = value.encode('UTF-8')

        cdef:
            object bad_flag
            char flag

        for flag in as_bytes:
            if not c_pkgs.lcfgpackage_valid_flag_chr(flag):
                bad_flag = (<bytes>flag).decode('UTF-8')
                raise ValueError(f"Invalid flag '{bad_flag}'")

        cdef char * as_c = as_bytes
        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_pkgs.lcfgpackage_set_flags( self._pkg, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Invalid flags '{value}'")

    @flags.deleter
    def flags(self):
        self.clear_flags()
        return

    cpdef bint has_flag(self, str flag):

        if len(flag) != 1:
            raise ValueError("Package flags are single characters")

        as_bytes = flag[0].encode('UTF-8')
        cdef char as_c = as_bytes[0]

        return c_pkgs.lcfgpackage_has_flag( self._pkg, as_c )

    cpdef bint has_flags(self):
        return c_pkgs.lcfgpackage_has_flags( self._pkg )

    cpdef clear_flags(self):
        cdef bint ok = c_pkgs.lcfgpackage_clear_flags( self._pkg )
        if not ok:
            raise RuntimeError("Failed to clear package flags")
        return

    cpdef add_flags(self,str value):

        cdef char * as_c = value

        cdef bint result = c_pkgs.lcfgpackage_add_flags( self._pkg, as_c )
        if not result:
            raise ValueError("Failed to add package flags '{value}'")

        return

    # context

    @property
    def context(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_context():
            as_c   = c_pkgs.lcfgpackage_get_context(self._pkg)
            if as_c != NULL: result = as_c

        return result

    @context.setter
    def context(self, str value):
        if is_empty(value):
            raise ValueError("Invalid context: empty string")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_context(as_c):
            raise ValueError(f"Invalid context '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_pkgs.lcfgpackage_set_context( self._pkg, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Invalid context '{value}'")

    cpdef bint has_context(self):
        return c_pkgs.lcfgpackage_has_context( self._pkg )

    cpdef add_context(self,str value):

        cdef char * as_c = value

        cdef bint result = c_pkgs.lcfgpackage_add_context( self._pkg, as_c )
        if not result:
            raise ValueError("Failed to add package context '{value}'")

        return

    # derivation

    @property
    def derivation(self):

        cdef:
            str result = None
            char * as_c = NULL
            size_t buf_size = 0
            Py_ssize_t len

        if self.has_derivation():
            len = c_pkgs.lcfgpackage_get_derivation_as_string(self._pkg, LCFGOption.NONE.value, &as_c, &buf_size )
            result = as_c[:len].decode('UTF-8')

        return result

    @derivation.setter
    def derivation(self, str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef char * as_c = value

        cdef bint ok = c_pkgs.lcfgpackage_set_derivation_as_string( self._pkg, as_c )

        if not ok:
            raise ValueError(f"Invalid derivation '{value}'")

    cpdef bint has_derivation(self):
        return c_pkgs.lcfgpackage_has_derivation( self._pkg )

    cpdef add_derivation(self,str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef char * as_c = value

        cdef bint ok = c_pkgs.lcfgpackage_add_derivation_string( self._pkg, as_c )
        if not ok:
            raise ValueError("Failed to add package derivation '{value}'")

        return

    cpdef add_derivation_file_line(self, str filename, int linenum):

        cdef char * as_c = filename

        cdef bint ok = c_pkgs.lcfgpackage_add_derivation_file_line( self._pkg, as_c, linenum )
        if not ok:
            raise ValueError("Failed to add package derivation '{file}:{linenum}'")

        return

    # category

    @property
    def category(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_category():
            as_c   = c_pkgs.lcfgpackage_get_category(self._pkg)
            if as_c != NULL: result = as_c

        return result

    @category.setter
    def category(self, str value):
        if is_empty(value):
            raise ValueError("Invalid category: empty string")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_category(as_c):
            raise ValueError(f"Invalid category '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_pkgs.lcfgpackage_set_category( self._pkg, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            c_copy = NULL
            raise ValueError(f"Invalid category '{value}'")

    cpdef bint has_category(self):
        return c_pkgs.lcfgpackage_has_category( self._pkg )

    # prefix

    @property
    def prefix(self):
        cdef:
            str result = None
            char as_c

        if self.has_prefix():
            as_c = c_pkgs.lcfgpackage_get_prefix(self._pkg)
            if as_c != LCFGPkgPrefix.NONE:
                result = (<bytes>as_c).decode('UTF-8')

        return result

    @prefix.setter
    def prefix(self, str value):

        if is_empty(value) or value == LCFGPkgPrefix.NONE:
            self.clear_prefix()
            return

        if len(value) != 1:
            raise ValueError(f"Invalid prefix '{value}': must be a single character")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_prefix(as_c[0]):
            raise ValueError(f"Invalid prefix '{value}'")

        cdef bint ok = c_pkgs.lcfgpackage_set_prefix( self._pkg, as_c[0] )

        if not ok:
            raise ValueError(f"Invalid prefix '{value}'")

    @prefix.deleter
    def prefix(self):
        self.clear_prefix()
        return

    cpdef bint has_prefix(self):
        return c_pkgs.lcfgpackage_has_prefix( self._pkg )

    cpdef clear_prefix(self):
        cdef bint ok = c_pkgs.lcfgpackage_clear_prefix( self._pkg )
        if not ok:
            raise RuntimeError("Failed to clear package prefix")
        return

    @property
    def priority(self):
        return c_pkgs.lcfgpackage_get_priority(self._pkg)

    @priority.setter
    def priority(self, int value):
        cdef bint ok = c_pkgs.lcfgpackage_set_priority(self._pkg, value)
        if not ok:
            raise ValueError(f"Invalid priority: '{value}'")
        return

    cpdef bint is_active(self):
        return c_pkgs.lcfgpackage_is_active(self._pkg)

    cpdef bint is_valid(self):
        return c_pkgs.lcfgpackage_is_valid(self._pkg)

    def __dealloc__(self):
        c_pkgs.lcfgpackage_relinquish(self._pkg)
        PyMem_Free(self.__str_buf)

