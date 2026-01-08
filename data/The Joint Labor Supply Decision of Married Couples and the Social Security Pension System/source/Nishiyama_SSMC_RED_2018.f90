!=========================================================================================
! This is a program developed for
!
! Nishiyama, Shinichi, "The Joint Labor Supply Decision of Married Couples and the U.S. 
! Social Security Pension System," Review of Economic Dynamics, Accepted in August 2018.
!
! The program solves a heterogeneous-agent dynamic general-equilibrium overlapping-
! generations model with single and married households for steady-state equilibria and 
! equilibrium transition paths.
!
! Shinichi Nishiyama
! Graduate School/Faculty of Economics
! Kyoto University
! Last Update: 08/24/2018
!=========================================================================================
PROGRAM Nishiyama_SSMC_RED_2018

INCLUDE 'link_fnl_static.h'       ! or 'link_f90_static.h'
!DEC$ OBJCOMMENT LIB:'libiomp5md.lib'

USE NEQNF_INT					  ! nonlinear eq solver: Powell hybrid algorithm
USE ERSET_INT					  ! skip error messages
USE IERCD_INT					  ! error code
USE CPSEC_INT					  ! CPU time
USE GAMDF_INT					  ! gamma cumulative distribution function
USE LINEAR_OPERATORS

IMPLICIT NONE

INTEGER, PARAMETER ::			&
	imax	=  27,				& ! number of wealth nodes
	i1max	=  15,				& ! number of average historical earnings nodes: husband
	i2max	=  15,				& ! number of average historical earnings nodes: wife
	j1max	=   5,				& ! number of working ability nodes: husband
	j2max	=   5,				& ! number of working ability nodes: wife
	kmax	=  80,				& ! highest possible age
	kr		=  46,				& ! full-retirement age
	kr1		=  46,				& ! change in AIME calculation 
	tmax	= 121,				& ! 1:initial steady state tmax:final steady state
	beq_no	=   1				  ! 0:full annuitization 1:accidental bequests
INTEGER, PARAMETER ::			& ! number of working ability nodes: combined
	jkmax	= (j1max*j2max+j1max+j2max)*(kr-1)+3*(kmax-kr+1), &
	jkmax0	= (j1max*j2max+j1max+j2max)*(kr-1)
REAL(4), PARAMETER ::			&
	gamma	= 2.0,				& ! coefficient of relative risk aversion
	eta		= 2.0/3,			& ! share of married men & women at age 21
	lambda	= 0.60,				& ! efficiency parameter of consumption
	mu		= 0.015,			& ! labor-augmenting productivity growth rate
	nu		= 0.009,			& ! population growth rate
	rho		= 0.87,				& ! autocorrelation of log(z)
	sigma1	= 0.39,				& ! standard deviation of epsilon: husband
	sigma2	= 0.39,				& ! standard deviation of epsilon: wife
	theta	= 0.375,			& ! share parameter of capital stock
	xi		= 0.29,				& ! husband-wife wage correlation (modified 07/11/2018)
	frisch0 = 0.5,				& ! frisch elasticity target
	kyratio0= 3.0,				& ! baseline capital output ratio
	wgratio0= 0.0,				& ! baseline gov't wealth output
	hrs21tgt= 0.895,			& ! baseline ratio of female work hours to male work hours
	lpr1tgt = 0.887,			& ! baseline labor participation rate: male ages 25-54
	lpr2tgt = 0.745				  ! baseline labor participation rate: female ages 25-54
CHARACTER(80) ::				&
	dir,						& ! directory name for baseline or alternative economies
	dir0,						& ! directory name for baseline
	dir1						  ! directory name for temporary files
INTEGER ::						&
	n0, n1ss,					& ! iteration counters
	nn1, nn2,					& ! number of optimizations 0:total 1:error
	i,							& ! wealth index
	i1,							& ! average historical earnings index: husband
	i2,							& ! average historical earnings index: wife
	j1,							& ! working ability index: husband
	j2,							& ! working ability index: wife
	k,							& ! model age
	m,							& ! marital status 0:married 1:widower 2:widow
	jk,							& ! working ability index: combined
	t,							& ! model year
	bas_no,						& ! alternative baseline index
	cas_no,						& ! alternative policy index
	br,							& ! financing rule, period-by-period
								  ! 1:con_g 2:tr_ls 3:tau_i
	br1,						& ! financing rule, social security
								  ! 0:none  4:tau_p 5:tr_ss
	hprd,						& ! 1:h1=0 2:h2=0
	oasi_no,					& ! 1:current law 2:alternative(no spousal/survivors ben)
	run							  ! run index
REAL(4) ::						&
	alpha,						& ! share parameter of consumption
	beta,						& ! time discount factor
	beta0,						& ! growth-adjusted time-discount factor
	delta,						& ! depreciation rate of capital
	kappa,						& ! variable cost of female working
	kappa0, kappa1, kappa2,		& ! fixed cost of working: gamma dist parameters
	phi(kmax,0:2),				& ! survival rates 0:joint 1:male 2:female
	pi1(j1max,j1max,kmax),		& ! markov transition matrix for earnings: husband
	pi2(j2max,j2max,kmax),		& ! markov transition matrix for earnings: wife
	pim(0:2,0:2,kmax),			& ! markov transition matrix for marrital status
	xi0,						&
	zeta,						&
	a(imax),					& ! regular wealth nodes
	amin(kmax+1),				& ! minimum wealth
	b1(i1max),					& ! average historical earnings nodes: husband
	b2(i2max),					& ! average historical earnings nodes: wife
	e1(j1max,kmax),				& ! working ability nodes: husband
	e2(j2max,kmax),				& ! working ability nodes: wife
	e1bar(kmax),				& ! median working ability: husband
	e2bar(kmax),				& ! median working ability: wife
	ln_inc_v(kr-1),				& ! variance of log labor income
	p1(j1max),					& ! unconditional prob. distribution of e1 (by households)
	p2(j2max),					& ! unconditional prob. distribution of e2 (by households)
	nhh(kmax,0:2),				& ! no. of households by age 0:couple 1:widower 2:widow
	npp(kmax,0:2),				& ! no. of people by age 0:total 1:male 2:female
	nwk(kmax,0:2),				& ! no. of workers (h>0) by age 0:total 1:male 2:female
	hh0,						& ! number of households
	hh1,						& ! number of elderly households (k>=kr)
	pp0,						& ! total population
	pp1,						& ! elderly population (k>=kr)
	nnb(kmax,0:2),				& ! no. of newborn babies 0:couple 1:s male 2:s female
	vnb(j1max,j2max,0:2,tmax)	  ! value of newborn households
REAL(4), DIMENSION(j1max,j2max,kr-1,0:2):: &
	hr1jk,						& ! working hours: men
	hr2jk,						& ! working hours: women
	lp1jk,						& ! labor participation rate: men
	lp2jk						  ! labor participation rate: women
REAL(4), DIMENSION(imax,i1max,i2max,jkmax):: &
	c,							& ! consumption
	h1,							& ! working hours: husband
	h2,							& ! working hours: wife
	ap,							& ! e.o.p. wealth
	b1p,						& ! e.o.p. average historical earnings: husband
	b2p,						& ! e.o.p. average historical earnings: wife
	mv,							& ! marginal value matrix (dv/da)
	mv1,						& ! marginal value matrix (dv/db1)
	mv2,						& ! marginal value matrix (dv/db2)
	v							  ! value matrix
REAL(4), DIMENSION(imax,i1max,i2max,jkmax0):: &
	c_s,						& ! consumption
	h1s,						& ! working hours: husband
	h2s,						& ! working hours: wife
	aps,						& ! e.o.p. wealth
	b1ps,						& ! e.o.p. average historical earnings: husband
	b2ps,						& ! e.o.p. average historical earnings: wife
	pr2							  ! probability of married two-earner households
REAL(4), DIMENSION(:,:,:,:,:,:), ALLOCATABLE:: &
	temp_iter,					&
	temp_iter_s
REAL(8), DIMENSION(imax,i1max,i2max,jkmax):: &
	x,							& ! distribution of households
	x0							  ! distribution of households (initial steady state)
REAL(4), DIMENSION(imax,i1max,i2max,jkmax,3):: &
	diss, dfss					  ! s.s. decision rules 1:c 2:h1 3:h2
REAL(4), DIMENSION(imax,i1max,i2max,jkmax0,3):: &
	diss2, dfss2				  ! s.s. decision rules 1:c_s 2:h1s 3:h2s
REAL(4), DIMENSION(imax,i1max,i2max):: &
	Ev,							& ! exp'd value
	Emv,						& ! exp'd marginal value (dv/da)
	Emv1,						& ! exp'd marginal value (dv/db1)
	Emv2						  ! exp'd marginal value (dv/db2)
REAL(4), DIMENSION(0:2,i1max,i2max,kmax,0:2):: &
	tr_ss						  ! 0:s.s. benefits before v_phi adjustment
								  ! 1:marginal s.s. benefits: husband
								  ! 2:marginal s.s. benefits: wife
REAL(4) ::						&
	maxte,						& ! maximum taxable earnings (OASDI)
	scale,						& ! $1000/model unit
	th1, th2,					& ! thresholds for 0.90/0.32/0.15
	time0,						& ! elapsed time
	tfp							  ! total factor productivity
REAL(4), DIMENSION(kmax)::		&
	c0,							& ! avg. consumption by age
	h10,						& ! avg. working hours by age: husband
	h20,						& ! avg. working hours by age: wife
	lab10,						& ! avg. labor supply by age: husband
	lab20,						& ! avg. labor supply by age: wife
	ap0,						& ! avg. e.o.p. regular wealth by age
	b1p0,						& ! avg. e.o.p. average historical earnings: husband
	b2p0,						& ! avg. e.o.p. average historical earnings: wife
	tax_i0,						& ! avg. income tax payment by age
	tax_p0,						& ! avg. payroll tax payment by age
	exp_s0,						& ! avg. soc.sec.benefits by age
	tax_c0,						& ! avg. consumption tax payment by age
	wlt_p0,						& ! avg. b.o.p. wealth by age
	beq0,						& ! avg. bequests by age
	lpr10,						& ! avg. labor paticipation rate by age: husband
	lpr20,						& ! avg. labor paticipation rate by age: wife
	hrs10,						& ! avg. working hours by age: male workers
	hrs20,						& ! avg. working hours by age: female workers
	vcr0						  ! avg. value of current households at t=1 or 2
REAL(4) ::						&
	var_itr(9,tmax),			& ! iteration variables
	con_g,						& ! 1:government consumption
	tr_ls,						& ! 2:lump-sum transfer per person
	tau_i,						& ! 3:flat income tax rate or marginal tax rate limit
	tau_p,						& ! 4:payroll tax rate
	v_phi,						& ! 5:benefit parameter
	tau_c,						& ! 6:consumption tax rate
	wlt_g,						& ! 7:government wealth
	wlt_gp,						& !   government wealth (next period)
	klratio,					& ! 8:capital-labor ratio
	beq_a						  ! 9:accidental bequests (all)
REAL(4) ::						&
	var_tbl(25,tmax),			& ! table variables
	cap,						& ! 1:capital stock
	lab,						& ! 2:labor supply in efficiency units
	gdp,						& ! 3:gross domestic product
	n_inc,						& ! 4:national income
	lab1,						& ! 5:labor supply in efficiency unit: men
	lab2,						& ! 6:labor supply in efficiency unit: women
	hrs1,						& ! 7:working hours: men
	hrs2,						& ! 8:working hours: women
	con_p,						& ! 9:private consumption
	a_val,						& ! 10:average value of newborn households
	tax_i,						& ! 11:income tax revenue
	tax_p,						& ! 12:payroll tax revenue
	exp_s,						& ! 13:social security expenditure
	tax_c,						& ! 14:consumption tax revenue
	r,							& ! 15:interest rate
	w,							& ! 16:wage rate
	wlt_p,						& ! 17:private wealth
	beq,						& ! 18:accidental bequests
	lpr1, lpr1x,				& ! 19:labor participation rate: men 25-54
	lpr2,						& ! 20:labor participation rate: women 25-54
	lpr1a,						& ! 21:labor participation rate: men 21-65
	lpr2a,						& ! 22:labor participation rate: women 21-65
	hrs1a,						& ! 23:working hours: male workers
	hrs2a,						& ! 24:working hours: female workers
	dscrp,						& ! 25:statistical discrepancy
	lab0a,						& !    average earnings: all workers
	kyratio						  !    capital-gdp ratio
REAL(4) ::						&
	exp_s1(3),					& ! 1:old-age 2:spousal 3:survivors benefits
	exp_s2(3,2),				& ! 1:old-age 2:spousal 3:survivors benefits (population)
	exp_so						  ! other OASI benefits, legacy cost, and admin costs
REAL(4), DIMENSION(kr-1) ::		&
	var_e1,						&
	var_e2,						&
	cov_12,						&
	corr12,						&
	x_pr2
REAL(4) ::						&
	beta1, beta2,				& ! discount factor (old)
	kyratio1					  ! capital-gdp ratio (old)
!-----------------------------------------------------------------------------------------

	time0 = CPSEC()
	time0 = SECNDS(0.0)

	CALL ERSET(4,0,0)		! turns off messages and stopping for fatal class errors

	a = (/((i-1)**2.0, i = 1, imax)/)/20
	b1 = (/(i**1.5, i = 1, i1max)/)

	pi1 = 0; pi2 = 0
	IF (j1max>1) THEN
		CALL rouwenhorst_markov(j1max,kmax,rho,sigma1,pi1(:,:,1),e1,p1)
		CALL rouwenhorst_markov(j2max,kmax,rho,sigma2,pi2(:,:,1),e2,p2)
	ELSE
		e1 = 1; pi1(:,:,1) = 1; p1 = 1
		e2 = 1; pi2(:,:,1) = 1; p2 = 1
	END IF
	DO, k = 2, kmax
		SELECT CASE (k)
		CASE (1:kr-2); pi1(:,:,k) = pi1(:,:,1); pi2(:,:,k) = pi2(:,:,1)
		CASE (kr-1:kmax); pi1(:,1,k) = 1; pi2(:,1,k) = 1
		END SELECT
	END DO

	xi0 = xi/(xi+(1-xi)*DOT_PRODUCT(p1,p2))

!	Survey of Consumer Finances 2013
	e1bar(1:45) = (/ &	! Men (OLS, 21-80, avg of 21-65=1.0)
		0.3148, 0.3872, 0.4565, 0.5227, 0.5857, 0.6456, 0.7025, 0.7564, 0.8072, 0.8551, &
		0.9001, 0.9421, 0.9812, 1.0175, 1.0509, 1.0815, 1.1093, 1.1343, 1.1567, 1.1763, &
		1.1932, 1.2075, 1.2192, 1.2282, 1.2347, 1.2386, 1.2401, 1.2390, 1.2355, 1.2295, &
		1.2211, 1.2104, 1.1972, 1.1818, 1.1640, 1.1440, 1.1217, 1.0972, 1.0705, 1.0417, &
		1.0107, 0.9775, 0.9423, 0.9051, 0.8658 /)	! weight 0.5
	e1bar(kr:kmax) = 0.0
	e2bar(1:45) = (/ &	! Women (OLS, 21-80, avg of 21-65=1.0)
		0.3769, 0.4203, 0.4615, 0.5007, 0.5378, 0.5729, 0.6059, 0.6370, 0.6661, 0.6933, &
		0.7186, 0.7421, 0.7637, 0.7835, 0.8014, 0.8177, 0.8322, 0.8450, 0.8561, 0.8655, &
		0.8734, 0.8796, 0.8843, 0.8874, 0.8891, 0.8892, 0.8879, 0.8851, 0.8810, 0.8754, &
		0.8686, 0.8604, 0.8509, 0.8401, 0.8281, 0.8149, 0.8005, 0.7849, 0.7683, 0.7505, &
		0.7316, 0.7117, 0.6908, 0.6689, 0.6460 /)	! weight 0.8
	e2bar(kr:kmax) = 0.0

	DO k = 1, kmax
		e1(:,k) = e1bar(k)*e1(:,k)
		e2(:,k) = e2bar(k)*e2(:,k)
	END DO
	
