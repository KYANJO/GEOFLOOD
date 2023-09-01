c-----------------------------------------------------------------------
      subroutine riemann_aug_JCP(maxiter,meqn,mwaves,hL,hR,huL,huR,
     &   hvL,hvR,bL,bR,uL,uR,vL,vR,phiL,phiR,pL,pR,sE1,sE2,drytol,g,rho,
     &   sw,fw)

      ! solve shallow water equations given single left and right states
      ! This solver is described in J. Comput. Phys. (6): 3089-3113, March 2008
      ! Augmented Riemann Solvers for the Shallow Equations with Steady States and Inundation

      ! To use the original solver call with maxiter=1.

      ! This solver allows iteration when maxiter > 1. The iteration seems to help with
      ! instabilities that arise (with any solver) as flow becomes transcritical over variable topo
      ! due to loss of hyperbolicity.

      implicit none

      !input
      integer meqn,mwaves,maxiter,ixy
      !!double precision fw(meqn,mwaves)
      !!double precision sw(mwaves)
      double precision fw(3,3)
      double precision sw(3)
      double precision hL,hR,huL,huR,bL,bR,uL,uR,phiL,phiR,sE1,sE2
      double precision hvL,hvR,vL,vR,pL,pR
      double precision drytol,g,rho


      !local
      integer m,mw,k,iter
      !! 3x3 for 3-wave decomposition (not related to 2d problem)
      double precision A(3,3)
      double precision r(3,3)
      double precision lambda(3)
      double precision del(3)
      double precision beta(3)

      double precision delh,delhu,delphi,delb,delnorm
      double precision rare1st,rare2st,sdelta,raremin,raremax
      double precision criticaltol,convergencetol,raretol
      double precision criticaltol_2, hustar_interface
      double precision s1s2bar,s1s2tilde,hbar,hLstar,hRstar,hustar
      double precision huRstar,huLstar,uRstar,uLstar,hstarHLL
      double precision deldelh,deldelphi,delP
      double precision s1m,s2m,hm
      double precision det1,det2,det3,determinant

      logical rare1,rare2,rarecorrector,rarecorrectortest,sonic

      integer ii_com, jj_com
      common /common_ii/ ii_com, jj_com

      !determine del vectors
      delh = hR-hL
      delhu = huR-huL
      delphi = phiR-phiL
      delb = bR-bL
      delP = pR - pL
      delnorm = delh**2 + delphi**2

      call riemanntype(hL,hR,uL,uR,hm,s1m,s2m,rare1,rare2,
     &                                  1,drytol,g)

c     # This is correct, as per D. George.       
      lambda(1)= min(sE1,s2m) !Modified Einfeldt speed
      lambda(3)= max(sE2,s1m) !Modified Eindfeldt speed
      sE1 = lambda(1)
      sE2 = lambda(3)
      lambda(2) = 0.d0  ! ### Fix to avoid uninitialized value in loop on mw -- Correct?? ###
      
      hstarHLL = max((huL-huR + sE2*hR - sE1*hL)/(sE2-sE1),0.d0) ! middle state in an HLL solve

c     !determine the middle entropy corrector wave------------------------
      rarecorrectortest = .false.
      rarecorrector = .false.
      if (rarecorrectortest) then
         sdelta = lambda(3)-lambda(1)
         raremin = 0.5d0
         raremax = 0.9d0
         if (rare1 .and. sE1*s1m .lt. 0.d0) raremin=0.2d0
         if (rare2 .and. sE2*s2m .lt. 0.d0) raremin=0.2d0
         if (rare1 .or. rare2) then
            !see which rarefaction is larger
            rare1st = 3.d0*(sqrt(g*hL) - sqrt(g*hm))
            rare2st = 3.d0*(sqrt(g*hR) - sqrt(g*hm))
            if (max(rare1st,rare2st) .gt. raremin*sdelta .and.
     &         max(rare1st,rare2st) .lt. raremax*sdelta) then
                  rarecorrector = .true.
               if (rare1st .gt. rare2st) then
                  lambda(2) = s1m
               elseif (rare2st .gt. rare1st) then
                  lambda(2) = s2m
               else
                  lambda(2) = 0.5d0*(s1m + s2m)
               endif
            endif
         endif
         if (hstarHLL .lt. min(hL,hR)/5.d0) rarecorrector = .false.
      endif

