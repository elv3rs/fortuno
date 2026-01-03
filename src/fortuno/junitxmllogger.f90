! This file is part of Fortuno.
! Licensed under the BSD-2-Clause Plus Patent license.
! SPDX-License-Identifier: BSD-2-Clause-Patent

!> Contains the implementation of the test logger for logging to JUnit XML
module fortuno_junitxmllogger
  use fortuno_testlogger, only : test_logger, testtypes
  use fortuno_testinfo, only : drive_result, test_result, teststatus, failure_info
  use fortuno_utils, only : str
  implicit none

  private
  public :: junit_xml_logger


  !> Implements a logger which logs to a JUnit XML file
  type, extends(test_logger) :: junit_xml_logger
    integer :: unit = -1
    character(:), allocatable :: filename
  contains
    procedure :: log_message => junit_xml_logger_log_message
    procedure :: log_error => junit_xml_logger_log_error
    procedure :: start_drive => junit_xml_logger_start_drive
    procedure :: end_drive => junit_xml_logger_end_drive
    procedure :: start_tests => junit_xml_logger_start_tests
    procedure :: end_tests => junit_xml_logger_end_tests
    procedure :: log_test_result => junit_xml_logger_log_test_result
    procedure :: log_drive_result => junit_xml_logger_log_drive_result
  end type junit_xml_logger