!	Table 4.C6 Period life table 2010, SSA Annual Statistical Supplement 2014 (05/27/2015)
	phi(:,1) = 1.0-(/ &		! Men
		0.001213, 0.001304, 0.001345, 0.001350, &
		0.001342, 0.001340, 0.001342, 0.001356, 0.001380, &
		0.001408, 0.001435, 0.001466, 0.001499, 0.001539, &
		0.001592, 0.001660, 0.001741, 0.001837, 0.001953, &
		0.002084, 0.002241, 0.002439, 0.002686, 0.002975, &
		0.003297, 0.003639, 0.003997, 0.004366, 0.004750, &
		0.005156, 0.005596, 0.006078, 0.006605, 0.007174, &
		0.007805, 0.008464, 0.009095, 0.009676, 0.010245, &
		0.010865, 0.011592, 0.012444, 0.013451, 0.014608, &
		0.015927, 0.017370, 0.018895, 0.020484, 0.022191, &
		0.024139, 0.026364, 0.028808, 0.031480, 0.034442, &
		0.037855, 0.041725, 0.045932, 0.050469, 0.055465, &
		0.061179, 0.067698, 0.074923, 0.082891, 0.091725, &
		0.101575, 0.112568, 0.124795, 0.138305, 0.153107, &
		0.169195, 0.186543, 0.205115, 0.224867, 0.245744, &
		0.266454, 0.286625, 0.305869, 0.323783, 0.339972, 1.000000 /)
	phi(:,2) = 1.0-(/ &		! Women
		0.000423, 0.000454, 0.000476, 0.000494, &
		0.000511, 0.000531, 0.000553, 0.000579, 0.000608, &
		0.000641, 0.000677, 0.000719, 0.000765, 0.000818, &
		0.000879, 0.000948, 0.001022, 0.001100, 0.001185, &
		0.001279, 0.001387, 0.001518, 0.001676, 0.001858, &
		0.002055, 0.002262, 0.002480, 0.002709, 0.002947, &
		0.003209, 0.003484, 0.003751, 0.004000, 0.004246, &
		0.004520, 0.004836, 0.005185, 0.005570, 0.006001, &
		0.006489, 0.007046, 0.007686, 0.008419, 0.009249, &
		0.010201, 0.011255, 0.012372, 0.013538, 0.014793, &
		0.016233, 0.017882, 0.019693, 0.021671, 0.023866, &
		0.026437, 0.029368, 0.032519, 0.035870, 0.039555, &
		0.043828, 0.048808, 0.054434, 0.060762, 0.067889, &
		0.075926, 0.084968, 0.095093, 0.106352, 0.118777, &
		0.132384, 0.147181, 0.163161, 0.180314, 0.198615, &
		0.217125, 0.235558, 0.253602, 0.270923, 0.287178, 1.000000 /)
	phi(:,0) = 1-(1-phi(:,1))*(1-phi(:,2))

	pim = 0
	pim(0,0,:) = phi(:,1)*phi(:,2)
	pim(0,1,:) = phi(:,1)*(1-phi(:,2))
	pim(0,2,:) = (1-phi(:,1))*phi(:,2)
	pim(1,1,:) = phi(:,1)
	pim(2,2,:) = phi(:,2)

	nhh(1,:) = (/eta, 1-eta, 1-eta/)
	npp(1,:) = (/2.0, 1.0, 1.0/)
	DO k = 2, kmax
		nhh(k,:) = nhh(k-1,:).x.pim(:,:,k-1)/(1+nu)
		npp(k,1) = nhh(k,0)+nhh(k,1)
		npp(k,2) = nhh(k,0)+nhh(k,2)
		npp(k,0) = SUM(npp(k,1:2))
	END DO
	hh0 = SUM(nhh( 1:kmax,:))
	hh1 = SUM(nhh(kr:kmax,:))
	pp0 = SUM(npp( 1:kmax,0))
	pp1 = SUM(npp(kr:kmax,0))

!	Average Number of Newborn Babies per Woman (United Nations 2006)
	nnb = 0
	nnb(1:29,0) = (/ &	! OLS estimates by a cubic polynomial on ages 21-49
		0.0960, 0.1021, 0.1065, 0.1094, 0.1107, 0.1107, 0.1095, 0.1071, 0.1037, 0.0994, &
		0.0943, 0.0885, 0.0822, 0.0754, 0.0682, 0.0608, 0.0533, 0.0458, 0.0384, 0.0312, &
		0.0244, 0.0180, 0.0122, 0.0070, 0.0026, 0.0000, 0.0000, 0.0000, 0.0000 /)
	nnb(:,0) = nnb(:,0)/(eta+0.5*(1-eta))
	nnb(:,2) = nnb(:,0)*0.5
!-----------------------------------------------------------------------------------------

	con_g  = 5.0
	tr_ls  = 0.0
	tau_i  = 0.30
	tau_p  = 0.1007
	v_phi  = 1.0
	tau_c  = 0.0
	wlt_g  = 0.0
	wlt_gp = 0.0
	beq_a  = 0.0

	alpha  = 0.36
	kappa1 = 0.0
	kappa2 = 0.0

	c	= 0
	c_s	= 0
	pr2	= 1

	br   = 1
	br1  = 0
	hprd = 0
	run  = 0

	nn1 = 0
	nn2 = 0

	kyratio	= kyratio0
	klratio	= kyratio/(1-theta)
	tfp		= klratio**(-theta)/(1-theta)
	r		= 0.05
	delta	= theta*tfp*klratio**(theta-1)-r

	amin = 0
	DO k = kmax, 2, -1
		amin(k) = ((1+mu)*amin(k+1)-0.1*e1(1,k))/(1+r)
	END DO
!-----------------------------------------------------------------------------------------
!	Initial Steady-State Equilibrium (Baseline)

	t = 1
	bas_no = 1

!	imax=27; i1max=i2max=15; kr=46; kyratio=3.0; wgratio=0.0; tau_p=0.1007; frisch0=0.5;
!	gamma=2.0; eta=2.0/3; lambda=0.6; rho=0.87; sigma=0.39;  theta0=2.0; xi=0.29;
!	0.5*var_lnz; beq_a(k<=kr-1); hrs21tgt=0.895; lpr1tgt=0.887; lpr2tgt = 0.745;
	
	SELECT CASE (bas_no)
	CASE (1) ! main baseline
		dir0 = '../base01'; dir1 = '../temp1'; alpha = 0.652991; beta = 0.982699
		kappa0 = 2.0; kappa1 = 0.499736; kappa2 = 1.115312; kappa = 1.165433
		con_g = 5.799120; tau_i = 0.345428; wlt_g = 0.000000; beq_a = 0.01884407;
		scale = 87.765953
	CASE (2) ! gamma=4.0
		dir0 = '../base02'; dir1 = 'C:/temp2'; alpha = 0.631270; beta = 0.990188
		kappa0 = 2.0; kappa1 = 2.201960; kappa2 = 3.670166; kappa = 1.326012
		con_g = 5.353809; tau_i = 0.351791; wlt_g = 0.000000; beq_a = 0.02041167;
		scale = 95.067139
	CASE (3) ! rho=0.92, sigma=0.31
		dir0 = '../base03'; dir1 = 'D:/temp3'; alpha = 0.639718; beta = 0.985913
		kappa0 = 2.0; kappa1 = 0.564095; kappa2 = 0.636709; kappa = 1.135517
		con_g = 5.628399; tau_i = 0.347240; wlt_g = 0.000000; beq_a = 0.01882800;
		scale = 90.429482
	CASE (4) ! xi=0.40
		dir0 = '../base04'; dir1 = 'D:/temp4'; alpha = 0.649812; beta = 0.981402
		kappa0 = 2.0; kappa1 = 0.552381; kappa2 = 0.254869; kappa = 1.089926
		con_g = 5.735657; tau_i = 0.342052; wlt_g = 0.000000; beq_a = 0.01822783;
		scale = 88.737175
	END SELECT

	run = -1
	dir = dir0
	beta0 = beta*(1+mu)**(alpha*(1-gamma))
	maxte = 113.7/scale; th1 = 0.791*12/scale; th2 = 4.768*12/scale	! SSA 2013
	b1 = b1*maxte/b1(i1max); b2 = b1

	var_itr(:,1) = (/con_g,tr_ls,tau_i,tau_p,v_phi,tau_c,wlt_g,klratio,beq_a/)

	DO n0 = 1, 20
		CALL steady_state(0); ! CALL check_mv
		WRITE(*,'(/A,6X,A,7X,A,4X,A)')"Iteration","beta","K/Y","dif(K/L)"
		WRITE(*,'(I10,2F10.6,ES12.3)') n0, beta, kyratio, kyratio-kyratio0
		IF (ABS(kyratio-kyratio0)<1e-4) EXIT
		IF (n0==1) THEN
			beta1 = beta
			beta = beta1-0.025*(kyratio-kyratio0)
		ELSE
			beta2 = beta1; beta1 = beta
			beta = beta1-(beta1-beta2)/(kyratio-kyratio1)*(kyratio-kyratio0)
		END IF
		kyratio1 = kyratio
		beta0 = beta*(1+mu)**(alpha*(1-gamma))
	END DO
	CALL output3;  STOP

	CALL copy_ss(0,1); CALL copy_ss2(0,1); x0 = x

	cas_no = 1

	SELECT CASE (cas_no)
	CASE ( 1); dir = TRIM(dir0)//"/ss_reform1"
	END SELECT
!-----------------------------------------------------------------------------------------
!	Final Steady-State Equilibrium

	run = 0
	t = tmax
	DO n0 = 1, 6
		CALL copy_ss(1,1); CALL copy_ss2(1,1)
		var_itr(:,t) = var_itr(:,1)
		CALL steady_state(0)
	END DO
	CALL output3;  STOP
!-----------------------------------------------------------------------------------------
!	Equilibrium Transition Path

	DO n0 = 1, 6
		run = n0
		CALL output1
		var_itr(:,tmax) = var_itr(:,1)
		CALL transition_path
		CALL output3
	END DO

CONTAINS
!=========================================================================================
SUBROUTINE policy_schedule

	IF (t==1) THEN	! baseline solution (initial steady state)
		oasi_no = 1; br = 1; br1 = 0
	ELSEIF (t>1) THEN
		SELECT CASE (cas_no)
		CASE (1)
			br1 = 5
			SELECT CASE (n0)
			CASE (1); br = 2; oasi_no = 2
			CASE (2); br = 3; oasi_no = 2
			CASE (3); br = 2; oasi_no = 3
			CASE (4); br = 3; oasi_no = 3
			CASE (5); br = 2; oasi_no = 4
			CASE (6); br = 3; oasi_no = 4
			END SELECT
		END SELECT
	END IF

END SUBROUTINE policy_schedule
!-----------------------------------------------------------------------------------------
SUBROUTINE steady_state(flag)
INTEGER ::						&
	flag						  ! 0:full output 1:partial output
INTEGER ::						&
	n1
REAL(4) ::						&
	var_itr0(9),				& ! iteration variables (work)
	dif0(9)
REAL(8) ::						&
	xp(imax,i1max,i2max,jkmax)

	SELECT CASE (t)
	CASE (1);	 WRITE(*,'(/A,I4)') "Initial Steady State t =", t
	CASE (tmax); WRITE(*,'(/A,I4)') "Final Steady State t =", t
	END SELECT
	WRITE(*,'(/A,2(9X,A),2(4X,A))')"Iteration","r","w"," dif(br)","dif(K/L)"
	DO n1ss = 1, 10
		var_itr0 = var_itr(:,t)
		con_g	= var_itr(1,t)
		tr_ls	= var_itr(2,t)
		tau_i	= var_itr(3,t)
		tau_p	= var_itr(4,t)
		v_phi	= var_itr(5,t)
		tau_c	= var_itr(6,t)
		wlt_g	= var_itr(7,t)
		klratio	= var_itr(8,t)
		beq_a   = var_itr(9,t)
		CALL policy_schedule
		IF (n1ss==1) CALL set_trss

		var_itr(:,t) = (/con_g,tr_ls,tau_i,tau_p,v_phi,tau_c,wlt_g,klratio,beq_a/)
		r = tfp*theta*klratio**(theta-1)-delta
		w = tfp*(1-theta)*klratio**theta
		CALL optimization(0,v,mv,mv1,mv2)
		CALL distribution(0,x,xp); x = xp
		CALL aggregation
		var_itr(:,t) = (/con_g,tr_ls,tau_i,tau_p,v_phi,tau_c,wlt_g,klratio,beq_a/)

		dif0 = (var_itr(:,t)-var_itr0)/(1+ABS(var_itr0))
		dif0(7) = 1e-1*dif0(7)
		WRITE(*,'(I10,2F10.6,2ES12.3)') n1ss, r, w, dif0(8), dif0(MAX(1,br))
		IF (MAXVAL(ABS(dif0))<1e-4.AND.n1ss>1) EXIT
		var_itr(8,t) = 0.6*var_itr(8,t)+0.4*var_itr0(8)
		IF (t==1)    var_itr(8,t) = 0.5*var_itr(8,t)+0.5*var_itr0(8)
		IF (t==tmax) var_itr(8,t) = 0.8*var_itr(8,t)+0.2*var_itr0(8)
		IF (br==2.AND.oasi_no==3) var_itr(2,t) = 0.4*var_itr(2,t)+0.6*var_itr0(2)
	END DO
	IF (t==1) THEN
		CALL output1
		CALL write_vcr(t)
	END IF
	CALL output2a
	IF (flag==0) THEN
		CALL output2b
		CALL write_hours(t)
		CALL write_vnb(t)
	END IF

END SUBROUTINE steady_state
!-----------------------------------------------------------------------------------------
SUBROUTINE transition_path
INTEGER ::						&
	n1, n2, n3
REAL(4) ::						&
	var_itr0(9,tmax),			&
	dif0(9),					&
	dif1(9)
REAL(4), DIMENSION(imax,i1max,i2max,jkmax) :: &
	vp, mvp, mv1p, mv2p
REAL(8), DIMENSION(imax,i1max,i2max,jkmax) :: &
	xp
INTEGER ::						&
	status

	WRITE(*,'(/A,5X,A,4X,A)') "Iteration", "dif(br)", "dif(K/L)"
	ALLOCATE(temp_iter(imax,i1max,i2max,jkmax,tmax,6),STAT=status)
	IF (status/=0) STOP "*** Not enough memory: temp_iter ***"
!	IF (kappa0>0.0) THEN
!		ALLOCATE(temp_iter_s(imax,i1max,i2max,jkmax0,tmax,7),STAT=status)
!		IF (status/=0) STOP "*** Not enough memory: temp_iter_s ***"
!	END IF
	DO n1 = 1, 12
		t = tmax
		SELECT CASE (n1)
		CASE (1);	CALL copy_ss(1,1);    CALL copy_ss2(1,1)
		CASE (2:);	CALL copy_ss(1,tmax); CALL copy_ss2(1,tmax)
		END SELECT
		CALL steady_state(1)
		CALL copy_ss(0,tmax); CALL copy_ss2(0,tmax)
		var_itr0 = var_itr

		IF (n1==1) THEN
			DO t = 2, tmax-1
				var_itr(:,t) = var_itr(:,tmax)
			END DO
			var_itr(7,2) = var_itr(7,1)
			var_itr0 = var_itr
		ELSE
			WRITE(*,'(/A)') "Transition Path Backward"
			DO t = tmax-1, 2, -1
				con_g	= var_itr(1,t)
				tr_ls	= var_itr(2,t)
				tau_i	= var_itr(3,t)
				tau_p	= var_itr(4,t)
				v_phi	= var_itr(5,t)
				tau_c	= var_itr(6,t)
				wlt_g	= var_itr(7,t)
				wlt_gp	= var_itr(7,t+1)
				klratio	= var_itr(8,t)
				beq_a   = var_itr(9,t)
				CALL policy_schedule
				CALL set_trss
				var_itr(:,t) = (/con_g,tr_ls,tau_i,tau_p,v_phi,tau_c,wlt_g,klratio,beq_a/)
				r = tfp*theta*klratio**(theta-1)-delta
				w = tfp*(1-theta)*klratio**theta
				vp = v; mvp = mv; mv1p = mv1; mv2p = mv2
				CALL optimization(1,vp,mvp,mv1p,mv2p)
!				CALL rw_decision(0)
				IF (kappa0>0.0) CALL rw_decision2(0)
				CALL rw_decision3(0)
				IF (t==2) CALL write_vcr(t)
				IF (MOD(t,10)==0) WRITE(*,'(10X,I10)') t
			END DO
		END IF

		WRITE(*,'(/A)') "Transition Path Forward"
		DO t = 2, tmax-1
			con_g	= var_itr(1,t)
			tr_ls	= var_itr(2,t)
			tau_i	= var_itr(3,t)
			tau_p	= var_itr(4,t)
			v_phi	= var_itr(5,t)
			tau_c	= var_itr(6,t)
			wlt_g	= var_itr(7,t)
			wlt_gp	= var_itr(7,t+1)
			klratio	= var_itr(8,t)
			beq_a   = var_itr(9,t)
			CALL policy_schedule
			CALL set_trss
			r = tfp*theta*klratio**(theta-1)-delta
			w = tfp*(1-theta)*klratio**theta
			IF (n1>1) THEN
