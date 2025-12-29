PROGRAM Health_GE_5period_endosur_MD_benchmark


!*****************************************
!				To do list
!*****************************************

! transition prob 5 years
! gov = 0.0
! intial z1


!**********************************************************************************************************
!  gfortran tw_progtax_bmlabor.f90 -ffree-line-length-none -fopenmp -O3 -o tw_progtax_bmlabor

! 2020 benchmark
! 	./tw_progtax_bmlabor  0.9120      0.5300      0.5500      9.5000      9.5000      3.3000      3.3000      0.0000      0.0022      0.8500     27.0000

! 2030 forecasted income distributions
! 	./tw_progtax_bmlabor  0.9120      0.5300      0.5500      9.5000      9.5000      3.3000      3.3000      0.0000      0.0022      0.8500     34.0000

! 2050 forecasted income distributions
! 	./tw_progtax_bmlabor  0.9120      0.5300      0.5500      9.5000      9.5000      3.3000      3.3000      0.0000      0.0022      0.8500     47.0000

!**********************************************************************************************************

! #ifdef _OPENMP 
!   include 'omp_lib.h'  !needed for OMP_GET_NUM_THREADS()
! #endif
USE omp_lib

INTEGER, PARAMETER :: prec=SELECTED_REAL_KIND(15, 307)
INTEGER, PARAMETER :: couple_labor = 0 ! 2= Male and Female endog labor ; 1= male endog labr; 0=exog labor
INTEGER, PARAMETER :: r_update = 1 ! 1=bisection ; 2=delta_r (bm use delta_r)
INTEGER, PARAMETER :: year = 2020 ! year of survival probability [2020,2030,2050]

!------------------------------welfare decomposition------------------------------
! INTEGER, PARAMETER :: ty_max_restriction = 0 ! without ty_max=0 ; with ty_max=1 (Guner et al 2014: Sample restriction eliminates those with reported taxes higher than the top statutory marginal tax rate, 39.5%.)
! INTEGER, PARAMETER :: optimal_tax_activation = 0 ! (defaut at 0, dont change)	benchmark=0 ; optimal=1  
! INTEGER, PARAMETER :: GBC_method_activation = 1  ! (defaut at 1, dont change)	adjust lambda=0 (optimal case) ; adjust PIA factor/gov exp as residual=1 (benchmark case) 
! INTEGER, PARAMETER :: MFS_method = 1 !	shut down MFS=0 ; allow MFS =1
! INTEGER, PARAMETER :: source_welfare_analysis_activation = 1 ! activate:1 ; shut down:0 (if activate, then set optimal_tax_activation = 0 and result_display = 0; set incomethreshold mannually!!!)
! INTEGER, PARAMETER :: result_display = 0 ! display results of optimal tax case: 1 ; No display: 0
! INTEGER, PARAMETER :: gov_method = 0 	 ! ratio of GDP =0 ; level value = 1
!--------------------------------Optimal tau------------------------------------
! INTEGER, PARAMETER :: ty_max_restriction = 0 ! without ty_max=0 ; with ty_max=1 (Guner et al 2014: Sample restriction eliminates those with reported taxes higher than the top statutory marginal tax rate, 39.5%.)
! INTEGER, PARAMETER :: optimal_tax_activation = 1 ! 	benchmark=0 ; optimal=1
! INTEGER, PARAMETER :: GBC_method_activation = 4 ! 	0=the GB is cleared by lambda ; 1=the GB is cleared by Gov; 2=the GB is cleared by tau_s
! INTEGER, PARAMETER :: MFS_method = 0 !	shut down MFS=0 ; allow MFS =1; shut down MFJ=2
! INTEGER, PARAMETER :: source_welfare_analysis_activation = 0 ! activate:1 ; shut down:0 (if activate, then set optimal_tax_activation = 0)
! INTEGER, PARAMETER :: result_display = 1 ! display results of optimal tax case: 1 ; No display: 0
! INTEGER, PARAMETER :: gov_method = 0 	 ! ratio of GDP =0 ; level value = 1
!-----------------------------Benchmark----------------------------------
INTEGER, PARAMETER :: ty_max_restriction = 0 ! without ty_max=0 ; with ty_max=1 (Guner et al 2014: Sample restriction eliminates those with reported taxes higher than the top statutory marginal tax rate, 39.5%.)
INTEGER, PARAMETER :: optimal_tax_activation = 0 ! 	benchmark=0 ; optimal=1
INTEGER, PARAMETER :: GBC_method_activation = 4  ! 	0=the GB is cleared by lambda ; 1=the GB is cleared by Gov; 2=the GB is cleared by tau_s;  4=the GB is cleared by premium_rate; 5= pension replacement rate 
INTEGER, PARAMETER :: MFS_method = 0 !	shut down MFS=0 ; allow MFS =1; shut down MFJ=2
INTEGER, PARAMETER :: source_welfare_analysis_activation = 0 ! activate:1 ; shut down:0 (if activate, then set optimal_tax_activation = 0)
INTEGER, PARAMETER :: result_display = 1 ! display results of optimal tax case: 1 ; No display: 0
INTEGER, PARAMETER :: gov_method = 0 	 ! ratio of GDP =0 ; level value = 1
INTEGER, PARAMETER :: CV = 0				 ! 0 = save benchmark value function for compensated variation	; 1=dont save the benchmark value function but use CV subroutine
INTEGER, PARAMETER :: save_bm_decisions = 0  ! 0 = not save; 1 = save
!-----------------------------No couple optimal----------------------------------
! set both gov exp and SSEXP as benchmark with couple 
! set marryprop = 0.0
! INTEGER, PARAMETER :: ty_max_restriction = 1 ! without ty_max=0 ; with ty_max=1 (Guner et al 2014: Sample restriction eliminates those with reported taxes higher than the top statutory marginal tax rate, 39.5%.)
! INTEGER, PARAMETER :: optimal_tax_activation = 1 ! 	benchmark=0 ; optimal=1
! INTEGER, PARAMETER :: GBC_method_activation = 0 ! 	adjust lambda=0 (optimal case) ; adjust PIA factor/gov exp as residual=1 (benchmark case)
! INTEGER, PARAMETER :: MFS_method = 1 !	shut down MFS=0 ; allow MFS =1
! INTEGER, PARAMETER :: source_welfare_analysis_activation = 0 ! activate:1 ; shut down:0 (if activate, then set optimal_tax_activation = 0)
! INTEGER, PARAMETER :: result_display = 0 ! display results of optimal tax case: 1 ; No display: 0
! INTEGER, PARAMETER :: gov_method = 1 	 ! ratio of GDP =0 ; level value = 1

!***************************
!
!   Initial Guess Values
!
!***************************

PARAMETER (BEQ0 =  0.04)	!  1.398701097315307E-002  ) 	    !  Accidental bequests
PARAMETER (SS0 =   0.266587382884863    )        !  Social Security benifits 
PARAMETER (STAX0 =  0.156058077828311  )      !  Social Security tax rate
PARAMETER (MTAX0 =  9.477625607851901E-002  )       !  Med tax rate
PARAMETER (PREMIUM0 =  3.466539718500166E-002  )     !  EHI premium

!*****************************************
!
!   SSA pension income (SSA_modelinputs.xlsx)
!
!*****************************************
! 2000 SSA pension income (SSA_modelinputs.xlsx: SS Source 1)
! Numbers are monthly basis (average indexed monthly earnings)
PARAMETER (ssmin_2000 = 0.0  )
PARAMETER (bend1_2000 = 531.0  ) 	! 531.0	(2000)	!580.0 (2000-04)
PARAMETER (bend2_2000 = 3202.0 ) 	! 3202.0 (2000)	!3498.0(2000-04)
PARAMETER (sscap_2000 = 3887.0  )	! 3887.0 (2000)	!4645.0 (2000-04)	! the value of sscap and incsscap in Baris' SSA_modelinputs should be switched!!!
PARAMETER (incsscap_2000 = 1435.3  ) ! 1435.3 (2000)	!1628.1 (2000-04)
PARAMETER (avg_monthly_earnings2000 = 2679.57  )	! 2679.57 (2000)	! 2800.7(2000-04)
PARAMETER (EHMAX_2000 = sscap_2000/(avg_monthly_earnings2000)  )	
!PARAMETER (incsscap = incsscap_2000/avg_monthly_earnings2000 )		! incsscap has to be REAL(prec) for function SS(IE)
PARAMETER (ssmin = ssmin_2000/(avg_monthly_earnings2000) )
PARAMETER (bend1 = bend1_2000/(avg_monthly_earnings2000)	)
PARAMETER (bend2 = bend2_2000/(avg_monthly_earnings2000)	)
! PARAMETER (PIA_factor = 0.62)	! PIA adjustment factor to match the target SS/Y

!*****************************************
!
!   Set factor prices
!
!*****************************************

!PARAMETER (WAGE = 1.000)			         ! Wage rate (Hui He 2016:$12.03 PSID)
!PARAMETER (R_ANNUAL = 0.040)                 ! Annual interest rate
!PARAMETER (R = (1.040)**5.00-1.000)          ! Interest rate
!PARAMETER (Avg_R_PE = 0.0489)               ! Average return implied from the return process in Partial Equilibrium


!******************
!
!   Set Parameters
!
!******************

PARAMETER (TOLB = 0.01)       !0.005              !  Convergence tolerance for bequests
PARAMETER (TOLSS = 0.005)                    	  !  Convergence tolerance for SS benefits
!PARAMETER (TOLSTAX = 0.005)                  	  !  Convergence tolerance for SS tax rate
PARAMETER (tol_lam = 0.005)    !0.005			  !  Convergence tolerance for lambda
PARAMETER (tol_tau_s = 0.01)					  !  Convergence tolerance for tau_s
PARAMETER (tol_PIA = 0.01) 						  !  Convergence tolerance for PIA factor
PARAMETER (tol_premium = 0.01)
PARAMETER (tol_REPLACE = 0.01)
PARAMETER (TOLMTAX = 0.005)                  	  !  Convergence tolerance for Med tax rate
PARAMETER (TOLEHI = 0.005)                        !  Convergence tolerance for EHI premium
PARAMETER (TOLK = 0.009)        !0.005       	  !  Convergence tolerance for asset market clear
PARAMETER (GRADB = 0.35)       !0.2               !  Convergence gradient for bequests
PARAMETER (GRADSS = 0.618)                   	  !  Convergence gradient for SS bnefits
PARAMETER (GRADSTAX = 0.618)                 	  !  Convergence gradient for SS tax rate
PARAMETER (GRADMTAX = 0.618)                 	  !  Convergence gradient for Med tax rate
PARAMETER (GRADEHI = 0.7)                  		  !  Convergence gradient for EHI
!PARAMETER (GRADBETA = 0.2)                    
PARAMETER (MAXITER = 50)       !100               !  Maximum number of iterations for convergence
PARAMETER (GRADLAMBDA = 0.5)
PARAMETER (GRADPIA = 0.5)
PARAMETER (GRADTAUS = 0.5)
PARAMETER (GRADPREMIUM = 0.5)
PARAMETER (GRADREPlACE = 0.5)
 
PARAMETER (ALPHA = 0.34)	!0.33                 ! capital share
PARAMETER (TFP   = 1.78) !1.8  		 !  Multiplicative constant in production function, such that wage = 1
PARAMETER (GROWTH_ANNUAL = 0.000)            !  Annual growth rate of per capita output
PARAMETER (GROWTH = (1.000+GROWTH_ANNUAL)**5.00-1.000)     !  Growth rate of per capita output
! calibrate depreciation to match interest rate
PARAMETER (DEP_ANNUAL = 0.0905) !0.07)       ! Annual depreciation rate of capital, 0.069 from He Hui, 0.048 from HKS
PARAMETER (DEP  = 1.000-(1.000-DEP_ANNUAL)**5.00) !  Depreciation rate of capital
PARAMETER (flat_transf_rate = 0.02)	!0.027				 ! 2% is destined to the general public in the form of disability benefits, veterans benefits etc (Markus & Baris 2016) 
REAL(prec), PARAMETER :: medicare_rate = 0.072	!0.033

! 2000 social security rate
PARAMETER (rr1 = 0.9)	 
PARAMETER (rr2 = 0.32)
PARAMETER (rr3 = 0.15)

! 1960 socail security rate
! PARAMETER (rr1 = 0.5636364)	 ! Pension Tables ( estimated by Baris )
! PARAMETER (rr2 = 0.2137931)
!!-------------------------------------------------------------------------------------------------------------------------------!!
!!---------------------------------------------- need to be calibriated ---------------------------------------------------------!!

!REAL, PARAMETER :: BETA_ANNUAL = 0.975 !0.975            !  Annual discount factor
!REAL, PARAMETER :: BETA   = (BETA_ANNUAL)**5.00      !  Subjective discount factor
!REAL(prec) :: BETA   = (BETA_ANNUAL)**5.00      !  Subjective discount factor
REAL, PARAMETER :: sigma  = 1.50000                    !  Risk aversion REAL PARAMETER
REAL, PARAMETER :: UCONS  = 2.300                    !  Constant term in utility function (Hall and Jones 2007)
REAL, PARAMETER :: sigma_lab_male  = 1.0/0.68	!2.5	! male Frisch elasticity = 0.4 (Blundell et al. (2012) ); 0.68(updated in submitted version)
REAL, PARAMETER :: sigma_lab_female  = 1.0/0.96	!1.25	! female Frisch elasticity = 0.8 (Blundell et al. (2012) ); 0.96(updated in submitted version)
! REAL, PARAMETER :: sigma_lab_female  = 1.0/0.68

! REAL, PARAMETER :: theta  = 2.3	!5.5
!REAL, PARAMETER :: eta	= 1.6 	! Nishyama (Bernheim et al. (2008))
REAL, PARAMETER :: eta	= 1.7	! The OECD equivalence scales assign a weight of 1 to the household head, 0.7 to each additional adult household member, and 0.5 to each child.
REAL, PARAMETER :: fixcost_male	= 0.0	
! REAL, PARAMETER :: fixcost_female = 0.126		!0.134 !0.112

REAL, PARAMETER :: RHO    = 0.342                  !  Share of consumption in consumption-leisure composition (Conesa, Kitao and Krueger 2009 = 0.377 
REAL, PARAMETER :: PSI    = -9.70000                   !  Elasticity of substitution b/w consumption-leisure and health, Yogo (2009  = -0.43            
!REAL, PARAMETER :: LAMBDA   = 0.970000                  !  Yogo (2009) = 0.7!  Share of consumption-leisure composition in the utility function

REAL, PARAMETER :: B  = 0.98000                        !  Productivity of health accumulation technology
REAL, PARAMETER :: XI  = 0.800                       !  Return to Scale in health investment

REAL, PARAMETER :: Q  = 0.0!0.0050                      !  Scale factor of sick time
REAL, PARAMETER :: GAMMA1  = 1.40                   !  Elasticity of sick time to health status

REAL, PARAMETER :: a0  = -4.300                       !  Intercept of depreciation rate of health status, benchmark value: -4.00
REAL, PARAMETER :: a1  = 0.31                       !  Coefficent for age, benchmark value: 0.215
REAL, PARAMETER :: a2  = 0.00400                    !  Coefficent for age^2, benchmark 0.00825

REAL, PARAMETER :: c0  = -5.490484!-5.81                       !  Intercept of sur. prob. function, benchmark value: -5.490484
REAL, PARAMETER :: c1  = 0.1499950!0.285                       !  Coefficent for age of sur. prob funtion, benchmark value: 0.1499950
REAL, PARAMETER :: c2  = 0.0161671!0.0082                      !  Coefficent for age^2, benchmark 0.0161671
REAL, PARAMETER :: c3  = -0.17                      !  Coefficent for h in sur. prob. function


!!-------------------------------------------------------------------------------------------------------------------------------!!
!!-------------------------------------------------------------------------------------------------------------------------------!!

! SS/Y target: 8.1% for 2010 (From Markus xlsx "NIPA_SocialBenefits")
! PARAMETER (REPLACE  = 0.095)      		     !0.09      !  Social security replacement rate, Cagetti and De Nardi (2009) =40%

PARAMETER (SUBM = 0.80)                      !  co-insurance rate of Medicare
PARAMETER (SUBEHI = 0.80)                    !  co-insurance rate of EHI

! Set the bounds for lambda
! real(prec), parameter	:: lambdamin = 0.8 !0.9D0 ! Use 0.9 and 1.1 unless tau_l is changing.
real(prec), parameter	:: lambdamin = 0.6
real(prec), parameter	:: lambdamax = 1.3 !1.2D0 ! 1.2
real(prec), parameter	:: delta_lambda = 1.0

! Set the bounds for tau_s
real(prec), parameter	:: tau_s_min = 0.0
real(prec), parameter	:: tau_s_max = 0.3

! Set the bounds for TFP
real(prec), parameter	:: Rmin = 0.045	!0.035 
real(prec), parameter	:: Rmax = 0.1	!0.075 

real(prec), parameter	:: ty_max = 0.45	!0.45		! Progressive Tax Rate System 2018-2021; before that ty_max is 45%
real(prec), parameter   :: tau_c = 0.236 	! Corporate tax: Markus & Kaymak 2016 (piketty paper)
! real(prec), parameter   :: tau_s = 0.05  ! Average sales tax: total sales tax rev/total consumption expenditures 

! REAL(prec), parameter  :: earn_corr	= 0.0	! husband-wife wage correlation 

! Marriage fraction for 1960
! real(prec), parameter 	:: marryprop = 0.87 ! Jeremy Greenwood et al. 2016 (Table 4)
! Marriage fraction for 2005
! real(prec), parameter 	:: marryprop = 0.661	! Jeremy Greenwood et al. 2016 (Table 6)
! Marriage fraction for 2001
 real(prec), parameter 	:: marryprop = 0.676	! share of marriage from 2019-2010 is 51.1% (MOI)

! 	Efficiency States (Markus JME 2016) 
PARAMETER (nn = 5)
real(prec), parameter :: std_w = 0.7500000**0.5 !HH earnings variance 1960: 0.504 1970: 0.585**0.5 2005: 0.75 ! hh earnings: 0.72D0 ! SED Version: 1960=0.458D0 !2010=0.55
real(prec), parameter :: zig1 = -std_w*(0.62)**0.5	! 62% of the variance is due to fixed effects
real(prec), parameter :: zig2 = std_w*(0.62)**0.5	! 62% of the variance is due to fixed effects
real(prec), parameter :: zlc1 = -std_w*(1.0-0.62)**0.5	! 62% of the variance is due to fixed effects
real(prec), parameter :: zlc2 = std_w*(1.0-0.62)**0.5	! 62% of the variance is due to fixed effects
real(prec), parameter :: difmedian =  0.276000912 !0.198D0] !0.152D0] !0.246465262D0] ! 0.152D0] !0.187D0] ! 0.187D0 to keep meanz in 2010 same as in 1960
real(prec), parameter :: sbtc  =  1.0	!1.22310660 !1.178D0] !1.178096376D0 ] !1.178D0] ! 1.213D0] ! 1960 and 2010 (actually th enumber is for 2005). selected to generate a 2010 wage variance of 0.754, from HPV, RED2010, F8
!PARAMETER (SLOW = 0.6712914)		         !  Realization of low individual productivity shock
!PARAMETER (SHIGH = 1.489666)		         !  Realization of high individual productivity shock

REAL(prec), parameter :: weight_MFS = 1.000
REAL(prec), parameter :: d_c = 100000.000
REAL(prec), parameter :: bendy = 10310001/788031 ! 10310001 is the threshold for 45% tax ; 788031 is the avg income
! REAL(prec), parameter :: bendy = 4530001/788031  ! 4530001 is the threshold for 40% tax

PARAMETER (MAXAGE = 15)                      !  Maximum age allowed
INTEGER, PARAMETER :: RETAGE = 9            !  Retirement age  

PARAMETER (POPG = 0.000)

! PARAMETER (AMAX   = 2.700)      !  Maximum permissible asset
! PARAMETER (AMIN   = 0.000)      !  Maximum permissible asset
! REAL(prec) MMAX
! PARAMETER (MMAX   = 1.2000)      !  Maximum permissible med exepnditure

PARAMETER (AMAX   = 8000.000 )   !8000 !  Maximum permissible asset	
PARAMETER (AMIN   = 0.001)      !  Minimum permissible asset
! REAL(prec) MMAX
! PARAMETER (MMAX   = 2.22)      !  Maximum permissible med exepnditure 

!PARAMETER (NGRIDR  = 2)! 4**4*2+1) 
PARAMETER (NGRIDA  = 129)! 4**4*2+1)     !129  Number of points on asset grid (state)
!PARAMETER (NGRIDH  = NGRIDA)! **4*2+1)       !  Number of points on health grid(state)
!PARAMETER (NGRIDA  =  4**4*2+1)     !  Number of points on asset grid (state)
!PARAMETER (NGRIDH  =  4**4*2+1)       !  Number of points on health grid(state)
PARAMETER (NGRIDEH  = 5)		!10		!  Number of points on earning history (state)
	

PARAMETER (CMIN   = 0.000000005)   !  Minimum permissible consumption
REAL(prec) LEIMIN
PARAMETER (LEIMIN   = 0.000000005)   !  Minimum permissible leisure
PARAMETER (HMIN   = 0.0000000005)      !  Minimum permissible health level

!********************
!
!   Data Type Declarations and Dimension Statements
!
!********************

INTEGER AGE, ILA, IUA, ISKIPA, ILN, IUN, ISKIPN ,ILN2, IUN2, ISKIPN2
INTEGER JAMAX, JNMAX, JNMAX2, IA, IE, IS, IS1, IS2, IN, IC, IG, JE, NEWIS, NEWIS1, NEWIS2,itax,isubsidy,NEWIE 
INTEGER CHUNK, NTHR, ID, INDEXV, MAXINDEX, NRET, ZEROINDEX
INTEGER JTS,JTM
INTEGER state_pos,isort,count, individ, LOOPNUMBER
INTEGER source_welfare,optimal_tax,GBC_method
INTEGER index_A,index_A_single,index_A_couple
INTEGER index_E,index_E_single,index_E_couple
INTEGER index_tinc,index_tinc_single,index_tinc_couple
INTEGER ASWITCH1, ASWITCH2

REAL(prec)  AEND, BEQEND, STAXEND, LEND, LSSEND, MEND, MEDW, MEDR, MEDEND, MYOUNG, MOLD, EXDEM, INV, K, K1, L, L1, INCOME, z_shock,z_shock1,z_shock2, INCOME1, INCOME2, TINCOME, taxable_income, IEND, KDEV, LDEV, TWEND
REAL(prec)  BEQ, STAX, MTAX, PREMIUM, BEQ1, SS1, STAX1, MTAX1, PREMIUM1, PREMIUM2, BEQDEV, SSDEV, STAXDEV, MTAXDEV, EHIDEV
REAL(prec)  PRICE, WAGEZ, WAGEZ1, WAGEZ2, UTIL, LEI1, LEI2, CONS, SUR, HEA, SKIPH, TW, VTEMPL, VMAX, HNEXT, HNEXTPOS, OUTPUT, X3
REAL(prec)  RATIO125
REAL(prec)  t0, t1
REAL(prec)	wea_gini, inc_gini, tinc_gini, cons_gini, yd_gini
REAL(prec)	Aggwealth, Aggincome, Aggtincome, Aggconsumption, agg_c, agg_yd, agg_y
REAL(prec) 	kshare05, kshare1, kshare5, kshare10, kshare20, kshare40, kshare60, kshare80
REAL(prec) 	kshare0001, kshare0005, kshare001, kshare005, kshare01, pos_zero_k, share_zero_k
REAL(prec) 	klevel05, klevel1, klevel5, klevel10, klevel20, klevel40, klevel60, klevel80, klevel9095, klevel9599, klevel6080,klevel4060,klevel2040
REAL(prec) 	klevel0001, klevel0005, klevel001, klevel01
REAL(prec) 	incshare05, incshare1, incshare5, incshare10, incshare20, incshare40, incshare60, incshare80
REAL(prec) 	incshare0001, incshare0005, incshare001,incshare005, incshare01
REAL(prec) 	tincshare05, tincshare1, tincshare5, tincshare10, tincshare20, tincshare40, tincshare60, tincshare80
REAL(prec) 	tincshare0001, tincshare0005, tincshare001, tincshare005, tincshare01
REAL(prec)  bshare0_50,bshare50_70,bshare70_80,bshare80_90,bshare90_95,bshare95_99,bshare99_100,beq_gini
REAL(prec) 	cshare05, cshare1, cshare5, cshare10, cshare20, cshare40, cshare60, cshare80
REAL(prec) 	cshare0001, cshare0005, cshare001, cshare01
REAL(prec)  sum_temp,sum_temp1,sum_temp2
REAL(prec)  zawel, zaweh
REAL(prec)  k_pct99,k_pct90,k_pct30,k_mean,k_median,kratio99_50,kratio90_50,kratioMM,kratio50_30
REAL(prec)  inc_pct99,inc_pct90,inc_pct30,inc_mean,inc_median,incratio99_50,incratio90_50,incratioMM,incratio50_30
REAL(prec)  tinc_pct99,tinc_pct90,tinc_pct30,tinc_mean,tinc_median,tincratio99_50,tincratio90_50,tincratioMM,tincratio50_30
REAL(prec)  ALONG95_100,ALONG25_30,ALONG30_35,ALONG35_40,ALONG40_45,ALONG45_50,ALONG50_55,ALONG55_60,ALONG55_25
REAL(prec)	ALONG60_65, ALONG65_70, ALONG70_75, ALONG75_80, ALONG80_85, ALONG85_90, ALONG90_95, ALONG60_89
REAL(prec)	ALONG20_25_couple,ALONG25_30_couple,ALONG30_35_couple,ALONG35_40_couple,ALONG40_45_couple,ALONG45_50_couple,ALONG50_55_couple,ALONG55_60_couple,ALONG60_65_couple,ALONG65_70_couple,ALONG70_75_couple,ALONG75_80_couple,ALONG80_85_couple,ALONG85_90_couple,ALONG90_95_couple,ALONG95_100_couple,ALONG65_MORE_couple
REAL(prec)  ILONG20_25,ILONG25_30,ILONG30_35,ILONG35_40,ILONG40_45,ILONG45_50,ILONG50_55,ILONG55_60,ILONG55_20
REAL(prec)	ILONG60_65, ILONG65_70, ILONG70_75, ILONG75_80, ILONG80_85, ILONG85_90, ILONG90_95
REAL(prec)	ILONG20_25_couple,ILONG25_30_couple,ILONG30_35_couple,ILONG35_40_couple,ILONG40_45_couple,ILONG45_50_couple,ILONG50_55_couple,ILONG55_60_couple,ILONG60_65_couple,ILONG65_MORE_couple
REAL(prec)  TILONG20_25,TILONG25_30,TILONG30_35,TILONG35_40,TILONG40_45,TILONG45_50,TILONG50_55,TILONG55_60,TILONG55_20
REAL(prec)	TILONG60_65, TILONG65_70, TILONG70_75, TILONG75_80, TILONG80_85, TILONG85_90, TILONG90_95
REAL(prec)  TILONG20_25_couple,TILONG25_30_couple,TILONG30_35_couple,TILONG35_40_couple,TILONG40_45_couple,TILONG45_50_couple,TILONG50_55_couple,TILONG55_60_couple,TILONG60_65_couple,TILONG65_MORE_couple
REAL(prec)  YDLONG20_25_couple,YDLONG25_30_couple,YDLONG30_35_couple,YDLONG35_40_couple,YDLONG40_45_couple,YDLONG45_50_couple,YDLONG50_55_couple,YDLONG55_60_couple,YDLONG60_65_couple,YDLONG65_MORE_couple
REAL(prec)  Avg_R,Avg_R_weighted, Avg_top0001_R, Avg_top0005_R, Avg_top001_R, Avg_top01_R, Avg_top05_R, Avg_top1_R, Avg_top5_R, Avg_top10_R, Avg_top20_R, Avg_top40_R,Avg_top60_R,Avg_top80_R
REAL(prec)	Avg_bot40_R, Avg_bot20_R,Avg_99_9999_R, Avg_99_999_R, Avg_95_99_R,Avg_90_95_R
REAL(prec)  SD_R,SD_R_weighted, SD_top0001_R, SD_top0005_R, SD_top001_R,SD_top01_R,SD_top1_R,SD_95_99_R,SD_90_95_R, SD_bot40_R, SD_bot20_R
REAL(prec)	earning_share_avg,kincome_share_avg,trans_share_avg,age_share_avg,earning_share001,kincome_share001,earning_share01,kincome_share01,earning_share05,kincome_share05,earning_share1,kincome_share1,earning_share5,kincome_share5,earning_share10,kincome_share10,trans_share1, age_share1, &
			earning_share995999, kincome_share995999, earning_share9599, kincome_share9599,trans_share9599,age_share9599, earning_share9095,kincome_share9095,trans_share9095,age_share9095,earning_share0510,kincome_share0510,trans_share0510,age_share0510,earning_share0105,kincome_share0105,trans_share0105,age_share0105, &
			earning_share5q,kincome_share5q,trans_share5q,age_share5q, earning_share4q,kincome_share4q,trans_share4q, age_share4q,earning_share3q,kincome_share3q,trans_share3q, age_share3q,earning_share2q,kincome_share2q,trans_share2q, age_share2q,earning_share1q,kincome_share1q,trans_share1q, age_share1q
REAL(prec)	MPK,MPL,beta_update,MAXBETA,MINBETA
REAL(prec)	Inc_top025pct_median_ratio, earn_top025pct_median_ratio, Inc_top0039pct_bot61pct_ratio,earn_top001pct_median_ratio,earn_top01pct_median_ratio,earn_top5pct_median_ratio
REAL(prec)	temp_totalincome
REAL(prec)	synsavingrate_avg, synsavingrate_bot90pct, synsavingrate_10pct, synsavingrate_5pct,synsavingrate_1pct,synsavingrate_10_1pct,synsavingrate_10_5pct,synsavingrate_5_1pct,synsavingrate_1_01pct,syn_totalincome_avg
REAL(prec)  beq_wealth_ratio,AggBeq,AggBeq52,Beq98, beq_pct98,Beq95, beq_pct95, Beq90, beq_pct90,Beq80, beq_pct80,Beq70, beq_pct70,Beq60, beq_pct60,Beq50, beq_pct50,Beq40, beq_pct40,Beq30, beq_pct30,Beq20, beq_pct20,Beq10, beq_pct10 
REAL(prec)  kshare_Y0001, kshare_Y0005, kshare_Y001, kshare_Y01, kshare_Y05, kshare_Y1, kshare_Y5, kshare_Y10, kshare_Y20, kshare_Y40, kshare_Y60, kshare_Y80
REAL(prec)  klevel_Y0001, klevel_Y0005, klevel_Y001, klevel_Y01, klevel_Y05, klevel_Y1, klevel_Y5, klevel_Y10, klevel_Y20, klevel_Y40, klevel_Y60, klevel_Y80, klevel_Y9599,klevel_Y9095, klevel_Y6080,klevel_Y4060,klevel_Y2040
REAL(prec)  kshare_E0001, kshare_E0005, kshare_E001, kshare_E01, kshare_E05, kshare_E1, kshare_E5, kshare_E10, kshare_E20, kshare_E40, kshare_E60, kshare_E80
REAL(prec)  klevel_E0001, klevel_E0005, klevel_E001, klevel_E01, klevel_E05, klevel_E1, klevel_E5, klevel_E10, klevel_E20, klevel_E40, klevel_E60, klevel_E80
REAL(prec)  cshare_tinc0001, cshare_tinc0005, cshare_tinc001, cshare_tinc01, cshare_tinc05, cshare_tinc1, cshare_tinc5, cshare_tinc10, cshare_tinc20, cshare_tinc40, cshare_tinc60, cshare_tinc80
REAL(prec)  lambda_implied,lambda, lambda1, lambda2, lambdaold,lambda_couple, gbcdenom, gbcnum, dlam, singlebendy, couplebendy, yd, MFSbendy
REAL(prec)	tau_s_implied, tau_s1, tau_s2, dtau_s, tau_s, premium_rate, premium_rate_implied, dpremium_rate, REPLACE, REPLACE_implied, dREPLACE
REAL(prec)	cor_tax_rev,sales_tax_rev, ATC1, ATC99, ctaxrev_income, ATY1,ATY10,ATY99,ATY90,inctaxrev_income,ATY,ATY_tax_single,ATY_taxableincome_single,ATY_tax_couple,ATY_taxableincome_couple, G_share, MTR1, MTR10, tax_subsidy, tax_revenue_single, tax_revenue_couple, income_tax_revenue_single, income_tax_revenue_couple,insurance_premium
REAL(prec)  ATY_single,ATY_single_Q1,ATY_single_Q2,ATY_single_Q3,ATY_single_Q4,ATY_single_Q5,ATY_couple,ATY_couple_Q1,ATY_couple_Q2,ATY_couple_Q3,ATY_couple_Q4,ATY_couple_Q5
REAL(prec)  ATY_tax_single_Q5,ATY_tax_single_Q4,ATY_tax_single_Q3,ATY_tax_single_Q2,ATY_tax_single_Q1,ATY_taxableincome_single_Q5,ATY_taxableincome_single_Q4,ATY_taxableincome_single_Q3,ATY_taxableincome_single_Q2,ATY_taxableincome_single_Q1
REAL(prec)  ATY_tax_couple_Q5,ATY_tax_couple_Q4,ATY_tax_couple_Q3,ATY_tax_couple_Q2,ATY_tax_couple_Q1,ATY_taxableincome_couple_Q5,ATY_taxableincome_couple_Q4,ATY_taxableincome_couple_Q3,ATY_taxableincome_couple_Q2,ATY_taxableincome_couple_Q1
REAL(prec)  ATY_tax_single_b10,ATY_tax_single_b9,ATY_tax_single_b8,ATY_tax_single_b7,ATY_tax_single_b6,ATY_tax_single_b5,ATY_tax_single_b4,ATY_tax_single_b3,ATY_tax_single_b2,ATY_tax_single_b1
REAL(prec)  ATY_taxableincome_single_b10,ATY_taxableincome_single_b9,ATY_taxableincome_single_b8,ATY_taxableincome_single_b7,ATY_taxableincome_single_b6,ATY_taxableincome_single_b5,ATY_taxableincome_single_b4,ATY_taxableincome_single_b3,ATY_taxableincome_single_b2,ATY_taxableincome_single_b1 
REAL(prec)  ATY_tax_couple_b10,ATY_tax_couple_b9,ATY_tax_couple_b8,ATY_tax_couple_b7,ATY_tax_couple_b6,ATY_tax_couple_b5,ATY_tax_couple_b4,ATY_tax_couple_b3,ATY_tax_couple_b2,ATY_tax_couple_b1
REAL(prec)  ATY_taxableincome_couple_b10,ATY_taxableincome_couple_b9,ATY_taxableincome_couple_b8,ATY_taxableincome_couple_b7,ATY_taxableincome_couple_b6,ATY_taxableincome_couple_b5,ATY_taxableincome_couple_b4,ATY_taxableincome_couple_b3,ATY_taxableincome_couple_b2,ATY_taxableincome_couple_b1
REAL(prec)  ATY_single_b10,ATY_single_b9,ATY_single_b8,ATY_single_b7,ATY_single_b6,ATY_single_b5,ATY_single_b4,ATY_single_b3,ATY_single_b2,ATY_single_b1
REAL(prec)  ATY_couple_b10,ATY_couple_b9,ATY_couple_b8,ATY_couple_b7,ATY_couple_b6,ATY_couple_b5,ATY_couple_b4,ATY_couple_b3,ATY_couple_b2,ATY_couple_b1
REAL(prec)  single_Y_b10,single_Y_b9,single_Y_b8,single_Y_b7,single_Y_b6,single_Y_b5,single_Y_b4,single_Y_b3,single_Y_b2,single_Y_b1
REAL(prec)  couple_Y_b10,couple_Y_b9,couple_Y_b8,couple_Y_b7,couple_Y_b6,couple_Y_b5,couple_Y_b4,couple_Y_b3,couple_Y_b2,couple_Y_b1
REAL(prec)	temp,temp2,temp_ctaxrev,temp_cons,temp_staxrev
REAL(prec)	incvar, mean_incvar, consvar, mean_consvar, var_cons_earning_ratio, var_cons_earning_ratio_single, var_cons_earning_ratio_couple 
REAL(prec)  KD,delta, BETA
REAL(prec)	WAGE
REAL(prec)  r_implied, r_new, R1, R2, delta_r
REAL(prec)  R,R_ANNUAL
REAL(prec)	avg_earnings,avg_wage,working_population,whole_population,retire_population
REAL(prec)	SSEXP,AggEH
REAL(prec)  EH_temp
REAL(prec)	Agg_labor,Avg_hour,Agg_asset,Agg_beq
! REAL(prec)  incsscap,ssmin,bend1,bend2
REAL(prec)  incsscap
REAL(prec)  ALONG_RETIRE_couple,ILONG_RETIRE_couple,TILONG_RETIRE_couple,YDLONG_RETIRE_couple
REAL(prec)  gov_trans, gov_exp,medicare
REAL(prec)	Aggearning_retire
REAL(prec)  jointfiling_tax, separatefiling_tax
REAL(prec)  taxableincome
REAL(prec)	single_male_welfare, single_female_welfare, married_male_welfare, married_female_welfare, total_couple_welfare, temp_couple_taxpenalty, temp_separatefiling_tax, prop_family_tax, prop_family_subsidy, avg_family_tax, avg_family_subsidy, sd_family_tax, sd_family_subsidy 
REAL(prec)  earn_ratio
REAL(prec)	invar_male_low,invar_male_high,invar_female_low,invar_female_high
REAL(prec)	LFP_male,LFP_female, LFP_married_female, LFP_single_female, hour_male, hour_female, hour_single_male, hour_single_female, hour_married_male, hour_married_female
REAL(prec)  popu_MFS, tax_MFS
REAL(prec)  incomethreshold01,incomethreshold1,incomethreshold5,incomethreshold10,incomethreshold20,incomethreshold30,incomethreshold40,incomethreshold50,incomethreshold60,incomethreshold70,incomethreshold80,incomethreshold90
REAL(prec)	earningthreshold80,earningthreshold60,earningthreshold40,earningthreshold20,earningthreshold10,earningthreshold5,earningthreshold1
REAL(prec)  util_welfare_hh, util_welfare_id, veil_welfare_hh, veil_welfare_id, agglabpath_singlemale,agglabpath_singlefemale,aggcerteq_singlemale,aggcerteq_singlefemale,par_welfare_singlemale,par_welfare_singlefemale,agglabpath_couplemale,agglabpath_couplefemale,aggcerteq_couplemale,aggcerteq_couplefemale,par_welfare_couple,par_welfare
REAL(prec)	CEV_optimal,reform_welfare,change_bench_util_C,change_bench_util_LS,optimal_CEV_newborn,reform_CEV_util,reform_welfare_newborn,reform_CEV_newborn
REAL tau_l_single, tau_l_couple
REAL(prec)	PIA_factor,PIA_factor_implied,dPIA
REAL(prec)  earn_corr_conditional,P_joint
REAL(prec)  consumption,INCOME_next,INCOME1_next,INCOME2_next,z_shock_next,z_shock1_next,z_shock2_next,consumption_next,avg_log_income,avg_log_cons,insurance_nominator,insurance_denominator,insurance_value
REAL(prec)  avg_log_income_shock,avg_log_income_shock_single,avg_log_income_shock_couple,insurance_cons_nominator,insurance_cons_denominator,insurance_cons_value,insurance_labor_nominator,insurance_labor_denominator,insurance_labor_value
REAL(prec)  insurance_cons_nominator_single,insurance_cons_denominator_single,insurance_cons_value_single,insurance_labor_nominator_single,insurance_labor_denominator_single,insurance_labor_value_single,insurance_cons_nominator_couple,insurance_cons_denominator_couple,insurance_cons_value_couple,insurance_labor_nominator_couple,insurance_labor_denominator_couple,insurance_labor_value_couple
REAL(prec)  avg_log_income_single,avg_log_cons_single,insurance_nominator_single,insurance_denominator_single,insurance_value_single
REAL(prec)  avg_log_income_couple,avg_log_cons_couple,insurance_nominator_couple,insurance_denominator_couple,insurance_value_couple
REAL(prec)  agg_certeqcons_singlemale,agg_certeqlab_singlemale,agg_certeqcons_singlefemale,agg_certeqlab_singlefemale,V_certeq_singlemale,V_certeq_singlefemale
REAL(prec)  AggC_singlemale,AggC_singlefemale,AggL_singlemale,AggL_singlefemale,cost_unc_singlemale,cost_unc_singlefemale,AggC_couple
REAL(prec)  expV_certeq_singlemale,cost_ineq_singlemale,expV_certeq_singlefemale,cost_ineq_singlefemale
REAL(prec)  AggC_singlemale_leicomp,AggC_singlefemale_leicomp,AggL_singlemale_bm,AggL_singlefemale_bm,AggL_couple_male_bm,AggL_couple_female_bm
REAL(prec)	temp_singleYW,temp_coupleYW,temp_singleYR,temp_singleYW1,temp_singleYW2,temp_coupleYR,temp_singleYR_AGE,temp_coupleYR_AGE,temp_dist_single,temp_dist_couple
REAL(prec)  Avg_corr_family_earn
REAL(prec)  mean_earning_single,var_earning_single,mean_cons_single,var_cons_single,mean_earning_couple,var_earning_couple,mean_cons_couple,var_cons_couple
REAL(prec)  lambda_in,lambda_ll,lambda_out
REAL(prec)  CEV

INTEGER singleIDCWA(:,:,:,:,:)     !  Asset decision rules for single working-age
INTEGER coupleIDCWA(:,:,:,:,:)     !  Asset decision rules for couple working-age

INTEGER singleIDCWN(:,:,:,:,:)     !  Decision rules of labor supply for single working-age
INTEGER coupleIDCWN(:,:,:,:,:,:)   !  Decision rules of labor supply for couple working-age

REAL(prec) singleIDCWC(:,:,:,:,:)     !  Consumption decision rules for single working-age
REAL(prec) coupleIDCWC(:,:,:,:,:)     !  Consumption decision rules for couple working-age

REAL(prec) singleIDCRC(:,:,:,:)       !  Consumption decision rules for single retirees
REAL(prec) coupleIDCRC(:,:,:)     	  !  Consumption decision rules for couple retirees


INTEGER singleIDCRA(:,:,:,:)     !  Asset decision rules for retirees
INTEGER coupleIDCRA(:,:,:)     !  Asset decision rules for retirees

INTEGER singleIDCRN(:,:,:,:)     !  Decision rules of labor supply for retirees
INTEGER coupleIDCRN(:,:,:)     !  Decision rules of labor supply for retirees


INTEGER Q1,Q2,Q3,Q4,Q5,Top10pct,Top05pct,Top01pct
INTEGER Q1_D(:),  Q2_D(:), Q3_D(:), Q4_D(:), Q5_D(:)
INTEGER top05pct_D(:), top1pct_D(:), top5pct_D(:), top10pct_D(:), top20pct_D(:), top40pct_D(:), top50pct_D(:),top60pct_D(:), top70pct_D(:), top80pct_D(:),top90pct_D(:),top95pct_D(:),top99pct_D(:)
INTEGER	bot99pct_D(:), bot90pct_D(:), bot50pct_D(:), bot30pct_D(:), bot99pct_D_inc(:), bot90pct_D_inc(:), bot50pct_D_inc(:), bot30pct_D_inc(:),bot99pct_D_tinc(:), bot90pct_D_tinc(:), bot50pct_D_tinc(:), bot30pct_D_tinc(:)
INTEGER top0001pct_D(:), top0005pct_D(:), top001pct_D(:), top005pct_D(:), top01pct_D(:)
INTEGER top05pct_D_inc(:), top1pct_D_inc(:), top5pct_D_inc(:), top10pct_D_inc(:), top20pct_D_inc(:),top39pct_D_inc(:), top40pct_D_inc(:), top50pct_D_inc(:), top60pct_D_inc(:), top70pct_D_inc(:), top80pct_D_inc(:)
INTEGER top0001pct_D_inc(:), top0005pct_D_inc(:), top001pct_D_inc(:),top005pct_D_inc(:),top0039pct_D_inc(:), top01pct_D_inc(:), top025pct_D_inc(:)
INTEGER top05pct_D_tinc(:), top1pct_D_tinc(:), top5pct_D_tinc(:), top10pct_D_tinc(:), top20pct_D_tinc(:), top30pct_D_tinc(:), top40pct_D_tinc(:),top50pct_D_tinc(:), top60pct_D_tinc(:),top70pct_D_tinc(:), top80pct_D_tinc(:), top90pct_D_tinc(:), top95pct_D_tinc(:),top99pct_D_tinc(:),bot20pct_D_tinc(:)
INTEGER top0001pct_D_tinc(:), top0005pct_D_tinc(:), top001pct_D_tinc(:), top005pct_D_tinc(:), top01pct_D_tinc(:), top025pct_D_tinc(:)
INTEGER top05pct_D_R(:,:), top1pct_D_R(:,:), top5pct_D_R(:,:), top10pct_D_R(:,:), top20pct_D_R(:,:), top40pct_D_R(:,:),top50pct_D_R(:,:), top60pct_D_R(:,:),top70pct_D_R(:,:), top80pct_D_R(:,:)
INTEGER top0001pct_D_R(:,:), top0005pct_D_R(:,:), top001pct_D_R(:,:), top01pct_D_R(:,:)
INTEGER top1pct_D_B(:),top2pct_D_B(:),top5pct_D_B(:),top10pct_D_B(:),top20pct_D_B(:),top30pct_D_B(:),top40pct_D_B(:),top50pct_D_B(:),top60pct_D_B(:),top70pct_D_B(:),top80pct_D_B(:),top90pct_D_B(:)
INTEGER top1pct_D_B_age52(:),top2pct_D_B_age52(:),top5pct_D_B_age52(:),top10pct_D_B_age52(:),top20pct_D_B_age52(:),top30pct_D_B_age52(:),top40pct_D_B_age52(:),top50pct_D_B_age52(:),top60pct_D_B_age52(:),top70pct_D_B_age52(:),top80pct_D_B_age52(:),top90pct_D_B_age52(:)
INTEGER top05pct_D_C(:), top1pct_D_C(:), top5pct_D_C(:), top10pct_D_C(:), top20pct_D_C(:), top40pct_D_C(:), top50pct_D_C(:),top60pct_D_C(:), top70pct_D_C(:), top80pct_D_C(:),top90pct_D_C(:),top95pct_D_C(:),top99pct_D_C(:)
INTEGER top0001pct_D_C(:), top0005pct_D_C(:), top001pct_D_C(:), top01pct_D_C(:)
INTEGER box(:), box_inc(:), box_tinc(:), box_R(:), box_B(:),box_B_age52(:), box_C(:), box_inc_retire(:)
INTEGER record_position_tinc(:), record_position_tinc_single(:), record_position_tinc_couple(:), record_position_A(:), record_position_A_single(:), record_position_A_couple(:), record_position_E(:), record_position_E_single(:), record_position_E_couple(:), record_position_B(:),record_position_C(:)
INTEGER itax1(:),isubsidy1(:),itax2(:),isubsidy2(:),itax3(:),isubsidy3(:),itax4(:),isubsidy4(:),itax5(:),isubsidy5(:)
INTEGER bench_coupleIDCWN(:,:,:,:,:,:),bench_singleIDCWN(:,:,:,:,:)

REAL(prec) A(:)              !  Asset levels (control variable)
REAL(prec) AS(:)             !  Asset levels (state variable)
!REAL(prec) H(:)              !  Health status (state variable)
REAL(prec) N(:)              !  Working hours ratio
!REAL(prec) M(:)              !  Expenditure on health
REAL(prec) ALONG(:)          !  Longitudinal age-assets profile
REAL(prec) ALONG_AGE_single(:,:)
REAL(prec) ALONG_AGE_couple(:)
REAL(prec) ACROSS(:)          !  Cross-sectional age-assets profile
REAL(prec) CLONG(:)          !  Longitudinal age-consumption profile
REAL(prec) CCROSS(:)          !  Cross-sectional age-consumption profile
REAL(prec) EFFCROSS(:,:)       !  Cross-sectional age-earnings profile
REAL(prec) EFFLONG(:,:)        !  Longitudinal age-earnings profile for given cohort
REAL(prec) ILONG(:)          !  Longitudinal age-income profile
REAL(prec) ILONG_AGE_single(:,:)
REAL(prec) ILONG_AGE_couple(:)
REAL(prec) TILONG_AGE_single(:,:)
REAL(prec) TILONG_AGE_couple(:)
REAL(prec) YDLONG_AGE_single(:,:)
REAL(prec) YDLONG_AGE_couple(:)
REAL(prec) NLONG_AGE_single(:,:)
REAL(prec) NLONG_AGE_couple(:,:)
REAL(prec) labor_participation_age(:,:) 
REAL(prec) labor_participation_age_single(:,:) 
REAL(prec) labor_participation_age_couple(:,:) 
REAL(prec) ICROSS(:)          !  Cross-sectional age-income profile
REAL(prec) TILONG(:)         !  Longitudinal total income (labor + asset) profile
REAL(prec) TICROSS(:)          !  Cross-sectional total income profile
REAL(prec) ALONG_RETIRE_single(:), ILONG_RETIRE_single(:), TILONG_RETIRE_single(:), YDLONG_RETIRE_single(:)
REAL(prec) ALONG20_25_single(:), ALONG25_30_single(:), ALONG30_35_single(:), ALONG35_40_single(:), ALONG40_45_single(:), ALONG45_50_single(:), ALONG50_55_single(:), ALONG55_60_single(:), ALONG60_65_single(:), ALONG65_MORE_single(:)
REAL(prec) ALONG65_70_single(:), ALONG70_75_single(:), ALONG75_80_single(:), ALONG80_85_single(:), ALONG85_90_single(:), ALONG90_95_single(:), ALONG95_100_single(:) 
REAL(prec) ILONG20_25_single(:), ILONG25_30_single(:), ILONG30_35_single(:), ILONG35_40_single(:), ILONG40_45_single(:), ILONG45_50_single(:), ILONG50_55_single(:), ILONG55_60_single(:), ILONG60_65_single(:), ILONG65_MORE_single(:)
REAL(prec) TILONG20_25_single(:), TILONG25_30_single(:), TILONG30_35_single(:), TILONG35_40_single(:), TILONG40_45_single(:), TILONG45_50_single(:), TILONG50_55_single(:), TILONG55_60_single(:), TILONG60_65_single(:), TILONG65_MORE_single(:)
REAL(prec) YDLONG20_25_single(:), YDLONG25_30_single(:), YDLONG30_35_single(:), YDLONG35_40_single(:), YDLONG40_45_single(:), YDLONG45_50_single(:), YDLONG50_55_single(:), YDLONG55_60_single(:), YDLONG60_65_single(:), YDLONG65_MORE_single(:)
REAL(prec) WLONG_AGE(:,:)
REAL(prec) sort_inc_retire(:), sort_D_inc_retire(:)	

REAL(prec) NLONG(:)           !  Longitudinal efficiency labor supply profile
REAL(prec) NCROSS(:)          !  Cross-sectional efficiency labor supply profile
REAL(prec) LLONG_single(:,:)  !  Longitudinal labor supply profile
REAL(prec) LLONG_couple(:,:) 
REAL(prec) LCROSS(:)          !  Cross-sectional labor supply profile
!REAL(prec) SICKLONG(:)          !  Longitudinal sick time profile
REAL(prec) CUMS(:)           !  Unconditional survival probabilities, age 1 to age j
REAL(prec) MU(:)             !  Age distribution of population
REAL(prec) CUMSWK(:)         !  Unconditional survival probabilities, age 1 to age j, for working age
REAL(prec) MUWK(:)           !  Age distribution of working age population
REAL(prec) S(:,:)            !  Conditional survival probabilities, age j-1 to age j
REAL(prec) DEP_H(:)          !  Depreciation rate of health capital
REAL(prec) P_m(2,2)                  !  Assortative mating matrix
REAL(prec) P(nn,nn,2)                  !  Transition matrix of idiosyncratic productivity shock
REAL(prec) intP(nn,nn,2)                !  Intergenerational Transition matrix 
REAL(prec) W(nn,2)                  !   idiosyncratic productivity shock
REAL(prec) initial_dist_z(nn,2)
REAL(prec) SSprob_z1(nn,nn)
REAL(prec) SSprob_z2(nn,nn)
REAL(prec) probmul_P(nn,nn)
real(prec) basicz(nn)
real(prec) z(nn)
REAL(prec) couple_taxpenalty(nn,nn)         

REAL(prec) singleVW(:,:,:,:,:)          !  Value function for single working-age
REAL(prec) coupleVW(:,:,:,:,:)          !  Value function for couple working-age
REAL(prec) marriageVW(:,:,:,:,:,:)
REAL(prec) singleVR(:,:,:,:)            !  Value function for retired single
REAL(prec) coupleVR(:,:,:)              !  Value function for retired couple
REAL(prec) marriageVR(:,:,:,:) 

REAL(prec) singleYW(:,:,:,:,:)          !  Age-dependent distribution of single agents across states for working-age
REAL(prec) coupleYW(:,:,:,:,:)          !  Age-dependent distribution of couple agents across states for working-age
REAL(prec) Y_AGE(:)

REAL(prec) singleYR(:,:,:,:)          !  Age-dependent distribution of agents across states for retirees
REAL(prec) coupleYR(:,:,:)          !  Age-dependent distribution of agents across states for retirees

REAL(prec) Cond_Sur(:,:,:,:)
REAL(prec) CUMSur(:,:,:,:)
REAL(prec) MU_STATE(:,:,:,:)
REAL(prec) X(:,:)			  ! wealth: x(:,1), labor income: x(:,2), total income: x(:,3)
REAL(prec) D(:)
REAL(prec) D_inc(:)
REAL(prec) D_A(:)
REAL(prec) x_age(:,:)
REAL(prec) D_age(:,:)
REAL(prec) NorD_age(:,:)
REAL(prec) age_wea_gini(:)
! REAL(prec) D_YW(:,:,:,:)
! REAL(prec) D_YR(:,:,:)
REAL(prec) sort_A(:)
REAL(prec) sort_A_single(:)
REAL(prec) sort_A_couple(:)
REAL(prec) sort_inc(:)
REAL(prec) sort_INC_single(:)
REAL(prec) sort_INC_couple(:)
REAL(prec) sort_tinc(:)
REAL(prec) sort_tinc_single(:)
REAL(prec) sort_tinc_couple(:)
REAL(prec) sort_R(:,:)
REAL(prec) sort_B(:)
REAL(prec) sort_B_age52(:)
REAL(prec) sort_C(:)
REAL(prec) sort_D(:), temp_sort_D(:)
REAL(prec) sort_D_single(:)
REAL(prec) sort_D_couple(:)
REAL(prec) sort_D_inc(:), temp_sort_D_inc(:)
REAL(prec) sort_D_inc_single(:)
REAL(prec) sort_D_inc_couple(:)
REAL(prec) sort_D_tinc(:), temp_sort_D_tinc(:)
REAL(prec) sort_D_tinc_single(:)
REAL(prec) sort_D_tinc_couple(:)
REAL(prec) sort_D_R(:,:)
REAL(prec) sort_D_B(:)
REAL(prec) sort_D_B_age52(:)
REAL(prec) sort_D_C(:),temp_sort_D_C(:)
REAL(prec) cum_sort_D(:)
REAL(prec) cum_sort_D_inc(:)
REAL(prec) cum_sort_D_tinc(:)
REAL(prec) cum_sort_D_R(:,:)
REAL(prec) cum_sort_D_B(:)
REAL(prec) cum_sort_D_B_age52(:)
REAL(prec) cum_sort_D_C(:)
! REAL(prec) R(:),R_ANNUAL(:)
!REAL(prec) ATR(:)
REAL(prec) totalincome(:),earning_share(:), kincome_share(:), trans_share(:), age_share(:)
REAL(prec) synsaving(:),syn_totalincome(:)
REAL(prec) sort_cons_Y(:), sort_wealth_Y(:), sort_wealth_E(:)
REAL(prec) sort_ATY(:),sort_ATC(:),temp_sort_ATY(:),temp_sort_ATC(:),sort_noncorpY(:) , MTR(:)
REAL(prec) weight_R(:,:)
REAL(prec) EH(:)
REAL(prec) male_welfare(:),female_welfare(:),couple_welfare(:)
REAL(prec) avg_couple_welfare(:,:)
REAL(prec) temp_family_tax(:), temp_family_tax_dist(:), temp_family_subsidy(:), temp_family_subsidy_dist(:)
REAL(prec) temp_earnratio_tax(:,:,:), temp_earnratio_tax_dist(:,:,:), temp_earnratio_subsidy(:,:,:), temp_earnratio_subsidy_dist(:,:,:)
REAL(prec) prop_earnratio_tax(:,:),  prop_earnratio_subsidy(:,:), avg_earnratio_tax(:,:), avg_earnratio_subsidy(:,:)
REAL(prec) avg_z(:), age_gender_eff(:,:),gender_gap(:)
REAL(prec) certeq_singlemale(:), certeq_singlefemale(:), certeq_couplemale(:,:), certeq_couplefemale(:,:)
REAL(prec) temp_retire_single_util_C(:,:,:,:),retire_single_util_C(:,:,:,:),temp_retire_couple_util_C(:,:,:,:), retire_couple_util_C(:,:,:,:)
REAL(prec) temp_single_util_LS(:,:,:,:,:),single_util_LS(:,:,:,:,:),temp_single_util_C(:,:,:,:,:),single_util_C(:,:,:,:,:),temp_couple_util_LS(:,:,:,:,:,:),couple_util_LS(:,:,:,:,:),temp_couple_util_C(:,:,:,:,:,:),couple_util_C(:,:,:,:,:,:)
REAL(prec) single_avg_cons_incomethreshold(MAXAGE,5,2), single_avg_labor_incomethreshold(MAXAGE,5,2), single_avg_val_incomethreshold(MAXAGE,5,2), single_dist_incomethreshold(MAXAGE,5,2), single_workingdist_incomethreshold(MAXAGE,5,2)
REAL(prec) couple_avg_cons_incomethreshold(MAXAGE,5,2), couple_avg_labor_incomethreshold(MAXAGE,5,2), couple_avg_val_incomethreshold(MAXAGE,5,2), couple_dist_incomethreshold(MAXAGE,5,2), couple_workingdist_incomethreshold(MAXAGE,5,2)
REAL(prec) single_avg_cons_incomethreshold_21_35(5,2),single_avg_cons_incomethreshold_36_50(5,2),single_avg_cons_incomethreshold_51_65(5,2),single_avg_cons_incomethreshold_66_80(5,2),single_avg_cons_incomethreshold_81_100(5,2)
REAL(prec) couple_avg_cons_incomethreshold_21_35(5,2),couple_avg_cons_incomethreshold_36_50(5,2),couple_avg_cons_incomethreshold_51_65(5,2),couple_avg_cons_incomethreshold_66_80(5,2),couple_avg_cons_incomethreshold_81_100(5,2)
REAL(prec) single_avg_labor_incomethreshold_21_35(5,2),single_avg_labor_incomethreshold_36_50(5,2),single_avg_labor_incomethreshold_51_65(5,2)
REAL(prec) couple_avg_labor_incomethreshold_21_35(5,2),couple_avg_labor_incomethreshold_36_50(5,2),couple_avg_labor_incomethreshold_51_65(5,2)
REAL(prec) single_avg_val_incomethreshold_21_35(5,2),single_avg_val_incomethreshold_36_50(5,2),single_avg_val_incomethreshold_51_65(5,2),single_avg_val_incomethreshold_66_80(5,2),single_avg_val_incomethreshold_81_100(5,2)
REAL(prec) couple_avg_val_incomethreshold_21_35(5,2),couple_avg_val_incomethreshold_36_50(5,2),couple_avg_val_incomethreshold_51_65(5,2),couple_avg_val_incomethreshold_66_80(5,2),couple_avg_val_incomethreshold_81_100(5,2)
REAL(prec) bench_singleIDCRC(:,:,:,:),bench_single_VR(:,:,:,:),bench_singleYR(:,:,:,:),bench_retire_single_util_C(:,:,:,:),bench_singleIDCWC(:,:,:,:,:),bench_single_VW(:,:,:,:,:),bench_singleYW(:,:,:,:,:),bench_single_util_C(:,:,:,:,:),bench_single_util_LS(:,:,:,:,:)
REAL(prec) bench_coupleIDCRC(:,:,:,:),bench_couple_VR(:,:,:),bench_coupleYR(:,:,:),bench_retire_couple_util_C(:,:,:,:),bench_coupleIDCWC(:,:,:,:,:,:),bench_couple_VW(:,:,:,:,:),bench_coupleYW(:,:,:,:,:),bench_couple_util_C(:,:,:,:,:,:),bench_couple_util_LS(:,:,:,:,:)
REAL(prec) change_bench_singleIDCRC(MAXAGE,5,2),change_bench_single_val(MAXAGE,5,2),bench_singleYR_incomethreshold(MAXAGE,5,2),change_bench_singleIDCWC(MAXAGE,5,2),change_bench_singleIDCWN(MAXAGE,5,2),bench_singleYW_incomethreshold(MAXAGE,5,2)
REAL(prec) change_bench_coupleIDCRC(MAXAGE,5,2),change_bench_couple_val(MAXAGE,5,2),bench_coupleYR_incomethreshold(MAXAGE,5,2),change_bench_coupleIDCWC(MAXAGE,5,2),change_bench_coupleIDCWN(MAXAGE,5,2),bench_coupleYW_incomethreshold(MAXAGE,5,2)
REAL(prec) change_bench_single_cons_incomethreshold_working(5,2),change_bench_single_labor_incomethreshold_working(5,2),change_bench_single_val_incomethreshold_working(5,2),change_bench_single_cons_incomethreshold_retire(5,2),change_bench_single_val_incomethreshold_retire(5,2)
REAL(prec) change_bench_couple_cons_incomethreshold_working(5,2),change_bench_couple_labor_incomethreshold_working(5,2),change_bench_couple_val_incomethreshold_working(5,2),change_bench_couple_cons_incomethreshold_retire(5,2),change_bench_couple_val_incomethreshold_retire(5,2)
REAL(prec) cons_change_single_male_retire(5),cons_change_single_female_retire(5),cons_change_single_male_working(5),cons_change_single_female_working(5),cons_change_couple_male_retire(5),cons_change_couple_female_retire(5),cons_change_couple_male_working(5),cons_change_couple_female_working(5)
REAL(prec) sum_bench_single_val(:,:,:), sum_single_util_C(:,:,:),sum_bench_couple_val(:,:,:),sum_couple_util_C(:,:,:),sum_single_util_LS(:,:,:),sum_couple_util_LS(:,:,:)
REAL(prec) util_welfare_id_incomethreshold(5),single_util_C_incomethreshold(5),couple_util_C_incomethreshold(5),single_util_LS_incomethreshold(5),couple_util_LS_incomethreshold(5), CEV_incomethreshold(5) 
REAL(prec) log_income_diff_single(:),log_income_shock_diff_single(:),log_cons_diff_single(:),dist_single(:),log_income_diff_couple(:),log_income_shock_diff_couple(:),log_cons_diff_couple(:),dist_couple(:)
REAL(prec) log_income_diff_single_retire(:),log_cons_diff_single_retire(:),dist_single_retire(:),log_income_diff_couple_retire(:),log_cons_diff_couple_retire(:),dist_couple_retire(:)
REAL(prec) ageprofile_log_income_shock_diff_single(:,:),ageprofile_log_cons_diff_single(:,:),ageprofile_dist_single(:,:),ageprofile_log_income_shock_diff_couple(:,:),ageprofile_log_cons_diff_couple(:,:),ageprofile_dist_couple(:,:)
REAL(prec) ageprofile_avg_log_income_shock_single(:),ageprofile_avg_log_income_shock_couple(:),ageprofile_avg_log_cons_single(:),ageprofile_avg_log_cons_couple(:),ageprofile_insurance_cons_shock_nominator_single(:),ageprofile_insurance_cons_shock_nominator_couple(:)
REAL(prec) ageprofile_insurance_cons_shock_denominator_single(:),ageprofile_insurance_cons_shock_denominator_couple(:),ageprofile_insurance_cons_shock_value_single(:),ageprofile_insurance_cons_shock_value_couple(:)
REAL(prec) ageprofile_log_income_diff_single(:,:),ageprofile_log_income_diff_couple(:,:),ageprofile_avg_log_income_single(:),ageprofile_avg_log_income_couple(:)
REAL(prec) ageprofile_insurance_cons_nominator_single(:),ageprofile_insurance_cons_nominator_couple(:),ageprofile_insurance_cons_denominator_single(:),ageprofile_insurance_cons_denominator_couple(:),ageprofile_insurance_cons_value_single(:),ageprofile_insurance_cons_value_couple(:)
REAL(prec) certeqcons_singlemale(:),certeqlab_singlemale(:),certeqcons_singlefemale(:),certeqlab_singlefemale(:)
REAL(prec) certeqcons_couple(:,:,:),certeqlab_couple(:,:,:)
REAL(prec) agg_certeqcons_couple(:),agg_certeqlab_couple(:),V_certeq_couple(:)
REAL(prec) AggL_couple(:),cost_unc_couple(:),expV_certeq_couple(:),cost_ineq_couple(:),AggC_couple_leicomp(:),AggL_couple_bm(:)
REAL(prec) temp_single_discount(:,:),single_discount(:),temp_couple_discount1(:,:),temp_couple_discount2(:,:),couple_discount1(:),couple_discount2(:)
REAL(prec) var_earn_husband(:),var_earn_wife(:),cov_family_earn(:),corr_family_earn(:),mean_earn_husband(:),mean_earn_wife(:)
REAL(prec) mean_earning_age_single(:),var_earning_age_single(:),mean_wage_age_single(:),var_wage_age_single(:),mean_cons_age_single(:),var_cons_age_single(:),mean_earning_age_couple(:),var_earning_age_couple(:),var_earning_age_couple_HH(:),mean_wage_age_couple(:),var_wage_age_couple(:),mean_cons_age_couple(:),var_cons_age_couple(:)
REAL(prec) mean_earning_age(:),var_earning_age(:),mean_cons_age(:),var_cons_age(:)
REAL(prec) lifecycle_var_cons_earn_ratio_single(:),lifecycle_var_cons_earn_ratio_couple(:)
REAL(prec) read_vector_single(:),read_vector_couple(:),read_vector_single_N(:),read_vector_couple_N(:)
REAL(prec) VW_delta_single(:,:,:,:,:),uprime_alt_working_single(:,:,:,:,:),cv_working_single(:,:,:,:,:),VW_delta_couple(:,:,:,:,:),uprime_alt_working_couple(:,:,:,:,:),cv_working_couple(:,:,:,:,:)
REAL(prec) VR_delta_single(:,:,:,:),uprime_alt_retire_single(:,:,:,:),cv_retire_single(:,:,:,:),VR_delta_couple(:,:,:),uprime_alt_retire_couple(:,:,:),cv_retire_couple(:,:,:)
REAL(prec) vec_reform_welfare(:),vec_reform_CEV_util(:),vec_reform_welfare_newborn(:),vec_reform_CEV_newborn(:)

character(20) :: Argument1, Argument2, Argument3, Argument4, Argument5, Argument6, Argument7
character(20) :: Argument8, Argument9, Argument10, Argument11, Argument12,  Argument13,  Argument14
character(20) :: Argument15,  Argument16, Argument17, Argument18


ALLOCATABLE  A,AS, N, EH,  ACROSS, ALONG,ALONG_AGE, CCROSS, CLONG, CUMS, CUMSWK, EFFCROSS, EFFLONG, ICROSS, ILONG, TILONG, TICROSS
ALLOCATABLE  ALONG_AGE_single, ALONG_AGE_couple, ILONG_AGE_single, ILONG_AGE_couple, TILONG_AGE_single, TILONG_AGE_couple, YDLONG_AGE_single, YDLONG_AGE_couple,NLONG_AGE_single,NLONG_AGE_couple,labor_participation_age,labor_participation_age_single,labor_participation_age_couple
ALLOCATABLE  ALONG_RETIRE_single, ILONG_RETIRE_single, TILONG_RETIRE_single, YDLONG_RETIRE_single
ALLOCATABLE  ALONG20_25_single, ALONG25_30_single, ALONG30_35_single, ALONG35_40_single, ALONG40_45_single, ALONG45_50_single, ALONG50_55_single, ALONG55_60_single, ALONG60_65_single,  ALONG65_70_single, ALONG70_75_single, ALONG75_80_single, ALONG80_85_single, ALONG85_90_single, ALONG90_95_single, ALONG95_100_single, ALONG65_MORE_single
ALLOCATABLE  ILONG20_25_single, ILONG25_30_single, ILONG30_35_single, ILONG35_40_single, ILONG40_45_single, ILONG45_50_single, ILONG50_55_single, ILONG55_60_single, ILONG60_65_single, ILONG65_MORE_single
ALLOCATABLE  TILONG20_25_single, TILONG25_30_single, TILONG30_35_single, TILONG35_40_single, TILONG40_45_single, TILONG45_50_single, TILONG50_55_single, TILONG55_60_single, TILONG60_65_single, TILONG65_MORE_single
ALLOCATABLE  YDLONG20_25_single, YDLONG25_30_single, YDLONG30_35_single, YDLONG35_40_single, YDLONG40_45_single, YDLONG45_50_single, YDLONG50_55_single, YDLONG55_60_single, YDLONG60_65_single, YDLONG65_MORE_single
ALLOCATABLE	 WLONG_AGE
ALLOCATABLE  sort_inc_retire, sort_D_inc_retire, box_inc_retire
ALLOCATABLE  NCROSS, NLONG, LCROSS, LLONG_single,LLONG_couple, MU, MUWK, S, DEP_H
ALLOCATABLE  singleIDCWA, coupleIDCWA, singleIDCWN, coupleIDCWN, singleIDCWC, coupleIDCWC,singleVW, coupleVW, singleYW, coupleYW, marriageVW
ALLOCATABLE	 singleIDCRA, coupleIDCRA, singleIDCRN, coupleIDCRN, singleIDCRC, coupleIDCRC, singleVR, coupleVR, marriageVR, singleYR, coupleYR, Y_AGE
ALLOCATABLE  Cond_Sur,CUMSur,MU_STATE,X,D,D_inc,D_A,x_age,D_age,NorD_age,age_wea_gini,D_YW,D_YR,sort_A,sort_inc,sort_tinc,sort_D,temp_sort_D,sort_D_inc,temp_sort_D_inc,sort_D_tinc,temp_sort_D_tinc,cum_sort_D,cum_sort_D_inc,cum_sort_D_tinc
ALLOCATABLE  sort_A_single,sort_A_couple,sort_D_single,sort_D_couple
ALLOCATABLE  sort_INC_single,sort_INC_couple,sort_D_inc_single,sort_D_inc_couple
ALLOCATABLE  sort_tinc_single,sort_tinc_couple,sort_D_tinc_single,sort_D_tinc_couple
ALLOCATABLE  sort_R, sort_D_R,cum_sort_D_R,weight_R
ALLOCATABLE  sort_C, sort_D_C,cum_sort_D_C,temp_sort_D_C
ALLOCATABLE  sort_B,sort_B_age52, sort_D_B,sort_D_B_age52,cum_sort_D_B,cum_sort_D_B_age52
ALLOCATABLE  Q1_D,  Q2_D, Q3_D, Q4_D, Q5_D, box, box_inc, box_tinc, box_R, box_B, box_B_age52, box_C
ALLOCATABLE  top05pct_D, top1pct_D, top5pct_D, top10pct_D, top20pct_D, top40pct_D, top50pct_D, top60pct_D, top70pct_D, top80pct_D, top90pct_D, top95pct_D, top99pct_D
ALLOCATABLE  bot99pct_D, bot90pct_D, bot50pct_D, bot30pct_D, bot99pct_D_inc, bot90pct_D_inc, bot50pct_D_inc, bot30pct_D_inc,bot99pct_D_tinc, bot90pct_D_tinc, bot50pct_D_tinc, bot30pct_D_tinc
ALLOCATABLE  top0001pct_D, top0005pct_D, top001pct_D, top005pct_D,top01pct_D
ALLOCATABLE  top05pct_D_inc, top1pct_D_inc, top5pct_D_inc, top10pct_D_inc, top20pct_D_inc, top39pct_D_inc, top40pct_D_inc, top50pct_D_inc, top60pct_D_inc, top70pct_D_inc, top80pct_D_inc
ALLOCATABLE  top0001pct_D_inc, top0005pct_D_inc, top001pct_D_inc,top005pct_D_inc, top0039pct_D_inc, top01pct_D_inc, top025pct_D_inc
ALLOCATABLE  top05pct_D_tinc, top1pct_D_tinc, top5pct_D_tinc, top10pct_D_tinc, top20pct_D_tinc,top30pct_D_tinc, top40pct_D_tinc,top50pct_D_tinc, top60pct_D_tinc,top70pct_D_tinc, top80pct_D_tinc,top90pct_D_tinc,top95pct_D_tinc,top99pct_D_tinc,bot20pct_D_tinc
ALLOCATABLE  top0001pct_D_tinc, top0005pct_D_tinc, top001pct_D_tinc, top005pct_D_tinc, top01pct_D_tinc, top025pct_D_tinc
ALLOCATABLE  top05pct_D_R, top1pct_D_R, top5pct_D_R, top10pct_D_R, top20pct_D_R, top40pct_D_R,top50pct_D_R, top60pct_D_R,top70pct_D_R, top80pct_D_R
ALLOCATABLE  top0001pct_D_R, top0005pct_D_R, top001pct_D_R, top01pct_D_R
ALLOCATABLE  top1pct_D_B,top2pct_D_B,top5pct_D_B,top10pct_D_B,top20pct_D_B,top30pct_D_B,top40pct_D_B,top50pct_D_B,top60pct_D_B,top70pct_D_B,top80pct_D_B,top90pct_D_B
ALLOCATABLE  top1pct_D_B_age52,top2pct_D_B_age52,top5pct_D_B_age52,top10pct_D_B_age52,top20pct_D_B_age52,top30pct_D_B_age52,top40pct_D_B_age52,top50pct_D_B_age52,top60pct_D_B_age52,top70pct_D_B_age52,top80pct_D_B_age52,top90pct_D_B_age52
ALLOCATABLE  top05pct_D_C, top1pct_D_C, top5pct_D_C, top10pct_D_C, top20pct_D_C, top40pct_D_C, top50pct_D_C, top60pct_D_C, top70pct_D_C, top80pct_D_C, top90pct_D_C, top95pct_D_C, top99pct_D_C
ALLOCATABLE  top0001pct_D_C, top0005pct_D_C, top001pct_D_C, top01pct_D_C
!ALLOCATABLE  ATR, R_ANNUAL
!ALLOCATABLE  adj_sort_A 
ALLOCATABLE  record_position_tinc,record_position_tinc_single, record_position_tinc_couple, record_position_A,record_position_A_single,record_position_A_couple,record_position_E,record_position_E_single,record_position_E_couple,record_position_B,record_position_C
ALLOCATABLE	 totalincome, earning_share, kincome_share, trans_share, age_share
ALLOCATABLE	 synsaving, syn_totalincome
ALLOCATABLE  sort_cons_Y, sort_wealth_Y, sort_wealth_E
ALLOCATABLE  sort_ATY, sort_ATC,temp_sort_ATY, temp_sort_ATC,sort_noncorpY, MTR
ALLOCATABLE	 male_welfare,female_welfare,couple_welfare,avg_couple_welfare
ALLOCATABLE  temp_family_tax, temp_family_tax_dist, temp_family_subsidy, temp_family_subsidy_dist
ALLOCATABLE	 avg_z, age_gender_eff,gender_gap
ALLOCATABLE  temp_earnratio_tax, temp_earnratio_tax_dist, temp_earnratio_subsidy, temp_earnratio_subsidy_dist
ALLOCATABLE  prop_earnratio_tax,  prop_earnratio_subsidy, avg_earnratio_tax, avg_earnratio_subsidy
ALLOCATABLE  itax1,isubsidy1,itax2,isubsidy2,itax3,isubsidy3,itax4,isubsidy4,itax5,isubsidy5
ALLOCATABLE  certeq_singlemale,certeq_singlefemale,certeq_couplemale,certeq_couplefemale
ALLOCATABLE  temp_retire_single_util_C,retire_single_util_C,temp_retire_couple_util_C, retire_couple_util_C
ALLOCATABLE  temp_single_util_LS,single_util_LS,temp_single_util_C,single_util_C,temp_couple_util_LS,couple_util_LS,temp_couple_util_C,couple_util_C
ALLOCATABLE  bench_singleIDCRC,bench_single_VR,bench_singleYR,bench_retire_single_util_C,bench_singleIDCWC,bench_singleIDCWN,bench_single_VW,bench_singleYW,bench_single_util_C,bench_single_util_LS
ALLOCATABLE  bench_coupleIDCRC,bench_couple_VR,bench_coupleYR,bench_retire_couple_util_C,bench_coupleIDCWC,bench_coupleIDCWN,bench_couple_VW,bench_coupleYW,bench_couple_util_C,bench_couple_util_LS
ALLOCATABLE  sum_bench_single_val, sum_single_util_C,sum_bench_couple_val,sum_couple_util_C,sum_single_util_LS,sum_couple_util_LS
ALLOCATABLE  log_income_diff_single,log_income_shock_diff_single,log_cons_diff_single,dist_single,log_income_diff_couple,log_income_shock_diff_couple,log_cons_diff_couple,dist_couple
ALLOCATABLE  log_income_diff_single_retire,log_cons_diff_single_retire,dist_single_retire,log_income_diff_couple_retire,log_cons_diff_couple_retire,dist_couple_retire
ALLOCATABLE	 ageprofile_log_income_shock_diff_single,ageprofile_log_cons_diff_single,ageprofile_dist_single,ageprofile_log_income_shock_diff_couple,ageprofile_log_cons_diff_couple,ageprofile_dist_couple
ALLOCATABLE  ageprofile_avg_log_income_shock_single,ageprofile_avg_log_income_shock_couple,ageprofile_avg_log_cons_single,ageprofile_avg_log_cons_couple,ageprofile_insurance_cons_shock_nominator_single,ageprofile_insurance_cons_shock_nominator_couple
ALLOCATABLE  ageprofile_insurance_cons_shock_denominator_single,ageprofile_insurance_cons_shock_denominator_couple,ageprofile_insurance_cons_shock_value_single,ageprofile_insurance_cons_shock_value_couple
ALLOCATABLE	 ageprofile_log_income_diff_single,ageprofile_log_income_diff_couple,ageprofile_avg_log_income_single,ageprofile_avg_log_income_couple
ALLOCATABLE  ageprofile_insurance_cons_nominator_single,ageprofile_insurance_cons_nominator_couple,ageprofile_insurance_cons_denominator_single,ageprofile_insurance_cons_denominator_couple,ageprofile_insurance_cons_value_single,ageprofile_insurance_cons_value_couple
ALLOCATABLE  certeqcons_singlemale,certeqlab_singlemale,certeqcons_singlefemale,certeqlab_singlefemale
ALLOCATABLE  certeqcons_couple,certeqlab_couple
ALLOCATABLE  agg_certeqcons_couple,agg_certeqlab_couple,V_certeq_couple
ALLOCATABLE  AggL_couple,cost_unc_couple,expV_certeq_couple,cost_ineq_couple,AggC_couple_leicomp,AggL_couple_bm
ALLOCATABLE  temp_single_discount,single_discount,temp_couple_discount1,temp_couple_discount2,couple_discount1,couple_discount2
ALLOCATABLE  var_earn_husband,var_earn_wife,cov_family_earn,corr_family_earn,mean_earn_husband,mean_earn_wife
ALLOCATABLE  mean_earning_age_single,var_earning_age_single,mean_wage_age_single,var_wage_age_single,mean_cons_age_single,var_cons_age_single,mean_earning_age_couple,var_earning_age_couple,var_earning_age_couple_HH,mean_wage_age_couple,var_wage_age_couple,mean_cons_age_couple,var_cons_age_couple
ALLOCATABLE  mean_earning_age,var_earning_age,mean_cons_age,var_cons_age
ALLOCATABLE  lifecycle_var_cons_earn_ratio_single,lifecycle_var_cons_earn_ratio_couple
ALLOCATABLE read_vector_single,read_vector_couple, read_vector_single_N ,read_vector_couple_N
ALLOCATABLE VW_delta_single,uprime_alt_working_single,cv_working_single,VW_delta_couple,uprime_alt_working_couple,cv_working_couple
ALLOCATABLE VR_delta_single,uprime_alt_retire_single,cv_retire_single,VR_delta_couple,uprime_alt_retire_couple,cv_retire_couple
ALLOCATABLE vec_reform_welfare,vec_reform_CEV_util,vec_reform_welfare_newborn,vec_reform_CEV_newborn

real(prec) ostart,oend
real(prec) fstart, fend

!*********************
!
!   Open Files
!
!*********************

! OPEN(UNIT=60,FILE='comboeff_sigiri_5period.txt')
OPEN(UNIT=60,FILE='age_eff.txt')
! OPEN(UNIT=7,FILE='male_age_eff_spline.txt')
! OPEN(UNIT=9,FILE='female_age_eff_spline.txt')
! OPEN(UNIT=7,FILE='male_age_eff_pchip.txt')
! OPEN(UNIT=9,FILE='female_age_eff_pchip.txt')
OPEN(UNIT=7,FILE='male_age_eff.txt')
OPEN(UNIT=9,FILE='female_age_eff.txt')
OPEN(UNIT=10,FILE='Health_result_benchmark.txt')   
! OPEN(UNIT=18,FILE='Health_profile_benchmark.txt')
OPEN(UNIT=4,FILE='sort_A.txt')
OPEN(UNIT=5,FILE='sort_INC.txt')
OPEN(UNIT=8,FILE='sort_tinc.txt')
!OPEN(UNIT=9,FILE='C:\Users\user\Documents\FTN95 Examples\Fortran test\cali_res.txt')
OPEN(UNIT=3,FILE='dist.txt')
OPEN(UNIT=2,FILE='record_position_tinc.txt')
OPEN(UNIT=12,FILE='D_inc.txt')
OPEN(UNIT=54,FILE='opt_tax_record.txt')
OPEN(UNIT=22,FILE='gender_gap_data.txt')
OPEN(UNIT=25,FILE='couple_labor_male.txt')
OPEN(UNIT=26,FILE='couple_labor_female.txt')

IF (year==2020)	THEN 
	OPEN(UNIT=14,FILE='male_surv_2020.txt')
	OPEN(UNIT=13,FILE='female_surv_2020.txt')
ELSEIF	(year==2030)	THEN 
	OPEN(UNIT=14,FILE='male_surv_2030.txt')
	OPEN(UNIT=13,FILE='female_surv_2030.txt')
ELSEIF	(year==2050)	THEN 
	OPEN(UNIT=14,FILE='male_surv_2050.txt')
	OPEN(UNIT=13,FILE='female_surv_2050.txt')
END IF
!*********************
!
!   Read Data
!
!*********************

    ! ALLOCATE( EFFCROSS(RETAGE-1,2) )     ! for comboeff and psurv
    ! READ(7,*) ( EFFCROSS(AGE,1), AGE=1,RETAGE-1 )
	! READ(9,*) ( EFFCROSS(AGE,2), AGE=1,RETAGE-1 )
	! !EFFCROSS(:,2) = EFFCROSS(:,1)
	


    !READ(8,*) ( S(AGE), AGE=1,MAXAGE )
    !DO AGE=1,MAXAGE
        !S(AGE) = 1/(1+EXP(-5.490484+0.1499950*AGE+0.0161671*(AGE**2)))         ! quadratic form of sur. prob. as a fn of age
    !END DO 

!   Longitudinal age-earnings profile for given cohort

    ! ALLOCATE( EFFLONG(RETAGE-1,2) )
    ! EFFLONG(:,1) = (/ ( EFFCROSS(AGE,1)*((1+GROWTH)**(AGE-1)), AGE=1,RETAGE-1 ) /)
	! EFFLONG(:,2) = (/ ( EFFCROSS(AGE,2)*((1+GROWTH)**(AGE-1)), AGE=1,RETAGE-1 ) /)


	! CALL GET_COMMAND_ARGUMENT(1,Argument1)
	! CALL GET_COMMAND_ARGUMENT(2,Argument2)
	! CALL GET_COMMAND_ARGUMENT(3,Argument3)
	! CALL GET_COMMAND_ARGUMENT(4,Argument4)
	! CALL GET_COMMAND_ARGUMENT(5,Argument5)
	! CALL GET_COMMAND_ARGUMENT(6,Argument6)
	! CALL GET_COMMAND_ARGUMENT(7,Argument7)
	
	! read(Argument1,*) BETA_ANNUAL 
	! read(Argument2,*) tau_l_single
	! read(Argument3,*) tau_l_couple
	! read(Argument4,*) delta_lambda
	! read(Argument5,*) weight_MFS
	! read(Argument6,*) d_c
	! read(Argument7,*) gov
	
	CALL GET_COMMAND_ARGUMENT(1,Argument1)
	CALL GET_COMMAND_ARGUMENT(2,Argument2)
	CALL GET_COMMAND_ARGUMENT(3,Argument3)
	CALL GET_COMMAND_ARGUMENT(4,Argument4)
	CALL GET_COMMAND_ARGUMENT(5,Argument5)
	CALL GET_COMMAND_ARGUMENT(6,Argument6)
	CALL GET_COMMAND_ARGUMENT(7,Argument7)
	CALL GET_COMMAND_ARGUMENT(8,Argument8)
	CALL GET_COMMAND_ARGUMENT(9,Argument9)
	CALL GET_COMMAND_ARGUMENT(10,Argument10)
	CALL GET_COMMAND_ARGUMENT(11,Argument11)
	
	read(Argument1,*) BETA_ANNUAL 
	read(Argument2,*) fixcost_singlefemale
	read(Argument3,*) fixcost_marriedfemale
	read(Argument4,*) theta_single_male
	read(Argument5,*) theta_married_male
	read(Argument6,*) theta_single_female
	read(Argument7,*) theta_married_female
	read(Argument8,*) earn_corr
	read(Argument9,*) lambda_in
	read(Argument10,*) lambda_ll
	read(Argument11,*) zawel
	
	! nthr = OMP_GET_NUM_THREADS()
    ! print *, ' We are using',nthr,' thread(s)'
	BETA = BETA_ANNUAL**5.00  ! change beta from annual to 5 years

	! Assortative mating matrix: Jeremy Greenwood et al. 2016 (Table 5)
 	!P_m = RESHAPE((/0.855, 0.082, 0.023, 0.041/),(/2,2/))	!1960
	 P_m = RESHAPE((/0.545, 0.109, 0.108, 0.237/),(/2,2/))	!2005

	! Random mating matrix:
	! P_m = RESHAPE((/0.427062, 0.226284, 0.225285, 0.11937/),(/2,2/))	!2005

! 1 year transition matrix of productivity shock
! DO IG=1,2
! P(1,:,IG) = [real(prec) :: 0.6795,  0.1937,	0.0799,	0.0468]
! P(2,:,IG) = [real(prec) :: 0.1753,	0.5055,	0.2383,	0.0809]
! P(3,:,IG) = [real(prec) :: 0.0714,	0.1876,	0.5121,	0.2288]
! P(4,:,IG) = [real(prec) :: 0.3796,	0.0606,	0.1196,	0.4402]
! END DO 

! 5 year transition matrix of "ordinary" idiosyncratic productivity shock
! DO IG=1,2
! P(1,:,IG) = [real(prec) :: 0.3837,  0.2547, 0.2150, 0.1462]
! P(2,:,IG) = [real(prec) :: 0.3535,  0.2504, 0.2312, 0.1647]
! P(3,:,IG) = [real(prec) :: 0.3580,  0.2408, 0.2289, 0.1720]
! P(4,:,IG) = [real(prec) :: 0.3936,  0.2445, 0.2090, 0.1526]
! END DO 
lambda_out = (1.0-lambda_ll)/(nn-1.0)
DO IG=1,2
P(1,:,IG) = [real(prec) :: 0.3837*(1.0-lambda_in),  0.2547*(1.0-lambda_in), 0.2150*(1.0-lambda_in), 0.1462*(1.0-lambda_in), lambda_in]
P(2,:,IG) = [real(prec) :: 0.3535*(1.0-lambda_in),  0.2504*(1.0-lambda_in), 0.2312*(1.0-lambda_in), 0.1647*(1.0-lambda_in), lambda_in]
P(3,:,IG) = [real(prec) :: 0.3580*(1.0-lambda_in),  0.2408*(1.0-lambda_in), 0.2289*(1.0-lambda_in), 0.1720*(1.0-lambda_in), lambda_in]
P(4,:,IG) = [real(prec) :: 0.3936*(1.0-lambda_in),  0.2445*(1.0-lambda_in), 0.2090*(1.0-lambda_in), 0.1526*(1.0-lambda_in), lambda_in]
P(5,:,IG) = [real(prec) :: lambda_out, lambda_out, lambda_out, lambda_out, lambda_ll]
END DO 

print *, "Transition Matrix for Productivity Process"
	DO i=1,nn
	  	WRITE(*,"(12(F10.6,1X))") P(i,1:nn,1)
	END DO
print*, ' '

! basicz(1) = -1.267289817081295
! basicz(2) = -0.588151250955058
! basicz(3) = 0.090987315171178
! basicz(4) = -0.090987315171178
! basicz(5) = 0.588151250955058
! basicz(6) = 1.267289817081295

! z(:) = basicz(:)
! z(:) = exp(z(:))/exp(z(1))

z(1) = 0.34/0.34
z(2) = 0.68/0.34
z(3) = 0.97/0.34
z(4) = 2.01/0.34
z(5) = zawel/0.34
W(:,1) = z(:)
W(:,2) = z(:)

print*,'z states'
WRITE(*,"(12(F12.4,1X))") W(:,1)
WRITE(*,"(12(F12.4,1X))") W(:,2)
!=============================================================================================================================================================================================================

	! initial_dist_z(1,1) = 0.5798867*0.088/(0.088+0.824+0.088)
	! initial_dist_z(2,1) = 0.5798867*0.824/(0.088+0.824+0.088)
	! initial_dist_z(3,1) = 0.5798867*0.088/(0.088+0.824+0.088)
	! initial_dist_z(4,1) = (1.0-0.5798867)*0.088/(0.088+0.824+0.088)
	! initial_dist_z(5,1) = (1.0-0.5798867)*0.824/(0.088+0.824+0.088)
	! initial_dist_z(6,1) = (1.0-0.5798867)*0.088/(0.088+0.824+0.088)

	! initial_dist_z(1,2) = 0.6336308*0.088/(0.088+0.824+0.088)
	! initial_dist_z(2,2) = 0.6336308*0.824/(0.088+0.824+0.088)
	! initial_dist_z(3,2) = 0.6336308*0.088/(0.088+0.824+0.088)
	! initial_dist_z(4,2) = (1.0-0.6336308)*0.088/(0.088+0.824+0.088)
	! initial_dist_z(5,2) = (1.0-0.6336308)*0.824/(0.088+0.824+0.088)
	! initial_dist_z(6,2) = (1.0-0.6336308)*0.088/(0.088+0.824+0.088)


	! initial_dist_z(1,1) = 1.0
	! initial_dist_z(2,1) = 0.0
	! initial_dist_z(3,1) = 0.0
	! initial_dist_z(4,1) = 0.0
	
	! initial_dist_z(1,2) = 1.0
	! initial_dist_z(2,2) = 0.0
	! initial_dist_z(3,2) = 0.0
	! initial_dist_z(4,2) = 0.0

	initial_dist_z(1,1) = 0.25
	initial_dist_z(2,1) = 0.25
	initial_dist_z(3,1) = 0.25
	initial_dist_z(4,1) = 0.25
	initial_dist_z(5,1) = 0.0
	
	initial_dist_z(1,2) = 0.25
	initial_dist_z(2,2) = 0.25
	initial_dist_z(3,2) = 0.25
	initial_dist_z(4,2) = 0.25
	initial_dist_z(5,2) = 0.0
	
print*,'initial_invar_male=',initial_dist_z(:,1)
print*,'initial_invar_female=',initial_dist_z(:,2)

! Calculate the stationary probabilities for productivity matrix. 
	probmul_P = P(:,:,1)
	DO i=1,5000
     probmul_P=MATMUL(probmul_P,P(:,:,1))
	END DO
	SSprob_z1 = probmul_P; 
	print *, 'Steady State Probabilities for Male'
	WRITE(*,"(12(F10.6,1X))") SSprob_z1(1,:)

	probmul_P = P(:,:,2)
	DO i=1,5000
     probmul_P=MATMUL(probmul_P,P(:,:,2))
	END DO
	SSprob_z2 = probmul_P; 
	print *, 'Steady State Probabilities for Female'
	WRITE(*,"(12(F10.6,1X))") SSprob_z2(1,:)	

	! OPEN(UNIT=11,FILE='initial_dist_z.txt')
	! WRITE(11,*) 'Male Transitional productivity matrix'
	! write(11,"(11(F8.5,1X))") P(1,1,1), P(1,2,1), P(1,3,1), P(1,4,1), P(1,5,1), P(1,6,1)
	! write(11,"(11(F8.5,1X))") P(2,1,1), P(2,2,1), P(2,3,1), P(2,4,1), P(2,5,1), P(2,6,1)
	! write(11,"(11(F8.5,1X))") P(3,1,1), P(3,2,1), P(3,3,1), P(3,4,1), P(3,5,1), P(3,6,1)
	! write(11,"(11(F8.5,1X))") P(4,1,1), P(4,2,1), P(4,3,1), P(4,4,1), P(4,5,1), P(4,6,1)
	! write(11,"(11(F8.5,1X))") P(5,1,1), P(5,2,1), P(5,3,1), P(5,4,1), P(5,5,1), P(5,6,1)
	! write(11,"(11(F8.5,1X))") P(6,1,1), P(6,2,1), P(6,3,1), P(6,4,1), P(6,5,1), P(6,6,1)
	! WRITE(11,*)
	! WRITE(11,*) 'Steady State Probabilities for Male'
	! write(11,"(11(F8.5,1X))") SSprob_z1(1,:)	
	! WRITE(11,*)

	! WRITE(11,*) 'Female Transitional productivity matrix'
	! write(11,"(11(F8.5,1X))") P(1,1,2), P(1,2,2), P(1,3,2), P(1,4,2), P(1,5,2), P(1,6,2)
	! write(11,"(11(F8.5,1X))") P(2,1,2), P(2,2,2), P(2,3,2), P(2,4,2), P(2,5,2), P(2,6,2)
	! write(11,"(11(F8.5,1X))") P(3,1,2), P(3,2,2), P(3,3,2), P(3,4,2), P(3,5,2), P(3,6,2)
	! write(11,"(11(F8.5,1X))") P(4,1,2), P(4,2,2), P(4,3,2), P(4,4,2), P(4,5,2), P(4,6,2)
	! write(11,"(11(F8.5,1X))") P(5,1,2), P(5,2,2), P(5,3,2), P(5,4,2), P(5,5,2), P(5,6,2)
	! write(11,"(11(F8.5,1X))") P(6,1,2), P(6,2,2), P(6,3,2), P(6,4,2), P(6,5,2), P(6,6,2)
	! WRITE(11,*)
	! WRITE(11,*) 'Steady State Probabilities for Female'
	! write(11,"(11(F8.5,1X))") SSprob_z2(1,:)	
	! WRITE(11,*)	

	! WRITE(11,*) 'Marriage-Sorting matrix='
	! write(11,"(11(F8.5,1X))") P_m(1,1), P_m(1,2)
	! write(11,"(11(F8.5,1X))") P_m(2,1), P_m(2,2)
	! CLOSE(UNIT=11)
	
		print*, ' '
		print *, "Male Transition Matrix for Productivity Process"
			DO i=1,nn
	  			WRITE(*,"(12(F10.6,1X))") P(i,1:nn,1)
			END DO
		print*, ' '
		print *, "Female Transition Matrix for Productivity Process"
			DO i=1,nn
	  			WRITE(*,"(12(F10.6,1X))") P(i,1:nn,2)
			END DO
		print*, ' '	
		print *, 'Marriage-Sorting matrix'
		WRITE(*,"(12(F10.6,1X))") P_m(1,1:2)
		WRITE(*,"(12(F10.6,1X))") P_m(2,1:2)
		print*, ' '


!*****************************************

! Age-efficiency

!*****************************************
! ALLOCATE(  avg_z(2) )
! invar_male_low=( (1.0-marryprop)*initial_dist_z(1,1)+marryprop*P_m(1,1)+marryprop*P_m(1,2) )/&
! 	  			 ( (1.0-marryprop)*initial_dist_z(1,1)+(1.0-marryprop)*initial_dist_z(3,1)+marryprop*P_m(1,1)+marryprop*P_m(1,2)+marryprop*P_m(2,1)+marryprop*P_m(2,2) )

! invar_male_high=( (1.0-marryprop)*initial_dist_z(3,1)+marryprop*P_m(2,1)+marryprop*P_m(2,2) )/&
! 	  			 ( (1.0-marryprop)*initial_dist_z(1,1)+(1.0-marryprop)*initial_dist_z(3,1)+marryprop*P_m(1,1)+marryprop*P_m(1,2)+marryprop*P_m(2,1)+marryprop*P_m(2,2) )

! invar_female_low=( (1.0-marryprop)*initial_dist_z(1,2)+marryprop*P_m(1,1)+marryprop*P_m(2,1) )/&
! 	  			 ( (1.0-marryprop)*initial_dist_z(1,2)+(1.0-marryprop)*initial_dist_z(3,2)+marryprop*P_m(1,1)+marryprop*P_m(2,1)+marryprop*P_m(1,2)+marryprop*P_m(2,2) )

! invar_female_high=( (1.0-marryprop)*initial_dist_z(3,2)+marryprop*P_m(1,2)+marryprop*P_m(2,2) )/&
! 	  			 ( (1.0-marryprop)*initial_dist_z(1,2)+(1.0-marryprop)*initial_dist_z(3,2)+marryprop*P_m(1,1)+marryprop*P_m(2,1)+marryprop*P_m(1,2)+marryprop*P_m(2,2) )


! ! compute average productivity for male
! !avg_z(1) = (W(1,1)*SSprob_z1(1,1)+W(2,1)*SSprob_z1(1,2))*initial_dist_z(1,1) + (W(3,1)*SSprob_z1(1,1)+W(4,1)*SSprob_z1(1,2))*initial_dist_z(3,1)
! avg_z(1) = (W(1,1)*SSprob_z1(1,1)+W(2,1)*SSprob_z1(1,2))*invar_male_low + (W(3,1)*SSprob_z1(1,1)+W(4,1)*SSprob_z1(1,2))*invar_male_high

! ! compute average productivity for female
! !avg_z(2) = (W(1,2)*SSprob_z2(1,1)+W(2,2)*SSprob_z2(1,2))*initial_dist_z(1,2) + (W(3,2)*SSprob_z2(1,1)+W(4,2)*SSprob_z2(1,2))*initial_dist_z(3,2)
! avg_z(2) = (W(1,2)*SSprob_z2(1,1)+W(2,2)*SSprob_z2(1,2))*invar_female_low + (W(3,2)*SSprob_z2(1,1)+W(4,2)*SSprob_z2(1,2))*invar_female_high

! print*, 'avg_z(1)=', avg_z(1)
! print*, 'avg_z(2)=', avg_z(2)

! ALLOCATE( EFFCROSS(RETAGE-1,2) )     ! from wineq_KLP
! READ(60,*) ( EFFCROSS(AGE,1), AGE=1,RETAGE-1 )	! Male age-eff

! ! Import gender_gap data from "Taxation and household labor supply" Guner2012
! ! Source: Table A2.xls
! ALLOCATE( age_gender_eff(RETAGE-1,2) )    
! READ(7,*) ( age_gender_eff(AGE,1), AGE=1,RETAGE-1 )
! READ(9,*) ( age_gender_eff(AGE,2), AGE=1,RETAGE-1 )
! EFFCROSS(:,2) = EFFCROSS(:,1)*(avg_z(1)/avg_z(2))*(age_gender_eff(:,2)/age_gender_eff(:,1))

! ! ALLOCATE( gender_gap(RETAGE-1) )  
! ! ! READ(22,*) ( gender_gap(AGE), AGE=1,RETAGE-1 ) 
! ! READ(22,*) ( gender_gap(AGE+1), AGE=1,RETAGE-2 )  
! !  gender_gap(1) = gender_gap(2) 
! !  EFFCROSS(:,2) = EFFCROSS(:,1)*(avg_z(1)/avg_z(2))*gender_gap(:)


! W(:,1) = W(:,1)*EFFCROSS(1,1)
! W(:,2) = W(:,2)*EFFCROSS(1,2)

! ! ! Normalize the first period efficieny to be 1
! EFFCROSS(:,1) = EFFCROSS(:,1)/EFFCROSS(1,1)
! EFFCROSS(:,2) = EFFCROSS(:,2)/EFFCROSS(1,2)


! print*, 'male wage'
! print*, W(:,1)
! print*, 'male_age_eff'
! print*, EFFCROSS(:,1)
! print*, 'female wage'
! print*, W(:,2)
! print*, 'female_age_eff'
! print*, EFFCROSS(:,2)


! ------------------------------- Apply the age-eff profiles from Guner 2012 Table A2 -------------------------------
ALLOCATE( EFFCROSS(RETAGE-1,2) )    
READ(7,*) ( EFFCROSS(AGE,1), AGE=1,RETAGE-1 )	! Male age-eff
READ(9,*) ( EFFCROSS(AGE,2), AGE=1,RETAGE-1 )	! Female age-eff

! Normalize the first period efficieny to be 1
	! EFFCROSS(:,1) = EFFCROSS(:,1)/EFFCROSS(1,1)
	! EFFCROSS(:,2) = EFFCROSS(:,2)/EFFCROSS(1,2)

! Longitudinal age-earnings profile for given cohort
ALLOCATE( EFFLONG(RETAGE-1,2) )
EFFLONG(:,1) = EFFCROSS(:,1)
EFFLONG(:,2) = EFFCROSS(:,2)

! Normalized by female first period wage
EFFLONG(:,1) = EFFCROSS(:,1)/EFFCROSS(1,2)
EFFLONG(:,2) = EFFCROSS(:,2)/EFFCROSS(1,2)

print*,'Male age-eff profiles'
print*, EFFLONG(:,1)
print*,'Female age-eff profiles'
print*, EFFLONG(:,2)

! OPEN(UNIT=27,FILE='EFFLONG.txt')
! 	write(27,*) EFFLONG
! CLOSE(27)


!*********************
!
!  Tabulate state and control variables
!
!*********************


!   Tabulate asset levels

!    ALLOCATE ( A(NGRIDA) )    
!    A = (/ ( AMIN + (AMAX-AMIN)*((FLOAT(IA-1)/FLOAT(NGRIDA-1))**1.000), IA=1,NGRIDA ) /)
    
	!A(1)=0.0
    !DO IA=2,NGRIDA
    !    A(IA)=AMAX*((IA-1.0)/(NGRIDA-1.0))**2.0
    !END DO
	
!!! Option 2: Logarithmic
	! ALLOCATE ( A(NGRIDA) ) 
	! tempA = (log(AMAX+1.0-AMIN) - 0.0)/(NGRIDA-1.0)
	! A = (/ ( exp(AMIN + (i-1)*tempA)-1.0+AMIN , i=1,NGRIDA )  /)

!!! Option 3: Log-linear
! log-linear, with unequal spacing.
! above old kmax, add potential for growing at rawe every period, for 10 periods. Make this a bit smoother by making increments (1+rawe)^(1/4).
! between this and about point 400, space the points a bit more widely.

	ALLOCATE( A(NGRIDA) ) 
	A = (/ ( exp(log(AMIN) + (log(AMAX)-log(AMIN))*(FLOAT(IA-1)/FLOAT(NGRIDA-1)) ), IA=1,NGRIDA ) /)
	A(1) = 0.0000001

	! ASWITCH1 = FLOOR(.8*NGRIDA)
	! ! ASWITCH2 = NGRIDA-48
	! ASWITCH2 = NGRIDA-48
	! A(ASWITCH1+1:ASWITCH2) = (/ (exp(log(A(ASWITCH1)) + IA * (log(AMAX)-log(A(ASWITCH1)))/(ASWITCH2-ASWITCH1)), IA=1,ASWITCH2-ASWITCH1 ) /)
	! ! A(ASWITCH2+1:NGRIDA) = (/ (AMAX * (1+R)**(0.25*FLOAT(IA)), IA = 1,48) /)
	! A(ASWITCH2+1:NGRIDA) = (/ (AMAX * (1+R)**(0.25*FLOAT(IA)), IA = 1,48) /)


OPEN(UNIT=27,FILE='Agrid.txt')
		write(27,*) A
	CLOSE(27)

! For option 1 and 2
	!ZEROINDEX = INT(ABS(AMIN)/((AMAX-AMIN)/FLOAT(NGRIDA-1)) + 1.000)

! log-linear zero asset index
	ZEROINDEX =	INT(abs(exp( log(AMIN)/(log(AMAX)-log(AMIN))/FLOAT(NGRIDA-1) ) + 1.000))

PRINT*, 'Zero Asset Index =', ZEROINDEX

!   Tabulate AIME
! ALLOCATE( EH(NGRIDEH) )    ! discretize earning history state-variable
! !EH = (/ ( 0.0 + (EHMAX-0.0)*((FLOAT(IE-1)/FLOAT(NGRIDEH-1))**1.000), IE=1,NGRIDEH ) /)
!  EH = (/ ( EHMAX*((FLOAT(IE-1))/FLOAT(NGRIDEH-1)**1.000), IE=1,NGRIDEH ) /)
	
    
!   Tabulate working hours ratio level
! SELECT CASE(couple_labor)
! CASE(0)
!     ALLOCATE(N(NGRIDA+(RETAGE-1)*2))	
! 	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)	
! 	READ(25,*) ( N(AGE), AGE=NGRIDA+1,NGRIDA+RETAGE-1 )
! 	READ(26,*) ( N(AGE), AGE=NGRIDA+RETAGE,NGRIDA+(RETAGE-1)*2 )
! CASE(1)
! 	ALLOCATE(N(NGRIDA+(RETAGE-1)))	
! 	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)
! 	READ(26,*) ( N(AGE), AGE=NGRIDA+1,NGRIDA+RETAGE-1 )
! CASE(2)
! 	ALLOCATE(N(NGRIDA))	
! 	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)	
! END SELECT
	ALLOCATE(N(NGRIDA))	
	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)	

!   Survival probability
ALLOCATE(S(MAXAGE,2))
S(1:RETAGE-1,:) = 1.0	
READ(14,*) ( S(AGE,1), AGE=RETAGE,MAXAGE-1 )	!male surv
READ(13,*) ( S(AGE,2), AGE=RETAGE,MAXAGE-1 )	!female surv
! S(:,2) = S(:,1)
S(MAXAGE,:) = 0.0

!*********************
!
!   Preliminary Calculations
!
!*********************
    
!	EHMAX	= EHMAX0
	BEQ     = BEQ0
	!SS      = SS0
	!STAX    = STAX0
	!MTAX    = MTAX0
	MTAX    = 0.0
	!PREMIUM = PREMIUM0
	! PREMIUM = 0.0

	! lambda1 = lambdamin
	! lambda2 = lambdamax
	! lambda = 0.5*lambda1 + 0.5*lambda2
	!dlam = 1.0

	! PIA_factor1 = PIA_factor_min
	! PIA_factor2 = PIA_factor_max
	! PIA_factor = 0.5*PIA_factor1 + 0.5*PIA_factor2
	
	! R_ANNUAL =  0.041	!0.03687	! Initial guess of interest rate
	! R = (1+R_ANNUAL)**5.00-1.00
	! R1 = (1+Rmin)**5.0-1.0
	! R2 = (1+Rmax)**5.0-1.0

!   Growth rate of aggregate output
	! ALLOCATE( ATR(NGRIDR) )
     AGROWTH = (1.0+GROWTH)*(1.0+POPG) - 1.000
    ! ATR = (/ ((1.0 + R(i)), i=1,NGRIDR) /) 

!  conditional probability for a married household to be a perfectly correlated household given that they are on the diagonal
	earn_corr_conditional = earn_corr/(earn_corr+(1.0-earn_corr)*DOT_PRODUCT(SSprob_z1(1,:),SSprob_z2(1,:)))
	print*,'earn_corr_conditional=',earn_corr_conditional
                                                               
! Write to Output file

    WRITE(10,*) 'PARAMETER VALUES for Health_GE_5period_endosur_MD_benchmark.f90'
    WRITE(10,*) '------------------------------------------------------'
    WRITE(10,*)

!   WRITE(10,*) '	Wage rate:', WAGE
!   WRITE(10,*) '	Interest rate (annual):', R_ANNUAL
!   WRITE(10,*) '	Interest rate (5 years accumulative):', R
    WRITE(10,*)

    WRITE(10,*) '	Initial Bequest:', BEQ0
    WRITE(10,*) '	Initial SS benefit:', SS0
    WRITE(10,*) '	Initial SS benefit:', STAX0
    WRITE(10,*) '	Initial med tax rate:', MTAX0
    WRITE(10,*) '	Initial EHI premium:', PREMIUM0
    WRITE(10,*) 

    WRITE(10,*) '	Convergence tolerance for bequests:', TOLB
    WRITE(10,*) '	Convergence tolerance for SS benefits:', TOLSS
    WRITE(10,*) '	Convergence tolerance for SS tax rate:', TOLSTAX
    WRITE(10,*) '	Convergence tolerance for med tax rate:', TOLMTAX
    WRITE(10,*) '	Convergence tolerance for EHI premium:', TOLEHI
    WRITE(10,*) '	Convergence gradient for bequests:', GRADB
    WRITE(10,*) '	Convergence gradient for SS tax rate:', GRADSS
    WRITE(10,*) '	Convergence gradient for SS tax rate:', GRADSTAX
    WRITE(10,*) '	Convergence gradient for med tax rate:', GRADMTAX
    WRITE(10,*) '	Convergence gradient for EHI premium:', GRADEHI
    WRITE(10,*) '	Maximum number of iterations for convergence:', MAXITER
    WRITE(10,*)
   
    WRITE(10,*) '	Capital exponent in production function:', ALPHA
    WRITE(10,*) '	Multiplicative constant in production function:', TFP
    WRITE(10,*) '	Annual growth rate of per capita output:', GROWTH_ANNUAL
    WRITE(10,*) '	Annual Depreciation rate:', DEP_ANNUAL
    WRITE(10,*) '	Depreciation rate of capital (5 years):', DEP
    WRITE(10,*)
    
    WRITE(10,*) '  Annual subjective discount factor:', BETA_ANNUAL
    WRITE(10,*) '  subjective discount factor ( 5 years):', BETA
    WRITE(10,*) '  Risk aversion parameter:', sigma
    WRITE(10,*) '  Constant term in utility function:', UCONS
    WRITE(10,*) '  Share of consumption in the consumption-leisure composition:', RHO
    WRITE(10,*) '  Elasticity of substitution b/w consumption-leisure and health:', PSI
!    WRITE(10,*) '  Share of consumption-leisure composition in utility:', LAMBDA
    WRITE(10,*)

    WRITE(10,*) '  Productivity of health accumulation technology:', B
    WRITE(10,*) '	Return to Scale in health investment:', XI
    WRITE(10,*)

    WRITE(10,*) '  Intercept of depreciation rate of health status (a0):', a0
    WRITE(10,*) '  Coefficent for age (a1):', a1
    WRITE(10,*) '	Coefficent for age^2 (a2):', a2
    WRITE(10,*)

    WRITE(10,*) '  Intercept of sur. prob. function (c0):', c0
    WRITE(10,*) '  Coefficent for age (c1):', c1
    WRITE(10,*) '	Coefficent for age^2 (c2):', c2
    WRITE(10,*) '	Coefficent for health (c3):', c3
    WRITE(10,*)

    WRITE(10,*) '  Scale factor of sick time:', Q
    WRITE(10,*) '  Elasticity of sick time to health status:', GAMMA1
    WRITE(10,*)

    WRITE(10,*) '  Social security replacement ratio:', REPLACE
    WRITE(10,*) '  Subsidy rate of med (Medicaid + Medicare):', SUBM
    WRITE(10,*)

    WRITE(10,*) '  Maximum age allowed:', MAXAGE
    WRITE(10,*) '  Retirement age:', RETAGE
    WRITE(10,*) '	Population growth rate:', POPG
    WRITE(10,*)

    WRITE(10,*) '  Maximum permissible asset:', AMAX
    WRITE(10,*) '  Minimum permissible asset:', AMIN
    WRITE(10,*) '  Maximum permissible med expenditure:', MMAX
    WRITE(10,*) '  Number of points on health state grid:', NGRIDH
    WRITE(10,*) '  Number of points on asset grid:', NGRIDA
    WRITE(10,*) '------------------------------------------------------'		
    WRITE(10,*)

    CALL CPU_TIME(t0)
    PRINT*, 'Begin the Program. Please Wait!'


IF (source_welfare_analysis_activation == 1) THEN 
	source_welfare = 0
ELSE 
	source_welfare = 100 
END IF 

IF (optimal_tax_activation == 0) THEN 
	optimal_tax = 0
ELSEIF (optimal_tax_activation == 1) THEN 
	optimal_tax = 1
END IF 

IF (GBC_method_activation==0) THEN      !Optimal set GBC_method=0 because the GB is cleared by lambda
	GBC_method = 0
	gov_exp = 0.044
ELSEIF (GBC_method_activation==1) THEN 	!Benchmark set GBC_method=1 because the GB is cleared by Gov
	GBC_method = 1	
ELSEIF (GBC_method_activation==2) THEN 	!Benchmark set GBC_method=1 because the GB is cleared by tau_s
	GBC_method = 2	
	! gov_exp = 0.044	
	gov_exp = 0.17
ELSEIF (GBC_method_activation==4) THEN 	!Benchmark set GBC_method=1 because the GB is cleared by premium_rate
	GBC_method = 4	
	! gov_exp = 0.044
	gov_exp = 0.17
ELSEIF (GBC_method_activation==5) THEN
	GBC_method = 5
	gov_exp = 0.044
END IF  

888 continue 

count = 0
DO JTS=17,17
	DO JTM=17,17
		
		tau_l_single = (JTS+0.0)/100.0
		tau_l_couple = (JTM+0.0)/100.0
		
		IF (optimal_tax == 0) THEN 	
		! Benchmark				
			! tau_l_single =  0.026
			! tau_l_couple = 0.043

			! tau_l_single =  0.03749881
			! tau_l_couple =  0.03749881

			tau_l_single =  0.07
			tau_l_couple =  0.07
		END IF 	

	
		BEQ = BEQ0
		R_ANNUAL =  0.051		! 0.041 Initial guess of interest rate
		R = (1+R_ANNUAL)**5.00-1.00
		R1 = (1+Rmin)**5.0-1.0
		R2 = (1+Rmax)**5.0-1.0
		! R1 = (1+Rmin)**5.0-1.0
		! R2 = (1+Rmax)**5.0-1.0
		

!*******************************
!
! 	General Equilibrium
!
!*******************************
LOOPNUMBER = 0
KDEV = 1.0  
WAGE = 1.0  ! Initial guess of wage
avg_earnings = 1.0	! benchmark avg earnings
OUTPUT = 40.0		! benchmark output
count = count + 1

DO WHILE ( KDEV > TOLK)

BEQ     = BEQ0
gov_trans = 0.031737692936344
medicare =	3.0414554907342812	! 0.0
!SS      = SS0	  
! avg_earnings = 1.8489	! Guess from my "determinant...." calibration

incsscap = incsscap_2000/(avg_monthly_earnings2000) 	

lambda1 = lambdamin
lambda2 = lambdamax
lambda = 0.5*lambda1 + 0.5*lambda2
dlam = 1.0

! tau_s1 = tau_s_min
! tau_s2 = tau_s_max
! tau_s = 0.5*tau_s1 + 0.5*tau_s2
tau_s = 0.05	!0.05	!initial guess of tau_s
REPLACE = 0.1011114
dtau_s = 1.0
premium_rate = 0.16682987	!0.01906851	!initial guess 

PIA_factor = 0.0	! 0.57 match the target SS/Y
dPIA = 0.0	
dREPLACE = 1.0


! !   Tabulate AIME
! EHMAX	= EHMAX_2000*avg_earnings
! ALLOCATE( EH(NGRIDEH) )    ! discretize earning history state-variable
! !EH = (/ ( 0.0 + (EHMAX-0.0)*((FLOAT(IE-1)/FLOAT(NGRIDEH-1))**1.000), IE=1,NGRIDEH ) /)
!  EH = (/ ( EHMAX*((FLOAT(IE-1))/FLOAT(NGRIDEH-1)**1.000), IE=1,NGRIDEH ) /)

!*********************
!
!   Iterate to Convergence
!
!*********************

    ITER = 1
	LOOPNUMBER = LOOPNUMBER +1

    WRITE(10,*) 'ITERATION RESULTS'
    WRITE(10,*)
200 ITERINC = 0

! IF (optimal_tax == 0) THEN 
! 	lambda = 0.841
! 	lambda_couple = 0.884
! ELSEIF (optimal_tax == 1) THEN 
! 	IF (GBC_method==0) THEN 
! 		lambda_couple = lambda*delta_lambda
! 	ELSEIF ((GBC_method==1) .OR. (GBC_method==2)) THEN 
! 		lambda = 0.841
! 		lambda_couple = 0.884
! 	END IF 
! END IF 
IF (GBC_method==0) THEN 
	lambda_couple = lambda*delta_lambda
ELSE
	lambda = 0.9
	lambda_couple = 0.9

	! lambda = 0.915
	! lambda_couple = 0.91
! Guner et al 2012
	! lambda = 0.841
	! lambda_couple = 0.884
! Krueger et al 2019
	! lambda = 0.8177
	! lambda_couple = 0.9420
END IF 

! Compute income bend point for top marginal tax rate given lambda:

IF (ty_max_restriction == 1) THEN 
	IF (tau_l_single>0.0) THEN 
		! singlebendy=((1.0-tau_l_single)*lambda/(1.0-ty_max))**(1.0/tau_l_single)	!bendy = y/AE
		! MFSbendy=((1.0-tau_l_couple)*lambda_couple/(1.0-ty_max))**(1.0/tau_l_couple) 

		singlebendy=bendy
		MFSbendy=bendy
	ELSE
		singlebendy= 1.E7
		MFSbendy= 1.E7
	END IF 

	IF (tau_l_couple>0.0) THEN 
		! couplebendy=((1.0-tau_l_couple)*(lambda_couple)/(1.0-ty_max))**(1.0/tau_l_couple)  		  
		couplebendy=bendy                                                                                                          
	ELSE 
		couplebendy=1.E7
	END IF
ELSEIF (ty_max_restriction == 0) THEN 
	singlebendy= 1.E7
	couplebendy=1.E7
	MFSbendy= 1.E7
END IF

print*,''
IF (GBC_method == 0) THEN 
	print*, ' =================New iteration on lambda================='
ELSEIF (GBC_method == 2) THEN 
	! print*, ' ====tau_s',tau_s,'','tau_single',tau_l_single,'','tau_MFJ',tau_l_couple,'','count',count,'===='
	print*, ' =================New iteration on tau_s================='
	print*,'tau_s',tau_s
	print*,'tau_single',tau_l_single
	print*,'tau_MFJ',tau_l_couple
	print*,'count',count
	print*, ' ========================================================'
END IF 

print*, 'singlebendy=',singlebendy
print*, 'couplebendy=',couplebendy
print*, 'MFSbendy=', MFSbendy

!   Update Tabulation of AIME
EHMAX	= EHMAX_2000*avg_earnings	! avg_earnings is updated every iteration
ALLOCATE( EH(NGRIDEH) )    ! discretize earning history state-variable
EH = (/ ( EHMAX*((FLOAT(IE-1))/FLOAT(NGRIDEH-1)**1.000), IE=1,NGRIDEH ) /)
print*, ' EHMAX=', EHMAX
print*, 'PIA factor=', PIA_factor
print*, ' incsscap=', incsscap*avg_earnings
print*, 'SS(EHMAX)=', SS(NGRIDEH)
print*, 'AIME'
WRITE(*,"(3(F10.5))") EH(:)
PRINT *, '  PIA benefit '
WRITE(*,"(3(F10.5))") SS(1),SS(2),SS(3),SS(4),SS(5),SS(6),SS(7),SS(8),SS(9),SS(10)
OPEN(UNIT=27,FILE='SS.txt')
	write(27,*)  SS(1),SS(2),SS(3),SS(4),SS(5),SS(6),SS(7),SS(8),SS(9),SS(10)
CLOSE(27)

!   Main Calculations

!******************************************************************************************************************************  
!	Compute the value function of the retired single person for all time periods after
!	retirement, doing the usual backward iteration starting from the last period.
call cpu_time (fstart)
ostart = omp_get_wtime()

print*, 'CALL DECRULE01 begin'
!   Find decision rules for all ages and states
	
	ALLOCATE( singleIDCWA(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleIDCWA(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) ) 
    ALLOCATE( singleIDCWN(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleIDCWN(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2)  )
    ALLOCATE( singleIDCRA(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2), coupleIDCRA(RETAGE:MAXAGE,NGRIDA,NGRIDEH) )
    ALLOCATE( singleIDCRN(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2), coupleIDCRN(RETAGE:MAXAGE,NGRIDA,NGRIDEH) )
    ALLOCATE( singleVW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleVW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH), marriageVW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( singleVR(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2), coupleVR(RETAGE:MAXAGE,NGRIDA,NGRIDEH), marriageVR(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )

	ALLOCATE(read_vector_single_N((RETAGE-1)*NGRIDA*nn*NGRIDEH*2))
	OPEN(UNIT=27,FILE='singleIDCWN.txt')
		READ(27,*) read_vector_single_N
	CLOSE(27)
	singleIDCWN = reshape(read_vector_single_N, (/ RETAGE-1, NGRIDA, nn,  NGRIDEH, 2/))	
	print*, "importing benchmark singleIDCWN"

	ALLOCATE(read_vector_couple_N((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH*2))
	OPEN(UNIT=27,FILE='coupleIDCWN.txt')
		READ(27,*) read_vector_couple_N
	CLOSE(27)
	coupleIDCWN = reshape(read_vector_couple_N, (/ RETAGE-1, NGRIDA, nn, nn,  NGRIDEH, 2/))	
	print*, "importing benchmark coupleIDCWN"

	DEALLOCATE(read_vector_single_N)
	DEALLOCATE(read_vector_couple_N)

    CALL DECRULE01       

call cpu_time (fend)                    
oend = omp_get_wtime()     
write(*,*) 'Time for solving policy functions', oend-ostart    
print*, 'CALL DECRULE01 end'     

!***************************************************************************************************************************************************************************************************
! OPEN(UNIT=19,FILE='single_policy.txt')
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA       
!     	DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 			  	DO IG=1,2
			
! 					WRITE(19,"(143(F16.8,1X))") real(AGE), real(IA), real(IS), real(IE), real(IG), real(singleIDCWA(AGE,IA,IS,IE,IG)), real(singleIDCWN(AGE,IA,IS,IE,IG))
					
! 				END DO 
! 			END DO
! 		END DO
! 	END DO
! END DO

! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA       
! 		DO IE=1,NGRIDEH
! 			DO IG=1,2
			
! 				WRITE(19,"(143(F16.8,1X))") real(AGE), real(IA), real(IE), real(IG), real(singleIDCRA(AGE,IA,IE,IG)), real(singleIDCRN(AGE,IA,IE,IG))
				
! 			END DO
! 		END DO
! 	END DO
! END DO
! CLOSE(UNIT=19) 
 				

! OPEN(UNIT=17,FILE='couple_policy.txt')
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA       
!     	DO IS1=1,nn
! 			DO IS2=1,nn
! 				DO IE=1,NGRIDEH
			  	
! 					WRITE(17,"(143(F16.8,1X))") real(AGE), real(IA), real(IS1), real(IS2), real(IE), real(coupleIDCWA(AGE,IA,IS1,IS2,IE)), real(coupleIDCWN(AGE,IA,IS1,IS2,IE,1)), real(coupleIDCWN(AGE,IA,IS1,IS2,IE,2))
					
! 				END DO 
! 			END DO
! 		END DO
! 	END DO
! END DO

! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA       
! 		DO IE=1,NGRIDEH
			
! 			WRITE(17,"(143(F16.8,1X))") real(AGE), real(IA),  real(IE), real(coupleIDCRA(AGE,IA,IE)), real(coupleIDCRN(AGE,IA,IE)), real(coupleIDCRN(AGE,IA,IE))
			  	
! 		END DO
! 	END DO
! END DO
! CLOSE(UNIT=17) 
!*************************************************************************************************************************************************************************************************** 

! Aggtincome=10.2657
! AGE=6
! IA = 20
! IS1 = 4
! IS2 = 1
! IE = 3
! JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
! JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
! ! Joint filing
! taxableincome = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) 
! jointfiling_tax = taxpayment(taxableincome,IA,tau_l_couple)
! print*, 'jointfiling_tax=', jointfiling_tax
! ! Separate filing
! separatefiling_tax = taxpayment(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1), IA, tau_l_single) + taxpayment(WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2), IA, tau_l_single)
					 
! print*, 'separatefiling_tax=',separatefiling_tax				



print*, 'CALL INVAR01 begin'
!   Find invariant distribution

    !ALLOCATE ( YW(1:RETAGE-1,NGRIDA,NGRIDH,nn), YR(RETAGE:MAXAGE,NGRIDA,NGRIDH) )
	ALLOCATE( singleYW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleYW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
	ALLOCATE( singleYR(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2), coupleYR(RETAGE:MAXAGE,NGRIDA,NGRIDEH) )

    CALL INVAR01

	! print*,'married household share', (sum(coupleYW(:,:,:,:,:))+sum(coupleYR(:,:,:)))/(sum(singleYW(:,:,:,:,:))+sum(singleYR(:,:,:,:))+sum(coupleYW(:,:,:,:,:))+sum(coupleYR(:,:,:)))
!***************************************************************************************************************************************************************************************************
! OPEN(UNIT=16,FILE='single_dist.txt')
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA       
!     	DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 			  	DO IG=1,2
			
! 					WRITE(16,*) real(AGE), real(IA), real(IS), real(IE), real(IG), singleYW(AGE,IA,IS,IE,IG)	!WRITE(16,"(143(F16.8,1X))")

! 				END DO 
! 			END DO
! 		END DO
! 	END DO
! END DO

! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA       
! 		DO IE=1,NGRIDEH
! 			DO IG=1,2
			
! 				WRITE(16,*) real(AGE), real(IA), real(IE), real(IG), singleYR(AGE,IA,IE,IG)

! 			END DO
! 		END DO
! 	END DO
! END DO
! CLOSE(UNIT=16) 


! OPEN(UNIT=15,FILE='couple_dist.txt')
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA       
!     	DO IS1=1,nn
! 			DO IS2=1,nn
! 				DO IE=1,NGRIDEH
			  	
! 					WRITE(15,*) real(AGE), real(IA), real(IS1), real(IS2), real(IE), coupleYW(AGE,IA,IS1,IS2,IE)

! 				END DO 
! 			END DO
! 		END DO
! 	END DO
! END DO

! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA       
! 		DO IE=1,NGRIDEH
			
! 			WRITE(15,*) real(AGE), real(IA),  real(IE), coupleYR(AGE,IA,IE)

! 		END DO
! 	END DO
! END DO
! CLOSE(UNIT=15) 
!***************************************************************************************************************************************************************************************************
print*, 'CALL INVAR01 end'  

! single_male_welfare = SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1))/SUM(singleYW(:,:,:,:,1))
! single_female_welfare = SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2))/SUM(singleYW(:,:,:,:,2))
! total_couple_welfare = SUM(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:))/SUM(coupleYW(:,:,:,:,:))

! ! single_male_welfare = SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleVR(RETAGE:MAXAGE,:,:,1)*singleYR(RETAGE:MAXAGE,:,:,1))
! ! single_female_welfare = SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleVR(RETAGE:MAXAGE,:,:,2)*singleYR(RETAGE:MAXAGE,:,:,2))
! ! total_couple_welfare = SUM(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + SUM(coupleVR(RETAGE:MAXAGE,:,:)*coupleYR(RETAGE:MAXAGE,:,:))

! single_male_welfare =  (SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleVR(RETAGE:MAXAGE,:,:,1)*singleYR(RETAGE:MAXAGE,:,:,1)))/(SUM(singleYW(:,:,:,:,1))+SUM(singleYR(RETAGE:MAXAGE,:,:,1)))
! single_female_welfare = (SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleVR(RETAGE:MAXAGE,:,:,2)*singleYR(RETAGE:MAXAGE,:,:,2)))/(SUM(singleYW(:,:,:,:,2))+SUM(singleYR(RETAGE:MAXAGE,:,:,2)))
! total_couple_welfare =( SUM(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + SUM(coupleVR(RETAGE:MAXAGE,:,:)*coupleYR(RETAGE:MAXAGE,:,:)))/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:)))

! write(*,"(11(A8,1X))") 'M_welfare', 'F_welfare', 'C_welfare'
! write(*,"(11(F8.5,1X))") single_male_welfare, single_female_welfare, total_couple_welfare

    ! WRITE(10,*)'welfare is ', sum( YW(1,1,1,1:nn) * VW(1,1,1,1:nn) ) 	! written by He Hui
    
    !DO AGE=1,RETAGE-1
    !    DO IA=1,NGRIDA
    !        DO IH=1,NGRIDH
    !            DO IS=1,nn
    !                IF ((IDCWA(AGE,IA,IH,IS)>=NGRIDA).AND.(YW(AGE,IA,IH,IS)>0)) THEN
    !                    PRINT *, 'Error:  Maximum asset limit is binding.'
    !                    PRINT *, 'AGE =', AGE
    !                    PRINT *, 'IA =', IA
				!        PRINT *, 'IH =', IH
    !                    PRINT *, 'IS =', IS
				!        WRITE(10,*), 'Error:  Maximum asset limit is binding.'
    !                    WRITE(10,*) 'AGE =', AGE
    !                    WRITE(10,*) 'IA =', IA
				!        WRITE(10,*) 'IH =', IH
    !                    WRITE(10,*) 'IS =', IS
    !                    GO TO 999
    !                ELSEIF ((IDCWM(AGE,IA,IH,IS)>=NGRIDA).AND.(YW(AGE,IA,IH,IS)>0)) THEN
    !                    PRINT *, 'Error:  Maximum med expenditure limit is binding.'
    !                    PRINT *, 'AGE =', AGE
    !                    PRINT *, 'IA =', IA
			 !           PRINT *, 'IH =', IH
    !                    PRINT *, 'IS =', IS
			 !           WRITE(10,*), 'Error:  Maximum med expenditure limit is binding.'
    !                    WRITE(10,*) 'AGE =', AGE
    !                    WRITE(10,*) 'IA =', IA
			 !           WRITE(10,*) 'IH =', IH
    !                    WRITE(10,*) 'IS =', IS
    !                    GO TO 999
    !                END IF
    !            END DO
    !        END DO
    !    END DO
    !END DO
    !DO AGE=RETAGE,MAXAGE
    !    DO IA=1,NGRIDA
    !        DO IH=1,NGRIDH
    !            IF ((IDCRA(AGE,IA,IH)>=NGRIDA).AND.(YR(AGE,IA,IH)>0)) THEN
    !                PRINT *, 'Error:  Maximum asset limit is binding.'
    !                PRINT *, 'AGE =', AGE
    !                PRINT *, 'IA =', IA
				!    PRINT *, 'IH =', IH
				!    WRITE(10,*), 'Error:  Maximum asset limit is binding.'
    !                WRITE(10,*) 'AGE =', AGE
    !                WRITE(10,*) 'IA =', IA
				!    WRITE(10,*) 'IH =', IH
    !                GO TO 999
    !            ELSEIF ((IDCRM(AGE,IA,IH)>=NGRIDA).AND.(YR(AGE,IA,IH)>0)) THEN
    !                PRINT *, 'Error:  Maximum med expenditure limit is binding.'
    !                PRINT *, 'AGE =', AGE
    !                PRINT *, 'IA =', IA
			 !       PRINT *, 'IH =', IH
			 !       WRITE(10,*), 'Error:  Maximum med expenditure limit is binding.'
    !                WRITE(10,*) 'AGE =', AGE
    !                WRITE(10,*) 'IA =', IA
			 !       WRITE(10,*) 'IH =', IH
    !                GO TO 999
    !            END IF
    !        END DO
    !    END DO
    !END DO

print*, 'CALL PROFILE01 begin'    
!   Compute age profiles

!    ALLOCATE ( ALONG(MAXAGE), CLONG(MAXAGE), ILONG(MAXAGE), TILONG(MAXAGE), HLONG(MAXAGE) )
!    ALLOCATE ( MLONG(MAXAGE), NLONG(MAXAGE), LLONG(MAXAGE), SICKLONG(RETAGE-1) )
!    ALLOCATE ( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE), HCROSS(MAXAGE), MCROSS(MAXAGE), NCROSS(MAXAGE), LCROSS(MAXAGE))
	 ALLOCATE( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE),  NCROSS(MAXAGE), LCROSS(MAXAGE))
!    ALLOCATE ( HLONGNEXT(MAXAGE) )
	
	 ALLOCATE( ALONG(MAXAGE), CLONG(MAXAGE), ILONG(MAXAGE), TILONG(MAXAGE) )
     ALLOCATE(  NLONG(MAXAGE), LLONG_single(MAXAGE,2), LLONG_couple(MAXAGE,2) )
    ! ALLOCATE ( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE), NCROSS(MAXAGE), LCROSS(MAXAGE))
   
    CALL PROFILE01
print*, 'CALL PROFILE01 end'
!********************************************************Not applicable to this paper**************************************************************************************************
! ! Compute the age sgares and sur. prob.

! 	ALLOCATE(S(MAXAGE,2))

! 	DO AGE=1,MAXAGE
! 		DO IG=1,2
! 	   	 !S(AGE) = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)+c3*HLONG(AGE)))               ! quadratic form of sur. prob. as a fn of age
! 	  	 S(AGE,IG) = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))   
! 	  	 !S(AGE) = 1.00-exp(-(HLONG(AGE)/SURV1)**SURV2)
! 	 	 !S(AGE) = 1/(1+EXP(c0+c2*AGE-c3*HLONG(AGE)))
! 	    END DO 
!     END DO 
! 		S(MAXAGE,:) = 0.0

! !  Unconditional survival probabilities

!     ALLOCATE( CUMS(MAXAGE), MU(MAXAGE) )

!     CUMS(1) = 1.000
!     DO J=2,MAXAGE
!         CUMS(J) = CUMS(J-1)*S(J-1)
!     END DO

! !  Age distribution of total population

!     CUM = 0.0
!     DO AGE=1,MAXAGE
!         CUM = CUM + CUMS(AGE)/((1.0+POPG)**(AGE-1))
!     END DO

!     MU(1) = 1.0/CUM
! 	SUM1=MU(1)
!     DO AGE=2,MAXAGE
!         MU(AGE) = S(AGE-1)*MU(AGE-1)/(1.0+POPG)
! 	    SUM1 = SUM1 + MU(AGE)
!     END DO
! !	Check the sum of age share is equal to one
! 	IF (ABS(SUM1-1.000000)>0.000001) THEN
!         PRINT*, 'The sum of age share for the total population is not equal to one at age!'
! !		GO TO 999
! 	END IF	

! !  Age distribution of working age population

! !799 ALLOCATE ( CUMSWK(RETAGE-1), MUWK(RETAGE-1) )
! 	ALLOCATE ( CUMSWK(RETAGE-1), MUWK(RETAGE-1) )

!     CUMSWK(1) = 1.000
!     DO J=2,RETAGE-1
!         CUMSWK(J) = CUMSWK(J-1)*S(J-1)
!     END DO
   
    
!     CUMWK = 0.0
!     DO AGE=1,RETAGE-1
!         CUMWK = CUMWK + CUMSWK(AGE)/((1.0+POPG)**(AGE-1))
!     END DO
   
    
!     MUWK(1) = 1.0/CUMWK
! 	SUMWK   = MUWK(1)
!     DO AGE=2,RETAGE-1
!         MUWK(AGE) = S(AGE-1)*MUWK(AGE-1)/(1.0+POPG)
! 	    SUMWK = SUMWK + MUWK(AGE)
!     END DO
   
    
! !	Check the sum of age share is equal to one
! 	IF (ABS(SUMWK-1.000000)>0.000001) THEN
!         PRINT*, 'The sum of age share for working age population is not equal to one at age!'
! !		GO TO 999
! 	END IF		

! !   	Compute average end-of-period assets, labor supply, bequests and SS tax rate
!     ALLOCATE ( Y_AGE(MAXAGE) ) 
	 
! 	CUM    = 0.0
! 	AEND   = 0.0
! 	LEND   = 0.0
! 	LSSEND = 0.0
!     BEQEND = 0.0  ! Agg Bequest
! 	MEDW   = 0.0
! 	MEDR   = 0.0
! 	ALIVE  = 0.0
	
	
! 	DO AGE=1,RETAGE-1
! 		Y_AGE(AGE)=0.0 
! 		DO IA=1,NGRIDA
! 			DO IR=1,NGRIDR
! 				DO IS=1,nn
					
! 					Y_AGE(AGE) = Y_AGE(AGE) + YW(AGE,IA,IR,IS)
					
! 				END DO
! 			END DO
! 		END DO
! 	END	DO
	
		
! 	DO AGE=RETAGE,MAXAGE
! 		Y_AGE(AGE)=0.0	
! 		DO IA=1,NGRIDA
! 			DO IR=1,NGRIDR	
				
! 				Y_AGE(AGE) = Y_AGE(AGE) + YR(AGE,IA,IR)				
				
! 			END DO
! 		END DO
! 	END	DO
	
!     CUM1  = 0.00
!     DO AGE=1,RETAGE-1
! 	    CUM1   = CUM1   + MU(AGE)
!         AEND   = AEND   + ACROSS(AGE)*MU(AGE)
! 	!    LEND   = LEND   + EFFCROSS(AGE)*NCROSS(AGE)*MU(AGE)
! 		LEND   = LEND   + EFFCROSS(AGE)*NCROSS(AGE)*MUWK(AGE)
! 	    LSSEND = LSSEND + EFFCROSS(AGE)*NCROSS(AGE)
!         BEQEND = BEQEND + ACROSS(AGE)*MU(AGE)*(1.0-S(AGE))
		
! !	    MEDW   = MEDW   + MCROSS(AGE)*MU(AGE)
! 		!ALIVE  = ALIVE  + MU(AGE)*Y_AGE(AGE)*S(AGE)
!     END DO

!     CUM2 = 0.0
!     DO AGE=RETAGE,MAXAGE                        
!         CUM2   = CUM2   + MU(AGE)		
! 	    AEND   = AEND   + ACROSS(AGE)*MU(AGE)
!         BEQEND = BEQEND + ACROSS(AGE)*MU(AGE)*(1.0-S(AGE))
		
! !	    MEDR   = MEDR   + MCROSS(AGE)*MU(AGE)
! 		!ALIVE  = ALIVE  + MU(AGE)*Y_AGE(AGE)*S(AGE)
!     END DO
!******************************************************************************************************************************************************************
print*, 'Aggregation begin'
! Aggregation

Agg_labor = 0.0
Avg_hour = 0.0
Agg_asset = 0.0
Agg_beq = 0.0
working_population = SUM(singleYW(1:RETAGE-1,:,:,:,:))+2*SUM(coupleYW(1:RETAGE-1,:,:,:,:))
retire_population = SUM(singleYR(RETAGE:MAXAGE,:,:,:))+2*SUM(coupleYR(RETAGE:MAXAGE,:,:))
whole_population = working_population + SUM(singleYR(RETAGE:MAXAGE,:,:,:))+2*SUM(coupleYR(RETAGE:MAXAGE,:,:))

print*,'working_population',working_population
print*,'retire_population',retire_population
print*,'old/young',retire_population/working_population
print*,'whole_population',whole_population

! Working-age "single" agents
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG=1,2                   
				  
				JN = singleIDCWN(AGE,IA,IS,IE,IG)   

				Agg_asset = Agg_asset + A(IA)*singleYW(AGE,IA,IS,IE,IG) !/working_population
				Agg_beq = Agg_beq + A(IA)*singleYW(AGE,IA,IS,IE,IG)*(1.0-S(AGE,IG)) !/working_population				
                Agg_labor = Agg_labor + EFFLONG(AGE,IG)*N(JN)*W(IS,IG)*singleYW(AGE,IA,IS,IE,IG) !/working_population
				Avg_hour = Avg_hour + N(JN)*singleYW(AGE,IA,IS,IE,IG)/working_population

				END DO 
            END DO
        END DO 
    END DO
END DO

!  Working-age "couple" agents
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH

				JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
				JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

				Agg_asset = Agg_asset + A(IA)*coupleYW(AGE,IA,IS1,IS2,IE) 
				Agg_beq = Agg_beq + A(IA)*coupleYW(AGE,IA,IS,IE,IG)*(1.0-S(AGE,1))*(1.0-S(AGE,2)) !/working_population
				Agg_labor = Agg_labor + (EFFLONG(AGE,1)*W(IS1,1)*N(JN1) +EFFLONG(AGE,2)*W(IS2,2)*N(JN2))*coupleYW(AGE,IA,IS1,IS2,IE)  !/working_population
				! Avg_hour = Avg_hour + ((N(JN1) + N(JN2))/2.0)*coupleYW(AGE,IA,IS1,IS2,IE)/working_population		! Avg hour within couple
				Avg_hour = Avg_hour + (N(JN1) + N(JN2))*coupleYW(AGE,IA,IS1,IS2,IE)/working_population

				END DO 
            END DO
        END DO 
    END DO
END DO

!  Single Retirees  
DO AGE=RETAGE,MAXAGE        
	DO IA=1,NGRIDA
        DO IE=1,NGRIDEH
			DO IG=1,2

			 Agg_asset = Agg_asset + A(IA)*singleYR(AGE,IA,IE,IG)
			 Agg_beq = Agg_beq + A(IA)*singleYR(AGE,IA,IE,IG)*(1.0-S(AGE,IG))

			END DO 
        END DO
    END DO
END DO

!  Couple Retirees    
DO AGE=RETAGE,MAXAGE                      
    DO IA=1,NGRIDA
        DO IE=1,NGRIDEH

		 Agg_asset = Agg_asset + A(IA)*coupleYR(AGE,IA,IE)
		 Agg_beq = Agg_beq + A(IA)*coupleYR(AGE,IA,IE)*(1.0-S(AGE,1))*(1.0-S(AGE,2))

		END DO
    END DO
END DO


PRINT*, 'K=', Agg_asset
PRINT*, 'L=', Agg_labor
PRINT*, 'Hour=', Avg_hour
PRINT*, 'AGG_BEQ=', Agg_beq

print*, 'Aggregation end'	


!	Output

	! K = AEND/(1.0+AGROWTH)      ! Detrend
	! L = LEND
	OUTPUT = TFP*(Agg_asset**ALPHA)*(Agg_labor**(1-ALPHA))
	! MPL = (1-ALPHA)*TFP*(K/L)**ALPHA
	! MPK = (ALPHA)*TFP*(K/L)**(ALPHA-1)

!***********************************************Should updated after the GBC*****************************************************************************	
 
! BEQ1 = Agg_beq/(working_population*(1.0+AGROWTH))

! ! Average earnings (to update EHMAX)
! avg_earnings = 0.0
! !working_population = SUM(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)))
! DO AGE=1,RETAGE-1
! 	DO IA=1,NGRIDA
!         DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2                   
                			   
! 				JN = singleIDCWN(AGE,IA,IS,IE,IG)  
! 				INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) 	
! 				!TINCOME	= R*A(IA) + INCOME 			
!                 avg_earnings = avg_earnings + INCOME*singleYW(AGE,IA,IS,IE,IG)/working_population

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO

! DO AGE=1,RETAGE-1
! 	DO IA=1,NGRIDA
!         DO IS1=1,nn
! 			DO IS2=1,nn
! 				DO IE=1,NGRIDEH

! 				JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
! 				JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
! 				INCOME = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)
! 				!TINCOME	= R*A(IA) + INCOME 
! 				avg_earnings = avg_earnings + INCOME*coupleYW(AGE,IA,IS1,IS2,IE)/working_population

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO
!***************************************************************************************************************************************

!	Update SS benifits and SS tax rate

SSEXP=0.0 	! SS expenditure
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IE = 1,NGRIDEH
			
			SSEXP = SSEXP + SS(IE)*(singleYR(AGE,IA,IE,1)+singleYR(AGE,IA,IE,2)+2*coupleYR(AGE,IA,IE))			
			! SSEXP = SSEXP + (SS(IE)/PIA_factor)*(singleYR(AGE,IA,IE,1)+singleYR(AGE,IA,IE,2)+2*coupleYR(AGE,IA,IE))

		END DO 
	END DO 
END DO 

! ! SS expense neutral
! AggEH = SSEXP/REPLACE
! REPLACE = 0.036*OUTPUT/AggEH
! print*,'REPLACE updated', REPLACE


!	SS1  = REPLACE*WAGE*LSSEND/FLOAT(RETAGE-1) 	
!   STAX1= SS1*CUM2/(WAGE*LEND)

!	Update govern flat transfer
	gov_trans = flat_transf_rate*OUTPUT/whole_population
	print*,'gov_trans per person=', gov_trans 
! Update total sum of expenditure and transfers of 17% of GDP
	! gov_exp = 0.17*OUTPUT

!  Update medicare (only for elderly)
	medicare = medicare_rate*OUTPUT/(whole_population-working_population)
	! medicare = medicare_rate*OUTPUT/SUM(D_YR(RETAGE:MAXAGE,:,:,:))
	print*,'medicare_rate*OUTPUT=', medicare_rate*OUTPUT
	print*,'CUM2', whole_population-working_population
	print*,'medicare per person=', medicare 


! Compute income bend point for top marginal tax rate given lambda:
!	bendy=((1.0-tau_l)*lambda/(1.0-ty_max))**(1.0/tau_l)

gbcdenom = 0.0
gbcnum = 0.0
income_tax_revenue_single = 0.0
income_tax_revenue_couple = 0.0
cor_tax_rev = 0.0
sales_tax_rev = 0.0
insurance_premium = 0.0
tax_subsidy = 0.0
agg_c = 0.0
agg_yd = 0.0
agg_y = 0.0
tax_revenue_single = 0.0
tax_revenue_couple = 0.0

! Single
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG=1,2		
			 
		  	JN = singleIDCWN(AGE,IA,IS,IE,IG)
			JA = singleIDCWA(AGE,IA,IS,IE,IG)

			INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
			TINCOME = R*A(IA) + INCOME
			PREMIUM = premium_rate*INCOME
			taxable_income = max(0.0,min(R*A(IA),d_c)) + INCOME

			yd = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings)*lambda*(MIN(singlebendy, taxable_income/avg_earnings))**(-tau_l_single) &
				+avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy) &
				+(1-tau_c)*max(R*A(IA)-d_c,0.0)
			
			agg_yd = agg_yd + yd*singleYW(AGE,IA,IS,IE,IG)

! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
			IF(GBC_method==0) THEN 			!cleared by lambda			
				temp = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings)*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single)
			ELSE	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
				temp = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings)*lambda*(MIN(singlebendy, taxable_income/avg_earnings))**(-tau_l_single)
			END IF 
				gbcdenom = gbcdenom + temp*singleYW(AGE,IA,IS,IE,IG)	! *MU(AGE)

! gbcnum = other tax revenue + Taxable income - top aftertax income
			temp2 = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings) & 
					+ avg_earnings*ty_max*MAX(0.0, taxable_income/avg_earnings - singlebendy) 
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			temp_cons = ( (avg_earnings*MIN(singlebendy, taxable_income/avg_earnings)*lambda*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) &
						+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy) ) &
						+ (1-tau_c)*max(R*A(IA)-d_c,0.0) &
						+  BEQ1*(1.0+GROWTH)**(AGE-1) + A(IA) + gov_trans - A(JA) - PREMIUM)/(1.0+tau_s) 
			temp_staxrev = tau_s*temp_cons
			
			!T + taxable income - top aftertax income
			IF(GBC_method==2) THEN
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + PREMIUM)*singleYW(AGE,IA,IS,IE,IG) 
			ELSEIF (GBC_method==4) THEN 
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*singleYW(AGE,IA,IS,IE,IG)
			ELSE
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYW(AGE,IA,IS,IE,IG) !*MU(AGE)
			END IF 

!	cor_tax_rev = cor_tax_rev+temp_ctaxrev*YW(AGE,IA,IR,IS)*MU(AGE)
			sales_tax_rev = sales_tax_rev + temp_staxrev*singleYW(AGE,IA,IS,IE,IG)	!*MU(AGE)
			agg_c = agg_c + temp_cons*singleYW(AGE,IA,IS,IE,IG)
			agg_y = agg_y + INCOME*singleYW(AGE,IA,IS,IE,IG)
			insurance_premium = insurance_premium + PREMIUM*singleYW(AGE,IA,IS,IE,IG)
			
! negative tax (subsidy) treated as gov exp
			! tax_subsidy = tax_subsidy + ABS( MIN(TINCOME - yd, 0.0) )*singleYW(AGE,IA,IS,IE,IG)

! share of tax revenue from single
			! tax_revenue_single = tax_revenue_single + (TINCOME-yd)*singleYW(AGE,IA,IS,IE,IG)
		IF(GBC_method==0) THEN 	
			tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYW(AGE,IA,IS,IE,IG) - lambda*temp*singleYW(AGE,IA,IS,IE,IG)
			income_tax_revenue_single = income_tax_revenue_single + (temp2 - lambda*temp)*singleYW(AGE,IA,IS,IE,IG)
		ELSE
			tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYW(AGE,IA,IS,IE,IG) - temp*singleYW(AGE,IA,IS,IE,IG)
			income_tax_revenue_single = income_tax_revenue_single + (temp2 - temp)*singleYW(AGE,IA,IS,IE,IG)
		END IF  

				END DO
			END DO
        END DO 
    END DO
END DO


! couple
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH
						
			JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)  
		  	JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
			JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

			INCOME = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)
			INCOME1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + min(R*A(IA),d_c)/2
			INCOME2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)/2
			PREMIUM = premium_rate*(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))
			PREMIUM1 = premium_rate*WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)	
			PREMIUM2 = premium_rate*WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)
			tax_MFS = INCOME1+INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA))			
			taxable_income = max(0.0,min(R*A(IA),d_c))+ WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)

! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
		IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
			IF(GBC_method==0) THEN  		!cleared by lambda	
				temp = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings)*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple)
			ELSE 	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
				temp = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings)*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple)						
			END IF

		ELSE 
			! IF (tau_l_single>0.0) THEN 
			! 	MFSbendy=((1.0-tau_l_single)*lambda*weight_MFS/(1.0-ty_max))**(1.0/tau_l_single) 
			! ELSE 
			! 	MFSbendy=1.E7 
			! END IF

			IF(GBC_method==0) THEN 
				! temp = weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1))*( MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) )/avg_earnings ))**(-tau_l_single) &
				! 		+ (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/avg_earnings ))**(-tau_l_single) )

				temp = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) + avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)
			ELSE
				! temp = lambda*weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1))/avg_earnings ))**(-tau_l_single) &
				! 	  + (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/avg_earnings ))**(-tau_l_single) )
				temp = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) + avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)
			END IF  

		END IF 	
			gbcdenom = gbcdenom + temp*coupleYW(AGE,IA,IS1,IS2,IE)	! *MU(AGE)

! gbcnum = other tax revenue + Taxable income - top aftertax income
		IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
			temp2 = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings) & 
					+ avg_earnings*ty_max*MAX(0.0, taxable_income/avg_earnings - couplebendy)  
					
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			yd = yd_MFJ(INCOME1 + INCOME2,IA)

			temp_cons = ( (avg_earnings*MIN(couplebendy, taxable_income/avg_earnings)*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
						+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - couplebendy)) &
						+ (1-tau_c)*max(R*A(IA)-d_c,0.0) &
						+  2*BEQ1*(1.0+GROWTH)**(AGE-1) + A(IA) + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)
			temp_staxrev = tau_s*temp_cons
		ELSE
			! IF (tau_l_single>0.0) THEN 
			! 	MFSbendy=((1.0-tau_l_single)*lambda*weight_MFS/(1.0-ty_max))**(1.0/tau_l_single) 
			! ELSE 
			! 	MFSbendy=1.E7 
			! END IF 
			temp2 = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings) + avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings) & 
					+ avg_earnings*ty_max*MAX(0.0, INCOME1/avg_earnings - MFSbendy) &
					+ avg_earnings*ty_max*MAX(0.0, INCOME2/avg_earnings - MFSbendy) 
					
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			yd = yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA)

			temp_cons = ( yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA) &
						+  2*BEQ1*(1.0+GROWTH)**(AGE-1) + A(IA) + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s) 
			temp_staxrev = tau_s*temp_cons
		END IF 	

			!T + taxable income - top aftertax income
			IF(GBC_method==2) THEN
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + PREMIUM)*coupleYW(AGE,IA,IS1,IS2,IE) !*MU(AGE)
			ELSEIF (GBC_method==4) THEN
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*coupleYW(AGE,IA,IS1,IS2,IE)
			ELSE 
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYW(AGE,IA,IS1,IS2,IE) !*MU(AGE)
			END IF

		!	cor_tax_rev = cor_tax_rev+temp_ctaxrev*YW(AGE,IA,IR,IS)*MU(AGE)
			sales_tax_rev = sales_tax_rev + temp_staxrev*coupleYW(AGE,IA,IS1,IS2,IE)	!*MU(AGE)
			agg_c = agg_c + temp_cons*coupleYW(AGE,IA,IS1,IS2,IE)
			agg_y = agg_y + INCOME*coupleYW(AGE,IA,IS1,IS2,IE)
			insurance_premium = insurance_premium + PREMIUM*coupleYW(AGE,IA,IS1,IS2,IE)
			agg_yd = agg_yd + yd*coupleYW(AGE,IA,IS1,IS2,IE)

! negative tax (subsidy) treated as gov exp
			! IF (yd_MFJ(INCOME,IA) < (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA)) ) THEN 
			! 	IF (tax_MFS < 0.0) THEN 
			! 		tax_subsidy = tax_subsidy + abs(tax_MFS)*coupleYW(AGE,IA,IS1,IS2,IE)
			! 	END IF
			! ELSE 
			! 	tax_subsidy = tax_subsidy + ABS( MIN(INCOME - yd_MFJ(INCOME,IA), 0.0) )*coupleYW(AGE,IA,IS1,IS2,IE)
			! END IF 

! share of tax revenue from single
			! IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
			! 	tax_revenue_couple = tax_revenue_couple + (INCOME1 + INCOME2 - yd_MFJ(INCOME1 + INCOME2 , IA))*coupleYW(AGE,IA,IS1,IS2,IE)
			! ELSE 
			! 	tax_revenue_couple = tax_revenue_couple + (INCOME1 + INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA)))*coupleYW(AGE,IA,IS1,IS2,IE)
			! END IF  
			IF(GBC_method==0) THEN
				tax_revenue_couple = tax_revenue_couple + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYW(AGE,IA,IS1,IS2,IE) - lambda*temp*coupleYW(AGE,IA,IS1,IS2,IE)
				income_tax_revenue_couple = income_tax_revenue_couple + (temp2 - lambda*temp)*coupleYW(AGE,IA,IS1,IS2,IE)
			ELSE
				tax_revenue_couple = tax_revenue_couple + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYW(AGE,IA,IS1,IS2,IE) - temp*coupleYW(AGE,IA,IS1,IS2,IE)
				income_tax_revenue_couple = income_tax_revenue_couple + (temp2 - temp)*coupleYW(AGE,IA,IS1,IS2,IE)
			END IF  

				END DO
			END DO
        END DO 
    END DO
END DO

! Single retiree
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IE = 1,NGRIDEH
			DO IG=1,2

			JA = singleIDCRA(AGE,IA,IE,IG)	

			INCOME = SS(IE)
			TINCOME = R*A(IA) + INCOME
			! PREMIUM = premium_rate*INCOME
			PREMIUM = 0.0
			taxable_income = max(0.0,min(R*A(IA),d_c)) + INCOME

			yd = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings)*lambda*(MIN(singlebendy, taxable_income/avg_earnings))**(-tau_l_single) &
				+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME)/avg_earnings - singlebendy) &
				+(1-tau_c)*max(R*A(IA)-d_c,0.0)	

			agg_yd = agg_yd + yd*singleYR(AGE,IA,IE,IG)

! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
		IF (GBC_method==0)	THEN 		!cleared by lambda	
			temp = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings )*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) 
		ELSE	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
			temp = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings )*lambda*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) 
		END IF 
			gbcdenom = gbcdenom + temp*singleYR(AGE,IA,IE,IG)	!*MU(AGE)

! gbcnum = Taxable income + other taxes - top aftertax income
			temp2 = avg_earnings*MIN(singlebendy, taxable_income/avg_earnings ) & 
					+ avg_earnings*ty_max*MAX(0.0, taxable_income/avg_earnings - singlebendy) 
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			temp_cons = ( (avg_earnings*MIN(singlebendy, taxable_income/avg_earnings )*lambda*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) &
						+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy)) &
						+ (1-tau_c)*max(R*A(IA)-d_c,0.0) &
						+ A(IA) + medicare + gov_trans - A(JA) - PREMIUM)/(1.0+tau_s) 
			temp_staxrev = tau_s*temp_cons

			!T + taxable income - top aftertax income
			IF(GBC_method==2) THEN	
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + PREMIUM)*singleYR(AGE,IA,IE,IG)	!*MU(AGE)
			ELSEIF (GBC_method==4) THEN 
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*singleYR(AGE,IA,IE,IG)
			ELSE
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYR(AGE,IA,IE,IG)	!*MU(AGE)
			END IF 

!	cor_tax_rev = cor_tax_rev+temp_ctaxrev*YR(AGE,IA,IR)*MU(AGE)
			sales_tax_rev = sales_tax_rev + temp_staxrev*singleYR(AGE,IA,IE,IG)	!*MU(AGE)
			agg_c = agg_c + temp_cons*singleYR(AGE,IA,IE,IG)
			agg_y = agg_y + INCOME*singleYR(AGE,IA,IE,IG)
			insurance_premium = insurance_premium + PREMIUM*singleYR(AGE,IA,IE,IG)

! negative tax (subsidy) treated as gov exp
			! tax_subsidy = tax_subsidy + ABS( MIN(TINCOME - yd, 0.0) )*singleYR(AGE,IA,IE,IG)

! share of tax revenue from single
			! tax_revenue_single = tax_revenue_single + (TINCOME-yd)*singleYR(AGE,IA,IE,IG)
		IF(GBC_method==0) THEN 	
			tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYR(AGE,IA,IE,IG) - lambda*temp*singleYR(AGE,IA,IE,IG)
			income_tax_revenue_single = income_tax_revenue_single + (temp2 - lambda*temp)*singleYR(AGE,IA,IE,IG)
		ELSE 
			tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYR(AGE,IA,IE,IG) - temp*singleYR(AGE,IA,IE,IG)
			income_tax_revenue_single = income_tax_revenue_single + (temp2 - temp)*singleYR(AGE,IA,IE,IG)
		END IF

			END DO 	
		END DO
    END DO
END DO


! Couple retiree
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IE = 1,NGRIDEH
			
			JA = coupleIDCRA(AGE,IA,IE)	

			INCOME =  2*SS(IE) + min(R*A(IA),d_c)
			INCOME1 = SS(IE) + min(R*A(IA),d_c)/2
			INCOME2 = SS(IE) + min(R*A(IA),d_c)/2
			! PREMIUM = premium_rate*2*SS(IE)
			PREMIUM = 0.0
			PREMIUM1 = premium_rate*SS(IE)
			PREMIUM2 = premium_rate*SS(IE)
			tax_MFS = INCOME1+INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA))		
			taxable_income = max(0.0,min(R*A(IA),d_c))+2*SS(IE)

! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
		IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
			IF (GBC_method==0)	THEN 							!cleared by lambda	
				temp = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings )*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) 
			ELSE 	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
				temp = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings )*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) 
			END IF 
		ELSE 
			! IF (tau_l_single>0.0) THEN 
			! 	MFSbendy=((1.0-tau_l_single)*lambda*weight_MFS/(1.0-ty_max))**(1.0/tau_l_single) 
			! ELSE 
			! 	MFSbendy=1.E7 
			! END IF

			IF (GBC_method==0)	THEN
			 	! temp = weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings))**(-tau_l_single) &
				!  	   + (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings ))**(-tau_l_single) )
				temp = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) + avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)
			ELSE
				! temp = lambda*weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings ))**(-tau_l_single) &
				! 	   + (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings ))**(-tau_l_single) )
				temp = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) + avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)
			END IF 
		END IF 
			gbcdenom = gbcdenom + temp*coupleYR(AGE,IA,IE)	!*MU(AGE)


! gbcnum = Taxable income + other taxes - top aftertax income
		IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
			temp2 = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings ) & 
					+ avg_earnings*ty_max*MAX(0.0, taxable_income/avg_earnings - couplebendy)  
					
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			yd = yd_MFJ(INCOME1 + INCOME2 , IA)

			temp_cons = ( ( avg_earnings*MIN(couplebendy,(max(0.0,min(R*A(IA),d_c)) + 2*SS(IE))/avg_earnings)*lambda_couple*(MIN(couplebendy,(max(0.0,min(R*A(IA),d_c)) + 2*SS(IE))/avg_earnings ))**(-tau_l_couple) &
						+ avg_earnings*(1.0-ty_max)*MAX(0.0, (max(0.0,min(R*A(IA),d_c))+2*SS(IE))/avg_earnings - couplebendy)) &
						+ (1-tau_c)*max(R*A(IA)-d_c,0.0) &
						+ A(IA) + 2*medicare + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s) 
			temp_staxrev = tau_s*temp_cons
		ELSE 
			! IF (tau_l_single>0.0) THEN 
			! 	MFSbendy=((1.0-tau_l_single)*lambda*weight_MFS/(1.0-ty_max))**(1.0/tau_l_single) 
			! ELSE 
			! 	MFSbendy=1.E7 
			! END IF 
			temp2 = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings) + avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings) & 
					+ avg_earnings*ty_max*MAX(0.0, INCOME1/avg_earnings - MFSbendy) &
					+ avg_earnings*ty_max*MAX(0.0, INCOME2/avg_earnings - MFSbendy) 
					
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			yd = yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA)

			temp_cons = ( yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA) &
						+ A(IA) + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s) 
			temp_staxrev = tau_s*temp_cons
		END IF  

		!T + taxable income - top aftertax income
		IF(GBC_method==2) THEN
			gbcnum = gbcnum + (temp2 + temp_ctaxrev + PREMIUM)*coupleYR(AGE,IA,IE)	!*MU(AGE)
		ELSEIF (GBC_method==4) THEN 
			gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*coupleYR(AGE,IA,IE)
		ELSE
			gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYR(AGE,IA,IE)	!*MU(AGE)
		END IF 

!	cor_tax_rev = cor_tax_rev+temp_ctaxrev*YR(AGE,IA,IR)*MU(AGE)
			sales_tax_rev = sales_tax_rev + temp_staxrev*coupleYR(AGE,IA,IE)	!*MU(AGE)
			agg_c = agg_c + temp_cons*coupleYR(AGE,IA,IE)
			agg_yd = agg_yd + yd*coupleYR(AGE,IA,IE)
			agg_y = agg_y + INCOME*coupleYR(AGE,IA,IE)
			insurance_premium = insurance_premium + PREMIUM*coupleYR(AGE,IA,IE)

! negative tax (subsidy) treated as gov exp
			! IF (yd_MFJ(INCOME,IA) < (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA)) ) THEN 
			! 	IF (tax_MFS < 0.0) THEN 
			! 		tax_subsidy = tax_subsidy + abs(tax_MFS)*coupleYR(AGE,IA,IE)
			! 	END IF
			! ELSE 
			! 	tax_subsidy = tax_subsidy + ABS( MIN(INCOME - yd_MFJ(INCOME,IA), 0.0) )*coupleYR(AGE,IA,IE)
			! END IF 

! share of tax revenue from single
			! IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
			! 	tax_revenue_couple = tax_revenue_couple + (INCOME1 + INCOME2 - yd_MFJ(INCOME1 + INCOME2 , IA))*coupleYR(AGE,IA,IE)
			! ELSE 
			! 	tax_revenue_couple = tax_revenue_couple + (INCOME1 + INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA)))*coupleYR(AGE,IA,IE)
			! END IF

			IF(GBC_method==0) THEN
				tax_revenue_couple = tax_revenue_couple + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYR(AGE,IA,IE) - lambda*temp*coupleYR(AGE,IA,IE)
				income_tax_revenue_couple = income_tax_revenue_couple + (temp2 - lambda*temp)*coupleYR(AGE,IA,IE)
			ELSE
				tax_revenue_couple = tax_revenue_couple + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYR(AGE,IA,IE) - temp*coupleYR(AGE,IA,IE)
				income_tax_revenue_couple = income_tax_revenue_couple + (temp2 - temp)*coupleYR(AGE,IA,IE)
			END IF  

		END DO
    END DO
END DO


!lambda_implied=(gbcnum-gov*aggY-aggpension-lumpsumfactor*aggY+aggT_e+aggT_c+aggT_s+aggT_k)/gbcdenom	!code from Markus, Baris
!lambda_implied = (gbcnum-SS1*CUM2-gov)/gbcdenom  ! original code
! lambda_implied = (gbcnum-SS1*CUM2-gov*OUTPUT)/gbcdenom

! lambda_implied = (gbcnum-SSEXP-gov*OUTPUT-flat_transf_rate*OUTPUT-tax_subsidy)/gbcdenom
IF (optimal_tax==0) THEN 	!benchmark

	IF (GBC_method==0) THEN 
		! lambda_implied = (gbcnum-PIA_factor*SSEXP-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-tax_subsidy)/gbcdenom
		lambda_implied = (gbcnum-SSEXP-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT)/gbcdenom
	ELSEIF (GBC_method==1) THEN
		! gov_exp = (gbcnum-PIA_factor*SSEXP-flat_transf_rate*OUTPUT-tax_subsidy-gbcdenom)/OUTPUT
		gov_exp = (gbcnum-SSEXP-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT-gbcdenom)/OUTPUT
	ELSEIF (GBC_method==2) THEN
		! tau_s_implied = (PIA_factor*SSEXP+flat_transf_rate*OUTPUT+tax_subsidy+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c	
		tau_s_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c		
	ELSEIF (GBC_method==4) THEN
		premium_rate_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_y
	ELSEIF (GBC_method==5) THEN
		REPLACE_implied = (gbcnum-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT-gbcdenom)/(SSEXP/REPLACE)
	END IF 

ELSEIF (optimal_tax==1) THEN 	!optimal
	IF (GBC_method==0) THEN		! lambda clear GBC	
		! IF (gov_method==0) THEN 
		! 	gov_exp = 0.13252750482082817	! MFS: 0.13248747539805739  		!ratio of GDP	
		! 	lambda_implied = (gbcnum-PIA_factor*SSEXP-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-tax_subsidy)/gbcdenom
		! ELSEIF (gov_method==1) THEN 
		! 	gov_exp = 8.4769458187				!level value
		! 	lambda_implied = (gbcnum-PIA_factor*SSEXP-gov_exp-flat_transf_rate*OUTPUT-tax_subsidy)/gbcdenom
		! END IF 

		! lambda_implied = (gbcnum-PIA_factor*SSEXP-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-tax_subsidy)/gbcdenom
		lambda_implied = (gbcnum-SSEXP-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT)/gbcdenom
	ELSEIF (GBC_method==2) THEN		!tau_s clear GBC
		! tau_s_implied = (PIA_factor*SSEXP+flat_transf_rate*OUTPUT+tax_subsidy+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c
		tau_s_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c
	ELSEIF (GBC_method==4) THEN
		premium_rate_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_y	
	ELSEIF (GBC_method==5) THEN
		REPLACE_implied = (gbcnum-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT-gbcdenom)/(SSEXP/REPLACE)
	END IF 
	! ELSEIF (GBC_method==1) THEN
	! ! SS clear GBC
	! 	IF (gov_method==0) THEN 
	! 		gov_exp = 0.13252750482082817	! MFS: 0.13248747539805739 		! benchmark gov_exp ratio of GDP	
	! 		PIA_factor_implied = (gbcnum-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-tax_subsidy-gbcdenom)/SSEXP
	! 	ELSEIF (gov_method==1) THEN
	! 		gov_exp = 8.4769458187				!level value
	! 		PIA_factor_implied = (gbcnum-gov_exp-flat_transf_rate*OUTPUT-tax_subsidy-gbcdenom)/SSEXP
	! 	END IF

	! 	dPIA = abs(PIA_factor_implied - PIA_factor)
	! END IF 

END IF 

! print*, 'tax revenue=',gbcnum
! print*, 'SS exp/GDP=',PIA_factor*SSEXP/OUTPUT
print*, 'SS exp/GDP=',SSEXP/OUTPUT
print*, 'transf exp=',flat_transf_rate*OUTPUT
print*, 'medicare=', medicare_rate*OUTPUT
print*, 'after tax income=',gbcdenom
! print*, 'tax_subsidy=',tax_subsidy
print*, 'tax_revenue_single=',tax_revenue_single
print*, 'tax_revenue_couple=',tax_revenue_couple
! print*, 'total expenditure=', PIA_factor*SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+tax_subsidy
print*, 'total expenditure=', SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT
print*, 'total tax revenue=', tax_revenue_single+tax_revenue_couple
print*, 'total tax revenue/GDP=', (tax_revenue_single+tax_revenue_couple)/OUTPUT
print*, 'total saving rate', 1.0 - agg_c/agg_yd

! IF (GBC_method==1) THEN 
! 	IF (gov_method==0) THEN 
! 		print*, 'implied gov exp/GDP=',gov_exp
! 		print*, 'total expenditure=', PIA_factor*SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+tax_subsidy
! 	ELSEIF (gov_method==1) THEN
! 		print*, 'implied gov exp level=',gov_exp
! 		print*, 'total expenditure=', PIA_factor*SSEXP+gov_exp+flat_transf_rate*OUTPUT+tax_subsidy
! 	END IF
! END IF 


! update BEQ and SS
BEQ1 = Agg_beq/working_population

! Average earnings (to update EHMAX)
avg_earnings = 0.0
avg_wage = 0.0
!working_population = SUM(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)))
! Single working
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG=1,2                   
                			   
				JN = singleIDCWN(AGE,IA,IS,IE,IG)  
				INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) 	
				TINCOME	= R*A(IA) + INCOME 			
                ! avg_earnings = avg_earnings + INCOME*singleYW(AGE,IA,IS,IE,IG)/working_population
				 avg_earnings = avg_earnings + TINCOME*singleYW(AGE,IA,IS,IE,IG)
				 avg_wage = avg_wage + WAGE*EFFLONG(AGE,IG)*W(IS,IG)*singleYW(AGE,IA,IS,IE,IG)

				END DO 
            END DO
        END DO 
    END DO
END DO
! Single retired
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IE = 1,NGRIDEH	
			DO IG=1,2

				TINCOME	= R*A(IA) + SS(IE)
				avg_earnings = avg_earnings + TINCOME*singleYR(AGE,IA,IE,IG)

			END DO     
        END DO
    END DO
END DO
! Couple working
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH

				JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
				JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
				INCOME = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)
				TINCOME	= R*A(IA) + INCOME 
				! avg_earnings = avg_earnings + INCOME*coupleYW(AGE,IA,IS1,IS2,IE)/working_population
				avg_earnings = avg_earnings + TINCOME*coupleYW(AGE,IA,IS1,IS2,IE)
				avg_wage = avg_wage + (WAGE*EFFLONG(AGE,1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*W(IS2,2))*coupleYW(AGE,IA,IS1,IS2,IE)

				END DO 
            END DO
        END DO 
    END DO
END DO
! Couple retired
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH   
			
			TINCOME	= R*A(IA) + 2*SS(IE) 
			avg_earnings = avg_earnings + TINCOME*coupleYR(AGE,IA,IE)

		END DO
    END DO
END DO  

! avg_earnings = avg_earnings/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:))+ SUM(singleYR(RETAGE:MAXAGE,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:)))
avg_earnings = avg_earnings/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+2.0*SUM(coupleYW(1:RETAGE-1,:,:,:,:))+ SUM(singleYR(RETAGE:MAXAGE,:,:,:))+2.0*SUM(coupleYR(RETAGE:MAXAGE,:,:)))
avg_wage = avg_wage/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+2.0*SUM(coupleYW(1:RETAGE-1,:,:,:,:)))

! avg_earnings = 1.0
print*,'avg_wage',avg_wage
print*,'avg_earnings',avg_earnings

! lambdaold = lambda
!      IF (lambda_implied>lambda) THEN
! 			lambda1=lambda;
! 			lambda=0.5*lambda1+0.5*lambda2
! 		 ELSE
! 			lambda2=lambda;
! 			lambda=0.5*lambda1+0.5*lambda2
! 	   	END IF
!      dlam = lambda2 - lambda1
!  if ( dlam < tol_lam ) lambda = lambdaold

	!!Update Medicare tax rate
	!MTAX1=SUBM*MEDR /(WAGE*LEND)

!   Update EHI premium
!	PREMIUM1=SUBEHI*MEDW/CUM1 /(1.0-STAX1-MTAX1)
    
!    PRINT *, 'EHI output ratio) =',       PREMIUM1/sum(TILONG(:)*MU(:))

    BEQDEV  = ABS(BEQ-BEQ1)        / BEQ
	!SSDEV   = ABS(SS-SS1)          / SS
	!STAXDEV = ABS(STAX-STAX1)      / STAX
	!MTAXDEV = ABS(MTAX-MTAX1)      / MTAX
!	EHIDEV  = ABS(PREMIUM-PREMIUM1)/ PREMIUM
!	dlam = abs(lambda-lambda_implied) / lambda
!	dPIA = abs(PIA_factor_implied - PIA_factor)
	IF (GBC_method==0) THEN	
		dlam = abs(lambda_implied - lambda) 
	ELSEIF (GBC_method==1) THEN
		dPIA = abs(PIA_factor_implied - PIA_factor)
	ELSEIF (GBC_method==2) THEN
		dtau_s = abs(tau_s_implied - tau_s)
	ELSEIF (GBC_method==4) THEN
		dpremium_rate = abs(premium_rate_implied - premium_rate)
	ELSEIF (GBC_method==5) THEN
		dREPLACE = abs(REPLACE_implied - REPLACE)
	END IF 


	PRINT*,''
    WRITE(10,*) 'Iteration', ITER
    PRINT *, 'Iteration', ITER, '(lambda),', LOOPNUMBER, '(r)'	
    PRINT*,'----------------------------------------'
	print*,'tau_s =',tau_s
	print*,'tau_l_single =',tau_l_single
	print*,'tau_l_couple =',tau_l_couple 
	print*, 'lambda_single=',lambda 
	print*, 'lambda_couple=',lambda_couple
	print*, 'premium_rate=', premium_rate
	print*, 'implied G/GDP=', gov_exp
	! print*, 'SS exp/GDP=',PIA_factor*SSEXP/OUTPUT
	print*, 'SS exp/GDP=',SSEXP/OUTPUT
	PRINT *, 'Output =', OUTPUT		
	PRINT *, 'K =', Agg_asset
	PRINT *, 'L =', Agg_labor	
	print*, 'source_welfare=', source_welfare
    WRITE(10,*) 'Initial bequests =', BEQ
    PRINT *, 'Initial bequests =', BEQ
    WRITE(10,*) 'Ending bequest =', BEQ1
    PRINT *, 'Ending bequests =', BEQ1
    WRITE(10,*) 'Relative change in bequests =', BEQDEV
    PRINT *, 'Relative change in bequests =', BEQDEV
	!WRITE(10,*) 'Initial SS benefit =', SS
    !PRINT *, 'Initial SS benefit =', SS
    !WRITE(10,*) 'Ending SS benefit =', SS1
    !PRINT *, 'Ending SS benefit =', SS1
    !WRITE(10,*) 'Relative change in SS =', SSDEV
    !PRINT *, 'Relative change in SS =', SSDEV

	! WRITE(10,*) 'Initial SS tax rate =', STAX
    ! PRINT *, 'Initial SS tax rate =', STAX
    ! WRITE(10,*) 'Ending SS tax rate =', STAX1
    ! PRINT *, 'Ending SS tax rate =', STAX1
    ! WRITE(10,*) 'Relative change in SS tax rate =', STAXDEV
    ! PRINT *, 'Relative change in SS tax rate =', STAXDEV
 	! WRITE(10,*) 'Initial med tax rate =', MTAX
    ! PRINT *, 'Initial med tax rate =', MTAX
    ! WRITE(10,*) 'Ending med tax rate =', MTAX1
    ! PRINT *, 'Ending med tax rate =', MTAX1
    ! WRITE(10,*) 'Relative change in med tax rate =', MTAXDEV
    ! PRINT *, 'Relative change in med tax rate =', MTAXDEV
	! WRITE(10,*) 'Initial EHI premium =', PREMIUM
    ! PRINT *, 'Initial EHI premium =', PREMIUM
    ! WRITE(10,*) 'Ending EHI premium =', PREMIUM1
    ! PRINT *, 'Ending EHI premium =', PREMIUM1
    ! WRITE(10,*) 'Relative change in EHI premium =', EHIDEV
    ! PRINT *, 'Relative change in EHI premium =', EHIDEV

	print*, ' Source of tax expenditure'
	! print*, 'SS exp/GDP=',PIA_factor*SSEXP/OUTPUT
	print*, 'SS exp/GDP=',SSEXP/OUTPUT
	IF (gov_method==0) THEN 
		print*, 'implied gov exp/GDP=',gov_exp
	ELSEIF (gov_method==1) THEN
		print*, 'implied gov exp level=',gov_exp
	ELSEIF (gov_method==2) THEN
		print*, 'gov exp=',gov_exp
	END IF
	print*, 'transf exp=',flat_transf_rate*OUTPUT
	! print*, 'tax_subsidy=',tax_subsidy
	print*, ' Source of tax revenue'
	print*, 'tax_revenue_single=',tax_revenue_single
	print*, 'tax_revenue_couple=',tax_revenue_couple
	print*, 'total tax revenue/GDP=', (tax_revenue_single+tax_revenue_couple)/OUTPUT
	print*, 'Government budget clearance'
	print*, 'total tax revenue=', tax_revenue_single+tax_revenue_couple
	
	IF (gov_method==0) THEN 
		! print*, 'total expenditure=', PIA_factor*SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+tax_subsidy
		print*, 'total expenditure=', SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT
	ELSEIF (gov_method==1) THEN
		! print*, 'total expenditure=', PIA_factor*SSEXP+gov_exp+flat_transf_rate*OUTPUT+tax_subsidy
		print*, 'total expenditure=', SSEXP+gov_exp+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT
	END IF


	IF (GBC_method==0) THEN 
	 	PRINT *, ''
     	! PRINT *, '  [lambda1  lambda2] ', '  lambdaold'
    	! WRITE(*,"(3(F10.5))") lambda1, lambda2, lambda
		PRINT*, 'lambda=', lambda
		PRINT*, 'lambda_implied=', lambda_implied
		PRINT *, 'Relative change in lambda =', dlam
	ELSEIF (GBC_method==1) THEN 
	 	PRINT *, ''   
		PRINT*, 'PIA old=', PIA_factor
	 	PRINT*, 'PIA_factor_implied=', PIA_factor_implied
	 	PRINT *, 'Relative change in PIA factor =', dPIA
	ELSEIF (GBC_method==2) THEN 
		PRINT *, ''
     	! PRINT *, '  [tau_s1  tau_s2] ', '  tau_s_old'
    	! WRITE(*,"(3(F10.5))") tau_s1, tau_s2, tau_s
		PRINT*, 'tau_s=', tau_s
		PRINT*, 'tau_s_implied=', tau_s_implied
		PRINT *, 'Relative change in tau_s =', dtau_s
	ELSEIF (GBC_method==4) THEN
		PRINT *, 'premium_rate =', premium_rate
		PRINT*, 'premium_rate_implied=', premium_rate_implied
		PRINT *, 'Relative change in premium rate =', dpremium_rate
	ELSEIF (GBC_method==5) THEN
		PRINT *, 'REPLACE =', REPLACE
		PRINT*, 'REPLACE_implied=', REPLACE_implied
		PRINT *, 'Relative change in premium rate =', dREPLACE
	END IF
    
	 PRINT *, ''
     PRINT *, '  [bend1  bend2] ', '  avg_earnings'
     WRITE(*,"(3(F10.5))") bend1, bend2, avg_earnings
	 PRINT *, ''
    !  PRINT *, '  PIA benefit '
    ! !  WRITE(*,"(3(F10.5))") SS(1),SS(2),SS(3),SS(4),SS(5),SS(6),SS(7),SS(8),SS(9),SS(10),SS(11),SS(12),SS(13),SS(14),SS(15)
	! WRITE(*,"(3(F10.5))") SS(1),SS(2),SS(3),SS(4),SS(5),SS(6),SS(7),SS(8),SS(9),SS(10)
    PRINT*,'----------------------------------------' 
    WRITE(10,*)


	IF (GBC_method==0) THEN 
		dREPLACE = 0.0
		dtau_s = 0.0
		dpremium_rate = 0.0
	ELSEIF (GBC_method==1) THEN 
		dlam = 0.0
		dtau_s = 0.0
		dpremium_rate = 0.0
	ELSEIF (GBC_method==2) THEN
		dREPLACE = 0.0 
		dlam = 0.0
		dpremium_rate = 0.0
	ELSEIF (GBC_method==4) THEN	
		dREPLACE = 0.0
		dlam = 0.0
		dtau_s = 0.0
	ELSEIF (GBC_method==5) THEN	
		dlam = 0.0
		dtau_s = 0.0
		dpremium_rate = 0.0
	END IF 
	
	print*,'BEQDEV', BEQDEV
	print*,'dlam', dlam
	print*,'dREPLACE', dREPLACE
	print*,'dtau_s', dtau_s
	print*, 'dpremium_rate', dpremium_rate


	print*,'BEQDEV-TOLB', BEQDEV-TOLB
	print*,'dlam-tol_lam', dlam-tol_lam
	print*,'dPIA-tol_PIA', dPIA-tol_PIA
	print*,'dtau_s-tol_tau_s', dtau_s-tol_tau_s 

	IF ( (BEQDEV>TOLB) .OR. (dlam>tol_lam) .OR. (dPIA>tol_PIA) .OR. (dtau_s>tol_tau_s) .OR. (dpremium_rate>tol_premium) .OR. (dREPLACE>tol_REPLACE) )  THEN
        BEQ     = (1 - GRADB)*BEQ       + GRADB*BEQ1
	    !SS      = (1 - GRADSS)*SS       + GRADSS*SS1
		


! Bend points from https://www.ssa.gov/oact/cola/bendpoints.html	

		! bend1   =  bend1_1960*(avg_earnings/(avg_monthly_earnings2000*5.0))	
		! bend2	=  bend2_1960*(avg_earnings/(avg_monthly_earnings2000*5.0))
! 		EHMAX	=  avg_earnings*MULTI_EHMAX0

	! ! UPDATE lambda
         lambdaold = lambda
		!  tau_s_old = tau_s

    !  	! 	IF (lambda_implied>lambda) THEN
	! 	! 		lambda1=lambda;
	! 	! 		lambda=0.5*lambda1+0.5*lambda2
	! 	!  	ELSE
	! 	! 		lambda2=lambda;
	! 	! 		lambda=0.5*lambda1+0.5*lambda2
	!    	! 	END IF
    ! 	!  dlam = lambda2 - lambda1
	! 	! if ( dlam < tol_lam ) lambda = lambdaold


! IF (GBC_method==2) THEN
! 	tau_s = (1 - GRADTAUS)*tau_s + GRADTAUS*tau_s_implied
! 	dtau_s = abs(tau_s_implied - tau_s)
! ELSE
! 	IF (optimal_tax==1) THEN 
! 		IF (GBC_method==0) THEN
! 	! UPDATE lambda 2
! 			lambda = (1 - GRADLAMBDA)*lambda + GRADLAMBDA*lambda_implied
! 			dlam = abs(lambda_implied - lambda) 
! 		ELSEIF (GBC_method==1) THEN
! 	! UPDATE PIA factor   		 
!             ! dPIA = abs(PIA_factor_implied - PIA_factor) 
! 			PIA_factor = (1 - GRADPIA)*PIA_factor + GRADPIA*PIA_factor_implied
! 		END IF 
! 	END IF
! END IF 

IF (GBC_method==0) THEN
	lambda = (1 - GRADLAMBDA)*lambda + GRADLAMBDA*lambda_implied
	! dlam = abs(lambda_implied - lambda) 
! ELSEIF (GBC_method==1) THEN
! 	PIA_factor = (1 - GRADPIA)*PIA_factor + GRADPIA*PIA_factor_implied
ELSEIF (GBC_method==2) THEN
	tau_s = (1 - GRADTAUS)*tau_s + GRADTAUS*tau_s_implied
	! dtau_s = abs(tau_s_implied - tau_s)
ELSEIF (GBC_method==4) THEN
	premium_rate = (1 - GRADPREMIUM)*premium_rate + GRADPREMIUM*premium_rate_implied
ELSEIF (GBC_method==5) THEN
	REPLACE = (1 - GRADREPlACE)*REPLACE + GRADREPlACE*REPLACE_implied
END IF 


ITERINC = 1
    END IF

	IF (ITERINC>0) THEN

        ITER = ITER + ITERINC

        IF (ITER>MAXITER) THEN
            PRINT *, 'Maximum number of iterations exceeded.'
            PRINT *, 'Program terminates.'
            WRITE(10,*) 'Maximum number of iterations exceeded.'
            WRITE(10,*) 'Program terminates.'
            GO TO 799
        END IF
     
		!DEALLOCATE(IDCWA, IDCWN, VW, YW, IDCRA, IDCRN,  singleVR, YR, S, CUMS, MU, Y_AGE, CUMSWK,MUWK)
		DEALLOCATE(singleIDCWA, coupleIDCWA, singleIDCWN, coupleIDCWN, singleVW, coupleVW, marriageVW,singleYW, coupleYW,singleIDCRA, coupleIDCRA, singleIDCRN, coupleIDCRN,singleVR, coupleVR, singleYR, coupleYR, marriageVR)
        !DEALLOCATE(S, CUMS, MU, Y_AGE, CUMSWK,MUWK)
		DEALLOCATE(ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, LLONG_single, LLONG_couple)
		DEALLOCATE(EH)
        GO TO 200
    END IF
799 continue

! Bisection method    
	! MPKDEV  = (MPK-0.034)/0.034		! 0.034 is the average return in wealth in the model
	! PRINT*, 'MPK=', MPK
	! PRINT*, 'MPKDEV=', MPKDEV
	! IF ( abs(MPKDEV)>TOLMPK ) THEN
		! IF  ( MPKDEV>0.0 ) THEN
		! !IF  ( MPKDEV<0.0 ) THEN
			! beta_update     = (BETA + MAXBETA)/2.0 
			! MINBETA = BETA
			! PRINT*,'BETADEV=', beta_update - BETA
			! DEALLOCATE (IDCWA, IDCWN, VW, YW, IDCRA, IDCRN,  VR, YR, S, CUMS, MU, Y_AGE)
			! DEALLOCATE (ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, LLONG)
			! GO TO 300			
		! ELSEIF ( MPKDEV<0.0 ) THEN
		! !ELSEIF ( MPKDEV>0.0 ) THEN
			! beta_update     = (BETA + MINBETA)/2.0
			! MAXBETA = BETA
			! PRINT*,'BETADEV=', beta_update - BETA
			! DEALLOCATE (IDCWA, IDCWN, VW, YW, IDCRA, IDCRN,  VR, YR, S, CUMS, MU, Y_AGE)
			! DEALLOCATE (ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, LLONG)
			! GO TO 300
		! END IF 
	! END IF	
!***************************
!
!  Calculate the Wealth Gini
!
!*************************** 
    ! print*,'IDCWA(1,1,1,1)=',IDCWA(1,1,1,1)
    ! print*,'IDCWA(1,1,1,2)=',IDCWA(1,1,1,2)
	! print*,'IDCWA(1,1,1,3)=',IDCWA(1,1,1,3)
    ! print*,'IDCWA(1,1,1,4)=',IDCWA(1,1,1,4)
	! print*,'IDCWA(1,1,1,5)=',IDCWA(1,1,1,5)
    ! print*,'IDCWA(1,1,1,6)=',IDCWA(1,1,1,6)

    !  CALL compute_gini
    !  CALL age_wealth_gini
      
!*************************************
!
!  Calculate the Wealth share holding
!
!*************************************  
      
    !  CALL wealthshare

!*************************************
!
!  Calculate the mean,SD of return in wealth of top wealth share
!
!*************************************		  
	  
	!  CALL avg_return       ! we get Avg_R,Avg_R_weighted

!***************************************************************************************************************      
! Asset demand
   ! KD = LEND*(ALPHA*TFP/(Avg_R+DEP))**(1/(1-ALPHA))  !capital labor ratio from demand side
   ! KD = LEND*(ALPHA*TFP/(Avg_R_weighted+DEP))**(1/(1-ALPHA))
   ! KD = LEND*(ALPHA*TFP/( ((1+Avg_R_weighted)**5.0-1.0) + DEP))**(1/(1-ALPHA))
   	 
   ! KD = LEND*(ALPHA*TFP/( ((1+R)**5.0-1.0) + DEP))**(1/(1-ALPHA))
   ! KD = Agg_labor*(ALPHA*TFP/( ((1+R)**5.0-1.0) + DEP))**(1/(1-ALPHA))	!origin
     KD = Agg_labor*(ALPHA*TFP/( R + DEP))**(1/(1-ALPHA))


    KDEV = abs(KD-Agg_asset)
	! KDEV = 0.0

print*, '==================Convergent result=================='
print*, 'beta=' , BETA_ANNUAL
print*, 'annual depreciation=', DEP_ANNUAL
print*, '5year Depreciation=', DEP
print*, 'TFP=',TFP
print*, 'Labor supply=',Agg_labor
print*, 'capital demand=',KD
print*, 'capital supply=', Agg_asset
print*, '5year return =', R
print*, 'Annual return =', (1.0+R)**0.2-1.0
print*, '5year net MPK=',  (ALPHA)*TFP*(KD/Agg_labor)**(ALPHA-1)-DEP
! print*, '5year MPL=', (1.0-ALPHA)*TFP*( (((1+R)**5.0-1.0)+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))
print*, '5year MPL=', (1.0-ALPHA)*TFP*( (R+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))
print*, 'wage=', WAGE
print*, 'tau_s=', tau_s
print*, 'lambda_S=', lambda
print*, 'lambda_MFS=', lambda_couple
print*, 'lambda_MFJ=', lambda*delta_lambda
print*, 'K Deviation=',KDEV


IF (KDEV > TOLK) THEN

 	SELECT CASE(r_update)
	
	CASE(1)
	!	Method 1: Update R bisection
		IF (Agg_asset > KD)	THEN
			R2 = R
			R = 0.5*R1 + 0.5*R2
		ELSE 
			R1 = R
			R = 0.5*R1 + 0.5*R2
		END IF

		! print*, ' --------------- update 5year R ---------------'		
		! PRINT *, '  [R1  R2] ', 'new R'
		! WRITE(*,"(3(F10.5))") R1, R2, R
		print*, ' --------------- update 1year R ---------------'		
		PRINT *, '  [R1  R2] ', 'new R'
		WRITE(*,"(3(F10.5))") (1.0+R1)**0.2-1.0, (1.0+R2)**0.2-1.0, (1.0+R)**0.2-1.0
		print*, '===================================================='

	CASE(2)
	!	Method 2
		R_ANNUAL = (1.0+R)**0.2 - 1.0
		r_implied = (1.0 + (ALPHA*TFP) * (Agg_asset/Agg_labor)**(ALPHA-1.0) - DEP)**0.2 - 1.0
		print*, 'r, r_implied', R_ANNUAL, r_implied

		IF (LOOPNUMBER==1) THEN
			! R1 = R_ANNUAL-0.03
			! R2 = R_ANNUAL+0.03
			R1 = R_ANNUAL-0.01
			R2 = R_ANNUAL+0.01
		END IF
			print*, 'old R1, R2: ', R1, R2

		IF (LOOPNUMBER>1) THEN
			IF ( r_implied < R_ANNUAL ) THEN
				R2 = 0.5*R_ANNUAL+0.5*R2
			ELSE
				R1 = 0.5*R_ANNUAL+0.5*R1
			END IF	
		END IF 
		print*, 'new R1, R2: ', R1, R2
		IF ( r_implied < R_ANNUAL ) THEN
			r_new = 0.5 * R_ANNUAL + 0.5 * MAX(r_implied,R1)
		ELSE
			r_new = 0.5 * R_ANNUAL + 0.5 * MIN(r_implied,R2)
		END IF

		delta_r = ABS(r_new-R_ANNUAL)
		print*, 'delta_r=',delta_r

		IF ( Agg_asset < KD ) THEN
			R= ( 1.0+((1+R)**(0.2)-1 + delta_r) )**5.0 -1.00			
		ELSEIF ( Agg_asset > KD ) THEN
			R= ( 1.0+((1+R)**(0.2)-1 - delta_r) )**5.0 -1.00        
		END IF
	
	CASE(3)
	
		IF (KDEV > 10.0) THEN
			delta_r = 0.01
		ELSEIF ( (KDEV < 10.0) .and. (KDEV > 5.0) ) THEN 
			delta_r = 0.005
		ELSEIF ( (KDEV < 5.0) .and. (KDEV > 2.0) ) THEN   
			delta_r = 0.002
		ELSEIF ( (KDEV < 2.0) .and. (KDEV > 0.5) ) THEN  
			delta_r = 0.0005     
		ELSE 
			delta_r = 0.0001   
		END IF 

		print*, 'delta_r=',delta_r

		IF ( Agg_asset < KD ) THEN
			R= ( 1.0+((1+R)**(0.2)-1 + delta_r) )**5.0 -1.00			
		ELSEIF ( Agg_asset > KD ) THEN
			R= ( 1.0+((1+R)**(0.2)-1 - delta_r) )**5.0 -1.00        
		END IF

	END SELECT

	! print*, ' --------------- update 5year R ---------------'		
	! PRINT *, '  [R1  R2] ', 'new R'
	! WRITE(*,"(3(F10.5))") R1, R2, R
	! print*, ' --------------- update 1year R ---------------'		
	! PRINT *, '  [R1  R2] ', 'new R'
	! WRITE(*,"(3(F10.5))") (1.0+R1)**0.2-1.0, (1.0+R2)**0.2-1.0, (1.0+R)**0.2-1.0
	! print*, '===================================================='

!  Update Wage rate
! WAGE = (1.0-ALPHA)*TFP*( (((1+R)**5.0-1.0)+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))	!wage= 5year MPL
  WAGE = (1.0-ALPHA)*TFP*( (R+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))	!wage= 5year MPL 
! WAGE = (1.0-ALPHA)*TFP*( (((1+R_ANNUAL)**5.0-1.0)+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))	!wage= 5year MPL

print*, ' ----------- update parameter ---------------'
print*, 'new WAGE=',WAGE
print*, 'new annual r=',(1+R)**(0.2)-1
print*, 'K Deviation=',KDEV
!print*, '===================================================='


! IF (KDEV > TOLK) THEN

!DEALLOCATE(IDCWA, IDCWN, VW, YW, IDCRA, IDCRN,  singleVR, YR, S, CUMS, MU, Y_AGE, MUWK, CUMSWK)
DEALLOCATE(singleIDCWA, coupleIDCWA, singleIDCWN, coupleIDCWN, singleVW, coupleVW, marriageVW,singleYW, coupleYW,singleIDCRA, coupleIDCRA, singleIDCRN, coupleIDCRN,singleVR, coupleVR, singleYR, coupleYR, marriageVR)
!DEALLOCATE(S, CUMS, MU, Y_AGE, CUMSWK,MUWK)
DEALLOCATE(ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, LLONG_single, LLONG_couple)
! DEALLOCATE(X,D,D_YW,D_YR,D_inc,D_A)  
!DEALLOCATE(X,D,D_inc,D_A)  
!DEALLOCATE(sort_A, sort_D,cum_sort_D,top0001pct_D,top0005pct_D,top001pct_D,top005pct_D,top01pct_D,top05pct_D,top1pct_D, &
!           top5pct_D, top10pct_D,top20pct_D,top40pct_D,top50pct_D,top60pct_D,top70pct_D,top80pct_D,top90pct_D,top95pct_D,&
!           top99pct_D, record_position_A, box  )
!DEALLOCATE(sort_D_R, box_R,weight_R)  
DEALLOCATE(EH) 

END IF 

END DO !DO WHILE
!***************************************************************************************************************

!***************************
!
!  Save results
!
!*************************** 
IF ((source_welfare_analysis_activation == 0) .AND. (optimal_tax_activation == 0 ) .AND. (save_bm_decisions ==1) ) THEN 
	OPEN(UNIT=27,FILE='eqm_outcomes.txt')
		write(27,*) WAGE, BETA, LAMBDA, SS(1),SS(2),SS(3),SS(4),SS(5),SS(6),SS(7),SS(8),SS(9),SS(10), AEND, LEND, OUTPUT, R
	CLOSE(27)

	! Fortran writes these like this: (1,1,1,1), (2,1,1,1), ... (1,2,1,1), (2,2,1,1), ... (1,1,2,1), (2,1,2,1), ... (1,2,2,1), (2,2,2,1), ... (1,1,1,2), (2,1,1,2) ... 
	! that is, it first keeps dim 2, 3, 4 fixed and cycles through one. Then it keeps 3, 4, fixed, changes the value of 2, and cycles through 1. So: it varies the last dim last, and always cycles first through 1, then 2, then 3, then 4.
	OPEN(UNIT=27,FILE='singleIDCWA.txt')
		write(27,*) singleIDCWA(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCWA.txt')
		write(27,*) coupleIDCWA(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCWN.txt')
		write(27,*) singleIDCWN(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCWN.txt')
		write(27,*) coupleIDCWN(:,:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCRA.txt')
		write(27,*) singleIDCRA(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCRA.txt')
		write(27,*) coupleIDCRA(:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCRN.txt')
		write(27,*) singleIDCRN(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCRN.txt')
		write(27,*) coupleIDCRN(:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCWC.txt')
		write(27,*) singleIDCWC(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCRC.txt')
		write(27,*) singleIDCRC(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCWC.txt')
		write(27,*) coupleIDCWC(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCRC.txt')
		write(27,*) coupleIDCRC(:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleVW.txt')
		write(27,*) singleVW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleVW.txt')
		write(27,*) coupleVW(:,:,:,:,:)
	CLOSE(27)
	
	OPEN(UNIT=27,FILE='marriageVW.txt')
		write(27,*) marriageVW(:,:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleVR.txt')
		write(27,*) singleVR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleVR.txt')
		write(27,*) coupleVR(:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='marriageVR.txt')
		write(27,*) marriageVR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleYW.txt')
		write(27,*) singleYW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleYW.txt')
		write(27,*) coupleYW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleYR.txt')
		write(27,*) singleYR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleYR.txt')
		write(27,*) coupleYR(:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='Agrid.txt')
		write(27,*) A
	CLOSE(27)

	OPEN(UNIT=27,FILE='Ngrid.txt')
		write(27,*) N
	CLOSE(27)
END IF

IF (CV==0) THEN 
	OPEN(UNIT=27,FILE='bench_single_VW.txt')
		write(27,*) singleVW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_single_VR.txt')
		write(27,*) singleVR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_VW.txt')
		write(27,*) coupleVW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_VR.txt')
		write(27,*) coupleVR(:,:,:)
	CLOSE(27)
END IF


print*, ' ================General equilibrium is solved================'	
!*************************************
!
!  Calculate the Consumption holding
!
!************************************* 

	  CALL consumptionshare

	!   CALL totalincomeshare	

	!   CALL wageshare

!***************************
!
!  Calculate the Welfare
!
!*************************** 
print*, 'CALL opt_tax_welfare begins'
ALLOCATE(certeq_singlemale(3), certeq_singlefemale(3) )
ALLOCATE(certeq_couplemale(2,2), certeq_couplefemale(2,2))

	CALL opt_tax_welfare 

print*, 'CALL opt_tax_welfare ends'

IF (source_welfare==0) THEN
	OPEN(UNIT=27,FILE='bench_singleIDCRC.txt')
		write(27,*) bench_singleIDCRC
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_single_VR.txt')
		write(27,*) bench_single_VR
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_singleYR.txt')
		write(27,*) bench_singleYR
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_retire_single_util_C.txt')
		write(27,*) bench_retire_single_util_C
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_singleIDCWC.txt')
		write(27,*) bench_singleIDCWC
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_singleIDCWN.txt')
		write(27,*) bench_singleIDCWN
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_single_VW.txt')
		write(27,*) bench_single_VW
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_singleYW.txt')
		write(27,*) bench_singleYW
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_single_util_C.txt')
		write(27,*) bench_single_util_C
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_single_util_LS.txt')
		write(27,*) bench_single_util_LS
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_coupleIDCRC.txt')
		write(27,*) bench_coupleIDCRC
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_VR.txt')
		write(27,*) bench_couple_VR
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_coupleYR.txt')
		write(27,*) bench_coupleYR
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_retire_couple_util_C.txt')
		write(27,*) bench_retire_couple_util_C
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_coupleIDCWC.txt')
		write(27,*) bench_coupleIDCWC
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_coupleIDCWN.txt')
		write(27,*) bench_coupleIDCWN
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_VW.txt')
		write(27,*) bench_couple_VW
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_coupleYW.txt')
		write(27,*) bench_coupleYW
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_util_C.txt')
		write(27,*) bench_couple_util_C
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_util_LS.txt')
		write(27,*) bench_couple_util_LS
	CLOSE(27)
END IF 

IF (CV==1) THEN
	CALL compensating_variation
	print*, 'CALL compensating_variation ends'
END IF 

	CALL couple_filing_tax

! Computing the pass through of income shock to consumption

!*************************************

	CALL insurance

!*************************************
!
!  Check whether kmax binding

    CALL check_kmaxbinding
print*, 'finished checking kmaxbinding'
!
!*************************************

	
!*************************************
!
!  Calculate winner_loser 
!	
!*************************************
!source_welfare in this stage should be 1 as it has computed benchmark already
	IF ((source_welfare==1) .AND. (optimal_tax == 1)) THEN 
		print*, 'CALL winner_loser begins'
		CALL winner_loser 
		print*, 'CALL winner_loser ends'
	END IF 
!*************************************

source_welfare = source_welfare + 1

IF (result_display==0) THEN
	IF (source_welfare /= 2) THEN
		IF ((optimal_tax == 1) .OR. (source_welfare ==1)) THEN 

			DEALLOCATE(certeq_singlemale, certeq_singlefemale, certeq_couplemale, certeq_couplefemale)
			DEALLOCATE(singleIDCWA, coupleIDCWA, singleIDCWN, coupleIDCWN, singleVW, coupleVW, marriageVW,singleYW, coupleYW,singleIDCRA, coupleIDCRA, singleIDCRN, coupleIDCRN,singleVR, coupleVR, singleYR, coupleYR, marriageVR)
			DEALLOCATE(ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, LLONG_single, LLONG_couple)
			DEALLOCATE(EH) 
			DEALLOCATE(singleIDCWC, coupleIDCWC, singleIDCRC, coupleIDCRC)
			DEALLOCATE(sort_C,sort_D_C,temp_sort_D_C,cum_sort_D_C,top0001pct_D_C,top0005pct_D_C,top001pct_D_C,top01pct_D_C,top05pct_D_C,top1pct_D_C, &
        	   		top5pct_D_C, top10pct_D_C,top20pct_D_C,top40pct_D_C,top50pct_D_C,top60pct_D_C,top70pct_D_C,top80pct_D_C,top90pct_D_C,top95pct_D_C,&
        	   		top99pct_D_C,box_C,record_position_C  )
			DEALLOCATE(temp_retire_single_util_C,retire_single_util_C,temp_retire_couple_util_C,retire_couple_util_C,temp_single_util_LS,single_util_LS,temp_single_util_C,&
					single_util_C,temp_couple_util_LS,couple_util_LS,temp_couple_util_C,couple_util_C   )
			DEALLOCATE(certeqcons_singlemale,certeqlab_singlemale,certeqcons_singlefemale,certeqlab_singlefemale,certeqcons_couple,certeqlab_couple,agg_certeqcons_couple,agg_certeqlab_couple,V_certeq_couple,AggL_couple,cost_unc_couple,expV_certeq_couple,cost_ineq_couple,AggC_couple_leicomp,AggL_couple_bm)
			DEALLOCATE(log_income_diff_single,log_income_shock_diff_single,log_cons_diff_single,dist_single,log_income_diff_couple,log_income_shock_diff_couple,log_cons_diff_couple,dist_couple)
			DEALLOCATE(ageprofile_log_income_shock_diff_single,ageprofile_log_cons_diff_single,ageprofile_dist_single,ageprofile_log_income_shock_diff_couple,ageprofile_log_cons_diff_couple,ageprofile_dist_couple)
			DEALLOCATE(ageprofile_avg_log_income_shock_single,ageprofile_avg_log_income_shock_couple,ageprofile_avg_log_cons_single,ageprofile_avg_log_cons_couple,ageprofile_insurance_cons_shock_nominator_single,ageprofile_insurance_cons_shock_nominator_couple)
			DEALLOCATE(ageprofile_insurance_cons_shock_denominator_single,ageprofile_insurance_cons_shock_denominator_couple,ageprofile_insurance_cons_shock_value_single,ageprofile_insurance_cons_shock_value_couple)
			DEALLOCATE(ageprofile_log_income_diff_single,ageprofile_log_income_diff_couple,ageprofile_avg_log_income_single,ageprofile_avg_log_income_couple)
			DEALLOCATE(ageprofile_insurance_cons_nominator_single,ageprofile_insurance_cons_nominator_couple,ageprofile_insurance_cons_denominator_single,ageprofile_insurance_cons_denominator_couple,ageprofile_insurance_cons_value_single,ageprofile_insurance_cons_value_couple)
			! DEALLOCATE(log_income_diff_single_retire,log_cons_diff_single_retire,dist_single_retire,log_income_diff_couple_retire,log_cons_diff_couple_retire,dist_couple_retire)
			DEALLOCATE(temp_single_discount,single_discount,temp_couple_discount1,temp_couple_discount2,couple_discount1,couple_discount2)

		END IF 
	END IF 
END IF  


END DO 	!JTS
	END DO 	!JTM

IF (source_welfare==1) THEN 
	optimal_tax = 1
	IF (GBC_method /= 2) THEN  
		GBC_method = 0
	END IF 
	GO TO 888
END IF 

IF (source_welfare /= 2) THEN
	IF ((optimal_tax == 1) .AND. (result_display==0)) THEN 			
		print*, 'program end'
		GO TO 999
	END IF 
END IF 

!***************************
!
!  Calculate the Wealth Gini
!
!*************************** 

     CALL compute_gini
      
!*************************************
!
!  Calculate the Wealth share holding
!
!*************************************  
      
     CALL wealthshare

!*************************************


!***************************
!
!  Calculate the Age Wealth Gini
!
!*************************** 

     CALL age_wealth_gini

!*************************************
!
!  Calculate the labor income share holding
!
!*************************************  

	  CALL wageshare	  
	  
!*************************************
!
!  Calculate the total income share holding
!
!*************************************  

	  CALL totalincomeshare	  

!*************************************
!
!  Calculate the Consumption holding
!
!************************************* 

	!  CALL consumptionshare

!*************************************
!
!  Calculate the Skewness of wealth and earning distribution 
!
!*************************************	 

	  CALL skewness
	  
!*************************************
!
!  Calculate the life cycle profile of wealth,earning,income ratio 
!
!*************************************	
      
	  CALL AGE_PARTITION
	  
!*************************************
!
!  Calculate the Income partition of top wealth share
!
!*************************************		  

	  CALL income_partition

!*************************************
!
!  Intra family earning correlation
!
!*************************************	
	  
	  CALL intrafamily_correlation

!*************************************
!
!  var log earning and log consumption profile
!
!*************************************	
	
	  CALL var_profile

!*************************************
!
!  Compare the earning distribution with the literature
!
!*************************************	
	  
	!  CALL COMPARE_LITERATURE

!*************************************
!
!  Calculate the Synthetic Saving Rate  (Saez, Zucman 2016 QJE Table B33)
!
!*************************************		  
	  
	!  CALL saving_rate
	  
!*************************************
!
!  Calculate the Bequest Moment  (De Nardi, Fang Yang 2016 JME Table 1)
!
!*************************************		  
	  
	!  CALL bequest

!*************************************
!
!  Calculate the consumption share by income ranking
!
!*************************************	

	!  CALL joint_dist
	        

	        			
!*******************************
!
!   Summary Calculations
!
!*******************************


! !  Age distribution of working age population

! 799 ALLOCATE ( CUMSWK(RETAGE-1), MUWK(RETAGE-1) )

!     CUMSWK(1) = 1.000
!     DO J=2,RETAGE-1
!         CUMSWK(J) = CUMSWK(J-1)*S(J-1)
!     END DO
   
    
!     CUMWK = 0.0
!     DO AGE=1,RETAGE-1
!         CUMWK = CUMWK + CUMSWK(AGE)/((1.0+POPG)**(AGE-1))
!     END DO
   
    
!     MUWK(1) = 1.0/CUMWK
! 	SUMWK   = MUWK(1)
!     DO AGE=2,RETAGE-1
!         MUWK(AGE) = S(AGE-1)*MUWK(AGE-1)/(1.0+POPG)
! 	    SUMWK = SUMWK + MUWK(AGE)
!     END DO
   
    
! !	Check the sum of age share is equal to one
! 	IF (ABS(SUMWK-1.000000)>0.000001) THEN
!         PRINT*, 'The sum of age share for working age population is not equal to one at age!'
! !		GO TO 999
! 	END IF		
   
!*********************************************** Not Applicable to this model *****************************************************************************
! !	Compute the average ratios over the life cycle
    
! 	SICKEND = 0.0
! 	CWKEND  = 0.0
! 	MEND    = 0.0
! 	IEND    = 0.0
! 	TWEND   = 0.0
!     LEND    = 0.0
	 	 
!     DO AGE=1,RETAGE-1
! 	    !SICKEND = SICKEND + SICKLONG(AGE)
! 	    CWKEND  = CWKEND  + CLONG(AGE)*MUWK(AGE)
! !	    MEND    = MEND    + MLONG(AGE)*MUWK(AGE)
! 	    IEND    = IEND    + ILONG(AGE)*MUWK(AGE)
!     !    LEND    = LEND    + NLONG(AGE)*MUWK(AGE)
! 		LEND    = LEND    +	EFFLONG(AGE)*NLONG(AGE)*MUWK(AGE)
! 	    TWEND   = TWEND   + LLONG(AGE)   ! working hours
!     END DO
! 	TWEND   = TWEND/(FLOAT(RETAGE-1))    ! average time endowment to work
! 	SICKEND = SICKEND/(FLOAT(RETAGE-1))
	
! PRINT*, 'IEND=', IEND

! 	!SICK1 =0.0
! 	!SICK2 =0.0
! 	!HEND  =0.0

! 	!DO AGE=1,5
! 	    !SICK1 = SICK1 + SICKLONG(AGE)
! 	    !HEND  = HEND  + HLONG(AGE)
! 	!END DO
! 	!SICK1 = SICK1/5.000

! 	!DO AGE=6,RETAGE-1   ! for retirement age = 10
! 	!DO AGE=6,RETAGE-2    ! for retirement age = 11
! 	!    SICK2 = SICK2 + SICKLONG(AGE)
! 	!    HEND  = HEND  + HLONG(AGE)
! 	!END DO
! 	!SICK2=SICK2/4.000
	

! 	!DO AGE=RETAGE,11        ! for retirement age = 10
!     !DO AGE=RETAGE-1,11     ! for retirement age = 11
! 	!    HEND = HEND + HLONG(AGE)
! 	!END DO
! 	!HEND=HEND/11.000
    
!     !H1END=0.0
! 	!DO AGE=1,14     ! Compute average health status for age 20-90
!     !    H1END = H1END + HLONG(AGE)
!     !END DO
!     !H1END=H1END/14.000
    
! 	!MYOUNG=0.0
! 	!DO AGE=1,7
! 	!    MYOUNG = MYOUNG + MLONG(AGE)
! 	!END DO
! 	!MYOUNG=MYOUNG/7.000

! 	!MOLD=0.0
! 	!DO AGE=8,11
! 	!    MOLD = MOLD + MLONG(AGE)
! 	!END DO
! 	!MOLD=MOLD/4.000

! 	AEND   =0.0
! 	!MEDEND =0.0
! 	CEND   =0.0
! 	TIEND  =0.0
!     DO AGE=1,MAXAGE
!         AEND   = AEND   + ALONG(AGE)*MU(AGE)
! 	   ! MEDEND = MEDEND + MLONG(AGE)*MU(AGE)
!  	    CEND   = CEND   + CLONG(AGE)*MU(AGE)
! 	    TIEND  = TIEND  + TILONG(AGE)*MU(AGE)
!     END DO
!     PRINT*, 'Replace=', Replace
!     PRINT*, 'TIEND=', TIEND
!     PRINT*, 'LEND=', LEND
! 	PRINT*, 'AEND=', AEND
!     PRINT*, 'BEQEND=', BEQEND

!************************************************************************************************************************************
Agg_labor = 0.0
Agg_asset = 0.0
! Working-age "single" agents
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG=1,2                   
				  
				 JN = singleIDCWN(AGE,IA,IS,IE,IG)   

				 Agg_asset = Agg_asset + A(IA)*singleYW(AGE,IA,IS,IE,IG) 
                 Agg_labor = Agg_labor + EFFLONG(AGE,IG)*N(JN)*W(IS,IG)*singleYW(AGE,IA,IS,IE,IG) 
												
				END DO 
            END DO
        END DO 
    END DO
END DO

!  Working-age "couple" agents
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH

				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
			 	 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

				 Agg_asset = Agg_asset + A(IA)*coupleYW(AGE,IA,IS1,IS2,IE) 
				 Agg_labor = Agg_labor + (EFFLONG(AGE,1)*W(IS1,1)*N(JN1) +EFFLONG(AGE,2)*W(IS2,2)*N(JN2))*coupleYW(AGE,IA,IS1,IS2,IE)  
				
				END DO 
            END DO
        END DO 
    END DO
END DO

!  Single Retirees  
DO AGE=RETAGE,MAXAGE        
	DO IA=1,NGRIDA
        DO IE=1,NGRIDEH
			DO IG=1,2

			 Agg_asset = Agg_asset + A(IA)*singleYR(AGE,IA,IE,IG)
			 
			END DO 
        END DO
    END DO
END DO

!  Couple Retirees    
DO AGE=RETAGE,MAXAGE                      
    DO IA=1,NGRIDA
        DO IE=1,NGRIDEH

		 Agg_asset = Agg_asset + A(IA)*coupleYR(AGE,IA,IE)

		END DO
    END DO
END DO

!	Output

	!K = AEND/(1.0+AGROWTH)      ! Detrend
	K = Agg_asset
	L = Agg_labor
!	OUTPUT = TFP*(K**ALPHA)*(L**(1-ALPHA))
!	MPL = (1-ALPHA)*TFP*(K/L)**ALPHA
!	MPK = (ALPHA)*TFP*(K/L)**(ALPHA-1)

	OUTPUT = TFP*(K**ALPHA)*(L**(1-ALPHA))	
    MPK = (ALPHA)*TFP*(KD/L)**(ALPHA-1)-DEP
	MPL = (1.0-ALPHA)*TFP*( (R+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))
	! MPL = (1.0-ALPHA)*TFP*( (((1+R)**5.0-1.0)+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))
	
	
    !MPK = (ALPHA)*TFP*(K/L)**(ALPHA-1)
	!MPL = (1-ALPHA)*TFP*(K/L)**ALPHA
!*************************************
!
!  Calculate the tax moments
!
!*************************************	

	  CALL tax_moment

!*************************************		  
!
!  Check whether kmax binding
!
!*************************************
      
      CALL check_kmaxbinding

!*************************************		  
!
!  welfare analysis
!
!*************************************
      
      CALL welfare

!*************************************
!
!  tax penalty for couple
!
!*************************************
        
      CALL tax_penalty
  
	!   CALL couple_filing_tax

!*************************************
!
!   by what factor would one need to increase the consumption of each and every person in the benchmark economy 
!	to reach the same average welfare as the optimal economy, keeping their labor supply constant?
!
!*************************************

	CALL welfare_consumption_change

!*************************************

! Computing the pass through of income shock to consumption

!*************************************

	! CALL insurance

!*************************************

    CALL CPU_TIME(t1)

    PRINT*, 'ELAPSED CPU time for is', t1-t0
    
    ! WRITE(10,*) 'labor income ratio-output ratio =', IEND-TIEND

    ! WRITE(10,*) 'EHI labor income ratio) =', PREMIUM/IEND
    ! WRITE(10,*) 'EHI output ratio) =',       PREMIUM/TIEND
     
 !	Print out the life cycle profiles

! 	DO AGE=1,MAXAGE
! 	!WRITE(18,88) AGE, ALONG(AGE), CLONG(AGE), ILONG(AGE), HLONG(AGE), MLONG(AGE), LLONG(AGE), S(AGE), TILONG(AGE)
! 	WRITE(18,88) AGE, ALONG(AGE), CLONG(AGE), ILONG(AGE), LLONG(AGE), S(AGE,1),S(AGE,2), TILONG(AGE)
! 88	FORMAT (1X,I2,1X,8(F10.7,X))
! 	END DO

	! VSLMOMENT1 = ((S(1)-S(3))/(S(1)+S(3)))   / ((MLONG(1)-MLONG(3))/(MLONG(1)+MLONG(3)))
	! VSLMOMENT2 = ((S(2)-S(4))/(S(2)+S(4)))   / ((MLONG(2)-MLONG(4))/(MLONG(2)+MLONG(4)))
	! VSLMOMENT3 = ((S(3)-S(5))/(S(3)+S(5)))   / ((MLONG(3)-MLONG(5))/(MLONG(3)+MLONG(5)))
	! VSLMOMENT4 = ((S(4)-S(6))/(S(4)+S(6)))   / ((MLONG(4)-MLONG(6))/(MLONG(4)+MLONG(6)))
	! VSLMOMENT5 = ((S(5)-S(7))/(S(5)+S(7)))   / ((MLONG(5)-MLONG(7))/(MLONG(5)+MLONG(7)))
	! VSLMOMENT6 = ((S(6)-S(8))/(S(6)+S(8)))   / ((MLONG(6)-MLONG(8))/(MLONG(6)+MLONG(8)))
	! VSLMOMENT7 = ((S(7)-S(9))/(S(7)+S(9)))   / ((MLONG(7)-MLONG(9))/(MLONG(7)+MLONG(9)))
	! VSLMOMENT8 = ((S(8)-S(10))/(S(8)+S(10))) / ((MLONG(8)-MLONG(10))/(MLONG(8)+MLONG(10)))
	! VSLMOMENT9 = ((S(9)-S(11))/(S(9)+S(11))) / ((MLONG(9)-MLONG(11))/(MLONG(9)+MLONG(11)))

!************************************* we use the data source for survival rate of male and female suggested by Nishiyama*************************************
	! SURVMOMENT1 = sum(CUMS(10:16))/sum(CUMS(1:9))
	! SURVMOMENT2 = 1.00/sum(CUMS(1:16))
	! SURVMOMENT3 = (S(12)-S(10))/(S(10)-S(8))
!************************************************************************************************************************************************************

    ! DEV = ((AEND*5.000/TIEND-2.63)/2.63)**2.00 + ((MEDEND/TIEND-0.151)/0.151)**2.00 + ((MEND/IEND-0.058)/0.058)**2.00
	! DEV = DEV + ((MOLD/MYOUNG-7.9586)/7.9586)**2.00 + ((CWKEND/IEND-0.7847)/0.7847)**2.00 + ((TWEND-0.3493)/0.3493)**2.00
	! DEV = DEV + ((SICKEND-0.021)/0.021)**2.00 + ((SICK1/SICK2-1.36)/1.36)**2.00 + ((HEND-0.8452)/0.8452)**2.00
	! DEV = DEV + (((HLONG(1)+HLONG(2))/(HLONG(3)+HLONG(4))-1.0213)/1.0213)**2.00 + (((HLONG(3)+HLONG(4))/(HLONG(5)+HLONG(6))-1.0491)/1.0491)**2.00
	! DEV = DEV + ((SURVMOMENT1-0.3970)/0.3970)**2.00 + (SURVMOMENT2-0.0824)**2.00 + ((SURVMOMENT3-2.266)/2.266)**2.00 + (S(10)/S(1)-0.9154)**2.00
	! DEV = DEV + ((VSLMOMENT1-(-0.00181))/(-0.00181))**2.00


!	Calibration

    WRITE(10,*) 'FINAL RESULTS'
    WRITE(10,*) '*****************************************************'
    WRITE(10,*)
    
    ! WRITE(10,*) '1, beta'
    ! WRITE(10,*) 'Capital-Wealth Ratio (Data: 2.63 from NIPA 2002, beta) =', AEND*5/TIEND
    ! WRITE(10,*) '2, LAMBDA'
    ! WRITE(10,*) 'Nonmed Expenditure-Labor Income Ratio (Data: GK=0.7082 FK=0.7847) =', CWKEND/IEND
    ! WRITE(10,*) '3, RHO'
    ! WRITE(10,*) 'Average working hours over working age (Data: 0.3493 from PSID) =', TWEND
    ! WRITE(10,*) '4, PSI' 
    ! WRITE(10,*) 'Med Expenditure (55-74)/ Med Expenditure (20-54) (Data: 7.9586 from MEPS) =', MOLD/MYOUNG
    ! WRITE(10,*) '5, UCONS' 
    ! WRITE(10,*) 'Change in sur prob (55-59 to 65-69) / Change in med expenditure (55-59 to 65-69) (Data: -0.06266) =', VSLMOMENT8
    ! WRITE(10,*)
    
!    WRITE(10,*) '6-8, health depreciation'
!    WRITE(10,*) 'Average Health status from age 20-24 to 70-74 (Data: 0.8452 from PSID) =', HEND 
    ! WRITE(10,*) 'Health status age 20-29 / Health status age 30-39 (Data: 1.0213 from PSID) =', (HLONG(1)+HLONG(2))/(HLONG(3)+HLONG(4))
    ! WRITE(10,*) 'Health status age 30-39 / Health status age 40-49 (Data: 1.0491 from PSID) =', (HLONG(3)+HLONG(4))/(HLONG(5)+HLONG(6))
    ! WRITE(10,*)
    
    ! WRITE(10,*) '9-10, health product function'
    ! WRITE(10,*) 'Med Expenditure-Output Ratio (Data: 0.151 from NHA 2002) =', MEDEND/TIEND
    ! WRITE(10,*) 'Med Expenditure-Labor Income Ratio (Data: 0.058 from PSID) =', MEND/IEND
    ! WRITE(10,*)

    ! WRITE(10,*) '11-12, sick time'
    ! WRITE(10,*) 'Sick Time Ratio over working age (Data: 0.021 from Lovell 2004) =', SICKEND
    ! WRITE(10,*) 'Sick Time (45-64) / Sick time (20-44) (Data: 1.36 from Lovell 2004) =', SICK2/SICK1
    ! WRITE(10,*)

!************************************************************************************************************************************************************    
    ! WRITE(10,*) '13-16, suvrvival probablity'
    ! WRITE(10,*) 'Dependency ratio (Data: 0.3970 from US Life Table) =', SURVMOMENT1
    ! WRITE(10,*) 'Average death rate (Data: 0.0824 from US Life Table) =', SURVMOMENT2
    ! WRITE(10,*) 'change in Sur. Prob (age 65-69 to 75-79) / change in sur. prob. (age 55-59 to 65-69) (Data: 2.266 from US Life Table) =', SURVMOMENT3
    ! WRITE(10,*) 'Sur. Prob (age 65-69) / Sur. Prob. (20-24) (Data: 0.9154 from US Life Table) =', S(10)/S(1)
    ! WRITE(10,*)
!************************************************************************************************************************************************************

    
    ! WRITE(10,*) 'others'
    ! WRITE(10,*) 'Nonmed Consumption-Output Ratio (Data: 0.669 from NHA 2002) =', CEND/TIEND
    ! WRITE(10,*) 'Change in sur prob (20-24 to 30-34) / Change in med expenditure (20-24 to 30-34) (Data: -0.00181) =', VSLMOMENT1
    ! WRITE(10,*) 'Change in sur prob (25-29 to 35-39) / Change in med expenditure (25-29 to 35-39) (Data: -0.00277) =', VSLMOMENT2
    ! WRITE(10,*) 'Change in sur prob (30-34 to 40-44) / Change in med expenditure (30-34 to 40-44) (Data: -0.01765) =', VSLMOMENT3
    ! WRITE(10,*) 'Change in sur prob (35-39 to 45-49) / Change in med expenditure (35-39 to 45-49) (Data: -0.01204) =', VSLMOMENT4
    ! WRITE(10,*) 'Change in sur prob (40-44 to 50-54) / Change in med expenditure (40-44 to 50-54) (Data: -0.0600) =', VSLMOMENT5
    ! WRITE(10,*) 'Change in sur prob (45-49 to 55-59) / Change in med expenditure (45-49 to 55-59) (Data: -0.03379) =', VSLMOMENT6
    ! WRITE(10,*) 'Change in sur prob (50-54 to 60-64) / Change in med expenditure (50-54 to 60-64) (Data: -0.02842) =', VSLMOMENT7
    ! WRITE(10,*) 'Change in sur prob (60-64 to 70-74) / Change in med expenditure (60-64 to 70-74) (Data: -0.1285) =', VSLMOMENT9
    ! WRITE(10,*)
    ! WRITE(10,*) 'Deviation from the targets =', DEV**0.500
    ! WRITE(10,*)
    
    ! WRITE(10,*) 'OUTPUT =', TIEND
     ! WRITE(10,*) 'Average Health status from age 20-24 to 85-89  =', H1END 
     
    ! WRITE(10,*) '*****************************************************' 
	
!**********************************************************************************************************************************************	
    ! print*, 'FINAL RESULTS'
    ! print*, '*****************************************************'
    ! print*,
    
    ! print*, '1, beta'
    ! print*, 'Capital-Wealth Ratio (Data: 2.63 from NIPA 2002, beta) =', AEND*5/TIEND
    ! print*, '2, LAMBDA'
    ! print*, 'Nonmed Expenditure-Labor Income Ratio (Data: GK=0.7082 FK=0.7847) =', CWKEND/IEND
    ! print*, '3, RHO'
    ! print*, 'Average working hours over working age (Data: 0.3493 from PSID) =', TWEND
    ! print*, '4, PSI' 
    ! print*, 'Med Expenditure (55-74)/ Med Expenditure (20-54) (Data: 7.9586 from MEPS) =', MOLD/MYOUNG
    ! print*, '5, UCONS' 
    ! print*, 'Change in sur prob (55-59 to 65-69) / Change in med expenditure (55-59 to 65-69) (Data: -0.06266) =', VSLMOMENT8
    ! print*,
    
    ! print*, '6-8, health depreciation'
    ! print*, 'Average Health status from age 20-24 to 70-74 (Data: 0.8452 from PSID) =', HEND 
    ! print*, 'Health status age 20-29 / Health status age 30-39 (Data: 1.0213 from PSID) =', (HLONG(1)+HLONG(2))/(HLONG(3)+HLONG(4))
    ! print*, 'Health status age 30-39 / Health status age 40-49 (Data: 1.0491 from PSID) =', (HLONG(3)+HLONG(4))/(HLONG(5)+HLONG(6))
    ! print*,
    
    ! print*, '9-10, health product function'
    ! print*, 'Med Expenditure-Output Ratio (Data: 0.151 from NHA 2002) =', MEDEND/TIEND
    ! print*, 'Med Expenditure-Labor Income Ratio (Data: 0.058 from PSID) =', MEND/IEND
    ! print*,

    ! print*, '11-12, sick time'
    ! print*, 'Sick Time Ratio over working age (Data: 0.021 from Lovell 2004) =', SICKEND
    ! print*, 'Sick Time (45-64) / Sick time (20-44) (Data: 1.36 from Lovell 2004) =', SICK2/SICK1
    ! print*,
    
    ! print*, '13-16, suvrvival probablity'
    ! print*, 'Dependency ratio (Data: 0.3970 from US Life Table) =', SURVMOMENT1
    ! print*, 'Average death rate (Data: 0.0824 from US Life Table) =', SURVMOMENT2
    ! print*, 'change in Sur. Prob (age 65-69 to 75-79) / change in sur. prob. (age 55-59 to 65-69) (Data: 2.266 from US Life Table) =', SURVMOMENT3
    ! print*, 'Sur. Prob (age 65-69) / Sur. Prob. (20-24) (Data: 0.9154 from US Life Table) =', S(10)/S(1)
    ! print*,
    
    ! print*, 'others'
    ! print*, 'Nonmed Consumption-Output Ratio (Data: 0.669 from NHA 2002) =', CEND/TIEND
    ! print*, 'Change in sur prob (20-24 to 30-34) / Change in med expenditure (20-24 to 30-34) (Data: -0.00181) =', VSLMOMENT1
    ! print*, 'Change in sur prob (25-29 to 35-39) / Change in med expenditure (25-29 to 35-39) (Data: -0.00277) =', VSLMOMENT2
    ! print*, 'Change in sur prob (30-34 to 40-44) / Change in med expenditure (30-34 to 40-44) (Data: -0.01765) =', VSLMOMENT3
    ! print*, 'Change in sur prob (35-39 to 45-49) / Change in med expenditure (35-39 to 45-49) (Data: -0.01204) =', VSLMOMENT4
    ! print*, 'Change in sur prob (40-44 to 50-54) / Change in med expenditure (40-44 to 50-54) (Data: -0.0600) =', VSLMOMENT5
    ! print*, 'Change in sur prob (45-49 to 55-59) / Change in med expenditure (45-49 to 55-59) (Data: -0.03379) =', VSLMOMENT6
    ! print*, 'Change in sur prob (50-54 to 60-64) / Change in med expenditure (50-54 to 60-64) (Data: -0.02842) =', VSLMOMENT7
    ! print*, 'Change in sur prob (60-64 to 70-74) / Change in med expenditure (60-64 to 70-74) (Data: -0.1285) =', VSLMOMENT9
    ! print*,
    ! print*, 'Deviation from the targets =', DEV**0.500
    ! print*,
    
    ! print*, 'OUTPUT =', TIEND
    ! print*, 'Average Health status from age 20-24 to 85-89  =', H1END 
     
    ! print*, '*****************************************************' 	
	
!**********************************************************************************************************************************************		
	

!*********************
!
!   Calibration Result
!
!*********************	
		print*, ' '
		print *, "Male Transition Matrix for Productivity Process"
			DO i=1,nn
	  			WRITE(*,"(12(F10.6,1X))") P(i,1:nn,1)
			END DO
		print *, 'Steady State Probabilities for Male'
		WRITE(*,"(12(F10.6,1X))") SSprob_z1(1,:)
		print *, 'productivity for Male'
		WRITE(*,"(12(F10.6,1X))") W(:,1)
		print *, 'male_age_eff'
		WRITE(*,"(12(F10.6,1X))") EFFLONG(:,1)
		print*, ' '
		print *, "Female Transition Matrix for Productivity Process"
			DO i=1,nn
	  			WRITE(*,"(12(F10.6,1X))") P(i,1:nn,2)
			END DO
		print *, 'Steady State Probabilities for Female'
		WRITE(*,"(12(F10.6,1X))") SSprob_z2(1,:)
		print *, 'productivity for Female'
		WRITE(*,"(12(F10.6,1X))") W(:,2)
		print *, 'female_age_eff'
		WRITE(*,"(12(F10.6,1X))") EFFLONG(:,2)
		print*, ' '
		WRITE(11,*) 'Marriage-Sorting matrix='
		write(11,"(11(F8.5,1X))") P_m(1,1), P_m(1,2)
		write(11,"(11(F8.5,1X))") P_m(2,1), P_m(2,2)
		print*, ' '

		! print*, ' '
		! print *, "Transition Matrix for Return in Wealth "
		! 	DO i=1,NGRIDR
	  	! 		WRITE(*,"(12(F10.6,1X))") P_r(i,1:NGRIDR)
		! 	END DO
		! print*, ' '

		! write(*, "(15(A11,1X))") 'p15', 'p55', 'p56', 'p66', 'w(1)', 'w(2)', 'w(3)', 'w(4)', 'W(5)', 'W(6)'
		! WRITE(*,"(12(F11.4,1X))") p15, p55, p56, p66, w(1), w(2), w(3), w(4), W(5), W(6)
		! print*, ' '

		print*, 'Intrafamily Wage Correlation'
		print*, 'corr_family_earn',corr_family_earn
		print*, 'Average corr_family_earn', avg_corr_family_earn

		write(*, "(15(A11,1X))") 'Annual BETA','tau_l_single','tau_l_couple','delta_lambda','tau_c','tau_s','d_c','premium_rate','REPLACE'
		WRITE(*,"(12(F11.4,1X))") BETA**(0.2), tau_l_single, tau_l_couple, delta_lambda,tau_c, tau_s, d_c, premium_rate, REPLACE
		write(*, "(15(A11,1X))") 'MPL','wage', 'MPK','Annual r', 'DEP_ANNUAL','marry prop', 'lambda_S','lambda_MFJ','lambda_MFS','ty_max'
		WRITE(*,"(12(F11.4,1X))") MPL, wage, MPK, (1.0+R)**0.2-1.0, DEP_ANNUAL,marryprop , lambda, lambda_couple, lambda_couple,ty_max
		write(*, "(15(A11,1X))") 'LPC_singleF','LPC_marr_F','theta_singM','theta_singF','theta_marrM','theta_marrF'
		WRITE(*,"(12(F11.4,1X))") fixcost_singlefemale,fixcost_marriedfemale,theta_single_male,theta_single_female,theta_married_male,theta_married_female
        write(*, "(15(A11,1X))") 'TFP','Y', 'L','K','C','ALPHA', 'K/Y','SS/Y'
        WRITE(*,"(12(F11.4,1X))") TFP,OUTPUT,Agg_labor,Agg_asset,Aggconsumption,ALPHA,alpha/((1.0+R)**0.2-1.0 + DEP_ANNUAL),SSEXP/OUTPUT
		
		! print*, 'Intra family earning risk correlation'
		! print*, 'corr_family_earn',corr_family_earn
		! print*, 'husband-wife wage correlation ',earn_corr
		! print*, ' '
		
		write(*,"(11(A8,1X))") 'wea_gini', 'kshare05', 'kshare1', 'kshare5', 'kshare10', 'kshare20', 'kshare40', 'kshare60', 'kshare80'
		write(*,"(11(F8.5,1X))") wea_gini, kshare05, kshare1, kshare5, kshare10, kshare20, kshare40, kshare60, kshare80
		print*, ' '
		
		write(*,"(11(A8,1X))") 'E_gini', 'Eshare05', 'Eshare1', 'Eshare5', 'Eshare10', 'Eshare20', 'Eshare40', 'Eshare60', 'Eshare80'
		write(*,"(11(F8.5,1X))") inc_gini, incshare05, incshare1, incshare5, incshare10, incshare20, incshare40, incshare60, incshare80
		print*, ' '
		
		write(*,"(11(A8,1X))") 'tinc_gini', 'TIshar05', 'TIshar1', 'TIshar5', 'TIshar10', 'TIshar20', 'TIshar40', 'TIshar60', 'TIshar80'
		write(*,"(11(F8.5,1X))") tinc_gini, tincshare05, tincshare1, tincshare5, tincshare10, tincshare20, tincshare40, tincshare60, tincshare80
		print*, ' '

		write(*,"(11(A8,1X))") 'con_gini', 'cshare05', 'cshare1', 'cshare5', 'cshare10', 'cshare20', 'cshare40', 'cshare60', 'cshare80'
		write(*,"(11(F8.5,1X))") cons_gini, cshare05, cshare1, cshare5, cshare10, cshare20, cshare40, cshare60, cshare80
		print*, ' '

		write(*,"(11(A8,1X))") 'yd_gini'
		write(*,"(11(F8.5,1X))") yd_gini
		print*, ' '
		
		print*, ' '
		print*, 'Income tax moments'
		write(*,"(15(A11,1X))") 'R/Y', 'ATY1', 'ATY10', 'ATY99','ATY90', 'ATY1-ATY99','ATY'
		write(*,"(12(F11.4,1X))") inctaxrev_income, ATY1,ATY10, ATY99,ATY90, ATY1-ATY99,ATY
		print*, 'ATY_single'
		write(*,"(15(A11,1X))") 'All','Q1','Q2','Q3','Q4','Q5'
		write(*,"(12(F11.4,1X))") ATY_single,ATY_single_Q1,ATY_single_Q2,ATY_single_Q3,ATY_single_Q4,ATY_single_Q5
		print*, 'ATY_couple'
		write(*,"(15(A11,1X))") 'All','Q1','Q2','Q3','Q4','Q5'
		write(*,"(12(F11.4,1X))") ATY_couple,ATY_couple_Q1,ATY_couple_Q2,ATY_couple_Q3,ATY_couple_Q4,ATY_couple_Q5
		print*, 'Income tax revenues (single)', income_tax_revenue_single
		print*, 'Income tax revenues (couple)', income_tax_revenue_couple


		print*,''
		print*, 'Corporate tax moments'
		write(*,"(15(A11,1X))") 'R/Y', 'ATC1', 'ATC99'
		write(*,"(12(F11.4,1X))") ctaxrev_income, ATC1, ATC99
		print*, 'Government expenditures','Government Transfer'
		write(*,"(15(A11,1X))") 'total exp/Y','G/Y' ,'Trans/Y','SS/Y','Med/Y'
		write(*,"(12(F11.4,1X))")  G_share, gov_exp ,flat_transf_rate,SSEXP/OUTPUT,medicare_rate

		IF (gov_method==0) THEN 
			print*, 'Implied Government expenditures/GDP', gov_exp
		ELSEIF (gov_method==1) THEN
			print*, 'implied gov exp level=',gov_exp
		ELSEIF (gov_method==2) THEN
			print*, 'G/Y=',gov_exp
		END IF

		print*, 'tax revenue share from single=',tax_revenue_single/(tax_revenue_single+tax_revenue_couple)
		print*, 'tax revenue share from couple=',tax_revenue_couple/(tax_revenue_single+tax_revenue_couple)
		print*, 'total tax revenue/GDP=', (tax_revenue_single+tax_revenue_couple)/OUTPUT
		print*, ' '	
		print*, 'saving rate =',1.0 - agg_c/agg_yd

		print*, ' '		
		print*, 'Agg. Working hour =', Avg_hour !TWEND
		print*, 'Total male Working hour (0.364)=', hour_male
		print*, 'Total female Working hour (0.353) =', hour_female
		print*, 'Single male Working hour =', hour_single_male
		print*, 'Single female Working hour =', hour_single_female
		print*, 'Married male Working hour =', hour_married_male
		print*, 'Married female Working hour =', hour_married_female
		print*, ' '
		print*, 'Labor force participation rate between 20-64'
		print*, 'Men', LFP_male
		print*, 'Women', LFP_female
		print*, 'Single female (0.63)', LFP_single_female
		print*, 'Married female (0.493)', LFP_married_female

		print*,''
		print*, 'Transmission of earning to consumption (Working Group) '
		print*,'transmission_value=',insurance_value
		print*,'transmission_value_single=',insurance_value_single
		print*,'transmission_value_couple=',insurance_value_couple
		print*,''
		print*,'var log cons / var log earning'
		print*,'var_cons_earning_ratio_single=',var_cons_earning_ratio_single
		print*,'var_cons_earning_ratio_couple=',var_cons_earning_ratio_couple
		print*,'var_cons_earning_ratio',var_cons_earning_ratio
		print*,''
		print*, 'transmission of productivity shock to consumption '
		print*,'transmission_cons_value',insurance_cons_value
		print*,'transmission_cons_value_single',insurance_cons_value_single
		print*,'transmission_cons_value_couple',insurance_cons_value_couple
		print*, 'transmission of productivity shock to earning '
		print*,'transmission_labor_value',insurance_labor_value
		print*,'transmission_labor_value_single',insurance_labor_value_single
		print*,'transmission_labor_value_couple',insurance_labor_value_couple

		! print*, ' '
		! print*, 'Agg. Working hour =', Avg_hour !TWEND
		! print*, 'Total male Working hour =', hour_male
		! print*, 'Total female Working hour =', hour_female
		! print*, 'Single male Working hour =', hour_single_male
		! print*, 'Single female Working hour =', hour_single_female
		! print*, 'Married male Working hour =', hour_married_male
		! print*, 'Married female Working hour =', hour_married_female
		! print*, ' '
		! print*, 'Labor force participation rate between 20-64'
		! print*, 'Men', LFP_male
		! print*, 'Women', LFP_female
		! print*, 'Single female', LFP_single_female
		! print*, 'Married female', LFP_married_female
	
		
		print*, '----------------------------------------------------------------------------------------------------------------'
		print*, 'Outside Target' 
		
		print*, ' '
		write(*, "(15(A16,1X))") 'zero wealth %'
		write(*, "(143(F16.8,1X))") share_zero_k
		write(*, "(15(A16,1X))") 'klevel01','klevel05', 'klevel1', 'klevel5', 'klevel10', 'klevel20', 'klevel40', 'klevel60', 'klevel80'
		write(*, "(143(F16.8,1X))") klevel01, klevel05, klevel1, klevel5, klevel10, klevel20, klevel40, klevel60, klevel80
		write(*, "(15(A16,1X))") 'klevel95-99','klevel90-95', 'klevel4Q', 'klevel3Q', 'klevel2Q'
		write(*, "(143(F16.8,1X))") klevel9599, klevel9095, klevel6080, klevel4060, klevel2040

		print*, ' '
		print*, 'top wealth share'
		write(*, "(15(A16,1X))") ' Top 0.001%', ' Top 0.005%', ' Top 0.01%', ' Top 0.05%',' Top 0.1%'
		write(*, "(143(F16.8,1X))") kshare0001, kshare0005, kshare001,kshare005, kshare01
		
		print*, ' '
		print*, 'top earning share'
		write(*, "(15(A16,1X))") ' Top 0.001%', ' Top 0.005%', ' Top 0.01%',' Top 0.05%', ' Top 0.1%'
		write(*, "(143(F16.8,1X))") incshare0001, incshare0005, incshare001,incshare005, incshare01
		
		print*, ' '
		print*, 'top income share'
		write(*, "(15(A16,1X))") ' Top 0.001%', ' Top 0.005%', ' Top 0.01%', ' Top 0.05%', ' Top 0.1%'
		write(*, "(143(F16.8,1X))") tincshare0001, tincshare0005, tincshare001, tincshare005, tincshare01

		print*, ' '
		print*, 'top consumption share'
		write(*, "(15(A16,1X))") ' Top 0.001%', ' Top 0.005%', ' Top 0.01%', ' Top 0.1%'
		write(*, "(143(F16.8,1X))") cshare0001, cshare0005, cshare001, cshare01
		
		print*, ' '
		print*, 'wealth by top income share'
		write(*, "(15(A16,1X))") ' Top 0.1%', ' Top 0.5%', ' Top 1%', ' Top 5%', ' Top 10%', ' Top 20%', ' Top 40%', ' Top 60%', ' Top 80%' 
		write(*, "(143(F16.8,1X))") kshare_Y01, kshare_Y05, kshare_Y1, kshare_Y5, kshare_Y10, kshare_Y20, kshare_Y40, kshare_Y60, kshare_Y80
		
		print*, ' '
		print*, 'wealth by top earning share'
		write(*, "(15(A16,1X))") ' Top 0.1%', ' Top 0.5%', ' Top 1%', ' Top 5%', ' Top 10%', ' Top 20%', ' Top 40%', ' Top 60%', ' Top 80%'
		write(*, "(143(F16.8,1X))")  kshare_E01, kshare_E05, kshare_E1, kshare_E5, kshare_E10, kshare_E20, kshare_E40, kshare_E60, kshare_E80

		print*, ' '
		print*, 'wealth LEVEL by top income share'
		write(*, "(15(A16,1X))") ' Top 0.1%', ' Top 0.5%', ' Top 1%', ' Top 5%', ' Top 10%', ' Top 20%', ' Top 40%', ' Top 60%', ' Top 80%' 
		write(*, "(143(F16.8,1X))") klevel_Y01, klevel_Y05, klevel_Y1, klevel_Y5, klevel_Y10, klevel_Y20, klevel_Y40, klevel_Y60, klevel_Y80
		write(*, "(15(A16,1X))")  '95-99%', '90-95%', '4th Q', '3rd Q', '2nd Q'
		write(*, "(143(F16.8,1X))") klevel_Y9599,klevel_Y9095, klevel_Y6080,klevel_Y4060,klevel_Y2040
		
		print*, ' '
		print*, 'wealth LEVEL by top earning share'
		write(*, "(15(A16,1X))") ' Top 0.1%', ' Top 0.5%', ' Top 1%', ' Top 5%', ' Top 10%', ' Top 20%', ' Top 40%', ' Top 60%', ' Top 80%'
		write(*, "(143(F16.8,1X))")  klevel_E01, klevel_E05, klevel_E1, klevel_E5, klevel_E10, klevel_E20, klevel_E40, klevel_E60, klevel_E80


		print*, ' '
		print*, 'Concentration and Skewness for wealth'
		write(*, "(15(A11,1X))") '99_50','90_50','Mean/median','50_30','P99','P90','P30','mean','median'
		WRITE(*,"(12(F11.4,1X))") kratio99_50,kratio90_50,kratioMM,kratio50_30,k_pct99,k_pct90,k_pct30,k_mean,k_median
		
		print*, ' '
		print*, 'Concentration and Skewness for earning'
		write(*, "(15(A11,1X))") '99_50','90_50','Mean/median','50_30','P99','P90','P30','mean','median'
		WRITE(*,"(12(F11.4,1X))") incratio99_50,incratio90_50,incratioMM,incratio50_30,inc_pct99,inc_pct90,inc_pct30,inc_mean,inc_median
		
		print*, ' '
		print*, 'Concentration and Skewness for income'
		write(*, "(15(A11,1X))") '99_50','90_50','Mean/median','50_30','P99','P90','P30','mean','median'
		WRITE(*,"(12(F11.4,1X))") tincratio99_50,tincratio90_50,tincratioMM,tincratio50_30,tinc_pct99,tinc_pct90,tinc_pct30,tinc_mean,tinc_median

		print*, ' '
		print*, 'Life cycle profile of wealth'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64','65_69','70_74','75_79','65+'
		print*, 'Single Male'
		WRITE(*,"(12(F11.4,1X))") ALONG25_30_single(1),ALONG30_35_single(1),ALONG35_40_single(1),ALONG40_45_single(1),ALONG45_50_single(1),ALONG50_55_single(1),ALONG55_60_single(1),ALONG60_65_single(1),ALONG65_70_single(1),ALONG70_75_single(1),ALONG75_80_single(1),ALONG65_MORE_single(1)
		print*, 'Single Female'
		WRITE(*,"(12(F11.4,1X))") ALONG25_30_single(2),ALONG30_35_single(2),ALONG35_40_single(2),ALONG40_45_single(2),ALONG45_50_single(2),ALONG50_55_single(2),ALONG55_60_single(2),ALONG60_65_single(2),ALONG65_70_single(2),ALONG70_75_single(2),ALONG75_80_single(2),ALONG65_MORE_single(2)
		print*, 'Couple'
		WRITE(*,"(12(F11.4,1X))") ALONG25_30_couple,ALONG30_35_couple,ALONG35_40_couple,ALONG40_45_couple,ALONG45_50_couple,ALONG50_55_couple,ALONG55_60_couple,ALONG60_65_couple,ALONG65_70_couple,ALONG70_75_couple,ALONG75_80_couple,ALONG65_MORE_couple

		print*, ' '
		print*, 'Life cycle profile of earnings'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64','65+'
		print*, 'Single Male'
		WRITE(*,"(12(F11.4,1X))") ILONG25_30_single(1),ILONG30_35_single(1),ILONG35_40_single(1),ILONG40_45_single(1),ILONG45_50_single(1),ILONG50_55_single(1),ILONG55_60_single(1),ILONG60_65_single(1),ILONG65_MORE_single(1)
		print*, 'Single Female'
		WRITE(*,"(12(F11.4,1X))") ILONG25_30_single(2),ILONG30_35_single(2),ILONG35_40_single(2),ILONG40_45_single(2),ILONG45_50_single(2),ILONG50_55_single(2),ILONG55_60_single(2),ILONG60_65_single(2),ILONG65_MORE_single(2)
		print*, 'Couple'
		WRITE(*,"(12(F11.4,1X))") ILONG25_30_couple,ILONG30_35_couple,ILONG35_40_couple,ILONG40_45_couple,ILONG45_50_couple,ILONG50_55_couple,ILONG55_60_couple,ILONG60_65_couple,ILONG65_MORE_couple

		print*, ' '
		print*, 'Life cycle profile of wage'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		print*, 'Male'
		WRITE(*,"(12(F11.4,1X))") WLONG_AGE(1,1),WLONG_AGE(2,1),WLONG_AGE(3,1),WLONG_AGE(4,1),WLONG_AGE(5,1),WLONG_AGE(6,1),WLONG_AGE(7,1),WLONG_AGE(8,1)
		print*, 'Female'
		WRITE(*,"(12(F11.4,1X))") WLONG_AGE(1,2),WLONG_AGE(2,2),WLONG_AGE(3,2),WLONG_AGE(4,2),WLONG_AGE(5,2),WLONG_AGE(6,2),WLONG_AGE(7,2),WLONG_AGE(8,2)

		print*, ' '
		print*, 'Gender Gap'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		WRITE(*,"(12(F11.4,1X))") WLONG_AGE(1,2)/WLONG_AGE(1,1),WLONG_AGE(2,2)/WLONG_AGE(2,1), WLONG_AGE(3,2)/WLONG_AGE(3,1),WLONG_AGE(4,2)/WLONG_AGE(4,1),WLONG_AGE(5,2)/WLONG_AGE(5,1), WLONG_AGE(6,2)/WLONG_AGE(6,1), WLONG_AGE(7,2)/WLONG_AGE(7,1), WLONG_AGE(8,2)/WLONG_AGE(8,1)

		print*, ' '
		print*, 'Life cycle profile of income'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64','65+'
		print*, 'Single Male'
		WRITE(*,"(12(F11.4,1X))") TILONG25_30_single(1),TILONG30_35_single(1),TILONG35_40_single(1),TILONG40_45_single(1),TILONG45_50_single(1),TILONG50_55_single(1),TILONG55_60_single(1),TILONG60_65_single(1),TILONG65_MORE_single(1)
		print*, 'Single Female'
		WRITE(*,"(12(F11.4,1X))") TILONG25_30_single(2),TILONG30_35_single(2),TILONG35_40_single(2),TILONG40_45_single(2),TILONG45_50_single(2),TILONG50_55_single(2),TILONG55_60_single(2),TILONG60_65_single(2),TILONG65_MORE_single(2)
		print*, 'Couple'
		WRITE(*,"(12(F11.4,1X))") TILONG25_30_couple,TILONG30_35_couple,TILONG35_40_couple,TILONG40_45_couple,TILONG45_50_couple,TILONG50_55_couple,TILONG55_60_couple,TILONG60_65_couple,TILONG65_MORE_couple

		
		! print*, ' '
		! print*, 'Life cycle profile of post-tax income'
		! write(*, "(15(A11,1X))") '20_24','25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64','65+'
		! print*, 'Single Male'
		! WRITE(*,"(12(F11.4,1X))") YDLONG20_25_single(1),YDLONG25_30_single(1),YDLONG30_35_single(1),YDLONG35_40_single(1),YDLONG40_45_single(1),YDLONG45_50_single(1),YDLONG50_55_single(1),YDLONG55_60_single(1),YDLONG60_65_single(1),YDLONG65_MORE_single(1)
		! print*, 'Single Female'
		! WRITE(*,"(12(F11.4,1X))") YDLONG20_25_single(2),YDLONG25_30_single(2),YDLONG30_35_single(2),YDLONG35_40_single(2),YDLONG40_45_single(2),YDLONG45_50_single(2),YDLONG50_55_single(2),YDLONG55_60_single(2),YDLONG60_65_single(2),YDLONG65_MORE_single(2)
		! print*, 'Couple'
		! WRITE(*,"(12(F11.4,1X))") YDLONG20_25_couple,YDLONG25_30_couple,YDLONG30_35_couple,YDLONG35_40_couple,YDLONG40_45_couple,YDLONG45_50_couple,YDLONG50_55_couple,YDLONG55_60_couple,YDLONG60_65_couple,YDLONG65_MORE_couple

		print*, ' '
		print*, 'Life cycle profile of participation rate'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		print*, 'Male (Married+Unmarried)'
		WRITE(*,"(12(F11.4,1X))")  labor_participation_age(1,1),labor_participation_age(2,1),labor_participation_age(3,1),labor_participation_age(4,1),labor_participation_age(5,1),labor_participation_age(6,1),labor_participation_age(7,1),labor_participation_age(8,1)
		print*, 'Female (Married+Unmarried)'
		WRITE(*,"(12(F11.4,1X))")  labor_participation_age(1,2),labor_participation_age(2,2),labor_participation_age(3,2),labor_participation_age(4,2),labor_participation_age(5,2),labor_participation_age(6,2),labor_participation_age(7,2),labor_participation_age(8,2)
		print*, 'Female (Unmarried)'
		WRITE(*,"(12(F11.4,1X))")  labor_participation_age_single(1,2),labor_participation_age_single(2,2),labor_participation_age_single(3,2),labor_participation_age_single(4,2),labor_participation_age_single(5,2),labor_participation_age_single(6,2),labor_participation_age_single(7,2),labor_participation_age_single(8,2)
		print*, 'Female (Married)'
		WRITE(*,"(12(F11.4,1X))")  labor_participation_age_couple(1,2),labor_participation_age_couple(2,2),labor_participation_age_couple(3,2),labor_participation_age_couple(4,2),labor_participation_age_couple(5,2),labor_participation_age_couple(6,2),labor_participation_age_couple(7,2),labor_participation_age_couple(8,2)

		print*, ' '
		print*, 'Life cycle profile of labor'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		print*, 'Single Male'
		WRITE(*,"(12(F11.4,1X))")  NLONG_AGE_single(1,1),NLONG_AGE_single(2,1),NLONG_AGE_single(3,1),NLONG_AGE_single(4,1),NLONG_AGE_single(5,1),NLONG_AGE_single(6,1),NLONG_AGE_single(7,1),NLONG_AGE_single(8,1)
		print*, 'Single Female'
		WRITE(*,"(12(F11.4,1X))")  NLONG_AGE_single(1,2),NLONG_AGE_single(2,2),NLONG_AGE_single(3,2),NLONG_AGE_single(4,2),NLONG_AGE_single(5,2),NLONG_AGE_single(6,2),NLONG_AGE_single(7,2),NLONG_AGE_single(8,2)
		print*, 'Married Male'
		WRITE(*,"(12(F11.4,1X))")  NLONG_AGE_couple(1,1),NLONG_AGE_couple(2,1),NLONG_AGE_couple(3,1),NLONG_AGE_couple(4,1),NLONG_AGE_couple(5,1),NLONG_AGE_couple(6,1),NLONG_AGE_couple(7,1),NLONG_AGE_couple(8,1)
		print*, 'Married Female'
		WRITE(*,"(12(F11.4,1X))")  NLONG_AGE_couple(1,2),NLONG_AGE_couple(2,2),NLONG_AGE_couple(3,2),NLONG_AGE_couple(4,2),NLONG_AGE_couple(5,2),NLONG_AGE_couple(6,2),NLONG_AGE_couple(7,2),NLONG_AGE_couple(8,2)


		print*, ' '
		print*, 'Life cycle profile of var log wage'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") var_wage_age_single(1),var_wage_age_single(2),var_wage_age_single(3),var_wage_age_single(4),var_wage_age_single(5),var_wage_age_single(6),var_wage_age_single(7),var_wage_age_single(8)
		print*, 'Couples'
		WRITE(*,"(12(F11.4,1X))") var_wage_age_couple(1),var_wage_age_couple(2),var_wage_age_couple(3),var_wage_age_couple(4),var_wage_age_couple(5),var_wage_age_couple(6),var_wage_age_couple(7),var_wage_age_couple(8)

		print*, ' '
		print*, 'Life cycle profile of var log earning'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") var_earning_age_single(1),var_earning_age_single(2),var_earning_age_single(3),var_earning_age_single(4),var_earning_age_single(5),var_earning_age_single(6),var_earning_age_single(7),var_earning_age_single(8)
		print*, 'Couples'
		WRITE(*,"(12(F11.4,1X))") var_earning_age_couple(1),var_earning_age_couple(2),var_earning_age_couple(3),var_earning_age_couple(4),var_earning_age_couple(5),var_earning_age_couple(6),var_earning_age_couple(7),var_earning_age_couple(8)
		print*, 'Couples_HH'
		WRITE(*,"(12(F11.4,1X))") var_earning_age_couple_HH(1),var_earning_age_couple_HH(2),var_earning_age_couple_HH(3),var_earning_age_couple_HH(4),var_earning_age_couple_HH(5),var_earning_age_couple_HH(6),var_earning_age_couple_HH(7),var_earning_age_couple_HH(8)
		print*, 'All'
		WRITE(*,"(12(F11.4,1X))") var_earning_age(1),var_earning_age(2),var_earning_age(3),var_earning_age(4),var_earning_age(5),var_earning_age(6),var_earning_age(7),var_earning_age(8)

		print*, ' '
		print*, 'Life cycle profile of var log consumption'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") var_cons_age_single(1),var_cons_age_single(2),var_cons_age_single(3),var_cons_age_single(4),var_cons_age_single(5),var_cons_age_single(6),var_cons_age_single(7),var_cons_age_single(8)
		print*, 'Couples'
		WRITE(*,"(12(F11.4,1X))") var_cons_age_couple(1),var_cons_age_couple(2),var_cons_age_couple(3),var_cons_age_couple(4),var_cons_age_couple(5),var_cons_age_couple(6),var_cons_age_couple(7),var_cons_age_couple(8)
		print*, 'All'
		WRITE(*,"(12(F11.4,1X))") var_cons_age(1),var_cons_age(2),var_cons_age(3),var_cons_age(4),var_cons_age(5),var_cons_age(6),var_cons_age(7),var_cons_age(8)

		print*, ' '
		print*, 'Life cycle profile of insurance from wage shock'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_cons_shock_value_single(1),ageprofile_insurance_cons_shock_value_single(2),ageprofile_insurance_cons_shock_value_single(3),ageprofile_insurance_cons_shock_value_single(4),ageprofile_insurance_cons_shock_value_single(5),ageprofile_insurance_cons_shock_value_single(6),ageprofile_insurance_cons_shock_value_single(7)
		print*, 'Couples'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_cons_shock_value_couple(1),ageprofile_insurance_cons_shock_value_couple(2),ageprofile_insurance_cons_shock_value_couple(3),ageprofile_insurance_cons_shock_value_couple(4),ageprofile_insurance_cons_shock_value_couple(5),ageprofile_insurance_cons_shock_value_couple(6),ageprofile_insurance_cons_shock_value_couple(7)
		print*, ' '
		print*, 'Life cycle profile of insurance from earning shock'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_cons_value_single(1),ageprofile_insurance_cons_value_single(2),ageprofile_insurance_cons_value_single(3),ageprofile_insurance_cons_value_single(4),ageprofile_insurance_cons_value_single(5),ageprofile_insurance_cons_value_single(6),ageprofile_insurance_cons_value_single(7)
		print*, 'Couples'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_cons_value_couple(1),ageprofile_insurance_cons_value_couple(2),ageprofile_insurance_cons_value_couple(3),ageprofile_insurance_cons_value_couple(4),ageprofile_insurance_cons_value_couple(5),ageprofile_insurance_cons_value_couple(6),ageprofile_insurance_cons_value_couple(7)

		print*, ' '
		print*, 'Income Partition (labor, capital, transfer) '  ! check Kuhn & Victor 2015 OR Piketty & Saez 2012
		write(*, "(15(A11,1X))") 'Average', 'Top 1%', '95-99%', '90-95%'
		WRITE(*,"(12(F11.4,1X))") earning_share_avg,earning_share1,earning_share9599,earning_share9095
		WRITE(*,"(12(F11.4,1X))") kincome_share_avg,kincome_share1,kincome_share9599,kincome_share9095
		WRITE(*,"(12(F11.4,1X))") trans_share_avg,trans_share1,trans_share9599,trans_share9095
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share_avg-1.0),22+5*(age_share1-1.0),22+5*(age_share9599-1.0),22+5*(age_share9095-1.0)
		write(*, "(15(A11,1X))") 'Q5', 'Q4', 'Q3', 'Q2', 'Q1'
		WRITE(*,"(12(F11.4,1X))") earning_share5q,earning_share4q,earning_share3q,earning_share2q, earning_share1q
		WRITE(*,"(12(F11.4,1X))") kincome_share5q,kincome_share4q,kincome_share3q,kincome_share2q, kincome_share1q
		WRITE(*,"(12(F11.4,1X))") trans_share5q,trans_share4q,trans_share3q,trans_share2q, trans_share1q
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share5q-1.0),22+5*(age_share4q-1.0),22+5*(age_share3q-1.0),22+5*(age_share2q-1.0), 22+5*(age_share1q-1.0)
		write(*, "(15(A11,1X))") '1-5%', '5-10%'
		WRITE(*,"(12(F11.4,1X))") earning_share0105,earning_share0510
		WRITE(*,"(12(F11.4,1X))") kincome_share0105,kincome_share0510
		WRITE(*,"(12(F11.4,1X))") trans_share0105,trans_share0510
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share0105-1.0),22+5*(age_share0510-1.0)
		
		print*, ' '
		print*, 'Synthetic Saving rates '
		write(*, "(15(A11,1X))") 'Average', 'Bottom 90%', 'Top 10%', 'Top 5%', 'Top 1%','Top 0.1%', 'Top 10-1%', 'Top 10-5%', 'Top 5-1%', 'Top 1-0.1%'
		WRITE(*,"(12(F11.4,1X))") synsavingrate_avg, synsavingrate_bot90pct, synsavingrate_10pct, synsavingrate_5pct,synsavingrate_1pct,synsavingrate_01pct,synsavingrate_10_1pct,synsavingrate_10_5pct,synsavingrate_5_1pct,synsavingrate_1_01pct
		
		print*, ' '
		print*, 'Consumption by income ranking'
		write(*,"(15(A11,1X))") 'Top 0.1%', 'Top 0.5%', 'Top 1%', 'Top 5%', 'Top 10%', 'Top 20%', 'Top 40%', 'Top 60%', 'Top 80%'
		write(*,"(12(F11.4,1X))") cshare_tinc01, cshare_tinc05, cshare_tinc1, cshare_tinc5, cshare_tinc10, cshare_tinc20, cshare_tinc40, cshare_tinc60, cshare_tinc80
		

        print*, ' '
		print*, 'Bequest Moment (Hurd and Smith 2002, PSID: 1968-2003)'
		write(*, "(15(A11,1X))") 'Beq_K_raito','Beq98','Beq95', 'Beq90', 'Beq80', 'Beq70', 'Beq60', 'Beq50'
		WRITE(*,"(12(F11.4,1X))") beq_wealth_ratio,Beq98,Beq95, Beq90, Beq80, Beq70, Beq60, Beq50
		write(*, "(15(A11,1X))") 'Beq40','Beq30', 'Beq20', 'Beq10'
		WRITE(*,"(12(F11.4,1X))") Beq40, Beq30, Beq20, Beq10

		

		print*, ' '
		print*, 'implied MTR on capital income for someone on the edge of the top 1%, 10%'
		write(*,"(15(A11,1X))") 'MTR1', 'MTR10'
		write(*,"(12(F11.4,1X))") MTR1, MTR10


		print*, ' '
		print*, 'Variance of log earnings =', incvar

		print*, ' '
		print*, 'inheritance Distribution (Hendricks 2007) '
		write(*, "(15(A11,1X))") 'Mean','Gini','0-50(%)','50-70(%)', '70-80(%)', '80-90(%)', '90-95(%)', '95-99(%)', '99-100(%)'
		WRITE(*,"(12(F11.4,1X))") AggBeq,beq_gini,bshare0_50*100,bshare50_70*100,bshare70_80*100,bshare80_90*100,bshare90_95*100,bshare95_99*100,bshare99_100*100

		print*, ' '
		print*, 'tax_penalty for couple'
		write(*,"(11(F8.5,1X))") couple_taxpenalty(1,1), couple_taxpenalty(1,2),couple_taxpenalty(1,3),couple_taxpenalty(1,4)
		write(*,"(11(F8.5,1X))") couple_taxpenalty(2,1), couple_taxpenalty(2,2),couple_taxpenalty(2,3),couple_taxpenalty(2,4)
		write(*,"(11(F8.5,1X))") couple_taxpenalty(3,1), couple_taxpenalty(3,2),couple_taxpenalty(3,3),couple_taxpenalty(3,4)
		write(*,"(11(F8.5,1X))") couple_taxpenalty(4,1), couple_taxpenalty(4,2),couple_taxpenalty(4,3),couple_taxpenalty(4,4)

		print*, ' '
		print*, 'Percent of total household'
		write(*, "(15(A11,1X))") 'tax', 'subsidy','MFS','weight_MFS'
		WRITE(*,"(12(F11.4,1X))") prop_family_tax, prop_family_subsidy, popu_MFS, weight_MFS
		print*, 'Average Tax'
		write(*, "(15(A11,1X))") 'avg_tax','sd_tax', 'avg_subsidy', 'sd_subsidy'
		WRITE(*,"(12(F11.4,1X))") avg_family_tax, sd_family_tax, avg_family_subsidy, sd_family_subsidy

		print*, ' '
		print*, 'Average Marriage Tax/Subsidy by Earnings Ratio of female to male'
		print*, 'Average marriage tax'
		DO i=1,5
			WRITE(*,"(12(F11.4,1X))") avg_earnratio_tax(i,1),avg_earnratio_tax(i,2), avg_earnratio_tax(i,3), avg_earnratio_tax(i,4),avg_earnratio_tax(i,5)
		END DO 
		print*, 'Average marriage subsidy'
		DO i=1,5
			WRITE(*,"(12(F11.4,1X))") avg_earnratio_subsidy(i,1),avg_earnratio_subsidy(i,2), avg_earnratio_subsidy(i,3), avg_earnratio_subsidy(i,4),avg_earnratio_subsidy(i,5)
		END DO
		print*, 'Proportion with marriage tax'	
		DO i=1,5
			WRITE(*,"(12(F11.4,1X))") prop_earnratio_tax(i,1),prop_earnratio_tax(i,2), prop_earnratio_tax(i,3), prop_earnratio_tax(i,4),prop_earnratio_tax(i,5)
		END DO	 
		print*, 'Proportion with marriage subsidy'	
		DO i=1,5
			WRITE(*,"(12(F11.4,1X))") prop_earnratio_subsidy(i,1),prop_earnratio_subsidy(i,2), prop_earnratio_subsidy(i,3), prop_earnratio_subsidy(i,4),prop_earnratio_subsidy(i,5)
		END DO

		! write(*, "(15(A11,1X))") 'avg tax','avg subsidy','prop tax','prop subsidy'
		! print*, '<0.25'
		! WRITE(*,"(12(F11.4,1X))") avg_earnratio_tax(1),avg_earnratio_subsidy(1), prop_earnratio_tax(1), prop_earnratio_subsidy(1)
		! print*, '0.25<e<0.5'
		! WRITE(*,"(12(F11.4,1X))") avg_earnratio_tax(2),avg_earnratio_subsidy(2), prop_earnratio_tax(2), prop_earnratio_subsidy(2)
		! print*, '0.5<e<0.75'
		! WRITE(*,"(12(F11.4,1X))") avg_earnratio_tax(3),avg_earnratio_subsidy(3), prop_earnratio_tax(3), prop_earnratio_subsidy(3)
		! print*, '0.75<e<1.0'
		! WRITE(*,"(12(F11.4,1X))") avg_earnratio_tax(4),avg_earnratio_subsidy(4), prop_earnratio_tax(4), prop_earnratio_subsidy(4)
		! print*, '>1.0'
		! WRITE(*,"(12(F11.4,1X))") avg_earnratio_tax(5),avg_earnratio_subsidy(5), prop_earnratio_tax(5), prop_earnratio_subsidy(5)

		print*, ' '
		print*, 'welfare'
		write(*,"(11(A8,1X))") 'single_M','single_F','marry_M','marry_F','Avg_couple'
		WRITE(*,"(12(F11.4,1X))") single_male_welfare, single_female_welfare, married_male_welfare, married_female_welfare, total_couple_welfare
		write(*,"(11(A8,1X))") 'coup_welfare'
		WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(1,1), avg_couple_welfare(1,2),  avg_couple_welfare(1,3), avg_couple_welfare(1,4)
		WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(2,1), avg_couple_welfare(2,2),  avg_couple_welfare(2,3), avg_couple_welfare(2,4)
		WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(3,1), avg_couple_welfare(3,2),  avg_couple_welfare(3,3), avg_couple_welfare(3,4)
		WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(4,1), avg_couple_welfare(4,2),  avg_couple_welfare(4,3), avg_couple_welfare(4,4)
		
		! print*, ' '
		! print*, 'welfare decompose'
		! print*, 'single male'
		! print*, 'average consumption of quintiles'
		! DO AGE=1,MAXAGE 
		! 	WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold(AGE,1,1),single_avg_cons_incomethreshold(AGE,2,1),single_avg_cons_incomethreshold(AGE,3,1),single_avg_cons_incomethreshold(AGE,4,1),single_avg_cons_incomethreshold(AGE,5,1)
		! END DO 
		! print*, 'average labor of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold(AGE,1,1),single_avg_labor_incomethreshold(AGE,2,1),single_avg_labor_incomethreshold(AGE,3,1),single_avg_labor_incomethreshold(AGE,4,1),single_avg_labor_incomethreshold(AGE,5,1)
		! END DO 
		! print*, 'average welfare of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold(AGE,1,1), single_avg_val_incomethreshold(AGE,2,1),single_avg_val_incomethreshold(AGE,3,1),single_avg_val_incomethreshold(AGE,4,1),single_avg_val_incomethreshold(AGE,5,1)
		! END DO 

		! print*, ' '
		! print*, 'single female'
		! print*, 'average consumption of quintiles'
		! DO AGE=1,MAXAGE 
		! 	WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold(AGE,1,2),single_avg_cons_incomethreshold(AGE,2,2),single_avg_cons_incomethreshold(AGE,3,2),single_avg_cons_incomethreshold(AGE,4,2),single_avg_cons_incomethreshold(AGE,5,2)
		! END DO 
		! print*, 'average labor of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold(AGE,1,2),single_avg_labor_incomethreshold(AGE,2,2),single_avg_labor_incomethreshold(AGE,3,2),single_avg_labor_incomethreshold(AGE,4,2),single_avg_labor_incomethreshold(AGE,5,2)
		! END DO 
		! print*, 'average welfare of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold(AGE,1,2), single_avg_val_incomethreshold(AGE,2,2),single_avg_val_incomethreshold(AGE,3,2),single_avg_val_incomethreshold(AGE,4,2),single_avg_val_incomethreshold(AGE,5,2)
		! END DO 

		! print*, ' '
		! print*, 'Married male'
		! print*, 'average consumption of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold(AGE,1,1),couple_avg_cons_incomethreshold(AGE,2,1),couple_avg_cons_incomethreshold(AGE,3,1),couple_avg_cons_incomethreshold(AGE,4,1),couple_avg_cons_incomethreshold(AGE,5,1)
		! END DO 
		! print*, 'average labor of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold(AGE,1,1),couple_avg_labor_incomethreshold(AGE,2,1),couple_avg_labor_incomethreshold(AGE,3,1),couple_avg_labor_incomethreshold(AGE,4,1),couple_avg_labor_incomethreshold(AGE,5,1)
		! END DO 
		! print*, 'average welfare of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold(AGE,1,1), couple_avg_val_incomethreshold(AGE,2,1), couple_avg_val_incomethreshold(AGE,3,1), couple_avg_val_incomethreshold(AGE,4,1), couple_avg_val_incomethreshold(AGE,5,1)
		! END DO 

		! print*, ' '
		! print*, 'Married female'
		! print*, 'average consumption of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold(AGE,1,2),couple_avg_cons_incomethreshold(AGE,2,2),couple_avg_cons_incomethreshold(AGE,3,2),couple_avg_cons_incomethreshold(AGE,4,2),couple_avg_cons_incomethreshold(AGE,5,2)
		! END DO 
		! print*, 'average labor of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold(AGE,1,2),couple_avg_labor_incomethreshold(AGE,2,2),couple_avg_labor_incomethreshold(AGE,3,2),couple_avg_labor_incomethreshold(AGE,4,2),couple_avg_labor_incomethreshold(AGE,5,2)
		! END DO 
		! print*, 'average welfare of quintiles'
		! DO AGE=1,MAXAGE
		! 	WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold(AGE,1,2), couple_avg_val_incomethreshold(AGE,2,2), couple_avg_val_incomethreshold(AGE,3,2), couple_avg_val_incomethreshold(AGE,4,2), couple_avg_val_incomethreshold(AGE,5,2)
		! END DO 

		print*, ' '
		print*, 'welfare decompose'
		print*, 'single male'
		print*, 'average consumption of quintiles'
		 
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_21_35(1,1),single_avg_cons_incomethreshold_21_35(2,1),single_avg_cons_incomethreshold_21_35(3,1),single_avg_cons_incomethreshold_21_35(4,1),single_avg_cons_incomethreshold_21_35(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_36_50(1,1),single_avg_cons_incomethreshold_36_50(2,1),single_avg_cons_incomethreshold_36_50(3,1),single_avg_cons_incomethreshold_36_50(4,1),single_avg_cons_incomethreshold_36_50(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_51_65(1,1),single_avg_cons_incomethreshold_51_65(2,1),single_avg_cons_incomethreshold_51_65(3,1),single_avg_cons_incomethreshold_51_65(4,1),single_avg_cons_incomethreshold_51_65(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_66_80(1,1),single_avg_cons_incomethreshold_66_80(2,1),single_avg_cons_incomethreshold_66_80(3,1),single_avg_cons_incomethreshold_66_80(4,1),single_avg_cons_incomethreshold_66_80(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_81_100(1,1),single_avg_cons_incomethreshold_81_100(2,1),single_avg_cons_incomethreshold_81_100(3,1),single_avg_cons_incomethreshold_81_100(4,1),single_avg_cons_incomethreshold_81_100(5,1)

			WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_working(1,1),change_bench_single_cons_incomethreshold_working(2,1),change_bench_single_cons_incomethreshold_working(3,1),change_bench_single_cons_incomethreshold_working(4,1),change_bench_single_cons_incomethreshold_working(5,1)
			WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_retire(1,1),change_bench_single_cons_incomethreshold_retire(2,1),change_bench_single_cons_incomethreshold_retire(3,1),change_bench_single_cons_incomethreshold_retire(4,1),change_bench_single_cons_incomethreshold_retire(5,1)

		print*, 'average labor of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold_21_35(1,1),single_avg_labor_incomethreshold_21_35(2,1),single_avg_labor_incomethreshold_21_35(3,1),single_avg_labor_incomethreshold_21_35(4,1),single_avg_labor_incomethreshold_21_35(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold_36_50(1,1),single_avg_labor_incomethreshold_36_50(2,1),single_avg_labor_incomethreshold_36_50(3,1),single_avg_labor_incomethreshold_36_50(4,1),single_avg_labor_incomethreshold_36_50(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold_51_65(1,1),single_avg_labor_incomethreshold_51_65(2,1),single_avg_labor_incomethreshold_51_65(3,1),single_avg_labor_incomethreshold_51_65(4,1),single_avg_labor_incomethreshold_51_65(5,1)

			WRITE(*,"(12(F11.4,1X))") change_bench_single_labor_incomethreshold_working(1,1),change_bench_single_labor_incomethreshold_working(2,1),change_bench_single_labor_incomethreshold_working(3,1),change_bench_single_labor_incomethreshold_working(4,1),change_bench_single_labor_incomethreshold_working(5,1)
			
		 
		print*, 'average welfare of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_21_35(1,1),single_avg_val_incomethreshold_21_35(2,1),single_avg_val_incomethreshold_21_35(3,1),single_avg_val_incomethreshold_21_35(4,1),single_avg_val_incomethreshold_21_35(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_36_50(1,1),single_avg_val_incomethreshold_36_50(2,1),single_avg_val_incomethreshold_36_50(3,1),single_avg_val_incomethreshold_36_50(4,1),single_avg_val_incomethreshold_36_50(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_51_65(1,1),single_avg_val_incomethreshold_51_65(2,1),single_avg_val_incomethreshold_51_65(3,1),single_avg_val_incomethreshold_51_65(4,1),single_avg_val_incomethreshold_51_65(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_66_80(1,1),single_avg_val_incomethreshold_66_80(2,1),single_avg_val_incomethreshold_66_80(3,1),single_avg_val_incomethreshold_66_80(4,1),single_avg_val_incomethreshold_66_80(5,1)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_81_100(1,1),single_avg_val_incomethreshold_81_100(2,1),single_avg_val_incomethreshold_81_100(3,1),single_avg_val_incomethreshold_81_100(4,1),single_avg_val_incomethreshold_81_100(5,1)

			WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_working(1,1),change_bench_single_val_incomethreshold_working(2,1),change_bench_single_val_incomethreshold_working(3,1),change_bench_single_val_incomethreshold_working(4,1),change_bench_single_val_incomethreshold_working(5,1)
			WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_retire(1,1),change_bench_single_val_incomethreshold_retire(2,1),change_bench_single_val_incomethreshold_retire(3,1),change_bench_single_val_incomethreshold_retire(4,1),change_bench_single_val_incomethreshold_retire(5,1)

			! print*,'sum(change_bench_single_val(1:RETAGE-1,i,1))',sum(change_bench_single_val(1:RETAGE-1,1,1)),sum(change_bench_single_val(1:RETAGE-1,2,1)),sum(change_bench_single_val(1:RETAGE-1,3,1)),sum(change_bench_single_val(1:RETAGE-1,4,1)),sum(change_bench_single_val(1:RETAGE-1,5,1))
			! print*,'sum(bench_singleYW_incomethreshold(1:RETAGE-1,i,1))',sum(bench_singleYW_incomethreshold(1:RETAGE-1,1,1)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,2,1)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,3,1)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,4,1)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,5,1))

		print*, 'change of lifetime consumption of quintiles'

			WRITE(*,"(12(F11.4,1X))") cons_change_single_male_working(1),cons_change_single_male_working(2),cons_change_single_male_working(3),cons_change_single_male_working(4),cons_change_single_male_working(5)
			WRITE(*,"(12(F11.4,1X))") cons_change_single_male_retire(1),cons_change_single_male_retire(2),cons_change_single_male_retire(3),cons_change_single_male_retire(4),cons_change_single_male_retire(5)


		print*, ' '
		print*, 'single female'
		print*, 'average consumption of quintiles'

			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_21_35(1,2),single_avg_cons_incomethreshold_21_35(2,2),single_avg_cons_incomethreshold_21_35(3,2),single_avg_cons_incomethreshold_21_35(4,2),single_avg_cons_incomethreshold_21_35(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_36_50(1,2),single_avg_cons_incomethreshold_36_50(2,2),single_avg_cons_incomethreshold_36_50(3,2),single_avg_cons_incomethreshold_36_50(4,2),single_avg_cons_incomethreshold_36_50(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_51_65(1,2),single_avg_cons_incomethreshold_51_65(2,2),single_avg_cons_incomethreshold_51_65(3,2),single_avg_cons_incomethreshold_51_65(4,2),single_avg_cons_incomethreshold_51_65(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_66_80(1,2),single_avg_cons_incomethreshold_66_80(2,2),single_avg_cons_incomethreshold_66_80(3,2),single_avg_cons_incomethreshold_66_80(4,2),single_avg_cons_incomethreshold_66_80(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_cons_incomethreshold_81_100(1,2),single_avg_cons_incomethreshold_81_100(2,2),single_avg_cons_incomethreshold_81_100(3,2),single_avg_cons_incomethreshold_81_100(4,2),single_avg_cons_incomethreshold_81_100(5,2) 
		
			WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_working(1,2),change_bench_single_cons_incomethreshold_working(2,2),change_bench_single_cons_incomethreshold_working(3,2),change_bench_single_cons_incomethreshold_working(4,2),change_bench_single_cons_incomethreshold_working(5,2)
			WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_retire(1,2),change_bench_single_cons_incomethreshold_retire(2,2),change_bench_single_cons_incomethreshold_retire(3,2),change_bench_single_cons_incomethreshold_retire(4,2),change_bench_single_cons_incomethreshold_retire(5,2)

		print*, 'average labor of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold_21_35(1,2),single_avg_labor_incomethreshold_21_35(2,2),single_avg_labor_incomethreshold_21_35(3,2),single_avg_labor_incomethreshold_21_35(4,2),single_avg_labor_incomethreshold_21_35(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold_36_50(1,2),single_avg_labor_incomethreshold_36_50(2,2),single_avg_labor_incomethreshold_36_50(3,2),single_avg_labor_incomethreshold_36_50(4,2),single_avg_labor_incomethreshold_36_50(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_labor_incomethreshold_51_65(1,2),single_avg_labor_incomethreshold_51_65(2,2),single_avg_labor_incomethreshold_51_65(3,2),single_avg_labor_incomethreshold_51_65(4,2),single_avg_labor_incomethreshold_51_65(5,2)

			WRITE(*,"(12(F11.4,1X))") change_bench_single_labor_incomethreshold_working(1,2),change_bench_single_labor_incomethreshold_working(2,2),change_bench_single_labor_incomethreshold_working(3,2),change_bench_single_labor_incomethreshold_working(4,2),change_bench_single_labor_incomethreshold_working(5,2)
			
		print*, 'average welfare of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_21_35(1,2),single_avg_val_incomethreshold_21_35(2,2),single_avg_val_incomethreshold_21_35(3,2),single_avg_val_incomethreshold_21_35(4,2),single_avg_val_incomethreshold_21_35(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_36_50(1,2),single_avg_val_incomethreshold_36_50(2,2),single_avg_val_incomethreshold_36_50(3,2),single_avg_val_incomethreshold_36_50(4,2),single_avg_val_incomethreshold_36_50(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_51_65(1,2),single_avg_val_incomethreshold_51_65(2,2),single_avg_val_incomethreshold_51_65(3,2),single_avg_val_incomethreshold_51_65(4,2),single_avg_val_incomethreshold_51_65(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_66_80(1,2),single_avg_val_incomethreshold_66_80(2,2),single_avg_val_incomethreshold_66_80(3,2),single_avg_val_incomethreshold_66_80(4,2),single_avg_val_incomethreshold_66_80(5,2)
			! WRITE(*,"(12(F11.4,1X))") single_avg_val_incomethreshold_81_100(1,2),single_avg_val_incomethreshold_81_100(2,2),single_avg_val_incomethreshold_81_100(3,2),single_avg_val_incomethreshold_81_100(4,2),single_avg_val_incomethreshold_81_100(5,2)

			WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_working(1,2),change_bench_single_val_incomethreshold_working(2,2),change_bench_single_val_incomethreshold_working(3,2),change_bench_single_val_incomethreshold_working(4,2),change_bench_single_val_incomethreshold_working(5,2)
			WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_retire(1,2),change_bench_single_val_incomethreshold_retire(2,2),change_bench_single_val_incomethreshold_retire(3,2),change_bench_single_val_incomethreshold_retire(4,2),change_bench_single_val_incomethreshold_retire(5,2)
			
			! print*,'sum(change_bench_single_val(1:RETAGE-1,i,2))',sum(change_bench_single_val(1:RETAGE-1,1,2)),sum(change_bench_single_val(1:RETAGE-1,2,2)),sum(change_bench_single_val(1:RETAGE-1,3,2)),sum(change_bench_single_val(1:RETAGE-1,4,2)),sum(change_bench_single_val(1:RETAGE-1,5,2))
			! print*,'sum(bench_singleYW_incomethreshold(1:RETAGE-1,i,2))',sum(bench_singleYW_incomethreshold(1:RETAGE-1,1,2)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,2,2)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,3,2)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,4,2)),sum(bench_singleYW_incomethreshold(1:RETAGE-1,5,2))

		print*, 'change of lifetime consumption of quintiles'
			WRITE(*,"(12(F11.4,1X))") cons_change_single_female_working(1),cons_change_single_female_working(2),cons_change_single_female_working(3),cons_change_single_female_working(4),cons_change_single_female_working(5)
			WRITE(*,"(12(F11.4,1X))") cons_change_single_female_retire(1),cons_change_single_female_retire(2),cons_change_single_female_retire(3),cons_change_single_female_retire(4),cons_change_single_female_retire(5)


		print*, ' '
		print*, 'Married male'
		print*, 'average consumption of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_21_35(1,1),couple_avg_cons_incomethreshold_21_35(2,1),couple_avg_cons_incomethreshold_21_35(3,1),couple_avg_cons_incomethreshold_21_35(4,1),couple_avg_cons_incomethreshold_21_35(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_36_50(1,1),couple_avg_cons_incomethreshold_36_50(2,1),couple_avg_cons_incomethreshold_36_50(3,1),couple_avg_cons_incomethreshold_36_50(4,1),couple_avg_cons_incomethreshold_36_50(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_51_65(1,1),couple_avg_cons_incomethreshold_51_65(2,1),couple_avg_cons_incomethreshold_51_65(3,1),couple_avg_cons_incomethreshold_51_65(4,1),couple_avg_cons_incomethreshold_51_65(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_66_80(1,1),couple_avg_cons_incomethreshold_66_80(2,1),couple_avg_cons_incomethreshold_66_80(3,1),couple_avg_cons_incomethreshold_66_80(4,1),couple_avg_cons_incomethreshold_66_80(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_81_100(1,1),couple_avg_cons_incomethreshold_81_100(2,1),couple_avg_cons_incomethreshold_81_100(3,1),couple_avg_cons_incomethreshold_81_100(4,1),couple_avg_cons_incomethreshold_81_100(5,1)

			WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_working(1,1),change_bench_couple_cons_incomethreshold_working(2,1),change_bench_couple_cons_incomethreshold_working(3,1),change_bench_couple_cons_incomethreshold_working(4,1),change_bench_couple_cons_incomethreshold_working(5,1)
			WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_retire(1,1),change_bench_couple_cons_incomethreshold_retire(2,1),change_bench_couple_cons_incomethreshold_retire(3,1),change_bench_couple_cons_incomethreshold_retire(4,1),change_bench_couple_cons_incomethreshold_retire(5,1)

		print*, 'average labor of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold_21_35(1,1),couple_avg_labor_incomethreshold_21_35(2,1),couple_avg_labor_incomethreshold_21_35(3,1),couple_avg_labor_incomethreshold_21_35(4,1),couple_avg_labor_incomethreshold_21_35(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold_36_50(1,1),couple_avg_labor_incomethreshold_36_50(2,1),couple_avg_labor_incomethreshold_36_50(3,1),couple_avg_labor_incomethreshold_36_50(4,1),couple_avg_labor_incomethreshold_36_50(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold_51_65(1,1),couple_avg_labor_incomethreshold_51_65(2,1),couple_avg_labor_incomethreshold_51_65(3,1),couple_avg_labor_incomethreshold_51_65(4,1),couple_avg_labor_incomethreshold_51_65(5,1)

			WRITE(*,"(12(F11.4,1X))") change_bench_couple_labor_incomethreshold_working(1,1),change_bench_couple_labor_incomethreshold_working(2,1),change_bench_couple_labor_incomethreshold_working(3,1),change_bench_couple_labor_incomethreshold_working(4,1),change_bench_couple_labor_incomethreshold_working(5,1)

		print*, 'average welfare of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_21_35(1,1),couple_avg_val_incomethreshold_21_35(2,1),couple_avg_val_incomethreshold_21_35(3,1),couple_avg_val_incomethreshold_21_35(4,1),couple_avg_val_incomethreshold_21_35(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_36_50(1,1),couple_avg_val_incomethreshold_36_50(2,1),couple_avg_val_incomethreshold_36_50(3,1),couple_avg_val_incomethreshold_36_50(4,1),couple_avg_val_incomethreshold_36_50(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_51_65(1,1),couple_avg_val_incomethreshold_51_65(2,1),couple_avg_val_incomethreshold_51_65(3,1),couple_avg_val_incomethreshold_51_65(4,1),couple_avg_val_incomethreshold_51_65(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_66_80(1,1),couple_avg_val_incomethreshold_66_80(2,1),couple_avg_val_incomethreshold_66_80(3,1),couple_avg_val_incomethreshold_66_80(4,1),couple_avg_val_incomethreshold_66_80(5,1)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_81_100(1,1),couple_avg_val_incomethreshold_81_100(2,1),couple_avg_val_incomethreshold_81_100(3,1),couple_avg_val_incomethreshold_81_100(4,1),couple_avg_val_incomethreshold_81_100(5,1)

			WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_working(1,1),change_bench_couple_val_incomethreshold_working(2,1),change_bench_couple_val_incomethreshold_working(3,1),change_bench_couple_val_incomethreshold_working(4,1),change_bench_couple_val_incomethreshold_working(5,1)
			WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_retire(1,1),change_bench_couple_val_incomethreshold_retire(2,1),change_bench_couple_val_incomethreshold_retire(3,1),change_bench_couple_val_incomethreshold_retire(4,1),change_bench_couple_val_incomethreshold_retire(5,1)

		print*, 'change of lifetime consumption of quintiles'
			
			WRITE(*,"(12(F11.4,1X))") cons_change_couple_male_working(1),cons_change_couple_male_working(2),cons_change_couple_male_working(3),cons_change_couple_male_working(4),cons_change_couple_male_working(5)
			WRITE(*,"(12(F11.4,1X))") cons_change_couple_male_retire(1),cons_change_couple_male_retire(2),cons_change_couple_male_retire(3),cons_change_couple_male_retire(4),cons_change_couple_male_retire(5)


		print*, ' '
		print*, 'Married female'
		print*, 'average consumption of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_21_35(1,2),couple_avg_cons_incomethreshold_21_35(2,2),couple_avg_cons_incomethreshold_21_35(3,2),couple_avg_cons_incomethreshold_21_35(4,2),couple_avg_cons_incomethreshold_21_35(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_36_50(1,2),couple_avg_cons_incomethreshold_36_50(2,2),couple_avg_cons_incomethreshold_36_50(3,2),couple_avg_cons_incomethreshold_36_50(4,2),couple_avg_cons_incomethreshold_36_50(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_51_65(1,2),couple_avg_cons_incomethreshold_51_65(2,2),couple_avg_cons_incomethreshold_51_65(3,2),couple_avg_cons_incomethreshold_51_65(4,2),couple_avg_cons_incomethreshold_51_65(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_66_80(1,2),couple_avg_cons_incomethreshold_66_80(2,2),couple_avg_cons_incomethreshold_66_80(3,2),couple_avg_cons_incomethreshold_66_80(4,2),couple_avg_cons_incomethreshold_66_80(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_cons_incomethreshold_81_100(1,2),couple_avg_cons_incomethreshold_81_100(2,2),couple_avg_cons_incomethreshold_81_100(3,2),couple_avg_cons_incomethreshold_81_100(4,2),couple_avg_cons_incomethreshold_81_100(5,2)

			WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_working(1,2),change_bench_couple_cons_incomethreshold_working(2,2),change_bench_couple_cons_incomethreshold_working(3,2),change_bench_couple_cons_incomethreshold_working(4,2),change_bench_couple_cons_incomethreshold_working(5,2)
			WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_retire(1,2),change_bench_couple_cons_incomethreshold_retire(2,2),change_bench_couple_cons_incomethreshold_retire(3,2),change_bench_couple_cons_incomethreshold_retire(4,2),change_bench_couple_cons_incomethreshold_retire(5,2)

		print*, 'average labor of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold_21_35(1,2),couple_avg_labor_incomethreshold_21_35(2,2),couple_avg_labor_incomethreshold_21_35(3,2),couple_avg_labor_incomethreshold_21_35(4,2),couple_avg_labor_incomethreshold_21_35(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold_36_50(1,2),couple_avg_labor_incomethreshold_36_50(2,2),couple_avg_labor_incomethreshold_36_50(3,2),couple_avg_labor_incomethreshold_36_50(4,2),couple_avg_labor_incomethreshold_36_50(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_labor_incomethreshold_51_65(1,2),couple_avg_labor_incomethreshold_51_65(2,2),couple_avg_labor_incomethreshold_51_65(3,2),couple_avg_labor_incomethreshold_51_65(4,2),couple_avg_labor_incomethreshold_51_65(5,2)

			WRITE(*,"(12(F11.4,1X))") change_bench_couple_labor_incomethreshold_working(1,2),change_bench_couple_labor_incomethreshold_working(2,2),change_bench_couple_labor_incomethreshold_working(3,2),change_bench_couple_labor_incomethreshold_working(4,2),change_bench_couple_labor_incomethreshold_working(5,2)

		print*, 'average welfare of quintiles'
		
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_21_35(1,2),couple_avg_val_incomethreshold_21_35(2,2),couple_avg_val_incomethreshold_21_35(3,2),couple_avg_val_incomethreshold_21_35(4,2),couple_avg_val_incomethreshold_21_35(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_36_50(1,2),couple_avg_val_incomethreshold_36_50(2,2),couple_avg_val_incomethreshold_36_50(3,2),couple_avg_val_incomethreshold_36_50(4,2),couple_avg_val_incomethreshold_36_50(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_51_65(1,2),couple_avg_val_incomethreshold_51_65(2,2),couple_avg_val_incomethreshold_51_65(3,2),couple_avg_val_incomethreshold_51_65(4,2),couple_avg_val_incomethreshold_51_65(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_66_80(1,2),couple_avg_val_incomethreshold_66_80(2,2),couple_avg_val_incomethreshold_66_80(3,2),couple_avg_val_incomethreshold_66_80(4,2),couple_avg_val_incomethreshold_66_80(5,2)
			! WRITE(*,"(12(F11.4,1X))") couple_avg_val_incomethreshold_81_100(1,2),couple_avg_val_incomethreshold_81_100(2,2),couple_avg_val_incomethreshold_81_100(3,2),couple_avg_val_incomethreshold_81_100(4,2),couple_avg_val_incomethreshold_81_100(5,2)

			WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_working(1,2),change_bench_couple_val_incomethreshold_working(2,2),change_bench_couple_val_incomethreshold_working(3,2),change_bench_couple_val_incomethreshold_working(4,2),change_bench_couple_val_incomethreshold_working(5,2)
			WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_retire(1,2),change_bench_couple_val_incomethreshold_retire(2,2),change_bench_couple_val_incomethreshold_retire(3,2),change_bench_couple_val_incomethreshold_retire(4,2),change_bench_couple_val_incomethreshold_retire(5,2)

		print*, 'change of lifetime consumption of quintiles'
			
			WRITE(*,"(12(F11.4,1X))") cons_change_couple_female_working(1),cons_change_couple_female_working(2),cons_change_couple_female_working(3),cons_change_couple_female_working(4),cons_change_couple_female_working(5)
			WRITE(*,"(12(F11.4,1X))") cons_change_couple_female_retire(1),cons_change_couple_female_retire(2),cons_change_couple_female_retire(3),cons_change_couple_female_retire(4),cons_change_couple_female_retire(5)


		print*, ' '
		print*, 'Welfare benefit of reducing consumption dispersion'
		print*, change_bench_util_C
		print*, 'Welfare benefit of reducing hours dispersion'
		print*, change_bench_util_LS

		print*, ' '
		write(*,"(11(A8,1X))")	'util_welfare_id','veil_welfare_id', 'par_welfare','CEV'
		WRITE(*,"(12(F11.4,1X))") util_welfare_id, veil_welfare_id, par_welfare,CEV
		print*, 'policy reform lifetime consumption CEV '
		write(*,"(11(A8,1X))")	'newborn','util'
		WRITE(*,"(12(F11.4,1X))") reform_CEV_newborn, reform_CEV_util
		! write(*,"(11(A8,1X))")	'CEV_optimal','CEV_Q1','CEV_Q2','CEV_Q3','CEV_Q4','CEV_Q5'
		! write(*,"(12(F11.4,1X))") optimal_CEV_newborn , CEV_incomethreshold(1),CEV_incomethreshold(2),CEV_incomethreshold(3),CEV_incomethreshold(4),CEV_incomethreshold(5)
		print*, ' '
		print*, 'pop 65+/pop25-64', retire_population/working_population
		

		print*, 'input parameters'
		WRITE(*,"(12(F11.4,1X))") BETA_ANNUAL, fixcost_singlefemale, fixcost_marriedfemale, theta_single_male,theta_married_male,theta_single_female,theta_married_female, earn_corr, lambda_in, lambda_ll, zawel
		
		print*, 'Year = ',year
		! print*, 'Saving "opt_tax_record.txt" '	
		write(54,"(220(F16.8,1X))") ty_max,CEV,util_welfare_id,veil_welfare_id, par_welfare,tau_l_single,tau_l_couple,lambda,lambda_couple,lambda_couple,tax_revenue_single,tax_revenue_couple,gov_exp*OUTPUT,(1.0+R)**0.2-1.0,popu_MFS,tau_s,insurance_value,insurance_value_single,insurance_value_couple, &
									cost_unc_singlemale,cost_unc_singlefemale,cost_unc_couple(1),cost_unc_couple(2),cost_ineq_singlemale,cost_ineq_singlefemale,cost_ineq_couple(1),cost_ineq_couple(2), &
									agg_certeqcons_singlemale,agg_certeqlab_singlemale,agg_certeqcons_singlefemale,agg_certeqlab_singlefemale,agg_certeqcons_couple(1),agg_certeqcons_couple(2),agg_certeqlab_couple(1),agg_certeqlab_couple(2), &
									AggC_singlemale,AggC_singlefemale,AggL_singlemale,AggL_singlefemale,AggC_couple,AggC_couple,AggL_couple(1),AggL_couple(2),AggC_singlemale_leicomp,AggC_singlefemale_leicomp,AggC_couple_leicomp(1),AggC_couple_leicomp(2),Agg_asset,Agg_labor,Aggconsumption,OUTPUT,wage,hour_single_male,hour_single_female,hour_married_male,hour_married_female,LFP_single_female,LFP_married_female,marryprop,earn_corr,sigma_lab_male,sigma_lab_female,premium_rate,REPLACE,SSEXP,&
									tinc_gini,tincshare1,tincshare10,income_tax_revenue_single,income_tax_revenue_couple
		
		
		
		! print*, ' '
		! print*, 'Kindermann & Krueger 2015:top 0.25% of agents earn on average somewhere between 400 to 600 times the median income '
		! print*, 'My model top0.25%/median =', earn_top025pct_median_ratio
		 
		! print*,' ' 
		! print*, 'the ratio between even the top 0.01% and the median is at most of the order of 200 in the World Wealth and Income Database (WWID)'
		! print*, 'My model top0.01%/median =', earn_top001pct_median_ratio
		
		! print*,' ' 
		! print*, 'the top 0.1% are just about 34 times larger than the median'
		! print*, 'My model top0.1%/median =', earn_top01pct_median_ratio

		! print*,' ' 
		! print*, 'the top 5% in WWID earns about 5 times the median'
		! print*, 'My model top5%/median =', earn_top5pct_median_ratio

		! print*, ' '
		! print*, 'Castaneda et al 2003:the top 0.039% earners have 1000 times the average labor endowment of the bottom 61%'
		! print*, 'My model top0.039%/bottom61% =', Inc_top0039pct_bot61pct_ratio

		
! OPEN(UNIT=9,FILE='cali_res_benchmark.txt')		
! WRITE(9,"(143(F16.8,1X))") wea_gini,kshare0001, kshare0005, kshare001, kshare01,kshare05,kshare1,kshare5,kshare10,kshare20,kshare40,kshare60,kshare80, &
! 		inc_gini,incshare0001, incshare0005, incshare001, incshare01,incshare05,incshare1,incshare5,incshare10,incshare20,incshare40,incshare60,incshare80, &
! 		tinc_gini,tincshare0001, tincshare0005, tincshare001, tincshare01,tincshare05,tincshare1,tincshare5,tincshare10,tincshare20,tincshare40,tincshare60,tincshare80, &
! 		p15, p55, p56, p66,w(1),w(2), w(3), w(4), w(5), w(6), RMIN, RMAX, p11_r, p22_r, bcoeff, bcoeff2, bsigma,sigma,tau_l,tau_c,tau_s,d_c,BETA**(0.2),DEP_ANNUAL, &
!         MPL,wage, MPK, Avg_R, TFP, alpha/(Avg_R + DEP_ANNUAL),&
! 		p15,p55,p56,p66,zawel,zaweh,RMIN,RMAX,p11_r,p22_r,bcoeff,bcoeff2,bsigma,BETA_ANNUAL,tau_l,d_c,gov
		
WRITE(4,*) sort_A(:)

! OPEN(UNIT=12,FILE='interest.txt')
! 	WRITE(12,*) 'R=', R(:)
! 	write(12,*), 'ATR=', ATR(:)
		
OPEN(UNIT=2,FILE='record_position_tinc.txt')
	write(2,*) record_position_tinc
		
OPEN(UNIT=1,FILE='record_position_A.txt')
	write(1,*) record_position_A

OPEN(UNIT=20,FILE='record_position_E.txt')
	write(20,*) record_position_E

OPEN(UNIT=21,FILE='record_position_B.txt')
	write(21,*) record_position_B		

OPEN(UNIT=3,FILE='dist.txt')
WRITE(3,"(143(F16.8,1X))") kshare0001,kshare0005, kshare001, kshare005, kshare01, kshare05, kshare1, &
						   incshare0001, incshare0005, incshare001, incshare005, incshare01, incshare05, incshare1, &
						   tincshare0001, tincshare0005, tincshare001, tincshare005, tincshare01, tincshare05, tincshare1	

OPEN(UNIT=30,FILE='lifecycle_wealth.txt')
write(30,*) ALONG20_25_single(1),ALONG25_30_single(1),ALONG30_35_single(1),ALONG35_40_single(1),ALONG40_45_single(1),ALONG45_50_single(1),ALONG50_55_single(1),ALONG55_60_single(1),ALONG60_65_single(1),ALONG65_MORE_single(1)
write(30,*) ALONG20_25_single(2),ALONG25_30_single(2),ALONG30_35_single(2),ALONG35_40_single(2),ALONG40_45_single(2),ALONG45_50_single(2),ALONG50_55_single(2),ALONG55_60_single(2),ALONG60_65_single(2),ALONG65_MORE_single(2)
write(30,*) ALONG20_25_couple,ALONG25_30_couple,ALONG30_35_couple,ALONG35_40_couple,ALONG40_45_couple,ALONG45_50_couple,ALONG50_55_couple,ALONG55_60_couple,ALONG60_65_couple,ALONG65_MORE_couple
CLOSE(UNIT=30)


OPEN(UNIT=31,FILE='lifecycle_earning.txt')
write(31,*) ILONG20_25_single(1),ILONG25_30_single(1),ILONG30_35_single(1),ILONG35_40_single(1),ILONG40_45_single(1),ILONG45_50_single(1),ILONG50_55_single(1),ILONG55_60_single(1),ILONG60_65_single(1),ILONG65_MORE_single(1)
write(31,*) ILONG20_25_single(2),ILONG25_30_single(2),ILONG30_35_single(2),ILONG35_40_single(2),ILONG40_45_single(2),ILONG45_50_single(2),ILONG50_55_single(2),ILONG55_60_single(2),ILONG60_65_single(2),ILONG65_MORE_single(2)
write(31,*) ILONG20_25_couple,ILONG25_30_couple,ILONG30_35_couple,ILONG35_40_couple,ILONG40_45_couple,ILONG45_50_couple,ILONG50_55_couple,ILONG55_60_couple,ILONG60_65_couple,ILONG65_MORE_couple
CLOSE(UNIT=31)

OPEN(UNIT=32,FILE='lifecycle_income.txt')
write(32,*) TILONG20_25_single(1),TILONG25_30_single(1),TILONG30_35_single(1),TILONG35_40_single(1),TILONG40_45_single(1),TILONG45_50_single(1),TILONG50_55_single(1),TILONG55_60_single(1),TILONG60_65_single(1),TILONG65_MORE_single(1)
write(32,*) TILONG20_25_single(2),TILONG25_30_single(2),TILONG30_35_single(2),TILONG35_40_single(2),TILONG40_45_single(2),TILONG45_50_single(2),TILONG50_55_single(2),TILONG55_60_single(2),TILONG60_65_single(2),TILONG65_MORE_single(2)
write(32,*) TILONG20_25_couple,TILONG25_30_couple,TILONG30_35_couple,TILONG35_40_couple,TILONG40_45_couple,TILONG45_50_couple,TILONG50_55_couple,TILONG55_60_couple,TILONG60_65_couple,TILONG65_MORE_couple
CLOSE(UNIT=32)

OPEN(UNIT=27,FILE='lifecycle_wealth_population.txt')
		write(27,*) ALONG(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_earning_population.txt')
		write(27,*) ILONG(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_income_population.txt')
		write(27,*) TILONG(:)
CLOSE(27)

OPEN(UNIT=27,FILE='var_earning_age_single.txt')
		write(27,*) var_earning_age_single(:)
CLOSE(27)
OPEN(UNIT=27,FILE='var_cons_age_single.txt')
		write(27,*) var_cons_age_single(:)
CLOSE(27)
OPEN(UNIT=27,FILE='var_earning_age_couple.txt')
		write(27,*) var_earning_age_couple(:)
CLOSE(27)
OPEN(UNIT=27,FILE='var_earning_age_couple_HH.txt')
		write(27,*) var_earning_age_couple_HH(:)
CLOSE(27)
OPEN(UNIT=27,FILE='var_cons_age_couple.txt')
		write(27,*) var_cons_age_couple(:)
CLOSE(27)
OPEN(UNIT=27,FILE='var_wage_age_single.txt')
		write(27,*) var_wage_age_single(:)
CLOSE(27)
OPEN(UNIT=27,FILE='var_wage_age_couple.txt')
		write(27,*) var_wage_age_couple(:)
CLOSE(27)
! OPEN(UNIT=27,FILE='mean_earning_age_single.txt')
! 		write(27,*) mean_earning_age_single(:)
! CLOSE(27)
! OPEN(UNIT=27,FILE='mean_earning_age_couple.txt')
! 		write(27,*) mean_earning_age_couple(:)
! CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_var_cons_earn_ratio_single.txt')
		write(27,*) lifecycle_var_cons_earn_ratio_single(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_var_cons_earn_ratio_couple.txt')
		write(27,*) lifecycle_var_cons_earn_ratio_couple(:)
CLOSE(27)
OPEN(UNIT=27,FILE='ageprofile_insurance_cons_shock_value_single.txt')
		write(27,*) ageprofile_insurance_cons_shock_value_single(:)
CLOSE(27)
OPEN(UNIT=27,FILE='ageprofile_insurance_cons_shock_value_couple.txt')
		write(27,*) ageprofile_insurance_cons_shock_value_couple(:)
CLOSE(27)
OPEN(UNIT=27,FILE='ageprofile_insurance_cons_value_single.txt')
		write(27,*) ageprofile_insurance_cons_value_single(:)
CLOSE(27)
OPEN(UNIT=27,FILE='ageprofile_insurance_cons_value_couple.txt')
		write(27,*) ageprofile_insurance_cons_value_couple(:)
CLOSE(27)
OPEN(UNIT=27,FILE='Female_LFP.txt')
		write(27,*) labor_participation_age(:,2)
CLOSE(27)
OPEN(UNIT=27,FILE='Single_Female_LFP.txt')
		write(27,*) labor_participation_age_single(:,2)
CLOSE(27)
OPEN(UNIT=27,FILE='Married_Female_LFP.txt')
		write(27,*) labor_participation_age_couple(:,2)
CLOSE(27)
OPEN(UNIT=27,FILE='ATY_couple.txt')
		write(27,*) ATY_couple_b10,ATY_couple_b9,ATY_couple_b8,ATY_couple_b7,ATY_couple_b6,ATY_couple_b5,ATY_couple_b4,ATY_couple_b3,ATY_couple_b2,ATY_couple_b1
CLOSE(27)
OPEN(UNIT=27,FILE='ATY_taxableincome_couple.txt')
		write(27,*) ATY_taxableincome_couple_b10/couple_Y_b10,ATY_taxableincome_couple_b9/couple_Y_b9,ATY_taxableincome_couple_b8/couple_Y_b8,ATY_taxableincome_couple_b7/couple_Y_b7,ATY_taxableincome_couple_b6/couple_Y_b6,ATY_taxableincome_couple_b5/couple_Y_b5,ATY_taxableincome_couple_b4/couple_Y_b4,ATY_taxableincome_couple_b3/couple_Y_b3,ATY_taxableincome_couple_b2/couple_Y_b2,ATY_taxableincome_couple_b1/couple_Y_b1
CLOSE(27)
OPEN(UNIT=27,FILE='ATY_single.txt')
		write(27,*) ATY_single_b10,ATY_single_b9,ATY_single_b8,ATY_single_b7,ATY_single_b6,ATY_single_b5,ATY_single_b4,ATY_single_b3,ATY_single_b2,ATY_single_b1
CLOSE(27)
OPEN(UNIT=27,FILE='ATY_taxableincome_single.txt')
		write(27,*) ATY_taxableincome_single_b10/single_Y_b10,ATY_taxableincome_single_b9/single_Y_b9,ATY_taxableincome_single_b8/single_Y_b8,ATY_taxableincome_single_b7/single_Y_b7,ATY_taxableincome_single_b6/single_Y_b6,ATY_taxableincome_single_b5/single_Y_b5,ATY_taxableincome_single_b4/single_Y_b4,ATY_taxableincome_single_b3/single_Y_b3,ATY_taxableincome_single_b2/single_Y_b2,ATY_taxableincome_single_b1/single_Y_b1
CLOSE(27)

999 continue
!*********************
!
!   Internal Functions and Subroutines
!
!*********************
     CONTAINS
!******************************************************************


!SUBROUTINE single_SRCHFIVE01(AGE,IR,IS,WAGEZ,JAMAX,JMMAX,JNMAX,JHMAX,VMAX, &
!                      ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN,X3)
SUBROUTINE single_SRCHFIVE01(AGE,IA,IE,IG,IS,WAGEZ,JAMAX,JNMAX,VMAX, &
                      		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ)

!******************
!
!   Finds optimum asset choice over several (generally five)
!         possibly non-contiguous grid points
!
!******************
!
!   Uses:    Parameters:   BETA, CINCR, CMIN, RETAGE
!            Variables:    AGE, IL, ISKIP, IU, VMAX, X3
!            Arrays:       A(:), P(:,:), S(:), UT(:), singleVR(:,:), VW(:,:,:)
!
!   Returns:   JAMAX, VMAX
!
!   Local:     CONS, DC, JA, JC, UTIL, VTEMP, XC
!
!  Calls:     None
!
!******************
IMPLICIT NONE
!PASSED VARIABLES:
!INTEGER    ::  AGE,IR,IS,JAMAX,JMMAX,JNMAX,JHMAX,&
!               ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN
INTEGER    ::  AGE,IA,IE,IG,IS,JAMAX,JNMAX,&
               ILA,IUA,ISKIPA,ILN,IUN,ISKIPN
REAL(PREC) ::  WAGEZ,VMAX,X3,BEQ


!LOCA VARIABLES
!INTEGER    :: JA,JM, JN,JH
!REAL(PREC)  :: VTEMP, CONS,LEI, HEA,UTIL,HNEXT,SUR,XH,DH
INTEGER    :: JA, JN, JE
REAL(PREC)  :: VTEMP, CONS,LEI, UTIL,SUR

DO JA=ILA,IUA,ISKIPA
!    DO JM=ILM,IUM,ISKIPM
        
        SELECT CASE(AGE)
        CASE(1:RETAGE-2)
		
            ! DO JN=ILN,IUN,ISKIPN   
			JN=singleIDCWN(AGE,IA,IS,IE,IG)  				


				yd = avg_earnings*MIN( singlebendy, (min(R*A(IA),d_c) + WAGEZ*N(JN))/avg_earnings )*lambda*(MIN( singlebendy, (min(R*A(IA),d_c) + WAGEZ*N(JN))/avg_earnings ))**(-tau_l_single) &
					+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+WAGEZ*N(JN))/avg_earnings - singlebendy) &
					+(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans

				CONS = ( X3 + BEQ + yd - A(JA) - premium_rate*WAGEZ*N(JN) )/(1.0+tau_s)   !X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				
		        LEI = 1.00000000 - N(JN) 
             
                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN                   
					UTIL= utility (cons,lei,IG, gov_exp*OUTPUT)
                ELSE
		            UTIL=-1.E7
                END IF

				! EH_temp = ((AGE-1)*EH(IE)+WAGEZ*N(JN)/5.0)/AGE 
				EH_temp = ((AGE-1)*EH(IE)+WAGEZ*N(JN))/AGE 
				DO i=1,NGRIDEH
					IF(EH(i)>EH_temp) THEN 
						JE = i-1 
					    VTEMP = UTIL + BETA*sum( P(IS,:,IG)*( singleVW(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVW(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
                
						EXIT 
					ELSEIF (i==NGRIDEH) THEN  
						JE = NGRIDEH
						VTEMP = UTIL + BETA*sum( P(IS,:,IG)*singleVW(AGE+1,JA,:,JE,IG) )

						EXIT
					END IF
				END DO 

				!SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
                
				! sum_temp = 0.0
				! DO i = 1,NGRIDR
				! sum_temp = sum_temp + P_r(IR,i)*(sum( P(IS,:)*VW(AGE+1,JA,i,:) ))
				! END DO				
				               
				! VTEMP = UTIL + BETA*SUR*sum_temp +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1))
				! VTEMP = UTIL + BETA*sum( P(IS,:)*singleVW(AGE+1,JA,:,JE,IG) ) 
				! VTEMP = UTIL + BETA*sum( P(IS,:)*( singleVW(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVW(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
                
                UPDATE1:  IF (VTEMP>=VMAX) THEN
			        VMAX = VTEMP
			        JAMAX = JA
			        JNMAX = JN			  
			     
                END IF UPDATE1
			       
            ! END DO

        !END IF 

        CASE(RETAGE-1)
            ! DO JN=ILN,IUN,ISKIPN
			JN=singleIDCWN(AGE,IA,IS,IE,IG)  	
                								
		        yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + WAGEZ*N(JN))/avg_earnings )*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + WAGEZ*N(JN))/avg_earnings ))**(-tau_l_single) &
					+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+WAGEZ*N(JN))/avg_earnings - singlebendy) &			
					+(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans

				CONS = (X3 + BEQ + yd - A(JA) - premium_rate*WAGEZ*N(JN))/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)

				LEI  = 1.00000000 - N(JN) 

                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN                
					UTIL= utility (cons,lei,IG,gov_exp*OUTPUT)
		        ELSE
		            UTIL=-1.E7
                END IF

				! EH_temp = ((AGE-1)*EH(IE)+WAGEZ*N(JN)/5.0)/AGE
				EH_temp = ((AGE-1)*EH(IE)+WAGEZ*N(JN))/AGE 
				DO i=1,NGRIDEH
					IF(EH(i)>EH_temp) THEN 
						JE = i-1 
						VTEMP = UTIL + BETA*( singleVR(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVR(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 		
				
						EXIT  
					ELSEIF (i==NGRIDEH) THEN  
						JE = NGRIDEH 
						VTEMP = UTIL + BETA*singleVR(AGE+1,JA,JE,IG)

						EXIT
					END IF
				END DO

				!SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
				
				! VTEMP = UTIL + BETA*(1.0-P_m(IS1,IS2,IG))*singleVR(AGE+1,JA,IG) &
				! 		+ BETA*P_m(IS1,IS2,IG)*marriageVR(AGE+1,JA,IG) 

				! VTEMP = UTIL + BETA*singleVR(AGE+1,JA,IG) 	
				! VTEMP = UTIL + BETA*( singleVR(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVR(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 		
						                
                UPDATE3:  IF (VTEMP>=VMAX) THEN
                    VMAX = VTEMP
			        JAMAX = JA			       
			        JNMAX = JN			  			        
                END IF UPDATE3
            ! END DO
        
        CASE(RETAGE:MAXAGE-1)   

		    yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + WAGEZ)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + WAGEZ)/avg_earnings))**(-tau_l_single) &
				 +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+ WAGEZ)/avg_earnings - singlebendy) &
				 +(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans+medicare

			! CONS = (X3 + yd - A(JA) - premium_rate*WAGEZ)/(1.0+tau_s)		
			CONS = (X3 + yd - A(JA) )/(1.0+tau_s)
			LEI  = 1.00000000 

		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN       
				UTIL= utility (cons,lei,IG,gov_exp*OUTPUT)
		    ELSE
		        UTIL=-1.E7
            END IF   
             
            !SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)+c3*H(IH))) 
			
            !SUR = 1/(1+EXP(-5.490484+0.1499950*AGE+0.0161671*(AGE**2)-0.02*H(IH)))
            !SUR = 1.00-exp(-(H(IH)/SURV1)**SURV2)
            !IF (JH<NGRIDH) THEN
            !    VTEMP = UTIL + BETA*SUR*( (1.0-DH)*VR(AGE+1,JA,JH)+DH*VR(AGE+1,JA,JH+1) )
            !ELSE
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*(A(JA)**(1-bsigma))/(1-bsigma))
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)) 				 
            !END IF

			!SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2))) 
			! VTEMP = UTIL + BETA*S(AGE,IG)*singleVR(AGE+1,JA,IG) + (1.0-S(AGE,IG))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) ) 
			! VTEMP = UTIL + BETA*S(AGE,IG)*singleVR(AGE+1,JA,IE,IG) + (1.0-S(AGE,IG))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) )
			  VTEMP = UTIL + BETA*S(AGE,IG)*singleVR(AGE+1,JA,IE,IG)   
            
            UPDATE2:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    JAMAX = JA			   
			    JNMAX = 1			  			   
            END IF UPDATE2


        CASE(MAXAGE)  			
			            
		    yd = avg_earnings*MIN(singlebendy, (min(R*A(IA),d_c) + WAGEZ)/avg_earnings)*lambda*(MIN(singlebendy, (min(R*A(IA),d_c) + WAGEZ)/avg_earnings))**(-tau_l_single) &
				 +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+ WAGEZ)/avg_earnings - singlebendy) &
				 +(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans+medicare
			
			! CONS = (X3 + yd - A(JA))/(1.0+tau_s)	!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
			! CONS = (X3 + yd - premium_rate*WAGEZ)/(1.0+tau_s)	
			CONS = (X3 + yd )/(1.0+tau_s)

			LEI = 1.0
            
		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
                UTIL= utility(cons,lei,IG,gov_exp*OUTPUT) 
		    ELSE
		        UTIL=-1.E7
            END IF
			!VTEMP = UTIL + bcoeff*(A(JA)**(1-bsigma))/(1-bsigma)
            !VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)   !De Nardi bequest functional form
			!VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1)
			 VTEMP = UTIL 

			UPDATE4:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    ! JAMAX = JA
				JAMAX = 1	!NO bequest
			    JNMAX = 1			  
			    
            END IF UPDATE4
        
        END SELECT
 !   END DO
END DO


END SUBROUTINE
!************************************************************************************************************************


SUBROUTINE couple_SRCHFIVE01(AGE,IA,IE,IS1,IS2,WAGEZ1,WAGEZ2,JAMAX,JNMAX,JNMAX2,VMAX, &
                      		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2,X3,BEQ)

!******************
!
!   Finds optimum asset choice over several (generally five)
!         possibly non-contiguous grid points
!
!******************
!
!   Uses:    Parameters:   BETA, CINCR, CMIN, RETAGE
!            Variables:    AGE, IL, ISKIP, IU, VMAX, X3
!            Arrays:       A(:), P(:,:), S(:), UT(:), singleVR(:,:), VW(:,:,:)
!
!   Returns:   JAMAX, VMAX
!
!   Local:     CONS, DC, JA, JC, UTIL, VTEMP, XC
!
!  Calls:     None
!
!******************
IMPLICIT NONE
!PASSED VARIABLES:
!INTEGER    ::  AGE,IR,IS,JAMAX,JMMAX,JNMAX,JHMAX,&
!               ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN
INTEGER    ::  AGE,IA,IE,IS1,IS2,JAMAX,JNMAX,JNMAX2, &
               ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2
REAL(PREC) :: WAGEZ1,WAGEZ2,VMAX,X3,BEQ


!LOCA VARIABLES
!INTEGER    :: JA,JM, JN,JH
!REAL(PREC)  :: VTEMP, CONS,LEI, HEA,UTIL,HNEXT,SUR,XH,DH
INTEGER    :: JA, JN1, JN2, JE
REAL(PREC)  :: VTEMP, CONS,LEI1,LEI2, UTIL,SUR

SELECT CASE(couple_labor)
CASE(0)	
	DO JA=ILA,IUA,ISKIPA

        SELECT CASE(AGE)
        CASE(1:RETAGE-2)
						
			JN1=coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
			JN2=coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

			yd = max(yd_MFJ( WAGEZ1*N(JN1) + WAGEZ2*N(JN2) + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )
			
			CONS = ( X3 + 2*BEQ + yd + 2*gov_trans - A(JA) -  premium_rate*(WAGEZ1*N(JN1)+WAGEZ2*N(JN2)) )/(1.0+tau_s)   

			LEI1  = 1.00000000 - N(JN1) 
			LEI2  = 1.00000000 - N(JN2)
			
			IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN  
			
				UTIL= couple_utility(cons,lei1, lei2,gov_exp*OUTPUT)
			ELSE
				UTIL=-1.E7
			END IF

			EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE 
			DO i=1,NGRIDEH
				IF(EH(i)>EH_temp) THEN 
					JE = i-1 
					sum_temp = 0.0
					DO NEWIS1 = 1,nn
						! sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( coupleVW(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
						DO NEWIS2 = 1,nn 

							IF (IS1==IS2) THEN
								P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
									+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)														
							ELSE
								P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
							END IF
						
							sum_temp = sum_temp + P_joint*( coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
						END DO 
					END DO

					EXIT   
				ELSEIF (i==NGRIDEH) THEN  
					JE = NGRIDEH
					sum_temp = 0.0
					DO NEWIS1 = 1,nn
						DO NEWIS2 = 1,nn 

							IF (IS1==IS2) THEN
								P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
									+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
							ELSE
								P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
							END IF

							sum_temp = sum_temp + P_joint*coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE)
							! sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*coupleVW(AGE+1,JA,NEWIS,:,JE)  ))
						END DO 
					END DO

				END IF
			END DO 

				VTEMP = UTIL + BETA*sum_temp
				
				UPDATE1a:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA			    
					JNMAX = JN1
					JNMAX2 = JN2			  			   
				END IF UPDATE1a
			
        CASE(RETAGE-1)
			
			JN1=coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
			JN2=coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
			
			yd = max(yd_MFJ( WAGEZ1*N(JN1) + WAGEZ2*N(JN2) + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )

			CONS = (X3 + 2*BEQ + yd + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1*N(JN1) + WAGEZ2*N(JN2)) )/(1.0+tau_s)		

			LEI1  = 1.00000000 - N(JN1) 
			LEI2  = 1.00000000 - N(JN2) 
			
			IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN  
			
				UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
			ELSE
				UTIL=-1.E7
			END IF                                                                     
			
			! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
			EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE 
			DO i=1,NGRIDEH
				IF(EH(i)>EH_temp) THEN 
					JE = i-1 
					VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
													
					EXIT 
				ELSEIF (i==NGRIDEH) THEN  
					JE = NGRIDEH  
					VTEMP = UTIL + BETA*coupleVR(AGE+1,JA,JE)
					
					EXIT
				END IF
			END DO 
							
			UPDATE3a:  IF (VTEMP>=VMAX) THEN
				VMAX = VTEMP
				JAMAX = JA			       
				JNMAX = JN1
				JNMAX2 = JN2			  			        
			END IF UPDATE3a
		
        
        CASE(RETAGE:MAXAGE-1)   

			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

			! CONS = (X3 + yd + 2*medicare + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)	
			CONS = (X3 + yd + 2*medicare + 2*gov_trans - A(JA) )/(1.0+tau_s)	
			LEI1  = 1.00000000 
			LEI2  = 1.00000000 

		    IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN       
				UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
		    ELSE
		        UTIL=-1.E7
            END IF   
             
            !SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)+c3*H(IH))) 
			
            !SUR = 1/(1+EXP(-5.490484+0.1499950*AGE+0.0161671*(AGE**2)-0.02*H(IH)))
            !SUR = 1.00-exp(-(H(IH)/SURV1)**SURV2)
            !IF (JH<NGRIDH) THEN
            !    VTEMP = UTIL + BETA*SUR*( (1.0-DH)*VR(AGE+1,JA,JH)+DH*VR(AGE+1,JA,JH+1) )
            !ELSE
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*(A(JA)**(1-bsigma))/(1-bsigma))
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)) 				 
            !END IF

			!SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))

			! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA) & 
			! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,1) &
			! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,2) &
			! 		+ (1-S(AGE,1))*(1-S(AGE,2))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) )  

			! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
			! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
			! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) &
			! 		+ (1-S(AGE,1))*(1-S(AGE,2))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) )  

			! No bequest			
				VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
						+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
						+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) 
				
				UPDATE2a:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA			   
					JNMAX = 1	
					JNMAX2 = 1		  			   
				END IF UPDATE2a

        CASE(MAXAGE)  			
			            
			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )
			
			
			! CONS = (X3 + yd + 2*medicare + 2*gov_trans  - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)
			CONS = (X3 + yd + 2*medicare + 2*gov_trans )/(1.0+tau_s)
			LEI1  = 1.00000000 
			LEI2  = 1.00000000 
            
		    IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN   
                UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
		    ELSE
		        UTIL=-1.E7
            END IF
			!VTEMP = UTIL + bcoeff*(A(JA)**(1-bsigma))/(1-bsigma)
            !VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)   !De Nardi bequest functional form
			!VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1)
			VTEMP = UTIL

			UPDATE4a:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    ! JAMAX = JA
				JAMAX = 1	! No bequest
			    JNMAX = 1			  
			    JNMAX2 = 1	
            END IF UPDATE4a
        
        END SELECT !AGE
 
	END DO !JA

CASE(1)
	DO JA=ILA,IUA,ISKIPA
		! DO JN2=ILN2,IUN2,ISKIPN2
		
			
		SELECT CASE(AGE)
        CASE(1:RETAGE-2)
			JN2=NGRIDA+AGE
			DO JN1=ILN,IUN,ISKIPN
				
				yd = max(yd_MFJ( WAGEZ1*N(JN1) + WAGEZ2*N(JN2) + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )

				CONS = ( X3 + 2*BEQ + yd + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1*N(JN1) + WAGEZ2*N(JN2)))/(1.0+tau_s)   !X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				
				LEI1  = 1.00000000 - N(JN1) 
				LEI2  = 1.00000000 - N(JN2)
				
				IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN  
				
					UTIL= couple_utility(cons,lei1, lei2,gov_exp*OUTPUT)
				ELSE
					UTIL=-1.E7
				END IF

				! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE
				EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE 
				DO i=1,NGRIDEH
					IF(EH(i)>EH_temp) THEN 
						JE = i-1 
						sum_temp = 0.0
						DO NEWIS1 = 1,nn
							! sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( coupleVW(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
							DO NEWIS2 = 1,nn 

								IF (IS1==IS2) THEN
									P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
										+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)														
								ELSE
									P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
								END IF
							
								sum_temp = sum_temp + P_joint*( coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							END DO 
						END DO

						EXIT   
					ELSEIF (i==NGRIDEH) THEN  
						JE = NGRIDEH
						sum_temp = 0.0
						DO NEWIS1 = 1,nn
							DO NEWIS2 = 1,nn 

								IF (IS1==IS2) THEN
									P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
										+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
								ELSE
									P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
								END IF

								sum_temp = sum_temp + P_joint*coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE)
								! sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*coupleVW(AGE+1,JA,NEWIS,:,JE)  ))
							END DO 
						END DO

					END IF
				END DO 

				
				! sum_temp = 0.0
				! DO NEWIS = 1,nn
				!   ! sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*coupleVW(AGE+1,JA,NEWIS,:) ))
				! 	sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*( coupleVW(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
				! END DO				
				
													
				!VTEMP = UTIL + BETA*SUR*sum_temp +(1-SUR)*(bcoeff*(A(JA)**(1-bsigma))/(1-bsigma))
				!VTEMP = UTIL + BETA*SUR*sum_temp +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma))
				!VTEMP = UTIL + BETA*SUR*sum_temp +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1))
				VTEMP = UTIL + BETA*sum_temp
				
				UPDATE1b:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA			    
					JNMAX = JN1
					JNMAX2 = JN2			  			   
				END IF UPDATE1b

			END DO !JN1

		CASE(RETAGE-1)
			JN2=NGRIDA+AGE
			DO JN1=ILN,IUN,ISKIPN
				
				yd = max(yd_MFJ( WAGEZ1*N(JN1) + WAGEZ2*N(JN2) + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )

				CONS = (X3 + 2*BEQ + yd + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1*N(JN1) + WAGEZ2*N(JN2)))/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)

				LEI1  = 1.00000000 - N(JN1) 
				LEI2  = 1.00000000 - N(JN2) 
				
				IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN  
				
					UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
				ELSE
					UTIL=-1.E7
				END IF                                                                     
				
				! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
				EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE 
				DO i=1,NGRIDEH
					IF(EH(i)>EH_temp) THEN 
						JE = i-1 
						VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
														
						EXIT 
					ELSEIF (i==NGRIDEH) THEN  
						JE = NGRIDEH  
						VTEMP = UTIL + BETA*coupleVR(AGE+1,JA,JE)
						
						EXIT
					END IF
				END DO 

				! splitasset = A(JA)/2.0
				! do i=IA,NGRIDA
				! 	if(A(i) > splitasset) then	
				! 		Alower = i-1
				! 		go to 131
				! 	elseif (A(i) == splitasset) then	
				! 		Alower = i
				! 		go to 131
				! 	end if 
				! end do
				! 131 continue

				! interpolate_singleVR1 = singleVR(AGE+1,Alower,1)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
				! 						+ singleVR(AGE+1,Alower+1,1)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))

				! interpolate_singleVR2 = singleVR(AGE+1,Alower,2)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
				! 						+ singleVR(AGE+1,Alower+1,2)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))						

				! VTEMP = UTIL + BETA*(1.0-divorce)*coupleVR(AGE+1,JA) + BETA*divorce*(interpolate_singleVR1 + interpolate_singleVR2)
				! VTEMP = UTIL + BETA*coupleVR(AGE+1,JA)
				! VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
								
				UPDATE3b:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA			       
					JNMAX = JN1
					JNMAX2 = JN2			  			        
				END IF UPDATE3b
		
			END DO	!JN1

		CASE(RETAGE:MAXAGE-1)   

		    ! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
			! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - couplebendy) &
			! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

			! CONS = (X3 + yd + 2*medicare + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)		
			CONS = (X3 + yd + 2*medicare + 2*gov_trans - A(JA) )/(1.0+tau_s)	
			LEI1  = 1.00000000 
			LEI2  = 1.00000000 

		    IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN       
				UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
		    ELSE
		        UTIL=-1.E7
            END IF   
             
            !SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)+c3*H(IH))) 
			
            !SUR = 1/(1+EXP(-5.490484+0.1499950*AGE+0.0161671*(AGE**2)-0.02*H(IH)))
            !SUR = 1.00-exp(-(H(IH)/SURV1)**SURV2)
            !IF (JH<NGRIDH) THEN
            !    VTEMP = UTIL + BETA*SUR*( (1.0-DH)*VR(AGE+1,JA,JH)+DH*VR(AGE+1,JA,JH+1) )
            !ELSE
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*(A(JA)**(1-bsigma))/(1-bsigma))
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)) 				 
            !END IF

			!SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))

			! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA) & 
			! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,1) &
			! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,2) &
			! 		+ (1-S(AGE,1))*(1-S(AGE,2))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) )  

			! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
			! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
			! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) &
			! 		+ (1-S(AGE,1))*(1-S(AGE,2))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) )  

			! No bequest			
				VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
						+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
						+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) 
				
				UPDATE2b:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA			   
					JNMAX = 1
					JNMAX2 = 1			  			   
				END IF UPDATE2b


        CASE(MAXAGE)  			
			            
		    ! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
			! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2 - couplebendy) &
			! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )
			
			
			! CONS = (X3 + yd + 2*medicare + 2*gov_trans - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)
			CONS = (X3 + yd + 2*medicare + 2*gov_trans )/(1.0+tau_s)
			LEI1  = 1.00000000 
			LEI2  = 1.00000000 
            
		    IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN   
                UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
		    ELSE
		        UTIL=-1.E7
            END IF
			!VTEMP = UTIL + bcoeff*(A(JA)**(1-bsigma))/(1-bsigma)
            !VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)   !De Nardi bequest functional form
			!VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1)
			VTEMP = UTIL

			UPDATE4b:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    ! JAMAX = JA
				JAMAX = 1	! No bequest
			    JNMAX = 1
				JNMAX2 = 1			  
			    
            END IF UPDATE4b
        
        END SELECT !AGE

		! END DO !JN2
	END DO	!JA

CASE(2)
	DO JA=ILA,IUA,ISKIPA
		DO JN2=ILN2,IUN2,ISKIPN2
			
		SELECT CASE(AGE)
        CASE(1:RETAGE-2)
			DO JN1=ILN,IUN,ISKIPN
				
				yd = max(yd_MFJ( WAGEZ1*N(JN1) + WAGEZ2*N(JN2) + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )

				CONS = ( X3 + 2*BEQ + yd + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1*N(JN1) + WAGEZ2*N(JN2)) )/(1.0+tau_s)   !X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				
				LEI1  = 1.00000000 - N(JN1) 
				LEI2  = 1.00000000 - N(JN2)
				
				IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN  
				
					UTIL= couple_utility(cons,lei1, lei2,gov_exp*OUTPUT)
				ELSE
					UTIL=-1.E7
				END IF

				! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE
				EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE 
				DO i=1,NGRIDEH
					IF(EH(i)>EH_temp) THEN 
						JE = i-1 
						sum_temp = 0.0
						DO NEWIS1 = 1,nn
							! sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( coupleVW(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
							DO NEWIS2 = 1,nn 

								IF (IS1==IS2) THEN
									P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
										+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)														
								ELSE
									P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
								END IF
							
								sum_temp = sum_temp + P_joint*( coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							END DO 
						END DO

						EXIT   
					ELSEIF (i==NGRIDEH) THEN  
						JE = NGRIDEH
						sum_temp = 0.0
						DO NEWIS1 = 1,nn
							DO NEWIS2 = 1,nn 

								IF (IS1==IS2) THEN
									P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
										+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
								ELSE
									P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
								END IF

								sum_temp = sum_temp + P_joint*coupleVW(AGE+1,JA,NEWIS1,NEWIS2,JE)
								! sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*coupleVW(AGE+1,JA,NEWIS,:,JE)  ))
							END DO 
						END DO

					END IF
				END DO 

				
				! sum_temp = 0.0
				! DO NEWIS = 1,nn
				!   ! sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*coupleVW(AGE+1,JA,NEWIS,:) ))
				! 	sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*( coupleVW(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
				! END DO				
				
													
				!VTEMP = UTIL + BETA*SUR*sum_temp +(1-SUR)*(bcoeff*(A(JA)**(1-bsigma))/(1-bsigma))
				!VTEMP = UTIL + BETA*SUR*sum_temp +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma))
				!VTEMP = UTIL + BETA*SUR*sum_temp +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1))
				VTEMP = UTIL + BETA*sum_temp
				
				UPDATE1c:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA			    
					JNMAX = JN1
					JNMAX2 = JN2			  			   
				END IF UPDATE1c

			END DO !JN1

		CASE(RETAGE-1)
				DO JN1=ILN,IUN,ISKIPN
					
					yd = max(yd_MFJ( WAGEZ1*N(JN1) + WAGEZ2*N(JN2) + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )

					CONS = (X3 + 2*BEQ + yd + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1*N(JN1) + WAGEZ2*N(JN2)))/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)

					LEI1  = 1.00000000 - N(JN1) 
					LEI2  = 1.00000000 - N(JN2) 
					
					IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN  
					
						UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
					ELSE
						UTIL=-1.E7
					END IF                                                                     
					
					! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
					EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
							VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
															
							EXIT 
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH  
							VTEMP = UTIL + BETA*coupleVR(AGE+1,JA,JE)
							
							EXIT
						END IF
					END DO 

					! splitasset = A(JA)/2.0
					! do i=IA,NGRIDA
					! 	if(A(i) > splitasset) then	
					! 		Alower = i-1
					! 		go to 131
					! 	elseif (A(i) == splitasset) then	
					! 		Alower = i
					! 		go to 131
					! 	end if 
					! end do
					! 131 continue

					! interpolate_singleVR1 = singleVR(AGE+1,Alower,1)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
					! 						+ singleVR(AGE+1,Alower+1,1)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))

					! interpolate_singleVR2 = singleVR(AGE+1,Alower,2)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
					! 						+ singleVR(AGE+1,Alower+1,2)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))						

					! VTEMP = UTIL + BETA*(1.0-divorce)*coupleVR(AGE+1,JA) + BETA*divorce*(interpolate_singleVR1 + interpolate_singleVR2)
					! VTEMP = UTIL + BETA*coupleVR(AGE+1,JA)
					! VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
									
					UPDATE3c:  IF (VTEMP>=VMAX) THEN
						VMAX = VTEMP
						JAMAX = JA			       
						JNMAX = JN1
						JNMAX2 = JN2			  			        
					END IF UPDATE3c
			
				END DO	!JN1

		CASE(RETAGE:MAXAGE-1)   

		    ! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
			! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - couplebendy) &
			! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

			! CONS = (X3 + yd + 2*medicare + 2*gov_trans - A(JA) - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)		
			CONS = (X3 + yd + 2*medicare + 2*gov_trans - A(JA) )/(1.0+tau_s)
			LEI1  = 1.00000000 
			LEI2  = 1.00000000 

		    IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN       
				UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
		    ELSE
		        UTIL=-1.E7
            END IF   
             
            !SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)+c3*H(IH))) 
			
            !SUR = 1/(1+EXP(-5.490484+0.1499950*AGE+0.0161671*(AGE**2)-0.02*H(IH)))
            !SUR = 1.00-exp(-(H(IH)/SURV1)**SURV2)
            !IF (JH<NGRIDH) THEN
            !    VTEMP = UTIL + BETA*SUR*( (1.0-DH)*VR(AGE+1,JA,JH)+DH*VR(AGE+1,JA,JH+1) )
            !ELSE
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*(A(JA)**(1-bsigma))/(1-bsigma))
                !VTEMP = UTIL + BETA*SUR*sum(P_r(IR,:)*VR(AGE+1,JA,:)) +(1-SUR)*(bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)) 				 
            !END IF

			!SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))

			! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA) & 
			! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,1) &
			! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,2) &
			! 		+ (1-S(AGE,1))*(1-S(AGE,2))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) )  

			! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
			! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
			! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) &
			! 		+ (1-S(AGE,1))*(1-S(AGE,2))*( bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1) )  

			! No bequest			
				VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
						+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
						+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) 
				
				UPDATE2c:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA			   
					JNMAX = 1
					JNMAX2 = 1			  			   
				END IF UPDATE2c


        CASE(MAXAGE)  			
			            
		    ! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
			! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2 - couplebendy) &
			! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )
			
			
			! CONS = (X3 + yd + 2*medicare + 2*gov_trans - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)
			CONS = (X3 + yd + 2*medicare + 2*gov_trans )/(1.0+tau_s)
			LEI1  = 1.00000000 
			LEI2  = 1.00000000 
            
		    IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN   
                UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
		    ELSE
		        UTIL=-1.E7
            END IF
			!VTEMP = UTIL + bcoeff*(A(JA)**(1-bsigma))/(1-bsigma)
            !VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma))/(1-bsigma)   !De Nardi bequest functional form
			!VTEMP = UTIL + bcoeff*((A(JA)+bcoeff2)**(1-bsigma)-1)
			VTEMP = UTIL

			UPDATE4c:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    ! JAMAX = JA
				JAMAX = 1	! No bequest
			    JNMAX = 1
				JNMAX2 = 1			  
			    
            END IF UPDATE4c
        
        END SELECT !AGE

		END DO !JN2
	END DO	!JA
			
END SELECT ! labor supply


END SUBROUTINE


!**************************************************************************************************************

!SUBROUTINE BRACKET01(AGE,IA,IH,IS, WAGEZ)
SUBROUTINE single_BRACKET01(AGE,IA,IE,IG,IS,WAGEZ)
!******************
!
!   Finds global optimum asset choice for a single state
!
!******************
!
!   Uses:    Parameters:   NGRID, RETAGE
!            Variables:    AGE, ATR, BEQ, IA, IS, WAGEZ
!            Arrays:       None
!
!   Returns:   IDCR(:,:), IDCW(:,:,:), singleVR(:,:), VW(:,:,:)
!
!   Local:     IL, ISKIP, IU, JAMAX, VMAX, X3
!
!   Calls:     SRCHFIVE01
!
!******************
IMPLICIT NONE
!PASSED VARIABLES
!INTEGER    :: AGE,IA,IH,IS
INTEGER    :: AGE,IA,IE,IG,IS
REAL(PREC) :: WAGEZ
!LOCAL VARIABLES
!INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JMMAX,JHMAX,&
!              ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN
INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JHMAX,&
              ILA,IUA,ISKIPA,ILN,IUN,ISKIPN
REAL(PREC) :: X3,VMAX 


     index_SRCHFIVE01 = 0

	  X3 = A(IA)

     VMAX = -1.E6
     JAMAX = 1
	 JNMAX = 1

     ILA = 1
     IUA = NGRIDA
     ISKIPA = (NGRIDA - 1)/4

	 ILN = 1
	 IUN = NGRIDA
	 ISKIPN = (NGRIDA - 1)/4
	

!101  CALL single_SRCHFIVE01 (AGE,IH,IS,WAGEZ,JAMAX,JMMAX,JNMAX,JHMAX,VMAX, &
!                     ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN,X3)  !  Updates VMAX and JAMAX  
101  CALL single_SRCHFIVE01 (AGE,IA,IE,IG,IS,WAGEZ,JAMAX,JNMAX,VMAX, &
                     		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ)  !  Updates VMAX and JAMAX    					 

     NARROW01:  IF (ISKIPA>1) THEN

        NARROW02:  IF ((JAMAX>1).AND.(JAMAX<NGRIDA)) THEN
           ILA = JAMAX - ISKIPA
           IUA = JAMAX + ISKIPA
           ISKIPA = ISKIPA/2
        ELSE IF (JAMAX==1) THEN
           IF (ISKIPA>=4) THEN
              ISKIPA = ISKIPA/4
              IUA = ILA + 4*ISKIPA
           ELSE IF (ISKIPA==2) THEN
              ISKIPA = 1
              IUA = 2
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW02'
           END IF
        ELSE
           IF (ISKIPA>=4) THEN
              ISKIPA = ISKIPA/4
              ILA = IUA - 4*ISKIPA
           ELSE IF (ISKIPA==2) THEN
              ISKIPA = 1
              ILA = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW02'
           END IF
        END IF NARROW02

          IF (ILA<1) PRINT *, 'Error:  ILA<1 in Subroutine BRACKET'
          IF (ILA>NGRIDA) PRINT *, 'Error:  ILA>NGRIDA in Subroutine BRACKET'


     END IF NARROW01


! 	 NARROW05:  IF (ISKIPN>1) THEN

!         !NARROW06:  IF ((JNMAX>1).AND.(JNMAX<NGRIDH)) THEN
! 		NARROW06:  IF ((JNMAX>1).AND.(JNMAX<NGRIDA)) THEN
!            ILN = JNMAX - ISKIPN
!            IUN = JNMAX + ISKIPN
!            ISKIPN = ISKIPN/2
!         ELSE IF (JNMAX==1) THEN
!            IF (ISKIPN>=4) THEN
!               ISKIPN = ISKIPN/4
!               IUN = ILN + 4*ISKIPN
!            ELSE IF (ISKIPN==2) THEN
!               ISKIPN = 1
!               IUN = 2
!            ELSE
!               PRINT *, 'Error in Subroutine BRACKET at NARROW08'
!            END IF
!         ELSE
!            IF (ISKIPN>=4) THEN
!               ISKIPN = ISKIPN/4
!               ILN = IUN - 4*ISKIPN
!            ELSE IF (ISKIPN==2) THEN
!               ISKIPN = 1
!               !ILN = NGRIDH - 1
! 			  ILN = NGRIDA - 1
!            ELSE
!               PRINT *, 'Error in Subroutine BRACKET at NARROW08'
!            END IF
!         END IF NARROW06

!           IF (ILN<1) PRINT *, 'Error:  ILN<1 in Subroutine BRACKET'
!           !IF (ILN>NGRIDH) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'
! 		  IF (ILN>NGRIDA) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'

! !        GO TO 101
        

!      END IF NARROW05


		! IF (ISKIPA==1 .AND. ISKIPN==1)  THEN
		IF (ISKIPA==1)  THEN
            index_SRCHFIVE01 = 1+index_SRCHFIVE01
		ELSE
            index_SRCHFIVE01 = 0
        END IF
        
		IF (index_SRCHFIVE01 < 2) THEN
           GO TO 101
		END IF

        
   	
	 IF (AGE<RETAGE) THEN	 
	 	singleVW(AGE,IA,IS,IE,IG) = VMAX
	 	singleIDCWA(AGE,IA,IS,IE,IG) = JAMAX
	 	! singleIDCWN(AGE,IA,IS,IE,IG) = JNMAX
	 ELSE	 
	 	singleVR(AGE,IA,IE,IG) = VMAX
     	singleIDCRA(AGE,IA,IE,IG) = JAMAX
	 	singleIDCRN(AGE,IA,IE,IG) = 1
	 END IF
	 
	  

END SUBROUTINE


SUBROUTINE couple_BRACKET01(AGE,IA,IE,IS1,IS2,WAGEZ1,WAGEZ2)
!******************
!
!   Finds global optimum asset choice for a single state
!
!******************
!
!   Uses:    Parameters:   NGRID, RETAGE
!            Variables:    AGE, ATR, BEQ, IA, IS, WAGEZ
!            Arrays:       None
!
!   Returns:   IDCR(:,:), IDCW(:,:,:), singleVR(:,:), VW(:,:,:)
!
!   Local:     IL, ISKIP, IU, JAMAX, VMAX, X3
!
!   Calls:     SRCHFIVE01
!
!******************
IMPLICIT NONE
!PASSED VARIABLES
!INTEGER    :: AGE,IA,IH,IS
INTEGER    :: AGE,IA,IS1,IS2,IE
REAL(PREC) :: WAGEZ1,WAGEZ2
!LOCAL VARIABLES
!INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JMMAX,JHMAX,&
!              ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN
INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JNMAX2,JHMAX,&
              ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2
REAL(PREC) :: X3,VMAX 

     index_SRCHFIVE01 = 0

	  X3 = A(IA)

     VMAX = -1.E6
     JAMAX = 1
	 JNMAX = 1
	 JNMAX2 = 1

     ILA = 1
     IUA = NGRIDA
     ISKIPA = (NGRIDA - 1)/4
	 
	 ILN = 1
	 ILN2 = 1
	 IUN = NGRIDA
	 IUN2 = NGRIDA
	 ISKIPN = (NGRIDA - 1)/4
	 ISKIPN2 = (NGRIDA - 1)/4
	

!101  CALL single_SRCHFIVE01 (AGE,IH,IS,WAGEZ,JAMAX,JMMAX,JNMAX,JHMAX,VMAX, &
!                     ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN,X3)  !  Updates VMAX and JAMAX  
201  CALL couple_SRCHFIVE01 (AGE,IA,IE,IS1,IS2,WAGEZ1,WAGEZ2,JAMAX,JNMAX,JNMAX2,VMAX, &
                     		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2,X3,BEQ)  !  Updates VMAX and JAMAX    					 

     NARROW01:  IF (ISKIPA>1) THEN

        NARROW02:  IF ((JAMAX>1).AND.(JAMAX<NGRIDA)) THEN
           ILA = JAMAX - ISKIPA
           IUA = JAMAX + ISKIPA
           ISKIPA = ISKIPA/2
        ELSE IF (JAMAX==1) THEN
           IF (ISKIPA>=4) THEN
              ISKIPA = ISKIPA/4
              IUA = ILA + 4*ISKIPA
           ELSE IF (ISKIPA==2) THEN
              ISKIPA = 1
              IUA = 2
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW02'
           END IF
        ELSE
           IF (ISKIPA>=4) THEN
              ISKIPA = ISKIPA/4
              ILA = IUA - 4*ISKIPA
           ELSE IF (ISKIPA==2) THEN
              ISKIPA = 1
              ILA = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW02'
           END IF
        END IF NARROW02

          IF (ILA<1) PRINT *, 'Error:  ILA<1 in Subroutine BRACKET'
          IF (ILA>NGRIDA) PRINT *, 'Error:  ILA>NGRIDA in Subroutine BRACKET'


     END IF NARROW01



	!  NARROW03:  IF (ISKIPN2>1) THEN
       
	! 	NARROW04:  IF ((JNMAX2>1).AND.(JNMAX2<NGRIDA)) THEN
    !        ILN2 = JNMAX2 - ISKIPN2
    !        IUN2 = JNMAX2 + ISKIPN2
    !        ISKIPN2 = ISKIPN2/2
    !     ELSE IF (JNMAX2==1) THEN
    !        IF (ISKIPN2>=4) THEN
    !           ISKIPN2 = ISKIPN2/4
    !           IUN2 = ILN2 + 4*ISKIPN2
    !        ELSE IF (ISKIPN2==2) THEN
    !           ISKIPN2 = 1
    !           IUN2 = 2
    !        ELSE
    !           PRINT *, 'Error in Subroutine BRACKET at NARROW04'
    !        END IF
    !     ELSE
    !        IF (ISKIPN2>=4) THEN
    !           ISKIPN2 = ISKIPN2/4
    !           ILN2 = IUN2 - 4*ISKIPN2
    !        ELSE IF (ISKIPN2==2) THEN
    !           ISKIPN2 = 1
    !           !ILN = NGRIDH - 1
	! 		  ILN2 = NGRIDA - 1
    !        ELSE
    !           PRINT *, 'Error in Subroutine BRACKET at NARROW04'
    !        END IF
    !     END IF NARROW04

    !       IF (ILN2<1) PRINT *, 'Error:  ILN2<1 in Subroutine BRACKET'
    !       !IF (ILN>NGRIDH) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'
	! 	  IF (ILN2>NGRIDA) PRINT *, 'Error:  ILN2>NGRIDA in Subroutine BRACKET'


    !  END IF NARROW03



! 	 NARROW05:  IF (ISKIPN>1) THEN

        
! 		NARROW06:  IF ((JNMAX>1).AND.(JNMAX<NGRIDA)) THEN
!            ILN = JNMAX - ISKIPN
!            IUN = JNMAX + ISKIPN
!            ISKIPN = ISKIPN/2
!         ELSE IF (JNMAX==1) THEN
!            IF (ISKIPN>=4) THEN
!               ISKIPN = ISKIPN/4
!               IUN = ILN + 4*ISKIPN
!            ELSE IF (ISKIPN==2) THEN
!               ISKIPN = 1
!               IUN = 2
!            ELSE
!               PRINT *, 'Error in Subroutine BRACKET at NARROW08'
!            END IF
!         ELSE
!            IF (ISKIPN>=4) THEN
!               ISKIPN = ISKIPN/4
!               ILN = IUN - 4*ISKIPN
!            ELSE IF (ISKIPN==2) THEN
!               ISKIPN = 1
!               !ILN = NGRIDH - 1
! 			  ILN = NGRIDA - 1
!            ELSE
!               PRINT *, 'Error in Subroutine BRACKET at NARROW08'
!            END IF
!         END IF NARROW06

!           IF (ILN<1) PRINT *, 'Error:  ILN<1 in Subroutine BRACKET'
!           !IF (ILN>NGRIDH) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'
! 		  IF (ILN>NGRIDA) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'

! !        GO TO 101
        
!      END IF NARROW05



      
		! IF (ISKIPA==1 .AND. ISKIPN==1 .AND. ISKIPN2==1)  THEN
		IF (ISKIPA==1)  THEN
            index_SRCHFIVE01 = 1+index_SRCHFIVE01
		ELSE
            index_SRCHFIVE01 = 0
        END IF
        
		IF (index_SRCHFIVE01 < 2) THEN
           GO TO 201
		END IF
	
         
	
	IF (AGE<RETAGE) THEN	 
	 	coupleVW(AGE,IA,IS1,IS2,IE) = VMAX
	 	coupleIDCWA(AGE,IA,IS1,IS2,IE) = JAMAX
	 	! coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = JNMAX
	 	! coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = JNMAX2
	ELSE	 
	 	coupleVR(AGE,IA,IE) = VMAX
     	coupleIDCRA(AGE,IA,IE) = JAMAX
	 	coupleIDCRN(AGE,IA,IE) = 1
	END IF
	 

 
END SUBROUTINE

!******************************************************************


!******************************************************************

SUBROUTINE DECRULE01

!******************
!
!   Finds optimal asset choice for all states
!
!******************
!
!   Uses:    Parameters:   GAMMA1, HBAR, MAXAGE, NGRID, PHI, RETAGE,
!            Variables:    ATR, BEQ, SS, STAX, UTAX, WAGE
!            Arrays:       A(:), EFFLONG(:)
!
!   Returns:   IDCR(:,:), IDCW(:,:,:), VR(:,:), VW(:,:,:)
!
!   Local:     CONS, WAGEZ
!
!   Calls:     BRACKET01
!
!******************
IMPLICIT NONE
!INTEGER    ::  AGE,IA,IH,IS
!REAL(PREC) ::  LEI, HEA, CONS, WAGEZ
INTEGER    ::  AGE,IA,IS,IS1,IS2,IE,IG
REAL(PREC) ::  LEI, CONS,  WAGEZ, WAGEZ1, WAGEZ2

IS = 1
!   Initialize value function and decision rules
 
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG=1,2
				
			  		singleVW(AGE,IA,IS,IE,IG) = -10000.0000					  
              		singleIDCWA(AGE,IA,IS,IE,IG) = -1			     
		      		! singleIDCWN(AGE,IA,IS,IE,IG) = -1

				END DO 
            END DO
        END DO
    END DO
END DO

DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH

					coupleVW(AGE,IA,IS1,IS2,IE) = -10000.0000
	 				coupleIDCWA(AGE,IA,IS1,IS2,IE) = -1
					! coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = -1
 					! coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = -1

				END DO 
			END DO
        END DO
    END DO
END DO


DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IE=1,NGRIDEH

		DO IG=1,2
		
			singleVR(AGE,IA,IE,IG) = -10000.0000
			!marriageVR(AGE,IA,IE,IG) = -10000.0000  
            singleIDCRA(AGE,IA,IE,IG) = -1
			singleIDCRN(AGE,IA,IE,IG) = -1
			
		END DO

		coupleVR(AGE,IA,IE) = -10000.0000
        coupleIDCRA(AGE,IA,IE) = -1
	 	coupleIDCRN(AGE,IA,IE) = -1

        END DO 
    END DO
END DO
  
!************************************
!   			Retirees
!************************************

!$OMP PARALLEL DEFAULT(NONE) &
!$OMP & PRIVATE(WAGEZ,WAGEZ1, WAGEZ2,IS,IS1,IS2,IE,IG,AGE,IA) &
!$OMP & SHARED(singleVW,coupleVW,singleVR,coupleVR,marriageVR,singleIDCWA,coupleIDCWA,singleIDCWN,coupleIDCWN,singleIDCRA,coupleIDCRA,singleIDCRN,coupleIDCRN, &
!$OMP &        EFFLONG,W,wage)

IS=1   
DO AGE=MAXAGE,RETAGE,-1
	DO IE=1,NGRIDEH
    	WAGEZ = SS(IE) 
		!$OMP DO
		DO IG=1,2
			
			DO IA=1,NGRIDA
				CALL single_BRACKET01(AGE,IA,IE,IG,IS,WAGEZ)	 ! Finds optimal asset choice for this state
			END DO
			
		END DO
		!$OMP END DO
	END DO  
END DO

DO AGE=RETAGE-1,1,-1       
	DO IG=1,2
		DO IS =1,nn   
			!$OMP DO				
			DO IE=1,NGRIDEH	
					
				DO IA=1,NGRIDA       			                   
					WAGEZ = WAGE*EFFLONG(AGE,IG)*W(IS,IG)
                	CALL single_BRACKET01(AGE,IA,IE,IG,IS,WAGEZ)
				END DO 
				
            END DO
			!$OMP END DO
        END DO	
    END DO
END DO 



IS1=1
IS2=1
DO AGE=MAXAGE,RETAGE,-1
	!$OMP DO
	DO IE=1,NGRIDEH
		WAGEZ1 = SS(IE)
		WAGEZ2 = SS(IE)             	
		
		DO IA=1,NGRIDA			   
			CALL couple_BRACKET01(AGE,IA,IE,IS1,IS2,WAGEZ1,WAGEZ2)
		END DO
		
	END DO
	!$OMP END DO
END DO
!$OMP END PARALLEL

DO AGE=RETAGE-1,1,-1
	DO IS1 =1,nn   
		DO IS2 =1,nn
			DO IE=1,NGRIDEH
				
				DO IA=1,NGRIDA			                              
					WAGEZ1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)
					WAGEZ2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)
                	CALL couple_BRACKET01(AGE,IA,IE,IS1,IS2,WAGEZ1,WAGEZ2)
				END DO 
				
			END DO
        END DO
    END DO
END DO



!******************************************************************************************
! 					Value of being in a marriage for an individual
!******************************************************************************************	 	 
DO AGE=MAXAGE,RETAGE,-1
    ! WAGEZ1 = SS
	! WAGEZ2 = SS           
		
	
	DO IA=1,NGRIDA
		DO IE=1,NGRIDEH

			JA = coupleIDCRA(AGE,IA,IE)
			WAGEZ1 = SS(IE)
			WAGEZ2 = SS(IE)  

			! yd = (lambda+delta_lambda)*(MIN(bendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l) &
			!  +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - bendy) &
			!  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

			! CONS = (A(IA) + yd + 2*gov_trans - A(JA))/(1.0+tau_s)
			LEI = 1.0
			
			IF (AGE==MAXAGE) THEN
				CONS = (A(IA) + yd + 2*gov_trans)/(1.0+tau_s)
				marriageVR(AGE,IA,IE,1) = utility(CONS/eta, LEI, 1,gov_exp*OUTPUT) 
				marriageVR(AGE,IA,IE,2) = utility(CONS/eta, LEI, 2,gov_exp*OUTPUT)
			ELSE
				CONS = (A(IA) + yd + 2*gov_trans - A(JA))/(1.0+tau_s)
				marriageVR(AGE,IA,IE,1) = utility(CONS/eta, LEI, 1,gov_exp*OUTPUT) + BETA*S(AGE,1)*S(AGE,2)*marriageVR(AGE+1,JA,IE,1) &
										+ BETA*S(AGE,1)*(1.0-S(AGE,2))*singleVR(AGE+1,JA,IE,1)

				marriageVR(AGE,IA,IE,2) = utility(CONS/eta, LEI, 2,gov_exp*OUTPUT) + BETA*S(AGE,1)*S(AGE,2)*marriageVR(AGE+1,JA,IE,2) &
										+ BETA*S(AGE,2)*(1.0-S(AGE,1))*singleVR(AGE+1,JA,IE,2)
			END IF 
		END DO 
	END DO
	
END DO

DO AGE=RETAGE-1,1,-1 
	DO IA =1,NGRIDA			   
        DO IS1 = 1,nn   
			DO IS2 = 1,nn
				DO IE=1,NGRIDEH

					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2) 						
					WAGEZ1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)
					WAGEZ2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)

                	! yd = lambda*(MIN(bendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l) &
				 	! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - bendy) &
					! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)
					
					yd = max(yd_MFJ( WAGEZ1*JN1 + WAGEZ2*JN2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*JN1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*JN2 + min(R*A(IA),d_c)/2 ,IA) )
							
					CONS = (A(IA) + yd + 2*BEQ + 2*gov_trans - A(JA))/(1.0+tau_s)

					LEI1 = 1.00000000 - N(JN1) 
					LEI2 = 1.00000000 - N(JN2)

														
						! splitasset = A(JA)/2.0
						! do i=IA,NGRIDA
						! 	if(A(i) > splitasset) then	
						! 		Alower = i-1
						! 		go to 132
						! 	elseif (A(i) == splitasset) then	
						! 		Alower = i
						! 		go to 132
						! 	end if 
						! end do
						! 132 continue 
										
					IF (AGE==RETAGE-1) THEN
							! interpolate_singleVR1 = singleVR(AGE+1,Alower,1)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
							! 						+ singleVR(AGE+1,Alower+1,1)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))

							! interpolate_singleVR2 = singleVR(AGE+1,Alower,2)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
							! 						+ singleVR(AGE+1,Alower+1,2)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))		
							
							! marriageVW(AGE,IA,IS1,IS2,1) = utility(CONS, coupleIDCWN(AGE,IA,IS1,IS2,1)) + BETA*(1.0-divorce)*marriageVR(AGE+1,JA,1) &
							! 								+ BETA*divorce*interpolate_singleVR1
							
							! marriageVW(AGE,IA,IS1,IS2,2) = utility(CONS, coupleIDCWN(AGE,IA,IS1,IS2,2)) + BETA*(1.0-divorce)*marriageVR(AGE+1,JA,2) &
							! 								+ BETA*divorce*interpolate_singleVR2	

						! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
						EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE
						DO i=1,NGRIDEH
							IF(EH(i)>EH_temp) THEN 
								JE = i-1 
								sum_temp = marriageVR(AGE+1,JA,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVR(AGE+1,JA,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
								
								EXIT   
							ELSEIF (i==NGRIDEH) THEN  
								JE = NGRIDEH
								sum_temp = marriageVR(AGE+1,JA,JE,1)  
								
							END IF
						END DO 	
				  				
						marriageVW(AGE,IA,IS1,IS2,IE,1) = utility(CONS/eta, LEI1, 1,gov_exp*OUTPUT) + BETA*sum_temp 
								
						DO i=1,NGRIDEH
							IF(EH(i)>EH_temp) THEN 
								JE = i-1 
								sum_temp = marriageVR(AGE+1,JA,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVR(AGE+1,JA,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
								
								EXIT   
							ELSEIF (i==NGRIDEH) THEN  
								JE = NGRIDEH
								sum_temp = marriageVR(AGE+1,JA,JE,2)  
								
							END IF
						END DO 	
				  					
						marriageVW(AGE,IA,IS1,IS2,IE,2) = utility(CONS/eta, LEI2, 2,gov_exp*OUTPUT) + BETA*sum_temp  
									
					ELSE
						
						! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
						EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE
						DO i=1,NGRIDEH
							IF(EH(i)>EH_temp) THEN 
								JE = i-1 
								sum_temp = 0.0
								DO NEWIS1 = 1,nn
									DO NEWIS2 = 1,nn	

										IF (IS1==IS2) THEN
											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
										ELSE
											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
										END IF
										
										sum_temp = sum_temp + P_joint*( marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )

									END DO 
								END DO

								EXIT   
							ELSEIF (i==NGRIDEH) THEN  
								JE = NGRIDEH
								sum_temp = 0.0
								DO NEWIS1 = 1,nn
									DO NEWIS2 = 1,nn	

										IF (IS1==IS2) THEN
											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
										ELSE
											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
										END IF
				  					
										sum_temp = sum_temp + P_joint*marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,1)

									END DO 
								END DO

							END IF
						END DO 
						
						marriageVW(AGE,IA,IS1,IS2,IE,1) = utility(CONS/eta, LEI1, 1,gov_exp*OUTPUT) + BETA*sum_temp 

						! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
						EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE
						DO i=1,NGRIDEH
							IF(EH(i)>EH_temp) THEN 
								JE = i-1 
								sum_temp = 0.0
								DO NEWIS1 = 1,nn
									DO NEWIS2 = 1,nn	

										IF (IS1==IS2) THEN
											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
										ELSE
											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
										END IF
				  					
										sum_temp = sum_temp + P_joint*( marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )

									END DO  
								END DO

								EXIT   
							ELSEIF (i==NGRIDEH) THEN  
								JE = NGRIDEH
								sum_temp = 0.0
								DO NEWIS1 = 1,nn
									DO NEWIS2 = 1,nn	

										IF (IS1==IS2) THEN
											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
										ELSE
											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
										END IF

				  					
										sum_temp = sum_temp + P_joint*marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,2)

									END DO   
								END DO

							END IF
						END DO
							
						marriageVW(AGE,IA,IS1,IS2,IE,2) = utility(CONS/eta, LEI2, 2,gov_exp*OUTPUT) + BETA*sum_temp

					END IF	

				END DO
            END DO
        END DO
	END DO 
END DO 
!******************************************************************************************	

END SUBROUTINE

!******************************************************************

SUBROUTINE INVAR01

!******************
!
!   Finds invariant distribution
!
!******************
!
!   Uses:    Parameters:   MAXAGE, NGRID, RETAGE
!            Variables:    None
!            Arrays:       IDCR(:,:), IDCW(:,:,:), P(:,:)
!
!   Returns:   YR(:,:), YW(:,:,:)
!
!   Local:     JA
!
!   Calls:     None
!
!******************

!   Initialize age-dependent distributions
! singleYW(:,:,:,:,:)=0.0
! coupleYW(:,:,:,:,:)=0.0
! singleYR(:,:,:,:)=0.0
! coupleYR(:,:,:)=0.0

	DO AGE=1,RETAGE-1
        DO IA=1,NGRIDA           
		  	DO IS=1,nn
			    DO IE=1,NGRIDEH
					DO IG = 1,2
						singleYW(AGE,IA,IS,IE,IG)=0.0
					END DO 		
			    END DO
            END DO
        END DO
    END DO
	 	
						 

	 DO AGE=1,RETAGE-1
        DO IA=1,NGRIDA           
		    DO IS1=1,nn
			  	DO IS2=1,nn
				  	DO IE=1,NGRIDEH 
						coupleYW(AGE,IA,IS1,IS2,IE)=0.0
					END DO 
			    END DO
            END DO
        END DO
     END DO
						


	DO AGE=RETAGE,MAXAGE
        DO IA=1,NGRIDA
			DO IE=1,NGRIDEH
		  		DO IG=1,2
			  		singleYR(AGE,IA,IE,IG)=0.0
				END DO 
            END DO
        END DO
    END DO

	DO AGE=RETAGE,MAXAGE
        DO IA=1,NGRIDA
			DO IE=1,NGRIDEH		  
				coupleYR(AGE,IA,IE)=0.0 
			END DO          
        END DO
    END DO


!*********************************************************************************************************************
! 	We use the setup of "The Joint Labor Supply Decision of Married Couples and the Social Security Pension System"	
! 	Assume everyone start with lowest productivity and zero wealth													
! 	Male population is assumed to be 1																				
! 	Female population is assumed to be 1																				
! 	A fixed proportion (marryprop) of men and women are married when they enter the economy at age20 and never divorce
! 	(1−marryprop) of men and women are single and never marry.
! 	Total population = 2*(1 - marryprop)+marryprop = 2-marryprop
!*********************************************************************************************************************

! DO IG=1,2
! 	 singleYW(1,ZEROINDEX,1,IG)=initial_dist_z(1)*(1.0-marryprop)	!0.6111  ! invariant distribution of SLOW
! 	 singleYW(1,ZEROINDEX,2,IG)=initial_dist_z(2)*(1.0-marryprop)	!0.2235  ! invariant distribution of SHIGH
! 	 singleYW(1,ZEROINDEX,3,IG)=initial_dist_z(3)*(1.0-marryprop)	!0.1650  ! invariant distribution of SLOW
! 	 singleYW(1,ZEROINDEX,4,IG)=initial_dist_z(4)*(1.0-marryprop)	!1- 0.6111 - 0.2235 - 0.1650  ! invariant distribution of SHIGH
! 	 singleYW(1,ZEROINDEX,5,IG)=initial_dist_z(5)*(1.0-marryprop)	!0.0  ! invariant distribution of SLOW
! 	 singleYW(1,ZEROINDEX,6,IG)=initial_dist_z(6)*(1.0-marryprop)	!0.0  ! invariant distribution of SHIGH
! END DO 


DO IG=1,2
	DO IS=1,nn
		singleYW(1,ZEROINDEX,IS,1,IG)=(1.0-marryprop)*initial_dist_z(IS,IG)
	END DO  
END DO 

! coupleYW(1,ZEROINDEX,1,1,1) = marryprop

DO IS1 = 1,nn-1
	DO IS2 = 1,nn-1
		coupleYW(1,ZEROINDEX,IS1,IS2,1) = marryprop/16.0
	END DO 
END DO 

! coupleYW(1,ZEROINDEX,1,1,1) = marryprop*P_m(1,1)	
! coupleYW(1,ZEROINDEX,3,1,1) = marryprop*P_m(2,1)	
! coupleYW(1,ZEROINDEX,1,3,1) = marryprop*P_m(1,2)	
! coupleYW(1,ZEROINDEX,3,3,1) = marryprop*P_m(2,2)	

! Option 1
! coupleYW(1,ZEROINDEX,1,1,1) = marryprop*P_m(1,1)	
! coupleYW(1,ZEROINDEX,4,1,1) = marryprop*P_m(2,1)	
! coupleYW(1,ZEROINDEX,1,4,1) = marryprop*P_m(1,2)	
! coupleYW(1,ZEROINDEX,4,4,1) = marryprop*P_m(2,2)	

! Option 2
! coupleYW(1,ZEROINDEX,1,1,1) = marryprop*P_m(1,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,1,2,1) = marryprop*P_m(1,1)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,1,3,1) = marryprop*P_m(1,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,2,1,1) = marryprop*P_m(1,1)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,2,2,1) = marryprop*P_m(1,1)*(0.824/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,2,3,1) = marryprop*P_m(1,1)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,3,1,1) = marryprop*P_m(1,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,3,2,1) = marryprop*P_m(1,1)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,3,3,1) = marryprop*P_m(1,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))

! coupleYW(1,ZEROINDEX,4,1,1) = marryprop*P_m(2,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,4,2,1) = marryprop*P_m(2,1)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,4,3,1) = marryprop*P_m(2,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,5,1,1) = marryprop*P_m(2,1)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,5,2,1) = marryprop*P_m(2,1)*(0.824/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,5,3,1) = marryprop*P_m(2,1)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,6,1,1) = marryprop*P_m(2,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,6,2,1) = marryprop*P_m(2,1)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,6,3,1) = marryprop*P_m(2,1)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))

! coupleYW(1,ZEROINDEX,1,4,1) = marryprop*P_m(1,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,2,4,1) = marryprop*P_m(1,2)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,3,4,1) = marryprop*P_m(1,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,1,5,1) = marryprop*P_m(1,2)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,2,5,1) = marryprop*P_m(1,2)*(0.824/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,3,5,1) = marryprop*P_m(1,2)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,1,6,1) = marryprop*P_m(1,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,2,6,1) = marryprop*P_m(1,2)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,3,6,1) = marryprop*P_m(1,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))

! coupleYW(1,ZEROINDEX,4,4,1) = marryprop*P_m(2,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,4,5,1) = marryprop*P_m(2,2)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,4,6,1) = marryprop*P_m(2,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,5,4,1) = marryprop*P_m(2,2)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,5,5,1) = marryprop*P_m(2,2)*(0.824/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,5,6,1) = marryprop*P_m(2,2)*(0.824/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))
! coupleYW(1,ZEROINDEX,6,4,1) = marryprop*P_m(2,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,6,5,1) = marryprop*P_m(2,2)*(0.088/(0.088+0.824+0.088))*(0.824/(0.088+0.824+0.088))	
! coupleYW(1,ZEROINDEX,6,6,1) = marryprop*P_m(2,2)*(0.088/(0.088+0.824+0.088))*(0.088/(0.088+0.824+0.088))


print*, ' population of age 21'
print*, 'Share of married households', marryprop/(2-marryprop)
print*,'sum couple population', SUM(coupleYW(1,:,:,:,:))
! print*, 'single proportion', 1.0-marryprop
print*,'sum male population', SUM(singleYW(1,:,:,:,1))
print*,'sum female population', SUM(singleYW(1,:,:,:,2))
print*, ' whole population at age 1', SUM(singleYW(1,:,:,:,1))+SUM(singleYW(1,:,:,:,2))+SUM(coupleYW(1,:,:,:,:))
!****************************************************
!			 Single person distribution
!****************************************************
DO AGE=2,RETAGE-1
    DO IA=1,NGRIDA
		DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG=1,2
                 
			 		JA = singleIDCWA(AGE-1,IA,IS,IE,IG)  
					JN = singleIDCWN(AGE-1,IA,IS,IE,IG)

					! EH_temp = ((AGE-1)*EH(IE) + WAGE*EFFLONG(AGE-1,IG)*W(IS)*N(JN)/5.0)/AGE
					! EH_temp = ((AGE-2)*EH(IE) + WAGE*EFFLONG(AGE-1,IG)*W(IS,IG)*N(JN)/5.0)/(AGE-1) 	! avg including first period zero earning
					EH_temp = ((AGE-2)*EH(IE) + WAGE*EFFLONG(AGE-1,IG)*W(IS,IG)*N(JN))/(AGE-1)
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
							DO NEWIS=1,nn 
						  	! singleYW(AGE,JA,NEWIS,IG) = singleYW(AGE,JA,NEWIS,IG) + singleYW(AGE-1,IA,IS,IG)*P(IS,NEWIS)
								singleYW(AGE,JA,NEWIS,JE,IG) = singleYW(AGE,JA,NEWIS,JE,IG) + singleYW(AGE-1,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
								singleYW(AGE,JA,NEWIS,JE+1,IG) = singleYW(AGE,JA,NEWIS,JE+1,IG) + singleYW(AGE-1,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
			 				END DO 

							EXIT
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH 
							DO NEWIS=1,nn 					  	
								singleYW(AGE,JA,NEWIS,JE,IG) = singleYW(AGE,JA,NEWIS,JE,IG) + singleYW(AGE-1,IA,IS,IE,IG)*P(IS,NEWIS,IG)							
			 				END DO

							EXIT  
						END IF
					END DO

					! IF (AGE==3) THEN 	! People get married at 25-29
					! 	DO NEWIS=1,nn 
					! 		singleYW(AGE,JA,NEWIS,IG) = singleYW(AGE,JA,NEWIS,IG) + singleYW(AGE-1,IA,IS,IG)*P(IS,NEWIS)*(1.0-SUM(P_m(NEWIS,:,IG)))
					! 	END DO  
					! ELSE 

			 			! DO NEWIS=1,nn 
						!   ! singleYW(AGE,JA,NEWIS,IG) = singleYW(AGE,JA,NEWIS,IG) + singleYW(AGE-1,IA,IS,IG)*P(IS,NEWIS)
						! 	singleYW(AGE,JA,NEWIS,JE,IG) = singleYW(AGE,JA,NEWIS,JE,IG) + singleYW(AGE-1,IA,IS,IE,IG)*P(IS,NEWIS)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
						! 	singleYW(AGE,JA,NEWIS,JE+1,IG) = singleYW(AGE,JA,NEWIS,JE+1,IG) + singleYW(AGE-1,IA,IS,IE,IG)*P(IS,NEWIS)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
			 			! END DO  
						
					!END IF

				END DO 
		    END DO
        END DO
    END DO
END DO

!	Newly retirees

DO IA=1,NGRIDA
	DO IS=1,nn
		DO IE=1,NGRIDEH
	  		DO IG=1,2 
           
			 JA = singleIDCWA(RETAGE-1,IA,IS,IE,IG)
			 JN = singleIDCWN(RETAGE-1,IA,IS,IE,IG)	

			! EH_temp = ((RETAGE-1)*EH(IE) + WAGE*EFFLONG(RETAGE-1,IG)*W(IS)*N(JN)/5.0)/RETAGE 	
			! EH_temp = ((RETAGE-2)*EH(IE) + WAGE*EFFLONG(RETAGE-1,IG)*W(IS,IG)*N(JN)/5.0)/(RETAGE-1)			! avg including first period zero earning
			EH_temp = ((RETAGE-2)*EH(IE) + WAGE*EFFLONG(RETAGE-1,IG)*W(IS,IG)*N(JN))/(RETAGE-1)
			DO i=1,NGRIDEH
				IF(EH(i)>EH_temp) THEN 
					JE = i-1 
					singleYR(RETAGE,JA,JE,IG) = singleYR(RETAGE,JA,JE,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
					singleYR(RETAGE,JA,JE+1,IG) = singleYR(RETAGE,JA,JE+1,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
				
					EXIT
				ELSEIF (i==NGRIDEH) THEN  
					JE = NGRIDEH 
					singleYR(RETAGE,JA,JE,IG) = singleYR(RETAGE,JA,JE,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)  
				
					EXIT
				END IF
			END DO

		 
			! singleYR(RETAGE,JA,JE,IG) = singleYR(RETAGE,JA,JE,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
			! singleYR(RETAGE,JA,JE+1,IG) = singleYR(RETAGE,JA,JE+1,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))

			END DO 	 
		END DO
    END DO
END DO

!	Previous retirees

DO AGE=RETAGE+1,MAXAGE
    DO IA=1,NGRIDA
		DO IE=1,NGRIDEH
	    	DO IG=1,2
           		      
		  	JA = singleIDCRA(AGE-1,IA,IE,IG)
		  		
		  	IF (IG==1) THEN
	     	 	singleYR(AGE,JA,IE,IG) = singleYR(AGE,JA,IE,IG) + singleYR(AGE-1,IA,IE,IG)*S(AGE-1,IG)
				singleYR(AGE,coupleIDCRA(AGE-1,IA,IE),IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IE),IE,IG) + coupleYR(AGE-1,IA,IE)*(1.0-S(AGE-1,2))	! wife dies, husband becomes single
			  ELSE
			  	singleYR(AGE,JA,IE,IG) = singleYR(AGE,JA,IE,IG) + singleYR(AGE-1,IA,IE,IG)*S(AGE-1,IG)
				singleYR(AGE,coupleIDCRA(AGE-1,IA,IE),IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IE),IE,IG) + coupleYR(AGE-1,IA,IE)*(1.0-S(AGE-1,1))	! husband dies, wife becomes single
			  END IF

			END DO 	  
        END DO
    END DO
END DO

!****************************************************
!			 Married Couple Distribution
!****************************************************

!************************************************************************************************************
! There is no married couple at first period or 20-25 age
! Compute number of household units
! temp_famsize = 0.0
! AGE=3
! DO IA=1,NGRIDA 
! 	DO IS=1,nn
! 		DO NEWIS = 1,nn
! 			temp_famsize =  temp_famsize + singleYW(AGE-1,IA,IS,1)*P(IS,NEWIS)*SUM(P_m(NEWIS,:,1))+singleYW(AGE-1,IA,IS,2)*P(IS,NEWIS)*SUM(P_m(NEWIS,:,2))
! 		END DO 
! 	END DO 
! END DO 

! ! Total household units
! temp_famsize = temp_famsize/2.0	

! ! Compute couple population
! WEIGHT(:,:) = 0.0
! AGE=3
! DO IS1=1,nn 
! 	DO IS2=1,nn
! 		DO IA1=1,NGRIDA
! 			DO IA2=1,NGRIDA
! 				WEIGHT(IS1,IS2) = singleYW(AGE-1,IA1,IS1,1)+singleYW(AGE-1,IA2,IS2,2)
! 			END DO 
! 		END DO 												
! 	END DO
! END DO 	

! AGE=3
! DO IA1=1,NGRIDA
! 	DO IA2=1,NGRIDA
! 		DO IS1=1,nn 
! 			DO IS2=1,nn

! 			!coupleYW(AGE,JA,IS1,IS2) = coupleYW(AGE,JA,IS1,IS2) + temp_famsize*P_m(IS1,IS2,1)		
! 			!WEIGHT = (singleYW(AGE-1,IA1,IS1,1)+singleYW(AGE-1,IA2,IS2,2))/( SUM(singleYW(AGE-1,:,IS1,1))+SUM(singleYW(AGE-1,:,IS2,2)) )

! 			famasset_weight = (singleYW(AGE-1,IA1,IS1,1)+singleYW(AGE-1,IA2,IS2,2))/WEIGHT(IS1,IS2)
! 			jointasset = A(singleIDCWA(AGE-1,IA1,IS1,1))+A(singleIDCWA(AGE-1,IA2,IS2,2)) !Do interpolation
! 			do i=IA,NGRIDA
! 				if(A(i) > jointasset) then	
! 					ACLOSE = i-1
! 					coupleYW(AGE,ACLOSE,IS1,IS2) = coupleYW(AGE,ACLOSE,IS1,IS2) + famasset_weight*temp_famsize*P_m(IS1,IS2,1)* (jointasset-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))
! 					coupleYW(AGE,ACLOSE+1,IS1,IS2) = coupleYW(AGE,ACLOSE+1,IS1,IS2) + famasset_weight*temp_famsize*P_m(IS1,IS2,1)*(1.0-(jointasset-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1)))
! 					go to 131
! 				elseif (A(i) == jointasset) then	
! 					ACLOSE = i
! 					coupleYW(AGE,ACLOSE,IS1,IS2) = coupleYW(AGE,ACLOSE,IS1,IS2) + temp_famsize*P_m(IS1,IS2,1)
! 					go to 131
! 				elseif ( (i==NGRIDA) .AND. (A(i) < jointasset) ) then
! 					coupleYW(AGE,NGRIDA,IS1,IS2) = coupleYW(AGE,NGRIDA,IS1,IS2) + temp_famsize*P_m(IS1,IS2,1)
! 					go to 131
! 				end if 
! 			end do
! 			131 continue
! 			END DO 
! 		END DO 												
! 	END DO
! END DO 
!*************************************************************************************************************
DO AGE=2,RETAGE-1
    DO IA=1,NGRIDA
		DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH
                 
			 		JA = coupleIDCWA(AGE-1,IA,IS1,IS2,IE) 
					JN1 = coupleIDCWN(AGE-1,IA,IS1,IS2,IE,1) 
					JN2 = coupleIDCWN(AGE-1,IA,IS1,IS2,IE,2) 
					! JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
					! JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2) 

					! EH_temp = ((AGE-2)*EH(IE)+(WAGE*EFFLONG(AGE-1,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE-1,2)*W(IS2,2)*N(JN2))/2.0/5.0)/(AGE-1) 
					EH_temp = ((AGE-2)*EH(IE)+(WAGE*EFFLONG(AGE-1,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE-1,2)*W(IS2,2)*N(JN2))/2.0)/(AGE-1) 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1
							DO NEWIS1=1,nn 
								DO NEWIS2=1,nn 

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P_joint*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
									coupleYW(AGE,JA,NEWIS1,NEWIS2,JE+1) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE+1) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P_joint*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
					 				! coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
									! coupleYW(AGE,JA,NEWIS1,NEWIS2,JE+1) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE+1) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
		 						END DO
							END DO   
						
							EXIT
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH
							DO NEWIS1=1,nn 
								DO NEWIS2=1,nn

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P_joint	
					 				! coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)									
		 						END DO
							END DO  

							EXIT 
						END IF
					END DO

			 		! DO NEWIS1=1,nn 
					! 	DO NEWIS2=1,nn 
					!  		coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P(IS1,NEWIS1)*P(IS2,NEWIS2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
					! 		coupleYW(AGE,JA,NEWIS1,NEWIS2,JE+1) = coupleYW(AGE,JA,NEWIS1,NEWIS2,JE+1) + coupleYW(AGE-1,IA,IS1,IS2,IE)*P(IS1,NEWIS1)*P(IS2,NEWIS2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
		 			! 	END DO
					! END DO  

				END DO 
		    END DO
        END DO
    END DO
END DO

!	Newly retirees

DO IA=1,NGRIDA
	DO IS1=1,nn
		DO IS2=1,nn  	
			DO IE=1,NGRIDEH
           
			JA = coupleIDCWA(RETAGE-1,IA,IS1,IS2,IE)
			JN1 = coupleIDCWN(RETAGE-1,IA,IS1,IS2,IE,1) 
			JN2 = coupleIDCWN(RETAGE-1,IA,IS1,IS2,IE,2) 

			! EH_temp = ((RETAGE-1)*EH(IE)+(WAGE*EFFLONG(RETAGE,1)*W(IS1)*N(JN1) + WAGE*EFFLONG(RETAGE,2)*W(IS2)*N(JN2))/2.0/5.0)/RETAGE 
			! EH_temp = ((RETAGE-2)*EH(IE)+(WAGE*EFFLONG(RETAGE-1,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(RETAGE-1,2)*W(IS2,2)*N(JN2))/2.0/5.0)/(RETAGE-1) 
			EH_temp = ((RETAGE-2)*EH(IE)+(WAGE*EFFLONG(RETAGE-1,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(RETAGE-1,2)*W(IS2,2)*N(JN2))/2.0)/(RETAGE-1) 
			DO i=1,NGRIDEH
				IF(EH(i)>EH_temp) THEN 
					JE = i-1
					coupleYR(RETAGE,JA,JE) = coupleYR(RETAGE,JA,JE) + coupleYW(RETAGE-1,IA,IS1,IS2,IE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
					coupleYR(RETAGE,JA,JE+1) = coupleYR(RETAGE,JA,JE+1) + coupleYW(RETAGE-1,IA,IS1,IS2,IE)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) 
				
					EXIT
				ELSEIF (i==NGRIDEH) THEN  
					JE = NGRIDEH
					coupleYR(RETAGE,JA,JE) = coupleYR(RETAGE,JA,JE) + coupleYW(RETAGE-1,IA,IS1,IS2,IE) 
					  
					EXIT 
				END IF
			END DO

			! coupleYR(RETAGE,JA,JE) = coupleYR(RETAGE,JA,JE) + coupleYW(RETAGE-1,IA,IS1,IS2,IE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
			! coupleYR(RETAGE,JA,JE+1) = coupleYR(RETAGE,JA,JE+1) + coupleYW(RETAGE-1,IA,IS1,IS2,IE)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))

			END DO 	 
		END DO 
    END DO
END DO

!	Previous retirees

	DO AGE=RETAGE+1,MAXAGE
        DO IA=1,NGRIDA
			DO IE=1,NGRIDEH
		               		      
			JA = coupleIDCRA(AGE-1,IA,IE)			  
		    coupleYR(AGE,JA,IE) = coupleYR(AGE,JA,IE) + coupleYR(AGE-1,IA,IE)*S(AGE-1,1)*S(AGE-1,2)	 

			END DO 
        END DO
    END DO


END SUBROUTINE
!******************************************************************

SUBROUTINE PROFILE01

!******************
!
!   Finds age profiles for income, consumption, and assets, and
!      computes average lifetime utility
!
!******************
!
!   Uses:    Parameters:   CINCR, CMIIN, HBAR, NGRID, PHI, RETAGE
!            Variables:    ATR, BEQ, SS, STAX, UTAX, WAGE
!            Arrays:       A(:), EFFLONG(:), IDCR(:,:), IDCW(:,:,:),
!                          UT(:), YR(:,:), YW(:,:,:)
!
!   Returns:   ACROSS(:), ALONG(:), AVGUTIL, CCROSS(:), CLONG(:),
!              ICROSS(:), ILONG(:)
!
!   Local:     CONS, DC, JA, JC, UTIL, WAGEZ, XC
!
!   Calls:     None
!
!******************

! Compute longitudinal profiles for a given cohort
! To match the age-partition from Kuhn & Rios 2016 
! Income consists of all kinds of revenue before taxes. 
! Hence, our definition of income includes both government and private transfers  
					
!  Working-age "single" agents
DO AGE=1,RETAGE-1
	
    ALONG(AGE) = 0.0
    CLONG(AGE) = 0.0
    ILONG(AGE) = 0.0
    NLONG(AGE) = 0.0
    LLONG_single(AGE,1) = 0.0
	LLONG_single(AGE,2) = 0.0
	TILONG(AGE) = 0.0
        
    DO IA=1,NGRIDA            
    	DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG=1,2
                    
                   !  Assets
				
                   ! ALONG(AGE) = ALONG(AGE) + A(JA)*YW(AGE,IA,IH,IS)
					JA = singleIDCWA(AGE,IA,IS,IE,IG)
                    ! ALONG(AGE) = ALONG(AGE) + A(JA)*YW(AGE,IA,IR,IS)
					ALONG(AGE) = ALONG(AGE) + A(IA)*singleYW(AGE,IA,IS,IE,IG)

	                !  Med. Expenditure
                    !JM = IDCWM(AGE,IA,IH,IS)
                    !MLONG(AGE) = MLONG(AGE) + M(JM)*YW(AGE,IA,IH,IS)

                    ! Efficiency labor & Working hours
			        !JN = IDCWN(AGE,IA,IH,IS)
                    !NLONG(AGE) = NLONG(AGE) + N(JN)*YW(AGE,IA,IH,IS)*W(IS)
                    !LLONG(AGE) = LLONG(AGE) + N(JN)*YW(AGE,IA,IH,IS)
					JN = singleIDCWN(AGE,IA,IS,IE,IG)
                    NLONG(AGE) = NLONG(AGE) + N(JN)*singleYW(AGE,IA,IS,IE,IG)*W(IS,IG)
                    LLONG_single(AGE,IG) = LLONG_single(AGE,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)
            
			        !  Sick time
			        !SICKLONG(AGE) = SICKLONG(AGE) + (Q*(H(IH)**(-GAMMA1)))*YW(AGE,IA,IH,IS)
			        !IF (SICKLONG(AGE)>=1.000) THEN
				    !SICKLONG(AGE)=1.0000
			        !END IF

			        ! Health capital
                    !HLONG(AGE) = HLONG(AGE) + H(IH)*YW(AGE,IA,IH,IS)
                    !
                    !JH = IDCWH(AGE,IA,IH,IS)
                    !HLONGNEXT(AGE) = HLONGNEXT(AGE) + H(JH)*YW(AGE,IA,IH,IS)

						  
			        !  (Before Tax) Labor Income and Total Income
                    INCOME     = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
					PREMIUM    = premium_rate*INCOME
                    !ILONG(AGE) = ILONG(AGE) + INCOME*YW(AGE,IA,IH,IS)
					ILONG(AGE) = ILONG(AGE) + INCOME*singleYW(AGE,IA,IS,IE,IG)
					
                    
					!(Kuhn & Rios 2016)Income consists of all kinds of revenue before taxes. Hence, our definition of income includes both government and private transfers  
					! (Before Tax) Total Income
                    !TINCOME     = R(IA)*A(IA) + (1-STAX-MTAX)*INCOME+ ATR(IA)* BEQ*(1.0+GROWTH)**(AGE-1)
				    !TINCOME     = R*A(IA) + (1-STAX-MTAX)*INCOME 
					
					!TINCOME     = R(IR)*A(IA) + (1-STAX-MTAX)*INCOME+ ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)					
                    TINCOME	= R*A(IA) + INCOME + BEQ*(1.0+GROWTH)**(AGE-1)					
					TILONG(AGE) = TILONG(AGE) + TINCOME*singleYW(AGE,IA,IS,IE,IG)

                    !  Consumption
                    !CONS = ATR(IA)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + (1-STAX-MTAX)*INCOME - A(JA) - (1.000-SUBEHI)*M(JM) - (1.0-STAX-MTAX)*PREMIUM !
                    !CLONG(AGE) = CLONG(AGE) + CONS*YW(AGE,IA,IH,IS)

					!CONS = ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + (1-STAX-MTAX)*INCOME - A(JA) - (1.0-STAX-MTAX)*PREMIUM !
                    yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
				 		  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+ INCOME)/avg_earnings - singlebendy) &						  
						  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

					! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
					X3 =  BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)
					CONS = (X3 + yd + gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)
					CLONG(AGE) = CLONG(AGE) + CONS*singleYW(AGE,IA,IS,IE,IG)
				END DO 
            END DO			  
        END DO
    END DO
END DO


!  Working-age "couple" agents
DO AGE=1,RETAGE-1 
	LLONG_couple(AGE,1) = 0.0
	LLONG_couple(AGE,2) = 0.0
    DO IA=1,NGRIDA            
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH					
                    
                   !  Assets
				
                   ! ALONG(AGE) = ALONG(AGE) + A(JA)*YW(AGE,IA,IH,IS)
					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
                    ! ALONG(AGE) = ALONG(AGE) + A(JA)*YW(AGE,IA,IR,IS)
					ALONG(AGE) = ALONG(AGE) + A(IA)*coupleYW(AGE,IA,IS1,IS2,IE)

	                !  Med. Expenditure
                    !JM = IDCWM(AGE,IA,IH,IS)
                    !MLONG(AGE) = MLONG(AGE) + M(JM)*YW(AGE,IA,IH,IS)

                    ! Efficiency labor & Working hours
			        !JN = IDCWN(AGE,IA,IH,IS)
                    !NLONG(AGE) = NLONG(AGE) + N(JN)*YW(AGE,IA,IH,IS)*W(IS)
                    !LLONG(AGE) = LLONG(AGE) + N(JN)*YW(AGE,IA,IH,IS)
					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)	
                    NLONG(AGE) = NLONG(AGE) + (N(JN1)*W(IS1,1)+N(JN2)*W(IS2,2))*coupleYW(AGE,IA,IS1,IS2,IE)
                    LLONG_couple(AGE,1) = LLONG_couple(AGE,1) + N(JN1)*coupleYW(AGE,IA,IS1,IS2,IE)
					LLONG_couple(AGE,2) = LLONG_couple(AGE,2) + N(JN2)*coupleYW(AGE,IA,IS1,IS2,IE)
            
			        !  Sick time
			        !SICKLONG(AGE) = SICKLONG(AGE) + (Q*(H(IH)**(-GAMMA1)))*YW(AGE,IA,IH,IS)
			        !IF (SICKLONG(AGE)>=1.000) THEN
				    !SICKLONG(AGE)=1.0000
			        !END IF

			        ! Health capital
                    !HLONG(AGE) = HLONG(AGE) + H(IH)*YW(AGE,IA,IH,IS)
                    !
                    !JH = IDCWH(AGE,IA,IH,IS)
                    !HLONGNEXT(AGE) = HLONGNEXT(AGE) + H(JH)*YW(AGE,IA,IH,IS)

						  
			        !  (Before Tax) Labor Income and Total Income
                    INCOME     = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)
					PREMIUM    = premium_rate*INCOME
                    !ILONG(AGE) = ILONG(AGE) + INCOME*YW(AGE,IA,IH,IS)
					ILONG(AGE) = ILONG(AGE) + INCOME*coupleYW(AGE,IA,IS1,IS2,IE)
					
                    
					!(Kuhn & Rios 2016)Income consists of all kinds of revenue before taxes. Hence, our definition of income includes both government and private transfers  
					! (Before Tax) Total Income
                    !TINCOME     = R(IA)*A(IA) + (1-STAX-MTAX)*INCOME+ ATR(IA)* BEQ*(1.0+GROWTH)**(AGE-1)
				    !TINCOME     = R*A(IA) + (1-STAX-MTAX)*INCOME 
					
					!TINCOME     = R(IR)*A(IA) + (1-STAX-MTAX)*INCOME+ ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)					
                    TINCOME	= R*A(IA) + INCOME + 2*BEQ*(1.0+GROWTH)**(AGE-1)					
					TILONG(AGE) = TILONG(AGE) + TINCOME*coupleYW(AGE,IA,IS1,IS2,IE)

                    !  Consumption
                    !CONS = ATR(IA)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + (1-STAX-MTAX)*INCOME - A(JA) - (1.000-SUBEHI)*M(JM) - (1.0-STAX-MTAX)*PREMIUM !
                    !CLONG(AGE) = CLONG(AGE) + CONS*YW(AGE,IA,IH,IS)

					                    
					! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
				 	! 	  +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ INCOME - couplebendy) &						  
					! 	  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

					yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c), IA), yd_MFS( WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )

					! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
					X3 =  2*BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)
					CONS = (X3 + yd + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)
					CLONG(AGE) = CLONG(AGE) + CONS*coupleYW(AGE,IA,IS1,IS2,IE)

				END DO 
            END DO			  
        END DO
    END DO
END DO

!  Single Retirees    
    DO AGE=RETAGE,MAXAGE              
        ALONG(AGE) = 0.0
        CLONG(AGE) = 0.0
        ILONG(AGE) = 0.0   !Original code: ILONG(AGE) = SS ; I assume SS is not earnings
		TILONG(AGE) = 0.0
        
        DO IA=1,NGRIDA
            DO IE=1,NGRIDEH
				DO IG=1,2   
				
                !  Assets
                !JA = IDCRA(AGE,IA,IH)
				JA = singleIDCRA(AGE,IA,IE,IG)
			    
                !ALONG(AGE) = ALONG(AGE) + A(JA)*YR(AGE,IA,IH)
				! ALONG(AGE) = ALONG(AGE) + A(JA)*YR(AGE,IA,IR)
				ALONG(AGE) = ALONG(AGE) + A(IA)*singleYR(AGE,IA,IE,IG)

			    !  Med. Expenditure
                !JM = IDCRM(AGE,IA,IH)
			    !IF (JM<1) THEN
			    !JM = 1
			    !END IF
                !MLONG(AGE) = MLONG(AGE) + M(JM)*YR(AGE,IA,IH)

			    ! Health capital
			    !HLONG(AGE) = HLONG(AGE) + H(IH)*YR(AGE,IA,IH)
                
                !JH = IDCRH(AGE,IA,IH)
                !HLONGNEXT(AGE) = HLONGNEXT(AGE) + H(JH)*YR(AGE,IA,IH)
			  			  
 		        !  Total income
                !TINCOME = R(IA)*A(IA) + SS + ATR(IA)* BEQ*(1.0+GROWTH)**(AGE-1) 
				!TINCOME = R*A(IA) + SS
				!TINCOME = R(IR)*A(IA) + SS + ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1) 

				! PREMIUM = premium_rate*SS(IE)
				PREMIUM = 0.0
				TINCOME = R*A(IA) + SS(IE)                  
				TILONG(AGE) = TILONG(AGE) + TINCOME*singleYR(AGE,IA,IE,IG)
                !TILONG(AGE) = TILONG(AGE) + TINCOME*YR(AGE,IA,IH)

				!  Consumption
                !CONS = ATR(IA)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) -(1.000-SUBM)*M(JM)
                !CLONG(AGE) = CLONG(AGE) + CONS*YR(AGE,IA,IH)

				!CONS = ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) 
				yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + SS(IE))/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + SS(IE))/avg_earnings))**(-tau_l_single) &
				 	 +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+ SS(IE))/avg_earnings - singlebendy) &					 
					 +(1-tau_c)*max(R*A(IA)-d_c,0.0)

				! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				X3 = A(IA)
				CONS = (X3 + yd + gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)
                CLONG(AGE) = CLONG(AGE) + CONS*singleYR(AGE,IA,IE,IG)

				END DO 
           END DO
        END DO
    END DO

!  Couple Retirees    
    DO AGE=RETAGE,MAXAGE                      
        DO IA=1,NGRIDA
            DO IE=1,NGRIDEH
				   				
                !  Assets
                !JA = IDCRA(AGE,IA,IH)
				JA = coupleIDCRA(AGE,IA,IE)
			    
                !ALONG(AGE) = ALONG(AGE) + A(JA)*YR(AGE,IA,IH)
				! ALONG(AGE) = ALONG(AGE) + A(JA)*YR(AGE,IA,IR)
				ALONG(AGE) = ALONG(AGE) + A(IA)*coupleYR(AGE,IA,IE)

			    !  Med. Expenditure
                !JM = IDCRM(AGE,IA,IH)
			    !IF (JM<1) THEN
			    !JM = 1
			    !END IF
                !MLONG(AGE) = MLONG(AGE) + M(JM)*YR(AGE,IA,IH)

			    ! Health capital
			    !HLONG(AGE) = HLONG(AGE) + H(IH)*YR(AGE,IA,IH)
                
                !JH = IDCRH(AGE,IA,IH)
                !HLONGNEXT(AGE) = HLONGNEXT(AGE) + H(JH)*YR(AGE,IA,IH)
			  			  
 		        !  Total income
                !TINCOME = R(IA)*A(IA) + SS + ATR(IA)* BEQ*(1.0+GROWTH)**(AGE-1) 
				!TINCOME = R*A(IA) + SS
				!TINCOME = R(IR)*A(IA) + SS + ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1) 

				! PREMIUM = premium_rate*(2*SS(IE))
				PREMIUM = 0.0
				TINCOME = R*A(IA) + 2*SS(IE)                  
				TILONG(AGE) = TILONG(AGE) + TINCOME*coupleYR(AGE,IA,IE)
                !TILONG(AGE) = TILONG(AGE) + TINCOME*YR(AGE,IA,IH)

				!  Consumption
                !CONS = ATR(IA)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) -(1.000-SUBM)*M(JM)
                !CLONG(AGE) = CLONG(AGE) + CONS*YR(AGE,IA,IH)

				!CONS = ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) 
				
				! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + 2*SS(IE)))**(1.0-tau_l_couple) &
				!  	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ 2*SS(IE) - couplebendy) &					 
				! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)

				
				yd = max( yd_MFJ(2*SS(IE) + min(R*A(IA),d_c), IA), yd_MFS(SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE) + min(R*A(IA),d_c)/2 ,IA) )

				! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				X3 = A(IA)
				CONS = (X3 + yd + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)
                CLONG(AGE) = CLONG(AGE) + CONS*coupleYR(AGE,IA,IE)				
				
           END DO
        END DO
    END DO

	DO AGE=1,RETAGE-1
		ALONG(AGE)  = ALONG(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
		ILONG(AGE)  = ILONG(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
		TILONG(AGE) = TILONG(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))		
	END DO
	DO AGE=RETAGE,MAXAGE
		ALONG(AGE) = ALONG(AGE)/(SUM(singleYR(AGE,:,:,:))+SUM(coupleYR(AGE,:,:)))
		TILONG(AGE) = TILONG(AGE)/(SUM(singleYR(AGE,:,:,:))+SUM(coupleYR(AGE,:,:)))
	END DO

!   Compute cross-sectional profiles for a given time period

    DO AGE=1,MAXAGE
        ACROSS(AGE) = ALONG(AGE)*(1+GROWTH)**(1-AGE)
        CCROSS(AGE) = CLONG(AGE)*(1+GROWTH)**(1-AGE)
        ICROSS(AGE) = ILONG(AGE)*(1+GROWTH)**(1-AGE)
	    TICROSS(AGE)= TILONG(AGE)*(1+GROWTH)**(1-AGE)
	    !MCROSS(AGE) = MLONG(AGE)*(1+GROWTH)**(1-AGE)
   	    !HCROSS(AGE) = HLONG(AGE)        
        NCROSS(AGE) = NLONG(AGE)
        LCROSS(AGE) = LLONG_single(AGE,1)+LLONG_single(AGE,2)+LLONG_couple(AGE,1)+LLONG_couple(AGE,2)
     END DO
 

 
END SUBROUTINE

SUBROUTINE compute_gini

!******************
!
!   Finds age profiles for wealth gini coefficient
!
!******************
!
!   Uses:    Parameters:   NGRIDA, RETAGE
!            Variables:    AGE
!            Arrays:       A(:), YW_AGE_A(:,:), YR_AGE_A(:,:)
!                                
!   Returns:   Kgini(:)  
!
!
!   Calls:     gini
!
!******************

    ! ALLOCATE ( Cond_Sur(MAXAGE,NGRIDA,NGRIDH,nn) )

    ! DO AGE=1,RETAGE-1
        ! DO IA=1,NGRIDA
			! DO IH=1,NGRIDH
				! DO IS=1,nn
					! JH = IDCWH(AGE,IA,IH,IS)!                   
					! Cond_Sur(AGE,IA,IH,IS) = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)+c3*H(JH)))    ! update survival rate for each state vector
				! END DO
			! END DO
	   ! END DO
    ! END DO
	          
	! DO AGE=RETAGE,MAXAGE-1
        ! DO IA=1,NGRIDA
			! DO IH=1,NGRIDH
                ! JH = IDCRH(AGE,IA,IH)
 ! !              PRINT*, 'JH=', JH, 'AGE=',AGE,'IA=',IA,'IH=',IH,'IS=',IS
                ! Cond_Sur(AGE,IA,IH,1) = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)+c3*H(JH)))    ! update survival rate for each state vector				
			! END DO
	   ! END DO
    ! END DO       
	          
!  Cumulative survival probabilities

    ! ALLOCATE ( CUMSur(MAXAGE,NGRIDA,NGRIDH,nn), MU_STATE(MAXAGE,NGRIDA,NGRIDH,nn) )

   	! DO IA = 1,NGRIDA
		! DO IH = 1,NGRIDH
		    ! DO IS=1,nn
				    ! CUMSur(1,IA,IH,IS) = 1.00000000/(FLOAT(NGRIDA*NGRIDH*nn))	 			
				! DO AGE=2,MAXAGE
                    ! IF (AGE < RETAGE)  THEN                    
					! CUMSur(AGE,IA,IH,IS) = CUMSur(AGE-1,IA,IH,IS)*Cond_Sur(AGE-1,IA,IH,IS)
                    ! ELSEIF (AGE == RETAGE) THEN
                    ! CUMSur(AGE,IA,IH,1) = CUMSur(AGE-1,IA,IH,IS)*Cond_Sur(AGE-1,IA,IH,IS)
                    ! ELSE
                    ! CUMSur(AGE,IA,IH,1) = CUMSur(AGE-1,IA,IH,1)*Cond_Sur(AGE-1,IA,IH,1)
                    ! END IF
				! END DO
			! END DO
        ! END DO
    ! END DO	

!  State distribution of total population
    
    ! CUM_ALL_SUR = 0.0
    ! DO AGE=1,MAXAGE
        ! DO IA = 1,NGRIDA
			! DO IH = 1,NGRIDH 				
                ! IF (AGE < RETAGE) THEN
                    ! DO IS=1,nn
					    ! CUM_ALL_SUR = CUM_ALL_SUR + CUMSur(AGE,IA,IH,IS)/((1.0+POPG)**(AGE-1))
                    ! END DO
                ! ELSE
                        ! CUM_ALL_SUR = CUM_ALL_SUR + CUMSur(AGE,IA,IH,1)/((1.0+POPG)**(AGE-1))
                ! END IF                
			! END DO
        ! END DO
    ! END DO	
    
!SUM1_MU = 0.0
	! DO IA = 1,NGRIDA
		! DO IH = 1,NGRIDH
			! DO IS=1,nn
 ! !               DO AGE=1,MAXAGE-1
                ! MU_STATE(1,IA,IH,IS) = (1.00000000/(FLOAT(NGRIDA*NGRIDH*nn)))/CUM_ALL_SUR
! !			    	SUM1_MU = MU_STATE(1,IA,IH,IS)
                ! DO AGE=2,MAXAGE
                    ! IF (AGE < RETAGE) THEN
                        ! MU_STATE(AGE,IA,IH,IS) = Cond_Sur(AGE-1,IA,IH,IS)*MU_STATE(AGE-1,IA,IH,IS)/(1.0+POPG)
                    ! ELSEIF  (AGE == RETAGE) THEN
                        ! MU_STATE(AGE,IA,IH,1) = Cond_Sur(AGE-1,IA,IH,IS)*MU_STATE(AGE-1,IA,IH,IS)/(1.0+POPG)
                    ! ELSE
                        ! MU_STATE(AGE,IA,IH,1) = Cond_Sur(AGE-1,IA,IH,1)*MU_STATE(AGE-1,IA,IH,1)/(1.0+POPG)
                    ! END IF
! !                    MU_STATE(AGE+1,IA,IH,IS) = Cond_Sur(AGE,IA,IH,IS)*MU_STATE(AGE,IA,IH,IS)/(1.0+POPG)
! !					SUM1_MU = SUM1_MU + MU_STATE(AGE,IA,IH,IS)
				! END DO
			! END DO
        ! END DO
    ! END DO

! check the value of state-share 
! SUM1_MU = 0.0
! DO AGE = 1,MAXAGE
    ! DO IA = 1,NGRIDA
		! DO IH = 1,NGRIDH
            ! IF (AGE < RETAGE) THEN
			    ! DO IS=1,nn
                    ! SUM1_MU = SUM1_MU + MU_STATE(AGE,IA,IH,IS) 
                ! END DO
            ! ELSE
                ! SUM1_MU = SUM1_MU + MU_STATE(AGE,IA,IH,1)
                ! END IF
        ! END DO
    ! END DO
! END DO

! SUM2_MU = 0.0    
    ! DO IA = 1,NGRIDA
		! DO IH = 1,NGRIDH
			! DO IS=1,nn
               ! IF (ABS(CUMSur(1,IA,IH,IS) - 1.00000000/(FLOAT(NGRIDA*NGRIDH*nn)))>0.000001) then
                 ! PRINT*, 'CUMSur has problem !'
                ! END IF
               ! SUM2_MU = SUM2_MU + CUMSur(1,IA,IH,IS) 
            ! END DO
        ! END DO
    ! END DO


    ! PRINT*, 'SUM1_MU=',SUM1_MU
    ! PRINT*, 'SUM2_MU=',SUM2_MU        
                
!	Check the sum of age share is equal to one
!	IF (ABS(SUM1_MU-1.000000)>0.000001) THEN  
    ! IF (ABS(SUM1_MU-1.000000)>0.001) THEN  
        ! PRINT*, 'The sum of all-state share for the total population is not equal to one at age!'
    ! ELSE
         ! PRINT*, 'The sum of all-state share for the total population is equal to one at age!'
! !		GO TO 999
    ! END IF	 	
	
	
! Compute Gini
	ALLOCATE( X((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH, 5) )  ! wealth: x(:,1), labor income: x(:,2), total income: x(:,3) , consumption: x(:,4)       
	ALLOCATE( D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )	
	!ALLOCATE( D_YW(MAXAGE,NGRIDA,NGRIDR,nn) )
	!ALLOCATE( D_YR(MAXAGE,NGRIDA,NGRIDR) )
	ALLOCATE( D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
	ALLOCATE( D_A( (RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH ) )

! Single working age	
    IY = 0   
    IX = 0
    DO AGE = 1,RETAGE-1
        DO IA = 1,NGRIDA           			
            DO IS = 1,nn 
				DO IE=1,NGRIDEH
					DO IG=1,2
				
                    IX = IX + 1 					
						! JA = IDCWA(AGE,IA,IH,IS)
						! JN = IDCWN(AGE,IA,IH,IS)
						! INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
						! x(IX,1) = A(JA)  ! Wealth level at the begining of each period
						! x(IX,2) = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
						! x(IX,3)	= R(JA)*A(JA) + (1-STAX-MTAX)*INCOME+ ATR(JA)* BEQ*(1.0+GROWTH)**(AGE-1)
						JA = singleIDCWA(AGE,IA,IS,IE,IG)
						JN = singleIDCWN(AGE,IA,IS,IE,IG)
						INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
						PREMIUM = premium_rate*INCOME
						
						IF (AGE>=2) THEN
						IY = IY + 1
						x(IY,1) = A(IA) 	!x(IX,1) = A(JA)  ! Wealth level at the begining of each period
						END IF

						x(IX,2) = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)	! pretax HH labor income											
												
						x(IX,3)	= R*A(IA) + INCOME 	! pretax income including corporate income
						
						! consumption
						!x(IX,4)	= ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + (1.0-STAX-MTAX)*WAGE*EFFLONG(AGE)*W(IS)*N(JN) - A(JA)
						yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
							+(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) + INCOME)/avg_earnings - singlebendy) &
							+(1-tau_c)*max(R*A(IA)-d_c,0.0)

						! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
						X3 =  BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)					 
						x(IX,4)	= X3 + yd + gov_trans - A(JA)

						x(IX,5)	= yd

					END DO 
				END DO
            END DO
        END DO
    END DO

! Couple working age
    DO AGE = 1,RETAGE-1
        DO IA = 1,NGRIDA           			
            DO IS1 = 1,nn 
				DO IS2=1,nn 
					DO IE=1,NGRIDEH
									
                    IX = IX + 1 					
						! JA = IDCWA(AGE,IA,IH,IS)
						! JN = IDCWN(AGE,IA,IH,IS)
						! INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
						! x(IX,1) = A(JA)  ! Wealth level at the begining of each period
						! x(IX,2) = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
						! x(IX,3)	= R(JA)*A(JA) + (1-STAX-MTAX)*INCOME+ ATR(JA)* BEQ*(1.0+GROWTH)**(AGE-1)
						JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
						JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
						JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
						INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
						PREMIUM = premium_rate*INCOME

						IF (AGE>=2) THEN
						IY = IY + 1
						x(IY,1) = A(IA) 	!x(IX,1) = A(JA)  ! Wealth level at the begining of each period
						END IF

						x(IX,2) = INCOME	! pretax labor income											
												
						x(IX,3)	= R*A(IA) + INCOME 	! pretax income including corporate income
						
						! consumption
						!x(IX,4)	= ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + (1.0-STAX-MTAX)*WAGE*EFFLONG(AGE)*W(IS)*N(JN) - A(JA)
						
						! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
						! 	+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
						! 	+(1-tau_c)*max(R*A(IA)-d_c,0.0)

						
						yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c), IA), yd_MFS( WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )


						! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
						X3 =  2*BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)					 
						x(IX,4)	= X3 + yd + 2*gov_trans - A(JA)

						x(IX,5)	= yd

					END DO 
				END DO
            END DO
        END DO
    END DO

! Single retiree    
    ! DO AGE = RETAGE,MAXAGE-1           ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
	DO AGE = RETAGE,MAXAGE
        DO IA = 1,NGRIDA      
			DO IE = 1,NGRIDEH	
				DO IG=1,2

                IX = IX + 1 
				IY = IY + 1                                                                                                   
                ! JA = IDCRA(AGE,IA,IH)     
                ! x(IX,1) = A(JA) 
				! x(IX,3) = R(JA)*A(JA) + SS + ATR(JA)* BEQ*(1.0+GROWTH)**(AGE-1)   
				JA = singleIDCRA(AGE,IA,IE,IG) 
			

                x(IY,1) = A(IA)		!A(JA) 
				 				 
				x(IX,3)	= R*A(IA) + SS(IE)

				!x(IX,4)	= ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA)
				yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + SS(IE))/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + SS(IE))/avg_earnings))**(-tau_l_single) &
					 +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+SS(IE))/avg_earnings - singlebendy) &
					 +(1-tau_c)*max(R*A(IA)-d_c,0.0)

				! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				X3 =  A(IA)	 
				x(IX,4)	= X3 + yd + gov_trans + medicare - A(JA) 

				x(IX,5)	= yd

				END DO  
            END DO
        END DO
    END DO 

! couple retiree    
    ! DO AGE = RETAGE,MAXAGE-1           ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
	DO AGE = RETAGE,MAXAGE
        DO IA = 1,NGRIDA      
			DO IE = 1,NGRIDEH	
				
                IX = IX + 1 
				IY = IY + 1                                                                                                   
                ! JA = IDCRA(AGE,IA,IH)     
                ! x(IX,1) = A(JA) 
				! x(IX,3) = R(JA)*A(JA) + SS + ATR(JA)* BEQ*(1.0+GROWTH)**(AGE-1)   
				JA = coupleIDCRA(AGE,IA,IE)     
                x(IY,1) = A(IA)		!A(JA) 
				 				 
				x(IX,3)	= R*A(IA) + 2*SS(IE)  

				!x(IX,4)	= ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA)

				! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + 2*SS(IE)))**(1.0-tau_l_couple) &
				! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+2*SS(IE) - couplebendy) &
				! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)

				
				yd = max( yd_MFJ( 2*SS(IE) + min(R*A(IA),d_c), IA), yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA) )


				! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				X3 =  A(IA)	 
				x(IX,4)	= X3 + yd + 2*medicare + 2*gov_trans - A(JA) 

				x(IX,5)	= yd
								  
            END DO
        END DO
    END DO 

!************************************************  
!   Initialize Sur-adjusted joint distributions

!      DO AGE=1,RETAGE-1
!         DO IA=1,NGRIDA
! 		   DO IR=1,NGRIDR
! 			  DO IS=1,nn
!                  !D_YW(AGE,IA,IH,IS)=0.0
! 				  D_YW(AGE,IA,IR,IS)=0.0
! 			  END DO
!            END DO
!         END DO
!      END DO

! 	DO AGE=RETAGE,MAXAGE
!         DO IA=1,NGRIDA
!            !DO IH=1,NGRIDH
! 		    DO IR=1,NGRIDR
!               !D_YR(AGE,IA,IH)=0.0
! 			  D_YR(AGE,IA,IR)=0.0
!            END DO
!         END DO
!      END DO
	
! ! use invariant distribution or unconditional distribution of labor productivity	
	
!     DO AGE = 1,RETAGE-1		
!         DO IA = 1,NGRIDA            
! 			DO IR = 1,NGRIDR
!                 DO IS = 1,nn                                                                                                                                                      
                    
! 				 D_YW(AGE,IA,IR,IS) = YW(AGE,IA,IR,IS)*MU(AGE)								
 					
! 				!  D_YW(AGE,JA,1,1) = D_YW(AGE,JA,1,1) + D_YW(AGE-1,IA,IR,IS)*P(IS,1)*P_r(IR,1)*SUR
! 				!  D_YW(AGE,JA,2,1) = D_YW(AGE,JA,2,1) + D_YW(AGE-1,IA,IR,IS)*P(IS,1)*P_r(IR,2)*SUR
				 
! 				!  D_YW(AGE,JA,1,2) = D_YW(AGE,JA,1,2) + D_YW(AGE-1,IA,IR,IS)*P(IS,2)*P_r(IR,1)*SUR
! 				!  D_YW(AGE,JA,2,2) = D_YW(AGE,JA,2,2) + D_YW(AGE-1,IA,IR,IS)*P(IS,2)*P_r(IR,2)*SUR
				 
! 				!  D_YW(AGE,JA,1,3) = D_YW(AGE,JA,1,3) + D_YW(AGE-1,IA,IR,IS)*P(IS,3)*P_r(IR,1)*SUR
! 				!  D_YW(AGE,JA,2,3) = D_YW(AGE,JA,2,3) + D_YW(AGE-1,IA,IR,IS)*P(IS,3)*P_r(IR,2)*SUR

! 				!  D_YW(AGE,JA,1,4) = D_YW(AGE,JA,1,4) + D_YW(AGE-1,IA,IR,IS)*P(IS,4)*P_r(IR,1)*SUR
! 				!  D_YW(AGE,JA,2,4) = D_YW(AGE,JA,2,4) + D_YW(AGE-1,IA,IR,IS)*P(IS,4)*P_r(IR,2)*SUR
				 
! 				!  D_YW(AGE,JA,1,5) = D_YW(AGE,JA,1,5) + D_YW(AGE-1,IA,IR,IS)*P(IS,5)*P_r(IR,1)*SUR
! 				!  D_YW(AGE,JA,2,5) = D_YW(AGE,JA,2,5) + D_YW(AGE-1,IA,IR,IS)*P(IS,5)*P_r(IR,2)*SUR
				 
! 				!  D_YW(AGE,JA,1,6) = D_YW(AGE,JA,1,6) + D_YW(AGE-1,IA,IR,IS)*P(IS,6)*P_r(IR,1)*SUR
! 				!  D_YW(AGE,JA,2,6) = D_YW(AGE,JA,2,6) + D_YW(AGE-1,IA,IR,IS)*P(IS,6)*P_r(IR,2)*SUR
				 
!                 END DO
!             END DO
!         END DO
!     END DO
	

! 	DO AGE=RETAGE,MAXAGE
!         DO IA=1,NGRIDA
! 		   DO IR=1,NGRIDR
		      
! 			  D_YR(AGE,IA,IR) = YR(AGE,IA,IR)*MU(AGE)		
	         
!            END DO
!         END DO
!      END DO
!******************************************	
! Normalize Distribution
ID = 0
IDA = 0
! Single working
    DO AGE = 1,RETAGE-1
        DO IA = 1,NGRIDA
            DO IS = 1,nn 
				DO IE=1,NGRIDEH
					DO IG=1,2

                    ID = ID + 1                                                                                                    
                    !D(ID) = D_YW(AGE,IA,IH,IS)
					!D_inc(ID) = D_YW(AGE,IA,IH,IS)
					D(ID) = singleYW(AGE,IA,IS,IE,IG)
					D_inc(ID) = singleYW(AGE,IA,IS,IE,IG)

					IF (AGE>=2)	THEN
					IDA = IDA+1
					D_A(IDA) = singleYW(AGE,IA,IS,IE,IG)
					END IF 

					END DO 
                END DO
            END DO
        END DO
    END DO

! Couple working
    DO AGE = 1,RETAGE-1
        DO IA = 1,NGRIDA
            DO IS1 = 1,nn 
				DO IS2=1,nn
					DO IE=1,NGRIDEH
					
                    ID = ID + 1                                                                                                    
                    !D(ID) = D_YW(AGE,IA,IH,IS)
					!D_inc(ID) = D_YW(AGE,IA,IH,IS)
					D(ID) = coupleYW(AGE,IA,IS1,IS2,IE)
					D_inc(ID) = coupleYW(AGE,IA,IS1,IS2,IE)

					IF (AGE>=2)	THEN
					IDA = IDA+1
					D_A(IDA) = coupleYW(AGE,IA,IS1,IS2,IE)
					END IF 

					END DO 
                END DO
            END DO
        END DO
    END DO

! Single retiree	    
    !DO AGE = RETAGE,MAXAGE-1
	DO AGE = RETAGE,MAXAGE    ! COUNT THE LAST PERIOD PEOPLE THOUGH SAVING IS ZERO
        DO IA = 1,NGRIDA
			DO IE = 1,NGRIDEH
	  			DO IG=1,2

                    ID = ID + 1                                                                                                    
                    IDA = IDA + 1

					D(ID) = singleYR(AGE,IA,IE,IG)						
					D_A(IDA) = singleYR(AGE,IA,IE,IG)	

				END DO 	
            END DO
        END DO
    END DO

! Couple retiree	    
    !DO AGE = RETAGE,MAXAGE-1
	DO AGE = RETAGE,MAXAGE    ! COUNT THE LAST PERIOD PEOPLE THOUGH SAVING IS ZERO
        DO IA = 1,NGRIDA
			DO IE = 1,NGRIDEH
	  			
                ID = ID + 1                                                                                                    
                IDA = IDA + 1

				D(ID) = coupleYR(AGE,IA,IE)						
				D_A(IDA) = coupleYR(AGE,IA,IE)	
						
            END DO
        END DO
    END DO

   
   D(:) = D(:)/sum(D)
   D_inc(:) = D_inc(:)/sum(D_inc)
   D_A(:) = D_A(:)/sum(D_A)
   
 !PRINT*,'sum of D_inc(:) =',sum(D_inc)

    wea_gini = gini(x(:,1),D_A)	!gini(x(:,1),D)
	inc_gini = gini(x(:,2),D_inc) ! earning gini
	! tinc_gini = gini(x(:,3),D_inc)    ! yginiworkers, only for working ages
	tinc_gini = gini(x(:,3),D)		! Full population
	cons_gini = gini(x(:,4),D)
	yd_gini = gini(x(:,5),D)

	! evar = sum(YG_mat(1:Nstar/2*Ngrid,2) * (log(YG_mat(1:Nstar/2*Ngrid,6)) - &
  	! 	 dot_product(log(YG_mat(1:Nstar/2*Ngrid,6)), YG_mat(1:Nstar/2*Ngrid,2))/(1.D0-retirees))**2) &
  	! 	 / (1.D0-retirees)


!Variance of log earnings
! print*, 'incvar2=',dot_product( D_inc , ( log(x(1:(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,2)+1.D-5) - dot_product(log(x(1:(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,2)+1.D-5),D_inc(:)) )**2 )  		
! Do i=1,(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH
! 	if ( x(i,2)==0.000 ) then
! 	 x(i,2) = 0.00000001
! 	 end if
! END DO
WRITE(12,*) x(:,2)

! incvar = dot_product( D_inc(:) , ( log(x(1:(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,2)) - dot_product(log(x(1:(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,2)),D_inc(:)) )**2 )

mean_incvar = 0.0
DO i=1,(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH
	IF (x(i,2)>0.0) THEN 
		mean_incvar = mean_incvar + log(x(i,2))*D_inc(i)
	END IF 
END DO 

incvar = 0.0
DO i=1,(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH
	IF (x(i,2)>0.0) THEN 
		incvar = incvar + ((log(x(i,2))-mean_incvar)**2)*D_inc(i)
	END IF 
END DO 

!*********************************************************
!    	L = size(x)
!        print*, 'L=',L
!	g = 0
!	do i = 1, L, 1
!		do j = 1, L, 1
!			g = g + D(i)*D(j)* abs(x(i)-x(j))
!		end do
!    end do
!    print*, 'g=',g
   
!	g = g/(2*dot_product(x,D))
!	gini = g
!    print*, 'wealth gini=',gini
!    print*, 'average=',dot_product(x,D)
!********************************************************
  
 !   kgini = gini(x,D)   

  print*, 'wealth gini=',wea_gini 
  print*, 'income gini=',inc_gini 
  print*, 'total income gini=',tinc_gini 
  print*, 'consumption gini=',cons_gini 
  print*, 'after-tax gini=',yd_gini 
  
  ! print*, 'W(1)=', W(1)  
  ! print*, 'W(2)=', W(2)
  ! print*, 'W(3)=', W(3)
  ! print*, 'W(4)=', W(4)    
  
END SUBROUTINE

SUBROUTINE age_wealth_gini 

    !ALLOCATE ( x_age(NGRIDA*NGRIDH*nn, MAXAGE-1) ) 
   ! ALLOCATE ( D_age(NGRIDA*NGRIDH*nn, MAXAGE-1), NorD_age(NGRIDA*NGRIDH*nn, MAXAGE-1) )
    !ALLOCATE ( age_wea_gini(MAXAGE-1) )
	ALLOCATE( x_age(NGRIDA*nn*NGRIDEH*2+NGRIDA*nn*nn*NGRIDEH, MAXAGE) ) 
    ALLOCATE( D_age(NGRIDA*nn*NGRIDEH*2+NGRIDA*nn*nn*NGRIDEH, MAXAGE), NorD_age(NGRIDA*nn*NGRIDEH*2+NGRIDA*nn*nn*NGRIDEH, MAXAGE) )
    ALLOCATE( age_wea_gini(MAXAGE) )
    
! Single working age    
    DO AGE = 1,RETAGE-1
        IX = 0
        DO IA = 1,NGRIDA
            DO IS = 1,nn 
				DO IE=1,NGRIDEH  
					DO IG=1,2

                    IX = IX + 1                                                                                                    
                    
					!JA = IDCWA(AGE,IA,IR,IS)
					x_age(IX,AGE) = A(IA)	!A(JA) 					
                    !x_age(IX,AGE+1) = A(JA)

					END DO 
                END DO
            END DO
        END DO

! Couple working age
		DO IA = 1,NGRIDA           			
            DO IS1 = 1,nn 
				DO IS2=1,nn 
					DO IE=1,NGRIDEH
									
                    IX = IX + 1
					x_age(IX,AGE) = A(IA)	

					END DO 
				END DO
            END DO
        END DO

    END DO

! Single retiree      
    DO AGE = RETAGE,MAXAGE           
        IX = 0
        DO IA = 1,NGRIDA             
			DO IE = 1,NGRIDEH
				DO IG=1,2	

                	IX = IX + 1                                                                                                                      
					!JA = IDCRA(AGE,IA,IR)
					x_age(IX,AGE) = A(IA)	!A(JA)   				
               		!x_age(IX,AGE+1) = A(JA)

				END DO                 
            END DO
        END DO

! couple retiree 
		DO IA = 1,NGRIDA      
			DO IE = 1,NGRIDEH	

				IX = IX + 1                                                                                                                      
				x_age(IX,AGE) = A(IA)

			END DO                 
        END DO
				
    END DO 
     
! Single working    
    DO AGE = 1,RETAGE-1
        ID = 0
        DO IA = 1,NGRIDA
            DO IS = 1,nn    
				DO IE=1,NGRIDEH
					DO IG=1,2                                                                                                                                                    
			
                   	 ID = ID + 1                                                                                                                        
					 D_age(ID,AGE) = singleYW(AGE,IA,IS,IE,IG)
					 !D_age(ID,AGE+1) = D_YW(AGE+1,IA,IR,IS)

					END DO 
                END DO
            END DO
        END DO

! Couple working
		DO IA = 1,NGRIDA
            DO IS1 = 1,nn 
				DO IS2=1,nn
					DO IE=1,NGRIDEH

						ID = ID + 1
						D_age(ID,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)

					END DO 
                END DO
            END DO
        END DO

    END DO

! Single retiree	    
    DO AGE = RETAGE,MAXAGE
        ID = 0
        DO IA = 1,NGRIDA  
			DO IE = 1,NGRIDEH
	  			DO IG=1,2 			
                	
					ID = ID + 1                                                                                                    
					D_age(ID,AGE) = singleYR(AGE,IA,IE,IG)	
					!D_age(ID,AGE+1) = D_YR(AGE+1,IA,IR)	

                END DO     
            END DO
        END DO

! Couple retiree	
		DO IA = 1,NGRIDA
			DO IE = 1,NGRIDEH

				ID = ID + 1
				D_age(ID,AGE) = coupleYR(AGE,IA,IE)	

			END DO 
		END DO 	

    END DO
!**********************************
 print*, '-------------------------------------------------------------'
DO AGE = 1,MAXAGE 
  
   PRINT*,'sum of non normalized D_age(:,AGE) at age',AGE,'=',sum(D_age(:,AGE))
   PRINT*,'sum of x_age(:,AGE) at age',AGE,'=',sum(x_age(:,AGE))
   PRINT*,'dot product of D_age*x_age at age',AGE,'=',dot_product(x_age(:,AGE),D_age(:,AGE))
   print*,'************************************************************'
END DO   
    
!***********************************    
! Normalize the D_age    
DO AGE = 1,MAXAGE 
   NorD_age(:,AGE) = D_age(:,AGE)/sum(D_age(:,AGE))    
!   PRINT*,'age=',AGE
   PRINT*,'sum of normalized D_age(:,AGE) at age',AGE,'=',sum(NorD_age(:,AGE)) 
END DO
 PRINT*,'********************************************************************'  
   DO AGE = 1,MAXAGE
      age_wea_gini(AGE) = gini(x_age(:,AGE), NorD_age(:,AGE))
!      PRINT*,'sum of normalized D_age(:,AGE) at age',AGE+1,'=',sum(NorD_age(:,AGE))
      PRINT*,'age_wea_gini at age',AGE,'=',age_wea_gini(AGE)
      print*,' '
   END DO

END SUBROUTINE

SUBROUTINE sorting(n,a)

INTEGER n
REAL(prec), DIMENSION(:):: a(n)
             
!Sorts an array a(1:n) into ascending numerical order by Shell’s method (diminishing increment
!sort). n is input; a is replaced on output by its sorted rearrangement.

INTEGER i,j,inc
REAL v

	inc=1 							!Determine the starting increment.
1 	inc=3*inc+1
	if(inc.le.n) goto 1
2 	continue 						!Loop over the partial sorts.
	inc=inc/3
	do  i=inc+1,n 					!Outer loop of straight insertion.
		v=a(i)
		j=i
3 		if(a(j-inc).gt.v) then 			!Inner loop of straight insertion.
			a(j)=a(j-inc)
			j=j-inc
			if(j.le.inc) goto 4
			goto 3
		end if
4 		a(j)=v
	end do 
	
	if(inc.gt.1) goto 2
!return
END SUBROUTINE

!************************************************************************************************************
SUBROUTINE wealthshare

ALLOCATE( sort_A((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) ) 
ALLOCATE( sort_A_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2) )
ALLOCATE( sort_A_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH)  )   
ALLOCATE( sort_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( temp_sort_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( sort_D_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2) )
ALLOCATE( sort_D_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH)  )
ALLOCATE( cum_sort_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top0001pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top0005pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top001pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top005pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top01pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top05pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top1pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top5pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top10pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top20pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top40pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top50pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top60pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top70pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top80pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top90pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top95pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top99pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( record_position_A((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( record_position_A_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2) )
ALLOCATE( record_position_A_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH)  ) 
ALLOCATE( box((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
 

!***************************This part is removed and the updated sorting agglorithm is replaced (Dec12,2019)*****************
! ! Single working age	
! isort=0
! DO AGE=2,RETAGE-1
!     DO IA=1,NGRIDA
! 		DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2                    
                
!                  !IF ( D_YW(AGE,IA,IH,IS) > 0 ) THEN
!                  isort=isort+1
                 
! 				 !JA=IDCWA(AGE,IA,IR,IS)                
!                  sort_A(isort) = A(IA)	!A(JA)
!                  !END IF
!                 END DO 
!             END DO
!         END DO 
!     END DO
! END DO

! ! Couple working age
! DO AGE = 2,RETAGE-1
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH
						
!                  	isort=isort+1
!                  	sort_A(isort) = A(IA)	!A(JA)

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO
                 
				             
! ! Single retiree 
! !DO AGE=RETAGE,MAXAGE-1  (for the case of no bequest)
! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA
! 		DO IE = 1,NGRIDEH	
! 			DO IG=1,2
            
!              !IF ( D_YR(AGE,IA,IH) > 0 ) THEN
!              isort=isort+1
            
! 			 !JA=IDCRA(AGE,IA,IR)
!              sort_A(isort) = A(IA)	!A(JA)
!              !END IF

!             END DO 
!         END DO 
!     END DO
! END DO 

! ! couple retiree    
! ! DO AGE = RETAGE,MAXAGE-1           ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
! DO AGE = RETAGE,MAXAGE
!     DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH

! 			isort=isort+1
!          	sort_A(isort) = A(IA)	!A(JA)	               
        
! 		END DO
!     END DO
! END DO     
			

! CALL sorting(size(sort_A),sort_A)       ! sort in ascending order
! !Aggwealth = dot_product(x,D)
! !WRITE(*,10) (SORT_A(I),I=1,size(sort_A)) 
! !print*, sort_A(:)

! !WRITE(20,*) sort_A(:)

! DO i = 1,size(sort_A)
!     if (sort_A(i) > A(1)) then
! 	pos_zero_k = i-1
!     print*, 'location of first positive sort_A elements=',i
!     go to 102
!     end if 
! end do
! 102 continue

! !CALL sort_write(INT(size(sort_A)),sort_A)
! !print *,' '
  
! !  10 FORMAT(10F6.1)


! ! Define the quintile and top 10%, 5%, 1%
! !Q1 = size(sort_A)/5
! !Q2 = 2*Q1
! !Q3 = 3*Q1
! !Q4 = 4*Q1
! !Q5 = 5*Q1
! !Top10pct =  90*size(sort_A)/100
! !Top05pct = 95*size(sort_A)/100
! !Top01pct = 99*size(sort_A)/100

! ! Calculate the population of Q1-Q5, 10%, 5%, 1%

 
! ! DO i = 1,size(sort_A) 
!  ! sort_D(i) = 0.0
! ! END DO


! DO i = 1,size(sort_A)
! 	box(i)= 0
! END DO

! ! Single working age
! index_A = 0
! DO AGE=2,RETAGE-1
!     DO IA=1,NGRIDA
! 		DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2 

!                		index_A = index_A + 1
               		
! 					!JA=IDCWA(AGE,IA,IR,IS)
!                 	!i = search(A(JA), sort_A, box)
! 					i = search(A(IA), sort_A, box,1.D-6)
                
! 					sort_D(i) = singleYW(AGE,IA,IS,IE,IG)
! 					record_position_A(index_A) = i

!                 END DO                   
!             END DO
!         END DO
!     END DO
! END DO

! ! Couple working
! DO AGE = 2,RETAGE-1
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 					index_A = index_A + 1
! 					i = search(A(IA), sort_A, box,1.D-6)
! 					sort_D(i) = coupleYW(AGE,IA,IS1,IS2,IE)
! 					record_position_A(index_A) = i

! 				END DO                   
!             END DO
!         END DO
!     END DO
! END DO

! ! Single retiree
! !DO AGE=RETAGE,MAXAGE-1 . (case for no bequest)
! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA
! 		DO IE = 1,NGRIDEH	
! 			DO IG=1,2

!              index_A = index_A + 1	
                           
! 			 !JA=IDCRA(AGE,IA,IR)
!              ! i = search(A(JA), sort_A, box)
! 			 i = search(A(IA), sort_A, box,1.D-6)
! 			 sort_D(i) = singleYR(AGE,IA,IE,IG)
! 			 record_position_A(index_A) = i	

!             END DO     
!         END DO
!     END DO
! END DO
            
! ! couple retiree    
! ! DO AGE = RETAGE,MAXAGE-1           ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
! DO AGE = RETAGE,MAXAGE
!     DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH   

! 			index_A = index_A + 1
! 			i = search(A(IA), sort_A, box,1.D-6)
! 			sort_D(i) = coupleYR(AGE,IA,IE)
! 			record_position_A(index_A) = i

! 		END DO
!     END DO
! END DO  


!*********************Use SSORT_INT (Dec12,2019)*******************************

! Single working
index_A = 0
index_A_single = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2

					index_A = index_A + 1
					index_A_single = index_A_single + 1

			   		sort_A(index_A) = A(IA)	
					sort_A_single(index_A_single) = A(IA)	!define

					sort_D(index_A) = singleYW(AGE,IA,IS,IE,IG)
					sort_D_single(index_A_single) = singleYW(AGE,IA,IS,IE,IG)
					
					record_position_A(index_A) = index_A
					record_position_A_single(index_A_single) = index_A_single
					
				END DO
			END DO		
		END DO
	END DO
END DO

! Single retired
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IE = 1,NGRIDEH	
			DO IG=1,2

				index_A = index_A + 1
				index_A_single = index_A_single + 1

				sort_A(index_A) = A(IA)	
				sort_A_single(index_A_single) = A(IA)

				sort_D(index_A) = singleYR(AGE,IA,IE,IG)
				sort_D_single(index_A_single) = singleYR(AGE,IA,IE,IG)
					
				record_position_A(index_A) = index_A
				record_position_A_single(index_A_single) = index_A_single
			
			END DO     
        END DO
    END DO
END DO

! Couple working
index_A_couple = 0
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					index_A = index_A + 1
					index_A_couple = index_A_couple + 1

					sort_A(index_A) = A(IA)	
					sort_A_couple(index_A_couple) = A(IA)

					sort_D(index_A) = coupleYW(AGE,IA,IS1,IS2,IE)
					sort_D_couple(index_A_couple) = coupleYW(AGE,IA,IS1,IS2,IE)

					record_position_A(index_A) = index_A
					record_position_A_couple(index_A_couple) = index_A_couple
				
				END DO
			END DO		
		END DO
	END DO
END DO

! Couple retired
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH   

			index_A = index_A + 1
			index_A_couple = index_A_couple + 1

			sort_A(index_A) = A(IA)	
			sort_A_couple(index_A_couple) = A(IA)

			sort_D(index_A) = coupleYR(AGE,IA,IE)
			sort_D_couple(index_A_couple) = coupleYR(AGE,IA,IE)

			record_position_A(index_A) = index_A
			record_position_A_couple(index_A_couple) = index_A_couple

		END DO
    END DO
END DO  


! the following two lines replicate what one could do with sortrows in Matlab:
CALL SSORT_INT(sort_A,record_position_A,size(sort_A),2)
temp_sort_D(:) = sort_D(record_position_A)
sort_D = temp_sort_D

!**********************************************************************
sort_D = sort_D/sum(sort_D)

cum_sort_D(1) = sort_D(1)
DO i = 2,size(sort_D)
	cum_sort_D(i) = cum_sort_D(i-1)+sort_D(i)
END DO
print*, 'cum_sort_D=',cum_sort_D(size(sort_D))

! Identify wealth fractile agents
DO i = 1,size(sort_D)
	top0001pct_D(i) = 0
	top0005pct_D(i) = 0
    top001pct_D(i) = 0
	top005pct_D(i) = 0
	top01pct_D(i) = 0
	top05pct_D(i) = 0
    top1pct_D(i) = 0
	top5pct_D(i) = 0
  	top10pct_D(i) = 0
  	top20pct_D(i) = 0
  	top40pct_D(i) = 0
	top50pct_D(i) = 0
  	top60pct_D(i) = 0
	top70pct_D(i) = 0
  	top80pct_D(i) = 0 
	top90pct_D(i) = 0
	top95pct_D(i) = 0
	top99pct_D(i) = 0
END DO

where ( cum_sort_D(1:size(sort_D)) > 1-0.00001 ) top0001pct_D = 1
where ( cum_sort_D(1:size(sort_D)) > 1-0.00005 ) top0005pct_D = 1
where ( cum_sort_D(1:size(sort_D)) > 1-0.0001 ) top001pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.0005 ) top005pct_D = 1
where ( cum_sort_D(1:size(sort_D)) > 1-0.001 ) top01pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.005 ) top05pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.01 ) top1pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.05 ) top5pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.1 ) top10pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.2 ) top20pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.4 ) top40pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.5 ) top50pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.6 ) top60pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.7 ) top70pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.8 ) top80pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.9 ) top90pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.95 ) top95pct_D = 1 
where ( cum_sort_D(1:size(sort_D)) > 1-0.99 ) top99pct_D = 1 


! WHERE ( sort_A == sort_A(Q1)  )  Q1_D = 1
! WHERE ( sort_A == sort_A(Q2)  )  Q2_D = 1
! WHERE ( sort_A == sort_A(Q3)  )  Q3_D = 1
! WHERE ( sort_A == sort_A(Q4)  )  Q4_D = 1
! WHERE ( sort_A == sort_A(Q5)  )  Q5_D = 1
! WHERE ( sort_A >= sort_A(TOP10PCT)  )  top10pct_D = 1
! WHERE ( sort_A >= sort_A(TOP05PCT)  )  top05pct_D = 1
! WHERE ( sort_A >= sort_A(TOP01PCT)  )  top01pct_D = 1
!INDEX = 0
!DO AGE=1,RETAGE-1
!    DO IA=1,NGRIDA
!        DO IH=1,NGRIDH
 !           DO IS=1,nn
!                
!                IF ( D_YW(AGE,IA,IH,IS) > 0 ) THEN
!                    JA=IDCWA(AGE,IA,IH,IS)
!                    INDEX=INDEX+1
!                     IF ( A(JA) == sort_A(Q1) ) THEN
!                         Q1_D(INDEX) = 1
!                     ELSEIF ( A(JA) == sort_A(Q2) ) THEN
!                         Q2_D(INDEX) = 1
!                     ELSEIF ( A(JA) == sort_A(Q3) ) THEN
!                         Q3_D(INDEX) = 1
!                     ELSEIF ( A(JA) == sort_A(Q4) ) THEN
!                         Q4_D(INDEX) = 1
!                     ELSEIF ( A(JA) == sort_A(Q5) ) THEN
!                         Q5_D(INDEX) = 1
!                     ELSEIF ( A(JA) >= sort_A(TOP10PCT) ) THEN
!                         TOP10PCT_D(INDEX) = 1
!                     ELSEIF ( A(JA) >= sort_A(TOP05PCT) ) THEN
!                         TOP05PCT_D(INDEX) = 1
!                     ELSEIF ( A(JA) >= sort_A(TOP01PCT) ) THEN
!                         TOP01PCT_D(INDEX) = 1
!                     END IF
!                END IF 
                
!            END DO
!        END DO
!    END DO
!END DO

!DO AGE=RETAGE,MAXAGE-1
!    DO IA=1,NGRIDA
!        DO IH=1,NGRIDH  
!            
!             IF ( D_YR(AGE,IA,IH) > 0 ) THEN
!                JA=IDCRA(AGE,IA,IH)
!                INDEX=INDEX+1
!                IF ( A(JA) == sort_A(Q1) ) THEN
!                     Q1_D(INDEX) = 1
!                ELSEIF ( A(JA) == sort_A(Q2) ) THEN
!                    Q2_D(INDEX) = 1
!                ELSEIF ( A(JA) == sort_A(Q3) ) THEN
!                    Q3_D(INDEX) = 1
!!                ELSEIF ( A(JA) == sort_A(Q4) ) THEN
!                    Q4_D(INDEX) = 1
!                ELSEIF ( A(JA) == sort_A(Q5) ) THEN
!                    Q5_D(INDEX) = 1
!                ELSEIF ( A(JA) >= sort_A(TOP10PCT) ) THEN
!                    TOP10PCT_D(INDEX) = 1
!                ELSEIF ( A(JA) >= sort_A(TOP05PCT) ) THEN
!                    TOP05PCT_D(INDEX) = 1
!                ELSEIF ( A(JA) >= sort_A(TOP01PCT) ) THEN
!                    TOP01PCT_D(INDEX) = 1
!!                END IF
!             END IF
             
           
!        END DO
!    END DO
!END DO


! DO i = 1,size(sort_A)
		! sort_AD(i) = sort_A(i)*sort_D(i)
! END DO
Aggwealth = dot_product(sort_A,sort_D)

    ! Q1share = (dot_product(sort_AD,Q1_D))/Aggwealth 
    ! Q2share = (dot_product(sort_AD,Q2_D))/Aggwealth 
	! Q3share = (dot_product(sort_AD,Q3_D))/Aggwealth	
	! Q4share = (dot_product(sort_AD,Q4_D))/Aggwealth
	! Q5share = (dot_product(sort_AD,Q5_D))/Aggwealth
	! TOP10PCTshare = (dot_product(sort_AD,TOP10PCT_D))/Aggwealth
	! TOP05PCTshare = (dot_product(sort_AD,TOP05PCT_D))/Aggwealth
	! TOP01PCTshare = (dot_product(sort_AD,TOP01PCT_D))/Aggwealth
	
	kshare0001 = sum(sort_A*sort_D*top0001pct_D)/Aggwealth
	kshare0005 = sum(sort_A*sort_D*top0005pct_D)/Aggwealth
	kshare001 = sum(sort_A*sort_D*top001pct_D)/Aggwealth
	kshare005 = sum(sort_A*sort_D*top005pct_D)/Aggwealth
	kshare01 = sum(sort_A*sort_D*top01pct_D)/Aggwealth
	kshare05 = sum(sort_A*sort_D*top05pct_D)/Aggwealth
	kshare1 = sum(sort_A*sort_D*top1pct_D)/Aggwealth
	kshare5 = sum(sort_A*sort_D*top5pct_D)/Aggwealth
	kshare10 = sum(sort_A*sort_D*top10pct_D)/Aggwealth
	kshare20 = sum(sort_A*sort_D*top20pct_D)/Aggwealth
	kshare40 = sum(sort_A*sort_D*top40pct_D)/Aggwealth
	kshare60 = sum(sort_A*sort_D*top60pct_D)/Aggwealth
	kshare80 = sum(sort_A*sort_D*top80pct_D)/Aggwealth

! Normalize the wealth level by average
	klevel0001 = ( sum(sort_A*sort_D*top0001pct_D)/sum(sort_D*top0001pct_D) )/Aggwealth
	klevel0005 = ( sum(sort_A*sort_D*top0005pct_D)/sum(sort_D*top0005pct_D) )/Aggwealth
	klevel001 = ( sum(sort_A*sort_D*top001pct_D)/sum(sort_D*top001pct_D) )/Aggwealth
	klevel01 = ( sum(sort_A*sort_D*top01pct_D)/sum(sort_D*top01pct_D) )/Aggwealth
	klevel05 = ( sum(sort_A*sort_D*top05pct_D)/sum(sort_D*top05pct_D) )/Aggwealth
	klevel1 = ( sum(sort_A*sort_D*top1pct_D)/sum(sort_D*top1pct_D) )/Aggwealth
	klevel5 = ( sum(sort_A*sort_D*top5pct_D)/sum(sort_D*top5pct_D) )/Aggwealth
	klevel10 = ( sum(sort_A*sort_D*top10pct_D)/sum(sort_D*top10pct_D) )/Aggwealth
	klevel20 = ( sum(sort_A*sort_D*top20pct_D)/sum(sort_D*top20pct_D) )/Aggwealth
	klevel40 = ( sum(sort_A*sort_D*top40pct_D)/sum(sort_D*top40pct_D) )/Aggwealth
	klevel60 = ( sum(sort_A*sort_D*top60pct_D)/sum(sort_D*top60pct_D) )/Aggwealth
	klevel80 = ( sum(sort_A*sort_D*top80pct_D)/sum(sort_D*top80pct_D) )/Aggwealth
	klevel9599 = ( sum(sort_A*sort_D*(top5pct_D-top1pct_D))/sum(sort_D*(top5pct_D-top1pct_D)) )/Aggwealth
	klevel9095 = ( sum(sort_A*sort_D*(top10pct_D-top5pct_D))/sum(sort_D*(top10pct_D-top5pct_D)) )/Aggwealth
	klevel6080 = ( sum(sort_A*sort_D*(top40pct_D-top20pct_D))/sum(sort_D*(top40pct_D-top20pct_D)) )/Aggwealth
	klevel4060 = ( sum(sort_A*sort_D*(top60pct_D-top40pct_D))/sum(sort_D*(top60pct_D-top40pct_D)) )/Aggwealth
	klevel2040 = ( sum(sort_A*sort_D*(top80pct_D-top60pct_D))/sum(sort_D*(top80pct_D-top60pct_D)) )/Aggwealth

	share_zero_k = sum(sort_D(1:INT(pos_zero_k)))
! 	find threshold for being in the top 1, 10% of wealth
	! do i = size(sort_D), 1, -1
  		! if (top1pct_D(i) < 1) then
  			! j = i
  			! exit
  		! end if
  	! end do
  	! if (j < size(sort_D)) then 
  		! wealththreshold1 = A(j+1)
  	! else
  		! wealththreshold1 = A(j)
  	! end if
	
  	! do i = size(sort_D), 1, -1
  		! if (top10pct_D(i) < 1) then
  			! j = i
  			! exit
  		! end if
  	! end do
  	! if (j < size(sort_D)) then 
  		! wealththreshold10 = A(j+1)
  	! else
  		! wealththreshold10 = A(j)
  	! end if

	print*, 'kshare0001 =',kshare0001
	print*, 'kshare0005 =',kshare0005
	print*, 'kshare001 =',kshare001
	print*, 'kshare01 =',kshare01
	print*, 'kshare05 =',kshare05
	print*, 'kshare1 =',kshare1 
	print*, 'kshare5 =',kshare5
	print*, 'kshare10 =',kshare10 
	print*, 'kshare20 =',kshare20
	print*, 'kshare40 =',kshare40
	print*, 'kshare60 =',kshare60
	print*, 'kshare80 =',kshare80  
!    PRINT*, 'wealththreshold1=',wealththreshold1
!    PRINT*, 'wealththreshold10=',wealththreshold10
	
	print*,'Aggwealth=',Aggwealth

	
!	print*,'size(sort_A)=',size(sort_A)
!    print*,'size(sort_D)=',size(sort_D)
!	print*,'size(top01pct_D)=',size(top01pct_D)
	
END SUBROUTINE

!SUBROUTINE sort_write(N,SORT_A)
!real SORT_A(N)
!  print *,' '
!  WRITE(*,10) (SORT_A(I),I=1,size(sort_A)) 
!  return
!10 FORMAT(10F6.1)
!END SUBROUTINE

!**************************************************************************************************************
SUBROUTINE wageshare

ALLOCATE( sort_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( sort_inc_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2) )
ALLOCATE( sort_inc_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( sort_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( temp_sort_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( sort_D_inc_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2) )
ALLOCATE( sort_D_inc_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( cum_sort_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top0001pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top0005pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top001pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top005pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top0039pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top01pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top025pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top05pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top1pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top5pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top10pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top20pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top39pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top40pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top50pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top60pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top70pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( top80pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( box_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( record_position_E( (RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH ) )
ALLOCATE( record_position_E_single( (RETAGE-1)*NGRIDA*nn*NGRIDEH*2 ) )
ALLOCATE( record_position_E_couple( (RETAGE-1)*NGRIDA*nn*nn*NGRIDEH ) )

OPEN(UNIT=46,FILE='male_earn.txt')
OPEN(UNIT=47,FILE='female_earn.txt')
OPEN(UNIT=48,FILE='couple_earn.txt')

! OPEN(UNIT=49,FILE='male_dist.txt')
! OPEN(UNIT=50,FILE='female_dist.txt')
! OPEN(UNIT=51,FILE='couple_dist.txt')

!***************************This part is removed and the updated sorting agglorithm is replaced (Dec12,2019)*****************
! ! Single working age
! isort=0
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA
!         DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2                     
                
! 				 isort=isort+1
! 				 JN=singleIDCWN(AGE,IA,IS,IE,IG)   				
!                  sort_INC(isort) =  WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)

! 				 IF (IG==1) THEN 
!                  	! WRITE(46,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)+min(R*A(IA),d_c)	!Taxable income
! 					 WRITE(46,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
! 				 ELSEIF (IG==2) THEN 
! 					! WRITE(47,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)+min(R*A(IA),d_c)
! 					 WRITE(47,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
! 				 END IF

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO

! ! Couple working age
! DO AGE = 1,RETAGE-1
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 				 isort=isort+1
! 				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
! 				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)    				
!                  sort_INC(isort) =  WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)

!                 !  WRITE(48,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + min(R*A(IA),d_c)
! 				WRITE(48,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)			  
				 
! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO 
						

! CALL sorting(size(sort_INC),sort_INC)       ! sort in ascending order

! WRITE(5,*) sort_INC(:)
! DO i = 1,size(sort_INC)
! 	box_inc(i)= 0
! END DO

! ! Single working age
! index_E = 0
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA
!         DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2               
                
! 				 index_E = index_E + 1
! 				 JN=singleIDCWN(AGE,IA,IS,IE,IG)   
! 				 income = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
!                  i = search(income, sort_INC, box_inc,1.D-4)                
! 				 sort_D_inc(i) = singleYW(AGE,IA,IS,IE,IG)
! 				 record_position_E(index_E) = i	

! 				!  IF (IG==1) THEN 
!                 !  	WRITE(49,"(12(F11.4,1X))") singleYW(AGE,IA,IS,IE,IG)
! 				!  ELSEIF (IG==2) THEN 
! 				! 	WRITE(50,"(12(F11.4,1X))") singleYW(AGE,IA,IS,IE,IG)
! 				!  END IF
                               
! 				END DO 
!             END DO
!         END DO
!     END DO
! END DO

! ! Couple working age
! DO AGE = 1,RETAGE-1
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 				 index_E = index_E + 1
! 				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
! 				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2) 
! 				 income = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
! 				 i = search(income, sort_INC, box_inc,1.D-4)                
! 				 sort_D_inc(i) = coupleYW(AGE,IA,IS1,IS2,IE)
! 				 record_position_E(index_E) = i	

! 				!  WRITE(51,"(12(F11.4,1X))") coupleYW(AGE,IA,IS1,IS2,IE)

! 				END DO 
!             END DO
!         END DO
!     END DO
! END DO


!*********************Use SSORT_INT (Dec12,2019)*******************************
! Single working
index_E=0
index_E_single = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2

					index_E = index_E + 1
					index_E_single = index_E_single + 1

					JN=singleIDCWN(AGE,IA,IS,IE,IG) 

			   		sort_INC(index_E) =  WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)	
					sort_INC_single(index_E_single) =  WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)

					sort_D_inc(index_E) = singleYW(AGE,IA,IS,IE,IG)
					sort_D_inc_single(index_E_single) = singleYW(AGE,IA,IS,IE,IG)
					
					record_position_E(index_E) = index_E
					record_position_E_single(index_E_single) = index_E_single
					
				END DO
			END DO		
		END DO
	END DO
END DO

! Couple working age
index_E_couple = 0
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					index_E = index_E + 1
					index_E_couple = index_E_couple + 1

					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)   

					sort_INC(index_E) = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
					sort_INC_couple(index_E_couple) = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)

					sort_D_inc(index_E) = coupleYW(AGE,IA,IS1,IS2,IE)
					sort_D_inc_couple(index_E_couple) = coupleYW(AGE,IA,IS1,IS2,IE)

					record_position_E(index_E) = index_E
					record_position_E_couple(index_E_couple) = index_E_couple

				END DO 
            END DO
        END DO
    END DO
END DO

CALL SSORT_INT(sort_INC,record_position_E,size(sort_INC),2)
temp_sort_D_inc(:) = sort_D_inc(record_position_E)
sort_D_inc = temp_sort_D_inc
!******************************************************************************
sort_D_inc = sort_D_inc/sum(sort_D_inc)

cum_sort_D_inc(1) = sort_D_inc(1)
DO i = 2,size(sort_D_inc)
	cum_sort_D_inc(i) = cum_sort_D_inc(i-1)+sort_D_inc(i)
END DO

print*, 'cum_sort_D_inc=',cum_sort_D_inc(size(sort_D_inc))

! Identify labor income fractile agents
DO i = 1,size(sort_D_inc)
	
	top0001pct_D_inc(i) = 0
	top0005pct_D_inc(i) = 0
	top001pct_D_inc(i) = 0
	top005pct_D_inc(i) = 0
	top0039pct_D_inc(i) = 0
	top01pct_D_inc(i) = 0
	top025pct_D_inc(i) = 0
	top05pct_D_inc(i) = 0
    top1pct_D_inc(i) = 0
	top5pct_D_inc(i) = 0
  	top10pct_D_inc(i) = 0
  	top20pct_D_inc(i) = 0
	top39pct_D_inc(i) = 0
  	top40pct_D_inc(i) = 0
	top50pct_D_inc(i) = 0
  	top60pct_D_inc(i) = 0
	top70pct_D_inc(i) = 0
  	top80pct_D_inc(i) = 0   
    
END DO

where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.00001 ) top0001pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.00005 ) top0005pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.0001 ) top001pct_D_inc = 1
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.0005 ) top005pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.00039 ) top0039pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.001 ) top01pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.0025 ) top025pct_D_inc = 1
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.005 ) top05pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.01 ) top1pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.05 ) top5pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.1 ) top10pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.2 ) top20pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.39 ) top39pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.4 ) top40pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.5 ) top50pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.6 ) top60pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.7 ) top70pct_D_inc = 1 
where ( cum_sort_D_inc(1:size(sort_D_inc)) > 1-0.8 ) top80pct_D_inc = 1 

	Aggincome = dot_product(sort_inc,sort_D_inc)

	incshare0001 = sum(sort_inc*sort_D_inc*top0001pct_D_inc)/Aggincome
	incshare0005 = sum(sort_inc*sort_D_inc*top0005pct_D_inc)/Aggincome
	incshare001 = sum(sort_inc*sort_D_inc*top001pct_D_inc)/Aggincome
	incshare005 = sum(sort_inc*sort_D_inc*top005pct_D_inc)/Aggincome
	incshare01 = sum(sort_inc*sort_D_inc*top01pct_D_inc)/Aggincome
	incshare05 = sum(sort_inc*sort_D_inc*top05pct_D_inc)/Aggincome
	incshare1 = sum(sort_inc*sort_D_inc*top1pct_D_inc)/Aggincome
	incshare5 = sum(sort_inc*sort_D_inc*top5pct_D_inc)/Aggincome
	incshare10 = sum(sort_inc*sort_D_inc*top10pct_D_inc)/Aggincome
	incshare20 = sum(sort_inc*sort_D_inc*top20pct_D_inc)/Aggincome
	incshare40 = sum(sort_inc*sort_D_inc*top40pct_D_inc)/Aggincome
	incshare60 = sum(sort_inc*sort_D_inc*top60pct_D_inc)/Aggincome
	incshare80 = sum(sort_inc*sort_D_inc*top80pct_D_inc)/Aggincome

	print*, 'incshare0001 =',incshare0001
	print*, 'incshare0005 =',incshare0005
	print*, 'incshare001 =',incshare001 	
	print*, 'incshare01 =',incshare01
	print*, 'incshare05 =',incshare05
	print*, 'incshare1 =',incshare1 
	print*, 'incshare5 =',incshare5
	print*, 'incshare10 =',incshare10 
	print*, 'incshare20 =',incshare20
	print*, 'incshare40 =',incshare40
	print*, 'incshare60 =',incshare60
	print*, 'incshare80 =',incshare80  

! threshold of top1% income
do i = size(sort_D_inc), 1, -1
  	if (top1pct_D_inc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_inc)) then 
  	earningthreshold1 = sort_inc(j+1)
else
  	earningthreshold1 = sort_inc(j)
end if

! threshold of top5% income
do i = size(sort_D_inc), 1, -1
  	if (top5pct_D_inc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_inc)) then 
  	earningthreshold5 = sort_inc(j+1)
else
  	earningthreshold5 = sort_inc(j)
end if

! threshold of top10% income
do i = size(sort_D_inc), 1, -1
  	if (top10pct_D_inc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_inc)) then 
  	earningthreshold10 = sort_inc(j+1)
else
  	earningthreshold10 = sort_inc(j)
end if

! threshold of top20% income
do i = size(sort_D_inc), 1, -1
  	if (top20pct_D_inc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_inc)) then 
  	earningthreshold20 = sort_inc(j+1)
else
  	earningthreshold20 = sort_inc(j)
end if

! threshold of top40% income
do i = size(sort_D_inc), 1, -1
  	if (top40pct_D_inc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_inc)) then 
  	earningthreshold40 = sort_inc(j+1)
else
  	earningthreshold40 = sort_inc(j)
end if

! threshold of top60% income
do i = size(sort_D_inc), 1, -1
  	if (top60pct_D_inc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_inc)) then 
  	earningthreshold60 = sort_inc(j+1)
else
  	earningthreshold60 = sort_inc(j)
end if

! threshold of top80% income
do i = size(sort_D_inc), 1, -1
  	if (top80pct_D_inc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_inc)) then 
  	earningthreshold80 = sort_inc(j+1)
else
  	earningthreshold80 = sort_inc(j)
end if

OPEN(UNIT=53,FILE='earningthreshold.txt')
WRITE(53,"(12(F11.4,1X))") earningthreshold80,earningthreshold60,earningthreshold40,earningthreshold20,earningthreshold10,earningthreshold5,earningthreshold1
CLOSE(UNIT=53)

END SUBROUTINE

!************************************************************************************************************
SUBROUTINE totalincomeshare

! Inculde last period due to the bequest
ALLOCATE( sort_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( sort_tinc_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2 ) )
ALLOCATE( sort_tinc_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( sort_D_TINC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( temp_sort_D_TINC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

ALLOCATE( sort_D_tinc_single( (RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2 ) )
ALLOCATE( sort_D_tinc_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

ALLOCATE( cum_sort_D_TINC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top0001pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top0005pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top001pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top005pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top01pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top025pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top05pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top1pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top5pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top10pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top20pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top30pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top40pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top50pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top60pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top70pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top80pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top90pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top95pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top99pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot20pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( box_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( record_position_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( record_position_tinc_single( (RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2 ) )
ALLOCATE( record_position_tinc_couple( (RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

OPEN(UNIT=55,FILE='male_income.txt')
OPEN(UNIT=56,FILE='female_income.txt')
OPEN(UNIT=57,FILE='couple_income.txt')

OPEN(UNIT=49,FILE='male_dist.txt')
OPEN(UNIT=50,FILE='female_dist.txt')
OPEN(UNIT=51,FILE='couple_dist.txt') 

!***************************This part is removed and the updated sorting agglorithm is replaced (Dec12,2019)*****************
! ! Single working age
! ! pre-tax total income share of top incomes
! isort=0
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA
!         DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2                   
                
! 				isort=isort+1
! 				JN=singleIDCWN(AGE,IA,IS,IE,IG)   	
! 				INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)			
! 				!sort_tinc(isort) =  R(IR)*A(IA) + INCOME  ! pretax income including corporate income
! 				!sort_tinc(isort) =  R(IR)*A(IA) + INCOME + BEQ*(1.0+GROWTH)**(AGE-1)
! 				sort_tinc(isort) =  R*A(IA) + INCOME 

! 				IF (IG==1) THEN 
!                  	WRITE(55,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)+R*A(IA)	!Taxable income					
! 				ELSEIF (IG==2) THEN 
! 					WRITE(56,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)+R*A(IA)
! 				END IF
												               
! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO			    

! ! Couple working age
! DO AGE = 1,RETAGE-1
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 				 isort=isort+1
! 				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
! 				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)  
! 				 INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)  				
!                  sort_tinc(isort) =  R*A(IA) + INCOME 

! 				!  WRITE(57,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)
! 				 WRITE(57,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+R*A(IA)/2.0 ,  WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+R*A(IA)/2.0

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO 


! !  Total income in retirement period

! ! Single retiree 
! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA
! 		DO IE = 1,NGRIDEH	
! 			DO IG=1,2  
            
!              isort=isort+1
! 			 !sort_tinc(isort)= R(IR)*A(IA) + SS + ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1) 
! 			 sort_tinc(isort)= R*A(IA) + SS(IE) 
! 			 !sort_tinc(isort)= R(IR)*A(IA) 

! 			IF (IG==1) THEN 
!                 WRITE(55,"(12(F11.4,1X))") R*A(IA) + SS(IE)	!Taxable income					
! 			ELSEIF (IG==2) THEN 
! 				WRITE(56,"(12(F11.4,1X))") R*A(IA) + SS(IE)
! 			END IF
			
! 			END DO
!         END DO 
!     END DO
! END DO  

! ! couple retiree    
! ! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
! DO AGE = RETAGE,MAXAGE
!     DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH

! 			isort=isort+1
!          	sort_tinc(isort)= R*A(IA) + 2*SS(IE)     

! 			! WRITE(57,"(12(F11.4,1X))") R*A(IA) + 2*SS(IE)    
! 			WRITE(57,"(12(F11.4,1X))") R*A(IA)/2.0 + SS(IE) , R*A(IA)/2.0 + SS(IE)          
        
! 		END DO
!     END DO
! END DO               

! CALL sorting(size(sort_tinc),sort_tinc) 
! !WRITE(8,*) sort_tinc(:)

! DO i = 1,size(sort_tinc)
! 	box_tinc(i)= 0
! END DO

! ! Single working age
! index_tinc = 0
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA
!         DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2  

!                  index_tinc = index_tinc + 1
! 				 JN=singleIDCWN(AGE,IA,IS,IE,IG)   	
! 				 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)	
              
! 			 	 !i = search(R(IR)*A(IA) + (1-STAX-MTAX)*INCOME+ ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1), sort_tinc, box_tinc)     
!                  !i = search( R(IR)*A(IA) + INCOME + BEQ*(1.0+GROWTH)**(AGE-1), sort_tinc, box_tinc )
! 				 i = search( R*A(IA) + INCOME , sort_tinc, box_tinc,1.D-2 )   
! 				 sort_D_TINC(i) = singleYW(AGE,IA,IS,IE,IG)			
!                  record_position_tinc(index_tinc) = i

! 				 IF (IG==1) THEN 
!                  	WRITE(49,"(12(F11.4,1X))") singleYW(AGE,IA,IS,IE,IG)
! 				 ELSEIF (IG==2) THEN 
! 					WRITE(50,"(12(F11.4,1X))") singleYW(AGE,IA,IS,IE,IG)
! 				 END IF
                
! 				END DO 
!             END DO
!         END DO
!     END DO
! END DO

! ! Couple working age
! DO AGE = 1,RETAGE-1
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 				 index_tinc = index_tinc + 1
! 				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
! 				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)  
! 				 INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)  				
                 
! 				 i = search( R*A(IA) + INCOME , sort_tinc, box_tinc,1.D-2 )   
! 				 sort_D_TINC(i) = coupleYW(AGE,IA,IS1,IS2,IE)			
!                  record_position_tinc(index_tinc) = i

! 				 WRITE(51,"(12(F11.4,1X))") coupleYW(AGE,IA,IS1,IS2,IE)

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO 
		
! ! Single retiree 

! ! DO AGE=RETAGE,MAXAGE-1
! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA
!         DO IE = 1,NGRIDEH	
! 			DO IG=1,2  
             
! 				index_tinc = index_tinc + 1		
              
! 				!TINCOME = R*A(JA) + SS + ATR* BEQ*(1.0+GROWTH)**(AGE-1) 
                
! 				!i = search(R(IR)*A(IA) + SS + ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1) , sort_tinc, box_tinc)
!                 i = search( R*A(IA) + SS(IE), sort_tinc, box_tinc,1.D-2)
! 				! i = search(R(IR)*A(IA)  , sort_tinc, box_tinc)
				
! 				sort_D_TINC(i) = singleYR(AGE,IA,IE,IG)			
!                 record_position_tinc(index_tinc) = i 

! 				IF (IG==1) THEN 
!                  	WRITE(49,"(12(F11.4,1X))") singleYR(AGE,IA,IE,IG)
! 				 ELSEIF (IG==2) THEN 
! 					WRITE(50,"(12(F11.4,1X))") singleYR(AGE,IA,IE,IG)
! 				 END IF
               
! 			END DO  							   
!         END DO
!     END DO
! END DO

! ! couple retiree    
! ! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
! DO AGE = RETAGE,MAXAGE
!     DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH

! 			index_tinc = index_tinc + 1	
!          	i = search( R*A(IA) + 2*SS(IE), sort_tinc, box_tinc,1.D-2)

! 			sort_D_TINC(i) = coupleYR(AGE,IA,IE)			
!             record_position_tinc(index_tinc) = i   

! 			WRITE(51,"(12(F11.4,1X))") coupleYR(AGE,IA,IE)      
        
! 		END DO
!     END DO
! END DO   

!*********************Use SSORT_INT (Dec12,2019)*******************************
! Single working
index_tinc = 0
index_tinc_single = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2

					index_tinc = index_tinc + 1
					index_tinc_single = index_tinc_single + 1

					JN=singleIDCWN(AGE,IA,IS,IE,IG)   	
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)

			   		sort_tinc(index_tinc) = R*A(IA) + INCOME 
					sort_tinc_single(index_tinc_single) = R*A(IA) + INCOME 

					sort_D_tinc(index_tinc) = singleYW(AGE,IA,IS,IE,IG)
					sort_D_tinc_single(index_tinc_single) = singleYW(AGE,IA,IS,IE,IG)
					
					record_position_tinc(index_tinc) = index_tinc
					record_position_tinc_single(index_tinc_single) = index_tinc_single

				END DO
			END DO		
		END DO
	END DO
END DO

! Single retired
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IE = 1,NGRIDEH	
			DO IG=1,2

				index_tinc = index_tinc + 1
				index_tinc_single = index_tinc_single + 1

				sort_tinc(index_tinc) = R*A(IA) + SS(IE) 
				sort_tinc_single(index_tinc_single) = R*A(IA) + SS(IE) 

				sort_D_tinc(index_tinc) = singleYR(AGE,IA,IE,IG)
				sort_D_tinc_single(index_tinc_single) = singleYR(AGE,IA,IE,IG)
				
				record_position_tinc(index_tinc) = index_tinc
				record_position_tinc_single(index_tinc_single) = index_tinc_single
			
			END DO     
        END DO
    END DO
END DO

! Couple working
index_tinc_couple = 0
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					index_tinc = index_tinc + 1
					index_tinc_couple = index_tinc_couple + 1

					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 	JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)  	
					INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)

			   		sort_tinc(index_tinc) = R*A(IA) + INCOME 
					sort_tinc_couple(index_tinc_couple) = R*A(IA) + INCOME 

					sort_D_tinc(index_tinc) = coupleYW(AGE,IA,IS1,IS2,IE)
					sort_D_tinc_couple(index_tinc_couple) = coupleYW(AGE,IA,IS1,IS2,IE)
					
					record_position_tinc(index_tinc) = index_tinc
					record_position_tinc_couple(index_tinc_couple) = index_tinc_couple

				END DO
			END DO		
		END DO
	END DO
END DO

! Couple retired
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH   

			index_tinc = index_tinc + 1
			index_tinc_couple = index_tinc_couple + 1

			sort_tinc(index_tinc) = R*A(IA) + 2*SS(IE)  
			sort_tinc_couple(index_tinc_couple) = R*A(IA) + 2*SS(IE)  

			sort_D_tinc(index_tinc) = coupleYR(AGE,IA,IE)
			sort_D_tinc_couple(index_tinc_couple) = coupleYR(AGE,IA,IE)

			record_position_tinc(index_tinc) = index_tinc
			record_position_tinc_couple(index_tinc_couple) = index_tinc_couple

		END DO
    END DO
END DO  

CALL SSORT_INT(sort_tinc,record_position_tinc,size(sort_tinc),2)
temp_sort_D_tinc(:) = sort_D_tinc(record_position_tinc)
sort_D_tinc = temp_sort_D_tinc
!******************************************************************************
sort_D_TINC = sort_D_TINC/sum(sort_D_TINC)

cum_sort_D_TINC(1) = sort_D_TINC(1)
DO i = 2,size(sort_D_TINC)
	cum_sort_D_TINC(i) = cum_sort_D_TINC(i-1)+sort_D_TINC(i)
END DO
print*, 'cum_sort_D_TINC=',cum_sort_D_TINC(size(sort_D_TINC))

! Identify total income fractile agents
DO i = 1,size(sort_D_tinc)
   
   	top0001pct_D_tinc(i) = 0
	top0005pct_D_tinc(i) = 0
    top001pct_D_tinc(i) = 0
	top005pct_D_tinc(i) = 0
	top01pct_D_tinc(i) = 0
	top025pct_D_tinc(i) = 0
	top05pct_D_tinc(i) = 0
    top1pct_D_tinc(i) = 0
	top5pct_D_tinc(i) = 0
  	top10pct_D_tinc(i) = 0
  	top20pct_D_tinc(i) = 0
	top30pct_D_tinc(i) = 0
  	top40pct_D_tinc(i) = 0
	top50pct_D_tinc(i) = 0
  	top60pct_D_tinc(i) = 0
	top70pct_D_tinc(i) = 0
  	top80pct_D_tinc(i) = 0 
	top90pct_D_tinc(i) = 0
	top95pct_D_tinc(i) = 0
	top99pct_D_tinc(i) = 0
	bot20pct_D_tinc(i) = 0

    
END DO

where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.00001 ) top0001pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.00005 ) top0005pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.0001 ) top001pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.0005 ) top005pct_D_tinc = 1
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.001 ) top01pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.0025 ) top025pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.005 ) top05pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.01 ) top1pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.05 ) top5pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.1 ) top10pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.2 ) top20pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.3 ) top30pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.4 ) top40pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.5 ) top50pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.6 ) top60pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.7 ) top70pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.8 ) top80pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.9 ) top90pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.95 ) top95pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) > 1-0.99 ) top99pct_D_tinc = 1 
where ( cum_sort_D_tinc(1:size(sort_D_tinc)) < 0.2 ) bot20pct_D_tinc = 1
	Aggtincome = dot_product(sort_tinc,sort_D_tinc)

	tincshare0001 = sum(sort_tinc*sort_D_tinc*top0001pct_D_tinc)/Aggtincome
	tincshare0005 = sum(sort_tinc*sort_D_tinc*top0005pct_D_tinc)/Aggtincome
	tincshare001 = sum(sort_tinc*sort_D_tinc*top001pct_D_tinc)/Aggtincome
	tincshare005 = sum(sort_tinc*sort_D_tinc*top005pct_D_tinc)/Aggtincome
	tincshare01 = sum(sort_tinc*sort_D_tinc*top01pct_D_tinc)/Aggtincome
	tincshare05 = sum(sort_tinc*sort_D_tinc*top05pct_D_tinc)/Aggtincome
	tincshare1 = sum(sort_tinc*sort_D_tinc*top1pct_D_tinc)/Aggtincome
	tincshare5 = sum(sort_tinc*sort_D_tinc*top5pct_D_tinc)/Aggtincome
	tincshare10 = sum(sort_tinc*sort_D_tinc*top10pct_D_tinc)/Aggtincome
	tincshare20 = sum(sort_tinc*sort_D_tinc*top20pct_D_tinc)/Aggtincome
	tincshare40 = sum(sort_tinc*sort_D_tinc*top40pct_D_tinc)/Aggtincome
	tincshare60 = sum(sort_tinc*sort_D_tinc*top60pct_D_tinc)/Aggtincome
	tincshare80 = sum(sort_tinc*sort_D_tinc*top80pct_D_tinc)/Aggtincome
	
	
	print*, 'tincshare0001 =',tincshare0001
	print*, 'tincshare0005 =',tincshare0005
	print*, 'tincshare001 =',tincshare001 
	print*, 'tincshare01 =',tincshare01
	print*, 'tincshare05 =',tincshare05
	print*, 'tincshare1 =',tincshare1 
	print*, 'tincshare5 =',tincshare5
	print*, 'tincshare10 =',tincshare10 
	print*, 'tincshare20 =',tincshare20
	print*, 'tincshare40 =',tincshare40
	print*, 'tincshare60 =',tincshare60
	print*, 'tincshare80 =',tincshare80  

! threshold of top0.1% income
do i = size(sort_D_tinc), 1, -1
  	if (top01pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold01 = sort_tinc(j+1)
else
  	incomethreshold01 = sort_tinc(j)
end if


! threshold of top1% income
do i = size(sort_D_tinc), 1, -1
  	if (top1pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold1 = sort_tinc(j+1)
else
  	incomethreshold1 = sort_tinc(j)
end if

! threshold of top5% income
do i = size(sort_D_tinc), 1, -1
  	if (top5pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold5 = sort_tinc(j+1)
else
  	incomethreshold5 = sort_tinc(j)
end if

! threshold of top10% income
do i = size(sort_D_tinc), 1, -1
  	if (top10pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold10 = sort_tinc(j+1)
else
  	incomethreshold10 = sort_tinc(j)
end if

! threshold of top20% income
do i = size(sort_D_tinc), 1, -1
  	if (top20pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold20 = sort_tinc(j+1)
else
  	incomethreshold20 = sort_tinc(j)
end if

! threshold of top30% income
do i = size(sort_D_tinc), 1, -1
  	if (top30pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold30 = sort_tinc(j+1)
else
  	incomethreshold30 = sort_tinc(j)
end if

! threshold of top40% income
do i = size(sort_D_tinc), 1, -1
  	if (top40pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold40 = sort_tinc(j+1)
else
  	incomethreshold40 = sort_tinc(j)
end if

! threshold of top50% income
do i = size(sort_D_tinc), 1, -1
  	if (top50pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold50 = sort_tinc(j+1)
else
  	incomethreshold50 = sort_tinc(j)
end if

! threshold of top60% income
do i = size(sort_D_tinc), 1, -1
  	if (top60pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold60 = sort_tinc(j+1)
else
  	incomethreshold60 = sort_tinc(j)
end if

! threshold of top70% income
do i = size(sort_D_tinc), 1, -1
  	if (top70pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold70 = sort_tinc(j+1)
else
  	incomethreshold70 = sort_tinc(j)
end if

! threshold of top80% income
do i = size(sort_D_tinc), 1, -1
  	if (top80pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold80 = sort_tinc(j+1)
else
  	incomethreshold80 = sort_tinc(j)
end if

! threshold of top90% income
do i = size(sort_D_tinc), 1, -1
  	if (top90pct_D_tinc(i) < 1) then
		j = i
  		exit
  	end if
end do

if (j < size(sort_D_tinc)) then 
  	incomethreshold90 = sort_tinc(j+1)
else
  	incomethreshold90 = sort_tinc(j)
end if

! only save the benchmark incomethreshold
IF (source_welfare==0) THEN
	OPEN(UNIT=52,FILE='incomethreshold.txt')
	! WRITE(52,"(12(F11.4,1X))") incomethreshold80,incomethreshold60,incomethreshold40,incomethreshold20,incomethreshold10,incomethreshold5,incomethreshold1
	WRITE(52,*) incomethreshold80,incomethreshold60,incomethreshold40,incomethreshold20,incomethreshold10,incomethreshold5,incomethreshold1
	CLOSE(UNIT=52)
END IF 

print*, 'incomethreshold01=',incomethreshold01
print*, 'incomethreshold1=',incomethreshold1
print*, 'incomethreshold5=',incomethreshold5
print*, 'incomethreshold10=',incomethreshold10
print*, 'incomethreshold20=',incomethreshold20
print*, 'incomethreshold30=',incomethreshold30
print*, 'incomethreshold40=',incomethreshold40
print*, 'incomethreshold50=',incomethreshold50
print*, 'incomethreshold60=',incomethreshold60
print*, 'incomethreshold70=',incomethreshold70
print*, 'incomethreshold80=',incomethreshold80
print*, 'incomethreshold90=',incomethreshold90

END SUBROUTINE
!************************************************************************************************************
SUBROUTINE consumptionshare

ALLOCATE( singleIDCWC(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleIDCWC(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
ALLOCATE( singleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2), coupleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDEH) )
ALLOCATE( sort_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )    
ALLOCATE( sort_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( temp_sort_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( cum_sort_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top0001pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top0005pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top001pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top01pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top05pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top1pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top5pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top10pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top20pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top40pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top50pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top60pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top70pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top80pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top90pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top95pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( top99pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( record_position_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( box_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )


! Single working age
isort=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2                     
                               
                 isort=isort+1
                 JN = singleIDCWN(AGE,IA,IS,IE,IG)   
				 JA = singleIDCWA(AGE,IA,IS,IE,IG)  
				                 
			 	 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
				 PREMIUM = premium_rate*INCOME
                
				 yd	= avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
					  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) + INCOME)/avg_earnings - singlebendy) &
					  +(1-tau_c)*max(R*A(IA)-d_c,0.0)
				 
				 X3 =  BEQ + A(IA)
				 singleIDCWC(AGE,IA,IS,IE,IG) = (X3 + yd + gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)

				 sort_C(isort) = singleIDCWC(AGE,IA,IS,IE,IG)
				 sort_D_C(isort) = singleYW(AGE,IA,IS,IE,IG)
				 record_position_C(isort) = isort

				END DO  
            END DO
        END DO 
    END DO
END DO

! Couple working age
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

				 isort=isort+1
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
				 JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)  

				 INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
				 PREMIUM = premium_rate*INCOME
				!  yd= (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
				! 		  +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
				! 		  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

				 
				 yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c), IA), yd_MFS( WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )

				
				 X3 =  2*BEQ + A(IA)
				 coupleIDCWC(AGE,IA,IS1,IS2,IE) = (X3 + yd + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)

				 sort_C(isort) = coupleIDCWC(AGE,IA,IS1,IS2,IE)
				 sort_D_C(isort) = coupleYW(AGE,IA,IS1,IS2,IE)
				 record_position_C(isort) = isort

				END DO 
            END DO
        END DO 
    END DO
END DO 


! Single retiree 
!DO AGE=RETAGE,MAXAGE-1  (for the case of no bequest)
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IE = 1,NGRIDEH	
			DO IG=1,2 
                        
             isort=isort+1           
			 JA=singleIDCRA(AGE,IA,IE,IG)
			
			 INCOME = SS(IE)
			!  PREMIUM = premium_rate*INCOME
			PREMIUM = 0.0
            
			 yd	= avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
					+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) + INCOME)/avg_earnings - singlebendy) &
					+(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans+medicare
						  
			 X3 = A(IA)
			 singleIDCRC(AGE,IA,IE,IG) = (X3 + yd + gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)
			
			 sort_C(isort) = singleIDCRC(AGE,IA,IE,IG)
			 sort_D_C(isort) = singleYR(AGE,IA,IE,IG)
			 record_position_C(isort) = isort

            END DO             
        END DO 
    END DO
END DO                

! couple retiree    
! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

		 isort=isort+1           
		 JA=coupleIDCRA(AGE,IA,IE)

		 INCOME = 2*SS(IE)
		!  PREMIUM = premium_rate*INCOME
		 PREMIUM = 0.0

		!  yd= (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
		! 			+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
		! 			+(1-tau_c)*max(R*A(IA)-d_c,0.0)

		
		 yd = max( yd_MFJ( 2*SS(IE) + min(R*A(IA),d_c), IA), yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA) ) 


		 X3 = A(IA)
		 coupleIDCRC(AGE,IA,IE) = (X3 + yd + 2*medicare + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)

		 sort_C(isort) = coupleIDCRC(AGE,IA,IE)
		 sort_D_C(isort) = coupleYR(AGE,IA,IE)
  		 record_position_C(isort) = isort

		END DO 
    END DO
END DO     


! CALL sorting(size(sort_C),sort_C)       ! sort in ascending order
CALL SSORT_INT(sort_C,record_position_C,size(sort_C),2)
temp_sort_D_C(:) = sort_D_C(record_position_C)
sort_D_C = temp_sort_D_C

sort_D_C = sort_D_C/sum(sort_D_C)

cum_sort_D_C(1) = sort_D_C(1)
DO i = 2,size(sort_D_C)
	cum_sort_D_C(i) = cum_sort_D_C(i-1)+sort_D_C(i)
END DO
print*, 'cum_sort_D_C=',cum_sort_D_C(size(sort_D_C))

! Identify wealth fractile agents
DO i = 1,size(sort_D_C)
	top0001pct_D_C(i) = 0
	top0005pct_D_C(i) = 0
    top001pct_D_C(i) = 0
	top01pct_D_C(i) = 0
	top05pct_D_C(i) = 0
    top1pct_D_C(i) = 0
	top5pct_D_C(i) = 0
  	top10pct_D_C(i) = 0
  	top20pct_D_C(i) = 0
  	top40pct_D_C(i) = 0
	top50pct_D_C(i) = 0
  	top60pct_D_C(i) = 0
	top70pct_D_C(i) = 0
  	top80pct_D_C(i) = 0 
	top90pct_D_C(i) = 0
	top95pct_D_C(i) = 0
	top99pct_D_C(i) = 0
    
END DO

where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.00001 ) top0001pct_D_C = 1
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.00005 ) top0005pct_D_C = 1
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.0001 ) top001pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.001 ) top01pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.005 ) top05pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.01 ) top1pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.05 ) top5pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.1 ) top10pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.2 ) top20pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.4 ) top40pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.5 ) top50pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.6 ) top60pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.7 ) top70pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.8 ) top80pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.9 ) top90pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.95 ) top95pct_D_C = 1 
where ( cum_sort_D_C(1:size(sort_D_C)) > 1-0.99 ) top99pct_D_C = 1 



Aggconsumption = dot_product(sort_C,sort_D_C)
	
	cshare0001 = sum(sort_C*sort_D_C*top0001pct_D_C)/Aggconsumption
	cshare0005 = sum(sort_C*sort_D_C*top0005pct_D_C)/Aggconsumption
	cshare001 = sum(sort_C*sort_D_C*top001pct_D_C)/Aggconsumption
	cshare01 = sum(sort_C*sort_D_C*top01pct_D_C)/Aggconsumption
	cshare05 = sum(sort_C*sort_D_C*top05pct_D_C)/Aggconsumption
	cshare1 = sum(sort_C*sort_D_C*top1pct_D_C)/Aggconsumption
	cshare5 = sum(sort_C*sort_D_C*top5pct_D_C)/Aggconsumption
	cshare10 = sum(sort_C*sort_D_C*top10pct_D_C)/Aggconsumption
	cshare20 = sum(sort_C*sort_D_C*top20pct_D_C)/Aggconsumption
	cshare40 = sum(sort_C*sort_D_C*top40pct_D_C)/Aggconsumption
	cshare60 = sum(sort_C*sort_D_C*top60pct_D_C)/Aggconsumption
	cshare80 = sum(sort_C*sort_D_C*top80pct_D_C)/Aggconsumption


	print*, 'cshare0001 =',cshare0001
	print*, 'cshare0005 =',cshare0005
	print*, 'cshare001 =',cshare001
	print*, 'cshare01 =',cshare01
	print*, 'cshare05 =',cshare05
	print*, 'cshare1 =',cshare1 
	print*, 'cshare5 =',cshare5
	print*, 'cshare10 =',cshare10 
	print*, 'cshare20 =',cshare20
	print*, 'cshare40 =',cshare40
	print*, 'cshare60 =',cshare60
	print*, 'cshare80 =',cshare80  
!    PRINT*, 'wealththreshold1=',wealththreshold1
!    PRINT*, 'wealththreshold10=',wealththreshold10
	
	print*,'Aggconsumption=',Aggconsumption

END SUBROUTINE
!************************************************************************************************************
 SUBROUTINE skewness  ! Data source from Kuhn & Rios 2016 (total income is different from Markus JME)


! Including the last period due to bequest
ALLOCATE( bot99pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot90pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot50pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot30pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot99pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot90pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot50pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot30pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot99pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot90pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot50pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( bot30pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

 !Wealth  
 bot99pct_D(:) = 1-top1pct_D(:)
 bot90pct_D(:) = 1-top10pct_D(:)
 bot50pct_D(:) = 1- top50pct_D(:)
 bot30pct_D(:) = 1- top70pct_D(:)
 k_pct99 = maxval(sort_A*bot99pct_D)
 k_pct90 = maxval(sort_A*bot90pct_D)
 k_pct30 = maxval(sort_A*bot30pct_D) 
 k_median = maxval(sort_A*bot50pct_D)
 k_mean = Aggwealth
  
 !Earnings
 bot99pct_D_inc(:) = 1-top1pct_D_inc(:)
 bot90pct_D_inc(:) = 1-top10pct_D_inc(:)
 bot50pct_D_inc(:) = 1- top50pct_D_inc(:)
 bot30pct_D_inc(:) = 1- top70pct_D_inc(:)
 inc_pct99 = maxval(sort_inc*bot99pct_D_inc)
 inc_pct90 = maxval(sort_inc*bot90pct_D_inc)
 inc_pct30 = maxval(sort_inc*bot30pct_D_inc) 
 inc_median = maxval(sort_inc*bot50pct_D_inc)
 inc_mean = Aggincome
 
 !Total Income
 bot99pct_D_tinc(:) = 1-top1pct_D_tinc(:)
 bot90pct_D_tinc(:) = 1-top10pct_D_tinc(:)
 bot50pct_D_tinc(:) = 1- top50pct_D_tinc(:)
 bot30pct_D_tinc(:) = 1- top70pct_D_tinc(:)
 tinc_pct99 = maxval(sort_tinc*bot99pct_D_tinc)
 tinc_pct90 = maxval(sort_tinc*bot90pct_D_tinc)
 tinc_pct30 = maxval(sort_tinc*bot30pct_D_tinc) 
 tinc_median = maxval(sort_tinc*bot50pct_D_tinc)
 tinc_mean = Aggtincome
 
 

	! Do i=1,size(sort_D) 
		! if (top1pct_D(i)==1) then
			! k_pct99 = sort_A(i)
			! go to 770
		! end if
	! end do
! 770 continue

	! Do i=1,size(sort_D)
		! if (top10pct_D(i)==1) then
			! k_pct90 = sort_A(i)
			! go to 771
		! end if
	! end do
! 771 continue

	! Do i=1,size(sort_D)
		! if (top50pct_D(i)==1) then
			! k_median = sort_A(i)
			! go to 772
		! end if
	! end do
! 772 continue

	! Do i=1,size(sort_D)
		! if (top70pct_D(i)==1) then
			! k_pct30 = sort_A(i)
			! go to 773
		! end if
	! end do
! 773 continue
 ! k_mean = Aggwealth	
  
 kratio99_50 = k_pct99/k_median		!	99-50 ratio
 kratio90_50 = k_pct90/k_median		!	99-50 ratio
 kratioMM = k_mean/k_median         !	mean to median
 kratio50_30 = k_median/k_pct30		!	50-30 ratio
 
 incratio99_50 = inc_pct99/inc_median		!	99-50 ratio
 incratio90_50 = inc_pct90/inc_median		!	99-50 ratio
 incratioMM = inc_mean/inc_median         !	mean to median
 incratio50_30 = inc_median/inc_pct30		!	50-30 ratio
 
 tincratio99_50 = tinc_pct99/tinc_median		!	99-50 ratio
 tincratio90_50 = tinc_pct90/tinc_median		!	99-50 ratio
 tincratioMM = tinc_mean/tinc_median         !	mean to median
 tincratio50_30 = tinc_median/tinc_pct30		!	50-30 ratio
 
 print*, 'k_pct99=',k_pct99
 print*, 'k_pct90=',k_pct90
 print*, 'k_pct30=',k_pct30
 print*, 'k_mean=', k_mean
 print*, 'k_median=', k_median
 
 !WRITE(3,*) top99pct_D
	
 END SUBROUTINE
 
 
 ! SUBROUTINE skewness2  ! it is not correct
 
 ! ! size_adj_sort_A =0
	! ! Do i=1,size(sort_A)
		! ! if (sort_D(i) > 0.0) then
		! ! size_adj_sort_A = size_adj_sort_A+1		
		! ! end if 
	! ! end do
	
! ALLOCATE ( adj_sort_A(size(sort_A)) )	
! ! ALLOCATE ( adj_sort_A(INT(size_adj_sort_A)) )
 ! !real(prec), dimension(size_adj_sort_A) :: adj_sort_A
 
 ! ide =0
	! Do i=1,size(sort_A)
		! if (sort_D(i) > 0.0000000000) then
		! ide = ide+1
		! adj_sort_A(ide) = sort_A(i)
		! end if 
	! end do

	! k_pct99 = percentile(99,adj_sort_A)
	! k_pct90 = percentile(90,adj_sort_A)
	! k_pct30 = percentile(30,adj_sort_A)
	! k_median = percentile(50,adj_sort_A)
	! k_mean = Aggwealth
	
	! kratio99_50 = k_pct99/k_median		!	99-50 ratio
	! kratio90_50 = k_pct90/k_median		!	99-50 ratio
	! kratioMM = k_mean/k_median         !	mean to median
	! kratio50_30 = k_median/k_pct30		!	50-30 ratio
 
 ! print*, 'k_pct99=',k_pct99
 ! print*, 'k_pct90=',k_pct90
 ! print*, 'k_pct30=',k_pct30
 ! print*, 'k_mean=', k_mean
 ! print*, 'k_median=', k_median
 
 ! WRITE(3,*) adj_sort_A
 
 ! END SUBROUTINE
!************************************************************************************************************

! Compute percentile (it is correct, verified by matlab)

 FUNCTION percentile(P,X)  !p=percentile, X=sorted array
 IMPLICIT  NONE
       REAL(prec), DIMENSION(:), INTENT(IN) :: X
       INTEGER, INTENT(IN)               	:: P
	   REAL(prec)                        	:: percentile, n
	
	
	 n = (P*(size(X)-1)/100)+1 
	
	 if ( n-floor(n)==0 ) then
	 percentile=X(INT(n))
	 else
	 percentile=X(floor(n))+(n-floor(n))*(X(floor(n)+1)-X(floor(n)))
	 end if

 END FUNCTION  percentile

!***************************************************************************************
SUBROUTINE AGE_PARTITION
ALLOCATE( ALONG_AGE_single(MAXAGE,2), ALONG_AGE_couple(MAXAGE) )
ALLOCATE( ILONG_AGE_single(MAXAGE,2), ILONG_AGE_couple(MAXAGE) )
ALLOCATE( TILONG_AGE_single(MAXAGE,2), TILONG_AGE_couple(MAXAGE) )
ALLOCATE( YDLONG_AGE_single(MAXAGE,2), YDLONG_AGE_couple(MAXAGE) )
ALLOCATE( ALONG_RETIRE_single(2), ILONG_RETIRE_single(2), TILONG_RETIRE_single(2), YDLONG_RETIRE_single(2) )
ALLOCATE( ALONG20_25_single(2), ALONG25_30_single(2), ALONG30_35_single(2), ALONG35_40_single(2), ALONG40_45_single(2), ALONG45_50_single(2), ALONG50_55_single(2), ALONG55_60_single(2), ALONG60_65_single(2), ALONG65_70_single(2), ALONG70_75_single(2), ALONG75_80_single(2), ALONG80_85_single(2), ALONG85_90_single(2), ALONG90_95_single(2),ALONG95_100_single(2),ALONG65_MORE_single(2) )
ALLOCATE( ILONG20_25_single(2), ILONG25_30_single(2), ILONG30_35_single(2), ILONG35_40_single(2), ILONG40_45_single(2), ILONG45_50_single(2), ILONG50_55_single(2), ILONG55_60_single(2), ILONG60_65_single(2), ILONG65_MORE_single(2) )
ALLOCATE( TILONG20_25_single(2), TILONG25_30_single(2), TILONG30_35_single(2), TILONG35_40_single(2), TILONG40_45_single(2), TILONG45_50_single(2), TILONG50_55_single(2), TILONG55_60_single(2), TILONG60_65_single(2), TILONG65_MORE_single(2) )
ALLOCATE( YDLONG20_25_single(2), YDLONG25_30_single(2), YDLONG30_35_single(2), YDLONG35_40_single(2), YDLONG40_45_single(2), YDLONG45_50_single(2), YDLONG50_55_single(2), YDLONG55_60_single(2), YDLONG60_65_single(2), YDLONG65_MORE_single(2) )
ALLOCATE( labor_participation_age(RETAGE-1,2) )
ALLOCATE( WLONG_AGE(RETAGE-1,2) )
ALLOCATE( labor_participation_age_single(RETAGE-1,2), labor_participation_age_couple(RETAGE-1,2) )
ALLOCATE( NLONG_AGE_single(RETAGE-1,2), NLONG_AGE_couple(RETAGE-1,2) )

! Single
DO AGE=1,RETAGE-1
	temp_coupleYW = SUM(coupleYW(AGE,:,:,:,:))
	DO IG=1,2
	ALONG_AGE_single(AGE,IG)=0.0
	ILONG_AGE_single(AGE,IG)=0.0
	TILONG_AGE_single(AGE,IG)=0.0
	YDLONG_AGE_single(AGE,IG)=0.0
	labor_participation_age(AGE,IG)=0.0
	labor_participation_age_single(AGE,IG)=0.0
	NLONG_AGE_single(AGE,IG)=0.0
	WLONG_AGE(AGE,IG)=0.0
	temp_singleYW = SUM(singleYW(AGE,:,:,:,IG))
		DO IA=1,NGRIDA
			DO IS = 1,nn 
				DO IE=1,NGRIDEH
				 
				 JA = singleIDCWA(AGE,IA,IS,IE,IG)
				 JN = singleIDCWN(AGE,IA,IS,IE,IG)
				 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)				
				 TINCOME = R*A(IA) + INCOME !+ BEQ
				 !post-tax income
				 yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
					  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME)/avg_earnings - singlebendy) &
					  +(1-tau_c)*max(R*A(IA)-d_c,0.0)	!+gov_trans

				 ALONG_AGE_single(AGE,IG) = ALONG_AGE_single(AGE,IG) + A(JA)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW
				 ILONG_AGE_single(AGE,IG) = ILONG_AGE_single(AGE,IG) + INCOME*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW
				 TILONG_AGE_single(AGE,IG) = TILONG_AGE_single(AGE,IG) + TINCOME*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW
				 YDLONG_AGE_single(AGE,IG) = YDLONG_AGE_single(AGE,IG) + yd*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW
				 NLONG_AGE_single(AGE,IG) = NLONG_AGE_single(AGE,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW
				!  WLONG_AGE(AGE,IG) = WLONG_AGE(AGE,IG) + WAGE*EFFLONG(AGE,IG)*W(IS,IG)*singleYW(AGE,IA,IS,IE,IG)/( SUM(singleYW(AGE,:,:,:,IG))+2*SUM(coupleYW(AGE,:,:,:,:)) )
				WLONG_AGE(AGE,IG) = WLONG_AGE(AGE,IG) + WAGE*EFFLONG(AGE,IG)*W(IS,IG)*singleYW(AGE,IA,IS,IE,IG)/( temp_singleYW+temp_coupleYW )

				 IF ( JN > 1 ) THEN
				 	labor_participation_age(AGE,IG) = labor_participation_age(AGE,IG) + singleYW(AGE,IA,IS,IE,IG)
					labor_participation_age_single(AGE,IG) = labor_participation_age_single(AGE,IG) + singleYW(AGE,IA,IS,IE,IG)
				 END IF 

				END DO
			END DO			  
        END DO
    END DO
END DO

temp_singleYR = SUM(singleYR(RETAGE:MAXAGE,:,:,:))
DO IG=1,2
ALONG_RETIRE_single(IG) = 0.0
ILONG_RETIRE_single(IG) = 0.0
TILONG_RETIRE_single(IG) = 0.0
YDLONG_RETIRE_single(IG) = 0.0

	DO AGE=RETAGE,MAXAGE
		ALONG_AGE_single(AGE,IG)=0.0
		temp_singleYR_AGE = SUM(singleYR(AGE,:,:,IG))
		DO IA=1,NGRIDA
        	DO IE = 1,NGRIDEH	
			
				JA = singleIDCRA(AGE,IA,IE,IG)
				INCOME = SS(IE)    
				TINCOME = R*A(IA) + INCOME 
				!post-tax income
				 yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
					  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME)/avg_earnings - singlebendy) &
					  +(1-tau_c)*max(R*A(IA)-d_c,0.0)	!+gov_trans
               
				ALONG_RETIRE_single(IG) = ALONG_RETIRE_single(IG) + A(JA)*singleYR(AGE,IA,IE,IG)/temp_singleYR
				ILONG_RETIRE_single(IG) = ILONG_RETIRE_single(IG) + INCOME*singleYR(AGE,IA,IE,IG)/temp_singleYR
				TILONG_RETIRE_single(IG) = TILONG_RETIRE_single(IG) + TINCOME*singleYR(AGE,IA,IE,IG)/temp_singleYR
				YDLONG_RETIRE_single(IG) = YDLONG_RETIRE_single(IG) + yd*singleYR(AGE,IA,IE,IG)/temp_singleYR

				ALONG_AGE_single(AGE,IG) = ALONG_AGE_single(AGE,IG) + A(JA)*singleYR(AGE,IA,IE,IG)/temp_singleYR_AGE

			END DO	
		END DO
	END DO
END DO

! Couple
DO AGE=1,RETAGE-1
	ALONG_AGE_couple(AGE)=0.0
	ILONG_AGE_couple(AGE)=0.0
	TILONG_AGE_couple(AGE)=0.0
	YDLONG_AGE_couple(AGE)=0.0
	NLONG_AGE_couple(AGE,:)=0.0
	labor_participation_age_couple(AGE,:) = 0.0
	temp_coupleYW = SUM(coupleYW(AGE,:,:,:,:))
	temp_singleYW1 = SUM(singleYW(AGE,:,:,:,1))
	temp_singleYW2 = SUM(singleYW(AGE,:,:,:,2))
		DO IA=1,NGRIDA
			DO IS1 = 1,nn
				DO IS2 = 1,nn 
					DO IE=1,NGRIDEH
				 
				 		JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
				 		JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
						JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
				 		INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
				 		TINCOME = R*A(IA) + INCOME	! + 2*BEQ
						! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME ))**(1.0-tau_l_couple) &
						! 	+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
						! 	+(1-tau_c)*max(R*A(IA)-d_c,0.0)	
						 
						yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c), IA), yd_MFS( WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )


				 		ALONG_AGE_couple(AGE) = ALONG_AGE_couple(AGE) + A(JA)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
				 		ILONG_AGE_couple(AGE) = ILONG_AGE_couple(AGE) + INCOME*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
				 		TILONG_AGE_couple(AGE) = TILONG_AGE_couple(AGE) + TINCOME*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						YDLONG_AGE_couple(AGE) = YDLONG_AGE_couple(AGE) + yd*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						NLONG_AGE_couple(AGE,1) = NLONG_AGE_couple(AGE,1) + N(JN1)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						NLONG_AGE_couple(AGE,2) = NLONG_AGE_couple(AGE,2) + N(JN2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						! WLONG_AGE(AGE,1) = WLONG_AGE(AGE,1) + WAGE*EFFLONG(AGE,1)*W(IS1,1)*coupleYW(AGE,IA,IS1,IS2,IE)/( SUM(singleYW(AGE,:,:,:,1))+2*SUM(coupleYW(AGE,:,:,:,:)) )
						! WLONG_AGE(AGE,2) = WLONG_AGE(AGE,2) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*coupleYW(AGE,IA,IS1,IS2,IE)/( SUM(singleYW(AGE,:,:,:,2))+2*SUM(coupleYW(AGE,:,:,:,:)) )
						WLONG_AGE(AGE,1) = WLONG_AGE(AGE,1) + WAGE*EFFLONG(AGE,1)*W(IS1,1)*coupleYW(AGE,IA,IS1,IS2,IE)/(temp_singleYW1 + temp_coupleYW)
						WLONG_AGE(AGE,2) = WLONG_AGE(AGE,2) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*coupleYW(AGE,IA,IS1,IS2,IE)/(temp_singleYW2 + temp_coupleYW)

						IF ( JN1 > 1 ) THEN
							labor_participation_age(AGE,1) = labor_participation_age(AGE,1) + coupleYW(AGE,IA,IS1,IS2,IE)
				 			labor_participation_age_couple(AGE,1) = labor_participation_age_couple(AGE,1) + coupleYW(AGE,IA,IS1,IS2,IE)
				 		END IF 

						IF ( JN2 > 1 ) THEN
							labor_participation_age(AGE,2) = labor_participation_age(AGE,2) + coupleYW(AGE,IA,IS1,IS2,IE)
				 			labor_participation_age_couple(AGE,2) = labor_participation_age_couple(AGE,2) + coupleYW(AGE,IA,IS1,IS2,IE)
				 		END IF  

				END DO
			END DO			  
        END DO
    END DO
END DO	

print*, 'save couple_labor.txt'
IF ((couple_labor==2) .AND. (optimal_tax_activation == 0)) THEN 
	OPEN(UNIT=27,FILE='couple_labor_male.txt')
		write(27,*) NLONG_AGE_couple(:,1)
	CLOSE(27)

	OPEN(UNIT=27,FILE='couple_labor_female.txt')
		write(27,*) NLONG_AGE_couple(:,2)
	CLOSE(27)
END IF 


ALONG_RETIRE_couple = 0.0
ILONG_RETIRE_couple = 0.0
TILONG_RETIRE_couple = 0.0
YDLONG_RETIRE_couple = 0.0
temp_coupleYR = SUM(coupleYR(RETAGE:MAXAGE,:,:))

DO AGE=RETAGE,MAXAGE
	ALONG_AGE_couple(AGE)=0.0
	temp_coupleYR_AGE = SUM(coupleYR(AGE,:,:))
	DO IA=1,NGRIDA
        DO IE = 1,NGRIDEH	
			
			JA = coupleIDCRA(AGE,IA,IE)
			INCOME = 2*SS(IE)    
			TINCOME = R*A(IA) + INCOME
			! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME ))**(1.0-tau_l_couple) &
			! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
			! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)	
			! yd = max( yd_MFJ(INCOME,IA), yd_MFS(INCOME,IA) )  
			yd = max( yd_MFJ(2*SS(IE) + min(R*A(IA),d_c), IA), yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA) )
			 
               
			ALONG_RETIRE_couple = ALONG_RETIRE_couple + A(JA)*coupleYR(AGE,IA,IE)/temp_coupleYR
			ILONG_RETIRE_couple = ILONG_RETIRE_couple + INCOME*coupleYR(AGE,IA,IE)/temp_coupleYR
			TILONG_RETIRE_couple = TILONG_RETIRE_couple + TINCOME*coupleYR(AGE,IA,IE)/temp_coupleYR
			YDLONG_RETIRE_couple = YDLONG_RETIRE_couple + yd*coupleYR(AGE,IA,IE)/temp_coupleYR

			ALONG_AGE_couple(AGE) = ALONG_AGE_couple(AGE) + A(JA)*coupleYR(AGE,IA,IE)/temp_coupleYR_AGE
			
		END DO
	END DO
END DO				

! Labor force participation rate: men (ages 25-54)
! LFP_male = SUM(labor_participation_age(2:6,1))/( SUM(singleYW(2:6,:,:,:,1))+SUM(coupleYW(2:6,:,:,:,:)) )

! Labor force participation rate: women (ages 25-54)
! LFP_female = SUM(labor_participation_age(2:6,2))/( SUM(singleYW(2:6,:,:,:,2))+SUM(coupleYW(2:6,:,:,:,:)) )

! Labor force participation rate: married women (ages 25-54)
! LFP_married_female = SUM(labor_participation_age_couple(2:6,2))/SUM(coupleYW(2:6,:,:,:,:)) 


! Labor force participation rate: men (ages 20-64)	!Dirk Krueger 2019 QE
LFP_male = SUM(labor_participation_age(1:RETAGE-1,1))/( SUM(singleYW(1:RETAGE-1,:,:,:,1))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)) )

! Labor force participation rate: women (ages 20-64)
LFP_female = SUM(labor_participation_age(1:RETAGE-1,2))/( SUM(singleYW(1:RETAGE-1,:,:,:,2))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)) )

! Labor force participation rate: single women (ages 20-64)
LFP_single_female = SUM(labor_participation_age_single(1:RETAGE-1,2))/SUM(singleYW(1:RETAGE-1,:,:,:,2)) 

! Labor force participation rate: married women (ages 20-64)
LFP_married_female = SUM(labor_participation_age_couple(1:RETAGE-1,2))/SUM(coupleYW(1:RETAGE-1,:,:,:,:)) 


! Age Profile Labor force participation rate: men 
DO AGE=1,RETAGE-1
	labor_participation_age(AGE,1) = labor_participation_age(AGE,1)/( SUM(singleYW(AGE,:,:,:,1))+SUM(coupleYW(AGE,:,:,:,:)) )
END DO 

! Age Profile Labor force participation rate: women 
DO AGE=1,RETAGE-1
	labor_participation_age(AGE,2) = labor_participation_age(AGE,2)/( SUM(singleYW(AGE,:,:,:,2))+SUM(coupleYW(AGE,:,:,:,:)) )
	labor_participation_age_single(AGE,2) = labor_participation_age_single(AGE,2)/SUM(singleYW(AGE,:,:,:,2))
	labor_participation_age_couple(AGE,2) = labor_participation_age_couple(AGE,2)/SUM(coupleYW(AGE,:,:,:,:))
END DO 

! Working hour male (all workers)
hour_male = 0.0
DO AGE=1,RETAGE-1
	hour_male = hour_male + ( NLONG_AGE_single(AGE,1)*SUM(singleYW(AGE,:,:,:,1)) + NLONG_AGE_couple(AGE,1)*SUM(coupleYW(AGE,:,:,:,:)) )/(SUM(singleYW(1:RETAGE-1,:,:,:,1))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)))
END DO

hour_single_male = 0.0
DO AGE=1,RETAGE-1
	hour_single_male = hour_single_male + NLONG_AGE_single(AGE,1)*SUM(singleYW(AGE,:,:,:,1))/SUM(singleYW(1:RETAGE-1,:,:,:,1))
END DO

hour_married_male = 0.0
DO AGE=1,RETAGE-1
	hour_married_male = hour_married_male + NLONG_AGE_couple(AGE,1)*SUM(coupleYW(AGE,:,:,:,:))/SUM(coupleYW(1:RETAGE-1,:,:,:,:))
END DO

! Working hour female (all workers)
hour_female = 0.0
DO AGE=1,RETAGE-1
	hour_female = hour_female + ( NLONG_AGE_single(AGE,2)*SUM(singleYW(AGE,:,:,:,2)) + NLONG_AGE_couple(AGE,2)*SUM(coupleYW(AGE,:,:,:,:)) )/(SUM(singleYW(1:RETAGE-1,:,:,:,2))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)))
END DO 

hour_single_female = 0.0
DO AGE=1,RETAGE-1
	hour_single_female = hour_single_female + NLONG_AGE_single(AGE,2)*SUM(singleYW(AGE,:,:,:,2))/SUM(singleYW(1:RETAGE-1,:,:,:,2))
END DO 

hour_married_female = 0.0
DO AGE=1,RETAGE-1
	hour_married_female = hour_married_female + NLONG_AGE_couple(AGE,2)*SUM(coupleYW(AGE,:,:,:,:))/SUM(coupleYW(1:RETAGE-1,:,:,:,:))
END DO 

! Wealth profile normalized by average
DO IG=1,2
! ALONG20_25_single(IG)=ALONG_AGE_single(1,IG)/Aggwealth
! ALONG25_30_single(IG)=ALONG_AGE_single(2,IG)/Aggwealth	
! ALONG30_35_single(IG)=ALONG_AGE_single(3,IG)/Aggwealth
! ALONG35_40_single(IG)=ALONG_AGE_single(4,IG)/Aggwealth		
! ALONG40_45_single(IG)=ALONG_AGE_single(5,IG)/Aggwealth
! ALONG45_50_single(IG)=ALONG_AGE_single(6,IG)/Aggwealth
! ALONG50_55_single(IG)=ALONG_AGE_single(7,IG)/Aggwealth
! ALONG55_60_single(IG)=ALONG_AGE_single(8,IG)/Aggwealth
! ALONG60_65_single(IG)=ALONG_AGE_single(9,IG)/Aggwealth
! ALONG65_70_single(IG)=ALONG_AGE_single(10,IG)/Aggwealth
! ALONG70_75_single(IG)=ALONG_AGE_single(11,IG)/Aggwealth
! ALONG75_80_single(IG)=ALONG_AGE_single(12,IG)/Aggwealth
! ALONG80_85_single(IG)=ALONG_AGE_single(13,IG)/Aggwealth
! ALONG85_90_single(IG)=ALONG_AGE_single(14,IG)/Aggwealth
! ALONG90_95_single(IG)=ALONG_AGE_single(15,IG)/Aggwealth
! ALONG95_100_single(IG)=ALONG_AGE_single(16,IG)/Aggwealth

ALONG25_30_single(IG)=ALONG_AGE_single(1,IG)/Aggwealth	
ALONG30_35_single(IG)=ALONG_AGE_single(2,IG)/Aggwealth
ALONG35_40_single(IG)=ALONG_AGE_single(3,IG)/Aggwealth		
ALONG40_45_single(IG)=ALONG_AGE_single(4,IG)/Aggwealth
ALONG45_50_single(IG)=ALONG_AGE_single(5,IG)/Aggwealth
ALONG50_55_single(IG)=ALONG_AGE_single(6,IG)/Aggwealth
ALONG55_60_single(IG)=ALONG_AGE_single(7,IG)/Aggwealth
ALONG60_65_single(IG)=ALONG_AGE_single(8,IG)/Aggwealth
ALONG65_70_single(IG)=ALONG_AGE_single(9,IG)/Aggwealth
ALONG70_75_single(IG)=ALONG_AGE_single(10,IG)/Aggwealth
ALONG75_80_single(IG)=ALONG_AGE_single(11,IG)/Aggwealth
ALONG80_85_single(IG)=ALONG_AGE_single(12,IG)/Aggwealth
ALONG85_90_single(IG)=ALONG_AGE_single(13,IG)/Aggwealth
ALONG90_95_single(IG)=ALONG_AGE_single(14,IG)/Aggwealth
ALONG95_100_single(IG)=ALONG_AGE_single(15,IG)/Aggwealth

ALONG65_MORE_single(IG)=ALONG_RETIRE_single(IG)/Aggwealth
END DO

! ALONG20_25_couple=ALONG_AGE_couple(1)/Aggwealth
! ALONG25_30_couple=ALONG_AGE_couple(2)/Aggwealth	
! ALONG30_35_couple=ALONG_AGE_couple(3)/Aggwealth
! ALONG35_40_couple=ALONG_AGE_couple(4)/Aggwealth		
! ALONG40_45_couple=ALONG_AGE_couple(5)/Aggwealth
! ALONG45_50_couple=ALONG_AGE_couple(6)/Aggwealth
! ALONG50_55_couple=ALONG_AGE_couple(7)/Aggwealth
! ALONG55_60_couple=ALONG_AGE_couple(8)/Aggwealth
! ALONG60_65_couple=ALONG_AGE_couple(9)/Aggwealth
! ALONG65_70_couple=ALONG_AGE_couple(10)/Aggwealth
! ALONG70_75_couple=ALONG_AGE_couple(11)/Aggwealth
! ALONG75_80_couple=ALONG_AGE_couple(12)/Aggwealth
! ALONG80_85_couple=ALONG_AGE_couple(13)/Aggwealth
! ALONG85_90_couple=ALONG_AGE_couple(14)/Aggwealth
! ALONG90_95_couple=ALONG_AGE_couple(15)/Aggwealth
! ALONG95_100_couple=ALONG_AGE_couple(16)/Aggwealth

ALONG25_30_couple=ALONG_AGE_couple(1)/Aggwealth	
ALONG30_35_couple=ALONG_AGE_couple(2)/Aggwealth
ALONG35_40_couple=ALONG_AGE_couple(3)/Aggwealth		
ALONG40_45_couple=ALONG_AGE_couple(4)/Aggwealth
ALONG45_50_couple=ALONG_AGE_couple(5)/Aggwealth
ALONG50_55_couple=ALONG_AGE_couple(6)/Aggwealth
ALONG55_60_couple=ALONG_AGE_couple(7)/Aggwealth
ALONG60_65_couple=ALONG_AGE_couple(8)/Aggwealth
ALONG65_70_couple=ALONG_AGE_couple(9)/Aggwealth
ALONG70_75_couple=ALONG_AGE_couple(10)/Aggwealth
ALONG75_80_couple=ALONG_AGE_couple(11)/Aggwealth
ALONG80_85_couple=ALONG_AGE_couple(12)/Aggwealth
ALONG85_90_couple=ALONG_AGE_couple(13)/Aggwealth
ALONG90_95_couple=ALONG_AGE_couple(14)/Aggwealth
ALONG95_100_couple=ALONG_AGE_couple(15)/Aggwealth
ALONG65_MORE_couple=ALONG_RETIRE_couple/Aggwealth

! ALONG20_25=ALONG(1)/Aggwealth
! ALONG25_30=ALONG(2)/Aggwealth	
! ALONG30_35=ALONG(3)/Aggwealth
! ALONG35_40=ALONG(4)/Aggwealth		
! ALONG40_45=ALONG(5)/Aggwealth
! ALONG45_50=ALONG(6)/Aggwealth
! ALONG50_55=ALONG(7)/Aggwealth
! ALONG55_60=ALONG(8)/Aggwealth
! ALONG60_65=ALONG(9)/Aggwealth
! ALONG65_MORE=(ALONG(10)+ALONG(11)+ALONG(12)+ALONG(13)+ALONG(14)+ALONG(15)+ALONG(16))/Aggwealth

! ALONG70_75=ALONG(12)/ALONG(11)
! ALONG75_80=ALONG(13)/ALONG(12)
! ALONG80_85=ALONG(14)/ALONG(13)
! ALONG85_90=ALONG(15)/ALONG(14)
! ALONG90_95=ALONG(16)/ALONG(15)
!ALONG95_100=ALONG(16)/ALONG(15)

! ALONG55_25=ALONG(8)/ALONG(2)
! ALONG60_89=ALONG(9)/ALONG(14)
! ALONG60_89=ALONG(9)*MU(9)/(ALONG(14)*MU(14))
! ALONG60_89=ALONG_AGE(9)/ALONG_AGE(15)
! ALONG60_89=ALONG(8)/ALONG(14)


!Earnings profile normalized by average

! calculate the average income that includes the retirement period same as Jose Victor, Kuhn 2016
ALLOCATE( sort_inc_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( sort_D_inc_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( box_inc_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

! Single working age
isort=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2                     
                
					isort=isort+1
					JN=singleIDCWN(AGE,IA,IS,IE,IG)   	
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)				
					sort_inc_retire(isort) =  INCOME 

				END DO 
            END DO
        END DO 
    END DO
END DO			    

! Couple working age
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

				 isort=isort+1
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)  
				 INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) 
				 sort_inc_retire(isort) =  INCOME 

				END DO 
            END DO
        END DO 
    END DO
END DO 

! Single retiree 
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IE = 1,NGRIDEH	
			DO IG=1,2    
            
              isort=isort+1
			  sort_inc_retire(isort) = SS(IE) 

            END DO 
        END DO 
    END DO
END DO  

! couple retiree
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

			isort=isort+1
			sort_inc_retire(isort) = 2*SS(IE) 

		END DO
    END DO
END DO  


CALL sorting(size(sort_inc_retire),sort_inc_retire) 

DO i = 1,size(sort_inc_retire)
	box_inc_retire(i)= 0
END DO

! Single working age
index_tinc = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2 

                 index_tinc = index_tinc + 1		
				 JN=singleIDCWN(AGE,IA,IS,IE,IG)   	
				 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)	
				 i = search(  INCOME , sort_inc_retire, box_inc_retire,1.D-2 )
				 sort_D_inc_retire(i) = singleYW(AGE,IA,IS,IE,IG)			
                !record_position_inc_retire(index_tinc) = i

				END DO 
            END DO
        END DO
    END DO
END DO

! Couple working age
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

				 index_tinc = index_tinc + 1
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)  
				 INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) 	
				 i = search(  INCOME , sort_inc_retire, box_inc_retire,1.D-2 )
				 sort_D_inc_retire(i) = coupleYW(AGE,IA,IS1,IS2,IE)

				 END DO 
            END DO
        END DO 
    END DO
END DO 


! Single retiree 
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA          
        DO IE = 1,NGRIDEH	
			DO IG=1,2

				index_tinc = index_tinc + 1		                
                i = search(SS(IE) , sort_inc_retire, box_inc_retire,1.D-2)				   
				sort_D_inc_retire(i) = singleYR(AGE,IA,IE,IG)			
                !record_position_inc_retire(index_tinc) = i
				
			END DO 				
        END DO
    END DO
END DO


! couple retiree
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

			index_tinc = index_tinc + 1		                
            i = search(2*SS(IE) , sort_inc_retire, box_inc_retire,1.D-2)				   
			sort_D_inc_retire(i) = coupleYR(AGE,IA,IE)

		END DO
    END DO
END DO  


sort_D_inc_retire(:) = sort_D_inc_retire(:)/sum(sort_D_inc_retire)
Aggearning_retire = dot_product(sort_inc_retire,sort_D_inc_retire)

DO IG=1,2
! ILONG20_25_single(IG)=ILONG_AGE_single(1,IG)/Aggearning_retire
! ILONG25_30_single(IG)=ILONG_AGE_single(2,IG)/Aggearning_retire	
! ILONG30_35_single(IG)=ILONG_AGE_single(3,IG)/Aggearning_retire
! ILONG35_40_single(IG)=ILONG_AGE_single(4,IG)/Aggearning_retire		
! ILONG40_45_single(IG)=ILONG_AGE_single(5,IG)/Aggearning_retire
! ILONG45_50_single(IG)=ILONG_AGE_single(6,IG)/Aggearning_retire
! ILONG50_55_single(IG)=ILONG_AGE_single(7,IG)/Aggearning_retire
! ILONG55_60_single(IG)=ILONG_AGE_single(8,IG)/Aggearning_retire
! ILONG60_65_single(IG)=ILONG_AGE_single(9,IG)/Aggearning_retire

ILONG25_30_single(IG)=ILONG_AGE_single(1,IG)/Aggearning_retire	
ILONG30_35_single(IG)=ILONG_AGE_single(2,IG)/Aggearning_retire
ILONG35_40_single(IG)=ILONG_AGE_single(3,IG)/Aggearning_retire		
ILONG40_45_single(IG)=ILONG_AGE_single(4,IG)/Aggearning_retire
ILONG45_50_single(IG)=ILONG_AGE_single(5,IG)/Aggearning_retire
ILONG50_55_single(IG)=ILONG_AGE_single(6,IG)/Aggearning_retire
ILONG55_60_single(IG)=ILONG_AGE_single(7,IG)/Aggearning_retire
ILONG60_65_single(IG)=ILONG_AGE_single(8,IG)/Aggearning_retire
ILONG65_MORE_single(IG)=ILONG_RETIRE_single(IG)/Aggearning_retire
END DO 

! ILONG20_25_couple=ILONG_AGE_couple(1)/Aggearning_retire
! ILONG25_30_couple=ILONG_AGE_couple(2)/Aggearning_retire	
! ILONG30_35_couple=ILONG_AGE_couple(3)/Aggearning_retire
! ILONG35_40_couple=ILONG_AGE_couple(4)/Aggearning_retire		
! ILONG40_45_couple=ILONG_AGE_couple(5)/Aggearning_retire
! ILONG45_50_couple=ILONG_AGE_couple(6)/Aggearning_retire
! ILONG50_55_couple=ILONG_AGE_couple(7)/Aggearning_retire
! ILONG55_60_couple=ILONG_AGE_couple(8)/Aggearning_retire
! ILONG60_65_couple=ILONG_AGE_couple(9)/Aggearning_retire

ILONG25_30_couple=ILONG_AGE_couple(1)/Aggearning_retire	
ILONG30_35_couple=ILONG_AGE_couple(2)/Aggearning_retire
ILONG35_40_couple=ILONG_AGE_couple(3)/Aggearning_retire		
ILONG40_45_couple=ILONG_AGE_couple(4)/Aggearning_retire
ILONG45_50_couple=ILONG_AGE_couple(5)/Aggearning_retire
ILONG50_55_couple=ILONG_AGE_couple(6)/Aggearning_retire
ILONG55_60_couple=ILONG_AGE_couple(7)/Aggearning_retire
ILONG60_65_couple=ILONG_AGE_couple(8)/Aggearning_retire
ILONG65_MORE_couple=ILONG_RETIRE_couple/Aggearning_retire

! ILONG20_25=ILONG(1)/Aggincome
! ILONG25_30=ILONG(2)/Aggincome	
! ILONG30_35=ILONG(3)/Aggincome
! ILONG35_40=ILONG(4)/Aggincome		
! ILONG40_45=ILONG(5)/Aggincome
! ILONG45_50=ILONG(6)/Aggincome
! ILONG50_55=ILONG(7)/Aggincome
! ILONG55_60=ILONG(8)/Aggincome
! ILONG60_65=ILONG(9)/Aggincome	
! ILONG65_MORE=(ILONG(10)+ILONG(11)+ILONG(12)+ILONG(13)+ILONG(14)+ILONG(15)+ILONG(16))/Aggincome

! ILONG70_75=ILONG(12)/ILONG(11)
! ILONG75_80=ILONG(13)/ILONG(12)
! ILONG80_85=ILONG(14)/ILONG(13)
! ILONG85_90=ILONG(15)/ILONG(14)
! ILONG90_95=ILONG(16)/ILONG(15)

!ILONG55_20=ILONG(7)/ILONG(1)


! Before tax total income including government transfers (According to Kuhn & Rios 2016 Definition)
DO IG=1,2
! TILONG20_25_single(IG)=TILONG_AGE_single(1,IG)/Aggtincome
! TILONG25_30_single(IG)=TILONG_AGE_single(2,IG)/Aggtincome
! TILONG30_35_single(IG)=TILONG_AGE_single(3,IG)/Aggtincome
! TILONG35_40_single(IG)=TILONG_AGE_single(4,IG)/Aggtincome		
! TILONG40_45_single(IG)=TILONG_AGE_single(5,IG)/Aggtincome
! TILONG45_50_single(IG)=TILONG_AGE_single(6,IG)/Aggtincome
! TILONG50_55_single(IG)=TILONG_AGE_single(7,IG)/Aggtincome
! TILONG55_60_single(IG)=TILONG_AGE_single(8,IG)/Aggtincome
! TILONG60_65_single(IG)=TILONG_AGE_single(9,IG)/Aggtincome	
! TILONG65_MORE_single(IG)=TILONG_RETIRE_single(IG)/Aggtincome

TILONG25_30_single(IG)=TILONG_AGE_single(1,IG)/Aggtincome
TILONG30_35_single(IG)=TILONG_AGE_single(2,IG)/Aggtincome
TILONG35_40_single(IG)=TILONG_AGE_single(3,IG)/Aggtincome		
TILONG40_45_single(IG)=TILONG_AGE_single(4,IG)/Aggtincome
TILONG45_50_single(IG)=TILONG_AGE_single(5,IG)/Aggtincome
TILONG50_55_single(IG)=TILONG_AGE_single(6,IG)/Aggtincome
TILONG55_60_single(IG)=TILONG_AGE_single(7,IG)/Aggtincome
TILONG60_65_single(IG)=TILONG_AGE_single(8,IG)/Aggtincome	
TILONG65_MORE_single(IG)=TILONG_RETIRE_single(IG)/Aggtincome
END DO 

! TILONG20_25_couple=TILONG_AGE_couple(1)/Aggtincome
! TILONG25_30_couple=TILONG_AGE_couple(2)/Aggtincome
! TILONG30_35_couple=TILONG_AGE_couple(3)/Aggtincome
! TILONG35_40_couple=TILONG_AGE_couple(4)/Aggtincome		
! TILONG40_45_couple=TILONG_AGE_couple(5)/Aggtincome
! TILONG45_50_couple=TILONG_AGE_couple(6)/Aggtincome
! TILONG50_55_couple=TILONG_AGE_couple(7)/Aggtincome
! TILONG55_60_couple=TILONG_AGE_couple(8)/Aggtincome
! TILONG60_65_couple=TILONG_AGE_couple(9)/Aggtincome	
! TILONG65_MORE_couple=TILONG_RETIRE_couple/Aggtincome


TILONG25_30_couple=TILONG_AGE_couple(1)/Aggtincome
TILONG30_35_couple=TILONG_AGE_couple(2)/Aggtincome
TILONG35_40_couple=TILONG_AGE_couple(3)/Aggtincome		
TILONG40_45_couple=TILONG_AGE_couple(4)/Aggtincome
TILONG45_50_couple=TILONG_AGE_couple(5)/Aggtincome
TILONG50_55_couple=TILONG_AGE_couple(6)/Aggtincome
TILONG55_60_couple=TILONG_AGE_couple(7)/Aggtincome
TILONG60_65_couple=TILONG_AGE_couple(8)/Aggtincome	
TILONG65_MORE_couple=TILONG_RETIRE_couple/Aggtincome


DO IG=1,2
! YDLONG20_25_single(IG)=YDLONG_AGE_single(1,IG)
! YDLONG25_30_single(IG)=YDLONG_AGE_single(2,IG)
! YDLONG30_35_single(IG)=YDLONG_AGE_single(3,IG)
! YDLONG35_40_single(IG)=YDLONG_AGE_single(4,IG)	
! YDLONG40_45_single(IG)=YDLONG_AGE_single(5,IG)
! YDLONG45_50_single(IG)=YDLONG_AGE_single(6,IG)
! YDLONG50_55_single(IG)=YDLONG_AGE_single(7,IG)
! YDLONG55_60_single(IG)=YDLONG_AGE_single(8,IG)
! YDLONG60_65_single(IG)=YDLONG_AGE_single(9,IG)
! YDLONG65_MORE_single(IG)=YDLONG_RETIRE_single(IG)

YDLONG25_30_single(IG)=YDLONG_AGE_single(1,IG)
YDLONG30_35_single(IG)=YDLONG_AGE_single(2,IG)
YDLONG35_40_single(IG)=YDLONG_AGE_single(3,IG)	
YDLONG40_45_single(IG)=YDLONG_AGE_single(4,IG)
YDLONG45_50_single(IG)=YDLONG_AGE_single(5,IG)
YDLONG50_55_single(IG)=YDLONG_AGE_single(6,IG)
YDLONG55_60_single(IG)=YDLONG_AGE_single(7,IG)
YDLONG60_65_single(IG)=YDLONG_AGE_single(8,IG)
YDLONG65_MORE_single(IG)=YDLONG_RETIRE_single(IG)
END DO 

! YDLONG20_25_couple=YDLONG_AGE_couple(1)
! YDLONG25_30_couple=YDLONG_AGE_couple(2)
! YDLONG30_35_couple=YDLONG_AGE_couple(3)
! YDLONG35_40_couple=YDLONG_AGE_couple(4)		
! YDLONG40_45_couple=YDLONG_AGE_couple(5)
! YDLONG45_50_couple=YDLONG_AGE_couple(6)
! YDLONG50_55_couple=YDLONG_AGE_couple(7)
! YDLONG55_60_couple=YDLONG_AGE_couple(8)
! YDLONG60_65_couple=YDLONG_AGE_couple(9)	

YDLONG25_30_couple=YDLONG_AGE_couple(1)
YDLONG30_35_couple=YDLONG_AGE_couple(2)
YDLONG35_40_couple=YDLONG_AGE_couple(3)		
YDLONG40_45_couple=YDLONG_AGE_couple(4)
YDLONG45_50_couple=YDLONG_AGE_couple(5)
YDLONG50_55_couple=YDLONG_AGE_couple(6)
YDLONG55_60_couple=YDLONG_AGE_couple(7)
YDLONG60_65_couple=YDLONG_AGE_couple(8)	
YDLONG65_MORE_couple=YDLONG_RETIRE_couple


END SUBROUTINE
!***************************************************************************************
SUBROUTINE var_profile

ALLOCATE( mean_earning_age_single(RETAGE-1), var_earning_age_single(RETAGE-1))
ALLOCATE( mean_cons_age_single(RETAGE-1), var_cons_age_single(RETAGE-1))
ALLOCATE( mean_earning_age_couple(RETAGE-1), var_earning_age_couple(RETAGE-1),var_earning_age_couple_HH(RETAGE-1))
ALLOCATE( mean_cons_age_couple(RETAGE-1), var_cons_age_couple(RETAGE-1))
ALLOCATE( mean_earning_age(RETAGE-1), var_earning_age(RETAGE-1))
ALLOCATE( mean_cons_age(RETAGE-1), var_cons_age(RETAGE-1))
ALLOCATE( mean_wage_age_single(RETAGE-1), var_wage_age_single(RETAGE-1))
ALLOCATE( mean_wage_age_couple(RETAGE-1), var_wage_age_couple(RETAGE-1))
ALLOCATE( lifecycle_var_cons_earn_ratio_single(RETAGE-1), lifecycle_var_cons_earn_ratio_couple(RETAGE-1))


mean_earning_age_single(:) = 0.0
var_earning_age_single(:) = 0.0
mean_cons_age_single(:) = 0.0
var_cons_age_single(:) = 0.0
mean_earning_age_couple(:) = 0.0
var_earning_age_couple(:) = 0.0
var_earning_age_couple_HH(:) = 0.0
mean_cons_age_couple(:) = 0.0
var_cons_age_couple(:) = 0.0
mean_earning_age(:) = 0.0
var_earning_age(:) = 0.0
mean_cons_age(:) = 0.0
var_cons_age(:) = 0.0
mean_wage_age_single(:) = 0.0
var_wage_age_single(:) = 0.0
mean_wage_age_couple(:) = 0.0
var_wage_age_couple(:) = 0.0

! Single
DO AGE=1,RETAGE-1
temp_singleYW = SUM(singleYW(AGE,:,:,:,:))
	DO IA = 1,NGRIDA           			
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2

					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)

					IF (INCOME > 1.D-5) THEN 
						mean_earning_single = mean_earning_single + log(INCOME)*singleYW(AGE,IA,IS,IE,IG)
						mean_earning_age_single(AGE) = mean_earning_age_single(AGE) + log(INCOME)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW	
						mean_earning_age(AGE) = mean_earning_age(AGE) + log(INCOME)*singleYW(AGE,IA,IS,IE,IG)
						mean_wage_age_single(AGE) = mean_wage_age_single(AGE) + log(WAGE*EFFLONG(AGE,IG)*W(IS,IG))*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW	
						! mean_wage_age_single(AGE) = mean_wage_age_single(AGE) + log(shock(IS,IG))*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW						
					END IF
					
					mean_cons_single = mean_cons_single + log(singleIDCWC(AGE,IA,IS,IE,IG))*singleYW(AGE,IA,IS,IE,IG)
					mean_cons_age_single(AGE) = mean_cons_age_single(AGE) + log(singleIDCWC(AGE,IA,IS,IE,IG))*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW
					mean_cons_age(AGE) = mean_cons_age(AGE) + log(singleIDCWC(AGE,IA,IS,IE,IG))*singleYW(AGE,IA,IS,IE,IG)

				END DO 
            END DO
        END DO
    END DO
END DO

mean_earning_single = mean_earning_single/SUM(singleYW)
mean_cons_single = mean_cons_single/SUM(singleYW)

DO AGE=1,RETAGE-1
temp_singleYW = SUM(singleYW(AGE,:,:,:,:))
	DO IA = 1,NGRIDA           			
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2

					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)

					IF (INCOME > 1.D-5) THEN 
						var_earning_single = var_earning_single + ((log(INCOME)-mean_earning_single)**2)*singleYW(AGE,IA,IS,IE,IG)
						var_earning_age_single(AGE) = var_earning_age_single(AGE) + ((log(INCOME)-mean_earning_age_single(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW	
						var_wage_age_single(AGE) = var_wage_age_single(AGE) + ((log(WAGE*EFFLONG(AGE,IG)*W(IS,IG))-mean_wage_age_single(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW		
						! var_wage_age_single(AGE) = var_wage_age_single(AGE) + ((log(shock(IS,IG))-mean_wage_age_single(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW			
					END IF

					var_cons_single = var_cons_single + ((log(singleIDCWC(AGE,IA,IS,IE,IG))-mean_cons_single)**2)*singleYW(AGE,IA,IS,IE,IG)
					var_cons_age_single(AGE) = var_cons_age_single(AGE) + ((log(singleIDCWC(AGE,IA,IS,IE,IG))-mean_cons_age_single(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW

				END DO 
            END DO
        END DO
    END DO
END DO

var_earning_single = var_earning_single/SUM(singleYW)
var_cons_single = var_cons_single/SUM(singleYW)

! Couple
DO AGE = 1,RETAGE-1
temp_coupleYW = SUM(coupleYW(AGE,:,:,:,:))
    DO IA = 1,NGRIDA           			
		DO IS1 = 1,nn 		
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					INCOME1 = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)
					INCOME2 = WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
					INCOME = INCOME1 + INCOME2 

					IF ((INCOME1 > 1.D-5) .AND. (INCOME2 > 1.D-5)) THEN 
						! mean_earning_couple = mean_earning_couple + log(INCOME)*coupleYW(AGE,IA,IS1,IS2,IE)
						! mean_earning_age_couple(AGE) = mean_earning_age_couple(AGE) + log(INCOME)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						! mean_earning_age(AGE) = mean_earning_age(AGE) + log(INCOME)*coupleYW(AGE,IA,IS1,IS2,IE)
						! mean_wage_age_couple(AGE) = mean_wage_age_couple(AGE) + log(WAGE*EFFLONG(AGE,1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*W(IS2,2))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

						mean_earning_couple = mean_earning_couple + (log(INCOME1)+log(INCOME2))*coupleYW(AGE,IA,IS1,IS2,IE)
						mean_earning_age_couple(AGE) = mean_earning_age_couple(AGE) + (log(INCOME1)+log(INCOME2))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						mean_earning_age(AGE) = mean_earning_age(AGE) + (log(INCOME1)+log(INCOME2))*coupleYW(AGE,IA,IS1,IS2,IE)
						mean_wage_age_couple(AGE) = mean_wage_age_couple(AGE) + (log(WAGE*EFFLONG(AGE,1)*W(IS1,1)) + log(WAGE*EFFLONG(AGE,2)*W(IS2,2)))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						
						! mean_wage_age_couple(AGE) = mean_wage_age_couple(AGE) + (log(shock(IS1,1)) + log(shock(IS2,2)))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					END IF
					
					mean_cons_couple = mean_cons_couple + log(coupleIDCWC(AGE,IA,IS1,IS2,IE))*coupleYW(AGE,IA,IS1,IS2,IE)
					mean_cons_age_couple(AGE) = mean_cons_age_couple(AGE) + log(coupleIDCWC(AGE,IA,IS1,IS2,IE))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					mean_cons_age(AGE) = mean_cons_age(AGE) + log(coupleIDCWC(AGE,IA,IS1,IS2,IE))*coupleYW(AGE,IA,IS1,IS2,IE)

				END DO 
            END DO
        END DO
    END DO
END DO

mean_earning_couple = mean_earning_couple/SUM(coupleYW)
mean_cons_couple = mean_cons_couple/SUM(coupleYW)

DO AGE = 1,RETAGE-1
temp_coupleYW = SUM(coupleYW(AGE,:,:,:,:))
    DO IA = 1,NGRIDA           			
		DO IS1 = 1,nn 		
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					INCOME1 = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)
					INCOME2 = WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
					INCOME = INCOME1 + INCOME2 

					IF ((INCOME1 > 1.D-5) .AND. (INCOME2 > 1.D-5)) THEN 
						! var_earning_couple = var_earning_couple + ((log(INCOME)-mean_earning_couple)**2)*coupleYW(AGE,IA,IS1,IS2,IE)
						! var_earning_age_couple(AGE) = var_earning_age_couple(AGE) + ((log(INCOME)-mean_earning_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						! var_wage_age_couple(AGE) = var_wage_age_couple(AGE) + ((log(WAGE*EFFLONG(AGE,1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*W(IS2,2))-mean_wage_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						var_earning_couple = var_earning_couple + (((log(INCOME1)+log(INCOME2))-mean_earning_couple)**2)*coupleYW(AGE,IA,IS1,IS2,IE)
						var_earning_age_couple(AGE) = var_earning_age_couple(AGE) + (((log(INCOME1)+log(INCOME2))-mean_earning_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						var_earning_age_couple_HH(AGE) = var_earning_age_couple_HH(AGE) + ((log(INCOME)-mean_earning_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						var_wage_age_couple(AGE) = var_wage_age_couple(AGE) + ((log(WAGE*EFFLONG(AGE,1)*W(IS1,1)) + log(WAGE*EFFLONG(AGE,2)*W(IS2,2))-mean_wage_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

						! var_wage_age_couple(AGE) = var_wage_age_couple(AGE) + ((log(shock(IS1,1)) + log(shock(IS2,2))-mean_wage_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					END IF 

					var_cons_couple = var_cons_couple + ((log(coupleIDCWC(AGE,IA,IS1,IS2,IE))-mean_cons_couple)**2)*coupleYW(AGE,IA,IS1,IS2,IE)
					var_cons_age_couple(AGE) = var_cons_age_couple(AGE) + ((log(coupleIDCWC(AGE,IA,IS1,IS2,IE))-mean_cons_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

				END DO 
            END DO
        END DO
    END DO
END DO

var_earning_couple = var_earning_couple/SUM(coupleYW)
var_cons_couple = var_cons_couple/SUM(coupleYW)

! variance of earning and consumption of whole population
DO AGE = 1,RETAGE-1
	mean_earning_age(AGE) = mean_earning_age(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
	mean_cons_age(AGE) = mean_cons_age(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
END DO 

DO AGE=1,RETAGE-1
	DO IA = 1,NGRIDA           			
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2

					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
					IF (INCOME > 1.D-5) THEN 					
						var_earning_age(AGE) = var_earning_age(AGE) + ((log(INCOME)-mean_earning_age(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)								
					END IF
					var_cons_age(AGE) = var_cons_age(AGE) + ((log(singleIDCWC(AGE,IA,IS,IE,IG))-mean_cons_age(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)
				
				END DO 
            END DO
        END DO
    END DO
END DO

DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
		DO IS1 = 1,nn 		
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					INCOME1 = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)
					INCOME2 = WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
					INCOME = INCOME1 + INCOME2

					IF ((INCOME1 > 1.D-5) .AND. (INCOME2 > 1.D-5)) THEN 			
						var_earning_age(AGE) = var_earning_age(AGE) + (((log(INCOME1)+log(INCOME2))-mean_earning_age(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)						
					END IF 
					var_cons_age(AGE) = var_cons_age(AGE) + ((log(coupleIDCWC(AGE,IA,IS1,IS2,IE))-mean_cons_age(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)

				END DO 
            END DO
        END DO
    END DO
END DO

DO AGE = 1,RETAGE-1
	var_earning_age(AGE) = var_earning_age(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
	var_cons_age(AGE) = var_cons_age(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
END DO 

var_cons_earning_ratio_single = var_cons_single/var_earning_single
var_cons_earning_ratio_couple = var_cons_couple/var_earning_couple
DO AGE = 1,RETAGE-1
	lifecycle_var_cons_earn_ratio_single(AGE) = var_cons_age_single(AGE)/var_earning_age_single(AGE)
	lifecycle_var_cons_earn_ratio_couple(AGE) = var_cons_age_couple(AGE)/var_earning_age_couple_HH(AGE)
END DO 

END SUBROUTINE
!***************************************************************************************
SUBROUTINE intrafamily_correlation

ALLOCATE(var_earn_husband(RETAGE-1),var_earn_wife(RETAGE-1))
ALLOCATE(mean_earn_husband(RETAGE-1),mean_earn_wife(RETAGE-1))
ALLOCATE(cov_family_earn(RETAGE-1),corr_family_earn(RETAGE-1))

var_earn_husband(:) = 0.0
var_earn_wife(:) = 0.0
cov_family_earn(:) = 0.0
corr_family_earn(:) = 0.0
mean_earn_husband(:) = 0.0
mean_earn_wife(:) = 0.0
Avg_corr_family_earn = 0.0

DO AGE = 1,RETAGE-1
temp_coupleYW = SUM(coupleYW(AGE,:,:,:,:))
    DO IA = 1,NGRIDA           			
		DO IS1 = 1,nn 		
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					! mean_earn_husband(AGE) = mean_earn_husband(AGE) + W(IS1,1)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					! mean_earn_wife(AGE) = mean_earn_wife(AGE) + W(IS2,2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

					mean_earn_husband(AGE) = mean_earn_husband(AGE) + EFFLONG(AGE,1)*W(IS1,1)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					mean_earn_wife(AGE) = mean_earn_wife(AGE) + EFFLONG(AGE,2)*W(IS2,2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

				END DO 
            END DO
        END DO
    END DO
END DO

DO AGE = 1,RETAGE-1
temp_coupleYW = SUM(coupleYW(AGE,:,:,:,:))
    DO IA = 1,NGRIDA           			
		DO IS1 = 1,nn 		
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					cov_family_earn(AGE) = cov_family_earn(AGE) + (W(IS1,1)-mean_earn_husband(AGE))*(W(IS2,2)-mean_earn_wife(AGE))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					var_earn_husband(AGE) = var_earn_husband(AGE) + ((W(IS1,1)-mean_earn_husband(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					var_earn_wife(AGE) = var_earn_wife(AGE) + ((W(IS2,2)-mean_earn_wife(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					
					! cov_family_earn(AGE) = cov_family_earn(AGE) + (EFFLONG(AGE,1)*W(IS1,1)-mean_earn_husband(AGE))*(EFFLONG(AGE,2)*W(IS2,2)-mean_earn_wife(AGE))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					! var_earn_husband(AGE) = var_earn_husband(AGE) + ((EFFLONG(AGE,1)*W(IS1,1)-mean_earn_husband(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					! var_earn_wife(AGE) = var_earn_wife(AGE) + ((EFFLONG(AGE,2)*W(IS2,2)-mean_earn_wife(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
				
				END DO 
            END DO
        END DO
    END DO
END DO

DO AGE = 1,RETAGE-1
	corr_family_earn(AGE) = cov_family_earn(AGE)/(var_earn_husband(AGE)*var_earn_wife(AGE))**0.5
END DO 

temp_coupleYW = SUM(coupleYW(1:RETAGE-1,:,:,:,:))
DO AGE = 1,RETAGE-1
	Avg_corr_family_earn = Avg_corr_family_earn + corr_family_earn(AGE)*SUM(coupleYW(AGE,:,:,:,:))/temp_coupleYW
END DO 

print*, 'Intrafamily Wage Correlation'
print*, 'Avg_corr_family_earn',Avg_corr_family_earn
print*, 'corr_family_earn',corr_family_earn
print*, 'cov_family_earn',cov_family_earn
print*, 'var_earn_husband',var_earn_husband
print*, 'var_earn_wife',var_earn_wife

END SUBROUTINE
!***************************************************************************************
SUBROUTINE income_partition   


ALLOCATE( totalincome((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( earning_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( kincome_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( trans_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( age_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )


! Kuhn & Jose Victor 2015  

! Single working age
state_pos = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA        
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2          
			
                 state_pos = state_pos + 1
				 JN=singleIDCWN(AGE,IA,IS,IE,IG)   	
				 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
				 TINCOME = R*A(IA) + INCOME
				 yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
					  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME)/avg_earnings - singlebendy) &
					  +(1-tau_c)*max(R*A(IA)-d_c,0.0)					
				
				 ! totalincome(record_position_tinc(INT(state_pos))) = R(IR)*A(IA) + WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				 totalincome(record_position_tinc(INT(state_pos))) = R*A(IA) + INCOME + BEQ + ABS( MIN(TINCOME - yd, 0.0) ) + gov_trans
				 earning_share(record_position_tinc(INT(state_pos))) = INCOME
				 kincome_share(record_position_tinc(INT(state_pos))) = R*A(IA)
				 ! trans_share(record_position_tinc(INT(state_pos))) = BEQ*(1.0+GROWTH)**(AGE-1) ! Transfer: social security, bequest (kuhn & rios 2016)
				 trans_share(record_position_tinc(INT(state_pos))) = BEQ + ABS( MIN(TINCOME - yd, 0.0) ) + gov_trans
				 age_share(record_position_tinc(INT(state_pos))) = AGE
				
				END DO 			                
            END DO
        END DO
    END DO
END DO
				
! Couple working age
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH		

				 state_pos = state_pos + 1		
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)  
				 INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
				 TINCOME = R*A(IA) + INCOME
				!  yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
				! 	+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+INCOME - couplebendy) &
				! 	+(1-tau_c)*max(R*A(IA)-d_c,0.0)
				 
				 yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c), IA), yd_MFS( WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)+ min(R*A(IA),d_c)/2 ,IA) )
	

				 ! totalincome(record_position_tinc(INT(state_pos))) = R(IR)*A(IA) + WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				 totalincome(record_position_tinc(INT(state_pos))) = R*A(IA) + INCOME + 2*BEQ + ABS( MIN(TINCOME - yd, 0.0) ) + gov_trans
				 earning_share(record_position_tinc(INT(state_pos))) = INCOME
				 kincome_share(record_position_tinc(INT(state_pos))) = R*A(IA)
				 ! trans_share(record_position_tinc(INT(state_pos))) = BEQ*(1.0+GROWTH)**(AGE-1) ! Transfer: social security, bequest (kuhn & rios 2016)
				 trans_share(record_position_tinc(INT(state_pos))) = 2*BEQ + ABS( MIN(TINCOME - yd, 0.0) ) + gov_trans
				 age_share(record_position_tinc(INT(state_pos))) = AGE

				END DO 
            END DO
        END DO 
    END DO
END DO 
				
! Single retiree 

!DO AGE=RETAGE,MAXAGE-1
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IE = 1,NGRIDEH	
			DO IG=1,2                
			
                state_pos = state_pos + 1
				
				INCOME = SS(IE)
				TINCOME = R*A(IA) + INCOME 
				yd = avg_earnings*MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
					  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME)/avg_earnings - singlebendy) &
					  +(1-tau_c)*max(R*A(IA)-d_c,0.0)
				
				! Transfer: social security, bequest (kuhn & rios 2016)				
				! totalincome(record_position_tinc(INT(state_pos))) = R(IR)*A(IA) + SS  
				totalincome(record_position_tinc(INT(state_pos))) = R*A(IA) + SS(IE) + ABS( MIN(TINCOME - yd, 0.0) ) +gov_trans 
				kincome_share(record_position_tinc(INT(state_pos))) = R*A(IA)
				!earning_share(record_position_tinc(INT(state_pos))) = SS/totalincome(record_position_tinc(INT(state_pos)))		
				!trans_share(record_position_tinc(INT(state_pos))) =  ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)/totalincome(record_position_tinc(INT(state_pos)))  
				earning_share(record_position_tinc(INT(state_pos))) = 0.0
				trans_share(record_position_tinc(INT(state_pos))) =  SS(IE) + ABS( MIN(TINCOME - yd, 0.0) ) +gov_trans ! +ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)		                
				age_share(record_position_tinc(INT(state_pos))) = AGE

			END DO 
        END DO
    END DO
END DO

! couple retiree    
! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

		 state_pos = state_pos + 1
				
		 INCOME = 2*SS(IE)
 		 TINCOME = R*A(IA) + INCOME 
		!  yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
		! 		+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+INCOME - couplebendy) &
		! 		+(1-tau_c)*max(R*A(IA)-d_c,0.0)
		 
		 yd = max( yd_MFJ( 2*SS(IE) + min(R*A(IA),d_c), IA), yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA) )


		 ! Transfer: social security, bequest (kuhn & rios 2016)				
		 ! totalincome(record_position_tinc(INT(state_pos))) = R(IR)*A(IA) + SS  
		 totalincome(record_position_tinc(INT(state_pos))) = R*A(IA) + INCOME + ABS( MIN(TINCOME - yd, 0.0) ) +gov_trans 
		 kincome_share(record_position_tinc(INT(state_pos))) = R*A(IA)
		 !earning_share(record_position_tinc(INT(state_pos))) = SS/totalincome(record_position_tinc(INT(state_pos)))		
		 !trans_share(record_position_tinc(INT(state_pos))) =  ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)/totalincome(record_position_tinc(INT(state_pos)))  
		 earning_share(record_position_tinc(INT(state_pos))) = 0.0
		 trans_share(record_position_tinc(INT(state_pos))) =  2*SS(IE) + ABS( MIN(TINCOME - yd, 0.0) ) +gov_trans ! +ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)		                
		 age_share(record_position_tinc(INT(state_pos))) = AGE

		END DO
    END DO
END DO   

! Average		
	
	earning_share_avg = sum(earning_share*sort_D_TINC)/sum(totalincome*sort_D_TINC)
	kincome_share_avg = sum(kincome_share*sort_D_TINC)/sum(totalincome*sort_D_TINC)
	trans_share_avg = sum(trans_share*sort_D_TINC)/sum(totalincome*sort_D_TINC)
	!age_share_avg = sum(age_share*sort_D_TINC)/sum(totalincome*sort_D_TINC)
	age_share_avg = sum(age_share*sort_D_TINC)
	print*, 'earning_share_avg=', earning_share_avg	
	print*, 'kincome_share_avg=', kincome_share_avg
	print*, 'trans_share_avg=', trans_share_avg
	!print*, 'sort_D_TINC',sum(sort_D_TINC)

! Top 1%		
	
	earning_share1 = (sum(earning_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc))))/sum(totalincome*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)))
	kincome_share1 = (sum(kincome_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc))))/sum(totalincome*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)))
	trans_share1 = (sum(trans_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc))))/sum(totalincome*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)))
	age_share1 = sum( age_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)) )
	print*, 'earning_share1=', earning_share1
	print*, 'kincome_share1=', kincome_share1
	print*, 'trans_share1=', trans_share1
!	print*, 'sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc))',sum(sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)))
	
	
! 95-99%		
	
	earning_share9599 = (sum(earning_share*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))))
	kincome_share9599 = (sum(kincome_share*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))))
	trans_share9599 = (sum(trans_share*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))))
	age_share9599 = sum( age_share*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc))) )
	print*, 'earning_share9599=', earning_share9599
	print*, 'kincome_share9599=', kincome_share9599
	print*, 'trans_share9599=', trans_share9599
!	print*, 'sort_D*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)))',sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))))

! 90-95%		
	
	earning_share9095 = (sum(earning_share*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))))
	kincome_share9095 = (sum(kincome_share*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))))
	trans_share9095 = (sum(trans_share*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))))
	age_share9095 = sum( age_share*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc))) )
	print*, 'earning_share9095=', earning_share9095
	print*, 'kincome_share9095=', kincome_share9095
	print*, 'trans_share9095=', trans_share9095
!	print*, 'sort_D*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D*(top10pct_D_tinc-top5pct_D_tinc)))',sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))))

!  80 - 100%		
	
	earning_share5q = (sum(earning_share*sort_D_TINC*top20pct_D_tinc/(sum(sort_D_TINC*top20pct_D_tinc))))/sum(totalincome*sort_D_TINC*top20pct_D_tinc/(sum(sort_D_TINC*top20pct_D_tinc)))
	kincome_share5q = (sum(kincome_share*sort_D_TINC*top20pct_D_tinc/(sum(sort_D_TINC*top20pct_D_tinc))))/sum(totalincome*sort_D_TINC*top20pct_D_tinc/(sum(sort_D_TINC*top20pct_D_tinc)))
	trans_share5q = (sum(trans_share*sort_D_TINC*top20pct_D_tinc/(sum(sort_D_TINC*top20pct_D_tinc))))/sum(totalincome*sort_D_TINC*top20pct_D_tinc/(sum(sort_D_TINC*top20pct_D_tinc)))
	age_share5q = sum( age_share*sort_D_TINC*top20pct_D_tinc/(sum(sort_D_TINC*top20pct_D_tinc)) )
!  60 - 80%		
	
	earning_share4q = (sum(earning_share*sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)/(sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top40pct_D_tinc-top20pct_D_tinc)/(sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc))))
	kincome_share4q = (sum(kincome_share*sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)/(sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top40pct_D_tinc-top20pct_D_tinc)/(sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc))))
	trans_share4q = (sum(trans_share*sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)/(sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top40pct_D_tinc-top20pct_D_tinc)/(sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc))))
	age_share4q = sum( age_share*sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)/(sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc))) )
!  40 - 60%		
	
	earning_share3q = (sum(earning_share*sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)/(sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top60pct_D_tinc-top40pct_D_tinc)/(sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc))))
	kincome_share3q = (sum(kincome_share*sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)/(sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top60pct_D_tinc-top40pct_D_tinc)/(sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc))))
	trans_share3q = (sum(trans_share*sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)/(sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top60pct_D_tinc-top40pct_D_tinc)/(sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc))))
	age_share3q = sum( age_share*sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)/(sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc))) )

!  20 - 40%		
	
	earning_share2q = (sum(earning_share*sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)/(sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top80pct_D_tinc-top60pct_D_tinc)/(sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc))))
	kincome_share2q = (sum(kincome_share*sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)/(sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top80pct_D_tinc-top60pct_D_tinc)/(sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc))))
	trans_share2q = (sum(trans_share*sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)/(sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top80pct_D_tinc-top60pct_D_tinc)/(sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc))))
	age_share2q = sum( age_share*sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)/(sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc))) )

!  0 - 20%		
	
	! earning_share1q = (sum(earning_share*sort_D_tinc*(1-top80pct_D_tinc)/(sum(sort_D_tinc*(1-top80pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(1-top80pct_D_tinc)/(sum(sort_D_tinc*(1-top80pct_D_tinc))))
	! kincome_share1q = (sum(kincome_share*sort_D_tinc*(1-top80pct_D_tinc)/(sum(sort_D_tinc*(1-top80pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(1-top80pct_D_tinc)/(sum(sort_D_tinc*(1-top80pct_D_tinc))))
	! trans_share1q = (sum(trans_share*sort_D_tinc*(1-top80pct_D_tinc)/(sum(sort_D_tinc*(1-top80pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(1-top80pct_D_tinc)/(sum(sort_D_tinc*(1-top80pct_D_tinc))))
	
	earning_share1q = (sum(earning_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))))
	kincome_share1q = (sum(kincome_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))))
	trans_share1q = (sum(trans_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))))
	age_share1q = sum( age_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))) )

! Bottom 5-10%	
	
	earning_share0510 = (sum(earning_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))))
	kincome_share0510 = (sum(kincome_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))))
	trans_share0510 = (sum(trans_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))))
	age_share0510 = sum( age_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))) )

	print*, 'earning_share0510=', earning_share0510
	print*, 'kincome_share0510=', kincome_share0510
	print*, 'trans_share0510=', trans_share0510
!	print*, 'sort_D*(top95pct_D_tinc-top90pct_D_tinc)/(sum(top95pct_D_tinc-top90pct_D_tinc))',sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))))

! Bottom 1-5%	
	
	earning_share0105 = (sum(earning_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))))
	kincome_share0105 = (sum(kincome_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))))
	trans_share0105 = (sum(trans_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))))
	age_share0105 = sum( age_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))) )

	print*, 'earning_share0105=', earning_share0105
	print*, 'kincome_share0105=', kincome_share0105
	print*, 'trans_share0105=', trans_share0105
	
!**********************************************************************************************************************
	
!	write(3,*) earning_share
!	write(3,*) totalincome
END SUBROUTINE
!***************************************************************************************
SUBROUTINE COMPARE_LITERATURE

! Kindermann and Krueger 2015

avg_earning_top025pct = sum( sort_inc*sort_D_inc*top025pct_D_inc/sum(sort_D_inc*top025pct_D_inc) )
earn_top025pct_median_ratio = avg_earning_top025pct/inc_median
print*, 'earn_top025pct_median_ratio=', earn_top025pct_median_ratio

avg_income_top025pct = sum( sort_tinc*sort_D_tinc*top025pct_D_tinc/sum(sort_D_tinc*top025pct_D_tinc) )
Inc_top025pct_median_ratio = avg_income_top025pct/tinc_median
print*, 'Inc_top025pct_median_ratio=', Inc_top025pct_median_ratio

! Castaneda et al. 2003
avg_earning_top0039pct = sum( sort_inc*sort_D_inc*top0039pct_D_inc/sum(sort_D_inc*top0039pct_D_inc) )
avg_earning_bot61pct = sum( sort_inc*sort_D_inc*(1-top39pct_D_inc)/sum(sort_D_inc*(1-top39pct_D_inc)) )
Inc_top0039pct_bot61pct_ratio = avg_earning_top0039pct/avg_earning_bot61pct
print*, 'Inc_top0039pct_bot61pct_ratio =', Inc_top0039pct_bot61pct_ratio

! "Earnings Inequality and Other Determinants of Wealth Inequality" Benhabib, Bisin, Luo 2016
! the ratio between even the top 0.01% and the median is at most of the order of 200 in the World Wealth and Income Database (WWID)
avg_earning_top001pct = sum( sort_inc*sort_D_inc*top001pct_D_inc/sum(sort_D_inc*top001pct_D_inc) )
earn_top001pct_median_ratio = avg_earning_top001pct/inc_median
print*, 'earn_top001pct_median_ratio=', earn_top001pct_median_ratio

! the top 0.1% are just about 34 times larger than the median.
avg_earning_top01pct = sum( sort_inc*sort_D_inc*top01pct_D_inc/sum(sort_D_inc*top01pct_D_inc) )
earn_top01pct_median_ratio = avg_earning_top01pct/inc_median
print*, 'earn_top01pct_median_ratio=', earn_top01pct_median_ratio

! the top 5% in WWID earns about 5 times the median
avg_earning_top5pct = sum( sort_inc*sort_D_inc*top5pct_D_inc/sum(sort_D_inc*top5pct_D_inc) )
earn_top5pct_median_ratio = avg_earning_top5pct/inc_median
print*, 'earn_top5pct_median_ratio=', earn_top5pct_median_ratio

END SUBROUTINE
!***************************************************************************************
SUBROUTINE saving_rate ! Emmanuel Saez and Gabriel Zucman 2016 Appendix Table B33
! Income includes realized capital gains and excludes government transfers
! Income is defined so as to match (pre-tax) national income in the national accounts.

! ALLOCATE ( synsaving((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE)*NGRIDA*NGRIDR) )
! ALLOCATE ( syn_totalincome((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE)*NGRIDA*NGRIDR) )

ALLOCATE( synsaving((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( syn_totalincome((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

! Single working age
state_pos_A = 0
DO AGE=2,RETAGE-1
    DO IA=1,NGRIDA        
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2   

				 state_pos_A = state_pos_A + 1
				 JA=singleIDCWA(AGE,IA,IS,IE,IG)
				 JN=singleIDCWN(AGE,IA,IS,IE,IG)			
				 !pre-tax income
				 !syn_totalincome(record_position_A(INT(state_pos_A))) = R(IR)*A(IA) + (1-STAX-MTAX)*WAGE*EFFLONG(AGE)*N(JN)*W(IS)+ ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)
				 syn_totalincome(record_position_A(INT(state_pos_A))) = R*A(IA) + WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)	! Income includes realized capital gains and excludes government transfers		
            	 synsaving(record_position_A(INT(state_pos_A))) = A(JA)-A(IA) 

				END DO 
			END DO
        END DO
    END DO
END DO

! Couple working age
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

				 state_pos_A = state_pos_A + 1
				 JA=coupleIDCWA(AGE,IA,IS1,IS2,IE)
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
				 INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)

				 syn_totalincome(record_position_A(INT(state_pos_A))) = R*A(IA) + INCOME	! Income includes realized capital gains and excludes government transfers		
            	 synsaving(record_position_A(INT(state_pos_A))) = A(JA)-A(IA)

				END DO 
            END DO
        END DO 
    END DO
END DO 


! Single retiree 
!DO AGE=RETAGE,MAXAGE-1
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IE = 1,NGRIDEH	
			DO IG=1,2               
			
             state_pos_A = state_pos_A + 1
			 JA=singleIDCRA(AGE,IA,IE,IG)
			 !syn_totalincome(record_position_A(INT(state_pos_A))) = R(IR)*A(IA) + SS + ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)
			 !syn_totalincome(record_position_A(INT(state_pos_A))) = R(IR)*A(IA) 
			 syn_totalincome(record_position_A(INT(state_pos_A))) = R*A(IA) + SS(IE)
             synsaving(record_position_A(INT(state_pos_A))) = A(JA)-A(IA) 

			END DO 
		END DO
    END DO
END DO

! couple retiree    
! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

		 state_pos_A = state_pos_A + 1
		 JA=coupleIDCRA(AGE,IA,IE)

		 syn_totalincome(record_position_A(INT(state_pos_A))) = R*A(IA) + 2*SS(IE)
         synsaving(record_position_A(INT(state_pos_A))) = A(JA)-A(IA) 

		END DO
    END DO
END DO    



! Average	
	synsaving_avg = sum( synsaving*sort_D )
	syn_totalincome_avg = sum(syn_totalincome*sort_D)
	synsavingrate_avg = synsaving_avg/syn_totalincome_avg 
	print*, 'synsavingrate_avg=', synsavingrate_avg

! Bottom 90%
	synsaving_bot90pct = sum( synsaving*sort_D*(1-top10pct_D)/(sum(sort_D*(1-top10pct_D))) )
	syn_totalincome_bot90pct = sum( syn_totalincome*sort_D*(1-top10pct_D)/(sum(sort_D*(1-top10pct_D))) )
	synsavingrate_bot90pct = synsaving_bot90pct/syn_totalincome_bot90pct
	 print*, 'synsavingrate_bot90pct=', synsavingrate_bot90pct
	
! Top 10%
	synsaving_10pct = sum( synsaving*sort_D*top10pct_D/(sum(sort_D*top10pct_D)) )
	syn_totalincome_10pct = sum( syn_totalincome*sort_D*top10pct_D/(sum(sort_D*top10pct_D)) )
	synsavingrate_10pct = synsaving_10pct/syn_totalincome_10pct
	print*, 'synsavingrate_10pct=', synsavingrate_10pct
	
! Top 5%
	synsaving_5pct = sum( synsaving*sort_D*top5pct_D/(sum(sort_D*top5pct_D)) )
	syn_totalincome_5pct = sum( syn_totalincome*sort_D*top5pct_D/(sum(sort_D*top5pct_D)) )
	synsavingrate_5pct = synsaving_5pct/syn_totalincome_5pct
	print*, 'synsavingrate_5pct=', synsavingrate_5pct
	
! Top 1%
	synsaving_1pct = sum( synsaving*sort_D*top1pct_D/(sum(sort_D*top1pct_D)) )
	syn_totalincome_1pct = sum( syn_totalincome*sort_D*top1pct_D/(sum(sort_D*top1pct_D)) )
	synsavingrate_1pct = synsaving_1pct/syn_totalincome_1pct
	print*, 'synsavingrate_1pct=', synsavingrate_1pct
	
! Top 0.1%
	synsaving_01pct = sum( synsaving*sort_D*top01pct_D/(sum(sort_D*top01pct_D)) )
	syn_totalincome_01pct = sum( syn_totalincome*sort_D*top01pct_D/(sum(sort_D*top01pct_D)) )
	synsavingrate_01pct = synsaving_01pct/syn_totalincome_01pct
	print*, 'synsavingrate_01pct=', synsavingrate_01pct
	
! Top 10-1%
	 synsaving_10_1pct = sum( synsaving*sort_D*(top10pct_D-top1pct_D)/(sum(sort_D*(top10pct_D-top1pct_D))) )
	 syn_totalincome_10_1pct = sum( syn_totalincome*sort_D*(top10pct_D-top1pct_D)/(sum(sort_D*(top10pct_D-top1pct_D))) )
	 synsavingrate_10_1pct = synsaving_10_1pct/syn_totalincome_10_1pct
	 print*, 'synsavingrate_10_1pct=', synsavingrate_10_1pct
 
! Top 10-5%
	 synsaving_10_5pct = sum( synsaving*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D))) )
	 syn_totalincome_10_5pct = sum( syn_totalincome*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D))) )
	 synsavingrate_10_5pct = synsaving_10_5pct/syn_totalincome_10_5pct
	 print*, 'synsavingrate_10_5pct=', synsavingrate_10_5pct
	 
! Top 5-1%
	 synsaving_5_1pct = sum( synsaving*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D))) )
	 syn_totalincome_5_1pct = sum( syn_totalincome*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D))) )
	 synsavingrate_5_1pct = synsaving_5_1pct/syn_totalincome_5_1pct
	 print*, 'synsavingrate_5_1pct=', synsavingrate_5_1pct
	 
! Top 1-0.1%
	 synsaving_1_01pct = sum( synsaving*sort_D*(top1pct_D-top01pct_D)/(sum(sort_D*(top1pct_D-top01pct_D))) )
	 syn_totalincome_1_01pct = sum( syn_totalincome*sort_D*(top1pct_D-top01pct_D)/(sum(sort_D*(top1pct_D-top01pct_D))) )
	 synsavingrate_1_01pct = synsaving_1_01pct/syn_totalincome_1_01pct
	 print*, 'synsavingrate_1_01pct=', synsavingrate_1_01pct
	

END SUBROUTINE
!***************************************************************************************
! SUBROUTINE bequest 

! ALLOCATE( sort_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( sort_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( cum_sort_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top1pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top2pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top5pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top10pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top20pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top30pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top40pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top50pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top60pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top70pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top80pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top90pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( box_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )

! ALLOCATE( sort_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( sort_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( cum_sort_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top1pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top2pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top5pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top10pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top20pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top30pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top40pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top50pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top60pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top70pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top80pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( top90pct_D_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( box_B_age52((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )

! ALLOCATE( record_position_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR))

! ! Sort the bequest distribution in ascending order
! isort=0
! DO AGE=1,RETAGE-1
!     !SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
!     DO IA=1,NGRIDA
! 		DO IR=1,NGRIDR
!             DO IS=1,nn                                   
                
!                 isort=isort+1
! 				JA=IDCWA(AGE,IA,IR,IS)                
!                 !sort_B(isort) = A(JA)*(1.0-SUR)
!                 sort_B(isort) = A(JA)
! 				sort_B_age52(isort) = A(JA)*(((1+Avg_R_weighted)**5.0)**(7-AGE))   !discounted to age 52 (Hendricks 2007)
                
!             END DO
!         END DO 
!     END DO
! END DO

! DO AGE=RETAGE,MAXAGE
!     !SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
!     DO IA=1,NGRIDA
! 		DO IR=1,NGRIDR
            
!             isort=isort+1
! 			JA=IDCRA(AGE,IA,IR)
!             !sort_B(isort) = A(JA)*(1.0-SUR)
!             sort_B(isort) = A(JA)
! 			sort_B_age52(isort) = A(JA)*(((1+Avg_R_weighted)**5.0)**(7-AGE))
            
!         END DO 
!     END DO
! END DO                

! CALL sorting(size(sort_B),sort_B) 
! CALL sorting(size(sort_B_age52),sort_B_age52) 

! DO i = 1,size(sort_B)
! 	box_B(i)= 0
! 	box_B_age52(i)=0
! END DO

! index_B = 0
! DO AGE=1,RETAGE-1
! SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
!     DO IA=1,NGRIDA
! 		DO IR=1,NGRIDR
!             DO IS=1,nn
!                index_B = index_B + 1
! 			   JA=IDCWA(AGE,IA,IR,IS)
!                i = search(A(JA), sort_B, box_B,1.D-4)
! 			   j = search(A(JA), sort_B_age52, box_B_age52,1.D-4)
! 				!sort_D_B(i) = D_YW(AGE,IA,IR,IS)*(1.0-S(AGE))
!                 !sort_D_B(i) = YW(AGE,IA,IR,IS)*(1-SUR)*MU(AGE)
! 				sort_D_B(i) = YW(AGE,IA,IR,IS)*(1-SUR)

! 				!sort_D_B_age52(j) = D_YW(AGE,IA,IR,IS)*(1.0-S(AGE))
! 				!sort_D_B_age52(j) = YW(AGE,IA,IR,IS)*(1.0-SUR)*MU(AGE)
! 				sort_D_B_age52(j) = YW(AGE,IA,IR,IS)*(1.0-SUR)

! 				record_position_B(index_B) = i
                
!             END DO
!         END DO
!     END DO
! END DO

! DO AGE=RETAGE,MAXAGE
! SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
!     DO IA=1,NGRIDA
! 		DO IR=1,NGRIDR
!             index_B = index_B + 1	
    
! 				JA=IDCRA(AGE,IA,IR)
!                 i = search(A(JA), sort_B, box_B,1.D-4)   
! 				j = search(A(JA), sort_B_age52, box_B_age52,1.D-4)
! 				!sort_D_B(i) = D_YR(AGE,IA,IR)*(1.0-S(AGE))
!                 !sort_D_B(i) = YR(AGE,IA,IR)*(1-SUR)*MU(AGE)
! 				sort_D_B(i) = YR(AGE,IA,IR)*(1-SUR)

! 				!sort_D_B_age52(j) = D_YR(AGE,IA,IR)*(1.0-S(AGE))
! 				!sort_D_B_age52(j) = YR(AGE,IA,IR)*(1.0-SUR)*MU(AGE)
! 				sort_D_B_age52(j) = YR(AGE,IA,IR)*(1.0-SUR)

! 				record_position_B(index_B) = i				
            
!         END DO
!     END DO
! END DO

! sort_D_B(:) = sort_D_B(:)/sum(sort_D_B)
! sort_D_B_age52(:) = sort_D_B_age52(:)/sum(sort_D_B_age52)

! cum_sort_D_B(1) = sort_D_B(1)
! DO i = 2,size(sort_D_B)
! 	cum_sort_D_B(i) = cum_sort_D_B(i-1)+sort_D_B(i)
! END DO
! print*, 'cum_sort_D_B=',cum_sort_D_B(size(sort_D_B))

! cum_sort_D_B_age52(1) = sort_D_B_age52(1)
! DO i = 2,size(sort_D_B_age52)
! 	cum_sort_D_B_age52(i) = cum_sort_D_B_age52(i-1)+sort_D_B_age52(i)
! END DO
! print*, 'cum_sort_D_B_age52=',cum_sort_D_B_age52(size(sort_D_B_age52))

! ! Identify wealth fractile agents
! DO i = 1,size(sort_D_B)
! 	top1pct_D_B(i) = 0
! 	top2pct_D_B(i) = 0
! 	top5pct_D_B(i) = 0
! 	top10pct_D_B(i) = 0
! 	top20pct_D_B(i) = 0
! 	top30pct_D_B(i) = 0
! 	top40pct_D_B(i) = 0
! 	top50pct_D_B(i) = 0
! 	top60pct_D_B(i) = 0
! 	top70pct_D_B(i) = 0
! 	top80pct_D_B(i) = 0
! 	top90pct_D_B(i) = 0

! 	top1pct_D_B_age52(i) = 0
! 	top2pct_D_B_age52(i) = 0
! 	top5pct_D_B_age52(i) = 0
! 	top10pct_D_B_age52(i) = 0
! 	top20pct_D_B_age52(i) = 0
! 	top30pct_D_B_age52(i) = 0
! 	top40pct_D_B_age52(i) = 0
! 	top50pct_D_B_age52(i) = 0
! 	top60pct_D_B_age52(i) = 0
! 	top70pct_D_B_age52(i) = 0
! 	top80pct_D_B_age52(i) = 0
! 	top90pct_D_B_age52(i) = 0
! END DO

! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.01 ) top1pct_D_B = 1
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.02 ) top2pct_D_B = 1
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.05 ) top5pct_D_B = 1
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.1 ) top10pct_D_B = 1 
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.2 ) top20pct_D_B = 1  
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.3 ) top30pct_D_B = 1
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.4 ) top40pct_D_B = 1 
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.5 ) top50pct_D_B = 1 
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.6 ) top60pct_D_B = 1
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.7 ) top70pct_D_B = 1 
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.8 ) top80pct_D_B = 1 
! where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.9 ) top90pct_D_B = 1   

! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.01 ) top1pct_D_B_age52 = 1
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.02 ) top2pct_D_B_age52 = 1
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.05 ) top5pct_D_B_age52 = 1
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.1 ) top10pct_D_B_age52 = 1 
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.2 ) top20pct_D_B_age52 = 1  
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.3 ) top30pct_D_B_age52 = 1
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.4 ) top40pct_D_B_age52 = 1 
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.5 ) top50pct_D_B_age52 = 1 
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.6 ) top60pct_D_B_age52 = 1
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.7 ) top70pct_D_B_age52 = 1 
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.8 ) top80pct_D_B_age52 = 1 
! where ( cum_sort_D_B_age52(1:size(sort_D_B_age52)) > 1-0.9 ) top90pct_D_B_age52 = 1        


! beq_pct98 = maxval(sort_B*(1-top2pct_D_B))
! beq_pct95 = maxval(sort_B*(1-top5pct_D_B))
! beq_pct90 = maxval(sort_B*(1-top10pct_D_B))
! beq_pct80 = maxval(sort_B*(1-top20pct_D_B))
! beq_pct70 = maxval(sort_B*(1-top30pct_D_B))
! beq_pct60 = maxval(sort_B*(1-top40pct_D_B))
! beq_pct50 = maxval(sort_B*(1-top50pct_D_B))
! beq_pct40 = maxval(sort_B*(1-top60pct_D_B))
! beq_pct30 = maxval(sort_B*(1-top70pct_D_B))
! beq_pct20 = maxval(sort_B*(1-top80pct_D_B))
! beq_pct10 = maxval(sort_B*(1-top90pct_D_B))
! print*,'beq_pct90=',beq_pct90


! beq_wealth_ratio = BEQEND/5.0/Aggwealth*100
! !beq_wealth_ratio = BEQEND/Aggwealth*100
! !beq_wealth_ratio = AggBeq/Aggwealth*100
! !beq_wealth_ratio = BEQEND/AEND*100

! !Beq90 = beq_pct90/syn_totalincome_avg
! Beq98 = beq_pct98/(syn_totalincome_avg/5.0)
! Beq95 = beq_pct95/(syn_totalincome_avg/5.0)
! Beq90 = beq_pct90/(syn_totalincome_avg/5.0)
! Beq80 = beq_pct80/(syn_totalincome_avg/5.0)
! Beq70 = beq_pct70/(syn_totalincome_avg/5.0)
! Beq60 = beq_pct60/(syn_totalincome_avg/5.0)
! Beq50 = beq_pct50/(syn_totalincome_avg/5.0)
! Beq40 = beq_pct40/(syn_totalincome_avg/5.0)
! Beq30 = beq_pct30/(syn_totalincome_avg/5.0)
! Beq20 = beq_pct20/(syn_totalincome_avg/5.0)
! Beq10 = beq_pct10/(syn_totalincome_avg/5.0)

! print*,'syn_totalincome_avg=',syn_totalincome_avg
! print*,'AEND=', AEND

! ! calculate percentile of the inheritance distribution (Hendricks 2007)
! AggBeq = dot_product(sort_B,sort_D_B)
! bshare99_100 = sum(sort_B*sort_D_B*top1pct_D_B)/AggBeq
! bshare95_99 = sum(sort_B*sort_D_B*(top5pct_D_B-top1pct_D_B))/AggBeq
! bshare90_95 = sum(sort_B*sort_D_B*(top10pct_D_B-top5pct_D_B))/AggBeq
! bshare80_90 = sum(sort_B*sort_D_B*(top20pct_D_B-top10pct_D_B))/AggBeq
! bshare70_80 = sum(sort_B*sort_D_B*(top30pct_D_B-top20pct_D_B))/AggBeq
! bshare50_70 = sum(sort_B*sort_D_B*(top50pct_D_B-top30pct_D_B))/AggBeq
! bshare0_50 = sum(sort_B*sort_D_B*(1-top50pct_D_B))/AggBeq
! beq_gini = gini(sort_B,sort_D_B)

! ! AggBeq52 = dot_product(sort_B_age52,sort_D_B_age52)
! ! bshare99_100 = sum(sort_B_age52*sort_D_B_age52*top1pct_D_B_age52)/AggBeq52
! ! bshare95_99 = sum(sort_B_age52*sort_D_B_age52*(top5pct_D_B_age52-top1pct_D_B_age52))/AggBeq52
! ! bshare90_95 = sum(sort_B_age52*sort_D_B_age52*(top10pct_D_B_age52-top5pct_D_B_age52))/AggBeq52
! ! bshare80_90 = sum(sort_B_age52*sort_D_B_age52*(top20pct_D_B_age52-top10pct_D_B_age52))/AggBeq52
! ! bshare70_80 = sum(sort_B_age52*sort_D_B_age52*(top30pct_D_B_age52-top20pct_D_B_age52))/AggBeq52
! ! bshare50_70 = sum(sort_B_age52*sort_D_B_age52*(top50pct_D_B_age52-top30pct_D_B_age52))/AggBeq52
! ! bshare0_50 = sum(sort_B_age52*sort_D_B_age52*(1-top50pct_D_B_age52))/AggBeq52
! ! beq_gini = gini(sort_B_age52,sort_D_B_age52)

! END SUBROUTINE
!***************************************************************************************
! SUBROUTINE joint_dist  

! ALLOCATE( sort_cons_Y((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( sort_wealth_Y((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
! ALLOCATE( sort_wealth_E((RETAGE-1)*NGRIDA*NGRIDR*nn) )


! state_pos=0
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA
! 		DO IR=1,NGRIDR
!             DO IS=1,nn                   
                
! 				state_pos = state_pos + 1
!                 JA=IDCWA(AGE,IA,IR,IS) 					
!                 sort_wealth_Y(record_position_tinc(INT(state_pos))) = A(JA)		! wealth share by income 						
! 				sort_wealth_E(record_position_E(INT(state_pos))) = A(JA)		! wealth share by earnings 
! 				sort_cons_Y(record_position_tinc(INT(state_pos))) = IDCWC(AGE,IA,IR,IS)	 ! consumption share by income
!             END DO
!         END DO 
!     END DO
! END DO

! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA        
! 		DO IR=1,NGRIDR                 
			
!             state_pos = state_pos + 1
! 			JA=IDCRA(AGE,IA,IR) 
			
! 			sort_wealth_Y(record_position_tinc(INT(state_pos))) = A(JA)									
! 			!sort_wealth_E(record_position_E(INT(state_pos))) = A(JA)
! 			sort_cons_Y(record_position_tinc(INT(state_pos))) = IDCRC(AGE,IA,IR)
            
! 		END DO
!     END DO
! END DO

! 	kshare_E0001 = sum(sort_wealth_E*sort_D_inc*top0001pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E0005 = sum(sort_wealth_E*sort_D_inc*top0005pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E001 = sum(sort_wealth_E*sort_D_inc*top001pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E01 = sum(sort_wealth_E*sort_D_inc*top01pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E05 = sum(sort_wealth_E*sort_D_inc*top05pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E1 = sum(sort_wealth_E*sort_D_inc*top1pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E5 = sum(sort_wealth_E*sort_D_inc*top5pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E10 = sum(sort_wealth_E*sort_D_inc*top10pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E20 = sum(sort_wealth_E*sort_D_inc*top20pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E40 = sum(sort_wealth_E*sort_D_inc*top40pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E60 = sum(sort_wealth_E*sort_D_inc*top60pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
! 	kshare_E80 = sum(sort_wealth_E*sort_D_inc*top80pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)

! 	klevel_E0001 = sum(sort_wealth_E*sort_D_inc*top0001pct_D_inc)
! 	klevel_E0005 = sum(sort_wealth_E*sort_D_inc*top0005pct_D_inc)
! 	klevel_E001 = sum(sort_wealth_E*sort_D_inc*top001pct_D_inc)
! 	klevel_E01 = sum(sort_wealth_E*sort_D_inc*top01pct_D_inc)
! 	klevel_E05 = sum(sort_wealth_E*sort_D_inc*top05pct_D_inc)
! 	klevel_E1 = sum(sort_wealth_E*sort_D_inc*top1pct_D_inc)
! 	klevel_E5 = sum(sort_wealth_E*sort_D_inc*top5pct_D_inc)
! 	klevel_E10 = sum(sort_wealth_E*sort_D_inc*top10pct_D_inc)
! 	klevel_E20 = sum(sort_wealth_E*sort_D_inc*top20pct_D_inc)
! 	klevel_E40 = sum(sort_wealth_E*sort_D_inc*top40pct_D_inc)
! 	klevel_E60 = sum(sort_wealth_E*sort_D_inc*top60pct_D_inc)
! 	klevel_E80 = sum(sort_wealth_E*sort_D_inc*top80pct_D_inc)

! 	kshare_Y0001 = sum(sort_wealth_Y*sort_D_tinc*top0001pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y0005 = sum(sort_wealth_Y*sort_D_tinc*top0005pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y001 = sum(sort_wealth_Y*sort_D_tinc*top001pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y01 = sum(sort_wealth_Y*sort_D_tinc*top01pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y05 = sum(sort_wealth_Y*sort_D_tinc*top05pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y1 = sum(sort_wealth_Y*sort_D_tinc*top1pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y5 = sum(sort_wealth_Y*sort_D_tinc*top5pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y10 = sum(sort_wealth_Y*sort_D_tinc*top10pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y20 = sum(sort_wealth_Y*sort_D_tinc*top20pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y40 = sum(sort_wealth_Y*sort_D_tinc*top40pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y60 = sum(sort_wealth_Y*sort_D_tinc*top60pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
! 	kshare_Y80 = sum(sort_wealth_Y*sort_D_tinc*top80pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)

! 	klevel_Y0001 = ( sum(sort_wealth_Y*sort_D_tinc*top0001pct_D_tinc)/sum(sort_D_tinc*top0001pct_D_tinc) )/Aggwealth
! 	klevel_Y0005 = ( sum(sort_wealth_Y*sort_D_tinc*top0005pct_D_tinc)/sum(sort_D_tinc*top0005pct_D_tinc) )/Aggwealth
! 	klevel_Y001 = ( sum(sort_wealth_Y*sort_D_tinc*top001pct_D_tinc)/sum(sort_D_tinc*top001pct_D_tinc) )/Aggwealth
! 	klevel_Y01 = ( sum(sort_wealth_Y*sort_D_tinc*top01pct_D_tinc)/sum(sort_D_tinc*top01pct_D_tinc) )/Aggwealth
! 	klevel_Y05 = ( sum(sort_wealth_Y*sort_D_tinc*top05pct_D_tinc)/sum(sort_D_tinc*top05pct_D_tinc) )/Aggwealth
! 	klevel_Y1 = ( sum(sort_wealth_Y*sort_D_tinc*top1pct_D_tinc)/sum(sort_D_tinc*top1pct_D_tinc) )/Aggwealth
! 	klevel_Y5 = ( sum(sort_wealth_Y*sort_D_tinc*top5pct_D_tinc)/sum(sort_D_tinc*top5pct_D_tinc) )/Aggwealth
! 	klevel_Y10 = ( sum(sort_wealth_Y*sort_D_tinc*top10pct_D_tinc)/sum(sort_D_tinc*top10pct_D_tinc) )/Aggwealth
! 	klevel_Y20 = ( sum(sort_wealth_Y*sort_D_tinc*top20pct_D_tinc)/sum(sort_D_tinc*top20pct_D_tinc) )/Aggwealth
! 	klevel_Y40 = ( sum(sort_wealth_Y*sort_D_tinc*top40pct_D_tinc)/sum(sort_D_tinc*top40pct_D_tinc) )/Aggwealth
! 	klevel_Y60 = ( sum(sort_wealth_Y*sort_D_tinc*top60pct_D_tinc)/sum(sort_D_tinc*top60pct_D_tinc) )/Aggwealth
! 	klevel_Y80 = ( sum(sort_wealth_Y*sort_D_tinc*top80pct_D_tinc)/sum(sort_D_tinc*top80pct_D_tinc) )/Aggwealth
! 	klevel_Y9599 = ( sum(sort_wealth_Y*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))/sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)) )/Aggwealth
! 	klevel_Y9095 = ( sum(sort_wealth_Y*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))/sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)) )/Aggwealth
! 	klevel_Y6080 = ( sum(sort_wealth_Y*sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc))/sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)) )/Aggwealth
! 	klevel_Y4060 = ( sum(sort_wealth_Y*sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc))/sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)) )/Aggwealth
! 	klevel_Y2040 = ( sum(sort_wealth_Y*sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc))/sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)) )/Aggwealth
	
! 	cshare_tinc0001 = sum(sort_cons_Y*sort_D_tinc*top0001pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc0005 = sum(sort_cons_Y*sort_D_tinc*top0005pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc001 = sum(sort_cons_Y*sort_D_tinc*top001pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc01 = sum(sort_cons_Y*sort_D_tinc*top01pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc05 = sum(sort_cons_Y*sort_D_tinc*top05pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc1 = sum(sort_cons_Y*sort_D_tinc*top1pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc5 = sum(sort_cons_Y*sort_D_tinc*top5pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc10 = sum(sort_cons_Y*sort_D_tinc*top10pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc20 = sum(sort_cons_Y*sort_D_tinc*top20pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc40 = sum(sort_cons_Y*sort_D_tinc*top40pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc60 = sum(sort_cons_Y*sort_D_tinc*top60pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
! 	cshare_tinc80 = sum(sort_cons_Y*sort_D_tinc*top80pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	
! END SUBROUTINE
!***************************************************************************************
SUBROUTINE tax_moment

ALLOCATE( sort_ATY((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( sort_ATC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( temp_sort_ATY((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( temp_sort_ATC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
!ALLOCATE( sort_noncorpY((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
!ALLOCATE( MTR((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

	
	! G_share = (gov*OUTPUT + PIA_factor*SSEXP + flat_transf_rate*OUTPUT)/OUTPUT
	G_share = (gov_exp*OUTPUT + SSEXP + flat_transf_rate*OUTPUT + medicare_rate*OUTPUT)/OUTPUT

! ATY1: Income tax target
ATY_tax_single = 0.0
ATY_taxableincome_single = 0.0
ATY_tax_couple = 0.0
ATY_taxableincome_couple = 0.0

ATY_tax_single_Q5 = 0.0
ATY_tax_single_Q4 = 0.0
ATY_tax_single_Q3 = 0.0
ATY_tax_single_Q2 = 0.0
ATY_tax_single_Q1 = 0.0
ATY_tax_single_b10 = 0.0
ATY_tax_single_b9 = 0.0
ATY_tax_single_b8 = 0.0
ATY_tax_single_b7 = 0.0
ATY_tax_single_b6 = 0.0
ATY_tax_single_b5 = 0.0
ATY_tax_single_b4 = 0.0
ATY_tax_single_b3 = 0.0
ATY_tax_single_b2 = 0.0
ATY_tax_single_b1 = 0.0
ATY_taxableincome_single_Q5 = 0.0
ATY_taxableincome_single_Q4 = 0.0
ATY_taxableincome_single_Q3 = 0.0
ATY_taxableincome_single_Q2 = 0.0
ATY_taxableincome_single_Q1 = 0.0
ATY_taxableincome_single_b10 = 0.0
ATY_taxableincome_single_b9 = 0.0
ATY_taxableincome_single_b8 = 0.0
ATY_taxableincome_single_b7 = 0.0
ATY_taxableincome_single_b6 = 0.0
ATY_taxableincome_single_b5 = 0.0
ATY_taxableincome_single_b4 = 0.0
ATY_taxableincome_single_b3 = 0.0
ATY_taxableincome_single_b2 = 0.0
ATY_taxableincome_single_b1 = 0.0

ATY_tax_couple_Q5 = 0.0
ATY_tax_couple_Q4 = 0.0
ATY_tax_couple_Q3 = 0.0
ATY_tax_couple_Q2 = 0.0
ATY_tax_couple_Q1 = 0.0
ATY_tax_couple_b10 = 0.0
ATY_tax_couple_b9 = 0.0
ATY_tax_couple_b8 = 0.0
ATY_tax_couple_b7 = 0.0
ATY_tax_couple_b6 = 0.0
ATY_tax_couple_b5 = 0.0
ATY_tax_couple_b4 = 0.0
ATY_tax_couple_b3 = 0.0
ATY_tax_couple_b2 = 0.0
ATY_tax_couple_b1 = 0.0
ATY_taxableincome_couple_Q5 = 0.0
ATY_taxableincome_couple_Q4 = 0.0
ATY_taxableincome_couple_Q3 = 0.0
ATY_taxableincome_couple_Q2 = 0.0
ATY_taxableincome_couple_Q1 = 0.0
ATY_taxableincome_couple_b10 = 0.0
ATY_taxableincome_couple_b9 = 0.0
ATY_taxableincome_couple_b8 = 0.0
ATY_taxableincome_couple_b7 = 0.0
ATY_taxableincome_couple_b6 = 0.0
ATY_taxableincome_couple_b5 = 0.0
ATY_taxableincome_couple_b4 = 0.0
ATY_taxableincome_couple_b3 = 0.0
ATY_taxableincome_couple_b2 = 0.0
ATY_taxableincome_couple_b1 = 0.0

single_Y_b10 = 0.0
single_Y_b9 = 0.0
single_Y_b8 = 0.0
single_Y_b7 = 0.0
single_Y_b6 = 0.0
single_Y_b5 = 0.0
single_Y_b4 = 0.0
single_Y_b3 = 0.0
single_Y_b2 = 0.0
single_Y_b1 = 0.0

couple_Y_b10 = 0.0
couple_Y_b9 = 0.0
couple_Y_b8 = 0.0
couple_Y_b7 = 0.0
couple_Y_b6 = 0.0
couple_Y_b5 = 0.0
couple_Y_b4 = 0.0
couple_Y_b3 = 0.0
couple_Y_b2 = 0.0
couple_Y_b1 = 0.0

! Single working age
state_pos=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
        DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2                 
                
				 state_pos = state_pos + 1
                 JN=singleIDCWN(AGE,IA,IS,IE,IG) 		
				 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
				 taxable_income = max(0.0,min(R*A(IA),d_c)) + INCOME

				 ! income tax paid only on non-corporate capital income and labor income				
                !  sort_ATY(state_pos) = taxable_income &
				! 					- taxable_income*lambda * (MIN(singlebendy,taxable_income/avg_earnings))**(-tau_l_single) & 
				! 					- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - singlebendy)

				sort_ATY(state_pos) = avg_earnings*MIN(singlebendy,taxable_income/avg_earnings)*(1.0 - lambda*(MIN(singlebendy,taxable_income/avg_earnings))**(-tau_l_single)) &
										+ avg_earnings*ty_max*MAX(0.0,taxable_income/avg_earnings - singlebendy)
										
				 sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)
				 
				 ATY_tax_single = ATY_tax_single + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
				 ATY_taxableincome_single = ATY_taxableincome_single + taxable_income*singleYW(AGE,IA,IS,IE,IG)
				 ! sort_noncorpY(record_position_tinc(INT(state_pos))) = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS) + min(R*A(IA),d_c)

				 ! ATY by income quintile
				 IF (taxable_income >= incomethreshold20) THEN 
					ATY_tax_single_Q5 = ATY_tax_single_Q5 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_Q5 = ATY_taxableincome_single_Q5 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold20)) THEN 
				 	ATY_tax_single_Q4 = ATY_tax_single_Q4 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_Q4 = ATY_taxableincome_single_Q4 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold40)) THEN 
				 	ATY_tax_single_Q3 = ATY_tax_single_Q3 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_Q3 = ATY_taxableincome_single_Q3 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold60)) THEN 
				 	ATY_tax_single_Q2 = ATY_tax_single_Q2 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_Q2 = ATY_taxableincome_single_Q2 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF (taxable_income < incomethreshold80) THEN 
				 	ATY_tax_single_Q1 = ATY_tax_single_Q1 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_Q1 = ATY_taxableincome_single_Q1 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
				 END IF 

				 IF (taxable_income >= incomethreshold10) THEN 
					ATY_tax_single_b10 = ATY_tax_single_b10 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b10 = ATY_taxableincome_single_b10 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b10 = single_Y_b10 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold20) .AND. (taxable_income < incomethreshold10)) THEN 
				 	ATY_tax_single_b9 = ATY_tax_single_b9 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b9 = ATY_taxableincome_single_b9 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b9 = single_Y_b9 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold30) .AND. (taxable_income < incomethreshold20)) THEN 
				 	ATY_tax_single_b8 = ATY_tax_single_b8 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b8 = ATY_taxableincome_single_b8 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b8 = single_Y_b8 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold30)) THEN 
				 	ATY_tax_single_b7 = ATY_tax_single_b7 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b7 = ATY_taxableincome_single_b7 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b7 = single_Y_b7 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold50) .AND. (taxable_income < incomethreshold40)) THEN 
				 	ATY_tax_single_b6 = ATY_tax_single_b6 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b6 = ATY_taxableincome_single_b6 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b6 = single_Y_b6 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold50)) THEN 
				 	ATY_tax_single_b5 = ATY_tax_single_b5 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b5 = ATY_taxableincome_single_b5 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b5 = single_Y_b5 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold70) .AND. (taxable_income < incomethreshold60)) THEN 
				 	ATY_tax_single_b4 = ATY_tax_single_b4 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b4 = ATY_taxableincome_single_b4 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b4 = single_Y_b4 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold70)) THEN 
				 	ATY_tax_single_b3 = ATY_tax_single_b3 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b3 = ATY_taxableincome_single_b3 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b3 = single_Y_b3 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold90) .AND. (taxable_income < incomethreshold80)) THEN 
				 	ATY_tax_single_b2 = ATY_tax_single_b2 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b2 = ATY_taxableincome_single_b2 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b2 = single_Y_b2 + singleYW(AGE,IA,IS,IE,IG)
				 ELSEIF (taxable_income < incomethreshold90) THEN 
				 	ATY_tax_single_b1 = ATY_tax_single_b1 + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
					ATY_taxableincome_single_b1 = ATY_taxableincome_single_b1 + taxable_income*singleYW(AGE,IA,IS,IE,IG)
					single_Y_b1 = single_Y_b1 + singleYW(AGE,IA,IS,IE,IG)
				 END IF

				END DO 
            END DO
        END DO 
    END DO
END DO

! Single retiree
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
        DO IE = 1,NGRIDEH	
			DO IG=1,2  
            
             state_pos=state_pos+1
			 INCOME = SS(IE)
			 TINCOME = R*A(IA) + INCOME
			 taxable_income = max(0.0,min(R*A(IA),d_c) + INCOME)
			
			!  sort_ATY(state_pos) = taxable_income &
			! 						- taxable_income*lambda * (MIN(singlebendy,taxable_income/avg_earnings))**(-tau_l_single) & 
			! 						- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - singlebendy)	

			sort_ATY(state_pos) = avg_earnings*MIN(singlebendy,taxable_income/avg_earnings)*(1.0 - lambda*(MIN(singlebendy,taxable_income/avg_earnings))**(-tau_l_single)) & 									
								  + avg_earnings*ty_max*MAX(0.0,taxable_income/avg_earnings - singlebendy)		

			 sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)	

			 !sort_noncorpY(record_position_tinc(INT(state_pos))) = SS + min(R(IR)*A(IA),d_c)	
			 ATY_tax_single = ATY_tax_single + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
			 ATY_taxableincome_single = ATY_taxableincome_single + taxable_income*singleYR(AGE,IA,IE,IG)

			 ! ATY by income quintile
				 IF (taxable_income >= incomethreshold20) THEN  
					ATY_tax_single_Q5 = ATY_tax_single_Q5 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_Q5 = ATY_taxableincome_single_Q5 + taxable_income*singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold20)) THEN 
				 	ATY_tax_single_Q4 = ATY_tax_single_Q4 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_Q4 = ATY_taxableincome_single_Q4 + taxable_income*singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold40)) THEN 
				 	ATY_tax_single_Q3 = ATY_tax_single_Q3 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_Q3 = ATY_taxableincome_single_Q3 + taxable_income*singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold60)) THEN
				 	ATY_tax_single_Q2 = ATY_tax_single_Q2 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_Q2 = ATY_taxableincome_single_Q2 + taxable_income*singleYR(AGE,IA,IE,IG)
				 ELSEIF (taxable_income < incomethreshold80) THEN
				 	ATY_tax_single_Q1 = ATY_tax_single_Q1 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_Q1 = ATY_taxableincome_single_Q1 + taxable_income*singleYR(AGE,IA,IE,IG)
				 END IF 

				 IF (taxable_income >= incomethreshold10) THEN 
					ATY_tax_single_b10 = ATY_tax_single_b10 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b10 = ATY_taxableincome_single_b10 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b10 = single_Y_b10 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold20) .AND. (taxable_income < incomethreshold10)) THEN 
				 	ATY_tax_single_b9 = ATY_tax_single_b9 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b9 = ATY_taxableincome_single_b9 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b9 = single_Y_b9 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold30) .AND. (taxable_income < incomethreshold20)) THEN 
				 	ATY_tax_single_b8 = ATY_tax_single_b8 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b8 = ATY_taxableincome_single_b8 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b8 = single_Y_b8 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold30)) THEN 
				 	ATY_tax_single_b7 = ATY_tax_single_b7 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b7 = ATY_taxableincome_single_b7 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b7 = single_Y_b7 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold50) .AND. (taxable_income < incomethreshold40)) THEN 
				 	ATY_tax_single_b6 = ATY_tax_single_b6 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b6 = ATY_taxableincome_single_b6 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b6 = single_Y_b6 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold50)) THEN 
				 	ATY_tax_single_b5 = ATY_tax_single_b5 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b5 = ATY_taxableincome_single_b5 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b5 = single_Y_b5 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold70) .AND. (taxable_income < incomethreshold60)) THEN 
				 	ATY_tax_single_b4 = ATY_tax_single_b4 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b4 = ATY_taxableincome_single_b4 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b4 = single_Y_b4 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold70)) THEN 
				 	ATY_tax_single_b3 = ATY_tax_single_b3 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b3 = ATY_taxableincome_single_b3 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b3 = single_Y_b3 + singleYR(AGE,IA,IE,IG)
				 ELSEIF ((taxable_income >= incomethreshold90) .AND. (taxable_income < incomethreshold80)) THEN 
				 	ATY_tax_single_b2 = ATY_tax_single_b2 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b2 = ATY_taxableincome_single_b2 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b2 = single_Y_b2 + singleYR(AGE,IA,IE,IG)
				 ELSEIF (taxable_income < incomethreshold90) THEN 
				 	ATY_tax_single_b1 = ATY_tax_single_b1 + sort_ATY(state_pos)*singleYR(AGE,IA,IE,IG)
					ATY_taxableincome_single_b1 = ATY_taxableincome_single_b1 + taxable_income*singleYR(AGE,IA,IE,IG)
					single_Y_b1 = single_Y_b1 + singleYR(AGE,IA,IE,IG)
				 END IF

            END DO 
        END DO 
    END DO
END DO 

! Couple working age
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

				 state_pos = state_pos + 1
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

				INCOME = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)
				INCOME1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + min(R*A(IA),d_c)/2
				INCOME2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)/2
				tax_MFS = INCOME1+INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA))			
				taxable_income = max(0.0,min(R*A(IA),d_c))+ WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)

				 ! income tax paid only on non-corporate capital income and labor income
				IF (yd_MFJ(INCOME1 + INCOME2 , IA) >= yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
					IF(GBC_method==0) THEN  		!cleared by lambda	
						! sort_ATY(state_pos) = taxable_income - taxable_income*lambda*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
						! 												 - avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)	
						sort_ATY(state_pos) = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings )*(1.0 - lambda*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings))**(-tau_l_couple)) &
											 + avg_earnings*ty_max*MAX(0.0,taxable_income/avg_earnings - couplebendy)	
						
					ELSE	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
						! sort_ATY(state_pos) = taxable_income - taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
						! 												- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)	
						sort_ATY(state_pos) = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings)*(1.0 - lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings))**(-tau_l_couple)) &
											+ avg_earnings*ty_max*MAX(0.0,taxable_income/avg_earnings - couplebendy)	
								 
					END IF
				ELSEIF (yd_MFJ(INCOME1 + INCOME2 , IA) < yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 

					! IF (ty_max_restriction == 1) THEN
					! 	IF (tau_l_single>0.0) THEN 
					! 		MFSbendy=((1.0-tau_l_single)*lambda*weight_MFS/(1.0-ty_max))**(1.0/tau_l_single) 
					! 	ELSE 
					! 		MFSbendy=1.E7 
					! 	END IF
					! ELSEIF (ty_max_restriction == 0) THEN
					! 	bendy=1.E7 
					! END IF

					IF(GBC_method==0) THEN 						
						! sort_ATY(state_pos) = INCOME1 - INCOME1*lambda*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
						! 											   + INCOME2 - INCOME2*lambda*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)
						sort_ATY(state_pos) = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*(1.0 - lambda*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
											+ avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*(1.0 - lambda*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME2/avg_earnings - MFSbendy)	
						
					ELSE					
						! sort_ATY(state_pos) = INCOME1 - INCOME1*lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
						! 										       + INCOME2 - INCOME2*lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)
						sort_ATY(state_pos) = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*(1.0 - lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
											+ avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*(1.0 - lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME2/avg_earnings - MFSbendy)
						
					END IF  

				END IF 	

				 sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)

				 ATY_tax_couple = ATY_tax_couple + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
				 ATY_taxableincome_couple = ATY_taxableincome_couple + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)

				 ! ATY by income quintile
				 IF (taxable_income >= incomethreshold20) THEN 
					ATY_tax_couple_Q5 = ATY_tax_couple_Q5 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_Q5 = ATY_taxableincome_couple_Q5 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold20)) THEN 
				 	ATY_tax_couple_Q4 = ATY_tax_couple_Q4 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_Q4 = ATY_taxableincome_couple_Q4 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold40)) THEN 
				 	ATY_tax_couple_Q3 = ATY_tax_couple_Q3 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_Q3 = ATY_taxableincome_couple_Q3 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold60)) THEN 
				 	ATY_tax_couple_Q2 = ATY_tax_couple_Q2 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_Q2 = ATY_taxableincome_couple_Q2 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF (taxable_income < incomethreshold80) THEN
				 	ATY_tax_couple_Q1 = ATY_tax_couple_Q1 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_Q1 = ATY_taxableincome_couple_Q1 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
				 END IF 

				 IF (taxable_income >= incomethreshold10) THEN 
					ATY_tax_couple_b10 = ATY_tax_couple_b10 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b10 = ATY_taxableincome_couple_b10 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b10 = couple_Y_b10 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold20) .AND. (taxable_income < incomethreshold10)) THEN 
				 	ATY_tax_couple_b9 = ATY_tax_couple_b9 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b9 = ATY_taxableincome_couple_b9 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b9 = couple_Y_b9 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold30) .AND. (taxable_income < incomethreshold20)) THEN 
				 	ATY_tax_couple_b8 = ATY_tax_couple_b8 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b8 = ATY_taxableincome_couple_b8 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b8 = couple_Y_b8 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold30)) THEN 
				 	ATY_tax_couple_b7 = ATY_tax_couple_b7 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b7 = ATY_taxableincome_couple_b7 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b7 = couple_Y_b7 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold50) .AND. (taxable_income < incomethreshold40)) THEN 
				 	ATY_tax_couple_b6 = ATY_tax_couple_b6 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b6 = ATY_taxableincome_couple_b6 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b6 = couple_Y_b6 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold50)) THEN 
				 	ATY_tax_couple_b5 = ATY_tax_couple_b5 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b5 = ATY_taxableincome_couple_b5 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b5 = couple_Y_b5 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold70) .AND. (taxable_income < incomethreshold60)) THEN 
				 	ATY_tax_couple_b4 = ATY_tax_couple_b4 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b4 = ATY_taxableincome_couple_b4 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b4 = couple_Y_b4 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold70)) THEN 
				 	ATY_tax_couple_b3 = ATY_tax_couple_b3 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b3 = ATY_taxableincome_couple_b3 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b3 = couple_Y_b3 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF ((taxable_income >= incomethreshold90) .AND. (taxable_income < incomethreshold80)) THEN 
				 	ATY_tax_couple_b2 = ATY_tax_couple_b2 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b2 = ATY_taxableincome_couple_b2 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b2 = couple_Y_b2 + coupleYW(AGE,IA,IS1,IS2,IE)
				 ELSEIF (taxable_income < incomethreshold90) THEN 
				 	ATY_tax_couple_b1 = ATY_tax_couple_b1 + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
					ATY_taxableincome_couple_b1 = ATY_taxableincome_couple_b1 + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)
					couple_Y_b1 = couple_Y_b1 + coupleYW(AGE,IA,IS1,IS2,IE)
				 END IF

				END DO 
            END DO
        END DO 
    END DO
END DO 


! couple retiree    
! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

		 state_pos=state_pos+1
		 
		 INCOME1 = SS(IE) + min(R*A(IA),d_c)/2
		 INCOME2 = SS(IE) + min(R*A(IA),d_c)/2
		 INCOME = INCOME1+INCOME2
		 tax_MFS = INCOME1+INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA))		
		 taxable_income = INCOME

		  ! income tax paid only on non-corporate capital income and labor income
			IF (yd_MFJ(INCOME1 + INCOME2 , IA) >= yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
				IF(GBC_method==0) THEN  		!cleared by lambda	
					! sort_ATY(state_pos) = taxable_income - taxable_income*lambda*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
					! 													- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)
					sort_ATY(state_pos) = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings)*(1.0 - lambda*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple)) &
										+ avg_earnings*ty_max*MAX(0.0,taxable_income/avg_earnings - couplebendy)	
					
				ELSE	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
					! sort_ATY(state_pos) = taxable_income - taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
					! 												- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)
					sort_ATY(state_pos) = avg_earnings*MIN(couplebendy, taxable_income/avg_earnings)*(1.0 - lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple)) &
										+ avg_earnings*ty_max*MAX(0.0,taxable_income/avg_earnings - couplebendy)		 
					
				END IF
			ELSE

				! IF (ty_max_restriction == 1) THEN
				! 	IF (tau_l_single>0.0) THEN 
				! 		MFSbendy=((1.0-tau_l_single)*lambda*weight_MFS/(1.0-ty_max))**(1.0/tau_l_single) 
				! 	ELSE 
				! 		MFSbendy=1.E7 
				! 	END IF
				! ELSEIF (ty_max_restriction == 0) THEN
				! 	MFSbendy=1.E7 
				! END IF

				IF(GBC_method==0) THEN 						
					! sort_ATY(state_pos) = INCOME1 - INCOME1*lambda*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
					! 												+ INCOME2 - INCOME2*lambda*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)	
					sort_ATY(state_pos) = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*(1.0 - lambda*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
										+ avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*(1.0 - lambda*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME2/avg_earnings - MFSbendy)	
						
				ELSE					
					! sort_ATY(state_pos) = INCOME1 - INCOME1*lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
					! 												+ INCOME2 - INCOME2*lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)
					sort_ATY(state_pos) = avg_earnings*MIN(MFSbendy,INCOME1/avg_earnings)*(1.0 - lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
										+ avg_earnings*MIN(MFSbendy,INCOME2/avg_earnings)*(1.0 - lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple)) + avg_earnings*ty_max*MAX(0.0,INCOME2/avg_earnings - MFSbendy)
					
				END IF  

			END IF 		

		 sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)

		 ATY_tax_couple = ATY_tax_couple + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
		 ATY_taxableincome_couple = ATY_taxableincome_couple + taxable_income*coupleYR(AGE,IA,IE)

		 ! ATY by income quintile
			IF (taxable_income >= incomethreshold20) THEN 
				ATY_tax_couple_Q5 = ATY_tax_couple_Q5 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_Q5 = ATY_taxableincome_couple_Q5 + taxable_income*coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold20)) THEN  
				ATY_tax_couple_Q4 = ATY_tax_couple_Q4 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_Q4 = ATY_taxableincome_couple_Q4 + taxable_income*coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold40)) THEN 
				ATY_tax_couple_Q3 = ATY_tax_couple_Q3 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_Q3 = ATY_taxableincome_couple_Q3 + taxable_income*coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold60)) THEN 
				ATY_tax_couple_Q2 = ATY_tax_couple_Q2 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_Q2 = ATY_taxableincome_couple_Q2 + taxable_income*coupleYR(AGE,IA,IE)
			ELSEIF (taxable_income < incomethreshold80) THEN 
				ATY_tax_couple_Q1 = ATY_tax_couple_Q1 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_Q1 = ATY_taxableincome_couple_Q1 + taxable_income*coupleYR(AGE,IA,IE)
			END IF 


			IF (taxable_income >= incomethreshold10) THEN 
				ATY_tax_couple_b10 = ATY_tax_couple_b10 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b10 = ATY_taxableincome_couple_b10 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b10 = couple_Y_b10 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold20) .AND. (taxable_income < incomethreshold10)) THEN 
				ATY_tax_couple_b9 = ATY_tax_couple_b9 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b9 = ATY_taxableincome_couple_b9 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b9 = couple_Y_b9 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold30) .AND. (taxable_income < incomethreshold20)) THEN 
				ATY_tax_couple_b8 = ATY_tax_couple_b8 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b8 = ATY_taxableincome_couple_b8 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b8 = couple_Y_b8 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold40) .AND. (taxable_income < incomethreshold30)) THEN 
				ATY_tax_couple_b7 = ATY_tax_couple_b7 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b7 = ATY_taxableincome_couple_b7 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b7 = couple_Y_b7 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold50) .AND. (taxable_income < incomethreshold40)) THEN 
				ATY_tax_couple_b6 = ATY_tax_couple_b6 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b6 = ATY_taxableincome_couple_b6 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b6 = couple_Y_b6 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold60) .AND. (taxable_income < incomethreshold50)) THEN 
				ATY_tax_couple_b5 = ATY_tax_couple_b5 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b5 = ATY_taxableincome_couple_b5 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b5 = couple_Y_b5 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold70) .AND. (taxable_income < incomethreshold60)) THEN 
				ATY_tax_couple_b4 = ATY_tax_couple_b4 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b4 = ATY_taxableincome_couple_b4 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b4 = couple_Y_b4 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold80) .AND. (taxable_income < incomethreshold70)) THEN 
				ATY_tax_couple_b3 = ATY_tax_couple_b3 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b3 = ATY_taxableincome_couple_b3 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b3 = couple_Y_b3 + coupleYR(AGE,IA,IE)
			ELSEIF ((taxable_income >= incomethreshold90) .AND. (taxable_income < incomethreshold80)) THEN 
				ATY_tax_couple_b2 = ATY_tax_couple_b2 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b2 = ATY_taxableincome_couple_b2 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b2 = couple_Y_b2 + coupleYR(AGE,IA,IE)
			ELSEIF (taxable_income < incomethreshold90) THEN 
				ATY_tax_couple_b1 = ATY_tax_couple_b1 + sort_ATY(state_pos)*coupleYR(AGE,IA,IE)
				ATY_taxableincome_couple_b1 = ATY_taxableincome_couple_b1 + taxable_income*coupleYR(AGE,IA,IE)
				couple_Y_b1 = couple_Y_b1 + coupleYR(AGE,IA,IE)
			END IF

		END DO
    END DO
END DO  

temp_sort_ATY(:) = sort_ATY(record_position_tinc)
temp_sort_ATC(:) = sort_ATC(record_position_tinc)
sort_ATY = temp_sort_ATY
sort_ATC = temp_sort_ATC

! Sorted by income group
! Corporate tax target moments
ctaxrev_income = sum(sort_ATC*sort_D_tinc)/OUTPUT
!ctaxrev_income = sum(sort_ATC*sort_D_tinc)/Aggtincome
!ctaxrev_income = cor_tax_rev/Aggtincome

ATC1 =  sum(sort_ATC*sort_D_tinc*top1pct_D_tinc) &
		/sum(sort_tinc*sort_D_tinc*top1pct_D_tinc)
! ATC1 =  sum(sort_ATC*sort_D_tinc*top1pct_D_tinc) &
! 		/sum(sort_noncorpY*sort_D_tinc*top1pct_D_tinc)
		
ATC99 =  sum(sort_ATC*sort_D_tinc*(1-top1pct_D_tinc)) &
		/sum(sort_tinc*sort_D_tinc*(1-top1pct_D_tinc))	
! ATC99 =  sum(sort_ATC*sort_D_tinc*(1-top1pct_D_tinc)) &
! 		/sum(sort_noncorpY*sort_D_tinc*(1-top1pct_D_tinc))	

! income tax target moments
ATY1 =  sum(sort_ATY*sort_D_tinc*top1pct_D_tinc) &
		/sum(sort_tinc*sort_D_tinc*top1pct_D_tinc)
! ATY1 =  sum(sort_ATY*sort_D_tinc*top1pct_D_tinc) &
! 		/sum(sort_noncorpY*sort_D_tinc*top1pct_D_tinc)

print*, 'ATY1=',sum( sort_ATY*sort_D_tinc*top1pct_D_tinc/sum(sort_D_tinc*top1pct_D_tinc) )
print*, 'Avg tinc 1%=',sum(sort_tinc*sort_D_tinc*top1pct_D_tinc/sum(sort_D_tinc*top1pct_D_tinc))
! ATY1 =  sum(sort_ATY*sort_D_tinc*top1pct_D_tinc/sum(sort_D_tinc*top1pct_D_tinc)) &
! 	   /sum(sort_tinc*sort_D_tinc*top1pct_D_tinc/sum(sort_D_tinc*top1pct_D_tinc))

ATY10 =  sum(sort_ATY*sort_D_tinc*top10pct_D_tinc) &
		/sum(sort_tinc*sort_D_tinc*top10pct_D_tinc)
print*, 'ATY10=',sum( sort_ATY*sort_D_tinc*top10pct_D_tinc/sum(sort_D_tinc*top10pct_D_tinc) )
print*, 'Avg tinc 10%=',sum(sort_tinc*sort_D_tinc*top10pct_D_tinc/sum(sort_D_tinc*top10pct_D_tinc))

ATY99 =  sum(sort_ATY*sort_D_tinc*(1-top1pct_D_tinc)) &
		/sum(sort_tinc*sort_D_tinc*(1-top1pct_D_tinc))
! ATY99 =  sum(sort_ATY*sort_D_tinc*(1-top1pct_D_tinc)) &
! 		/sum(sort_noncorpY*sort_D_tinc*(1-top1pct_D_tinc))

print*, 'ATY99=',sum(sort_ATY*sort_D_tinc*(1-top1pct_D_tinc)/sum(sort_D_tinc*(1-top1pct_D_tinc)) ) 
print*, 'Avg tinc 99%=',sum( sort_tinc*sort_D_tinc*(1-top1pct_D_tinc)/sum(sort_D_tinc*(1-top1pct_D_tinc)) )

ATY90 =  sum(sort_ATY*sort_D_tinc*(1-top10pct_D_tinc)) &
		/sum(sort_tinc*sort_D_tinc*(1-top10pct_D_tinc))

print*, 'ATY90=',sum(sort_ATY*sort_D_tinc*(1-top10pct_D_tinc)/sum(sort_D_tinc*(1-top10pct_D_tinc)) ) 
print*, 'Avg tinc bottom 90%=',sum( sort_tinc*sort_D_tinc*(1-top10pct_D_tinc)/sum(sort_D_tinc*(1-top10pct_D_tinc)) )

inctaxrev_income = sum(sort_ATY*sort_D_tinc)/OUTPUT
! ATY = sum(sort_ATY*sort_D_tinc)/Aggtincome
ATY = (ATY_tax_single+ATY_tax_couple)/(ATY_taxableincome_single+ATY_taxableincome_couple)
ATY_single = ATY_tax_single/ATY_taxableincome_single
ATY_single_Q1 = ATY_tax_single_Q1/ATY_taxableincome_single_Q1
ATY_single_Q2 = ATY_tax_single_Q2/ATY_taxableincome_single_Q2
ATY_single_Q3 = ATY_tax_single_Q3/ATY_taxableincome_single_Q3
ATY_single_Q4 = ATY_tax_single_Q4/ATY_taxableincome_single_Q4
ATY_single_Q5 = ATY_tax_single_Q5/ATY_taxableincome_single_Q5

ATY_single_b10 = ATY_tax_single_b10/ATY_taxableincome_single_b10
ATY_single_b9 = ATY_tax_single_b9/ATY_taxableincome_single_b9
ATY_single_b8 = ATY_tax_single_b8/ATY_taxableincome_single_b8
ATY_single_b7 = ATY_tax_single_b7/ATY_taxableincome_single_b7
ATY_single_b6 = ATY_tax_single_b6/ATY_taxableincome_single_b6
ATY_single_b5 = ATY_tax_single_b5/ATY_taxableincome_single_b5
ATY_single_b4 = ATY_tax_single_b4/ATY_taxableincome_single_b4
ATY_single_b3 = ATY_tax_single_b3/ATY_taxableincome_single_b3
ATY_single_b2 = ATY_tax_single_b2/ATY_taxableincome_single_b2
ATY_single_b1 = ATY_tax_single_b1/ATY_taxableincome_single_b1

ATY_couple = ATY_tax_couple/ATY_taxableincome_couple
ATY_couple_Q1 = ATY_tax_couple_Q1/ATY_taxableincome_couple_Q1
ATY_couple_Q2 = ATY_tax_couple_Q2/ATY_taxableincome_couple_Q2
ATY_couple_Q3 = ATY_tax_couple_Q3/ATY_taxableincome_couple_Q3
ATY_couple_Q4 = ATY_tax_couple_Q4/ATY_taxableincome_couple_Q4
ATY_couple_Q5 = ATY_tax_couple_Q5/ATY_taxableincome_couple_Q5

ATY_couple_b10 = ATY_tax_couple_b10/ATY_taxableincome_couple_b10
ATY_couple_b9 = ATY_tax_couple_b9/ATY_taxableincome_couple_b9
ATY_couple_b8 = ATY_tax_couple_b8/ATY_taxableincome_couple_b8
ATY_couple_b7 = ATY_tax_couple_b7/ATY_taxableincome_couple_b7
ATY_couple_b6 = ATY_tax_couple_b6/ATY_taxableincome_couple_b6
ATY_couple_b5 = ATY_tax_couple_b5/ATY_taxableincome_couple_b5
ATY_couple_b4 = ATY_tax_couple_b4/ATY_taxableincome_couple_b4
ATY_couple_b3 = ATY_tax_couple_b3/ATY_taxableincome_couple_b3
ATY_couple_b2 = ATY_tax_couple_b2/ATY_taxableincome_couple_b2
ATY_couple_b1 = ATY_tax_couple_b1/ATY_taxableincome_couple_b1



! inctaxrev_income = sum(sort_ATY*sort_D_tinc)/Aggtincome

! ***** need to separately calculate "top10pct_D_tinc" and "top1pct_D_tinc" with single and couple *******
! MTR_single(:) = MIN(1.0 - lambda * (1.0-tau_l_single) * sort_tinc(:)**(-tau_l_single),ty_max)
! MTR_couple(:) = MIN(1.0 - lambda * (1.0-tau_l_couple) * sort_tinc(:)**(-tau_l_couple),ty_max)
! !where ( sort_D_tinc == 0.0 ) MTR = 0.0

! MTR10_single = MTR_single(int(size(MTR_single)-sum(top10pct_D_tinc)))
! MTR1_single = MTR_single(int(size(MTR_single)-sum(top1pct_D_tinc)))

! MTR10_couple = MTR_couple(int(size(MTR_couple)-sum(top10pct_D_tinc)))
! MTR1_couple = MTR_couple(int(size(MTR_couple)-sum(top1pct_D_tinc)))

END SUBROUTINE
!***************************************************************************************
SUBROUTINE check_kmaxbinding

! Single working age
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2                 
                
            	 IF  ( (singleIDCWA(AGE,IA,IS,IE,IG)>=NGRIDA) .AND. (singleYW(AGE,IA,IS,IE,IG)>0.0) ) THEN
            	 print*, ' WARNING kmax binding !!!!'
            	 END IF 

				END DO 
            END DO
        END DO
    END DO
END DO  

! Couple working age
DO AGE = 1,RETAGE-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

				 IF  ( (coupleIDCWA(AGE,IA,IS1,IS2,IE)>=NGRIDA) .AND. (coupleYW(AGE,IA,IS1,IS2,IE)>0.0) ) THEN
            	 print*, ' WARNING kmax binding !!!!'
            	 END IF

				END DO 
            END DO
        END DO 
    END DO
END DO


! Single retiree 
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IE = 1,NGRIDEH	
			DO IG=1,2

             IF  ( (singleIDCRA(AGE,IA,IE,IG)>=NGRIDA) .AND. (singleYR(AGE,IA,IE,IG)>0.0) ) THEN
             print*, ' WARNING kmax binding !!!!'
             END IF 

			END DO 
        END DO
    END DO
END DO

! couple retiree
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

		 IF  ( (coupleIDCRA(AGE,IA,IE)>=NGRIDA) .AND. (coupleYR(AGE,IA,IE)>0.0) ) THEN
         print*, ' WARNING kmax binding !!!!'
         END IF

		END DO
    END DO
END DO    

END SUBROUTINE
!***************************************************************************************
! SUBROUTINE combine_couple_asset(AGE)

! IMPLICIT NONE 
! INTEGER    ::  AGE,IA,IS1,IS2,id1,id2,ACLOSE
! REAL(PREC) ::  tempjointasset

! ! Construct partner distribution

! !DO AGE = 1,RETAGE-1
! 	!SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
! 	DO IA = 1,NGRIDA
! 		!DO IG=1,2		
! 			DO IS=1,nn	!partner productivity
				
! 				single_male_dist(IA,IS) = YW(AGE,IA,IS,1)
! 				single_female_dist(IA,IS) = YW(AGE,IA,IS,2)
! 				single_male_asset(IA,IS) = A(IA) 
! 				single_female_asset(IA,IS) = A(IA)
! 				! single_male_asset(IA,IS) = A(singleIDCWA(AGE,IA,IS,1)) 
! 				! single_female_asset(IA,IS) = A(singleIDCWA(AGE,IA,IS,2))
			
! 			END DO
! 		!END DO 
! 	END DO 

! !	Normalize along the IS dimension
! DO IS=1,nn 
! 	DO IA=1,NGRIDA 
! 		single_male_dist(IA,IS) = single_male_dist(IA,IS)/SUM(single_male_dist(:,IS))
! 		single_female_dist(IA,IS) = single_female_dist(IA,IS)/SUM(single_female_dist(:,IS))
! 	END DO 
! END DO 

! ! build transition matrix of combining asset for male
! DO IA1=1,NGRIDA	
! 	DO IS2=1,nn 	! wife's productivity
! 		DO IA2=1,NGRIDA

! 			tempjointasset = A(IA1) + single_female_asset(IA2,IS2) 

! 			IF (single_female_asset(IA2,IS2) <= 0.0) THEN
! 				jointasset_femalepartner(IA1,IA1,IS2) = jointasset_femalepartner(IA1,IA1,IS2) + single_female_dist(IA2,IS2)
! 			ELSE 

! 				DO i=IA1,NGRIDA 
! 					IF (A(i) > tempjointasset)	THEN 
! 						ACLOSE = i-1
! 						jointasset_femalepartner(IA1,ACLOSE,IS2) = jointasset_femalepartner(IA1,ACLOSE,IS2) + single_female_dist(IA2,IS2)*(tempjointasset-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))
! 						jointasset_femalepartner(IA1,ACLOSE+1,IS2) = jointasset_femalepartner(IA1,ACLOSE+1,IS2) + single_female_dist(IA2,IS2)*(1.0-(tempjointasset-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))) 
! 						GO TO 111
! 					ELSEIF	(A(i) == tempjointasset) THEN
! 						ACLOSE = i 
! 						jointasset_femalepartner(IA1,ACLOSE,IS2) = jointasset_femalepartner(IA1,ACLOSE,IS2) + single_female_dist(IA2,IS2)
! 						GO TO 111
! 					ELSEIF ( (i==NGRIDA) .AND. (A(i) < tempjointasset) ) THEN	
! 						jointasset_femalepartner(IA1,NGRIDA,IS2) = jointasset_femalepartner(IA1,NGRIDA,IS2) + single_female_dist(IA2,IS2)
! 						GO TO 111 
! 					END IF 
! 				END DO
! 			END IF 
! 			111 continue
! 		END DO 
! 	END DO 
! END DO 

! ! build transition matrix of combining asset for female
! DO IA2=1,NGRIDA	
! 	DO IS1=1,nn 	! husband's productivity
! 		DO IA1=1,NGRIDA

! 			tempjointasset = A(IA2) + single_male_asset(IA1,IS1) 

! 			IF (single_male_asset(IA1,IS1) <= 0.0) THEN
! 				jointasset_malepartner(IA2,IA2,IS1) = jointasset_malepartner(IA2,IA2,IS1) + single_male_dist(IA1,IS1)
! 			ELSE 

! 				DO i=IA2,NGRIDA 
! 					IF (A(i) > tempjointasset)	THEN 
! 						ACLOSE = i-1
! 						jointasset_malepartner(IA2,ACLOSE,IS1) = jointasset_malepartner(IA2,ACLOSE,IS1) + single_male_dist(IA1,IS1)*(tempjointasset-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))
! 						jointasset_malepartner(IA2,ACLOSE+1,IS1) = jointasset_malepartner(IA2,ACLOSE+1,IS1) + single_male_dist(IA1,IS1)*(1.0-(tempjointasset-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))) 
! 						GO TO 112
! 					ELSEIF	(A(i) == tempjointasset) THEN
! 						ACLOSE = i 
! 						jointasset_malepartner(IA2,ACLOSE,IS1) = jointasset_malepartner(IA2,ACLOSE,IS1) + single_male_dist(IA1,IS1)
! 						GO TO 112
! 					ELSEIF ( (i==NGRIDA) .AND. (A(i) < tempjointasset) ) THEN	
! 						jointasset_malepartner(IA2,NGRIDA,IS1) = jointasset_malepartner(IA2,NGRIDA,IS1) + single_male_dist(IA1,IS1)
! 						GO TO 112 
! 					END IF 
! 				END DO
! 			END IF 
! 			112 continue
! 		END DO 
! 	END DO 
! END DO 

! DO IS=1,nn
! 	DO IA=1,NGRIDA
! 		if(abs(1.0 - sum(jointasset_femalepartner(IA,:,IS))) > 0.0001) then
! 			print*, ' Warning the sum of jointasset_femalepartner transition matrix row not equal to 1'
! 			print*, 'IS=', IS
! 			print*, 'row=',IA
! 			print*, 'sum=',sum(jointasset_femalepartner(IA,:,IS))
! 		end if 
! 		if(abs(1.0 - sum(jointasset_malepartner(IA,:,IS))) > 0.0001) then
! 			print*, ' Warning the sum of jointasset_malepartner transition matrix row not equal to 1'
! 			print*, 'IS=', IS
! 			print*, 'row=',IA
! 			print*, 'sum=',sum(jointasset_malepartner(IA,:,IS))
! 		end if
! 	END DO
! END DO	 

! END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE welfare_wealth

ALLOCATE( male_welfare(NGRIDA), female_welfare(NGRIDA), couple_welfare(NGRIDA) )

! DO IA=1,NGRIDA
! male_welfare(IA) = ( dot_product(singleVW(:,IA,:,:,1),singleYW(:,IA,:,:,1)) + dot_product(singleVR(:,IA,:,1),singleYR(:,IA,:,1)) )/( SUM(singleYW(:,IA,:,:,1))+SUM(singleYR(:,IA,:,1)) )
! female_welfare(IA) = ( dot_product(singleVW(:,IA,:,:,2),singleYW(:,IA,:,:,2)) + dot_product(singleVR(:,IA,:,2),singleYR(:,IA,:,2)) )/( SUM(singleYW(:,IA,:,:,2))+SUM(singleYR(:,IA,:,2)) )
! couple_welfare(IA) = ( dot_product(coupleVW(:,IA,:,:,:),coupleYW(:,IA,:,:,:)) + dot_product(coupleVR(:,IA,:),coupleYR(:,IA,:)) )/( SUM(coupleYW(:,IA,:,:,:))+SUM(coupleYR(:,IA,:)) )
! END DO 

DO IA=1,NGRIDA
male_welfare(IA) = ( SUM(singleVW(:,IA,:,:,1)*singleYW(:,IA,:,:,1)) + SUM(singleVR(:,IA,:,1)*singleYR(:,IA,:,1)) )/( SUM(singleYW(:,IA,:,:,1))+SUM(singleYR(:,IA,:,1)) )
female_welfare(IA) = ( SUM(singleVW(:,IA,:,:,2)*singleYW(:,IA,:,:,2)) + SUM(singleVR(:,IA,:,2)*singleYR(:,IA,:,2)) )/( SUM(singleYW(:,IA,:,:,2))+SUM(singleYR(:,IA,:,2)) )
couple_welfare(IA) = ( SUM(coupleVW(:,IA,:,:,:)*coupleYW(:,IA,:,:,:)) + SUM(coupleVR(:,IA,:)*coupleYR(:,IA,:)) )/( SUM(coupleYW(:,IA,:,:,:))+SUM(coupleYR(:,IA,:)) )
END DO 


OPEN(UNIT=33,FILE='welfare_wealth.txt')
write(33,*) male_welfare(:)
write(33,*) female_welfare(:)
write(33,*) couple_welfare(:)
CLOSE(UNIT=33)

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE welfare

ALLOCATE( avg_couple_welfare(nn,nn) )

! male_welfare(IA) = ( SUM(singleVW(:,IA,:,:,1)*singleYW(:,IA,:,:,1)) + SUM(singleVR(:,IA,:,1)*singleYR(:,IA,:,1)) )/( SUM(singleYW(:,IA,:,:,1))+SUM(singleYR(:,IA,:,1)) )
! female_welfare(IA) = ( SUM(singleVW(:,IA,:,:,2)*singleYW(:,IA,:,:,2)) + SUM(singleVR(:,IA,:,2)*singleYR(:,IA,:,2)) )/( SUM(singleYW(:,IA,:,:,2))+SUM(singleYR(:,IA,:,2)) )
! couple_welfare(IA) = ( SUM(coupleVW(:,IA,:,:,:)*coupleYW(:,IA,:,:,:)) + SUM(coupleVR(:,IA,:)*coupleYR(:,IA,:)) )/( SUM(coupleYW(:,IA,:,:,:))+SUM(coupleYR(:,IA,:)) )

! single_male_welfare = ( SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleVR(RETAGE:MAXAGE,:,:,1)*singleYR(RETAGE:MAXAGE,:,:,1)) )/( SUM(singleYW(:,:,:,:,1))+SUM(singleYR(RETAGE:MAXAGE,:,:,1)) )
! single_female_welfare = ( SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleVR(RETAGE:MAXAGE,:,:,2)*singleYR(RETAGE:MAXAGE,:,:,2)) )/( SUM(singleYW(:,:,:,:,2))+SUM(singleYR(RETAGE:MAXAGE,:,:,2)) )

! single_male_welfare = SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1))/SUM(singleYW(:,:,:,:,1))
! single_female_welfare = SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2))/SUM(singleYW(:,:,:,:,2))
! total_couple_welfare = SUM(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:))/SUM(coupleYW(:,:,:,:,:))

! single_male_welfare = SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleVR(RETAGE:MAXAGE,:,:,1)*singleYR(RETAGE:MAXAGE,:,:,1))
! single_female_welfare = SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleVR(RETAGE:MAXAGE,:,:,2)*singleYR(RETAGE:MAXAGE,:,:,2))
! total_couple_welfare = SUM(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + SUM(coupleVR(RETAGE:MAXAGE,:,:)*coupleYR(RETAGE:MAXAGE,:,:))

single_male_welfare =  (SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleVR(RETAGE:MAXAGE,:,:,1)*singleYR(RETAGE:MAXAGE,:,:,1)))/(SUM(singleYW(:,:,:,:,1))+SUM(singleYR(RETAGE:MAXAGE,:,:,1)))
single_female_welfare = (SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleVR(RETAGE:MAXAGE,:,:,2)*singleYR(RETAGE:MAXAGE,:,:,2)))/(SUM(singleYW(:,:,:,:,2))+SUM(singleYR(RETAGE:MAXAGE,:,:,2)))
total_couple_welfare =( SUM(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + SUM(coupleVR(RETAGE:MAXAGE,:,:)*coupleYR(RETAGE:MAXAGE,:,:)))/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:)))

married_male_welfare =  (SUM(marriageVW(:,:,:,:,:,1)*coupleYW(:,:,:,:,:)) + SUM(marriageVR(RETAGE:MAXAGE,:,:,1)*coupleYR(RETAGE:MAXAGE,:,:)))/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:)))
married_female_welfare = (SUM(marriageVW(:,:,:,:,:,2)*coupleYW(:,:,:,:,:)) + SUM(marriageVR(RETAGE:MAXAGE,:,:,2)*coupleYR(RETAGE:MAXAGE,:,:)))/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:)))

DO IS1=1,nn
	DO IS2=1,nn 
		avg_couple_welfare(IS1,IS2) =  SUM(coupleVW(:,:,IS1,IS2,:)*coupleYW(:,:,IS1,IS2,:))/SUM(coupleYW(:,:,IS1,IS2,:))
	END DO 
END DO 

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE output_analysis

male_avgwealth = 0.0
female_avgwealth = 0.0
couple_avgwealth = 0.0

male_avgearning = 0.0
female_avgearning = 0.0
couple_avgearning = 0.0

male_avghour = 0.0
female_avghour = 0.0
couple_avghour = 0.0

male_avgincome = 0.0
female_avgincome = 0.0
couple_avgincome = 0.0

male_avgcons = 0.0
female_avgcons = 0.0
couple_avgcons = 0.0

male_population = SUM(singleYW(:,:,:,:,1))+SUM(singleYR(:,:,:,1))
female_population = SUM(singleYW(:,:,:,:,2))+SUM(singleYR(:,:,:,2))
couple_population =  SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(:,:,:))

! Working-age "single" agents
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH               
				  
				JN1 = singleIDCWN(AGE,IA,IS,IE,1)  		
				JN2 = singleIDCWN(AGE,IA,IS,IE,2) 
				
				male_avgwealth = male_avgwealth + A(IA)*singleYW(AGE,IA,IS,IE,1)/male_population
				female_avgwealth = female_avgwealth + A(IA)*singleYW(AGE,IA,IS,IE,2)/female_population
				
				male_avgearning = male_avgearning + WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS,1)*singleYW(AGE,IA,IS,IE,1)/male_population
				female_avgearning = female_avgearning + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS,2)*singleYW(AGE,IA,IS,IE,2)/female_population

				male_avgincome = male_avgincome + (WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS,1)+R*A(IA))*singleYW(AGE,IA,IS,IE,1)/male_population
				female_avgincome = female_avgincome + (WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS,2)+R*A(IA))*singleYW(AGE,IA,IS,IE,2)/female_population

				male_avgcons = male_avgcons + singleIDCWC(AGE,IA,IS,IE,1)*singleYW(AGE,IA,IS,IE,1)/male_population
				female_avgcons = female_avgcons + singleIDCWC(AGE,IA,IS,IE,2)*singleYW(AGE,IA,IS,IE,2)/female_population
				
            END DO
        END DO 
    END DO
END DO

!  Working-age "couple" agents
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH

				JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
				JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

				couple_avgwealth = couple_avgwealth + A(IA)*coupleYW(AGE,IA,IS1,IS2,IE)/couple_population
								
				couple_avgearning = couple_avgearning + (WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS,1)+WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS,2))*coupleYW(AGE,IA,IS1,IS2,IE)/couple_population
				
				couple_avgincome = couple_avgincome + (WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS,1)+WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS,2)+R*A(IA))*coupleYW(AGE,IA,IS1,IS2,IE)/couple_population				

				couple_avgcons = couple_avgcons + coupleIDCWC(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)/couple_population
			
				END DO 
            END DO
        END DO 
    END DO
END DO

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE tax_penalty

! ALLOCATE( single_taxliability(2) )
! ALLOCATE( couple_taxpenalty(nn,nn) )

!single_taxliability(:) = 0.0
couple_taxpenalty(:,:) = 0.0

! ! Single working age
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA
!         DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2   

! 				 JN=singleIDCWN(AGE,IA,IS,IE,IG)
! 				 taxableincome = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + min(R*A(IA),d_c)
! 				 single_taxliability(IG) = single_taxliability(IG) + taxpayment(taxableincome,tau_l_single)

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO

! ! Single retiree
! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA
!         DO IE = 1,NGRIDEH	
! 			DO IG=1,2 

! 			 taxableincome = SS(IE) + min(R*A(IA),d_c)
! 			 single_taxliability(IG) = single_taxliability(IG) + taxpayment(taxableincome,tau_l_single)

! 			END DO 
!         END DO 
!     END DO
! END DO 
!************************************************************************************************************************************************************************************************
! Couple working age
! DO IS1 = 1,nn 
! 	DO IS2=1,nn 
! 		DO AGE = 1,RETAGE-1     
!     		DO IA = 1,NGRIDA           			
! 				DO IE=1,NGRIDEH

! 				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
! 				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
! 		! with capital income
! 				 ! Joint filing
! 				 	taxableincome = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + min(R*A(IA),d_c)
! 					jointfiling_tax = taxpayment(taxableincome,IA,tau_l_couple)
! 				 ! Separate filing
! 				 	separatefiling_tax = taxpayment(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, IA, tau_l_single) &
! 					 					+ taxpayment(WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, IA, tau_l_single)
					
! 					couple_taxpenalty(IS1,IS2) = couple_taxpenalty(IS1,IS2) + (separatefiling_tax - jointfiling_tax)*coupleYW(AGE,IA,IS1,IS2,IE)/SUM(coupleYW(:,:,IS1,IS2,:))

! 		! w/o capital income	
! 				! ! Joint filing
! 				!  	taxableincome = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) 
! 				! 	jointfiling_tax = taxpayment(taxableincome,IA,tau_l_couple)
! 				!  ! Separate filing
! 				!  	separatefiling_tax = taxpayment(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1), IA, tau_l_single) &
! 				! 	 					+ taxpayment(WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2), IA, tau_l_single)
					
! 				! 	couple_taxpenalty(IS1,IS2) = couple_taxpenalty(IS1,IS2) + (separatefiling_tax - jointfiling_tax)*coupleYW(AGE,IA,IS1,IS2,IE)/SUM(coupleYW(:,:,IS1,IS2,:))

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO 
!************************************************************************************************************************************************************************************************
temp_couple_taxpenalty = 0.0
temp_separatefiling_tax = 0.0
! percentage of tax penalty
DO IS1 = 1,nn 
	DO IS2=1,nn 
		DO AGE = 1,RETAGE-1     
    		DO IA = 1,NGRIDA           			
				DO IE=1,NGRIDEH

				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

				 ! Joint filing
				 	taxableincome = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + min(R*A(IA),d_c)
					jointfiling_tax = taxpayment(taxableincome,tau_l_couple,2)
				 ! Separate filing
				 	separatefiling_tax = taxpayment(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, tau_l_single,1) &
					 					+ taxpayment(WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, tau_l_single,1)
					
					! couple_taxpenalty(IS1,IS2) = couple_taxpenalty(IS1,IS2) + (separatefiling_tax - jointfiling_tax)*coupleYW(AGE,IA,IS1,IS2,IE)/SUM(coupleYW(:,:,IS1,IS2,:))

					temp_couple_taxpenalty = temp_couple_taxpenalty + (jointfiling_tax-separatefiling_tax)*coupleYW(AGE,IA,IS1,IS2,IE)/SUM(coupleYW(:,:,IS1,IS2,:))
					temp_separatefiling_tax = temp_separatefiling_tax + separatefiling_tax*coupleYW(AGE,IA,IS1,IS2,IE)/SUM(coupleYW(:,:,IS1,IS2,:))

				END DO 
            END DO
        END DO 

		couple_taxpenalty(IS1,IS2) = temp_couple_taxpenalty/temp_separatefiling_tax

    END DO
END DO 

!************************************************************************************************************************
! perecent of total households getting subsidy/penalty
ALLOCATE( temp_family_tax((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH), temp_family_subsidy((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH)  )
ALLOCATE( temp_family_tax_dist((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH), temp_family_subsidy_dist((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH)  )

temp_family_tax(:) = 0.0
temp_family_tax_dist(:) = 0.0
temp_family_subsidy(:) = 0.0
temp_family_subsidy_dist(:) = 0.0

itax=0
isubsidy=0

DO AGE = 1,RETAGE-1     
    DO IA = 1,NGRIDA           			
		DO IS1 = 1,nn 
			DO IS2=1,nn 	
				DO IE=1,NGRIDEH
		
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

				 ! Joint filing
				 	taxableincome = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + min(R*A(IA),d_c)
					jointfiling_tax = taxpayment(taxableincome,tau_l_couple,2)
				 ! Separate filing
				 	separatefiling_tax = taxpayment(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, tau_l_single,1) &
					 					+ taxpayment(WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, tau_l_single,1)
					
					IF ( separatefiling_tax - jointfiling_tax < 0.0 ) THEN 	! Families with tax
					itax = itax + 1
					temp_family_tax(itax) = temp_family_tax(itax) + (jointfiling_tax - separatefiling_tax )
					temp_family_tax_dist(itax) = temp_family_tax_dist(itax) + coupleYW(AGE,IA,IS1,IS2,IE)

					ELSEIF ( separatefiling_tax - jointfiling_tax > 0.0 ) THEN		! Families with subsidy
					isubsidy = isubsidy + 1
					temp_family_subsidy(isubsidy) = temp_family_subsidy(isubsidy) + (jointfiling_tax - separatefiling_tax )
					temp_family_subsidy_dist(isubsidy) = temp_family_subsidy_dist(isubsidy) + coupleYW(AGE,IA,IS1,IS2,IE)

					END IF 

				END DO 
            END DO
        END DO 
    END DO
END DO 

prop_family_tax = SUM(temp_family_tax_dist)/SUM(coupleYW(:,:,:,:,:))
prop_family_subsidy = SUM(temp_family_subsidy_dist)/SUM(coupleYW(:,:,:,:,:))
avg_family_tax = dot_product(temp_family_tax,temp_family_tax_dist)/SUM(temp_family_tax_dist)
avg_family_subsidy = dot_product(temp_family_subsidy,temp_family_subsidy_dist)/SUM(temp_family_subsidy_dist)
sd_family_tax = (SUM( ((temp_family_tax(:)-avg_family_tax)**2.0)*temp_family_tax_dist(:) ))**0.5
sd_family_subsidy = (SUM( ((temp_family_subsidy(:)-avg_family_subsidy)**2.0)*temp_family_subsidy_dist(:) ))**0.5

!************************************************************************************************************************
! Average Marriage Tax/Subsidy by Earnings Ratio of female to male

ALLOCATE( temp_earnratio_tax((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,5,5), temp_earnratio_subsidy((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,5,5)  )
ALLOCATE( temp_earnratio_tax_dist((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,5,5), temp_earnratio_subsidy_dist((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH,5,5)  )
ALLOCATE( prop_earnratio_tax(5,5),  prop_earnratio_subsidy(5,5), avg_earnratio_tax(5,5), avg_earnratio_subsidy(5,5) )
ALLOCATE( itax1(5),itax2(5),itax3(5),itax4(5),itax5(5) )
ALLOCATE( isubsidy1(5),isubsidy2(5),isubsidy3(5),isubsidy4(5),isubsidy5(5) )

temp_earnratio_tax(:,:,:) = 0.0
temp_earnratio_tax_dist(:,:,:) = 0.0
temp_earnratio_subsidy(:,:,:) = 0.0
temp_earnratio_subsidy_dist(:,:,:) = 0.0

itax1(:)=0
isubsidy1(:)=0
itax2(:)=0
isubsidy2(:)=0
itax3(:)=0
isubsidy3(:)=0
itax4(:)=0
isubsidy4(:)=0
itax5(:)=0
isubsidy5(:)=0

OPEN(UNIT=41,FILE='earn_ratio1.txt')
OPEN(UNIT=42,FILE='earn_ratio2.txt')
OPEN(UNIT=43,FILE='earn_ratio3.txt')
OPEN(UNIT=44,FILE='earn_ratio4.txt')
OPEN(UNIT=45,FILE='earn_ratio5.txt')
! WRITE(40,*) 'female earning','male earning','tax','subsidy'

DO AGE = 1,RETAGE-1     
    DO IA = 1,NGRIDA           			
		DO IS1 = 1,nn 
			DO IS2=1,nn 	
				DO IE=1,NGRIDEH

				IF (coupleYW(AGE,IA,IS1,IS2,IE) > 0.0) THEN 

				 	JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 	JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					TINCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)

				 	earn_ratio = ( WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2 )/( WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2 )

 				 ! Joint filing
				 	taxableincome = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + min(R*A(IA),d_c)
					jointfiling_tax = taxpayment(taxableincome,tau_l_couple,2)
				 ! Separate filing
				 	separatefiling_tax = taxpayment(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, tau_l_single,1) &
					 					+ taxpayment(WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, tau_l_single,1)
				
					! IF (TINCOME<=incomethreshold80) THEN
					! 	i=1
					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
					! 	i=2
					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
					! 	i=3
					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
					! 	i=4
					! ELSEIF (TINCOME>incomethreshold20) THEN 
					! 	i=5
					! END IF 

					IF (TINCOME<=0.2*Aggincome) THEN
						i=1
					ELSEIF ( (TINCOME>0.2*Aggincome) .AND. (TINCOME<=0.4*Aggincome) ) THEN 
						i=2
					ELSEIF ( (TINCOME>0.4*Aggincome) .AND. (TINCOME<=0.6*Aggincome) ) THEN 
						i=3
					ELSEIF ( (TINCOME>0.6*Aggincome) .AND. (TINCOME<=0.8*Aggincome) ) THEN 
						i=4
					ELSEIF (TINCOME>0.8*Aggincome) THEN 
						i=5
					END IF 

					IF (earn_ratio<=0.25) THEN 

						IF ( separatefiling_tax - jointfiling_tax < 0.0 ) THEN 	! Families with tax
							itax1(i) = itax1(i) + 1
							temp_earnratio_tax(itax1(i),1,i) = jointfiling_tax - separatefiling_tax 
							temp_earnratio_tax_dist(itax1(i),1,i) = coupleYW(AGE,IA,IS1,IS2,IE)
						ELSEIF ( separatefiling_tax - jointfiling_tax > 0.0 ) THEN		! Families with subsidy
							isubsidy1(i) = isubsidy1(i) + 1							
							temp_earnratio_subsidy(isubsidy1(i),1,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_subsidy_dist(isubsidy1(i),1,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						END IF 
				
					! WRITE(41,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2,temp_earnratio_tax(itax1,1),temp_earnratio_subsidy(isubsidy1,1)
					! WRITE(41,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, coupleYW(AGE,IA,IS1,IS2,IE)
					WRITE(41,"(12(F11.4,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, coupleYW(AGE,IA,IS1,IS2,IE)


					ELSEIF ((earn_ratio>0.25) .AND. (earn_ratio<=0.5)) THEN 

						IF ( separatefiling_tax - jointfiling_tax < 0.0 ) THEN 	! Families with tax
							itax2(i) = itax2(i) + 1							
							temp_earnratio_tax(itax2(i),2,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_tax_dist(itax2(i),2,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						ELSEIF ( separatefiling_tax - jointfiling_tax > 0.0 ) THEN		! Families with subsidy
							isubsidy2(i) = isubsidy2(i) + 1						
							temp_earnratio_subsidy(isubsidy2(i),2,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_subsidy_dist(isubsidy2(i),2,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						END IF

					! WRITE(42,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2,temp_earnratio_tax(itax2,2),temp_earnratio_subsidy(isubsidy2,2)
					WRITE(42,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, coupleYW(AGE,IA,IS1,IS2,IE)

					ELSEIF ((earn_ratio>0.5) .AND. (earn_ratio<=0.75)) THEN 

						IF ( separatefiling_tax - jointfiling_tax < 0.0 ) THEN 	! Families with tax
							itax3(i) = itax3(i) + 1
							temp_earnratio_tax(itax3(i),3,i) = jointfiling_tax - separatefiling_tax 
							temp_earnratio_tax_dist(itax3(i),3,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						ELSEIF ( separatefiling_tax - jointfiling_tax > 0.0 ) THEN		! Families with subsidy
							isubsidy3(i) = isubsidy3(i) + 1
							temp_earnratio_subsidy(isubsidy3(i),3,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_subsidy_dist(isubsidy3(i),3,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						END IF

					! WRITE(43,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2,temp_earnratio_tax(itax3,3),temp_earnratio_subsidy(isubsidy3,3)
					WRITE(43,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, coupleYW(AGE,IA,IS1,IS2,IE)

					ELSEIF ((earn_ratio>0.75) .AND. (earn_ratio<=1.0)) THEN 

						IF ( separatefiling_tax - jointfiling_tax < 0.0 ) THEN 	! Families with tax
							itax4(i) = itax4(i) + 1
							temp_earnratio_tax(itax4(i),4,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_tax_dist(itax4(i),4,i) =   coupleYW(AGE,IA,IS1,IS2,IE)
						ELSEIF ( separatefiling_tax - jointfiling_tax > 0.0 ) THEN		! Families with subsidy
							isubsidy4(i) = isubsidy4(i) + 1
							temp_earnratio_subsidy(isubsidy4(i),4,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_subsidy_dist(isubsidy4(i),4,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						END IF

					! WRITE(44,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2,temp_earnratio_tax(itax4,4),temp_earnratio_subsidy(isubsidy4,4)
					WRITE(44,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, coupleYW(AGE,IA,IS1,IS2,IE)
				
					ELSEIF (earn_ratio>1.0) THEN 

						IF ( separatefiling_tax - jointfiling_tax < 0.0 ) THEN 	! Families with tax
							itax5(i) = itax5(i) + 1
							temp_earnratio_tax(itax5(i),5,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_tax_dist(itax5(i),5,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						ELSEIF ( separatefiling_tax - jointfiling_tax > 0.0 ) THEN		! Families with subsidy
							isubsidy5(i) = isubsidy5(i) + 1
							temp_earnratio_subsidy(isubsidy5(i),5,i) =  jointfiling_tax - separatefiling_tax 
							temp_earnratio_subsidy_dist(isubsidy5(i),5,i) =  coupleYW(AGE,IA,IS1,IS2,IE)
						END IF

					! WRITE(45,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2,temp_earnratio_tax(itax5,5),temp_earnratio_subsidy(isubsidy5,5)
					WRITE(45,"(11(F8.5,1X))") WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+min(R*A(IA),d_c)/2, WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)+min(R*A(IA),d_c)/2, coupleYW(AGE,IA,IS1,IS2,IE)

					END IF 

				END IF  
				
				END DO 
            END DO
        END DO 
    END DO
END DO

DO i=1,5
	DO j=1,5
		prop_earnratio_tax(i,j) = SUM(temp_earnratio_tax_dist(:,i,j))/( SUM(temp_earnratio_tax_dist(:,i,j)) + SUM(temp_earnratio_subsidy_dist(:,i,j)) )
		prop_earnratio_subsidy(i,j) = SUM(temp_earnratio_subsidy_dist(:,i,j))/( SUM(temp_earnratio_tax_dist(:,i,j)) + SUM(temp_earnratio_subsidy_dist(:,i,j)) )

		avg_earnratio_tax(i,j) = dot_product(temp_earnratio_tax(:,i,j),temp_earnratio_tax_dist(:,i,j))/SUM(temp_earnratio_tax_dist(:,i,j))
		avg_earnratio_subsidy(i,j) = dot_product(temp_earnratio_subsidy(:,i,j),temp_earnratio_subsidy_dist(:,i,j))/SUM(temp_earnratio_subsidy_dist(:,i,j))
	END DO 
END DO 


! DO i=1,(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH
! WRITE(41,"(11(F8.5,1X))") temp_earnratio_tax(i,1),temp_earnratio_subsidy(i,1)
! WRITE(42,"(11(F8.5,1X))") temp_earnratio_tax(i,2),temp_earnratio_subsidy(i,2)
! WRITE(43,"(11(F8.5,1X))") temp_earnratio_tax(i,3),temp_earnratio_subsidy(i,3)
! WRITE(44,"(11(F8.5,1X))") temp_earnratio_tax(i,4),temp_earnratio_subsidy(i,4)
! WRITE(45,"(11(F8.5,1X))") temp_earnratio_tax(i,5),temp_earnratio_subsidy(i,5)
! END DO 

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE couple_filing_tax

popu_MFS = 0.0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH

				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
				 INCOME = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)
				 INCOME1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + min(R*A(IA),d_c)/2
				 INCOME2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)/2
				 tax_MFS = INCOME1+INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA))

				 IF (yd_MFJ(INCOME,IA) < (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA)) ) THEN 
					popu_MFS = popu_MFS + coupleYW(AGE,IA,IS1,IS2,IE)					
				 END IF 

				END DO 
			END DO
        END DO
    END DO
END DO

! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA
! 		DO IE=1,NGRIDEH

! 			INCOME = 2*SS(IE) + min(R*A(IA),d_c)
! 			INCOME1 = SS(IE) + min(R*A(IA),d_c)/2
! 			INCOME2 = SS(IE) + min(R*A(IA),d_c)/2

! 			IF (yd_MFJ(INCOME,IA) < (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA)) ) THEN  
! 				popu_MFS = popu_MFS + coupleYR(AGE,IA,IE)
! 			END IF

! 		END DO 
!     END DO
! END DO

! popu_MFS = popu_MFS/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:)))

popu_MFS = popu_MFS/SUM(coupleYW(:,:,:,:,:))

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE	opt_tax_welfare

! util_welfare_hh = sum(singleVW(:,:,:,:,:)*singleYW(:,:,:,:,:)) + sum(singleVR(:,:,:,:)*singleYR(:,:,:,:)) &
! 			 	+ sum(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + sum(coupleVR(:,:,:)*coupleYR(:,:,:))

! util_welfare_id = sum(singleVW(:,:,:,:,:)*singleYW(:,:,:,:,:)) + sum(singleVR(:,:,:,:)*singleYR(:,:,:,:)) &
! 			 	+ sum(marriageVW(:,:,:,:,:,1)*coupleYW(:,:,:,:,:)) + sum(marriageVW(:,:,:,:,:,2)*coupleYW(:,:,:,:,:)) &  
! 				+ sum(marriageVR(:,:,:,1)*coupleYR(:,:,:)) + sum(marriageVR(:,:,:,2)*coupleYR(:,:,:))			 
			
! veil_welfare_hh = ( sum(singleVW(1,1,1,1,:)*singleYW(1,1,1,1,:)) + sum(singleVW(1,1,3,1,:)*singleYW(1,1,3,1,:)) &
! 			 	+ (coupleVW(1,1,1,1,1)*coupleYW(1,1,1,1,1)) + (coupleVW(1,1,1,3,1)*coupleYW(1,1,1,3,1)) &
! 			 	+ (coupleVW(1,1,3,1,1)*coupleYW(1,1,3,1,1)) + (coupleVW(1,1,3,3,1)*coupleYW(1,1,3,3,1)) ) &
! 			 	/ (sum(singleYW(1,1,:,1,:))+sum(coupleYW(1,1,:,:,1)))

! veil_welfare_id = ( sum(singleVW(1,1,1,1,:)*singleYW(1,1,1,1,:)) + sum(singleVW(1,1,3,1,:)*singleYW(1,1,3,1,:)) &
! 				+ (marriageVW(1,1,1,1,1,1)*coupleYW(1,1,1,1,1)) + (marriageVW(1,1,1,3,1,1)*coupleYW(1,1,1,3,1)) + (marriageVW(1,1,1,1,1,2)*coupleYW(1,1,1,1,1)) + (marriageVW(1,1,1,3,1,2)*coupleYW(1,1,1,3,1)) &			
! 				+ (marriageVW(1,1,3,1,1,1)*coupleYW(1,1,3,1,1)) + (marriageVW(1,1,3,3,1,1)*coupleYW(1,1,3,3,1)) + (marriageVW(1,1,3,1,1,2)*coupleYW(1,1,3,1,1)) + (marriageVW(1,1,3,3,1,2)*coupleYW(1,1,3,3,1)) ) &
! 				/ (sum(singleYW(1,1,:,1,:))+2*sum(coupleYW(1,1,:,:,1)))

ALLOCATE( temp_retire_single_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )
ALLOCATE( retire_single_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )
ALLOCATE( temp_retire_couple_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )
ALLOCATE( retire_couple_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )

ALLOCATE( temp_single_util_LS(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( single_util_LS(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( temp_single_util_C(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( single_util_C(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( temp_couple_util_LS(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
ALLOCATE( couple_util_LS(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
ALLOCATE( temp_couple_util_C(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
ALLOCATE( couple_util_C(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )

print*, 'source welfare', source_welfare


IF (source_welfare==0) THEN 
	ALLOCATE( bench_singleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) ) 
	ALLOCATE( bench_single_VR(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) ) 
	ALLOCATE( bench_singleYR(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) ) 
	ALLOCATE( bench_retire_single_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) ) 
	ALLOCATE( bench_singleIDCWC(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_singleIDCWN(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_single_VW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_singleYW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_single_util_C(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_single_util_LS(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )

	ALLOCATE( bench_coupleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )
	ALLOCATE( bench_couple_VR(RETAGE:MAXAGE,NGRIDA,NGRIDEH) )
	ALLOCATE( bench_coupleYR(RETAGE:MAXAGE,NGRIDA,NGRIDEH) )
	ALLOCATE( bench_retire_couple_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )
	ALLOCATE( bench_coupleIDCWC(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( bench_coupleIDCWN(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( bench_couple_VW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
	ALLOCATE( bench_coupleYW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
	ALLOCATE( bench_couple_util_C(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( bench_couple_util_LS(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
END IF 


temp_retire_single_util_C(:,:,:,:) = 0.0
retire_single_util_C(:,:,:,:) = 0.0
temp_retire_couple_util_C(:,:,:,:) = 0.0
retire_couple_util_C(:,:,:,:) = 0.0

temp_single_util_LS(:,:,:,:,:) = 0.0
single_util_LS(:,:,:,:,:) = 0.0
temp_single_util_C(:,:,:,:,:) = 0.0
single_util_C(:,:,:,:,:) = 0.0
temp_couple_util_LS(:,:,:,:,:,:) = 0.0
couple_util_LS(:,:,:,:,:) = 0.0
temp_couple_util_C(:,:,:,:,:,:) = 0.0
couple_util_C(:,:,:,:,:,:) = 0.0

single_avg_cons_incomethreshold(:,:,:) = 0.0
single_avg_labor_incomethreshold(:,:,:) = 0.0
single_avg_val_incomethreshold(:,:,:) = 0.0
single_dist_incomethreshold(:,:,:) = 0.0
single_workingdist_incomethreshold(:,:,:) = 0.0

couple_avg_cons_incomethreshold(:,:,:) = 0.0
couple_avg_labor_incomethreshold(:,:,:) = 0.0
couple_avg_val_incomethreshold(:,:,:) = 0.0
couple_dist_incomethreshold(:,:,:) = 0.0
couple_workingdist_incomethreshold(:,:,:) = 0.0


util_welfare_id = 0.0

!********************************************************CRRA Utility******************************************************************

! ! Single retiree
! AGE = MAXAGE
!     DO IA=1,NGRIDA
! 		DO IE=1,NGRIDEH
! 			DO IG =1,2

! 				! TINCOME = SS(IE) + R*A(IA)

! 				! IF (TINCOME<=incomethreshold80) THEN
! 				! 	j=1
! 				! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 				! 	j=2
! 				! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 				! 	j=3
! 				! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 				! 	j=4
! 				! ELSEIF (TINCOME>incomethreshold20) THEN 
! 				! 	j=5
! 				! END IF 
			

! 				temp_retire_single_util_C(AGE,IA,IE,IG) = (singleIDCRC(AGE,IA,IE,IG)**(1-sigma))/(1-sigma) 
! 				retire_single_util_C(AGE,IA,IE,IG) =  temp_retire_single_util_C(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG) 
! 				util_welfare_id = util_welfare_id + retire_single_util_C(AGE,IA,IE,IG)

! 				! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCRC(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG)
! 				! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + 0.0
! 				! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + retire_single_util_C(AGE,IA,IE,IG)
! 				! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYR(AGE,IA,IE,IG)

! 				IF (source_welfare==0) THEN 
! 					bench_singleIDCRC(AGE,IA,IE,IG) = singleIDCRC(AGE,IA,IE,IG)
! 					bench_single_VR(AGE,IA,IE,IG) = temp_retire_single_util_C(AGE,IA,IE,IG)
! 					bench_singleYR(AGE,IA,IE,IG) = singleYR(AGE,IA,IE,IG)
! 					bench_retire_single_util_C(AGE,IA,IE,IG) = retire_single_util_C(AGE,IA,IE,IG)							
! 				END IF 

! 			END DO 
!     	END DO
! 	END DO 

! DO AGE = MAXAGE-1,RETAGE,-1
!     DO IA=1,NGRIDA
! 		DO IE=1,NGRIDEH
! 			DO IG =1,2

! 				JA = singleIDCRA(AGE,IA,IE,IG)

! 				! TINCOME = SS(IE) + R*A(IA)

! 				! IF (TINCOME<=incomethreshold80) THEN
! 				! 	j=1
! 				! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 				! 	j=2
! 				! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 				! 	j=3
! 				! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 				! 	j=4
! 				! ELSEIF (TINCOME>incomethreshold20) THEN 
! 				! 	j=5
! 				! END IF

! 				temp_retire_single_util_C(AGE,IA,IE,IG) =  (singleIDCRC(AGE,IA,IE,IG)**(1-sigma))/(1-sigma) + BETA*temp_retire_single_util_C(AGE+1,JA,IE,IG) 
! 				retire_single_util_C(AGE,IA,IE,IG) =  temp_retire_single_util_C(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG) 
! 				util_welfare_id = util_welfare_id + retire_single_util_C(AGE,IA,IE,IG)	

! 				! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCRC(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG)
! 				! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + 0.0
! 				! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + retire_single_util_C(AGE,IA,IE,IG)
! 				! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYR(AGE,IA,IE,IG)
				
! 				IF (source_welfare==0) THEN
! 					bench_singleIDCRC(AGE,IA,IE,IG) = singleIDCRC(AGE,IA,IE,IG)
! 					bench_single_VR(AGE,IA,IE,IG) = temp_retire_single_util_C(AGE,IA,IE,IG)
! 					bench_singleYR(AGE,IA,IE,IG) = singleYR(AGE,IA,IE,IG)	
! 					bench_retire_single_util_C(AGE,IA,IE,IG) = retire_single_util_C(AGE,IA,IE,IG)	
! 				END IF 								

! 			END DO 
! 		END DO 
!     END DO
! END DO 


! AGE=RETAGE-1
!     DO IA=1,NGRIDA
!         DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 				DO IG =1,2

! 					JA = singleIDCWA(AGE,IA,IS,IE,IG)
! 					JN = singleIDCWN(AGE,IA,IS,IE,IG)
! 					! INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
! 					! TINCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + R*A(IA)

! 					! IF (TINCOME<=incomethreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (TINCOME>incomethreshold20) THEN 
! 					! 	j=5
! 					! END IF

! 					! IF (INCOME<=earningthreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (INCOME>earningthreshold20) THEN 
! 					! 	j=5
! 					! END IF 

					
! 					IF (IG==1) THEN 				
! 						temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male)
! 						single_util_LS(AGE,IA,IS,IE,IG) =  temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
! 					ELSEIF (IG==2) THEN 
! 						temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female)
! 						single_util_LS(AGE,IA,IS,IE,IG) =  temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
! 					END IF
														
! 					! EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE 
! 					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 
! 						    ! discount_V = discount_V + (BETA*( singleVR(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVR(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ))*singleYW(AGE,IA,IS,IE,IG)
! 							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*( temp_retire_single_util_C(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_single_util_C(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
! 							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
																						
! 							EXIT 
                
! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH
! 							! discount_V = discount_V + (BETA*singleVR(AGE+1,JA,JE,IG))*singleYW(AGE,IA,IS,IE,IG)
! 							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*temp_retire_single_util_C(AGE+1,JA,JE,IG) 
! 							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

! 							EXIT

! 						END IF
! 					END DO

! 					util_welfare_id = util_welfare_id + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)

! 					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCWC(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
! 					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)
! 					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
! 					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)
! 					! single_workingdist_incomethreshold(AGE,j,IG) = single_workingdist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)	

! 					IF (source_welfare==0) THEN
! 						bench_singleIDCWC(AGE,IA,IS,IE,IG) = singleIDCWC(AGE,IA,IS,IE,IG)
! 						bench_singleIDCWN(AGE,IA,IS,IE,IG) = singleIDCWN(AGE,IA,IS,IE,IG)
! 						! bench_single_VW(AGE,IA,IS,IE,IG) = (single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG))/singleYW(AGE,IA,IS,IE,IG)	
! 						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)	
! 						bench_singleYW(AGE,IA,IS,IE,IG) = singleYW(AGE,IA,IS,IE,IG)
! 						bench_single_util_C(AGE,IA,IS,IE,IG) = single_util_C(AGE,IA,IS,IE,IG)
! 						bench_single_util_LS(AGE,IA,IS,IE,IG) = single_util_LS(AGE,IA,IS,IE,IG)
! 					END IF 

! 				END DO
!         	END DO
!     	END DO
! 	END DO


! DO AGE=RETAGE-2,1,-1
!     DO IA=1,NGRIDA
!         DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 				DO IG =1,2

! 					JA = singleIDCWA(AGE,IA,IS,IE,IG)
! 					JN = singleIDCWN(AGE,IA,IS,IE,IG)
! 					! INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
! 					! TINCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + R*A(IA)

! 					! IF (TINCOME<=incomethreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (TINCOME>incomethreshold20) THEN 
! 					! 	j=5
! 					! END IF		

! 					! IF (INCOME<=earningthreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (INCOME>earningthreshold20) THEN 
! 					! 	j=5
! 					! END IF 			
					
! 					! EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE
! 					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 
! 						    ! discount_V = discount_V + (BETA*sum( P(IS,:,IG)*( singleVW(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVW(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))*singleYW(AGE,IA,IS,IE,IG)
! 							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*sum( P(IS,:,IG)*( temp_single_util_C(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_C(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
! 							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
							
! 							IF (IG==1) THEN 				
! 								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum( P(IS,:,IG)*( temp_single_util_LS(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_LS(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
! 								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
! 							ELSEIF (IG==2) THEN 
! 								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum( P(IS,:,IG)*( temp_single_util_LS(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_LS(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
! 								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
! 							END IF
							
! 							EXIT 
                
! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH
! 							! discount_V = discount_V + (BETA*sum( P(IS,:,IG)*singleVW(AGE+1,JA,:,JE,IG) ))*singleYW(AGE,IA,IS,IE,IG)
! 							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*sum( P(IS,:,IG)*temp_single_util_C(AGE+1,JA,:,JE,IG) )
! 							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

! 							IF (IG==1) THEN 				
! 								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum( P(IS,:,IG)*temp_single_util_LS(AGE+1,JA,:,JE,IG) )
! 								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
! 							ELSEIF (IG==2) THEN 
! 								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum( P(IS,:,IG)*temp_single_util_LS(AGE+1,JA,:,JE,IG) )
! 								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
! 							END IF

! 							EXIT

! 						END IF
! 					END DO

! 					util_welfare_id = util_welfare_id + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)

! 					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCWC(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
! 					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)
! 					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
! 					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)
! 					! single_workingdist_incomethreshold(AGE,j,IG) = single_workingdist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)

! 					IF (source_welfare==0) THEN
! 						bench_singleIDCWC(AGE,IA,IS,IE,IG) = singleIDCWC(AGE,IA,IS,IE,IG)
! 						bench_singleIDCWN(AGE,IA,IS,IE,IG) = singleIDCWN(AGE,IA,IS,IE,IG)
! 						! bench_single_VW(AGE,IA,IS,IE,IG) = (single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG))/singleYW(AGE,IA,IS,IE,IG)	
! 						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)	
! 						bench_singleYW(AGE,IA,IS,IE,IG) = singleYW(AGE,IA,IS,IE,IG)
! 						bench_single_util_C(AGE,IA,IS,IE,IG) = single_util_C(AGE,IA,IS,IE,IG)
! 						bench_single_util_LS(AGE,IA,IS,IE,IG) = single_util_LS(AGE,IA,IS,IE,IG)
! 					END IF  

! 				END DO 
!             END DO
!         END DO
!     END DO
! END DO


! ! Couple retiree

! AGE = MAXAGE
! 	DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH

! 			! TINCOME = 2*SS(IE) + R*A(IA)

! 			! 	IF (TINCOME<=incomethreshold80) THEN
! 			! 		j=1
! 			! 	ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 			! 		j=2
! 			! 	ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 			! 		j=3
! 			! 	ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 			! 		j=4
! 			! 	ELSEIF (TINCOME>incomethreshold20) THEN 
! 			! 		j=5
! 			! 	END IF

! 			DO IG =1,2

! 				temp_retire_couple_util_C(AGE,IA,IE,IG) = ((coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma)
! 				retire_couple_util_C(AGE,IA,IE,IG) =  temp_retire_couple_util_C(AGE,IA,IE,IG)*coupleYR(AGE,IA,IE) 		
! 				util_welfare_id = util_welfare_id +	retire_couple_util_C(AGE,IA,IE,IG)
			
! 			END DO 

! 			! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
! 			! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
! 			! couple_avg_labor_incomethreshold(AGE,j,:) = couple_avg_labor_incomethreshold(AGE,j,:) + 0.0		
! 			! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + retire_couple_util_C(AGE,IA,IE,1)
! 			! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + retire_couple_util_C(AGE,IA,IE,2)
! 			! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYR(AGE,IA,IE)	
! 			! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYR(AGE,IA,IE)

! 			IF (source_welfare==0) THEN
! 				bench_coupleIDCRC(AGE,IA,IE,1) = coupleIDCRC(AGE,IA,IE)/eta
! 				bench_coupleIDCRC(AGE,IA,IE,2) = coupleIDCRC(AGE,IA,IE)/eta
! 				bench_couple_VR(AGE,IA,IE,1) = temp_retire_couple_util_C(AGE,IA,IE,1)
! 				bench_couple_VR(AGE,IA,IE,2) = temp_retire_couple_util_C(AGE,IA,IE,2)
! 				bench_coupleYR(AGE,IA,IE) = coupleYR(AGE,IA,IE)
! 				bench_retire_couple_util_C(AGE,IA,IE,1) = retire_couple_util_C(AGE,IA,IE,1)
! 				bench_retire_couple_util_C(AGE,IA,IE,2) = retire_couple_util_C(AGE,IA,IE,2)
! 			END IF 

! 		END DO 
! 	END DO 


! DO AGE = MAXAGE-1,RETAGE,-1
!     DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH

! 			JA = coupleIDCRA(AGE,IA,IE)

! 			! TINCOME = 2*SS(IE) + R*A(IA)

! 			! IF (TINCOME<=incomethreshold80) THEN
! 			! 	j=1
! 			! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 			! 	j=2
! 			! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 			! 	j=3
! 			! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 			! 	j=4
! 			! ELSEIF (TINCOME>incomethreshold20) THEN 
! 			! 	j=5
! 			! END IF
			
! 			temp_retire_couple_util_C(AGE,IA,IE,1) =  ((coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma) + BETA*S(AGE,1)*S(AGE,2)*temp_retire_couple_util_C(AGE+1,JA,IE,1) &
! 														+ BETA*S(AGE,1)*(1-S(AGE,2))*temp_retire_single_util_C(AGE+1,JA,IE,1) 
												

! 			temp_retire_couple_util_C(AGE,IA,IE,2) =  ((coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma) + BETA*S(AGE,1)*S(AGE,2)*temp_retire_couple_util_C(AGE+1,JA,IE,2) &
! 														+ BETA*S(AGE,2)*(1-S(AGE,1))*temp_retire_single_util_C(AGE+1,JA,IE,2)
												

! 			retire_couple_util_C(AGE,IA,IE,1) =  temp_retire_couple_util_C(AGE,IA,IE,1)*coupleYR(AGE,IA,IE) 
! 			retire_couple_util_C(AGE,IA,IE,2) =  temp_retire_couple_util_C(AGE,IA,IE,2)*coupleYR(AGE,IA,IE) 
			
! 			util_welfare_id = util_welfare_id +	retire_couple_util_C(AGE,IA,IE,1) +	retire_couple_util_C(AGE,IA,IE,2)	

! 			! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
! 			! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
! 			! couple_avg_labor_incomethreshold(AGE,j,:) = couple_avg_labor_incomethreshold(AGE,j,:) + 0.0		
! 			! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + retire_couple_util_C(AGE,IA,IE,1)
! 			! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + retire_couple_util_C(AGE,IA,IE,2)
! 			! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYR(AGE,IA,IE)	
! 			! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYR(AGE,IA,IE)	

! 			IF (source_welfare==0) THEN
! 				bench_coupleIDCRC(AGE,IA,IE,1) = coupleIDCRC(AGE,IA,IE)/eta
! 				bench_coupleIDCRC(AGE,IA,IE,2) = coupleIDCRC(AGE,IA,IE)/eta
! 				bench_couple_VR(AGE,IA,IE,1) = temp_retire_couple_util_C(AGE,IA,IE,1)
! 				bench_couple_VR(AGE,IA,IE,2) = temp_retire_couple_util_C(AGE,IA,IE,2)
! 				bench_coupleYR(AGE,IA,IE) = coupleYR(AGE,IA,IE)	
! 				bench_retire_couple_util_C(AGE,IA,IE,1) = retire_couple_util_C(AGE,IA,IE,1)
! 				bench_retire_couple_util_C(AGE,IA,IE,2) = retire_couple_util_C(AGE,IA,IE,2)
! 			END IF 					

! 		END DO 
!     END DO
! END DO 


! AGE = RETAGE-1
! 	DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
! 					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
! 					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
! 					! INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
! 					! TINCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)

! 					! IF (TINCOME<=incomethreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (TINCOME>incomethreshold20) THEN 
! 					! 	j=5
! 					! END IF

! 					! IF (INCOME<=earningthreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (INCOME>earningthreshold20) THEN 
! 					! 	j=5
! 					! END IF

! 					! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female)
! 					! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) 
! 					temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female)
! 					couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)
					
! 					! EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0/5.0)/AGE 
! 					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0)/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 
							
! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*( temp_retire_couple_util_C(AGE+1,JA,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*( temp_retire_couple_util_C(AGE+1,JA,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
! 							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
! 							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
														
! 							EXIT   

! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH  
							
! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*temp_retire_couple_util_C(AGE+1,JA,JE,1)
! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*temp_retire_couple_util_C(AGE+1,JA,JE,2) 
! 							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
! 							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
						
! 							EXIT

! 						END IF
! 					END DO 

! 					util_welfare_id = util_welfare_id + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)

! 					! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_labor_incomethreshold(AGE,j,1) = couple_avg_labor_incomethreshold(AGE,j,1) + N(JN1)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_labor_incomethreshold(AGE,j,2) = couple_avg_labor_incomethreshold(AGE,j,2) + N(JN2)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + couple_util_C(AGE,IA,IS1,IS2,IE,1)+(-theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + couple_util_C(AGE,IA,IS1,IS2,IE,2)+(-theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_workingdist_incomethreshold(AGE,j,1) = couple_workingdist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_workingdist_incomethreshold(AGE,j,2) = couple_workingdist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)

! 					IF (source_welfare==0) THEN
! 						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,1) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
! 						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,2) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
! 						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
! 						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
! 						! bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+(-theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))
! 						! bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+(-theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))	
! 						bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
! 						bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)				
! 						bench_coupleYW(AGE,IA,IS1,IS2,IE) = coupleYW(AGE,IA,IS1,IS2,IE)
! 						bench_couple_util_C(AGE,IA,IS1,IS2,IE,1) = couple_util_C(AGE,IA,IS1,IS2,IE,1)
! 						bench_couple_util_C(AGE,IA,IS1,IS2,IE,2) = couple_util_C(AGE,IA,IS1,IS2,IE,2)
! 						bench_couple_util_LS(AGE,IA,IS1,IS2,IE) = couple_util_LS(AGE,IA,IS1,IS2,IE)
! 					END IF 

! 				END DO
!        	 	END DO 
!     	END DO
! 	END DO 


! DO AGE = RETAGE-2,1,-1
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
! 					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
! 					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
! 					! INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)	
! 					! TINCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)

! 					! IF (TINCOME<=incomethreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (TINCOME>incomethreshold20) THEN 
! 					! 	j=5
! 					! END IF

! 					! IF (INCOME<=earningthreshold80) THEN
! 					! 	j=1
! 					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
! 					! 	j=2
! 					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
! 					! 	j=3
! 					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
! 					! 	j=4
! 					! ELSEIF (INCOME>earningthreshold20) THEN 
! 					! 	j=5
! 					! END IF				
					
! 					! EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0/5.0)/AGE 
! 					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0)/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 

! 							sum_temp1 = 0.0
! 							sum_temp2 = 0.0
! 							DO NEWIS1 = 1,nn		
! 								DO NEWIS2 = 1,nn		  			
								
! 									IF (IS1==IS2) THEN
! 										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 									ELSE
! 										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 									END IF
								
! 									sum_temp1 = sum_temp1 + P_joint*( temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
! 									sum_temp2 = sum_temp2 + P_joint*( temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
								
! 								END DO 
! 							END DO

! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp1
! 							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp2
! 							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)

! 							! sum_temp = 0.0
! 							! DO NEWIS = 1,nn				  			
! 							! 	sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
! 							! END DO

! 							! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp
! 							! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)

! 							sum_temp1 = 0.0
! 							sum_temp2 = 0.0
! 							DO NEWIS1 = 1,nn
! 								DO NEWIS2 = 1,nn	

! 									IF (IS1==IS2) THEN
! 										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 									ELSE
! 										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 									END IF

! 									sum_temp1 = sum_temp1 + P_joint*( temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
! 									sum_temp2 = sum_temp2 + P_joint*( temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )

! 								END DO 
! 							END DO

! 							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum_temp1 
! 							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp2
! 							couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)

! 							EXIT   

! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH

! 							sum_temp1 = 0.0
! 							sum_temp2 = 0.0
! 							DO NEWIS1 = 1,nn
! 								DO NEWIS2 = 1,nn	

! 									IF (IS1==IS2) THEN
! 										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 									ELSE
! 										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 									END IF

! 									sum_temp1 = sum_temp1 + P_joint*temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,1)  
! 									sum_temp2 = sum_temp2 + P_joint*temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,2)  

! 								END DO 
! 							END DO

! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp1
! 							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
! 							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp2
! 							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)

! 							! sum_temp = 0.0
! 							! DO NEWIS = 1,nn				  			
! 							! 	sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE)  ))
! 							! END DO

! 							! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp
! 							! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)

! 							sum_temp1 = 0.0
! 							sum_temp2 = 0.0
! 							DO NEWIS1 = 1,nn
! 								DO NEWIS2 = 1,nn	

! 									IF (IS1==IS2) THEN
! 										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 									ELSE
! 										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 									END IF

! 									sum_temp1 = sum_temp1 + P_joint*temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,1)  
! 									sum_temp2 = sum_temp2 + P_joint*temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,2)  

! 								END DO 
! 							END DO

! 							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum_temp1
! 							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp2
! 							couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)
						
! 							EXIT

! 						END IF
! 					END DO 

! 					util_welfare_id = util_welfare_id + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)

! 					! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_labor_incomethreshold(AGE,j,1) = couple_avg_labor_incomethreshold(AGE,j,1) + N(JN1)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_labor_incomethreshold(AGE,j,2) = couple_avg_labor_incomethreshold(AGE,j,2) + N(JN2)*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + couple_util_C(AGE,IA,IS1,IS2,IE,1)+(-theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + couple_util_C(AGE,IA,IS1,IS2,IE,2)+(-theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))*coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_workingdist_incomethreshold(AGE,j,1) = couple_workingdist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
! 					! couple_workingdist_incomethreshold(AGE,j,2) = couple_workingdist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)

! 					IF (source_welfare==0) THEN
! 						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,1) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
! 						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,2) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
! 						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
! 						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
! 						! bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+(-theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))
! 						! bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+(-theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))
! 						bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
! 						bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)				
! 						bench_coupleYW(AGE,IA,IS1,IS2,IE) = coupleYW(AGE,IA,IS1,IS2,IE)
! 						bench_couple_util_C(AGE,IA,IS1,IS2,IE,1) = couple_util_C(AGE,IA,IS1,IS2,IE,1)
! 						bench_couple_util_C(AGE,IA,IS1,IS2,IE,2) = couple_util_C(AGE,IA,IS1,IS2,IE,2)
! 						bench_couple_util_LS(AGE,IA,IS1,IS2,IE) = couple_util_LS(AGE,IA,IS1,IS2,IE)
! 					END IF 

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO 



! ! DO AGE=1,MAXAGE
! ! 	DO i=1,5
! ! 		DO IG=1,2
! ! 			single_avg_cons_incomethreshold(AGE,i,IG) = single_avg_cons_incomethreshold(AGE,i,IG)/single_dist_incomethreshold(AGE,i,IG)
! ! 			single_avg_labor_incomethreshold(AGE,i,IG) = single_avg_labor_incomethreshold(AGE,i,IG)/single_workingdist_incomethreshold(AGE,i,IG)
! ! 			couple_avg_cons_incomethreshold(AGE,i,IG) = couple_avg_cons_incomethreshold(AGE,i,IG)/couple_dist_incomethreshold(AGE,i,IG)
! ! 			couple_avg_labor_incomethreshold(AGE,i,IG) = couple_avg_labor_incomethreshold(AGE,i,IG)/couple_workingdist_incomethreshold(AGE,i,IG)
! ! 		END DO 
! ! 	END DO 
! ! END DO 


! ! DO i=1,5
! ! 	DO IG=1,2
! ! 		single_avg_cons_incomethreshold_21_35(i,IG) = sum(single_avg_cons_incomethreshold(1:3,i,IG))/sum(single_dist_incomethreshold(1:3,i,IG))
! ! 		couple_avg_cons_incomethreshold_21_35(i,IG) = sum(couple_avg_cons_incomethreshold(1:3,i,IG))/sum(couple_dist_incomethreshold(1:3,i,IG))
! ! 		single_avg_val_incomethreshold_21_35(i,IG) = sum(single_avg_val_incomethreshold(1:3,i,IG))/sum(single_dist_incomethreshold(1:3,i,IG))
! ! 		couple_avg_val_incomethreshold_21_35(i,IG) = sum(couple_avg_val_incomethreshold(1:3,i,IG))/sum(couple_dist_incomethreshold(1:3,i,IG))

! ! 		single_avg_cons_incomethreshold_36_50(i,IG) = sum(single_avg_cons_incomethreshold(4:6,i,IG))/sum(single_dist_incomethreshold(4:6,i,IG))
! ! 		couple_avg_cons_incomethreshold_36_50(i,IG) = sum(couple_avg_cons_incomethreshold(4:6,i,IG))/sum(couple_dist_incomethreshold(4:6,i,IG))
! ! 		single_avg_val_incomethreshold_36_50(i,IG) = sum(single_avg_val_incomethreshold(4:6,i,IG))/sum(single_dist_incomethreshold(4:6,i,IG))
! ! 		couple_avg_val_incomethreshold_36_50(i,IG) = sum(couple_avg_val_incomethreshold(4:6,i,IG))/sum(couple_dist_incomethreshold(4:6,i,IG))

! ! 		single_avg_cons_incomethreshold_51_65(i,IG) = sum(single_avg_cons_incomethreshold(7:9,i,IG))/sum(single_dist_incomethreshold(7:9,i,IG))
! ! 		couple_avg_cons_incomethreshold_51_65(i,IG) = sum(couple_avg_cons_incomethreshold(7:9,i,IG))/sum(couple_dist_incomethreshold(7:9,i,IG))
! ! 		single_avg_val_incomethreshold_51_65(i,IG) = sum(single_avg_val_incomethreshold(7:9,i,IG))/sum(single_dist_incomethreshold(7:9,i,IG))
! ! 		couple_avg_val_incomethreshold_51_65(i,IG) = sum(couple_avg_val_incomethreshold(7:9,i,IG))/sum(couple_dist_incomethreshold(7:9,i,IG))

! ! 		single_avg_cons_incomethreshold_66_80(i,IG) = sum(single_avg_cons_incomethreshold(10:12,i,IG))/sum(single_dist_incomethreshold(10:12,i,IG))
! ! 		couple_avg_cons_incomethreshold_66_80(i,IG) = sum(couple_avg_cons_incomethreshold(10:12,i,IG))/sum(couple_dist_incomethreshold(10:12,i,IG))
! ! 		single_avg_val_incomethreshold_66_80(i,IG) = sum(single_avg_val_incomethreshold(10:12,i,IG))/sum(single_dist_incomethreshold(10:12,i,IG))
! ! 		couple_avg_val_incomethreshold_66_80(i,IG) = sum(couple_avg_val_incomethreshold(10:12,i,IG))/sum(couple_dist_incomethreshold(10:12,i,IG))

! ! 		single_avg_cons_incomethreshold_81_100(i,IG) = sum(single_avg_cons_incomethreshold(13:16,i,IG))/sum(single_dist_incomethreshold(13:16,i,IG))
! ! 		couple_avg_cons_incomethreshold_81_100(i,IG) = sum(couple_avg_cons_incomethreshold(13:16,i,IG))/sum(couple_dist_incomethreshold(13:16,i,IG))
! ! 		single_avg_val_incomethreshold_81_100(i,IG) = sum(single_avg_val_incomethreshold(13:16,i,IG))/sum(single_dist_incomethreshold(13:16,i,IG))
! ! 		couple_avg_val_incomethreshold_81_100(i,IG) = sum(couple_avg_val_incomethreshold(13:16,i,IG))/sum(couple_dist_incomethreshold(13:16,i,IG))
! ! 	END DO 
! ! END DO 


! ! DO i=1,5
! ! 	DO IG=1,2
! ! 		single_avg_labor_incomethreshold_21_35(i,IG) = sum(single_avg_labor_incomethreshold(1:3,i,IG))/sum(single_workingdist_incomethreshold(1:3,i,IG))
! ! 		couple_avg_labor_incomethreshold_21_35(i,IG) = sum(couple_avg_labor_incomethreshold(1:3,i,IG))/sum(couple_workingdist_incomethreshold(1:3,i,IG))

! ! 		single_avg_labor_incomethreshold_36_50(i,IG) = sum(single_avg_labor_incomethreshold(4:6,i,IG))/sum(single_workingdist_incomethreshold(4:6,i,IG))
! ! 		couple_avg_labor_incomethreshold_36_50(i,IG) = sum(couple_avg_labor_incomethreshold(4:6,i,IG))/sum(couple_workingdist_incomethreshold(4:6,i,IG))

! ! 		single_avg_labor_incomethreshold_51_65(i,IG) = sum(single_avg_labor_incomethreshold(7:9,i,IG))/sum(single_workingdist_incomethreshold(7:9,i,IG))
! ! 		couple_avg_labor_incomethreshold_51_65(i,IG) = sum(couple_avg_labor_incomethreshold(7:9,i,IG))/sum(couple_workingdist_incomethreshold(7:9,i,IG))
! ! 	END DO 
! ! END DO 


! veil_welfare_id = (SUM(couple_util_C(1,:,:,:,:,:)) + SUM(couple_util_LS(1,:,:,:,:)))/(sum(singleYW(1,:,:,:,:))+2*sum(coupleYW(1,:,:,:,:)))

! ! Method by Baris&Markus 2014 RED:
! ! PARETIAN WELFARE: Aggregate consumption equivalents before time aggregation.
! ! Notes: Assume everyone gets average leisure, lbar, and solve for C(k,z) in 
! ! C^(1-sigma)/(1-sigma) + theta (1-lbar)^(1-eps)/(1-eps) = (1-beta)V(k,z)

!*******************************************************This part is not correct*******************************************************************
! ! Single 
! agglabpath_singlemale = 0.0
! agglabpath_singlefemale = 0.0
! DO AGE=1,RETAGE-1
! 	agglabpath_singlemale = agglabpath_singlemale + BETA**(AGE-1) * (LLONG_single(AGE,1))**(1.D0+sigma_lab_male)/(1.D0+sigma_lab_male)
! 	agglabpath_singlefemale = agglabpath_singlefemale + BETA**(AGE-1) * (LLONG_single(AGE,2))**(1.D0+sigma_lab_female)/(1.D0+sigma_lab_female)
! END DO


! certeq_singlemale(1)=((singleVW(1,1,1,1,1)+theta_single_male*agglabpath_singlemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_singlemale(3)=((singleVW(1,1,3,1,1)+theta_single_male*agglabpath_singlemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))

! certeq_singlefemale(1)=((singleVW(1,1,1,1,2)+theta_single_female*agglabpath_singlefemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_singlefemale(3)=((singleVW(1,1,3,1,2)+theta_single_female*agglabpath_singlefemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))

! aggcerteq_singlemale = certeq_singlemale(1)*singleYW(1,1,1,1,1) + certeq_singlemale(3)*singleYW(1,1,3,1,1)   
! aggcerteq_singlefemale = certeq_singlefemale(1)*singleYW(1,1,1,1,2) + certeq_singlefemale(3)*singleYW(1,1,3,1,2) 

! par_welfare_singlemale = (aggcerteq_singlemale**(1.0-sigma))/(1.0-sigma)-theta_single_male*agglabpath_singlemale
! par_welfare_singlefemale = (aggcerteq_singlefemale**(1.0-sigma))/(1.0-sigma)-theta_single_female*agglabpath_singlefemale

! ! Couple
! agglabpath_couplemale = 0.0
! agglabpath_couplefemale = 0.0
! DO AGE=1,RETAGE-1
! 	agglabpath_couplemale = agglabpath_couplemale + BETA**(AGE-1) * (LLONG_couple(AGE,1))**(1.D0+sigma_lab_male)/(1.D0+sigma_lab_male)
! 	agglabpath_couplefemale = agglabpath_couplefemale + BETA**(AGE-1) * (LLONG_couple(AGE,2))**(1.D0+sigma_lab_female)/(1.D0+sigma_lab_female)
! END DO

! !marriageVW(AGE,IA,IS1,IS2,IE,2
! certeq_couplemale(1,1)=eta*((marriageVW(1,1,1,1,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_couplemale(1,2)=eta*((marriageVW(1,1,1,2,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_couplemale(2,1)=eta*((marriageVW(1,1,2,1,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_couplemale(2,2)=eta*((marriageVW(1,1,2,2,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))

! certeq_couplefemale(1,1)=eta*((marriageVW(1,1,1,1,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_couplefemale(1,2)=eta*((marriageVW(1,1,1,2,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_couplefemale(2,1)=eta*((marriageVW(1,1,2,1,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))
! certeq_couplefemale(2,2)=eta*((marriageVW(1,1,2,2,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)*(1.0-sigma)/(1.0-BETA**MAXAGE))**(1/(1.0-sigma))

! aggcerteq_couplemale = certeq_couplemale(1,1)*coupleYW(1,1,1,1,1)+certeq_couplemale(1,2)*coupleYW(1,1,1,2,1)+certeq_couplemale(2,1)*coupleYW(1,1,2,1,1)+certeq_couplemale(2,2)*coupleYW(1,1,2,2,1)
! aggcerteq_couplefemale = certeq_couplefemale(1,1)*coupleYW(1,1,1,1,1)+certeq_couplefemale(1,2)*coupleYW(1,1,1,2,1)+certeq_couplefemale(2,1)*coupleYW(1,1,2,1,1)+certeq_couplefemale(2,2)*coupleYW(1,1,2,2,1)

! par_welfare_couple = (aggcerteq_couplemale**(1.0-sigma))/(1.0-sigma)-theta_married_male*agglabpath_couplemale + (aggcerteq_couplefemale**(1.0-sigma))/(1.0-sigma)-theta_married_female*agglabpath_couplefemale

! par_welfare = par_welfare_singlemale + par_welfare_singlefemale + par_welfare_couple

!**************************************************************************************************************************

! !***************************** Martin Floden 2001 JME *******************************

! ! Single
! DO IS=1,nn 
! 	certeqcons_singlemale(IS) = ( (1.0-BETA)*(1.0-sigma)*single_util_C(1,1,IS,1,1)/(1.0-BETA**MAXAGE) )**(1.0/(1.0-sigma))
! 	certeqlab_singlemale(IS) = ( (1.0-BETA)*(1.0+sigma_lab_male)*(- single_util_LS(1,1,IS,1,1))/(theta_single_male*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_male))
	
! 	certeqcons_singlefemale(IS) = ( (1.0-BETA)*(1.0-sigma)*single_util_C(1,1,IS,1,2)/(1.0-BETA**MAXAGE) )**(1.0/(1.0-sigma))
! 	certeqlab_singlefemale(IS) = ( (1.0-BETA)*(1.0+sigma_lab_female)*(- single_util_LS(1,1,IS,1,2))/(theta_single_female*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_female))
! END DO 

! agg_certeqcons_singlemale = sum(certeqcons_singlemale(:)*singleYW(1,1,:,1,1))
! agg_certeqlab_singlemale = sum(certeqlab_singlemale(:)*singleYW(1,1,:,1,1))
! agg_certeqcons_singlefemale = sum(certeqcons_singlefemale(:)*singleYW(1,1,:,1,2))
! agg_certeqlab_singlefemale = sum(certeqlab_singlefemale(:)*singleYW(1,1,:,1,2))

! V_certeq_singlemale = (agg_certeqcons_singlemale**(1.0-sigma))/(1.0-sigma) - theta_single_male*(agg_certeqlab_singlemale**(1.0+sigma_lab_male))/(1.0+sigma_lab_male)
! V_certeq_singlefemale = (agg_certeqcons_singlefemale**(1.0-sigma))/(1.0-sigma) - theta_single_female*(agg_certeqlab_singlefemale**(1.0+sigma_lab_female))/(1.0+sigma_lab_female)
! V_certeq_single = V_certeq_singlemale + V_certeq_singlefemale

! ! Couple
! DO IS1=1,nn
! 	DO IS2=1,nn
! 		certeqcons_couple(IS1,IS2,1) = eta*( (1.0-BETA)*(1.0-sigma)*couple_util_C(1,1,IS1,IS2,1,1)/(1.0-BETA**MAXAGE)/2.0 )**(1.0/(1.0-sigma))
! 		certeqcons_couple(IS1,IS2,2) = eta*( (1.0-BETA)*(1.0-sigma)*couple_util_C(1,1,IS1,IS2,1,2)/(1.0-BETA**MAXAGE)/2.0 )**(1.0/(1.0-sigma))

! 		certeqlab_couple(IS1,IS2,1) = ( (1.0-BETA)*(1.0+sigma_lab_male)*(- temp_couple_util_LS(1,1,IS1,IS2,1,1)*coupleYW(1,1,IS1,IS2,1))/(theta_married_male*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_male))
! 		certeqlab_couple(IS1,IS2,2) = ( (1.0-BETA)*(1.0+sigma_lab_female)*(- temp_couple_util_LS(1,1,IS1,IS2,1,2)*coupleYW(1,1,IS1,IS2,1))/(theta_married_female*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_female))
! 	END DO 
! END DO 

! DO IS1=1,nn
! 	agg_certeqcons_couple(1) = agg_certeqcons_couple(1) + sum(certeqcons_couple(IS1,:,1)*coupleYW(1,1,IS1,:,1))
! 	agg_certeqlab_couple(1) = agg_certeqlab_couple(1) + sum(certeqlab_couple(IS1,:,1))*coupleYW(1,1,IS1,:,1))

! 	agg_certeqcons_couple(2) = agg_certeqcons_couple(2) + sum(certeqcons_couple(IS1,:,2)*coupleYW(1,1,IS1,:,1))
! 	agg_certeqlab_couple(2) = agg_certeqlab_couple(2) + sum(certeqlab_couple(IS1,:,2))*coupleYW(1,1,IS1,:,2))
! END DO 

! V_certeq_couple(1) = ((agg_certeqcons_couple(1)/eta)**(1.0-sigma))/(1.0-sigma) - theta_married_male*(agg_certeqlab_couple(1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male)
! V_certeq_couple(2) = ((agg_certeqcons_couple(2)/eta)**(1.0-sigma))/(1.0-sigma) - theta_married_female*(agg_certeqlab_couple(2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female)


!********************************************************Log Utility******************************************************************

! Single retiree
AGE = MAXAGE
    DO IA=1,NGRIDA
		DO IE=1,NGRIDEH
			DO IG =1,2

				! TINCOME = SS(IE) + R*A(IA)

				! IF (TINCOME<=incomethreshold80) THEN
				! 	j=1
				! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
				! 	j=2
				! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
				! 	j=3
				! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
				! 	j=4
				! ELSEIF (TINCOME>incomethreshold20) THEN 
				! 	j=5
				! END IF 
			
			
				temp_retire_single_util_C(AGE,IA,IE,IG) = log(singleIDCRC(AGE,IA,IE,IG))
				retire_single_util_C(AGE,IA,IE,IG) =  temp_retire_single_util_C(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG) 
				util_welfare_id = util_welfare_id + retire_single_util_C(AGE,IA,IE,IG)

				! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCRC(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG)
				! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + 0.0
				! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + retire_single_util_C(AGE,IA,IE,IG)
				! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYR(AGE,IA,IE,IG)

				IF (source_welfare==0) THEN 
					bench_singleIDCRC(AGE,IA,IE,IG) = singleIDCRC(AGE,IA,IE,IG)
					bench_single_VR(AGE,IA,IE,IG) = temp_retire_single_util_C(AGE,IA,IE,IG)
					bench_singleYR(AGE,IA,IE,IG) = singleYR(AGE,IA,IE,IG)
					bench_retire_single_util_C(AGE,IA,IE,IG) = retire_single_util_C(AGE,IA,IE,IG)							
				END IF 

			END DO 
    	END DO
	END DO 

DO AGE = MAXAGE-1,RETAGE,-1
    DO IA=1,NGRIDA
		DO IE=1,NGRIDEH
			DO IG =1,2

				JA = singleIDCRA(AGE,IA,IE,IG)

				! TINCOME = SS(IE) + R*A(IA)

				! IF (TINCOME<=incomethreshold80) THEN
				! 	j=1
				! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
				! 	j=2
				! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
				! 	j=3
				! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
				! 	j=4
				! ELSEIF (TINCOME>incomethreshold20) THEN 
				! 	j=5
				! END IF

			
				temp_retire_single_util_C(AGE,IA,IE,IG) = log(singleIDCRC(AGE,IA,IE,IG)) + BETA*S(AGE,IG)*temp_retire_single_util_C(AGE+1,JA,IE,IG) 
				retire_single_util_C(AGE,IA,IE,IG) =  temp_retire_single_util_C(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG) 
				util_welfare_id = util_welfare_id + retire_single_util_C(AGE,IA,IE,IG)	

				! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCRC(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG)
				! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + 0.0
				! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + retire_single_util_C(AGE,IA,IE,IG)
				! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYR(AGE,IA,IE,IG)
				
				IF (source_welfare==0) THEN
					bench_singleIDCRC(AGE,IA,IE,IG) = singleIDCRC(AGE,IA,IE,IG)
					bench_single_VR(AGE,IA,IE,IG) = temp_retire_single_util_C(AGE,IA,IE,IG)
					bench_singleYR(AGE,IA,IE,IG) = singleYR(AGE,IA,IE,IG)	
					bench_retire_single_util_C(AGE,IA,IE,IG) = retire_single_util_C(AGE,IA,IE,IG)	
				END IF 								

			END DO 
		END DO 
    END DO
END DO 


AGE=RETAGE-1
    DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG =1,2

					JA = singleIDCWA(AGE,IA,IS,IE,IG)
					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					! INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
					! TINCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + R*A(IA)

					! IF (TINCOME<=incomethreshold80) THEN
					! 	j=1
					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
					! 	j=4
					! ELSEIF (TINCOME>incomethreshold20) THEN 
					! 	j=5
					! END IF

					! IF (INCOME<=earningthreshold80) THEN
					! 	j=1
					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
					! 	j=4
					! ELSEIF (INCOME>earningthreshold20) THEN 
					! 	j=5
					! END IF 

					
					IF (IG==1) THEN 							
						temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male)
						single_util_LS(AGE,IA,IS,IE,IG) =  temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
					ELSEIF (IG==2) THEN 
						temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female)
						single_util_LS(AGE,IA,IS,IE,IG) =  temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
					END IF
														
					! EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE 
					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
						    ! discount_V = discount_V + (BETA*( singleVR(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVR(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ))*singleYW(AGE,IA,IS,IE,IG)							
							temp_single_util_C(AGE,IA,IS,IE,IG) =  log(singleIDCWC(AGE,IA,IS,IE,IG)) + BETA*( temp_retire_single_util_C(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_single_util_C(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
																						
							EXIT 
                
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH
							! discount_V = discount_V + (BETA*singleVR(AGE+1,JA,JE,IG))*singleYW(AGE,IA,IS,IE,IG)
							
							temp_single_util_C(AGE,IA,IS,IE,IG) =  log(singleIDCWC(AGE,IA,IS,IE,IG)) + BETA*temp_retire_single_util_C(AGE+1,JA,JE,IG) 
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

							EXIT

						END IF
					END DO

					util_welfare_id = util_welfare_id + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)

					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCWC(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)
					! single_workingdist_incomethreshold(AGE,j,IG) = single_workingdist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)	

					IF (source_welfare==0) THEN
						bench_singleIDCWC(AGE,IA,IS,IE,IG) = singleIDCWC(AGE,IA,IS,IE,IG)
						bench_singleIDCWN(AGE,IA,IS,IE,IG) = singleIDCWN(AGE,IA,IS,IE,IG)
						! bench_single_VW(AGE,IA,IS,IE,IG) = (single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG))/singleYW(AGE,IA,IS,IE,IG)	
						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)	
						bench_singleYW(AGE,IA,IS,IE,IG) = singleYW(AGE,IA,IS,IE,IG)
						bench_single_util_C(AGE,IA,IS,IE,IG) = single_util_C(AGE,IA,IS,IE,IG)
						bench_single_util_LS(AGE,IA,IS,IE,IG) = single_util_LS(AGE,IA,IS,IE,IG)
					END IF 

				END DO
        	END DO
    	END DO
	END DO


DO AGE=RETAGE-2,1,-1
    DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG =1,2

					JA = singleIDCWA(AGE,IA,IS,IE,IG)
					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					! INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
					! TINCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + R*A(IA)

					! IF (TINCOME<=incomethreshold80) THEN
					! 	j=1
					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
					! 	j=4
					! ELSEIF (TINCOME>incomethreshold20) THEN 
					! 	j=5
					! END IF		

					! IF (INCOME<=earningthreshold80) THEN
					! 	j=1
					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
					! 	j=4
					! ELSEIF (INCOME>earningthreshold20) THEN 
					! 	j=5
					! END IF 			
					
					! EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE
					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
						    ! discount_V = discount_V + (BETA*sum( P(IS,:,IG)*( singleVW(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVW(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))*singleYW(AGE,IA,IS,IE,IG)
							
							temp_single_util_C(AGE,IA,IS,IE,IG) =  log(singleIDCWC(AGE,IA,IS,IE,IG)) + BETA*sum( P(IS,:,IG)*( temp_single_util_C(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_C(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
							
							IF (IG==1) THEN 				
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum( P(IS,:,IG)*( temp_single_util_LS(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_LS(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							ELSEIF (IG==2) THEN 
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum( P(IS,:,IG)*( temp_single_util_LS(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_LS(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							END IF
							
							EXIT 
                
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH
							! discount_V = discount_V + (BETA*sum( P(IS,:,IG)*singleVW(AGE+1,JA,:,JE,IG) ))*singleYW(AGE,IA,IS,IE,IG)
							
							temp_single_util_C(AGE,IA,IS,IE,IG) = log(singleIDCWC(AGE,IA,IS,IE,IG)) + BETA*sum( P(IS,:,IG)*temp_single_util_C(AGE+1,JA,:,JE,IG) )
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

							IF (IG==1) THEN 				
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum( P(IS,:,IG)*temp_single_util_LS(AGE+1,JA,:,JE,IG) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							ELSEIF (IG==2) THEN 
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum( P(IS,:,IG)*temp_single_util_LS(AGE+1,JA,:,JE,IG) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							END IF

							EXIT

						END IF
					END DO

					util_welfare_id = util_welfare_id + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)

					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCWC(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)
					! single_workingdist_incomethreshold(AGE,j,IG) = single_workingdist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)

					IF (source_welfare==0) THEN
						bench_singleIDCWC(AGE,IA,IS,IE,IG) = singleIDCWC(AGE,IA,IS,IE,IG)
						bench_singleIDCWN(AGE,IA,IS,IE,IG) = singleIDCWN(AGE,IA,IS,IE,IG)
						! bench_single_VW(AGE,IA,IS,IE,IG) = (single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG))/singleYW(AGE,IA,IS,IE,IG)	
						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)	
						bench_singleYW(AGE,IA,IS,IE,IG) = singleYW(AGE,IA,IS,IE,IG)
						bench_single_util_C(AGE,IA,IS,IE,IG) = single_util_C(AGE,IA,IS,IE,IG)
						bench_single_util_LS(AGE,IA,IS,IE,IG) = single_util_LS(AGE,IA,IS,IE,IG)
					END IF  

				END DO 
            END DO
        END DO
    END DO
END DO


! Couple retiree

AGE = MAXAGE
	DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

			! TINCOME = 2*SS(IE) + R*A(IA)

			! 	IF (TINCOME<=incomethreshold80) THEN
			! 		j=1
			! 	ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
			! 		j=2
			! 	ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
			! 		j=3
			! 	ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
			! 		j=4
			! 	ELSEIF (TINCOME>incomethreshold20) THEN 
			! 		j=5
			! 	END IF

			DO IG =1,2
				
				temp_retire_couple_util_C(AGE,IA,IE,IG) = log(coupleIDCRC(AGE,IA,IE)/eta)
				retire_couple_util_C(AGE,IA,IE,IG) =  temp_retire_couple_util_C(AGE,IA,IE,IG)*coupleYR(AGE,IA,IE) 		
				util_welfare_id = util_welfare_id +	retire_couple_util_C(AGE,IA,IE,IG)
			
			END DO 

			! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
			! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
			! couple_avg_labor_incomethreshold(AGE,j,:) = couple_avg_labor_incomethreshold(AGE,j,:) + 0.0		
			! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + retire_couple_util_C(AGE,IA,IE,1)
			! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + retire_couple_util_C(AGE,IA,IE,2)
			! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYR(AGE,IA,IE)	
			! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYR(AGE,IA,IE)

			IF (source_welfare==0) THEN
				bench_coupleIDCRC(AGE,IA,IE,1) = coupleIDCRC(AGE,IA,IE)/eta
				bench_coupleIDCRC(AGE,IA,IE,2) = coupleIDCRC(AGE,IA,IE)/eta
				! bench_couple_VR(AGE,IA,IE,1) = temp_retire_couple_util_C(AGE,IA,IE,1)
				! bench_couple_VR(AGE,IA,IE,2) = temp_retire_couple_util_C(AGE,IA,IE,2)
				bench_couple_VR(AGE,IA,IE) = coupleVR(AGE,IA,IE)
				bench_coupleYR(AGE,IA,IE) = coupleYR(AGE,IA,IE)
				bench_retire_couple_util_C(AGE,IA,IE,1) = retire_couple_util_C(AGE,IA,IE,1)
				bench_retire_couple_util_C(AGE,IA,IE,2) = retire_couple_util_C(AGE,IA,IE,2)
			END IF 

		END DO 
	END DO 


DO AGE = MAXAGE-1,RETAGE,-1
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

			JA = coupleIDCRA(AGE,IA,IE)

			! TINCOME = 2*SS(IE) + R*A(IA)

			! IF (TINCOME<=incomethreshold80) THEN
			! 	j=1
			! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
			! 	j=2
			! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
			! 	j=3
			! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
			! 	j=4
			! ELSEIF (TINCOME>incomethreshold20) THEN 
			! 	j=5
			! END IF
			
			temp_retire_couple_util_C(AGE,IA,IE,1) =  log(coupleIDCRC(AGE,IA,IE)/eta) + BETA*S(AGE,1)*S(AGE,2)*temp_retire_couple_util_C(AGE+1,JA,IE,1) &
														+ BETA*S(AGE,1)*(1-S(AGE,2))*temp_retire_single_util_C(AGE+1,JA,IE,1) 
												

			temp_retire_couple_util_C(AGE,IA,IE,2) =  log(coupleIDCRC(AGE,IA,IE)/eta) + BETA*S(AGE,1)*S(AGE,2)*temp_retire_couple_util_C(AGE+1,JA,IE,2) &
														+ BETA*S(AGE,2)*(1-S(AGE,1))*temp_retire_single_util_C(AGE+1,JA,IE,2)
												

			retire_couple_util_C(AGE,IA,IE,1) =  temp_retire_couple_util_C(AGE,IA,IE,1)*coupleYR(AGE,IA,IE) 
			retire_couple_util_C(AGE,IA,IE,2) =  temp_retire_couple_util_C(AGE,IA,IE,2)*coupleYR(AGE,IA,IE) 
			
			util_welfare_id = util_welfare_id +	retire_couple_util_C(AGE,IA,IE,1) +	retire_couple_util_C(AGE,IA,IE,2)	

			! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
			! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
			! couple_avg_labor_incomethreshold(AGE,j,:) = couple_avg_labor_incomethreshold(AGE,j,:) + 0.0		
			! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + retire_couple_util_C(AGE,IA,IE,1)
			! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + retire_couple_util_C(AGE,IA,IE,2)
			! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYR(AGE,IA,IE)	
			! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYR(AGE,IA,IE)	

			IF (source_welfare==0) THEN
				bench_coupleIDCRC(AGE,IA,IE,1) = coupleIDCRC(AGE,IA,IE)/eta
				bench_coupleIDCRC(AGE,IA,IE,2) = coupleIDCRC(AGE,IA,IE)/eta
				! bench_couple_VR(AGE,IA,IE,1) = temp_retire_couple_util_C(AGE,IA,IE,1)
				! bench_couple_VR(AGE,IA,IE,2) = temp_retire_couple_util_C(AGE,IA,IE,2)
				bench_couple_VR(AGE,IA,IE) = coupleVR(AGE,IA,IE)
				bench_coupleYR(AGE,IA,IE) = coupleYR(AGE,IA,IE)	
				bench_retire_couple_util_C(AGE,IA,IE,1) = retire_couple_util_C(AGE,IA,IE,1)
				bench_retire_couple_util_C(AGE,IA,IE,2) = retire_couple_util_C(AGE,IA,IE,2)
			END IF 					

		END DO 
    END DO
END DO 


AGE = RETAGE-1
	DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					! INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
					! TINCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)

					! IF (TINCOME<=incomethreshold80) THEN
					! 	j=1
					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
					! 	j=4
					! ELSEIF (TINCOME>incomethreshold20) THEN 
					! 	j=5
					! END IF

					! IF (INCOME<=earningthreshold80) THEN
					! 	j=1
					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
					! 	j=4
					! ELSEIF (INCOME>earningthreshold20) THEN 
					! 	j=5
					! END IF

					! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female)
					! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)
					temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) 
					temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female)
					couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)
					
					! EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0/5.0)/AGE 
					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0)/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
							
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*( temp_retire_couple_util_C(AGE+1,JA,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*( temp_retire_couple_util_C(AGE+1,JA,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
														
							EXIT   

						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH  
							
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*temp_retire_couple_util_C(AGE+1,JA,JE,1)
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*temp_retire_couple_util_C(AGE+1,JA,JE,2) 
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
						
							EXIT

						END IF
					END DO 

					util_welfare_id = util_welfare_id + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)

					! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_labor_incomethreshold(AGE,j,1) = couple_avg_labor_incomethreshold(AGE,j,1) + N(JN1)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_labor_incomethreshold(AGE,j,2) = couple_avg_labor_incomethreshold(AGE,j,2) + N(JN2)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + couple_util_C(AGE,IA,IS1,IS2,IE,1)+(-theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + couple_util_C(AGE,IA,IS1,IS2,IE,2)+(-theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_workingdist_incomethreshold(AGE,j,1) = couple_workingdist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_workingdist_incomethreshold(AGE,j,2) = couple_workingdist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)

					IF (source_welfare==0) THEN
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,1) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,2) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
						! bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
						! bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)	
						bench_couple_VW(AGE,IA,IS1,IS2,IE) = coupleVW(AGE,IA,IS1,IS2,IE)			
						bench_coupleYW(AGE,IA,IS1,IS2,IE) = coupleYW(AGE,IA,IS1,IS2,IE)
						bench_couple_util_C(AGE,IA,IS1,IS2,IE,1) = couple_util_C(AGE,IA,IS1,IS2,IE,1)
						bench_couple_util_C(AGE,IA,IS1,IS2,IE,2) = couple_util_C(AGE,IA,IS1,IS2,IE,2)
						bench_couple_util_LS(AGE,IA,IS1,IS2,IE) = couple_util_LS(AGE,IA,IS1,IS2,IE)
					END IF 

				END DO
       	 	END DO 
    	END DO
	END DO 


DO AGE = RETAGE-2,1,-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					! INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)	
					! TINCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)

					! IF (TINCOME<=incomethreshold80) THEN
					! 	j=1
					! ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
					! 	j=4
					! ELSEIF (TINCOME>incomethreshold20) THEN 
					! 	j=5
					! END IF

					! IF (INCOME<=earningthreshold80) THEN
					! 	j=1
					! ELSEIF ( (INCOME>earningthreshold80) .AND. (INCOME<=earningthreshold60) ) THEN 
					! 	j=2
					! ELSEIF ( (INCOME>earningthreshold60) .AND. (INCOME<=earningthreshold40) ) THEN 
					! 	j=3
					! ELSEIF ( (INCOME>earningthreshold40) .AND. (INCOME<=earningthreshold20) ) THEN 
					! 	j=4
					! ELSEIF (INCOME>earningthreshold20) THEN 
					! 	j=5
					! END IF				
					
					! EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0/5.0)/AGE 
					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0)/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn		
								DO NEWIS2 = 1,nn		  			
								
									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF
								
									sum_temp1 = sum_temp1 + P_joint*( temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
									sum_temp2 = sum_temp2 + P_joint*( temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
								
								END DO 
							END DO

							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*sum_temp1
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*sum_temp2
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)

							! sum_temp = 0.0
							! DO NEWIS = 1,nn				  			
							! 	sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
							! END DO

							! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp
							! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn
								DO NEWIS2 = 1,nn	

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									sum_temp1 = sum_temp1 + P_joint*( temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
									sum_temp2 = sum_temp2 + P_joint*( temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )

								END DO 
							END DO

							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum_temp1 
							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp2
							couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)

							EXIT   

						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn
								DO NEWIS2 = 1,nn	

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									sum_temp1 = sum_temp1 + P_joint*temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,1)  
									sum_temp2 = sum_temp2 + P_joint*temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,2)  

								END DO 
							END DO

							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*sum_temp1
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*sum_temp2
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)

							! sum_temp = 0.0
							! DO NEWIS = 1,nn				  			
							! 	sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE)  ))
							! END DO

							! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp
							! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn
								DO NEWIS2 = 1,nn	

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									sum_temp1 = sum_temp1 + P_joint*temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,1)  
									sum_temp2 = sum_temp2 + P_joint*temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,2)  

								END DO 
							END DO

							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum_temp1
							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp2
							couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)
						
							EXIT

						END IF
					END DO 

					util_welfare_id = util_welfare_id + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)

					! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_labor_incomethreshold(AGE,j,1) = couple_avg_labor_incomethreshold(AGE,j,1) + N(JN1)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_labor_incomethreshold(AGE,j,2) = couple_avg_labor_incomethreshold(AGE,j,2) + N(JN2)*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + couple_util_C(AGE,IA,IS1,IS2,IE,1)+(-theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + couple_util_C(AGE,IA,IS1,IS2,IE,2)+(-theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))*coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_workingdist_incomethreshold(AGE,j,1) = couple_workingdist_incomethreshold(AGE,j,1) + coupleYW(AGE,IA,IS1,IS2,IE)
					! couple_workingdist_incomethreshold(AGE,j,2) = couple_workingdist_incomethreshold(AGE,j,2) + coupleYW(AGE,IA,IS1,IS2,IE)

					IF (source_welfare==0) THEN
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,1) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,2) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)						
						! bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
						! bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)	
						bench_couple_VW(AGE,IA,IS1,IS2,IE) = coupleVW(AGE,IA,IS1,IS2,IE)			
						bench_coupleYW(AGE,IA,IS1,IS2,IE) = coupleYW(AGE,IA,IS1,IS2,IE)
						bench_couple_util_C(AGE,IA,IS1,IS2,IE,1) = couple_util_C(AGE,IA,IS1,IS2,IE,1)
						bench_couple_util_C(AGE,IA,IS1,IS2,IE,2) = couple_util_C(AGE,IA,IS1,IS2,IE,2)
						bench_couple_util_LS(AGE,IA,IS1,IS2,IE) = couple_util_LS(AGE,IA,IS1,IS2,IE)
					END IF 

				END DO 
            END DO
        END DO 
    END DO
END DO 



! DO AGE=1,MAXAGE
! 	DO i=1,5
! 		DO IG=1,2
! 			single_avg_cons_incomethreshold(AGE,i,IG) = single_avg_cons_incomethreshold(AGE,i,IG)/single_dist_incomethreshold(AGE,i,IG)
! 			single_avg_labor_incomethreshold(AGE,i,IG) = single_avg_labor_incomethreshold(AGE,i,IG)/single_workingdist_incomethreshold(AGE,i,IG)
! 			couple_avg_cons_incomethreshold(AGE,i,IG) = couple_avg_cons_incomethreshold(AGE,i,IG)/couple_dist_incomethreshold(AGE,i,IG)
! 			couple_avg_labor_incomethreshold(AGE,i,IG) = couple_avg_labor_incomethreshold(AGE,i,IG)/couple_workingdist_incomethreshold(AGE,i,IG)
! 		END DO 
! 	END DO 
! END DO 


! DO i=1,5
! 	DO IG=1,2
! 		single_avg_cons_incomethreshold_21_35(i,IG) = sum(single_avg_cons_incomethreshold(1:3,i,IG))/sum(single_dist_incomethreshold(1:3,i,IG))
! 		couple_avg_cons_incomethreshold_21_35(i,IG) = sum(couple_avg_cons_incomethreshold(1:3,i,IG))/sum(couple_dist_incomethreshold(1:3,i,IG))
! 		single_avg_val_incomethreshold_21_35(i,IG) = sum(single_avg_val_incomethreshold(1:3,i,IG))/sum(single_dist_incomethreshold(1:3,i,IG))
! 		couple_avg_val_incomethreshold_21_35(i,IG) = sum(couple_avg_val_incomethreshold(1:3,i,IG))/sum(couple_dist_incomethreshold(1:3,i,IG))

! 		single_avg_cons_incomethreshold_36_50(i,IG) = sum(single_avg_cons_incomethreshold(4:6,i,IG))/sum(single_dist_incomethreshold(4:6,i,IG))
! 		couple_avg_cons_incomethreshold_36_50(i,IG) = sum(couple_avg_cons_incomethreshold(4:6,i,IG))/sum(couple_dist_incomethreshold(4:6,i,IG))
! 		single_avg_val_incomethreshold_36_50(i,IG) = sum(single_avg_val_incomethreshold(4:6,i,IG))/sum(single_dist_incomethreshold(4:6,i,IG))
! 		couple_avg_val_incomethreshold_36_50(i,IG) = sum(couple_avg_val_incomethreshold(4:6,i,IG))/sum(couple_dist_incomethreshold(4:6,i,IG))

! 		single_avg_cons_incomethreshold_51_65(i,IG) = sum(single_avg_cons_incomethreshold(7:9,i,IG))/sum(single_dist_incomethreshold(7:9,i,IG))
! 		couple_avg_cons_incomethreshold_51_65(i,IG) = sum(couple_avg_cons_incomethreshold(7:9,i,IG))/sum(couple_dist_incomethreshold(7:9,i,IG))
! 		single_avg_val_incomethreshold_51_65(i,IG) = sum(single_avg_val_incomethreshold(7:9,i,IG))/sum(single_dist_incomethreshold(7:9,i,IG))
! 		couple_avg_val_incomethreshold_51_65(i,IG) = sum(couple_avg_val_incomethreshold(7:9,i,IG))/sum(couple_dist_incomethreshold(7:9,i,IG))

! 		single_avg_cons_incomethreshold_66_80(i,IG) = sum(single_avg_cons_incomethreshold(10:12,i,IG))/sum(single_dist_incomethreshold(10:12,i,IG))
! 		couple_avg_cons_incomethreshold_66_80(i,IG) = sum(couple_avg_cons_incomethreshold(10:12,i,IG))/sum(couple_dist_incomethreshold(10:12,i,IG))
! 		single_avg_val_incomethreshold_66_80(i,IG) = sum(single_avg_val_incomethreshold(10:12,i,IG))/sum(single_dist_incomethreshold(10:12,i,IG))
! 		couple_avg_val_incomethreshold_66_80(i,IG) = sum(couple_avg_val_incomethreshold(10:12,i,IG))/sum(couple_dist_incomethreshold(10:12,i,IG))

! 		single_avg_cons_incomethreshold_81_100(i,IG) = sum(single_avg_cons_incomethreshold(13:16,i,IG))/sum(single_dist_incomethreshold(13:16,i,IG))
! 		couple_avg_cons_incomethreshold_81_100(i,IG) = sum(couple_avg_cons_incomethreshold(13:16,i,IG))/sum(couple_dist_incomethreshold(13:16,i,IG))
! 		single_avg_val_incomethreshold_81_100(i,IG) = sum(single_avg_val_incomethreshold(13:16,i,IG))/sum(single_dist_incomethreshold(13:16,i,IG))
! 		couple_avg_val_incomethreshold_81_100(i,IG) = sum(couple_avg_val_incomethreshold(13:16,i,IG))/sum(couple_dist_incomethreshold(13:16,i,IG))
! 	END DO 
! END DO 


! DO i=1,5
! 	DO IG=1,2
! 		single_avg_labor_incomethreshold_21_35(i,IG) = sum(single_avg_labor_incomethreshold(1:3,i,IG))/sum(single_workingdist_incomethreshold(1:3,i,IG))
! 		couple_avg_labor_incomethreshold_21_35(i,IG) = sum(couple_avg_labor_incomethreshold(1:3,i,IG))/sum(couple_workingdist_incomethreshold(1:3,i,IG))

! 		single_avg_labor_incomethreshold_36_50(i,IG) = sum(single_avg_labor_incomethreshold(4:6,i,IG))/sum(single_workingdist_incomethreshold(4:6,i,IG))
! 		couple_avg_labor_incomethreshold_36_50(i,IG) = sum(couple_avg_labor_incomethreshold(4:6,i,IG))/sum(couple_workingdist_incomethreshold(4:6,i,IG))

! 		single_avg_labor_incomethreshold_51_65(i,IG) = sum(single_avg_labor_incomethreshold(7:9,i,IG))/sum(single_workingdist_incomethreshold(7:9,i,IG))
! 		couple_avg_labor_incomethreshold_51_65(i,IG) = sum(couple_avg_labor_incomethreshold(7:9,i,IG))/sum(couple_workingdist_incomethreshold(7:9,i,IG))
! 	END DO 
! END DO 

util_welfare_id = util_welfare_id/whole_population
veil_welfare_id = ( SUM(single_util_C(1,:,:,:,:)) + SUM(single_util_LS(1,:,:,:,:)) + SUM(couple_util_C(1,:,:,:,:,:)) + SUM(couple_util_LS(1,:,:,:,:)) )/(sum(singleYW(1,:,:,:,:))+2*sum(coupleYW(1,:,:,:,:)))
! veil_welfare_id = ( SUM((temp_single_util_C(1,1,:,1,1) + temp_single_util_LS(1,1,:,1,1))*singleYW(1,1,:,1,1)) +  SUM((temp_single_util_C(1,1,:,1,2) + temp_single_util_LS(1,1,:,1,2))*singleYW(1,1,:,1,2)) &
! 				  + SUM((temp_couple_util_C(1,1,1,:,1,1) + temp_couple_util_LS(1,1,1,:,1,1))*coupleYW(1,1,1,:,1) ) + SUM((temp_couple_util_C(1,1,1,:,1,2) + temp_couple_util_LS(1,1,1,:,1,2))*coupleYW(1,1,1,:,1) ) &  
! 				  + SUM((temp_couple_util_C(1,1,2,:,1,1) + temp_couple_util_LS(1,1,2,:,1,1))*coupleYW(1,1,2,:,1) ) + SUM((temp_couple_util_C(1,1,2,:,1,2) + temp_couple_util_LS(1,1,2,:,1,2))*coupleYW(1,1,2,:,1) ) &
! 				  + SUM((temp_couple_util_C(1,1,3,:,1,1) + temp_couple_util_LS(1,1,3,:,1,1))*coupleYW(1,1,3,:,1) ) + SUM((temp_couple_util_C(1,1,3,:,1,2) + temp_couple_util_LS(1,1,3,:,1,2))*coupleYW(1,1,3,:,1) ) &
! 				  + SUM((temp_couple_util_C(1,1,4,:,1,1) + temp_couple_util_LS(1,1,4,:,1,1))*coupleYW(1,1,4,:,1) ) + SUM((temp_couple_util_C(1,1,4,:,1,2) + temp_couple_util_LS(1,1,4,:,1,2))*coupleYW(1,1,4,:,1) ) &
! 				  + SUM((temp_couple_util_C(1,1,5,:,1,1) + temp_couple_util_LS(1,1,5,:,1,1))*coupleYW(1,1,5,:,1) ) + SUM((temp_couple_util_C(1,1,5,:,1,2) + temp_couple_util_LS(1,1,5,:,1,2))*coupleYW(1,1,5,:,1) ) &
! 				   )/(sum(singleYW(1,1,:,1,:))+2*sum(coupleYW(1,1,:,:,1)))


! Method by Baris&Markus 2014 RED:
! PARETIAN WELFARE: Aggregate consumption equivalents before time aggregation.
! Notes: Assume everyone gets average leisure, lbar, and solve for C(k,z) in 
! C^(1-sigma)/(1-sigma) + theta (1-lbar)^(1-eps)/(1-eps) = (1-beta)V(k,z)

!*******************************************************This part is not correct*******************************************************************
! ! Single 
! agglabpath_singlemale = 0.0
! agglabpath_singlefemale = 0.0
! DO AGE=1,RETAGE-1
! 	agglabpath_singlemale = agglabpath_singlemale + BETA**(AGE-1) * (LLONG_single(AGE,1))**(1.D0+sigma_lab_male)/(1.D0+sigma_lab_male)
! 	agglabpath_singlefemale = agglabpath_singlefemale + BETA**(AGE-1) * (LLONG_single(AGE,2))**(1.D0+sigma_lab_female)/(1.D0+sigma_lab_female)
! END DO


! certeq_singlemale(1) = exp((singleVW(1,1,1,1,1)+theta_single_male*agglabpath_singlemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_singlemale(3) = exp((singleVW(1,1,3,1,1)+theta_single_male*agglabpath_singlemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))

! certeq_singlefemale(1) = exp((singleVW(1,1,1,1,2)+theta_single_female*agglabpath_singlefemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_singlefemale(3) = exp((singleVW(1,1,3,1,2)+theta_single_female*agglabpath_singlefemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))

! aggcerteq_singlemale = certeq_singlemale(1)*singleYW(1,1,1,1,1) + certeq_singlemale(3)*singleYW(1,1,3,1,1)   
! aggcerteq_singlefemale = certeq_singlefemale(1)*singleYW(1,1,1,1,2) + certeq_singlefemale(3)*singleYW(1,1,3,1,2) 

! par_welfare_singlemale = log(aggcerteq_singlemale) - theta_single_male*agglabpath_singlemale
! par_welfare_singlefemale = log(aggcerteq_singlefemale) - theta_single_female*agglabpath_singlefemale

! ! Couple
! agglabpath_couplemale = 0.0
! agglabpath_couplefemale = 0.0
! DO AGE=1,RETAGE-1
! 	agglabpath_couplemale = agglabpath_couplemale + BETA**(AGE-1) * (LLONG_couple(AGE,1))**(1.D0+sigma_lab_male)/(1.D0+sigma_lab_male)
! 	agglabpath_couplefemale = agglabpath_couplefemale + BETA**(AGE-1) * (LLONG_couple(AGE,2))**(1.D0+sigma_lab_female)/(1.D0+sigma_lab_female)
! END DO

! !marriageVW(AGE,IA,IS1,IS2,IE,2
! certeq_couplemale(1,1) = eta*exp((marriageVW(1,1,1,1,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_couplemale(1,2) = eta*exp((marriageVW(1,1,1,2,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_couplemale(2,1) = eta*exp((marriageVW(1,1,2,1,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_couplemale(2,2) = eta*exp((marriageVW(1,1,2,2,1,1)+theta_married_male*agglabpath_couplemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))

! certeq_couplefemale(1,1) = eta*exp((marriageVW(1,1,1,1,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_couplefemale(1,2) = eta*exp((marriageVW(1,1,1,2,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_couplefemale(2,1) = eta*exp((marriageVW(1,1,2,1,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))
! certeq_couplefemale(2,2) = eta*exp((marriageVW(1,1,2,2,1,2)+theta_married_female*agglabpath_couplefemale)*(1.0-BETA)/(1.0-BETA**MAXAGE))

! aggcerteq_couplemale = certeq_couplemale(1,1)*coupleYW(1,1,1,1,1)+certeq_couplemale(1,2)*coupleYW(1,1,1,2,1)+certeq_couplemale(2,1)*coupleYW(1,1,2,1,1)+certeq_couplemale(2,2)*coupleYW(1,1,2,2,1)
! aggcerteq_couplefemale = certeq_couplefemale(1,1)*coupleYW(1,1,1,1,1)+certeq_couplefemale(1,2)*coupleYW(1,1,1,2,1)+certeq_couplefemale(2,1)*coupleYW(1,1,2,1,1)+certeq_couplefemale(2,2)*coupleYW(1,1,2,2,1)

! par_welfare_couple = log(aggcerteq_couplemale) - theta_married_male*agglabpath_couplemale + log(aggcerteq_couplefemale) - theta_married_female*agglabpath_couplefemale

! par_welfare = par_welfare_singlemale + par_welfare_singlefemale + par_welfare_couple

!************************************************************************************************************************************************************

!***************************** Martin Floden 2001 JME *******************************
ALLOCATE(certeqcons_singlemale(nn),certeqlab_singlemale(nn))
ALLOCATE(certeqcons_singlefemale(nn),certeqlab_singlefemale(nn))
ALLOCATE(certeqcons_couple(nn,nn,2),certeqlab_couple(nn,nn,2))
ALLOCATE(agg_certeqcons_couple(2),agg_certeqlab_couple(2))
ALLOCATE(V_certeq_couple(2))
ALLOCATE(AggL_couple(2),cost_unc_couple(2),expV_certeq_couple(2),cost_ineq_couple(2),AggC_couple_leicomp(2),AggL_couple_bm(2))
ALLOCATE(temp_single_discount(MAXAGE,2),single_discount(2))
ALLOCATE(temp_couple_discount1(MAXAGE,2),temp_couple_discount2(MAXAGE,2),couple_discount1(2),couple_discount2(2))


temp_single_discount(:,:) = 0.0
! temp_single_discount(RETAGE,1) = BETA**(RETAGE)*S(RETAGE,1)
! temp_single_discount(RETAGE,2) = BETA**(RETAGE)*S(RETAGE,2)
temp_single_discount(RETAGE,1) = BETA**(RETAGE-1)*S(RETAGE-1,1)
temp_single_discount(RETAGE,2) = BETA**(RETAGE-1)*S(RETAGE-1,2)
DO IG = 1,2	
	DO AGE = RETAGE+1,MAXAGE
		! temp_single_discount(AGE,IG) = temp_single_discount(AGE-1,IG)*BETA*S(AGE,IG)
		temp_single_discount(AGE,IG) = temp_single_discount(AGE-1,IG)*BETA*S(AGE-1,IG)
	END DO 
END DO 
single_discount(1) = (1.0 - BETA**(RETAGE-1))/(1.0 - BETA) + SUM(temp_single_discount(:,1))
single_discount(2) = (1.0 - BETA**(RETAGE-1))/(1.0 - BETA) + SUM(temp_single_discount(:,2))

! Single
DO IS=1,nn 
	! certeqcons_singlemale(IS) = exp( (1.0-BETA)*single_util_C(1,1,IS,1,1)/(1.0-BETA**MAXAGE) )
	! certeqlab_singlemale(IS) = ( (1.0-BETA)*(1.0+sigma_lab_male)*(- single_util_LS(1,1,IS,1,1))/(theta_single_male*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_male))
	
	! certeqcons_singlefemale(IS) = exp( (1.0-BETA)*single_util_C(1,1,IS,1,2)/(1.0-BETA**MAXAGE) )
	! certeqlab_singlefemale(IS) = ( (1.0-BETA)*(1.0+sigma_lab_female)*(- single_util_LS(1,1,IS,1,2))/(theta_single_female*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_female))

! Exclude the distribution 
	! certeqcons_singlemale(IS) = exp( (1.0-BETA)*temp_single_util_C(1,1,IS,1,1)/(1.0-BETA**MAXAGE) )
	certeqcons_singlemale(IS) = exp( temp_single_util_C(1,1,IS,1,1)/single_discount(1) )
	certeqlab_singlemale(IS) = ( (1.0-BETA)*(1.0+sigma_lab_male)*(- temp_single_util_LS(1,1,IS,1,1))/(theta_single_male*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_male))
	
	! certeqcons_singlefemale(IS) = exp( (1.0-BETA)*temp_single_util_C(1,1,IS,1,2)/(1.0-BETA**MAXAGE) )
	certeqcons_singlefemale(IS) = exp( temp_single_util_C(1,1,IS,1,2)/single_discount(2) )
	certeqlab_singlefemale(IS) = ( (1.0-BETA)*(1.0+sigma_lab_female)*(- temp_single_util_LS(1,1,IS,1,2))/(theta_single_female*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_female))
END DO 

! agg_certeqcons_singlemale = sum(certeqcons_singlemale(:)*singleYW(1,1,:,1,1))
! agg_certeqlab_singlemale = sum(certeqlab_singlemale(:)*singleYW(1,1,:,1,1))
! agg_certeqcons_singlefemale = sum(certeqcons_singlefemale(:)*singleYW(1,1,:,1,2))
! agg_certeqlab_singlefemale = sum(certeqlab_singlefemale(:)*singleYW(1,1,:,1,2))
agg_certeqcons_singlemale = sum(certeqcons_singlemale(:)*singleYW(1,1,:,1,1))/sum(singleYW(1,1,:,1,1))
agg_certeqlab_singlemale = sum(certeqlab_singlemale(:)*singleYW(1,1,:,1,1))/sum(singleYW(1,1,:,1,1))
agg_certeqcons_singlefemale = sum(certeqcons_singlefemale(:)*singleYW(1,1,:,1,2))/sum(singleYW(1,1,:,1,2))
agg_certeqlab_singlefemale = sum(certeqlab_singlefemale(:)*singleYW(1,1,:,1,2))/sum(singleYW(1,1,:,1,2))

V_certeq_singlemale = log(agg_certeqcons_singlemale) - theta_single_male*(agg_certeqlab_singlemale**(1.0+sigma_lab_male))/(1.0+sigma_lab_male)
V_certeq_singlefemale = log(agg_certeqcons_singlefemale) - theta_single_female*(agg_certeqlab_singlefemale**(1.0+sigma_lab_female))/(1.0+sigma_lab_female)
! V_certeq_single = V_certeq_singlemale + V_certeq_singlefemale

temp_couple_discount1(:,:) = 0.0
temp_couple_discount2(:,:) = 0.0

temp_couple_discount1(RETAGE,1) = BETA**(RETAGE-1)*S(RETAGE,1)*S(RETAGE,2)
temp_couple_discount2(RETAGE,1) = BETA**(RETAGE-1)*S(RETAGE,1)*(1.0-S(RETAGE,2))
temp_couple_discount1(RETAGE,2) = BETA**(RETAGE-1)*S(RETAGE,1)*S(RETAGE,2)
temp_couple_discount2(RETAGE,2) = BETA**(RETAGE-1)*S(RETAGE,1)*(1.0-S(RETAGE,2))
! temp_couple_discount1(RETAGE,1) = BETA**(RETAGE-1)*S(RETAGE-1,1)*S(RETAGE-1,2)
! temp_couple_discount2(RETAGE,1) = BETA**(RETAGE-1)*S(RETAGE-1,1)*(1.0-S(RETAGE-1,2))
! temp_couple_discount1(RETAGE,2) = BETA**(RETAGE-1)*S(RETAGE-1,1)*S(RETAGE-1,2)
! temp_couple_discount2(RETAGE,2) = BETA**(RETAGE-1)*S(RETAGE-1,1)*(1.0-S(RETAGE-1,2))
DO AGE = RETAGE+1,MAXAGE-1
	temp_couple_discount1(AGE,1) = temp_couple_discount1(AGE-1,1)*BETA*S(AGE,1)*S(AGE,2)
	temp_couple_discount2(AGE,1) = temp_couple_discount1(AGE-1,1)*BETA*S(AGE,1)*(1.0-S(AGE,2))
	temp_couple_discount1(AGE,2) = temp_couple_discount1(AGE-1,2)*BETA*S(AGE,1)*S(AGE,2)
	temp_couple_discount2(AGE,2) = temp_couple_discount1(AGE-1,2)*BETA*S(AGE,2)*(1.0-S(AGE,1))
	! temp_couple_discount1(AGE,1) = temp_couple_discount1(AGE-1,1)*BETA*S(AGE-1,1)*S(AGE-1,2)
	! temp_couple_discount2(AGE,1) = temp_couple_discount1(AGE-1,1)*BETA*S(AGE-1,1)*(1.0-S(AGE-1,2))
	! temp_couple_discount1(AGE,2) = temp_couple_discount1(AGE-1,2)*BETA*S(AGE-1,1)*S(AGE-1,2)
	! temp_couple_discount2(AGE,2) = temp_couple_discount1(AGE-1,2)*BETA*S(AGE-1,2)*(1.0-S(AGE-1,1))
END DO 

couple_discount1(1) = (1.0 - BETA**(RETAGE-1))/(1.0 - BETA) + SUM(temp_couple_discount1(:,1))
couple_discount2(1) = SUM(temp_couple_discount2(:,1))
couple_discount1(2) = (1.0 - BETA**(RETAGE-1))/(1.0 - BETA) + SUM(temp_couple_discount1(:,2))
couple_discount2(2) = SUM(temp_couple_discount2(:,2))

! Couple
DO IS1=1,nn
	DO IS2=1,nn
		! certeqcons_couple(IS1,IS2,1) = eta*exp( (1.0-BETA)*couple_util_C(1,1,IS1,IS2,1,1)/(1.0-BETA**MAXAGE)/2.0 )
		! certeqlab_couple(IS1,IS2,1) = ( (1.0-BETA)*(1.0+sigma_lab_male)*(- temp_couple_util_LS(1,1,IS1,IS2,1,1)*coupleYW(1,1,IS1,IS2,1))/(theta_married_male*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_male))

		! certeqcons_couple(IS1,IS2,2) = eta*exp( (1.0-BETA)*couple_util_C(1,1,IS1,IS2,1,2)/(1.0-BETA**MAXAGE)/2.0 )
		! certeqlab_couple(IS1,IS2,2) = ( (1.0-BETA)*(1.0+sigma_lab_female)*(- temp_couple_util_LS(1,1,IS1,IS2,1,2)*coupleYW(1,1,IS1,IS2,1))/(theta_married_female*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_female))

		! certeqcons_couple(IS1,IS2,1) = eta*exp( (1.0-BETA)*temp_couple_util_C(1,1,IS1,IS2,1,1)/(1.0-BETA**MAXAGE)/2.0 )
		certeqcons_couple(IS1,IS2,1) = exp( (temp_couple_util_C(1,1,IS1,IS2,1,1) + couple_discount1(1)*log(eta))/(couple_discount1(1)+couple_discount2(1)) )
		certeqlab_couple(IS1,IS2,1) = ( (1.0-BETA)*(1.0+sigma_lab_male)*(- temp_couple_util_LS(1,1,IS1,IS2,1,1))/(theta_married_male*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_male))

		! certeqcons_couple(IS1,IS2,2) = eta*exp( (1.0-BETA)*temp_couple_util_C(1,1,IS1,IS2,1,2)/(1.0-BETA**MAXAGE)/2.0 )
		certeqcons_couple(IS1,IS2,2) = exp( (temp_couple_util_C(1,1,IS1,IS2,1,2) + couple_discount1(2)*log(eta))/(couple_discount1(2)+couple_discount2(2)) )
		certeqlab_couple(IS1,IS2,2) = ( (1.0-BETA)*(1.0+sigma_lab_female)*(- temp_couple_util_LS(1,1,IS1,IS2,1,2))/(theta_married_female*(1.0-BETA**(RETAGE-1))) )**(1.0/(1.0+sigma_lab_female))
	END DO 
END DO 

agg_certeqcons_couple(:)=0.0
agg_certeqlab_couple(:)=0.0
DO IS1=1,nn
	agg_certeqcons_couple(1) = agg_certeqcons_couple(1) + sum(certeqcons_couple(IS1,:,1)*coupleYW(1,1,IS1,:,1))
	agg_certeqlab_couple(1) = agg_certeqlab_couple(1) + sum(certeqlab_couple(IS1,:,1)*coupleYW(1,1,IS1,:,1))

	agg_certeqcons_couple(2) = agg_certeqcons_couple(2) + sum(certeqcons_couple(IS1,:,2)*coupleYW(1,1,IS1,:,1))
	agg_certeqlab_couple(2) = agg_certeqlab_couple(2) + sum(certeqlab_couple(IS1,:,2)*coupleYW(1,1,IS1,:,1))
END DO 

agg_certeqcons_couple(1)=agg_certeqcons_couple(1)/sum(coupleYW(1,1,:,:,1))
agg_certeqcons_couple(2)=agg_certeqcons_couple(2)/sum(coupleYW(1,1,:,:,1))
agg_certeqlab_couple(1)=agg_certeqlab_couple(1)/sum(coupleYW(1,1,:,:,1))
agg_certeqlab_couple(2)=agg_certeqlab_couple(2)/sum(coupleYW(1,1,:,:,1))

V_certeq_couple(1) = log(agg_certeqcons_couple(1)/eta) - theta_married_male*(agg_certeqlab_couple(1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male)
V_certeq_couple(2) = log(agg_certeqcons_couple(2)/eta) - theta_married_female*(agg_certeqlab_couple(2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female)

print*, 'agg_certeqcons_singlemale',agg_certeqcons_singlemale 
print*, 'agg_certeqlab_singlemale',agg_certeqlab_singlemale
print*, 'agg_certeqcons_singlefemale',agg_certeqcons_singlefemale  
print*, 'agg_certeqlab_singlefemale',agg_certeqlab_singlefemale
print*, 'agg_certeqcons_couple(1)',agg_certeqcons_couple(1)
print*, 'agg_certeqcons_couple(2)',agg_certeqcons_couple(2)
print*, 'agg_certeqlab_couple(1)',agg_certeqlab_couple(1)
print*, 'agg_certeqlab_couple(2)',agg_certeqlab_couple(2)

print*, 'certainty-equivalent value (single male)', V_certeq_singlemale
print*, 'certainty-equivalent value (single female)', V_certeq_singlefemale
print*, 'certainty-equivalent value (single)', V_certeq_singlemale+V_certeq_singlefemale
print*, 'certainty-equivalent value (married male)', V_certeq_couple(1)
print*, 'certainty-equivalent value (married female)', V_certeq_couple(2)
print*, 'certainty-equivalent value (married)', V_certeq_couple(1)+V_certeq_couple(2)
print*, 'certainty-equivalent value (single+married)', V_certeq_singlemale+V_certeq_singlefemale+V_certeq_couple(1)+V_certeq_couple(2)


par_welfare = V_certeq_singlemale+V_certeq_singlefemale+V_certeq_couple(1)+V_certeq_couple(2)
!************************************************
! 			  Welfare decomposition
!************************************************

! Cost of uncertainty
!  AggC_singlemale = SUM(singleIDCWC(:,:,:,:,1)*singleYW(:,:,:,:,1))/SUM(singleYW(:,:,:,:,1))
!  AggC_singlefemale = SUM(singleIDCWC(:,:,:,:,2)*singleYW(:,:,:,:,2))/SUM(singleYW(:,:,:,:,2))
AggC_singlemale = ( SUM(singleIDCWC(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleIDCRC(:,:,:,1)*singleYR(:,:,:,1)) )/( SUM(singleYW(:,:,:,:,1)) + SUM(singleYR(:,:,:,1)) )
AggC_singlefemale = ( SUM(singleIDCWC(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleIDCRC(:,:,:,2)*singleYR(:,:,:,2)) )/( SUM(singleYW(:,:,:,:,2)) + SUM(singleYR(:,:,:,2)) )

! ****************** APPENDIX A: agg_certeqlab = AggL and (1- p_unc)C = C_bar in (A.2) ******************
!  AggL_singlemale = 0.0
!  AggL_singlefemale = 0.0
!  DO AGE=1,RETAGE-1
! 	DO IA=1,NGRIDA
!         DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 				AggL_singlemale = AggL_singlemale + N(singleIDCWN(AGE,IA,IS,IE,1))*singleYW(AGE,IA,IS,IE,1)
! 				AggL_singlefemale = AggL_singlefemale + N(singleIDCWN(AGE,IA,IS,IE,2))*singleYW(AGE,IA,IS,IE,2)
! 			END DO
!         END DO 
!     END DO
!  END DO
!  AggL_singlemale = AggL_singlemale/SUM(singleYW(:,:,:,:,1))
!  AggL_singlefemale = AggL_singlefemale/SUM(singleYW(:,:,:,:,2))
AggL_singlemale = agg_certeqlab_singlemale
AggL_singlefemale = agg_certeqlab_singlefemale

!  cost_unc_singlemale = 1.0 - exp(V_certeq_singlemale + theta_single_male*(AggL_singlemale**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))/AggC_singlemale
!  cost_unc_singlefemale = 1.0 - exp(V_certeq_singlefemale + theta_single_female*(AggL_singlefemale**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))/AggC_singlefemale
cost_unc_singlemale = 1.0 - agg_certeqcons_singlemale/AggC_singlemale
cost_unc_singlefemale = 1.0 - agg_certeqcons_singlefemale/AggC_singlefemale

!  AggC_couple = SUM(coupleIDCWC(:,:,:,:,:)*coupleYW(:,:,:,:,:))/SUM(coupleYW(:,:,:,:,:))
AggC_couple = ( SUM(coupleIDCWC(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + SUM(coupleIDCRC(:,:,:)*coupleYR(:,:,:)) )/( SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(:,:,:)) )

!  AggL_couple(:) = 0.0
!  DO AGE=1,RETAGE-1
! 	DO IA=1,NGRIDA
!         DO IS1=1,nn
! 			DO IS2=1,nn
! 				DO IE=1,NGRIDEH
! 					AggL_couple(1) = AggL_couple(1) + N(coupleIDCWN(AGE,IA,IS1,IS2,IE,1))*coupleYW(AGE,IA,IS1,IS2,IE)
! 					AggL_couple(2) = AggL_couple(2) + N(coupleIDCWN(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)
! 				END DO 
!             END DO
!         END DO 
!     END DO
!  END DO
!  AggL_couple(1) = AggL_couple(1)/SUM(coupleYW(:,:,:,:,:))
!  AggL_couple(2) = AggL_couple(2)/SUM(coupleYW(:,:,:,:,:))
AggL_couple(1) = agg_certeqlab_couple(1)
AggL_couple(2) = agg_certeqlab_couple(2)

!  cost_unc_couple(1) = 1.0 - eta*exp(V_certeq_couple(1) + theta_married_male*(AggL_couple(1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))/AggC_couple
!  cost_unc_couple(2) = 1.0 - eta*exp(V_certeq_couple(2) + theta_married_female*(AggL_couple(2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))/AggC_couple
 cost_unc_couple(1) = 1.0 - agg_certeqcons_couple(1)/AggC_couple
 cost_unc_couple(2) = 1.0 - agg_certeqcons_couple(2)/AggC_couple

! Cost of inequality
! expV_certeq_singlemale =sum((log(certeqcons_singlemale(:))-theta_single_male*(certeqlab_singlemale(:)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))*singleYW(1,1,:,1,1))/sum(singleYW(1,1,:,1,1))
expV_certeq_singlemale =sum((single_discount(1)*log(certeqcons_singlemale(:))-((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_single_male*(certeqlab_singlemale(:)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))*singleYW(1,1,:,1,1))/sum(singleYW(1,1,:,1,1))
cost_ineq_singlemale = 1.0 - exp((expV_certeq_singlemale + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_single_male*(agg_certeqlab_singlemale**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))/single_discount(1))/agg_certeqcons_singlemale
! expV_certeq_singlefemale =sum((log(certeqcons_singlefemale(:))-theta_single_female*(certeqlab_singlefemale(:)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))*singleYW(1,1,:,1,2))/sum(singleYW(1,1,:,1,2))
expV_certeq_singlefemale =sum((single_discount(2)*log(certeqcons_singlefemale(:))-((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_single_female*(certeqlab_singlefemale(:)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))*singleYW(1,1,:,1,2))/sum(singleYW(1,1,:,1,2))
cost_ineq_singlefemale = 1.0 - exp((expV_certeq_singlefemale + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_single_female*(agg_certeqlab_singlefemale**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))/single_discount(2))/agg_certeqcons_singlefemale

! expV_certeq_couple(1) =sum((log(certeqcons_couple(:,:,1))-theta_married_male*(certeqlab_couple(:,:,1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))*coupleYW(1,1,:,:,1))
! cost_ineq_couple(1) = 1.0 - eta*exp(expV_certeq_couple(1) + theta_married_male*(agg_certeqlab_couple(1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))/agg_certeqcons_couple(1)
expV_certeq_couple(1) =sum((couple_discount1(1)*log(certeqcons_couple(:,:,1)/eta) + couple_discount2(1)*log(certeqcons_couple(:,:,1)) - ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_married_male*(certeqlab_couple(:,:,1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))*coupleYW(1,1,:,:,1))/sum(coupleYW(1,1,:,:,1))
cost_ineq_couple(1) = 1.0 - exp((expV_certeq_couple(1) + couple_discount1(1)*log(eta) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_married_male*(agg_certeqlab_couple(1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))/(couple_discount1(1)+couple_discount2(1)))/agg_certeqcons_couple(1)
! expV_certeq_couple(2) =sum((log(certeqcons_couple(:,:,2)/eta)-theta_married_female*(certeqlab_couple(:,:,2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))*coupleYW(1,1,:,:,1))/sum(coupleYW(1,1,:,:,1))
! cost_ineq_couple(2) = 1.0 - eta*exp(expV_certeq_couple(2) + theta_married_female*(agg_certeqlab_couple(2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))/agg_certeqcons_couple(2)
expV_certeq_couple(2) =sum((couple_discount1(2)*log(certeqcons_couple(:,:,2)/eta) + couple_discount2(2)*log(certeqcons_couple(:,:,2)) - ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_married_female*(certeqlab_couple(:,:,2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))*coupleYW(1,1,:,:,1))/sum(coupleYW(1,1,:,:,1))
cost_ineq_couple(2) = 1.0 - exp((expV_certeq_couple(2) + couple_discount1(2)*log(eta) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*theta_married_female*(agg_certeqlab_couple(2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))/(couple_discount1(2)+couple_discount2(2)))/agg_certeqcons_couple(2)

! Cost of efficiency (agg cons)
! AggC_singlemale_bm = 
! AggL_singlemale_bm = 
! V_aggCL_singlemale = log(AggC_singlemale_bm) - theta_single_male*(AggL_singlemale_bm**(1.0+sigma_lab_male))/(1.0+sigma_lab_male)
! AggC_leicomp_singlemale = exp(V_aggCL_singlemale + theta_single_male*(AggL_singlemale**(1.0+sigma_lab_male))/(1.0+sigma_lab_male))

! AggC_singlefemale_bm = 
! AggL_singlefemale_bm = 
! V_aggCL_singlefemale = log(AggC_singlefemale_bm) - theta_single_female*(AggL_singlefemale_bm**(1.0+sigma_lab_female))/(1.0+sigma_lab_female)
! AggC_leicomp_singlefemale = exp(V_aggCL_singlefemale + theta_single_female*(AggL_singlefemale**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))

! AggC_couple_bm = 
! AggL_couple_bm(1) = 
! AggL_couple_bm(2) = 
! V_aggCL_couple = 2.0*log(AggC_couple_bm/eta) - theta_married_male*(AggL_couple_bm(1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male) - theta_married_female*(AggL_couple_bm(2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female)
! AggC_leicomp_couple = eta*exp((V_aggCL_couple + theta_married_male*(AggL_couple(1)**(1.0+sigma_lab_male))/(1.0+sigma_lab_male)+ theta_married_female*(AggL_couple(2)**(1.0+sigma_lab_female))/(1.0+sigma_lab_female))/2.0)

print*, 'cost_unc_singlemale',cost_unc_singlemale
print*, 'cost_unc_singlefemale',cost_unc_singlefemale
print*, 'cost_unc_couple(1)',cost_unc_couple(1)
print*, 'cost_unc_couple(2)',cost_unc_couple(2)
print*, 'cost_ineq_singlemale',cost_ineq_singlemale
print*, 'cost_ineq_singlefemale',cost_ineq_singlefemale
print*, 'cost_ineq_couple(1)',cost_ineq_couple(1)
print*, 'cost_ineq_couple(2)',cost_ineq_couple(2)

print*,'util_welfare_id',util_welfare_id
print*,'veil_welfare_id',veil_welfare_id
print*,'par_welfare',par_welfare

IF (optimal_tax_activation == 0) THEN 
	OPEN(UNIT=27,FILE='AggC_singlemale.txt')
		write(27,*) AggC_singlemale
	CLOSE(27)

	OPEN(UNIT=27,FILE='AggC_singlefemale.txt')
		write(27,*) AggC_singlefemale
	CLOSE(27)

	OPEN(UNIT=27,FILE='AggL_singlemale.txt')
		write(27,*) AggL_singlemale
	CLOSE(27)

	OPEN(UNIT=27,FILE='AggL_singlefemale.txt')
		write(27,*) AggL_singlefemale
	CLOSE(27)

	OPEN(UNIT=27,FILE='AggC_couple_male.txt')
		write(27,*) AggC_couple
	CLOSE(27)

	OPEN(UNIT=27,FILE='AggC_couple_female.txt')
		write(27,*) AggC_couple
	CLOSE(27)

	OPEN(UNIT=27,FILE='AggL_couple_male.txt')
		write(27,*) AggL_couple(1)
	CLOSE(27)

	OPEN(UNIT=27,FILE='AggL_couple_female.txt')
		write(27,*) AggL_couple(2)
	CLOSE(27)

	AggC_singlemale_leicomp = 0.0
	AggC_singlefemale_leicomp = 0.0
	AggC_couple_leicomp(1) = 0.0
	AggC_couple_leicomp(2) = 0.0

ELSE

	! welfare gain of increased levels

	!Read benchmark data for C,L
	! OPEN(UNIT=27,FILE='AggC_singlemale.txt')
	! 	READ(27,*) AggC_singlemale_bm
	! CLOSE(27)
	! OPEN(UNIT=27,FILE='AggC_singlefemale.txt')
	! 	READ(27,*) AggC_singlefemale_bm
	! CLOSE(27)
	OPEN(UNIT=27,FILE='AggL_singlemale.txt')
		READ(27,*) AggL_singlemale_bm
	CLOSE(27)
	OPEN(UNIT=27,FILE='AggL_singlefemale.txt')
		READ(27,*) AggL_singlefemale_bm
	CLOSE(27)
	! OPEN(UNIT=27,FILE='AggC_couple_male.txt')
	! 	READ(27,*) AggC_couple_male_bm
	! CLOSE(27)
	! OPEN(UNIT=27,FILE='AggC_couple_female.txt')
	! 	READ(27,*) AggC_couple_female_bm
	! CLOSE(27)
	OPEN(UNIT=27,FILE='AggL_couple_male.txt')
		READ(27,*) AggL_couple_male_bm
	CLOSE(27)
	OPEN(UNIT=27,FILE='AggL_couple_female.txt')
		READ(27,*) AggL_couple_female_bm
	CLOSE(27)

	! single male
	AggC_singlemale_leicomp = exp(log(AggC_singlemale) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*(theta_single_male*(AggL_singlemale**(1+sigma_lab_male))/(1+sigma_lab_male) - theta_single_male*(AggL_singlemale_bm**(1+sigma_lab_male))/(1+sigma_lab_male))/single_discount(1))
	! AggC_singlemale_leicomp = exp(single_discount(1)*log(AggC_singlemale) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*(theta_single_male*(AggL_singlemale**(1+sigma_lab_male))/(1+sigma_lab_male) - theta_single_male*(AggL_singlemale_bm**(1+sigma_lab_male))/(1+sigma_lab_male))/single_discount(1))
	! single female
	AggC_singlefemale_leicomp = exp(log(AggC_singlefemale) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*(theta_single_female*(AggL_singlefemale**(1+sigma_lab_female))/(1+sigma_lab_female) -  theta_single_female*(AggL_singlefemale_bm**(1+sigma_lab_female))/(1+sigma_lab_female))/single_discount(2))
	! AggC_singlefemale_leicomp = exp(single_discount(2)*log(AggC_singlefemale) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*(theta_single_female*(AggL_singlefemale**(1+sigma_lab_female))/(1+sigma_lab_female) -  theta_single_female*(AggL_singlefemale_bm**(1+sigma_lab_female))/(1+sigma_lab_female))/single_discount(2))

	! due to the survival prob, married couple could become single after retirement. the eta is eliminated in the equation
	! married male	
	AggC_couple_leicomp(1) = exp( log(AggC_couple) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*( theta_married_male*(AggL_couple(1)**(1+sigma_lab_male))/(1+sigma_lab_male) -  theta_married_male*(AggL_couple_male_bm**(1+sigma_lab_male))/(1+sigma_lab_male) )/(couple_discount1(1)+couple_discount2(1)) )
	! AggC_couple_leicomp(1) = exp( (couple_discount1(1)+couple_discount2(1))*log(AggC_couple) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*( theta_married_male*(AggL_couple(1)**(1+sigma_lab_male))/(1+sigma_lab_male) -  theta_married_male*(AggL_couple_male_bm**(1+sigma_lab_male))/(1+sigma_lab_male) )/(couple_discount1(1)+couple_discount2(1)) )

	! married female
	AggC_couple_leicomp(2) = exp( log(AggC_couple) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*( theta_married_female*(AggL_couple(2)**(1+sigma_lab_female))/(1+sigma_lab_female) -  theta_married_female*(AggL_couple_female_bm**(1+sigma_lab_female))/(1+sigma_lab_female) )/(couple_discount1(2)+couple_discount2(2)) )
	! AggC_couple_leicomp(2) = exp( (couple_discount1(2)+couple_discount2(2))*log(AggC_couple) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*( theta_married_female*(AggL_couple(2)**(1+sigma_lab_female))/(1+sigma_lab_female) -  theta_married_female*(AggL_couple_female_bm**(1+sigma_lab_female))/(1+sigma_lab_female) )/(couple_discount1(2)+couple_discount2(2)) )

END IF 

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE compensating_variation

ALLOCATE(read_vector_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2))
ALLOCATE(read_vector_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH))
ALLOCATE(bench_single_VW(RETAGE-1, NGRIDA, nn, NGRIDEH, 2))
ALLOCATE(bench_couple_VW(RETAGE-1, NGRIDA, nn, nn, NGRIDEH))

OPEN(UNIT=27,FILE='bench_single_VW.txt')
	READ(27,*) read_vector_single
CLOSE(27)
bench_single_VW = reshape(read_vector_single, (/ RETAGE-1, NGRIDA, nn, NGRIDEH, 2 /))	
print*, "bench_single_VW"

OPEN(UNIT=27,FILE='bench_couple_VW.txt')
	READ(27,*) read_vector_couple
CLOSE(27)
bench_couple_VW = reshape(read_vector_couple, (/ RETAGE-1, NGRIDA, nn, nn, NGRIDEH /))	
print*, "bench_couple_VW"

DEALLOCATE(read_vector_single)
DEALLOCATE(read_vector_couple)

! retiree
ALLOCATE(read_vector_single((MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2))
ALLOCATE(read_vector_couple((MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH))
ALLOCATE(bench_single_VR(RETAGE:MAXAGE, NGRIDA, NGRIDEH, 2))
ALLOCATE(bench_couple_VR(RETAGE:MAXAGE, NGRIDA, NGRIDEH))

OPEN(UNIT=27,FILE='bench_single_VR.txt')
		READ(27,*) read_vector_single
	CLOSE(27)
	bench_single_VR = reshape(read_vector_single, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDEH, 2 /))	
	print*, "bench_single_VR"

	OPEN(UNIT=27,FILE='bench_couple_VR.txt')
		READ(27,*) read_vector_couple
	CLOSE(27)
	bench_couple_VR = reshape(read_vector_couple, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDEH /))	
	print*, "bench_couple_VR"

DEALLOCATE(read_vector_single)
DEALLOCATE(read_vector_couple)

! compensating variation
ALLOCATE(VW_delta_single(RETAGE-1, NGRIDA,nn,NGRIDEH,2))
ALLOCATE(uprime_alt_working_single(RETAGE-1,NGRIDA,nn,NGRIDEH,2))
ALLOCATE(cv_working_single(RETAGE-1,NGRIDA,nn,NGRIDEH,2))

ALLOCATE(VW_delta_couple(RETAGE-1,NGRIDA,nn,nn,NGRIDEH ))
ALLOCATE(uprime_alt_working_couple(RETAGE-1,NGRIDA,nn,nn,NGRIDEH))
ALLOCATE(cv_working_couple(RETAGE-1,NGRIDA,nn,nn,NGRIDEH))

ALLOCATE(VR_delta_single(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2))
ALLOCATE(uprime_alt_retire_single(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2))
ALLOCATE(cv_retire_single(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2))

ALLOCATE(VR_delta_couple(RETAGE:MAXAGE,NGRIDA,NGRIDEH))
ALLOCATE(uprime_alt_retire_couple(RETAGE:MAXAGE,NGRIDA,NGRIDEH))
ALLOCATE(cv_retire_couple(RETAGE:MAXAGE,NGRIDA,NGRIDEH))

CEV = 0.0
DO AGE = 1,RETAGE-1
	DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2
					
					uprime_alt_working_single(AGE,IA,IS,IE,IG) = 1.0/singleIDCWC(AGE,IA,IS,IE,IG)
					
					VW_delta_single(AGE,IA,IS,IE,IG) =  bench_single_VW(AGE,IA,IS,IE,IG) - singleVW(AGE,IA,IS,IE,IG)
					cv_working_single(AGE,IA,IS,IE,IG) =(VW_delta_single(AGE,IA,IS,IE,IG)/uprime_alt_working_single(AGE,IA,IS,IE,IG))*singleYW(AGE,IA,IS,IE,IG)	!this is now in units of assets. being in alt with additioanl assets CV equivalent to being in V. if CV<0, alt is better than bm.

					CEV = CEV + cv_working_single(AGE,IA,IS,IE,IG)
				END DO 
			END DO 	 
		END DO
    END DO
END DO

DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA            
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH	

					uprime_alt_working_couple(AGE,IA,IS1,IS2,IE) = 2.0*(1.0/coupleIDCWC(AGE,IA,IS1,IS2,IE))
					
					VW_delta_couple(AGE,IA,IS1,IS2,IE) = bench_couple_VW(AGE,IA,IS1,IS2,IE) - coupleVW(AGE,IA,IS1,IS2,IE)
					cv_working_couple(AGE,IA,IS1,IS2,IE) = (VW_delta_couple(AGE,IA,IS1,IS2,IE)/uprime_alt_working_couple(AGE,IA,IS1,IS2,IE))*coupleYW(AGE,IA,IS1,IS2,IE)

					CEV = CEV + cv_working_couple(AGE,IA,IS1,IS2,IE)
				END DO 
			END DO 	 
		END DO
    END DO
END DO

DO AGE=RETAGE,MAXAGE
	DO IA=1,NGRIDA
		DO IE=1,NGRIDEH
			DO IG=1,2

				VR_delta_single(AGE,IA,IE,IG) =  bench_single_VR(AGE,IA,IE,IG) - singleVR(AGE,IA,IE,IG)
				uprime_alt_retire_single(AGE,IA,IE,IG) = 1.0/singleIDCRC(AGE,IA,IE,IG)
				cv_retire_single(AGE,IA,IE,IG) = (VR_delta_single(AGE,IA,IE,IG)/uprime_alt_retire_single(AGE,IA,IE,IG))*singleYR(AGE,IA,IE,IG)

				CEV = CEV + cv_retire_single(AGE,IA,IE,IG) 

			END DO 	 
		END DO
    END DO
END DO

DO AGE=RETAGE,MAXAGE
	DO IA=1,NGRIDA
		DO IE=1,NGRIDEH	

			VR_delta_couple(AGE,IA,IE) =  bench_couple_VR(AGE,IA,IE) - coupleVR(AGE,IA,IE)
			uprime_alt_retire_couple(AGE,IA,IE) = 2.0*(1.0/coupleIDCRC(AGE,IA,IE))
			cv_retire_couple(AGE,IA,IE) = (VR_delta_couple(AGE,IA,IE)/uprime_alt_retire_couple(AGE,IA,IE))*coupleYR(AGE,IA,IE)
			
			CEV = CEV + cv_retire_couple(AGE,IA,IE)

		END DO         
	END DO
END DO

! people get confused by CV<0 being gains: multiply by -1
cv_working_single = -cv_working_single
cv_working_couple = -cv_working_couple
cv_retire_single = -cv_retire_single
cv_retire_couple = -cv_retire_couple

CEV = -CEV/(SUM(singleYW(:,:,:,:,:))+SUM(coupleYW(:,:,:,:,:))+SUM(singleYR(:,:,:,:))+SUM(coupleYR(:,:,:)))
print*,'CEV',CEV

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE welfare_consumption_change


!------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
! ! Single
! DO AGE=1,RETAGE-2
!     DO IA=1,NGRIDA
!         DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 				DO IG =1,2

! 					JA = singleIDCWA(AGE,IA,IS,IE,IG)
! 					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					
! 					single_util_C = single_util_C + ( (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) )*singleYW(AGE,IA,IS,IE,IG) 
									
! 					IF (IG==1) THEN 				
! 						single_util_LS = single_util_LS - (theta*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male))*singleYW(AGE,IA,IS,IE,IG) 
! 					ELSEIF (IG==2) THEN 
! 						single_util_LS = single_util_LS - (theta*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female))*singleYW(AGE,IA,IS,IE,IG)
! 					END IF 

! 					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 
! 						    discount_V = discount_V + (BETA*sum( P(IS,:,IG)*( singleVW(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVW(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))*singleYW(AGE,IA,IS,IE,IG)
! 							EXIT 
                
! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH
! 							discount_V = discount_V + (BETA*sum( P(IS,:,IG)*singleVW(AGE+1,JA,:,JE,IG) ))*singleYW(AGE,IA,IS,IE,IG)
! 							EXIT

! 						END IF
! 					END DO

! 				END DO 
!             END DO
!         END DO
!     END DO
! END DO

! AGE=RETAGE-1
!     DO IA=1,NGRIDA
!         DO IS=1,nn
! 			DO IE=1,NGRIDEH
! 				DO IG =1,2

! 					JA = singleIDCWA(AGE,IA,IS,IE,IG)
! 					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					
! 					single_util_C = single_util_C + ( (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) )*singleYW(AGE,IA,IS,IE,IG) 
									
! 					IF (IG==1) THEN 				
! 						single_util_LS = single_util_LS - (theta*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male))*singleYW(AGE,IA,IS,IE,IG) 
! 					ELSEIF (IG==2) THEN 
! 						single_util_LS = single_util_LS - (theta*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female))*singleYW(AGE,IA,IS,IE,IG)
! 					END IF 

! 					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 
! 						    discount_V = discount_V + (BETA*( singleVR(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVR(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ))*singleYW(AGE,IA,IS,IE,IG)
! 							EXIT 
                
! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH
! 							discount_V = discount_V + (BETA*singleVR(AGE+1,JA,JE,IG))*singleYW(AGE,IA,IS,IE,IG)
! 							EXIT

! 						END IF
! 					END DO

! 				END DO
!         END DO
!     END DO
! END DO

! ! Single retiree
! DO AGE = RETAGE,MAXAGE-1
!     DO IA=1,NGRIDA
! 		DO IE=1,NGRIDEH
! 			DO IG =1,2

! 				JA = singleIDCRA(AGE,IA,IE,IG)

! 				single_util_C = single_util_C + ( (singleIDCRC(AGE,IA,IE,IG)**(1-sigma))/(1-sigma) )*singleYR(AGE,IA,IE,IG) 
							
! 				discount_V = discount_V + (BETA*S(AGE,IG)*singleVR(AGE+1,JA,IE,IG))*singleYR(AGE,IA,IE,IG)

! 			END DO 
! 		END DO 
!     END DO
! END DO 

! AGE = MAXAGE
!     DO IA=1,NGRIDA
! 		DO IE=1,NGRIDEH
! 			DO IG =1,2

! 				single_util_C = single_util_C + ( (singleIDCRC(AGE,IA,IE,IG)**(1-sigma))/(1-sigma) )*singleYR(AGE,IA,IE,IG) 

! 			END DO 
!     	END DO
! 	END DO 


! ! Couple
! DO AGE = 1,RETAGE-2
!     DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
! 					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
! 					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

! 					single_util_C = single_util_C + ((2*(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma))*coupleYW(AGE,IA,IS1,IS2,IE)

! 					single_util_LS = single_util_LS - (theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))*coupleYW(AGE,IA,IS1,IS2,IE) &
! 								 - (theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))*coupleYW(AGE,IA,IS1,IS2,IE)
					
! 					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0/5.0)/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 
! 							sum_temp = 0.0
! 							DO NEWIS = 1,nn				  			
! 								sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( coupleVW(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVW(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
! 							END DO
! 							EXIT   

! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH
! 							sum_temp = 0.0
! 							DO NEWIS = 1,nn				  			
! 								sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*coupleVW(AGE+1,JA,NEWIS,:,JE)  ))
! 							END DO

! 						END IF
! 					END DO 

! 					discount_V = discount_V + (BETA*sum_temp)*coupleYW(AGE,IA,IS1,IS2,IE)

! 				END DO 
!             END DO
!         END DO 
!     END DO
! END DO 

! AGE = RETAGE-1
! 	DO IA = 1,NGRIDA           			
!         DO IS1 = 1,nn 
! 			DO IS2=1,nn 
! 				DO IE=1,NGRIDEH

! 					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
! 					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
! 					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

! 					single_util_C = single_util_C + ((2*(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma))*coupleYW(AGE,IA,IS1,IS2,IE)

! 					single_util_LS = single_util_LS - (theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male))*coupleYW(AGE,IA,IS1,IS2,IE) &
! 								 - (theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female))*coupleYW(AGE,IA,IS1,IS2,IE)
					
! 					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0/5.0)/AGE 
! 					DO i=1,NGRIDEH
! 						IF(EH(i)>EH_temp) THEN 
! 							JE = i-1 
! 							discount_V = discount_V + (BETA*( coupleVR(AGE+1,JA,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ))*coupleYW(AGE,IA,IS1,IS2,IE)
														
! 							EXIT   

! 						ELSEIF (i==NGRIDEH) THEN  
! 							JE = NGRIDEH  
! 							discount_V = discount_V + (BETA*coupleVR(AGE+1,JA,JE))*coupleYW(AGE,IA,IS1,IS2,IE)
						
! 							EXIT

! 						END IF
! 					END DO 

! 				END DO
!        	 	END DO 
!     	END DO
! 	END DO 

! ! Couple retiree
! DO AGE = RETAGE,MAXAGE-1
!     DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH

! 			JA = coupleIDCRA(AGE,IA,IE)

! 			single_util_C = single_util_C + ((2*(coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma))*coupleYR(AGE,IA,IE)

! 			discount_V = discount_V + ( BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
! 						+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
! 						+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) )*coupleYR(AGE,IA,IE)

! 		END DO 
!     END DO
! END DO 

! AGE = MAXAGE
! 	DO IA = 1,NGRIDA      
! 		DO IE = 1,NGRIDEH

! 			single_util_C = single_util_C + ((2*(coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma))*coupleYR(AGE,IA,IE)

! 		END DO 
! 	END DO 
      
! CEV_optimal = ((opt_welfare - single_util_LS )/(single_util_C + discount_V))**(1.0/(1-sigma)) - 1.0

!------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ALLOCATE(vec_reform_welfare(2), vec_reform_CEV_util(2))
ALLOCATE(vec_reform_welfare_newborn(17), vec_reform_CEV_newborn(17))

! Welfare improvement of the optimal taxation in terms of CEV
! reform_welfare = -0.3452074   !ty_max 40
reform_welfare = -0.75036888	!ty_max 71
vec_reform_welfare = (/-0.72469856, -0.67487792/)	!benchmark,prog tax, cons tax

reform_CEV_util = exp( (reform_welfare - util_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
vec_reform_CEV_util = exp( (vec_reform_welfare - util_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
! CRRA utility
! CEV_optimal = (( opt_welfare - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:)) ) &
! 			  /( sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:)) + sum(single_util_C(1:RETAGE-1,:,:,:,:)) + sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:)) + sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) ) )**(1.0/(1-sigma)) - 1.0

! Log utility
! CEV_optimal = exp(( opt_welfare - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
! 			  - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:)) - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0

! reform_welfare_newborn = -0.50523608	!ty_max 40
reform_welfare_newborn = -0.47252383	!ty_max 71
vec_reform_welfare_newborn = (/-0.60251183,-0.57484155,-0.57162957,-0.55520893,-0.53612898,-0.52279637,-0.50523608,-0.49481971,-0.49327596,-0.47652487,-0.47830302,-0.46530943,-0.46329122,-0.46745372,-0.49111392,-0.51556659,-0.62699988 /)

reform_CEV_newborn = exp( (reform_welfare_newborn-veil_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
vec_reform_CEV_newborn = exp( (vec_reform_welfare_newborn-veil_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0

OPEN(UNIT=27,FILE='vec_reform_CEV_util.txt')
		write(27,*) vec_reform_CEV_util(:)
CLOSE(27)

OPEN(UNIT=27,FILE='vec_reform_CEV_newborn.txt')
		write(27,*) vec_reform_CEV_newborn(:)
CLOSE(27)

! Winner Loser Analysis in terms of CEV
IF (source_welfare/=101) THEN 	

	! cons_change_single_male_retire(:)=0.0
	! cons_change_single_female_retire(:)=0.0
	! cons_change_single_male_working(:)=0.0
	! cons_change_single_female_working(:)=0.0
	! cons_change_couple_male_retire(:)=0.0
	! cons_change_couple_female_retire(:)=0.0
	! cons_change_couple_male_working(:)=0.0
	! cons_change_couple_female_working(:)=0.0

	! ! Single retire
	! DO j=1,5
	! 	cons_change_single_male_retire(j) = ( sum(sum_bench_single_val(RETAGE:MAXAGE,j,1))  &
	! 				/( sum(sum_single_util_C(RETAGE:MAXAGE,j,1)) ) )**(1.0/(1-sigma)) - 1.0

	! 	cons_change_single_female_retire(j) = ( sum(sum_bench_single_val(RETAGE:MAXAGE,j,2))  &
	! 				/( sum(sum_single_util_C(RETAGE:MAXAGE,j,2)) ) )**(1.0/(1-sigma)) - 1.0
	! END DO

	! ! Single working
	! DO j=1,5
	! 	cons_change_single_male_working(j) = (( sum(sum_bench_single_val(1:RETAGE-1,j,1)) - sum(sum_single_util_LS(1:RETAGE-1,j,1)) ) &
	! 				/( sum(sum_single_util_C(1:RETAGE-1,j,1)) ) )**(1.0/(1-sigma)) - 1.0

	! 	cons_change_single_female_working(j) = (( sum(sum_bench_single_val(1:RETAGE-1,j,2)) - sum(sum_single_util_LS(1:RETAGE-1,j,2)) ) &
	! 				/( sum(sum_single_util_C(1:RETAGE-1,j,2)) ) )**(1.0/(1-sigma)) - 1.0				  
	! END DO 

	! ! Couple retire
	! DO j=1,5
	! 	cons_change_couple_male_retire(j) = ( sum(sum_bench_couple_val(RETAGE:MAXAGE,j,1))  &
	! 				/( sum(sum_couple_util_C(RETAGE:MAXAGE,j,1)) ) )**(1.0/(1-sigma)) - 1.0

	! 	cons_change_couple_female_retire(j) = ( sum(sum_bench_couple_val(RETAGE:MAXAGE,j,2))  &
	! 				/( sum(sum_couple_util_C(RETAGE:MAXAGE,j,2)) ) )**(1.0/(1-sigma)) - 1.0
	! END DO

	! ! Couple working
	! DO j=1,5
	! 	cons_change_couple_male_working(j) = (( sum(sum_bench_couple_val(1:RETAGE-1,j,1)) - sum(sum_couple_util_LS(1:RETAGE-1,j,1)) ) &
	! 				/( sum(sum_couple_util_C(1:RETAGE-1,j,1)) ) )**(1.0/(1-sigma)) - 1.0

	! 	cons_change_couple_female_working(j) = (( sum(sum_bench_couple_val(1:RETAGE-1,j,2)) - sum(sum_couple_util_LS(1:RETAGE-1,j,2)) ) &
	! 				/( sum(sum_couple_util_C(1:RETAGE-1,j,2)) ) )**(1.0/(1-sigma)) - 1.0				  
	! END DO 


! "xxxxx_incomethreshold" uses the benchmark policy functions
	CEV_incomethreshold(:) = 0.0
	DO j=1,5
		CEV_incomethreshold(j) = (( util_welfare_id_incomethreshold(j) - single_util_LS_incomethreshold(j) - couple_util_LS_incomethreshold(j) ) &
				/( single_util_C_incomethreshold(j) + couple_util_C_incomethreshold(j) ) )**(1.0/(1-sigma)) - 1.0
	END DO 

END IF



print*, 'opt_welfare=', opt_welfare
print*, 'bench_welfare=', util_welfare_id
print*, 'single_util_LS=', sum(single_util_LS(1:RETAGE-1,:,:,:,:))
print*, 'couple_util_LS=', sum(couple_util_LS(1:RETAGE-1,:,:,:,:))
print*, 'retire_single_util_C=', sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:))
print*, 'single_util_C=', sum(single_util_C(1:RETAGE-1,:,:,:,:))
print*, 'retire_couple_util_C=', sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:))
print*, 'couple_util_C', sum(couple_util_C(1:RETAGE-1,:,:,:,:,:))
print*, 'CEV_optimal=', CEV_optimal
print*, 'optimal_CEV_newborn=', optimal_CEV_newborn
print*, 'CEV_incomethreshold', CEV_incomethreshold(:)

! OPEN(UNIT=60,FILE='cons.txt')
! 	write(60,*) singleIDCWC
! 	write(60,*) singleIDCRC
! 	write(60,*) coupleIDCWC
! 	write(60,*) coupleIDCRC

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE winner_loser

! ALLOCATE(sum_bench_single_val(MAXAGE,5,2) )
! ALLOCATE(sum_single_util_C(MAXAGE,5,2) )
! ALLOCATE(sum_bench_couple_val(MAXAGE,5,2) )
! ALLOCATE(sum_couple_util_C(MAXAGE,5,2) )
! ALLOCATE(sum_single_util_LS(RETAGE-1,5,2) )
! ALLOCATE(sum_couple_util_LS(RETAGE-1,5,2) )

! ALLOCATE(util_welfare_id_incomethreshold(5) )
! ALLOCATE(single_util_C_incomethreshold(5) )
! ALLOCATE(couple_util_C_incomethreshold(5) )
! ALLOCATE(single_util_LS_incomethreshold(5) )
! ALLOCATE(couple_util_LS_incomethreshold(5) )

! mannually set incomethreshold as benchmark
! incomethreshold20 = 30.329477310180664	!4.7586345672607422
! incomethreshold40 = 20.284038543701172	!2.9385061264038086     
! incomethreshold60 = 12.213137626647949	!1.7834103107452393     
! incomethreshold80 = 8.1457214355468750	!1.1828738451004028
OPEN(UNIT=27,FILE='incomethreshold.txt')
	READ(27,*) incomethreshold80,incomethreshold60,incomethreshold40,incomethreshold20
CLOSE(27)
print*, 'check benchmark incomethresholds'
print*, 'bm incomethreshold20=',incomethreshold20
print*, 'bm incomethreshold40=',incomethreshold40
print*, 'bm incomethreshold60=',incomethreshold60
print*, 'bm incomethreshold80=',incomethreshold80


change_bench_singleIDCRC(:,:,:) = 0.0
change_bench_single_val(:,:,:) = 0.0
bench_singleYR_incomethreshold(:,:,:) = 0.0
change_bench_singleIDCWC(:,:,:) = 0.0
change_bench_singleIDCWN(:,:,:) = 0.0
bench_singleYW_incomethreshold(:,:,:) = 0.0
change_bench_coupleIDCRC(:,:,:) = 0.0
change_bench_couple_val(:,:,:) = 0.0
bench_coupleYR_incomethreshold(:,:,:) = 0.0
change_bench_coupleIDCWC(:,:,:) = 0.0
change_bench_coupleIDCWN(:,:,:) = 0.0
bench_coupleYW_incomethreshold(:,:,:) = 0.0


util_welfare_id_incomethreshold(:) = 0.0	! define this variable
single_util_C_incomethreshold(:) = 0.0
couple_util_C_incomethreshold(:) = 0.0
single_util_LS_incomethreshold(:) = 0.0
couple_util_LS_incomethreshold(:) = 0.0

! Single retiree	
! DO AGE=MAXAGE,RETAGE,-1
AGE=MAXAGE
    DO IA=1,NGRIDA
		DO IE=1,NGRIDEH
			DO IG =1,2

				TINCOME = SS(IE) + R*A(IA)

				IF (TINCOME<=incomethreshold80) THEN
					j=1
				ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
					j=2
				ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
					j=3
				ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
					j=4
				ELSEIF (TINCOME>incomethreshold20) THEN 
					j=5
				END IF

				util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + ( (singleIDCRC(AGE,IA,IE,IG)**(1-sigma))/(1-sigma) )*singleYR(AGE,IA,IE,IG)
				single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + bench_retire_single_util_C(AGE,IA,IE,IG)
				! single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + temp_retire_single_util_C(AGE,IA,IE,IG)*bench_singleYR(AGE,IA,IE,IG)

				! change_bench_singleIDCRC(AGE,j,IG) = change_bench_singleIDCRC(AGE,j,IG) + (singleIDCRC(AGE,IA,IE,IG) - bench_singleIDCRC(AGE,IA,IE,IG))*bench_singleYR(AGE,IA,IE,IG)
				! change_bench_single_val(AGE,j,IG) = change_bench_single_val(AGE,j,IG) + (temp_retire_single_util_C(AGE,IA,IE,IG) - bench_single_VR(AGE,IA,IE,IG))*bench_singleYR(AGE,IA,IE,IG)
				! bench_singleYR_incomethreshold(AGE,j,IG) = bench_singleYR_incomethreshold(AGE,j,IG) + bench_singleYR(AGE,IA,IE,IG)

				! sum_bench_single_val(AGE,j,IG) = sum_bench_single_val(AGE,j,IG) + bench_single_VR(AGE,IA,IE,IG)*bench_singleYR(AGE,IA,IE,IG)
				! sum_single_util_C(AGE,j,IG) = sum_single_util_C(AGE,j,IG) + temp_retire_single_util_C(AGE,IA,IE,IG)*bench_singleYR(AGE,IA,IE,IG)


			END DO 
		END DO 
    END DO
! END DO 

DO AGE = MAXAGE-1,RETAGE,-1
    DO IA=1,NGRIDA
		DO IE=1,NGRIDEH
			DO IG =1,2

				JA = singleIDCRA(AGE,IA,IE,IG)
				TINCOME = SS(IE) + R*A(IA)

				IF (TINCOME<=incomethreshold80) THEN
					j=1
				ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
					j=2
				ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
					j=3
				ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
					j=4
				ELSEIF (TINCOME>incomethreshold20) THEN 
					j=5
				END IF

				util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + ( (singleIDCRC(AGE,IA,IE,IG)**(1-sigma))/(1-sigma) + &
													 BETA*temp_retire_single_util_C(AGE+1,JA,IE,IG) )*singleYR(AGE,IA,IE,IG)
				single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + bench_retire_single_util_C(AGE,IA,IE,IG)
				! single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + temp_retire_single_util_C(AGE,IA,IE,IG)*bench_singleYR(AGE,IA,IE,IG)

			END DO 
		END DO 
    END DO
END DO 

AGE=RETAGE-1
    DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG =1,2

					JA = singleIDCWA(AGE,IA,IS,IE,IG)
					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					TINCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)+R*A(IA)

					IF (TINCOME<=incomethreshold80) THEN
						j=1
					ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
						j=2
					ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
						j=3
					ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
						j=4
					ELSEIF (TINCOME>incomethreshold20) THEN 
						j=5
					END IF

					IF (IG==1) THEN 				
						temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male)
						single_util_LS(AGE,IA,IS,IE,IG) =  temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
					ELSEIF (IG==2) THEN 
						temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female)
						single_util_LS(AGE,IA,IS,IE,IG) =  temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
					END IF

					! EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE 
					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
						    ! discount_V = discount_V + (BETA*( singleVR(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVR(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ))*singleYW(AGE,IA,IS,IE,IG)
							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*( temp_retire_single_util_C(AGE+1,JA,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_single_util_C(AGE+1,JA,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
																						
							EXIT 
                
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH
							! discount_V = discount_V + (BETA*singleVR(AGE+1,JA,JE,IG))*singleYW(AGE,IA,IS,IE,IG)
							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*temp_retire_single_util_C(AGE+1,JA,JE,IG) 
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

							EXIT

						END IF
					END DO

					util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
					single_util_LS_incomethreshold(j)  = single_util_LS_incomethreshold(j) + bench_single_util_LS(AGE,IA,IS,IE,IG)
					! single_util_LS_incomethreshold(j)  = single_util_LS_incomethreshold(j) + temp_single_util_LS(AGE,IA,IS,IE,IG)*bench_singleYW(AGE,IA,IS,IE,IG)
					single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + bench_single_util_C(AGE,IA,IS,IE,IG)
					! single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + temp_single_util_C(AGE,IA,IS,IE,IG)*bench_singleYW(AGE,IA,IS,IE,IG)


				END DO
        	END DO
    	END DO
	END DO


! Single working
DO AGE=RETAGE-2,1,-1
    DO IA=1,NGRIDA
        DO IS=1,nn
			DO IE=1,NGRIDEH
				DO IG =1,2

					JA = singleIDCWA(AGE,IA,IS,IE,IG)
					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					TINCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + R*A(IA)

					IF (TINCOME<=incomethreshold80) THEN
						j=1
					ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
						j=2
					ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
						j=3
					ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
						j=4
					ELSEIF (TINCOME>incomethreshold20) THEN 
						j=5
					END IF

					! EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN)/5.0)/AGE
					EH_temp = ((AGE-1)*EH(IE)+WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
						    ! discount_V = discount_V + (BETA*sum( P(IS,:,IG)*( singleVW(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVW(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))*singleYW(AGE,IA,IS,IE,IG)
							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*sum( P(IS,:,IG)*( temp_single_util_C(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_C(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
							
							IF (IG==1) THEN 				
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum( P(IS,:,IG)*( temp_single_util_LS(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_LS(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							ELSEIF (IG==2) THEN 
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum( P(IS,:,IG)*( temp_single_util_LS(AGE+1,JA,:,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_single_util_LS(AGE+1,JA,:,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							END IF
							
							EXIT 
                
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH
							! discount_V = discount_V + (BETA*sum( P(IS,:,IG)*singleVW(AGE+1,JA,:,JE,IG) ))*singleYW(AGE,IA,IS,IE,IG)
							temp_single_util_C(AGE,IA,IS,IE,IG) =  (singleIDCWC(AGE,IA,IS,IE,IG)**(1-sigma))/(1-sigma) + BETA*sum( P(IS,:,IG)*temp_single_util_C(AGE+1,JA,:,JE,IG) )
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

							IF (IG==1) THEN 				
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_male*(N(JN)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum( P(IS,:,IG)*temp_single_util_LS(AGE+1,JA,:,JE,IG) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							ELSEIF (IG==2) THEN 
								temp_single_util_LS(AGE,IA,IS,IE,IG) =  - theta_single_female*(N(JN)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum( P(IS,:,IG)*temp_single_util_LS(AGE+1,JA,:,JE,IG) )
								single_util_LS(AGE,IA,IS,IE,IG) = temp_single_util_LS(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG) 
							END IF

							EXIT

						END IF
					END DO

					util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
					! single_util_LS_incomethreshold(j)  = single_util_LS_incomethreshold(j) + temp_single_util_LS(AGE,IA,IS,IE,IG)*bench_singleYW(AGE,IA,IS,IE,IG)
					single_util_LS_incomethreshold(j)  = single_util_LS_incomethreshold(j) + bench_single_util_LS(AGE,IA,IS,IE,IG)
					! single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + temp_single_util_C(AGE,IA,IS,IE,IG)*bench_singleYW(AGE,IA,IS,IE,IG)
					single_util_C_incomethreshold(j)   = single_util_C_incomethreshold(j) + bench_single_util_C(AGE,IA,IS,IE,IG)

				END DO
        	END DO
    	END DO
	END DO
END DO 

! Couple retiree
AGE = MAXAGE
	DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH

			TINCOME = 2*SS(IE) + R*A(IA)

			IF (TINCOME<=incomethreshold80) THEN
				j=1
			ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
				j=2
			ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
				j=3
			ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
				j=4
			ELSEIF (TINCOME>incomethreshold20) THEN 
				j=5
			END IF

			DO IG =1,2
				temp_retire_couple_util_C(AGE,IA,IE,IG) = ((coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma)
				retire_couple_util_C(AGE,IA,IE,IG) =  temp_retire_couple_util_C(AGE,IA,IE,IG)*coupleYR(AGE,IA,IE) 		
				util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + retire_couple_util_C(AGE,IA,IE,IG)
			END DO
			! couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + (temp_retire_couple_util_C(AGE,IA,IE,1)+temp_retire_couple_util_C(AGE,IA,IE,2))*bench_coupleYR(AGE,IA,IE)	
			couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + bench_retire_couple_util_C(AGE,IA,IE,1) + bench_retire_couple_util_C(AGE,IA,IE,2)

		END DO 
	END DO


DO AGE = MAXAGE-1,RETAGE,-1
    DO IA = 1,NGRIDA      
		DO IE = 1,NGRIDEH
			
			JA = coupleIDCRA(AGE,IA,IE)
			TINCOME = 2*SS(IE) + R*A(IA)

			IF (TINCOME<=incomethreshold80) THEN
				j=1
			ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
				j=2
			ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
				j=3
			ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
				j=4
			ELSEIF (TINCOME>incomethreshold20) THEN 
				j=5
			END IF

			temp_retire_couple_util_C(AGE,IA,IE,1) =  ((coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma) + BETA*S(AGE,1)*S(AGE,2)*temp_retire_couple_util_C(AGE+1,JA,IE,1) &
														+ BETA*S(AGE,1)*(1-S(AGE,2))*temp_retire_single_util_C(AGE+1,JA,IE,1) 
												

			temp_retire_couple_util_C(AGE,IA,IE,2) =  ((coupleIDCRC(AGE,IA,IE)/eta)**(1-sigma))/(1-sigma) + BETA*S(AGE,1)*S(AGE,2)*temp_retire_couple_util_C(AGE+1,JA,IE,2) &
														+ BETA*S(AGE,2)*(1-S(AGE,1))*temp_retire_single_util_C(AGE+1,JA,IE,2)
												

			retire_couple_util_C(AGE,IA,IE,1) =  temp_retire_couple_util_C(AGE,IA,IE,1)*coupleYR(AGE,IA,IE) 
			retire_couple_util_C(AGE,IA,IE,2) =  temp_retire_couple_util_C(AGE,IA,IE,2)*coupleYR(AGE,IA,IE)

			util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + retire_couple_util_C(AGE,IA,IE,1) +	retire_couple_util_C(AGE,IA,IE,2)	
			! couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + (temp_retire_couple_util_C(AGE,IA,IE,1)+temp_retire_couple_util_C(AGE,IA,IE,2))*bench_coupleYR(AGE,IA,IE)	
			couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + bench_retire_couple_util_C(AGE,IA,IE,1) + bench_retire_couple_util_C(AGE,IA,IE,2)

		END DO 
    END DO
END DO 


AGE = RETAGE-1
	DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					TINCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)
					
					IF (TINCOME<=incomethreshold80) THEN
						j=1
					ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
						j=2
					ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
						j=3
					ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
						j=4
					ELSEIF (TINCOME>incomethreshold20) THEN 
						j=5
					END IF

					temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) 
					temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female)
					couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)

					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0)/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 
							
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*( temp_retire_couple_util_C(AGE+1,JA,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*( temp_retire_couple_util_C(AGE+1,JA,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
														
							EXIT   

						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH  
							
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*temp_retire_couple_util_C(AGE+1,JA,JE,1)
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*temp_retire_couple_util_C(AGE+1,JA,JE,2) 
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
						
							EXIT

						END IF
					END DO 

					util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)
					! couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + (temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_C(AGE,IA,IS1,IS2,IE,2))*bench_coupleYW(AGE,IA,IS1,IS2,IE)
					couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + bench_couple_util_C(AGE,IA,IS1,IS2,IE,1) + bench_couple_util_C(AGE,IA,IS1,IS2,IE,2)
					! couple_util_LS_incomethreshold(j) = couple_util_LS_incomethreshold(j) + (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*bench_coupleYW(AGE,IA,IS1,IS2,IE)
					couple_util_LS_incomethreshold(j) = couple_util_LS_incomethreshold(j) + bench_couple_util_LS(AGE,IA,IS1,IS2,IE)
				END DO
       	 	END DO 
    	END DO
	END DO 


DO AGE = RETAGE-2,1,-1
    DO IA = 1,NGRIDA           			
        DO IS1 = 1,nn 
			DO IS2=1,nn 
				DO IE=1,NGRIDEH

					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					TINCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + R*A(IA)

					IF (TINCOME<=incomethreshold80) THEN
						j=1
					ELSEIF ( (TINCOME>incomethreshold80) .AND. (TINCOME<=incomethreshold60) ) THEN 
						j=2
					ELSEIF ( (TINCOME>incomethreshold60) .AND. (TINCOME<=incomethreshold40) ) THEN 
						j=3
					ELSEIF ( (TINCOME>incomethreshold40) .AND. (TINCOME<=incomethreshold20) ) THEN 
						j=4
					ELSEIF (TINCOME>incomethreshold20) THEN 
						j=5
					END IF

					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/2.0)/AGE 
					DO i=1,NGRIDEH
						IF(EH(i)>EH_temp) THEN 
							JE = i-1 

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn
								DO NEWIS2 = 1,nn	

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									sum_temp1 = sum_temp1 + P_joint*( temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
									sum_temp2 = sum_temp2 + P_joint*( temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
								
								END DO 
							END DO

							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp1
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp2
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)

							! sum_temp = 0.0
							! DO NEWIS = 1,nn				  			
							! 	sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
							! END DO

							! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp
							! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn
								DO NEWIS2 = 1,nn	

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									sum_temp1 = sum_temp1 + P_joint*( temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
									sum_temp2 = sum_temp2 + P_joint*( temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
								
								END DO 
							END DO

							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum_temp1 
							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp2
							couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)

							EXIT   

						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn
								DO NEWIS2 = 1,nn	

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									sum_temp1 = sum_temp1 + P_joint*temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,1)  
									sum_temp2 = sum_temp2 + P_joint*temp_couple_util_C(AGE+1,JA,NEWIS1,NEWIS2,JE,2)

								END DO 
							END DO

							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp1
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  ((coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta)**(1-sigma))/(1-sigma) + BETA*sum_temp2
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)

							! sum_temp = 0.0
							! DO NEWIS = 1,nn				  			
							! 	sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*temp_couple_util_LS(AGE+1,JA,NEWIS,:,JE)  ))
							! END DO

							! temp_couple_util_LS(AGE,IA,IS1,IS2,IE) =  - theta*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) - theta*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp
							! couple_util_LS(AGE,IA,IS1,IS2,IE) =  temp_couple_util_LS(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)

							sum_temp1 = 0.0
							sum_temp2 = 0.0
							DO NEWIS1 = 1,nn
								DO NEWIS2 = 1,nn	

									IF (IS1==IS2) THEN
										P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
											+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
									ELSE
										P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
									END IF

									sum_temp1 = sum_temp1 + P_joint*temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,1)
									sum_temp2 = sum_temp2 + P_joint*temp_couple_util_LS(AGE+1,JA,NEWIS1,NEWIS2,JE,2)

								END DO 
							END DO

							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1) = - theta_married_male*(N(JN1)**(1+sigma_lab_male))/(1+sigma_lab_male) + BETA*sum_temp1
							temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2) = - theta_married_female*(N(JN2)**(1+sigma_lab_female))/(1+sigma_lab_female) + BETA*sum_temp2
							couple_util_LS(AGE,IA,IS1,IS2,IE) =  (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)
						
							EXIT

						END IF
					END DO 

					util_welfare_id_incomethreshold(j) = util_welfare_id_incomethreshold(j) + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)
					! couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + (temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_C(AGE,IA,IS1,IS2,IE,2))*bench_coupleYW(AGE,IA,IS1,IS2,IE)
					couple_util_C_incomethreshold(j) = couple_util_C_incomethreshold(j) + bench_couple_util_C(AGE,IA,IS1,IS2,IE,1) + bench_couple_util_C(AGE,IA,IS1,IS2,IE,2)
					! couple_util_LS_incomethreshold(j) = couple_util_LS_incomethreshold(j) + (temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2))*bench_coupleYW(AGE,IA,IS1,IS2,IE)
					couple_util_LS_incomethreshold(j) = couple_util_LS_incomethreshold(j) + bench_couple_util_LS(AGE,IA,IS1,IS2,IE)

				END DO 
            END DO
        END DO 
    END DO
END DO 

OPEN(UNIT=27,FILE='util_welfare_id_incomethreshold.txt')
	write(27,*) util_welfare_id_incomethreshold
CLOSE(27)

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE insurance

ALLOCATE(log_income_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_log_income_diff_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)))
ALLOCATE(log_income_shock_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_log_income_shock_diff_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)) )
ALLOCATE(log_cons_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_log_cons_diff_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)) )
ALLOCATE(dist_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_dist_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)) )
ALLOCATE(log_income_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2), ageprofile_log_income_diff_couple(NGRIDA*nn*nn*NGRIDEH*nn*nn*2,(RETAGE-2)) )
ALLOCATE(log_income_shock_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2), ageprofile_log_income_shock_diff_couple(NGRIDA*nn*nn*NGRIDEH*nn*nn*2,(RETAGE-2)) )
ALLOCATE(log_cons_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2), ageprofile_log_cons_diff_couple(NGRIDA*nn*nn*NGRIDEH*nn*nn*2,(RETAGE-2)) )
ALLOCATE(dist_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2), ageprofile_dist_couple(NGRIDA*nn*nn*NGRIDEH*nn*nn*2,(RETAGE-2)) )
ALLOCATE(ageprofile_avg_log_income_shock_single(RETAGE-2), ageprofile_avg_log_income_shock_couple(RETAGE-2))
ALLOCATE(ageprofile_avg_log_income_single(RETAGE-2), ageprofile_avg_log_income_couple(RETAGE-2))
ALLOCATE(ageprofile_avg_log_cons_single(RETAGE-2), ageprofile_avg_log_cons_couple(RETAGE-2))
ALLOCATE(ageprofile_insurance_cons_shock_nominator_single(RETAGE-2), ageprofile_insurance_cons_shock_nominator_couple(RETAGE-2))
ALLOCATE(ageprofile_insurance_cons_shock_denominator_single(RETAGE-2), ageprofile_insurance_cons_shock_denominator_couple(RETAGE-2))
ALLOCATE(ageprofile_insurance_cons_shock_value_single(RETAGE-2), ageprofile_insurance_cons_shock_value_couple(RETAGE-2))
ALLOCATE(ageprofile_insurance_cons_nominator_single(RETAGE-2), ageprofile_insurance_cons_nominator_couple(RETAGE-2))
ALLOCATE(ageprofile_insurance_cons_denominator_single(RETAGE-2), ageprofile_insurance_cons_denominator_couple(RETAGE-2))
ALLOCATE(ageprofile_insurance_cons_value_single(RETAGE-2), ageprofile_insurance_cons_value_couple(RETAGE-2))

! Single working
individ = 0
DO AGE=1,RETAGE-2
individ_age = 0
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2
					
					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					JA = singleIDCWA(AGE,IA,IS,IE,IG) 
					z_shock = W(IS,IG)
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)
					consumption = singleIDCWC(AGE,IA,IS,IE,IG)
					EH_temp = ((AGE-1)*EH(IE) + WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/(AGE)
					
					IF ((INCOME <= 1.D-4) .OR. (consumption <= 1.D-4)) THEN 
						GO TO 688
					END IF 

						DO NEWIS = 1,nn
							DO i=1,NGRIDEH

								IF(EH(i)>EH_temp) THEN 
									NEWIE = i-1 				
							 
										JN=singleIDCWN(AGE+1,JA,NEWIS,NEWIE,IG)
										z_shock_next = W(NEWIS,IG)
										INCOME_next = WAGE*EFFLONG(AGE+1,IG)*N(JN)*W(NEWIS,IG)
										consumption_next = singleIDCWC(AGE+1,JA,NEWIS,NEWIE,IG)
										IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
											EXIT
										END IF 
										individ = individ + 1
										individ_age = individ_age + 1
									! change in log = approximate percentage change
										log_income_shock_diff_single(individ) = log(z_shock_next) - log(z_shock)
										log_income_diff_single(individ) = log(INCOME_next) - log(INCOME)
										log_cons_diff_single(individ) = log(consumption_next) - log(consumption)

										ageprofile_log_income_shock_diff_single(individ_age,AGE) = log(z_shock_next) - log(z_shock)
										ageprofile_log_income_diff_single(individ_age,AGE) = log(INCOME_next) - log(INCOME)
										ageprofile_log_cons_diff_single(individ_age,AGE) = log(consumption_next) - log(consumption)

										dist_single(individ) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
										ageprofile_dist_single(individ_age,AGE) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))

										JN=singleIDCWN(AGE+1,JA,NEWIS,NEWIE+1,IG)
										z_shock_next = W(NEWIS,IG) 
										INCOME_next = WAGE*EFFLONG(AGE+1,IG)*N(JN)*W(NEWIS,IG)
										consumption_next = singleIDCWC(AGE+1,JA,NEWIS,NEWIE+1,IG)
										IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
											EXIT
										END IF 
										individ = individ + 1
										individ_age = individ_age + 1
									! change in log = approximate percentage change
										log_income_shock_diff_single(individ) = log(z_shock_next) - log(z_shock)
										log_income_diff_single(individ) = log(INCOME_next) - log(INCOME)
										log_cons_diff_single(individ) = log(consumption_next) - log(consumption)

										ageprofile_log_income_shock_diff_single(individ_age,AGE) = log(z_shock_next) - log(z_shock)
										ageprofile_log_income_diff_single(individ_age,AGE) = log(INCOME_next) - log(INCOME)
										ageprofile_log_cons_diff_single(individ_age,AGE) = log(consumption_next) - log(consumption)

										dist_single(individ) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
										ageprofile_dist_single(individ_age,AGE) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))

									EXIT
								ELSEIF (i==NGRIDEH) THEN 
									NEWIE = NGRIDEH 

										JN=singleIDCWN(AGE+1,JA,NEWIS,NEWIE,IG)
										z_shock_next = W(NEWIS,IG)
										INCOME_next = WAGE*EFFLONG(AGE+1,IG)*N(JN)*W(NEWIS,IG)
										consumption_next = singleIDCWC(AGE+1,JA,NEWIS,NEWIE,IG)
										IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
											EXIT
										END IF 
										individ = individ + 1
										individ_age = individ_age + 1
									! change in log = approximate percentage change
										log_income_shock_diff_single(individ) = log(z_shock_next) - log(z_shock)	
										log_income_diff_single(individ) = log(INCOME_next) - log(INCOME)
										log_cons_diff_single(individ) = log(consumption_next) - log(consumption)

										ageprofile_log_income_shock_diff_single(individ_age,AGE) = log(z_shock_next) - log(z_shock)
										ageprofile_log_income_diff_single(individ_age,AGE) = log(INCOME_next) - log(INCOME)
										ageprofile_log_cons_diff_single(individ_age,AGE) = log(consumption_next) - log(consumption)

										dist_single(individ) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)
										ageprofile_dist_single(individ_age,AGE) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)
									EXIT
								END IF

							END DO 
						END DO
688 continue					
				END DO 
			END DO 	 
		END DO
    END DO
END DO

! Couple working
individ = 0
DO AGE=1,RETAGE-2
individ_age = 0
    DO IA=1,NGRIDA
		DO IS1 = 1,nn 
			DO IS2 = 1,nn 
				DO IE=1,NGRIDEH

					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					JA  = coupleIDCWA(AGE,IA,IS1,IS2,IE) 
					z_shock1 = W(IS1,1) 
					z_shock2 = W(IS2,2)	
					INCOME1 = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1)
					INCOME2 = WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)
					INCOME = INCOME1 + INCOME2
					consumption = coupleIDCWC(AGE,IA,IS1,IS2,IE)
					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2))/2.0)/(AGE) 

					IF ((INCOME1 <= 1.D-4) .OR. (INCOME2 <= 1.D-4) .OR. (consumption <= 1.D-4)) THEN
						GO TO 689
					END IF 
					
						DO NEWIS1 = 1,nn 
							DO NEWIS2 = 1,nn

								IF (IS1==IS2) THEN
									P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
										+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
								ELSE
									P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
								END IF

								DO i=1,NGRIDEH
									IF(EH(i)>EH_temp) THEN
										NEWIE = i-1							

											JN1 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE,1) 
											JN2 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE,2)
											z_shock1_next = W(NEWIS1,1)
											z_shock2_next = W(NEWIS2,2)
											z_shock_next = z_shock1_next + z_shock2_next
											INCOME1_next = WAGE*EFFLONG(AGE+1,1)*N(JN1)*W(NEWIS1,1)
											INCOME2_next = WAGE*EFFLONG(AGE+1,2)*N(JN2)*W(NEWIS2,2)
											INCOME_next = INCOME1_next + INCOME2_next
											consumption_next = coupleIDCWC(AGE+1,JA,NEWIS1,NEWIS2,NEWIE)
											IF ((INCOME1_next <= 1.D-4) .OR. (INCOME2_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN
												EXIT
											END IF 
											individ = individ + 1
											individ_age = individ_age + 1
										! change in log = approximate percentage change
											! log_income_diff_couple(individ) = log(INCOME_next) - log(INCOME)
											log_income_shock_diff_couple(individ) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											log_income_diff_couple(individ) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											log_cons_diff_couple(individ) = log(consumption_next) - log(consumption)

											ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											ageprofile_log_cons_diff_couple(individ_age,AGE) = log(consumption_next) - log(consumption)

											dist_couple(individ) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
											ageprofile_dist_couple(individ_age,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))

											JN1 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE+1,1) 
											JN2 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE+1,2)
											z_shock1_next = W(NEWIS1,1)
											z_shock2_next = W(NEWIS2,2)
											z_shock_next = z_shock1_next + z_shock2_next
											INCOME1_next = WAGE*EFFLONG(AGE+1,1)*N(JN1)*W(NEWIS1,1)
											INCOME2_next = WAGE*EFFLONG(AGE+1,2)*N(JN2)*W(NEWIS2,2)
											INCOME_next = INCOME1_next + INCOME2_next
											consumption_next = coupleIDCWC(AGE+1,JA,NEWIS1,NEWIS2,NEWIE+1)
											IF ((INCOME1_next <= 1.D-4) .OR. (INCOME2_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN
												EXIT
											END IF 
											individ = individ + 1
											individ_age = individ_age + 1
										! change in log = approximate percentage change
											! log_income_diff_couple(individ) = log(INCOME_next) - log(INCOME)
											log_income_shock_diff_couple(individ) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											log_income_diff_couple(individ) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											log_cons_diff_couple(individ) = log(consumption_next) - log(consumption)

											ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											ageprofile_log_cons_diff_couple(individ_age,AGE) = log(consumption_next) - log(consumption)

											dist_couple(individ) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
											ageprofile_dist_couple(individ_age,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
										EXIT
									ELSEIF (i==NGRIDEH) THEN 
										NEWIE = NGRIDEH 

											JN1 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE,1) 
											JN2 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE,2)
											z_shock1_next = W(NEWIS1,1)
											z_shock2_next = W(NEWIS2,2)
											z_shock_next = z_shock1_next + z_shock2_next
											INCOME1_next = WAGE*EFFLONG(AGE+1,1)*N(JN1)*W(NEWIS1,1)
											INCOME2_next = WAGE*EFFLONG(AGE+1,2)*N(JN2)*W(NEWIS2,2)
											INCOME_next = INCOME1_next + INCOME2_next
											consumption_next = coupleIDCWC(AGE+1,JA,NEWIS1,NEWIS2,NEWIE)
											IF ((INCOME1_next <= 1.D-4) .OR. (INCOME2_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN  
												EXIT
											END IF 
											individ = individ + 1
											individ_age = individ_age + 1
										! change in log = approximate percentage change
											! log_income_diff_couple(individ) = log(INCOME_next) - log(INCOME)
											log_income_shock_diff_couple(individ) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											log_income_diff_couple(individ) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											log_cons_diff_couple(individ) = log(consumption_next) - log(consumption)

											ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											ageprofile_log_cons_diff_couple(individ_age,AGE) = log(consumption_next) - log(consumption)

											dist_couple(individ) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint
											ageprofile_dist_couple(individ_age,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint
										EXIT
									END IF
								END DO

							END DO 
						END DO 
689 continue
				END DO 
			END DO 	 
		END DO
    END DO
END DO

avg_log_income_shock = (SUM(log_income_shock_diff_single(:)*dist_single(:)) + SUM(log_income_shock_diff_couple(:)*dist_couple(:)))/(SUM(dist_single)+SUM(dist_couple))
avg_log_income_shock_single = (SUM(log_income_shock_diff_single(:)*dist_single(:)))/SUM(dist_single)
avg_log_income_shock_couple = (SUM(log_income_shock_diff_couple(:)*dist_couple(:)))/SUM(dist_couple)

avg_log_income = (SUM(log_income_diff_single(:)*dist_single(:)) + SUM(log_income_diff_couple(:)*dist_couple(:)))/(SUM(dist_single)+SUM(dist_couple))
avg_log_income_single = (SUM(log_income_diff_single(:)*dist_single(:)))/SUM(dist_single)
avg_log_income_couple = (SUM(log_income_diff_couple(:)*dist_couple(:)))/SUM(dist_couple)

avg_log_cons = (SUM(log_cons_diff_single(:)*dist_single(:)) + SUM(log_cons_diff_couple(:)*dist_couple(:)))/(SUM(dist_single)+SUM(dist_couple))
avg_log_cons_single = (SUM(log_cons_diff_single(:)*dist_single(:)))/SUM(dist_single)
avg_log_cons_couple = (SUM(log_cons_diff_couple(:)*dist_couple(:)))/SUM(dist_couple)

insurance_cons_nominator   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock)*(log_cons_diff_single(:)-avg_log_cons)*dist_single(:) ) + SUM( (log_income_shock_diff_couple(:)-avg_log_income_shock)*(log_cons_diff_couple(:)-avg_log_cons)*dist_couple(:) )
insurance_cons_denominator = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock)**2.0)*dist_single(:) ) + SUM( ((log_income_shock_diff_couple(:)-avg_log_income_shock)**2.0)*dist_couple(:) )
insurance_cons_value = insurance_cons_nominator/insurance_cons_denominator

insurance_labor_nominator   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock)*(log_income_diff_single(:)-avg_log_income)*dist_single(:) ) + SUM( (log_income_shock_diff_couple(:)-avg_log_income_shock)*(log_income_diff_couple(:)-avg_log_income)*dist_couple(:) )
insurance_labor_denominator = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock)**2.0)*dist_single(:) ) + SUM( ((log_income_shock_diff_couple(:)-avg_log_income_shock)**2.0)*dist_couple(:) )
insurance_labor_value = insurance_labor_nominator/insurance_labor_denominator

insurance_nominator   = SUM( (log_income_diff_single(:)-avg_log_income)*(log_cons_diff_single(:)-avg_log_cons)*dist_single(:) ) + SUM( (log_income_diff_couple(:)-avg_log_income)*(log_cons_diff_couple(:)-avg_log_cons)*dist_couple(:) )
insurance_denominator = SUM( ((log_income_diff_single(:)-avg_log_income)**2.0)*dist_single(:) ) + SUM( ((log_income_diff_couple(:)-avg_log_income)**2.0)*dist_couple(:) )
insurance_value = insurance_nominator/insurance_denominator

insurance_cons_nominator_single   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock_single)*(log_cons_diff_single(:)-avg_log_cons_single)*dist_single(:) )
insurance_cons_denominator_single = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock_single)**2.0)*dist_single(:) )
insurance_cons_value_single = insurance_cons_nominator_single/insurance_cons_denominator_single

insurance_labor_nominator_single   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock_single)*(log_income_diff_single(:)-avg_log_income_single)*dist_single(:) )
insurance_labor_denominator_single = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock_single)**2.0)*dist_single(:) )
insurance_labor_value_single = insurance_labor_nominator_single/insurance_labor_denominator_single

insurance_nominator_single   = SUM( (log_income_diff_single(:)-avg_log_income_single)*(log_cons_diff_single(:)-avg_log_cons_single)*dist_single(:) )
insurance_denominator_single = SUM( ((log_income_diff_single(:)-avg_log_income_single)**2.0)*dist_single(:) )
insurance_value_single = insurance_nominator_single/insurance_denominator_single

insurance_cons_nominator_couple   = SUM( (log_income_shock_diff_couple(:)-avg_log_income_shock_couple)*(log_cons_diff_couple(:)-avg_log_cons_couple)*dist_couple(:) )
insurance_cons_denominator_couple = SUM( ((log_income_shock_diff_couple(:)-avg_log_income_shock_couple)**2.0)*dist_couple(:) )
insurance_cons_value_couple = insurance_cons_nominator_couple/insurance_cons_denominator_couple

insurance_labor_nominator_couple   = SUM( (log_income_shock_diff_couple(:)-avg_log_income_shock_couple)*(log_income_diff_couple(:)-avg_log_income_couple)*dist_couple(:) )
insurance_labor_denominator_couple = SUM( ((log_income_shock_diff_couple(:)-avg_log_income_shock_couple)**2.0)*dist_couple(:) )
insurance_labor_value_couple = insurance_labor_nominator_couple/insurance_labor_denominator_couple

insurance_nominator_couple   = SUM( (log_income_diff_couple(:)-avg_log_income_couple)*(log_cons_diff_couple(:)-avg_log_cons_couple)*dist_couple(:) )
insurance_denominator_couple = SUM( ((log_income_diff_couple(:)-avg_log_income_couple)**2.0)*dist_couple(:) )
insurance_value_couple = insurance_nominator_couple/insurance_denominator_couple

! Age profile insurance
DO AGE=1,RETAGE-2
	ageprofile_avg_log_income_shock_single(AGE) = SUM(ageprofile_log_income_shock_diff_single(:,AGE)*ageprofile_dist_single(:,AGE))/SUM(ageprofile_dist_single(:,AGE))
	ageprofile_avg_log_income_shock_couple(AGE) = SUM(ageprofile_log_income_shock_diff_couple(:,AGE)*ageprofile_dist_couple(:,AGE))/SUM(ageprofile_dist_couple(:,AGE))

	ageprofile_avg_log_income_single(AGE) = SUM(ageprofile_log_income_diff_single(:,AGE)*ageprofile_dist_single(:,AGE))/SUM(ageprofile_dist_single(:,AGE))
	ageprofile_avg_log_income_couple(AGE) = SUM(ageprofile_log_income_diff_couple(:,AGE)*ageprofile_dist_couple(:,AGE))/SUM(ageprofile_dist_couple(:,AGE))
	
	ageprofile_avg_log_cons_single(AGE) = SUM(ageprofile_log_cons_diff_single(:,AGE)*ageprofile_dist_single(:,AGE))/SUM(ageprofile_dist_single(:,AGE))
	ageprofile_avg_log_cons_couple(AGE) = SUM(ageprofile_log_cons_diff_couple(:,AGE)*ageprofile_dist_couple(:,AGE))/SUM(ageprofile_dist_couple(:,AGE))
END DO 
DO AGE=1,RETAGE-2
	ageprofile_insurance_cons_shock_nominator_single(AGE)   = SUM( (ageprofile_log_income_shock_diff_single(:,AGE)-ageprofile_avg_log_income_shock_single(AGE))*(ageprofile_log_cons_diff_single(:,AGE)-ageprofile_avg_log_cons_single(AGE))*ageprofile_dist_single(:,AGE) )	
	ageprofile_insurance_cons_shock_denominator_single(AGE) = SUM( ((ageprofile_log_income_shock_diff_single(:,AGE)-ageprofile_avg_log_income_shock_single(AGE))**2.0)*ageprofile_dist_single(:,AGE) )
	ageprofile_insurance_cons_shock_value_single(AGE) = ageprofile_insurance_cons_shock_nominator_single(AGE)/ageprofile_insurance_cons_shock_denominator_single(AGE)

	ageprofile_insurance_cons_shock_nominator_couple(AGE)   = SUM( (ageprofile_log_income_shock_diff_couple(:,AGE)-ageprofile_avg_log_income_shock_couple(AGE))*(ageprofile_log_cons_diff_couple(:,AGE)-ageprofile_avg_log_cons_couple(AGE))*ageprofile_dist_couple(:,AGE) )
	ageprofile_insurance_cons_shock_denominator_couple(AGE) = SUM( ((ageprofile_log_income_shock_diff_couple(:,AGE)-ageprofile_avg_log_income_shock_couple(AGE))**2.0)*ageprofile_dist_couple(:,AGE) )
	ageprofile_insurance_cons_shock_value_couple(AGE) = ageprofile_insurance_cons_shock_nominator_couple(AGE)/ageprofile_insurance_cons_shock_denominator_couple(AGE)

	ageprofile_insurance_cons_nominator_single(AGE)   = SUM( (ageprofile_log_income_diff_single(:,AGE)-ageprofile_avg_log_income_single(AGE))*(ageprofile_log_cons_diff_single(:,AGE)-ageprofile_avg_log_cons_single(AGE))*ageprofile_dist_single(:,AGE) )	
	ageprofile_insurance_cons_denominator_single(AGE) = SUM( ((ageprofile_log_income_diff_single(:,AGE)-ageprofile_avg_log_income_single(AGE))**2.0)*ageprofile_dist_single(:,AGE) )
	ageprofile_insurance_cons_value_single(AGE) = ageprofile_insurance_cons_nominator_single(AGE)/ageprofile_insurance_cons_denominator_single(AGE)

	ageprofile_insurance_cons_nominator_couple(AGE)   = SUM( (ageprofile_log_income_diff_couple(:,AGE)-ageprofile_avg_log_income_couple(AGE))*(ageprofile_log_cons_diff_couple(:,AGE)-ageprofile_avg_log_cons_couple(AGE))*ageprofile_dist_couple(:,AGE) )
	ageprofile_insurance_cons_denominator_couple(AGE) = SUM( ((ageprofile_log_income_diff_couple(:,AGE)-ageprofile_avg_log_income_couple(AGE))**2.0)*ageprofile_dist_couple(:,AGE) )
	ageprofile_insurance_cons_value_couple(AGE) = ageprofile_insurance_cons_nominator_couple(AGE)/ageprofile_insurance_cons_denominator_couple(AGE)

END DO 

print*,'avg_log_income',avg_log_income
print*,'avg_log_cons',avg_log_cons
print*,'insurance_nominator',insurance_nominator
print*,'insurance_denominator',insurance_denominator
print*,'insurance_value',insurance_value

print*,'avg_log_income_single',avg_log_income_single
print*,'avg_log_cons_single',avg_log_cons_single
print*,'insurance_nominator_single',insurance_nominator_single
print*,'insurance_denominator_single',insurance_denominator_single
print*,'insurance_value_single',insurance_value_single

print*,'avg_log_income_couple',avg_log_income_couple
print*,'avg_log_cons_couple',avg_log_cons_couple
print*,'insurance_nominator_couple',insurance_nominator_couple
print*,'insurance_denominator_couple',insurance_denominator_couple
print*,'insurance_value_couple',insurance_value_couple

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE SSORT_INT (X, Y, N, KFLAG)
! C***BEGIN PROLOGUE  SSORT_INT
! Same as SSORT, but Y is an array of integers
! C***PURPOSE  Sort an array and optionally make the same interchanges in
! C            an auxiliary array.  The array may be sorted in increasing
! C            or decreasing order.  A slightly modified QUICKSORT
! C            algorithm is used.
! C***LIBRARY   SLATEC
! C***CATEGORY  N6A2B
! C***TYPE      SINGLE PRECISION (SSORT-S, DSORT-D, ISORT-I)
! C***KEYWORDS  SINGLETON QUICKSORT, SORT, SORTING
! C***AUTHOR  Jones, R. E., (SNLA)
! C           Wisniewski, J. A., (SNLA)
! C***DESCRIPTION
! C
! C   SSORT sorts array X and optionally makes the same interchanges in
! C   array Y.  The array X may be sorted in increasing order or
! C   decreasing order.  A slightly modified quicksort algorithm is used.
! C
! C   Description of Parameters
! C      X - array of values to be sorted   (usually abscissas)
! C      Y - array to be (optionally) carried along
! C      N - number of values in array X to be sorted
! C      KFLAG - control parameter
! C            =  2  means sort X in increasing order and carry Y along.
! C            =  1  means sort X in increasing order (ignoring Y)
! C            = -1  means sort X in decreasing order (ignoring Y)
! C            = -2  means sort X in decreasing order and carry Y along.
! C
! C***REFERENCES  R. C. Singleton, Algorithm 347, An efficient algorithm
! C                 for sorting with minimal storage, Communications of
! C                 the ACM, 12, 3 (1969), pp. 185-187.
! C***REVISION HISTORY  (YYMMDD)
! C   761101  DATE WRITTEN
! C   761118  Modified to use the Singleton quicksort algorithm.  (JAW)
! C   890531  Changed all specific intrinsics to generic.  (WRB)
! C   890831  Modified array declarations.  (WRB)
! C   891009  Removed unreferenced statement labels.  (WRB)
! C   891024  Changed category.  (WRB)
! C   891024  REVISION DATE from Version 3.2
! C   891214  Prologue converted to Version 4.0 format.  (BAB)
! C   900315  CALLs to XERROR changed to CALLs to XERMSG.  (THJ)
! C   901012  Declared all variables; changed X,Y to SX,SY. (M. McClain)
! C   920501  Reformatted the REFERENCES section.  (DWL, WRB)
! C   920519  Clarified error messages.  (DWL)
! C   920801  Declarations section rebuilt and code restructured to use
! C           IF-THEN-ELSE-ENDIF.  (RWC, WRB)
! C***END PROLOGUE  SSORT
! C     .. Scalar Arguments ..
      INTEGER KFLAG, N
! C     .. Array Arguments ..
      REAL(prec) X(*)
	  INTEGER Y(*)
! C     .. Local Scalars ..
      REAL(prec) R, T, TT, TTY, TY
      INTEGER I, IJ, J, K, KK, L, M, NN
! C     .. Local Arrays ..
      INTEGER IL(21), IU(21)
! C     .. External Subroutines ..
! C     None
! C     .. Intrinsic Functions ..
      INTRINSIC ABS, INT
! C***FIRST EXECUTABLE STATEMENT  SSORT
      NN = N
      IF (NN .LT. 1) THEN
         PRINT *, 'The number of values to be sorted is not positive.'
         RETURN
      ENDIF
! C
      KK = ABS(KFLAG)
      IF (KK.NE.1 .AND. KK.NE.2) THEN
         PRINT *, 'The sort control parameter, K, is not 2, 1, -1, or -2.'
         RETURN
      ENDIF
! C
! C     Alter array X to get decreasing order if needed
! C
      IF (KFLAG .LE. -1) THEN
         DO 10 I=1,NN
            X(I) = -X(I)
   10    CONTINUE
      ENDIF
! C
      IF (KK .EQ. 2) GO TO 100
!C
! C     Sort X only
! C
      M = 1
      I = 1
      J = NN
      R = 0.375E0
! C
   20 IF (I .EQ. J) GO TO 60
      IF (R .LE. 0.5898437E0) THEN
         R = R+3.90625E-2
      ELSE
         R = R-0.21875E0
      ENDIF
! C
   30 K = I
! C
! C     Select a central element of the array and save it in location T
! C
      IJ = I + INT((J-I)*R)
      T = X(IJ)
! C
! C     If first element of array is greater than T, interchange with T
! C
      IF (X(I) .GT. T) THEN
         X(IJ) = X(I)
         X(I) = T
         T = X(IJ)
      ENDIF
      L = J
! C
! C     If last element of array is less than than T, interchange with T
! C
      IF (X(J) .LT. T) THEN
         X(IJ) = X(J)
         X(J) = T
         T = X(IJ)
! C
! C        If first element of array is greater than T, interchange with T
! C
         IF (X(I) .GT. T) THEN
            X(IJ) = X(I)
            X(I) = T
            T = X(IJ)
         ENDIF
      ENDIF
! C
! C     Find an element in the second half of the array which is smaller
! C     than T
! C
   40 L = L-1
      IF (X(L) .GT. T) GO TO 40
! C
! C     Find an element in the first half of the array which is greater
! C     than T
! C
   50 K = K+1
      IF (X(K) .LT. T) GO TO 50
! C
! C     Interchange these elements
! C
      IF (K .LE. L) THEN
         TT = X(L)
         X(L) = X(K)
         X(K) = TT
         GO TO 40
      ENDIF
! C
! C     Save upper and lower subscripts of the array yet to be sorted
! C
      IF (L-I .GT. J-K) THEN
         IL(M) = I
         IU(M) = L
         I = K
         M = M+1
      ELSE
         IL(M) = K
         IU(M) = J
         J = L
         M = M+1
      ENDIF
      GO TO 70
! C
! C     Begin again on another portion of the unsorted array
! C
   60 M = M-1
      IF (M .EQ. 0) GO TO 190
      I = IL(M)
      J = IU(M)
! C
   70 IF (J-I .GE. 1) GO TO 30
      IF (I .EQ. 1) GO TO 20
      I = I-1
! C
   80 I = I+1
      IF (I .EQ. J) GO TO 60
      T = X(I+1)
      IF (X(I) .LE. T) GO TO 80
      K = I
! C
   90 X(K+1) = X(K)
      K = K-1
      IF (T .LT. X(K)) GO TO 90
      X(K+1) = T
      GO TO 80
! C
! C     Sort X and carry Y along
! C
  100 M = 1
      I = 1
      J = NN
      R = 0.375E0
! C
  110 IF (I .EQ. J) GO TO 150
      IF (R .LE. 0.5898437E0) THEN
         R = R+3.90625E-2
      ELSE
         R = R-0.21875E0
      ENDIF
! C
  120 K = I
! C
! C     Select a central element of the array and save it in location T
! C
      IJ = I + INT((J-I)*R)
      T = X(IJ)
      TY = Y(IJ)
! C
! C     If first element of array is greater than T, interchange with T
! C
      IF (X(I) .GT. T) THEN
         X(IJ) = X(I)
         X(I) = T
         T = X(IJ)
         Y(IJ) = Y(I)
         Y(I) = TY
         TY = Y(IJ)
      ENDIF
      L = J
! C
! C     If last element of array is less than T, interchange with T
! C
      IF (X(J) .LT. T) THEN
         X(IJ) = X(J)
         X(J) = T
         T = X(IJ)
         Y(IJ) = Y(J)
         Y(J) = TY
         TY = Y(IJ)
! C
! C        If first element of array is greater than T, interchange with T
! C
         IF (X(I) .GT. T) THEN
            X(IJ) = X(I)
            X(I) = T
            T = X(IJ)
            Y(IJ) = Y(I)
            Y(I) = TY
            TY = Y(IJ)
         ENDIF
      ENDIF
! C
! C     Find an element in the second half of the array which is smaller
! C     than T
! C
  130 L = L-1
      IF (X(L) .GT. T) GO TO 130
! C
! C     Find an element in the first half of the array which is greater
! C     than T
! C
  140 K = K+1
      IF (X(K) .LT. T) GO TO 140
! C
! C     Interchange these elements
! C
      IF (K .LE. L) THEN
         TT = X(L)
         X(L) = X(K)
         X(K) = TT
         TTY = Y(L)
         Y(L) = Y(K)
         Y(K) = TTY
         GO TO 130
      ENDIF
! C
! C     Save upper and lower subscripts of the array yet to be sorted
! C
      IF (L-I .GT. J-K) THEN
         IL(M) = I
         IU(M) = L
         I = K
         M = M+1
      ELSE
         IL(M) = K
         IU(M) = J
         J = L
         M = M+1
      ENDIF
      GO TO 160
! C
! C     Begin again on another portion of the unsorted array
! C
  150 M = M-1
      IF (M .EQ. 0) GO TO 190
      I = IL(M)
      J = IU(M)
! C
  160 IF (J-I .GE. 1) GO TO 120
      IF (I .EQ. 1) GO TO 110
      I = I-1
! C
  170 I = I+1
      IF (I .EQ. J) GO TO 150
      T = X(I+1)
      TY = Y(I+1)
      IF (X(I) .LE. T) GO TO 170
      K = I
! C
  180 X(K+1) = X(K)
      Y(K+1) = Y(K)
      K = K-1
      IF (T .LT. X(K)) GO TO 180
      X(K+1) = T
      Y(K+1) = TY
      GO TO 170
! C
! C     Clean up
! C
  190 IF (KFLAG .LE. -1) THEN
         DO 200 I=1,NN
            X(I) = -X(I)
  200    CONTINUE
      ENDIF
      RETURN
      END

!************************************************************************************************************************************
FUNCTION search(X,Y,Z,W)

INTEGER:: i,search
REAL(prec):: W
INTEGER, DIMENSION(:):: Z
REAL(prec), INTENT(IN):: X
REAL(prec), DIMENSION(:), INTENT(IN) :: Y

! Both methods are correct 
!************Method 1*****************
DO i=1,size(Y)
    IF ( abs(Y(i)-X)<W ) THEN
		IF ( Z(i)==0 ) THEN	
		   search = i
		   Z(i)=1
		   GO TO 100
		ELSE
			DO j = i+1,size(Y)
				IF 	(Z(j)==0) THEN
					search = j
					Z(j) = 1
					GO TO 100
				END IF
			END DO
		END IF			           
    END IF
END DO
!**************Method 2*******************
! DO i=1,size(Y)
    ! IF ( abs(Y(i)-X)<1.D-4 ) THEN
		! IF ( Z(i)==0 ) THEN	
		   ! search = i
		   ! Z(i)=1
		   ! GO TO 100		
		! END IF			           
    ! END IF
! END DO

100 END FUNCTION  search

!***************************************************************************************************************************
!function utility (cons,lei, hea)
function utility (cons,lei,gender,G)
    !  Purpose
	!  Assuming that the utility function is of CRRA type,
	!  compute the utility base on consume and leisure 
    
       ! REAL(prec) cons, lei, hea
	    INTEGER gender
		REAL(prec) cons, lei, G
        REAL(prec) utility 
        !utility = ( LAMBDA*( ((CONS**RHO)*(LEI**(1-RHO)) )**PSI )+(1-LAMBDA)*(hea**PSI))**((1-sigma)/PSI)/(1-sigma) + UCONS
	    !utility = (LAMBDA*(CONS**PSI)+(1-LAMBDA)*(HEA**PSI))**((1-sigma)/PSI)/(1-sigma) + theta*(LEI**(1-THETA))/(1-THETA) ! alternative preference

		IF (gender==1) THEN		!male
			IF (lei==1.0) THEN 	!no labor participation
				! utility = (CONS**(1-sigma))/(1-sigma) - theta_single_male*((1.0-lei)**(1+sigma_lab_male))/(1+sigma_lab_male)	
				utility = log(CONS) - theta_single_male*((1.0-lei)**(1+sigma_lab_male))/(1+sigma_lab_male) !+ log(G)			
			ELSE
				! utility = (CONS**(1-sigma))/(1-sigma) - theta_single_male*((1.0-lei)**(1+sigma_lab_male))/(1+sigma_lab_male) - fixcost_male
				utility = log(CONS) - theta_single_male*((1.0-lei)**(1+sigma_lab_male))/(1+sigma_lab_male) - fixcost_male !+ log(G)
			END IF  
		ELSEIF 	(gender==2) THEN
			IF (lei==1.0) THEN 	!no labor participation
				! utility = (CONS**(1-sigma))/(1-sigma) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female)	
				utility = log(CONS) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female) !+ log(G)				
			ELSE
				! utility = (CONS**(1-sigma))/(1-sigma) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_singlefemale
				utility = log(CONS) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_singlefemale !+ log(G)
			END IF
		END IF  

end function utility 


function couple_utility (cons,lei1,lei2,G)
    !  Purpose
	!  Assuming that the utility function is of CRRA type,
	!  compute the utility base on consume and leisure 
    
       ! REAL(prec) cons, lei, hea
		REAL(prec) cons, lei1,lei2,G
        REAL(prec) couple_utility 
        !utility = ( LAMBDA*( ((CONS**RHO)*(LEI**(1-RHO)) )**PSI )+(1-LAMBDA)*(hea**PSI))**((1-sigma)/PSI)/(1-sigma) + UCONS
	    !utility = (LAMBDA*(CONS**PSI)+(1-LAMBDA)*(HEA**PSI))**((1-sigma)/PSI)/(1-sigma) + theta*(LEI**(1-THETA))/(1-THETA) ! alternative preference
		
		IF( (lei1==1.0) .AND. (lei2==1.0) )THEN 
			! couple_utility = ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female)
			couple_utility = log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) !+ log(G)
			
		ELSEIF  ( (lei1<1.0) .AND. (lei2==1.0) )THEN
			! couple_utility = ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male
			couple_utility = log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male !+ log(G)
			
		ELSEIF  ( (lei1==1.0) .AND. (lei2<1.0) )THEN
			! couple_utility = ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_marriedfemale
			couple_utility = log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_marriedfemale !+ log(G)
			
		ELSEIF  ( (lei1<1.0) .AND. (lei2<1.0) )THEN
			! couple_utility = ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male - fixcost_marriedfemale
			couple_utility = log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male - fixcost_marriedfemale !+ log(G)
		END IF  

end function couple_utility 
!***************************************************************************************************************************


! function beq_util(A,bcoeff,bsigma)
! 		REAL(prec), intent(in):: A
! 		REAL ,intent(in):: bcoeff,bsigma
!         REAL(prec) beq_util
! 		beq_util = bcoeff*(A**(1-bsigma))/(1-bsigma)
! end function beq_util

REAL FUNCTION gini(x,f) 
	! returns the Gini coefficient for a distribution
	! required inputs: x are values, f is mass at each point. 
	REAL(prec), DIMENSION(:), INTENT(IN) :: x, f
	REAL(prec) :: g ! Gini coefficient
!	INTEGER, parameter :: N = 10000 ! number people to simulate
!	REAL(prec), DIMENSION(N) :: y
	INTEGER :: i, j, L
	
!	L = size(x)
	L = size(f)

	g = 0
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i, j) REDUCTION(+:g)
!$OMP DO
	do i = 1, L, 1
		do j = i+1, L, 1
			g = g + f(i)*f(j)* abs(x(i)-x(j))
		end do
    end do
!$OMP END DO
!$OMP END PARALLEL   
g = g*2
!    dotproduct = 0.0
!     do i = 1, L, 1		
!    dotproduct = dotproduct + x(i)*f(i)
!    end do
    
!    print*,'dot_product=', dotproduct
    g = g/(2*dot_product(x,f))
	gini = g
!	g = g/(2*dotproduct)
!	gini = g
    PRINT*,'sum of normalized f(:) at age',AGE+1,'=',sum(f(:))
    print*,'dot_product(x,f)=', dot_product(x,f)
END FUNCTION gini

!*************************************************************************************************************************
! function PIAfct(hours,N,wageindex,w,zi) 

! ! intended inputs: hours, wage index. hours can be a scalar or a vector of length N 
! ! notes: wageindex: windex=agglabor*w parameters are sscap, rr1, bend1, rr2, bend2, rr3 You can see in the presentatio how they work.

! integer, intent(in) :: N 

! real(dp), intent(in), dimension(N) :: hours 

! real(dp), intent(in) :: wageindex, w, zi 

! real(dp), dimension(N) :: PIAfct 

! !PIAfct = wageindex*MIN(sscap, rr1*MIN(w*zi*hours/wageindex, bend1) + rr2* MAX(0.0, MIN(w*zi*hours/wageindex-bend1,bend2-bend1)) + rr3*MAX(0.0, w*zi*hours/wageindex-bend2))
! PIAfct = wageindex*MIN(sscap, rr1*MIN(EH(IE)/wageindex, bend1) + rr2* MAX(0.0, MIN(EH(IE)/wageindex-bend1,bend2-bend1)) + rr3*MAX(0.0, EH(IE)/wageindex-bend2))

! end function PIAfct
!*************************************************************************************************************************
function SS(IE) 

integer, intent(in) :: IE
real(prec) :: SS 

! for ssmin = 0
	! SS = PIA_factor*avg_earnings*MIN(incsscap, ssmin+rr1*MAX(0.0, MIN(EH(IE)/avg_earnings, bend1)) + rr2* MAX(0.0, MIN(EH(IE)/avg_earnings-bend1,bend2-bend1)) + rr3*MAX(0.0, EH(IE)/avg_earnings-bend2))

! If there is ssmin, then y<bend1 receive ssmin
!	SS = avg_earnings*MIN(incsscap, ssmin+rr1*MAX(0.0, MIN(EH(IE)/avg_earnings-bend1, bend2-bend1)) + rr2* MAX(0.0, EH(IE)/avg_earnings-bend2) )

SS = REPLACE*EH(IE)

end function SS 
!*************************************************************************************************************************
function taxpayment(pretaxincome,taxrate,marital)

INTEGER :: marital		! 1 = single, 2 = married couples
!integer, intent(in) :: IA
REAL(prec), INTENT(IN) :: pretaxincome
REAL(prec) :: bendy,taxpayment
REAL :: taxrate

! pretaxincome = pretaxincome/Aggincome

IF (marital == 1) THEN 
	IF (taxrate>0.0) THEN 
		! bendy=((1.0-taxrate)*lambda/(1.0-ty_max))**(1.0/taxrate) 

		bendy=10310001/788031 
		! bendy = 4530001/788031
	ELSE 
		bendy=1.E7 
	END IF 

	! yd	= lambda*(MIN(bendy, pretaxincome/Aggincome))**(1.0-taxrate) &
	! 	+(1.0-ty_max)*MAX(0.0,  pretaxincome/Aggincome - bendy)

	yd	= pretaxincome*lambda*(MIN(bendy, pretaxincome/avg_earnings))**(-taxrate) &
		  +avg_earnings*(1.0-ty_max)*MAX(0.0,  pretaxincome/avg_earnings - bendy)
	 	
	! yd	= lambda*(MIN(bendy,min(R*A(IA),d_c) + pretaxincome))**(1.0-taxrate) &
	! 		+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + pretaxincome - bendy) &
	! 		+(1-tau_c)*max(R*A(IA)-d_c,0.0)
	

	! yd	= lambda*(MIN(bendy/Aggtincome,(min(R*A(IA),d_c) + pretaxincome)/Aggtincome))**(1.0-taxrate) &
	! 	+(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) + pretaxincome)/Aggtincome - bendy/Aggtincome)  

		! yd	= lambda*(MIN(bendy, pretaxincome))**(1.0-taxrate) &
		! +(1.0-ty_max)*MAX(0.0,  pretaxincome - bendy) 
	
ELSEIF (marital == 2) THEN
	IF (taxrate>0.0) THEN 
		! bendy=((1.0-taxrate)*(lambda_couple)/(1.0-ty_max))**(1.0/taxrate) 
		
		bendy=10310001/788031 
		! bendy=4530001/788031
	ELSE 
		bendy=1.E7 
	END IF 

	! yd	= (lambda+delta_lambda)*(MIN(bendy, pretaxincome/Aggincome))**(1.0-taxrate) &
	! 		+(1.0-ty_max)*MAX(0.0, pretaxincome/Aggincome - bendy)
	
	yd	= pretaxincome*lambda_couple*(MIN(bendy, pretaxincome/avg_earnings))**(-taxrate) &
		  +avg_earnings*(1.0-ty_max)*MAX(0.0, pretaxincome/avg_earnings - bendy)

	! yd	= (lambda+delta_lambda)*(MIN(bendy,min(R*A(IA),d_c) + pretaxincome))**(1.0-taxrate) &
	! 		+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + pretaxincome - bendy)

	! yd	= lambda*(MIN(bendy,min(R*A(IA),d_c) + pretaxincome))**(1.0-taxrate) &
	! 		+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + pretaxincome - bendy) &
	! 		+(1-tau_c)*max(R*A(IA)-d_c,0.0)


	! yd	= lambda*(MIN(bendy/Aggtincome,(min(R*A(IA),d_c) + pretaxincome)/Aggtincome))**(1.0-taxrate) &
	! 	+(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) + pretaxincome)/Aggtincome - bendy/Aggtincome)  

		! yd	= lambda*(MIN(bendy, pretaxincome))**(1.0-taxrate) &
		! +(1.0-ty_max)*MAX(0.0,  pretaxincome - bendy) 

END IF 

	taxpayment =  pretaxincome - yd		
	! taxpayment =  pretaxincome/Aggincome - yd		!multiple of avg earning

end function taxpayment
!*************************************************************************************************************************
function yd_MFJ(pretaxincome,IA)

integer, intent(in) :: IA
REAL(prec), INTENT(IN) :: pretaxincome
REAL(prec) :: bendy,yd_MFJ

IF (ty_max_restriction == 1) THEN
	IF (tau_l_couple>0.0) THEN 
		! bendy=((1.0-tau_l_couple)*(lambda_couple)/(1.0-ty_max))**(1.0/tau_l_couple) 

		bendy=10310001/788031 
		! bendy=4530001/788031
	ELSE 
		bendy=1.E7 
	END IF 
ELSEIF (ty_max_restriction == 0) THEN
	bendy=1.E7 
END IF

yd_MFJ	= avg_earnings*MIN(bendy, pretaxincome/avg_earnings)*lambda_couple*(MIN(bendy, pretaxincome/avg_earnings))**(-tau_l_couple) &
			+avg_earnings*(1.0-ty_max)*MAX(0.0,  pretaxincome/avg_earnings - bendy) &
			+(1-tau_c)*max(R*A(IA)-d_c,0.0)

IF (MFS_method==2) THEN 
	yd_MFJ	= 0.0
END IF 

end function yd_MFJ
!*************************************************************************************************************************
function yd_MFS(pretaxincome,IA)

integer, intent(in) :: IA
REAL(prec), INTENT(IN) :: pretaxincome
REAL(prec) :: bendy, yd_MFS, tau_l_couple_MFS, lambda_couple_MFS

! tau_l_couple_MFS = (1.0-weight_MFS)*tau_l_couple + weight_MFS*tau_l_single
! lambda_couple_MFS = (1.0-weight_MFS)*(lambda+delta_lambda) + weight_MFS*lambda

! tau_l_couple_MFS = tau_l_single 
! lambda_couple_MFS = lambda*weight_MFS		!lambda + weight_MFS
tau_l_couple_MFS = tau_l_couple
lambda_couple_MFS = lambda_couple

! tau_l_couple_MFS = tau_l_couple + weight_MFS
! lambda_couple_MFS = lambda+delta_lambda

IF (ty_max_restriction == 1) THEN
	IF (tau_l_couple_MFS>0.0) THEN 
		! bendy=((1.0-tau_l_couple_MFS)*lambda_couple_MFS/(1.0-ty_max))**(1.0/tau_l_couple_MFS) 

		bendy=10310001/788031 
		! bendy=4530001/788031
	ELSE 
		bendy=1.E7 
	END IF
ELSEIF (ty_max_restriction == 0) THEN
	bendy=1.E7 
END IF

yd_MFS	= avg_earnings*MIN(bendy, pretaxincome/avg_earnings)*lambda_couple_MFS*(MIN(bendy, pretaxincome/avg_earnings))**(-tau_l_couple_MFS) &
			+avg_earnings*(1.0-ty_max)*MAX(0.0, pretaxincome/avg_earnings - bendy) &
			+(1-tau_c)*max((R*A(IA)-d_c)/2,0.0)

IF (MFS_method==0) THEN 
	yd_MFS	= 0.0
END IF 

end function yd_MFS
!*************************************************************************************************************************
function indicator(x,y)

integer, intent(in) :: x,Y
REAL(prec) :: indicator

IF (x == y) THEN 
	indicator = 1.0
ELSE 
	indicator = 0.0
END IF 

end function indicator
!*************************************************************************************************************************

END PROGRAM
