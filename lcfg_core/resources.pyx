#!/usr/bin/python3

import collections.abc
import os

cimport lcfg_core.c_resources as c_res

from libc.string cimport strdup

from .common import LCFGStatus, LCFGChange, LCFGOption, LCFGMergeRule, is_empty

from cpython.mem cimport PyMem_Free

from enum import Enum, IntFlag
class LCFGResourceType(IntFlag):
    STRING    = 0
    INTEGER   = 1
    BOOLEAN   = 2
    LIST      = 3
    PUBLISH   = 4
    SUBSCRIBE = 5

class LCFGResourceStyle(IntFlag):
    SPEC    = 0
    STATUS  = 1
    SUMMARY = 2
    EXPORT  = 3
    VALUE   = 4

cdef const char * RESOURCE_ENV_VAL_PFX  = "LCFG_%s_"
cdef const char * RESOURCE_ENV_TYPE_PFX = "LCFGTYPE_%s_"

def _stringify_value( value ):

    if not isinstance( value, str ) and \
       isinstance( value, collections.abc.Sequence ):
        new_value = ' '.join(value)
    elif isinstance( value, bool ):
        if value:
            new_value = "yes"
        else:
            new_value = "no"
    else:
        new_value = str(value)

    return new_value

cdef class LCFGResource:
    fields = [ 'name', 'type', 'value',\
               'template', 'comment',\
               'context', 'derivation',\
               'priority' ]

    cdef:
        c_res.LCFGResourceStruct* _res
        char * __str_buf
        size_t __buf_size

    def __init__( self, spec=None, style=None, **kwargs ):
        self.update(**kwargs)

    def __cinit__( self, spec=None, style=LCFGResourceStyle.SPEC, full_init=True, **kwargs ):

        # For speed a buffer is maintained which can be reused for
        # various stringification tasks.

        self.__str_buf  = NULL
        self.__buf_size = 0

        self._res == NULL

        if not full_init: return

        # Create a new empty package
        if spec is None:
            self._res = c_res.lcfgresource_new()
            if self._res == NULL:
                raise RuntimeError("Failed to create new resource")
            return

        cdef:
            str err_msg = 'unknown error'
            char * msg = NULL
            char * hostname = NULL
            char * compname = NULL
            c_res.LCFGStatus status = LCFGStatus.ERROR.value
            const char * spec_as_c = spec

        try:

            if style == LCFGResourceStyle.SPEC:
                status = c_res.lcfgresource_from_spec( spec_as_c, &self._res,
                                                   &hostname, &compname, &msg )
            else:
                raise RuntimeError(f"No support for {style} parsing")

            if status == LCFGStatus.ERROR.value or self._res == NULL:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to parse '{spec}': {err_msg}")

        finally:
            PyMem_Free(hostname)
            PyMem_Free(compname)
            PyMem_Free(msg)

        return

    @classmethod
    def from_spec( cls, spec, **kwargs ):
        return cls( spec=spec, style=LCFGResourceStyle.SPEC, **kwargs )

    @classmethod
    def from_env( cls, str resource, str comp=None, str value_pfx=None, str type_pfx=None, options=LCFGOption.NONE, **kwargs ):

        cdef:
            const char * c_comp      = NULL
            const char * c_value_pfx = NULL
            const char * c_type_pfx  = NULL
            const char * c_resource  = resource
            c_res.LCFGOption options_value = int(options)
            c_res.LCFGStatus status = LCFGStatus.ERROR.value
            char * msg = NULL
            str err_msg = 'unknown error'
            LCFGResource self = cls(full_init=False)

        if comp      is not None: c_comp      = comp
        if value_pfx is not None: c_value_pfx = value_pfx
        if type_pfx  is not None: c_type_pfx  = type_pfx

        try:
            status = c_res.lcfgresource_from_env( c_resource, c_comp,
                                                  c_value_pfx, c_type_pfx,
                                                  &self._res, options_value,
                                                  &msg )

            if status == LCFGStatus.ERROR.value or self._res == NULL:
                if msg != NULL: err_msg = msg
                raise RuntimeError(f"Failed to load resource '{resource}' from environment: err_msg")

            self.update(**kwargs)

        finally:
            PyMem_Free(msg)

        return self

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
            as_c = c_res.lcfgresource_get_name(self._res)
            if as_c != NULL: result = as_c

        return result

    @name.setter
    def name(self, str value):
        if is_empty(value):
            raise ValueError("Invalid name: empty string")

        cdef const char * as_c = value

        if not c_res.lcfgresource_valid_name(as_c):
            raise ValueError(f"Invalid name '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_res.lcfgresource_set_name( self._res, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Failed to set name to '{value}'")

    cpdef bint has_name(self):
        return c_res.lcfgresource_has_name( self._res )

    # Type

    @property
    def type(self):
        cdef c_res.LCFGResourceType type_id = c_res.lcfgresource_get_type(self._res)
        
        result = LCFGResourceType(type_id)
        return result

    @property
    def type_string(self):

        cdef:
            str result = None
            Py_ssize_t len

        len = c_res.lcfgresource_get_type_as_string(self._res, LCFGOption.NONE.value, &(self.__str_buf), &(self.__buf_size) )
        result = (<bytes> self.__str_buf[:len]).decode('UTF-8')

        return result

    @type.setter
    def type(self, value):

        if is_empty(value):
            raise ValueError("Invalid type: empty string")

        # Translate basic Python types into the closest LCFG resource type
        if value == str:
            new_type = LCFGResourceType.STRING
        elif value == int:
            new_type = LCFGResourceType.INTEGER
        elif value == bool:
            new_type = LCFGResourceType.BOOLEAN
        elif value == list:
            new_type = LCFGResourceType.LIST
        else:
            new_type = value

        cdef:
            bint ok
            char * msg = NULL
            const char * as_c
            str err_msg = None

        try:
            if isinstance( new_type, str ):
                as_c = new_type
                ok = c_res.lcfgresource_set_type_as_string( self._res, as_c, &msg )
                if msg != NULL: err_msg = msg
            else:
                new_type = int(new_type)
                ok = c_res.lcfgresource_set_type(self._res, new_type )

            # Deal with the fact that the set_type function is not as
            # helpful as we would like.

            if not ok:
                if err_msg == None and self.value != None:
                    err_msg = f"Cannot coerce current value '{self.value}'"
                else:
                    err_msg = "Unknown error"

                raise ValueError(f"Failed to set type to '{value}': {err_msg}")
        finally:
            PyMem_Free(msg)

    def is_string(self):
        return c_res.lcfgresource_is_string(self._res)

    def is_integer(self):
        return c_res.lcfgresource_is_integer(self._res)

    def is_boolean(self):
        return c_res.lcfgresource_is_boolean(self._res)

    def is_list(self):
        return c_res.lcfgresource_is_list(self._res)

    def is_true(self):
        return c_res.lcfgresource_is_true(self._res)

    @property
    def value(self):
        cdef:
            object result = None
            const char * as_c

        if self.has_value():

            if self.is_boolean():
                result = self.is_true()
            else:
                as_c = c_res.lcfgresource_get_value(self._res)
                if as_c != NULL:
                    result = <unicode> as_c

                    if self.is_integer():
                        result = int(result)
                    elif self.is_list():
                        result = result.split()

        return result

    @property
    def v(self):
        return self.value

    @value.setter
    def value(self, value):
        if value is None:
            del(self.value)
            return

        cdef:
            str new_value = _stringify_value(value)
            const char * as_c = new_value
            char * c_copy = NULL
            bint ok

        try:

            # Need to canonicalise before validating
            if self.is_boolean():
                c_copy = c_res.lcfgresource_canon_boolean(as_c)
            else:
                c_copy = strdup(as_c)

            if not c_res.lcfgresource_valid_value( self._res, c_copy ):
                raise ValueError(f"Invalid value '{value}'")

            ok = c_res.lcfgresource_set_value( self._res, c_copy )
            if not ok:
                raise ValueError(f"Failed to set value to '{value}'")

        except:
            PyMem_Free(c_copy)
            raise

    @value.deleter
    def value(self):
        if not c_res.lcfgresource_unset_value(self._res):
            raise RuntimeError("Failed to unset value")

    def valid_value( self, value ):
        cdef:
            str new_value
            const char * as_c = NULL

        is_valid = False
        if value is not None:
            new_value = _stringify_value(value)
            as_c = new_value
            is_valid = c_res.lcfgresource_valid_value( self._res, as_c )

        return is_valid

    cpdef bint has_value(self):
        return c_res.lcfgresource_has_value( self._res )

    cpdef value_needs_encode(self):
        return c_res.lcfgresource_value_needs_encode(self._res)

    def enc_value(self):

        cdef:
            str result = None
            cdef char * as_c = NULL;

        try:
            if self.has_value():
                as_c = c_res.lcfgresource_enc_value(self._res)
                result = as_c
        finally:
            PyMem_Free(as_c)

        return result

    # context

    @property
    def context(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_context():
            as_c   = c_res.lcfgresource_get_context(self._res)
            if as_c != NULL: result = as_c

        return result

    @context.setter
    def context(self, str value):

        if is_empty(value):
            raise ValueError("Invalid context: empty string")

        cdef const char * as_c = value

        if not c_res.lcfgresource_valid_context(as_c):
            raise ValueError(f"Invalid context '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_res.lcfgresource_set_context( self._res, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Failed to set context to '{value}'")

    cpdef bint has_context(self):
        return c_res.lcfgresource_has_context( self._res )

    def add_context(self,str value):

        if is_empty(value):
            raise ValueError("Invalid context: empty string")

        cdef const char * as_c = value

        if not c_res.lcfgresource_valid_context(as_c):
            raise ValueError(f"Invalid context '{value}'")

        cdef bint result = c_res.lcfgresource_add_context( self._res, as_c )
        if not result:
            raise ValueError(f"Failed to add context '{value}'")

        return

    # derivation

    @property
    def derivation(self):

        cdef:
            str result = None
            Py_ssize_t len

        if self.has_derivation():
            len = c_res.lcfgresource_get_derivation_as_string(self._res, LCFGOption.NONE.value, &(self.__str_buf), &(self.__buf_size) )
            result = (<bytes> self.__str_buf[:len]).decode('UTF-8')

        return result

    @derivation.setter
    def derivation(self, str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef const char * as_c = value

        cdef bint ok = c_res.lcfgresource_set_derivation_as_string( self._res, as_c )

        if not ok:
            raise ValueError(f"Failed to set derivation to '{value}'")

    cpdef bint has_derivation(self):
        return c_res.lcfgresource_has_derivation( self._res )

    cpdef add_derivation(self,str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef const char * as_c = value

        cdef bint ok = c_res.lcfgresource_add_derivation_string( self._res, as_c )
        if not ok:
            raise ValueError(f"Failed to add derivation '{value}'")

        return

    cpdef add_derivation_file_line(self, str filename, int linenum):

        cdef const char * as_c = filename

        cdef bint ok = c_res.lcfgresource_add_derivation_file_line( self._res, as_c, linenum )
        if not ok:
            raise ValueError(f"Failed to add derivation '{filename}:{linenum}'")

        return

    # comment

    @property
    def comment(self):
        cdef:
            str result = None
            const char * as_c

        if self.has_comment():
            as_c   = c_res.lcfgresource_get_comment(self._res)
            if as_c != NULL: result = as_c

        return result

    @comment.setter
    def comment(self, str value):
        if is_empty(value):
            raise ValueError("Invalid comment: empty string")

        cdef const char * as_c = value
        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_res.lcfgresource_set_comment( self._res, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            c_copy = NULL
            raise ValueError(f"Failed to set comment to '{value}'")

    cpdef bint has_comment(self):
        return c_res.lcfgresource_has_comment( self._res )

    # template

    @property
    def template(self):

        cdef:
            str result = None
            Py_ssize_t len

        if self.has_template():
            len = c_res.lcfgresource_get_template_as_string(self._res, LCFGOption.NONE.value, &(self.__str_buf), &(self.__buf_size) )
            result = (<bytes> self.__str_buf[:len]).decode('UTF-8')

        return result

    @template.setter
    def template(self, str value):

        if is_empty(value):
            del(self.template)
            return

        cdef:
            const char * as_c = value
            cdef bint ok
            char * msg = NULL
            str err_msg = 'unknown error'

        try:
            ok = c_res.lcfgresource_set_template_as_string( self._res, as_c, &msg )

            if not ok:
                if msg != NULL: err_msg = msg
                raise ValueError(f"Failed to set template to '{value}': {err_msg}")
        finally:
            PyMem_Free(msg)

    @template.deleter
    def template(self):

        cdef:
            bint ok
            char * msg = NULL
            str err_msg = 'unknown error'

        try:
            ok = c_res.lcfgresource_set_template_as_string( self._res, "", &msg )

            if not ok:
                if msg != NULL: err_msg = msg
                raise ValueError(f"Failed to unset template: {err_msg}")
        finally:
            PyMem_Free(msg)

    cpdef bint has_template(self):
        return c_res.lcfgresource_has_template( self._res )


    @property
    def priority(self):
        return c_res.lcfgresource_get_priority(self._res)

    @priority.setter
    def priority(self, int value):
        cdef bint ok = c_res.lcfgresource_set_priority(self._res, value)
        if not ok:
            raise ValueError(f"Failed to set priority to '{value}'")
        return

    cpdef bint is_active(self):
        return c_res.lcfgresource_is_active(self._res)

    cpdef bint is_valid(self):
        return c_res.lcfgresource_is_valid(self._res)

    cpdef bint merge_derivation( self, LCFGResource other ):
        return c_res.lcfgresource_merge_derivation( self._res, other._res )

    @classmethod
    def valid_name(cls, value):
        value_as_str = _stringify_value(value)
        cdef const char * value_as_c = value_as_str
        return c_res.lcfgresource_valid_name(value_as_c)

    @classmethod
    def valid_boolean(cls, value):
        value_as_str = _stringify_value(value)
        cdef const char * value_as_c = value_as_str
        return c_res.lcfgresource_valid_boolean(value_as_c)

    @classmethod
    def valid_integer(cls, value):
        value_as_str = _stringify_value(value)
        cdef const char * value_as_c = value_as_str
        return c_res.lcfgresource_valid_integer(value_as_c)

    @classmethod
    def valid_list(cls, value):
        value_as_str = _stringify_value(value)
        cdef const char * value_as_c = value_as_str
        return c_res.lcfgresource_valid_list(value_as_c)

    def to_string(self, str comp=None, style=LCFGResourceStyle.SPEC, options=LCFGOption.NONE, str value_pfx=None, str type_pfx=None ):

        if style == LCFGResourceStyle.EXPORT and is_empty(comp) and \
           ( value_pfx is None or type_pfx is None or \
             "%s" in value_pfx or "%s" in type_pfx ):
            raise ValueError("Component name MUST be specified")

        cdef:
            const char * c_comp      = NULL
            const char * c_value_pfx = NULL
            const char * c_type_pfx  = NULL

        if comp      is not None: c_comp      = comp
        if value_pfx is not None: c_value_pfx = value_pfx
        if type_pfx  is not None: c_type_pfx  = type_pfx

        cdef:
            char ** buf_addr       = &(self.__str_buf)
            size_t * buf_size_addr = &(self.__buf_size)
            c_res.LCFGOption options_value = int(options)
            Py_ssize_t len
            str result

        if style == LCFGResourceStyle.EXPORT:
            len = c_res.lcfgresource_to_export( self._res, c_comp,
                                                c_value_pfx, c_type_pfx,
                                                options_value,
                                                buf_addr, buf_size_addr );

        else:
            len = c_res.lcfgresource_to_string( self._res, c_comp,
                                                style.value,
                                                options_value,
                                                buf_addr, buf_size_addr );

        if len < 0:
            raise RuntimeError("Failed to stringify resource")

        result = self.__str_buf

        return result

    @classmethod
    def valid_env_var( cls, value ):
        cdef const char * value_as_c = value
        return c_res.lcfgresource_valid_env_var(value_as_c)

    def to_spec( self, str comp=None, options=LCFGOption.NONE ):
        return self.to_string( comp=comp, options=options, style=LCFGResourceStyle.SPEC)

    def to_status( self, str comp=None, options=LCFGOption.NONE ):
        return self.to_string( comp=comp, options=options, style=LCFGResourceStyle.STATUS)

    def to_summary( self, str comp=None, options=LCFGOption.NONE ):
        return self.to_string( comp=comp, options=options, style=LCFGResourceStyle.SUMMARY)

    def to_value( self, str comp=None, options=LCFGOption.NONE ):
        return self.to_string( comp=comp, options=options, style=LCFGResourceStyle.VALUE)

    def to_export( self, str comp=None, options=LCFGOption.NONE, str value_pfx=None, str type_pfx=None ):
        return self.to_string( comp=comp, options=options, style=LCFGResourceStyle.EXPORT, value_pfx=value_pfx, type_pfx=type_pfx)

    def to_env( self, str comp=None,  options=LCFGOption.NONE, str value_pfx=None, str type_pfx=None ):

        if is_empty(comp) and \
           ( value_pfx is None or type_pfx is None or \
             "%s" in value_pfx or "%s" in type_pfx ):
            raise ValueError("Component name MUST be specified")

        cdef:
            const char * c_comp      = NULL
            const char * c_value_pfx = NULL
            const char * c_type_pfx  = NULL
            str type_var
            str value_var

        if comp      is not None: c_comp      = comp
        if value_pfx is not None: c_value_pfx = value_pfx
        if type_pfx  is not None: c_type_pfx  = type_pfx

        cdef:
            c_res.LCFGOption options_value = int(options)
            c_res.LCFGStatus status = LCFGStatus.ERROR.value
            Py_ssize_t len
            const char * c_resname

        c_resname = c_res.lcfgresource_get_name(self._res)

        len = c_res.lcfgresource_build_env_var( c_resname, c_comp, RESOURCE_ENV_VAL_PFX, c_value_pfx, &(self.__str_buf), &(self.__buf_size) )

        if len < 0:
            raise RuntimeError(f"Failed to export resource to environment")

        value_var = self.__str_buf

        if not self.valid_env_var(value_var):
            raise RuntimeError(f"Invalid environment variable '{value_var}'")

        env = os.environ

        if self.has_value():
            env[value_var] = str(self.value)
        else:
            env[value_var] = ""

        if options & LCFGOption.USE_META and not self.is_string():

            len = c_res.lcfgresource_build_env_var( c_resname, c_comp, RESOURCE_ENV_TYPE_PFX, c_type_pfx, &(self.__str_buf), &(self.__buf_size) )

            if len < 0:
                raise RuntimeError(f"Failed to export resource to environment")

            type_var = self.__str_buf

            if not self.valid_env_var(type_var):
                raise RuntimeError(f"Invalid environment variable '{type_var}'")

            env[type_var] = self.type_string

        return

    cpdef int compare( self, LCFGResource other ):
        return c_res.lcfgresource_compare( self._res, other._res )

    cpdef bint equals( self, LCFGResource other):
        return c_res.lcfgresource_compare( self._res, other._res )

    def compare_names( self, LCFGResource other ):
        return c_res.lcfgresource_compare_names( self._res, other._res )

    def compare_values( self, LCFGResource other ):
        return c_res.lcfgresource_compare_values( self._res, other._res )

    def __eq__(self,LCFGResource other not None):
        return self.equals(other)

    def __lt__(self,LCFGResource other not None):
        return self.compare(other) < 0

    def __le__(self,LCFGResource other not None):
        return self.compare(other) <= 0

    def __gt__(self,LCFGResource other not None):
        return self.compare(other) > 0

    def __ge__(self,LCFGResource other not None):
        return self.compare(other) >= 0

    cpdef bint same_name( self, LCFGResource other):
        return c_res.lcfgresource_same_name( self._res, other._res )

    cpdef bint same_value( self, LCFGResource other):
        return c_res.lcfgresource_same_value( self._res, other._res )

    cpdef bint same_type( self, LCFGResource other):
        return c_res.lcfgresource_same_type( self._res, other._res )

    cpdef bint same_context( self, LCFGResource other):
        return c_res.lcfgresource_same_context( self._res, other._res )

    def __bool__(self):
        return self.is_true()

    def __str__(self):
        return self.to_spec()

    def __dealloc__(self):
        c_res.lcfgresource_relinquish(self._res)
        PyMem_Free(self.__str_buf)
