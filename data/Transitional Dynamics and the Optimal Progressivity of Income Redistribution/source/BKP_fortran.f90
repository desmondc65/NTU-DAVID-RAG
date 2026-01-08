! Code for Bakis, Kaymak and Poschke, Transitional Dynamics and the Optimal Progressivity of Income Redistribution

! choose parameters, then compile the code using < gfortran -framework Accelerate -g3 -o transout.out BKP_fortran.f90 >, then execute transout.out.

!                    ************ modules  ************! 
module def
  integer, PARAMETER :: dp = selected_real_kind(10)
end module def
!******************************************************************************!
MODULE calib
  use def
  IMPLICIT NONE
  REAL(dp), PARAMETER :: period = 5.0D0 
  REAL(dp), PARAMETER :: alpha = 0.36D0, beta=0.9617D0**period, delta=(1.0D0-0.92D0**period), sigma=2.0D0 
  REAL(dp), PARAMETER :: thet = 0.358D0, epsi=1.183D0, phi=0.0D0
  REAL(dp), PARAMETER :: kmax = 100.D0 
  REAL(dp), PARAMETER :: mu = 1.0D0-.2D0
  REAL(dp), PARAMETER :: rtarget = 1.041**period-1.
  REAL(dp), PARAMETER :: gov = 0.17 ! share of taxes in income in the steady state
  REAL(dp), PARAMETER :: govexp = 2.59 ! government expenditure
  INTEGER, PARAMETER :: govfixed = 1 ! 1: use fixed expenditure, 0: use proportional
  REAL(dp), PARAMETER :: reformstarts = 1 ! period in which reform kicks in
  INTEGER, PARAMETER :: taxfunction = 1 ! 1: yd = lambda*y^(1-tau) (used in the paper); 
	!   2: same for tau>0, yd = y-lambda*y^(1+tau) for tau<0
	!   3: yd = lambda*(w*z*n)^(1-tau_l) + (1-tau_k)*r*k
  INTEGER, PARAMETER :: fixedprices = 0 ! fixedprices = 1 works only for steady states, use for Section 4
	! the fixed r can be provided as maxrpar in the equil subroutine, the lambda as lambda1 in equil
  INTEGER, PARAMETER :: lifecycle = 1 ! 1: intergenerational + lifecycle (as in the paper), 0: only intergenerational
END MODULE calib
!******************************************************************************!
module findroot1D ! module of auxiliary functions
  use def
  USE calib
  implicit none
  REAL(dp), parameter, private :: tol = 1.D-5
  REAL(dp) :: kpm,km,zm,lm,mm,r,w,tau_l, tau_k, lambda, mN,cm

contains
!****************internal subroutines and functions*****************!
  function util(cp,lap) result(u)
    REAL(dp), dimension(:) :: cp, lap
    REAL(dp), dimension(:), allocatable :: u
    ALLOCATE(u(size(cp)))
    WHERE ( cp > 0.D0 .AND. lap > 0.D0 )
       u = (cp**(1-sigma))/(1-sigma) - thet*lap**(1+epsi)/(1+epsi)
    ELSEWHERE
		u = -1.0D+12
    END WHERE
  end function util
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!
  FUNCTION mtok(x) result (f_res)
    REAL(dp), INTENT(in) :: x
    REAL(dp) :: f_res
	if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
	    f_res = lambda*(w*zm*lm + r*x)**(1.-tau_l) + x - mm
	else if (taxfunction==3) then
		f_res = lambda*(w*zm*lm)**(1.-tau_l) + (1.-tau_k)*r*x + x - mm
	else
	    f_res = (w*zm*lm + r*x)-lambda*(w*zm*lm + r*x)**(1.+tau_l) + x - mm
	end if
  END FUNCTION mtok
  
!******************************************************************************!
  FUNCTION fl(x) result (f_res)
    REAL(dp), intent(in) :: x
    REAL(dp) :: f_res, cm
		if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
			cm = km + lambda*(w*x*zm+r*km)**(1.D0-tau_l) - kpm
		else if (taxfunction==3) then
			cm = km + lambda*(w*x*zm)**(1.D0-tau_l) + (1.D0-tau_k)*r*km - kpm 
		else
			cm = km + (w*x*zm+r*km)-lambda*(w*x*zm+r*km)**(1.D0+tau_l) - kpm 
		end if
		IF ( cm<0 ) THEN
			f_res = 10000.D0
		ELSE
		if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
		    f_res = - thet*x**epsi+(1.D0-tau_l)*lambda*(w*zm*x+r*km)**(-tau_l)*(w*zm)&
	        *cm**(-sigma)
		else if (taxfunction==3) then
			f_res = -thet*x**epsi + (1.D0-tau_l) *lambda * (w*zm*x)**(-tau_l) *(w*zm)&
			*cm**(-sigma)
		else
		    f_res = - thet* x**epsi + (w*zm-(1.D0+tau_l)* lambda* (w*zm*x+r*km)**(tau_l)*(w*zm))&
	        *cm**(-sigma)
		end if
		END IF
  END FUNCTION fl
!******************************************************************************!
  FUNCTION maxfind(func,x1,x2) result(fl_max)
    REAL(dp), INTENT(IN) :: x1,x2
    REAL(dp) :: func, fl_max
    INTEGER :: j, i
    REAL(dp) :: x,dx,fx

	j=1
	i=1
	dx = (x2 - x1)/(10**j-1)	
	fx=-1.0D0
	DO WHILE (fx<0 .AND. j<3)
		x = x2 - (i-1)*dx
		fx=func(x)
		IF (i<10**j) THEN
			i=i+1
			ELSE
			j=j+1
			i=1
		dx = (x2 - x1)/(10**j-1)
		END IF	
  	END DO
    fl_max=x
	IF (j<3) THEN
	    fl_max=x
	ELSE
		fl_max=0
	END IF
  END FUNCTION maxfind


!******************************************************************************!
  function bisect(func,x1,x2,modified) result (f_res)
    ! modified code, based on code by Numerical Recipes in F90
    INTEGER, INTENT(IN) :: modified
    REAL(dp), INTENT(IN) :: x1,x2
    REAL(dp) :: func, f_res, f1, f2
    INTEGER, PARAMETER :: maxit=1000
    INTEGER :: j
    REAL(dp) :: dx,f,fmid,xmid
	IF ( modified == 1 ) THEN	
	    f1 = func(x1); f2 = func(x2)
	    IF (f1 >0.D0 .AND. f2 > 0.D0) THEN
	       f_res = 0.9999D0;
	       return
	    END IF
	    IF (f1 <0.D0 .AND. f2 < 0.D0) THEN
	       f_res = 0.0001D0;
	       return
	    END IF
	END IF
    fmid=func(x2)
    f=func(x1)
    if (f*fmid >= 0.D0) STOP 'bisection: root must be bracketed'
    if (f < 0.D0) then
        f_res=x1
        dx=x2-x1
     else
        f_res=x2
        dx=x1-x2
     end if
     do j=1, maxit
        dx=dx*0.5_dp
        xmid=f_res+dx
        fmid=func(xmid)
        if (fmid <= 0.D0) f_res=xmid
        if (ABS(dx) < tol .OR. fmid == 0.D0) RETURN
     end do
     STOP 'bisection: too many bissections'
   end function bisect


!******************************************************************************!
  function myinterp1D(x,y,xi) result(yi)
    ! original code by  John Burkardt
    REAL(dp), intent(in), dimension(:) :: x, y, xi
    REAL(dp), dimension(:), allocatable :: yi
    integer :: i, j, NX, l,r, N, go_on
    integer, dimension(1) :: x_min
    REAL(dp) :: t
    
    nx = size(xi)
    allocate(yi(nx))
    doj:do j = 1,nx
       call bracket (x, xi(j), l, r)
       yi(j)= y(l)+(y(r)-y(l))*(xi(j)-x(l))/(x(r)-x(l))
    end do doj
  end function myinterp1D
!******************************************************************************!
  
  subroutine bracket(x, xval, l, r)
    ! original code by  John Burkardt
    REAL(dp), intent(in), dimension(:) :: x
    REAL(dp), intent(in) :: xval
    integer, intent(out) :: l, r
    integer :: i, n
    
    n=size(x)
    do i = 2, n - 1
       if ( xval < x(i) ) then
          l = i - 1
          r = i
          return
       end if
    end do
    l = n - 1
    r = n
  end subroutine bracket

SUBROUTINE WRITE_DM(A)
  REAL(8), DIMENSION(:,:) :: A 
  INTEGER i, j
  WRITE(*,*)
  DO I = LBOUND(A,1), UBOUND(A,1) 
     WRITE(*,"(100(f10.3, 1X))") (A(I,J), J = LBOUND(A,2), UBOUND(A,2))
  END DO
END SUBROUTINE WRITE_DM

SUBROUTINE WRITE_IM(A)
  INTEGER, DIMENSION(:,:) :: A 
  INTEGER i, j
  WRITE(*,*)
  DO I = LBOUND(A,1), UBOUND(A,1) 
     WRITE(*,"(100(I10, 1X))") (A(I,J), J = LBOUND(A,2), UBOUND(A,2))
  END DO
END SUBROUTINE WRITE_IM


end module findroot1D
  
  
!*******************************************************************!
! *************** main program  ************! 
!*******************************************************************!
PROGRAM aiyagari
  use def
  USE calib
  USE findroot1D
  IMPLICIT NONE
  INTEGER, PARAMETER :: Nstar = 4, Ngrid = 401, Ntrans = 40 
!   Number of z states, of k grid points, of transition periods
  integer, PARAMETER :: ssread = 2
  ! 0: compute 1st or both steady states. 
  ! 1: compute 2nd, import 1st. 
  ! 2: import both. Filenames for import: SS1.out and SS1vectors.out, similar for SS2.
  integer, PARAMETER :: ssonly = 0
  ! 1: one SS, 2: two SS differing in tauL, 0: two SS + transition
  ! If 0, one or both SS may be imported -- see ssread above.
  ! If not 0, need to set ssread to 0.
  integer, PARAMETER :: stopearly = 0 ! if >0, stop after 'stopearly' iterations on r
  REAL(dp), PARAMETER :: kmin = phi, tol_r = 1.D-4, tol_l = 1.D-4, lam = 0.9
  REAL(dp), PARAMETER, DIMENSION(2) :: gtau_l = [.166D0,-.09D0]
!   controls the progressivity of the tax system for SS1, SS2
  REAL(dp), PARAMETER, DIMENSION(2) :: gtau_k = [-0.1D0, 0.0D0]
