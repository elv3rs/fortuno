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


function(fortuno_register_tests target)
# Usage:
# fortuno_register_tests 
    if(NOT TARGET ${target})
        message(FATAL_ERROR "fortuno_register_tests: target '${target}' does not exist")
    endif()
    
    # Parse arguments and apply defaults
    cmake_parse_arguments(ARG "USE_PRE_TEST_DISCOVERY" "TEST_PREFIX;TEST_SUFFIX;TEST_PATTERN;WORKING_DIRECTORY" "" ${ARGN})

    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "fortuno_register_tests: Unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()

    if(NOT DEFINED ARG_WORKING_DIRECTORY)
        set(ARG_WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")
    endif()


    set(discovery_script "${CMAKE_CURRENT_BINARY_DIR}/discover_tests_${target}_.cmake")
    set(testlist_file "${CMAKE_CURRENT_BINARY_DIR}/testlist_${target}.cmake")

    if(ARG_USE_PRE_TEST_DISCOVERY)
        # Ctest runs discovery -> adds tests -> runs tests
        set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILES "${discovery_script}")
    else()
        # (Post) Build runs discovery -> generates testlist.cmake -> CTest includes testlist
        add_custom_command(
            TARGET ${target} 
            POST_BUILD
            COMMAND ${CMAKE_COMMAND} -P "${discovery_script}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
            BYPRODUCTS "${testlist_file}"
            VERBATIM
        )
        # Add a placeholder incase someone skips the build step
        if(NOT EXISTS "${testlist_file}")
            file(WRITE "${testlist_file}" "# Build the project to populate this file.\nadd_test(ERR_RUN_BUILD_FIRST \"${target}\")\n")
        endif()

        # Point ctest to the generated list
        set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILES "${testlist_file}")
    endif()
    
    # Generate the discovery script at generation time to resolve $<TARGET_FILE:...>.
    # This script will be run at build time (default) or test time (USE_PRE_TEST_DISCOVERY)
    # discover and either directly add or generate a testlist.cmake file.
    file(GENERATE OUTPUT "${discovery_script}" CONTENT "
# Auto-generated test discovery script for ${target}
cmake_policy(PUSH)
cmake_policy(SET CMP0012 NEW) # Enable bools
set(working_dir \"${ARG_WORKING_DIRECTORY}\")
set(test_prefix \"${ARG_TEST_PREFIX}\")
set(test_suffix \"${ARG_TEST_SUFFIX}\")
set(test_executable \"$<TARGET_FILE:${target}>\")
set(cross_emulator $<TARGET_PROPERTY:${target},CROSSCOMPILING_EMULATOR>)

set(discover_command \${cross_emulator} \"\${test_executable}\" --list ${ARG_TEST_PATTERN})

# Query Fortuno executable for tests
if(NOT EXISTS \"\${test_executable}\")
    message(WARNING \"Could not find test executable: \${test_executable}. (Have you built the project?) Skipping test discovery.\")
    cmake_policy(POP)
    return()
endif()

execute_process(
    COMMAND \${discover_command}
    OUTPUT_VARIABLE output_string
    ERROR_VARIABLE error_string
    RESULT_VARIABLE returncode
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(returncode)
    message(FATAL_ERROR \"Test discovery failed for ${target}, \${discover_command} returned \${returncode}.\\nOutput:\\n\${error_string}\")
    cmake_policy(POP)
    return()
endif()

# Convert newlines to CMake semicolon list
string(REGEX REPLACE \"(\\r\\n|\\n)\" \";\" testlist \"\${output_string}\")

# Notify user if no tests found (e.q. due to bad pattern)
if(testlist STREQUAL \"\")
    message(WARNING \"No tests found for ${target} with pattern '${ARG_TEST_PATTERN}'.\")
    cmake_policy(POP)
    return()
endif()

if(${ARG_USE_PRE_TEST_DISCOVERY})
    message(STATUS \"Registering \${testlist} tests for ${target} (PRE_TEST discovery mode)...\")
else()
    file(WRITE \"${testlist_file}\" \"# Auto-generated test list for ${target} (POST_BUILD discovery mode)\\n\")
endif()


# Actually register each test
foreach(test_name IN LISTS testlist)
    set(ctest_name \"\${test_prefix}\${test_name}\${test_suffix}\")
    set(test_command \${cross_emulator} \"\${test_executable}\" \"\${test_name}\" --fail-on-missing-test)

    # Either write tests to file, or add directly
    if(${ARG_USE_PRE_TEST_DISCOVERY})
        add_test(\"\${ctest_name}\" \${test_command})
        set_tests_properties(\"\${ctest_name}\" PROPERTIES WORKING_DIRECTORY \"\${working_dir}\")
    else()
        file(APPEND \"${testlist_file}\" \"add_test(\\\"\${ctest_name}\\\" \${test_command})\\n\")
        file(APPEND \"${testlist_file}\" \"set_tests_properties(\\\"\${ctest_name}\\\" PROPERTIES WORKING_DIRECTORY \\\"\${working_dir}\\\")\\n\")
    endif()
endforeach()
cmake_policy(POP)
    ") # end file(GENERATE)

endfunction()



fortuno_register_tests(fortuno_test_unit_testapp USE_PRE_TEST_DISCOVERY)