c     ## Is this correct 2-wave when rarecorrector == .true. ??
      do mw=1,3
         r(1,mw) = 1.d0
         r(2,mw) = lambda(mw)
         r(3,mw) = (lambda(mw))**2
      enddo
      if (.not. rarecorrector) then
         lambda(2) = 0.5d0*(lambda(1) + lambda(3))
c         lambda(2) = max(min(0.5d0*(s1m+s2m),sE2),sE1)
         r(1,2) = 0.d0
         r(2,2) = 0.d0
         r(3,2) = 1.d0
      endif
c     !---------------------------------------------------


c     !determine the steady state wave -------------------
      !criticaltol = 1.d-6
      ! MODIFIED:
      criticaltol = max(drytol*g, 1d-6)
      criticaltol_2 = sqrt(criticaltol)
      deldelh = -delb
      deldelphi = -0.5d0 * (hR + hL) * (g * delb + delp / rho)

c     !determine a few quanitites needed for steady state wave if iterated
      hLstar = hL
      hRstar = hR
      uLstar = uL
      uRstar = uR
      huLstar = uLstar*hLstar
      huRstar = uRstar*hRstar

      !iterate to better determine the steady state wave
      convergencetol = 1.d-6
      do iter = 1,maxiter
         !determine steady state wave (this will be subtracted from the delta vectors)
         if (min(hLstar,hRstar) .lt. drytol .and. rarecorrector) then
            write(6,'(A,A)') 'geoclaw_riemann_utils : ',
     &             'min(hlstar,hrstar) < drytol'
            stop
            rarecorrector=.false.
            hLstar = hL
            hRstar = hR
            uLstar = uL
            uRstar = uR
            huLstar = uLstar*hLstar
            huRstar = uRstar*hRstar
            lambda(2) = 0.5d0*(lambda(1) + lambda(3))
c           lambda(2) = max(min(0.5d0*(s1m+s2m),sE2),sE1)
            r(1,2) = 0.d0
            r(2,2) = 0.d0
            r(3,2) = 1.d0
         endif

         hbar =  max(0.5d0*(hLstar + hRstar),0.d0)
         s1s2bar = 0.25d0*(uLstar + uRstar)**2 - g*hbar
         s1s2tilde = max(0.d0,uLstar*uRstar) - g*hbar

c        !find if sonic problem
         ! MODIFIED from 5.3.1 version
         sonic = .false.
         if (abs(s1s2bar) <= criticaltol) then
            sonic = .true.
         else if (s1s2bar*s1s2tilde <= criticaltol**2) then
            sonic = .true.
         else if (s1s2bar*sE1*sE2 <= criticaltol**2) then
            sonic = .true.
         else if (min(abs(sE1),abs(sE2)) < criticaltol_2) then
            sonic = .true.
         else if (sE1 <  criticaltol_2 .and. s1m > -criticaltol_2) then
            sonic = .true.
         else if (sE2 > -criticaltol_2 .and. s2m <  criticaltol_2) then
            sonic = .true.
         else if ((uL + dsqrt(g*hL))*(uR + dsqrt(g*hR)) < 0.d0) then
            sonic = .true.
         else if ((uL - dsqrt(g*hL))*(uR - dsqrt(g*hR)) < 0.d0) then
            sonic = .true.
         end if
         if (sonic) then
            write(6,*) 'geoclaw_riemann_utils : sonic == true'
            stop
         endif

c        !find jump in h, deldelh
         if (sonic) then
            deldelh =  -delb
         else
            deldelh = delb*g*hbar/s1s2bar
         endif
c        !find bounds in case of critical state resonance, or negative states
         if (sE1.lt.-criticaltol .and. sE2 .gt. criticaltol) then
            deldelh = min(deldelh,hstarHLL*(sE2-sE1)/sE2)
            deldelh = max(deldelh,hstarHLL*(sE2-sE1)/sE1)
         elseif (sE1 .ge. criticaltol) then
            deldelh = min(deldelh,hstarHLL*(sE2-sE1)/sE1)
            deldelh = max(deldelh,-hL)
         elseif (sE2 .le. -criticaltol) then
            deldelh = min(deldelh,hR)
            deldelh = max(deldelh,hstarHLL*(sE2-sE1)/sE2)
         endif

c        ! adjust deldelh for well-balancing of atmospheric pressure difference 
         deldelh = deldelh - delP/(rho*g)