!   capital income tax rate, used only with taxfunction 3.
  REAL(dp) :: t1,t2,t3,delta_t, diff_r, diff_l, h, maxN
  REAL(dp) :: delk, delr, dellam
  INTEGER :: i,j, j2, itr, iter_r
  REAL(dp), DIMENSION(Nstar) :: z 
  REAL(dp), DIMENSION(1:Ngrid) :: kp, ctemp, vtemp, ltemp, kptemp
  REAL(dp), DIMENSION(1:Ngrid,Nstar) :: EV, newV, V
  REAL(dp), DIMENSION(Nstar,Nstar) :: prob, problc, SSprob, probmul, picum, eye
  REAL(dp), dimension(Ngrid, Ngrid, Nstar) :: lap3
  REAL(dp), dimension(Ntrans, Ngrid, Nstar) :: kpptr,laptr,Vtr,ctr,utr,Gtr
  REAL(dp), dimension(Ntrans) :: aggKtr,aggNtr,aggVtr,aggleistr,aggCtr
  INTEGER, DIMENSION(Ngrid,Nstar) :: dr, drid, drss1, drss2, drintp
  INTEGER, dimension(Ngrid,2*Nstar) :: drout
  REAL(dp), DIMENSION(Ngrid*Nstar,Ngrid*Nstar) :: dridmat
  INTEGER, dimension(Ntrans, Ngrid, Nstar) :: drtr
  REAL(dp), dimension(Ngrid) :: kindex
  REAL(dp), DIMENSION(Ngrid*Nstar,Ntrans) :: utrmat,Vtrmat,ctrmat,laptrmat
  REAL(dp), DIMENSION(Ngrid,Nstar) :: lap, kpp
  REAL(dp) :: rss1, rss2, wss1, wss2, lamss1, lamss2, knss1, knss2, knSS, wrateSS
  REAL(dp) :: Kss1, Kss2, Nss1, Nss2, Yss1, Yss2, Ytr, leisss1, leisss2, Welfss1, Welfss2, aggCss1, aggCss2
  REAL(dp) :: W_par, W_par_ss1, W_par_ss2, aggvaluess1, aggvaluess2, aggvalue, aggleispath, aggcerteq
  REAL(dp), DIMENSION(Ngrid,Nstar) :: Gamss1, Gamss2, Vss1, Vss2, G, Gamma, V0, certeq, Vss2original
  REAL(dp), DIMENSION(Ngrid,Nstar) :: lapss1, lapss2, kppss1, kppss2, css1, css2, Vc, Vl
  REAL(dp), DIMENSION(Ngrid,Nstar) :: c,l,u,dEV
  REAL(dp), DIMENSION(Ngrid,3*Nstar) :: Voutmat, Vout
  REAL(dp), DIMENSION(Ngrid,2*Nstar) :: lapout, kppout, Gout
  REAL(dp), DIMENSION(Ntrans) :: rdyn, rdynimp, wdyn, lamdyn, kndyn, kndynimp, Gamdyn, Vdyn, ldynimp
  REAL(dp), PARAMETER :: l0=0.0001,l2=0.9999
  REAL(dp) :: temp2, l1
  integer :: temp1(1)
  REAL(dp) :: agglabor, aggcapital,aggdisp, aggleisure,aggV,temp, cvhours, agghours,aggconsumption
  REAL(dp), dimension(Ngrid,(Ngrid-1)/10) :: ctempout, ltempout, Vtempout, EVtempout, utempout
  REAL(dp), dimension(Ngrid) :: Y
  REAL(dp), dimension(Ngrid,Nstar) :: mp, EMUp, m, k
  REAL(dp), DIMENSION(Ngrid*Nstar) :: Gammalong, Gamma1long
  REAL(dp), dimension(7) :: ss1scalars, ss2scalars
  REAL(dp), dimension(Ngrid,8*Nstar) :: ss1vectors, ss2vectors

  !********************** execution part *****************************!
  
  PRINT*, 'Start by finding the equilibrium interest rate with a bisection method'
  
  ! Begin time...
  CALL cpu_time(t1)        

!%%%%%%%%%%%%%%%%%%%%%% TRANSITION MATRIX %%%%%%%%%%%%%%%%%%%%%%%%%%%!

! Generate the transition matrix. 
! Step 1: Intergenerational Component

prob(1,:) = [0.621, 0.0690, 0.2790, 0.0310]
prob(2,:) = [0.621, 0.0690, 0.2790, 0.0310]
prob(3,:) = [0.387, 0.0430, 0.5130, 0.0570]
prob(4,:) = [0.387, 0.0430, 0.5130, 0.0570]

  z=[8.3100, 16.7220, 21.4792, 43.2220] ! hourly wages from the data
  knSS = ((rtarget+delta)/alpha)**(1./(alpha-1.))
  wrateSS = (1.-alpha)/alpha * knSS ! model wage rate per unit of z
  z=z/knSS  ! infer z from data hourly wages

! Step 2: Add the life-cycle component (mu:survival rate)

IF ( lifecycle==1 ) THEN
	problc(1,:) = [0.4721,  0.5279,  0.0000,  0.0000]
	problc(2,:) = [0.4619,  0.5381,  0.0000,  0.0000]
	problc(3,:) = [0.0000,  0.0000,  0.4721,  0.5279]
	problc(4,:) = [0.0000,  0.0000,  0.4619,  0.5381]

	prob = mu * problc + (1.D0-mu) * prob	
END IF

  	PRINT*, prob
  
  ! Calculate the stationary probabilities.
  probmul = prob
  DO i=1,1000
     probmul=MATMUL(probmul,prob)
  END DO
  SSprob = probmul; 
	PRINT*, SSprob
  maxN = DOT_PRODUCT(SSprob(:,1),z)

!%%%%%%%%%%%%%%%% GRIDS FOR TOMORROW'S CAPITAL %%%%%%%%%%%%%%%%%%%%%%%!

  h = (log(kmax+1-kmin) - 0)/(Ngrid-1.0D0)
  DO i = 1, Ngrid
  	kptemp(i) = kmin + (i-1)*h
  END DO
  kp=exp(kptemp)-1.D0+kmin

  OPEN (unit = 3, file = "res_optax_ss.out", ACCESS = 'APPEND') 
  WRITE(3, "(10(A16,1X))") 'K Tax.', 'Tau_L', 'lambda', 'Utilitarian',  'Paretian', 'Output', 'r', &
			'A. Hours', 'Agg. K', 'Agg. zL'
  CLOSE(3)

  
IF ( ssread == 0 ) THEN
  !******************* Compute 1st STEADY STATE **********************!
  tau_k = gtau_k(1);  
  tau_l = gtau_l(1); 
  ! call subroutine to compute SS1. Then write results to file.
  CALL equil(rss1,wss1,lamss1,knss1,Gamss1, Vss1,Kss1,Nss1,leisss1,lapss1,kppss1,drss1,Vc,Vl,css1,aggCss1)

  OPEN(1,file='SS1.out')
  WRITE(1,"(7(1x,f16.12))"), rss1, wss1, lamss1, knss1, Kss1, Nss1, leisss1
  CLOSE(1)
  ss1vectors(:,1:Nstar) = Gamss1; ss1vectors(:,Nstar+1:2*Nstar) = Vss1;
  ss1vectors(:,2*Nstar+1:3*Nstar) = lapss1; ss1vectors(:,Nstar*3+1:4*Nstar) = kppss1;
  ss1vectors(:,4*Nstar+1:5*Nstar) = drss1; ss1vectors(:,5*Nstar+1:6*Nstar) = Vc;
  ss1vectors(:,6*Nstar+1:7*Nstar) = Vl; ss1vectors(:,7*Nstar+1:8*Nstar) = css1;
  OPEN(1,file='SS1vectors.out')
  WRITE(1,"(32(1x,f16.12))") ((ss1vectors(i,j), j=1,8*Nstar), i=1,Ngrid)
  CLOSE(1)

  ! If only asked to compute SS1, display results.
  IF (ssonly == 1) THEN
	agghours = 1.-leisss1
	cvhours=0.0D0
	DO j=1,Nstar
	temp = DOT_PRODUCT((lapss1(:,j)-(agghours))**2.D0,Gamss1(:,j))
	cvhours=cvhours+temp
	END DO
	cvhours = cvhours**.5/agghours	
	
	
	aggvaluess1=0.0D0
	DO j=1,Nstar
	   temp=DOT_PRODUCT(Vss1(:,j),Gamss1(:,j))
	   aggvaluess1=aggvaluess1+temp
	END DO
	Yss1 = Kss1**alpha * Nss1**(1.-alpha)
	CALL cpu_time(t2)
    delta_t=t2 - t1
	PRINT*, 'Elapsed time in the steady state PROGRAM =', delta_t, 'sec'
	WRITE(*,"(7(A8,1X))"), 'hours', 'cv hours', 'r', 'r(y)', 'G/Y', 'kn', 'lambda'
	WRITE(*,"(7(F8.5,1X))"), 1.-leisss1, cvhours, rss1, (1.+rss1)**(1./period)-1., govexp/Yss1, knss1, lamss1
	WRITE(*,"(11(A8,1X))"), 'tau_l', 'lambda', 'Value', 'Output', 'r', 'r(y)', 'hours', 'w', 'K', 'N', 'leisure'
	WRITE(*,"(11(F8.5,1X))"), gtau_l(1), lamss1,aggvaluess1,Yss1, rss1, (rss1+1.)**(1./period)-1., 1.-leisss1, wss1, Kss1, Nss1,leisss1
	
    STOP
  END IF
END IF
IF (ssread<2) THEN
  !***************** Compute 2nd STEADY STATE ***********************!
  tau_k = gtau_k(2);  
  tau_l = gtau_l(2); 
  ! call subroutine to compute SS1. Then write results to file.
  CALL equil(rss2,wss2,lamss2,knss2,Gamss2, Vss2,Kss2,Nss2,leisss2,lapss2,kppss2,drss2,Vc,Vl,css2,aggCss2)

  OPEN(2,file='SS2.out')
  WRITE(2,"(7(1x,f16.12))"), rss2, wss2, lamss2, knss2, Kss2, Nss2, leisss2
  CLOSE(2)
  ss2vectors(:,1:Nstar) = Gamss2; ss2vectors(:,Nstar+1:2*Nstar) = Vss2;
  ss2vectors(:,2*Nstar+1:3*Nstar) = lapss2; ss2vectors(:,Nstar*3+1:4*Nstar) = kppss2;
  ss2vectors(:,4*Nstar+1:5*Nstar) = drss2; ss2vectors(:,5*Nstar+1:6*Nstar) = Vc;
  ss2vectors(:,6*Nstar+1:7*Nstar) = Vl; ss2vectors(:,7*Nstar+1:8*Nstar) = css2;
  OPEN(2,file='SS2vectors.out')
  WRITE(2,"(32(1x,f16.12))") ((ss2vectors(i,j), j=1,8*Nstar), i=1,Ngrid)
  CLOSE(2)
