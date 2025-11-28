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
add_test(NAME unit COMMAND testapp)


set(test_list_file "${CMAKE_CURRENT_BINARY_DIR}/testlist.cmake")
set(test_executable "$<TARGET_FILE:fortuno_test_unit_testapp>")

add_custom_command(
    TARGET fortuno_test_unit_testapp POST_BUILD
    COMMAND "${test_executable}" --emit-cmake-testlist --cmake-outfile "${test_list_file}" --executable "${test_executable}"
    BYPRODUCTS "${test_list_file}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
)

set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILE "${test_list_file}")
