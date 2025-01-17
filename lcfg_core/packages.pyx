#!/usr/bin/python3

import collections.abc
from datetime import datetime
import filecmp
from pathlib import Path
from tempfile import NamedTemporaryFile
import sys
import os

cimport lcfg_core.c_packages as c_pkgs

from libc.time   cimport time_t
from libc.stdio  cimport fdopen, FILE, fflush
from libc.string cimport strdup

from .common import LCFGStatus, LCFGChange, LCFGOption, LCFGMergeRule, is_empty

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
    RPMDB   = 5

class LCFGPkgFlag:
    BOOTONLY   = 'b'
    NOTONBOOT  = 'B'
    SAVECONFIG = 'c'
    NODEPS     = 'd'
    FORCE      = 'f'
    IGNORE     = 'i'
    REBOOT     = 'r'
    NOSCRIPTS  = 's'
    NOTRIGGERS = 't'

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
                raise RuntimeError(f"Failed to parse '{spec}': {err_msg}")

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

    @property
    def identifier(self):

        cdef:
            str result = None
            char * as_c

        try:
            as_c = c_pkgs.lcfgpackage_id(self._pkg)
            if as_c != NULL:
                result = as_c
            else:
                raise RuntimeError("Failed to get identifier");
        finally:
            PyMem_Free(as_c)

        return result

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
            raise ValueError(f"Failed to add context '{value}'")

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
            raise ValueError(f"Failed to add derivation '{value}'")

        return

    cpdef add_derivation_file_line(self, str filename, int linenum):

        cdef char * as_c = filename

        cdef bint ok = c_pkgs.lcfgpackage_add_derivation_file_line( self._pkg, as_c, linenum )
        if not ok:
            raise ValueError(f"Failed to add derivation '{filename}:{linenum}'")

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

    def compare_names(self,LCFGPackage other not None):
        cdef:
            c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
            c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        return c_pkgs.lcfgpackage_compare_names(pkg1,pkg2)

    def compare_versions(self,LCFGPackage other not None):
        cdef:
            c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
            c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        return c_pkgs.lcfgpackage_compare_versions(pkg1,pkg2)

    def compare_archs(self,LCFGPackage other not None):
        cdef:
            c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
            c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        return c_pkgs.lcfgpackage_compare_archs(pkg1,pkg2)

    def same_context(self,LCFGPackage other not None):
        cdef:
            c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
            c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        return c_pkgs.lcfgpackage_same_context(pkg1,pkg2)

    def __eq__(self,LCFGPackage other not None):
        cdef c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
        cdef c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        cdef bint result = c_pkgs.lcfgpackage_equals(pkg1,pkg2)
        return result

    def __lt__(self,LCFGPackage other not None):
        cdef c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
        cdef c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        cdef bint result = c_pkgs.lcfgpackage_compare(pkg1,pkg2) < 0
        return result

    def __le__(self,LCFGPackage other not None):
        cdef c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
        cdef c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        cdef bint result = c_pkgs.lcfgpackage_compare(pkg1,pkg2) <= 0
        return result

    def __gt__(self,LCFGPackage other not None):
        cdef c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
        cdef c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        cdef bint result = c_pkgs.lcfgpackage_compare(pkg1,pkg2) > 0
        return result

    def __ge__(self,LCFGPackage other not None):
        cdef c_pkgs.LCFGPackageStruct* pkg1 = self._pkg
        cdef c_pkgs.LCFGPackageStruct* pkg2 = other._pkg

        cdef bint result = c_pkgs.lcfgpackage_compare(pkg1,pkg2) >= 0
        return result

    cpdef to_string(self, str defarch=None, style=LCFGPkgStyle.SPEC, options=LCFGOption.NONE):

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

    cpdef to_dict(self):
        cdef:
            dict result = {}
            str attr
            object value

        for attr in self.fields:
            value = getattr( self, attr )
            if not is_empty(value):
                result[attr] = value

        return result

    def __str__(self):
        return self.to_string()

    def __bool__(self):
        return self.is_valid()

    def __dealloc__(self):
        c_pkgs.lcfgpackage_relinquish(self._pkg)
        PyMem_Free(self.__str_buf)