END IF

IF (ssread>0) THEN
! read SS1 results from file.
  OPEN(1,file='SS1.out')
  READ(1,*) ss1scalars
  CLOSE(1)
  OPEN(1,file='SS1vectors.out')
  READ(1,"(32(1x,f16.12))") ((ss1vectors(i,j), j=1,8*Nstar), i=1,Ngrid)
  CLOSE(1)
  rss1 = ss1scalars(1); wss1 = ss1scalars(2); lamss1 = ss1scalars(3); 
  knss1 = ss1scalars(4); Kss1 = ss1scalars(5); Nss1 = ss1scalars(6); 
  leisss1 = ss1scalars(7)
  Gamss1 = ss1vectors(:,1:Nstar); Vss1 = ss1vectors(:,Nstar+1:2*Nstar);
  lapss1 = ss1vectors(:,2*Nstar+1:3*Nstar); kppss1 = ss1vectors(:,Nstar*3+1:4*Nstar);
  drss1 = ss1vectors(:,4*Nstar+1:5*Nstar)
END IF
IF (ssread==2) THEN
! read SS2 results from file
  OPEN(1,file='SS2.out')
  READ(1,*) ss2scalars
  CLOSE(1)
  OPEN(1,file='SS2vectors.out')
  READ(1,"(32(1x,f16.12))") ((ss2vectors(i,j), j=1,8*Nstar), i=1,Ngrid)
  CLOSE(1)
  rss2 = ss2scalars(1); wss2 = ss2scalars(2); lamss2 = ss2scalars(3); 
  knss2 = ss2scalars(4); Kss2 = ss2scalars(5); Nss2 = ss2scalars(6); 
  leisss2 = ss2scalars(7)
  Gamss2 = ss2vectors(:,1:Nstar); Vss2 = ss2vectors(:,Nstar+1:2*Nstar);
  lapss2 = ss2vectors(:,2*Nstar+1:3*Nstar); kppss2 = ss2vectors(:,Nstar*3+1:4*Nstar);
  drss2 = ss2vectors(:,4*Nstar+1:5*Nstar)
END IF
tau_k = gtau_k(2);  
tau_l = gtau_l(2); 

w = wss2; r=rss2; lambda = lamss2; tau_l = gtau_l(2);

! compute welfare for both SS.
  Welfss1= 0.0D0
  DO j=1,Nstar
  	Welfss1 = Welfss1+DOT_PRODUCT(Gamss1(:,j),Vss1(:,j))  	
  END DO
  Welfss2= 0.0D0
  DO j=1,Nstar
  	Welfss2 = Welfss2+DOT_PRODUCT(Gamss2(:,j),Vss2(:,j))  	
  END DO

! display results for the two steady states  
  CALL cpu_time(t2)
  delta_t=t2 - t1
  PRINT*, 'Elapsed time in the steady state PROGRAM =', delta_t, 'sec'

	PRINT*, 'tau_lss1', gtau_l(1), 'tau_lss2', gtau_l(2) 
	PRINT*, 'rss1=', rss1, 'rss2=', rss2
	PRINT*, 'lambdass1=', lamss1, 'lambdass2=', lamss2
	PRINT*, 'wss1=', wss1, 'wss2=', wss2
	PRINT*, 'Kss1=', Kss1, 'Kss2=', Kss2
	PRINT*, 'Nss1=', Nss1, 'Nss2=', Nss2
	PRINT*, 'Css1=', aggCss1, 'Css2=', aggCss2
	PRINT*, 'leisss1=', leisss1, 'leisss2=', leisss2
	PRINT*, 'EVss1=', Welfss1, 'EVss2=', Welfss2

! save steady state values
OPEN (unit = 5, file = "res_Vss2.OUT")
WRITE(5,"(2(1x,f8.4))") ((Vss2(i,j), j=1,Nstar), i=1,Ngrid)
CLOSE(5)	
  
aggvaluess1=0.0D0
DO j=1,Nstar
   temp=DOT_PRODUCT(Vss1(:,j),Gamss1(:,j))
   aggvaluess1=aggvaluess1+temp
END DO
aggvaluess2=0.0D0
DO j=1,Nstar
   temp=DOT_PRODUCT(Vss2(:,j),Gamss2(:,j))
   aggvaluess2=aggvaluess2+temp
END DO

if (ssonly == 2) then
  Yss1 = Kss1**alpha * Nss1**(1.-alpha)
  Yss2 = Kss2**alpha * Nss2**(1.-alpha)

  PRINT*, 'Steady State 1:'
	WRITE(*,"(11(A8,1X))"), 'tau_l', 'lambda', 'Value', 'Output', 'r', 'r(y)', 'hours', 'w', 'K', 'N', 'leisure'
WRITE(*,"(11(F8.5,1X))"), gtau_l(1), lamss1,aggvaluess1,Yss1, rss1, (rss1+1.)**(1./period)-1., 1.-leisss1, wss1, Kss1, Nss1, leisss1
  PRINT*, 'Steady State 2:'
	WRITE(*,"(11(A8,1X))"), 'tau_l', 'lambda', 'Value', 'Output', 'r', 'r(y)', 'hours', 'w', 'K', 'N', 'leisure'
WRITE(*,"(11(F8.5,1X))"), gtau_l(2), lamss2,aggvaluess2,Yss2, rss2, (rss2+1.)**(1./period)-1., 1.-leisss2, wss2, Kss2, Nss2, leisss2


	stop "Computed both steady states."
end if

!*********************** COMPUTE TRANSITION ************************** 
! by shooting. Guess paths for r and lambda and iterate on them.

! compute initial candidate paths
delr = (rss2 - rss1)/(Ntrans-1.0D0)
dellam = (lamss2 - lamss1)/(Ntrans-1.0D0)
rdyn = rss2
rdyn(1) = rss1
lamdyn = lamss2
lamdyn(1) = lamss1

! initialize convergence measures
diff_r =1.0
diff_l =1.0
iter_r = 0

rloop: do while (diff_r > tol_r .OR. diff_l > tol_l) 
     iter_r = iter_r+1

     IF (iter_r == 2500) THEN
        STOP "r does not converge IN 500 iterations!!!"
     END IF
  
     ! guesses for r imply capital-labor ratios and wage rates per z.
	  DO i = 1, Ntrans
	     kndyn(i) = (( rdyn(i)+delta)/alpha)**(1.D0/(alpha-1.D0))
	     wdyn(i) = (1.D0-alpha)*kndyn(i)**(alpha)
	  END DO

	  PRINT*, '   r dyn     lambda dyn	     w dyn'
	  DO i = 1, Ntrans
	     WRITE(*,"(3(F10.4))"), rdyn(i), lamdyn(i), wdyn(i)
	  END DO

  V = Vss2;  newV = 0.0D0;   EV = 0.0;
  dr = 0;

! approach:
! find optimal l and kp given next period V
! to do this, try all possible values on kp for kpp, get implications for 
! l, c and thus V, and choose best.
! this is cheaper here than in say value function iteration because
! iteration isn't required.
  lap3 = 0.D0
