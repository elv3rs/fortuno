! This file is part of Fortuno.
! Licensed under the BSD-2-Clause Plus Patent license.
! SPDX-License-Identifier: BSD-2-Clause-Patent

!> Contains a logger that delegates to multiple other loggers
module fortuno_multilogger
  use fortuno_testlogger, only : test_logger
  use fortuno_testinfo, only : drive_result, test_result
  implicit none

  private
  public :: multi_logger


  !> Wrapper for polymorphic loggers
  type :: logger_wrapper
    class(test_logger), allocatable :: item
  end type logger_wrapper

  !> Logger that delegates to multiple other loggers
  type, extends(test_logger) :: multi_logger
    type(logger_wrapper), allocatable :: loggers(:)
  contains
    procedure :: add_logger => multi_logger_add_logger
    procedure :: log_message => multi_logger_log_message
    procedure :: log_error => multi_logger_log_error
    procedure :: start_drive => multi_logger_start_drive
    procedure :: end_drive => multi_logger_end_drive
    procedure :: start_tests => multi_logger_start_tests
    procedure :: end_tests => multi_logger_end_tests
    procedure :: log_test_result => multi_logger_log_test_result
    procedure :: log_drive_result => multi_logger_log_drive_result
  end type multi_logger

contains

  !> Adds a logger to the list
  subroutine multi_logger_add_logger(this, logger)
    class(multi_logger), intent(inout) :: this
    class(test_logger), intent(in) :: logger
    
    type(logger_wrapper), allocatable :: new_loggers(:)
    integer :: n, i

    if (allocated(this%loggers)) then
      n = size(this%loggers)
      allocate(new_loggers(n + 1))
      do i = 1, n
        call move_alloc(this%loggers(i)%item, new_loggers(i)%item)
      end do
      allocate(new_loggers(n + 1)%item, source=logger)
      call move_alloc(new_loggers, this%loggers)
    else
      allocate(this%loggers(1))
      allocate(this%loggers(1)%item, source=logger)
    end if

  end subroutine multi_logger_add_logger

  !> Logs a normal message
  subroutine multi_logger_log_message(this, message)
    class(multi_logger), intent(inout) :: this
    character(*), intent(in) :: message
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%log_message(message)
      end do
    end if
  end subroutine multi_logger_log_message

  !> Logs an error message
  subroutine multi_logger_log_error(this, message)
    class(multi_logger), intent(inout) :: this
    character(*), intent(in) :: message
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%log_error(message)
      end do
    end if
  end subroutine multi_logger_log_error

  !> Called when the test drive starts
  subroutine multi_logger_start_drive(this)
    class(multi_logger), intent(inout) :: this
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%start_drive()
      end do
    end if
  end subroutine multi_logger_start_drive

  !> Called when the test drive ended
  subroutine multi_logger_end_drive(this)
    class(multi_logger), intent(inout) :: this
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%end_drive()
      end do
    end if
  end subroutine multi_logger_end_drive

  !> Called immediately before the processing of the tests starts
  subroutine multi_logger_start_tests(this)
    class(multi_logger), intent(inout) :: this
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%start_tests()
      end do
    end if
  end subroutine multi_logger_start_tests

  !> Called after the processing of all tests had been finished
  subroutine multi_logger_end_tests(this)
    class(multi_logger), intent(inout) :: this
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%end_tests()
      end do
    end if
  end subroutine multi_logger_end_tests

  !> Logs the result of an individual test during processing
  subroutine multi_logger_log_test_result(this, testtype, testresult)
    class(multi_logger), intent(inout) :: this
    integer, intent(in) :: testtype
    type(test_result), intent(in) :: testresult
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%log_test_result(testtype, testresult)
      end do
    end if
  end subroutine multi_logger_log_test_result

  !> Logs the final detailed summary after all tests test drive has finished
  subroutine multi_logger_log_drive_result(this, driveresult)
    class(multi_logger), intent(inout) :: this
    type(drive_result), intent(in) :: driveresult
    integer :: i
    if (allocated(this%loggers)) then
      do i = 1, size(this%loggers)
        if (allocated(this%loggers(i)%item)) &
          call this%loggers(i)%item%log_drive_result(driveresult)
      end do
    end if
  end subroutine multi_logger_log_drive_result

end module fortuno_multilogger
