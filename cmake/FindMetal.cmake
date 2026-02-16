if(APPLE)
    find_library(METAL_FRAMEWORK Metal)
    find_library(FOUNDATION_FRAMEWORK Foundation)
    find_library(QUARTZCORE_FRAMEWORK QuartzCore)

    if(METAL_FRAMEWORK)
        add_library(Metal::Metal INTERFACE IMPORTED)
        set_target_properties(Metal::Metal PROPERTIES
            INTERFACE_LINK_LIBRARIES
            "${METAL_FRAMEWORK};${FOUNDATION_FRAMEWORK};${QUARTZCORE_FRAMEWORK}")
        set(Metal_FOUND TRUE)
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Metal DEFAULT_MSG METAL_FRAMEWORK)
