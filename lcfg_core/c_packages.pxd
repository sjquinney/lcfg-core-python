from libc.stdio cimport FILE
from libc.time  cimport time_t

cdef extern from "lcfg/packages.h":
    ctypedef struct LCFGPackageStruct "LCFGPackage":
        pass

    ctypedef struct LCFGPackageListStruct "LCFGPackageList":
        pass

    ctypedef struct LCFGPackageIteratorStruct "LCFGPackageIterator":
        pass

    ctypedef unsigned int LCFGStatus
    ctypedef unsigned int LCFGChange
    ctypedef unsigned int LCFGOption
    ctypedef unsigned int LCFGPkgStyle
    ctypedef unsigned int LCFGMergeRule

    LCFGPackageStruct * lcfgpackage_new()
    void lcfgpackage_acquire( LCFGPackageStruct * pkg )
    void lcfgpackage_relinquish( LCFGPackageStruct * pkg )

    bint lcfgpackage_valid_name( const char * name )
    bint lcfgpackage_has_name( const LCFGPackageStruct * pkg )
    const char * lcfgpackage_get_name( const LCFGPackageStruct * pkg )
    bint lcfgpackage_set_name( LCFGPackageStruct * pkg, char * new_value )

    bint lcfgpackage_valid_version( const char * version )
    bint lcfgpackage_has_version( const LCFGPackageStruct * pkg )
    const char * lcfgpackage_get_version( const LCFGPackageStruct * pkg )
    bint lcfgpackage_set_version( LCFGPackageStruct * pkg, char * new_value )
    unsigned long int lcfgpackage_get_epoch(  const LCFGPackageStruct * pkg )
    char * lcfgpackage_full_version( const LCFGPackageStruct * pkg )

    bint lcfgpackage_valid_release( const char * release )
    bint lcfgpackage_has_release( const LCFGPackageStruct * pkg )
    const char * lcfgpackage_get_release( const LCFGPackageStruct * pkg )
    bint lcfgpackage_set_release( LCFGPackageStruct * pkg, char * new_value )

    bint lcfgpackage_valid_arch( const char * arch )
    bint lcfgpackage_has_arch( const LCFGPackageStruct * pkg )
    const char * lcfgpackage_get_arch( const LCFGPackageStruct * pkg )
    bint lcfgpackage_set_arch( LCFGPackageStruct * pkg, char * new_value )

    bint lcfgpackage_valid_flag_chr( const char flag )
    bint lcfgpackage_valid_flags( const char * flag )
    bint lcfgpackage_has_flag( const LCFGPackageStruct * pkg, char flag )
    bint lcfgpackage_has_flags( const LCFGPackageStruct * pkg )
    const char * lcfgpackage_get_flags( const LCFGPackageStruct * pkg )
    bint lcfgpackage_clear_flags( LCFGPackageStruct * pkg )
    bint lcfgpackage_set_flags( LCFGPackageStruct * pkg, char * new_value )
    bint lcfgpackage_add_flags( LCFGPackageStruct * pkg, const char * new_value )

    bint lcfgpackage_valid_prefix( char prefix )
    bint lcfgpackage_has_prefix( const LCFGPackageStruct * pkg );
    char lcfgpackage_get_prefix( const LCFGPackageStruct * pkg );
    bint lcfgpackage_set_prefix( LCFGPackageStruct * pkg, char new_prefix )
    bint lcfgpackage_clear_prefix( LCFGPackageStruct * pkg )

    bint lcfgpackage_valid_context( const char * expr )
    bint lcfgpackage_has_context( const LCFGPackageStruct * pkg )
    const char * lcfgpackage_get_context( const LCFGPackageStruct * pkg )
    bint lcfgpackage_set_context( LCFGPackageStruct * pkg, char * new_value )
    bint lcfgpackage_add_context( LCFGPackageStruct * pkg, const char * extra )

    bint lcfgpackage_has_derivation( const LCFGPackageStruct * pkg )
    ssize_t lcfgpackage_get_derivation_as_string(const LCFGPackageStruct * pkg,
                                                 LCFGOption options,
                                                 char ** result, size_t * size )
    bint lcfgpackage_set_derivation_as_string( LCFGPackageStruct * pkg,
                                               const char * new_value )
    bint lcfgpackage_add_derivation_string( LCFGPackageStruct * pkg,
                                            const char * extra_deriv )
    bint lcfgpackage_add_derivation_file_line( LCFGPackageStruct * res, const char * filename, unsigned int linenum )

    bint lcfgpackage_valid_category( const char * category )
    bint lcfgpackage_has_category( const LCFGPackageStruct * pkg )
    const char * lcfgpackage_get_category( const LCFGPackageStruct * pkg )
    bint lcfgpackage_set_category( LCFGPackageStruct * pkg, char * new_value )

    int lcfgpackage_get_priority( const LCFGPackageStruct * pkg )
    bint lcfgpackage_set_priority( LCFGPackageStruct * pkg, int priority )
    bint lcfgpackage_is_active( const LCFGPackageStruct * pkg )

    ssize_t lcfgpackage_to_string( const LCFGPackageStruct * pkg,
                                   const char * defarch,
                                   LCFGPkgStyle style, LCFGOption options,
                                   char ** result, size_t * size )

    LCFGStatus lcfgpackage_from_spec( const char * input,
                                      LCFGPackageStruct ** result,
                                      char ** msg)

    LCFGStatus lcfgpackage_from_rpm_filename( const char * input,
                                              LCFGPackageStruct ** result,
                                              char ** msg)

    bint lcfgpackage_is_valid( const LCFGPackageStruct * pkg )

    char * lcfgpackage_id( const LCFGPackageStruct * pkg )

    int lcfgpackage_compare_names( const LCFGPackageStruct * pkg1,
                                   const LCFGPackageStruct * pkg2 );
    int lcfgpackage_compare_versions( const LCFGPackageStruct * pkg1,
                                      const LCFGPackageStruct * pkg2 );
    int lcfgpackage_compare_archs( const LCFGPackageStruct * pkg1,
                                   const LCFGPackageStruct * pkg2 );
    bint lcfgpackage_same_context( const LCFGPackageStruct * pkg1,
                                   const LCFGPackageStruct * pkg2 );
    int lcfgpackage_compare( const LCFGPackageStruct * pkg1,
                             const LCFGPackageStruct * pkg2 )
    bint lcfgpackage_equals( const LCFGPackageStruct * pkg1,
                             const LCFGPackageStruct * pkg2 )

    const char * default_architecture()
    int compare_vstrings( const char * v1, const char * v2 )

    bint lcfgpackage_valid_name( const char * name )
    bint lcfgpackage_valid_arch( const char * arch )
    bint lcfgpackage_valid_version( const char * version )
    bint lcfgpackage_valid_release( const char * release )
    bint lcfgpackage_valid_prefix( char prefix )
    bint lcfgpackage_valid_flag_chr( const char flag )
    bint lcfgpackage_valid_flags( const char * flag )
    bint lcfgpackage_valid_context( const char * expr )
    bint lcfgpackage_valid_category( const char * category )

    char * lcfgpackage_build_message( const LCFGPackageStruct * pkg,
                                      const char *fmt, ... )

    LCFGPackageListStruct * lcfgpkglist_new()
    void lcfgpkglist_acquire( LCFGPackageListStruct * pkglist );
    void lcfgpkglist_relinquish( LCFGPackageListStruct * pkglist )

    unsigned int lcfgpkglist_size(const LCFGPackageListStruct * pkglist )
    bint lcfgpkglist_is_empty(const LCFGPackageListStruct * pkglist )

    LCFGMergeRule lcfgpkglist_get_merge_rules( const LCFGPackageListStruct * pkglist );

    bint lcfgpkglist_set_merge_rules( LCFGPackageListStruct * pkglist, LCFGMergeRule new_rules )

    LCFGChange lcfgpkglist_merge_package( LCFGPackageListStruct * pkglist, LCFGPackageStruct * pkg, char ** msg )

    LCFGChange lcfgpkglist_merge_list( LCFGPackageListStruct * pkglist1, const LCFGPackageListStruct * pkglist2, char ** msg )

    bint lcfgpkglist_has_package( const LCFGPackageListStruct * pkglist, const char * name, const char * arch )

    LCFGPackageStruct * lcfgpkglist_first_package( const LCFGPackageListStruct * pkglist )

    LCFGPackageStruct * lcfgpkglist_find_package( const LCFGPackageListStruct * pkglist, const char * name, const char * arch )

    LCFGPackageListStruct * lcfgpkglist_match( const LCFGPackageListStruct * pkglist, const char * name, const char * arch, const char * ver, const char * rel )

    void lcfgpkglist_sort( LCFGPackageListStruct * pkglist )

    LCFGChange lcfgpkglist_from_pkgsfile( const char * filename,
                                          LCFGPackageListStruct ** result,
                                          const char * defarch,
                                          const char * macros_file,
                                          char ** incpath,
                                          LCFGOption options,
			                     	      char *** deps,
                                          char ** msg )

    LCFGChange lcfgpkglist_from_rpmcfg( const char * filename,
                                        LCFGPackageListStruct ** result,
                                        const char * defarch,
                                        LCFGOption options,
                                        char ** msg )

    LCFGChange lcfgpkglist_from_debian_index( const char * filename, LCFGPackageListStruct ** result, LCFGOption options, char ** msg )

    LCFGChange lcfgpkglist_from_rpm_dir( const char * rpmdir, LCFGPackageListStruct ** result, char ** msg )

    LCFGChange lcfgpkglist_from_rpmlist( const char * filename, LCFGPackageListStruct ** result, LCFGOption options, char ** msg )

    bint lcfgpkglist_print( const LCFGPackageListStruct * pkglist,
                            const char * defarch,
                            const char * base,
                            LCFGPkgStyle style,
                            LCFGOption options,
                            FILE * out )

    LCFGChange lcfgpkglist_to_rpmlist( LCFGPackageListStruct * pkglist,
                                       const char * defarch,
                                       const char * base,
                                       const char * filename,
                                       time_t mtime,
                                       char ** msg )

    LCFGChange lcfgpkglist_to_rpmcfg( LCFGPackageListStruct * active,
                                      LCFGPackageListStruct * inactive,
                                      const char * defarch,
                                      const char * filename,
                                      const char * rpminc,
                                      time_t mtime,
                                      char ** msg )

    LCFGPackageIteratorStruct * lcfgpkgiter_new( LCFGPackageListStruct * pkgs )
    void lcfgpkgiter_destroy( LCFGPackageIteratorStruct * iterator )
    void lcfgpkgiter_reset( LCFGPackageIteratorStruct * iterator )
    bint lcfgpkgiter_has_next( LCFGPackageIteratorStruct * iterator )
    LCFGPackageStruct * lcfgpkgiter_next(LCFGPackageIteratorStruct * iterator)