cdef class LCFGPackageCollection:

    def __init__( self, merge_rules=None, **kwargs ):
        if merge_rules is not None:
            self.merge_rules = merge_rules

    @classmethod
    def from_rpmlist( cls, source, options=LCFGOption.NONE):
        return cls.from_source( source, source_type=LCFGPkgSourceType.RPMLIST,
                                options=options)

    @classmethod
    def from_rpmcfg( cls, source, defarch=None, options=LCFGOption.NONE):
        return cls.from_source( source, source_type=LCFGPkgSourceType.RPMCFG,
                                defarch=defarch, options=options)

    @classmethod
    def from_rpm_dir( cls, source ):
        return cls.from_source( source, source_type=LCFGPkgSourceType.RPMDIR )

    @classmethod
    def from_rpm_db( cls, source ):
        return cls.from_source( source, source_type=LCFGPkgSourceType.RPMDB )

    @classmethod
    def from_debian_index( cls, source, options=LCFGOption.NONE):
        return cls.from_source( source, source_type=LCFGPkgSourceType.DEBIDX,
                                options=options)

    def merge(self, other):
        if isinstance( other, LCFGPackage ):
            return self.merge_package(other)
        elif isinstance( other, LCFGPackageList ):
            return self.merge_list(other)
        elif isinstance( self, LCFGPackageSet ) and isinstance( other, LCFGPackageSet ):
            return self.merge_set(other)
        else:
            raise TypeError(f"No support for merging {other!r}")

    def to_dict(self):
        cdef:
           LCFGPackage pkg
           result = {}
           str pkg_name

        for pkg in self:
            pkg_name = pkg.name
            if pkg_name not in result:
                result[pkg_name] = {}
            result[pkg_name][pkg.vra()] = pkg.to_dict()

        return result

    def to_list(self):
        cdef:
           LCFGPackage pkg
           result = []
           str pkg_name

        for pkg in sorted(self):
            result.append( pkg.to_dict() )

        return result

    @classmethod
    def from_yaml( cls, filename, merge_rules=None ):

        # Create temporary file in same directory to allow for renaming

        if isinstance( filename, str ):
            filename = Path(filename)

        if isinstance( filename, Path ):
            if not filename.is_file():
                raise RuntimeError(f"YAML file '{filename}' does not exist")

        from ruamel.yaml import YAML

        yaml = YAML()

        data = yaml.load(filename)

        if merge_rules is None:
            merge_rules = LCFGMergeRule.SQUASH_IDENTICAL

        new_collection = cls(merge_rules=merge_rules)

        cdef LCFGPackage pkg_obj
        if isinstance( data, list ):
            packages = (item for item in data )
        elif isinstance( data, dict ):
            packages = ( item for item in data.values )
        else:
            raise RuntimeError(f"No support for loading {data!r}")

        for pkg in packages:
            try:
                pkg_dict = dict(pkg)
                pkg_obj  = LCFGPackage(**pkg_dict)
                new_collection.merge_package( pkg_obj )
            except Exception as e:
                print(f"Failed to import package '{pkg}': {e}", file=sys.stderr)

        return new_collection

    def to_yaml(self, filename, style='list'):

        from ruamel.yaml import YAML

        yaml = YAML()
        yaml.explicit_start = True

        # Create temporary file in same directory to allow for renaming

        if isinstance( filename, str ):
            filename = Path(filename)

        temp_file = NamedTemporaryFile( dir=filename.parent, suffix='.yaml' )

        if style == 'dict' or style == 'hash':
            data = self.to_dict()
        else:
            data = self.to_list()

        yaml.dump( data, temp_file )

        if not filename.exists() or not filecmp.cmp( filename, temp_file.name ):
            os.link( temp_file.name, filename )
            result = LCFGChange.MODIFIED
        else:
            result = LCFGChange.NONE

        return result

    def __iadd__( self, other ):
        self.merge(other)
        return self

    def __contains__(self,key):

        if isinstance(key, str):
            name = key
            arch = '*'
        elif isinstance(key, collections.abc.Sequence):
            name = key[0]
            arch = key[1]
        else:
            raise TypeError(f"Invalid key '{key}'")

        return self.has_package(name,arch)

    def __getitem__(self,key):

        # Supports the Debian/apt style of name:arch being specified
        # as a single string.

        if isinstance(key, str):
            if ':' in key:
                ( name, arch ) = key.split( sep=':', maxsplit=2 )
            else:
                name = key
                arch = '*'
        elif isinstance(key, collections.abc.Sequence):
            name = key[0]
            arch = key[1]
        else:
            raise TypeError(f"Invalid key '{key}'")

        result = self.find_package(name,arch)
        if result is None:
            raise KeyError(f"Nothing found for key '{key}'")

        return result

    def __len__(self):
        return self.size

    def __bool__(self):
        return self.size > 0