c        !find jump in phi, deldelphi
         if (sonic) then
            deldelphi = -g*hbar*delb
         else
            deldelphi = -delb*g*hbar*s1s2tilde/s1s2bar
         endif
c        !find bounds in case of critical state resonance, or negative states
         deldelphi = min(deldelphi,g*max(-hLstar*delb,-hRstar*delb))
         deldelphi = max(deldelphi,g*min(-hLstar*delb,-hRstar*delb))
         deldelphi = deldelphi - hbar * delp / rho

         del(1) = delh - deldelh
         del(2) = delhu
         del(3) = delphi - deldelphi

c        !Determine determinant of eigenvector matrix========
         det1 = r(1,1)*(r(2,2)*r(3,3) - r(2,3)*r(3,2))
         det2 = r(1,2)*(r(2,1)*r(3,3) - r(2,3)*r(3,1))
         det3 = r(1,3)*(r(2,1)*r(3,2) - r(2,2)*r(3,1))
         determinant = det1 - det2 + det3

c        !solve for beta(k) using Cramers Rule=================
         do k=1,3
            do mw=1,3
               A(1,mw) = r(1,mw)
               A(2,mw) = r(2,mw)
               A(3,mw) = r(3,mw)
            enddo
            A(1,k) = del(1)
            A(2,k) = del(2)
            A(3,k) = del(3)
            det1 = A(1,1)*(A(2,2)*A(3,3) - A(2,3)*A(3,2))
            det2 = A(1,2)*(A(2,1)*A(3,3) - A(2,3)*A(3,1))
            det3 = A(1,3)*(A(2,1)*A(3,2) - A(2,2)*A(3,1))
            beta(k) = (det1 - det2 + det3)/determinant
         enddo

         !exit if things aren't changing
         if (abs(del(1)**2 + del(3)**2 - delnorm) .lt. 
     &              convergencetol) exit
         delnorm = del(1)**2 + del(3)**2
         !find new states qLstar and qRstar on either side of interface
         hLstar = hL
         hRstar = hR
         uLstar = uL
         uRstar = uR
         huLstar = uLstar*hLstar
         huRstar = uRstar*hRstar
         do mw = 1,3
            if (lambda(mw) .lt. 0.d0) then
               hLstar= hLstar + beta(mw)*r(1,mw)
               huLstar= huLstar + beta(mw)*r(2,mw)
            endif
         enddo
         do mw = 3,1,-1
            if (lambda(mw) .gt. 0.d0) then
               hRstar = hRstar - beta(mw)*r(1,mw)
               huRstar = huRstar - beta(mw)*r(2,mw)
            endif
         enddo

         if (hLstar .gt. drytol) then
            uLstar = huLstar/hLstar
         else
            hLstar = max(hLstar,0.d0)
            uLstar = 0.d0
         endif
         if (hRstar .gt. drytol) then
            uRstar = huRstar/hRstar
         else
            hRstar = max(hRstar,0.d0)
            uRstar = 0.d0
         endif

      enddo ! end iteration on Riemann problem

      do mw=1,3
         sw(mw) = lambda(mw)
         fw(1,mw) = beta(mw)*r(2,mw)
         fw(2,mw) = beta(mw)*r(3,mw)
         fw(3,mw) = beta(mw)*r(2,mw)
      enddo
      !!find transverse components (ie huv jumps).
      !! MODIFIED from 5.3.1 version
      fw(3,1) = fw(3,1)*vL
      !!fw(3,3) = fw(3,3)*vR
      !!fw(3,2) =  0.d0

      fw(3,3) = fw(3,3)*vR
      fw(3,2) =  0.d0

 
      hustar_interface = huL + fw(1,1)   ! = huR - fw(1,3)
      if (hustar_interface .le. 0.0d0) then
         fw(3,1) = fw(3,1) + (hR*uR*vR - hL*uL*vL - 
     &            fw(3,1)- fw(3,3))
      else
         fw(3,3) = fw(3,3) + (hR*uR*vR - hL*uL*vL - 
     &            fw(3,1)- fw(3,3))
      end if


      return

      end !subroutine riemann_aug_JCP-------------------------------------------------


c-----------------------------------------------------------------------