! solve the problem backwards, moving from the final period Ntrans to period 1.
! set and display period tax system, prices:
  DO itr = Ntrans, 1, -1
	 IF ( itr .GE. reformstarts ) THEN
		tau_l = gtau_l(2)
	 ELSE
		tau_l = gtau_l(1)
	 END IF
	 lambda = lamdyn(itr)
     r = rdyn(itr)
     w = wdyn(itr)
  	 PRINT "(4(A9,2X,F10.5))", 'itr', REAL(itr), 'r', r, 'w', w, 'lambda', lambda
	
	 ! find optimal labor supply given prices for each kp, kpp combination
     DO j2 = 1, Ngrid
        DO i=1, Nstar
           DO j=1,Ngrid
        	  kpm = kp(j2); 
              km = kp(j);
              zm = z(i);
              l1=maxfind(fl,l0,l2)
              IF (l1==0) l1=l0
              lap3(j2,j,i) = bisect(fl, l1, l2,1)
           END DO
        END DO
     END DO

	 ! find the optimal savings policy, using next period's value function as the continuation value
     EV=MATMUL(V,TRANSPOSE(prob)) ;       
     DO j = 1, Ngrid
        DO i = 1, Nstar
		   IF (taxfunction == 1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
           	  ctemp = lambda*(r*kp(j)+w*z(i)*lap3(:,j,i))**(1.0-tau_l)+kp(j) - kp 
		   ELSE IF (taxfunction==3) THEN
			  ctemp = lambda*(w*z(i)*lap3(:,j,i))**(1.0-tau_l) + (1.-tau_k) * &
			  r*kp(j) + kp(j) - kp 
		   ELSE
			  ctemp =(r*kp(j)+w*z(i)*lap3(:,j,i))- lambda*(r*kp(j)+w*z(i)*lap3(:,j,i))**(1.0+tau_l)+kp(j) &
				- kp 
		   END IF
! 			the last kp in these expressions contains values considered for kpp, using the kp grid.
! 			the first kp is kp (initial assets).
           ltemp = lap3(:,j,i);
           vtemp = util(ctemp,ltemp) + beta*EV(:,i) 
           temp2 = MAXVAL(vtemp) 
           temp1(1:1) = MAXLOC(vtemp)
           newV(j,i) = temp2 
           dr(j,i) = temp1(1)	
           lap(j,i) = lap3(temp1(1),j,i)

	! save some results
	IF (itr==2 .AND. i==4 .AND. MOD(REAL(j),10.)==0) THEN
		ctempout(:,j/10) = ctemp
		ltempout(:,j/10) = ltemp
		utempout(:,j/10) = util(ctemp,ltemp)
		Vtempout(:,j/10) = vtemp
		EVtempout(:,j/10) = EV(:,i)	
	END IF

        END DO !i
     END DO !j

     ! update value function and savings policy
     V=newV
     DO i=1,Nstar
        kpp(:,i)=kp(dr(:,i))
     END DO

	! obtain asset law of motion
	DO i = 1, Ngrid
	   kindex(i) = i
	END DO
	DO i=1, Nstar  
	   drintp(:,i) = nint(myinterp1D(kp,kindex,kpp(:,i)))
	END DO    
	WHERE (drintp <= 0)
	   drintp =1
	END WHERE
	WHERE (drintp > Ngrid)
	   drintp = Ngrid
	END WHERE
    PRINT*, "t=", itr

	! save some results
	IF (itr==2) THEN
		OPEN (unit = 5, file = "res_cchoice.OUT")
		WRITE(5,"(20(1x,f16.4))") ((ctempout(i,j2), j2=1,20), i=1,Ngrid)
		CLOSE(5)	
		OPEN (unit = 5, file = "res_lchoice.OUT")
		WRITE(5,"(20(1x,f16.4))") ((ltempout(i,j2), j2=1,20), i=1,Ngrid)
		CLOSE(5)	
		OPEN (unit = 5, file = "res_Vchoice.OUT")
		WRITE(5,"(20(1x,f20.4))") ((Vtempout(i,j2), j2=1,20), i=1,Ngrid)
		CLOSE(5)	
		OPEN (unit = 5, file = "res_EVchoice.OUT")
		WRITE(5,"(20(1x,f16.4))") ((EVtempout(i,j2), j2=1,20), i=1,Ngrid)
		CLOSE(5)	
		OPEN (unit = 5, file = "res_uchoice.OUT")
		WRITE(5,"(20(1x,f20.4))") ((utempout(i,j2), j2=1,20), i=1,Ngrid)
		CLOSE(5)	
	END IF

	! save some more results (select period in next if loop)
	DO j=1,Nstar
		lapout(:,j) = lapss2(:,j)
		lapout(:,j+Nstar) = lap(:,j)
	END DO
	DO j=1,Nstar
		kppout(:,j) = kppss2(:,j)
		kppout(:,j+Nstar) = kpp(:,j)
	END DO

	DO j=1,Nstar
		drout(:,j) = drintp(:,j)
		drout(:,j+Nstar) = dr(:,j)
	END DO
	DO j=1,Nstar
		Vout(:,j) = Vss2(:,j)
		Vout(:,j+Nstar) = V(:,j)
		Vout(:,j+Nstar*2) = EV(:,j)
	END DO
	IF (itr==Ntrans) THEN
		OPEN (unit = 5, file = "res_firstlap.OUT")
		WRITE(5,"(1x,8f8.4)") ((lapout(i,j), j=1,2*Nstar), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_kp.OUT")
		WRITE(5,"(1x,1f8.4)") (kp(i), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_Vss1.OUT")
		WRITE(5,"(1x,4f8.4)") ((Vss1(i,j), j=1,Nstar), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_Vss2.OUT")
		WRITE(5,"(1x,4f8.4)") ((Vss2(i,j), j=1,Nstar), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_Gamss1.OUT")
		WRITE(5,"(1x,4f8.4)") ((Gamss1(i,j), j=1,Nstar), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_Gamss2.OUT")
		WRITE(5,"(1x,4f8.4)") ((Gamss2(i,j), j=1,Nstar), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_firstkpp.OUT")
		WRITE(5,"(1x,8f9.4)") ((kppout(i,j), j=1,2*Nstar), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_firstdr.OUT")
		WRITE(5,"(1x,8i4)") ((drout(i,j), j=1,2*Nstar), i=1,Ngrid)
		CLOSE(5)
		OPEN (unit = 5, file = "res_firstV.OUT")
		WRITE(5,"(1x,16f10.4)") ((Vout(i,j), j=1,3*Nstar), i=1,Ngrid)
		CLOSE(5)
	END IF
 
	! save policies and values
     DO i=1,Nstar
        kpptr(itr,:,i) = kpp(:,i)
        laptr(itr,:,i) = lap(:,i)
        drtr(itr,:,i) = drintp(:,i)
		Vtr(itr,:,i) = V(:,i)
		IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
			ctr(itr,:,i) = lambda*(r*kp+w*z(i)*lap(:,i))**(1.0-tau_l)+kp - kpp(:,i) 
		ELSE IF (taxfunction==3) THEN
			ctr(itr,:,i) = lambda*(w*z(i)*lap(:,i))**(1.0-tau_l) + & 
			(1.-tau_k)*r*kp + kp - kpp(:,i) 
		ELSE
			ctr(itr,:,i) = (r*kp+w*z(i)*lap(:,i))-lambda*(r*kp+w*z(i)*lap(:,i))**(1.0+tau_l)+kp &
			 	- kpp(:,i) 
		END IF
		utr(itr,:,i) = util(ctr(itr,:,i),lap(:,i))
     END DO

  END DO ! itr loop

! after all periods have been solved, save policies and values:
OPEN (unit = 5, file = "res_laptr.out")
WRITE(5,"(64(1x,f16.4))") (((laptr(j2,i,j), j=1,Nstar), j2=1,Ntrans), i=1,Ngrid)
CLOSE(5)	
OPEN (unit = 5, file = "res_kpptr.out")
WRITE(5,"(64(1x,f16.4))") (((kpptr(j2,i,j), j=1,Nstar), j2=1,Ntrans), i=1,Ngrid)
CLOSE(5)	
OPEN (unit = 5, file = "res_ctr.out")
WRITE(5,"(64(1x,f16.4))") (((ctr(j2,i,j), j=1,Nstar), j2=1,Ntrans), i=1,Ngrid)
CLOSE(5)	
OPEN (unit = 5, file = "res_Vtr.out")
WRITE(5,"(64(1x,f16.4))") (((Vtr(j2,i,j), j=1,Nstar), j2=1,Ntrans), i=1,Ngrid)
CLOSE(5)	
OPEN (unit = 5, file = "res_utr.out")
WRITE(5,"(64(1x,f16.4))") (((utr(j2,i,j), j=1,Nstar), j2=1,Ntrans), i=1,Ngrid)
CLOSE(5)	

!*********** COMPUTE EVOLUTION OF THE ASSET DISTRIBUTION, FORWARD *********** 

! initial distribution:
Gamma=Gamss1

! *** compute implied r and lambda and aggregates for period 1 ***
! Calculate aggregate capital and labor:
aggcapital=SUM(MATMUL(kp,Gamma));
agglabor=0.0D0	
DO j=1,Nstar
   temp=z(j)*DOT_PRODUCT(laptr(1,:,j),Gamma(:,j))
   agglabor=agglabor+temp
END DO

! implied r:
rdynimp(1) = alpha*(aggcapital/agglabor)**(alpha-1.D0)-delta;

! to obtain implied lambda, compute aggregate disposable income
if (reformstarts == 1) then
	tau_l = gtau_l(2)
else
	tau_l = gtau_l(1)
end if
aggdisp=0.0D0 
temp2 = 0.0D0
DO j=1,Nstar
	IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
		temp=DOT_PRODUCT((rdyn(1)*kp+wdyn(1)*z(j)*laptr(1,:,j))**(1.0-tau_l),Gamma(:,j))
	ELSE IF (taxfunction==3) THEN
		temp=DOT_PRODUCT((wdyn(1)*z(j)*laptr(1,:,j))**(1.0-tau_l),Gamma(:,j))			
		temp2 = temp2+ DOT_PRODUCT((1.-tau_k)*rdyn(1)*kp,Gamma(:,j))
	ELSE
		temp=DOT_PRODUCT((rdyn(1)*kp+wdyn(1)*z(j)*laptr(1,:,j))**(1.0+tau_l),Gamma(:,j))
	END IF
	aggdisp=aggdisp+temp
END DO
! implied lambda:
IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
	SELECT CASE (govfixed)
	CASE (0)
		ldynimp(1)=(1.0-gov)*(rdyn(1)*aggcapital+wdyn(1)*agglabor)/aggdisp
	CASE (1)
		ldynimp(1) = (rdyn(1)*aggcapital+wdyn(1)*agglabor-govexp)/aggdisp
	END SELECT
ELSE IF (taxfunction==3) THEN
	SELECT CASE (govfixed)
	CASE (0)
		ldynimp(1) = ((1.0-gov)*(rdyn(1)*aggcapital+wdyn(1)*agglabor) & 
			- temp2)/aggdisp
	CASE (1)
		ldynimp(1) = (rdyn(1)*aggcapital+wdyn(1)*agglabor-temp2-govexp)/aggdisp
	END SELECT
ELSE
	SELECT CASE (govfixed)
	CASE (0)
		ldynimp(1)=(gov)*(rdyn(1)*aggcapital+wdyn(1)*agglabor)/aggdisp
	CASE (1)
		ldynimp(1) = govexp/aggdisp
	END SELECT
END IF

! other	aggregate variables:
aggleisure=0.0D0
DO j=1,Nstar
   temp=DOT_PRODUCT(1.-laptr(1,:,j),Gamma(:,j))
   aggleisure=aggleisure+temp
END DO
aggconsumption = 0.0D0
DO j=1,Nstar
	temp = dot_product(ctr(1,:,j),Gamma(:,j))
	aggconsumption=aggconsumption+temp
END DO
aggKtr(1) = aggcapital
aggNtr(1) = agglabor
aggleistr(1) = aggleisure
aggCtr(1) = aggconsumption

! fill in matrix that captures evolution of the asset distribution:
DO j=1,Nstar
   	Gtr(1,:,j) = Gamss1(:,j)
END DO
	
! *** compute implied r and lambda and aggregates for all other periods ***  
itr = 0
DO itr = 1, Ntrans -1, 1     
	IF ( itr+1 .GE. reformstarts ) THEN
		tau_l = gtau_l(2)
	else
		tau_l = gtau_l(1)
	END IF

	! update asset distribution. 2 steps:
	! 1. apply asset accumulation policy (drtr):
     DO i = 1, Ngrid
        drid = 0
        WHERE (drtr(itr,:,:) == i )
           drid =1
        END WHERE
        DO j=1,Nstar
           G(i,j)=DOT_PRODUCT(drid(:,j),Gamma(:,j))
        END DO
     END DO
	! 2. apply stochastic income transitions
     Gamma=matmul(G,prob)
     DO j=1,Nstar
        Gamma(:,j) = SSprob(1,j)*Gamma(:,j)/(sum(Gamma(:,j)))
     END DO
	! save the result
	IF (itr<Ntrans) THEN
	DO j=1,Nstar
		Gtr(itr+1,:,j) = Gamma(:,j)
	END DO
	END IF	
	! write a result to disk (select period in if condition)
	IF (itr==3) THEN	
		DO j=1,Nstar
			Gout(:,j) = Gamss2(:,j)
			Gout(:,j+2) = Gamma(:,j)
		END DO	
		OPEN (unit = 5, file = "res_firstG.OUT")
		WRITE(5,"(1x,4f8.4)") ((Gout(i,j), j=1,2*Nstar), i=1,Ngrid)
		CLOSE(5)
  	END IF
  

	! Calculate aggregate capital and labor:
     aggcapital=SUM(MATMUL(kp,Gamma));
     agglabor=0.0D0	
     DO j=1,Nstar
        temp=z(j)*DOT_PRODUCT(laptr(itr+1,:,j),Gamma(:,j))
        agglabor=agglabor+temp
     END DO

	! calculate implied capital labor ratio and r:
     kndynimp(itr+1) = aggcapital/agglabor
     rdynimp(itr+1) = MAX(MIN(alpha*kndynimp(itr+1)**(alpha-1.D0)-delta,10.D0),0.D0)		

	! to obtain implied lambda, compute aggregate disposable income
	aggdisp=0.0D0 
	temp2 = 0.0D0
	DO j=1,Nstar
		IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
			temp=DOT_PRODUCT((rdyn(itr+1)*kp+wdyn(itr+1)*z(j)*laptr(itr+1,:,j))**(1.0-tau_l),Gamma(:,j))
		ELSE IF (taxfunction==3) THEN
			temp=DOT_PRODUCT((wdyn(itr+1)*z(j)*laptr(itr+1,:,j))**(1.0-tau_l),Gamma(:,j))
			temp2 = temp2+ DOT_PRODUCT((1.-tau_k)*rdyn(itr+1)*kp,Gamma(:,j))			
		ELSE
			temp=DOT_PRODUCT((rdyn(itr+1)*kp+wdyn(itr+1)*z(j)*laptr(itr+1,:,j))**(1.0+tau_l),Gamma(:,j))
		END IF
		aggdisp=aggdisp+temp
	END DO
	! implied lambda:
	IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
		SELECT CASE (govfixed)
			CASE (0)
				ldynimp(itr+1)=(1.0-gov)*(rdyn(itr+1)*aggcapital+wdyn(itr+1)*agglabor)/aggdisp
			CASE (1)
				ldynimp(itr+1)=(rdyn(itr+1)*aggcapital+wdyn(itr+1)*agglabor-govexp)/aggdisp
		END SELECT
	ELSE IF (taxfunction==3) THEN
		SELECT CASE (govfixed)
			CASE (0)
				ldynimp(itr+1) = ((1.0-gov)*(rdyn(itr+1)*aggcapital+wdyn(itr+1)*agglabor) & 
					- temp2)/aggdisp		
			CASE (1)
				ldynimp(itr+1) = (rdyn(itr+1)*aggcapital+wdyn(itr+1)*agglabor-temp2-govexp) & 
					/aggdisp						
		END SELECT
	ELSE
		SELECT CASE (govfixed)
			CASE (0)
				ldynimp(itr+1)=(gov)*(rdyn(itr+1)*aggcapital+wdyn(itr+1)*agglabor)/aggdisp
			CASE (1)
				ldynimp(itr+1)=govexp/aggdisp				
		END SELECT
	END IF

	! other aggregates
	aggleisure=0.0D0
	DO j=1,Nstar
	   temp=DOT_PRODUCT(1.-laptr(itr+1,:,j),Gamma(:,j))
	   aggleisure=aggleisure+temp
	END DO
	aggconsumption = 0.0D0
	DO j=1,Nstar
		temp = DOT_PRODUCT(ctr(itr+1,:,j),Gamma(:,j))
		aggconsumption=aggconsumption+temp
	END DO
	aggKtr(itr+1) = aggcapital
	aggNtr(itr+1) = agglabor
	aggleistr(itr+1) = aggleisure
	aggCtr(itr+1) = aggconsumption

	
END DO ! loop computing gamma and implied r and lambda for remaining periods.

! display results. 
! 1. Steady states
PRINT*, "Reminder: (Iteration ", iter_r, ")"
PRINT "(3(a10,2X,F10.5))", 'rss1', rss1, 'rss2', rss2 
PRINT "(3(a10,2X,F10.5))", 'wss1', wss1, 'wss2', wss2 
PRINT "(3(a10,2X,F10.5))", 'lambdass1', lamss1, 'lambdass2', lamss2
PRINT "(3(a10,2X,F10.5))", 'Kss1', Kss1, 'Kss2', Kss2
PRINT "(3(a10,2X,F10.5))", 'Nss1', Nss1, 'Nss2', Nss2
! 2. transition
PRINT*, '   r_guess    r_imp     lambda_guess    lambda_imp   aggK    aggN   w    aggC'
DO i = 1, Ntrans
   WRITE(*,"(5(F10.4))"), rdyn(i), rdynimp(i), lamdyn(i), ldynimp(i), aggKtr(i), aggNtr(i), wdyn(i), aggCtr(i)
END DO

! save results for aggregates and asset distribution over the transition 
OPEN (unit = 5, file = "results.OUT")
	WRITE(5,"(7(A8,1X))") "period", "aggK", "aggN", "aggleis", "r", "lambda", "w"
DO itr=1,Ntrans
	WRITE(5,"(7(f8.4,1X))") REAL(itr), aggKtr(itr), aggNtr(itr), aggleistr(itr), rdyn(itr), lamdyn(itr), wdyn(itr)
END DO
CLOSE(5)
OPEN (unit = 5, file = "res_Gtr.out")
WRITE(5,"(64(1x,f16.4))") (((Gtr(j2,i,j), j=1,Nstar), j2=1,Ntrans), i=1,Ngrid)
CLOSE(5)	


! check convergence
diff_r = MAXVAL(ABS(rdynimp-rdyn)/(1.D0+rdyn))
diff_l = MAXVAL(ABS(ldynimp-lamdyn)/(1.D0+lamdyn))

! update candidate paths for r and lambda
rdyn = lam*rdyn + (1.D0-lam)*rdynimp
lamdyn = lam*lamdyn + (1.D0-lam)*ldynimp
  
! stop the computation if instructed only to do finite number of iterations
IF (stopearly > 0 .AND. iter_r==stopearly) THEN
	PRINT*, "exiting r loop after", stopearly, "iterations as instructed"
	OPEN (unit = 5, file = "res_cchoice.OUT")
	WRITE(5,"(20(1x,f16.4))") ((ctempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_drchoice.OUT")
	WRITE(5,"(4(1x,I3))") ((dr(i,j2), j2=1,Nstar), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_lchoice.OUT")
	WRITE(5,"(20(1x,f16.4))") ((ltempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_Vchoice.OUT")
	WRITE(5,"(20(1x,f20.4))") ((Vtempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_EVchoice.OUT")
	WRITE(5,"(20(1x,f16.4))") ((EVtempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_uchoice.OUT")
	WRITE(5,"(20(1x,f20.4))") ((utempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)		
	EXIT rloop
END IF

END DO rloop ! r guess

!***************** compute welfare for the path *********************

! compute utility over whole path
DO itr=1,Ntrans
	DO j = 1,Nstar
		utrmat((j-1)*Ngrid+1:j*Ngrid,itr) = util(ctr(itr,:,j),laptr(itr,:,j))
	END DO
END DO
! 	build an Nstar*Ngrid x Nstar*Ngrid transition matrix
! and use it to build the value function by period, backwards from SS2.
DO itr = Ntrans,1, -1
    dridmat = 0
	DO j = 1,Nstar
	    DO i = 1, Ngrid
			DO j2 = 1,Nstar
				dridmat((j-1)*Ngrid+i,(j2-1)*Ngrid+drtr(itr,i,j)) = prob(j,j2)
			END DO
		END DO 
	END DO
	IF (itr==Ntrans) THEN
		DO j=1,Nstar
			Vtrmat((j-1)*Ngrid+1:j*Ngrid,itr) = Vss2(:,j)
		END DO
		Vtrmat(:,itr) = utrmat(:,itr) + beta*MATMUL(dridmat,Vtrmat(:,itr))
	ELSE
		Vtrmat(:,itr) = utrmat(:,itr) + beta*MATMUL(dridmat,Vtrmat(:,itr+1))
	END IF
END DO
DO j=1,Nstar
	V0(:,j) = Vtrmat((j-1)*Ngrid+1:j*Ngrid,1)
END DO

! compute welfare criteria for first period of transition
Gamma = Gamss1
! (in first period of transition, Gamma is predetermined and asme as in SS1)
! 1. utilitarian
aggvalue=0.0D0
DO j=1,Nstar
   temp=DOT_PRODUCT(V0(:,j),Gamma(:,j))
   aggvalue=aggvalue+temp
END DO
! 2 - PARETIAN WELFARE: Aggregate consumption equivalents before time aggregation.
! Notes: Assume everyone gets average leisure, lbar, and solve for C(k,z) in 
! C^(1-sigma)/(1-sigma) + theta (1-lbar)^(1-eps)/(1-eps) = (1-beta)V(k,z)
aggleispath = (beta**Ntrans/(1.D0-beta)) * (1.-leisss2)**(1.D0+epsi)/(1.D0+epsi)
DO itr=1,Ntrans
	aggleispath = aggleispath + beta**(itr-1) * (1.-aggleistr(itr))**(1.D0+epsi)/(1.D0+epsi)
END DO

DO i=1,Nstar
   DO j=1,Ngrid
       certeq(j,i)=((V0(j,i)+thet*aggleispath)*(1.D0-beta)*(1.D0-sigma))**(1/(1.D0-sigma))
   END DO
END DO

aggcerteq=0.0D0
DO j=1,Nstar
   temp=DOT_PRODUCT(certeq(:,j),Gamma(:,j))
   aggcerteq=aggcerteq+temp
END DO

! Paretian welfare.
W_par = (aggcerteq**(1.D0-sigma)/(1.D0-sigma))/(1.D0-beta)-thet*aggleispath
! for comparison, same for SS1:
DO i=1,Nstar
   DO j=1,Ngrid
       certeq(j,i)=((Vss1(j,i)*(1.D0-beta)+thet*(1.D0-leisss1)**(1.D0+epsi)/(1.D0+epsi))*(1.D0-sigma))**(1/(1.D0-sigma))
   END DO
END DO
aggcerteq=0.0D0
DO j=1,Nstar
   temp=DOT_PRODUCT(certeq(:,j),Gamma(:,j))
   aggcerteq=aggcerteq+temp
END DO
W_par_ss1 = (aggcerteq**(1.D0-sigma)/(1.D0-sigma)-thet*(1.-leisss1)**(1.D0+epsi)/(1.D0+epsi))/(1.D0-beta)
! for comparison, same for SS2:
DO i=1,Nstar
   DO j=1,Ngrid
       certeq(j,i)=((Vss2(j,i)*(1.D0-beta)+thet*(1.D0-leisss2)**(1.D0+epsi)/(1.D0+epsi))*(1.D0-sigma))**(1/(1.D0-sigma))
   END DO
END DO
aggcerteq=0.0D0
DO j=1,Nstar
   temp=DOT_PRODUCT(certeq(:,j),Gamss2(:,j))
   aggcerteq=aggcerteq+temp
END DO
W_par_ss2 = (aggcerteq**(1.D0-sigma)/(1.D0-sigma)-thet*(1.-leisss2)**(1.D0+epsi)/(1.D0+epsi))/(1.D0-beta)

! 3. Output
! SS1 and SS2
Yss1 = Kss1**alpha * Nss1**(1.-alpha)
Yss2 = Kss2**alpha * Nss2**(1.-alpha)
! incl transition (average, beta-weighted)
Ytr = (beta**Ntrans/(1.-beta)) * Yss2
DO itr=1,Ntrans
	Ytr = Ytr + beta**(itr-1) * aggKtr(itr)**alpha * aggNtr(itr)**(1.-alpha)
END DO
Ytr = Ytr*(1.-beta)

! display welfare results
CALL cpu_time(t3)
delta_t=t3 - t1
PRINT*, 'Elapsed time in the full PROGRAM =', delta_t, 'sec'
PRINT*, 'Vss1 =', aggvaluess1, 'Vss2 =', aggvaluess2, 'incl trans =', aggvalue
PRINT*, 'Paretian_ss1 =', W_par_ss1, 'Paretian_ss2 =', W_par_ss2, 'incl trans =', W_par
PRINT*, 'rss1=', rss1, 'rss2=', rss2
PRINT*, 'lambdass1=', lamss1, 'lambdass2=', lamss2
PRINT*, 'wss1=', wss1, 'wss2=', wss2
PRINT*, 'Kss1=', Kss1, 'Kss2=', Kss2
PRINT*, 'Nss1=', Nss1, 'Nss2=', Nss2
PRINT*, 'Yss1=', Yss1, 'Yss2=', Yss2, 'incl trans =', Ytr
PRINT*, 'Css1=', aggCss1, 'Css2=', aggCss2
PRINT*, 'leisss1=', leisss1, 'leisss2=', leisss2
PRINT*, 'iterations', iter_r

PRINT*, "new steady state:"
WRITE(*, "(6(A8,1X))"), 'tau_l', 'lambda', 'Utilitarian', 'incl trans', 'Paretian', 'incl trans'
WRITE(*, "(6(F16.7,1X))"), gtau_l(2), lamss2, aggvaluess2, aggvalue, W_par_ss2, W_par
WRITE(*, "(5(A8,1X))"), 'Output', 'incl trans', 'r', 'r(y)', 'hours'
WRITE(*, "(5(F16.7,1X))"), Yss2, Ytr, rss2, (1.+rss2)**(1./period)-1., 1.-leisss2



! save welfare results
DO j=1,Nstar
	Voutmat(:,j) = V0(:,j)
	Voutmat(:,j+Nstar) = Vss1(:,j)
	Voutmat(:,j+2*Nstar) = Vss2(:,j)
END DO
DO itr=1,Ntrans
	laptrmat(1:Ngrid,itr) = laptr(itr,:,1)
	laptrmat(Ngrid+1:2*Ngrid,itr) = laptr(itr,:,2)
	ctrmat(1:Ngrid,itr) = ctr(itr,:,1)
	ctrmat(Ngrid+1:2*Ngrid,itr) = ctr(itr,:,2)
END DO

OPEN (unit = 5, file = "res_V.OUT")
WRITE(5,"(1x,16f8.4)") ((Voutmat(i,j), j=1,3*Nstar), i=1,Ngrid)
CLOSE(5)
OPEN (unit = 5, file = "res_ctrmat.OUT")
WRITE(5,"(16(f8.4,1X))") ((ctrmat(i,j), j=1,Ntrans), i=1,Nstar*Ngrid)
CLOSE(5)
OPEN (unit = 5, file = "res_utrmat.OUT")
WRITE(5,"(16(f20.4,1X))") ((utrmat(i,j), j=1,Ntrans), i=1,Nstar*Ngrid)
CLOSE(5)
OPEN (unit = 5, file = "res_laptrmat.OUT")
WRITE(5,"(16(f8.4,1X))") ((laptrmat(i,j), j=1,Ntrans), i=1,Nstar*Ngrid)
CLOSE(5)
OPEN (unit = 5, file = "res_Vtrmat.OUT")
WRITE(5,"(16(1x,f20.4))") ((Vtrmat(i,j), j=1,Ntrans), i=1,Nstar*Ngrid)
CLOSE(5)



CONTAINS 
  
!******************************************************************************!
!************** SUBROUTINES BELOW, FUNCTIONS BELOW*****************************!
!******************************************************************************!
  SUBROUTINE equil(rss,wss,lamss,knss,Gamss,Vss,Kss,Nss,leisss,lapss,kppss,drss,Vc,Vl,css,aggCss)
  USE findroot1D
  integer, PARAMETER :: usediscrete = 1 ! Set this to 1 when using welfare numbers. 
  REAL(dp), DIMENSION(1:Ngrid,Nstar) :: kpp, Gamma, mp, EMUp, m, m0, k, G, Gamma1,cons  
  REAL(dp), DIMENSION(1:Ngrid,Nstar) :: lap, cp, V, oldlap, certeq 
  REAL(dp) :: agglabor, temp, aggvalue, aggcapital, aggconsumption, aggdisp, aggleisure, aggcerteq
  REAL(dp) :: temp2
  REAL(dp) :: dlam, lambda1, lambda2, fgbc
  REAL(dp) :: kn, k0, k2
  REAL(dp) :: d1, d2,d3, rcrit, meankn, rimplied, r1,r2,r3, diffL, lambda_implied
  REAL(dp) :: W_par, Y
  INTEGER :: i, iz, ik,is, iter, itgam, discrete, switched
  INTEGER :: s, j, ii, itergbc, itk,itl
  REAL(dp), PARAMETER :: tol_l = 1.D-4, tol_lam = 1.D-4, tol_r = 1.D-4, tol_g = 1.D-6*Ngrid/201.
  REAL(dp), PARAMETER :: minr = .2D0, maxrpar = .25D0
!   REAL(dp), PARAMETER :: minr = .12D0, maxrpar = .15D0
  REAL(dp), intent(out) :: rss, wss, lamss, knss, Kss, Nss, leisss, aggCss
  REAL(dp), DIMENSION(Ngrid,Nstar), intent(out) :: Gamss, Vss, lapss, kppss, Vc, Vl, css
  integer, dimension(Ngrid, Nstar), intent(out) :: drss
  REAL(dp), dimension(Ngrid) :: kindex
  integer, dimension(Ngrid,Nstar) :: dr, draux
  REAL(dp), dimension(Ngrid,Nstar) :: ind
  REAL(dp), dimension(Ngrid*Nstar,Ngrid*Nstar) :: dridmat


  ! initialization of kpp, lap and Gamma
  ! Initial guess for tomorrow's policy function (here zero net-investment).
  DO i = 1, Nstar
     kpp(:,i) = (1.0D0 - delta)*kp
     lap(:,i) = MIN(1.0D0 - kp/kmax, 0.99)
  END DO
  DO i=1,Nstar
     Gamma(:,i)=SSprob(1,i)/DBLE(Ngrid)
  END DO

  if (tau_l>0) then
    lambda1 = 1.1D0 
    lambda2 = 1.3D0 
  else
  if (taxfunction==1) then
    lambda1 = 0.5D0
    lambda2 = 0.7D0  
  else
    lambda1 = 0.3D0
    lambda2 = .4D0
  end if
  end if

  itergbc = 0
  if (itergbc == 0) then
	 lambda = .5D0*lambda1 + .5D0*lambda2
  end if
  if (fixedprices==1) then
     lambda = lambda1
  end if

  dlam = 1.D0
  discrete = 0; switched = 0

lamloop:  DO WHILE (ABS(dlam)> tol_lam) 

	mN = maxN     
	r = maxrpar 
		
    s = 0		! Initial value of the counter for the bisection used for interest rate
    d1 = 1.0 	! Initial value for the interest rate loop's convergence measure.           

rloop:   DO WHILE (d1 > tol_r) 
    kn = ((r+delta)/alpha)**(1.D0/(alpha-1.D0));	  ! capital labor ratio implied by r
    w = (1.D0-alpha)*kn**(alpha); ! wage implied by the capital labor ratio.
    s = s+1;                             			!% s is the # of iterations started

    diffL=1.D0
    iter=0		

        
!************  find optimal labor and consumption policies ********
! 		2 ways:
	IF (usediscrete == 1 .AND. discrete==1) THEN
! 1. using value function iteration
		CALL PFIdiscrete(kpp,lap,V,dr)
! 2. using policy function iteration
    ELSE
        DO WHILE(diffL>tol_l) 
           iter=iter+1
           IF (iter == 3500) THEN
              stop "PFI does not converge in 3500 iterations!!!"
           END IF
           
           oldlap=lap
           CALL PFI(kpp,lap,m) 
           diffL = MAXVAL(ABS((oldlap(:,:)-lap(:,:))/lap(:,:)));
        END DO
    	   call getV(kpp,lap,V,0) !get (dis)value due to labor
    END IF

!****************** get stationary distribution Gamma.
	d3 = 1.D0 ! convergence measure for Gamma
	itgam = 0
	
    DO i = 1, Ngrid
       kindex(i) = i
    END DO
    DO i=1, Nstar  
       ind(:,i) = myinterp1D(kp,kindex,kpp(:,i))	
    END DO    

   	dr = NINT(ind)
    WHERE (dr <= 0)
       dr =1
    END WHERE
    WHERE (dr > Ngrid)
       dr = Ngrid
    END WHERE

	DO WHILE (d3>tol_g)
	    Gamma1 = 0.D0
		DO i=1,Ngrid
			draux = 0
			WHERE (dr == i)
			    draux = 1
			END WHERE
		    DO j=1,Nstar
				Gamma1(i,j) = DOT_PRODUCT(draux(:,j),Gamma(:,j))
			END DO
		END DO
        Gamma1 = MATMUL(Gamma1,prob)
        DO j=1,Nstar
           Gamma1(:,j) = SSprob(1,j)*Gamma1(:,j)/(sum(Gamma1(:,j)))
        END DO
        d3 = MAXVAL(ABS(Gamma1-Gamma)/(1.D0+Gamma)) !  % Update the convergence measure.   
        Gamma = Gamma1;                             !  % And finally update Gamma as the normalized Gamma1.    
	END DO

        
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CHECK MARKET CLEARING AND UPDATE INTEREST RATE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!            
        agglabor=0.0D0	!Calculate aggregate labor
        DO j=1,Nstar
           temp=z(j)*DOT_PRODUCT(lap(:,j),Gamma(:,j))
           agglabor=agglabor+temp
        END DO

        aggcapital=SUM(MATMUL(kp,Gamma));
        meankn = aggcapital/agglabor;			! % The average capital labor ratio.
		IF (meankn>0) THEN
			rimplied = alpha*meankn**(alpha-1.D0)-delta	! % and the implied interest rate 
 		 ELSE
			rimplied = MAX(1./beta, 3.33)
		END IF

		if (fixedprices==1) then
			exit lamloop
		end if
                
        IF (s == 1) THEN
           r1 = max(rimplied,minr)
           r2 = r
        END IF
        
        IF (rimplied>r .AND. s>1) THEN
           r1 = r;
        else 
           r2 = r;
        END IF

        ! update guess for r:
        r3 = (r1+r2)/2.0;
        d1 = ABS(r3-r)/(1.0+ABS(r));
        r = r3;  

        PRINT*, 'Interest rate bracket', '  ', 'Conv. metric'
        WRITE(*,"(3(F10.5))"), r1,  r2, d1
        
     END DO rloop 
    
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CHECK GOV BC AND LAMBDA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%!            
     
     aggdisp=0.0D0 !Calculate aggregate disposable income
	 temp2 = 0.0D0
		DO j=1,Nstar
			if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
				temp=DOT_PRODUCT((r*kp+w*z(j)*lap(:,j))**(1.0-tau_l),Gamma(:,j))
			else if (taxfunction==3) then
				temp=DOT_PRODUCT((w*z(j)*lap(:,j))**(1.0-tau_l),Gamma(:,j))
				temp2 = temp2+ DOT_PRODUCT((1.-tau_k)*r*kp,Gamma(:,j))
			else
				temp=DOT_PRODUCT((r*kp+w*z(j)*lap(:,j))**(1.0+tau_l),Gamma(:,j))
			end if
			aggdisp=aggdisp+temp
		END DO
     ! check if the GBC holds
		IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
			SELECT CASE (govfixed)
				CASE (0)
				lambda_implied=(1.0-gov)*(r*aggcapital+w*agglabor)/aggdisp				
				CASE (1)
				lambda_implied=(r*aggcapital+w*agglabor-govexp)/aggdisp					
			END SELECT
		ELSE IF (taxfunction==3) THEN
			SELECT CASE (govfixed)
				CASE (0)
				lambda_implied = ((1.0-gov)*(r*aggcapital+w*agglabor) & 
						- temp2)/aggdisp			
				CASE (1)
				lambda_implied = (r*aggcapital+w*agglabor -govexp & 
						- temp2)/aggdisp			
			END SELECT
		ELSE
			SELECT CASE (govfixed)
				CASE (0)
				lambda_implied=(gov)*(r*aggcapital+w*agglabor)/aggdisp
				CASE (1)
				lambda_implied=govexp/aggdisp
			END SELECT
		END IF
     
	! update lambda
     IF (lambda_implied>lambda .AND. s>1) THEN
			lambda1=lambda;
			lambda=0.6*lambda1+0.4*lambda2
		 ELSE
			lambda2=lambda;
			lambda=0.4*lambda1+0.6*lambda2
	   	END IF
     dlam = lambda2 - lambda1
     itergbc = itergbc +1

     IF (dlam<2*tol_lam .AND. switched==0) THEN
		discrete = 1
		switched = 1
     END IF 
     
     PRINT*, ''
     PRINT*, 'Iteration_GBC:', itergbc
     PRINT*, '  [lambda1  lambda2] ', '  lambda'
     WRITE(*,"(3(F10.5))"), lambda1, lambda2, lambda
  END DO lamloop

!%%%%%%%%%%%% ONCE R AND LAMBDA HAVE BEEN OBTAINED: %%%%%%%%%%%% 
!%%%%%%%%%%%% COMPUTE DISTRIBUTIONS OF OTHER VARIABLES %%%%%%%%%%%% 

	aggleisure=0.0D0	!Calculate aggregate leisure
	DO j=1,Nstar
	   temp=DOT_PRODUCT(1.D0-lap(:,j),Gamma(:,j))
	   aggleisure=aggleisure+temp
	END DO

	! compute consumption
	if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
		do j=1,Nstar
     	css(:,j) = kp+lambda*(w*Z(j)*lap(:,j) + r*kp)**(1.D0-tau_l) - kpp(:,j) 
	    end do
	else if (taxfunction==3) then
		do j=1,Nstar
     	css(:,j) = kp+lambda*(w*Z(j)*lap(:,j))**(1.D0-tau_l) + &
 			(1.-tau_k) * r*kp - kpp(:,j) 
	    end do		
	else
		do j=1,Nstar
		css(:,j) = kp+(w*Z(j)*lap(:,j) + r*kp)-lambda*(w*Z(j)*lap(:,j) + r*kp)**(1.D0+tau_l)-kpp(:,j)
		end do
    end if
	aggconsumption=0.0D0
	DO j=1,Nstar
		temp = dot_product(css(:,j),Gamma(:,j))
		aggconsumption = aggconsumption+temp
	END DO

  
  !******** calculate welfare ****************
  !************ get Value function on kp grid, Vp, but denoted V in this scope *****
	drss = dr
	call getV(kpp,lap,Vl,1) !get (dis)value due to labor
	Vc = V + Vl	! value due to the consumption component of the utility function
	! save some steady state outcomes for reporting
    rss = r; wss = w; lamss = lambda; knss = kn; Gamss = Gamma; Vss = V; lapss = lap; kppss = kpp
    Kss = aggcapital; Nss = agglabor; leisss = aggleisure; aggCss = aggconsumption;
  
	! save results
    OPEN (unit = 5, file = "res_k.OUT")
    WRITE(5,"(1x,4f9.4)") ((k(i,j), j=1,Nstar), i=1,Ngrid)
    CLOSE(5)
    OPEN (unit = 55, file = "res_c.OUT")
  	if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
      WRITE(55,"(1x,4f8.4)") ((kp(i)+lambda*(w*Z(j)*lap(i,j) + r*kp(i))**(1.D0-tau_l) - kpp(i,j), &
 			j=1,Nstar), i=1,Ngrid) 
	else if (taxfunction==3) then
      WRITE(55,"(1x,4f8.4)") ((kp(i)+lambda*(w*Z(j)*lap(i,j))**(1.D0-tau_l) + &
			(1.-tau_k)*r*kp(i) - kpp(i,j), j=1,Nstar), i=1,Ngrid) 
	else
      WRITE(55,"(1x,4f8.4)") ((kp(i)+(w*Z(j)*lap(i,j) + r*kp(i))-lambda*(w*Z(j)*lap(i,j) + r*kp(i))**(1.D0+tau_l) &
		- kpp(i,j), 	j=1,Nstar), i=1,Ngrid) 
    end if
    CLOSE(55)

end subroutine equil
  
  SUBROUTINE PFI(kpp,lap, m) !!INOUT: lap, kpp, !!OUT: m
! does policy function iteration on the household's savings policy
! given guesses for that policy and for the labor supply policy
! then updates the labor supply policy using bisection 
    use def
    IMPLICIT NONE
    REAL(dp), DIMENSION(Ngrid,Nstar), INTENT(OUT) :: m
    REAL(dp), DIMENSION(Ngrid,Nstar), INTENT(INOUT) :: kpp, lap 
    REAL(dp), PARAMETER :: tol_m = 1.D-6
    INTEGER :: i, j, ii, iter
    REAL(dp) :: d2, l1, k0, k1, k2
    REAL(dp), PARAMETER :: l0=0.0001,l2=0.9999
    REAL(dp), DIMENSION(1:Ngrid,Nstar) :: mp, EMUp, EMUp2, m0 
    
	! compute "cash on hand" mp for candidate policy functions
	! timing: choose kpp and lap given kp, r, w.
    DO i=1,Nstar
		if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
	       mp(:,i)=lambda*(lap(:,i)*w*z(i)+r*kp)**(1-tau_l) + kp 
		else if (taxfunction==3) then
	       mp(:,i)=lambda*(lap(:,i)*w*z(i))**(1-tau_l)+(1.-tau_k)*r*kp + kp 
		else
	       mp(:,i)=(lap(:,i)*w*z(i)+r*kp)-lambda*(lap(:,i)*w*z(i)+r*kp)**(1+tau_l) + kp 
		end if
    END DO
    
    d2 = 1.D0;   ! Initial value for the loop's convergence measure.
    m0 = 0.D0;        
    iter = 0
	k0=0.01; k2=kp(Ngrid)
    
	! policy function iteration using endogenous grid point method
    DO WHILE (d2>tol_m)                                
       iter = iter +1    
       ! Compute EMUp, expected marginal utility tomorrow times the marginal return to saving
	   DO i=1,Nstar
		if (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) then
		   EMUp(:,i) = (mp(:,i) - MAX(kpp(:,i),phi))**(-sigma) * &
			(1+lambda*(1-tau_l)*(w*z(i)*lap(:,i)+r*kp)**(-tau_l)*r)
		else if (taxfunction==3) then
		   EMUp(:,i) = (mp(:,i) - MAX(kpp(:,i),phi))**(-sigma) * &
			(1+(1.-tau_k)*r)
		else
		   EMUp(:,i) = (mp(:,i) - MAX(kpp(:,i),phi))**(-sigma) * &
			(1+r-r*lambda*(1+tau_l)*(w*z(i)*lap(:,i)+r*kp)**(tau_l))
		end if
	   END DO
       EMUp = MATMUL(EMUp,TRANSPOSE(prob))  
       DO i=1,Nstar
          m(:,i) = (beta*EMUp(:,i))**(-1.D0/sigma) + kp;  
          ! Given EMUp, we get c = (beta*EMUp)^(-1/sigma) and then cash on hand today as m = c+kp.
       END DO
       d2 = MAXVAL(ABS(m0-m)/(1+ABS(m)));! Update convergence measure.
       m0 = m;                           ! Update initial value for cash on hand
       !Interpolate the kp,m policy onto mp space.			
       !given m(:,i) <->  x and kp  <-> y; get  kpp(:,i) <-> yi from mp(:,i)  <->  xi       
       DO i=1, Nstar  
          kpp(:,i) = myinterp1D(m(:,i),kp,mp(:,i))	
       END DO	
	   WHERE ( kpp < 0 ) kpp=0
    END DO
    
    
    !************  Update the labor policy function *****************************
    ! given z_i and kp_j, find lap_ji from intratemporal FOC: F[u'_c(z,kp,kpp)-u'_l(z)] = 0.
    DO i=1, Nstar
       DO j=1,Ngrid
          kpm = kpp(j,i);
          km = kp(j);
          zm = z(i);
          l1=maxfind(fl,l0,l2)
          IF (l1==0) l1=l0
          lap(j,i) = bisect(fl, l1, l2,1)
       END DO
    END DO

  END SUBROUTINE PFI
!******************************************************************************!
  SUBROUTINE PFIdiscrete(kpp,lap,V,dr) !!INOUT: lap, kpp, !!OUT: m
! solves household dynamic problem using value function iteration, 
! solves static problem (labor supply) using bisection at every iteration
    use def
	use findroot1D
    IMPLICIT NONE
    REAL(dp), DIMENSION(Ngrid,Nstar), INTENT(OUT) :: kpp, lap, V
    integer, DIMENSION(1:Ngrid,Nstar), INTENT(OUT) :: dr
    REAL(dp), PARAMETER :: tol_m = 5.D-4
    INTEGER :: i, j, j2, iter
    REAL(dp) :: d2, l1, k0, k1, k2, Vcrit
    REAL(dp) :: temp2 
	INTEGER :: temp1(1)
    REAL(dp), PARAMETER :: l0=0.0001,l2=0.9999
    REAL(dp), DIMENSION(1:Ngrid,Nstar) :: newV, EV
    REAL(dp), DIMENSION(Ngrid) :: ctemp, ltemp, vtemp
    REAL(dp), DIMENSION(Ngrid,Ngrid,Nstar) :: lap3
! 	some objects used for reporting and control:
    REAL(dp), DIMENSION(Ngrid,(Ngrid-1)/10) :: ctempout, ltempout, Vtempout, EVtempout, utempout

	! initialize value function, counter and convergence measure
	V = 0.0D0; newV = V;
	Vcrit = 1.D0; iter = 0
	
DO WHILE ( Vcrit > tol_m )
	iter = iter+1
	! solve the household's labor supply problem given a savings policy
     DO j2 = 1, Ngrid
        DO i=1, Nstar
           DO j=1,Ngrid
        	  kpm = kp(j2); 
              km = kp(j);
              zm = z(i);
              l1=maxfind(fl,l0,l2)
              IF (l1==0) l1=l0
              lap3(j2,j,i) = bisect(fl, l1, l2,1)
           END DO
        END DO
     END DO

     EV=MATMUL(V,TRANSPOSE(prob)) 

	! value function iteration, given a labor supply policy
     DO j = 1, Ngrid
        DO i = 1, Nstar
			! compute consumption given the labor supply policy, for different savings choices
! 			note: in each expression, the first kp contains assets
! 			brought into the period, while the last kp contains values
! 			considered for kpp, using the kp grid.
			IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
	           ctemp = lambda*(r*kp(j)+w*z(i)*lap3(:,j,i))**(1.0-tau_l)+kp(j) - kp
			ELSE IF (taxfunction==3) THEN
	           ctemp = lambda*(w*z(i)*lap3(:,j,i))**(1.0-tau_l) + &
					(1.-tau_k) * r*kp(j) + kp(j) - kp 
			ELSE
	           ctemp = (r*kp(j)+w*z(i)*lap3(:,j,i))-lambda*(r*kp(j)+w*z(i)*lap3(:,j,i))**(1.0+tau_l)+kp(j) &
					- kp 
			END IF
           ltemp = lap3(:,j,i);
			! determine optimal choice
           vtemp = util(ctemp,ltemp) + beta*EV(:,i) 
           temp2 = MAXVAL(vtemp) 
           temp1(1:1) = MAXLOC(vtemp)
           newV(j,i) = temp2 
           dr(j,i) = temp1(1)
           lap(j,i) = lap3(temp1(1),j,i)

			! save some values for outputting and control
			IF (i==4 .AND. MOD(REAL(j),10.)==0) THEN
				ctempout(:,j/10) = ctemp
				ltempout(:,j/10) = ltemp
				utempout(:,j/10) = util(ctemp,ltemp)
				Vtempout(:,j/10) = vtemp
				EVtempout(:,j/10) = EV(:,i)	
			END IF
        END DO !i
     END DO !j

	! check convergence, update V
	Vcrit = MAXVAL(ABS(newV-V)/(1+ABS(V)))
	V = newV
	PRINT*, "iter: ", iter, " Vcrit: ", Vcrit
END DO !while

! update the savings policy
DO j=1,Nstar
	kpp(:,j) = kp(dr(:,j))
END DO

	! save some values for control
	OPEN (unit = 5, file = "res_cchoicess.out")
	WRITE(5,"(20(1x,f16.4))") ((ctempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_lchoicess.out")
	WRITE(5,"(20(1x,f16.4))") ((ltempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_Vchoicess.out")
	WRITE(5,"(20(1x,f20.4))") ((Vtempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_EVchoicess.out")
	WRITE(5,"(20(1x,f16.4))") ((EVtempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_uchoicess.out")
	WRITE(5,"(20(1x,f20.4))") ((utempout(i,j2), j2=1,20), i=1,Ngrid)
	CLOSE(5)	
	OPEN (unit = 5, file = "res_PFIdr.out")
	WRITE(5,"(4(1x,I4))") ((dr(i,j2), j2=1,Nstar), i=1,Ngrid)
	CLOSE(5)	

    

  END SUBROUTINE PFIdiscrete
!******************************************************************************!
  SUBROUTINE getV(kpp,lap,Vp,onlyleisure) !!INOUT: lap, kpp, !!OUT: Vp
! computes value function using policy functions
! The option onlyleisure allows outputting only the value due to utility from leisure
    use def
    IMPLICIT NONE
    INTEGER, PARAMETER :: interpolate = 0
	INTEGER, INTENT(IN) :: onlyleisure
    REAL(dp), DIMENSION(Ngrid,Nstar), INTENT(OUT) :: Vp
    REAL(dp), DIMENSION(Ngrid,Nstar), INTENT(IN) :: kpp, lap 
    INTEGER :: i, j, ii, j2
    REAL(dp), DIMENSION(1:Ngrid,Nstar) :: mp, m, EMUp, k
    REAL(dp), DIMENSION(1:Ngrid,Nstar) :: cp, up
    REAL(dp), DIMENSION(1:Ngrid,Nstar) :: EV, newV
    INTEGER, DIMENSION(Ngrid,Nstar) :: dr 
    REAL(dp), DIMENSION(Ngrid,Nstar) :: ind
    REAL(dp), DIMENSION(Ngrid) :: kindex
    REAL(dp), DIMENSION(Ngrid*Nstar,Ngrid*Nstar) :: dridmat
	REAL(dp), DIMENSION(Ngrid*Nstar) :: newVt, uplong
	
    IF (onlyleisure==0) THEN
    ! compute "cash on hand" mp for candidate policy functions
	! timing: choose kpp and lap given kp, r, w.
	DO i=1,Nstar
		IF (taxfunction==1 .OR. (taxfunction==2 .AND. tau_l>0)) THEN
	       mp(:,i)=lambda*(lap(:,i)*w*z(i)+r*kp)**(1-tau_l) + kp 
	    ELSE IF (taxfunction==3) THEN
	       mp(:,i)=lambda*(lap(:,i)*w*z(i))**(1-tau_l) + (1.-tau_k)*r*kp & 
	 			+ kp 
		ELSE 
	       mp(:,i)=(lap(:,i)*w*z(i)+r*kp)-lambda*(lap(:,i)*w*z(i)+r*kp)**(1+tau_l) + kp 
		END IF
    END DO

! 	policies kpp and lap imply utility up given kp, z.
    cp = mp - kpp
	DO j=1,Nstar
		up(:,j) = util(cp(:,j),lap(:,j))	
	END DO
	ELSE !only utility from leisure
		DO j=1,Nstar
			up(:,j) = thet*lap(:,j)**(1.D0+epsi)/(1.D0+epsi)
		END DO
	END IF

	IF ( interpolate == 1 ) THEN
	    DO j=1,Nstar
	    		uplong((j-1)*Ngrid+1:(j-1)*Ngrid+Ngrid) = up(:,j)
	    END DO		
	END IF

    DO i = 1, Ngrid
       kindex(i) = i
    END DO
    DO i=1, Nstar  
       ind(:,i) = myinterp1D(kp,kindex,kpp(:,i))	
    END DO    

    IF ( interpolate == 0 ) THEN
	    dr = NINT(ind)
	    WHERE (dr <= 0)
	       dr =1
	    END WHERE
	    WHERE (dr > Ngrid)
	       dr = Ngrid
	    END WHERE    	
	ELSE
		WHERE ( ind < 1 )
			ind = 1.D0
		END WHERE
		WHERE ( ind >= Ngrid )
			ind = Ngrid-.001
		END WHERE
		dridmat = 0.D0
		DO j = 1,Nstar
		    DO i = 1, Ngrid
				DO j2 = 1,Nstar
					dridmat((j-1)*Ngrid+i,(j2-1)*Ngrid+floor(ind(i,j))) = prob(j,j2)*(1-(ind(i,j)-floor(ind(i,j))))
					dridmat((j-1)*Ngrid+i,(j2-1)*Ngrid+floor(ind(i,j))+1) = prob(j,j2)*(ind(i,j)-floor(ind(i,j)))
				END DO
			END DO 
		END DO
    END IF
    
    ! Iterate over the policy function for 500 periods to obtain V.
	! Initialize.
    EV = 0.0D0;
    newV = 0.0D0; newVt = 0.0D0;
	DO ii = 1,500
		IF ( interpolate == 1 ) THEN
			newVt = matmul(dridmat,newVt)
			newVt = uplong + beta*newVt
		ELSE
			DO i=1,Nstar
		       newV(:,i)=newV(dr(:,i),i)
		    END DO
			newV=MATMUL(newV,TRANSPOSE(prob)) 
			newV = up + beta*newV 
		END IF
	END DO
	
	IF ( interpolate == 0 ) THEN
		Vp = newV
	ELSE
		DO j=1,Nstar
			Vp(:,j) = newVt((j-1)*Ngrid+1:(j-1)*Ngrid+Ngrid)
		END DO
	END IF

  END SUBROUTINE GETV

!******************************************************************************!  

  
END PROGRAM aiyagari