cdef class LCFGPackageList(LCFGPackageCollection):

    cdef:
        c_pkgs.LCFGPackageListStruct * _pkgs
        char * __str_buf
        size_t __buf_size

    def __cinit__( self, full_init=True, **kwargs ):
        self.__str_buf = NULL
        self.__buf_size = 0
        self._pkgs == NULL

        if full_init:
            self._pkgs = c_pkgs.lcfgpkglist_new()
            if self._pkgs == NULL:
                raise RuntimeError("Failed to create empty package list")

        return

    @staticmethod
    cdef init_with_struct(c_pkgs.LCFGPackageListStruct* pkgs):
        cdef LCFGPackageList new_obj = LCFGPackageList(full_init=False)
        new_obj._pkgs = pkgs

        return new_obj

    @classmethod
    def from_source(cls, str source, source_type, str defarch=None, options=LCFGOption.NONE):
        cdef:
            c_pkgs.LCFGPackageListStruct * pkgs = NULL
            LCFGPackageList result = None
            c_pkgs.LCFGStatus status = LCFGStatus.ERROR.value
            char * c_filename = source
            char * c_defarch  = NULL
            char * msg        = NULL
            str err_msg = 'unknown error'

        if defarch is not None: c_defarch = defarch

        try:
            if source_type == LCFGPkgSourceType.RPMLIST:
                status = c_pkgs.lcfgpkglist_from_rpmlist( c_filename, &pkgs, options, &msg )
            elif source_type == LCFGPkgSourceType.RPMDIR:
                status = c_pkgs.lcfgpkglist_from_rpm_dir( c_filename, &pkgs, &msg )
            elif source_type == LCFGPkgSourceType.RPMCFG:
                status = c_pkgs.lcfgpkglist_from_rpmcfg( c_filename, &pkgs, c_defarch, options, &msg )
            elif source_type == LCFGPkgSourceType.DEBIDX:
                status = c_pkgs.lcfgpkglist_from_debian_index( c_filename, &pkgs, options, &msg )
            else:
                raise RuntimeError(f"No support for reading package information from '{source}' as type '{source_type}'")


            if status != LCFGStatus.ERROR.value and pkgs != NULL:
                result = LCFGPackageList.init_with_struct(pkgs)
            else:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to read package information from '{source}': {err_msg}")

        finally:
            PyMem_Free(msg)

        return result

    @property
    def size(self):
        return c_pkgs.lcfgpkglist_size(self._pkgs)

    cpdef bint is_empty(self):
        return c_pkgs.lcfgpkglist_is_empty(self._pkgs)

    @property
    def merge_rules(self):
        return c_pkgs.lcfgpkglist_get_merge_rules(self._pkgs)

    @merge_rules.setter
    def merge_rules(self, value):
        # Allow use of LCFGMergeRule enum as well as ints
        value = int(value)

        cdef bint ok = c_pkgs.lcfgpkglist_set_merge_rules(self._pkgs,value)
        if not ok:
            raise ValueError(f"Invalid merge rules {value}")

        return

    def has_package(self, str name, str arch=None):
        cdef:
            const char * c_name = name
            const char * c_arch = NULL

        if arch is not None: c_arch = arch

        return c_pkgs.lcfgpkglist_has_package( self._pkgs, c_name, c_arch )

    def find_package(self, str name, str arch=None):

        cdef:
            const char * c_name = name
            const char * c_arch = NULL
            c_pkgs.LCFGPackageStruct * pkg = NULL
            LCFGPackage result = None

        if arch is None:
            c_arch = "*" # Match any architecture
        else:
            c_arch = arch

        pkg = c_pkgs.lcfgpkglist_find_package( self._pkgs, c_name, c_arch )
        if pkg != NULL:
            c_pkgs.lcfgpackage_acquire(pkg)
            result = LCFGPackage.init_with_struct(pkg)

        return result

    def match(self, str name=None, str arch=None, str version=None, str release=None):

        cdef:
            const char * c_name    = NULL
            const char * c_arch    = NULL
            const char * c_version = NULL
            const char * c_release = NULL
            c_pkgs.LCFGPackageListStruct * matches = NULL
            LCFGPackageList result = None

        if name: c_name = name
        if arch: c_arch = arch
        if version: c_version = version
        if release: c_release = release

        matches = c_pkgs.lcfgpkglist_match( self._pkgs, c_name, c_arch, c_version, c_release )
        if matches != NULL:
            result = LCFGPackageList.init_with_struct(matches)

        return result

    def merge_package(self, LCFGPackage package not None):
        cdef:
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        try:
            change = c_pkgs.lcfgpkglist_merge_package( self._pkgs, package._pkg, &msg )

            if change == LCFGChange.ERROR.value:
                if msg != NULL:  err_msg = msg
                raise RuntimeError(f"Failed to merge package: {err_msg}")

        finally:
            PyMem_Free(msg)
            result = LCFGChange(change)

        return result

    def merge_list(self, LCFGPackageList other not None):
        cdef:
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        try:
            change = c_pkgs.lcfgpkglist_merge_list( self._pkgs, other._pkgs, &msg )

            if change == LCFGChange.ERROR.value:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to merge package list: {err_msg}")

        finally:
            PyMem_Free(msg)
            result = LCFGChange(change)

        return result

    def to_rpmlist(self, str filename, str defarch=None, str base=None, mtime=None):

        cdef:
            const char * c_filename = filename
            const char * c_defarch  = NULL
            const char * c_base     = NULL
            time_t c_mtime = 0
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        if defarch is not None: c_defarch = defarch
        if base: c_base = base

        if mtime is not None:
            if isinstance(mtime,datetime):
                c_mtime = int(mtime.timestamp())
            else:
                c_mtime = int(mtime)

        try:
            change = c_pkgs.lcfgpkglist_to_rpmlist( self._pkgs, c_defarch, c_base, c_filename, c_mtime, &msg )
            result = LCFGChange(change)

            if result == LCFGChange.ERROR:
                if msg != NULL: err_msg = msg

                raise RuntimeError(f"Failed to write rpmlist file: {err_msg}")

        finally:
            PyMem_Free(msg)

        return result

    def to_rpmcfg(self, str filename, LCFGPackageList inactive=None, str defarch=None, str rpminc=None, mtime=None):

        cdef:
            c_pkgs.LCFGPackageListStruct *pkgs_active   = self._pkgs
            c_pkgs.LCFGPackageListStruct *pkgs_inactive = NULL
            const char * c_filename = filename
            const char * c_defarch  = NULL
            const char * c_rpminc   = NULL
            time_t c_mtime = 0
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        if inactive: pkgs_inactive = inactive._pkgs
        if defarch is not None: c_defarch = defarch
        if rpminc: c_rpminc   = rpminc

        if mtime is not None:
            if isinstance(mtime,datetime):
                c_mtime = int(mtime.timestamp())
            else:
                c_mtime = int(mtime)

        try:
            change = c_pkgs.lcfgpkglist_to_rpmcfg( pkgs_active, pkgs_inactive, c_defarch, c_filename, c_rpminc, c_mtime, &msg )
            result = LCFGChange(change)

            if result == LCFGChange.ERROR:
                if msg != NULL: err_msg = msg

                raise RuntimeError(f"Failed to write rpmcfg file: {err_msg}")

        finally:
            PyMem_Free(msg)

        return result

    def print( self, file=sys.stdout,
               str defarch=None, str base=None,
               style=LCFGPkgStyle.SPEC,
               options=LCFGOption.NONE ):
        cdef:
           int fd
           FILE * out_stream = NULL
           bint ok
           c_pkgs.LCFGOption options_value = int(options)
           c_pkgs.LCFGPkgStyle style_value = int(style)
           const char * c_base    = NULL
           const char * c_defarch = NULL

        if base: c_base = base
        if defarch is not None: c_defarch = defarch

        try:
            file.flush()

            fd = PyObject_AsFileDescriptor(file)

            out_stream = fdopen( fd, 'a' )
            if out_stream == NULL:
                raise RuntimeError("Failed to open file stream for writing")

            ok = c_pkgs.lcfgpkglist_print( self._pkgs, c_defarch, c_base,
                                           style_value, options_value,
                                           out_stream )

            fflush(out_stream)

            if not ok:
                raise RuntimeError("Failed to print")
        except:
            raise RuntimeError("Failed to print")

        return

    cpdef sort(self):
        c_pkgs.lcfgpkglist_sort(self._pkgs)

    def __iter__(self):
        return LCFGPackageListIterator(self)

    def __dealloc__(self):
        c_pkgs.lcfgpkglist_relinquish(self._pkgs)
        PyMem_Free(self.__str_buf)