c     # Current GeoClaw comments this out of main rpn2_geoclaw.f90
      subroutine riemann_ssqfwave(maxiter,meqn,mwaves,hL,hR,huL,huR,
     &    hvL,hvR,bL,bR,uL,uR,vL,vR,phiL,phiR,pL,pR,sE1,sE2,drytol,g,
     &    rho,sw,fw)

      ! solve shallow water equations given single left and right states
      ! steady state wave is subtracted from delta [q,f]^T before decomposition

      implicit none

      !input
      integer meqn,mwaves,maxiter

      double precision hL,hR,huL,huR,bL,bR,uL,uR,phiL,phiR,sE1,sE2
      double precision vL,vR,hvL,hvR,pL,pR
      double precision drytol,g,rho

      !local
      integer iter

      logical sonic

      double precision delh,delhu,delphi,delb,delhdecomp,delphidecomp
      double precision s1s2bar,s1s2tilde,hbar,hLstar,hRstar,hustar
      double precision uRstar,uLstar,hstarHLL
      double precision deldelh,deldelphi,delP
      double precision alpha1,alpha2,beta1,beta2,delalpha1,delalpha2
      double precision criticaltol,convergencetol
      double precision sL,sR
      double precision uhat,chat,sRoe1,sRoe2

      double precision sw(mwaves)
      double precision fw(meqn,mwaves)

      !determine del vectors
      delh = hR-hL
      delhu = huR-huL
      delphi = phiR-phiL
      delb = bR-bL
      delP = pR - pL

      convergencetol= 1.d-16
      criticaltol = 1.d-99

      deldelh = -delb
      deldelphi = -0.5d0 * (hR + hL) * (g * delb + delP / rho)

!     !if no source term, skip determining steady state wave
      if (abs(delb).gt.0.d0) then
!
         !determine a few quanitites needed for steady state wave if iterated
         hLstar=hL
         hRstar=hR
         uLstar=uL
         uRstar=uR
         hstarHLL = max((huL-huR+sE2*hR-sE1*hL)/(sE2-sE1),0.d0) ! middle state in an HLL solve

         alpha1=0.d0
         alpha2=0.d0

!        !iterate to better determine Riemann problem
         do iter=1,maxiter

            !determine steady state wave (this will be subtracted from the delta vectors)
            hbar =  max(0.5d0*(hLstar+hRstar),0.d0)
            s1s2bar = 0.25d0*(uLstar+uRstar)**2 - g*hbar
            s1s2tilde= max(0.d0,uLstar*uRstar) - g*hbar


c           !find if sonic problem
            sonic=.false.
            if (abs(s1s2bar).le.criticaltol) sonic=.true.
            if (s1s2bar*s1s2tilde.le.criticaltol) sonic=.true.
            if (s1s2bar*sE1*sE2.le.criticaltol) sonic = .true.
            if (min(abs(sE1),abs(sE2)).lt.criticaltol) sonic=.true.

c           !find jump in h, deldelh
            if (sonic) then
               deldelh =  -delb
            else
               deldelh = delb*g*hbar/s1s2bar
            endif
!           !bounds in case of critical state resonance, or negative states
            if (sE1.lt.-criticaltol.and.sE2.gt.criticaltol) then
               deldelh = min(deldelh,hstarHLL*(sE2-sE1)/sE2)
               deldelh = max(deldelh,hstarHLL*(sE2-sE1)/sE1)
            elseif (sE1.ge.criticaltol) then
               deldelh = min(deldelh,hstarHLL*(sE2-sE1)/sE1)
               deldelh = max(deldelh,-hL)
            elseif (sE2.le.-criticaltol) then
               deldelh = min(deldelh,hR)
               deldelh = max(deldelh,hstarHLL*(sE2-sE1)/sE2)
            endif

c           !find jump in phi, deldelphi
            if (sonic) then
               deldelphi = -g*hbar*delb
            else
               deldelphi = -delb*g*hbar*s1s2tilde/s1s2bar
            endif
!           !bounds in case of critical state resonance, or negative states
            deldelphi=min(deldelphi,g*max(-hLstar*delb,-hRstar*delb))
            deldelphi=max(deldelphi,g*min(-hLstar*delb,-hRstar*delb))

!---------determine fwaves ------------------------------------------

!           !first decomposition
            delhdecomp = delh-deldelh
            delalpha1 = (sE2*delhdecomp - delhu)/(sE2-sE1)-alpha1
            alpha1 = alpha1 + delalpha1
            delalpha2 = (delhu - sE1*delhdecomp)/(sE2-sE1)-alpha2
            alpha2 = alpha2 + delalpha2

            !second decomposition
            delphidecomp = delphi - deldelphi
            beta1 = (sE2*delhu - delphidecomp)/(sE2-sE1)
            beta2 = (delphidecomp - sE1*delhu)/(sE2-sE1)

            if ((delalpha2**2+delalpha1**2).lt.convergencetol**2) then
               exit
            endif
