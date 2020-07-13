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

class LCFGPkgPrefix(Enum):
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
        self.update(**kwargs)

    def __cinit__( self, spec=None, style=None, full_init=True, **kwargs ):

        # For speed a buffer is maintained which can be reused for
        # various stringification tasks.

        self.__str_buf  = NULL
        self.__buf_size = 0

        self._pkg == NULL

        if not full_init: return

        # Create a new empty package
        if spec is None:
            self._pkg = c_pkgs.lcfgpackage_new()
            if self._pkg == NULL:
                raise RuntimeError("Failed to create new package")
            return

        # Otherwise - Parse an input string

        if style is None:
            if spec.endswith('.rpm'):
                style = LCFGPkgStyle.RPM
            elif spec.endswith('.deb'):
                style = LCFGPkgStyle.DEB
            else:
                style = LCFGPkgStyle.SPEC

        cdef:
            str err_msg = 'unknown error'
            char * msg = NULL
            c_pkgs.LCFGStatus status = LCFGStatus.ERROR.value
            char * spec_as_c = spec

        try:

            if style == LCFGPkgStyle.SPEC:
                status = c_pkgs.lcfgpackage_from_spec( spec_as_c, &self._pkg, &msg )
            elif style == LCFGPkgStyle.RPM:
                status = c_pkgs.lcfgpackage_from_rpm_filename( spec_as_c, &self._pkg, &msg )
            else:
                raise RuntimeError(f"No support for {style} parsing")

            if status == LCFGStatus.ERROR.value or self._pkg == NULL:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to parse specification: {err_msg}")

        finally:
            PyMem_Free(msg)

        return

    @staticmethod
    def from_rpm_filename( spec ):
        return LCFGPackage( spec=spec, style=LCFGPkgStyle.RPM )

    @staticmethod
    def from_spec( spec ):
        return LCFGPackage( spec=spec, style=LCFGPkgStyle.SPEC )

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
            raise ValueError(f"Failed to set name to '{value}'")

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
            raise ValueError(f"Failed to set architecture to '{value}'")

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

        if value is None:
            raise ValueError("Invalid version: empty string")

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
            raise ValueError(f"Failed to set version to '{value}'")

    cpdef bint has_version(self):
        return c_pkgs.lcfgpackage_has_version( self._pkg )

    @property
    def epoch(self):
        cdef int result = c_pkgs.lcfgpackage_get_epoch( self._pkg )
        return result

    def has_epoch(self):
        return self.has_version() and ':' in self.version

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

        if value is None:
            raise ValueError("Invalid release: empty string")

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
            raise ValueError(f"Failed to set release to '{value}'")

    cpdef bint has_release(self):
        return c_pkgs.lcfgpackage_has_release( self._pkg )

    @property
    def full_version(self):
        cdef:
            str result = None
            char * as_c

        try:
            as_c = c_pkgs.lcfgpackage_full_version(self._pkg)
            if as_c != NULL:
                result = as_c
            else:
                raise RuntimeError("Failed to get full version");
        finally:
            PyMem_Free(as_c)

        return result

    @property
    def vra(self):

        cdef str vra = self.full_version
        if self.has_arch():
            vra = '/'.join( (vra, self.arch) )

        return vra;

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
            del(self.flags)
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
            raise ValueError(f"Failed to set flags to '{value}'")

    @flags.deleter
    def flags(self):
        self.clear_flags()
        return

    cpdef has_flag(self, str flag):

        if is_empty(flag) or len(flag) != 1:
            raise ValueError(f"Flags are single characters")

        as_bytes = flag[0].encode('UTF-8')
        cdef char as_c = as_bytes[0]

        return c_pkgs.lcfgpackage_has_flag( self._pkg, as_c )

    cpdef bint has_flags(self):
        return c_pkgs.lcfgpackage_has_flags( self._pkg )

    cpdef clear_flags(self):
        cdef bint ok = c_pkgs.lcfgpackage_clear_flags( self._pkg )
        if not ok:
            raise RuntimeError("Failed to clear flags")
        return

    cpdef add_flags(self,str value):

        if is_empty(value):
            return

        cdef:
            object bad_flag
            char flag
            bytes as_bytes = value.encode('UTF-8')

        for flag in as_bytes:
            if not c_pkgs.lcfgpackage_valid_flag_chr(flag):
                bad_flag = (<bytes>flag).decode('UTF-8')
                raise ValueError(f"Invalid flag '{bad_flag}'")

        cdef char * as_c = as_bytes

        cdef bint result = c_pkgs.lcfgpackage_add_flags( self._pkg, as_c )
        if not result:
            raise ValueError(f"Failed to add flags '{value}'")

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
            raise ValueError(f"Failed to set context to '{value}'")

    cpdef bint has_context(self):
        return c_pkgs.lcfgpackage_has_context( self._pkg )

    cpdef add_context(self,str value):

        if is_empty(value):
            raise ValueError("Invalid context: empty string")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_context(as_c):
            raise ValueError(f"Invalid context '{value}'")

        cdef bint result = c_pkgs.lcfgpackage_add_context( self._pkg, as_c )
        if not result:
            raise ValueError("Failed to add context '{value}'")

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
            result = (<bytes> as_c[:len]).decode('UTF-8')

        return result

    @derivation.setter
    def derivation(self, str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef char * as_c = value

        cdef bint ok = c_pkgs.lcfgpackage_set_derivation_as_string( self._pkg, as_c )

        if not ok:
            raise ValueError(f"Failed to set derivation to '{value}'")

    cpdef bint has_derivation(self):
        return c_pkgs.lcfgpackage_has_derivation( self._pkg )

    cpdef add_derivation(self,str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef char * as_c = value

        cdef bint ok = c_pkgs.lcfgpackage_add_derivation_string( self._pkg, as_c )
        if not ok:
            raise ValueError("Failed to add derivation '{value}'")

        return

    cpdef add_derivation_file_line(self, str filename, int linenum):

        cdef char * as_c = filename

        cdef bint ok = c_pkgs.lcfgpackage_add_derivation_file_line( self._pkg, as_c, linenum )
        if not ok:
            raise ValueError("Failed to add derivation '{file}:{linenum}'")

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
            raise ValueError(f"Failed to set category to '{value}'")

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
            if as_c != LCFGPkgPrefix.NONE.value[0]:
                result = (<bytes>as_c).decode('UTF-8')

        return result

    @prefix.setter
    def prefix(self, value):

        # Convert to string if necessary
        if isinstance( value, LCFGPkgPrefix ):
            value = value.value

        if is_empty(value) or value == LCFGPkgPrefix.NONE.value:
            del(self.prefix)
            return

        if len(value) != 1:
            raise ValueError(f"Invalid prefix '{value}': must be a single character")

        cdef char * as_c = value

        if not c_pkgs.lcfgpackage_valid_prefix(as_c[0]):
            raise ValueError(f"Invalid prefix '{value}'")

        cdef bint ok = c_pkgs.lcfgpackage_set_prefix( self._pkg, as_c[0] )

        if not ok:
            raise ValueError(f"Failed to set prefix to '{value}'")

    @prefix.deleter
    def prefix(self):
        self.clear_prefix()
        return

    cpdef bint has_prefix(self):
        return c_pkgs.lcfgpackage_has_prefix( self._pkg )

    cpdef clear_prefix(self):
        cdef bint ok = c_pkgs.lcfgpackage_clear_prefix( self._pkg )
        if not ok:
            raise RuntimeError("Failed to clear prefix")
        return

    @property
    def priority(self):
        return c_pkgs.lcfgpackage_get_priority(self._pkg)

    @priority.setter
    def priority(self, int value):
        cdef bint ok = c_pkgs.lcfgpackage_set_priority(self._pkg, value)
        if not ok:
            raise ValueError(f"Failed to set priority to '{value}'")
        return

    cpdef bint is_active(self):
        return c_pkgs.lcfgpackage_is_active(self._pkg)

    cpdef bint is_valid(self):
        return c_pkgs.lcfgpackage_is_valid(self._pkg)

    @classmethod
    def valid_name(cls, str value):
        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_name(value_as_c)
        return valid

    @classmethod
    def valid_arch(cls, str value):
        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_arch(value_as_c)
        return valid

    @classmethod
    def valid_version(cls, str value):
        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_version(value_as_c)
        return valid

    @classmethod
    def valid_release(cls, str value):
        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_release(value_as_c)
        return valid

    @classmethod
    def valid_prefix(cls, str value):
        if len(value) != 1: return False

        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_prefix(value_as_c[0])
        return valid

    @classmethod
    def valid_flag(cls, str value):
        if len(value) != 1: return False

        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_flag_chr(value_as_c[0])
        return valid

    @classmethod
    def valid_flags(cls, str value):
        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_flags(value_as_c)
        return valid

    @classmethod
    def valid_context(cls, str value):
        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_context(value_as_c)
        return valid

    @classmethod
    def valid_category(cls, str value):
        cdef char * value_as_c = value

        cdef bint valid = c_pkgs.lcfgpackage_valid_category(value_as_c)
        return valid

    def to_string(self, str defarch=None, style=LCFGPkgStyle.SPEC, options=LCFGOption.NONE):

        if style in [LCFGPkgStyle.RPM,LCFGPkgStyle.DEB] and \
           ( not self.has_version() or not self.has_release() ):
            raise RuntimeError("Package style requires version and release fields to be defined")

        cdef char * c_defarch = NULL
        if defarch is not None: c_defarch = defarch

        cdef:
            char ** buf_addr       = &(self.__str_buf)
            size_t * buf_size_addr = &(self.__buf_size)
            c_pkgs.LCFGOption options_value = int(options)
            Py_ssize_t len
            str result

        len = c_pkgs.lcfgpackage_to_string( self._pkg, c_defarch,
                                            style.value, options_value,
                                            buf_addr, buf_size_addr );

        if len < 0:
            raise RuntimeError("Failed to stringify package")

        result = self.__str_buf

        return result

    # Convenience wrapper functions

    def to_spec(self, str defarch=None, options=LCFGOption.NONE):
        return self.to_string( style=LCFGPkgStyle.SPEC, defarch=defarch, options=options)

    def to_cpp(self, str defarch=None, options=LCFGOption.NONE):
        return self.to_string( style=LCFGPkgStyle.CPP, defarch=defarch, options=options)

    def to_summary(self, str defarch=None, options=LCFGOption.NONE):
        return self.to_string( style=LCFGPkgStyle.SUMMARY, defarch=defarch, options=options)

    def to_xml(self, str defarch=None, options=LCFGOption.NONE):
        return self.to_string( style=LCFGPkgStyle.XML, defarch=defarch, options=options)

    def to_rpm_filename(self, str defarch=None, options=LCFGOption.NONE):
        return self.to_string( style=LCFGPkgStyle.RPM, defarch=defarch, options=options)

    def to_deb_filename(self, str defarch=None, options=LCFGOption.NONE):
        return self.to_string( style=LCFGPkgStyle.DEB, defarch=defarch, options=options)

    def __str__(self):
        return self.to_string()

    def __dealloc__(self):
        c_pkgs.lcfgpackage_relinquish(self._pkg)
        PyMem_Free(self.__str_buf)

