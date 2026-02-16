find_path(OpenColorIO_INCLUDE_DIR OpenColorIO/OpenColorIO.h)
find_library(OpenColorIO_LIBRARY NAMES OpenColorIO)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OpenColorIO DEFAULT_MSG
    OpenColorIO_INCLUDE_DIR OpenColorIO_LIBRARY)

if(OpenColorIO_FOUND)
    add_library(OpenColorIO::OpenColorIO UNKNOWN IMPORTED)
    set_target_properties(OpenColorIO::OpenColorIO PROPERTIES
        IMPORTED_LOCATION ${OpenColorIO_LIBRARY}
        INTERFACE_INCLUDE_DIRECTORIES ${OpenColorIO_INCLUDE_DIR})
endif()
