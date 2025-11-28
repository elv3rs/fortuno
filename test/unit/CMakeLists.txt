# This file is part of Fortuno.
# Licensed under the BSD-2-Clause Plus Patent license.
# SPDX-License-Identifier: BSD-2-Clause-Patent

list(APPEND CMAKE_MESSAGE_CONTEXT Unit)

add_executable(fortuno_test_unit_testapp)
set_target_properties(
  fortuno_test_unit_testapp PROPERTIES
  OUTPUT_NAME testapp
)
target_sources(
  fortuno_test_unit_testapp PRIVATE
  test_checkers.f90
  testapp.f90
)
target_link_libraries(fortuno_test_unit_testapp PRIVATE Fortuno::fortuno_serial)


function(register_tests target)
  set(test_list_file "${CMAKE_CURRENT_BINARY_DIR}/testlist.cmake")
  set(test_executable "$<TARGET_FILE:${target}>")

  add_custom_command(
    TARGET ${target} POST_BUILD
    COMMAND "${test_executable}" --emit-cmake-testlist --cmake-outfile "${test_list_file}" --executable "${test_executable}"
    BYPRODUCTS "${test_list_file}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
  )
  
  # Point ctest to the new tests
  set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILE "${test_list_file}")
endfunction()


function(register_tests_unix target)
    # (This doesnt handle different paths for Debug/Release etc.)
    # Either always share paths, or add dispatch logic below.
    set(discovery_script "${CMAKE_CURRENT_BINARY_DIR}/${target}_discover.cmake")

    # Generate the discovery script at generation time to resolve $<TARGET_FILE:...>.
    file(GENERATE OUTPUT "${discovery_script}" CONTENT "
        execute_process(
            COMMAND \"$<TARGET_FILE:${target}>\" --list
            OUTPUT_VARIABLE output_string
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_VARIABLE TEST_ERROR
        )

        # Convert newlines to cmake semicolon list.
        string(REPLACE \"\\n\" \";\" test_list \"\${output_string}\")

        foreach(test_name IN LISTS test_list)
            add_test(
                \"${target}:\${test_name}\"
                \"$<TARGET_FILE:${target}>\" \"\${test_name}\"
            )
        endforeach()
    ")

    # Point ctest to the script that queries the executable (--list) and adds the test.
    set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILE "${discovery_script}")

endfunction()



#register_tests(fortuno_test_unit_testapp)

register_tests_unix(fortuno_test_unit_testapp)
