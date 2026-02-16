function(compile_metal_shaders TARGET SHADER_FILES)
    foreach(SHADER ${SHADER_FILES})
        get_filename_component(SHADER_NAME ${SHADER} NAME_WE)

        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${SHADER_NAME}.metallib
            COMMAND xcrun -sdk macosx metal ${SHADER} -o ${SHADER_NAME}.air
            COMMAND xcrun -sdk macosx metallib ${SHADER_NAME}.air -o ${SHADER_NAME}.metallib
            DEPENDS ${SHADER}
        )

        add_custom_target(${TARGET}_${SHADER_NAME} ALL
            DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${SHADER_NAME}.metallib)
    endforeach()
endfunction()
