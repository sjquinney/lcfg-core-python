#!/usr/bin/python3

import collections.abc
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

    def __cinit__( self, spec=None, style=None, full_init=True, **kwargs ):

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

        cdef char * as_c = value

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

        cdef char * as_c = value

        if not c_res.lcfgresource_valid_context(as_c):
            raise ValueError(f"Invalid context '{value}'")

        cdef char * c_copy = strdup(as_c)
        cdef bint ok = c_res.lcfgresource_set_context( self._res, c_copy )

        if not ok:
            PyMem_Free(c_copy)
            raise ValueError(f"Failed to set context to '{value}'")

    cpdef bint has_context(self):
        return c_res.lcfgresource_has_context( self._res )

    cpdef add_context(self,str value):

        if is_empty(value):
            raise ValueError("Invalid context: empty string")

        cdef char * as_c = value

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
            char * as_c = NULL
            size_t buf_size = 0
            Py_ssize_t len

        if self.has_derivation():
            len = c_res.lcfgresource_get_derivation_as_string(self._res, LCFGOption.NONE.value, &as_c, &buf_size )
            result = (<bytes> as_c[:len]).decode('UTF-8')

        return result

    @derivation.setter
    def derivation(self, str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef char * as_c = value

        cdef bint ok = c_res.lcfgresource_set_derivation_as_string( self._res, as_c )

        if not ok:
            raise ValueError(f"Failed to set derivation to '{value}'")

    cpdef bint has_derivation(self):
        return c_res.lcfgresource_has_derivation( self._res )

    cpdef add_derivation(self,str value):
        if is_empty(value):
            raise ValueError("Invalid derivation: empty string")

        cdef char * as_c = value

        cdef bint ok = c_res.lcfgresource_add_derivation_string( self._res, as_c )
        if not ok:
            raise ValueError(f"Failed to add derivation '{value}'")

        return

    cpdef add_derivation_file_line(self, str filename, int linenum):

        cdef char * as_c = filename

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

        cdef char * as_c = value
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
            char * as_c = NULL
            size_t buf_size = 0
            Py_ssize_t len

        if self.has_template():
            len = c_res.lcfgresource_get_template_as_string(self._res, LCFGOption.NONE.value, &as_c, &buf_size )
            result = (<bytes> as_c[:len]).decode('UTF-8')

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

    def to_string(self, prefix=None, style=LCFGResourceStyle.SPEC, options=LCFGOption.NONE ):

        cdef const char * c_prefix = NULL
        if prefix is not None: c_prefix = prefix

        cdef:
            char ** buf_addr       = &(self.__str_buf)
            size_t * buf_size_addr = &(self.__buf_size)
            c_res.LCFGOption options_value = int(options)
            Py_ssize_t len
            str result

        len = c_res.lcfgresource_to_string( self._res, c_prefix,
                                            style.value, options_value,
                                            buf_addr, buf_size_addr );

        if len < 0:
            raise RuntimeError("Failed to stringify resource")

        result = self.__str_buf

        return result

    def __bool__(self):
        return self.is_true()

    def __str__(self):
        return self.to_string()

    def __dealloc__(self):
        c_res.lcfgresource_relinquish(self._res)
        PyMem_Free(self.__str_buf)