!
            if (sE2.gt.0.d0.and.sE1.lt.0.d0) then
               hLstar=hL+alpha1
               hRstar=hR-alpha2
c               hustar=huL+alpha1*sE1
               hustar = huL + beta1
            elseif (sE1.ge.0.d0) then
               hLstar=hL
               hustar=huL
               hRstar=hR - alpha1 - alpha2
            elseif (sE2.le.0.d0) then
               hRstar=hR
               hustar=huR
               hLstar=hL + alpha1 + alpha2
            endif
!
            if (hLstar.gt.drytol) then
               uLstar=hustar/hLstar
            else
               hLstar=max(hLstar,0.d0)
               uLstar=0.d0
            endif
!
            if (hRstar.gt.drytol) then
               uRstar=hustar/hRstar
            else
               hRstar=max(hRstar,0.d0)
               uRstar=0.d0
            endif

         enddo
      endif

      delhdecomp = delh - deldelh
      delphidecomp = delphi - deldelphi

      !first decomposition
      alpha1 = (sE2*delhdecomp - delhu)/(sE2-sE1)
      alpha2 = (delhu - sE1*delhdecomp)/(sE2-sE1)

      !second decomposition
      beta1 = (sE2*delhu - delphidecomp)/(sE2-sE1)
      beta2 = (delphidecomp - sE1*delhu)/(sE2-sE1)

      ! 1st nonlinear wave
      fw(1,1) = alpha1*sE1
      fw(2,1) = beta1*sE1
      fw(3,1) = fw(1,1)*vL
      ! 2nd nonlinear wave
      fw(1,3) = alpha2*sE2
      fw(2,3) = beta2*sE2
      fw(3,3) = fw(1,3)*vR
      ! advection of transverse wave
      fw(1,2) = 0.d0
      fw(2,2) = 0.d0
      fw(3,2) = hR*uR*vR - hL*uL*vL -fw(3,1)-fw(3,3)
      !speeds
      sw(1)=sE1
      sw(2)=0.5d0*(sE1+sE2)
      sw(3)=sE2

      return

      end subroutine !-------------------------------------------------


c-----------------------------------------------------------------------
c     # Current GeoClaw comments this out of main rpn2_geoclaw.f90
c     # And this duplicates my "simple_riemann" code.
      subroutine riemann_fwave(meqn,mwaves,hL,hR,huL,huR,hvL,hvR,
     &            bL,bR,uL,uR,vL,vR,phiL,phiR,pL,pR,s1,s2,drytol,g,rho,
     &            sw,fw)

      ! solve shallow water equations given single left and right states
      ! solution has two waves.
      ! flux - source is decomposed.

      implicit none

      !input
      integer meqn,mwaves

      double precision hL,hR,huL,huR,bL,bR,uL,uR,phiL,phiR,s1,s2
      double precision hvL,hvR,vL,vR,pL,pR
      double precision drytol,g,rho

      double precision sw(mwaves)
      double precision fw(meqn,mwaves)

      !local
      double precision delh,delhu,delphi,delb,delhdecomp,delphidecomp
      double precision deldelh,deldelphi,delP
      double precision beta1,beta2


      !determine del vectors
      delh = hR-hL
      delhu = huR-huL
      delphi = phiR-phiL
      delb = bR-bL
      delP = pR - pL

      deldelphi = -0.5d0 * (hR + hL) * (g * delb + delP / rho)
      delphidecomp = delphi - deldelphi

      !flux decomposition
      beta1 = (s2*delhu - delphidecomp)/(s2-s1)
      beta2 = (delphidecomp - s1*delhu)/(s2-s1)

      sw(1)=s1
      sw(2)=0.5d0*(s1+s2)
      sw(3)=s2
      ! 1st nonlinear wave
      fw(1,1) = beta1
      fw(2,1) = beta1*s1
      fw(3,1) = beta1*vL
      ! 2nd nonlinear wave
      fw(1,3) = beta2
      fw(2,3) = beta2*s2
      fw(3,3) = beta2*vR
      ! advection of transverse wave
      fw(1,2) = 0.d0
      fw(2,2) = 0.d0
      fw(3,2) = hR*uR*vR - hL*uL*vL -fw(3,1)-fw(3,3)
      return

      end !subroutine -------------------------------------------------





