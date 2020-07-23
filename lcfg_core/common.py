from enum import Enum, IntFlag

class LCFGStatus(IntFlag):
    ERROR = 0
    WARN  = 1
    OK    = 2

class LCFGChange(IntFlag):
    ERROR    =   0
    NONE     =   1
    MODIFIED =   2
    ADDED    =   4
    REPLACED =   8
    REMOVED  =  16

class LCFGOption(IntFlag):
    NONE           =    0
    NOCONTEXT      =    1
    NOPREFIX       =    2
    NEWLINE        =    4
    NOVALUE        =    8
    NOTEMPLATES    =   16
    ALLOW_NOEXIST  =   32
    ENCODE         =   64
    ALL_CONTEXTS   =  128
    ALL_PRIORITIES =  256
    USE_META       =  512
    ALL_VALUES     = 1024
    COMPAT         = 2048
    LEGACY         = 4096
    NEW            = 8192

class LCFGMergeRule(IntFlag):
    NONE             =  0
    KEEP_ALL         =  1
    SQUASH_IDENTICAL =  2
    USE_PRIORITY     =  4
    USE_PREFIX       =  8
    REPLACE          = 16

def is_empty(value):
    return value is None or value == ''
