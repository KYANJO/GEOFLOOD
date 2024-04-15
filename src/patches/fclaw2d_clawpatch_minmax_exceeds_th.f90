!> @file
!! check to see if value exceeds threshold

!  --------------------------------------------------------------
!> @brief Check if the difference between min and max 
!! exceeds the threshold
!!
!! @param[in] blockno the block number
!! @param[in] qval the 
!! @param[in] qmin the minimum q value
!! @param[in] qmax the maximum q value
!! @param[in] quad the value and adjacent values of q
!! @param[in] dx, dy the spacing in the x and y directions
!! @param[in] xc, yc the coordinate of the cell
!! @param[in] threshold the threshold
!! @param[in] init_flag true if in init stage
!! @param[in] is_ghost true if cell is a ghost cell
!! @return 1 if exceeds threshold, 0 if not, -1 if inconclusive.
!  --------------------------------------------------------------
integer function fclaw2d_clawpatch_minmax_exceeds_th(blockno,meqn, & 
                                     qval,qmin,qmax,quad, & 
                                     dx,dy,xc,yc,ivar_threshold, & 
                                     threshold, init_flag, is_ghost)
    implicit none
    
    integer :: meqn
    double precision :: qval(meqn),qmin(meqn),qmax(meqn),threshold
    double precision :: quad(-1:1,-1:1,meqn)
    double precision :: dx,dy, xc, yc
    integer :: blockno, init_flag
    integer :: ivar_threshold
    logical(kind=4) :: is_ghost

    integer :: refine
    integer :: mq

    mq = ivar_threshold

    refine = 0

    if (qmax(mq)-qmin(mq) .gt. threshold) then
        refine = 1
    endif

    fclaw2d_clawpatch_minmax_exceeds_th = refine

end function fclaw2d_clawpatch_minmax_exceeds_th