cdef class LCFGPackageSet(LCFGPackageCollection):

    cdef:
        c_pkgs.LCFGPackageSetStruct * _pkgs
        char * __str_buf
        size_t __buf_size

    def __cinit__( self, full_init=True, **kwargs ):
        self.__str_buf = NULL
        self.__buf_size = 0
        self._pkgs == NULL

        if full_init:
            self._pkgs = c_pkgs.lcfgpkgset_new()
            if self._pkgs == NULL:
                raise RuntimeError("Failed to create empty package set")

        return

    @staticmethod
    cdef init_with_struct(c_pkgs.LCFGPackageSetStruct* pkgs):
        cdef LCFGPackageSet new_obj = LCFGPackageSet(full_init=False)
        new_obj._pkgs = pkgs

        return new_obj

    @classmethod
    def from_source(cls, str source, source_type, str defarch=None, options=LCFGOption.NONE):
        cdef:
            c_pkgs.LCFGPackageSetStruct * pkgs = NULL
            LCFGPackageSet result = None
            c_pkgs.LCFGStatus status = LCFGStatus.ERROR.value
            char * c_filename = source
            char * c_defarch  = NULL
            char * msg        = NULL
            str err_msg = 'unknown error'

        if defarch is not None: c_defarch = defarch

        try:
            if source_type == LCFGPkgSourceType.RPMLIST:
                status = c_pkgs.lcfgpkgset_from_rpmlist( c_filename, &pkgs, options, &msg )
            elif source_type == LCFGPkgSourceType.RPMDIR:
                status = c_pkgs.lcfgpkgset_from_rpm_dir( c_filename, &pkgs, &msg )
            elif source_type == LCFGPkgSourceType.RPMCFG:
                status = c_pkgs.lcfgpkgset_from_rpmcfg( c_filename, &pkgs, c_defarch, options, &msg )
            elif source_type == LCFGPkgSourceType.RPMDB:
                status = c_pkgs.lcfgpkgset_from_rpm_db( c_filename, &pkgs, &msg )
            elif source_type == LCFGPkgSourceType.DEBIDX:
                status = c_pkgs.lcfgpkgset_from_debian_index( c_filename, &pkgs, options, &msg )
            else:
                raise RuntimeError(f"No support for reading package information from '{source}' as type '{source_type}'")


            if status != LCFGStatus.ERROR.value and pkgs != NULL:
                result = LCFGPackageSet.init_with_struct(pkgs)
            else:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to read package information from '{source}': {err_msg}")

        finally:
            PyMem_Free(msg)

        return result

    @property
    def size(self):
        return c_pkgs.lcfgpkgset_size(self._pkgs)

    cpdef bint is_empty(self):
        return c_pkgs.lcfgpkgset_is_empty(self._pkgs)

    @property
    def merge_rules(self):
        return c_pkgs.lcfgpkgset_get_merge_rules(self._pkgs)

    @merge_rules.setter
    def merge_rules(self, value):
        # Allow use of LCFGMergeRule enum as well as ints
        value = int(value)

        cdef bint ok = c_pkgs.lcfgpkgset_set_merge_rules(self._pkgs,value)
        if not ok:
            raise ValueError(f"Invalid merge rules {value}")

        return

    def has_package(self, str name, str arch=None):
        cdef:
            const char * c_name = name
            const char * c_arch = NULL

        if arch is not None: c_arch = arch

        return c_pkgs.lcfgpkgset_has_package( self._pkgs, c_name, c_arch )

    def find_package(self, str name, str arch=None):

        cdef:
            const char * c_name = name
            const char * c_arch = NULL
            c_pkgs.LCFGPackageStruct * pkg = NULL
            LCFGPackage result = None

        if arch is None:
            c_arch = "*" # Match any architecture
        else:
            c_arch = arch

        pkg = c_pkgs.lcfgpkgset_find_package( self._pkgs, c_name, c_arch )
        if pkg != NULL:
            c_pkgs.lcfgpackage_acquire(pkg)
            result = LCFGPackage.init_with_struct(pkg)

        return result

    def match(self, str name=None, str arch=None, str version=None, str release=None):

        cdef:
            const char * c_name    = NULL
            const char * c_arch    = NULL
            const char * c_version = NULL
            const char * c_release = NULL
            c_pkgs.LCFGPackageSetStruct * matches = NULL
            LCFGPackageSet result = None

        if name: c_name = name
        if arch: c_arch = arch
        if version: c_version = version
        if release: c_release = release

        matches = c_pkgs.lcfgpkgset_match( self._pkgs, c_name, c_arch, c_version, c_release )
        if matches != NULL:
            result = LCFGPackageSet.init_with_struct(matches)

        return result

    def merge_package(self, LCFGPackage package not None):
        cdef:
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        try:
            change = c_pkgs.lcfgpkgset_merge_package( self._pkgs, package._pkg, &msg )

            if change == LCFGChange.ERROR.value:
                if msg != NULL:  err_msg = msg
                raise RuntimeError(f"Failed to merge package: {err_msg}")

        finally:
            PyMem_Free(msg)
            result = LCFGChange(change)

        return result

    def merge_list(self, LCFGPackageList other not None):
        cdef:
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        try:
            change = c_pkgs.lcfgpkgset_merge_list( self._pkgs, other._pkgs, &msg )

            if change == LCFGChange.ERROR.value:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to merge package list: {err_msg}")

        finally:
            PyMem_Free(msg)
            result = LCFGChange(change)

        return result

    def merge_set(self, LCFGPackageSet other not None):
        cdef:
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        try:
            change = c_pkgs.lcfgpkgset_merge_set( self._pkgs, other._pkgs, &msg )

            if change == LCFGChange.ERROR.value:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to merge package set: {err_msg}")

        finally:
            PyMem_Free(msg)
            result = LCFGChange(change)

        return result

    def to_rpmlist(self, str filename, str defarch=None, str base=None, mtime=None):

        cdef:
            const char * c_filename = filename
            const char * c_defarch  = NULL
            const char * c_base     = NULL
            time_t c_mtime = 0
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        if defarch is not None: c_defarch = defarch
        if base: c_base = base

        if mtime is not None:
            if isinstance(mtime,datetime):
                c_mtime = int(mtime.timestamp())
            else:
                c_mtime = int(mtime)

        try:
            change = c_pkgs.lcfgpkgset_to_rpmlist( self._pkgs, c_defarch, c_base, c_filename, c_mtime, &msg )
            result = LCFGChange(change)

            if result == LCFGChange.ERROR:
                if msg != NULL: err_msg = msg

                raise RuntimeError(f"Failed to write rpmlist file: {err_msg}")

        finally:
            PyMem_Free(msg)

        return result

    def to_rpmcfg(self, str filename, LCFGPackageSet inactive=None, str defarch=None, str rpminc=None, mtime=None):

        cdef:
            c_pkgs.LCFGPackageSetStruct *pkgs_active   = self._pkgs
            c_pkgs.LCFGPackageSetStruct *pkgs_inactive = NULL
            const char * c_filename = filename
            const char * c_defarch  = NULL
            const char * c_rpminc   = NULL
            time_t c_mtime = 0
            result = LCFGChange.NONE
            c_pkgs.LCFGChange change = result.value
            char * msg = NULL
            str err_msg = 'unknown error'

        if inactive: pkgs_inactive = inactive._pkgs
        if defarch is not None: c_defarch = defarch
        if rpminc: c_rpminc   = rpminc

        if mtime is not None:
            if isinstance(mtime,datetime):
                c_mtime = int(mtime.timestamp())
            else:
                c_mtime = int(mtime)

        try:
            change = c_pkgs.lcfgpkgset_to_rpmcfg( pkgs_active, pkgs_inactive, c_defarch, c_filename, c_rpminc, c_mtime, &msg )
            result = LCFGChange(change)

            if result == LCFGChange.ERROR:
                if msg != NULL: err_msg = msg

                raise RuntimeError(f"Failed to write rpmcfg file: {err_msg}")

        finally:
            PyMem_Free(msg)

        return result

    def print( self, file=sys.stdout,
               str defarch=None, str base=None,
               style=LCFGPkgStyle.SPEC,
               options=LCFGOption.NONE ):
        cdef:
           int fd
           FILE * out_stream = NULL
           bint ok
           c_pkgs.LCFGOption options_value = int(options)
           c_pkgs.LCFGPkgStyle style_value = int(style)
           const char * c_base    = NULL
           const char * c_defarch = NULL

        if base: c_base = base
        if defarch is not None: c_defarch = defarch

        try:
            file.flush()

            fd = PyObject_AsFileDescriptor(file)

            out_stream = fdopen( fd, 'a' )
            if out_stream == NULL:
                raise RuntimeError("Failed to open file stream for writing")

            ok = c_pkgs.lcfgpkgset_print( self._pkgs, c_defarch, c_base,
                                          style_value, options_value,
                                          out_stream )

            fflush(out_stream)

            if not ok:
                raise RuntimeError("Failed to print")
        except:
            raise RuntimeError("Failed to print")

        return

    def __iter__(self):
        return LCFGPackageSetIterator(self)

    def __dealloc__(self):
        c_pkgs.lcfgpkgset_relinquish(self._pkgs)
        PyMem_Free(self.__str_buf)

