! This file is part of Fortuno.
! Licensed under the BSD-2-Clause Plus Patent license.
! SPDX-License-Identifier: BSD-2-Clause-Patent

!> Contains common code used by the various command line apps
module fortuno_cmdapp
  use fortuno_argumentparser, only : argtypes, argument_def, argument_values, argument_parser,&
      & init_argument_parser
  use fortuno_basetypes, only : error_info, test_list
  use fortuno_utils, only : string_item
  use fortuno_testdriver, only : test_driver, test_selection
  use fortuno_testinfo, only : teststatus
  use fortuno_testlogger, only : test_logger
  implicit none

  private
  public :: cmd_app
  public :: get_selections
  public :: default_argument_defs


  !> App for driving tests through command line interface app
  type :: cmd_app
    class(test_logger), allocatable :: logger
    class(test_driver), allocatable :: driver
    type(argument_values) :: argvals
  contains
    procedure :: run => cmd_app_run
    procedure :: parse_args => cmd_app_parse_args
    procedure :: register_tests => cmd_app_register_tests
    procedure :: run_tests => cmd_app_run_tests
  end type cmd_app


contains

  !> Runs the command line interface app (calls parse_args(), register_tests() and run_tests())
  subroutine cmd_app_run(this, tests, exitcode)

    !> Instance
    class(cmd_app), intent(inout) :: this

    !> Test items to be considered by the app
    type(test_list), intent(in) :: tests

    !> Exit code of the run
    integer, intent(out) :: exitcode

    call this%parse_args(exitcode)
    if (exitcode >= 0) return
    call this%register_tests(tests, exitcode)
    if (exitcode >= 0) return
    call this%run_tests(exitcode)

  end subroutine cmd_app_run


  !> Parses the command line arguments
  subroutine cmd_app_parse_args(this, exitcode)

    !> Instance
    class(cmd_app), intent(inout) :: this

    !> Exit code (-1 if processing can continue, >=0 if program should stop with that exit code)
    integer, intent(out) :: exitcode

    type(argument_parser) :: argparser

    call init_argument_parser(argparser,&
        & description="Command line app for driving Fortuno unit tests.",&
        & argdefs=default_argument_defs()&
        & )
    call argparser%parse_args(this%argvals, this%logger, exitcode)

  end subroutine cmd_app_parse_args


  !> Register all tests which should be considered
  subroutine cmd_app_register_tests(this, testitems, exitcode)

    !> Initialized instance on exit
    class(cmd_app), intent(inout) :: this

    !> Items to be considered by the app
    type(test_list), intent(in) :: testitems

    !> Exit code (-1, if processing can continue, >= 0 otherwise)
    integer, intent(out) :: exitcode

    type(test_selection), allocatable :: selections(:)
    type(string_item), allocatable :: selectors(:), testnames(:)
    type(error_info), allocatable :: error
    integer :: itest

    exitcode = -1
    if (this%argvals%has("tests")) then
      call this%argvals%get_value("tests", selectors, error)
      if (allocated(error)) then
        call this%logger%log_error("internal error  " // error%msg)
        exitcode = error%code
        return
      end if
      call get_selections(selectors, selections)
    end if
    call this%driver%register_tests(testitems, selections=selections)

    if (this%argvals%has("list")) then
      call this%driver%get_test_names(testnames)
      do itest = 1, size(testnames)
        call this%logger%log_message(testnames(itest)%value)
      end do
      exitcode = 0
      return
    end if

    if (this%argvals%has("emit-cmake-testlist")) then
      exitcode = 0
      call cmd_app_emit_cmake_testlist(this, testitems, exitcode)
      return
    end if


  end subroutine cmd_app_register_tests

  !> Emit test list cmake.
  subroutine cmd_app_emit_cmake_testlist(this, testitems, exitcode)

    !> Initialized instance on exit
    class(cmd_app), intent(inout) :: this

    !> Items to be considered by the app
    type(test_list), intent(in) :: testitems

    !> Exit code (-1, if processing can continue, >= 0 otherwise)
    integer, intent(out) :: exitcode

    character(:), allocatable :: line, testname, executable, output_path

    type(string_item), allocatable :: testnames(:)
    type(string_item), allocatable :: tmp
    integer :: itest, f, iostat, ii

    if (this%argvals%has("executable")) then
      call this%argvals%get_value_string("executable", tmp)
      executable = trim(tmp%value)
    else
      executable = "./testapp"
      call this%logger%log_message("No executable specified for cmake test list,&
          & defaulting to '" // executable // "'." )
    end if

    if (this%argvals%has("cmake-outfile")) then
      call this%argvals%get_value("cmake-outfile", tmp)
      output_path = trim(tmp%value)
    else
      output_path = "testlist.cmake"
      call this%logger%log_message("No output file specified for cmake test list,&
          & defaulting to '" // output_path // "'." )
    end if


    call this%driver%get_test_names(testnames)

    open(newunit=f, file=output_path, status='replace', action='write', iostat=iostat)

    if (iostat /= 0) then
        print *, "Error: Could not open file '", output_path, "' for writing."
        return 
    end if

    write(f, '(a)') "# CMake test list generated by Fortuno."

    do itest = 1, size(testnames)
      testname = trim(testnames(itest)%value)
      ! Replace slashes with underscores
      !do ii = 1, len(testname)
      !  if (testname(ii:ii) == "/") then
      !    testname(ii:ii) = "_"
      !  end if
      !end do


      write(f, '(a)') "add_test("
      write(f, '(a)') "    NAME " // testname
      write(f, '(a)') "    COMMAND " // executable // " " // testname // " --fail-on-missing-test"
      write(f, '(a)') ")"
    end do

    close(f)

    call this%logger%log_message("Wrote cmake test list to " // output_path)

  end subroutine cmd_app_emit_cmake_testlist


  !> Runs the initialized app
  subroutine cmd_app_run_tests(this, exitcode)

    !> Instance
    class(cmd_app), intent(inout) :: this

    !> Exit code of the test run (0 - success, 1 - failure)
    integer, intent(out) :: exitcode

    logical :: should_run_tests, did_run_tests

    call this%driver%run_tests(this%logger)

    should_run_tests = this%argvals%has("fail-on-missing-test") 
    did_run_tests = this%driver%driveresult%teststats(teststatus%succeeded) > 0

    if (.not. this%driver%driveresult%successful) then
      exitcode = 1
    else if (should_run_tests .and. .not. did_run_tests) then
      call this%logger%log_message("Error: No tests ran, but --fail-on-missing-test specified.")
      exitcode = 1
    else
      exitcode = 0
    end if

  end subroutine cmd_app_run_tests


  !> Converts test selector expressions to test selections
  subroutine get_selections(selectors, selections)

    !> Selector expressions
    type(string_item), intent(in) :: selectors(:)

    !> Array of selections on exit
    type(test_selection), allocatable, intent(out) :: selections(:)

    integer :: ii

    allocate(selections(size(selectors)))
    do ii = 1, size(selectors)
      associate(selector => selectors(ii)%value, selection => selections(ii))
        if (selector(1:1) == "~") then
          selection%name = selector(2:)
          selection%selectiontype = "-"
        else
          selection%name = selector
          selection%selectiontype = "+"
        end if
      end associate
    end do

  end subroutine get_selections


  !> Returns the default argument definitions for the command line apps
  function default_argument_defs() result(argdefs)

    !> Argument defintions
    type(argument_def), allocatable :: argdefs(:)

    ! Workaround:gfortran:14.1 (bug 116679)
    ! Omit array expression to avoid memory leak
    ! {-
    ! argdefs = [&
    !     & &
    !     & argument_def("list", argtypes%bool, shortopt="l", longopt="list",&
    !     & helpmsg="show list of tests to run and exit"),&
    !     & &
    !     & argument_def("tests", argtypes%stringlist,&
    !     & helpmsg="list of tests and suites to include or to exclude when prefixed with '~' (e.g.&
    !     & 'somesuite ~somesuite/avoidedtest' would run all tests except 'avoidedtest' in the test&
    !     & suite 'somesuite')")&
    !     & &
    !     & ]
    ! -}{+
    allocate(argdefs(6))
    argdefs(1) =  argument_def("list", argtypes%bool, shortopt="l", longopt="list",&
        & helpmsg="show list of tests to run and exit")
    argdefs(2) = argument_def("fail-on-missing-test", argtypes%bool, &
        & longopt="fail-on-missing-test",&
        & helpmsg="Return nonzero status code if the requested test doesnt exist.")
    argdefs(3) =  argument_def("emit-cmake-testlist", argtypes%bool, &
        & longopt="emit-cmake-testlist",&
        & helpmsg="Generate a cmake file with individual add_test(...) entries.")
    argdefs(4) =  argument_def("cmake-outfile", argtypes%string, &
        & longopt="cmake-outfile",&
        & helpmsg="Target file to write when using --emit-cmake-testlist. Defaults to 'testlist.cmake'.")
    argdefs(5) =  argument_def("executable", argtypes%string, &
        & longopt="executable",&
        & helpmsg="Executable path to include in the cmake add_test(...) entries. Defaults to './testapp'.")
    argdefs(6) = argument_def("tests", argtypes%stringlist,&
        & helpmsg="list of tests and suites to include or to exclude when prefixed with '~' (e.g.&
        & 'somesuite ~somesuite/avoidedtest' would run all tests except 'avoidedtest' in the test&
        & suite 'somesuite')")
    ! +}

  end function default_argument_defs

end module fortuno_cmdapp
