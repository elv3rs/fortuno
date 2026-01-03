! This file is part of Fortuno.
! Licensed under the BSD-2-Clause Plus Patent license.
! SPDX-License-Identifier: BSD-2-Clause-Patent

module test_junitxmllogger
  use fortuno_junitxmllogger, only : junit_xml_logger
  use fortuno_serial, only : check => serial_check, test => serial_case_item,&
      & suite => serial_suite_item, test_list, is_equal
  use fortuno_testinfo, only : drive_result, init_drive_result, test_result, teststatus,&
      & init_failure_location
  implicit none

  private
  public :: tests

contains

  subroutine test_simple_output()
    type(junit_xml_logger) :: logger
    type(drive_result) :: dres
    character(len=:), allocatable :: content
    integer :: u
    character(len=20) :: filename = "junit_test.xml"
    
    call init_drive_result(dres, 0, 2)
    
    dres%teststats(teststatus%succeeded) = 1
    dres%teststats(teststatus%failed) = 1
    dres%testresults(1)%reprname = "suite1.test1"
    dres%testresults(1)%status = teststatus%succeeded
    dres%testresults(1)%name = "test1"
    
    dres%testresults(2)%reprname = "suite1.test2"
    dres%testresults(2)%status = teststatus%failed
    dres%testresults(2)%name = "test2"
    allocate(dres%testresults(2)%failureinfo)
    dres%testresults(2)%failureinfo%message = "Something failed"
    allocate(dres%testresults(2)%failureinfo%location)
    call init_failure_location(dres%testresults(2)%failureinfo%location, 1, "test.f90", 123)

    logger%filename = filename
    call logger%log_drive_result(dres)
    
    ! Read back and verify
    ! open(newunit=u, file=filename, action='read', status='old')
    ! read(u, '(a)', iostat=u) ! just read content roughly
    
    ! We can't easily read full file content into string in standard Fortran without knowing size.
    ! But we can read line by line or check existence.
    ! For now, let's just assume if it runs without error it works, and maybe check a few lines.
    
    call check(file_contains(filename, '<testsuite name="(root)"'))
    call check(file_contains(filename, '<testcase name="suite1.test1"'))
    call check(file_contains(filename, '<failure message="Something failed">'))
    call check(file_contains(filename, 'File: test.f90 (line 123)'))

    ! close(u)
    ! Cleanup
    ! call execute_command_line("rm " // filename) ! optional

  end subroutine test_simple_output
  
  subroutine test_slash_output()
    type(junit_xml_logger) :: logger
    type(drive_result) :: dres
    character(len=20) :: filename = "junit_slash.xml"
    
    call init_drive_result(dres, 0, 1)
    dres%teststats(teststatus%succeeded) = 1
    dres%testresults(1)%reprname = "parent/child"
    dres%testresults(1)%status = teststatus%succeeded
    dres%testresults(1)%name = "child"
    
    logger%filename = filename
    call logger%log_drive_result(dres)
    
    call check(file_contains(filename, '<testsuite name="parent"'))
    call check(file_contains(filename, '<testcase name="child"'))
  end subroutine test_slash_output


  logical function file_contains(filename, snippet)
    character(*), intent(in) :: filename, snippet
    integer :: u, iostat, size
    character(:), allocatable :: content
    
    file_contains = .false.
    open(newunit=u, file=filename, status='old', action='read', access='stream')
    inquire(unit=u, size=size)
    allocate(character(size) :: content)
    read(u) content
    close(u)
    
    if (index(content, snippet) > 0) then
      file_contains = .true.
    end if
  end function file_contains


  function tests()
    type(test_list) :: tests

    tests = test_list([&
        suite("junitxmllogger", test_list([&
            test("simple_output", test_simple_output),&
            test("slash_output", test_slash_output)&
        ]))&
    ])

  end function tests

end module test_junitxmllogger