cdef class LCFGPackageListIterator:
    cdef c_pkgs.LCFGPackageIteratorStruct *_iter

    def __cinit__(self,LCFGPackageList coll):
        self._iter = c_pkgs.lcfgpkgiter_new(coll._pkgs)

    def __iter__(self):
        return self

    def __next__(self):

        cdef c_pkgs.LCFGPackageStruct *pkg = c_pkgs.lcfgpkgiter_next(self._iter)

        if pkg == NULL: raise StopIteration

        cdef LCFGPackage result = None

        c_pkgs.lcfgpackage_acquire(pkg)
        result = LCFGPackage.init_with_struct(pkg)

        return result

    def __dealloc__(self):
        c_pkgs.lcfgpkgiter_destroy(self._iter)


cdef class LCFGPackageSetIterator:
    cdef c_pkgs.LCFGPkgSetIteratorStruct *_iter

    def __cinit__(self,LCFGPackageSet coll):
        self._iter = c_pkgs.lcfgpkgsetiter_new(coll._pkgs)

    def __iter__(self):
        return self

    def __next__(self):

        cdef c_pkgs.LCFGPackageStruct *pkg = c_pkgs.lcfgpkgsetiter_next(self._iter)

        if pkg == NULL: raise StopIteration

        cdef LCFGPackage result = None

        c_pkgs.lcfgpackage_acquire(pkg)
        result = LCFGPackage.init_with_struct(pkg)

        return result

    def __dealloc__(self):
        c_pkgs.lcfgpkgsetiter_destroy(self._iter)
