# JUnit XML Reporter Implementation Plan

## Goal
Add support for generating JUnit XML test reports in Fortuno.

## Steps

1.  **Create `multi_logger` Module**
    *   **File:** `src/fortuno/multilogger.f90`
    *   **Description:** A logger that delegates calls to a list of other loggers.
    *   **Implementation:**
        *   Extend `test_logger`.
        *   Hold `class(test_logger), allocatable :: loggers(:)`.
        *   Implement all deferred procedures of `test_logger` by iterating over `loggers`.
        *   Add a subroutine `add_logger(logger)` to append to the list.

2.  **Create `junit_xml_logger` Module**
    *   **File:** `src/fortuno/junitxmllogger.f90`
    *   **Description:** A logger that writes test results to a file in JUnit XML format.
    *   **Implementation:**
        *   Extend `test_logger`.
        *   Constructor takes a filename.
        *   Main logic in `log_drive_result` (since it has the full summary).
        *   Use `drive_result` to generate `<testsuites>` and `<testsuite>`.
        *   Group tests by suite (using `reprname` or available structure).
        *   Output XML using standard Fortran I/O.
        *   Handle XML escaping for messages.
        *   Map Fortuno status (succeeded, failed, skipped, ignored, notrun) to JUnit status (`<failure>`, `<error>`, `<skipped>`).

3.  **Integrate into `cmd_app`**
    *   **File:** `src/fortuno/cmdapp.f90`
    *   **Modifications:**
        *   Add `--junit <file>` to `default_argument_defs`.
        *   In `cmd_app_run_tests` (or appropriate place after arg parsing):
            *   Check if `--junit` is present.
            *   If yes, create `multi_logger`.
            *   Add existing `this%logger`.
            *   Create `junit_xml_logger` with the specified filename.
            *   Add `junit_xml_logger`.
            *   Set `this%logger` to the `multi_logger`.

4.  **Register New Modules**
    *   **File:** `src/fortuno/CMakeLists.txt` (and `meson.build` if applicable)
    *   **Action:** Add new files to the build system.

5.  **Verification**
    *   Run tests with `--junit out.xml`.
    *   Inspect `out.xml`.
