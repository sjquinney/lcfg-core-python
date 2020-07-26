cdef extern from "lcfg/resources.h":
    ctypedef struct LCFGResourceStruct "LCFGResource":
        pass

    ctypedef unsigned int LCFGStatus
    ctypedef unsigned int LCFGChange
    ctypedef unsigned int LCFGOption
    ctypedef unsigned int LCFGResourceType
    ctypedef unsigned int LCFGResourceStyle

    LCFGResourceStruct * lcfgresource_new()
    LCFGResourceStruct * lcfgresource_clone(const LCFGResourceStruct * res)
    void lcfgresource_acquire( LCFGResourceStruct * res )
    void lcfgresource_relinquish( LCFGResourceStruct * res )

    bint lcfgresource_is_valid( const LCFGResourceStruct * res )

    bint lcfgresource_valid_name( const char * name )
    bint lcfgresource_has_name( const LCFGResourceStruct * res )
    const char * lcfgresource_get_name( const LCFGResourceStruct * res )
    bint lcfgresource_set_name( LCFGResourceStruct * res, char * new_value )

    LCFGResourceType lcfgresource_get_type( const LCFGResourceStruct * res )
    bint lcfgresource_set_type( LCFGResourceStruct * res,
                                LCFGResourceType new_value )
    bint lcfgresource_set_type_as_string( LCFGResourceStruct * res,
                                          const char * new_value,
                                          char ** msg )
    ssize_t lcfgresource_get_type_as_string( const LCFGResourceStruct * res,
                                             LCFGOption options,
                                             char ** result, size_t * size )

    bint lcfgresource_is_string(  const LCFGResourceStruct * res )
    bint lcfgresource_is_integer( const LCFGResourceStruct * res )
    bint lcfgresource_is_boolean( const LCFGResourceStruct * res )
    bint lcfgresource_is_list(    const LCFGResourceStruct * res )
    bint lcfgresource_is_true( const LCFGResourceStruct * res )

    bint lcfgresource_has_template( const LCFGResourceStruct * res )
    ssize_t lcfgresource_get_template_as_string( const LCFGResourceStruct * res,
                                                 LCFGOption options,
                                                 char ** result, size_t * size )
    bint lcfgresource_set_template_as_string( LCFGResourceStruct * res,
                                              const char * new_value,
                                              char ** msg )

    char * lcfgresource_canon_boolean( const char * value )

    bint lcfgresource_valid_boolean( const char * value )

    bint lcfgresource_valid_integer( const char * value )

    bint lcfgresource_valid_list(    const char * value )

    bint lcfgresource_valid_value_for_type( LCFGResourceType type,
                                            const char * value )

    bint lcfgresource_value_needs_encode( const LCFGResourceStruct * res );

    bint lcfgresource_valid_value( const LCFGResourceStruct * res,
                                   const char * value )

    bint lcfgresource_has_value( const LCFGResourceStruct * res )
    const char * lcfgresource_get_value( const LCFGResourceStruct * res )
    bint lcfgresource_set_value( LCFGResourceStruct * res,
                                 char * new_value )
    bint lcfgresource_unset_value( LCFGResourceStruct * res )

    char * lcfgresource_enc_value( const LCFGResourceStruct * res)

    bint lcfgresource_has_derivation( const LCFGResourceStruct * res )
    ssize_t lcfgresource_get_derivation_as_string( const LCFGResourceStruct * res,
                                                   LCFGOption options,
                                                   char ** result, size_t * size )

    size_t lcfgresource_get_derivation_length( const LCFGResourceStruct * res )
    bint lcfgresource_set_derivation_as_string( LCFGResourceStruct * res,
                                                const char * new_value )
    bint lcfgresource_add_derivation_string( LCFGResourceStruct * resource,
                                             const char * extra_deriv )
    bint lcfgresource_add_derivation_file_line( LCFGResourceStruct * res,
                                                const char * filename,
                                                int line )

    bint lcfgresource_merge_derivation( LCFGResourceStruct * res1,
                                        const LCFGResourceStruct * res2 )

    bint lcfgresource_valid_context( const char * expr )
    bint lcfgresource_has_context( const LCFGResourceStruct * res )
    const char * lcfgresource_get_context( const LCFGResourceStruct * res )
    bint lcfgresource_set_context( LCFGResourceStruct * res, char * new_value )
    bint lcfgresource_add_context( LCFGResourceStruct * res,
                                   const char * extra_context )

    bint lcfgresource_has_comment( const LCFGResourceStruct * res )
    const char * lcfgresource_get_comment( const LCFGResourceStruct * res )
    bint lcfgresource_set_comment( LCFGResourceStruct * res, char * new_value )

    int lcfgresource_get_priority( const LCFGResourceStruct * res )
    ssize_t lcfgresource_get_priority_as_string( const LCFGResourceStruct * res,
                                                 LCFGOption options,
                                                 char ** result, size_t * size )
    bint lcfgresource_set_priority( LCFGResourceStruct * res, int priority )
    bint lcfgresource_set_priority_default( LCFGResourceStruct * res )
    bint lcfgresource_is_active( const LCFGResourceStruct * res )

    ssize_t lcfgresource_to_string( const LCFGResourceStruct * res,
                                    const char * prefix,
                                    LCFGResourceStyle style,
                                    LCFGOption options,
                                    char ** result, size_t * size )

    ssize_t lcfgresource_to_export( const LCFGResourceStruct * res,
                                    const char * compname,
                                    const char * val_pfx, const char * type_pfx,
                                    LCFGOption options,
                                    char ** result, size_t * size )

    LCFGStatus lcfgresource_from_spec( const char * spec,
                                       LCFGResourceStruct ** result,
				                       char ** hostname, char ** compname,
				                       char ** msg )

    LCFGStatus lcfgresource_from_env( const char * resname,
                                      const char * compname,
                                      const char * val_pfx, const char * type_pfx,
                                      LCFGResourceStruct ** result,
                                      LCFGOption options, char ** msg )