!				CALL rw_decision(1)
				IF (kappa0>0.0) CALL rw_decision2(1)
				CALL rw_decision3(1)
			END IF
			IF (t==2) x = x0
			CALL aggregation
			CALL distribution(1,x,xp); x = xp
			var_itr(:,t) = (/con_g,tr_ls,tau_i,tau_p,v_phi,tau_c,wlt_g,klratio,beq_a/)
			var_itr(7,t+1) = wlt_gp
		END DO
		
		CALL rw_iteration(0)
		dif0 = MAXVAL((var_itr-var_itr0)/(1+ABS(var_itr0)),2)
		dif1 = MINVAL((var_itr-var_itr0)/(1+ABS(var_itr0)),2)
		DO n3 = 1, 9
			IF (dif0(n3)<ABS(dif1(n3))) dif0(n3) = dif1(n3)
		END DO
		dif0(7) = 1e-1*dif0(7)

		WRITE(*,'(I10,2ES12.3)') n1, dif0(8), dif0(br)
		SELECT CASE (run)
		CASE (:0); OPEN (UNIT=11,FILE=TRIM(dir)//"/output.txt",POSITION="APPEND")
		CASE (1:); OPEN (UNIT=11,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
			"/output.txt",POSITION="APPEND")
		END SELECT
		WRITE(11,'(/I10,2ES12.3)') n1, dif0(8), dif0(br)
		CLOSE(UNIT=11)

		IF (MAXVAL(ABS(dif0))<1e-4) EXIT
		var_itr(8,:) = 0.6*var_itr(8,:)+0.4*var_itr0(8,:)
	END DO
	DEALLOCATE(temp_iter)
!	IF (kappa0>0.0) DEALLOCATE(temp_iter_s)

END SUBROUTINE transition_path
!-----------------------------------------------------------------------------------------
FUNCTION idx(j1,j2,k,m)
INTEGER :: idx, j1, j2, k, m

	SELECT CASE (k)
	CASE (1:kr-1)
		idx = (j1max*j2max+j1max+j2max)*(k-1)
		SELECT CASE (m)
		CASE (0); idx = idx+j1max*(j2-1)+j1
		CASE (1); idx = idx+j1max*j2max+j1
		CASE (2); idx = idx+j1max*j2max+j1max+j2
		END SELECT
	CASE (kr:)
		idx = (j1max*j2max+j1max+j2max)*(kr-1)+3*(k-kr)+(m+1)
	END SELECT

END FUNCTION idx
!-----------------------------------------------------------------------------------------
SUBROUTINE optimization(flag,vp,mvp,mv1p,mv2p)
INTEGER, INTENT(in) ::			&
	flag						  ! 0:steady state 1:transition path
REAL(4), INTENT(inout), DIMENSION(imax,i1max,i2max,jkmax) :: &
	vp,							& ! value (t+1)
	mvp,						& ! marginal value dv/da (t+1)
	mv1p,						& ! marginal value dv/db1 (t+1)
	mv2p						  ! marginal value dv/db2 (t+1)
INTEGER ::						&
	ip,							&
	i1p, i2p,					&
	j1p, j2p,					&
	mp,							&
	jk1, jk2,					&
	jkp
REAL(4) ::						&
	alpha,						& ! Gamma distribution parameter
	theta,						& ! Gamma distribution parameter
	kappa1a,					&
	mvs,						&
	mv1s,						&
	mv2s,						&
	vs
REAL(4) ::						&
	pix	,						& ! transition probability
	p,							& ! Pr(eta0<v-vs) = Pr(h2>0)
	vdif						  ! v-vs

	DO k = kmax, 1, -1
		IF (flag==0.AND.k<kmax) THEN	! steady state
			jk1 = idx(1,1,k+1,0)
			jk2 = idx(1,1,k+2,0)-1
			vp(:,:,:,jk1:jk2) = v(:,:,:,jk1:jk2)
			mvp(:,:,:,jk1:jk2) = mv(:,:,:,jk1:jk2)
			mv1p(:,:,:,jk1:jk2) = mv1(:,:,:,jk1:jk2)
			mv2p(:,:,:,jk1:jk2) = mv2(:,:,:,jk1:jk2)
		END IF
		DO m = 0, 2
		DO j2 = 1, j2max; IF ((k>=kr.OR.m==1).AND.j2>1) EXIT
		DO j1 = 1, j1max; IF ((k>=kr.OR.m==2).AND.j1>1) EXIT
			Ev = 0; Emv = 0; Emv1 = 0; Emv2 = 0
			IF (k<kmax) THEN
				DO mp = m, 2; IF (m==1.AND.mp==2) EXIT
				DO j2p = 1, j2max; IF ((k>=kr-1.OR.mp==1).AND.j2p>1) EXIT
				DO j1p = 1, j1max; IF ((k>=kr-1.OR.mp==2).AND.j1p>1) EXIT
					SELECT CASE (mp)
					CASE (0); 
						IF (j1==j2) THEN
							pix = (1-xi0)*pi1(j1,j1p,k)*pi2(j2,j2p,k) &
								+xi0*ABS(j1p==j2p)*pi1(j1,j1p,k)
						ELSE
							pix = pi1(j1,j1p,k)*pi2(j2,j2p,k)
						END IF
					CASE (1); pix = pi1(j1,j1p,k)
					CASE (2); pix = pi2(j2,j2p,k)
					END SELECT
					pix = pix*pim(m,mp,k)
					jkp = idx(j1p,j2p,k+1,mp)
					Ev = Ev + vp(:,:,:,jkp)*pix
					Emv = Emv + mvp(:,:,:,jkp)*pix
					Emv1 = Emv1 + mv1p(:,:,:,jkp)*pix
					Emv2 = Emv2 + mv2p(:,:,:,jkp)*pix
				END DO ! j1p
				END DO ! j2p
				END DO ! mp
			END IF
			jk = idx(j1,j2,k,m)
			DO i2 = 1, i2max
			DO i1 = 1, i1max
			DO i  = 1, imax
				CALL bellman_equation(c(i,i1,i2,jk),h1(i,i1,i2,jk),h2(i,i1,i2,jk), &
					ap(i,i1,i2,jk),b1p(i,i1,i2,jk),b2p(i,i1,i2,jk),mv(i,i1,i2,jk), &
					mv1(i,i1,i2,jk),mv2(i,i1,i2,jk),v(i,i1,i2,jk))
				IF (k<kr.AND.kappa0>0.0) THEN
					IF (m==0.AND.h1(i,i1,i2,jk)>1e-3.AND.h2(i,i1,i2,jk)>1e-3) THEN
						IF (h1(i,i1,i2,jk)<h2(i,i1,i2,jk)) THEN
							hprd = 1	! m=0, h1=0
						ELSE
							hprd = 2	! m=0, h2=0
						END IF
					ELSE IF (m==1.AND.h1(i,i1,i2,jk)>1e-3) THEN
						IF (a(i)+amin(k)-(1+mu)*amin(k+1)>0.1) hprd = 1	! m=1, h1=0
					ELSE IF (m==2.AND.h2(i,i1,i2,jk)>1e-3) THEN
						IF (a(i)+amin(k)-(1+mu)*amin(k+1)>0.1) hprd = 2	! m=2, h2=0
					END IF
					theta = kappa0
					kappa1a = kappa1*(1+(5.0*MAX(k-35,0)+10.0*MAX(k-40,0)**2)/100.0)
					IF (hprd>0) THEN
						CALL bellman_equation(c_s(i,i1,i2,jk),h1s(i,i1,i2,jk), &
							h2s(i,i1,i2,jk),aps(i,i1,i2,jk),b1ps(i,i1,i2,jk), &
							b2ps(i,i1,i2,jk),mvs,mv1s,mv2s,vs)
						SELECT CASE (m)
						CASE (0)
							IF (hprd==1) alpha = kappa1a
							IF (hprd==2) alpha = kappa1a+kappa2*nnb(k,m)
						CASE (1); alpha = kappa1a
						CASE (2); alpha = kappa1a+kappa2*nnb(k,m)
						END SELECT
						alpha = alpha/theta
						vdif = v(i,i1,i2,jk)-vs
						p = GAMDF(vdif/theta,alpha)
						pr2(i,i1,i2,jk) = p
						v(i,i1,i2,jk) = v(i,i1,i2,jk) + &
							alpha*theta*(1-GAMDF(vdif/theta,alpha+1))-vdif*(1-p)
						mv (i,i1,i2,jk) = p*mv (i,i1,i2,jk) + (1-p)*mvs
						mv1(i,i1,i2,jk) = p*mv1(i,i1,i2,jk) + (1-p)*mv1s
						mv2(i,i1,i2,jk) = p*mv2(i,i1,i2,jk) + (1-p)*mv2s
					ELSE
						c_s(i,i1,i2,jk) = c(i,i1,i2,jk)
						h1s(i,i1,i2,jk) = h1(i,i1,i2,jk)
						h2s(i,i1,i2,jk) = h2(i,i1,i2,jk)
						aps(i,i1,i2,jk) = ap(i,i1,i2,jk)
						b1ps(i,i1,i2,jk) = b1p(i,i1,i2,jk)
						b2ps(i,i1,i2,jk) = b2p(i,i1,i2,jk)
						pr2(i,i1,i2,jk) = 1
						IF (m/=1.AND.h2(i,i1,i2,jk)<1e-3) THEN
							alpha = kappa1a+kappa2*nnb(k,m)
						ELSEIF (m/=2.AND.h1(i,i1,i2,jk)<1e-3) THEN
							alpha = kappa1a
						ELSE
							alpha = 0
						END IF
						alpha = alpha/theta
						v(i,i1,i2,jk) = v(i,i1,i2,jk) + alpha*theta
					END IF
					hprd = 0
				END IF
			END DO ! i
			END DO ! i1
			END DO ! i2
		END DO ! j1
		END DO ! j2
		END DO ! m
		jk1 = idx(1,1,k,0)
		jk2 = idx(1,1,k+1,0)-1
		IF (t==1) vcr0(k) = SUM(v(:,:,:,jk1:jk2)*x (:,:,:,jk1:jk2))/npp(k,0)
		IF (t==2) vcr0(k) = SUM(v(:,:,:,jk1:jk2)*x0(:,:,:,jk1:jk2))/npp(k,0)
	END DO ! k
	DO j2 = 1, j2max
		DO j1 = 1, j1max
			vnb(j1,j2,0,t) = v(1,1,1,idx(j1,j2,1,0))
		END DO
		vnb(j2,1,1,t) = v(1,1,1,idx(j2,1,1,1))
		vnb(1,j2,2,t) = v(1,1,1,idx(1,j2,1,2))
	END DO

END SUBROUTINE optimization
!-----------------------------------------------------------------------------------------
SUBROUTINE bellman_equation(c_star,h1star,h2star,ap,b1p,b2p,mv,mv1,mv2,v)
REAL(4), INTENT(inout) :: &
	c_star,						& ! consumption
	h1star,						& ! working hours: husband
	h2star						  ! working hours: wife
REAL(4), INTENT(out) :: &
	ap,							& ! e.o.p. regular wealth
	b1p,						& ! e.o.p. average historical earnings: husband
	b2p,						& ! e.o.p. average historical earnings: wife
	mv,							& ! marginal value matrix (dv/da)
	mv1,						& ! marginal value matrix (dv/db1)
	mv2,						& ! marginal value matrix (dv/db2)
	v							  ! value matrix
INTEGER ::						&
	n0,							&
	ip,							&
	i1p, i2p,					&
	j1p, j2p,					&
	mp,							&
	jk1, jk2,					&
	jkp
REAL(4) ::						&
	u0,							& ! utility
	u1(3),						& ! marginal utility (u1,u2,u3)
	Evp,						& ! exp'd value
	Emvp,						& ! exp'd marginal value dv/da
	Emv1p,						& ! exp'd marginal value dv/db1
	Emv2p,						& ! exp'd marginal value dv/db2
	kinc,						& ! capital income
	linc1,						& ! husband's labor income
	linc2,						& ! wife's labor income
	trss,						& ! social security benefits
	d(3),						& ! decision (c,l1,l2)
	zero(3)						  ! zeros
REAL(8) ::						&
	w0, w1, w2					  ! weights

	DO n0 = 1, 2
		nn1 = nn1+1
		IF (c_star==0.0) THEN
			IF (k==kmax) THEN
				d = (/((1+r)*(a(i)+amin(k))+v_phi*tr_ss(0,i1,i2,k,m))/(1+tau_c),0.0,0.0/)
			ELSEIF (i==1) THEN
				jkp = idx(j1,j2,k+1,m)
				IF (k==kr-1) d = (/0.2,0.4,0.4/)
				IF (k<=kr-2) d = (/c(i,i1,i2,jkp),h1(i,i1,i2,jkp),h2(i,i1,i2,jkp)/)
			ELSE
				d = (/c(i-1,i1,i2,jk),h1(i-1,i1,i2,jk),h2(i-1,i1,i2,jk)/)
			END IF
		ELSE
			d = (/c_star,h1star,h2star/)
		END IF
		CALL NEQNF(cp0,d,XGUESS=d); CALL cp0(d,zero,0)

		IF (d(1)<0.0.OR.MAXVAL(d(2:3))>1.0) THEN						! debug
			WRITE (*,'(8I5,3F10.6)') i, i1, i2, j1, j2, k, m, hprd, d;	! STOP
		END IF

		c_star = d(1); h1star = d(2); h2star = d(3)
		IF (n0==2.OR.IERCD()<3.AND.MAXVAL(ABS(zero))<1e-3) EXIT
		nn2 = nn2+1
		c_star = 0.2; h1star = 0.4; h2star = 0.4
	END DO
	kinc = r*(a(i)+amin(k))
	linc1 = w*e1(j1,k)*d(2)
	linc2 = w*e2(j2,k)*d(3)
	trss = v_phi*tr_ss(0,i1,i2,k,m)
	ap = ((1+r)*(a(i)+amin(k))+linc1+linc2-itax(0,kinc,linc1,linc2,trss,m)-ptax(0,linc1,linc2) &
		+trss+(1+ABS(m==0))*(tr_ls+ABS(k<kr)*beq_a)-(1+tau_c)*d(1))/(1+mu)
	IF (beq_no==0.OR.ap<0.0) ap = ap/MAX(phi(k,m),0.1)
	b1p = ABS(k>=kr.OR.m==2.OR.(k>=kr1.AND.linc1<b1(i1)))*b1(i1) &
		+ABS(k<kr.AND.m/=2.AND.(k<kr1.OR.linc1>=b1(i1)))*((k-1)*b1(i1)+MIN(linc1,maxte))/k
	b2p = ABS(k>=kr.OR.m==1.OR.(k>=kr1.AND.linc2<b2(i2)))*b2(i2) &
		+ABS(k<kr.AND.m/=1.AND.(k<kr1.OR.linc2>=b2(i2)))*((k-1)*b2(i2)+MIN(linc2,maxte))/k

	IF (k==kmax) THEN
		Evp = 0; Emv1p = 0; Emv2p = 0
	ELSE
		DO ip = 1, imax-2; IF (ap-amin(k+1)<a(ip+1)) EXIT; END DO
		w0 = (ap-amin(k+1)-a(ip))/(a(ip+1)-a(ip))
		DO i1p = 1, i1max-2; IF (b1p<b1(i1p+1)) EXIT; END DO
		w1 = (b1p-b1(i1p))/(b1(i1p+1)-b1(i1p))
		DO i2p = 1, i2max-2; IF (b2p<b2(i2p+1)) EXIT; END DO
		w2 = (b2p-b2(i2p))/(b2(i2p+1)-b2(i2p))
		Evp = (1-w0)*SUM((/1-w1,w1/)*(Ev(ip,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/))) &
			+w0*SUM((/1-w1,w1/)*(Ev(ip+1,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))
		Emv1p = (1-w0)*SUM((/1-w1,w1/)*(Emv1(ip,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/))) &
			+w0*SUM((/1-w1,w1/)*(Emv1(ip+1,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))
		Emv2p = (1-w0)*SUM((/1-w1,w1/)*(Emv2(ip,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/))) &
			+w0*SUM((/1-w1,w1/)*(Emv2(ip+1,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))
	END IF

	CALL utility(d(1),1-d(2),1-kappa*nnb(k,m)-d(3),m,u0,u1)
	v = u0+beta0*Evp
	mv = (1+(1-itax(1,kinc,linc1,linc2,trss,m))*r)*u1(1)/(1+tau_c)
	mv1 = v_phi*tr_ss(1,i1,i2,k,m)*u1(1)/(1+tau_c) &
		+(ABS(k<kr.AND.m/=2)*REAL(k-1)/k+ABS(k>=kr.OR.m==2))*beta0*Emv1p
	mv2 = v_phi*tr_ss(2,i1,i2,k,m)*u1(1)/(1+tau_c) &
		+(ABS(k<kr.AND.m/=1)*REAL(k-1)/k+ABS(k>=kr.OR.m==1))*beta0*Emv2p

END SUBROUTINE bellman_equation
!-----------------------------------------------------------------------------------------
SUBROUTINE cp0(d,zero,n)
REAL(4) ::						&
	d(3),						& ! c, h1, h2
	zero(3)
INTEGER ::						&
	n							  ! dummy required by NEQNF
REAL(4) ::						&
	ap,							& ! e.o.p. wealth
	b1p,						& ! e.o.p. husband's historical earnings
	b2p,						& ! e.o.p. wife's historical earnings
	u0, u1(3),					& ! utliity, marginal utility
	Emvp,						& ! exp'd marginal value (wealth)
	Emv1p,						& ! exp'd marginal value (husband's historical earnings)
	Emv2p,						& ! exp'd marginal value (wife's historical earnings)
	kinc,						& ! capital income
	linc1,						& ! husband's labor income
	linc2,						& ! wife's labor income
	trss,						& ! social security benefits
	w0, w1, w2					  ! weights
INTEGER ::						&
	ip, i1p, i2p				  ! indexes

	kinc = r*(a(i)+amin(k))
	linc1 = w*e1(j1,k)*d(2)
	linc2 = w*e2(j2,k)*d(3)
	trss = v_phi*tr_ss(0,i1,i2,k,m)
	ap = ((1+r)*(a(i)+amin(k))+linc1+linc2-itax(0,kinc,linc1,linc2,trss,m)-ptax(0,linc1,linc2) &
		+trss+(1+ABS(m==0))*(tr_ls+ABS(k<kr)*beq_a)-(1+tau_c)*d(1))/(1+mu)
	IF (beq_no==0.OR.ap<0.0) ap = ap/MAX(phi(k,m),0.1)
	b1p = ABS(k>=kr.OR.m==2.OR.(k>=kr1.AND.linc1<b1(i1)))*b1(i1) &
		+ABS(k<kr.AND.m/=2.AND.(k<kr1.OR.linc1>=b1(i1)))*((k-1)*b1(i1)+MIN(linc1,maxte))/k
	b2p = ABS(k>=kr.OR.m==1.OR.(k>=kr1.AND.linc2<b2(i2)))*b2(i2) &
		+ABS(k<kr.AND.m/=1.AND.(k<kr1.OR.linc2>=b2(i2)))*((k-1)*b2(i2)+MIN(linc2,maxte))/k

	IF (k==kmax) THEN
		Emvp = 0; Emv1p = 0; Emv2p = 0
	ELSE
		DO ip = 1, imax-2; IF (ap-amin(k+1)<a(ip+1)) EXIT; END DO
		w0 = (ap-amin(k+1)-a(ip))/(a(ip+1)-a(ip))
		DO i1p = 1, i1max-2; IF (b1p<b1(i1p+1)) EXIT; END DO
		w1 = (b1p-b1(i1p))/(b1(i1p+1)-b1(i1p))
		DO i2p = 1, i2max-2; IF (b2p<b2(i2p+1)) EXIT; END DO
		w2 = (b2p-b2(i2p))/(b2(i2p+1)-b2(i2p))
		Emvp = (1-w0)*SUM((/1-w1,w1/)*(Emv(ip,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))+ &
			w0*SUM((/1-w1,w1/)*(Emv(ip+1,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))
		Emv1p = (1-w0)*SUM((/1-w1,w1/)*(Emv1(ip,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))+ &
			w0*SUM((/1-w1,w1/)*(Emv1(ip+1,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))
		Emv2p = (1-w0)*SUM((/1-w1,w1/)*(Emv2(ip,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))+ &
			w0*SUM((/1-w1,w1/)*(Emv2(ip+1,i1p:i1p+1,i2p:i2p+1).x.(/1-w2,w2/)))
	END IF

	CALL utility(d(1),1-d(2),1-kappa*nnb(k,m)-d(3),m,u0,u1)

	SELECT CASE (beq_no)
	CASE (0); zero(1) = 1.0/(1+tau_c)-beta0/(1+mu)*Emvp/u1(1)/MAX(phi(k,m),0.1)
	CASE (1); zero(1) = 1.0/(1+tau_c)-beta0/(1+mu)*Emvp/u1(1)
	END SELECT
	zero(2) = u1(2)/u1(1)- &
		(1-itax(2,kinc,linc1,linc2,trss,m)-ptax(1,linc1,linc2))*w*e1(j1,k)/(1+tau_c)- &
		ABS(k<kr.AND.linc1<maxte.AND.(k<kr1.OR.linc1>=b1(i1)))*w*e1(j1,k)/k*beta0*Emv1p/u1(1)
	zero(3) = u1(3)/u1(1)- &
		(1-itax(3,kinc,linc1,linc2,trss,m)-ptax(2,linc1,linc2))*w*e2(j2,k)/(1+tau_c)- &
		ABS(k<kr.AND.linc2<maxte.AND.(k<kr1.OR.linc2>=b2(i2)))*w*e2(j2,k)/k*beta0*Emv2p/u1(1)

	zero(1) = phi_m(phi_p(zero(1),1e-2-d(1)),ap-amin(k+1))
	zero(2) = ABS(m==2.OR.hprd==1)*d(2)+ABS(m/=2.AND.hprd/=1)* &
		phi_m(phi_p(zero(2),1e-2-(1-d(2))),d(2))
	zero(3) = ABS(m==1.OR.hprd==2)*d(3)+ABS(m/=1.AND.hprd/=2)* &
		phi_m(phi_p(zero(3),1e-2-(1-kappa*nnb(k,m)-d(3))),d(3))

END SUBROUTINE cp0
!-----------------------------------------------------------------------------------------
FUNCTION phi_m(a,b)
REAL(4) :: phi_m, a, b

	phi_m = a+b-SQRT(a**2+b**2)

END FUNCTION phi_m
!-----------------------------------------------------------------------------------------
FUNCTION phi_p(a,b)
REAL(4) :: phi_p, a, b

	phi_p = a+b+SQRT(a**2+b**2)

END FUNCTION phi_p
!-----------------------------------------------------------------------------------------
SUBROUTINE utility(c,l1,l2,m,u0,u1)
REAL(4) :: c, l1, l2, u0, u1(3), u01, u02
INTEGER :: m

	c = MAX(c,1e-2); l1 = MAX(l1,1e-2); l2 = MAX(l2,1e-2)
	SELECT CASE (m)
	CASE (0)
		u01 = (c/(1+lambda))**(alpha*(1-gamma))*l1**((1-alpha)*(1-gamma))/(1-gamma)
		u02 = (c/(1+lambda))**(alpha*(1-gamma))*l2**((1-alpha)*(1-gamma))/(1-gamma)
		u0 = u01 + u02
		u1(1) = alpha*(1-gamma)*u0/c
		u1(2) = (1-alpha)*(1-gamma)*u01/l1
		u1(3) = (1-alpha)*(1-gamma)*u02/l2
	CASE (1)
		u0 = c**(alpha*(1-gamma))*l1**((1-alpha)*(1-gamma))/(1-gamma)
		u1(1) = alpha*(1-gamma)*u0/c
		u1(2) = (1-alpha)*(1-gamma)*u0/l1
		u1(3) = 0
	CASE (2)
		u0 = c**(alpha*(1-gamma))*l2**((1-alpha)*(1-gamma))/(1-gamma)
		u1(1) = alpha*(1-gamma)*u0/c
		u1(2) = 0
		u1(3) = (1-alpha)*(1-gamma)*u0/l2
	END SELECT

END SUBROUTINE utility
!-----------------------------------------------------------------------------------------
FUNCTION itax(flag,kinc,linc1,linc2,trss,m)
INTEGER ::						&
	flag,						& ! 0:tax amount
								  ! 1:marginal tax rate (capital income)
								  ! 2:marginal tax rate (husband's labor income)
								  ! 3:marginal tax rate (wife's labor income)
	m							  ! marrital status
REAL(4) ::						&
	itax,						& ! tax amount or marginal tax rate
	kinc,						& ! capital income
	linc1,						& ! husband's labor income
	linc2,						& ! wife's labor income
	trss						  ! social security benefits
REAL(4) ::						&
	y0,							& ! gross adjusted income
	y,							& ! taxable income
	vph0, vph1, vph2			  ! progressive tax parameters

	y0 = kinc+linc1+linc2
	vph0 = tau_i
	SELECT CASE (m)
	CASE (0)
		y = MAX(y0-(6.1+3.9)*2/scale,1e-6)	! 2013
		vph1 = 0.8564; vph2 = 0.010448*scale**vph1
	CASE (1:2)
		y = MAX(y0-(6.1+3.9)/scale,1e-6)	! 2013
		vph1 = 0.6785; vph2 = 0.027675*scale**vph1
	END SELECT
	SELECT CASE (flag)
	CASE (0);	itax = vph0*(y-(y**(-vph1)+vph2)**(-1/vph1))
	CASE (1:3);	itax = vph0*(1-(y**(-vph1)+vph2)**(-1/vph1-1)*y**(-vph1-1))
	END SELECT

END FUNCTION itax
!-----------------------------------------------------------------------------------------
FUNCTION ptax(flag,linc1,linc2)
INTEGER ::						&
	flag						  ! 0:tax amount
								  ! 1:marginal tax rate (husband's labor income)
								  ! 2:marginal tax rate (wife's labor income)
REAL(4) ::						&
	ptax,						& ! tax amount or marginal tax rate
	linc1,						& ! husband's labor income
	linc2						  ! wife's labor income

	SELECT CASE (flag)
	CASE (0);	ptax = tau_p*(MIN(maxte,linc1)+MIN(maxte,linc2))
	CASE (1);	ptax = -tau_p*(linc1<maxte)
	CASE (2);	ptax = -tau_p*(linc2<maxte)
	END SELECT

END FUNCTION ptax
!-----------------------------------------------------------------------------------------
SUBROUTINE set_trss
INTEGER ::						&
	n, i1, i2, k, m

	tr_ss = 0
	DO m = 0, 2
		DO k = kr, kmax
			DO i2 = 1, i2max
				DO i1 = 1, i1max
					DO n = 0, 2
						tr_ss(n,i1,i2,k,m) = oasi(n,i1,i2,k,m)
					END DO
				END DO
			END DO
		END DO
	END DO

END SUBROUTINE set_trss
!-----------------------------------------------------------------------------------------
FUNCTION oasi(flag,i1,i2,k,m)
INTEGER ::						&
	flag,						& ! 0:oasi benefits
								  ! 1:marginal benefits (husband's historical earnings)
								  ! 2:marginal benefits (wife's historical earnings)
	i1, i2, k, m
REAL ::							&
	oasi,						& ! 0:oasi benefits 1&2:marginal benefits
	oasi0(2),					& ! oasi=oasi0(1) or oasi0(2)
	pia1, pia2,					& ! primary insurnace amounts
	mpia1, mpia2 				  ! marginal pia's

	oasi = 0
	IF (k>=kr) THEN
		pia1 = 0.90*MIN(b1(i1),th1)
		IF (b1(i1)>th1) pia1 = pia1+0.32*(MIN(b1(i1),th2)-th1)
		IF (b1(i1)>th2) pia1 = pia1+0.15*(b1(i1)-th2)
		pia2 = 0.90*MIN(b2(i2),th1)
		IF (b2(i2)>th1) pia2 = pia2+0.32*(MIN(b2(i2),th2)-th1)
		IF (b2(i2)>th2) pia2 = pia2+0.15*(b2(i2)-th2)

		mpia1 = 0.90
		IF (b1(i1)>=th1) mpia1 = 0.32
		IF (b1(i1)>=th2) mpia1 = 0.15
		mpia2 = 0.90
		IF (b2(i2)>=th1) mpia2 = 0.32
		IF (b2(i2)>=th2) mpia2 = 0.15

		SELECT CASE (flag)
		CASE (0)	! oasi benefits
			IF (oasi_no==1.OR.(t>1.AND.t<tmax)) THEN
				SELECT CASE (m)
				CASE (0);	oasi0(1) = MAX(1.5*pia1,1.5*pia2,pia1+pia2)
				CASE (1:2);	oasi0(1) = MAX(pia1,pia2)
				END SELECT
			END IF
			IF (oasi_no>=2) THEN
				SELECT CASE (oasi_no)
				CASE (2) ! removing both spousal and survivors benefits
					SELECT CASE (m)
					CASE (0);	oasi0(2) = pia1+pia2
					CASE (1);	oasi0(2) = pia1
					CASE (2);	oasi0(2) = pia2
					END SELECT
				CASE (3) ! removing spousal benefits only
					SELECT CASE (m)
					CASE (0);	oasi0(2) = pia1+pia2
					CASE (1:2);	oasi0(2) = MAX(pia1,pia2)
					END SELECT
				CASE (4) ! removing survivors benefits only
					SELECT CASE (m)
					CASE (0);	oasi0(2) = MAX(1.5*pia1,1.5*pia2,pia1+pia2)
					CASE (1);	oasi0(2) = pia1
					CASE (2);	oasi0(2) = pia2
					END SELECT
				END SELECT
			END IF
		CASE (1)	! marginal benefits of husband's historical earnings
			IF (oasi_no==1.OR.(t>1.AND.t<tmax)) THEN
				SELECT CASE (m)
				CASE (0)
					oasi0(1) = 0
					IF (pia1>=0.5*pia2) oasi0(1) = mpia1
					IF (pia1> 2.0*pia2) oasi0(1) = 1.5*mpia1
				CASE (1:2)
					oasi0(1) = 0
					IF (pia1>=pia2) oasi0(1) = mpia1
				END SELECT
			END IF
			IF (oasi_no>=2) THEN
				SELECT CASE (oasi_no)
				CASE (2) ! removing both spousal and survivors benefits
					SELECT CASE (m)
					CASE (0:1)
						oasi0(2) = mpia1
					CASE (2)
						oasi0(2) = 0
					END SELECT
				CASE (3) ! removing spousal benefits only
					SELECT CASE (m)
					CASE (0)
						oasi0(2) = mpia1
					CASE (1:2)
						oasi0(2) = 0
						IF (pia1>=pia2) oasi0(2) = mpia1
					END SELECT
				CASE (4) ! removing survivors benefits only
					SELECT CASE (m)
					CASE (0)
						oasi0(2) = 0
						IF (pia1>=0.5*pia2) oasi0(2) = mpia1
						IF (pia1> 2.0*pia2) oasi0(2) = 1.5*mpia1
					CASE (1)
						oasi0(2) = mpia1
					CASE (2)
						oasi0(2) = 0
					END SELECT
				END SELECT
			END IF
		CASE (2)	! marginal pia of wife's earnings
			IF (oasi_no==1.OR.(t>1.AND.t<tmax)) THEN
				SELECT CASE (m)
				CASE (0)
					oasi0(1) = 0
					IF (pia2>=0.5*pia1) oasi0(1) = mpia2
					IF (pia2> 2.0*pia1) oasi0(1) = 1.5*mpia2
				CASE (1:2)
					oasi0(1) = 0
					IF (pia2>=pia1) oasi0(1) = mpia2
				END SELECT
			END IF
			IF (oasi_no>=2) THEN
				SELECT CASE (oasi_no)
				CASE (2) ! removing both spousal and survivors benefits
					SELECT CASE (m)
					CASE (0); oasi0(2) = mpia2
					CASE (1); oasi0(2) = 0
					CASE (2); oasi0(2) = mpia2
					END SELECT
				CASE (3) ! removing spousal benefits only
					SELECT CASE (m)
					CASE (0)
						oasi0(2) = mpia2
					CASE (1:2)
						oasi0(2) = 0
						IF (pia2>=pia1) oasi0(2) = mpia2
					END SELECT
				CASE (4) ! removing survivors benefits only
					SELECT CASE (m)
					CASE (0)
						oasi0(2) = 0
						IF (pia2>=0.5*pia1) oasi0(2) = mpia2
						IF (pia2> 2.0*pia1) oasi0(2) = 1.5*mpia2
					CASE (1)
						oasi0(2) = 0
					CASE (2)
						oasi0(2) = mpia2
					END SELECT
				END SELECT
			END IF
		END SELECT

		IF (oasi_no==1) THEN
			oasi = oasi0(1)
		ELSE IF (oasi_no>=2) THEN
			IF (t==tmax) THEN
				oasi = oasi0(2)
			ELSE	! 40-year phased-in by age cohort
				IF (k-(t-2)>=41) THEN
					oasi = oasi0(1)*var_itr(5,1)/var_itr(5,tmax)
				ELSE IF (k-(t-2)<=1) THEN
					oasi = oasi0(2)
				ELSE
					oasi = REAL(k-(t-2)-1)/40*oasi0(1)*var_itr(5,1)/var_itr(5,tmax) &
						+(1-REAL(k-(t-2)-1)/40)*oasi0(2)
				END IF
			END IF
		END IF
		oasi = oasi*(1+mu)**(40-k)	! price indexation instead of wage indexation
	END IF

END FUNCTION oasi
!-----------------------------------------------------------------------------------------
FUNCTION oasiss(i1,i2,k,m)		  ! steady-state oasi benefits
INTEGER ::						&
	i1, i2, k, m
REAL ::							&
	oasiss(3,0:2),				& ! 1:old age 2:spousal 3:survivors benefits
	pia1, pia2					  ! primary insurnace amounts

	oasiss = 0
	IF (k>=kr) THEN
		pia1 = 0.90*MIN(b1(i1),th1)
		IF (b1(i1)>th1) pia1 = pia1+0.32*(MIN(b1(i1),th2)-th1)
		IF (b1(i1)>th2) pia1 = pia1+0.15*(b1(i1)-th2)
		pia2 = 0.90*MIN(b2(i2),th1)
		IF (b2(i2)>th1) pia2 = pia2+0.32*(MIN(b2(i2),th2)-th1)
		IF (b2(i2)>th2) pia2 = pia2+0.15*(b2(i2)-th2)

		SELECT CASE (oasi_no)
		CASE (1)
			SELECT CASE (m)
			CASE (0)
				IF (pia1<0.5*pia2) THEN
					oasiss(:,0) = (/pia2, 0.5*pia2, 0.0/)
					oasiss(:,1) = (/0.0, 1.0, 0.0/)
					oasiss(:,2) = (/1.0, 0.0, 0.0/)
				ELSEIF (pia2<0.5*pia1) THEN
					oasiss(:,0) = (/pia1, 0.5*pia1, 0.0/)
					oasiss(:,1) = (/1.0, 0.0, 0.0/)
					oasiss(:,2) = (/0.0, 1.0, 0.0/)
				ELSE
					oasiss(:,0) = (/pia1+pia2, 0.0, 0.0/)
					oasiss(:,1) = (/1.0, 0.0, 0.0/)
					oasiss(:,2) = (/1.0, 0.0, 0.0/)
				END IF
			CASE (1)
				IF (pia1<pia2) THEN
					oasiss(:,0) = (/0.0, 0.0, pia2/)
					oasiss(:,1) = (/0.0, 0.0, 1.0/)
					oasiss(:,2) = (/0.0, 0.0, 0.0/)
				ELSE IF (pia2<=pia1) THEN
					oasiss(:,0) = (/pia1, 0.0, 0.0/)
					oasiss(:,1) = (/1.0, 0.0, 0.0/)
					oasiss(:,2) = (/0.0, 0.0, 0.0/)
				END IF
			CASE (2)
				IF (pia2<pia1) THEN
					oasiss(:,0) = (/0.0, 0.0, pia1/)
					oasiss(:,1) = (/0.0, 0.0, 0.0/)
					oasiss(:,2) = (/0.0, 0.0, 1.0/)
				ELSE IF (pia1<=pia2) THEN
					oasiss(:,0) = (/pia2, 0.0, 0.0/)
					oasiss(:,1) = (/0.0, 0.0, 0.0/)
					oasiss(:,2) = (/1.0, 0.0, 0.0/)
				END IF
			END SELECT
		END SELECT
		oasiss(:,0) = oasiss(:,0)*(1+mu)**(40-k)	! price indexation
	END IF

END FUNCTION oasiss
!-----------------------------------------------------------------------------------------
SUBROUTINE distribution(flag,x,xp)
INTEGER, INTENT(in) ::			&
	flag						  ! 0:steady state 1:transition path
REAL(8), INTENT(inout), DIMENSION(imax,i1max,i2max,jkmax) :: &
	x							  ! b.o.p. distribution
REAL(8), INTENT(out), DIMENSION(imax,i1max,i2max,jkmax) :: &
	xp							  ! e.o.p. distribution
INTEGER ::						&
	hp, h1p, h2p,				& ! indexes
	ip, i1p, i2p,				&
	j1p, j2p, mp,				&
	jk1, jk2, jkp
REAL(8) ::						&
	pix,						& ! transiiton probability
	v0, v1, v2,					&
	w0, w1, w2,					&
	z0, z1

	xp = 0
	DO j2 = 1, j2max
		DO j1 = 1,j1max
			xp(1,1,1,idx(j1,j2,1,0)) = eta*((1-xi)*p1(j1)*p2(j2)+xi*ABS(j1==j2)*p1(j1))
		END DO
		xp(1,1,1,idx(j2,1,1,1)) = (1-eta)*p1(j2)
		xp(1,1,1,idx(1,j2,1,2)) = (1-eta)*p2(j2)
	END DO

	jk1 = idx(1,1,1,0)
	jk2 = idx(1,1,2,0)-1
	DO k = 1, kmax-1
		IF (flag==0) x(:,:,:,jk1:jk2) = xp(:,:,:,jk1:jk2)
		DO m = 0, 2
		DO j2 = 1, j2max; IF ((k>=kr.OR.m==1).AND.j2>1) EXIT
		DO j1 = 1, j1max; IF ((k>=kr.OR.m==2).AND.j1>1) EXIT
			jk = idx(j1,j2,k,m)
			DO i2 = 1, i2max
			DO i1 = 1, i1max
			DO i  = 1, imax
				DO ip = 1, imax-2; IF (ap(i,i1,i2,jk)-amin(k+1)<a(ip+1)) EXIT; END DO
				w0 = (ap(i,i1,i2,jk)-amin(k+1)-a(ip))/(a(ip+1)-a(ip))
				DO i1p = 1, i1max-2; IF (b1p(i,i1,i2,jk)<b1(i1p+1)) EXIT; END DO
				w1 = (b1p(i,i1,i2,jk)-b1(i1p))/(b1(i1p+1)-b1(i1p))
				DO i2p = 1, i2max-2; IF (b2p(i,i1,i2,jk)<b2(i2p+1)) EXIT; END DO
				w2 = (b2p(i,i1,i2,jk)-b2(i2p))/(b2(i2p+1)-b2(i2p))

				IF (k<kr) THEN
					IF (pr2(i,i1,i2,jk)<1.0) THEN
						DO hp = 1, imax-2; IF (aps(i,i1,i2,jk)-amin(k+1)<a(hp+1)) EXIT; END DO
						v0 = (aps(i,i1,i2,jk)-amin(k+1)-a(hp))/(a(hp+1)-a(hp))
						DO h1p = 1, i1max-2; IF (b1ps(i,i1,i2,jk)<b1(h1p+1)) EXIT; END DO
						v1 = (b1ps(i,i1,i2,jk)-b1(h1p))/(b1(h1p+1)-b1(h1p))
						DO h2p = 1, i2max-2; IF (b2ps(i,i1,i2,jk)<b2(h2p+1)) EXIT; END DO
						v2 = (b2ps(i,i1,i2,jk)-b2(h2p))/(b2(h2p+1)-b2(h2p))
					END IF
				END IF
				DO mp = m, 2; IF (m==1.AND.mp==2) EXIT
				DO j2p = 1, j2max; IF ((k>=kr-1.OR.mp==1).AND.j2p>1) EXIT
				DO j1p = 1, j1max; IF ((k>=kr-1.OR.mp==2).AND.j1p>1) EXIT
					jkp = idx(j1p,j2p,k+1,mp)
					SELECT CASE (mp)
					CASE (0);
						IF (j1==j2) THEN
							pix = (1-xi0)*pi1(j1,j1p,k)*pi2(j2,j2p,k) &
								+xi0*ABS(j1p==j2p)*pi1(j1,j1p,k)
						ELSE
							pix = pi1(j1,j1p,k)*pi2(j2,j2p,k)
						END IF
					CASE (1); pix = pi1(j1,j1p,k)
					CASE (2); pix = pi2(j2,j2p,k)
					END SELECT
					pix = pix*pim(m,mp,k)*x(i,i1,i2,jk)
					IF (k<kr) THEN
						z0 = pr2(i,i1,i2,jk)*pix; z1 = (1-pr2(i,i1,i2,jk))*pix
					ELSE
						z0 = pix; z1 = 0.0
					END IF
					xp(ip,i1p,i2p,jkp) = xp(ip,i1p,i2p,jkp) + (1-w0)*(1-w1)*(1-w2)*z0
					xp(ip,i1p,i2p+1,jkp) = xp(ip,i1p,i2p+1,jkp) + (1-w0)*(1-w1)*w2*z0
					xp(ip,i1p+1,i2p,jkp) = xp(ip,i1p+1,i2p,jkp) + (1-w0)*w1*(1-w2)*z0
					xp(ip,i1p+1,i2p+1,jkp) = xp(ip,i1p+1,i2p+1,jkp) + (1-w0)*w1*w2*z0
					xp(ip+1,i1p,i2p,jkp) = xp(ip+1,i1p,i2p,jkp) + w0*(1-w1)*(1-w2)*z0
					xp(ip+1,i1p,i2p+1,jkp) = xp(ip+1,i1p,i2p+1,jkp) + w0*(1-w1)*w2*z0
					xp(ip+1,i1p+1,i2p,jkp) = xp(ip+1,i1p+1,i2p,jkp) + w0*w1*(1-w2)*z0
					xp(ip+1,i1p+1,i2p+1,jkp) = xp(ip+1,i1p+1,i2p+1,jkp) + w0*w1*w2*z0

					IF (z1/=0.0) THEN
						xp(hp,h1p,h2p,jkp) = xp(hp,h1p,h2p,jkp) + (1-v0)*(1-v1)*(1-v2)*z1
						xp(hp,h1p,h2p+1,jkp) = xp(hp,h1p,h2p+1,jkp) + (1-v0)*(1-v1)*v2*z1
						xp(hp,h1p+1,h2p,jkp) = xp(hp,h1p+1,h2p,jkp) + (1-v0)*v1*(1-v2)*z1
						xp(hp,h1p+1,h2p+1,jkp) = xp(hp,h1p+1,h2p+1,jkp) + (1-v0)*v1*v2*z1
						xp(hp+1,h1p,h2p,jkp) = xp(hp+1,h1p,h2p,jkp) + v0*(1-v1)*(1-v2)*z1
						xp(hp+1,h1p,h2p+1,jkp) = xp(hp+1,h1p,h2p+1,jkp) + v0*(1-v1)*v2*z1
						xp(hp+1,h1p+1,h2p,jkp) = xp(hp+1,h1p+1,h2p,jkp) + v0*v1*(1-v2)*z1
						xp(hp+1,h1p+1,h2p+1,jkp) = xp(hp+1,h1p+1,h2p+1,jkp) + v0*v1*v2*z1
					END IF
				END DO ! j1p
				END DO ! j2p
				END DO ! mp
			END DO ! i
			END DO ! i1
			END DO ! i2
		END DO ! j1
		END DO ! j2
		END DO ! m
		jk1 = idx(1,1,k+1,0)
		jk2 = idx(1,1,k+2,0)-1
		xp(:,:,:,jk1:jk2) = xp(:,:,:,jk1:jk2)/(1+nu)
	END DO ! k

END SUBROUTINE distribution
!-----------------------------------------------------------------------------------------
SUBROUTINE aggregation
INTEGER ::						&
	n1,							& ! counter
	jk1, jk2					  ! indexes
REAL(4) ::						&
	hr_avg,						& ! average working hours
	linc1,						& ! husband's labor income
	linc2,						& ! wife's labor income
	trss,						& ! social security benefits
	work(3,0:2)
REAL(8) ::						&
	w0, w1						  ! weights
REAL, DIMENSION(kr-1) ::		&
	ln_inc_e1,					& ! log labor income
	ln_inc_e2,					& ! log labor income squared
	x_inc						  ! population of households with linc>$1000
REAL ::							&
	pp_neg,						&
	db_avg

	c0     = 0;	h10    = 0;	h20    = 0;	ap0    = 0;	b1p0   = 0;	b2p0   = 0;
	lab10  = 0;	lab20  = 0;	tax_i0 = 0;	tax_p0 = 0; exp_s0 = 0;	wlt_p0 = 0;
	beq0   = 0;	nwk    = 0;	hr1jk  = 0;	hr2jk  = 0; pp_neg = 0; db_avg = 0;
	x_pr2  = 0; var_e1 = 0; var_e2 = 0; cov_12 = 0;

	DO k = 1, kmax
		DO m = 0, 2
		DO j2 = 1, j2max
		IF ((k>=kr.OR.m==1).AND.j2>1) EXIT
		DO j1 = 1, j1max
			IF ((k>=kr.OR.m==2).AND.j1>1) EXIT
			jk = idx(j1,j2,k,m)
			DO i2 = 1, i2max
			DO i1 = 1, i1max
			DO i  = 1, imax
				IF (k<kr) THEN
					w0 = pr2(i,i1,i2,jk)*x(i,i1,i2,jk)
					w1 = (1-pr2(i,i1,i2,jk))*x(i,i1,i2,jk)
				ELSE
					w0 = x(i,i1,i2,jk); w1 = 0.0
				END IF
				c0(k) = c0(k) + c(i,i1,i2,jk)*w0
				h10(k) = h10(k) + h1(i,i1,i2,jk)*w0
				h20(k) = h20(k) + h2(i,i1,i2,jk)*w0
				ap0(k) = ap0(k) + ap(i,i1,i2,jk)*w0
				IF (m/=2) b1p0(k) = b1p0(k) + b1p(i,i1,i2,jk)*w0
				IF (m/=1) b2p0(k) = b2p0(k) + b2p(i,i1,i2,jk)*w0
				linc1 = w*e1(j1,k)*h1(i,i1,i2,jk)
				linc2 = w*e2(j2,k)*h2(i,i1,i2,jk)
				trss = v_phi*tr_ss(0,i1,i2,k,m)
				lab10(k) = lab10(k) + linc1/w*w0
				lab20(k) = lab20(k) + linc2/w*w0
				tax_i0(k) = tax_i0(k) + itax(0,r*(a(i)+amin(k)),linc1,linc2,trss,m)*w0
				tax_p0(k) = tax_p0(k) + ptax(0,linc1,linc2)*w0
				exp_s0(k) = exp_s0(k) + trss*w0
				wlt_p0(k) = wlt_p0(k) + (a(i)+amin(k))*w0
				IF (beq_no==1.AND.ap(i,i1,i2,jk)>0.0) &
					beq0(k) = beq0(k) + (1-phi(k,m))*(1+mu)*ap(i,i1,i2,jk)*w0
				nwk(k,1) = nwk(k,1) + ABS(h1(i,i1,i2,jk)>1e-3)*w0
				nwk(k,2) = nwk(k,2) + ABS(h2(i,i1,i2,jk)>1e-3)*w0
				IF (k<kr) hr1jk(j1,j2,k,m) = hr1jk(j1,j2,k,m) + h1(i,i1,i2,jk)*w0
				IF (k<kr) hr2jk(j1,j2,k,m) = hr2jk(j1,j2,k,m) + h2(i,i1,i2,jk)*w0
				IF (t==1.AND.linc1+linc2>2.0/scale) THEN
					ln_inc_e1(k) = ln_inc_e1(k) + LOG(linc1+linc2)*w0
					ln_inc_e2(k) = ln_inc_e2(k) + LOG(linc1+linc2)**2*w0
					x_inc(k) = x_inc(k) + w0
				END IF
				IF (a(i)+amin(k)<0.0) THEN
					pp_neg = pp_neg + w0
					db_avg = db_avg + (a(i)+amin(k))*w0
				END IF
				IF (m==0.AND.k<kr) THEN
					x_pr2(k) = x_pr2(k) + w0
					var_e1(k) = var_e1(k) + (e1(j1,k)-e1bar(k))**2*w0
					var_e2(k) = var_e2(k) + (e2(j2,k)-e2bar(k))**2*w0
					cov_12(k) = cov_12(k) + (e1(j1,k)-e1bar(k))*(e2(j2,k)-e2bar(k))*w0
				END IF
				IF (w1>0.0) THEN
					c0(k) = c0(k) + c_s(i,i1,i2,jk)*w1
					h10(k) = h10(k) + h1s(i,i1,i2,jk)*w1
					h20(k) = h20(k) + h2s(i,i1,i2,jk)*w1
					ap0(k) = ap0(k) + aps(i,i1,i2,jk)*w1
					IF (m/=2) b1p0(k) = b1p0(k) + b1ps(i,i1,i2,jk)*w1
					IF (m/=1) b2p0(k) = b2p0(k) + b2ps(i,i1,i2,jk)*w1
					linc1 = w*e1(j1,k)*h1s(i,i1,i2,jk)
					linc2 = w*e2(j2,k)*h2s(i,i1,i2,jk)
					lab10(k) = lab10(k) + linc1/w*w1
					lab20(k) = lab20(k) + linc2/w*w1
					tax_i0(k) = tax_i0(k) + itax(0,r*(a(i)+amin(k)),linc1,linc2,trss,m)*w1
					tax_p0(k) = tax_p0(k) + ptax(0,linc1,linc2)*w1
					wlt_p0(k) = wlt_p0(k) + (a(i)+amin(k))*w1
					IF (beq_no==1.AND.aps(i,i1,i2,jk)>0.0) &
						beq0(k) = beq0(k) + (1-phi(k,m))*(1+mu)*aps(i,i1,i2,jk)*w1
					nwk(k,1) = nwk(k,1) + ABS(h1s(i,i1,i2,jk)>1e-3)*w1
					nwk(k,2) = nwk(k,2) + ABS(h2s(i,i1,i2,jk)>1e-3)*w1
					IF (k<kr) hr1jk(j1,j2,k,m) = hr1jk(j1,j2,k,m) + h1s(i,i1,i2,jk)*w1
					IF (k<kr) hr2jk(j1,j2,k,m) = hr2jk(j1,j2,k,m) + h2s(i,i1,i2,jk)*w1
					IF (t==1.AND.linc1+linc2>2.0/scale) THEN
						ln_inc_e1(k) = ln_inc_e1(k) + LOG(linc1+linc2)*w1
						ln_inc_e2(k) = ln_inc_e2(k) + LOG(linc1+linc2)**2*w1
						x_inc(k) = x_inc(k) + w1
					END IF
					IF (a(i)+amin(k)<0.05813) THEN
						pp_neg = pp_neg + w1
						db_avg = db_avg + (a(i)+amin(k))*w1
					END IF
				END IF
			END DO ! i
			END DO ! i1
			END DO ! i2
			IF (k<kr) THEN
				hr1jk(j1,j2,k,m) = hr1jk(j1,j2,k,m)/MAX(SUM(x(:,:,:,jk)),1e-9)
				hr2jk(j1,j2,k,m) = hr2jk(j1,j2,k,m)/MAX(SUM(x(:,:,:,jk)),1e-9)
			END IF
		END DO ! j1
		END DO ! j2
		END DO ! m
	END DO ! k

	var_e1 = var_e1/x_pr2
	var_e2 = var_e2/x_pr2
	cov_12 = cov_12/x_pr2
	corr12 = cov_12/SQRT(var_e1*var_e2)

	tax_c0 = tau_c*c0

	con_p = SUM(c0)
	hrs1  = SUM(h10)
	hrs2  = SUM(h20)
	lab1  = SUM(lab10)
	lab2  = SUM(lab20)
	lab   = lab1+lab2
	tax_i = SUM(tax_i0)
	tax_p = SUM(tax_p0)
	exp_s = SUM(exp_s0)
	tax_c = SUM(tax_c0)
	wlt_p = SUM(wlt_p0)
	beq   = SUM(beq0)

	lpr10 = nwk(:,1)/npp(:,1)
	lpr20 = nwk(:,2)/npp(:,2)
	hrs10 = h10/MAX(1e-3,nwk(:,1))
	hrs20 = h20/MAX(1e-3,nwk(:,2))

	c0  = c0 /npp(:,0)
	h10 = h10/npp(:,1)
	h20 = h20/npp(:,2)
	ap0 = ap0/npp(:,0)
	b1p0 = b1p0/npp(:,1)
	b2p0 = b2p0/npp(:,2)
	lab10 = lab10/npp(:,1)
	lab20 = lab20/npp(:,2)
	tax_i0 = tax_i0/npp(:,0)
	tax_p0 = tax_p0/npp(:,0)
	exp_s0 = exp_s0/npp(:,0)
	tax_c0 = tax_c0/npp(:,0)
	wlt_p0 = wlt_p0/npp(:,0)

	nwk(:,0) = nwk(:,1)+nwk(:,2)
	lpr1 = SUM(nwk(5:34,1))/SUM(npp(5:34,1))		! ages 25-54
	lpr2 = SUM(nwk(5:34,2))/SUM(npp(5:34,2))		! ages 25-54
	lpr1x = SUM(nwk(42:44,1))/SUM(npp(42:44,1))		! ages 62-64
	
	lpr1a = SUM(nwk(1:kr-1,1))/SUM(npp(1:kr-1,1))
	lpr2a = SUM(nwk(1:kr-1,2))/SUM(npp(1:kr-1,2))
	hrs1a = hrs1/SUM(nwk(1:kr-1,1))
	hrs2a = hrs2/SUM(nwk(1:kr-1,2))
	lab0a = lab/SUM(nwk(1:kr-1,0))
	hr_avg = (hrs1+hrs2)/SUM(nwk(1:kr-1,0))

	IF (t==1) THEN
		exp_s1 = 0; exp_s2 = 0
		DO k = kr, kmax
			DO m = 0, 2
				jk = idx(1,1,k,m)
				DO i2 = 1, i2max
					DO i1 = 1, i1max
						work = oasiss(i1,i2,k,m)
						exp_s1 = exp_s1 + v_phi*work(:,0)*SUM(x(:,i1,i2,jk))
						exp_s2(:,1) = exp_s2(:,1) + work(:,1)*SUM(x(:,i1,i2,jk))
						exp_s2(:,2) = exp_s2(:,2) + work(:,2)*SUM(x(:,i1,i2,jk))
					END DO
				END DO
			END DO
		END DO
	END IF

	DO n1 = 1, 10
		cap = wlt_p+wlt_g
		gdp = tfp*cap**theta*lab**(1-theta)
		IF (t==1) wlt_g = wgratio0*gdp
	END DO
	klratio = cap/lab
	kyratio = cap/gdp
	r = tfp*theta*klratio**(theta-1)-delta
	w = tfp*(1-theta)*klratio**theta
	n_inc = r*cap+w*lab

	a_val = 0
	DO j2 = 1, j2max
		DO j1 = 1, j1max
			a_val = a_val + vnb(j1,j2,0,t)*x(1,1,1,idx(j1,j2,1,0))
		END DO
		a_val = a_val + vnb(j2,1,1,t)*x(1,1,1,idx(j2,1,1,1))
		a_val = a_val + vnb(1,j2,2,t)*x(1,1,1,idx(1,j2,1,2))
	END DO
	a_val = a_val/npp(1,0)
	
	IF (t==1) THEN
		kappa = kappa + 10.0*(hrs2a/hrs1a-hrs21tgt)
		IF (kappa0>0.0) THEN
			kappa1 = kappa1 + 5.0*(lpr1-lpr1tgt); kappa1 = MAX(kappa1,0.0)
			kappa2 = kappa2 +50.0*(lpr2-lpr2tgt-lpr1+lpr1tgt); kappa2 = MAX(kappa2,0.0)
		END IF
		alpha = alpha + 1.0*((1-alpha*(1-gamma))/gamma*(1-hr_avg)/hr_avg-frisch0)
		tau_i = 1.0*tau_i*0.10/(tax_i/gdp) + 0.0*tau_i
		scale = 0.8*65.453/(lab/(hh0-hh1)) + 0.2*scale	! 2013 SCF
		maxte = 113.7/scale; th1 = 0.791*12/scale; th2 = 4.768*12/scale	! 2013
		
		b1 = b1*maxte/b1(i1max); b2 = b1
		PRINT *, hrs2a/hrs1a, hrs2a/hrs1a-hrs21tgt, kappa
		PRINT *, lpr1, lpr1-lpr1tgt, kappa1
		PRINT *, lpr2, lpr2-lpr2tgt, kappa2
		PRINT *, alpha, hr_avg, (1-alpha*(1-gamma))/gamma*(1-hr_avg)/hr_avg
		PRINT *, tax_i/gdp, tax_i/gdp-0.10, tau_i
		PRINT *, scale, lab0a
		IF (amin(2)<0.0) PRINT *, pp_neg, pp_neg/hh0, db_avg/pp_neg
		ln_inc_v = ln_inc_e2/x_inc-(ln_inc_e1/x_inc)**2
	END IF
	beq_a = 1.0*beq/(pp0-pp1)+0.0*beq_a
	wlt_gp = wlt_g

	SELECT CASE (br1)
	CASE (0)
		v_phi = 1.0; exp_so = tax_p-exp_s
	CASE (4)
		tau_p = (exp_s+exp_so)/tax_p*tau_p; tax_p = exp_s+exp_so
	CASE (5)
		v_phi = (tax_p-exp_so)/exp_s*v_phi; exp_s = tax_p-exp_so
	END SELECT

	SELECT CASE (br)
	CASE (1)
		con_g = (1+r-(1+mu)*(1+nu))*wlt_g+tax_i+tax_c-tr_ls*pp0
	CASE (2)
		tr_ls = ((1+r-(1+mu)*(1+nu))*wlt_g+tax_i+tax_c-con_g)/pp0
	CASE (3)
		tau_i = (con_g+tr_ls*pp0-tax_c-(1+r-(1+mu)*(1+nu))*wlt_g)/tax_i*tau_i
		tax_i = con_g+tr_ls*pp0-tax_c-(1+r-(1+mu)*(1+nu))*wlt_g
	END SELECT

	IF (t==1.OR.t==tmax) THEN
		dscrp = con_p+con_g+exp_so+((1+mu)*(1+nu)-(1-delta))*cap-gdp
	ELSE
		dscrp = con_p+con_g+exp_so+(1+mu)*(1+nu)*var_tbl(1,t+1)-(1-delta)*cap-gdp
	END IF

	var_tbl(1:25,t) = (/ &
		cap,   lab,   gdp,   n_inc, lab1,  lab2,  hrs1,  hrs2,  con_p, a_val, &
		tax_i, tax_p, exp_s, tax_c, r,     w,     wlt_p, beq,   lpr1,  lpr2,  &
		lpr1a, lpr2a, hrs1a, hrs2a, dscrp /)

END SUBROUTINE aggregation
!-----------------------------------------------------------------------------------------
SUBROUTINE copy_ss(flag,t)
INTEGER, INTENT(in) ::			&
	flag,						& ! 0:write 1:read
	t							  ! 1:initial tmax:final ss

	SELECT CASE (t)
	CASE (1)
		SELECT CASE (flag)
		CASE (0)
			diss(:,:,:,:,1) = c (:,:,:,:)
			diss(:,:,:,:,2) = h1(:,:,:,:)
			diss(:,:,:,:,3) = h2(:,:,:,:)
		CASE (1)
			c (:,:,:,:) = diss(:,:,:,:,1)
			h1(:,:,:,:) = diss(:,:,:,:,2)
			h2(:,:,:,:) = diss(:,:,:,:,3)
		END SELECT
	CASE (tmax)
		SELECT CASE (flag)
		CASE (0)
			dfss(:,:,:,:,1) = c (:,:,:,:)
			dfss(:,:,:,:,2) = h1(:,:,:,:)
			dfss(:,:,:,:,3) = h2(:,:,:,:)
		CASE (1)
			c (:,:,:,:) = dfss(:,:,:,:,1)
			h1(:,:,:,:) = dfss(:,:,:,:,2)
			h2(:,:,:,:) = dfss(:,:,:,:,3)
		END SELECT
	END SELECT

END SUBROUTINE copy_ss
!-----------------------------------------------------------------------------------------
SUBROUTINE copy_ss2(flag,t)
INTEGER, INTENT(in) ::			&
	flag,						& ! 0:write 1:read
	t							  ! 1:initial tmax:final ss

	SELECT CASE (t)
	CASE (1)
		SELECT CASE (flag)
		CASE (0)
			diss2(:,:,:,:,1) = c_s(:,:,:,:)
			diss2(:,:,:,:,2) = h1s(:,:,:,:)
			diss2(:,:,:,:,3) = h2s(:,:,:,:)
		CASE (1)
			c_s(:,:,:,:) = diss2(:,:,:,:,1)
			h1s(:,:,:,:) = diss2(:,:,:,:,2)
			h2s(:,:,:,:) = diss2(:,:,:,:,3)
		END SELECT
	CASE (tmax)
		SELECT CASE (flag)
		CASE (0)
			dfss2(:,:,:,:,1) = c_s(:,:,:,:)
			dfss2(:,:,:,:,2) = h1s(:,:,:,:)
			dfss2(:,:,:,:,3) = h2s(:,:,:,:)
		CASE (1)
			c_s(:,:,:,:) = dfss2(:,:,:,:,1)
			h1s(:,:,:,:) = dfss2(:,:,:,:,2)
			h2s(:,:,:,:) = dfss2(:,:,:,:,3)
		END SELECT
	END SELECT

END SUBROUTINE copy_ss2
!-----------------------------------------------------------------------------------------
SUBROUTINE output1

	WRITE (*,'(A/)') "Parameter Settings"
	WRITE (*,'(A,I10)')   "imax      ", imax
	WRITE (*,'(A,I10)')   "i1max     ", i1max
	WRITE (*,'(A,I10)')   "i2max     ", i2max
	WRITE (*,'(A,I10)')   "j1max     ", j1max
	WRITE (*,'(A,I10)')   "j2max     ", j2max
	WRITE (*,'(A,I10)')   "kmax      ", kmax
	WRITE (*,'(A,I10)')   "kr        ", kr
	WRITE (*,'(A,I10)')   "tmax      ", tmax
	WRITE (*,'(A,F10.6)') "xi        ", xi
	WRITE (*,'(A,I10)')   "beq_no    ", beq_no

	WRITE (*,'(A,F10.6)') "alpha     ", alpha
	WRITE (*,'(A,F10.6)') "beta      ", beta
	WRITE (*,'(A,F10.6)') "beta0     ", beta0
	WRITE (*,'(A,F10.6)') "gamma     ", gamma
	WRITE (*,'(A,F10.6)') "delta     ", delta
	WRITE (*,'(A,F10.6)') "eta       ", eta
	WRITE (*,'(A,F10.6)') "kappa0    ", kappa0
	WRITE (*,'(A,F10.6)') "kappa1    ", kappa1
	WRITE (*,'(A,F10.6)') "kappa2    ", kappa2
	WRITE (*,'(A,F10.6)') "kappa     ", kappa
	WRITE (*,'(A,F10.6)') "lambda    ", lambda
	WRITE (*,'(A,F10.6)') "mu        ", mu
	WRITE (*,'(A,F10.6)') "nu        ", nu
	WRITE (*,'(A,F10.6)') "rho       ", rho
	WRITE (*,'(A,F10.6)') "sigma1    ", sigma1
	WRITE (*,'(A,F10.6)') "sigma2    ", sigma2
	WRITE (*,'(A,F10.6)') "theta     ", theta

	WRITE (*,'(A,F10.6)') "con_g     ", con_g
	WRITE (*,'(A,F10.6)') "tr_ls     ", tr_ls
	WRITE (*,'(A,F10.6)') "tau_i     ", tau_i
	WRITE (*,'(A,F10.6)') "tau_p     ", tau_p
	WRITE (*,'(A,F10.6)') "v_phi     ", v_phi
	WRITE (*,'(A,F10.6)') "exp_so    ", exp_so
	WRITE (*,'(A,F10.6)') "wlt_g     ", wlt_g
	WRITE (*,'(A,F10.8)') "beq_a     ", beq_a

	WRITE (*,'(A,F10.6)') "kyratio0  ", kyratio0
	WRITE (*,'(A,F10.6)') "maxte     ", maxte
	WRITE (*,'(A,F10.6)') "scale     ", scale
	WRITE (*,'(A,F10.6)') "tfp       ", tfp

	WRITE (*,'(A,F10.6)') "hh0       ", hh0
	WRITE (*,'(A,F10.6)') "hh1       ", hh1
	WRITE (*,'(A,F10.6)') "pp0       ", pp0
	WRITE (*,'(A,F10.6)') "pp1       ", pp1

	WRITE (*,'(A,I10)')   "bas_no    ", bas_no
	WRITE (*,'(A,I10)')   "br        ", br
	WRITE (*,'(A,I10)')   "br1       ", br1

	WRITE (*,'(A,F10.6)') "lab0a     ", lab0a

	WRITE (*,'(/A/)') "OASI Benefits by Type"
	WRITE (*,'(A,3F10.6)') "exp_s1    ", exp_s1
	WRITE (*,'(A,3F10.6)') "exp_s2_1  ", exp_s2(:,1)
	WRITE (*,'(A,3F10.6)') "exp_s2_2  ", exp_s2(:,2)

	SELECT CASE (run)
	CASE (:0); OPEN (UNIT=11,FILE=TRIM(dir)//"/output.txt")
	CASE (1:); OPEN (UNIT=11,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))//"/output.txt")
	END SELECT

	WRITE (11,'(A/)') "Parameter Settings"
	WRITE (11,'(A,I10)')   "imax      ", imax
	WRITE (11,'(A,I10)')   "i1max     ", i1max
	WRITE (11,'(A,I10)')   "i2max     ", i2max
	WRITE (11,'(A,I10)')   "j1max     ", j1max
	WRITE (11,'(A,I10)')   "j2max     ", j2max
	WRITE (11,'(A,I10)')   "kmax      ", kmax
	WRITE (11,'(A,I10)')   "kr        ", kr
	WRITE (11,'(A,I10)')   "tmax      ", tmax
	WRITE (11,'(A,F10.6)') "xi        ", xi
	WRITE (11,'(A,I10)')   "beq_no    ", beq_no

	WRITE (11,'(A,F10.6)') "alpha     ", alpha
	WRITE (11,'(A,F10.6)') "beta      ", beta
	WRITE (11,'(A,F10.6)') "beta0     ", beta0
	WRITE (11,'(A,F10.6)') "gamma     ", gamma
	WRITE (11,'(A,F10.6)') "delta     ", delta
	WRITE (11,'(A,F10.6)') "eta       ", eta
	WRITE (11,'(A,F10.6)') "kappa0    ", kappa0
	WRITE (11,'(A,F10.6)') "kappa1    ", kappa1
	WRITE (11,'(A,F10.6)') "kappa2    ", kappa2
	WRITE (11,'(A,F10.6)') "kappa     ", kappa
	WRITE (11,'(A,F10.6)') "lambda    ", lambda
	WRITE (11,'(A,F10.6)') "mu        ", mu
	WRITE (11,'(A,F10.6)') "nu        ", nu
	WRITE (11,'(A,F10.6)') "rho       ", rho
	WRITE (11,'(A,F10.6)') "sigma1    ", sigma1
	WRITE (11,'(A,F10.6)') "sigma2    ", sigma2
	WRITE (11,'(A,F10.6)') "theta     ", theta

	WRITE (11,'(A,F10.6)') "con_g     ", con_g
	WRITE (11,'(A,F10.6)') "tr_ls     ", tr_ls
	WRITE (11,'(A,F10.6)') "tau_i     ", tau_i
	WRITE (11,'(A,F10.6)') "tau_p     ", tau_p
	WRITE (11,'(A,F10.6)') "v_phi     ", v_phi
	WRITE (11,'(A,F10.6)') "exp_so    ", exp_so
	WRITE (11,'(A,F10.6)') "wlt_g     ", wlt_g
	WRITE (11,'(A,F10.8)') "beq_a     ", beq_a

	WRITE (11,'(A,F10.6)') "kyratio0  ", kyratio0
	WRITE (11,'(A,F10.6)') "maxte     ", maxte
	WRITE (11,'(A,F10.6)') "scale     ", scale
	WRITE (11,'(A,F10.6)') "tfp       ", tfp

	WRITE (11,'(A,F10.6)') "hh0       ", hh0
	WRITE (11,'(A,F10.6)') "hh1       ", hh1
	WRITE (11,'(A,F10.6)') "pp0       ", pp0
	WRITE (11,'(A,F10.6)') "pp1       ", pp1

	WRITE (11,'(A,I10)')   "bas_no    ", bas_no
	WRITE (11,'(A,I10)')   "br        ", br
	WRITE (11,'(A,I10)')   "br1       ", br1

	WRITE (11,'(A,F10.6)') "lab0a     ", lab0a

	WRITE (11,'(/A/)') "OASI Benefits by Type"
	WRITE (11,'(A,3F10.6)') "exp_s1    ", exp_s1
	WRITE (11,'(A,3F10.6)') "exp_s2_1  ", exp_s2(:,1)
	WRITE (11,'(A,3F10.6)') "exp_s2_2  ", exp_s2(:,2)

	WRITE (11,'(/A/)') "Age Wage Profile: Husband"
	WRITE(11,'(3A)') "         k","     e1bar","   e1(j,k)"
	DO k = 1, kr-1
		WRITE(11,'(I10,10F10.4)') k, e1bar(k), e1(:,k)
	END DO
	WRITE (11,'(/A/)') "Age Wage Profile: Wife"
	WRITE(11,'(3A)') "         k","     e2bar","   e2(j,k)"
	DO k = 1, kr-1
		WRITE(11,'(I10,10F10.4)') k, e2bar(k), e2(:,k)
	END DO
	
	WRITE (11,'(/A/)') "Distribution: Husband"
	WRITE (11,'(10F10.4)') p1
	WRITE (11,'(/A/)') "Transition Matrix: Husband"
	DO j1 = 1, j1max
		WRITE (11,'(10F10.4)') pi1(j1,:,1)
	END DO
	WRITE (11,'(/A/)') "Distribution: Wife"
	WRITE (11,'(10F10.4)') p2
	WRITE (11,'(/A/)') "Transition Matrix: Wife"
	DO j2 = 1, j2max
		WRITE (11,'(10F10.4)') pi2(j2,:,1)
	END DO

	IF (run==-1) THEN
		WRITE (11,'(/A/)') "Variance of Log Earnings"
		WRITE (11,'(3(2X,A))') "       k","ln_inc_v"," amin(k)"
		DO k = 1, kr-1
			WRITE(11,'(I10,2F10.6)') k, ln_inc_v(k), amin(k)
		END DO

		WRITE (11,'(/A/)') "Private Wealth Distribution"
		WRITE (11,'(4(2X,A))') "       i","    a(i)","    x(i)","a(i)x(i)"
		DO i = 1, imax
			WRITE(11,'(I10,F10.4,2F10.6)') i, a(i), SUM(x(i,:,:,:)), a(i)*SUM(x(i,:,:,:))
		END DO

		WRITE (11,'(/A/)') "Intrafamily Wage Correlation"
		WRITE (11,'(6(4X,A))') "     k"," x_pr2","var_e1","var_e2","cov_12","corr12"
		DO k = 1, kr-1
			WRITE(11,'(I10,5F10.6)') k, x_pr2(k), var_e1(k), var_e2(k), cov_12(k), corr12(k)
		END DO

	END IF

END SUBROUTINE output1
!-----------------------------------------------------------------------------------------
SUBROUTINE output2a
REAL :: var_itr0(9)

	var_itr0 = var_itr(:,t)
	var_itr0(2) = var_itr(2,t)*1000
	var_itr0(9) = var_itr(9,t)*1000

	WRITE(*,'(/6(3X,A)/6F10.4)') &
		"    cap","    lab","    gdp","  n_inc","   lab1","   lab2",var_tbl( 1: 6,t)
	WRITE(*,'( 6(3X,A)/6F10.4)') &
		"   hrs1","   hrs2","  con_p","  a_val","  tax_i","  tax_p",var_tbl( 7:12,t)
	WRITE(*,'( 6(3X,A)/6F10.4)') &
		"  exp_s","  tax_c","      r","      w","  wlt_p","    beq",var_tbl(13:18,t)
	WRITE(*,'( 6(3X,A)/6F10.4)') &
		"   lpr1","   lpr2","  lpr1a","  lpr2a","  hrs1a","  hrs2a",var_tbl(19:24,t)
	WRITE(*,'( 1(3X,A)/1F10.4)') &
		"  dscrp",var_tbl(25,t)
	WRITE(*,'( 6(3X,A)/6F10.4)') &
		"  con_g","tr_ls+3","  tau_i","  tau_p","  v_phi","  tau_c",var_itr0(1:6)
	WRITE(*,'( 3(3X,A)/3F10.4)') &
		"  wlt_g","klratio","beq_a+3",var_itr0(7:9)

	SELECT CASE (run)
	CASE (:0); OPEN (UNIT=11,FILE=TRIM(dir)//"/output.txt",POSITION="APPEND")
	CASE (1:); OPEN (UNIT=11,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
		"/output.txt",POSITION="APPEND")
	END SELECT
	SELECT CASE (t)
	CASE (1);    WRITE(11,'(/A,I4)') "Initial Steady State t =", t
	CASE (tmax); WRITE(11,'(/A,I4)') "Final Steady State t =", t
	END SELECT
	WRITE(11,'(/6(3X,A)/6F10.4)') &
		"    cap","    lab","    gdp","  n_inc","   lab1","   lab2",var_tbl( 1: 6,t)
	WRITE(11,'( 6(3X,A)/6F10.4)') &
		"   hrs1","   hrs2","  con_p","  a_val","  tax_i","  tax_p",var_tbl( 7:12,t)
	WRITE(11,'( 6(3X,A)/6F10.4)') &
		"  exp_s","  tax_c","      r","      w","  wlt_p","    beq",var_tbl(13:18,t)
	WRITE(11,'( 6(3X,A)/6F10.4)') &
		"   lpr1","   lpr2","  lpr1a","  lpr2a","  hrs1a","  hrs2a",var_tbl(19:24,t)
	WRITE(11,'( 1(3X,A)/1F10.4)') &
		"  dscrp",var_tbl(25,t)
	WRITE(11,'( 6(3X,A)/6F10.4)') &
		"  con_g","tr_ls+3","  tau_i","  tau_p","  v_phi","  tau_c",var_itr0(1:6)
	WRITE(11,'( 3(3X,A)/3F10.4)') &
		"  wlt_g","klratio","beq_a+3",var_itr0(7:9)
	CLOSE(UNIT=11)

END SUBROUTINE output2a
!-----------------------------------------------------------------------------------------
SUBROUTINE output2b
INTEGER :: n

	SELECT CASE (run)
	CASE (:0); OPEN (UNIT=11,FILE=TRIM(dir)//"/output.txt",POSITION="APPEND")
	CASE (1:); OPEN (UNIT=11,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
		"/output.txt",POSITION="APPEND")
	END SELECT

100 FORMAT(10X,100F10.4)
101 FORMAT(101F10.4)

	i1 = i1max/2+1; i2 = i2max/2+1; k = kmax/2; j1 = j1max/2+1; j2 = j2max/2+1
	
	WRITE(11,'(/A,5(I2,A))') "c(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), c(:,i1,i2,idx(n,j2,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "c(:,",i1,",",i2,",:,", 1,",",k,",",1,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), c(:,i1,i2,idx(n,1,k,1))
	END DO
	WRITE(11,'(/A,5(I2,A))') "c(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), c(:,i1,i2,idx(j1,n,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "c(:,",i1,",",i2,",", 1,",:,",k,",",2,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), c(:,i1,i2,idx(1,n,k,2))
	END DO

	WRITE(11,'(/A,5(I2,A))') "h1(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), h1(:,i1,i2,idx(n,j2,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "h1(:,",i1,",",i2,",:,", 1,",",k,",",1,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), h1(:,i1,i2,idx(n,1,k,1))
	END DO
	WRITE(11,'(/A,5(I2,A))') "h1(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), h1(:,i1,i2,idx(j1,n,k,0))
	END DO

	WRITE(11,'(/A,5(I2,A))') "h2(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), h2(:,i1,i2,idx(j1,n,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "h2(:,",i1,",",i2,",", 1,",:,",k,",",2,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), h2(:,i1,i2,idx(1,n,k,2))
	END DO
	WRITE(11,'(/A,5(I2,A))') "h2(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), h2(:,i1,i2,idx(n,j2,k,0))
	END DO

	WRITE(11,'(/A,5(I2,A))') "ap(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), ap(:,i1,i2,idx(n,j2,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "ap(:,",i1,",",i2,",:,", 1,",",k,",",1,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), ap(:,i1,i2,idx(n,1,k,1))
	END DO
	WRITE(11,'(/A,5(I2,A))') "ap(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), ap(:,i1,i2,idx(j1,n,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "ap(:,",i1,",",i2,",", 1,",:,",k,",",2,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), ap(:,i1,i2,idx(1,n,k,2))
	END DO

	WRITE(11,'(/A,5(I2,A))') "v(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), v(:,i1,i2,idx(n,j2,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "v(:,",i1,",",i2,",:,", 1,",",k,",",1,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), v(:,i1,i2,idx(n,1,k,1))
	END DO
	WRITE(11,'(/A,5(I2,A))') "v(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), v(:,i1,i2,idx(j1,n,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "v(:,",i1,",",i2,",", 1,",:,",k,",",2,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), v(:,i1,i2,idx(1,n,k,2))
	END DO

	WRITE(11,'(/A,5(I2,A))') "mv(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), mv(:,i1,i2,idx(n,j2,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "mv(:,",i1,",",i2,",:,", 1,",",k,",",1,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), mv(:,i1,i2,idx(n,1,k,1))
	END DO
	WRITE(11,'(/A,5(I2,A))') "mv(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), mv(:,i1,i2,idx(j1,n,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "mv(:,",i1,",",i2,",", 1,",:,",k,",",2,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), mv(:,i1,i2,idx(1,n,k,2))
	END DO

	WRITE(11,'(/A,5(I2,A))') "mv1(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), mv1(:,i1,i2,idx(n,j2,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "mv1(:,",i1,",",i2,",:,", 1,",",k,",",1,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), mv1(:,i1,i2,idx(n,1,k,1))
	END DO
	WRITE(11,'(/A,5(I2,A))') "mv1(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), mv1(:,i1,i2,idx(j1,n,k,0))
	END DO

	WRITE(11,'(/A,5(I2,A))') "mv2(:,",i1,",",i2,",",j1,",:,",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), mv2(:,i1,i2,idx(j1,n,k,0))
	END DO
	WRITE(11,'(/A,5(I2,A))') "mv2(:,",i1,",",i2,",", 1,",:,",k,",",2,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j2max
		WRITE(11,101) e2(n,k), mv2(:,i1,i2,idx(1,n,k,2))
	END DO
	WRITE(11,'(/A,5(I2,A))') "mv2(:,",i1,",",i2,",:,",j2,",",k,",",0,")"
	WRITE(11,100) a+amin(k)
	DO n = 1, j1max
		WRITE(11,101) e1(n,k), mv2(:,i1,i2,idx(n,j2,k,0))
	END DO

	k = kr; j1 = 1; j2 = 1

	WRITE(11,'(/A,5(I2,A))') "x(:,:,",i2,",",j1,",",j2,",",k,",",0,")*1000"
	WRITE(11,100) a+amin(k)
	jk = idx(j1,j2,k,0)
	DO n = 1, i1max
		WRITE(11,101) b1(n), x(:,n,i2,jk)*1000
	END DO
	WRITE(11,'(/A,5(I2,A))') "x(:,:,",i2,",",j1,",", 1,",",k,",",1,")*1000"
	WRITE(11,100) a+amin(k)
	jk = idx(j1,1,k,1)
	DO n = 1, i1max
		WRITE(11,101) b1(n), x(:,n,i2,jk)*1000
	END DO
	WRITE(11,'(/A,5(I2,A))') "x(:,",i1,",:,",j1,",",j2,",",k,",",0,")*1000"
	WRITE(11,100) a+amin(k)
	jk = idx(j1,j2,k,0)
	DO n = 1, i2max
		WRITE(11,101) b2(n), x(:,i1,n,jk)*1000
	END DO
	WRITE(11,'(/A,5(I2,A))') "x(:,",i1,",:,", 1,",",j2,",",k,",",2,")*1000"
	WRITE(11,100) a+amin(k)
	jk = idx(1,j2,k,2)
	DO n = 1, i2max
		WRITE(11,101) b2(n), x(:,i1,n,jk)*1000
	END DO

	WRITE(11,'(/19(5X,A))') "    k","    c","   h1","   h2"," lab1"," lab2", &
			"   ap","  b1p","  b2p","tax_i","tax_p","exp_s","tax_c","wlt_p","   pp", &
			"lpr10","lpr20","hrs10","hrs20"
	DO k = 1, kmax
		WRITE(11,'(I10,18F10.4)') k,c0(k),h10(k),h20(k),lab10(k),lab20(k),ap0(k), &
			b1p0(k),b2p0(k),tax_i0(k),tax_p0(k),exp_s0(k),tax_c0(k),wlt_p0(k),npp(k,0), &
			lpr10(k),lpr20(k),hrs10(k),hrs20(k)
	END DO
	CLOSE(UNIT=11)

END SUBROUTINE output2b
!-----------------------------------------------------------------------------------------
SUBROUTINE output3

	WRITE(*,'(/A,3ES12.4)')"error/total  = ", REAL(nn2)/nn1, REAL(nn1), REAL(nn2)
	WRITE(*,'( A,ES12.4)') "cpu time     = ", CPSEC()
	WRITE(*,'( A,ES12.4)') "elapsed time = ", SECNDS(time0)

	SELECT CASE (run)
	CASE (:0); OPEN (UNIT=11,FILE=TRIM(dir)//"/output.txt",POSITION="APPEND")
	CASE (1:); OPEN (UNIT=11,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
		"/output.txt",POSITION="APPEND")
	END SELECT
	WRITE(11,'(/A,3ES12.4)')"error/total  = ", REAL(nn2)/nn1, REAL(nn1), REAL(nn2)
	WRITE(11,'( A,ES12.4)') "cpu time     = ", CPSEC()
	WRITE(11,'( A,ES12.4)') "elapsed time = ", SECNDS(time0)
	CLOSE(UNIT=11)

	time0 = CPSEC(); time0 = SECNDS(0.0); nn1 = 0; nn2 = 0

END SUBROUTINE output3
!-----------------------------------------------------------------------------------------
SUBROUTINE rw_iteration(flag)
INTEGER, INTENT(in) ::			&
	flag						  ! 0:write 1:read
INTEGER ::						&
	io_status, t, t0

	SELECT CASE (flag)
	CASE (0)
		SELECT CASE (run)
		CASE (:0); OPEN (UNIT=12,FILE=TRIM(dir)//"/var_itr.txt",STATUS="REPLACE")
		CASE (1:); OPEN (UNIT=12,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
			"/var_itr.txt",STATUS="REPLACE")
!		CASE (:0); OPEN (UNIT=12,FILE=TRIM(dir)//"/var_itr.txt",POSITION="APPEND")
!		CASE (1:); OPEN (UNIT=12,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
!			"/var_itr.txt",POSITION="APPEND")
		END SELECT
		WRITE(12,'(4X,A,7(7X,A),5X,A,7X,A)') &
			"t","con_g","tr_ls","tau_i","tau_p","v_phi","tau_c","wlt_g","klratio","beq_a"
		DO t = 1, tmax; WRITE(12,'(I6,9F12.6)') t, var_itr(1:9,t); END DO
	CASE (1:2)
		SELECT CASE (run)
		CASE (:0); OPEN (UNIT=12,FILE=TRIM(dir)//"/var_itr.txt",STATUS="OLD")
		CASE (1:); OPEN (UNIT=12,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
			"/var_itr.txt",STATUS="OLD")
		END SELECT
		READ(12,'(A)')
		SELECT CASE (flag)
		CASE (1)
			DO t = 1, tmax; READ(12,'(I6,9F12.6)') t0, var_itr(1:9,t); END DO
		CASE (2)
			READ(12,'(A)')
			DO t = 2, tmax; READ(12,'(I6,9F12.6)') t0, var_itr(1:9,t); END DO
		END SELECT
	END SELECT
	CLOSE(UNIT=12)

	SELECT CASE (flag)
	CASE (0)
		SELECT CASE (run)
		CASE (:0); OPEN (UNIT=13,FILE=TRIM(dir)//"/var_tbl.txt",STATUS="REPLACE")
		CASE (1:); OPEN (UNIT=13,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
			"/var_tbl.txt",STATUS="REPLACE")
		END SELECT
		WRITE(13,'(4X,A,24(7X,A),5X,A)') "t", &
			"  cap","  lab","  gdp","n_inc"," lab1"," lab2"," hrs1"," hrs2","con_p","a_val", &
			"tax_i","tax_p","exp_s","tax_c","    r","    w","wlt_p","  beq"," lpr1"," lpr2", &
			"lpt1a","lpt2a","hrs1a","hrs2a","lab0a"
		DO t = 1, tmax; WRITE(13,'(I6,25F12.6)') t, var_tbl(1:25,t); END DO
	CASE (1)
	END SELECT
	CLOSE(UNIT=13)

	SELECT CASE (flag)
	CASE (0)
		SELECT CASE (run)
		CASE (:0); OPEN (UNIT=16,FILE=TRIM(dir)//"/vnb.txt",STATUS="REPLACE")
		CASE (1:); OPEN (UNIT=16,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
				   "/vnb.txt",STATUS="REPLACE")
		END SELECT
		WRITE(16,'(4X,A,7X,A)') "t", "value"
		DO t = 1, tmax
			WRITE(16,'(I6,35F12.6)') t, &
				vnb(1,:,0,t),vnb(2,:,0,t),vnb(3,:,0,t),vnb(4,:,0,t),vnb(5,:,0,t), &
				vnb(:,1,1,t),vnb(1,:,2,t)
		END DO
	CASE (1)
	END SELECT
	CLOSE(UNIT=16)

END SUBROUTINE rw_iteration
!-----------------------------------------------------------------------------------------
SUBROUTINE rw_decision(flag)	! use rw_decision3 instead if the memory is sufficient
INTEGER, INTENT(in) ::			&
	flag						  ! 0:write 1:read
INTEGER ::						&
	io_status

100 FORMAT(100ES12.5)
	
	SELECT CASE (flag)
	CASE (0);   OPEN (UNIT=14,FILE=TRIM(dir1)//"/d"//TRIM(int2char(t,3))//".txt", &
				STATUS="REPLACE")
	CASE (1:2); OPEN (UNIT=14,FILE=TRIM(dir1)//"/d"//TRIM(int2char(t,3))//".txt", &
				STATUS="OLD",IOSTAT=io_status)
	END SELECT

	IF (flag==0.OR.io_status==0) THEN
		DO jk = 1, jkmax
			SELECT CASE (flag)
			CASE (0)
				WRITE(14,'(A,1(I4,A))') "c(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(14,100) c(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (14,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (14,100) c(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax
			SELECT CASE (flag)
			CASE (0)
				WRITE(14,'(A,1(I4,A))') "h1(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(14,100) h1(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (14,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (14,100) h1(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax
			SELECT CASE (flag)
			CASE (0)
				WRITE(14,'(A,1(I4,A))') "h2(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(14,100) h2(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (14,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (14,100) h2(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax
			SELECT CASE (flag)
			CASE (0)
				WRITE(14,'(A,1(I4,A))') "ap(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(14,100) ap(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (14,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (14,100) ap(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax
			SELECT CASE (flag)
			CASE (0)
				WRITE(14,'(A,1(I4,A))') "b1p(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(14,100) b1p(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (14,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (14,100) b1p(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax
			SELECT CASE (flag)
			CASE (0)
				WRITE(14,'(A,1(I4,A))') "b2p(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(14,100) b2p(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (14,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (14,100) b2p(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO
	END IF
	CLOSE(UNIT=14)

END SUBROUTINE rw_decision
!-----------------------------------------------------------------------------------------
SUBROUTINE rw_decision2(flag)	! use rw_decision3 instead if the memory is sufficient
INTEGER, INTENT(in) ::			&
	flag						  ! 0:write 1:read
INTEGER ::						&
	io_status

100 FORMAT(100ES12.5)
	
	SELECT CASE (flag)
	CASE (0);   OPEN (UNIT=19,FILE=TRIM(dir1)//"/ds"//TRIM(int2char(t,3))//".txt", &
				STATUS="REPLACE")
	CASE (1:2); OPEN (UNIT=19,FILE=TRIM(dir1)//"/ds"//TRIM(int2char(t,3))//".txt", &
				STATUS="OLD",IOSTAT=io_status)
	END SELECT

	IF (flag==0.OR.io_status==0) THEN
		DO jk = 1, jkmax0
			SELECT CASE (flag)
			CASE (0)
				WRITE(19,'(A,1(I4,A))') "c_s(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(19,100) c_s(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (19,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (19,100) c_s(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax0
			SELECT CASE (flag)
			CASE (0)
				WRITE(19,'(A,1(I4,A))') "h1s(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(19,100) h1s(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (19,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (19,100) h1s(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax0
			SELECT CASE (flag)
			CASE (0)
				WRITE(19,'(A,1(I4,A))') "h2s(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(19,100) h2s(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (19,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (19,100) h2s(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax0
			SELECT CASE (flag)
			CASE (0)
				WRITE(19,'(A,1(I4,A))') "aps(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(19,100) aps(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (19,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (19,100) aps(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax0
			SELECT CASE (flag)
			CASE (0)
				WRITE(19,'(A,1(I4,A))') "b1ps(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(19,100) b1ps(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (19,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (19,100) b1ps(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax0
			SELECT CASE (flag)
			CASE (0)
				WRITE(19,'(A,1(I4,A))') "b2ps(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(19,100) b2ps(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (19,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (19,100) b2ps(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO

		DO jk = 1, jkmax0
			SELECT CASE (flag)
			CASE (0)
				WRITE(19,'(A,1(I4,A))') "pr2(:,:,:,",jk,")"
				DO i2 = 1, i2max; DO i1 = 1, i1max
					WRITE(19,100) pr2(:,i1,i2,jk)
				END DO; END DO
			CASE (1)
				READ (19,'(A)')
				DO i2 = 1, i2max; DO i1 = 1, i1max
					READ (19,100) pr2(:,i1,i2,jk)
				END DO; END DO
			END SELECT
		END DO
	END IF
	CLOSE(UNIT=19)

END SUBROUTINE rw_decision2
!-----------------------------------------------------------------------------------------
SUBROUTINE rw_decision3(flag)
INTEGER, INTENT(in) ::			&
	flag						  ! 0:write 1:read

	SELECT CASE (flag)
	CASE (0) ! Saving results to temp variable
		temp_iter(:,:,:,:,t,1) = c(:,:,:,:)		! consumption
		temp_iter(:,:,:,:,t,2) = h1(:,:,:,:)	! working hours (husband, single male)
		temp_iter(:,:,:,:,t,3) = h2(:,:,:,:)	! working hours (wife, single female)
		temp_iter(:,:,:,:,t,4) = ap(:,:,:,:)	! t+1 wealth
		temp_iter(:,:,:,:,t,5) = b1p(:,:,:,:)	! t+1 avg hist earnings (husband)
		temp_iter(:,:,:,:,t,6) = b2p(:,:,:,:)	! t+1 avg hist earnings (wife)
	CASE (1)! Reading results from temp varialbe
		c(:,:,:,:)   = temp_iter(:,:,:,:,t,1)	! consumption
		h1(:,:,:,:)  = temp_iter(:,:,:,:,t,2)	! working hours (husband, single male)
		h2(:,:,:,:)  = temp_iter(:,:,:,:,t,3)	! working hours (wife, single female)
		ap(:,:,:,:)  = temp_iter(:,:,:,:,t,4)	! t+1 wealth
		b1p(:,:,:,:) = temp_iter(:,:,:,:,t,5)	! t+1 avg hist earnings (husband)
		b2p(:,:,:,:) = temp_iter(:,:,:,:,t,6)	! t+1 avg hist earnings (wife)
	END SELECT

!	IF (kappa0>0.0) THEN 						! h1s=0 or h2s=0 or both
!		SELECT CASE (flag)
!		CASE (0) ! Saving results to temp variable
!			temp_iter_s(:,:,:,:,t,1) = c_s(:,:,:,:)
!			temp_iter_s(:,:,:,:,t,2) = h1s(:,:,:,:)
!			temp_iter_s(:,:,:,:,t,3) = h2s(:,:,:,:)
!			temp_iter_s(:,:,:,:,t,4) = aps(:,:,:,:)
!			temp_iter_s(:,:,:,:,t,5) = b1ps(:,:,:,:)
!			temp_iter_s(:,:,:,:,t,6) = b2ps(:,:,:,:)
!			temp_iter_s(:,:,:,:,t,7) = pr2(:,:,:,:)
!		CASE (1)! Reading results from temp varialbe
!			c_s(:,:,:,:)  = temp_iter_s(:,:,:,:,t,1)
!			h1s(:,:,:,:)  = temp_iter_s(:,:,:,:,t,2)
!			h2s(:,:,:,:)  = temp_iter_s(:,:,:,:,t,3)
!			aps(:,:,:,:)  = temp_iter_s(:,:,:,:,t,4)
!			b1ps(:,:,:,:) = temp_iter_s(:,:,:,:,t,5)
!			b2ps(:,:,:,:) = temp_iter_s(:,:,:,:,t,6)
!			pr2(:,:,:,:)  = temp_iter_s(:,:,:,:,t,7)
!		END SELECT
!	END IF

END SUBROUTINE rw_decision3
!-----------------------------------------------------------------------------------------
SUBROUTINE write_vnb(t)
INTEGER, INTENT(in) ::			&
	t

	SELECT CASE (run)
	CASE (-1); OPEN (UNIT=16,FILE=TRIM(dir)//"/vnb.txt",STATUS="REPLACE")
	CASE ( 0); OPEN (UNIT=16,FILE=TRIM(dir)//"/vnb.txt",POSITION="APPEND")
	CASE (1:); OPEN (UNIT=16,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
		"/vnb.txt",STATUS="REPLACE")
	END SELECT
!	WRITE(16,'(4X,A,7X,A)') "t", "value"
	WRITE(16,'(I6,35F12.6)') t, &
		vnb(1,:,0,t),vnb(2,:,0,t),vnb(3,:,0,t),vnb(4,:,0,t),vnb(5,:,0,t), &
		vnb(:,1,1,t),vnb(1,:,2,t)
	CLOSE(UNIT=16)

END SUBROUTINE write_vnb
!-----------------------------------------------------------------------------------------
SUBROUTINE write_vcr(t)
INTEGER,INTENT(in) ::			&
	t

	SELECT CASE (run)
	CASE (:0); OPEN (UNIT=17,FILE=TRIM(dir)//"/vcr"//TRIM(int2char(t,3))//".txt", &
		STATUS="REPLACE")
	CASE (1:); OPEN (UNIT=17,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
		"/vcr"//TRIM(int2char(t,3))//".txt",STATUS="REPLACE")
	END SELECT
	WRITE(17,'(4X,A,7X,A)') "k", "value"
	DO k = kmax, 1, -1; WRITE(17,'(I6,F12.6)') k, vcr0(k); END DO
	CLOSE(UNIT=17)

END SUBROUTINE write_vcr
!-----------------------------------------------------------------------------------------
SUBROUTINE write_hours(t)
INTEGER,INTENT(in) ::			&
	t
	SELECT CASE (run)
	CASE (:0); OPEN (UNIT=18,FILE=TRIM(dir)//"/hours"//TRIM(int2char(t,3))//".txt", &
		POSITION="APPEND")
	CASE (1:); OPEN (UNIT=18,FILE=TRIM(dir)//"/run"//TRIM(int2char(run,1))// &
		"/hours"//TRIM(int2char(t,3))//".txt",STATUS="REPLACE")
	END SELECT
	WRITE(18,'(4X,A,6X,A)') "k", "hours1"
	DO k = 1, kr-1
		WRITE(18,'(I6,30F12.6)') k, &
			hr1jk(1,:,k,0), hr1jk(2,:,k,0), hr1jk(3,:,k,0), hr1jk(4,:,k,0), hr1jk(5,:,k,0), &
			hr1jk(:,1,k,1)
	END DO
	WRITE(18,'(4X,A,6X,A)') "k", "hours2"
	DO k = 1, kr-1
		WRITE(18,'(I6,30F12.6)') k, &
			hr2jk(1,:,k,0), hr2jk(2,:,k,0), hr2jk(3,:,k,0), hr2jk(4,:,k,0), hr2jk(5,:,k,0), &
			hr2jk(1,:,k,2)
	END DO
	CLOSE(UNIT=18)

END SUBROUTINE write_hours
!-----------------------------------------------------------------------------------------
FUNCTION int2char(n,w)
CHARACTER(10) ::				&
	int2char
INTEGER ::						&
	n,							& ! natural number
	w,							& ! number of digits (minimum if w=0)
	i, j,						&
	n0,							&
	nbuf(10)

	int2char = ""; n0 = n; nbuf = 0;
	DO i = 1, 10
		nbuf(i) = MOD(n0,10)
		n0 = (n0-nbuf(i))/10
		IF (n0==0) EXIT
	END DO
	DO j = MIN(10,MAX(w,i)), 1, -1
		int2char = TRIM(int2char)//CHAR(48+nbuf(j))
	END DO

END FUNCTION int2char
!=========================================================================================
SUBROUTINE rouwenhorst_markov(jmax,kmax,rho,sigma,pi,z,p)
INTEGER, INTENT(in) ::			&
	jmax,						& ! number of nodes
	kmax						  ! 1:infinite-horizon model 2-100:life-cycle model
REAL(4), INTENT(in) ::			&
	rho,						& ! autocorrelation of ln(z)
	sigma						  ! standard deviation of epsilon
REAL(4), INTENT(out) ::			&
	pi(jmax,jmax),				& ! markov transition matrix
	z(jmax,kmax),				& ! nodes of z
	p(jmax)						  ! distribution of z
REAL(4), DIMENSION(jmax,jmax) :: &
	pi1, pi2, pi3, pi4
INTEGER ::						&
	i, j, k
REAL(4) ::						&
	m,							& ! ln(z(jmax)) = mu_lnz+m*sigma_lnz
	d,							&
	x(jmax),					&
	y,							&
	mu_lnz,						& ! mean of ln(z)
	sigma_lnz,					& ! standard deviation of ln(z)
	var_lnz,					& ! variance of ln(z)
	b2(jmax,1),					&
	p2(jmax,1),					&
	q(jmax,jmax)

	m = sqrt(REAL(jmax-1))
	d = 2*m/REAL(jmax-1)
	x(jmax) = m
	DO i = jmax-1, 1, -1
		x(i) = x(i+1)-d
	END DO
	y = (1+rho)/2
	pi(1:2,1:2) = RESHAPE((/y, 1-y, 1-y, y/),(/2, 2/))
	pi1 = 0; pi2 = 0; pi3 = 0; pi4 = 0
	DO i = 3, jmax
		pi1(1:i-1,1:i-1) = pi(1:i-1,1:i-1)
		pi2(1:i-1,2:i)   = pi(1:i-1,1:i-1)
		pi3(2:i,  1:i-1) = pi(1:i-1,1:i-1)
		pi4(2:i,  2:i  ) = pi(1:i-1,1:i-1)
		pi(1:i,1:i) = y*(pi1(1:i,1:i)+pi4(1:i,1:i))+(1-y)*(pi2(1:i,1:i)+pi3(1:i,1:i))
		pi(2:i-1,:) = pi(2:i-1,:)/2
	END DO

	var_lnz = 0.50*sigma**2/(1-rho**2)
	DO k = 1, kmax
		var_lnz = rho**2*var_lnz+sigma**2
		mu_lnz = -var_lnz/2
		sigma_lnz = SQRT(var_lnz)
		z(:,k) = mu_lnz+x*sigma_lnz
	END DO
	z = exp(z)

	q = EYE(jmax)-.t.pi; q(jmax,:)=1
	b2 = 0; b2(jmax,1) = 1
	p2 = q.ix.b2; p = p2(:,1)

END SUBROUTINE rouwenhorst_markov
!=========================================================================================
END PROGRAM Nishiyama_SSMC_RED_2018