contains

  !> Logs a normal message (ignored for XML)
  subroutine junit_xml_logger_log_message(this, message)
    class(junit_xml_logger), intent(inout) :: this
    character(*), intent(in) :: message
  end subroutine junit_xml_logger_log_message


  !> Logs an error message (ignored for XML)
  subroutine junit_xml_logger_log_error(this, message)
    class(junit_xml_logger), intent(inout) :: this
    character(*), intent(in) :: message
  end subroutine junit_xml_logger_log_error


  !> Starts the logging
  subroutine junit_xml_logger_start_drive(this)
    class(junit_xml_logger), intent(inout) :: this
    ! File is opened in log_drive_result or constructor? 
    ! Better to open here or in constructor. 
    ! Since we don't have a constructor, we rely on the caller to set filename.
    ! But we can't open here easily if we want to write everything at the end.
    ! log_drive_result does the main work.
  end subroutine junit_xml_logger_start_drive


  !> Ends the logging
  subroutine junit_xml_logger_end_drive(this)
    class(junit_xml_logger), intent(inout) :: this
  end subroutine junit_xml_logger_end_drive


  !> Starts the processing log
  subroutine junit_xml_logger_start_tests(this)
    class(junit_xml_logger), intent(inout) :: this
  end subroutine junit_xml_logger_start_tests


  !> Ends processing log
  subroutine junit_xml_logger_end_tests(this)
    class(junit_xml_logger), intent(inout) :: this
  end subroutine junit_xml_logger_end_tests


  !> Logs the result of an individual test during processing
  subroutine junit_xml_logger_log_test_result(this, testtype, testresult)
    class(junit_xml_logger), intent(inout) :: this
    integer, intent(in) :: testtype
    type(test_result), intent(in) :: testresult
    ! We don't stream results to XML, we wait for the full result.
  end subroutine junit_xml_logger_log_test_result


  !> Logs the final detailed summary after all tests had been run
  subroutine junit_xml_logger_log_drive_result(this, driveresult)
    class(junit_xml_logger), intent(inout) :: this
    type(drive_result), intent(in) :: driveresult

    integer :: i, j, k, ntests
    integer, allocatable :: idx(:)
    character(:), allocatable :: current_suite, suite_name, case_name
    integer :: suite_tests, suite_failures, suite_errors, suite_skipped
    integer :: total_tests, total_failures, total_errors, total_skipped
    logical :: new_suite
    
    if (.not. allocated(this%filename)) return
    
    open(newunit=this%unit, file=this%filename, status='replace', action='write')
    
    total_tests = sum(driveresult%teststats)
    total_failures = driveresult%teststats(teststatus%failed)
    total_errors = 0 ! Fortuno doesn't distinguish error vs failure clearly in stats?
    ! Actually teststatus%failed usually covers both.
    ! teststatus%ignored could be skipped.
    total_skipped = driveresult%teststats(teststatus%skipped) + driveresult%teststats(teststatus%ignored)

    write(this%unit, '(a)') '<?xml version="1.0" encoding="UTF-8"?>'
    write(this%unit, '(a,i0,a,i0,a,i0,a,i0,a)') '<testsuites tests="', total_tests, &
         '" failures="', total_failures, &
         '" errors="0" skipped="', total_skipped, &
         '" time="0.0">'

    ntests = size(driveresult%testresults)
    if (ntests > 0) then
      allocate(idx(ntests))
      do i = 1, ntests
        idx(i) = i
      end do
      
      ! Sort indices by suite name
      call sort_indices(idx, driveresult%testresults)
      
      i = 1
      do while (i <= ntests)
        call split_name(driveresult%testresults(idx(i))%reprname, current_suite, case_name)
        
        ! Count suite stats
        suite_tests = 0
        suite_failures = 0
        suite_errors = 0
        suite_skipped = 0
        
        j = i
        do while (j <= ntests)
          call split_name(driveresult%testresults(idx(j))%reprname, suite_name, case_name)
          if (suite_name /= current_suite) exit
          
          suite_tests = suite_tests + 1
          select case (driveresult%testresults(idx(j))%status)
          case (teststatus%failed)
            suite_failures = suite_failures + 1
          case (teststatus%skipped, teststatus%ignored)
            suite_skipped = suite_skipped + 1
          end select
          
          j = j + 1
        end do
        
        write(this%unit, '(a,a,a,i0,a,i0,a,i0,a,i0,a)') '  <testsuite name="', escape_xml(current_suite), &
             '" tests="', suite_tests, &
             '" failures="', suite_failures, &
             '" errors="0" skipped="', suite_skipped, &
             '" time="0.0">'
             
        ! Write test cases
        do k = i, j - 1
          call write_testcase(this%unit, driveresult%testresults(idx(k)))
        end do
        
        write(this%unit, '(a)') '  </testsuite>'
        
        i = j
      end do
      deallocate(idx)
    end if
    
    write(this%unit, '(a)') '</testsuites>'
    close(this%unit)

  end subroutine junit_xml_logger_log_drive_result
  
  
  subroutine write_testcase(unit, res)
    integer, intent(in) :: unit
    type(test_result), intent(in) :: res
    
    character(:), allocatable :: suite_name, case_name, msg, details_str
    
    call split_name(res%reprname, suite_name, case_name)
    
    write(unit, '(a,a,a,a,a)', advance='no') '    <testcase name="', escape_xml(case_name), &
         '" classname="', escape_xml(suite_name), '" time="0.0"'
         
    select case (res%status)
    case (teststatus%succeeded)
      write(unit, '(a)') ' />'
    case (teststatus%skipped, teststatus%ignored)
      write(unit, '(a)') '>'
      write(unit, '(a)') '      <skipped/>'
      write(unit, '(a)') '    </testcase>'
    case (teststatus%failed)
      write(unit, '(a)') '>'
      msg = ""
      if (allocated(res%failureinfo%message)) msg = res%failureinfo%message
      ! Try to get details
      details_str = ""
      if (allocated(res%failureinfo%details)) details_str = res%failureinfo%details%as_string()
      
      write(unit, '(a,a,a)') '      <failure message="', escape_xml(msg), '">'
      if (len(details_str) > 0) then
         write(unit, '(a)') escape_xml(details_str)
      end if
      if (allocated(res%failureinfo%location)) then
         write(unit, '(a)') escape_xml(res%failureinfo%location%as_string())
      end if
      write(unit, '(a)') '      </failure>'
      write(unit, '(a)') '    </testcase>'
    case default
       ! Treat as passed or error? Notrun should not happen here ideally
       write(unit, '(a)') ' />'
    end select
    
  end subroutine write_testcase


  subroutine sort_indices(idx, results)
    integer, intent(inout) :: idx(:)
    type(test_result), intent(in) :: results(:)
    
    integer :: i, j, temp
    character(:), allocatable :: name1, name2, suite1, suite2, case1, case2
    
    ! Simple insertion sort (stable)
    do i = 2, size(idx)
      temp = idx(i)
      call split_name(results(temp)%reprname, suite1, case1)
      
      j = i - 1
      do while (j >= 1)
        call split_name(results(idx(j))%reprname, suite2, case2)
        if (suite2 <= suite1) exit
        idx(j + 1) = idx(j)
        j = j - 1
      end do
      idx(j + 1) = temp
    end do
  end subroutine sort_indices
  
  
  subroutine split_name(full_name, suite, case)
    character(*), intent(in) :: full_name
    character(:), allocatable, intent(out) :: suite, case
    integer :: i, last_dot
    
    last_dot = 0
    do i = 1, len(full_name)
      if (full_name(i:i) == '/') last_dot = i
    end do
    
    if (last_dot > 0) then
      suite = full_name(1:last_dot-1)
      case = full_name(last_dot+1:)
    else
      suite = "(root)"
      case = full_name
    end if
  end subroutine split_name


  function escape_xml(str) result(escaped)
    character(*), intent(in) :: str
    character(:), allocatable :: escaped
    integer :: i
    character(1) :: c
    
    escaped = ""
    do i = 1, len(str)
      c = str(i:i)
      select case (c)
      case ('<')
        escaped = escaped // "&lt;"
      case ('>')
        escaped = escaped // "&gt;"
      case ('&')
        escaped = escaped // "&amp;"
      case ('"')
        escaped = escaped // "&quot;"
      case ("'")
        escaped = escaped // "&apos;"
      case default
        escaped = escaped // c
      end select
    end do
  end function escape_xml

end module fortuno_junitxmllogger