c=============================================================================
      subroutine riemanntype(hL,hR,uL,uR,hm,s1m,s2m,rare1,rare2,
     &             maxiter,drytol,g)

      !determine the Riemann structure (wave-type in each family)


      implicit none

      !input
      double precision hL,hR,uL,uR,drytol,g
      integer maxiter

      !output
      double precision s1m,s2m
      logical rare1,rare2

      !local
      double precision hm,u1m,u2m,um,delu
      double precision h_max,h_min,h0,F_max,F_min,dfdh,F0,slope,gL,gR
      integer iter



c     !Test for Riemann structure

      h_min=min(hR,hL)
      h_max=max(hR,hL)
      delu=uR-uL

      if (h_min.le.drytol) then
         hm=0.d0
         um=0.d0
         s1m=uR+uL-2.d0*sqrt(g*hR)+2.d0*sqrt(g*hL)
         s2m=uR+uL-2.d0*sqrt(g*hR)+2.d0*sqrt(g*hL)
         if (hL.le.0.d0) then
            rare2=.true.
            rare1=.false.
         else
            rare1=.true.
            rare2=.false.
         endif

      else
         F_min= delu+2.d0*(sqrt(g*h_min)-sqrt(g*h_max))
         F_max= delu +
     &         (h_max-h_min)*(sqrt(.5d0*g*(h_max+h_min)/(h_max*h_min)))

         if (F_min.gt.0.d0) then !2-rarefactions

            hm=(1.d0/(16.d0*g))*
     &               max(0.d0,-delu+2.d0*(sqrt(g*hL)+sqrt(g*hR)))**2
            um=sign(1.d0,hm)*(uL+2.d0*(sqrt(g*hL)-sqrt(g*hm)))

            s1m=uL+2.d0*sqrt(g*hL)-3.d0*sqrt(g*hm)
            s2m=uR-2.d0*sqrt(g*hR)+3.d0*sqrt(g*hm)

            rare1=.true.
            rare2=.true.

         elseif (F_max.le.0.d0) then !2 shocks

c           !root finding using a Newton iteration on sqrt(h)===
            h0=h_max
            do iter=1,maxiter
               gL=sqrt(.5d0*g*(1/h0 + 1/hL))
               gR=sqrt(.5d0*g*(1/h0 + 1/hR))
               F0=delu+(h0-hL)*gL + (h0-hR)*gR
               dfdh=gL-g*(h0-hL)/(4.d0*(h0**2)*gL)+
     &                   gR-g*(h0-hR)/(4.d0*(h0**2)*gR)
               slope=2.d0*sqrt(h0)*dfdh
               h0=(sqrt(h0)-F0/slope)**2
            enddo
               hm=h0
               u1m=uL-(hm-hL)*sqrt((.5d0*g)*(1/hm + 1/hL))
               u2m=uR+(hm-hR)*sqrt((.5d0*g)*(1/hm + 1/hR))
               um=.5d0*(u1m+u2m)

               s1m=u1m-sqrt(g*hm)
               s2m=u2m+sqrt(g*hm)
               rare1=.false.
               rare2=.false.

         else !one shock one rarefaction
            h0=h_min

            do iter=1,maxiter
               F0=delu + 2.d0*(sqrt(g*h0)-sqrt(g*h_max))
     &                  + (h0-h_min)*sqrt(.5d0*g*(1/h0+1/h_min))
               slope=(F_max-F0)/(h_max-h_min)
               h0=h0-F0/slope
            enddo

            hm=h0
            if (hL.gt.hR) then
               um=uL+2.d0*sqrt(g*hL)-2.d0*sqrt(g*hm)
               s1m=uL+2.d0*sqrt(g*hL)-3.d0*sqrt(g*hm)
               s2m=uL+2.d0*sqrt(g*hL)-sqrt(g*hm)
               rare1=.true.
               rare2=.false.
            else
               s2m=uR-2.d0*sqrt(g*hR)+3.d0*sqrt(g*hm)
               s1m=uR-2.d0*sqrt(g*hR)+sqrt(g*hm)
               um=uR-2.d0*sqrt(g*hR)+2.d0*sqrt(g*hm)
               rare2=.true.
               rare1=.false.
            endif
         endif
      endif

      return

      end ! subroutine riemanntype----------------------------------------------------------------
