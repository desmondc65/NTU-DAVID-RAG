PROGRAM Health_GE_5period_endosur_MD_benchmark

! 17Apr2023
! Updated the wage-efficiency profile for both sex by using the data from Employment Status Survey 2017
! All couples are MFS with tau_couple and lambda_couple

! 24Nov2023
! eliminate Unemployment benefit 
! introduced health transition matrix

!Dec 2, 2023
! Ref: Medical Expenditures over the Life-Cycle: Persistent Risks and Insurance
! there is no premium payment for HI; premium_rate = 0.0
! the copayment rate SUBEHI is age-dependent (Medical Expenditures over the Life-Cycle: Persistent Risks and Insurance)
! SUBEHI(RETAGE) = 0.7
! SUBEHI(RETAGE+1) = 0.8
! SUBEHI(RETAGE+2:MAXAGE) = 0.9

!Jan 5, 2024
! need to finish the insurance path for the retirees.
! the loop is finished, but the insurance coeff not yet finished.

! Apr2, 2024
! changed the labour productivity matrix 
! corrected the calculation of ATY_S, ATY_M
! added the GBC method 4 by premium rate

!May7, 2024
! why there is no beq redist?

!Aug 2024
! changed copay to 80% so that the transmission coeff of med to consumption is close to the DeNardi's estimates

!Sept 2024
! insurance premium only apply to working-age
!**********************************************************************************************************
!  gfortran Jap_social_healthshock_lumpsumtax_bm5.f90 -ffree-line-length-none -fopenmp -O3 -o Jap_social_healthshock_lumpsumtax_bm5
!  ifort Jap_social_simple.f90 -fopenmp -O3 -o Jap_social_simple

! Gov clear GBC
! ./Jap_social_healthshock_lumpsumtax_bm3  0.9660      0.81000      0.3000     52.0000     50.0000     53.0000     54.0000      0.0000(with new wage-efficiency)

! Re-normalized the female age efficiency
! ./Jap_social_healthshock_lumpsumtax_bm3  0.9660      0.8100      0.2300     50.0000     50.0000     53.0000     48.0000      0.000
! Modified the labour productivity matrix for different educational attainment and added insurance premium
! ./Jap_social_healthshock_lumpsumtax_bm5  0.9670      0.6000      0.1800     48.0000     49.0000     48.0000     46.0000      0.1000
!**********************************************************************************************************

! #ifdef _OPENMP 
!   include 'omp_lib.h'  !needed for OMP_GET_NUM_THREADS()
! #endif
USE omp_lib

INTEGER, PARAMETER :: prec=SELECTED_REAL_KIND(15, 307)
INTEGER, PARAMETER :: couple_labor = 2 ! 2= Male and Female endog labor ; 1= male endog labr; 0=exog labor
INTEGER, PARAMETER :: r_update = 2 ! 1=bisection ; 2=delta_r (bm use delta_r)

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
! INTEGER, PARAMETER :: GBC_method_activation = 2 ! 	0=the GB is cleared by lambda ; 1=the GB is cleared by Gov; 2=the GB is cleared by tau_s
! INTEGER, PARAMETER :: MFS_method = 1 !	shut down MFS=0 ; allow MFS =1; shut down MFJ=2
! INTEGER, PARAMETER :: source_welfare_analysis_activation = 0 ! activate:1 ; shut down:0 (if activate, then set optimal_tax_activation = 0)
! INTEGER, PARAMETER :: result_display = 0 ! display results of optimal tax case: 1 ; No display: 0
! INTEGER, PARAMETER :: gov_method = 0 	 ! ratio of GDP =0 ; level value = 1
!-----------------------------Benchmark----------------------------------
INTEGER, PARAMETER :: ty_max_restriction = 0 ! without ty_max=0 ; with ty_max=1 (Guner et al 2014: Sample restriction eliminates those with reported taxes higher than the top statutory marginal tax rate, 39.5%.)
INTEGER, PARAMETER :: optimal_tax_activation = 0 ! 	benchmark=0 ; optimal=1
INTEGER, PARAMETER :: GBC_method_activation = 4  ! 	0=the GB is cleared by lambda ; 1=the GB is cleared by Gov; 2=the GB is cleared by tau_s; 3=the GB is cleared by lump sum tax;  4=the GB is cleared by premium_rate
INTEGER, PARAMETER :: MFS_method = 2 !	shut down MFS=0 ; allow MFS =1; shut down MFJ=2
INTEGER, PARAMETER :: source_welfare_analysis_activation = 0 ! activate:1 ; shut down:0 (if activate, then set optimal_tax_activation = 0)
INTEGER, PARAMETER :: result_display = 1 ! display results of optimal tax case: 1 ; No display: 0
INTEGER, PARAMETER :: gov_method = 0 	 ! ratio of GDP =0 ; level value = 1
INTEGER, PARAMETER :: beq_activation = 1  ! 0=shut down; 1=active 
INTEGER, PARAMETER :: CV = 0			 ! 0 = save benchmark value function for compensated variation	; 1=dont save the benchmark value function but use CV subroutine
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

PARAMETER (BEQ0 =  0.0)	!  1.398701097315307E-002  ) 	    !  Accidental bequests
PARAMETER (SS0 =   0.266587382884863    )        !  Social Security benifits 
PARAMETER (STAX0 =  0.156058077828311  )      !  Social Security tax rate
PARAMETER (MTAX0 =  9.477625607851901E-002  )       !  Med tax rate
PARAMETER (PREMIUM0 =  0.0  )     !  EHI premium

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
PARAMETER (tol_lumpsum = 0.01)					  !  Convergence tolerance for tau_s
PARAMETER (tol_premium = 0.01)
PARAMETER (tol_PIA = 0.01) 						  !  Convergence tolerance for PIA factor
PARAMETER (TOLMTAX = 0.005)                  	  !  Convergence tolerance for Med tax rate
PARAMETER (TOLEHI = 0.005)                        !  Convergence tolerance for EHI premium
PARAMETER (TOLK = 0.01)        !0.018       	  !  Convergence tolerance for asset market clear
PARAMETER (GRADB = 0.35)       !0.2               !  Convergence gradient for bequests
PARAMETER (GRADSS = 0.618)                   	  !  Convergence gradient for SS bnefits
PARAMETER (GRADSTAX = 0.618)                 	  !  Convergence gradient for SS tax rate
PARAMETER (GRADMTAX = 0.618)                 	  !  Convergence gradient for Med tax rate
PARAMETER (GRADEHI = 0.2)                  		  !  Convergence gradient for EHI
!PARAMETER (GRADBETA = 0.2)                    
PARAMETER (MAXITER = 50)       !100               !  Maximum number of iterations for convergence
PARAMETER (GRADLAMBDA = 0.5)
PARAMETER (GRADPIA = 0.5)
PARAMETER (GRADTAUS = 0.5)
PARAMETER (GRADTAULUMPSUM = 0.5)
PARAMETER (GRADPREMIUM = 0.5)
 
PARAMETER (ALPHA = 0.29)	 ! 0.3                 ! Source: "Females, the elderly, and also males: Demographic aging and macroeconomy in Japan"
PARAMETER (TFP   = 1.45)	 ! 1.45   		 !  Multiplicative constant in production function, such that wage = 1
PARAMETER (GROWTH_ANNUAL = 0.000)            !  Annual growth rate of per capita output
PARAMETER (GROWTH = (1.000+GROWTH_ANNUAL)**5.00-1.000)     !  Growth rate of per capita output
! calibrate depreciation to match interest rate
PARAMETER (DEP_ANNUAL = 0.07) !0.07)      		!0.07 Source: "Females, the elderly, and also males: Demographic aging and macroeconomy in Japan"
PARAMETER (DEP  = 1.000-(1.000-DEP_ANNUAL)**5.00) !  Depreciation rate of capital
PARAMETER (flat_transf_rate = 0.0)					 ! 0.027 is destined to the general public in the form of disability benefits, veterans benefits etc (Markus & Baris 2016) 
REAL(prec), PARAMETER :: medicare_rate = 0.0		!0.033

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
REAL, PARAMETER :: UCONS1  = 250.0!80.0      !250                !  Constant term in utility function (Hall and Jones 2007)
REAL, PARAMETER :: UCONS2  = 120.0!80.0      !120                !  Constant term in utility function (Hall and Jones 2007)
REAL, PARAMETER :: sigma_lab_male  = 1.8 ! 1.0/0.14		! male Frisch elasticity = 0.14 (Estimating Frisch labor supply elasticity in Japan 2008)
REAL, PARAMETER :: sigma_lab_female  = 1.8 ! 1.0/0.13		! female Frisch elasticity = 0.13 (Estimating Frisch labor supply elasticity in Japan 2008)
! REAL, PARAMETER :: sigma_lab_female  = 1.0/0.68

! REAL, PARAMETER :: theta  = 2.3	!5.5
!REAL, PARAMETER :: eta	= 1.6 	! Nishyama (Bernheim et al. (2008))
REAL, PARAMETER :: eta	= 1.7	! The OECD equivalence scales assign a weight of 1 to the household head, 0.7 to each additional adult household member, and 0.5 to each child.
REAL, PARAMETER :: fixcost_male	= 0.0	
! REAL, PARAMETER :: fixcost_female = 0.126		!0.134 !0.112

! REAL, PARAMETER :: RHO    = 0.342                  !  Share of consumption in consumption-leisure composition (Conesa, Kitao and Krueger 2009 = 0.377 
! REAL, PARAMETER :: PSI    = -9.70000                   !  Elasticity of substitution b/w consumption-leisure and health, Yogo (2009  = -0.43            
!REAL, PARAMETER :: LAMBDA   = 0.970000                  !  Yogo (2009) = 0.7!  Share of consumption-leisure composition in the utility function

REAL, PARAMETER :: B  =  0.5  !0.5                   !B  = 0.98000  Productivity of health accumulation technology
REAL, PARAMETER :: XI  = 0.8  !0.700                         !XI  = 0.800    Return to Scale in health investment

REAL, PARAMETER :: Q  = 0.0!0.0050                      !  Scale factor of sick time
REAL, PARAMETER :: GAMMA1  = 1.40                   !  Elasticity of sick time to health status

REAL, PARAMETER :: a0  = -2.800		!-1.9	                       !  Intercept of depreciation rate of health status, benchmark value: -4.00
REAL, PARAMETER :: a1  = 0.225		!0.2152	                    !  Coefficent for age, benchmark value: 0.215
REAL, PARAMETER :: a2  = 0.0   !0.00825!0.00400                    !  Coefficent for age^2, benchmark 0.00825

! REAL, PARAMETER :: c0  = -5.490484!-5.81                       !  Intercept of sur. prob. function, benchmark value: -5.490484
! REAL, PARAMETER :: c1  = 0.1499950!0.285                       !  Coefficent for age of sur. prob funtion, benchmark value: 0.1499950
! REAL, PARAMETER :: c2  = 0.0161671!0.0082                      !  Coefficent for age^2, benchmark 0.0161671
! REAL, PARAMETER :: c3  = -0.17                      !  Coefficent for h in sur. prob. function


!!-------------------------------------------------------------------------------------------------------------------------------!!
!!-------------------------------------------------------------------------------------------------------------------------------!!

real(prec), parameter	:: rr = 0.205         !0.185  Social security replacement rate

PARAMETER (SUBM = 0.80)                      !  co-insurance rate of Medicare
! PARAMETER (SUBEHI = 0.80)                    !  co-insurance rate of EHI
! PARAMETER (premium_rate = 0.1415)				 !  premium rates for the pension is 18.3%, and the rates for health is 10.0%, respectively, shared equally by the employer and the employee. (Source: Why Women Work the Way They Do in Japan: Roles of Fiscal Policies)

! Set the bounds for lambda
! real(prec), parameter	:: lambdamin = 0.8 !0.9D0 ! Use 0.9 and 1.1 unless tau_l is changing.
real(prec), parameter	:: lambdamin = 0.6
real(prec), parameter	:: lambdamax = 1.3 !1.2D0 ! 1.2
real(prec), parameter	:: delta_lambda = 0.970987/0.916685

! Set the bounds for tau_s
real(prec), parameter	:: tau_s_min = 0.0
real(prec), parameter	:: tau_s_max = 0.3

! Set the bounds for TFP
real(prec), parameter	:: Rmin = 0.015	!0.035 (ifort) ; 0.03 (gfort)
real(prec), parameter	:: Rmax = 0.035	!0.045 (ifort) ; 0.05 (gfort)

real(prec), parameter	:: ty_max = 0.396	!(2000: 39.6% ; 2010: 35%)
real(prec), parameter   :: tau_c = 0.236 	! Corporate tax: Markus & Kaymak 2016 (piketty paper)
! real(prec), parameter   :: tau_s = 0.05  ! Average sales tax: total sales tax rev/total consumption expenditures 

! REAL(prec), parameter  :: earn_corr	= 0.0	! husband-wife wage correlation 

! Marriage fraction for 1960
! real(prec), parameter 	:: marryprop = 0.87 ! Jeremy Greenwood et al. 2016 (Table 4)
! Marriage fraction for 2005
! real(prec), parameter 	:: marryprop = 0.661	! Jeremy Greenwood et al. 2016 (Table 6)
! Marriage fraction for 2001
 real(prec), parameter 	:: marryprop = 0.74	! population of married = 0.74/(0.26+0.26+0.74)= 0.589: National Population Census, 2010

! PARAMETER (nn = 8)
PARAMETER (nn = 6)

REAL(prec), parameter :: weight_MFS = 1.000
REAL(prec), parameter :: d_c = 100000.000
REAL(prec), parameter :: prob_sep = 0.0425!0.0283	! 0.0048 is a monthly exogenous separation rate
REAL(prec), parameter :: prob_job = 0.999	    ! 10.97% chance of finding a job during a give month

PARAMETER (MAXAGE = 15)                      !  Maximum age allowed (5year=15; 6months=151, 1year=76)
INTEGER, PARAMETER :: RETAGE = 9           !  Retirement age  (5year=9; 6months=81, 1year=41)

PARAMETER (POPG = 0.000)

! PARAMETER (AMAX   = 2.700)      !  Maximum permissible asset
! PARAMETER (AMIN   = 0.000)      !  Maximum permissible asset
! REAL(prec) MMAX
! PARAMETER (MMAX   = 1.2000)      !  Maximum permissible med exepnditure

PARAMETER (AMAX   = 400.000)   !400 !  Maximum permissible asset
PARAMETER (AMIN   = 0.001)      !  Minimum permissible asset
REAL(prec) MMAX
PARAMETER (MMAX   = 1.00)   !1.0   !  Maximum permissible med exepnditure
PARAMETER (HMAX   = 0.56732)      !0.5716  Maximum permissible health stocks	 0.9445

!PARAMETER (NGRIDR  = 2)! 4**4*2+1) 
PARAMETER (NGRIDA  = 65)! 4**4*2+1)     !129  Number of points on asset grid (state)
PARAMETER (NGRIDH  = 5)! **4*2+1)       !  Number of points on health grid(state)
!PARAMETER (NGRIDA  =  4**4*2+1)     !  Number of points on asset grid (state)
!PARAMETER (NGRIDH  =  4**4*2+1)       !  Number of points on health grid(state)
PARAMETER (NGRIDEH  = 10)		!10		!  Number of points on earning history (state)
	

! PARAMETER (CMIN   = 0.000000005)   !  Minimum permissible consumption
PARAMETER (CMIN   = 0.00001)   !  Minimum permissible consumption
REAL(prec) LEIMIN
PARAMETER (LEIMIN   = 0.000000005)   !  Minimum permissible leisure
! PARAMETER (HMIN   = 0.0000000005)      !  Minimum permissible health level
PARAMETER (HMIN   = 0.01)  !0.01    !  Minimum permissible health level

!********************
!
!   Data Type Declarations and Dimension Statements
!
!********************

INTEGER AGE, ILA, IUA, ISKIPA, ILN, IUN, ISKIPN ,ILN2, IUN2, ISKIPN2, ILM,IUM,ISKIPM
INTEGER JAMAX, JNMAX, JNMAX2, IA, IE, IS, IS1, IS2, IN, IC, IG, NEWIS, NEWIS1, NEWIS2, NEWH,itax,isubsidy,NEWIE ,IH,IM, JHMAX, JMMAX 
INTEGER JA,JN,JM,JH,JN1,JN2,JE
INTEGER CHUNK, NTHR, ID, INDEXV, MAXINDEX, NRET, ZEROINDEX
INTEGER JTS,JTM
INTEGER state_pos,isort,count, individ,individ_age,individ_youngage,individ_midage,LOOPNUMBER
INTEGER source_welfare,optimal_tax,GBC_method
INTEGER index_A,index_A_single,index_A_couple
INTEGER index_E,index_E_single,index_E_couple
INTEGER index_tinc,index_tinc_single,index_tinc_couple

REAL(prec)  AEND, BEQEND, STAXEND, LEND, LSSEND, MEND, MEDW, MEDR, MEDEND, MYOUNG, MOLD, EXDEM, INV, K, K1, L, L1, INCOME,h_shock,z_shock,z_shock1,z_shock2, INCOME1, INCOME2,TINCOME, TINCOME1, TINCOME2, taxable_income,taxable_income1,taxable_income2, IEND, KDEV, LDEV, TWEND
REAL(prec)  BEQ, STAX, MTAX, PREMIUM, PREMIUM1, PREMIUM2, BEQ1, SS1, STAX1, MTAX1, med_insur_exp, UB1, BEQDEV, SSDEV, STAXDEV, MTAXDEV, EHIDEV
REAL(prec)  PRICE, WAGEZ, WAGEZ1, WAGEZ2, UTIL, LEI1, LEI2, CONS, HEA, SKIPH, TW, VTEMPL, VMAX, HNEXT, HNEXTPOS, OUTPUT, X3,XH,DH
REAL(prec)  RATIO125
REAL(prec)  t0, t1
REAL(prec)	wea_gini, inc_gini, tinc_gini, cons_gini, yd_gini
REAL(prec)	Aggwealth, Aggincome, Aggtincome, Aggconsumption, agg_c, Avg_ALONG,Avg_MLONG,Avg_ILONG,Avg_TILONG, agg_y,Avg_CLONG
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
REAL(prec)	tau_s_implied, tau_s1, tau_s2, dtau_s, tau_s, dlumpsum, lumpsum_taxrev_implied, lumpsum_taxrev, lumpsum, premium_rate, premium_rate_implied, dpremium_rate
REAL(prec)	cor_tax_rev,sales_tax_rev,insurance_premium,income_tax_rev, ATC1, ATC99, ctaxrev_income, ATY1,ATY99,inctaxrev_income,ATY,ATY_single,ATY_couple,ATY_tax_single,ATY_taxableincome_single,ATY_tax_couple,ATY_taxableincome_couple, G_share, MTR1, MTR10, tax_subsidy, tax_revenue_single, tax_revenue_couple
REAL(prec)	temp,temp2,temp_ctaxrev,temp_cons,temp_staxrev
REAL(prec)	incvar, mean_incvar, consvar, mean_consvar, var_cons_earning_ratio, var_cons_earning_ratio_single, var_cons_earning_ratio_couple
REAL(prec)  KD,delta, BETA
REAL(prec)	WAGE
REAL(prec)  r_implied, r_new, R1, R2, delta_r
REAL(prec)  R,R_ANNUAL
REAL(prec)	avg_earnings,working_population,whole_population,unemployed_population,unemployment_rate
REAL(prec)	SSEXP
REAL(prec)  EH_temp
REAL(prec)	Agg_labor,Avg_hour,Agg_asset,Agg_beq,Avg_H,Avg_M,Avg_H_6569
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
REAL(prec)  incomethreshold1,incomethreshold5,incomethreshold10,incomethreshold20,incomethreshold40,incomethreshold60,incomethreshold80
REAL(prec)	earningthreshold80,earningthreshold60,earningthreshold40,earningthreshold20,earningthreshold10,earningthreshold5,earningthreshold1
REAL(prec)  util_welfare_hh, util_welfare_id,util_welfare_id_retiree,util_welfare_id_working, veil_welfare_hh, veil_welfare_id, agglabpath_singlemale,agglabpath_singlefemale,aggcerteq_singlemale,aggcerteq_singlefemale,par_welfare_singlemale,par_welfare_singlefemale,agglabpath_couplemale,agglabpath_couplefemale,aggcerteq_couplemale,aggcerteq_couplefemale,par_welfare_couple,par_welfare
REAL(prec)	CEV_optimal,opt_welfare,change_bench_util_C,change_bench_util_LS,no_pension_welfare_newborn,no_UB_welfare,no_EHI_welfare_newborn,no_prog_welfare_newborn,no_allpolicy_welfare_newborn,no_allpolicy_welfare,pop_birth,pop_working,no_pension_CEV_newborn,no_UB_CEV_newborn,no_EHI_CEV_newborn,no_prog_CEV_newborn,no_allpolicy_CEV_newborn,no_pension_welfare,no_EHI_welfare,no_prog_welfare,no_pension_CEV,no_EHI_CEV,no_prog_CEV,no_allpolicy_CEV
REAL(prec)  no_pension_welfare_working, no_UB_welfare_working, no_EHI_welfare_working,no_prog_welfare_working, no_pension_CEV_working,no_UB_CEV_working, no_EHI_CEV_working,no_prog_CEV_working,no_pension_welfare_retiree,no_UB_welfare_retiree,no_EHI_welfare_retiree,no_prog_welfare_retiree,pop_retiree,no_pension_CEV_retiree,no_UB_CEV_retiree,no_EHI_CEV_retiree,no_prog_CEV_retiree
REAL tau_l_single, tau_l_couple
REAL(prec)	PIA_factor,PIA_factor_implied,dPIA
REAL(prec)  earn_corr_conditional,P_joint
REAL(prec)  consumption,INCOME_next,INCOME1_next,INCOME2_next,h_shock_next,z_shock_next,z_shock1_next,z_shock2_next,consumption_next,avg_log_income,avg_log_cons,insurance_nominator,insurance_denominator,insurance_value,med_expense,med_expense_next
REAL(prec)  avg_log_income_shock,avg_log_income_shock_single,avg_log_income_shock_couple,insurance_cons_nominator,insurance_cons_denominator,insurance_cons_value,insurance_labor_nominator,insurance_labor_denominator,insurance_labor_value
REAL(prec)  youngage_avg_log_income_shock,youngage_avg_log_income_shock_single,youngage_avg_log_income_shock_couple,midage_avg_log_income_shock,midage_avg_log_income_shock_single,midage_avg_log_income_shock_couple,youngage_avg_log_cons,youngage_avg_log_cons_single,youngage_avg_log_cons_couple,midage_avg_log_cons,midage_avg_log_cons_single,midage_avg_log_cons_couple
REAL(prec)  insurance_cons_nominator_single,insurance_cons_denominator_single,insurance_cons_value_single,insurance_labor_nominator_single,insurance_labor_denominator_single,insurance_labor_value_single,insurance_cons_nominator_couple,insurance_cons_denominator_couple,insurance_cons_value_couple,insurance_labor_nominator_couple,insurance_labor_denominator_couple,insurance_labor_value_couple
REAL(prec)  youngage_insurance_cons_nominator,youngage_insurance_cons_denominator,youngage_insurance_cons_value,midage_insurance_cons_nominator,midage_insurance_cons_denominator,midage_insurance_cons_value,youngage_insurance_cons_nominator_single,youngage_insurance_cons_denominator_single,youngage_insurance_cons_value_single,midage_insurance_cons_nominator_single,midage_insurance_cons_denominator_single,midage_insurance_cons_value_single
REAL(prec)  youngage_insurance_cons_nominator_couple,youngage_insurance_cons_denominator_couple,youngage_insurance_cons_value_couple,midage_insurance_cons_nominator_couple,midage_insurance_cons_denominator_couple,midage_insurance_cons_value_couple
REAL(prec)  avg_log_income_single,avg_log_cons_single,insurance_nominator_single,insurance_denominator_single,insurance_value_single
REAL(prec)  avg_log_income_couple,avg_log_cons_couple,insurance_nominator_couple,insurance_denominator_couple,insurance_value_couple
REAL(prec)  avg_log_income_retire,avg_log_cons_retire,insurance_nominator_retire,insurance_denominator_retire,insurance_value_retire,insurance_nominator_med_retire,insurance_value_med_retire
REAL(prec)  avg_log_health_shock_retire,avg_log_health_shock_single_retire,avg_log_health_shock_couple_retire,avg_log_med_retire,avg_log_med_single_retire,avg_log_med_couple_retire
REAL(prec)  avg_log_income_single_retire,avg_log_cons_single_retire,insurance_nominator_single_retire,insurance_denominator_single_retire,insurance_value_single_retire,insurance_nominator_med_single_retire,insurance_value_med_single_retire
REAL(prec)  avg_log_income_couple_retire,avg_log_cons_couple_retire,insurance_nominator_couple_retire,insurance_denominator_couple_retire,insurance_value_couple_retire,insurance_nominator_med_couple_retire,insurance_value_med_couple_retire
REAL(prec)  agg_certeqcons_singlemale,agg_certeqlab_singlemale,agg_certeqcons_singlefemale,agg_certeqlab_singlefemale,V_certeq_singlemale,V_certeq_singlefemale
REAL(prec)  AggC_singlemale,AggC_singlefemale,AggL_singlemale,AggL_singlefemale,cost_unc_singlemale,cost_unc_singlefemale,AggC_couple
REAL(prec)  expV_certeq_singlemale,cost_ineq_singlemale,expV_certeq_singlefemale,cost_ineq_singlefemale
REAL(prec)  AggC_singlemale_leicomp,AggC_singlefemale_leicomp,AggL_singlemale_bm,AggL_singlefemale_bm,AggL_couple_male_bm,AggL_couple_female_bm
REAL(prec)	temp_singleYW,temp_coupleYW,temp_singleYR,temp_singleYW1,temp_singleYW2,temp_coupleYR,temp_singleYR_AGE,temp_coupleYR_AGE,temp_dist_single,temp_dist_couple
REAL(prec)  Avg_corr_family_earn
REAL(prec)  mean_earning_single,var_earning_single,mean_cons_single,var_cons_single,mean_earning_couple,var_earning_couple,mean_cons_couple,var_cons_couple

INTEGER singleIDCWA(:,:,:,:,:)     !  Asset decision rules for single working-age
INTEGER coupleIDCWA(:,:,:,:,:)     !  Asset decision rules for couple working-age

INTEGER singleIDCWN(:,:,:,:,:)     !  Decision rules of labor supply for single working-age
INTEGER coupleIDCWN(:,:,:,:,:,:)   !  Decision rules of labor supply for couple working-age

REAL(prec) singleIDCWC(:,:,:,:,:)     !  Consumption decision rules for single working-age
REAL(prec) coupleIDCWC(:,:,:,:,:)     !  Consumption decision rules for couple working-age

REAL(prec) singleIDCRC(:,:,:,:,:)       !  Consumption decision rules for single retirees
REAL(prec) coupleIDCRC(:,:,:,:)     	  !  Consumption decision rules for couple retirees

INTEGER singleIDCRA(:,:,:,:,:)     !  Asset decision rules for retirees
INTEGER coupleIDCRA(:,:,:,:)     !  Asset decision rules for retirees

INTEGER singleIDCRN(:,:,:,:,:)     !  Decision rules of labor supply for retirees
INTEGER coupleIDCRN(:,:,:,:)     !  Decision rules of labor supply for retirees

INTEGER singleIDCRM(:,:,:,:,:)	   !  Health Expenditure decision rules for single retirees
INTEGER coupleIDCRM(:,:,:,:)	   !  Health Expenditure decision rules for couple retirees

INTEGER singleIDCRH(:,:,:,:,:)	   !  Decision rules of health status for single retirees
INTEGER coupleIDCRH(:,:,:,:)	   !  Decision rules of health status for couple retirees

INTEGER Q1,Q2,Q3,Q4,Q5,Top10pct,Top05pct,Top01pct
INTEGER Q1_D(:),  Q2_D(:), Q3_D(:), Q4_D(:), Q5_D(:)
INTEGER top05pct_D(:), top1pct_D(:), top5pct_D(:), top10pct_D(:), top20pct_D(:), top40pct_D(:), top50pct_D(:),top60pct_D(:), top70pct_D(:), top80pct_D(:),top90pct_D(:),top95pct_D(:),top99pct_D(:)
INTEGER	bot99pct_D(:), bot90pct_D(:), bot50pct_D(:), bot30pct_D(:), bot99pct_D_inc(:), bot90pct_D_inc(:), bot50pct_D_inc(:), bot30pct_D_inc(:),bot99pct_D_tinc(:), bot90pct_D_tinc(:), bot50pct_D_tinc(:), bot30pct_D_tinc(:)
INTEGER top0001pct_D(:), top0005pct_D(:), top001pct_D(:), top005pct_D(:), top01pct_D(:)
INTEGER top05pct_D_inc(:), top1pct_D_inc(:), top5pct_D_inc(:), top10pct_D_inc(:), top20pct_D_inc(:),top39pct_D_inc(:), top40pct_D_inc(:), top50pct_D_inc(:), top60pct_D_inc(:), top70pct_D_inc(:), top80pct_D_inc(:)
INTEGER top0001pct_D_inc(:), top0005pct_D_inc(:), top001pct_D_inc(:),top005pct_D_inc(:),top0039pct_D_inc(:), top01pct_D_inc(:), top025pct_D_inc(:)
INTEGER top05pct_D_tinc(:), top1pct_D_tinc(:), top5pct_D_tinc(:), top10pct_D_tinc(:), top20pct_D_tinc(:), top40pct_D_tinc(:),top50pct_D_tinc(:), top60pct_D_tinc(:),top70pct_D_tinc(:), top80pct_D_tinc(:), top90pct_D_tinc(:), top95pct_D_tinc(:),top99pct_D_tinc(:),bot20pct_D_tinc(:)
INTEGER top0001pct_D_tinc(:), top0005pct_D_tinc(:), top001pct_D_tinc(:), top005pct_D_tinc(:), top01pct_D_tinc(:), top025pct_D_tinc(:)
INTEGER top05pct_D_R(:,:), top1pct_D_R(:,:), top5pct_D_R(:,:), top10pct_D_R(:,:), top20pct_D_R(:,:), top40pct_D_R(:,:),top50pct_D_R(:,:), top60pct_D_R(:,:),top70pct_D_R(:,:), top80pct_D_R(:,:)
INTEGER top0001pct_D_R(:,:), top0005pct_D_R(:,:), top001pct_D_R(:,:), top01pct_D_R(:,:)
INTEGER top1pct_D_B(:),top2pct_D_B(:),top5pct_D_B(:),top10pct_D_B(:),top20pct_D_B(:),top30pct_D_B(:),top40pct_D_B(:),top50pct_D_B(:),top60pct_D_B(:),top70pct_D_B(:),top80pct_D_B(:),top90pct_D_B(:)
INTEGER top1pct_D_B_age52(:),top2pct_D_B_age52(:),top5pct_D_B_age52(:),top10pct_D_B_age52(:),top20pct_D_B_age52(:),top30pct_D_B_age52(:),top40pct_D_B_age52(:),top50pct_D_B_age52(:),top60pct_D_B_age52(:),top70pct_D_B_age52(:),top80pct_D_B_age52(:),top90pct_D_B_age52(:)
INTEGER top05pct_D_C(:), top1pct_D_C(:), top5pct_D_C(:), top10pct_D_C(:), top20pct_D_C(:), top40pct_D_C(:), top50pct_D_C(:),top60pct_D_C(:), top70pct_D_C(:), top80pct_D_C(:),top90pct_D_C(:),top95pct_D_C(:),top99pct_D_C(:)
INTEGER top0001pct_D_C(:), top0005pct_D_C(:), top001pct_D_C(:), top01pct_D_C(:)
INTEGER box(:), box_inc(:), box_tinc(:), box_R(:), box_B(:),box_B_age52(:), box_C(:), box_inc_retire(:)
INTEGER record_position_tinc(:), record_position_tinc_single(:), record_position_tinc_couple(:), record_position_A(:), record_position_A_single(:), record_position_A_couple(:), record_position_E(:),record_position_E_retire(:) , record_position_E_single(:), record_position_E_couple(:), record_position_B(:),record_position_C(:)
INTEGER itax1(:),isubsidy1(:),itax2(:),isubsidy2(:),itax3(:),isubsidy3(:),itax4(:),isubsidy4(:),itax5(:),isubsidy5(:)
INTEGER bench_coupleIDCWN(:,:,:,:,:,:),bench_singleIDCWN(:,:,:,:,:)

REAL(prec) A(:)              !  Asset levels (control variable)
REAL(prec) AS(:)             !  Asset levels (state variable)
REAL(prec) H(:)              !  Health status (state variable)
REAL(prec) N(:)              !  Working hours ratio
REAL(prec) M(:)              !  Expenditure on health
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
REAL(prec) HLONG_AGE_single(:,:)
REAL(prec) HLONG_AGE_couple(:)
REAL(prec) MLONG_AGE_single(:,:)
REAL(prec) MLONG_AGE_couple(:)
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
REAL(prec) sort_inc_retire(:), sort_D_inc_retire(:),temp_sort_D_inc_retire(:)	
REAL(prec) HLONG(:)          !  Longitudinal health status profile
REAL(prec) HCROSS(:)          !  Cross-sectional health status profile
REAL(prec) MLONG(:)          !  Longitudinal health expenditure profile
REAL(prec) MCROSS(:)          !  Cross-sectional health expenditure profile
REAL(prec) NLONG(:)           !  Longitudinal efficiency labor supply profile
REAL(prec) NCROSS(:)          !  Cross-sectional efficiency labor supply profile
REAL(prec) LLONG_single(:,:)  !  Longitudinal labor supply profile
REAL(prec) LLONG_couple(:,:) 
REAL(prec) LCROSS(:)          !  Cross-sectional labor supply profile
!REAL(prec) SICKLONG(:)          !  Longitudinal sick time profile
REAL(prec) CUMS(:,:)           !  Unconditional survival probabilities, age 1 to age j
REAL(prec) MU(:)             !  Age distribution of population
REAL(prec) CUMSWK(:)         !  Unconditional survival probabilities, age 1 to age j, for working age
REAL(prec) MUWK(:)           !  Age distribution of working age population
! REAL(prec) S(:,:)            !  Conditional survival probabilities, age j-1 to age j
REAL(prec) DEP_H(:)          !  Depreciation rate of health capital
REAL(prec) P_m(2,2)                  !  Assortative mating matrix
REAL(prec) P(nn,nn,2)                  !  Transition matrix of idiosyncratic productivity shock
REAL(prec) intP(nn,nn,2)                !  Intergenerational Transition matrix 
REAL(prec) W(nn,2)                  !   idiosyncratic productivity shock
REAL(prec) initial_dist_z(nn,2)
REAL(prec) P_h(NGRIDH,NGRIDH,4)		! the health transition matrix is age-dependent and it has 4 age groups
REAL(prec) SSprob_z1(nn,nn)
REAL(prec) SSprob_z2(nn,nn)
REAL(prec) probmul_P(nn,nn)
real(prec) basicz(nn)
real(prec) z(nn)
REAL(prec) couple_taxpenalty(nn,nn)         

REAL(prec) singleVW(:,:,:,:,:)          !  Value function for single working-age
REAL(prec) coupleVW(:,:,:,:,:)          !  Value function for couple working-age
REAL(prec) marriageVW(:,:,:,:,:,:)
REAL(prec) singleVR(:,:,:,:,:)            !  Value function for retired single
REAL(prec) coupleVR(:,:,:,:)              !  Value function for retired couple
REAL(prec) marriageVR(:,:,:,:) 

REAL(prec) singleYW(:,:,:,:,:)          !  Age-dependent distribution of single agents across states for working-age
REAL(prec) coupleYW(:,:,:,:,:)          !  Age-dependent distribution of couple agents across states for working-age
REAL(prec) Y_AGE(:)

REAL(prec) singleYR(:,:,:,:,:)          !  Age-dependent distribution of agents across states for retirees
REAL(prec) coupleYR(:,:,:,:)          !  Age-dependent distribution of agents across states for retirees

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
REAL(prec) temp_retire_single_util_C(:,:,:,:,:),retire_single_util_C(:,:,:,:,:),temp_retire_couple_util_C(:,:,:,:,:), retire_couple_util_C(:,:,:,:,:)
REAL(prec) temp_single_util_LS(:,:,:,:,:),single_util_LS(:,:,:,:,:),temp_single_util_C(:,:,:,:,:),single_util_C(:,:,:,:,:),temp_couple_util_LS(:,:,:,:,:,:),couple_util_LS(:,:,:,:,:),temp_couple_util_C(:,:,:,:,:,:),couple_util_C(:,:,:,:,:,:)
REAL(prec) single_avg_cons_incomethreshold(MAXAGE,5,2), single_avg_labor_incomethreshold(MAXAGE,5,2), single_avg_val_incomethreshold(MAXAGE,5,2), single_dist_incomethreshold(MAXAGE,5,2), single_workingdist_incomethreshold(MAXAGE,5,2)
REAL(prec) couple_avg_cons_incomethreshold(MAXAGE,5,2), couple_avg_labor_incomethreshold(MAXAGE,5,2), couple_avg_val_incomethreshold(MAXAGE,5,2), couple_dist_incomethreshold(MAXAGE,5,2), couple_workingdist_incomethreshold(MAXAGE,5,2)
REAL(prec) single_avg_cons_incomethreshold_21_35(5,2),single_avg_cons_incomethreshold_36_50(5,2),single_avg_cons_incomethreshold_51_65(5,2),single_avg_cons_incomethreshold_66_80(5,2),single_avg_cons_incomethreshold_81_100(5,2)
REAL(prec) couple_avg_cons_incomethreshold_21_35(5,2),couple_avg_cons_incomethreshold_36_50(5,2),couple_avg_cons_incomethreshold_51_65(5,2),couple_avg_cons_incomethreshold_66_80(5,2),couple_avg_cons_incomethreshold_81_100(5,2)
REAL(prec) single_avg_labor_incomethreshold_21_35(5,2),single_avg_labor_incomethreshold_36_50(5,2),single_avg_labor_incomethreshold_51_65(5,2)
REAL(prec) couple_avg_labor_incomethreshold_21_35(5,2),couple_avg_labor_incomethreshold_36_50(5,2),couple_avg_labor_incomethreshold_51_65(5,2)
REAL(prec) single_avg_val_incomethreshold_21_35(5,2),single_avg_val_incomethreshold_36_50(5,2),single_avg_val_incomethreshold_51_65(5,2),single_avg_val_incomethreshold_66_80(5,2),single_avg_val_incomethreshold_81_100(5,2)
REAL(prec) couple_avg_val_incomethreshold_21_35(5,2),couple_avg_val_incomethreshold_36_50(5,2),couple_avg_val_incomethreshold_51_65(5,2),couple_avg_val_incomethreshold_66_80(5,2),couple_avg_val_incomethreshold_81_100(5,2)
REAL(prec) bench_singleIDCRC(:,:,:,:,:),bench_single_VR(:,:,:,:,:),bench_singleYR(:,:,:,:,:),bench_retire_single_util_C(:,:,:,:,:),bench_singleIDCWC(:,:,:,:,:),bench_single_VW(:,:,:,:,:),bench_singleYW(:,:,:,:,:),bench_single_util_C(:,:,:,:,:),bench_single_util_LS(:,:,:,:,:)
REAL(prec) bench_coupleIDCRC(:,:,:,:,:),bench_couple_VR(:,:,:,:,:),bench_coupleYR(:,:,:,:),bench_retire_couple_util_C(:,:,:,:,:),bench_coupleIDCWC(:,:,:,:,:,:),bench_couple_VW(:,:,:,:,:,:),bench_coupleYW(:,:,:,:,:),bench_couple_util_C(:,:,:,:,:,:),bench_couple_util_LS(:,:,:,:,:)
REAL(prec) change_bench_singleIDCRC(MAXAGE,5,2),change_bench_single_val(MAXAGE,5,2),bench_singleYR_incomethreshold(MAXAGE,5,2),change_bench_singleIDCWC(MAXAGE,5,2),change_bench_singleIDCWN(MAXAGE,5,2),bench_singleYW_incomethreshold(MAXAGE,5,2)
REAL(prec) change_bench_coupleIDCRC(MAXAGE,5,2),change_bench_couple_val(MAXAGE,5,2),bench_coupleYR_incomethreshold(MAXAGE,5,2),change_bench_coupleIDCWC(MAXAGE,5,2),change_bench_coupleIDCWN(MAXAGE,5,2),bench_coupleYW_incomethreshold(MAXAGE,5,2)
REAL(prec) change_bench_single_cons_incomethreshold_working(5,2),change_bench_single_labor_incomethreshold_working(5,2),change_bench_single_val_incomethreshold_working(5,2),change_bench_single_cons_incomethreshold_retire(5,2),change_bench_single_val_incomethreshold_retire(5,2)
REAL(prec) change_bench_couple_cons_incomethreshold_working(5,2),change_bench_couple_labor_incomethreshold_working(5,2),change_bench_couple_val_incomethreshold_working(5,2),change_bench_couple_cons_incomethreshold_retire(5,2),change_bench_couple_val_incomethreshold_retire(5,2)
REAL(prec) cons_change_single_male_retire(5),cons_change_single_female_retire(5),cons_change_single_male_working(5),cons_change_single_female_working(5),cons_change_couple_male_retire(5),cons_change_couple_female_retire(5),cons_change_couple_male_working(5),cons_change_couple_female_working(5)
REAL(prec) sum_bench_single_val(:,:,:), sum_single_util_C(:,:,:),sum_bench_couple_val(:,:,:),sum_couple_util_C(:,:,:),sum_single_util_LS(:,:,:),sum_couple_util_LS(:,:,:)
REAL(prec) util_welfare_id_incomethreshold(5),single_util_C_incomethreshold(5),couple_util_C_incomethreshold(5),single_util_LS_incomethreshold(5),couple_util_LS_incomethreshold(5), CEV_incomethreshold(5) 
REAL(prec) log_income_diff_single(:),log_income_shock_diff_single(:),log_cons_diff_single(:),dist_single(:),log_income_diff_couple(:),log_income_shock_diff_couple(:),log_cons_diff_couple(:),dist_couple(:)
REAL(prec) log_income_diff_single_retire(:),log_cons_diff_single_retire(:),ageprofile_log_cons_diff_single_retire(:,:),log_med_diff_single_retire(:),log_health_shock_diff_single_retire(:),ageprofile_log_health_shock_diff_single_retire(:,:),dist_single_retire(:),ageprofile_dist_single_retire(:,:),log_income_diff_couple_retire(:),log_cons_diff_couple_retire(:),ageprofile_log_cons_diff_couple_retire(:,:),dist_couple_retire(:),ageprofile_dist_couple_retire(:,:),log_health_shock_diff_couple_retire(:),ageprofile_log_health_shock_diff_couple_retire(:,:),log_med_diff_couple_retire(:)
REAL(prec) ageprofile_log_income_shock_diff_single(:,:),ageprofile_log_cons_diff_single(:,:),ageprofile_dist_single(:,:),ageprofile_log_income_shock_diff_couple(:,:),ageprofile_log_cons_diff_couple(:,:),ageprofile_dist_couple(:,:)
REAL(prec) ageprofile_avg_log_income_shock_single(:),ageprofile_avg_log_income_shock_couple(:),ageprofile_avg_log_cons_single(:),ageprofile_avg_log_cons_couple(:),ageprofile_insurance_cons_shock_nominator_single(:),ageprofile_insurance_cons_shock_nominator_couple(:)
REAL(prec) ageprofile_insurance_cons_shock_denominator_single(:),ageprofile_insurance_cons_shock_denominator_couple(:),ageprofile_insurance_cons_shock_value_single(:),ageprofile_insurance_cons_shock_value_couple(:)
REAL(prec) ageprofile_log_income_diff_single(:,:),ageprofile_log_income_diff_couple(:,:),ageprofile_avg_log_income_single(:),ageprofile_avg_log_income_couple(:)
REAL(prec) ageprofile_insurance_cons_nominator_single(:),ageprofile_insurance_cons_nominator_couple(:),ageprofile_insurance_cons_denominator_single(:),ageprofile_insurance_cons_denominator_couple(:),ageprofile_insurance_cons_value_single(:),ageprofile_insurance_cons_value_couple(:)
REAL(prec) ageprofile_avg_log_health_shock_single_retire(:),ageprofile_avg_log_health_shock_couple_retire(:),ageprofile_avg_log_cons_single_retire(:),ageprofile_avg_log_cons_couple_retire(:),ageprofile_insurance_cons_shock_nominator_single_retire(:),ageprofile_insurance_cons_shock_denominator_single_retire(:)
REAL(prec) ageprofile_insurance_cons_shock_value_single_retire(:),ageprofile_insurance_cons_shock_nominator_couple_retire(:),ageprofile_insurance_cons_shock_denominator_couple_retire(:),ageprofile_insurance_cons_shock_value_couple_retire(:)
REAL(prec) ageprofile_log_med_diff_single_retire(:,:),ageprofile_log_med_diff_couple_retire(:,:),ageprofile_avg_log_med_single_retire(:),ageprofile_avg_log_med_couple_retire(:),ageprofile_insurance_med_shock_nominator_single_retire(:),ageprofile_insurance_med_shock_denominator_single_retire(:),ageprofile_insurance_med_shock_value_single_retire(:),ageprofile_insurance_med_shock_nominator_couple_retire(:),ageprofile_insurance_med_shock_denominator_couple_retire(:),ageprofile_insurance_med_shock_value_couple_retire(:)
REAL(prec) youngage_log_income_shock_diff_single(:),youngage_log_cons_diff_single(:),midage_log_income_shock_diff_single(:),midage_log_cons_diff_single(:),youngage_dist_single(:),midage_dist_single(:),youngage_log_income_shock_diff_couple(:),youngage_log_cons_diff_couple(:),midage_log_income_shock_diff_couple(:),midage_log_cons_diff_couple(:),youngage_dist_couple(:),midage_dist_couple(:)
REAL(prec) certeqcons_singlemale(:),certeqlab_singlemale(:),certeqcons_singlefemale(:),certeqlab_singlefemale(:)
REAL(prec) certeqcons_couple(:,:,:),certeqlab_couple(:,:,:)
REAL(prec) agg_certeqcons_couple(:),agg_certeqlab_couple(:),V_certeq_couple(:)
REAL(prec) AggL_couple(:),cost_unc_couple(:),expV_certeq_couple(:),cost_ineq_couple(:),AggC_couple_leicomp(:),AggL_couple_bm(:)
REAL(prec) temp_single_discount(:,:),single_discount(:),temp_couple_discount1(:,:),temp_couple_discount2(:,:),couple_discount1(:),couple_discount2(:)
REAL(prec) c0(:),c1(:),c2(:),c3(:),avg_death(:)
REAL(prec) VSLMOMENT1(:),VSLMOMENT2(:),VSLMOMENT3(:),VSLMOMENT4(:),VSLMOMENT5(:),VSLMOMENT6(:),VSLMOMENT7(:),VSLMOMENT8(:),VSLMOMENT9(:),SURVMOMENT1(:),SURVMOMENT2(:),SURVMOMENT3(:),SURVMOMENT4(:)
REAL(prec) var_earn_husband(:),var_earn_wife(:),cov_family_earn(:),corr_family_earn(:),mean_earn_husband(:),mean_earn_wife(:)
REAL(prec) mean_earning_age_single(:),var_earning_age_single(:),mean_wage_age_single(:),var_wage_age_single(:),mean_cons_age_single(:),var_cons_age_single(:),mean_earning_age_couple(:),var_earning_age_couple(:),mean_wage_age_couple(:),var_wage_age_couple(:),mean_cons_age_couple(:),var_cons_age_couple(:)
REAL(prec) lifecycle_var_cons_earn_ratio_single(:),lifecycle_var_cons_earn_ratio_couple(:)
REAL(prec) SUBEHI(:), shock(:,:)
REAL(prec) read_vector_single(:),read_vector_couple(:)
REAL(prec) youngage_VW_delta_single(:,:,:,:,:),midage_VW_delta_single(:,:,:,:,:),uprime_alt_working_single(:,:,:,:,:),cv_working_single(:,:,:,:,:),youngage_VW_delta_couple(:,:,:,:,:),midage_VW_delta_couple(:,:,:,:,:),uprime_alt_working_couple(:,:,:,:,:),cv_working_couple(:,:,:,:,:)
REAL(prec) VR_delta_single(:,:,:,:,:),uprime_alt_retire_single(:,:,:,:,:),cv_retire_single(:,:,:,:,:),VR_delta_couple(:,:,:,:),uprime_alt_retire_couple(:,:,:,:),cv_retire_couple(:,:,:,:)

character(20) :: Argument1, Argument2, Argument3, Argument4, Argument5, Argument6, Argument7
character(20) :: Argument8, Argument9, Argument10, Argument11, Argument12,  Argument13,  Argument14
character(20) :: Argument15,  Argument16, Argument17, Argument18


ALLOCATABLE  A, AS, H, N, M, EH,  ACROSS, ALONG,ALONG_AGE, CCROSS, CLONG, CUMS, CUMSWK, EFFCROSS, EFFLONG, ICROSS, ILONG, TILONG, TICROSS
ALLOCATABLE  ALONG_AGE_single, ALONG_AGE_couple, ILONG_AGE_single, ILONG_AGE_couple, TILONG_AGE_single, TILONG_AGE_couple, YDLONG_AGE_single, YDLONG_AGE_couple,NLONG_AGE_single,NLONG_AGE_couple,labor_participation_age,labor_participation_age_single,labor_participation_age_couple,HLONG_AGE_single,HLONG_AGE_couple,MLONG_AGE_single,MLONG_AGE_couple
ALLOCATABLE  ALONG_RETIRE_single, ILONG_RETIRE_single, TILONG_RETIRE_single, YDLONG_RETIRE_single
ALLOCATABLE  ALONG20_25_single, ALONG25_30_single, ALONG30_35_single, ALONG35_40_single, ALONG40_45_single, ALONG45_50_single, ALONG50_55_single, ALONG55_60_single, ALONG60_65_single,  ALONG65_70_single, ALONG70_75_single, ALONG75_80_single, ALONG80_85_single, ALONG85_90_single, ALONG90_95_single, ALONG95_100_single, ALONG65_MORE_single
ALLOCATABLE  ILONG20_25_single, ILONG25_30_single, ILONG30_35_single, ILONG35_40_single, ILONG40_45_single, ILONG45_50_single, ILONG50_55_single, ILONG55_60_single, ILONG60_65_single, ILONG65_MORE_single
ALLOCATABLE  TILONG20_25_single, TILONG25_30_single, TILONG30_35_single, TILONG35_40_single, TILONG40_45_single, TILONG45_50_single, TILONG50_55_single, TILONG55_60_single, TILONG60_65_single, TILONG65_MORE_single
ALLOCATABLE  YDLONG20_25_single, YDLONG25_30_single, YDLONG30_35_single, YDLONG35_40_single, YDLONG40_45_single, YDLONG45_50_single, YDLONG50_55_single, YDLONG55_60_single, YDLONG60_65_single, YDLONG65_MORE_single
ALLOCATABLE	 WLONG_AGE
ALLOCATABLE  sort_inc_retire, sort_D_inc_retire, box_inc_retire,temp_sort_D_inc_retire
ALLOCATABLE  HCROSS, HLONG, MCROSS, MLONG, NCROSS, NLONG, LCROSS, LLONG_single,LLONG_couple, MU, MUWK, DEP_H !S
ALLOCATABLE  singleIDCWA, coupleIDCWA, singleIDCWN, coupleIDCWN, singleIDCWC, coupleIDCWC,singleVW, coupleVW, singleYW, coupleYW, marriageVW
ALLOCATABLE	 singleIDCRA, coupleIDCRA, singleIDCRN, coupleIDCRN, singleIDCRC, coupleIDCRC, singleVR, coupleVR, marriageVR, singleYR, coupleYR, Y_AGE, singleIDCRM, coupleIDCRM, singleIDCRH, coupleIDCRH
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
ALLOCATABLE  top05pct_D_tinc, top1pct_D_tinc, top5pct_D_tinc, top10pct_D_tinc, top20pct_D_tinc, top40pct_D_tinc,top50pct_D_tinc, top60pct_D_tinc,top70pct_D_tinc, top80pct_D_tinc,top90pct_D_tinc,top95pct_D_tinc,top99pct_D_tinc,bot20pct_D_tinc
ALLOCATABLE  top0001pct_D_tinc, top0005pct_D_tinc, top001pct_D_tinc, top005pct_D_tinc, top01pct_D_tinc, top025pct_D_tinc
ALLOCATABLE  top05pct_D_R, top1pct_D_R, top5pct_D_R, top10pct_D_R, top20pct_D_R, top40pct_D_R,top50pct_D_R, top60pct_D_R,top70pct_D_R, top80pct_D_R
ALLOCATABLE  top0001pct_D_R, top0005pct_D_R, top001pct_D_R, top01pct_D_R
ALLOCATABLE  top1pct_D_B,top2pct_D_B,top5pct_D_B,top10pct_D_B,top20pct_D_B,top30pct_D_B,top40pct_D_B,top50pct_D_B,top60pct_D_B,top70pct_D_B,top80pct_D_B,top90pct_D_B
ALLOCATABLE  top1pct_D_B_age52,top2pct_D_B_age52,top5pct_D_B_age52,top10pct_D_B_age52,top20pct_D_B_age52,top30pct_D_B_age52,top40pct_D_B_age52,top50pct_D_B_age52,top60pct_D_B_age52,top70pct_D_B_age52,top80pct_D_B_age52,top90pct_D_B_age52
ALLOCATABLE  top05pct_D_C, top1pct_D_C, top5pct_D_C, top10pct_D_C, top20pct_D_C, top40pct_D_C, top50pct_D_C, top60pct_D_C, top70pct_D_C, top80pct_D_C, top90pct_D_C, top95pct_D_C, top99pct_D_C
ALLOCATABLE  top0001pct_D_C, top0005pct_D_C, top001pct_D_C, top01pct_D_C
!ALLOCATABLE  ATR, R_ANNUAL
!ALLOCATABLE  adj_sort_A 
ALLOCATABLE  record_position_tinc,record_position_tinc_single, record_position_tinc_couple, record_position_A,record_position_A_single,record_position_A_couple,record_position_E,record_position_E_retire,record_position_E_single,record_position_E_couple,record_position_B,record_position_C
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
ALLOCATABLE  log_income_diff_single_retire,log_cons_diff_single_retire,ageprofile_log_cons_diff_single_retire,log_med_diff_single_retire,log_health_shock_diff_single_retire,ageprofile_log_health_shock_diff_single_retire,dist_single_retire,ageprofile_dist_single_retire,log_income_diff_couple_retire,log_cons_diff_couple_retire,ageprofile_log_cons_diff_couple_retire,dist_couple_retire,ageprofile_dist_couple_retire,log_health_shock_diff_couple_retire,ageprofile_log_health_shock_diff_couple_retire,log_med_diff_couple_retire
ALLOCATABLE	 ageprofile_log_income_shock_diff_single,ageprofile_log_cons_diff_single,ageprofile_dist_single,ageprofile_log_income_shock_diff_couple,ageprofile_log_cons_diff_couple,ageprofile_dist_couple
ALLOCATABLE  ageprofile_avg_log_income_shock_single,ageprofile_avg_log_income_shock_couple,ageprofile_avg_log_cons_single,ageprofile_avg_log_cons_couple,ageprofile_insurance_cons_shock_nominator_single,ageprofile_insurance_cons_shock_nominator_couple
ALLOCATABLE  ageprofile_insurance_cons_shock_denominator_single,ageprofile_insurance_cons_shock_denominator_couple,ageprofile_insurance_cons_shock_value_single,ageprofile_insurance_cons_shock_value_couple
ALLOCATABLE	 ageprofile_log_income_diff_single,ageprofile_log_income_diff_couple,ageprofile_avg_log_income_single,ageprofile_avg_log_income_couple
ALLOCATABLE  ageprofile_insurance_cons_nominator_single,ageprofile_insurance_cons_nominator_couple,ageprofile_insurance_cons_denominator_single,ageprofile_insurance_cons_denominator_couple,ageprofile_insurance_cons_value_single,ageprofile_insurance_cons_value_couple
ALLOCATABLE  ageprofile_avg_log_health_shock_single_retire,ageprofile_avg_log_health_shock_couple_retire,ageprofile_avg_log_cons_single_retire,ageprofile_avg_log_cons_couple_retire,ageprofile_insurance_cons_shock_nominator_single_retire,ageprofile_insurance_cons_shock_denominator_single_retire
ALLOCATABLE  ageprofile_insurance_cons_shock_value_single_retire,ageprofile_insurance_cons_shock_nominator_couple_retire,ageprofile_insurance_cons_shock_denominator_couple_retire,ageprofile_insurance_cons_shock_value_couple_retire
ALLOCATABLE  ageprofile_log_med_diff_single_retire,ageprofile_log_med_diff_couple_retire,ageprofile_avg_log_med_single_retire,ageprofile_avg_log_med_couple_retire,ageprofile_insurance_med_shock_nominator_single_retire,ageprofile_insurance_med_shock_denominator_single_retire,ageprofile_insurance_med_shock_value_single_retire,ageprofile_insurance_med_shock_nominator_couple_retire,ageprofile_insurance_med_shock_denominator_couple_retire,ageprofile_insurance_med_shock_value_couple_retire
ALLOCATABLE  youngage_log_income_shock_diff_single,youngage_log_cons_diff_single,midage_log_income_shock_diff_single,midage_log_cons_diff_single,youngage_dist_single,midage_dist_single,youngage_log_income_shock_diff_couple,youngage_log_cons_diff_couple,midage_log_income_shock_diff_couple,midage_log_cons_diff_couple,youngage_dist_couple,midage_dist_couple
ALLOCATABLE  certeqcons_singlemale,certeqlab_singlemale,certeqcons_singlefemale,certeqlab_singlefemale
ALLOCATABLE  certeqcons_couple,certeqlab_couple
ALLOCATABLE  agg_certeqcons_couple,agg_certeqlab_couple,V_certeq_couple
ALLOCATABLE  AggL_couple,cost_unc_couple,expV_certeq_couple,cost_ineq_couple,AggC_couple_leicomp,AggL_couple_bm
ALLOCATABLE  temp_single_discount,single_discount,temp_couple_discount1,temp_couple_discount2,couple_discount1,couple_discount2
ALLOCATABLE	 c0,c1,c2,c3,avg_death
ALLOCATABLE  VSLMOMENT1,VSLMOMENT2,VSLMOMENT3,VSLMOMENT4,VSLMOMENT5,VSLMOMENT6,VSLMOMENT7,VSLMOMENT8,VSLMOMENT9,SURVMOMENT1,SURVMOMENT2,SURVMOMENT3,SURVMOMENT4
ALLOCATABLE  var_earn_husband,var_earn_wife,cov_family_earn,corr_family_earn,mean_earn_husband,mean_earn_wife
ALLOCATABLE  mean_earning_age_single,var_earning_age_single,mean_wage_age_single,var_wage_age_single,mean_cons_age_single,var_cons_age_single,mean_earning_age_couple,var_earning_age_couple,mean_wage_age_couple,var_wage_age_couple,mean_cons_age_couple,var_cons_age_couple
ALLOCATABLE  lifecycle_var_cons_earn_ratio_single,lifecycle_var_cons_earn_ratio_couple
ALLOCATABLE  SUBEHI,shock
ALLOCATABLE read_vector_single,read_vector_couple
ALLOCATABLE youngage_VW_delta_single,midage_VW_delta_single,uprime_alt_working_single,cv_working_single,youngage_VW_delta_couple,midage_VW_delta_couple,uprime_alt_working_couple,cv_working_couple
ALLOCATABLE VR_delta_single,uprime_alt_retire_single,cv_retire_single,VR_delta_couple,uprime_alt_retire_couple,cv_retire_couple

real(prec) ostart,oend
real(prec) fstart, fend

!*********************
!
!   Open Files
!
!*********************

!OPEN(UNIT=7,FILE='........\comboeff_sigiri_5period.txt')
!OPEN(UNIT=10,FILE='........\Health_result_benchmark.txt')   
!OPEN(UNIT=18,FILE='........\Health_profile_benchmark.txt')
! OPEN(UNIT=60,FILE='comboeff_sigiri_5period.txt')
OPEN(UNIT=60,FILE='age_eff.txt')
OPEN(UNIT=7,FILE='male_age_eff.txt')
OPEN(UNIT=9,FILE='female_age_eff.txt')
OPEN(UNIT=14,FILE='male_surv.txt')
OPEN(UNIT=13,FILE='female_surv.txt')
OPEN(UNIT=10,FILE='Health_result_benchmark.txt')   
! OPEN(UNIT=18,FILE='Health_profile_benchmark.txt')
OPEN(UNIT=4,FILE='sort_A.txt')
OPEN(UNIT=5,FILE='sort_INC.txt')
OPEN(UNIT=8,FILE='sort_tinc.txt')
OPEN(UNIT=3,FILE='dist.txt')
OPEN(UNIT=2,FILE='record_position_tinc.txt')
OPEN(UNIT=12,FILE='D_inc.txt')
OPEN(UNIT=54,FILE='opt_tax_record.txt')
OPEN(UNIT=22,FILE='gender_gap_data.txt')
OPEN(UNIT=25,FILE='couple_labor_male.txt')
OPEN(UNIT=26,FILE='couple_labor_female.txt')
!*********************
!
!   Read Data
!
!*********************
	
	CALL GET_COMMAND_ARGUMENT(1,Argument1)
	CALL GET_COMMAND_ARGUMENT(2,Argument2)
	CALL GET_COMMAND_ARGUMENT(3,Argument3)
	CALL GET_COMMAND_ARGUMENT(4,Argument4)
	CALL GET_COMMAND_ARGUMENT(5,Argument5)
	CALL GET_COMMAND_ARGUMENT(6,Argument6)
	CALL GET_COMMAND_ARGUMENT(7,Argument7)
	CALL GET_COMMAND_ARGUMENT(8,Argument8)
	! CALL GET_COMMAND_ARGUMENT(9,Argument9)
	! CALL GET_COMMAND_ARGUMENT(10,Argument10)
	
	read(Argument1,*) BETA_ANNUAL 
	! read(Argument2,*) delta_lambda
	! read(Argument2,*) weight_MFS
	! read(Argument3,*) d_c
	read(Argument2,*) fixcost_singlefemale
	read(Argument3,*) fixcost_marriedfemale
	read(Argument4,*) theta_single_male
	read(Argument5,*) theta_married_male
	read(Argument6,*) theta_single_female
	read(Argument7,*) theta_married_female
	read(Argument8,*) earn_corr
	
	! nthr = OMP_GET_NUM_THREADS()
    ! print *, ' We are using',nthr,' thread(s)'
	BETA = BETA_ANNUAL**5.00  ! change beta from annual to 5 years

	! Assortative mating matrix: source: Educational Assortative Mating in Japan Evidence from the 1980-2010 Census
 	
	 P_m = RESHAPE((/0.289, 0.163, 0.124, 0.424/),(/2,2/))	!2010

	! Random mating matrix:
	! P_m = RESHAPE((/0.427062, 0.226284, 0.225285, 0.11937/),(/2,2/))	!2005

!**********************************************************************
	! Health Transition Matrix 
	
	! Every 5 years
	! !Age 65-69
	! P_h(:,:,1) = RESHAPE((/0.6586,0.201,0.08681,0.06587,0.09244,0.1777,0.4913,0.2209,0.06786,0.1008,0.11,0.2171,0.5352,0.3353,0.2605,0.04092,0.06824,0.1253,0.4471,0.3193,0.01279,0.02233,0.03187,0.08383,0.2269 /),(/5,5/))
	! !Age 70-74
	! P_h(:,:,2) = RESHAPE((/0.6213,0.2155,0.08861,0.09375,0.01667,0.2109,0.459,0.2152,0.1116,0.1,0.1134,0.2412,0.5298,0.2768,0.2,0.04989,0.05621,0.1392,0.4196,0.3167,0.004535,0.0281,0.02712,0.09821,0.3667 /),(/5,5/))
	! !Age 75-79
	! P_h(:,:,3) = RESHAPE((/0.6061,0.2308,0.09341,0.07595,0.0, 0.1697,0.4505,0.2308,0.08861,0.08696,0.1758,0.2308,0.5165,0.2152,0.2609,0.02424,0.06593,0.1264,0.5443,0.3913,0.02424,0.02198,0.03297,0.07595,0.2609 /),(/5,5/))
	! !Age 80+
	! P_h(:,:,4) = RESHAPE((/0.5938,0.1406,0.09375,0.1176,0.2,0.2031,0.5625,0.1771,0.1176,0.2,0.1406,0.1875,0.5625,0.3235,0.0,0.03125,0.07813,0.1458,0.3235,0.6,0.03125,0.03125,0.02083,0.1176,0.0 /),(/5,5/))
	

	! Every 10 years
	! Age 65-74
	P_h(:,:,1) = RESHAPE((/0.6451,0.206,0.08749,0.07448,0.06704,0.1897,0.4801,0.2187,0.08138,0.1006,0.1112,0.2255,0.5332,0.3172,0.2402,0.04415,0.06407,0.1306,0.4386,0.3184,0.009812,0.02433,0.03008,0.08828,0.2737 /),(/5,5/))
	! Age 65-74
	P_h(:,:,2) = RESHAPE((/0.6451,0.206,0.08749,0.07448,0.06704,0.1897,0.4801,0.2187,0.08138,0.1006,0.1112,0.2255,0.5332,0.3172,0.2402,0.04415,0.06407,0.1306,0.4386,0.3184,0.009812,0.02433,0.03008,0.08828,0.2737 /),(/5,5/))
	! Age 75+
	P_h(:,:,3) = RESHAPE((/0.6026,0.2073,0.09353,0.0885,0.03571,0.179,0.4797,0.2122,0.09735,0.1071,0.1659,0.2195,0.5324,0.2478,0.2143,0.0262,0.06911,0.1331,0.4779,0.4286,0.0262,0.02439,0.02878,0.0885,0.2143 /),(/5,5/))
	! Age 75+
	P_h(:,:,4) = RESHAPE((/0.6026,0.2073,0.09353,0.0885,0.03571,0.179,0.4797,0.2122,0.09735,0.1071,0.1659,0.2195,0.5324,0.2478,0.2143,0.0262,0.06911,0.1331,0.4779,0.4286,0.0262,0.02439,0.02878,0.0885,0.2143 /),(/5,5/))

	! Average all the retired groups
	! DO i = 1,4
	! 	P_h(:,:,i) = RESHAPE((/0.6384,0.2062,0.08845,0.07637,0.0628,0.188,0.4801,0.2177,0.08353,0.1014,0.1198,0.2245,0.533,0.3079,0.2367,0.04132,0.06491,0.131,0.4439,0.3333,0.0124,0.02434,0.02987,0.08831,0.2657 /),(/5,5/))
	! END DO

!**********************************************************************
	print*, ' '
		print *, "Transition Matrix for health "
			DO j = 1,4
				DO i=1,NGRIDH
					WRITE(*,"(12(F10.6,1X))") P_h(i,1:NGRIDH,j)
				END DO
				print*, ' '
			END DO
	print*, ' '
	
!============================================================================Earning Process=================================================================================================================

!-----------------------------------------BLK wineq version Rouwenhorst Method ----------------------------------------

! 1 year transition matrix of "ordinary" idiosyncratic productivity shock
! DO IG=1,2
! 	P(1,:,IG) = [real(prec) :: 0.900601*(1.0-prob_sep), 0.096798*(1.0-prob_sep), 0.002601*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(2,:,IG) = [real(prec) :: 0.048399*(1.0-prob_sep), 0.903202*(1.0-prob_sep), 0.048399*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(3,:,IG) = [real(prec) :: 0.002601*(1.0-prob_sep), 0.096798*(1.0-prob_sep), 0.900601*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(4,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.900601*(1.0-prob_sep), 0.096798*(1.0-prob_sep), 0.002601*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(5,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.048399*(1.0-prob_sep), 0.903202*(1.0-prob_sep), 0.048399*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(6,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.002601*(1.0-prob_sep), 0.096798*(1.0-prob_sep), 0.900601*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(7,:,IG) = [real(prec) :: prob_job/3.0,  prob_job/3.0,  prob_job/3.0,  0.000000,  0.000000,  0.000000,   1.0-prob_job,  0.000000]
! 	P(8,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, prob_job/3.0,  prob_job/3.0,  prob_job/3.0,  0.000000,   1.0-prob_job]
! END DO 

! 6 months transition matrix of "ordinary" idiosyncratic productivity shock
! DO IG=1,2
! 	P(1,:,IG) = [real(prec) :: 0.948314309619285*(1.0-prob_sep), 0.051000000000000*(1.0-prob_sep), 0.000685690380715*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(2,:,IG) = [real(prec) :: 0.025500000000000*(1.0-prob_sep), 0.949000000000000*(1.0-prob_sep), 0.025500000000000*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(3,:,IG) = [real(prec) :: 0.000685690380715*(1.0-prob_sep), 0.051000000000000*(1.0-prob_sep), 0.948314309619285*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(4,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.948314309619285*(1.0-prob_sep), 0.051000000000000*(1.0-prob_sep), 0.000685690380715*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(5,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.025500000000000*(1.0-prob_sep), 0.949000000000000*(1.0-prob_sep), 0.025500000000000*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(6,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.000685690380715*(1.0-prob_sep), 0.051000000000000*(1.0-prob_sep), 0.948314309619285*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(7,:,IG) = [real(prec) :: prob_job/3.0,  prob_job/3.0,  prob_job/3.0,  0.000000,  0.000000,  0.000000,   1.0-prob_job,  0.000000]
! 	P(8,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, prob_job/3.0,  prob_job/3.0,  prob_job/3.0,  0.000000,   1.0-prob_job]
! END DO

! ! 5 years transition matrix of "ordinary" idiosyncratic productivity shock
! DO IG=1,2
! 	P(1,:,IG) = [real(prec) :: 0.627230811894400*(1.0-prob_sep), 0.329496471483167*(1.0-prob_sep), 0.043272716622432*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(2,:,IG) = [real(prec) :: 0.164748235741584*(1.0-prob_sep), 0.670503528516832*(1.0-prob_sep), 0.164748235741584*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(3,:,IG) = [real(prec) :: 0.043272716622432*(1.0-prob_sep), 0.329496471483167*(1.0-prob_sep), 0.627230811894400*(1.0-prob_sep), 0.000000, 0.000000, 0.000000,  prob_sep,  0.000000]
! 	P(4,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.627230811894400*(1.0-prob_sep), 0.329496471483167*(1.0-prob_sep), 0.043272716622432*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(5,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.164748235741584*(1.0-prob_sep), 0.670503528516832*(1.0-prob_sep), 0.164748235741584*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(6,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.043272716622432*(1.0-prob_sep), 0.329496471483167*(1.0-prob_sep), 0.627230811894400*(1.0-prob_sep),  0.000000,  prob_sep]
! 	P(7,:,IG) = [real(prec) :: prob_job/3.0,  prob_job/3.0,  prob_job/3.0,  0.000000,  0.000000,  0.000000,   1.0-prob_job,  0.000000]
! 	P(8,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, prob_job/3.0,  prob_job/3.0,  prob_job/3.0,  0.000000,   1.0-prob_job]
! END DO 
DO IG=1,2
	P(1,:,IG) = [real(prec) :: 0.627230811894400, 0.329496471483167, 0.043272716622432, 0.000000, 0.000000, 0.000000]
	P(2,:,IG) = [real(prec) :: 0.164748235741584, 0.670503528516832, 0.164748235741584, 0.000000, 0.000000, 0.000000]
	P(3,:,IG) = [real(prec) :: 0.043272716622432, 0.329496471483167, 0.627230811894400, 0.000000, 0.000000, 0.000000]
	P(4,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.627230811894400, 0.329496471483167, 0.043272716622432]
	P(5,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.164748235741584, 0.670503528516832, 0.164748235741584]
	P(6,:,IG) = [real(prec) :: 0.000000, 0.000000, 0.000000, 0.043272716622432, 0.329496471483167, 0.627230811894400]
END DO 

print *, "Transition Matrix for Productivity Process"
	DO i=1,nn
	  	WRITE(*,"(12(F10.6,1X))") P(i,1:nn,1)
	END DO
print*, ' '

! basicz(1) = -1.442036615248569
! basicz(2) = -0.669251522224642
! basicz(3) = 0.103533570799286
! basicz(4) = -0.103533570799286
! basicz(5) = 0.669251522224642
! basicz(6) = 1.442036615248569

! z(:) = basicz(:)
! DO i=1,6
! 	z(i) = exp(z(i))/exp(basicz(1))
! END DO 


basicz(1) = -1.240265294201204
basicz(2) = 0.0
basicz(3) =  1.240265294201204
basicz(4) = -1.240265294201204	
basicz(5) = 0.0
basicz(6) = 1.240265294201204

z(:) = basicz(:)
DO i=1,6
	z(i) = exp(z(i))/exp(basicz(1))
END DO 
! college wage premium in Japan is about 1.34 (Kawaguchia and Mori 2016: Why has wage inequality evolved so differently between Japan and the US? The role of the supply of college-educated workers)
z(4) = 1.4*z(1)
z(5) = 1.4*z(2)
z(6) = 1.4*z(3)

W(:,1) = z(:)
W(:,2) = z(:)

print*,'z states'
WRITE(*,"(12(F12.4,1X))") W(:,1)
WRITE(*,"(12(F12.4,1X))") W(:,2)

!=============================================================================================================================================================================================================

! (1) Data from CPS (Table A-1. Years of School Completed by People 25 Years and Over, by Age and Sex:  Selected Years 1940 to 2018)
	! initial_dist_z(1,1) = 0.5798867
	! initial_dist_z(2,1) = 0.0
	! initial_dist_z(3,1) = 0.0
	! initial_dist_z(4,1) = 1.0-0.5798867
	! initial_dist_z(5,1) = 0.0
	! initial_dist_z(6,1) = 0.0

	! initial_dist_z(1,2) = 0.6336308
	! initial_dist_z(2,2) = 0.0
	! initial_dist_z(3,2) = 0.0
	! initial_dist_z(4,2) = 1.0-0.6336308
	! initial_dist_z(5,2) = 0.0
	! initial_dist_z(6,2) = 0.0

! (2) Initial productivity type distribution (unconditional)
	! initial_dist_z(1,:) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)
	! initial_dist_z(2,:) = 0.824/(0.088+0.824+0.088+0.088+0.824+0.088)
	! initial_dist_z(3,:) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)
	! initial_dist_z(4,:) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)
	! initial_dist_z(5,:) = 0.824/(0.088+0.824+0.088+0.088+0.824+0.088)
	! initial_dist_z(6,:) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)

! (1)+(2)	OECD:Population with tertiary education is defined as those having completed the highest level of education, by age group. 
	initial_dist_z(1,1) = (1.0-0.571)*0.090500/(0.090500+0.819000+0.0905000)
	initial_dist_z(2,1) = (1.0-0.571)*0.819000/(0.090500+0.819000+0.0905000)
	initial_dist_z(3,1) = (1.0-0.571)*0.090500/(0.090500+0.819000+0.0905000)
	initial_dist_z(4,1) = 0.571*0.090500/(0.090500+0.819000+0.0905000)
	initial_dist_z(5,1) = 0.571*0.819000/(0.090500+0.819000+0.0905000)
	initial_dist_z(6,1) = 0.571*0.090500/(0.090500+0.819000+0.0905000)
	! initial_dist_z(7,1) = 0.0
	! initial_dist_z(8,1) = 0.0

	initial_dist_z(1,2) = (1.0-0.626)*0.090500/(0.090500+0.819000+0.0905000)
	initial_dist_z(2,2) = (1.0-0.626)*0.819000/(0.090500+0.819000+0.0905000)
	initial_dist_z(3,2) = (1.0-0.626)*0.090500/(0.090500+0.819000+0.0905000)
	initial_dist_z(4,2) = 0.626*0.090500/(0.090500+0.819000+0.0905000)
	initial_dist_z(5,2) = 0.626*0.819000/(0.090500+0.819000+0.0905000)
	initial_dist_z(6,2) = 0.626*0.090500/(0.090500+0.819000+0.0905000)
	! initial_dist_z(7,2) = 0.0
	! initial_dist_z(8,2) = 0.0
	
	
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

! ------------------------------- Apply the age-eff profiles from JHPS -------------------------------
ALLOCATE( EFFCROSS(RETAGE-1,2) )    
READ(7,*) ( EFFCROSS(AGE,1), AGE=1,RETAGE-1 )	! Male age-eff
READ(9,*) ( EFFCROSS(AGE,2), AGE=1,RETAGE-1 )	! Female age-eff
! READ(7,*) ( EFFCROSS(AGE,1), AGE=1,8 )	! Male age-eff
! READ(9,*) ( EFFCROSS(AGE,2), AGE=1,8 )	! Female age-eff

! Normalize the first period efficieny to be 1
	! EFFCROSS(:,1) = EFFCROSS(:,1)/EFFCROSS(1,1)
	! EFFCROSS(:,2) = EFFCROSS(:,2)/EFFCROSS(1,2)

! Longitudinal age-earnings profile for given cohort
ALLOCATE( EFFLONG(RETAGE-1,2) )
EFFLONG(:,1) = EFFCROSS(:,1)
EFFLONG(:,2) = EFFCROSS(:,2)

! DO AGE=1,8
! 	EFFLONG(1+5*(AGE-1):AGE*5,1) = EFFCROSS(AGE,1)
! 	EFFLONG(1+5*(AGE-1):AGE*5,2) = EFFCROSS(AGE,2)
! END DO 

! EFFLONG(:,1) = EFFLONG(:,1)/EFFCROSS(1,1)
! EFFLONG(:,2) = EFFLONG(:,2)/EFFCROSS(1,2)
! EFFLONG(:,1) = EFFLONG(:,1)/EFFCROSS(1,1)
! EFFLONG(:,2) = EFFLONG(:,2)/EFFCROSS(1,1)
EFFLONG(:,1) = EFFLONG(:,1)/EFFCROSS(1,2)
EFFLONG(:,2) = EFFLONG(:,2)/EFFCROSS(1,2)


print*,'Male age-eff profiles'
print*, EFFLONG(:,1)
print*,'Female age-eff profiles'
print*, EFFLONG(:,2)

! OPEN(UNIT=27,FILE='EFFLONG.txt')
! 	write(27,*) EFFLONG
! CLOSE(27)

!*****************************************

! Survival probability parameters

!*****************************************
ALLOCATE(c0(2),c1(2),c2(2),c3(2))

c0(1) = -6.0966   !-6.0966 
c0(2) = -7.06932  !-7.06932
c1(1) = 0.1112	  !0.1112			
c1(2) = 0.1145    !0.1145
c2(1) = 0.022	  !0.022				
c2(2) = 0.025     !0.025
c3(1) = -2.8	  !-0.8    
c3(2) = -2.8	  !-0.8 

! c0(1) = -5.81 
! c0(2) = -5.81 
! c1(1) = 0.285				
! c1(2) = 0.285
! c2(1) = 0.0082					
! c2(2) = 0.0082
! c3(1) = -0.17	  
! c3(2) = -0.17


!***************************************
!
!   Depareciation rate of health status
!
!***************************************

    ALLOCATE(DEP_H(MAXAGE))
    	
	DO AGE=1,MAXAGE
		DEP_H(AGE) = 1/(1+EXP(-a0-a1*AGE-a2*(AGE**2)))
	END DO 
	 

	!DO AGE=1,MAXAGE
	!   DEP_H(AGE) = 0.00000
    !END DO 

!***************************************
!
!   Health Insurance copayment rates:
!   Under 70: 0.7
!   70-74   : 0.8
!   75+     : 0.9
!
!***************************************
	ALLOCATE(SUBEHI(MAXAGE))
	! DO AGE=1,RETAGE
	! 	SUBEHI(AGE) = 0.7
	! END DO 
	! SUBEHI(RETAGE+1) = 0.8
	! SUBEHI(RETAGE+2:MAXAGE) = 0.9

	! SUBEHI(:) = 0.0
	SUBEHI(:) = 0.8

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
	ALLOCATE( A(NGRIDA) ) 
	A = (/ ( exp(log(AMIN) + (log(AMAX)-log(AMIN))*(FLOAT(IA-1)/FLOAT(NGRIDA-1)) ), IA=1,NGRIDA ) /)
	A(1) = 0.0000001

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
SELECT CASE(couple_labor)
CASE(0)
    ALLOCATE(N(NGRIDA+(RETAGE-1)*2))	
	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)	
	READ(25,*) ( N(AGE), AGE=NGRIDA+1,NGRIDA+RETAGE-1 )
	READ(26,*) ( N(AGE), AGE=NGRIDA+RETAGE,NGRIDA+(RETAGE-1)*2 )
CASE(1)
	ALLOCATE(N(NGRIDA+(RETAGE-1)))	
	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)
	READ(26,*) ( N(AGE), AGE=NGRIDA+1,NGRIDA+RETAGE-1 )
CASE(2)
	ALLOCATE(N(NGRIDA))	
	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)	
END SELECT

!   Tabulate health level

    ALLOCATE (H(NGRIDH))         ! for state variable 
    H=(/ ( HMAX*(1.000-(FLOAT(IH-1)/FLOAT(NGRIDH-1))**1.000), IH=1,NGRIDH) /)
	H(NGRIDH) = HMIN
	print*,'H grid',H(:)

!   Tabulate medical expenditure level

    ALLOCATE(M(NGRIDA))
	M = (/ ( MMAX*((FLOAT(IM-1)/FLOAT(NGRIDA-1))**1.000), IM=1,NGRIDA ) /)
 
	

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
	! MTAX    = 0.0
	! PREMIUM = PREMIUM0

	! R_ANNUAL =  0.041	!0.03687	! Initial guess of interest rate
	! R = (1+R_ANNUAL)**5.00-1.00
	! R1 = (1+Rmin)**5.0-1.0
	! R2 = (1+Rmax)**5.0-1.0

!   Growth rate of aggregate output
     AGROWTH = (1.0+GROWTH)*(1.0+POPG) - 1.000
  

!  conditional probability for a married household to be a perfectly correlated household given that they are on the diagonal
	earn_corr_conditional = earn_corr/(earn_corr+(1.0-earn_corr)*DOT_PRODUCT(SSprob_z1(1,:),SSprob_z2(1,:)))
	print*,'earn_corr_conditional=',earn_corr_conditional
                                                               
! Write to Output file

    WRITE(10,*) 'PARAMETER VALUES for Health_GE_5period_endosur_MD_benchmark.f90'
    WRITE(10,*) '------------------------------------------------------'
    WRITE(10,*)

	WRITE(10,*) '	Wage rate:', WAGE
	WRITE(10,*) '	Interest rate (annual):', R_ANNUAL
	WRITE(10,*) '	Interest rate (5 years accumulative):', R
    WRITE(10,*)

    WRITE(10,*) '	Initial Bequest:', BEQ0
    WRITE(10,*) '	Initial SS benefit:', SS0
    WRITE(10,*) '	Initial SS benefit:', STAX0
    WRITE(10,*) '	Initial med tax rate:', MTAX0
    ! WRITE(10,*) '	Initial EHI premium:', PREMIUM0
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
    WRITE(10,*) '  Constant term in utility function(male):', UCONS1
	WRITE(10,*) '  Constant term in utility function(female):', UCONS2
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
    WRITE(10,*) '  Subsidy rate of med (Medicaid + Medicare):', SUBEHI(RETAGE)
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
	gov_exp = 0.1163	!SNA = 0.2436 ; 20% Females, the elderly, and also males: Demographic aging and macroeconomy in Japan; 0.1163 Welfare analysis of pension reforms in an ageing Japan
ELSEIF (GBC_method_activation==1) THEN 	!Benchmark set GBC_method=1 because the GB is cleared by Gov
	GBC_method = 1	
ELSEIF (GBC_method_activation==2) THEN 	!Benchmark set GBC_method=1 because the GB is cleared by tau_s
	GBC_method = 2	
	gov_exp = 0.1163	!SNA = 0.2436 ; 20% Females, the elderly, and also males: Demographic aging and macroeconomy in Japan; 0.1163 Welfare analysis of pension reforms in an ageing Japan
ELSEIF (GBC_method_activation==3) THEN 	!Benchmark set GBC_method=1 because the GB is cleared by tau_s
	GBC_method = 3	
	gov_exp = 0.1163	!SNA = 0.2436 ; 20% Females, the elderly, and also males: Demographic aging and macroeconomy in Japan; 0.1163 Welfare analysis of pension reforms in an ageing Japan
ELSEIF (GBC_method_activation==4) THEN 	!Benchmark set GBC_method=1 because the GB is cleared by tau_s
	GBC_method = 4	
	gov_exp = 0.1163
END IF  

888 continue 

count = 0
DO JTS=11,11
	DO JTM=13,13
		
		tau_l_single = (JTS+0.0)/100.0
		tau_l_couple = (JTM+0.0)/100.0
		

		IF (optimal_tax == 0) THEN 	
		! Benchmark		
		! Krueger et al 2019
			tau_l_single = 0.121497
			tau_l_couple = 0.085774	!average of all married household types: (0.073769+0.086518+0.097036)/3 

		END IF 	

	
		BEQ = BEQ0
		R_ANNUAL =  0.018		! Initial guess of interest rate
		R = (1+R_ANNUAL)**5.00-1.00
		! R1 = Rmin
		! R2 = Rmax
		R1 = (1+Rmin)**5.0-1.0
		R2 = (1+Rmax)**5.0-1.0
		

!*******************************
!
! 	General Equilibrium
!
!*******************************
LOOPNUMBER = 0
KDEV = 1.0  
WAGE = 1.0  ! Initial guess of wage
avg_earnings = 1.00 ! benchmark avg earnings
OUTPUT = 30.0		! benchmark output
count = count + 1

DO WHILE ( KDEV > TOLK)

BEQ     = BEQ0
gov_trans = 0.0
medicare = 0.0
!SS      = SS0	  

incsscap = incsscap_2000/(avg_monthly_earnings2000) 	

lambda1 = lambdamin
lambda2 = lambdamax
lambda = 0.5*lambda1 + 0.5*lambda2
dlam = 1.0

! tau_s1 = tau_s_min
! tau_s2 = tau_s_max
! tau_s = 0.5*tau_s1 + 0.5*tau_s2
tau_s = 0.1	!initial guess of tau_s
premium_rate = 0.1	!initial guess 
dtau_s = 1.0
lumpsum = 0.0
lumpsum_taxrev = 0.0
dlumpsum = 1.0
dpremium_rate = 1.0

PIA_factor = 0.57	! match the target SS/Y
dPIA = 0.0	

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
! Krueger et al 2019
	lambda = 0.916685
	lambda_couple = 0.970987 	! average of all married household types: (0.948966+0.971621+0.992375)/3
END IF 

! Compute income bend point for top marginal tax rate given lambda:

IF (ty_max_restriction == 1) THEN 
	IF (tau_l_single>0.0) THEN 
		singlebendy=((1.0-tau_l_single)*lambda/(1.0-ty_max))**(1.0/tau_l_single)	!bendy = y/AE
		MFSbendy=((1.0-tau_l_couple)*lambda_couple/(1.0-ty_max))**(1.0/tau_l_couple) 
	ELSE
		singlebendy= 1.E7
		MFSbendy= 1.E7
	END IF 

	IF (tau_l_couple>0.0) THEN 
		couplebendy=((1.0-tau_l_couple)*(lambda_couple)/(1.0-ty_max))**(1.0/tau_l_couple)                                                                                                             
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
	print*,'lambda',lambda
	print*,'tau_MFJ',tau_l_couple
	print*,'lambda_couple',lambda_couple
	print*,'count',count
	print*, ' ========================================================'
ELSEIF (GBC_method == 3) THEN 
	print*, ' =================New iteration on lump sum================='
	print*,'lump sum',lumpsum
	print*,'lumpsum_taxrev',lumpsum_taxrev
	print*,'lumpsum_taxrev_implied',lumpsum_taxrev_implied
	print*,'dlumpsum', dlumpsum
	print*,'count',count
	print*, ' ========================================================'
END IF 

print*, 'singlebendy=',singlebendy
print*, 'couplebendy=',couplebendy
print*, 'MFSbendy=', MFSbendy

!   Update Tabulation of AIME
! EHMAX	= EHMAX_2000*avg_earnings	! avg_earnings is updated every iteration
EHMAX	= 2.0*avg_earnings	! avg_earnings is updated every iteration
ALLOCATE( EH(NGRIDEH) )    ! discretize earning history state-variable
EH = (/ ( EHMAX*((FLOAT(IE-1))/FLOAT(NGRIDEH-1)**1.000), IE=1,NGRIDEH ) /)
print*, ' avg_earnings=', avg_earnings
print*, ' EHMAX=', EHMAX
print*, 'PIA factor=', PIA_factor
print*, ' incsscap=', incsscap*avg_earnings
print*, 'SS(EHMAX)=', SS(NGRIDEH)
print*, 'AIME'
WRITE(*,"(3(F10.5))") EH(:)
PRINT *, 'Pension Income'
WRITE(*,"(3(F10.5))") SS(1),SS(2),SS(3),SS(4),SS(5),SS(6),SS(7),SS(8),SS(9),SS(10)
OPEN(UNIT=27,FILE='SS.txt')
	write(27,*)  SS(1),SS(2),SS(3),SS(4),SS(5),SS(6),SS(7),SS(8),SS(9),SS(10)
CLOSE(27)
PRINT *, 'Unemployment Benefit'
WRITE(*,"(3(F10.5))") UB(7,1,1),UB(7,2,1),UB(7,3,1),UB(7,4,1),UB(7,5,1),UB(7,6,1),UB(7,7,1),UB(7,8,1),UB(7,9,1),UB(7,10,1)

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
    ALLOCATE( singleIDCRA(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2), coupleIDCRA(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH) )
    ALLOCATE( singleIDCRN(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2), coupleIDCRN(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH) )
    ALLOCATE( singleVW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleVW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH), marriageVW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( singleVR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2), coupleVR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH), marriageVR(RETAGE:MAXAGE,NGRIDA,NGRIDEH,2) )
	ALLOCATE( singleIDCRM(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2), coupleIDCRM(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH) )
	ALLOCATE( singleIDCRH(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2), coupleIDCRH(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH) )

    CALL DECRULE01       

call cpu_time (fend)                    
oend = omp_get_wtime()     
write(*,*) 'Time for solving policy functions', oend-ostart    
print*, 'CALL DECRULE01 end'     


print*, 'CALL INVAR01 begin'
!   Find invariant distribution

    !ALLOCATE ( YW(1:RETAGE-1,NGRIDA,NGRIDH,nn), YR(RETAGE:MAXAGE,NGRIDA,NGRIDH) )
	ALLOCATE( singleYW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleYW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
	ALLOCATE( singleYR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2), coupleYR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH) )

    CALL INVAR01

	! print*,'married household share', (sum(coupleYW(:,:,:,:,:))+sum(coupleYR(:,:,:)))/(sum(singleYW(:,:,:,:,:))+sum(singleYR(:,:,:,:))+sum(coupleYW(:,:,:,:,:))+sum(coupleYR(:,:,:)))
print*, 'CALL INVAR01 end'  


print*, 'CALL PROFILE01 begin'    
!   Compute age profiles

!    ALLOCATE ( ALONG(MAXAGE), CLONG(MAXAGE), ILONG(MAXAGE), TILONG(MAXAGE), HLONG(MAXAGE) )
!    ALLOCATE ( MLONG(MAXAGE), NLONG(MAXAGE), LLONG(MAXAGE), SICKLONG(RETAGE-1) )
!    ALLOCATE ( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE), HCROSS(MAXAGE), MCROSS(MAXAGE), NCROSS(MAXAGE), LCROSS(MAXAGE))
!    ALLOCATE ( HLONGNEXT(MAXAGE) )
!    ALLOCATE ( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE), NCROSS(MAXAGE), LCROSS(MAXAGE))
	
	 ALLOCATE( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE),  NCROSS(MAXAGE), LCROSS(MAXAGE), MCROSS(MAXAGE) ,HCROSS(MAXAGE))
	 ALLOCATE( ALONG(MAXAGE), CLONG(MAXAGE), ILONG(MAXAGE), TILONG(MAXAGE), MLONG(MAXAGE), HLONG(MAXAGE))
     ALLOCATE(  NLONG(MAXAGE), LLONG_single(MAXAGE,2), LLONG_couple(MAXAGE,2) )
   
    CALL PROFILE01
print*, 'CALL PROFILE01 end'


print*, 'Aggregation begin'
Agg_labor = 0.0
Avg_hour = 0.0
Agg_asset = 0.0
Agg_beq = 0.0
Avg_H = 0.0
Avg_H_6569 = 0.0
Avg_M = 0.0
working_population = SUM(singleYW(1:RETAGE-1,:,:,:,:))+2*SUM(coupleYW(1:RETAGE-1,:,:,:,:))
whole_population = working_population + SUM(singleYR(RETAGE:MAXAGE,:,:,:,:))+2*SUM(coupleYR(RETAGE:MAXAGE,:,:,:))
unemployed_population = SUM(singleYW(1:RETAGE-1,:,7:8,:,:))+SUM(coupleYW(1:RETAGE-1,:,7:8,1:6,:))+SUM(coupleYW(1:RETAGE-1,:,1:6,7:8,:))+2*SUM(coupleYW(1:RETAGE-1,:,7:8,7:8,:))
unemployment_rate = unemployed_population/working_population
print*,'working_population',working_population
print*,'whole_population',whole_population
print*,'unemployment rate',unemployment_rate

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
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH
				DO IG=1,2

				JM = singleIDCRM(AGE,IA,IH,IE,IG) 

				Agg_asset = Agg_asset + A(IA)*singleYR(AGE,IA,IH,IE,IG)
				Agg_beq = Agg_beq + A(IA)*singleYR(AGE,IA,IH,IE,IG)*(1.0-SUR(AGE,IG,IH))
				Avg_H = Avg_H + H(IH)*singleYR(AGE,IA,IH,IE,IG)	
				IF (AGE< MAXAGE-2) THEN 			
					Avg_M = Avg_M + M(JM)*singleYR(AGE,IA,IH,IE,IG)
				END IF 
				IF (AGE == RETAGE) THEN 
					Avg_H_6569 = Avg_H_6569 + H(IH)*singleYR(AGE,IA,IH,IE,IG)
				END IF 

				END DO 
			END DO
		END DO 
    END DO
END DO

!  Couple Retirees    
DO AGE=RETAGE,MAXAGE                      
    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH

			JM = coupleIDCRM(AGE,IA,IH,IE)

			Agg_asset = Agg_asset + A(IA)*coupleYR(AGE,IA,IH,IE)
			Agg_beq = Agg_beq + A(IA)*coupleYR(AGE,IA,IH,IE)*(1.0-SUR(AGE,1,IH))*(1.0-SUR(AGE,2,IH))
			Avg_H = Avg_H + H(IH)*coupleYR(AGE,IA,IH,IE)
			IF (AGE< MAXAGE-2) THEN 			
				Avg_M = Avg_M + M(JM)*coupleYR(AGE,IA,IH,IE)
			END IF 
			IF (AGE == RETAGE) THEN 
				Avg_H_6569 = Avg_H_6569 + H(IH)*coupleYR(AGE,IA,IH,IE)
			END IF 

			END DO
		END DO
    END DO
END DO

Avg_H = Avg_H/(SUM(coupleYR)+SUM(singleYR))
Avg_H_6569 = Avg_H_6569/(SUM(coupleYR(RETAGE,:,:,:))+SUM(singleYR(RETAGE,:,:,:,:)))
Avg_M = Avg_M/(SUM(coupleYR(RETAGE:MAXAGE-2,:,:,:))+SUM(singleYR(RETAGE:MAXAGE-2,:,:,:,:)))

PRINT*, 'K=', Agg_asset
PRINT*, 'L=', Agg_labor
PRINT*, 'Hour=', Avg_hour
PRINT*, 'AGG_BEQ=', Agg_beq
PRINT*, 'Avg_H=', Avg_H
PRINT*, 'Avg_H_6569=', Avg_H_6569
PRINT*, 'Avg_M=', Avg_M

print*, 'Aggregation end'	


!	Output
	! K = AEND/(1.0+AGROWTH)      ! Detrend
	! L = LEND
	OUTPUT = TFP*(Agg_asset**ALPHA)*(Agg_labor**(1-ALPHA))
	! MPL = (1-ALPHA)*TFP*(K/L)**ALPHA
	! MPK = (ALPHA)*TFP*(K/L)**(ALPHA-1)


!	Update SS expenditure

SSEXP=0.0 	
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH
				
				SSEXP = SSEXP + SS(IE)*(singleYR(AGE,IA,IH,IE,1)+singleYR(AGE,IA,IH,IE,2)+2*coupleYR(AGE,IA,IH,IE))
				! SSEXP = SSEXP + (SS(IE)/PIA_factor)*(singleYR(AGE,IA,IE,1)+singleYR(AGE,IA,IE,2)+2*coupleYR(AGE,IA,IE))

			END DO 
		END DO
	END DO 
END DO 

!	Update medical insurance expenditure
med_insur_exp=0.0 	
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH
		
				med_insur_exp = med_insur_exp + SUBEHI(AGE)*( M(singleIDCRM(AGE,IA,IH,IE,1))*singleYR(AGE,IA,IH,IE,1) + M(singleIDCRM(AGE,IA,IH,IE,2))*singleYR(AGE,IA,IH,IE,2)) &
								    + SUBEHI(AGE)*( M(coupleIDCRM(AGE,IA,IH,IE))*2*coupleYR(AGE,IA,IH,IE) )
				
			END DO 
		END DO
	END DO 
END DO 

! PREMIUM1 = med_insur_exp/whole_population
PRINT *, 'EHI Income ratio) =',       med_insur_exp/sum(TILONG(:))
PRINT *, 'med_insur_exp =', med_insur_exp
! PRINT *, 'updated PREMIUM1 =', PREMIUM1

!	Update unemployment benefit expenditure
UB1=0.0 	
!single
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS=7,8
			DO IE=1,NGRIDEH
				DO IG=1,2
		
				 UB1 = UB1 + UB(IS,IE,1)*singleYW(AGE,IA,IS,IE,IG) 
								    
				END DO 
			END DO 
		END DO
	END DO 
END DO 
!couple
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
        DO IS1=1,nn
			DO IS2=1,nn
				DO IE=1,NGRIDEH

				 UB1 = UB1 + (UB(IS1,IE,2)+UB(IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE) 

				END DO 
            END DO
        END DO 
    END DO
END DO



!	Update govern flat transfer
	gov_trans = flat_transf_rate*OUTPUT/whole_population

! Update total sum of expenditure and transfers of 17% of GDP
	! gov_exp = 0.17*OUTPUT

!  Update medicare (only for elderly)
	medicare = medicare_rate*OUTPUT/(whole_population-working_population)
	! medicare = medicare_rate*OUTPUT/SUM(D_YR(RETAGE:MAXAGE,:,:,:))
	print*,'medicare_rate*OUTPUT=', medicare_rate*OUTPUT
	print*,'CUM2', whole_population-working_population
	print*,'medicare subsidy per person=', medicare 


! Compute income bend point for top marginal tax rate given lambda:
!	bendy=((1.0-tau_l)*lambda/(1.0-ty_max))**(1.0/tau_l)

gbcdenom = 0.0
gbcnum = 0.0
cor_tax_rev = 0.0
sales_tax_rev = 0.0
income_tax_rev = 0.0
insurance_premium = 0.0
tax_subsidy = 0.0
agg_c = 0.0
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

			INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1)
			TINCOME = min(R*A(IA),d_c) + INCOME
			PREMIUM = premium_rate*INCOME
			taxable_income = TINCOME	
			! taxable_income = TINCOME  - PREMIUM	

			yd = taxable_income*lambda*(MIN(singlebendy, taxable_income/avg_earnings))**(-tau_l_single) &
				+avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy) &
				+(1-tau_c)*max(R*A(IA)-d_c,0.0)

! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
			IF(GBC_method==0) THEN 			!cleared by lambda			
				temp = taxable_income*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single)
			ELSE 	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate ; GBC_method==3: cleared by lump sum tax
				temp = taxable_income*lambda*(MIN(singlebendy, taxable_income/avg_earnings))**(-tau_l_single)
			END IF 
				gbcdenom = gbcdenom + temp*singleYW(AGE,IA,IS,IE,IG)	! *MU(AGE)
			

! gbcnum = other tax revenue + Taxable income - top aftertax income
			temp2 = taxable_income - avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy) 					
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			temp_cons = ( (taxable_income*lambda*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) &
						+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy)) &
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
			income_tax_rev = income_tax_rev + (temp2-temp)*singleYW(AGE,IA,IS,IE,IG)

! negative tax (subsidy) treated as gov exp
			! tax_subsidy = tax_subsidy + ABS( MIN(TINCOME - yd, 0.0) )*singleYW(AGE,IA,IS,IE,IG)

! share of tax revenue from single
			! tax_revenue_single = tax_revenue_single + (TINCOME-yd)*singleYW(AGE,IA,IS,IE,IG)
		IF(GBC_method==0) THEN 	
			tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYW(AGE,IA,IS,IE,IG) - lambda*temp*singleYW(AGE,IA,IS,IE,IG)
		ELSE	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate ; GBC_method==3: cleared by lump sum tax
			tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYW(AGE,IA,IS,IE,IG) - temp*singleYW(AGE,IA,IS,IE,IG)
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

			INCOME1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + UB(IS1,IE,2)
			INCOME2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + UB(IS2,IE,2)
			INCOME = INCOME1 + INCOME2
			TINCOME1 = INCOME1 + min(R*A(IA),d_c)/2
			TINCOME2 = INCOME2 + min(R*A(IA),d_c)/2
			TINCOME = TINCOME1 + TINCOME2
			PREMIUM = premium_rate*INCOME	
			PREMIUM1 = premium_rate*INCOME1	
			PREMIUM2 = premium_rate*INCOME2
			taxable_income = TINCOME 
			taxable_income1 = TINCOME1 
			taxable_income2 = TINCOME2 	
			! taxable_income = TINCOME - PREMIUM
			! taxable_income1 = TINCOME1 - PREMIUM1
			! taxable_income2 = TINCOME2 - PREMIUM2
			
! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
		IF (yd_MFJ(taxable_income,IA) > yd_MFS(taxable_income1,IA)+yd_MFS(taxable_income2,IA) ) THEN 
			IF(GBC_method==0) THEN  		!cleared by lambda	
				temp = taxable_income*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple)
			ELSE 	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate ; GBC_method==3: cleared by lump sum tax
				temp = taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple)						
			END IF

		ELSE 
			
			IF(GBC_method==0) THEN 
				! temp = weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1))*( MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) )/avg_earnings ))**(-tau_l_single) &
				! 		+ (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/avg_earnings ))**(-tau_l_single) )

				temp = taxable_income1*delta_lambda*( MIN(MFSbendy,taxable_income1/avg_earnings))**(-tau_l_couple) + taxable_income2*delta_lambda*( MIN(MFSbendy,taxable_income2/avg_earnings))**(-tau_l_couple)
			ELSE
				! temp = lambda*weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1))/avg_earnings ))**(-tau_l_single) &
				! 	  + (max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2))/avg_earnings ))**(-tau_l_single) )
				temp = taxable_income1*lambda_couple*( MIN(MFSbendy,taxable_income1/avg_earnings))**(-tau_l_couple) + taxable_income2*lambda_couple*( MIN(MFSbendy,taxable_income2/avg_earnings))**(-tau_l_couple)
			END IF  

		END IF 	
			gbcdenom = gbcdenom + temp*coupleYW(AGE,IA,IS1,IS2,IE)	! *MU(AGE)
		
! gbcnum = other tax revenue + Taxable income - top aftertax income
		IF (yd_MFJ(taxable_income,IA) > yd_MFS(taxable_income1,IA)+yd_MFS(taxable_income2,IA) ) THEN 
			temp2 = taxable_income - avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - couplebendy) 
										
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			temp_cons = ( (taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
						+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - couplebendy)) &
						+ (1-tau_c)*max(R*A(IA)-d_c,0.0) &
						+  2*BEQ1 + A(IA) + 2*gov_trans - A(JA) - PREMIUM)/(1.0+tau_s)
			temp_staxrev = tau_s*temp_cons
		ELSE
			 
			temp2 = taxable_income - avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - MFSbendy)  
					
					
			temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

			temp_cons = ( yd_MFS(taxable_income1,IA)+yd_MFS(taxable_income2,IA) &
						+  2*BEQ1 + A(IA) + 2*gov_trans - A(JA) - PREMIUM )/(1.0+tau_s) 
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
			income_tax_rev = income_tax_rev + (temp2-temp)*coupleYW(AGE,IA,IS1,IS2,IE)

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
			ELSE
				tax_revenue_couple = tax_revenue_couple + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYW(AGE,IA,IS1,IS2,IE) - temp*coupleYW(AGE,IA,IS1,IS2,IE)
			END IF  

				END DO
			END DO
        END DO 
    END DO
END DO

! Single retiree
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IH = 1,NGRIDH
			DO IE = 1,NGRIDEH
				DO IG=1,2

				JA = singleIDCRA(AGE,IA,IH,IE,IG)	
				JM = singleIDCRM(AGE,IA,IH,IE,IG)

				INCOME = SS(IE)
				TINCOME = min(R*A(IA),d_c) + INCOME
				PREMIUM = premium_rate*INCOME
				taxable_income = TINCOME
				! taxable_income = TINCOME - PREMIUM

				yd = taxable_income*lambda*(MIN(singlebendy, taxable_income/avg_earnings))**(-tau_l_single) &
					+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy) &
					+ (1-tau_c)*max(R*A(IA)-d_c,0.0)	

	! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
			IF (GBC_method==0)	THEN 		!cleared by lambda	
				temp = taxable_income*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) 
			ELSE 	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate ; GBC_method==3: cleared by lump sum tax
				temp = taxable_income*lambda*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) 
			END IF 
				gbcdenom = gbcdenom + temp*singleYR(AGE,IA,IH,IE,IG)	!*MU(AGE)
				

	! gbcnum = Taxable income + other taxes - top aftertax income
				temp2 = taxable_income - avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy) 
						
				temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

				temp_cons = ( (taxable_income*lambda*(MIN(singlebendy, taxable_income/avg_earnings ))**(-tau_l_single) &
							+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy)) &
							+ (1-tau_c)*max(R*A(IA)-d_c,0.0) &
							+ A(IA) + medicare + gov_trans - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM )/(1.0+tau_s) 
				temp_staxrev = tau_s*temp_cons

				!T + taxable income - top aftertax income
				IF(GBC_method==2) THEN	
					gbcnum = gbcnum + (temp2 + temp_ctaxrev + PREMIUM)*singleYR(AGE,IA,IH,IE,IG)	!*MU(AGE)
				ELSEIF (GBC_method==4) THEN 
					gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*singleYR(AGE,IA,IH,IE,IG)
				ELSE
					gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYR(AGE,IA,IH,IE,IG)	!*MU(AGE)
				END IF 

	!	cor_tax_rev = cor_tax_rev+temp_ctaxrev*YR(AGE,IA,IR)*MU(AGE)
				sales_tax_rev = sales_tax_rev + temp_staxrev*singleYR(AGE,IA,IH,IE,IG)	!*MU(AGE)
				agg_c = agg_c + temp_cons*singleYR(AGE,IA,IH,IE,IG)
				agg_y = agg_y + INCOME*singleYR(AGE,IA,IH,IE,IG)
				insurance_premium = insurance_premium + PREMIUM*singleYR(AGE,IA,IH,IE,IG)
				income_tax_rev = income_tax_rev + (temp2-temp)*singleYR(AGE,IA,IH,IE,IG)
	! negative tax (subsidy) treated as gov exp
				! tax_subsidy = tax_subsidy + ABS( MIN(TINCOME - yd, 0.0) )*singleYR(AGE,IA,IE,IG)

	! share of tax revenue from single
				! tax_revenue_single = tax_revenue_single + (TINCOME-yd)*singleYR(AGE,IA,IE,IG)
			IF(GBC_method==0) THEN 	
				tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYR(AGE,IA,IH,IE,IG) - lambda*temp*singleYR(AGE,IA,IH,IE,IG)
			ELSE
				tax_revenue_single = tax_revenue_single + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*singleYR(AGE,IA,IH,IE,IG) - temp*singleYR(AGE,IA,IH,IE,IG)
			END IF

				END DO 	
			END DO
		END DO
	END DO
END DO


! Couple retiree
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IH = 1,NGRIDH
			DO IE = 1,NGRIDEH
				
				JA = coupleIDCRA(AGE,IA,IH,IE)	
				JM = coupleIDCRM(AGE,IA,IH,IE)

				INCOME1 = SS(IE) 
				INCOME2 = SS(IE)
				INCOME = INCOME1 + INCOME2
				TINCOME1 = INCOME1 + min(R*A(IA),d_c)/2
				TINCOME2 = INCOME2 + min(R*A(IA),d_c)/2	
				TINCOME = TINCOME1 + TINCOME2			
				PREMIUM = premium_rate*INCOME
				PREMIUM1 = premium_rate*INCOME1
				PREMIUM2 = premium_rate*INCOME2
				taxable_income = TINCOME
				taxable_income1 = TINCOME1
				taxable_income2 = TINCOME2
				! taxable_income = TINCOME- PREMIUM
				! taxable_income1 = TINCOME1- PREMIUM1
				! taxable_income2 = TINCOME2- PREMIUM2

	! GBC_method==0: gbcdenom = \int y*(y/AE)^{-tau} ; GBC_method==1: gbcdenom = \int y*(y/AE)^{-tau}
			IF (yd_MFJ(taxable_income,IA) > yd_MFS(taxable_income1 ,IA)+yd_MFS(taxable_income2,IA) ) THEN 
				IF (GBC_method==0)	THEN 							!cleared by lambda	
					temp = taxable_income*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) 
				ELSE 	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
					temp = taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) 
				END IF 
			ELSE 
				

				IF (GBC_method==0)	THEN
					! temp = weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings))**(-tau_l_single) &
					!  	   + (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings ))**(-tau_l_single) )
					temp = taxable_income1*delta_lambda*( MIN(MFSbendy,taxable_income1/avg_earnings))**(-tau_l_couple) + taxable_income2*delta_lambda*( MIN(MFSbendy,taxable_income2/avg_earnings))**(-tau_l_couple)
				ELSE
					! temp = lambda*weight_MFS*( (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings ))**(-tau_l_single) &
					! 	   + (max(0.0,min(R*A(IA),d_c)/2)+SS(IE))*(MIN(MFSbendy,(max(0.0,min(R*A(IA),d_c)/2)+SS(IE))/avg_earnings ))**(-tau_l_single) )
					temp = taxable_income1*lambda_couple*( MIN(MFSbendy,taxable_income1/avg_earnings))**(-tau_l_couple) + taxable_income2*lambda_couple*( MIN(MFSbendy,taxable_income2/avg_earnings))**(-tau_l_couple)
				END IF 
			END IF 
				gbcdenom = gbcdenom + temp*coupleYR(AGE,IA,IH,IE)	!*MU(AGE)
				


	! gbcnum = Taxable income + other taxes - top aftertax income
			IF (yd_MFJ(taxable_income, IA) > yd_MFS(taxable_income1 ,IA)+yd_MFS(taxable_income2 ,IA) ) THEN 
				temp2 = taxable_income - avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - couplebendy) 
						  					
				temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

				temp_cons = ( (taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
							+ avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - couplebendy)) &
							+ (1-tau_c)*max(R*A(IA)-d_c,0.0) &
							+ A(IA) + 2*medicare + 2*gov_trans - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM)/(1.0+tau_s) 
				temp_staxrev = tau_s*temp_cons
			ELSE 
				
				temp2 = taxable_income - avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - couplebendy) 					
						
				temp_ctaxrev = tau_c*max(R*A(IA)-d_c,0.0)

				temp_cons = ( yd_MFS(taxable_income1,IA)+yd_MFS(taxable_income2,IA) &
							+ A(IA) + 2*medicare + 2*gov_trans - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM )/(1.0+tau_s) 
				temp_staxrev = tau_s*temp_cons
			END IF  

			!T + taxable income - top aftertax income
			IF(GBC_method==2) THEN
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + PREMIUM)*coupleYR(AGE,IA,IH,IE)	!*MU(AGE)
			ELSEIF (GBC_method==4) THEN 
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*coupleYR(AGE,IA,IH,IE)
			ELSE
				gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYR(AGE,IA,IH,IE)	!*MU(AGE)
			END IF 

	!	cor_tax_rev = cor_tax_rev+temp_ctaxrev*YR(AGE,IA,IR)*MU(AGE)
				sales_tax_rev = sales_tax_rev + temp_staxrev*coupleYR(AGE,IA,IH,IE)	!*MU(AGE)
				agg_c = agg_c + temp_cons*coupleYR(AGE,IA,IH,IE)
				agg_y = agg_y + INCOME*coupleYR(AGE,IA,IH,IE)
				insurance_premium = insurance_premium + PREMIUM*coupleYR(AGE,IA,IH,IE)
				income_tax_rev = income_tax_rev + (temp2-temp)*coupleYR(AGE,IA,IH,IE)

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
					tax_revenue_couple = tax_revenue_couple + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYR(AGE,IA,IH,IE) - lambda*temp*coupleYR(AGE,IA,IH,IE)
				ELSE
					tax_revenue_couple = tax_revenue_couple + (temp2 + temp_ctaxrev + temp_staxrev + PREMIUM)*coupleYR(AGE,IA,IH,IE) - temp*coupleYR(AGE,IA,IH,IE)
				END IF  

			END DO
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
		lambda_implied = (gbcnum-SSEXP-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT-med_insur_exp-UB1)/gbcdenom
	ELSEIF (GBC_method==1) THEN
		! gov_exp = (gbcnum-PIA_factor*SSEXP-flat_transf_rate*OUTPUT-tax_subsidy-gbcdenom)/OUTPUT
		gov_exp = (gbcnum-SSEXP-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT-med_insur_exp-UB1-gbcdenom)/OUTPUT
	ELSEIF (GBC_method==2) THEN
		! tau_s_implied = (PIA_factor*SSEXP+flat_transf_rate*OUTPUT+tax_subsidy+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c	
		tau_s_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c		
	ELSEIF (GBC_method==3) THEN
		lumpsum_taxrev_implied = SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1+gov_exp*OUTPUT+gbcdenom-gbcnum
	ELSEIF (GBC_method==4) THEN
		premium_rate_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_y	
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
		lambda_implied = (gbcnum-SSEXP-gov_exp*OUTPUT-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT-med_insur_exp-UB1)/gbcdenom
	ELSEIF (GBC_method==1) THEN
		! gov_exp = (gbcnum-PIA_factor*SSEXP-flat_transf_rate*OUTPUT-tax_subsidy-gbcdenom)/OUTPUT
		gov_exp = (gbcnum-SSEXP-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT-med_insur_exp-UB1-gbcdenom)/OUTPUT
	ELSEIF (GBC_method==2) THEN		!tau_s clear GBC
		! tau_s_implied = (PIA_factor*SSEXP+flat_transf_rate*OUTPUT+tax_subsidy+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c
		tau_s_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_c
	ELSEIF (GBC_method==3) THEN
		lumpsum_taxrev_implied = SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1+gov_exp*OUTPUT+gbcdenom-gbcnum
	ELSEIF (GBC_method==4) THEN
		premium_rate_implied = (SSEXP+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1+gov_exp*OUTPUT+gbcdenom-gbcnum)/agg_y	
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

print*, '================Summary of GBC Revenue ================'
print*, 'Total tax revenue=',gbcnum-gbcdenom+lumpsum_taxrev_implied
print*, 'Labor income tax revenue=',income_tax_rev
print*, 'Sales tax revenue=', sales_tax_rev
print*, 'EHI premium revenue=', insurance_premium
print*, 'lump sum tax revenue=', lumpsum_taxrev_implied
print*, '================Summary of GBC Expenditure ================'
print*, 'total expenditure=', SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1
print*, 'SS exp',SSEXP
print*, 'gov exp',gov_exp*OUTPUT
print*, 'transf exp',flat_transf_rate*OUTPUT
PRINT*, 'EHI exp =',med_insur_exp
print*, 'UB exp =',UB1
print*, '================GBC Expenditure ratio ================'
print*, 'SS exp/GDP=',SSEXP/OUTPUT
print*, 'gov exp/GDP',gov_exp
print*, 'transf exp/GDP=',flat_transf_rate
PRINT *, 'EHI/GDP) =',med_insur_exp/OUTPUT
! print*, 'medicare=', medicare_rate*OUTPUT
print*, 'UB exp/GDP=',UB1/OUTPUT
print*, 'lump sum/GDP=',lumpsum_taxrev_implied/OUTPUT
print*, '====================================================='
! print*, 'after tax income=',gbcdenom
! print*, 'tax_subsidy=',tax_subsidy
! print*, 'tax_revenue_single=',tax_revenue_single
! print*, 'tax_revenue_couple=',tax_revenue_couple
! print*, 'total expenditure=', PIA_factor*SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+tax_subsidy
! print*, 'total expenditure=', SSEXP+gov_exp*OUTPUT+flat_transf_rate*OUTPUT+medicare_rate*OUTPUT+med_insur_exp+UB1
! print*, 'total tax revenue=', tax_revenue_single+tax_revenue_couple

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
IF (beq_activation==1) THEN 
	BEQ1 = Agg_beq/working_population
ELSEIF (beq_activation==0) THEN 
	BEQ1 = 0.0
END IF 
! Average earnings (to update EHMAX)
avg_earnings = 0.0
!working_population = SUM(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)))
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

				END DO 
            END DO
        END DO 
    END DO
END DO
! Single retired
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA       
		DO IH = 1,NGRIDH 
			DO IE = 1,NGRIDEH	
				DO IG=1,2 

					INCOME = SS(IE)
					TINCOME = R*A(IA) + INCOME
					avg_earnings = avg_earnings + TINCOME*singleYR(AGE,IA,IH,IE,IG)

				END DO             
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

				END DO 
            END DO
        END DO 
    END DO
END DO
! couple retiree    
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA 
		DO IH = 1,NGRIDH     
			DO IE = 1,NGRIDEH

				INCOME = 2*SS(IE)
				TINCOME = R*A(IA) + INCOME
				avg_earnings = avg_earnings + TINCOME*coupleYR(AGE,IA,IH,IE)

			END DO 
		END DO
    END DO
END DO  

avg_earnings = avg_earnings/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+2.0*SUM(coupleYW(1:RETAGE-1,:,:,:,:))+ SUM(singleYR(RETAGE:MAXAGE,:,:,:,:))+2.0*SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))

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
IF (beq_activation==1) THEN 
    BEQDEV  = ABS(BEQ-BEQ1)        / BEQ
ELSEIF (beq_activation==0) THEN 
	BEQDEV  = 0.0
END IF 

	!SSDEV   = ABS(SS-SS1)          / SS
	!STAXDEV = ABS(STAX-STAX1)      / STAX
	!MTAXDEV = ABS(MTAX-MTAX1)      / MTAX
	! EHIDEV  = ABS(PREMIUM-PREMIUM1)/ PREMIUM
!	dlam = abs(lambda-lambda_implied) / lambda
!	dPIA = abs(PIA_factor_implied - PIA_factor)
	IF (GBC_method==0) THEN	
		dlam = abs(lambda_implied - lambda) 
	! ELSEIF (GBC_method==1) THEN
		! dPIA = abs(PIA_factor_implied - PIA_factor)
	ELSEIF (GBC_method==2) THEN
		dtau_s = abs(tau_s_implied - tau_s)
	ELSEIF (GBC_method==3) THEN
		dlumpsum = abs(lumpsum_taxrev_implied - lumpsum_taxrev)
	ELSEIF (GBC_method==4) THEN
		dpremium_rate = abs(premium_rate_implied - premium_rate)
	END IF 


	PRINT*,''
    WRITE(10,*) 'Iteration', ITER
    PRINT *, 'Iteration', ITER, '(lambda),', LOOPNUMBER, '(r)'	
    PRINT*,'-------------------Tax parameters---------------------'
	print*,'tau_s_implied =',tau_s_implied
	print*,'tau_s =',tau_s
	print*,'lumpsum_taxrev_implied =',lumpsum_taxrev_implied
	print*,'lumpsum_taxrev =',lumpsum_taxrev
	print*,'tau_l_single =',tau_l_single
	print*,'tau_l_couple =',tau_l_couple 
	print*, 'lambda_single=',lambda 
	print*, 'lambda_couple=',lambda_couple
	print*, 'gov implied=',gov_exp
	PRINT*,'----------------------GE outcomes----------------------'
	! print*, 'implied G/GDP=', gov_exp
	! print*, 'SS exp/GDP=',PIA_factor*SSEXP/OUTPUT
	! print*, 'SS exp/GDP=',SSEXP/OUTPUT
	PRINT *, 'Output =', OUTPUT		
	PRINT *, 'K =', Agg_asset
	PRINT *, 'L =', Agg_labor	
	PRINT *, 'WAGE =', WAGE	
	PRINT *, 'annual return =', (1+R)**(0.2)-1	
	PRINT*,'-----------------------------------------------------'
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
	! ELSEIF (GBC_method==1) THEN 
	!  	PRINT *, ''   
	! 	PRINT*, 'PIA old=', PIA_factor
	!  	PRINT*, 'PIA_factor_implied=', PIA_factor_implied
	!  	PRINT *, 'Relative change in PIA factor =', dPIA
	ELSEIF (GBC_method==2) THEN 
		PRINT *, ''
     	! PRINT *, '  [tau_s1  tau_s2] ', '  tau_s_old'
    	! WRITE(*,"(3(F10.5))") tau_s1, tau_s2, tau_s
		PRINT*, 'tau_s=', tau_s
		PRINT*, 'tau_s_implied=', tau_s_implied
		PRINT *, 'Relative change in tau_s =', dtau_s
	ELSEIF (GBC_method==3) THEN 
		PRINT *, 'lumpsum_taxrev =', lumpsum_taxrev
		PRINT*, 'lumpsum_taxrev_implied=', lumpsum_taxrev_implied
		PRINT *, 'Relative change in lumpsum tax =', dlumpsum
	ELSEIF (GBC_method==4) THEN
		PRINT *, 'premium_rate =', premium_rate
		PRINT*, 'premium_rate_implied=', premium_rate_implied
		PRINT *, 'Relative change in premium rate =', dpremium_rate
	END IF
    
	 PRINT *, ''
     PRINT *, '  [bend1  bend2] ', '  avg_earnings'
     WRITE(*,"(3(F10.5))") bend1, bend2, avg_earnings
	 PRINT *, ''
    
    PRINT*,'----------------------------------------' 
    WRITE(10,*)


	IF (GBC_method==0) THEN 		
		dtau_s = 0.0
		dlumpsum = 0.0
		dpremium_rate = 0.0
	ELSEIF (GBC_method==1) THEN 
		dlam = 0.0
		dtau_s = 0.0
		dlumpsum = 0.0
		dpremium_rate = 0.0
	ELSEIF (GBC_method==2) THEN		
		dlam = 0.0
		dlumpsum = 0.0
		dpremium_rate = 0.0
	ELSEIF (GBC_method==3) THEN		
		dlam = 0.0
		dtau_s = 0.0
		dpremium_rate = 0.0
	ELSEIF (GBC_method==4) THEN	
		dlam = 0.0
		dtau_s = 0.0
		dlumpsum = 0.0	
	END IF 
	
	print*,'BEQDEV', BEQDEV
	print*,'dlam', dlam
	! print*,'dPIA', dPIA
	print*,'dtau_s', dtau_s
	print*,'dlumpsum', dlumpsum
	print*, 'dpremium_rate', dpremium_rate


	! print*,'BEQDEV-TOLB', BEQDEV-TOLB
	! print*,'dlam-tol_lam', dlam-tol_lam
	! print*,'dPIA-tol_PIA', dPIA-tol_PIA
	! print*,'dtau_s-tol_tau_s', dtau_s-tol_tau_s 

	! IF ( (BEQDEV>TOLB) .OR. (dlam>tol_lam) .OR. (dPIA>tol_PIA) .OR. (dtau_s>tol_tau_s) ) THEN
	IF ( (BEQDEV>TOLB) .OR. (dlam>tol_lam) .OR. (dtau_s>tol_tau_s) .OR. (dlumpsum>tol_lumpsum) .OR. (dpremium_rate>tol_premium) ) THEN
        BEQ     = (1 - GRADB)*BEQ       + GRADB*BEQ1
	    !SS      = (1 - GRADSS)*SS       + GRADSS*SS1
		! PREMIUM = (1 - GRADEHI)*PREMIUM + GRADEHI*PREMIUM1
		


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
ELSEIF (GBC_method==3) THEN
	lumpsum_taxrev = (1 - GRADTAULUMPSUM)*lumpsum_taxrev + GRADTAULUMPSUM*lumpsum_taxrev_implied
	lumpsum = lumpsum_taxrev/whole_population
ELSEIF (GBC_method==4) THEN
	premium_rate = (1 - GRADPREMIUM)*premium_rate + GRADPREMIUM*premium_rate_implied
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
        DEALLOCATE(singleIDCRM, coupleIDCRM, singleIDCRH, coupleIDCRH)
		!DEALLOCATE(S, CUMS, MU, Y_AGE, CUMSWK,MUWK)
		DEALLOCATE(ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, MLONG, MCROSS, HLONG, HCROSS, LLONG_single, LLONG_couple)
		DEALLOCATE(EH)
        GO TO 200
    END IF
799 continue
    
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
print*, 'ALPHA=',ALPHA
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
! print*, 'lambda_MFS=', lambda*weight_MFS
print*, 'lambda_MFJ=', lambda_couple
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
			! r1 = Avg_R_weighted-0.005
			! r2 = Avg_R_weighted+0.005
			R1 = R_ANNUAL-0.03
			R2 = R_ANNUAL+0.03
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
DEALLOCATE(singleIDCRM, coupleIDCRM, singleIDCRH, coupleIDCRH)
!DEALLOCATE(S, CUMS, MU, Y_AGE, CUMSWK,MUWK)
DEALLOCATE(ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, MLONG, MCROSS, HLONG, HCROSS, LLONG_single, LLONG_couple)
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
IF ((source_welfare_analysis_activation == 0) .AND. (optimal_tax_activation == 0 )) THEN 
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
		write(27,*) singleIDCRA(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCRA.txt')
		write(27,*) coupleIDCRA(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCRN.txt')
		write(27,*) singleIDCRN(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCRN.txt')
		write(27,*) coupleIDCRN(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCWC.txt')
		write(27,*) singleIDCWC(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleIDCRC.txt')
		write(27,*) singleIDCRC(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCWC.txt')
		write(27,*) coupleIDCWC(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleIDCRC.txt')
		write(27,*) coupleIDCRC(:,:,:,:)
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
		write(27,*) singleVR(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleVR.txt')
		write(27,*) coupleVR(:,:,:,:)
	CLOSE(27)

	! OPEN(UNIT=27,FILE='marriageVR.txt')
	! 	write(27,*) marriageVR(:,:,:,:)
	! CLOSE(27)

	OPEN(UNIT=27,FILE='singleYW.txt')
		write(27,*) singleYW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleYW.txt')
		write(27,*) coupleYW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='singleYR.txt')
		write(27,*) singleYR(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='coupleYR.txt')
		write(27,*) coupleYR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='Agrid.txt')
		write(27,*) A
	CLOSE(27)

	OPEN(UNIT=27,FILE='Ngrid.txt')
		write(27,*) N
	CLOSE(27)
END IF

! IF (CV==0) THEN 
! 	OPEN(UNIT=27,FILE='bench_single_VW.txt')
! 		! write(27,*) singleVW(:,:,:,:,:)
! 		write(27,*) bench_single_VW(:,:,:,:,:)
! 	CLOSE(27)

! 	OPEN(UNIT=27,FILE='bench_single_VR.txt')
! 		! write(27,*) singleVR(:,:,:,:,:)
! 		write(27,*) bench_single_VR(:,:,:,:,:)
! 	CLOSE(27)

! 	OPEN(UNIT=27,FILE='bench_couple_VW.txt')
! 		! write(27,*) coupleVW(:,:,:,:,:)
! 		write(27,*) bench_couple_VW(:,:,:,:,:,:)
! 	CLOSE(27)

! 	OPEN(UNIT=27,FILE='bench_couple_VR.txt')
! 		! write(27,*) coupleVR(:,:,:,:)
! 		write(27,*) bench_couple_VR(:,:,:,:,:)
! 	CLOSE(27)
! END IF


print*, ' ================General equilibrium is solved================'	
!*************************************
!
!  Calculate the Consumption holding
!
!************************************* 

	  CALL consumptionshare

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

IF ((source_welfare==0)) THEN
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

IF (CV==0) THEN 
	OPEN(UNIT=27,FILE='bench_single_VW.txt')
		! write(27,*) singleVW(:,:,:,:,:)
		write(27,*) bench_single_VW(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_single_VR.txt')
		! write(27,*) singleVR(:,:,:,:,:)
		write(27,*) bench_single_VR(:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_VW.txt')
		! write(27,*) coupleVW(:,:,:,:,:)
		write(27,*) bench_couple_VW(:,:,:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='bench_couple_VR.txt')
		! write(27,*) coupleVR(:,:,:,:)
		write(27,*) bench_couple_VR(:,:,:,:,:)
	CLOSE(27)
END IF

IF (CV==1) THEN
	CALL compensating_variation
END IF 

print*, 'CALL compensating_variation ends'

	CALL couple_filing_tax

! Computing the pass through of income shock to consumption

!*************************************
	print*,'CALL insurance_working'
	CALL insurance_working
	print*,'CALL insurance_retiree'
	CALL insurance_retiree

!*************************************
!
!*************************************
!  Check whether kmax binding

    CALL check_kmaxbinding
print*, 'finished checking kmaxbinding'
!
!*************************************

	! print*, 'Saving "opt_tax_record.txt" '	
		! write(54,"(220(F16.8,1X))") util_welfare_id,veil_welfare_id, par_welfare,tau_l_single,tau_l_couple,lambda,lambda_couple,lambda*weight_MFS,tax_revenue_single,tax_revenue_couple,gov_exp*OUTPUT,(1.0+R)**0.2-1.0,popu_MFS,tau_s,insurance_value,insurance_value_single,insurance_value_couple, &
		! 							cost_unc_singlemale,cost_unc_singlefemale,cost_unc_couple(1),cost_unc_couple(2),cost_ineq_singlemale,cost_ineq_singlefemale,cost_ineq_couple(1),cost_ineq_couple(2), &
		! 							agg_certeqcons_singlemale,agg_certeqlab_singlemale,agg_certeqcons_singlefemale,agg_certeqlab_singlefemale,agg_certeqcons_couple(1),agg_certeqcons_couple(2),agg_certeqlab_couple(1),agg_certeqlab_couple(2), &
		! 							AggC_singlemale,AggC_singlefemale,AggL_singlemale,AggL_singlefemale,AggC_couple,AggC_couple,AggL_couple(1),AggL_couple(2),AggC_singlemale_leicomp,AggC_singlefemale_leicomp,AggC_couple_leicomp(1),AggC_couple_leicomp(2),Agg_asset,OUTPUT,wage,hour_single_male,hour_single_female,hour_married_male,hour_married_female,LFP_single_female,LFP_married_female,marryprop,earn_corr,sigma_lab_male,sigma_lab_female
		
		! write(54,"(220(F16.8,1X))") util_welfare_id,veil_welfare_id, par_welfare,tau_l_single,tau_l_couple,lambda,lambda_couple,tau_s,premium_rate,SUBEHI,income_tax_rev,sales_tax_rev,insurance_premium,tax_revenue_single,tax_revenue_couple,SSEXP,gov_exp*OUTPUT,med_insur_exp,UB1,gov_exp,SSEXP/OUTPUT,med_insur_exp/OUTPUT,UB1/OUTPUT,(1.0+R)**0.2-1.0,wage,OUTPUT,Agg_labor,Agg_asset,Aggconsumption,Avg_H,Avg_M, &
		! 							insurance_value,insurance_value_single,insurance_value_couple, hour_single_male,hour_single_female,hour_married_male,hour_married_female,LFP_single_female,LFP_married_female,earn_corr, & 									
		! 							cost_unc_singlemale,cost_unc_singlefemale,cost_unc_couple(1),cost_unc_couple(2),cost_ineq_singlemale,cost_ineq_singlefemale,cost_ineq_couple(1),cost_ineq_couple(2), &
		! 							agg_certeqcons_singlemale,agg_certeqlab_singlemale,agg_certeqcons_singlefemale,agg_certeqlab_singlefemale,agg_certeqcons_couple(1),agg_certeqcons_couple(2),agg_certeqlab_couple(1),agg_certeqlab_couple(2), &
		! 							AggC_singlemale,AggC_singlefemale,AggL_singlemale,AggL_singlefemale,AggC_couple,AggC_couple,AggL_couple(1),AggL_couple(2),AggC_singlemale_leicomp,AggC_singlefemale_leicomp,AggC_couple_leicomp(1),AggC_couple_leicomp(2)
									
	
!*************************************
!
!  Calculate winner_loser 
!	
!*************************************
!source_welfare in this stage should be 1 as it has computed benchmark already
	IF ((source_welfare==1) .AND. (optimal_tax == 1)) THEN 
		print*, 'CALL winner_loser begins'
		! CALL winner_loser 
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
			DEALLOCATE(log_income_diff_single_retire,log_cons_diff_single_retire,ageprofile_log_cons_diff_single_retire,log_health_shock_diff_single_retire,ageprofile_log_health_shock_diff_single_retire,log_med_diff_single_retire,dist_single_retire,ageprofile_dist_single_retire,log_income_diff_couple_retire,log_cons_diff_couple_retire,ageprofile_log_cons_diff_couple_retire,log_health_shock_diff_couple_retire,ageprofile_log_health_shock_diff_couple_retire,log_med_diff_couple_retire,dist_couple_retire,ageprofile_dist_couple_retire)
			DEALLOCATE(ageprofile_avg_log_health_shock_single_retire,ageprofile_avg_log_health_shock_couple_retire,ageprofile_avg_log_cons_single_retire,ageprofile_avg_log_cons_couple_retire,ageprofile_insurance_cons_shock_nominator_single_retire,ageprofile_insurance_cons_shock_denominator_single_retire)
			DEALLOCATE(ageprofile_insurance_cons_shock_value_single_retire,ageprofile_insurance_cons_shock_nominator_couple_retire,ageprofile_insurance_cons_shock_denominator_couple_retire,ageprofile_insurance_cons_shock_value_couple_retire)
			DEALLOCATE(ageprofile_log_med_diff_single_retire,ageprofile_log_med_diff_couple_retire,ageprofile_avg_log_med_single_retire,ageprofile_avg_log_med_couple_retire,ageprofile_insurance_med_shock_nominator_single_retire,ageprofile_insurance_med_shock_denominator_single_retire,ageprofile_insurance_med_shock_value_single_retire,ageprofile_insurance_med_shock_nominator_couple_retire,ageprofile_insurance_med_shock_denominator_couple_retire,ageprofile_insurance_med_shock_value_couple_retire)
			DEALLOCATE(temp_single_discount,single_discount,temp_couple_discount1,temp_couple_discount2,couple_discount1,couple_discount2)
			DEALLOCATE(shock)
			DEALLOCATE(youngage_log_income_shock_diff_single,youngage_log_cons_diff_single,midage_log_income_shock_diff_single,midage_log_cons_diff_single,youngage_dist_single,midage_dist_single,youngage_log_income_shock_diff_couple,youngage_log_cons_diff_couple,midage_log_income_shock_diff_couple,midage_log_cons_diff_couple,youngage_dist_couple,midage_dist_couple)
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

    !  CALL age_wealth_gini

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
	  print*, 'CALL skewness'
	  CALL skewness
	  
!*************************************
!
!  Calculate the life cycle profile of wealth,earning,income ratio 
!
!*************************************	
      print*, 'CALL AGE_PARTITION'
	  CALL AGE_PARTITION
	  
!*************************************
!
!  Calculate the Income partition of top wealth share
!
!*************************************		  
	  print*, 'CALL income_partition'
	  CALL income_partition

!*************************************
!
!  Intra family earning correlation
!
!*************************************	
	  print*, 'CALL intrafamily_correlation'
	  CALL intrafamily_correlation

!*************************************
!
!  var log earning and log consumption profile
!
!*************************************	
	  print*, 'CALL var_profile'
	  CALL var_profile

!*************************************

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
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH
				DO IG=1,2

				Agg_asset = Agg_asset + A(IA)*singleYR(AGE,IA,IH,IE,IG)
				
				END DO 
			END DO
		END DO 
    END DO
END DO

!  Couple Retirees    
DO AGE=RETAGE,MAXAGE                      
    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH

			 Agg_asset = Agg_asset + A(IA)*coupleYR(AGE,IA,IH,IE)

			END DO 
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
      
    !   CALL check_kmaxbinding

!*************************************		  
!
!  welfare analysis
!
!*************************************
      
      CALL welfare

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

ALLOCATE(VSLMOMENT1(2),VSLMOMENT2(2),VSLMOMENT3(2),VSLMOMENT4(2),VSLMOMENT5(2),VSLMOMENT6(2),VSLMOMENT7(2),VSLMOMENT8(2),VSLMOMENT9(2))
ALLOCATE(SURVMOMENT1(2),SURVMOMENT2(2),SURVMOMENT3(2),SURVMOMENT4(2))
ALLOCATE(avg_death(2))

DO IG=1,2
	VSLMOMENT1(IG) = ((S(1,IG)-S(3,IG))/(S(1,IG)+S(3,IG)))   / ((MLONG(1)-MLONG(3))/(MLONG(1)+MLONG(3)))
	VSLMOMENT2(IG) = ((S(2,IG)-S(4,IG))/(S(2,IG)+S(4,IG)))   / ((MLONG(2)-MLONG(4))/(MLONG(2)+MLONG(4)))
	VSLMOMENT3(IG) = ((S(3,IG)-S(5,IG))/(S(3,IG)+S(5,IG)))   / ((MLONG(3)-MLONG(5))/(MLONG(3)+MLONG(5)))
	VSLMOMENT4(IG) = ((S(4,IG)-S(6,IG))/(S(4,IG)+S(6,IG)))   / ((MLONG(4)-MLONG(6))/(MLONG(4)+MLONG(6)))
	VSLMOMENT5(IG) = ((S(5,IG)-S(7,IG))/(S(5,IG)+S(7,IG)))   / ((MLONG(5)-MLONG(7))/(MLONG(5)+MLONG(7)))
	VSLMOMENT6(IG) = ((S(6,IG)-S(8,IG))/(S(6,IG)+S(8,IG)))   / ((MLONG(6)-MLONG(8))/(MLONG(6)+MLONG(8)))
	VSLMOMENT7(IG) = ((S(7,IG)-S(9,IG))/(S(7,IG)+S(9,IG)))   / ((MLONG(7)-MLONG(9))/(MLONG(7)+MLONG(9)))
	! VSLMOMENT8(IG) = ((S(RETAGE,IG)-S(RETAGE+2,IG))/(S(RETAGE,IG)+S(RETAGE+2,IG))) / ((MLONG(RETAGE)-MLONG(RETAGE+2))/(MLONG(RETAGE)+MLONG(RETAGE+2)))
	VSLMOMENT8(IG) = ((S(RETAGE,IG)-S(RETAGE+2,IG))/S(RETAGE,IG)) / ((MLONG_AGE_single(RETAGE,IG)-MLONG_AGE_single(RETAGE+2,IG))/MLONG_AGE_single(RETAGE,IG))
	VSLMOMENT9(IG) = ((S(9,IG)-S(11,IG))/(S(9,IG)+S(11,IG))) / ((MLONG(9)-MLONG(11))/(MLONG(9)+MLONG(11)))
END DO
	VSLMOMENT_UCONS = (( (S(RETAGE,1)+S(RETAGE,2))/2 - (S(RETAGE+2,1)+S(RETAGE+2,2))/2 )/((S(RETAGE,1)+S(RETAGE,2))/2) ) / ((MLONG(RETAGE)-MLONG(RETAGE+2))/(MLONG(RETAGE)+MLONG(RETAGE+2)))
	
!  Unconditional survival probabilities
avg_death(:) = 0.0
    ALLOCATE( CUMS(MAXAGE,2) )
	DO IG=1,2
		CUMS(1,IG) = 1.000
		DO J=2,MAXAGE
			CUMS(J,IG) = CUMS(J-1,IG)*S(J-1,IG)
		END DO
		
		DO AGE=1,MAXAGE-1
			avg_death(IG) = avg_death(IG) + (1.0-S(AGE,IG))*CUMS(AGE,IG)
		END DO 
		avg_death(IG) = avg_death(IG)/SUM(CUMS(1:MAXAGE-1,IG))

		SURVMOMENT1(IG) = sum(CUMS(RETAGE:MAXAGE,IG))/sum(CUMS(1:RETAGE-1,IG))
		! SURVMOMENT2(IG) = 1.00/sum(CUMS(1:MAXAGE-1,IG))
		! SURVMOMENT2(IG) = 1.00/sum(CUMS(RETAGE:MAXAGE,IG))
		! SURVMOMENT2(IG) = 1.00 - sum(CUMS(RETAGE:MAXAGE,IG))/(MAXAGE-RETAGE+1)
		! SURVMOMENT2(IG) = 1.00 - sum(CUMS(1:MAXAGE,IG))/MAXAGE
		SURVMOMENT2(IG) = avg_death(IG)
		SURVMOMENT3(IG) = (S(RETAGE+2,IG)-S(RETAGE+4,IG))/(S(RETAGE,IG)-S(RETAGE+2,IG))
		SURVMOMENT4(IG) = S(MAXAGE-1,IG)/S(RETAGE,IG)
	END DO 

    ! DEV = ((AEND*5.000/TIEND-2.63)/2.63)**2.00 + ((MEDEND/TIEND-0.151)/0.151)**2.00 + ((MEND/IEND-0.058)/0.058)**2.00
	! DEV = DEV + ((MOLD/MYOUNG-7.9586)/7.9586)**2.00 + ((CWKEND/IEND-0.7847)/0.7847)**2.00 + ((TWEND-0.3493)/0.3493)**2.00
	! DEV = DEV + ((SICKEND-0.021)/0.021)**2.00 + ((SICK1/SICK2-1.36)/1.36)**2.00 + ((HEND-0.8452)/0.8452)**2.00
	! DEV = DEV + (((HLONG(1)+HLONG(2))/(HLONG(3)+HLONG(4))-1.0213)/1.0213)**2.00 + (((HLONG(3)+HLONG(4))/(HLONG(5)+HLONG(6))-1.0491)/1.0491)**2.00
	! DEV = DEV + ((SURVMOMENT1-0.3970)/0.3970)**2.00 + (SURVMOMENT2-0.0824)**2.00 + ((SURVMOMENT3-2.266)/2.266)**2.00 + (S(10)/S(1)-0.9154)**2.00
	! DEV = DEV + ((VSLMOMENT1-(-0.00181))/(-0.00181))**2.00

	MYOUNG=0.0
	DO AGE=1,7
	    MYOUNG = MYOUNG + MLONG(AGE)
	END DO
	MYOUNG=MYOUNG/7.000

	MOLD=0.0
	DO AGE=8,11
	    MOLD = MOLD + MLONG(AGE)
	END DO
	MOLD=MOLD/4.000

!	Calibration

    ! WRITE(10,*) 'FINAL RESULTS'
    ! WRITE(10,*) '*****************************************************'
    ! WRITE(10,*)
    
    ! WRITE(10,*) '1, beta'
    ! WRITE(10,*) 'Capital-Wealth Ratio (Data: 2.63 from NIPA 2002, beta) =', AEND*5/TIEND
    ! WRITE(10,*) '2, LAMBDA'
    ! WRITE(10,*) 'Nonmed Expenditure-Labor Income Ratio (Data: GK=0.7082 FK=0.7847) =', CWKEND/IEND
    ! WRITE(10,*) '3, RHO'
    ! WRITE(10,*) 'Average working hours over working age (Data: 0.3493 from PSID) =', TWEND
    ! WRITE(10,*) '4, PSI' 
    ! WRITE(10,*) 'Med Expenditure (55-74)/ Med Expenditure (20-54) (Data: 7.9586 from MEPS) =', MOLD/MYOUNG
    ! WRITE(10,*) '5, UCONS' 
    ! WRITE(10,*) 'Change in sur prob (55-59 to 65-69) / Change in med expenditure (55-59 to 65-69) (Data: -0.06266) =', VSLMOMENT8(1),VSLMOMENT8(2)
    ! WRITE(10,*)
    
!    WRITE(10,*) '6-8, health depreciation'
!    WRITE(10,*) 'Average Health status from age 20-24 to 70-74 (Data: 0.8452 from PSID) =', HEND 
!     WRITE(10,*) 'Health status age 20-29 / Health status age 30-39 (Data: 1.0213 from PSID) =', (HLONG(1)+HLONG(2))/(HLONG(3)+HLONG(4))
!     WRITE(10,*) 'Health status age 30-39 / Health status age 40-49 (Data: 1.0491 from PSID) =', (HLONG(3)+HLONG(4))/(HLONG(5)+HLONG(6))
!     WRITE(10,*)
    
!     WRITE(10,*) '9-10, health product function'
!     WRITE(10,*) 'Med Expenditure-Output Ratio (Data: 0.0774 Medical expenditure-GDP ratio (2009-2020)) =', MEDEND/TIEND
!     WRITE(10,*) 'Med Expenditure-Labor Income Ratio (Data: 0.058 from PSID) =', MEND/IEND
!     WRITE(10,*)

    ! WRITE(10,*) '11-12, sick time'
    ! WRITE(10,*) 'Sick Time Ratio over working age (Data: 0.021 from Lovell 2004) =', SICKEND
    ! WRITE(10,*) 'Sick Time (45-64) / Sick time (20-44) (Data: 1.36 from Lovell 2004) =', SICK2/SICK1
    ! WRITE(10,*)

!************************************************************************************************************************************************************    
    ! WRITE(10,*) '13-16, suvrvival probablity'
    ! WRITE(10,*) 'Dependency ratio (Data: 0.3970 from US Life Table) =', SURVMOMENT1(1),SURVMOMENT1(2)
    ! WRITE(10,*) 'Average death rate (Data: 0.0824 from US Life Table) =', SURVMOMENT2(1),SURVMOMENT2(2)
    ! WRITE(10,*) 'change in Sur. Prob (age 65-69 to 75-79) / change in sur. prob. (age 55-59 to 65-69) (Data: 2.266 from US Life Table) =', SURVMOMENT3(1), SURVMOMENT3(2)
    ! WRITE(10,*) 'Sur. Prob (age 65-69) / Sur. Prob. (20-24) (Data: 0.9154 from US Life Table) =', SURVMOMENT4(1), SURVMOMENT4(2)!S(10,1)/S(1,1), S(10,2)/S(1,2)
    ! WRITE(10,*)
!************************************************************************************************************************************************************

    
    ! WRITE(10,*) 'others'
    ! WRITE(10,*) 'Nonmed Consumption-Output Ratio (Data: 0.669 from NHA 2002) =', CEND/TIEND
    ! WRITE(10,*) 'Change in sur prob (20-24 to 30-34) / Change in med expenditure (20-24 to 30-34) (Data: -0.00181) =', VSLMOMENT1(1),VSLMOMENT1(2)
    ! WRITE(10,*) 'Change in sur prob (25-29 to 35-39) / Change in med expenditure (25-29 to 35-39) (Data: -0.00277) =', VSLMOMENT2(1),VSLMOMENT2(2)
    ! WRITE(10,*) 'Change in sur prob (30-34 to 40-44) / Change in med expenditure (30-34 to 40-44) (Data: -0.01765) =', VSLMOMENT3(1),VSLMOMENT3(2)
    ! WRITE(10,*) 'Change in sur prob (35-39 to 45-49) / Change in med expenditure (35-39 to 45-49) (Data: -0.01204) =', VSLMOMENT4(1),VSLMOMENT4(2)
    ! WRITE(10,*) 'Change in sur prob (40-44 to 50-54) / Change in med expenditure (40-44 to 50-54) (Data: -0.0600) =',  VSLMOMENT5(1),VSLMOMENT5(2)
    ! WRITE(10,*) 'Change in sur prob (45-49 to 55-59) / Change in med expenditure (45-49 to 55-59) (Data: -0.03379) =', VSLMOMENT6(1),VSLMOMENT6(2)
    ! WRITE(10,*) 'Change in sur prob (50-54 to 60-64) / Change in med expenditure (50-54 to 60-64) (Data: -0.02842) =', VSLMOMENT7(1),VSLMOMENT7(2)
    ! WRITE(10,*) 'Change in sur prob (60-64 to 70-74) / Change in med expenditure (60-64 to 70-74) (Data: -0.1285) =',  VSLMOMENT9(1),VSLMOMENT9(2)
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
		
		

		write(*, "(15(A11,1X))") 'Annual BETA','tau_l_single','tau_l_couple','delta_lambda','tau_c','tau_s','d_c','premium_rate'
		WRITE(*,"(12(F11.4,1X))") BETA**(0.2), tau_l_single, tau_l_couple, delta_lambda,tau_c, tau_s, d_c, premium_rate
		write(*, "(15(A11,1X))") 'MPL','wage', 'MPK','Annual r', 'DEP_ANNUAL','marry prop', 'lambda_S','lambda_M'
		WRITE(*,"(12(F11.4,1X))") MPL, wage, MPK, (1.0+R)**0.2-1.0, DEP_ANNUAL,marryprop , lambda, lambda_couple
		write(*, "(15(A11,1X))") 'LPC_singleF','LPC_marr_F','theta_singM','theta_singF','theta_marrM','theta_marrF'
		WRITE(*,"(12(F11.4,1X))") fixcost_singlefemale,fixcost_marriedfemale,theta_single_male,theta_single_female,theta_married_male,theta_married_female
        write(*, "(15(A11,1X))") 'TFP','Y', 'L','K','C','ALPHA', 'K/Y','H','M'
        WRITE(*,"(12(F11.4,1X))") TFP,OUTPUT,Agg_labor,Agg_asset,Aggconsumption,ALPHA,alpha/((1.0+R)**0.2-1.0 + DEP_ANNUAL),Avg_H,Avg_M
		
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
		write(*,"(15(A11,1X))") 'R/Y', 'ATY1', 'ATY99', 'ATY1-ATY99','ATY','ATY_S','ATY_M'
		write(*,"(12(F11.4,1X))") inctaxrev_income, ATY1, ATY99, ATY1-ATY99,ATY,ATY_single,ATY_couple
		print*, 'Corporate tax moments'
		write(*,"(15(A11,1X))") 'R/Y', 'ATC1', 'ATC99'
		write(*,"(12(F11.4,1X))") ctaxrev_income, ATC1, ATC99
		print*, 'Government expenditures','Government Transfer'
		write(*,"(15(A11,1X))") 'total exp/Y','G/Y' ,'Trans/Y','SS/Y','Med/Y','EHI/Y','UB/Y'
		write(*,"(12(F11.4,1X))")  G_share, gov_exp ,flat_transf_rate,SSEXP/OUTPUT,medicare_rate,med_insur_exp/OUTPUT,UB1/OUTPUT
		

		IF (gov_method==0) THEN 
			print*, 'Implied G/GDP', gov_exp
		ELSEIF (gov_method==1) THEN
			print*, 'implied G level=',gov_exp
		ELSEIF (gov_method==2) THEN
			print*, 'G/GDP=',gov_exp
		END IF

		print*, ' '		
		print*, 'tax revenue share from single=',tax_revenue_single/(tax_revenue_single+tax_revenue_couple)
		print*, 'tax revenue share from couple=',tax_revenue_couple/(tax_revenue_single+tax_revenue_couple)


		print*, ' '		
		print*, 'unemployment rate =',unemployment_rate
		print*, 'Agg. Working hour =', Avg_hour !TWEND
		print*, 'Total male Working hour =', hour_male
		print*, 'Total female Working hour =', hour_female
		print*, 'Single male Working hour (0.258) =', hour_single_male
		print*, 'Married male Working hour (0.279)=', hour_married_male
		print*, 'Single female Working hour (0.22)=', hour_single_female
		print*, 'Married female Working hour (0.171) =', hour_married_female
		print*, ' '
		print*, 'Labor force participation rate between 20-64'
		print*, 'Men', LFP_male
		print*, 'Women', LFP_female
		print*, 'Single female (0.819)', LFP_single_female
		print*, 'Married female (0.715)', LFP_married_female

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
		print*,'young age group'
		print*,'all household', youngage_insurance_cons_value
		print*,'single household', youngage_insurance_cons_value_single
		print*,'married household', youngage_insurance_cons_value_couple
		print*,'middle age group'
		print*,'all household', midage_insurance_cons_value
		print*,'single household', midage_insurance_cons_value_single
		print*,'married household', midage_insurance_cons_value_couple
		print*,''
		print*, 'transmission of productivity shock to earning '
		print*,'transmission_labor_value',insurance_labor_value
		print*,'transmission_labor_value_single',insurance_labor_value_single
		print*,'transmission_labor_value_couple',insurance_labor_value_couple
		print*,''
		print*, 'transmission of health shock to consumption '
		print*,'insurance_value_retire=',insurance_value_retire
		print*,'insurance_value_single_retire=',insurance_value_single_retire
		print*,'insurance_value_couple_retire=',insurance_value_couple_retire
		print*,''
		print*, 'transmission of health shock to medical expense '
		print*,'insurance_value_med_retire=',insurance_value_med_retire
		print*,'insurance_value_med_single_retire=',insurance_value_med_single_retire
		print*,'insurance_value_med_couple_retire=',insurance_value_med_couple_retire
		print*,''
		IF (CV==1) THEN 
		print*,'Compensated Variation'
		print*,'young age single', SUM(cv_working_single(1:4,:,:,:,:))/SUM(singleYW(1:4,:,:,:,:))
		print*,'mid age single', SUM(cv_working_single(5:RETAGE-1,:,:,:,:))/SUM(singleYW(5:RETAGE-1,:,:,:,:))
		print*,'retire age single', SUM(cv_retire_single(:,:,:,:,:))/SUM(singleYR(:,:,:,:,:))
		print*,'young age couple', SUM(cv_working_couple(1:4,:,:,:,:))/SUM(coupleYW(1:4,:,:,:,:))
		print*,'mid age couple', SUM(cv_working_couple(5:RETAGE-1,:,:,:,:))/SUM(coupleYW(5:RETAGE-1,:,:,:,:))
		print*,'retire age couple', SUM(cv_retire_couple(:,:,:,:))/SUM(coupleYR(:,:,:,:))
		END IF 

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

		print*, ' '
		print*, 'Life cycle profile of health'
		write(*, "(15(A11,1X))") '65_69','70_74','75_79','80_84','85_89','90_94','95_99'
		print*, 'Single Male'
		WRITE(*,"(12(F11.4,1X))") HLONG_AGE_single(9,1),HLONG_AGE_single(10,1),HLONG_AGE_single(11,1),HLONG_AGE_single(12,1),HLONG_AGE_single(13,1),HLONG_AGE_single(14,1),HLONG_AGE_single(15,1)
		print*, 'Single Female'
		WRITE(*,"(12(F11.4,1X))") HLONG_AGE_single(9,2),HLONG_AGE_single(10,2),HLONG_AGE_single(11,2),HLONG_AGE_single(12,2),HLONG_AGE_single(13,2),HLONG_AGE_single(14,2),HLONG_AGE_single(15,2)
		print*, 'Couple'
		WRITE(*,"(12(F11.4,1X))") HLONG_AGE_couple(9),HLONG_AGE_couple(10),HLONG_AGE_couple(11),HLONG_AGE_couple(12),HLONG_AGE_couple(13),HLONG_AGE_couple(14),HLONG_AGE_couple(15)
		print*, 'All'
		WRITE(*,"(12(F11.4,1X))") HLONG(9),HLONG(10),HLONG(11),HLONG(12),HLONG(13),HLONG(14),HLONG(15)

		print*, ' '
		print*, 'Life cycle profile of medical expenditure'
		write(*, "(15(A11,1X))") '65_69','70_74','75_79','80_84','85_89','90_94','95_99'
		print*, 'Single Male'
		WRITE(*,"(12(F11.4,1X))") MLONG_AGE_single(9,1),MLONG_AGE_single(10,1),MLONG_AGE_single(11,1),MLONG_AGE_single(12,1),MLONG_AGE_single(13,1),MLONG_AGE_single(14,1),MLONG_AGE_single(15,1)
		print*, 'Single Female'
		WRITE(*,"(12(F11.4,1X))") MLONG_AGE_single(9,2),MLONG_AGE_single(10,2),MLONG_AGE_single(11,2),MLONG_AGE_single(12,2),MLONG_AGE_single(13,2),MLONG_AGE_single(14,2),MLONG_AGE_single(15,2)
		print*, 'Couple'
		WRITE(*,"(12(F11.4,1X))") MLONG_AGE_couple(9),MLONG_AGE_couple(10),MLONG_AGE_couple(11),MLONG_AGE_couple(12),MLONG_AGE_couple(13),MLONG_AGE_couple(14),MLONG_AGE_couple(15)
		print*, 'All'
		WRITE(*,"(12(F11.4,1X))") MLONG(9),MLONG(10),MLONG(11),MLONG(12),MLONG(13),MLONG(14),MLONG(15)

		
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

		print*, ' '
		print*, 'Life cycle profile of var log consumption'
		write(*, "(15(A11,1X))") '25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") var_cons_age_single(1),var_cons_age_single(2),var_cons_age_single(3),var_cons_age_single(4),var_cons_age_single(5),var_cons_age_single(6),var_cons_age_single(7),var_cons_age_single(8)
		print*, 'Couples'
		WRITE(*,"(12(F11.4,1X))") var_cons_age_couple(1),var_cons_age_couple(2),var_cons_age_couple(3),var_cons_age_couple(4),var_cons_age_couple(5),var_cons_age_couple(6),var_cons_age_couple(7),var_cons_age_couple(8)

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
		print*, 'Life cycle profile of consumption insurance from health shock'
		write(*, "(15(A11,1X))") '65_69','70_74','75_79','80_84','85_89','90_94','95_99'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_cons_shock_value_single_retire(9),ageprofile_insurance_cons_shock_value_single_retire(10),ageprofile_insurance_cons_shock_value_single_retire(11),ageprofile_insurance_cons_shock_value_single_retire(12),ageprofile_insurance_cons_shock_value_single_retire(13),ageprofile_insurance_cons_shock_value_single_retire(14)
		print*, 'Couple'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_cons_shock_value_couple_retire(9),ageprofile_insurance_cons_shock_value_couple_retire(10),ageprofile_insurance_cons_shock_value_couple_retire(11),ageprofile_insurance_cons_shock_value_couple_retire(12),ageprofile_insurance_cons_shock_value_couple_retire(13),ageprofile_insurance_cons_shock_value_couple_retire(14)
		print*, ' '
		print*, 'Life cycle profile of medical exp insurance from health shock'
		write(*, "(15(A11,1X))") '65_69','70_74','75_79','80_84','85_89','90_94','95_99'
		print*, 'Single'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_med_shock_value_single_retire(9),ageprofile_insurance_med_shock_value_single_retire(10),ageprofile_insurance_med_shock_value_single_retire(11),ageprofile_insurance_med_shock_value_single_retire(12),ageprofile_insurance_med_shock_value_single_retire(13),ageprofile_insurance_med_shock_value_single_retire(14)
		print*, 'Couple'
		WRITE(*,"(12(F11.4,1X))") ageprofile_insurance_med_shock_value_couple_retire(9),ageprofile_insurance_med_shock_value_couple_retire(10),ageprofile_insurance_med_shock_value_couple_retire(11),ageprofile_insurance_med_shock_value_couple_retire(12),ageprofile_insurance_med_shock_value_couple_retire(13),ageprofile_insurance_med_shock_value_couple_retire(14)


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
		
		! print*, ' '
		! print*, 'Synthetic Saving rates '
		! write(*, "(15(A11,1X))") 'Average', 'Bottom 90%', 'Top 10%', 'Top 5%', 'Top 1%','Top 0.1%', 'Top 10-1%', 'Top 10-5%', 'Top 5-1%', 'Top 1-0.1%'
		! WRITE(*,"(12(F11.4,1X))") synsavingrate_avg, synsavingrate_bot90pct, synsavingrate_10pct, synsavingrate_5pct,synsavingrate_1pct,synsavingrate_01pct,synsavingrate_10_1pct,synsavingrate_10_5pct,synsavingrate_5_1pct,synsavingrate_1_01pct
		
		! print*, ' '
		! print*, 'Consumption by income ranking'
		! write(*,"(15(A11,1X))") 'Top 0.1%', 'Top 0.5%', 'Top 1%', 'Top 5%', 'Top 10%', 'Top 20%', 'Top 40%', 'Top 60%', 'Top 80%'
		! write(*,"(12(F11.4,1X))") cshare_tinc01, cshare_tinc05, cshare_tinc1, cshare_tinc5, cshare_tinc10, cshare_tinc20, cshare_tinc40, cshare_tinc60, cshare_tinc80
		

        ! print*, ' '
		! print*, 'Bequest Moment (Hurd and Smith 2002, PSID: 1968-2003)'
		! write(*, "(15(A11,1X))") 'Beq_K_raito','Beq98','Beq95', 'Beq90', 'Beq80', 'Beq70', 'Beq60', 'Beq50'
		! WRITE(*,"(12(F11.4,1X))") beq_wealth_ratio,Beq98,Beq95, Beq90, Beq80, Beq70, Beq60, Beq50
		! write(*, "(15(A11,1X))") 'Beq40','Beq30', 'Beq20', 'Beq10'
		! WRITE(*,"(12(F11.4,1X))") Beq40, Beq30, Beq20, Beq10

		

		! print*, ' '
		! print*, 'implied MTR on capital income for someone on the edge of the top 1%, 10%'
		! write(*,"(15(A11,1X))") 'MTR1', 'MTR10'
		! write(*,"(12(F11.4,1X))") MTR1, MTR10


		print*, ' '
		print*, 'Variance of log earnings =', incvar
		print*, 'Variance of log consumption =', consvar
		print*, 'insurance ratio=', consvar/incvar

		! print*, ' '
		! print*, 'inheritance Distribution (Hendricks 2007) '
		! write(*, "(15(A11,1X))") 'Mean','Gini','0-50(%)','50-70(%)', '70-80(%)', '80-90(%)', '90-95(%)', '95-99(%)', '99-100(%)'
		! WRITE(*,"(12(F11.4,1X))") AggBeq,beq_gini,bshare0_50*100,bshare50_70*100,bshare70_80*100,bshare80_90*100,bshare90_95*100,bshare95_99*100,bshare99_100*100

		! print*, ' '
		! print*, 'tax_penalty for couple'
		! write(*,"(11(F8.5,1X))") couple_taxpenalty(1,1), couple_taxpenalty(1,2),couple_taxpenalty(1,3),couple_taxpenalty(1,4)
		! write(*,"(11(F8.5,1X))") couple_taxpenalty(2,1), couple_taxpenalty(2,2),couple_taxpenalty(2,3),couple_taxpenalty(2,4)
		! write(*,"(11(F8.5,1X))") couple_taxpenalty(3,1), couple_taxpenalty(3,2),couple_taxpenalty(3,3),couple_taxpenalty(3,4)
		! write(*,"(11(F8.5,1X))") couple_taxpenalty(4,1), couple_taxpenalty(4,2),couple_taxpenalty(4,3),couple_taxpenalty(4,4)

		print*, ' '
		print*, 'Percent of total household'
		write(*, "(15(A11,1X))") 'tax', 'subsidy','MFS','weight_MFS'
		WRITE(*,"(12(F11.4,1X))") prop_family_tax, prop_family_subsidy, popu_MFS, weight_MFS
		print*, 'Average Tax'
		write(*, "(15(A11,1X))") 'avg_tax','sd_tax', 'avg_subsidy', 'sd_subsidy'
		WRITE(*,"(12(F11.4,1X))") avg_family_tax, sd_family_tax, avg_family_subsidy, sd_family_subsidy

		! print*, ' '
		! print*, 'Average Marriage Tax/Subsidy by Earnings Ratio of female to male'
		! print*, 'Average marriage tax'
		! DO i=1,5
		! 	WRITE(*,"(12(F11.4,1X))") avg_earnratio_tax(i,1),avg_earnratio_tax(i,2), avg_earnratio_tax(i,3), avg_earnratio_tax(i,4),avg_earnratio_tax(i,5)
		! END DO 
		! print*, 'Average marriage subsidy'
		! DO i=1,5
		! 	WRITE(*,"(12(F11.4,1X))") avg_earnratio_subsidy(i,1),avg_earnratio_subsidy(i,2), avg_earnratio_subsidy(i,3), avg_earnratio_subsidy(i,4),avg_earnratio_subsidy(i,5)
		! END DO
		! print*, 'Proportion with marriage tax'	
		! DO i=1,5
		! 	WRITE(*,"(12(F11.4,1X))") prop_earnratio_tax(i,1),prop_earnratio_tax(i,2), prop_earnratio_tax(i,3), prop_earnratio_tax(i,4),prop_earnratio_tax(i,5)
		! END DO	 
		! print*, 'Proportion with marriage subsidy'	
		! DO i=1,5
		! 	WRITE(*,"(12(F11.4,1X))") prop_earnratio_subsidy(i,1),prop_earnratio_subsidy(i,2), prop_earnratio_subsidy(i,3), prop_earnratio_subsidy(i,4),prop_earnratio_subsidy(i,5)
		! END DO

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

		! print*, ' '
		! print*, 'welfare'
		! write(*,"(11(A8,1X))") 'single_M','single_F','marry_M','marry_F','Avg_couple'
		! WRITE(*,"(12(F11.4,1X))") single_male_welfare, single_female_welfare, married_male_welfare, married_female_welfare, total_couple_welfare
		! write(*,"(11(A8,1X))") 'coup_welfare'
		! WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(1,1), avg_couple_welfare(1,2),  avg_couple_welfare(1,3), avg_couple_welfare(1,4)
		! WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(2,1), avg_couple_welfare(2,2),  avg_couple_welfare(2,3), avg_couple_welfare(2,4)
		! WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(3,1), avg_couple_welfare(3,2),  avg_couple_welfare(3,3), avg_couple_welfare(3,4)
		! WRITE(*,"(12(F11.4,1X))") avg_couple_welfare(4,1), avg_couple_welfare(4,2),  avg_couple_welfare(4,3), avg_couple_welfare(4,4)
		
		

		! print*, ' '
		! print*, 'welfare decompose'
		! print*, 'single male'
		! print*, 'average consumption of quintiles'
		 

		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_working(1,1),change_bench_single_cons_incomethreshold_working(2,1),change_bench_single_cons_incomethreshold_working(3,1),change_bench_single_cons_incomethreshold_working(4,1),change_bench_single_cons_incomethreshold_working(5,1)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_retire(1,1),change_bench_single_cons_incomethreshold_retire(2,1),change_bench_single_cons_incomethreshold_retire(3,1),change_bench_single_cons_incomethreshold_retire(4,1),change_bench_single_cons_incomethreshold_retire(5,1)

		! print*, 'average labor of quintiles'
		

		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_labor_incomethreshold_working(1,1),change_bench_single_labor_incomethreshold_working(2,1),change_bench_single_labor_incomethreshold_working(3,1),change_bench_single_labor_incomethreshold_working(4,1),change_bench_single_labor_incomethreshold_working(5,1)		
		 
		! print*, 'average welfare of quintiles'

		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_working(1,1),change_bench_single_val_incomethreshold_working(2,1),change_bench_single_val_incomethreshold_working(3,1),change_bench_single_val_incomethreshold_working(4,1),change_bench_single_val_incomethreshold_working(5,1)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_retire(1,1),change_bench_single_val_incomethreshold_retire(2,1),change_bench_single_val_incomethreshold_retire(3,1),change_bench_single_val_incomethreshold_retire(4,1),change_bench_single_val_incomethreshold_retire(5,1)

		! print*, 'change of lifetime consumption of quintiles'

		! 	WRITE(*,"(12(F11.4,1X))") cons_change_single_male_working(1),cons_change_single_male_working(2),cons_change_single_male_working(3),cons_change_single_male_working(4),cons_change_single_male_working(5)
		! 	WRITE(*,"(12(F11.4,1X))") cons_change_single_male_retire(1),cons_change_single_male_retire(2),cons_change_single_male_retire(3),cons_change_single_male_retire(4),cons_change_single_male_retire(5)


		! print*, ' '
		! print*, 'single female'
		! print*, 'average consumption of quintiles'

		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_working(1,2),change_bench_single_cons_incomethreshold_working(2,2),change_bench_single_cons_incomethreshold_working(3,2),change_bench_single_cons_incomethreshold_working(4,2),change_bench_single_cons_incomethreshold_working(5,2)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_cons_incomethreshold_retire(1,2),change_bench_single_cons_incomethreshold_retire(2,2),change_bench_single_cons_incomethreshold_retire(3,2),change_bench_single_cons_incomethreshold_retire(4,2),change_bench_single_cons_incomethreshold_retire(5,2)

		! print*, 'average labor of quintiles'
		
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_labor_incomethreshold_working(1,2),change_bench_single_labor_incomethreshold_working(2,2),change_bench_single_labor_incomethreshold_working(3,2),change_bench_single_labor_incomethreshold_working(4,2),change_bench_single_labor_incomethreshold_working(5,2)
			
		! print*, 'average welfare of quintiles'
		
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_working(1,2),change_bench_single_val_incomethreshold_working(2,2),change_bench_single_val_incomethreshold_working(3,2),change_bench_single_val_incomethreshold_working(4,2),change_bench_single_val_incomethreshold_working(5,2)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_single_val_incomethreshold_retire(1,2),change_bench_single_val_incomethreshold_retire(2,2),change_bench_single_val_incomethreshold_retire(3,2),change_bench_single_val_incomethreshold_retire(4,2),change_bench_single_val_incomethreshold_retire(5,2)
			
		! print*, 'change of lifetime consumption of quintiles'
		! 	WRITE(*,"(12(F11.4,1X))") cons_change_single_female_working(1),cons_change_single_female_working(2),cons_change_single_female_working(3),cons_change_single_female_working(4),cons_change_single_female_working(5)
		! 	WRITE(*,"(12(F11.4,1X))") cons_change_single_female_retire(1),cons_change_single_female_retire(2),cons_change_single_female_retire(3),cons_change_single_female_retire(4),cons_change_single_female_retire(5)


		! print*, ' '
		! print*, 'Married male'
		! print*, 'average consumption of quintiles'

		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_working(1,1),change_bench_couple_cons_incomethreshold_working(2,1),change_bench_couple_cons_incomethreshold_working(3,1),change_bench_couple_cons_incomethreshold_working(4,1),change_bench_couple_cons_incomethreshold_working(5,1)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_retire(1,1),change_bench_couple_cons_incomethreshold_retire(2,1),change_bench_couple_cons_incomethreshold_retire(3,1),change_bench_couple_cons_incomethreshold_retire(4,1),change_bench_couple_cons_incomethreshold_retire(5,1)

		! print*, 'average labor of quintiles'
		
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_labor_incomethreshold_working(1,1),change_bench_couple_labor_incomethreshold_working(2,1),change_bench_couple_labor_incomethreshold_working(3,1),change_bench_couple_labor_incomethreshold_working(4,1),change_bench_couple_labor_incomethreshold_working(5,1)

		! print*, 'average welfare of quintiles'
		
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_working(1,1),change_bench_couple_val_incomethreshold_working(2,1),change_bench_couple_val_incomethreshold_working(3,1),change_bench_couple_val_incomethreshold_working(4,1),change_bench_couple_val_incomethreshold_working(5,1)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_retire(1,1),change_bench_couple_val_incomethreshold_retire(2,1),change_bench_couple_val_incomethreshold_retire(3,1),change_bench_couple_val_incomethreshold_retire(4,1),change_bench_couple_val_incomethreshold_retire(5,1)

		! print*, 'change of lifetime consumption of quintiles'
			
		! 	WRITE(*,"(12(F11.4,1X))") cons_change_couple_male_working(1),cons_change_couple_male_working(2),cons_change_couple_male_working(3),cons_change_couple_male_working(4),cons_change_couple_male_working(5)
		! 	WRITE(*,"(12(F11.4,1X))") cons_change_couple_male_retire(1),cons_change_couple_male_retire(2),cons_change_couple_male_retire(3),cons_change_couple_male_retire(4),cons_change_couple_male_retire(5)


		! print*, ' '
		! print*, 'Married female'
		! print*, 'average consumption of quintiles'
		
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_working(1,2),change_bench_couple_cons_incomethreshold_working(2,2),change_bench_couple_cons_incomethreshold_working(3,2),change_bench_couple_cons_incomethreshold_working(4,2),change_bench_couple_cons_incomethreshold_working(5,2)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_cons_incomethreshold_retire(1,2),change_bench_couple_cons_incomethreshold_retire(2,2),change_bench_couple_cons_incomethreshold_retire(3,2),change_bench_couple_cons_incomethreshold_retire(4,2),change_bench_couple_cons_incomethreshold_retire(5,2)

		! print*, 'average labor of quintiles'
		
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_labor_incomethreshold_working(1,2),change_bench_couple_labor_incomethreshold_working(2,2),change_bench_couple_labor_incomethreshold_working(3,2),change_bench_couple_labor_incomethreshold_working(4,2),change_bench_couple_labor_incomethreshold_working(5,2)

		! print*, 'average welfare of quintiles'
		
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_working(1,2),change_bench_couple_val_incomethreshold_working(2,2),change_bench_couple_val_incomethreshold_working(3,2),change_bench_couple_val_incomethreshold_working(4,2),change_bench_couple_val_incomethreshold_working(5,2)
		! 	WRITE(*,"(12(F11.4,1X))") change_bench_couple_val_incomethreshold_retire(1,2),change_bench_couple_val_incomethreshold_retire(2,2),change_bench_couple_val_incomethreshold_retire(3,2),change_bench_couple_val_incomethreshold_retire(4,2),change_bench_couple_val_incomethreshold_retire(5,2)

		! print*, 'change of lifetime consumption of quintiles'
			
		! 	WRITE(*,"(12(F11.4,1X))") cons_change_couple_female_working(1),cons_change_couple_female_working(2),cons_change_couple_female_working(3),cons_change_couple_female_working(4),cons_change_couple_female_working(5)
		! 	WRITE(*,"(12(F11.4,1X))") cons_change_couple_female_retire(1),cons_change_couple_female_retire(2),cons_change_couple_female_retire(3),cons_change_couple_female_retire(4),cons_change_couple_female_retire(5)


		! print*, ' '
		! print*, 'Welfare benefit of reducing consumption dispersion'
		! print*, change_bench_util_C
		! print*, 'Welfare benefit of reducing hours dispersion'
		! print*, change_bench_util_LS


		print*, ' '
		write(*,"(15(A11,1X))")	'util_welfare_id','welfare_retiree','welfare_working','veil_welfare_id', 'par_welfare'
		WRITE(*,"(12(F11.4,1X))") util_welfare_id, util_welfare_id_retiree,util_welfare_id_working, veil_welfare_id, par_welfare
		print*, ' CEV '
		write(*,"(15(A11,1X))")	'no_SS','no_EHI','no_prog','no_allpolicy'
		write(*,"(11(A8,1X))")	'newborn'
		write(*,"(12(F11.4,1X))") no_pension_CEV_newborn,no_EHI_CEV_newborn,no_prog_CEV_newborn,no_allpolicy_CEV_newborn
		write(*,"(11(A8,1X))")	'All individuals'
		write(*,"(12(F11.4,1X))") no_pension_CEV,no_EHI_CEV,no_prog_CEV, no_allpolicy_CEV
		write(*,"(11(A8,1X))")	'working'
		write(*,"(12(F11.4,1X))") no_pension_CEV_working,no_UB_CEV_working,no_EHI_CEV_working,no_prog_CEV_working
		write(*,"(11(A8,1X))")	'retiree'
		write(*,"(12(F11.4,1X))") no_pension_CEV_retiree,no_UB_CEV_retiree,no_EHI_CEV_retiree,no_prog_CEV_retiree
		


	print*, '------------------------------------------------------'
	print*, '                    PARAMETER VALUES'
    print*, '------------------------------------------------------'
  
	 print*, 'Wage rate:', WAGE
	 print*, 'Interest rate (annual):', R_ANNUAL
	 print*, 'Interest rate (5 years accumulative):', R
  

    !  print*, 'Initial Bequest:', BEQ0
    !  print*, 'Initial SS benefit:', SS0
    !  print*, 'Initial SS benefit:', STAX0
    !  print*, 'Initial med tax rate:', MTAX0
    !  print*, '	Initial EHI premium:', PREMIUM0
 

    !  print*, 'Convergence tolerance for bequests:', TOLB
    !  print*, 'Convergence tolerance for SS benefits:', TOLSS
    !  print*, 'Convergence tolerance for SS tax rate:', TOLSTAX
    !  print*, 'Convergence tolerance for med tax rate:', TOLMTAX
    !  print*, 'Convergence tolerance for EHI premium:', TOLEHI
    !  print*, 'Convergence gradient for bequests:', GRADB
    !  print*, 'Convergence gradient for SS tax rate:', GRADSS
    !  print*, 'Convergence gradient for SS tax rate:', GRADSTAX
    !  print*, 'Convergence gradient for med tax rate:', GRADMTAX
    !  print*, 'Convergence gradient for EHI premium:', GRADEHI
    !  print*, 'Maximum number of iterations for convergence:', MAXITER
    
   
     print*, 'Capital exponent in production function:', ALPHA
     print*, 'Multiplicative constant in production function:', TFP
     print*, 'Annual growth rate of per capita output:', GROWTH_ANNUAL
     print*, 'Annual Depreciation rate:', DEP_ANNUAL
     print*, 'Depreciation rate of capital (5 years):', DEP

    
     print*, 'Annual subjective discount factor:', BETA_ANNUAL
     print*, 'subjective discount factor ( 5 years):', BETA
     print*, 'Risk aversion parameter:', sigma
     print*, 'Constant term in utility function(male):', UCONS1
	 print*, 'Constant term in utility function(female):', UCONS2
     print*, 'Share of consumption in the consumption-leisure composition:', RHO
     print*, 'Elasticity of substitution b/w consumption-leisure and health:', PSI
!     print*, '  Share of consumption-leisure composition in utility:', LAMBDA


     print*, 'Productivity of health accumulation technology:', B
     print*, 'Return to Scale in health investment:', XI
 

     print*, 'Intercept of depreciation rate of health status (a0):', a0
     print*, 'Coefficent for age (a1):', a1
     print*, 'Coefficent for age^2 (a2):', a2


     print*, 'Intercept of sur. prob. function (c0):', c0
     print*, 'Coefficent for age (c1):', c1
     print*, 'Coefficent for age^2 (c2):', c2
     print*, 'Coefficent for health (c3):', c3
 

     print*, 'Health insurance premium', premium_rate

   

     print*, 'Social security replacement ratio:', rr
     print*, 'Subsidy rate of med (Medicaid + Medicare):', SUBEHI
  

     print*, 'Maximum age allowed:', MAXAGE
     print*, 'Retirement age:', RETAGE
     print*, 'Population growth rate:', POPG
 

     print*, 'Maximum permissible asset:', AMAX
     print*, 'Minimum permissible asset:', AMIN
     print*, 'Maximum permissible med expenditure:', MMAX
	 print*, 'Maximum permissible health:', HMAX
     print*, 'Number of points on health state grid:', NGRIDH
     print*, 'Number of points on asset grid:', NGRIDA
     print*, '------------------------------------------------------'		
   

  	 print*, ''
     print*, '*************************FINAL RESULTS****************************'
   
    
     print*, '1, alpha'
     print*, 'K/Y Ratio (Data: 3.2 from Kitao) =', alpha/((1.0+R)**0.2-1.0 + DEP_ANNUAL)
	 print*, '2, beta'
     print*, 'interest rate (Data: 2.0 from Kitao) =', (1.0+R)**0.2-1.0
    !  print*, '2, LAMBDA'
    !  print*, 'Nonmed Expenditure-Labor Income Ratio (Data: GK=0.7082 FK=0.7847) =', CWKEND/IEND
    !  print*, '3, RHO'
    !  print*, 'Average working hours over working age (Data: 0.3493 from PSID) =', TWEND
    !  print*, '4, PSI' 
    !  print*, 'Med Expenditure (55-74)/ Med Expenditure (20-54) (Data: 7.9586 from MEPS) =', MOLD/MYOUNG
     print*, '5, UCONS' 
     print*, 'Change in sur prob (65-69 to 75-79) / Change in med expenditure (65-69 to 75-79) (Data: -0.0416(male), -0.0171(female)), -0.0292(avg) =', VSLMOMENT8(1),VSLMOMENT8(2),VSLMOMENT_UCONS
    
     print*, '6-8, health depreciation'
     print*, 'Average Health status from age 65-89 (Data: 0.532) =', Avg_H 
     print*, 'Health status age 65-69 / Health status age 70-74 (Data: 1.03) =', HLONG(RETAGE)/HLONG(RETAGE+1)
     print*, 'Health status age 75-79 / Health status age 80-84 (Data: 1.08) =', HLONG(RETAGE+2)/HLONG(RETAGE+3)
	 print*, 'average health status at age 65 (Data:0.56732) =',  Avg_H_6569
   
    
     print*, '9-10, health product function'
     print*, 'Gov Med Expenditure-GDP Ratio (Data: 7.74) =', med_insur_exp/OUTPUT
     print*, 'Med Expenditure-Labor Income Ratio (Data: 0.0852) =', SUM(MLONG)/SUM(ILONG) !med_insur_exp/SUM(ILONG)!SUM(MLONG)/SUM(ILONG)
   

    !  print*, '11-12, sick time'
    !  print*, 'Sick Time Ratio over working age (Data: 0.021 from Lovell 2004) =', SICKEND
    !  print*, 'Sick Time (45-64) / Sick time (20-44) (Data: 1.36 from Lovell 2004) =', SICK2/SICK1
    !  print*,

!************************************************************************************************************************************************************    
     print*, '13-16, suvrvival probablity'
     print*, 'Dependency ratio (Data: 0.360(male), 0.486(female) ) =', SURVMOMENT1(1),SURVMOMENT1(2)
     print*, 'Average death rate (Age:65-99) (Data: 0.0572(male), 0.0328(female)) =', SURVMOMENT2(1),SURVMOMENT2(2)
    !  print*, 'change in Sur. Prob (age 65-69 to 75-79) / change in sur. prob. (age 55-59 to 65-69) (Data: 2.781(male), 3.628(female)) =', SURVMOMENT3(1), SURVMOMENT3(2)
	print*, 'change in Sur. Prob (age 75-79 to 85-89) / change in sur. prob. (age 65-69 to 75-79) (Data: 3.35(male), 4.46(female)) =', SURVMOMENT3(1), SURVMOMENT3(2)
     print*, 'Sur. Prob (age 75-79) / Sur. Prob. (age 65-69) (Data: 0.977(male) , 0.989(male)) =', S(RETAGE+2,1)/S(RETAGE,1), S(RETAGE+2,2)/S(RETAGE,2)
	 print*, 'Sur. Prob (age 80-84) / Sur. Prob. (age 65-69) (Data: 0.947(male) , 0.972(male)) =', S(RETAGE+3,1)/S(RETAGE,1), S(RETAGE+3,2)/S(RETAGE,2)
	 print*, 'Sur. Prob (age 90-94) / Sur. Prob. (age 65-69) (Data: 0.8255(male) , 0.877(male)) =', S(RETAGE+5,1)/S(RETAGE,1), S(RETAGE+5,2)/S(RETAGE,2)
!************************************************************************************************************************************************************

    
    !  print*, 'others'
    !  print*, 'Nonmed Consumption-Output Ratio (Data: 0.669 from NHA 2002) =', CEND/TIEND
    !  print*, 'Change in sur prob (20-24 to 30-34) / Change in med expenditure (20-24 to 30-34) (Data: -0.00181) =', VSLMOMENT1(1),VSLMOMENT1(2)
    !  print*, 'Change in sur prob (25-29 to 35-39) / Change in med expenditure (25-29 to 35-39) (Data: -0.00277) =', VSLMOMENT2(1),VSLMOMENT2(2)
    !  print*, 'Change in sur prob (30-34 to 40-44) / Change in med expenditure (30-34 to 40-44) (Data: -0.01765) =', VSLMOMENT3(1),VSLMOMENT3(2)
    !  print*, 'Change in sur prob (35-39 to 45-49) / Change in med expenditure (35-39 to 45-49) (Data: -0.01204) =', VSLMOMENT4(1),VSLMOMENT4(2)
    !  print*, 'Change in sur prob (40-44 to 50-54) / Change in med expenditure (40-44 to 50-54) (Data: -0.0600) =',  VSLMOMENT5(1),VSLMOMENT5(2)
    !  print*, 'Change in sur prob (45-49 to 55-59) / Change in med expenditure (45-49 to 55-59) (Data: -0.03379) =', VSLMOMENT6(1),VSLMOMENT6(2)
    !  print*, 'Change in sur prob (50-54 to 60-64) / Change in med expenditure (50-54 to 60-64) (Data: -0.02842) =', VSLMOMENT7(1),VSLMOMENT7(2)
    !  print*, 'Change in sur prob (60-64 to 70-74) / Change in med expenditure (60-64 to 70-74) (Data: -0.1285) =',  VSLMOMENT9(1),VSLMOMENT9(2)

	print*, 'Saving "opt_tax_record.txt" '	
		
		write(54,"(220(F16.8,1X))") util_welfare_id,veil_welfare_id, par_welfare,insurance_value,insurance_value_single,insurance_value_couple,insurance_cons_value,insurance_cons_value_single,insurance_cons_value_couple,insurance_labor_value,insurance_labor_value_single,insurance_labor_value_couple,var_cons_earning_ratio,var_cons_earning_ratio_single,var_cons_earning_ratio_couple,tau_l_single, &
									tau_l_couple,lambda,lambda_couple,tau_s,premium_rate,SUBEHI(RETAGE),income_tax_rev,sales_tax_rev,insurance_premium,tax_revenue_single,tax_revenue_couple,SSEXP,gov_exp*OUTPUT,med_insur_exp,UB1,gov_exp,SSEXP/OUTPUT,med_insur_exp/OUTPUT,UB1/OUTPUT, &
								    (1.0+R)**0.2-1.0,wage,OUTPUT,Agg_labor,Agg_asset,Aggconsumption,Avg_H,Avg_M,hour_single_male,hour_single_female,hour_married_male,hour_married_female,LFP_single_female,LFP_married_female,avg_corr_family_earn, & 									
									cost_unc_singlemale,cost_unc_singlefemale,cost_unc_couple(1),cost_unc_couple(2),cost_ineq_singlemale,cost_ineq_singlefemale,cost_ineq_couple(1),cost_ineq_couple(2), &
									agg_certeqcons_singlemale,agg_certeqlab_singlemale,agg_certeqcons_singlefemale,agg_certeqlab_singlefemale,agg_certeqcons_couple(1),agg_certeqcons_couple(2),agg_certeqlab_couple(1),agg_certeqlab_couple(2), &
									AggC_singlemale,AggC_singlefemale,AggL_singlemale,AggL_singlefemale,AggC_couple,AggC_couple,AggL_couple(1),AggL_couple(2),AggC_singlemale_leicomp,AggC_singlefemale_leicomp,AggC_couple_leicomp(1),AggC_couple_leicomp(2),premium_rate

		print*, 'Input parameters'
		WRITE(*,"(12(F11.4,1X))") BETA_ANNUAL, fixcost_singlefemale, fixcost_marriedfemale, theta_single_male,theta_married_male,theta_single_female,theta_married_female, earn_corr

		
WRITE(4,*) sort_A(:)
		
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

OPEN(UNIT=33,FILE='survival_rates.txt')
write(33,*) S(9,1),S(10,1),S(11,1),S(12,1),S(13,1),S(14,1),S(15,1)
write(33,*) S(9,2),S(10,2),S(11,2),S(12,2),S(13,2),S(14,2),S(15,2)
CLOSE(UNIT=33)

OPEN(UNIT=27,FILE='lifecycle_wealth_population.txt')
		write(27,*) ALONG(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_consumption_population.txt')
		write(27,*) CLONG(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_earning_population.txt')
		write(27,*) ILONG(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_income_population.txt')
		write(27,*) TILONG(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_health_population.txt')
		write(27,*) HLONG(:)
CLOSE(27)
OPEN(UNIT=27,FILE='lifecycle_Med_population.txt')
		write(27,*) MLONG(:)
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
OPEN(UNIT=27,FILE='ageprofile_insurance_cons_shock_value_single_retire.txt')
		write(27,*) ageprofile_insurance_cons_shock_value_single_retire(:)
CLOSE(27)
OPEN(UNIT=27,FILE='ageprofile_insurance_cons_shock_value_couple_retire.txt')
		write(27,*) ageprofile_insurance_cons_shock_value_couple_retire(:)
CLOSE(27)
OPEN(UNIT=27,FILE='ageprofile_insurance_med_shock_value_single_retire.txt')
		write(27,*) ageprofile_insurance_med_shock_value_single_retire(:)
CLOSE(27)
OPEN(UNIT=27,FILE='ageprofile_insurance_med_shock_value_couple_retire.txt')
		write(27,*) ageprofile_insurance_med_shock_value_couple_retire(:)
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
SUBROUTINE single_SRCHFIVE01(AGE,IA,IH,IE,IG,IS,WAGEZ,JAMAX,JNMAX,JHMAX,JMMAX,VMAX, &
                      		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILM,IUM,ISKIPM,X3,BEQ)

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
INTEGER    ::  AGE,IA,IH,IE,IG,IS,JAMAX,JNMAX,JHMAX,JMMAX,&
               ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILM,IUM,ISKIPM
REAL(PREC) ::  WAGEZ,VMAX,X3,BEQ


!LOCA VARIABLES
!INTEGER    :: JA,JM, JN,JH
!REAL(PREC)  :: VTEMP, CONS,LEI, HEA,UTIL,HNEXT,SUR,XH,DH
INTEGER    :: JA, JN, JE, JH, JM
! REAL(PREC)  :: VTEMP, CONS,LEI, UTIL,HNEXT,SUR,XH,DH
REAL(PREC)  :: VTEMP, CONS,LEI, UTIL,HNEXT,XH,DH

DO JA=ILA,IUA,ISKIPA
!    DO JM=ILM,IUM,ISKIPM
        
        SELECTCASE(AGE)
        CASE(1:RETAGE-2)
		
            DO JN=ILN,IUN,ISKIPN                

				yd = (min(R*A(IA),d_c) +  (WAGEZ*N(JN) + UB(IS,IE,1)) )*lambda*(MIN( singlebendy, ( min(R*A(IA),d_c) +  (WAGEZ*N(JN) + UB(IS,IE,1)) )/avg_earnings ))**(-tau_l_single) &
					+ avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) +  (WAGEZ*N(JN) + UB(IS,IE,1)))/avg_earnings - singlebendy) &
					+ (1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans-lumpsum

				CONS = ( X3 + BEQ + yd - A(JA) - premium_rate*(WAGEZ*N(JN) + UB(IS,IE,1)) )/(1.0+tau_s)   !X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				
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
			       
            END DO

        !END IF 

        CASE(RETAGE-1)
            DO JN=ILN,IUN,ISKIPN
                								
		        yd = (min(R*A(IA),d_c) +  (WAGEZ*N(JN) + UB(IS,IE,1)))*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) +  (WAGEZ*N(JN) + UB(IS,IE,1)))/avg_earnings ))**(-tau_l_single) &
					+ avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) +  (WAGEZ*N(JN) + UB(IS,IE,1)))/avg_earnings - singlebendy) &			
					+ (1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans-lumpsum

				CONS = (X3 + BEQ + yd - A(JA) - premium_rate*(WAGEZ*N(JN) + UB(IS,IE,1)))/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)

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
						VTEMP = UTIL + BETA*( singleVR(AGE+1,JA,1,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + singleVR(AGE+1,JA,1,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 		
				
						EXIT  
					ELSEIF (i==NGRIDEH) THEN  
						JE = NGRIDEH 
						VTEMP = UTIL + BETA*singleVR(AGE+1,JA,1,JE,IG)

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
            END DO
        
        CASE(RETAGE:MAXAGE-1)   
			
			IF (AGE==RETAGE) THEN
				j=1
			ELSEIF (AGE==RETAGE+1) THEN 
				j=2
			ELSEIF (AGE==RETAGE+2) THEN
				j=3
			ELSE
				j=4
			END IF 

			DO JM=ILM,IUM,ISKIPM

				yd = (min(R*A(IA),d_c) +  WAGEZ )*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) +  WAGEZ )/avg_earnings))**(-tau_l_single) &
					+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+  WAGEZ )/avg_earnings - singlebendy) &
					+(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans+medicare-lumpsum

				CONS = (X3 + yd - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - premium_rate*WAGEZ )/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				LEI  = 1.00000000 

				IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN       
					UTIL= utility (cons,lei,IG,gov_exp*OUTPUT)
				ELSE
					UTIL=-1.E7
				END IF   
				
				HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
				IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
                    XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
                    JH = FLOOR(XH)
                    DH = XH-JH
				ELSE IF (HNEXT>HMAX) THEN
				    JH = 1
                    DH = 0.0000	       
				ELSE IF (HNEXT<HMIN) THEN
				    JH = NGRIDH
                    DH = 0.0000
                END IF
								
		
				IF (JH<NGRIDH) THEN
					! VTEMP = UTIL + BETA*SUR(AGE,IG,IH)*( (1.0-DH)*singleVR(AGE+1,JA,JH,IE,IG) + DH*singleVR(AGE+1,JA,JH+1,IE,IG) )
					VTEMP = UTIL + BETA*SUR(AGE,IG,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,IG)) + DH*SUM(P_h(JH+1,:,j)*singleVR(AGE+1,JA,:,IE,IG)) )
				ELSE 
					! VTEMP = UTIL + BETA*SUR(AGE,IG,IH)*singleVR(AGE+1,JA,JH,IE,IG)
					VTEMP = UTIL + BETA*SUR(AGE,IG,IH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,IG))
				END IF 
				! VTEMP = UTIL + BETA*S(AGE,IG)*singleVR(AGE+1,JA,IE,IG)   
				
				UPDATE2:  IF (VTEMP>=VMAX) THEN
					VMAX = VTEMP
					JAMAX = JA		
					JNMAX = 1	
					JMMAX = JM	   
					JHMAX = JH		  			   
				END IF UPDATE2
			END DO !JM

        CASE(MAXAGE)  			
			            
		    yd = (min(R*A(IA),d_c) +  WAGEZ)*lambda*(MIN(singlebendy, (min(R*A(IA),d_c) +  WAGEZ)/avg_earnings))**(-tau_l_single) &
				 +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+  WAGEZ)/avg_earnings - singlebendy) &
				 +(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans+medicare-lumpsum
			
			! CONS = (X3 + yd - A(JA))/(1.0+tau_s)	!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
			CONS = (X3 + yd - premium_rate*WAGEZ)/(1.0+tau_s)	! NO bequest

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
				JMMAX = 1
				JHMAX = NGRIDH		  
			    
            END IF UPDATE4
        
        END SELECT
 !   END DO
END DO



!IF ((AGE==44) .AND. (IA==8) .AND. (IH==44)) THEN
!PRINT*, '*****************'
!PRINT*, 'AGE=', AGE
!PRINT*, 'IA=', IA
!PRINT*, 'IH=', IH

!PRINT*, 'VMAX=', VMAX
!PRINT*, 'MAXINDEX=', MAXINDEX	
!PRINT*, '*****************'  

!PRINT*, '*****************'
!PRINT*, 'AGE=', AGE
!PRINT*, 'IA=', IA
!PRINT*, 'IH=', IH
!PRINT*, 'ILA=', ILA
!PRINT*, 'IUA=', IUA
!PRINT*, 'ILM=', ILM
!PRINT*, 'IUM=', IUM
!PRINT*, 'ILV=', ILV
!PRINT*, 'IUV=', IUV
!PRINT*, 'ILN=', ILN
!PRINT*, 'IUN=', IUN
!PRINT*, '*****************'

!END IF


!	 IF ((AGE==44) .AND. (IA==8) .AND. (IH==44)) THEN
!	 PRINT*, '*****************'
!	 PRINT*, 'AGE=', AGE
!    PRINT*, 'IA=', IA
!	 PRINT*, 'IH=', IH
!    PRINT*, 'VMAX=', VMAX
!	 PRINT*, 'IDCA=', JAMAX
!	 PRINT*, 'ILA=', ILA
!    PRINT*, 'IUA=', IUA
!    PRINT*, 'IDCM=', JMMAX
!    PRINT*, 'ILM=', ILM
!    PRINT*, 'IUM=', IUM
!     PRINT*, 'IDCV=', JVMAX
!     PRINT*, 'ILV=', ILV
!     PRINT*, 'IUV=', IUV
!     PRINT*, 'IDCN=', JNMAX	  
!	 PRINT*, 'ILN=', ILN
!     PRINT*, 'IUN=', IUN
!	 PRINT*, 'IDCH=', JHMAX
!	 PRINT*, '*****************'
!     PAUSE
!     END IF

END SUBROUTINE


SUBROUTINE couple_SRCHFIVE01(AGE,IA,IH,IE,IS1,IS2,WAGEZ1,WAGEZ2,JAMAX,JNMAX,JNMAX2,JHMAX,JMMAX,VMAX, &
                      		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2,ILM,IUM,ISKIPM,X3,BEQ)

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
INTEGER    ::  AGE,IA,IH,IE,IS1,IS2,JAMAX,JNMAX,JNMAX2,JHMAX,JMMAX, &
               ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2,ILM,IUM,ISKIPM
REAL(PREC) :: WAGEZ1,WAGEZ2,VMAX,X3,BEQ


!LOCA VARIABLES
!INTEGER    :: JA,JM, JN,JH
!REAL(PREC)  :: VTEMP, CONS,LEI, HEA,UTIL,HNEXT,SUR,XH,DH
INTEGER    :: JA, JN1, JN2, JE, JH, JM
! REAL(PREC)  :: VTEMP, CONS,LEI1,LEI2, UTIL,HNEXT,SUR,XH,DH
REAL(PREC)  :: VTEMP, CONS,LEI1,LEI2, UTIL,HNEXT,XH,DH

SELECT CASE(couple_labor)
CASE(0)	
	DO JA=ILA,IUA,ISKIPA

        SELECT CASE(AGE)
        CASE(1:RETAGE-2)
						
			JN1=NGRIDA+AGE
			JN2=NGRIDA+RETAGE-1+AGE

			yd = max(yd_MFJ(  (WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) + min(R*A(IA),d_c), IA), yd_MFS(  (WAGEZ1*N(JN1)+UB(IS1,IE,2)) + min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  (WAGEZ2*N(JN2)+UB(IS2,IE,2))+ min(R*A(IA),d_c)/2 ,IA) )
			
			CONS = ( X3 + 2*BEQ + yd + 2*(gov_trans-lumpsum) - A(JA) -  premium_rate*(WAGEZ1*N(JN1)+UB(IS1,IE,2)+WAGEZ2*N(JN2)+UB(IS2,IE,2)) )/(1.0+tau_s)   

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
			
			JN1=NGRIDA+AGE
			JN2=NGRIDA+RETAGE-1+AGE
			
			yd = max(yd_MFJ(  (WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) + min(R*A(IA),d_c), IA), yd_MFS(  (WAGEZ1*N(JN1)+UB(IS1,IE,2))+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  (WAGEZ2*N(JN2)+UB(IS2,IE,2))+ min(R*A(IA),d_c)/2 ,IA) )

			CONS = (X3 + 2*BEQ + yd + 2*(gov_trans-lumpsum) - A(JA) - premium_rate*(WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)))/(1.0+tau_s)		

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
					VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,1,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,1,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
													
					EXIT 
				ELSEIF (i==NGRIDEH) THEN  
					JE = NGRIDEH  
					VTEMP = UTIL + BETA*coupleVR(AGE+1,JA,1,JE)
					
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

			IF (AGE==RETAGE) THEN
				j=1
			ELSEIF (AGE==RETAGE+1) THEN 
				j=2
			ELSEIF (AGE==RETAGE+2) THEN
				j=3
			ELSE
				j=4
			END IF 

			DO JM=ILM,IUM,ISKIPM  

				yd = max(yd_MFJ( (WAGEZ1 + WAGEZ2) + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA) + yd_MFS(WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

				CONS = (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - premium_rate*(WAGEZ1 + WAGEZ2) )/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				LEI1  = 1.00000000 
				LEI2  = 1.00000000 

				IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN       
					UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
				ELSE
					UTIL=-1.E7
				END IF   

				HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
				IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
                    XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
                    JH = FLOOR(XH)
                    DH = XH-JH
				ELSE IF (HNEXT>HMAX) THEN
				    JH = 1
                    DH = 0.0000	       
				ELSE IF (HNEXT<HMIN) THEN
				    JH = NGRIDH
                    DH = 0.0000
                END IF
				
				
				IF (JH<NGRIDH) THEN
					! VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*coupleVR(AGE+1,JA,JH,IE)+DH*coupleVR(AGE+1,JA,JH+1,IE) ) &
					! 		+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*singleVR(AGE+1,JA,JH,IE,1)+DH*singleVR(AGE+1,JA,JH+1,IE,1) ) &
					! 		+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*( (1.0-DH)*singleVR(AGE+1,JA,JH,IE,2)+DH*singleVR(AGE+1,JA,JH+1,IE,2) )

					VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*coupleVR(AGE+1,JA,:,IE))+DH*SUM(P_h(JH+1,:,j)*coupleVR(AGE+1,JA,:,IE)) ) &
							+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,1))+DH*SUM(P_h(JH+1,:,j)*singleVR(AGE+1,JA,:,IE,1)) ) &
							+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,2))+DH*SUM(P_h(JH+1,:,j)*singleVR(AGE+1,JA,:,IE,2)) )
				ELSE 
					! VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*coupleVR(AGE+1,JA,JH,IE) & 
					! 		+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*singleVR(AGE+1,JA,JH,IE,1) &
					! 		+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*singleVR(AGE+1,JA,JH,IE,2)

					VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*coupleVR(AGE+1,JA,:,IE)) & 
							+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,1)) &
							+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,2))
				END IF 
				! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,JH,IE) & 
				! 			+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,JH,IE,1) &
				! 			+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,JH,IE,2)

					UPDATE2a:  IF (VTEMP>=VMAX) THEN
						VMAX = VTEMP
						JAMAX = JA	
						JMMAX = JM		   
						JNMAX = 1	
						JNMAX2 = 1		  
						JHMAX = JH				   
					END IF UPDATE2a
			END DO	!JM

        CASE(MAXAGE)  			
			            
			yd = max(yd_MFJ(  (WAGEZ1 + WAGEZ2) + min(R*A(IA),d_c), IA), yd_MFS(  WAGEZ1 + min(R*A(IA),d_c)/2,IA)+yd_MFS(  WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )
			
			! CONS = (X3 + yd - A(JA))/(1.0+tau_s)	!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
			CONS = (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)
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
				JMMAX = 1
				JHMAX = NGRIDH	

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
				
				yd = max(yd_MFJ(  (WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) + min(R*A(IA),d_c), IA), yd_MFS(  (WAGEZ1*N(JN1)+UB(IS1,IE,2))+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  (WAGEZ2*N(JN2)+UB(IS2,IE,2))+ min(R*A(IA),d_c)/2 ,IA) )

				CONS = ( X3 + 2*BEQ + yd + 2*(gov_trans-lumpsum) - A(JA) - premium_rate*(WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) )/(1.0+tau_s)   !X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				
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
				
				yd = max(yd_MFJ(  (WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) + min(R*A(IA),d_c), IA), yd_MFS(  (WAGEZ1*N(JN1)+UB(IS1,IE,2))+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  (WAGEZ2*N(JN2)+UB(IS2,IE,2))+ min(R*A(IA),d_c)/2 ,IA) )

				CONS = (X3 + 2*BEQ + yd + 2*(gov_trans-lumpsum) - A(JA) - premium_rate*(WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)))/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)

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
						VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,1,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,1,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
														
						EXIT 
					ELSEIF (i==NGRIDEH) THEN  
						JE = NGRIDEH  
						VTEMP = UTIL + BETA*coupleVR(AGE+1,JA,1,JE)
						
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

			IF (AGE==RETAGE) THEN
				j=1
			ELSEIF (AGE==RETAGE+1) THEN 
				j=2
			ELSEIF (AGE==RETAGE+2) THEN
				j=3
			ELSE
				j=4
			END IF 

			DO JM=ILM,IUM,ISKIPM  
				! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
				! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - couplebendy) &
				! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

				yd = max(yd_MFJ(  (WAGEZ1 + WAGEZ2) + min(R*A(IA),d_c), IA), yd_MFS(  WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

				CONS = (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - premium_rate*(WAGEZ1 + WAGEZ2) )/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				LEI1  = 1.00000000 
				LEI2  = 1.00000000 

				IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN       
					UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
				ELSE
					UTIL=-1.E7
				END IF   

				HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
				IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
                    XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
                    JH = FLOOR(XH)
                    DH = XH-JH
				ELSE IF (HNEXT>HMAX) THEN
				    JH = 1
                    DH = 0.0000	       
				ELSE IF (HNEXT<HMIN) THEN
				    JH = NGRIDH
                    DH = 0.0000
                END IF
				

				IF (JH<NGRIDH) THEN
					! VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*coupleVR(AGE+1,JA,JH,IE)+DH*coupleVR(AGE+1,JA,JH+1,IE) ) &
					! 		+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*singleVR(AGE+1,JA,JH,IE,1)+DH*singleVR(AGE+1,JA,JH+1,IE,1) ) &
					! 		+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*( (1.0-DH)*singleVR(AGE+1,JA,JH,IE,2)+DH*singleVR(AGE+1,JA,JH+1,IE,2) )

					VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*coupleVR(AGE+1,JA,:,IE))+DH*SUM(P_h(JH+1,:,j)*coupleVR(AGE+1,JA,:,IE)) ) &
							+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,1))+DH*SUM(P_h(JH+1,:,j)*singleVR(AGE+1,JA,:,IE,1)) ) &
							+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,2))+DH*SUM(P_h(JH+1,:,j)*singleVR(AGE+1,JA,:,IE,2)) )
				ELSE 
					! VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*coupleVR(AGE+1,JA,JH,IE) & 
					! 		+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*singleVR(AGE+1,JA,JH,IE,1) &
					! 		+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*singleVR(AGE+1,JA,JH,IE,2) 

					VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*coupleVR(AGE+1,JA,:,IE)) & 
							+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,1)) &
							+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,2))
				END IF 		
					! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
					! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
					! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) 
					
					UPDATE2b:  IF (VTEMP>=VMAX) THEN
						VMAX = VTEMP
						JAMAX = JA		
						JMMAX = JM	   
						JNMAX = 1
						JNMAX2 = 1		
						JHMAX = JH		  			   
					END IF UPDATE2b
			END DO	!JM

        CASE(MAXAGE)  			
			            
		    ! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
			! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2 - couplebendy) &
			! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

			yd = max(yd_MFJ(  (WAGEZ1 + WAGEZ2) + min(R*A(IA),d_c), IA), yd_MFS(  WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )
			
			! CONS = (X3 + yd - A(JA))/(1.0+tau_s)	!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
			CONS = (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)
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
				JMMAX = 1
				JHMAX = NGRIDH	  
			    
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
				
				yd = max(yd_MFJ(  (WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) + min(R*A(IA),d_c), IA), yd_MFS(  (WAGEZ1*N(JN1)+UB(IS1,IE,2))+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  (WAGEZ2*N(JN2)+UB(IS2,IE,2))+ min(R*A(IA),d_c)/2 ,IA) )

				CONS = ( X3 + 2*BEQ + yd + 2*(gov_trans-lumpsum) - A(JA) - premium_rate*(WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) )/(1.0+tau_s)
				
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
					
					yd = max(yd_MFJ(  (WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)) + min(R*A(IA),d_c), IA), yd_MFS(  (WAGEZ1*N(JN1)+UB(IS1,IE,2))+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  (WAGEZ2*N(JN2)+UB(IS2,IE,2))+ min(R*A(IA),d_c)/2 ,IA) )

					CONS = (X3 + 2*BEQ + yd + 2*(gov_trans-lumpsum) - A(JA) - premium_rate*(WAGEZ1*N(JN1)+UB(IS1,IE,2) + WAGEZ2*N(JN2)+UB(IS2,IE,2)))/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)

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
							VTEMP = UTIL + BETA*( coupleVR(AGE+1,JA,1,JE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + coupleVR(AGE+1,JA,1,JE+1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
															
							EXIT 
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH  
							VTEMP = UTIL + BETA*coupleVR(AGE+1,JA,1,JE)
							
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

			IF (AGE==RETAGE) THEN
				j=1
			ELSEIF (AGE==RETAGE+1) THEN 
				j=2
			ELSEIF (AGE==RETAGE+2) THEN
				j=3
			ELSE
				j=4
			END IF 

			DO JM=ILM,IUM,ISKIPM 
				! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
				! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - couplebendy) &
				! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

				yd = max(yd_MFJ(  (WAGEZ1 + WAGEZ2) + min(R*A(IA),d_c), IA), yd_MFS(  WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

				CONS = (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - premium_rate*(WAGEZ1 + WAGEZ2) )/(1.0+tau_s)		!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
				LEI1  = 1.00000000 
				LEI2  = 1.00000000 

				IF  ((CONS>=CMIN) .AND. (LEI1>=LEIMIN) .AND. (LEI2>=LEIMIN)) THEN       
					UTIL= couple_utility (cons,lei1, lei2,gov_exp*OUTPUT)
				ELSE
					UTIL=-1.E7
				END IF   
				
				HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
				IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
                    XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
                    JH = FLOOR(XH)
                    DH = XH-JH
				ELSE IF (HNEXT>HMAX) THEN
				    JH = 1
                    DH = 0.0000	       
				ELSE IF (HNEXT<HMIN) THEN
				    JH = NGRIDH
                    DH = 0.0000
                END IF
 

				IF (JH<NGRIDH) THEN
					! VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*coupleVR(AGE+1,JA,JH,IE)+DH*coupleVR(AGE+1,JA,JH+1,IE) ) &
					! 		+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*singleVR(AGE+1,JA,JH,IE,1)+DH*singleVR(AGE+1,JA,JH+1,IE,1) ) &
					! 		+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*( (1.0-DH)*singleVR(AGE+1,JA,JH,IE,2)+DH*singleVR(AGE+1,JA,JH+1,IE,2) )

					VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*coupleVR(AGE+1,JA,:,IE))+DH*SUM(P_h(JH+1,:,j)*coupleVR(AGE+1,JA,:,IE)) ) &
							+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,1))+DH*SUM(P_h(JH+1,:,j)*singleVR(AGE+1,JA,:,IE,1)) ) &
							+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,2))+DH*SUM(P_h(JH+1,:,j)*singleVR(AGE+1,JA,:,IE,2)) )

				ELSE 
					! VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*coupleVR(AGE+1,JA,JH,IE) & 
					! 		+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*singleVR(AGE+1,JA,JH,IE,1) &
					! 		+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*singleVR(AGE+1,JA,JH,IE,2) 

					VTEMP = UTIL + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*coupleVR(AGE+1,JA,:,IE)) & 
							+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,1)) &
							+ BETA*(1-SUR(AGE,1,IH))*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*singleVR(AGE+1,JA,:,IE,2))
				END IF 			
					! VTEMP = UTIL + BETA*S(AGE,1)*S(AGE,2)*coupleVR(AGE+1,JA,IE) & 
					! 		+ BETA*S(AGE,1)*(1-S(AGE,2))*singleVR(AGE+1,JA,IE,1) &
					! 		+ BETA*S(AGE,2)*(1-S(AGE,1))*singleVR(AGE+1,JA,IE,2) 
					
					UPDATE2c:  IF (VTEMP>=VMAX) THEN
						VMAX = VTEMP
						JAMAX = JA			   
						JMMAX = JM	
						JNMAX = 1
						JNMAX2 = 1
						JHMAX = JH				  			   
					END IF UPDATE2c
			END DO	!JM

        CASE(MAXAGE)  			
			            
		    ! yd = lambda*(MIN(couplebendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l_couple) &
			! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2 - couplebendy) &
			! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0) + 2*gov_trans

			yd = max(yd_MFJ(  (WAGEZ1 + WAGEZ2) + min(R*A(IA),d_c), IA), yd_MFS(  WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS(  WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )
			
			! CONS = (X3 + yd - A(JA))/(1.0+tau_s)	!X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
			CONS = (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - premium_rate*(WAGEZ1 + WAGEZ2))/(1.0+tau_s)
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
				JMMAX = 1
				JHMAX = NGRIDH	  
			    
            END IF UPDATE4c
        
        END SELECT !AGE

		END DO !JN2
	END DO	!JA
			
END SELECT ! labor supply


END SUBROUTINE


!**************************************************************************************************************

!SUBROUTINE BRACKET01(AGE,IA,IH,IS, WAGEZ)
SUBROUTINE single_BRACKET01(AGE,IA,IH,IE,IG,IS,WAGEZ)
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
INTEGER    :: AGE,IA,IE,IG,IS,IH
REAL(PREC) :: WAGEZ
!LOCAL VARIABLES
!INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JMMAX,JHMAX,&
!              ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN
INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JHMAX,JMMAX,&
              ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILM,IUM,ISKIPM
REAL(PREC) :: X3,VMAX 


     index_SRCHFIVE01 = 0

	  X3 = A(IA)

     VMAX = -1.E6
     JAMAX = 1
	 JMMAX = 1
	 JNMAX = 1
	 JHMAX = 1

     ILA = 1
     IUA = NGRIDA
     ISKIPA = (NGRIDA - 1)/4

	 ILM = 1
     IUM = NGRIDA
     ISKIPM = (NGRIDA - 1)/4

	 ILN = 1
	 IUN = NGRIDA
	 ISKIPN = (NGRIDA - 1)/4
	

!101  CALL single_SRCHFIVE01 (AGE,IH,IS,WAGEZ,JAMAX,JMMAX,JNMAX,JHMAX,VMAX, &
!                     ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN,X3)  !  Updates VMAX and JAMAX  
101  CALL single_SRCHFIVE01 (AGE,IA,IH,IE,IG,IS,WAGEZ,JAMAX,JNMAX,JHMAX,JMMAX,VMAX, &
                     		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILM,IUM,ISKIPM,X3,BEQ)  !  Updates VMAX and JAMAX    					 

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


	 NARROW05:  IF (ISKIPN>1) THEN

        !NARROW06:  IF ((JNMAX>1).AND.(JNMAX<NGRIDH)) THEN
		NARROW06:  IF ((JNMAX>1).AND.(JNMAX<NGRIDA)) THEN
           ILN = JNMAX - ISKIPN
           IUN = JNMAX + ISKIPN
           ISKIPN = ISKIPN/2
        ELSE IF (JNMAX==1) THEN
           IF (ISKIPN>=4) THEN
              ISKIPN = ISKIPN/4
              IUN = ILN + 4*ISKIPN
           ELSE IF (ISKIPN==2) THEN
              ISKIPN = 1
              IUN = 2
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW08'
           END IF
        ELSE
           IF (ISKIPN>=4) THEN
              ISKIPN = ISKIPN/4
              ILN = IUN - 4*ISKIPN
           ELSE IF (ISKIPN==2) THEN
              ISKIPN = 1
              !ILN = NGRIDH - 1
			  ILN = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW08'
           END IF
        END IF NARROW06

          IF (ILN<1) PRINT *, 'Error:  ILN<1 in Subroutine BRACKET'
          !IF (ILN>NGRIDH) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'
		  IF (ILN>NGRIDA) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'

!        GO TO 101
        
     END IF NARROW05



	IF (AGE >= RETAGE) THEN	
	 NARROW03:  IF (ISKIPM>1) THEN

        NARROW04:  IF ((JMMAX>1).AND.(JMMAX<NGRIDA)) THEN
           ILM = JMMAX - ISKIPM
           IUM = JMMAX + ISKIPM
           ISKIPM = ISKIPM/2
        ELSE IF (JMMAX==1) THEN
           IF (ISKIPM>=4) THEN
              ISKIPM = ISKIPM/4
              IUM = ILM + 4*ISKIPM
           ELSE IF (ISKIPM==2) THEN
              ISKIPM = 1
              IUM = 2
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW04'
           END IF
        ELSE
           IF (ISKIPM>=4) THEN
              ISKIPM = ISKIPM/4
              ILM = IUM - 4*ISKIPM
           ELSE IF (ISKIPM==2) THEN
              ISKIPM = 1
              ILM = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW04'
           END IF
        END IF NARROW04

          IF (ILM<1) PRINT *, 'Error:  ILM<1 in Subroutine BRACKET'
          IF (ILM>NGRIDA) PRINT *, 'Error:  ILM>NGRIDA in Subroutine BRACKET'

     END IF NARROW03

	END IF 


	IF (AGE < RETAGE) THEN	

	 IF (ISKIPA==1 .AND. ISKIPN==1)  THEN
		index_SRCHFIVE01 = 1+index_SRCHFIVE01
	 ELSE
		index_SRCHFIVE01 = 0
	 END IF
	
	 IF (index_SRCHFIVE01 < 2) THEN
		GO TO 101
	 END IF

	ELSEIF (AGE >= RETAGE) THEN	 

		IF (ISKIPA==1 .AND. ISKIPN==1 .AND. ISKIPM==1)  THEN
            index_SRCHFIVE01 = 1+index_SRCHFIVE01
		ELSE
            index_SRCHFIVE01 = 0
        END IF
        
		IF (index_SRCHFIVE01 < 2) THEN
           GO TO 101
		END IF

    END IF 


   	
	 IF (AGE<RETAGE) THEN	 
	 	singleVW(AGE,IA,IS,IE,IG) = VMAX
	 	singleIDCWA(AGE,IA,IS,IE,IG) = JAMAX
	 	singleIDCWN(AGE,IA,IS,IE,IG) = JNMAX
	 ELSE	 
	 	singleVR(AGE,IA,IH,IE,IG) = VMAX
     	singleIDCRA(AGE,IA,IH,IE,IG) = JAMAX
	 	singleIDCRN(AGE,IA,IH,IE,IG) = 1
		singleIDCRM(AGE,IA,IH,IE,IG) = JMMAX
		singleIDCRH(AGE,IA,IH,IE,IG) = JHMAX
	 END IF
	 

END SUBROUTINE


SUBROUTINE couple_BRACKET01(AGE,IA,IH,IE,IS1,IS2,WAGEZ1,WAGEZ2)
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
INTEGER    :: AGE,IA,IS1,IS2,IE,IH
REAL(PREC) :: WAGEZ1,WAGEZ2
!LOCAL VARIABLES
!INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JMMAX,JHMAX,&
!              ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN
INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JNMAX2,JHMAX,JMMAX,&
              ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2,ILM,IUM,ISKIPM
REAL(PREC) :: X3,VMAX 

     index_SRCHFIVE01 = 0

	  X3 = A(IA)

     VMAX = -1.E6
     JAMAX = 1
	 JMMAX = 1
	 JNMAX = 1
	 JNMAX2 = 1
	 JHMAX = 1

     ILA = 1
     IUA = NGRIDA
     ISKIPA = (NGRIDA - 1)/4

	 ILM = 1
     IUM = NGRIDA
     ISKIPM = (NGRIDA - 1)/4
	 
	 ILN = 1
	 ILN2 = 1
	 IUN = NGRIDA
	 IUN2 = NGRIDA
	 ISKIPN = (NGRIDA - 1)/4
	 ISKIPN2 = (NGRIDA - 1)/4
	

!101  CALL single_SRCHFIVE01 (AGE,IH,IS,WAGEZ,JAMAX,JMMAX,JNMAX,JHMAX,VMAX, &
!                     ILA,IUA,ISKIPA,ILM,IUM,ISKIPM,ILN,IUN,ISKIPN,X3)  !  Updates VMAX and JAMAX  
201  CALL couple_SRCHFIVE01 (AGE,IA,IH,IE,IS1,IS2,WAGEZ1,WAGEZ2,JAMAX,JNMAX,JNMAX2,JHMAX,JMMAX,VMAX, &
                     		 ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,ILN2,IUN2,ISKIPN2,ILM,IUM,ISKIPM,X3,BEQ)  !  Updates VMAX and JAMAX    					 

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



	 NARROW03:  IF (ISKIPN2>1) THEN
       
		NARROW04:  IF ((JNMAX2>1).AND.(JNMAX2<NGRIDA)) THEN
           ILN2 = JNMAX2 - ISKIPN2
           IUN2 = JNMAX2 + ISKIPN2
           ISKIPN2 = ISKIPN2/2
        ELSE IF (JNMAX2==1) THEN
           IF (ISKIPN2>=4) THEN
              ISKIPN2 = ISKIPN2/4
              IUN2 = ILN2 + 4*ISKIPN2
           ELSE IF (ISKIPN2==2) THEN
              ISKIPN2 = 1
              IUN2 = 2
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW04'
           END IF
        ELSE
           IF (ISKIPN2>=4) THEN
              ISKIPN2 = ISKIPN2/4
              ILN2 = IUN2 - 4*ISKIPN2
           ELSE IF (ISKIPN2==2) THEN
              ISKIPN2 = 1
              !ILN = NGRIDH - 1
			  ILN2 = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW04'
           END IF
        END IF NARROW04

          IF (ILN2<1) PRINT *, 'Error:  ILN2<1 in Subroutine BRACKET'
          !IF (ILN>NGRIDH) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'
		  IF (ILN2>NGRIDA) PRINT *, 'Error:  ILN2>NGRIDA in Subroutine BRACKET'


     END IF NARROW03



	 NARROW05:  IF (ISKIPN>1) THEN

        
		NARROW06:  IF ((JNMAX>1).AND.(JNMAX<NGRIDA)) THEN
           ILN = JNMAX - ISKIPN
           IUN = JNMAX + ISKIPN
           ISKIPN = ISKIPN/2
        ELSE IF (JNMAX==1) THEN
           IF (ISKIPN>=4) THEN
              ISKIPN = ISKIPN/4
              IUN = ILN + 4*ISKIPN
           ELSE IF (ISKIPN==2) THEN
              ISKIPN = 1
              IUN = 2
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW06'
           END IF
        ELSE
           IF (ISKIPN>=4) THEN
              ISKIPN = ISKIPN/4
              ILN = IUN - 4*ISKIPN
           ELSE IF (ISKIPN==2) THEN
              ISKIPN = 1
              !ILN = NGRIDH - 1
			  ILN = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW06'
           END IF
        END IF NARROW06

          IF (ILN<1) PRINT *, 'Error:  ILN<1 in Subroutine BRACKET'
          !IF (ILN>NGRIDH) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'
		  IF (ILN>NGRIDA) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'

!        GO TO 101
        
     END IF NARROW05


	! IF (AGE >= RETAGE) THEN	
	 NARROW07:  IF (ISKIPM>1) THEN

        NARROW08:  IF ((JMMAX>1).AND.(JMMAX<NGRIDA)) THEN
           ILM = JMMAX - ISKIPM
           IUM = JMMAX + ISKIPM
           ISKIPM = ISKIPM/2
        ELSE IF (JMMAX==1) THEN
           IF (ISKIPM>=4) THEN
              ISKIPM = ISKIPM/4
              IUM = ILM + 4*ISKIPM
           ELSE IF (ISKIPM==2) THEN
              ISKIPM = 1
              IUM = 2
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW08'
           END IF
        ELSE
           IF (ISKIPM>=4) THEN
              ISKIPM = ISKIPM/4
              ILM = IUM - 4*ISKIPM
           ELSE IF (ISKIPM==2) THEN
              ISKIPM = 1
              ILM = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW08'
           END IF
        END IF NARROW08

          IF (ILM<1) PRINT *, 'Error:  ILM<1 in Subroutine BRACKET'
          IF (ILM>NGRIDA) PRINT *, 'Error:  ILM>NGRIDA in Subroutine BRACKET'

     END IF NARROW07

	! END IF 
      

	! IF (AGE < RETAGE) THEN  

	! 	IF (ISKIPA==1 .AND. ISKIPN==1 .AND. ISKIPN2==1)  THEN
    !         index_SRCHFIVE01 = 1+index_SRCHFIVE01
	! 	ELSE
    !         index_SRCHFIVE01 = 0
    !     END IF
        
	! 	IF (index_SRCHFIVE01 < 2) THEN
    !        GO TO 201
	! 	END IF

	! ELSEIF (AGE >= RETAGE) THEN	

	! 	IF (ISKIPA==1 .AND. ISKIPN==1 .AND. ISKIPM==1)  THEN
    !         index_SRCHFIVE01 = 1+index_SRCHFIVE01
	! 	ELSE
    !         index_SRCHFIVE01 = 0
    !     END IF
        
	! 	IF (index_SRCHFIVE01 < 2) THEN
    !        GO TO 201
	! 	END IF
	
	! END IF 

	IF (ISKIPA==1 .AND. ISKIPN==1 .AND. ISKIPN2==1 .AND. ISKIPM==1)  THEN
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
	 	coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = JNMAX
	 	coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = JNMAX2
	ELSE	 
	 	coupleVR(AGE,IA,IH,IE) = VMAX
     	coupleIDCRA(AGE,IA,IH,IE) = JAMAX
	 	coupleIDCRN(AGE,IA,IH,IE) = 1
		coupleIDCRM(AGE,IA,IH,IE) = JMMAX
		coupleIDCRH(AGE,IA,IH,IE) = JHMAX
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
INTEGER    ::  AGE,IA,IS,IS1,IS2,IE,IG,IH
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
		      		singleIDCWN(AGE,IA,IS,IE,IG) = -1

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
					coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = -1
 					coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = -1

				END DO 
			END DO
        END DO
    END DO
END DO


DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH
				DO IG=1,2
				
					singleVR(AGE,IA,IH,IE,IG) = -10000.0000
					!marriageVR(AGE,IA,IE,IG) = -10000.0000  
					singleIDCRA(AGE,IA,IH,IE,IG) = -1
					singleIDCRN(AGE,IA,IH,IE,IG) = -1
					singleIDCRM(AGE,IA,IH,IE,IG) = -1
					singleIDCRH(AGE,IA,IH,IE,IG) = -1
					
				END DO		
			END DO 
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH
				
				coupleVR(AGE,IA,IH,IE) = -10000.0000
				coupleIDCRA(AGE,IA,IH,IE) = -1
				coupleIDCRN(AGE,IA,IH,IE) = -1
				coupleIDCRM(AGE,IA,IH,IE) = -1
				coupleIDCRH(AGE,IA,IH,IE) = -1

			END DO					
        END DO 
    END DO
END DO
!************************************
!   			Retirees
!************************************

!$OMP PARALLEL DEFAULT(NONE) &
!$OMP & PRIVATE(WAGEZ,WAGEZ1, WAGEZ2,IS,IS1,IS2,IE,IG,AGE,IA,IH) &
!$OMP & SHARED(singleVW,coupleVW,singleVR,coupleVR,singleIDCWA,coupleIDCWA,singleIDCWN,coupleIDCWN,singleIDCRA,coupleIDCRA,singleIDCRN,coupleIDCRN,singleIDCRM,singleIDCRH,coupleIDCRM,coupleIDCRH, &
!$OMP &        EFFLONG,W,wage,avg_earnings)

IS=1   
DO AGE=MAXAGE,RETAGE,-1
	DO IH=1,NGRIDH
		DO IE=1,NGRIDEH
			WAGEZ = SS(IE) 
			!$OMP DO
			DO IG=1,2
				
				DO IA=1,NGRIDA					
					CALL single_BRACKET01(AGE,IA,IH,IE,IG,IS,WAGEZ)	 ! Finds optimal asset choice for this state
				END DO
				
			END DO
			!$OMP END DO
		END DO  
	END DO 
END DO

DO AGE=RETAGE-1,1,-1       
	DO IG=1,2
		DO IS =1,nn   
			!$OMP DO				
			DO IE=1,NGRIDEH	
					
				DO IA=1,NGRIDA       			                   
					WAGEZ = WAGE*EFFLONG(AGE,IG)*W(IS,IG)
                	CALL single_BRACKET01(AGE,IA,IH,IE,IG,IS,WAGEZ)
				END DO 
				
            END DO
			!$OMP END DO
        END DO	
    END DO
END DO 


!******************************************************************************************
! 					Value of being in a marriage for an individual
!******************************************************************************************	 	 
! DO AGE=MAXAGE,RETAGE,-1
!     ! WAGEZ1 = SS
! 	! WAGEZ2 = SS           
		
	
! 	DO IA=1,NGRIDA
! 		DO IE=1,NGRIDEH

! 			JA = coupleIDCRA(AGE,IA,IE)
! 			WAGEZ1 = SS(IE)
! 			WAGEZ2 = SS(IE)  

! 			! yd = (lambda+delta_lambda)*(MIN(bendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l) &
! 			!  +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - bendy) &
! 			!  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

! 			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

! 			! CONS = (A(IA) + yd + 2*gov_trans - A(JA))/(1.0+tau_s)
! 			LEI = 1.0
			
! 			IF (AGE==MAXAGE) THEN
! 				CONS = (A(IA) + yd + 2*gov_trans)/(1.0+tau_s)
! 				marriageVR(AGE,IA,IE,1) = utility(CONS, LEI, 1) 
! 				marriageVR(AGE,IA,IE,2) = utility(CONS, LEI, 2)
! 			ELSE
! 				CONS = (A(IA) + yd + 2*gov_trans - A(JA))/(1.0+tau_s)
! 				marriageVR(AGE,IA,IE,1) = utility(CONS, LEI, 1) + BETA*S(AGE,1)*S(AGE,2)*marriageVR(AGE+1,JA,IE,1) &
! 										+ BETA*S(AGE,1)*(1.0-S(AGE,2))*singleVR(AGE+1,JA,IE,1)

! 				marriageVR(AGE,IA,IE,2) = utility(CONS, LEI, 2) + BETA*S(AGE,1)*S(AGE,2)*marriageVR(AGE+1,JA,IE,2) &
! 										+ BETA*S(AGE,2)*(1.0-S(AGE,1))*singleVR(AGE+1,JA,IE,2)
! 			END IF 
! 		END DO 
! 	END DO
	
! END DO
!******************************************************************************************	

!*******************************************************
!   				Working-age agents
!*******************************************************
!===================================================================================================================
!Solution Algorithm:
!	During the working age, the value functions are interconnected, so we need to
!	solve for each of them at a given time t. For each period, working backwards over
!	the life cycle, we apply the following solution strategy:
!
!	1. For any given time period, take as given the value of being a single person in a
!		married couple for next period, which has been previously computed. Compute
!		the value function of being single.

! 	2. Given the value function of being single, compute the value function of the
! 		couple for the same age.

! 	3. Given the optimal policy function of the couple, solve for the discounted present
! 		value of utility for each of the spouses in a marriage.

! 	4. Keep going back in time until the first period we solve for.
!===================================================================================================================

IS1=1
IS2=1
DO AGE=MAXAGE,RETAGE,-1
	DO IH=1,NGRIDH
		!$OMP DO
		DO IE=1,NGRIDEH
			WAGEZ1 = SS(IE)
			WAGEZ2 = SS(IE)             	
			
			DO IA=1,NGRIDA			   
				CALL couple_BRACKET01(AGE,IA,IH,IE,IS1,IS2,WAGEZ1,WAGEZ2)
			END DO
			
		END DO
		!$OMP END DO
	END DO 
END DO
!$OMP END PARALLEL

DO AGE=RETAGE-1,1,-1
	DO IS1 =1,nn   
		DO IS2 =1,nn
			DO IE=1,NGRIDEH
				WAGEZ1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)
				WAGEZ2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)
				DO IA=1,NGRIDA			                              					
                	CALL couple_BRACKET01(AGE,IA,IH,IE,IS1,IS2,WAGEZ1,WAGEZ2)
				END DO 
				
			END DO
        END DO
    END DO
END DO


	!******************************************************************************************
	! 					Value of being in a marriage for an individual
	!******************************************************************************************	
	
	! DO IA =1,NGRIDA			   
    !     DO IS1 = 1,nn   
	! 		DO IS2 = 1,nn
	! 			DO IE=1,NGRIDEH

	! 				JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
	! 				JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
	! 				JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2) 						
	! 				WAGEZ1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)
	! 				WAGEZ2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)

    !             	! yd = lambda*(MIN(bendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l) &
	! 			 	! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - bendy) &
	! 				! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)
					
	! 				yd = max(yd_MFJ( WAGEZ1*JN1 + WAGEZ2*JN2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*JN1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*JN2 + min(R*A(IA),d_c)/2 ,IA) )
							
	! 				CONS = (A(IA) + yd + 2*BEQ + 2*gov_trans - A(JA))/(1.0+tau_s)

	! 				LEI1 = 1.00000000 - N(JN1) 
	! 				LEI2 = 1.00000000 - N(JN2)

														
	! 					! splitasset = A(JA)/2.0
	! 					! do i=IA,NGRIDA
	! 					! 	if(A(i) > splitasset) then	
	! 					! 		Alower = i-1
	! 					! 		go to 132
	! 					! 	elseif (A(i) == splitasset) then	
	! 					! 		Alower = i
	! 					! 		go to 132
	! 					! 	end if 
	! 					! end do
	! 					! 132 continue 
										
	! 				IF (AGE==RETAGE-1) THEN
	! 						! interpolate_singleVR1 = singleVR(AGE+1,Alower,1)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
	! 						! 						+ singleVR(AGE+1,Alower+1,1)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))

	! 						! interpolate_singleVR2 = singleVR(AGE+1,Alower,2)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
	! 						! 						+ singleVR(AGE+1,Alower+1,2)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))		
							
	! 						! marriageVW(AGE,IA,IS1,IS2,1) = utility(CONS, coupleIDCWN(AGE,IA,IS1,IS2,1)) + BETA*(1.0-divorce)*marriageVR(AGE+1,JA,1) &
	! 						! 								+ BETA*divorce*interpolate_singleVR1
							
	! 						! marriageVW(AGE,IA,IS1,IS2,2) = utility(CONS, coupleIDCWN(AGE,IA,IS1,IS2,2)) + BETA*(1.0-divorce)*marriageVR(AGE+1,JA,2) &
	! 						! 								+ BETA*divorce*interpolate_singleVR2	

	! 					EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
	! 					DO i=1,NGRIDEH
	! 						IF(EH(i)>EH_temp) THEN 
	! 							JE = i-1 
	! 							sum_temp = marriageVR(AGE+1,JA,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVR(AGE+1,JA,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
								
	! 							EXIT   
	! 						ELSEIF (i==NGRIDEH) THEN  
	! 							JE = NGRIDEH
	! 							sum_temp = marriageVR(AGE+1,JA,JE,1)  
								
	! 						END IF
	! 					END DO 	
				  				
	! 					marriageVW(AGE,IA,IS1,IS2,IE,1) = utility(CONS, LEI1, 1) + BETA*sum_temp 
								
	! 					DO i=1,NGRIDEH
	! 						IF(EH(i)>EH_temp) THEN 
	! 							JE = i-1 
	! 							sum_temp = marriageVR(AGE+1,JA,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVR(AGE+1,JA,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
								
	! 							EXIT   
	! 						ELSEIF (i==NGRIDEH) THEN  
	! 							JE = NGRIDEH
	! 							sum_temp = marriageVR(AGE+1,JA,JE,2)  
								
	! 						END IF
	! 					END DO 	
				  					
	! 					marriageVW(AGE,IA,IS1,IS2,IE,2) = utility(CONS, LEI2, 2) + BETA*sum_temp  
									
	! 				ELSE
						
	! 					EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
	! 					DO i=1,NGRIDEH
	! 						IF(EH(i)>EH_temp) THEN 
	! 							JE = i-1 
	! 							sum_temp = 0.0
	! 							DO NEWIS = 1,nn
	! 			  					! sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*coupleVW(AGE+1,JA,NEWIS,:) ))
	! 								sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( marriageVW(AGE+1,JA,NEWIS,:,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVW(AGE+1,JA,NEWIS,:,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
	! 							END DO

	! 							EXIT   
	! 						ELSEIF (i==NGRIDEH) THEN  
	! 							JE = NGRIDEH
	! 							sum_temp = 0.0
	! 							DO NEWIS = 1,nn
	! 			  					! sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*coupleVW(AGE+1,JA,NEWIS,:) ))
	! 								sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*marriageVW(AGE+1,JA,NEWIS,:,JE,1)  ))
	! 							END DO

	! 						END IF
	! 					END DO 
						
	! 					marriageVW(AGE,IA,IS1,IS2,IE,1) = utility(CONS, LEI1, 1) + BETA*sum_temp 

	! 					EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
	! 					DO i=1,NGRIDEH
	! 						IF(EH(i)>EH_temp) THEN 
	! 							JE = i-1 
	! 							sum_temp = 0.0
	! 							DO NEWIS = 1,nn
	! 			  					! sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*coupleVW(AGE+1,JA,NEWIS,:) ))
	! 								sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*( marriageVW(AGE+1,JA,NEWIS,:,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVW(AGE+1,JA,NEWIS,:,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) ))
	! 							END DO

	! 							EXIT   
	! 						ELSEIF (i==NGRIDEH) THEN  
	! 							JE = NGRIDEH
	! 							sum_temp = 0.0
	! 							DO NEWIS = 1,nn
	! 			  					! sum_temp = sum_temp + P(IS1,NEWIS)*(sum( P(IS2,:)*coupleVW(AGE+1,JA,NEWIS,:) ))
	! 								sum_temp = sum_temp + P(IS1,NEWIS,1)*(sum( P(IS2,:,2)*marriageVW(AGE+1,JA,NEWIS,:,JE,2)  ))
	! 							END DO

	! 						END IF
	! 					END DO
							
	! 					marriageVW(AGE,IA,IS1,IS2,IE,2) = utility(CONS, LEI2, 2) + BETA*sum_temp

	! 				END IF	

	! 			END DO
    !         END DO
    !     END DO
	! END DO 
	
	!******************************************************************************************	




!******************************************************************************************
! 					Value of being in a marriage for an individual
!******************************************************************************************	 	 
! DO AGE=MAXAGE,RETAGE,-1
!     ! WAGEZ1 = SS
! 	! WAGEZ2 = SS           
		
	
! 	DO IA=1,NGRIDA
! 		DO IE=1,NGRIDEH

! 			JA = coupleIDCRA(AGE,IA,IE)
! 			WAGEZ1 = SS(IE)
! 			WAGEZ2 = SS(IE)  

! 			! yd = (lambda+delta_lambda)*(MIN(bendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l) &
! 			!  +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - bendy) &
! 			!  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

! 			yd = max(yd_MFJ( WAGEZ1 + WAGEZ2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2 + min(R*A(IA),d_c)/2 ,IA) )

! 			! CONS = (A(IA) + yd + 2*gov_trans - A(JA))/(1.0+tau_s)
! 			LEI = 1.0
			
! 			IF (AGE==MAXAGE) THEN
! 				CONS = (A(IA) + yd + 2*gov_trans)/(1.0+tau_s)
! 				marriageVR(AGE,IA,IE,1) = utility(CONS/eta, LEI, 1,gov_exp*OUTPUT) 
! 				marriageVR(AGE,IA,IE,2) = utility(CONS/eta, LEI, 2,gov_exp*OUTPUT)
! 			ELSE
! 				CONS = (A(IA) + yd + 2*gov_trans - A(JA))/(1.0+tau_s)
! 				marriageVR(AGE,IA,IE,1) = utility(CONS/eta, LEI, 1,gov_exp*OUTPUT) + BETA*S(AGE,1)*S(AGE,2)*marriageVR(AGE+1,JA,IE,1) &
! 										+ BETA*S(AGE,1)*(1.0-S(AGE,2))*singleVR(AGE+1,JA,IE,1)

! 				marriageVR(AGE,IA,IE,2) = utility(CONS/eta, LEI, 2,gov_exp*OUTPUT) + BETA*S(AGE,1)*S(AGE,2)*marriageVR(AGE+1,JA,IE,2) &
! 										+ BETA*S(AGE,2)*(1.0-S(AGE,1))*singleVR(AGE+1,JA,IE,2)
! 			END IF 
! 		END DO 
! 	END DO
	
! END DO

! DO AGE=RETAGE-1,1,-1 
! 	DO IA =1,NGRIDA			   
!         DO IS1 = 1,nn   
! 			DO IS2 = 1,nn
! 				DO IE=1,NGRIDEH

! 					JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)
! 					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
! 					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2) 						
! 					WAGEZ1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)
! 					WAGEZ2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)

!                 	! yd = lambda*(MIN(bendy,min(R*A(IA),d_c) + WAGEZ1 + WAGEZ2))**(1.0-tau_l) &
! 				 	! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ WAGEZ1 + WAGEZ2 - bendy) &
! 					! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)
					
! 					yd = max(yd_MFJ( WAGEZ1*JN1 + WAGEZ2*JN2 + min(R*A(IA),d_c), IA), yd_MFS( WAGEZ1*JN1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGEZ2*JN2 + min(R*A(IA),d_c)/2 ,IA) )
							
! 					CONS = (A(IA) + yd + 2*BEQ + 2*gov_trans - A(JA))/(1.0+tau_s)

! 					LEI1 = 1.00000000 - N(JN1) 
! 					LEI2 = 1.00000000 - N(JN2)

														
! 						! splitasset = A(JA)/2.0
! 						! do i=IA,NGRIDA
! 						! 	if(A(i) > splitasset) then	
! 						! 		Alower = i-1
! 						! 		go to 132
! 						! 	elseif (A(i) == splitasset) then	
! 						! 		Alower = i
! 						! 		go to 132
! 						! 	end if 
! 						! end do
! 						! 132 continue 
										
! 					IF (AGE==RETAGE-1) THEN
! 							! interpolate_singleVR1 = singleVR(AGE+1,Alower,1)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
! 							! 						+ singleVR(AGE+1,Alower+1,1)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))

! 							! interpolate_singleVR2 = singleVR(AGE+1,Alower,2)*(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)) &
! 							! 						+ singleVR(AGE+1,Alower+1,2)*(1.0-(splitasset-A(Alower+1))/(A(Alower)-A(Alower+1)))		
							
! 							! marriageVW(AGE,IA,IS1,IS2,1) = utility(CONS, coupleIDCWN(AGE,IA,IS1,IS2,1)) + BETA*(1.0-divorce)*marriageVR(AGE+1,JA,1) &
! 							! 								+ BETA*divorce*interpolate_singleVR1
							
! 							! marriageVW(AGE,IA,IS1,IS2,2) = utility(CONS, coupleIDCWN(AGE,IA,IS1,IS2,2)) + BETA*(1.0-divorce)*marriageVR(AGE+1,JA,2) &
! 							! 								+ BETA*divorce*interpolate_singleVR2	

! 						! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
! 						EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE
! 						DO i=1,NGRIDEH
! 							IF(EH(i)>EH_temp) THEN 
! 								JE = i-1 
! 								sum_temp = marriageVR(AGE+1,JA,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVR(AGE+1,JA,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
								
! 								EXIT   
! 							ELSEIF (i==NGRIDEH) THEN  
! 								JE = NGRIDEH
! 								sum_temp = marriageVR(AGE+1,JA,JE,1)  
								
! 							END IF
! 						END DO 	
				  				
! 						marriageVW(AGE,IA,IS1,IS2,IE,1) = utility(CONS/eta, LEI1, 1,gov_exp*OUTPUT) + BETA*sum_temp 
								
! 						DO i=1,NGRIDEH
! 							IF(EH(i)>EH_temp) THEN 
! 								JE = i-1 
! 								sum_temp = marriageVR(AGE+1,JA,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVR(AGE+1,JA,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
								
! 								EXIT   
! 							ELSEIF (i==NGRIDEH) THEN  
! 								JE = NGRIDEH
! 								sum_temp = marriageVR(AGE+1,JA,JE,2)  
								
! 							END IF
! 						END DO 	
				  					
! 						marriageVW(AGE,IA,IS1,IS2,IE,2) = utility(CONS/eta, LEI2, 2,gov_exp*OUTPUT) + BETA*sum_temp  
									
! 					ELSE
						
! 						! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
! 						EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE
! 						DO i=1,NGRIDEH
! 							IF(EH(i)>EH_temp) THEN 
! 								JE = i-1 
! 								sum_temp = 0.0
! 								DO NEWIS1 = 1,nn
! 									DO NEWIS2 = 1,nn	

! 										IF (IS1==IS2) THEN
! 											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 										ELSE
! 											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 										END IF
										
! 										sum_temp = sum_temp + P_joint*( marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )

! 									END DO 
! 								END DO

! 								EXIT   
! 							ELSEIF (i==NGRIDEH) THEN  
! 								JE = NGRIDEH
! 								sum_temp = 0.0
! 								DO NEWIS1 = 1,nn
! 									DO NEWIS2 = 1,nn	

! 										IF (IS1==IS2) THEN
! 											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 										ELSE
! 											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 										END IF
				  					
! 										sum_temp = sum_temp + P_joint*marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,1)

! 									END DO 
! 								END DO

! 							END IF
! 						END DO 
						
! 						marriageVW(AGE,IA,IS1,IS2,IE,1) = utility(CONS/eta, LEI1, 1,gov_exp*OUTPUT) + BETA*sum_temp 

! 						! EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0/5.0)/AGE 
! 						EH_temp = ((AGE-1)*EH(IE)+(WAGEZ1*N(JN1)+WAGEZ2*N(JN2))/2.0)/AGE
! 						DO i=1,NGRIDEH
! 							IF(EH(i)>EH_temp) THEN 
! 								JE = i-1 
! 								sum_temp = 0.0
! 								DO NEWIS1 = 1,nn
! 									DO NEWIS2 = 1,nn	

! 										IF (IS1==IS2) THEN
! 											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 										ELSE
! 											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 										END IF
				  					
! 										sum_temp = sum_temp + P_joint*( marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )

! 									END DO  
! 								END DO

! 								EXIT   
! 							ELSEIF (i==NGRIDEH) THEN  
! 								JE = NGRIDEH
! 								sum_temp = 0.0
! 								DO NEWIS1 = 1,nn
! 									DO NEWIS2 = 1,nn	

! 										IF (IS1==IS2) THEN
! 											P_joint = (1-earn_corr_conditional)*P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2) &
! 												+earn_corr_conditional*indicator(NEWIS1,NEWIS2)*P(IS1,NEWIS1,1)
! 										ELSE
! 											P_joint = P(IS1,NEWIS1,1)*P(IS2,NEWIS2,2)
! 										END IF

				  					
! 										sum_temp = sum_temp + P_joint*marriageVW(AGE+1,JA,NEWIS1,NEWIS2,JE,2)

! 									END DO   
! 								END DO

! 							END IF
! 						END DO
							
! 						marriageVW(AGE,IA,IS1,IS2,IE,2) = utility(CONS/eta, LEI2, 2,gov_exp*OUTPUT) + BETA*sum_temp

! 					END IF	

! 				END DO
!             END DO
!         END DO
! 	END DO 
! END DO 
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
			DO IH=1,NGRIDH
				DO IE=1,NGRIDEH
					DO IG=1,2
						singleYR(AGE,IA,IH,IE,IG)=0.0
					END DO 
				END DO
			END DO 
        END DO
    END DO

	DO AGE=RETAGE,MAXAGE
        DO IA=1,NGRIDA
			DO IH=1,NGRIDH
				DO IE=1,NGRIDEH		  
					coupleYR(AGE,IA,IH,IE)=0.0 
				END DO  
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
coupleYW(1,ZEROINDEX,1,1,1) = marryprop*P_m(1,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,1,2,1) = marryprop*P_m(1,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,1,3,1) = marryprop*P_m(1,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,2,1,1) = marryprop*P_m(1,1)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,2,2,1) = marryprop*P_m(1,1)*(0.819000/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,2,3,1) = marryprop*P_m(1,1)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,3,1,1) = marryprop*P_m(1,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,3,2,1) = marryprop*P_m(1,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,3,3,1) = marryprop*P_m(1,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))

coupleYW(1,ZEROINDEX,4,1,1) = marryprop*P_m(2,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,4,2,1) = marryprop*P_m(2,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,4,3,1) = marryprop*P_m(2,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,5,1,1) = marryprop*P_m(2,1)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,5,2,1) = marryprop*P_m(2,1)*(0.819000/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,5,3,1) = marryprop*P_m(2,1)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,6,1,1) = marryprop*P_m(2,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,6,2,1) = marryprop*P_m(2,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,6,3,1) = marryprop*P_m(2,1)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))

coupleYW(1,ZEROINDEX,1,4,1) = marryprop*P_m(1,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,2,4,1) = marryprop*P_m(1,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,3,4,1) = marryprop*P_m(1,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,1,5,1) = marryprop*P_m(1,2)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,2,5,1) = marryprop*P_m(1,2)*(0.819000/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,3,5,1) = marryprop*P_m(1,2)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,1,6,1) = marryprop*P_m(1,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,2,6,1) = marryprop*P_m(1,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,3,6,1) = marryprop*P_m(1,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))

coupleYW(1,ZEROINDEX,4,4,1) = marryprop*P_m(2,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,4,5,1) = marryprop*P_m(2,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,4,6,1) = marryprop*P_m(2,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,5,4,1) = marryprop*P_m(2,2)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,5,5,1) = marryprop*P_m(2,2)*(0.819000/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,5,6,1) = marryprop*P_m(2,2)*(0.819000/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,6,4,1) = marryprop*P_m(2,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))	
coupleYW(1,ZEROINDEX,6,5,1) = marryprop*P_m(2,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.819000/(0.090500+0.819000+0.0905000))
coupleYW(1,ZEROINDEX,6,6,1) = marryprop*P_m(2,2)*(0.090500/(0.090500+0.819000+0.0905000))*(0.090500/(0.090500+0.819000+0.0905000))


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
					singleYR(RETAGE,JA,1,JE,IG) = singleYR(RETAGE,JA,1,JE,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
					singleYR(RETAGE,JA,1,JE+1,IG) = singleYR(RETAGE,JA,1,JE+1,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)))
				
					EXIT
				ELSEIF (i==NGRIDEH) THEN  
					JE = NGRIDEH 
					singleYR(RETAGE,JA,1,JE,IG) = singleYR(RETAGE,JA,1,JE,IG) + singleYW(RETAGE-1,IA,IS,IE,IG)  
				
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

	IF (AGE==RETAGE+1) THEN
		j=1
	ELSEIF (AGE==RETAGE+2) THEN 
		j=2
	ELSEIF (AGE==RETAGE+3) THEN
		j=3
	ELSE
		j=4
	END IF 

    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH
				DO IG=1,2
						
					JA = singleIDCRA(AGE-1,IA,IH,IE,IG)
					JM = singleIDCRM(AGE-1,IA,IH,IE,IG) 

					HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
					IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
						XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
						JH = FLOOR(XH)
						DH = XH-JH
					ELSE IF (HNEXT>HMAX) THEN
						JH = 1
						DH = 0.0000	       
					ELSE IF (HNEXT<HMIN) THEN
						JH = NGRIDH
						DH = 0.0000
					END IF
						
					
					! IF (JH<NGRIDH) THEN
					! 	singleYR(AGE,JA,JH,IE,IG) = singleYR(AGE,JA,JH,IE,IG) + (1.0-DH)*singleYR(AGE-1,IA,IH,IE,IG)*SUR(AGE-1,IG,IH)
					! 	singleYR(AGE,JA,JH+1,IE,IG) = singleYR(AGE,JA,JH+1,IE,IG) + DH*singleYR(AGE-1,IA,IH,IE,IG)*SUR(AGE-1,IG,IH)						
					! ELSE
					! 	singleYR(AGE,JA,JH,IE,IG) = singleYR(AGE,JA,JH,IE,IG) + singleYR(AGE-1,IA,IH,IE,IG)*SUR(AGE-1,IG,IH)
					! END IF 
					IF (JH<NGRIDH) THEN
						DO NEWH = 1,NGRIDH
							singleYR(AGE,JA,NEWH,IE,IG) = singleYR(AGE,JA,NEWH,IE,IG) + (1.0-DH)*P_h(JH,NEWH,j)*singleYR(AGE-1,IA,IH,IE,IG)*SUR(AGE-1,IG,IH)
							singleYR(AGE,JA,NEWH,IE,IG) = singleYR(AGE,JA,NEWH,IE,IG) + DH*P_h(JH+1,NEWH,j)*singleYR(AGE-1,IA,IH,IE,IG)*SUR(AGE-1,IG,IH)	
						END DO					
					ELSE
						DO NEWH = 1,NGRIDH
							singleYR(AGE,JA,NEWH,IE,IG) = singleYR(AGE,JA,NEWH,IE,IG) + P_h(JH,NEWH,j)*singleYR(AGE-1,IA,IH,IE,IG)*SUR(AGE-1,IG,IH)
						END DO 
					END IF 
										
						
				
					JM = coupleIDCRM(AGE-1,IA,IH,IE) 	!couple

					HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
					IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
						XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
						JH = FLOOR(XH)
						DH = XH-JH
					ELSE IF (HNEXT>HMAX) THEN
						JH = 1
						DH = 0.0000	       
					ELSE IF (HNEXT<HMIN) THEN
						JH = NGRIDH
						DH = 0.0000
					END IF


					! IF (IG==1) THEN
					! 	IF (JH<NGRIDH) THEN
					! 		singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) + (1.0-DH)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,2,IH))	! wife dies, husband becomes single
					! 		singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH+1,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH+1,IE,IG) + DH*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,2,IH))	! wife dies, husband becomes single
					! 	ELSE
					! 		singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) + coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,2,IH))
					! 	END IF
					! ELSE 	
					! 	IF (JH<NGRIDH) THEN
					! 		singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) + (1.0-DH)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,1,IH))	! husband dies, wife becomes single
					! 		singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH+1,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH+1,IE,IG) + DH*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,1,IH))	! husband dies, wife becomes single
					! 	ELSE
					! 		singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),JH,IE,IG) + coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,1,IH))
					! 	END IF 
					! END IF 
					IF (IG==1) THEN
						IF (JH<NGRIDH) THEN
							DO NEWH = 1,NGRIDH
								singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) + (1.0-DH)*P_h(JH,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,2,IH))	! wife dies, husband becomes single
								singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) + DH*P_h(JH+1,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,2,IH))	! wife dies, husband becomes single
							END DO 
						ELSE
							DO NEWH = 1,NGRIDH
								singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) + P_h(JH,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,2,IH))
							END DO 
						END IF
					ELSE 	
						IF (JH<NGRIDH) THEN
							DO NEWH = 1,NGRIDH
								singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) + (1.0-DH)*P_h(JH,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,1,IH))	! husband dies, wife becomes single
								singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) + DH*P_h(JH+1,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,1,IH))	! husband dies, wife becomes single
							END DO 
						ELSE
							DO NEWH = 1,NGRIDH
								singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) = singleYR(AGE,coupleIDCRA(AGE-1,IA,IH,IE),NEWH,IE,IG) + P_h(JH,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*(1.0-SUR(AGE-1,1,IH))
							END DO
						END IF 
					END IF 

				END DO 	 
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
					coupleYR(RETAGE,JA,1,JE) = coupleYR(RETAGE,JA,1,JE) + coupleYW(RETAGE-1,IA,IS1,IS2,IE)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))
					coupleYR(RETAGE,JA,1,JE+1) = coupleYR(RETAGE,JA,1,JE+1) + coupleYW(RETAGE-1,IA,IS1,IS2,IE)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) 
					
				
					EXIT
				ELSEIF (i==NGRIDEH) THEN  
					JE = NGRIDEH
					coupleYR(RETAGE,JA,1,JE) = coupleYR(RETAGE,JA,1,JE) + coupleYW(RETAGE-1,IA,IS1,IS2,IE) 
				
					  
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

		IF (AGE==RETAGE+1) THEN
			j=1
		ELSEIF (AGE==RETAGE+2) THEN 
			j=2
		ELSEIF (AGE==RETAGE+3) THEN
			j=3
		ELSE
			j=4
		END IF 

        DO IA=1,NGRIDA
			DO IH=1,NGRIDH
				DO IE=1,NGRIDEH
									
					JA = coupleIDCRA(AGE-1,IA,IH,IE)
					JM = coupleIDCRM(AGE-1,IA,IH,IE) 	

					HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
					IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
						XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
						JH = FLOOR(XH)
						DH = XH-JH
					ELSE IF (HNEXT>HMAX) THEN
						JH = 1
						DH = 0.0000	       
					ELSE IF (HNEXT<HMIN) THEN
						JH = NGRIDH
						DH = 0.0000
					END IF
					
					! coupleYR(AGE,JA,JH,IE) = coupleYR(AGE,JA,JH,IE) + (1.0-DH)*coupleYR(AGE-1,IA,IH,IE)*SUR(AGE-1,1,IH)*SUR(AGE-1,2,IH)	 
					! coupleYR(AGE,JA,JH+1,IE) = coupleYR(AGE,JA,JH+1,IE) + DH*coupleYR(AGE-1,IA,IH,IE)*SUR(AGE-1,1,IH)*SUR(AGE-1,2,IH)	
						 
					DO NEWH = 1,NGRIDH
						coupleYR(AGE,JA,NEWH,IE) = coupleYR(AGE,JA,NEWH,IE) + (1.0-DH)*P_h(JH,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*SUR(AGE-1,1,IH)*SUR(AGE-1,2,IH)	 
						coupleYR(AGE,JA,NEWH,IE) = coupleYR(AGE,JA,NEWH,IE) + DH*P_h(JH+1,NEWH,j)*coupleYR(AGE-1,IA,IH,IE)*SUR(AGE-1,1,IH)*SUR(AGE-1,2,IH)
					END DO 

				END DO 
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
                    INCOME     = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1)
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
                    yd = (min(R*A(IA),d_c) + INCOME)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
				 		  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+ INCOME)/avg_earnings - singlebendy) &						  
						  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

					! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
					X3 =  BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)
					CONS = (X3 + yd + gov_trans -lumpsum - A(JA) - PREMIUM)/(1.0+tau_s)
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
                    INCOME     = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + UB(IS1,IE,2)+ UB(IS2,IE,2)
					INCOME1    = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + UB(IS1,IE,2)
					INCOME2    = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + UB(IS2,IE,2)
					PREMIUM    = premium_rate*INCOME
                    !ILONG(AGE) = ILONG(AGE) + INCOME*YW(AGE,IA,IH,IS)
					ILONG(AGE) = ILONG(AGE) + INCOME*coupleYW(AGE,IA,IS1,IS2,IE)
                    
					!(Kuhn & Rios 2016)Income consists of all kinds of revenue before taxes. Hence, our definition of income includes both government and private transfers  
					! (Before Tax) Total Income
                    !TINCOME     = R(IA)*A(IA) + (1-STAX-MTAX)*INCOME+ ATR(IA)* BEQ*(1.0+GROWTH)**(AGE-1)
				    !TINCOME     = R*A(IA) + (1-STAX-MTAX)*INCOME 
					
					!TINCOME     = R(IR)*A(IA) + (1-STAX-MTAX)*INCOME+ ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1)					
                    TINCOME	= min(R*A(IA),d_c) + INCOME + 2*BEQ				
					TILONG(AGE) = TILONG(AGE) + TINCOME*coupleYW(AGE,IA,IS1,IS2,IE)

                    !  Consumption
                    !CONS = ATR(IA)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + (1-STAX-MTAX)*INCOME - A(JA) - (1.000-SUBEHI)*M(JM) - (1.0-STAX-MTAX)*PREMIUM !
                    !CLONG(AGE) = CLONG(AGE) + CONS*YW(AGE,IA,IH,IS)

					                    
					! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
				 	! 	  +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ INCOME - couplebendy) &						  
					! 	  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

					yd = max( yd_MFJ( INCOME+min(R*A(IA),d_c), IA), yd_MFS(INCOME1+min(R*A(IA),d_c)/2,IA)+yd_MFS(INCOME2+min(R*A(IA),d_c)/2,IA) )

					! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
					X3 =  2*BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)
					CONS = (X3 + yd + 2*(gov_trans-lumpsum) - A(JA) - PREMIUM)/(1.0+tau_s)
					CLONG(AGE) = CLONG(AGE) + CONS*coupleYW(AGE,IA,IS1,IS2,IE)

				END DO 
            END DO			  
        END DO
    END DO
END DO


MLONG(:) = 0.0
HLONG(:) = 0.0
!  Single Retirees    
    DO AGE=RETAGE,MAXAGE              
        ALONG(AGE) = 0.0
        CLONG(AGE) = 0.0
        ILONG(AGE) = 0.0   !Original code: ILONG(AGE) = SS ; I assume SS is not earnings
		TILONG(AGE) = 0.0
		HLONG(AGE) = 0.0
        MLONG(AGE) = 0.0
        
        DO IA=1,NGRIDA
			DO IH=1,NGRIDH
				DO IE=1,NGRIDEH
					DO IG=1,2   
					
					!  Assets
					!JA = IDCRA(AGE,IA,IH)
					JA = singleIDCRA(AGE,IA,IH,IE,IG)
					ALONG(AGE) = ALONG(AGE) + A(IA)*singleYR(AGE,IA,IH,IE,IG)

					!  Med. Expenditure
					JM = singleIDCRM(AGE,IA,IH,IE,IG)
					IF (JM<1) THEN
						JM = 1
					END IF
					MLONG(AGE) = MLONG(AGE) + M(JM)*singleYR(AGE,IA,IH,IE,IG)

					! Health capital
					HLONG(AGE) = HLONG(AGE) + H(IH)*singleYR(AGE,IA,IH,IE,IG)
					
					!JH = IDCRH(AGE,IA,IH)
					!HLONGNEXT(AGE) = HLONGNEXT(AGE) + H(JH)*YR(AGE,IA,IH)
							
					!  Total income
					!TINCOME = R(IA)*A(IA) + SS + ATR(IA)* BEQ*(1.0+GROWTH)**(AGE-1) 
					!TINCOME = R*A(IA) + SS
					!TINCOME = R(IR)*A(IA) + SS + ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1) 
					PREMIUM = premium_rate*SS(IE)
					TINCOME = min(R*A(IA),d_c) + SS(IE)                  
					TILONG(AGE) = TILONG(AGE) + TINCOME*singleYR(AGE,IA,IH,IE,IG)
					!TILONG(AGE) = TILONG(AGE) + TINCOME*YR(AGE,IA,IH)

					!  Consumption
					!CONS = ATR(IA)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) -(1.000-SUBM)*M(JM)
					!CLONG(AGE) = CLONG(AGE) + CONS*YR(AGE,IA,IH)

					!CONS = ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) 
					yd = (min(R*A(IA),d_c) + SS(IE) )*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + SS(IE))/avg_earnings))**(-tau_l_single) &
						+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+ SS(IE) )/avg_earnings - singlebendy) &					 
						+(1-tau_c)*max(R*A(IA)-d_c,0.0)

					! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
					X3 = A(IA)
					CONS = (X3 + yd + gov_trans -lumpsum - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM)/(1.0+tau_s)
					CLONG(AGE) = CLONG(AGE) + CONS*singleYR(AGE,IA,IH,IE,IG)

					END DO 
				END DO
			END DO 
        END DO
    END DO

!  Couple Retirees    
    DO AGE=RETAGE,MAXAGE                      
        DO IA=1,NGRIDA
			DO IH=1,NGRIDH
				DO IE=1,NGRIDEH
									
					!  Assets
					!JA = IDCRA(AGE,IA,IH)
					JA = coupleIDCRA(AGE,IA,IH,IE)
					ALONG(AGE) = ALONG(AGE) + A(IA)*coupleYR(AGE,IA,IH,IE)

					!  Med. Expenditure
					JM = coupleIDCRM(AGE,IA,IH,IE)
					IF (JM<1) THEN
						JM = 1
					END IF
					MLONG(AGE) = MLONG(AGE) + M(JM)*coupleYR(AGE,IA,IH,IE)

					! Health capital
					HLONG(AGE) = HLONG(AGE) + H(IH)*coupleYR(AGE,IA,IH,IE)
					
					!JH = IDCRH(AGE,IA,IH)
					!HLONGNEXT(AGE) = HLONGNEXT(AGE) + H(JH)*YR(AGE,IA,IH)
							
					!  Total income
					!TINCOME = R(IA)*A(IA) + SS + ATR(IA)* BEQ*(1.0+GROWTH)**(AGE-1) 
					!TINCOME = R*A(IA) + SS
					!TINCOME = R(IR)*A(IA) + SS + ATR(IR)* BEQ*(1.0+GROWTH)**(AGE-1) 
					PREMIUM = premium_rate*(2*SS(IE))
					TINCOME = min(R*A(IA),d_c) + 2*SS(IE)                  
					TILONG(AGE) = TILONG(AGE) + TINCOME*coupleYR(AGE,IA,IH,IE)
					!TILONG(AGE) = TILONG(AGE) + TINCOME*YR(AGE,IA,IH)

					!  Consumption
					!CONS = ATR(IA)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) -(1.000-SUBM)*M(JM)
					!CLONG(AGE) = CLONG(AGE) + CONS*YR(AGE,IA,IH)

					!CONS = ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA) 
					
					! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + 2*SS(IE)))**(1.0-tau_l_couple) &
					!  	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+ 2*SS(IE) - couplebendy) &					 
					! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)

					
					yd = max( yd_MFJ(2*SS(IE) + min(R*A(IA),d_c) , IA), yd_MFS(SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE) + min(R*A(IA),d_c)/2 ,IA) )

					! X3 = ATR(IR)*( BEQ*(1.0+GROWTH)**(AGE-1) ) + A(IA)
					X3 = A(IA)
					CONS = (X3 + yd + 2*(gov_trans-lumpsum) - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM)/(1.0+tau_s)
					CLONG(AGE) = CLONG(AGE) + CONS*coupleYR(AGE,IA,IH,IE)				
				END DO
			END DO		
        END DO
    END DO

Avg_ALONG = SUM(ALONG)/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:))+SUM(singleYR(RETAGE:MAXAGE,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))
print*,'Avg_ALONG',Avg_ALONG
Avg_CLONG = SUM(CLONG)/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:))+SUM(singleYR(RETAGE:MAXAGE,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))
print*,'Avg_CLONG',Avg_CLONG
Avg_MLONG = SUM(MLONG)/(SUM(singleYR(RETAGE:MAXAGE,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))
print*,'Avg_MLONG',Avg_MLONG
Avg_ILONG = SUM(ILONG)/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:)))
print*,'Avg_ILONG',Avg_ILONG
Avg_TILONG = SUM(TILONG)/(SUM(singleYW(1:RETAGE-1,:,:,:,:))+SUM(coupleYW(1:RETAGE-1,:,:,:,:))+SUM(singleYR(RETAGE:MAXAGE,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))
print*,'Avg_TILONG',Avg_TILONG

DO AGE=1,RETAGE-1
	ALONG(AGE)  = ALONG(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
	CLONG(AGE)  = CLONG(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
	ILONG(AGE)  = ILONG(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
	TILONG(AGE) = TILONG(AGE)/(SUM(singleYW(AGE,:,:,:,:))+SUM(coupleYW(AGE,:,:,:,:)))
END DO
DO AGE=RETAGE,MAXAGE
	ALONG(AGE) = ALONG(AGE)/(SUM(singleYR(AGE,:,:,:,:))+SUM(coupleYR(AGE,:,:,:)))
	CLONG(AGE) = CLONG(AGE)/(SUM(singleYR(AGE,:,:,:,:))+SUM(coupleYR(AGE,:,:,:)))
	TILONG(AGE) = TILONG(AGE)/(SUM(singleYR(AGE,:,:,:,:))+SUM(coupleYR(AGE,:,:,:)))
	HLONG(AGE) = HLONG(AGE)/(SUM(singleYR(AGE,:,:,:,:))+SUM(coupleYR(AGE,:,:,:)))
	MLONG(AGE) = MLONG(AGE)/(SUM(singleYR(AGE,:,:,:,:))+SUM(coupleYR(AGE,:,:,:)))
END DO 

! OPEN(UNIT=27,FILE='lifecycle_wealth.txt')
! 		write(27,*) ALONG(:)
! CLOSE(27)
! OPEN(UNIT=27,FILE='lifecycle_earning.txt')
! 		write(27,*) ILONG(:)
! CLOSE(27)
! OPEN(UNIT=27,FILE='lifecycle_income.txt')
! 		write(27,*) TILONG(:)
! CLOSE(27)
! OPEN(UNIT=27,FILE='lifecycle_health.txt')
! 		write(27,*) HLONG(:)
! CLOSE(27)
! OPEN(UNIT=27,FILE='lifecycle_Med.txt')
! 		write(27,*) MLONG(:)
! CLOSE(27)

!   Compute cross-sectional profiles for a given time period

    DO AGE=1,MAXAGE
        ACROSS(AGE) = ALONG(AGE)*(1+GROWTH)**(1-AGE)
        CCROSS(AGE) = CLONG(AGE)*(1+GROWTH)**(1-AGE)
        ICROSS(AGE) = ILONG(AGE)*(1+GROWTH)**(1-AGE)
	    TICROSS(AGE)= TILONG(AGE)*(1+GROWTH)**(1-AGE)
	    MCROSS(AGE) = MLONG(AGE)*(1+GROWTH)**(1-AGE)
   	    HCROSS(AGE) = HLONG(AGE)        
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
	ALLOCATE( X((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH, 6) )  ! wealth: x(:,1), labor income: x(:,2), total income: x(:,3) , consumption: x(:,4) , after-tax income: x(:,5), working consumption: x(:,6)      
	ALLOCATE( D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )	
	!ALLOCATE( D_YW(MAXAGE,NGRIDA,NGRIDR,nn) )
	!ALLOCATE( D_YR(MAXAGE,NGRIDA,NGRIDR) )
	ALLOCATE( D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
	ALLOCATE( D_A( (RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH ) )

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
						INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1)
						PREMIUM = premium_rate*INCOME
						
						IF (AGE>=2) THEN
						IY = IY + 1
						x(IY,1) = A(IA) 	!x(IX,1) = A(JA)  ! Wealth level at the begining of each period
						END IF

						! x(IX,2) = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)	! pretax labor income	
						x(IX,2) = INCOME	! pretax labor income											
												
						x(IX,3)	= R*A(IA) + INCOME 	! pretax income including corporate income
						
						! consumption
						!x(IX,4)	= ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + (1.0-STAX-MTAX)*WAGE*EFFLONG(AGE)*W(IS)*N(JN) - A(JA)
						yd = (min(R*A(IA),d_c) + INCOME)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
							+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) + INCOME)/avg_earnings - singlebendy) &
							+(1-tau_c)*max(R*A(IA)-d_c,0.0)

						
						! X3 =  BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)					 
						! x(IX,4)	= X3 + yd + gov_trans - A(JA) - PREMIUM
						x(IX,4) = singleIDCWC(AGE,IA,IS,IE,IG)

						x(IX,5)	= yd

						x(IX,6) = x(IX,4)

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
						INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + UB(IS1,IE,2) + UB(IS2,IE,2)
						INCOME1 = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + UB(IS1,IE,2)
						INCOME2 = WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + UB(IS2,IE,2)
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

						
						yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c), IA), yd_MFS( INCOME1 + min(R*A(IA),d_c)/2,IA)+yd_MFS( INCOME2 + min(R*A(IA),d_c)/2,IA) )


						
						! X3 =  2*BEQ*(1.0+GROWTH)**(AGE-1) + A(IA)					 
						! x(IX,4)	= X3 + yd + 2*gov_trans - A(JA) - PREMIUM
						x(IX,4)	= coupleIDCWC(AGE,IA,IS1,IS2,IE)

						x(IX,5)	= yd

						x(IX,6) = x(IX,4)

					END DO 
				END DO
            END DO
        END DO
    END DO

! Single retiree    
    ! DO AGE = RETAGE,MAXAGE-1           ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
	DO AGE = RETAGE,MAXAGE
        DO IA = 1,NGRIDA   
			DO IH = 1,NGRIDH   
				DO IE = 1,NGRIDEH	
					DO IG=1,2

					IX = IX + 1 
					IY = IY + 1                                                                                                   
					! JA = IDCRA(AGE,IA,IH)     
					! x(IX,1) = A(JA) 
					! x(IX,3) = R(JA)*A(JA) + SS + ATR(JA)* BEQ*(1.0+GROWTH)**(AGE-1)   
					JA = singleIDCRA(AGE,IA,IH,IE,IG)     
					JM = singleIDCRM(AGE,IA,IH,IE,IG)
					INCOME = SS(IE)		
					PREMIUM = premium_rate*INCOME		
					
					x(IY,1) = A(IA)		!A(JA) 

					x(IX,3)	= R*A(IA) +  INCOME 

					!x(IX,4)	= ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA)
					yd = (min(R*A(IA),d_c) + INCOME)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
						+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME)/avg_earnings - singlebendy) &
						+(1-tau_c)*max(R*A(IA)-d_c,0.0)
					
					! X3 =  A(IA)	 
					! x(IX,4)	= X3 + yd + gov_trans + medicare - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM
					x(IX,4) = singleIDCRC(AGE,IA,IH,IE,IG)

					x(IX,5)	= yd

					END DO  
				END DO
			END DO
        END DO
    END DO 

! couple retiree    
    ! DO AGE = RETAGE,MAXAGE-1           ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
	DO AGE = RETAGE,MAXAGE
        DO IA = 1,NGRIDA 
			DO IH = 1,NGRIDH     
				DO IE = 1,NGRIDEH	
					
					IX = IX + 1 
					IY = IY + 1                                                                                                   
					! JA = IDCRA(AGE,IA,IH)     
					! x(IX,1) = A(JA) 
					! x(IX,3) = R(JA)*A(JA) + SS + ATR(JA)* BEQ*(1.0+GROWTH)**(AGE-1)   
					JA = coupleIDCRA(AGE,IA,IH,IE)  
					JM = coupleIDCRM(AGE,IA,IH,IE)
					INCOME = 2*SS(IE)
					INCOME1 = SS(IE)
					INCOME2 = SS(IE)
					PREMIUM = premium_rate*INCOME 

					x(IY,1) = A(IA)		!A(JA) 
									
					x(IX,3)	= R*A(IA) + INCOME  

					!x(IX,4)	= ATR(IR)*( A(IA) + BEQ*(1.0+GROWTH)**(AGE-1) ) + SS - A(JA)

					! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + 2*SS(IE)))**(1.0-tau_l_couple) &
					! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+2*SS(IE) - couplebendy) &
					! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)

					
					yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c), IA), yd_MFS( INCOME1 + min(R*A(IA),d_c)/2 ,IA)+yd_MFS( INCOME2 + min(R*A(IA),d_c)/2 ,IA) )
					
					! X3 =  A(IA)	 
					! x(IX,4)	= X3 + yd + 2*medicare + 2*gov_trans - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM
					x(IX,4) = coupleIDCRC(AGE,IA,IH,IE)

					x(IX,5)	= yd
									
				END DO
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
			DO IH = 1,NGRIDH
				DO IE = 1,NGRIDEH
					DO IG=1,2

						ID = ID + 1                                                                                                    
						IDA = IDA + 1

						D(ID) = singleYR(AGE,IA,IH,IE,IG)						
						D_A(IDA) = singleYR(AGE,IA,IH,IE,IG)	

					END DO 	
				END DO
			END DO 
        END DO
    END DO

! Couple retiree	    
    !DO AGE = RETAGE,MAXAGE-1
	DO AGE = RETAGE,MAXAGE    ! COUNT THE LAST PERIOD PEOPLE THOUGH SAVING IS ZERO
        DO IA = 1,NGRIDA
			DO IH = 1,NGRIDH
				DO IE = 1,NGRIDEH
					
					ID = ID + 1                                                                                                    
					IDA = IDA + 1

					D(ID) = coupleYR(AGE,IA,IH,IE)						
					D_A(IDA) = coupleYR(AGE,IA,IH,IE)	
							
				END DO
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
! WRITE(12,*) x(:,2)

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

mean_consvar = 0.0
DO i=1,(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH	 
		mean_consvar = mean_consvar + log(x(i,6))*D_inc(i)	
END DO 

consvar = 0.0
DO i=1,(RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH	
	consvar = consvar + ((log(x(i,6))-mean_consvar)**2)*D_inc(i)
END DO 

var_cons_earning_ratio = consvar/incvar
!********************************************************************************************************
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
!*******************************************************************************************************
  
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
!*******************************************************************************************************
! SUBROUTINE age_wealth_gini 

!     !ALLOCATE ( x_age(NGRIDA*NGRIDH*nn, MAXAGE-1) ) 
!    ! ALLOCATE ( D_age(NGRIDA*NGRIDH*nn, MAXAGE-1), NorD_age(NGRIDA*NGRIDH*nn, MAXAGE-1) )
!     !ALLOCATE ( age_wea_gini(MAXAGE-1) )
! 	ALLOCATE( x_age(NGRIDA*nn*NGRIDEH*2+NGRIDA*nn*nn*NGRIDEH, MAXAGE) ) 
!     ALLOCATE( D_age(NGRIDA*nn*NGRIDEH*2+NGRIDA*nn*nn*NGRIDEH, MAXAGE), NorD_age(NGRIDA*nn*NGRIDEH*2+NGRIDA*nn*nn*NGRIDEH, MAXAGE) )
!     ALLOCATE( age_wea_gini(MAXAGE) )
    
! ! Single working age    
!     DO AGE = 1,RETAGE-1
!         IX = 0
!         DO IA = 1,NGRIDA
!             DO IS = 1,nn 
! 				DO IE=1,NGRIDEH  
! 					DO IG=1,2

!                     IX = IX + 1                                                                                                    
                    
! 					!JA = IDCWA(AGE,IA,IR,IS)
! 					x_age(IX,AGE) = A(IA)	!A(JA) 					
!                     !x_age(IX,AGE+1) = A(JA)

! 					END DO 
!                 END DO
!             END DO
!         END DO

! ! Couple working age
! 		DO IA = 1,NGRIDA           			
!             DO IS1 = 1,nn 
! 				DO IS2=1,nn 
! 					DO IE=1,NGRIDEH
									
!                     IX = IX + 1
! 					x_age(IX,AGE) = A(IA)	

! 					END DO 
! 				END DO
!             END DO
!         END DO

!     END DO

! ! Single retiree      
!     DO AGE = RETAGE,MAXAGE           
!         IX = 0
!         DO IA = 1,NGRIDA             
! 			DO IE = 1,NGRIDEH
! 				DO IG=1,2	

!                 	IX = IX + 1                                                                                                                      
! 					!JA = IDCRA(AGE,IA,IR)
! 					x_age(IX,AGE) = A(IA)	!A(JA)   				
!                		!x_age(IX,AGE+1) = A(JA)

! 				END DO                 
!             END DO
!         END DO

! ! couple retiree 
! 		DO IA = 1,NGRIDA      
! 			DO IE = 1,NGRIDEH	

! 				IX = IX + 1                                                                                                                      
! 				x_age(IX,AGE) = A(IA)

! 			END DO                 
!         END DO
				
!     END DO 
     
! ! Single working    
!     DO AGE = 1,RETAGE-1
!         ID = 0
!         DO IA = 1,NGRIDA
!             DO IS = 1,nn    
! 				DO IE=1,NGRIDEH
! 					DO IG=1,2                                                                                                                                                    
			
!                    	 ID = ID + 1                                                                                                                        
! 					 D_age(ID,AGE) = singleYW(AGE,IA,IS,IE,IG)
! 					 !D_age(ID,AGE+1) = D_YW(AGE+1,IA,IR,IS)

! 					END DO 
!                 END DO
!             END DO
!         END DO

! ! Couple working
! 		DO IA = 1,NGRIDA
!             DO IS1 = 1,nn 
! 				DO IS2=1,nn
! 					DO IE=1,NGRIDEH

! 						ID = ID + 1
! 						D_age(ID,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)

! 					END DO 
!                 END DO
!             END DO
!         END DO

!     END DO

! ! Single retiree	    
!     DO AGE = RETAGE,MAXAGE
!         ID = 0
!         DO IA = 1,NGRIDA  
! 			DO IE = 1,NGRIDEH
! 	  			DO IG=1,2 			
                	
! 					ID = ID + 1                                                                                                    
! 					D_age(ID,AGE) = singleYR(AGE,IA,IE,IG)	
! 					!D_age(ID,AGE+1) = D_YR(AGE+1,IA,IR)	

!                 END DO     
!             END DO
!         END DO

! ! Couple retiree	
! 		DO IA = 1,NGRIDA
! 			DO IE = 1,NGRIDEH

! 				ID = ID + 1
! 				D_age(ID,AGE) = coupleYR(AGE,IA,IE)	

! 			END DO 
! 		END DO 	

!     END DO
! !**********************************
!  print*, '-------------------------------------------------------------'
! DO AGE = 1,MAXAGE 
  
!    PRINT*,'sum of non normalized D_age(:,AGE) at age',AGE,'=',sum(D_age(:,AGE))
!    PRINT*,'sum of x_age(:,AGE) at age',AGE,'=',sum(x_age(:,AGE))
!    PRINT*,'dot product of D_age*x_age at age',AGE,'=',dot_product(x_age(:,AGE),D_age(:,AGE))
!    print*,'************************************************************'
! END DO   
    
! !***********************************    
! ! Normalize the D_age    
! DO AGE = 1,MAXAGE 
!    NorD_age(:,AGE) = D_age(:,AGE)/sum(D_age(:,AGE))    
! !   PRINT*,'age=',AGE
!    PRINT*,'sum of normalized D_age(:,AGE) at age',AGE,'=',sum(NorD_age(:,AGE)) 
! END DO
!  PRINT*,'********************************************************************'  
!    DO AGE = 1,MAXAGE
!       age_wea_gini(AGE) = gini(x_age(:,AGE), NorD_age(:,AGE))
! !      PRINT*,'sum of normalized D_age(:,AGE) at age',AGE+1,'=',sum(NorD_age(:,AGE))
!       PRINT*,'age_wea_gini at age',AGE,'=',age_wea_gini(AGE)
!       print*,' '
!    END DO

! END SUBROUTINE
!***************************************************************************************************
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

ALLOCATE( sort_A((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) ) 
ALLOCATE( sort_A_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2) )
ALLOCATE( sort_A_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH)  )   
ALLOCATE( sort_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( temp_sort_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( sort_D_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2) )
ALLOCATE( sort_D_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH)  )
ALLOCATE( cum_sort_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top0001pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top0005pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top001pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top005pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top01pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top05pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top1pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top5pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top10pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top20pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top40pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top50pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top60pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top70pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top80pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top90pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top95pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top99pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( record_position_A((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( record_position_A_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2) )
ALLOCATE( record_position_A_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH)  ) 
ALLOCATE( box((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
 

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
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH	
				DO IG=1,2

					index_A = index_A + 1
					index_A_single = index_A_single + 1

					sort_A(index_A) = A(IA)	
					sort_A_single(index_A_single) = A(IA)

					sort_D(index_A) = singleYR(AGE,IA,IH,IE,IG)
					sort_D_single(index_A_single) = singleYR(AGE,IA,IH,IE,IG)
						
					record_position_A(index_A) = index_A
					record_position_A_single(index_A_single) = index_A_single
				
				END DO     
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
		DO IH=1,NGRIDH  
			DO IE = 1,NGRIDEH   

				index_A = index_A + 1
				index_A_couple = index_A_couple + 1

				sort_A(index_A) = A(IA)	
				sort_A_couple(index_A_couple) = A(IA)

				sort_D(index_A) = coupleYR(AGE,IA,IH,IE)
				sort_D_couple(index_A_couple) = coupleYR(AGE,IA,IH,IE)

				record_position_A(index_A) = index_A
				record_position_A_couple(index_A_couple) = index_A_couple

			END DO
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
ALLOCATE( sort_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( sort_tinc_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2 ) )
ALLOCATE( sort_tinc_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )
ALLOCATE( sort_D_TINC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( temp_sort_D_TINC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )

ALLOCATE( sort_D_tinc_single( (RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2 ) )
ALLOCATE( sort_D_tinc_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

ALLOCATE( cum_sort_D_TINC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top0001pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top0005pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top001pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top005pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top01pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top025pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top05pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top1pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top5pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top10pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top20pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top40pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top50pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top60pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top70pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top80pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top90pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top95pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top99pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot20pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( box_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( record_position_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( record_position_tinc_single( (RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2 ) )
ALLOCATE( record_position_tinc_couple( (RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )

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
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH	
				DO IG=1,2

					index_tinc = index_tinc + 1
					index_tinc_single = index_tinc_single + 1

					sort_tinc(index_tinc) = R*A(IA) + SS(IE) 
					sort_tinc_single(index_tinc_single) = R*A(IA) + SS(IE) 

					sort_D_tinc(index_tinc) = singleYR(AGE,IA,IH,IE,IG)
					sort_D_tinc_single(index_tinc_single) = singleYR(AGE,IA,IH,IE,IG)
					
					record_position_tinc(index_tinc) = index_tinc
					record_position_tinc_single(index_tinc_single) = index_tinc_single
				
				END DO     
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
		DO IH=1,NGRIDH    
			DO IE = 1,NGRIDEH   

				index_tinc = index_tinc + 1
				index_tinc_couple = index_tinc_couple + 1

				sort_tinc(index_tinc) = R*A(IA) + 2*SS(IE)  
				sort_tinc_couple(index_tinc_couple) = R*A(IA) + 2*SS(IE)  

				sort_D_tinc(index_tinc) = coupleYR(AGE,IA,IH,IE)
				sort_D_tinc_couple(index_tinc_couple) = coupleYR(AGE,IA,IH,IE)

				record_position_tinc(index_tinc) = index_tinc
				record_position_tinc_couple(index_tinc_couple) = index_tinc_couple

			END DO
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

! only save the benchmark incomethreshold
IF (source_welfare==0) THEN
	OPEN(UNIT=52,FILE='incomethreshold.txt')
	! WRITE(52,"(12(F11.4,1X))") incomethreshold80,incomethreshold60,incomethreshold40,incomethreshold20,incomethreshold10,incomethreshold5,incomethreshold1
	WRITE(52,*) incomethreshold80,incomethreshold60,incomethreshold40,incomethreshold20,incomethreshold10,incomethreshold5,incomethreshold1
	CLOSE(UNIT=52)
END IF 

print*, 'incomethreshold1=',incomethreshold1
print*, 'incomethreshold5=',incomethreshold5
print*, 'incomethreshold10=',incomethreshold10
print*, 'incomethreshold20=',incomethreshold20
print*, 'incomethreshold40=',incomethreshold40
print*, 'incomethreshold60=',incomethreshold60
print*, 'incomethreshold80=',incomethreshold80

END SUBROUTINE
!************************************************************************************************************
SUBROUTINE consumptionshare

ALLOCATE( singleIDCWC(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2), coupleIDCWC(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
ALLOCATE( singleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2), coupleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH) )
ALLOCATE( sort_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )    
ALLOCATE( sort_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( temp_sort_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( cum_sort_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top0001pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top0005pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top001pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top01pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top05pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top1pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top5pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top10pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top20pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top40pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top50pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top60pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top70pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top80pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top90pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top95pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( top99pct_D_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( record_position_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( box_C((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )


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
				                 
			 	 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1)
				 PREMIUM = premium_rate*INCOME
                
				 yd	= (min(R*A(IA),d_c) + INCOME)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
					  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c) + INCOME)/avg_earnings - singlebendy) &
					  +(1-tau_c)*max(R*A(IA)-d_c,0.0)
				 
				 X3 =  BEQ + A(IA)
				 singleIDCWC(AGE,IA,IS,IE,IG) = max( CMIN, (X3 + yd + gov_trans - lumpsum - A(JA) - PREMIUM)/(1.0+tau_s) )
				! singleIDCWC(AGE,IA,IS,IE,IG) =  (X3 + yd + gov_trans - lumpsum - A(JA) - PREMIUM)/(1.0+tau_s) 

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
				 JA = coupleIDCWA(AGE,IA,IS1,IS2,IE)  
				 JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
				 JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)

				 INCOME1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + UB(IS1,IE,2)
				 INCOME2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + UB(IS2,IE,2)
				 INCOME = INCOME1 + INCOME2
				 TINCOME1 = INCOME1 + min(R*A(IA),d_c)/2
				 TINCOME2 = INCOME2 + min(R*A(IA),d_c)/2
				 TINCOME = TINCOME1 + TINCOME2
				 PREMIUM = premium_rate*INCOME
				 taxable_income = TINCOME 
				 taxable_income1 = TINCOME1 
				 taxable_income2 = TINCOME2
				!  yd= (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
				! 		  +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
				! 		  +(1-tau_c)*max(R*A(IA)-d_c,0.0)

				 
				 yd = max( yd_MFJ(taxable_income, IA), yd_MFS(taxable_income1,IA)+yd_MFS(taxable_income2,IA) )
				
				 X3 =  2*BEQ + A(IA)
				 coupleIDCWC(AGE,IA,IS1,IS2,IE) = max( CMIN, (X3 + yd + 2*(gov_trans- lumpsum) - A(JA) - PREMIUM)/(1.0+tau_s))
				! coupleIDCWC(AGE,IA,IS1,IS2,IE) = (X3 + yd + 2*(gov_trans- lumpsum) - A(JA) - PREMIUM)/(1.0+tau_s)

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
		DO IH = 1,NGRIDH 
			DO IE = 1,NGRIDEH	
				DO IG=1,2 
							
				isort=isort+1           
				JA=singleIDCRA(AGE,IA,IH,IE,IG)
				JM = singleIDCRM(AGE,IA,IH,IE,IG)

				INCOME = SS(IE)
				TINCOME = min(R*A(IA),d_c) + INCOME
				PREMIUM = premium_rate*INCOME
				taxable_income = TINCOME
				
				yd	= taxable_income*lambda*(MIN(singlebendy,taxable_income/avg_earnings))**(-tau_l_single) &
						+avg_earnings*(1.0-ty_max)*MAX(0.0, taxable_income/avg_earnings - singlebendy) &
						+(1-tau_c)*max(R*A(IA)-d_c,0.0)+gov_trans+medicare
							
				X3 = A(IA)
				singleIDCRC(AGE,IA,IH,IE,IG) = max( CMIN, (X3 + yd + medicare + gov_trans - lumpsum - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM)/(1.0+tau_s) )
				! singleIDCRC(AGE,IA,IH,IE,IG) =  (X3 + yd + medicare + gov_trans - lumpsum - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM)/(1.0+tau_s) 
				
				sort_C(isort) = singleIDCRC(AGE,IA,IH,IE,IG)
				sort_D_C(isort) = singleYR(AGE,IA,IH,IE,IG)
				record_position_C(isort) = isort

				END DO             
			END DO 
		END DO 
    END DO
END DO                

! couple retiree    
! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA 
		DO IH = 1,NGRIDH     
			DO IE = 1,NGRIDEH

			isort=isort+1           
			JA=coupleIDCRA(AGE,IA,IH,IE)
			JM = coupleIDCRM(AGE,IA,IH,IE)

			
			INCOME1 = SS(IE) 
			INCOME2 = SS(IE)
			INCOME = INCOME1 + INCOME2
			TINCOME1 = INCOME1 + min(R*A(IA),d_c)/2
			TINCOME2 = INCOME2 + min(R*A(IA),d_c)/2	
			TINCOME = TINCOME1 + TINCOME2			
			PREMIUM = premium_rate*INCOME
			PREMIUM1 = premium_rate*INCOME1
			PREMIUM2 = premium_rate*INCOME2
			taxable_income = TINCOME
			taxable_income1 = TINCOME1
			taxable_income2 = TINCOME2

			!  yd= (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
			! 			+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
			! 			+(1-tau_c)*max(R*A(IA)-d_c,0.0)

			
			yd = max( yd_MFJ( taxable_income , IA), yd_MFS( taxable_income1 ,IA)+yd_MFS( taxable_income2 ,IA) ) 

			X3 = A(IA)
			coupleIDCRC(AGE,IA,IH,IE) = max(CMIN, (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM)/(1.0+tau_s))
			! coupleIDCRC(AGE,IA,IH,IE) =  (X3 + yd + 2*medicare + 2*(gov_trans-lumpsum) - A(JA) - (1.0-SUBEHI(AGE))*M(JM) - PREMIUM)/(1.0+tau_s)

			sort_C(isort) = coupleIDCRC(AGE,IA,IH,IE)
			sort_D_C(isort) = coupleYR(AGE,IA,IH,IE)
			record_position_C(isort) = isort

			END DO 
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
! ALLOCATE( bot99pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
! ALLOCATE( bot90pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
! ALLOCATE( bot50pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
! ALLOCATE( bot30pct_D((RETAGE-1-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )

ALLOCATE( bot99pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot90pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot50pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot30pct_D((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot99pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot90pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot50pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot30pct_D_inc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH) )
ALLOCATE( bot99pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot90pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot50pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( bot30pct_D_tinc((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )

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
ALLOCATE( HLONG_AGE_single(MAXAGE,2), HLONG_AGE_couple(MAXAGE) )
ALLOCATE( MLONG_AGE_single(MAXAGE,2), MLONG_AGE_couple(MAXAGE) )
ALLOCATE( ALONG_RETIRE_single(2), ILONG_RETIRE_single(2), TILONG_RETIRE_single(2), YDLONG_RETIRE_single(2) )
ALLOCATE( ALONG20_25_single(2), ALONG25_30_single(2), ALONG30_35_single(2), ALONG35_40_single(2), ALONG40_45_single(2), ALONG45_50_single(2), ALONG50_55_single(2), ALONG55_60_single(2), ALONG60_65_single(2), ALONG65_70_single(2), ALONG70_75_single(2), ALONG75_80_single(2), ALONG80_85_single(2), ALONG85_90_single(2), ALONG90_95_single(2),ALONG95_100_single(2),ALONG65_MORE_single(2) )
ALLOCATE( ILONG20_25_single(2), ILONG25_30_single(2), ILONG30_35_single(2), ILONG35_40_single(2), ILONG40_45_single(2), ILONG45_50_single(2), ILONG50_55_single(2), ILONG55_60_single(2), ILONG60_65_single(2), ILONG65_MORE_single(2) )
ALLOCATE( TILONG20_25_single(2), TILONG25_30_single(2), TILONG30_35_single(2), TILONG35_40_single(2), TILONG40_45_single(2), TILONG45_50_single(2), TILONG50_55_single(2), TILONG55_60_single(2), TILONG60_65_single(2), TILONG65_MORE_single(2) )
ALLOCATE( YDLONG20_25_single(2), YDLONG25_30_single(2), YDLONG30_35_single(2), YDLONG35_40_single(2), YDLONG40_45_single(2), YDLONG45_50_single(2), YDLONG50_55_single(2), YDLONG55_60_single(2), YDLONG60_65_single(2), YDLONG65_MORE_single(2) )
ALLOCATE( labor_participation_age(RETAGE-1,2) )
ALLOCATE( WLONG_AGE(RETAGE-1,2) )
ALLOCATE( labor_participation_age_single(RETAGE-1,2), labor_participation_age_couple(RETAGE-1,2) )
ALLOCATE( NLONG_AGE_single(RETAGE-1,2), NLONG_AGE_couple(RETAGE-1,2) )
! ALLOCATE( CLONG_AGE_single(MAXAGE,2), CLONG_AGE_couple(MAXAGE) )


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
				 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1)				
				 TINCOME = R*A(IA) + INCOME !+ BEQ
				 !post-tax income
				 yd = (min(R*A(IA),d_c) + INCOME)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
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

temp_singleYR = SUM(singleYR(RETAGE:MAXAGE,:,:,:,:))
DO IG=1,2
 ALONG_RETIRE_single(IG) = 0.0
 ILONG_RETIRE_single(IG) = 0.0
 TILONG_RETIRE_single(IG) = 0.0
 YDLONG_RETIRE_single(IG) = 0.0
	DO AGE=RETAGE,MAXAGE
		ALONG_AGE_single(AGE,IG)=0.0
		HLONG_AGE_single(AGE,IG)=0.0
		MLONG_AGE_single(AGE,IG)=0.0	
		temp_singleYR_AGE = SUM(singleYR(AGE,:,:,:,IG))	
		DO IA=1,NGRIDA
			DO IH = 1,NGRIDH
				DO IE = 1,NGRIDEH	
				
					JA = singleIDCRA(AGE,IA,IH,IE,IG)
					JM = singleIDCRM(AGE,IA,IH,IE,IG)
					INCOME = SS(IE)    
					TINCOME = R*A(IA) + INCOME 
					!post-tax income
					yd = (min(R*A(IA),d_c) + INCOME)*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME)/avg_earnings))**(-tau_l_single) &
						+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME)/avg_earnings - singlebendy) &
						+(1-tau_c)*max(R*A(IA)-d_c,0.0)	!+gov_trans
				
					ALONG_RETIRE_single(IG) = ALONG_RETIRE_single(IG) + A(JA)*singleYR(AGE,IA,IH,IE,IG)/temp_singleYR
					ILONG_RETIRE_single(IG) = ILONG_RETIRE_single(IG) + INCOME*singleYR(AGE,IA,IH,IE,IG)/temp_singleYR
					TILONG_RETIRE_single(IG) = TILONG_RETIRE_single(IG) + TINCOME*singleYR(AGE,IA,IH,IE,IG)/temp_singleYR
					YDLONG_RETIRE_single(IG) = YDLONG_RETIRE_single(IG) + yd*singleYR(AGE,IA,IH,IE,IG)/temp_singleYR

					ALONG_AGE_single(AGE,IG) = ALONG_AGE_single(AGE,IG) + A(JA)*singleYR(AGE,IA,IH,IE,IG)/temp_singleYR_AGE
					HLONG_AGE_single(AGE,IG) = HLONG_AGE_single(AGE,IG) + H(IH)*singleYR(AGE,IA,IH,IE,IG)/temp_singleYR_AGE
					MLONG_AGE_single(AGE,IG) = MLONG_AGE_single(AGE,IG) + M(JM)*singleYR(AGE,IA,IH,IE,IG)/temp_singleYR_AGE

				END DO	
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
						 
						yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c) + UB(IS1,IE,2)+ UB(IS2,IE,2), IA), yd_MFS( WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+ UB(IS1,IE,2)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)+ UB(IS2,IE,2)+ min(R*A(IA),d_c)/2 ,IA) )


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
temp_coupleYR = SUM(coupleYR(RETAGE:MAXAGE,:,:,:))


DO AGE=RETAGE,MAXAGE
	ALONG_AGE_couple(AGE) = 0.0
	HLONG_AGE_couple(AGE) = 0.0
	MLONG_AGE_couple(AGE) = 0.0 
	temp_coupleYR_AGE = SUM(coupleYR(AGE,:,:,:))
	DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH	
				
				JA = coupleIDCRA(AGE,IA,IH,IE)
				JM = coupleIDCRM(AGE,IA,IH,IE)
				INCOME = 2*SS(IE)    
				TINCOME = R*A(IA) + INCOME
				! yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME ))**(1.0-tau_l_couple) &
				! 	 +(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c) + INCOME - couplebendy) &
				! 	 +(1-tau_c)*max(R*A(IA)-d_c,0.0)	
				! yd = max( yd_MFJ(INCOME,IA), yd_MFS(INCOME,IA) )  
				yd = max( yd_MFJ(2*SS(IE) + min(R*A(IA),d_c), IA), yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA) )
							
				ALONG_RETIRE_couple = ALONG_RETIRE_couple + A(JA)*coupleYR(AGE,IA,IH,IE)/temp_coupleYR
				ILONG_RETIRE_couple = ILONG_RETIRE_couple + INCOME*coupleYR(AGE,IA,IH,IE)/temp_coupleYR
				TILONG_RETIRE_couple = TILONG_RETIRE_couple + TINCOME*coupleYR(AGE,IA,IH,IE)/temp_coupleYR
				YDLONG_RETIRE_couple = YDLONG_RETIRE_couple + yd*coupleYR(AGE,IA,IH,IE)/temp_coupleYR

				ALONG_AGE_couple(AGE) = ALONG_AGE_couple(AGE) + A(JA)*coupleYR(AGE,IA,IH,IE)/temp_coupleYR_AGE
				HLONG_AGE_couple(AGE) = HLONG_AGE_couple(AGE) + H(IH)*coupleYR(AGE,IA,IH,IE)/temp_coupleYR_AGE
				MLONG_AGE_couple(AGE) = MLONG_AGE_couple(AGE) + M(JM)*coupleYR(AGE,IA,IH,IE)/temp_coupleYR_AGE
				
			END DO
		END DO
	END DO
END DO				
print*,'line9787'

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
print*,'line9853'

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
ALLOCATE( sort_inc_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( sort_D_inc_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( temp_sort_D_inc_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( box_inc_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( record_position_E_retire((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH))
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
					sort_D_inc_retire(isort) = singleYW(AGE,IA,IS,IE,IG)
					record_position_E_retire(isort) = isort

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
				 sort_D_inc_retire(isort) = coupleYW(AGE,IA,IS1,IS2,IE)
				 record_position_E_retire(isort) = isort

				END DO 
            END DO
        END DO 
    END DO
END DO 

! Single retiree 
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH	
				DO IG=1,2    
				
				 isort=isort+1

				 sort_inc_retire(isort) = SS(IE) 
				 sort_D_inc_retire(isort) = singleYR(AGE,IA,IH,IE,IG)
				 record_position_E_retire(isort) = isort

				END DO 
			END DO 
		END DO 
    END DO
END DO  

! couple retiree
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA   
		DO IH= 1,NGRIDH   
			DO IE = 1,NGRIDEH

				isort=isort+1

				sort_inc_retire(isort) = 2*SS(IE) 
				sort_D_inc_retire(isort) = coupleYR(AGE,IA,IH,IE)
				record_position_E_retire(isort) = isort

			END DO
		END DO
    END DO
END DO  


CALL SSORT_INT(sort_inc_retire,record_position_E_retire,size(sort_inc_retire),2)
temp_sort_D_inc_retire(:) = sort_D_inc_retire(record_position_E_retire)
sort_D_inc_retire = temp_sort_D_inc_retire
sort_D_inc_retire = sort_D_inc_retire/sum(sort_D_inc_retire)
! CALL sorting(size(sort_inc_retire),sort_inc_retire) 

! DO i = 1,size(sort_inc_retire)
! 	box_inc_retire(i)= 0
! END DO

! ! Single working age
! index_tinc = 0
! DO AGE=1,RETAGE-1
!     DO IA=1,NGRIDA
! 		DO IS = 1,nn 
! 			DO IE=1,NGRIDEH
! 				DO IG=1,2 

!                  index_tinc = index_tinc + 1		
! 				 JN=singleIDCWN(AGE,IA,IS,IE,IG)   	
! 				 INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG)	
! 				 i = search(  INCOME , sort_inc_retire, box_inc_retire,1.D-2 )
! 				 sort_D_inc_retire(i) = singleYW(AGE,IA,IS,IE,IG)			
!                 !record_position_inc_retire(index_tinc) = i

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
! 				 i = search(  INCOME , sort_inc_retire, box_inc_retire,1.D-2 )
! 				 sort_D_inc_retire(i) = coupleYW(AGE,IA,IS1,IS2,IE)

! 				 END DO 
!             END DO
!         END DO 
!     END DO
! END DO 


! ! Single retiree 
! DO AGE=RETAGE,MAXAGE
!     DO IA=1,NGRIDA  
! 		DO IH=1,NGRIDH        
! 			DO IE = 1,NGRIDEH	
! 				DO IG=1,2

! 					index_tinc = index_tinc + 1		                
! 					i = search(SS(IE) , sort_inc_retire, box_inc_retire,1.D-2)				   
! 					sort_D_inc_retire(i) = singleYR(AGE,IA,IH,IE,IG)			
! 					!record_position_inc_retire(index_tinc) = i
					
! 				END DO 				
! 			END DO
! 		END DO 
!     END DO
! END DO


! ! couple retiree
! DO AGE = RETAGE,MAXAGE
!     DO IA = 1,NGRIDA 
! 		DO IH=1,NGRIDH
! 			DO IE = 1,NGRIDEH

! 				index_tinc = index_tinc + 1		                
! 				i = search(2*SS(IE) , sort_inc_retire, box_inc_retire,1.D-2)				   
! 				sort_D_inc_retire(i) = coupleYR(AGE,IA,IH,IE)

! 			END DO
! 		END DO 
!     END DO
! END DO  
! print*,'line10113'


! sort_D_inc_retire(:) = sort_D_inc_retire(:)/sum(sort_D_inc_retire)

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
ALLOCATE( mean_earning_age_couple(RETAGE-1), var_earning_age_couple(RETAGE-1))
ALLOCATE( mean_cons_age_couple(RETAGE-1), var_cons_age_couple(RETAGE-1))
ALLOCATE( mean_wage_age_single(RETAGE-1), var_wage_age_single(RETAGE-1))
ALLOCATE( mean_wage_age_couple(RETAGE-1), var_wage_age_couple(RETAGE-1))
ALLOCATE( lifecycle_var_cons_earn_ratio_single(RETAGE-1), lifecycle_var_cons_earn_ratio_couple(RETAGE-1))


mean_earning_age_single(:) = 0.0
var_earning_age_single(:) = 0.0
mean_cons_age_single(:) = 0.0
var_cons_age_single(:) = 0.0
mean_earning_age_couple(:) = 0.0
var_earning_age_couple(:) = 0.0
mean_cons_age_couple(:) = 0.0
var_cons_age_couple(:) = 0.0
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
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1)	

					IF (INCOME > 1.D-5) THEN 
						mean_earning_single = mean_earning_single + log(INCOME)*singleYW(AGE,IA,IS,IE,IG)
						mean_earning_age_single(AGE) = mean_earning_age_single(AGE) + log(INCOME)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW	
						mean_wage_age_single(AGE) = mean_wage_age_single(AGE) + log(WAGE*EFFLONG(AGE,IG)*W(IS,IG) + UB(IS,IE,1))*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW	
						! mean_wage_age_single(AGE) = mean_wage_age_single(AGE) + log(shock(IS,IG))*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW						
					END IF
					
					mean_cons_single = mean_cons_single + log(singleIDCWC(AGE,IA,IS,IE,IG))*singleYW(AGE,IA,IS,IE,IG)
					mean_cons_age_single(AGE) = mean_cons_age_single(AGE) + log(singleIDCWC(AGE,IA,IS,IE,IG))*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW

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
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1)

					IF (INCOME > 1.D-5) THEN 
						var_earning_single = var_earning_single + ((log(INCOME)-mean_earning_single)**2)*singleYW(AGE,IA,IS,IE,IG)
						var_earning_age_single(AGE) = var_earning_age_single(AGE) + ((log(INCOME)-mean_earning_age_single(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW	
						var_wage_age_single(AGE) = var_wage_age_single(AGE) + ((log(WAGE*EFFLONG(AGE,IG)*W(IS,IG) + UB(IS,IE,1))-mean_wage_age_single(AGE))**2)*singleYW(AGE,IA,IS,IE,IG)/temp_singleYW		
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
					INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + UB(IS1,IE,2) + UB(IS2,IE,2)

					IF (INCOME > 1.D-5) THEN 
						mean_earning_couple = mean_earning_couple + log(INCOME)*coupleYW(AGE,IA,IS1,IS2,IE)
						mean_earning_age_couple(AGE) = mean_earning_age_couple(AGE) + log(INCOME)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						mean_wage_age_couple(AGE) = mean_wage_age_couple(AGE) + log(WAGE*EFFLONG(AGE,1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*W(IS2,2) + UB(IS1,IE,2) + UB(IS2,IE,2))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						! mean_wage_age_couple(AGE) = mean_wage_age_couple(AGE) + (log(shock(IS1,1)) + log(shock(IS2,2)))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					END IF
					
					mean_cons_couple = mean_cons_couple + log(coupleIDCWC(AGE,IA,IS1,IS2,IE))*coupleYW(AGE,IA,IS1,IS2,IE)
					mean_cons_age_couple(AGE) = mean_cons_age_couple(AGE) + log(coupleIDCWC(AGE,IA,IS1,IS2,IE))*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

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
					INCOME = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2) + UB(IS1,IE,2) + UB(IS2,IE,2)

					IF (INCOME > 1.D-5) THEN 
						var_earning_couple = var_earning_couple + ((log(INCOME)-mean_earning_couple)**2)*coupleYW(AGE,IA,IS1,IS2,IE)
						var_earning_age_couple(AGE) = var_earning_age_couple(AGE) + ((log(INCOME)-mean_earning_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
						var_wage_age_couple(AGE) = var_wage_age_couple(AGE) + ((log(WAGE*EFFLONG(AGE,1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*W(IS2,2) + UB(IS1,IE,2) + UB(IS2,IE,2))-mean_wage_age_couple(AGE))**2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
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

var_cons_earning_ratio_single = var_cons_single/var_earning_single
var_cons_earning_ratio_couple = var_cons_couple/var_earning_couple
DO AGE = 1,RETAGE-1
	lifecycle_var_cons_earn_ratio_single(AGE) = var_cons_age_single(AGE)/var_earning_age_single(AGE)
	lifecycle_var_cons_earn_ratio_couple(AGE) = var_cons_age_couple(AGE)/var_earning_age_couple(AGE)
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

					mean_earn_husband(AGE) = mean_earn_husband(AGE) + W(IS1,1)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					mean_earn_wife(AGE) = mean_earn_wife(AGE) + W(IS2,2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

					! mean_earn_husband(AGE) = mean_earn_husband(AGE) + EFFLONG(AGE,1)*W(IS1,1)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW
					! mean_earn_wife(AGE) = mean_earn_wife(AGE) + EFFLONG(AGE,2)*W(IS2,2)*coupleYW(AGE,IA,IS1,IS2,IE)/temp_coupleYW

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


ALLOCATE( totalincome((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( earning_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( kincome_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( trans_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( age_share((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )


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
				 yd = (min(R*A(IA),d_c) + INCOME + UB(IS,IE,1))*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME + UB(IS,IE,1))/avg_earnings))**(-tau_l_single) &
					  +avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME + UB(IS,IE,1))/avg_earnings - singlebendy) &
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
				 
				 yd = max( yd_MFJ( INCOME + min(R*A(IA),d_c) + UB(IS1,IE,2) + UB(IS2,IE,2), IA), yd_MFS( WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1)+ UB(IS1,IE,2)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)+ UB(IS2,IE,2)+ min(R*A(IA),d_c)/2 ,IA) )
	

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
		DO IH=1,NGRIDH       
			DO IE = 1,NGRIDEH	
				DO IG=1,2                
				
					state_pos = state_pos + 1
					
					INCOME = SS(IE)
					TINCOME = R*A(IA) + INCOME 
					yd =  (min(R*A(IA),d_c) + INCOME )*lambda*(MIN(singlebendy,(min(R*A(IA),d_c) + INCOME )/avg_earnings))**(-tau_l_single) &
						+avg_earnings*(1.0-ty_max)*MAX(0.0, (min(R*A(IA),d_c)+INCOME )/avg_earnings - singlebendy) &
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
END DO

! couple retiree    
! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA 
		DO IH=1,NGRIDH     
			DO IE = 1,NGRIDEH

				state_pos = state_pos + 1
						
				INCOME = 2*SS(IE)
				TINCOME = R*A(IA) + INCOME 
				!  yd = (lambda+delta_lambda)*(MIN(couplebendy,min(R*A(IA),d_c) + INCOME))**(1.0-tau_l_couple) &
				! 		+(1.0-ty_max)*MAX(0.0, min(R*A(IA),d_c)+INCOME - couplebendy) &
				! 		+(1-tau_c)*max(R*A(IA)-d_c,0.0)
				
				yd = max( yd_MFJ( 2*SS(IE) + min(R*A(IA),d_c) , IA), yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA)+yd_MFS( SS(IE)+ min(R*A(IA),d_c)/2 ,IA) )

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

ALLOCATE( sort_ATY((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( sort_ATC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( temp_sort_ATY((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
ALLOCATE( temp_sort_ATC((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH) )
!ALLOCATE( sort_noncorpY((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR) )
!ALLOCATE( MTR((RETAGE-1)*NGRIDA*nn*NGRIDEH*2+(RETAGE-1)*NGRIDA*nn*nn*NGRIDEH+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH*2+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDEH) )

	
	! G_share = (gov*OUTPUT + PIA_factor*SSEXP + flat_transf_rate*OUTPUT)/OUTPUT
	G_share = (gov_exp*OUTPUT + SSEXP + flat_transf_rate*OUTPUT + medicare_rate*OUTPUT)/OUTPUT

! ATY1: Income tax target
ATY_tax_single = 0.0
ATY_taxableincome_single = 0.0
ATY_tax_couple = 0.0
ATY_taxableincome_couple = 0.0
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
				 taxable_income = max(0.0,min(R*A(IA),d_c)) + INCOME  + UB(IS,IE,1)

				 ! income tax paid only on non-corporate capital income and labor income				
                 sort_ATY(state_pos) = taxable_income &
									- taxable_income*lambda * (MIN(singlebendy,taxable_income/avg_earnings))**(-tau_l_single) & 
									- avg_earnings*(1.0-ty_max)*MAX(0.0,(WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + min(R*A(IA),d_c))/avg_earnings - singlebendy)
										
				 sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)
				 
				 ATY_tax_single = ATY_tax_single + sort_ATY(state_pos)*singleYW(AGE,IA,IS,IE,IG)
				 ATY_taxableincome_single = ATY_taxableincome_single + taxable_income*singleYW(AGE,IA,IS,IE,IG)
				 ! sort_noncorpY(record_position_tinc(INT(state_pos))) = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS) + min(R*A(IA),d_c)

				END DO 
            END DO
        END DO 
    END DO
END DO

! Single retiree
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH	
				DO IG=1,2  
				
				state_pos=state_pos+1
				INCOME = SS(IE)
				TINCOME = R*A(IA) + INCOME
				taxable_income = max(0.0,min(R*A(IA),d_c) + INCOME) 
				
				sort_ATY(state_pos) = taxable_income &
										- taxable_income*lambda * (MIN(singlebendy,taxable_income/avg_earnings))**(-tau_l_single) & 
										- avg_earnings*(1.0-ty_max)*MAX(0.0,(WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + min(R*A(IA),d_c))/avg_earnings - singlebendy)

				sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)	

				!sort_noncorpY(record_position_tinc(INT(state_pos))) = SS + min(R(IR)*A(IA),d_c)	
			    ATY_tax_single = ATY_tax_single + sort_ATY(state_pos)*singleYR(AGE,IA,IH,IE,IG)
				ATY_taxableincome_single = ATY_taxableincome_single + taxable_income*singleYR(AGE,IA,IH,IE,IG)
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

				INCOME = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)
				INCOME1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + min(R*A(IA),d_c)/2  + UB(IS1,IE,2)
				INCOME2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)/2  + UB(IS2,IE,2)
				tax_MFS = INCOME1+INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA))			
				taxable_income = max(0.0,min(R*A(IA),d_c))+ WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2)  + UB(IS1,IE,2) + UB(IS2,IE,2)

				 ! income tax paid only on non-corporate capital income and labor income
				IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
					IF(GBC_method==0) THEN  		!cleared by lambda	
						sort_ATY(state_pos) = taxable_income - taxable_income*lambda*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
																		 - avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)	
					ELSE 	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
						sort_ATY(state_pos) = taxable_income - taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
																		- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)		 
					END IF
				ELSE 

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
						sort_ATY(state_pos) = INCOME1 - INCOME1*lambda*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
																	   + INCOME2 - INCOME2*lambda*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)	
					ELSE					
						sort_ATY(state_pos) = INCOME1 - INCOME1*lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
																       + INCOME2 - INCOME2*lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)
					END IF  

				END IF 	

				 sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)
				 
				 ATY_tax_couple = ATY_tax_couple + sort_ATY(state_pos)*coupleYW(AGE,IA,IS1,IS2,IE)
				 ATY_taxableincome_couple = ATY_taxableincome_couple + taxable_income*coupleYW(AGE,IA,IS1,IS2,IE)

				END DO 
            END DO
        END DO 
    END DO
END DO 

! couple retiree    
! DO AGE = RETAGE,MAXAGE-1         ! first period everyone has zero asset, so not consider it, total period is MAXAGE-1
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA 
		DO IH=1,NGRIDH     
			DO IE = 1,NGRIDEH

				state_pos=state_pos+1
				
				INCOME1 = SS(IE) + min(R*A(IA),d_c)/2 
				INCOME2 = SS(IE) + min(R*A(IA),d_c)/2
				INCOME = INCOME1+INCOME2
				tax_MFS = INCOME1+INCOME2 - (yd_MFS(INCOME1,IA)+yd_MFS(INCOME2,IA))		
				taxable_income = INCOME

				! income tax paid only on non-corporate capital income and labor income
					IF (yd_MFJ(INCOME1 + INCOME2 , IA) > yd_MFS(INCOME1 ,IA)+yd_MFS(INCOME2 ,IA) ) THEN 
						IF(GBC_method==0) THEN  		!cleared by lambda	
							sort_ATY(state_pos) = taxable_income - taxable_income*lambda*delta_lambda*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
																				- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)	
						ELSE	! GBC_method==1: cleared by Gov ; GBC_method==2: cleared by consumption tax rate
							sort_ATY(state_pos) = taxable_income - taxable_income*lambda_couple*(MIN(couplebendy, taxable_income/avg_earnings ))**(-tau_l_couple) &
																			- avg_earnings*(1.0-ty_max)*MAX(0.0,taxable_income/avg_earnings - couplebendy)		 
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
							sort_ATY(state_pos) = INCOME1 - INCOME1*lambda*delta_lambda*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
																			+ INCOME2 - INCOME2*lambda*delta_lambda*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)	
						ELSE					
							sort_ATY(state_pos) = INCOME1 - INCOME1*lambda_couple*( MIN(MFSbendy,INCOME1/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME1/avg_earnings - MFSbendy) &
																			+ INCOME2 - INCOME2*lambda_couple*( MIN(MFSbendy,INCOME2/avg_earnings))**(-tau_l_couple) - avg_earnings*(1.0-ty_max)*MAX(0.0,INCOME2/avg_earnings - MFSbendy)
						END IF  

					END IF 		

				sort_ATC(state_pos) = tau_c*max(R*A(IA)-d_c,0.0)
				
				ATY_tax_couple = ATY_tax_couple + sort_ATY(state_pos)*coupleYR(AGE,IA,IH,IE)
				ATY_taxableincome_couple = ATY_taxableincome_couple + taxable_income*coupleYR(AGE,IA,IH,IE)

			END DO
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


ATY99 =  sum(sort_ATY*sort_D_tinc*(1-top1pct_D_tinc)) &
		/sum(sort_tinc*sort_D_tinc*(1-top1pct_D_tinc))
! ATY99 =  sum(sort_ATY*sort_D_tinc*(1-top1pct_D_tinc)) &
! 		/sum(sort_noncorpY*sort_D_tinc*(1-top1pct_D_tinc))

print*, 'ATY99=',sum( sort_ATY*sort_D_tinc*(1-top1pct_D_tinc)/sum(sort_D_tinc*(1-top1pct_D_tinc)) ) 
print*, 'Avg tinc 99%=',sum( sort_tinc*sort_D_tinc*(1-top1pct_D_tinc)/sum(sort_D_tinc*(1-top1pct_D_tinc)) )

inctaxrev_income = sum(sort_ATY*sort_D_tinc)/OUTPUT
! ATY = sum(sort_ATY*sort_D_tinc)/Aggtincome
ATY = (ATY_tax_single+ATY_tax_couple)/(ATY_taxableincome_single+ATY_taxableincome_couple)
ATY_single = ATY_tax_single/ATY_taxableincome_single
ATY_couple = ATY_tax_couple/ATY_taxableincome_couple

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
		DO IH=1,NGRIDH
			DO IE = 1,NGRIDEH	
				DO IG=1,2

					IF  ( (singleIDCRA(AGE,IA,IH,IE,IG)>=NGRIDA) .AND. (singleYR(AGE,IA,IH,IE,IG)>0.0) ) THEN
					print*, ' WARNING kmax binding !!!!'
					END IF 

				END DO 
			END DO
		END DO
    END DO
END DO

! couple retiree
DO AGE = RETAGE,MAXAGE
    DO IA = 1,NGRIDA   
		DO IH=1,NGRIDH   
			DO IE = 1,NGRIDEH

				IF  ( (coupleIDCRA(AGE,IA,IH,IE)>=NGRIDA) .AND. (coupleYR(AGE,IA,IH,IE)>0.0) ) THEN
				print*, ' WARNING kmax binding !!!!'
				END IF

			END DO
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
! 
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

single_male_welfare =  (SUM(singleVW(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleVR(RETAGE:MAXAGE,:,:,:,1)*singleYR(RETAGE:MAXAGE,:,:,:,1)))/(SUM(singleYW(:,:,:,:,1))+SUM(singleYR(RETAGE:MAXAGE,:,:,:,1)))
single_female_welfare = (SUM(singleVW(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleVR(RETAGE:MAXAGE,:,:,:,2)*singleYR(RETAGE:MAXAGE,:,:,:,2)))/(SUM(singleYW(:,:,:,:,2))+SUM(singleYR(RETAGE:MAXAGE,:,:,:,2)))
total_couple_welfare =( SUM(coupleVW(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + SUM(coupleVR(RETAGE:MAXAGE,:,:,:)*coupleYR(RETAGE:MAXAGE,:,:,:)))/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))

! married_male_welfare =  (SUM(marriageVW(:,:,:,:,:,1)*coupleYW(:,:,:,:,:)) + SUM(marriageVR(RETAGE:MAXAGE,:,:,1)*coupleYR(RETAGE:MAXAGE,:,:,:)))/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))
! married_female_welfare = (SUM(marriageVW(:,:,:,:,:,2)*coupleYW(:,:,:,:,:)) + SUM(marriageVR(RETAGE:MAXAGE,:,:,2)*coupleYR(RETAGE:MAXAGE,:,:,:)))/(SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(RETAGE:MAXAGE,:,:,:)))

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

male_population = SUM(singleYW(:,:,:,:,1))+SUM(singleYR(:,:,:,:,1))
female_population = SUM(singleYW(:,:,:,:,2))+SUM(singleYR(:,:,:,:,2))
couple_population =  SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(:,:,:,:))

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
				 INCOME = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)  + UB(IS1,IE,2) + UB(IS2,IE,2)
				 INCOME1 = WAGE*EFFLONG(AGE,1)*W(IS1,1)*N(JN1) + min(R*A(IA),d_c)/2 + UB(IS1,IE,2)
				 INCOME2 = WAGE*EFFLONG(AGE,2)*W(IS2,2)*N(JN2) + min(R*A(IA),d_c)/2 + UB(IS2,IE,2)
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

ALLOCATE( temp_retire_single_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )
ALLOCATE( retire_single_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )
ALLOCATE( temp_retire_couple_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )
ALLOCATE( retire_couple_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )

ALLOCATE( temp_single_util_LS(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( single_util_LS(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( temp_single_util_C(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( single_util_C(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) ) 
ALLOCATE( temp_couple_util_LS(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
ALLOCATE( couple_util_LS(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
ALLOCATE( temp_couple_util_C(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
ALLOCATE( couple_util_C(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )

print*, 'source welfare', source_welfare


IF ((source_welfare==0)) THEN 
	ALLOCATE( bench_singleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) ) 
	ALLOCATE( bench_single_VR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) ) 
	ALLOCATE( bench_singleYR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) ) 
	ALLOCATE( bench_retire_single_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) ) 
	ALLOCATE( bench_singleIDCWC(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_singleIDCWN(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_single_VW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_singleYW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_single_util_C(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_single_util_LS(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )

	ALLOCATE( bench_coupleIDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )
	ALLOCATE( bench_couple_VR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )
	ALLOCATE( bench_coupleYR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH) )
	ALLOCATE( bench_retire_couple_util_C(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )
	ALLOCATE( bench_coupleIDCWC(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( bench_coupleIDCWN(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( bench_couple_VW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( bench_coupleYW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )
	ALLOCATE( bench_couple_util_C(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
	ALLOCATE( bench_couple_util_LS(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH) )	
END IF 

IF (CV==0) THEN 
	ALLOCATE( bench_single_VR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) ) 
	ALLOCATE( bench_single_VW(1:RETAGE-1,NGRIDA,nn,NGRIDEH,2) )
	ALLOCATE( bench_couple_VR(RETAGE:MAXAGE,NGRIDA,NGRIDH,NGRIDEH,2) )
	ALLOCATE( bench_couple_VW(1:RETAGE-1,NGRIDA,nn,nn,NGRIDEH,2) )
END IF 

temp_retire_single_util_C(:,:,:,:,:) = 0.0
retire_single_util_C(:,:,:,:,:) = 0.0
temp_retire_couple_util_C(:,:,:,:,:) = 0.0
retire_couple_util_C(:,:,:,:,:) = 0.0

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
util_welfare_id_working = 0.0
util_welfare_id_retiree = 0.0

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
		DO IH=1,NGRIDH
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
				
				
					temp_retire_single_util_C(AGE,IA,IH,IE,IG) = log(singleIDCRC(AGE,IA,IH,IE,IG))
					retire_single_util_C(AGE,IA,IH,IE,IG) =  temp_retire_single_util_C(AGE,IA,IH,IE,IG)*singleYR(AGE,IA,IH,IE,IG) 
					util_welfare_id = util_welfare_id + retire_single_util_C(AGE,IA,IH,IE,IG)
					util_welfare_id_retiree = util_welfare_id_retiree + retire_single_util_C(AGE,IA,IH,IE,IG)

					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCRC(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG)
					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + 0.0
					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + retire_single_util_C(AGE,IA,IE,IG)
					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYR(AGE,IA,IE,IG)

					IF (CV==0) THEN 
						bench_single_VR(AGE,IA,IH,IE,IG) = temp_retire_single_util_C(AGE,IA,IH,IE,IG)
					END IF 

					IF ((source_welfare==0)) THEN 
						bench_singleIDCRC(AGE,IA,IH,IE,IG) = singleIDCRC(AGE,IA,IH,IE,IG)
						bench_single_VR(AGE,IA,IH,IE,IG) = temp_retire_single_util_C(AGE,IA,IH,IE,IG)
						! bench_single_VR(AGE,IA,IH,IE,IG) = singleVR(AGE,IA,IH,IE,IG)
						bench_singleYR(AGE,IA,IH,IE,IG) = singleYR(AGE,IA,IH,IE,IG)
						bench_retire_single_util_C(AGE,IA,IH,IE,IG) = retire_single_util_C(AGE,IA,IH,IE,IG)							
					END IF 

				END DO 
			END DO
		END DO 
	END DO 

DO AGE = MAXAGE-1,RETAGE,-1

	IF (AGE==RETAGE) THEN
		j=1
	ELSEIF (AGE==RETAGE+1) THEN 
		j=2
	ELSEIF (AGE==RETAGE+2) THEN
		j=3
	ELSE
		j=4
	END IF 

    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH
				DO IG =1,2

					JA = singleIDCRA(AGE,IA,IH,IE,IG)
					JM = singleIDCRM(AGE,IA,IH,IE,IG)

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

					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCRC(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG)
					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + 0.0
					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + retire_single_util_C(AGE,IA,IE,IG)
					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYR(AGE,IA,IE,IG)

					HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
					IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
						XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
						JH = FLOOR(XH)
						DH = XH-JH
					ELSE IF (HNEXT>HMAX) THEN
						JH = 1
						DH = 0.0000	       
					ELSE IF (HNEXT<HMIN) THEN
						JH = NGRIDH
						DH = 0.0000
					END IF
				
					IF (JH<NGRIDH) THEN
						! temp_retire_single_util_C(AGE,IA,IH,IE,IG) = log(singleIDCRC(AGE,IA,IH,IE,IG)) + BETA*SUR(AGE,IG,IH)*( (1.0-DH)*temp_retire_single_util_C(AGE+1,JA,JH,IE,IG) + DH*temp_retire_single_util_C(AGE+1,JA,JH+1,IE,IG) ) 
						temp_retire_single_util_C(AGE,IA,IH,IE,IG) = log(singleIDCRC(AGE,IA,IH,IE,IG)) + BETA*SUR(AGE,IG,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,IG)) + DH*SUM(P_h(JH+1,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,IG)) ) 
					ELSE 
						! temp_retire_single_util_C(AGE,IA,IH,IE,IG) = log(singleIDCRC(AGE,IA,IH,IE,IG)) + BETA*SUR(AGE,IG,IH)*temp_retire_single_util_C(AGE+1,JA,JH,IE,IG)
						temp_retire_single_util_C(AGE,IA,IH,IE,IG) = log(singleIDCRC(AGE,IA,IH,IE,IG)) + BETA*SUR(AGE,IG,IH)*SUM(P_h(JH,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,IG))
					END IF 
						retire_single_util_C(AGE,IA,IH,IE,IG) =  temp_retire_single_util_C(AGE,IA,IH,IE,IG)*singleYR(AGE,IA,IH,IE,IG) 
						util_welfare_id = util_welfare_id + retire_single_util_C(AGE,IA,IH,IE,IG)
						util_welfare_id_retiree = util_welfare_id_retiree + retire_single_util_C(AGE,IA,IH,IE,IG)
					! temp_retire_single_util_C(AGE,IA,IE,IG) = log(singleIDCRC(AGE,IA,IE,IG)) + BETA*S(AGE,IG)*temp_retire_single_util_C(AGE+1,JA,IE,IG) 
					! retire_single_util_C(AGE,IA,IE,IG) =  temp_retire_single_util_C(AGE,IA,IE,IG)*singleYR(AGE,IA,IE,IG) 
					! util_welfare_id = util_welfare_id + retire_single_util_C(AGE,IA,IE,IG)	
					
					IF (CV==0) THEN 
						bench_single_VR(AGE,IA,IH,IE,IG) = temp_retire_single_util_C(AGE,IA,IH,IE,IG)
					END IF 

					IF ((source_welfare==0)) THEN
						bench_singleIDCRC(AGE,IA,IH,IE,IG) = singleIDCRC(AGE,IA,IH,IE,IG)
						bench_single_VR(AGE,IA,IH,IE,IG) = temp_retire_single_util_C(AGE,IA,IH,IE,IG)
						! bench_single_VR(AGE,IA,IH,IE,IG) = singleVR(AGE,IA,IH,IE,IG)
						bench_singleYR(AGE,IA,IH,IE,IG) = singleYR(AGE,IA,IH,IE,IG)	
						bench_retire_single_util_C(AGE,IA,IH,IE,IG) = retire_single_util_C(AGE,IA,IH,IE,IG)	
					END IF 								

				END DO 
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
							temp_single_util_C(AGE,IA,IS,IE,IG) =  log(singleIDCWC(AGE,IA,IS,IE,IG)) + BETA*( temp_retire_single_util_C(AGE+1,JA,1,JE,IG)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_single_util_C(AGE+1,JA,1,JE+1,IG)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
																						
							EXIT 
                
						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH
							! discount_V = discount_V + (BETA*singleVR(AGE+1,JA,JE,IG))*singleYW(AGE,IA,IS,IE,IG)
							
							temp_single_util_C(AGE,IA,IS,IE,IG) =  log(singleIDCWC(AGE,IA,IS,IE,IG)) + BETA*temp_retire_single_util_C(AGE+1,JA,1,JE,IG) 
							single_util_C(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

							EXIT

						END IF
					END DO

					util_welfare_id = util_welfare_id + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
					util_welfare_id_working = util_welfare_id_working + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)

					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCWC(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)
					! single_workingdist_incomethreshold(AGE,j,IG) = single_workingdist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)	

					IF (CV==0) THEN 
						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)	
					END IF 

					IF ((source_welfare==0)) THEN
						bench_singleIDCWC(AGE,IA,IS,IE,IG) = singleIDCWC(AGE,IA,IS,IE,IG)
						bench_singleIDCWN(AGE,IA,IS,IE,IG) = singleIDCWN(AGE,IA,IS,IE,IG)	
						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)	
						! bench_single_VW(AGE,IA,IS,IE,IG) = 	singleVW(AGE,IA,IS,IE,IG)
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
					util_welfare_id_working = util_welfare_id_working + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)

					! single_avg_cons_incomethreshold(AGE,j,IG) = single_avg_cons_incomethreshold(AGE,j,IG) + singleIDCWC(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_labor_incomethreshold(AGE,j,IG) = single_avg_labor_incomethreshold(AGE,j,IG) + N(JN)*singleYW(AGE,IA,IS,IE,IG)
					! single_avg_val_incomethreshold(AGE,j,IG) = single_avg_val_incomethreshold(AGE,j,IG) + single_util_C(AGE,IA,IS,IE,IG) + single_util_LS(AGE,IA,IS,IE,IG)
					! single_dist_incomethreshold(AGE,j,IG) = single_dist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)
					! single_workingdist_incomethreshold(AGE,j,IG) = single_workingdist_incomethreshold(AGE,j,IG) + singleYW(AGE,IA,IS,IE,IG)

					IF (CV==0) THEN 
						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)
					END IF 

					IF ((source_welfare==0)) THEN
						bench_singleIDCWC(AGE,IA,IS,IE,IG) = singleIDCWC(AGE,IA,IS,IE,IG)
						bench_singleIDCWN(AGE,IA,IS,IE,IG) = singleIDCWN(AGE,IA,IS,IE,IG)							
						bench_single_VW(AGE,IA,IS,IE,IG) = temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG)	
						! bench_single_VW(AGE,IA,IS,IE,IG) = singleVW(AGE,IA,IS,IE,IG) 
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
		DO IH=1,NGRIDH    
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

				! couple_avg_cons_incomethreshold(AGE,j,1) = couple_avg_cons_incomethreshold(AGE,j,1) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
				! couple_avg_cons_incomethreshold(AGE,j,2) = couple_avg_cons_incomethreshold(AGE,j,2) + (coupleIDCRC(AGE,IA,IE)/eta)*coupleYR(AGE,IA,IE)
				! couple_avg_labor_incomethreshold(AGE,j,:) = couple_avg_labor_incomethreshold(AGE,j,:) + 0.0		
				! couple_avg_val_incomethreshold(AGE,j,1) = couple_avg_val_incomethreshold(AGE,j,1) + retire_couple_util_C(AGE,IA,IE,1)
				! couple_avg_val_incomethreshold(AGE,j,2) = couple_avg_val_incomethreshold(AGE,j,2) + retire_couple_util_C(AGE,IA,IE,2)
				! couple_dist_incomethreshold(AGE,j,1) = couple_dist_incomethreshold(AGE,j,1) + coupleYR(AGE,IA,IE)	
				! couple_dist_incomethreshold(AGE,j,2) = couple_dist_incomethreshold(AGE,j,2) + coupleYR(AGE,IA,IE)

				DO IG =1,2
					
					temp_retire_couple_util_C(AGE,IA,IH,IE,IG) = log(coupleIDCRC(AGE,IA,IH,IE)/eta)
					retire_couple_util_C(AGE,IA,IH,IE,IG) =  temp_retire_couple_util_C(AGE,IA,IH,IE,IG)*coupleYR(AGE,IA,IH,IE) 		
					util_welfare_id = util_welfare_id +	retire_couple_util_C(AGE,IA,IH,IE,IG)
					util_welfare_id_retiree = util_welfare_id_retiree +	retire_couple_util_C(AGE,IA,IH,IE,IG)
				
				END DO 

				IF (CV==0) THEN 
					bench_couple_VR(AGE,IA,IH,IE,1) = temp_retire_couple_util_C(AGE,IA,IH,IE,1)
					bench_couple_VR(AGE,IA,IH,IE,2) = temp_retire_couple_util_C(AGE,IA,IH,IE,2)
				END IF 

				IF ((source_welfare==0)) THEN
					bench_coupleIDCRC(AGE,IA,IH,IE,1) = coupleIDCRC(AGE,IA,IH,IE)/eta
					bench_coupleIDCRC(AGE,IA,IH,IE,2) = coupleIDCRC(AGE,IA,IH,IE)/eta
					bench_couple_VR(AGE,IA,IH,IE,1) = temp_retire_couple_util_C(AGE,IA,IH,IE,1)
					bench_couple_VR(AGE,IA,IH,IE,2) = temp_retire_couple_util_C(AGE,IA,IH,IE,2)
					! bench_couple_VR(AGE,IA,IH,IE) = coupleVR(AGE,IA,IH,IE)
					bench_coupleYR(AGE,IA,IH,IE) = coupleYR(AGE,IA,IH,IE)
					bench_retire_couple_util_C(AGE,IA,IH,IE,1) = retire_couple_util_C(AGE,IA,IH,IE,1)
					bench_retire_couple_util_C(AGE,IA,IH,IE,2) = retire_couple_util_C(AGE,IA,IH,IE,2)
				END IF 

			END DO 
		END DO 
	END DO 


DO AGE = MAXAGE-1,RETAGE,-1

	IF (AGE==RETAGE) THEN
		j=1
	ELSEIF (AGE==RETAGE+1) THEN 
		j=2
	ELSEIF (AGE==RETAGE+2) THEN
		j=3
	ELSE
		j=4
	END IF 

    DO IA = 1,NGRIDA      
		DO IH=1,NGRIDH 
			DO IE = 1,NGRIDEH

				JA = coupleIDCRA(AGE,IA,IH,IE)
				JM = coupleIDCRM(AGE,IA,IH,IE)

				! TINCOME = 2*SS(IE) + R*A(IA)


				HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
				IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
					XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
					JH = FLOOR(XH)
					DH = XH-JH
				ELSE IF (HNEXT>HMAX) THEN
					JH = 1
					DH = 0.0000	       
				ELSE IF (HNEXT<HMIN) THEN
					JH = NGRIDH
					DH = 0.0000
				END IF

				IF (JH<NGRIDH) THEN
					! temp_retire_couple_util_C(AGE,IA,IH,IE,1) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*temp_retire_couple_util_C(AGE+1,JA,JH,IE,1)+DH*temp_retire_couple_util_C(AGE+1,JA,JH+1,IE,1) ) &
					! 										+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*temp_retire_single_util_C(AGE+1,JA,JH,IE,1)+DH*temp_retire_single_util_C(AGE+1,JA,JH+1,IE,1) )
					! temp_retire_couple_util_C(AGE,IA,IH,IE,2) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*temp_retire_couple_util_C(AGE+1,JA,JH,IE,2)+DH*temp_retire_couple_util_C(AGE+1,JA,JH+1,IE,2) )&
					! 										+ BETA*SUR(AGE,2,IH)*(1-SUR(AGE,1,IH))*( (1.0-DH)*temp_retire_single_util_C(AGE+1,JA,JH,IE,2)+DH*temp_retire_single_util_C(AGE+1,JA,JH+1,IE,2) )
					temp_retire_couple_util_C(AGE,IA,IH,IE,1) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*temp_retire_couple_util_C(AGE+1,JA,:,IE,1))+DH*SUM(P_h(JH+1,:,j)*temp_retire_couple_util_C(AGE+1,JA,:,IE,1)) ) &
															+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*( (1.0-DH)*SUM(P_h(JH,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,1))+DH*SUM(P_h(JH+1,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,1)) )
					temp_retire_couple_util_C(AGE,IA,IH,IE,2) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*( (1.0-DH)*SUM(P_h(JH,:,j)*temp_retire_couple_util_C(AGE+1,JA,:,IE,2))+DH*SUM(P_h(JH+1,:,j)*temp_retire_couple_util_C(AGE+1,JA,:,IE,2)) ) &
															+ BETA*SUR(AGE,2,IH)*(1-SUR(AGE,1,IH))*( (1.0-DH)*SUM(P_h(JH,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,2))+DH*SUM(P_h(JH+1,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,2)) )
				ELSE
					! temp_retire_couple_util_C(AGE,IA,IH,IE,1) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*temp_retire_couple_util_C(AGE+1,JA,JH,IE,1) &
					! 											+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*temp_retire_single_util_C(AGE+1,JA,JH,IE,1) 												
					! temp_retire_couple_util_C(AGE,IA,IH,IE,2) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*temp_retire_couple_util_C(AGE+1,JA,JH,IE,2) &
					! 											+ BETA*SUR(AGE,2,IH)*(1-SUR(AGE,1,IH))*temp_retire_single_util_C(AGE+1,JA,JH,IE,2)
					temp_retire_couple_util_C(AGE,IA,IH,IE,1) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*temp_retire_couple_util_C(AGE+1,JA,:,IE,1)) &
																+ BETA*SUR(AGE,1,IH)*(1-SUR(AGE,2,IH))*SUM(P_h(JH,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,1))												
					temp_retire_couple_util_C(AGE,IA,IH,IE,2) =  log(coupleIDCRC(AGE,IA,IH,IE)/eta) + BETA*SUR(AGE,1,IH)*SUR(AGE,2,IH)*SUM(P_h(JH,:,j)*temp_retire_couple_util_C(AGE+1,JA,:,IE,2)) &
																+ BETA*SUR(AGE,2,IH)*(1-SUR(AGE,1,IH))*SUM(P_h(JH,:,j)*temp_retire_single_util_C(AGE+1,JA,:,IE,2))
				END IF 									

				retire_couple_util_C(AGE,IA,IH,IE,1) =  temp_retire_couple_util_C(AGE,IA,IH,IE,1)*coupleYR(AGE,IA,IH,IE) 
				retire_couple_util_C(AGE,IA,IH,IE,2) =  temp_retire_couple_util_C(AGE,IA,IH,IE,2)*coupleYR(AGE,IA,IH,IE) 
				
				util_welfare_id = util_welfare_id +	retire_couple_util_C(AGE,IA,IH,IE,1) +	retire_couple_util_C(AGE,IA,IH,IE,2)
				util_welfare_id_retiree = util_welfare_id_retiree +	retire_couple_util_C(AGE,IA,IH,IE,1) +	retire_couple_util_C(AGE,IA,IH,IE,2)	
				
				IF (CV==0) THEN 
					bench_couple_VR(AGE,IA,IH,IE,1) = temp_retire_couple_util_C(AGE,IA,IH,IE,1)
					bench_couple_VR(AGE,IA,IH,IE,2) = temp_retire_couple_util_C(AGE,IA,IH,IE,2)
				END IF 

				IF ((source_welfare==0)) THEN
					bench_coupleIDCRC(AGE,IA,IH,IE,1) = coupleIDCRC(AGE,IA,IH,IE)/eta
					bench_coupleIDCRC(AGE,IA,IH,IE,2) = coupleIDCRC(AGE,IA,IH,IE)/eta
					bench_couple_VR(AGE,IA,IH,IE,1) = temp_retire_couple_util_C(AGE,IA,IH,IE,1)
					bench_couple_VR(AGE,IA,IH,IE,2) = temp_retire_couple_util_C(AGE,IA,IH,IE,2)
					! bench_couple_VR(AGE,IA,IH,IE) = coupleVR(AGE,IA,IH,IE)
					bench_coupleYR(AGE,IA,IH,IE) = coupleYR(AGE,IA,IH,IE)	
					bench_retire_couple_util_C(AGE,IA,IH,IE,1) = retire_couple_util_C(AGE,IA,IH,IE,1)
					bench_retire_couple_util_C(AGE,IA,IH,IE,2) = retire_couple_util_C(AGE,IA,IH,IE,2)
				END IF 					

			END DO 
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
							
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*( temp_retire_couple_util_C(AGE+1,JA,1,JE,1)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,1,JE+1,1)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) )
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*( temp_retire_couple_util_C(AGE+1,JA,1,JE,2)*(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1)) + temp_retire_couple_util_C(AGE+1,JA,1,JE+1,2)*(1.0-(EH_temp-EH(JE+1))/(EH(JE)-EH(JE+1))) ) 
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
														
							EXIT   

						ELSEIF (i==NGRIDEH) THEN  
							JE = NGRIDEH  
							
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,1) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*temp_retire_couple_util_C(AGE+1,JA,1,JE,1)
							temp_couple_util_C(AGE,IA,IS1,IS2,IE,2) =  log(coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta) + BETA*temp_retire_couple_util_C(AGE+1,JA,1,JE,2) 
							couple_util_C(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)*coupleYW(AGE,IA,IS1,IS2,IE)
							couple_util_C(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)*coupleYW(AGE,IA,IS1,IS2,IE)
						
							EXIT

						END IF
					END DO 

					util_welfare_id = util_welfare_id + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)
					util_welfare_id_working = util_welfare_id_working + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)

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

					IF (CV==0) THEN 
						bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
						bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)
					END IF 

					IF ((source_welfare==0)) THEN
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,1) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,2) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)			
						bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
						bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)
						! bench_couple_VW(AGE,IA,IS1,IS2,IE) = coupleVW(AGE,IA,IS1,IS2,IE)							
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
					util_welfare_id_working = util_welfare_id_working + couple_util_C(AGE,IA,IS1,IS2,IE,1) + couple_util_C(AGE,IA,IS1,IS2,IE,2) + couple_util_LS(AGE,IA,IS1,IS2,IE)

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

					IF (CV==0) THEN 
						bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
						bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)
					END IF 

					IF ((source_welfare==0)) THEN
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,1) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWC(AGE,IA,IS1,IS2,IE,2) = coupleIDCWC(AGE,IA,IS1,IS2,IE)/eta
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,1) = coupleIDCWN(AGE,IA,IS1,IS2,IE,1)
						bench_coupleIDCWN(AGE,IA,IS1,IS2,IE,2) = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)					
						bench_couple_VW(AGE,IA,IS1,IS2,IE,1) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,1)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,1)
						bench_couple_VW(AGE,IA,IS1,IS2,IE,2) = temp_couple_util_C(AGE,IA,IS1,IS2,IE,2)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,2)	
						! bench_couple_VW(AGE,IA,IS1,IS2,IE) = coupleVW(AGE,IA,IS1,IS2,IE)			
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

!***************************** Martin Floden 2001 JME *******************************

! Method by Baris&Markus 2014 RED:
! PARETIAN WELFARE: Aggregate consumption equivalents before time aggregation.
! Notes: Assume everyone gets average leisure, lbar, and solve for C(k,z) in 
! C^(1-sigma)/(1-sigma) + theta (1-lbar)^(1-eps)/(1-eps) = (1-beta)V(k,z)

ALLOCATE(certeqcons_singlemale(nn),certeqlab_singlemale(nn))
ALLOCATE(certeqcons_singlefemale(nn),certeqlab_singlefemale(nn))
ALLOCATE(certeqcons_couple(nn,nn,2),certeqlab_couple(nn,nn,2))
ALLOCATE(agg_certeqcons_couple(2),agg_certeqlab_couple(2))
ALLOCATE(V_certeq_couple(2))
ALLOCATE(AggL_couple(2),cost_unc_couple(2),expV_certeq_couple(2),cost_ineq_couple(2),AggC_couple_leicomp(2),AggL_couple_bm(2))
ALLOCATE(temp_single_discount(MAXAGE,2),single_discount(2))
ALLOCATE(temp_couple_discount1(MAXAGE,2),temp_couple_discount2(MAXAGE,2),couple_discount1(2),couple_discount2(2))

! Use this survival function to replace SUR
! ALLOCATE(S(MAXAGE,2))
! 	S(1:RETAGE-1,:) = 1.0	
! 	DO IG=1,2
! 		DO AGE=RETAGE,MAXAGE
! 	   		S(AGE,IG) = 1/(1+EXP(c0(IG)+c1(IG)*AGE+c2(IG)*(AGE**2)+c3(IG)*HLONG(AGE)))             ! quadratic form of sur. prob. as a fn of age
! 		END DO 
! 	END DO 
! 	S(MAXAGE,:) = 0.0

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
DO AGE = RETAGE+1,MAXAGE-1
	temp_couple_discount1(AGE,1) = temp_couple_discount1(AGE-1,1)*BETA*S(AGE,1)*S(AGE,2)
	temp_couple_discount2(AGE,1) = temp_couple_discount1(AGE-1,1)*BETA*S(AGE,1)*(1.0-S(AGE,2))
	temp_couple_discount1(AGE,2) = temp_couple_discount1(AGE-1,2)*BETA*S(AGE,1)*S(AGE,2)
	temp_couple_discount2(AGE,2) = temp_couple_discount1(AGE-1,2)*BETA*S(AGE,2)*(1.0-S(AGE,1))
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
AggC_singlemale = ( SUM(singleIDCWC(:,:,:,:,1)*singleYW(:,:,:,:,1)) + SUM(singleIDCRC(:,:,:,:,1)*singleYR(:,:,:,:,1)) )/( SUM(singleYW(:,:,:,:,1)) + SUM(singleYR(:,:,:,:,1)) )
AggC_singlefemale = ( SUM(singleIDCWC(:,:,:,:,2)*singleYW(:,:,:,:,2)) + SUM(singleIDCRC(:,:,:,:,2)*singleYR(:,:,:,:,2)) )/( SUM(singleYW(:,:,:,:,2)) + SUM(singleYR(:,:,:,:,2)) )

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
AggC_couple = ( SUM(coupleIDCWC(:,:,:,:,:)*coupleYW(:,:,:,:,:)) + SUM(coupleIDCRC(:,:,:,:)*coupleYR(:,:,:,:)) )/( SUM(coupleYW(:,:,:,:,:))+SUM(coupleYR(:,:,:,:)) )

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
	! AggC_singlemale_leicomp = exp( log(AggC_singlemale) + (1.0-BETA**(RETAGE-1))*( theta_single_male*(AggL_singlemale**(1+sigma_lab_male))/(1+sigma_lab_male) -  theta_single_male*(AggL_singlemale_bm**(1+sigma_lab_male))/(1+sigma_lab_male) )/(1.0-BETA)/single_discount(1) )
	AggC_singlemale_leicomp = exp(log(AggC_singlemale) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*(theta_single_male*(AggL_singlemale**(1+sigma_lab_male))/(1+sigma_lab_male) - theta_single_male*(AggL_singlemale_bm**(1+sigma_lab_male))/(1+sigma_lab_male))/single_discount(1))

	! single female
	AggC_singlefemale_leicomp = exp(log(AggC_singlefemale) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*(theta_single_female*(AggL_singlefemale**(1+sigma_lab_female))/(1+sigma_lab_female) -  theta_single_female*(AggL_singlefemale_bm**(1+sigma_lab_female))/(1+sigma_lab_female))/single_discount(2))

	! due to the survival prob, married couple could become single after retirement. the eta is eliminated in the equation
	! married male
	! AggC_couple_leicomp(1) = exp( log(AggC_couple) + (1.0-BETA**(RETAGE-1))*( theta_married_male*(AggL_couple(1)**(1+sigma_lab_male))/(1+sigma_lab_male) -  theta_married_male*(AggL_couple_male_bm**(1+sigma_lab_male))/(1+sigma_lab_male) )/(1.0-BETA)/(couple_discount1(1)+couple_discount2(1)) )
	AggC_couple_leicomp(1) = exp( log(AggC_couple) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*( theta_married_male*(AggL_couple(1)**(1+sigma_lab_male))/(1+sigma_lab_male) -  theta_married_male*(AggL_couple_male_bm**(1+sigma_lab_male))/(1+sigma_lab_male) )/(couple_discount1(1)+couple_discount2(1)) )

	! married female
	! AggC_couple_leicomp(2) = exp( log(AggC_couple) + (1.0-BETA**(RETAGE-1))*( theta_married_female*(AggL_couple(2)**(1+sigma_lab_female))/(1+sigma_lab_female) -  theta_married_female*(AggL_couple_female_bm**(1+sigma_lab_female))/(1+sigma_lab_female) )/(1.0-BETA)/(couple_discount1(2)+couple_discount2(2)) )
	AggC_couple_leicomp(2) = exp( log(AggC_couple) + ((1.0 - BETA**(RETAGE-1))/(1.0 - BETA))*( theta_married_female*(AggL_couple(2)**(1+sigma_lab_female))/(1+sigma_lab_female) -  theta_married_female*(AggL_couple_female_bm**(1+sigma_lab_female))/(1+sigma_lab_female) )/(couple_discount1(2)+couple_discount2(2)) )

END IF 

END SUBROUTINE
!************************************************************************************************************************************
SUBROUTINE compensating_variation

! working
ALLOCATE(read_vector_single((RETAGE-1)*NGRIDA*nn*NGRIDEH*2))
ALLOCATE(read_vector_couple((RETAGE-1)*NGRIDA*nn*nn*NGRIDEH*2))
ALLOCATE(bench_single_VW(RETAGE-1, NGRIDA, nn, NGRIDEH, 2))
ALLOCATE(bench_couple_VW(RETAGE-1, NGRIDA, nn, nn, NGRIDEH, 2))

	OPEN(UNIT=27,FILE='bench_single_VW.txt')
		READ(27,*) read_vector_single
	CLOSE(27)
	bench_single_VW = reshape(read_vector_single, (/ RETAGE-1, NGRIDA, nn, NGRIDEH, 2 /))	
	print*, "bench_single_VW"

	OPEN(UNIT=27,FILE='bench_couple_VW.txt')
		READ(27,*) read_vector_couple
	CLOSE(27)
	bench_couple_VW = reshape(read_vector_couple, (/ RETAGE-1, NGRIDA, nn, nn, NGRIDEH, 2 /))	
	print*, "bench_couple_VW"

DEALLOCATE(read_vector_single)
DEALLOCATE(read_vector_couple)

! retiree
ALLOCATE(read_vector_single((MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2))
ALLOCATE(read_vector_couple((MAXAGE-RETAGE+1)*NGRIDA*NGRIDH*NGRIDEH*2))
ALLOCATE(bench_single_VR(RETAGE:MAXAGE, NGRIDA, NGRIDH, NGRIDEH, 2))
ALLOCATE(bench_couple_VR(RETAGE:MAXAGE, NGRIDA, NGRIDH, NGRIDEH, 2))


	OPEN(UNIT=27,FILE='bench_single_VR.txt')
		READ(27,*) read_vector_single
	CLOSE(27)
	bench_single_VR = reshape(read_vector_single, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDH, NGRIDEH, 2 /))	
	print*, "bench_single_VR"

	OPEN(UNIT=27,FILE='bench_couple_VR.txt')
		READ(27,*) read_vector_couple
	CLOSE(27)
	bench_couple_VR = reshape(read_vector_couple, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDH, NGRIDEH, 2 /))	
	print*, "bench_couple_VR"

DEALLOCATE(read_vector_single)
DEALLOCATE(read_vector_couple)


! compensating variation
ALLOCATE(youngage_VW_delta_single(RETAGE-1, NGRIDA,nn,NGRIDEH,2))
ALLOCATE(midage_VW_delta_single(RETAGE-1,NGRIDA,nn,NGRIDEH,2))
ALLOCATE(uprime_alt_working_single(RETAGE-1,NGRIDA,nn,NGRIDEH,2))
ALLOCATE(cv_working_single(RETAGE-1,NGRIDA,nn,NGRIDEH,2))

ALLOCATE(youngage_VW_delta_couple(RETAGE-1,NGRIDA,nn,nn,NGRIDEH ))
ALLOCATE(midage_VW_delta_couple(RETAGE-1,NGRIDA,nn,nn,NGRIDEH))
ALLOCATE(uprime_alt_working_couple(RETAGE-1,NGRIDA,nn,nn,NGRIDEH))
ALLOCATE(cv_working_couple(RETAGE-1,NGRIDA,nn,nn,NGRIDEH))

ALLOCATE(VR_delta_single((MAXAGE-RETAGE+1),NGRIDA,NGRIDH,NGRIDEH,2))
ALLOCATE(uprime_alt_retire_single((MAXAGE-RETAGE+1),NGRIDA,NGRIDH,NGRIDEH,2))
ALLOCATE(cv_retire_single((MAXAGE-RETAGE+1),NGRIDA,NGRIDH,NGRIDEH,2))

ALLOCATE(VR_delta_couple((MAXAGE-RETAGE+1),NGRIDA,NGRIDH,NGRIDEH))
ALLOCATE(uprime_alt_retire_couple((MAXAGE-RETAGE+1),NGRIDA,NGRIDH,NGRIDEH))
ALLOCATE(cv_retire_couple((MAXAGE-RETAGE+1),NGRIDA,NGRIDH,NGRIDEH))



DO AGE = 1,RETAGE-1
	DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2
					
					uprime_alt_working_single(AGE,IA,IS,IE,IG) = 1.0/singleIDCWC(AGE,IA,IS,IE,IG)

					IF(AGE<=4) THEN	
						! youngage_VW_delta_single(AGE,IA,IS,IE,IG) =  bench_single_VW(AGE,IA,IS,IE,IG) - singleVW(AGE,IA,IS,IE,IG)
						youngage_VW_delta_single(AGE,IA,IS,IE,IG) =  bench_single_VW(AGE,IA,IS,IE,IG) - (temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG))
						cv_working_single(AGE,IA,IS,IE,IG) = youngage_VW_delta_single(AGE,IA,IS,IE,IG)/uprime_alt_working_single(AGE,IA,IS,IE,IG)	!this is now in units of assets. being in alt with additioanl assets CV equivalent to being in V. if CV<0, alt is better than bm.
					ELSE
						! midage_VW_delta_single(AGE,IA,IS,IE,IG) =  bench_single_VW(AGE,IA,IS,IE,IG) - singleVW(AGE,IA,IS,IE,IG)
						midage_VW_delta_single(AGE,IA,IS,IE,IG) = bench_single_VW(AGE,IA,IS,IE,IG) - (temp_single_util_C(AGE,IA,IS,IE,IG) + temp_single_util_LS(AGE,IA,IS,IE,IG))
						cv_working_single(AGE,IA,IS,IE,IG) = midage_VW_delta_single(AGE,IA,IS,IE,IG)/uprime_alt_working_single(AGE,IA,IS,IE,IG)
					END IF 

					cv_working_single(AGE,IA,IS,IE,IG) = cv_working_single(AGE,IA,IS,IE,IG)*singleYW(AGE,IA,IS,IE,IG)

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
					IF(AGE<=4) THEN	
						! youngage_VW_delta_couple(AGE,IA,IS1,IS2,IE) = bench_couple_VW(AGE,IA,IS1,IS2,IE) - coupleVW(AGE,IA,IS1,IS2,IE)
						youngage_VW_delta_couple(AGE,IA,IS1,IS2,IE) = SUM(bench_couple_VW(AGE,IA,IS1,IS2,IE,:) - (temp_couple_util_C(AGE,IA,IS1,IS2,IE,:)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,:)))
						cv_working_couple(AGE,IA,IS1,IS2,IE) = youngage_VW_delta_couple(AGE,IA,IS1,IS2,IE)/uprime_alt_working_couple(AGE,IA,IS1,IS2,IE)
					ELSE
						! midage_VW_delta_couple(AGE,IA,IS1,IS2,IE) = bench_couple_VW(AGE,IA,IS1,IS2,IE) - coupleVW(AGE,IA,IS1,IS2,IE)
						midage_VW_delta_couple(AGE,IA,IS1,IS2,IE) = SUM(bench_couple_VW(AGE,IA,IS1,IS2,IE,:) - (temp_couple_util_C(AGE,IA,IS1,IS2,IE,:)+temp_couple_util_LS(AGE,IA,IS1,IS2,IE,:)))
						cv_working_couple(AGE,IA,IS1,IS2,IE) = midage_VW_delta_couple(AGE,IA,IS1,IS2,IE)/uprime_alt_working_couple(AGE,IA,IS1,IS2,IE)
					END IF
					
					cv_working_couple(AGE,IA,IS1,IS2,IE) = cv_working_couple(AGE,IA,IS1,IS2,IE)*coupleYW(AGE,IA,IS1,IS2,IE)

				END DO 
			END DO 	 
		END DO
    END DO
END DO

DO AGE=RETAGE,MAXAGE
	DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH
				DO IG=1,2

					! VR_delta_single(AGE,IA,IH,IE,IG) =  bench_single_VR(AGE,IA,IH,IE,IG) - singleVR(AGE,IA,IH,IE,IG)
					VR_delta_single(AGE,IA,IH,IE,IG) = bench_single_VR(AGE,IA,IH,IE,IG) - temp_retire_single_util_C(AGE,IA,IH,IE,IG)
					uprime_alt_retire_single(AGE,IA,IH,IE,IG) = 1.0/singleIDCRC(AGE,IA,IH,IE,IG)
					cv_retire_single(AGE,IA,IH,IE,IG) = (VR_delta_single(AGE,IA,IH,IE,IG)/uprime_alt_retire_single(AGE,IA,IH,IE,IG))*singleYR(AGE,IA,IH,IE,IG)

				END DO 
			END DO 	 
		END DO
    END DO
END DO

DO AGE=RETAGE,MAXAGE
	DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH	

				! VR_delta_couple(AGE,IA,IH,IE) =  bench_couple_VR(AGE,IA,IH,IE) - coupleVR(AGE,IA,IH,IE)
				VR_delta_couple(AGE,IA,IH,IE) = SUM(bench_couple_VR(AGE,IA,IH,IE,:) - temp_retire_couple_util_C(AGE,IA,IH,IE,:))
				uprime_alt_retire_couple(AGE,IA,IH,IE) = 2.0*(1.0/coupleIDCRC(AGE,IA,IH,IE))
				cv_retire_couple(AGE,IA,IH,IE) = (VR_delta_couple(AGE,IA,IH,IE)/uprime_alt_retire_couple(AGE,IA,IH,IE))*coupleYR(AGE,IA,IH,IE)

			END DO  
		END DO         
	END DO
END DO

! people get confused by CV<0 being gains: multiply by -1
cv_working_single = -cv_working_single
cv_working_couple = -cv_working_couple
cv_retire_single = -cv_retire_single
cv_retire_couple = -cv_retire_couple


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

! Welfare improvement of the optimal taxation in terms of CEV

! all living individuals' welfare (utilitarian)
! opt_welfare = -276.57331517		
no_pension_welfare =  -1.44164019
no_EHI_welfare = -0.65281586		
no_prog_welfare =  -0.77848283
no_allpolicy_welfare = -1.77118797

! CRRA utility
! CEV_optimal = (( opt_welfare - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:)) ) &
! 			  /( sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:)) + sum(single_util_C(1:RETAGE-1,:,:,:,:)) + sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:)) + sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) ) )**(1.0/(1-sigma)) - 1.0

! Log utility
! CEV_optimal = exp(( opt_welfare - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
! 			  - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0

! no_pension_CEV = exp(( no_pension_welfare - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
! 			  - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0
! no_EHI_CEV = exp(( no_EHI_welfare - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
! 			  - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0
! no_prog_CEV = exp(( no_prog_welfare - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
! 			  - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0	

no_pension_CEV = exp( (no_pension_welfare - util_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
no_EHI_CEV = exp( (no_EHI_welfare - util_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2))  ) - 1.0
no_prog_CEV = exp( (no_prog_welfare - util_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2))  ) - 1.0	
no_allpolicy_CEV = exp( (no_allpolicy_welfare - util_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2))  ) - 1.0				  

! newborn welfare CEV
! w/o pension : -1.62876384
! w/o UB : -0.99104436
! w/o EHI : -1.06600776
! w/o prog : -1.94300609

no_pension_welfare_newborn = -0.40325163
! no_UB_welfare = -0.87641795
no_EHI_welfare_newborn = -0.38859328
no_prog_welfare_newborn = -0.97455049
no_allpolicy_welfare_newborn = -0.4277718
pop_birth = sum(singleYW(1,:,:,:,:))+2*sum(coupleYW(1,:,:,:,:))

! no_pension_CEV_newborn = exp(( no_pension_welfare_newborn - sum(single_util_LS(1,:,:,:,:))/pop_birth - sum(couple_util_LS(1,:,:,:,:))/pop_birth  &
! 			   - sum(single_util_C(1,:,:,:,:))/pop_birth - sum(couple_util_C(1,:,:,:,:,:))/pop_birth )) - 1.0

! no_UB_CEV_newborn = exp(( no_UB_welfare - sum(single_util_LS(1,:,:,:,:))/pop_birth - sum(couple_util_LS(1,:,:,:,:))/pop_birth  &
! 			   - sum(single_util_C(1,:,:,:,:))/pop_birth - sum(couple_util_C(1,:,:,:,:,:))/pop_birth )) - 1.0

! no_EHI_CEV_newborn = exp(( no_EHI_welfare_newborn - sum(single_util_LS(1,:,:,:,:))/pop_birth - sum(couple_util_LS(1,:,:,:,:))/pop_birth  &
! 			   - sum(single_util_C(1,:,:,:,:))/pop_birth - sum(couple_util_C(1,:,:,:,:,:))/pop_birth )) - 1.0

! no_prog_CEV_newborn = exp(( no_prog_welfare_newborn - sum(single_util_LS(1,:,:,:,:))/pop_birth - sum(couple_util_LS(1,:,:,:,:))/pop_birth  &
! 			   - sum(single_util_C(1,:,:,:,:))/pop_birth - sum(couple_util_C(1,:,:,:,:,:))/pop_birth )) - 1.0
 
! no_pension_CEV_newborn = exp( (no_pension_welfare_newborn-veil_welfare_id)*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0
! no_UB_CEV_newborn      = exp( (no_UB_welfare-veil_welfare_id)*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0
! no_EHI_CEV_newborn 	   = exp( (no_EHI_welfare_newborn-veil_welfare_id)*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0
! no_prog_CEV_newborn    = exp( (no_prog_welfare_newborn-veil_welfare_id)*(1.0-BETA)/(1.0-BETA**MAXAGE) ) - 1.0
no_pension_CEV_newborn = exp( (no_pension_welfare_newborn-veil_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
! no_UB_CEV_newborn = exp( (no_UB_welfare-veil_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
no_EHI_CEV_newborn = exp( (no_EHI_welfare_newborn-veil_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
no_prog_CEV_newborn = exp( (no_prog_welfare_newborn-veil_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0
no_allpolicy_CEV_newborn = exp( (no_allpolicy_welfare_newborn-veil_welfare_id)/(sum(single_discount)+sum(couple_discount1)+sum(couple_discount2)) ) - 1.0

! average of every working individual CEV

no_pension_welfare_working = -31.2556
no_UB_welfare_working = -10.5463
no_EHI_welfare_working = -15.0988
no_prog_welfare_working = -23.9564
pop_working = sum(singleYW(1:RETAGE-1,:,:,:,:))+2*sum(coupleYW(1:RETAGE-1,:,:,:,:))

no_pension_CEV_working = exp(( no_pension_welfare_working - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
			   - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )/pop_working) - 1.0

no_UB_CEV_working = exp(( no_UB_welfare_working - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
			   - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )/pop_working) - 1.0

no_EHI_CEV_working = exp(( no_EHI_welfare_working - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
			   - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )/pop_working) - 1.0
no_prog_CEV_working = exp(( no_prog_welfare_working - sum(single_util_LS(1:RETAGE-1,:,:,:,:)) - sum(couple_util_LS(1:RETAGE-1,:,:,:,:))  &
			   - sum(single_util_C(1:RETAGE-1,:,:,:,:)) - sum(couple_util_C(1:RETAGE-1,:,:,:,:,:)) )/pop_working) - 1.0

! no_pension_CEV_working = (no_pension_welfare_working-util_welfare_id_working)

! average of every retired individual CEV
no_pension_welfare_retiree = -17.1440
no_UB_welfare_retiree = -5.1774
no_EHI_welfare_retiree = -7.2194
no_prog_welfare_retiree = -9.6643
pop_retiree = sum(singleYR(RETAGE:MAXAGE,:,:,:,:))+2*sum(coupleYR(RETAGE:MAXAGE,:,:,:))

no_pension_CEV_retiree = exp(( no_pension_welfare_retiree - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) )/pop_retiree) - 1.0
			   
no_UB_CEV_retiree = exp(( no_UB_welfare_retiree - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) )/pop_retiree) - 1.0

no_EHI_CEV_retiree = exp(( no_EHI_welfare_retiree - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) )/pop_retiree) - 1.0

no_prog_CEV_retiree = exp(( no_prog_welfare_retiree - sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:)) - sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:)) )/pop_retiree) - 1.0

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



! print*, 'opt_welfare=', opt_welfare
! print*, 'bench_welfare=', util_welfare_id
! print*, 'single_util_LS=', sum(single_util_LS(1:RETAGE-1,:,:,:,:))
! print*, 'couple_util_LS=', sum(couple_util_LS(1:RETAGE-1,:,:,:,:))
! print*, 'retire_single_util_C=', sum(retire_single_util_C(RETAGE:MAXAGE,:,:,:,:))
! print*, 'single_util_C=', sum(single_util_C(1:RETAGE-1,:,:,:,:))
! print*, 'retire_couple_util_C=', sum(retire_couple_util_C(RETAGE:MAXAGE,:,:,:,:))
! print*, 'couple_util_C', sum(couple_util_C(1:RETAGE-1,:,:,:,:,:))
print*, 'single_util_LS=', sum(single_util_LS(1,:,:,:,:))
print*, 'couple_util_LS=', sum(couple_util_LS(1,:,:,:,:))
print*, 'single_util_C=', sum(single_util_C(1,:,:,:,:))
print*, 'couple_util_C', sum(couple_util_C(1,:,:,:,:,:))
! print*, 'CEV_optimal=', CEV_optimal
! print*, 'CEV_incomethreshold', CEV_incomethreshold(:)


! OPEN(UNIT=60,FILE='cons.txt')
! 	write(60,*) singleIDCWC
! 	write(60,*) singleIDCRC
! 	write(60,*) coupleIDCWC
! 	write(60,*) coupleIDCRC

END SUBROUTINE
!************************************************************************************************************************************

!************************************************************************************************************************************
SUBROUTINE insurance_working

ALLOCATE(log_income_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_log_income_diff_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)) )
ALLOCATE(log_income_shock_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_log_income_shock_diff_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)) )
ALLOCATE(log_cons_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_log_cons_diff_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)) )
ALLOCATE(dist_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2), ageprofile_dist_single(NGRIDA*nn*NGRIDEH*2*nn*2,(RETAGE-2)) )
ALLOCATE(log_income_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2), ageprofile_log_income_diff_couple(NGRIDA*nn*nn*NGRIDEH*nn*nn*2,(RETAGE-2)))
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
ALLOCATE(shock(nn,2))
ALLOCATE(youngage_log_income_shock_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2))
ALLOCATE(youngage_log_cons_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2))
ALLOCATE(midage_log_income_shock_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2))
ALLOCATE(midage_log_cons_diff_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2))
ALLOCATE(youngage_dist_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2))
ALLOCATE(midage_dist_single((RETAGE-2)*NGRIDA*nn*NGRIDEH*2*nn*2))
ALLOCATE(youngage_log_income_shock_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2))
ALLOCATE(youngage_log_cons_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2))
ALLOCATE(midage_log_income_shock_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2))
ALLOCATE(midage_log_cons_diff_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2))
ALLOCATE(youngage_dist_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2))
ALLOCATE(midage_dist_couple((RETAGE-2)*NGRIDA*nn*nn*NGRIDEH*nn*nn*2))

shock(:,:) = W(:,:)
! shock(7,:) = 1.D-4	! Avoid log(0) for the unemployed
! shock(8,:) = 1.D-4

! Single working
individ = 0
individ_youngage = 0
individ_midage = 0
DO AGE=1,RETAGE-2
individ_age = 0
    DO IA=1,NGRIDA
		DO IS = 1,nn 
			DO IE=1,NGRIDEH
				DO IG=1,2
					
					JN = singleIDCWN(AGE,IA,IS,IE,IG)
					JA = singleIDCWA(AGE,IA,IS,IE,IG) 
					z_shock = W(IS,IG) + UB(IS,IE,1)
					! z_shock = shock(IS,IG) 
					INCOME = WAGE*EFFLONG(AGE,IG)*N(JN)*W(IS,IG) + UB(IS,IE,1) !+ R*A(IA)
					consumption = singleIDCWC(AGE,IA,IS,IE,IG)
					EH_temp = ((AGE-1)*EH(IE) + WAGE*EFFLONG(AGE,IG)*W(IS,IG)*N(JN))/(AGE)
					
					IF ((INCOME <= 1.D-4) .OR. (consumption <= 1.D-4)) THEN 
						GO TO 688
					END IF 						
					! IF (INCOME <= 1.D-4) THEN 
					! 	INCOME = 0.01
					! END IF 

						DO NEWIS = 1,nn
							DO i=1,NGRIDEH

								IF(EH(i)>EH_temp) THEN 
									NEWIE = i-1 				
							 
										JN=singleIDCWN(AGE+1,JA,NEWIS,NEWIE,IG)										
										z_shock_next = W(NEWIS,IG) + UB(NEWIS,NEWIE,1)
										! z_shock_next = shock(NEWIS,IG)
										INCOME_next = WAGE*EFFLONG(AGE+1,IG)*N(JN)*W(NEWIS,IG) + UB(NEWIS,NEWIE,1) !+ R*A(JA)
										consumption_next = singleIDCWC(AGE+1,JA,NEWIS,NEWIE,IG)
										IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
											EXIT
										END IF 
										! IF (INCOME_next <= 1.D-4) THEN 
										! 	INCOME_next = 0.01
										! END IF
										individ = individ + 1
										individ_age = individ_age + 1
										IF(AGE<=4) THEN
											individ_youngage = individ_youngage + 1
										ELSE
											individ_midage = individ_midage + 1
										END IF 
									! change in log = approximate percentage change
										log_income_shock_diff_single(individ) = log(z_shock_next) - log(z_shock)
										log_income_diff_single(individ) = log(INCOME_next) - log(INCOME)
										log_cons_diff_single(individ) = log(consumption_next) - log(consumption)

										ageprofile_log_income_shock_diff_single(individ_age,AGE) = log(z_shock_next) - log(z_shock)
										ageprofile_log_income_diff_single(individ_age,AGE) = log(INCOME_next) - log(INCOME)
										ageprofile_log_cons_diff_single(individ_age,AGE) = log(consumption_next) - log(consumption)

										IF(AGE<=4) THEN											
											youngage_log_income_shock_diff_single(individ_youngage) = log(z_shock_next) - log(z_shock)
											youngage_log_cons_diff_single(individ_youngage) = log(consumption_next) - log(consumption)
										ELSE 									
											midage_log_income_shock_diff_single(individ_midage) = log(z_shock_next) - log(z_shock)
											midage_log_cons_diff_single(individ_midage) = log(consumption_next) - log(consumption)
										END IF

									! percentage change 
										! log_income_shock_diff_single(individ) = (z_shock_next - z_shock)/z_shock
										! log_income_diff_single(individ) = (INCOME_next - INCOME)/INCOME
										! log_cons_diff_single(individ) = (consumption_next - consumption)/consumption

										dist_single(individ) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
										ageprofile_dist_single(individ_age,AGE) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
										IF(AGE<=4) THEN
											youngage_dist_single(individ_youngage) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
										ELSE
											midage_dist_single(individ_midage) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
										END IF 

										JN=singleIDCWN(AGE+1,JA,NEWIS,NEWIE+1,IG)										
										z_shock_next = W(NEWIS,IG) + UB(NEWIS,NEWIE+1,1)
										! z_shock_next = shock(NEWIS,IG)
										INCOME_next = WAGE*EFFLONG(AGE+1,IG)*N(JN)*W(NEWIS,IG) + UB(NEWIS,NEWIE+1,1) !+ R*A(JA)
										consumption_next = singleIDCWC(AGE+1,JA,NEWIS,NEWIE+1,IG)
										IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
											EXIT
										END IF 
										! IF (INCOME_next <= 1.D-4) THEN 
										! 	INCOME_next = 0.01
										! END IF
										individ = individ + 1
										individ_age = individ_age + 1
										IF(AGE<=4) THEN
											individ_youngage = individ_youngage + 1
										ELSE
											individ_midage = individ_midage + 1
										END IF 

									! change in log = approximate percentage change
										log_income_shock_diff_single(individ) = log(z_shock_next) - log(z_shock)
										log_income_diff_single(individ) = log(INCOME_next) - log(INCOME)
										log_cons_diff_single(individ) = log(consumption_next) - log(consumption)

										ageprofile_log_income_shock_diff_single(individ_age,AGE) = log(z_shock_next) - log(z_shock)
										ageprofile_log_income_diff_single(individ_age,AGE) = log(INCOME_next) - log(INCOME)
										ageprofile_log_cons_diff_single(individ_age,AGE) = log(consumption_next) - log(consumption)

										IF(AGE<=4) THEN										
											youngage_log_income_shock_diff_single(individ_youngage) = log(z_shock_next) - log(z_shock)
											youngage_log_cons_diff_single(individ_youngage) = log(consumption_next) - log(consumption)
										ELSE 										
											midage_log_income_shock_diff_single(individ_midage) = log(z_shock_next) - log(z_shock)
											midage_log_cons_diff_single(individ_midage) = log(consumption_next) - log(consumption)
										END IF

									! percentage change
										! log_income_shock_diff_single(individ) = (z_shock_next - z_shock)/z_shock
										! log_income_diff_single(individ) = (INCOME_next - INCOME)/INCOME
										! log_cons_diff_single(individ) = (consumption_next - consumption)/consumption

										dist_single(individ) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
										ageprofile_dist_single(individ_age,AGE) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
										IF(AGE<=4) THEN
											youngage_dist_single(individ_youngage) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
										ELSE
											midage_dist_single(individ_midage) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
										END IF 
									EXIT
								ELSEIF (i==NGRIDEH) THEN 
									NEWIE = NGRIDEH 

										JN=singleIDCWN(AGE+1,JA,NEWIS,NEWIE,IG)										
										z_shock_next = W(NEWIS,IG) + UB(NEWIS,NEWIE,1)
										! z_shock_next = shock(NEWIS,IG)
										INCOME_next = WAGE*EFFLONG(AGE+1,IG)*N(JN)*W(NEWIS,IG) + UB(NEWIS,NEWIE,1) !+ R*A(JA)
										consumption_next = singleIDCWC(AGE+1,JA,NEWIS,NEWIE,IG)
										IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
											EXIT
										END IF 
										! IF (INCOME_next <= 1.D-4) THEN 
										! 	INCOME_next = 0.01
										! END IF
										individ = individ + 1
										individ_age = individ_age + 1
										IF(AGE<=4) THEN
											individ_youngage = individ_youngage + 1
										ELSE
											individ_midage = individ_midage + 1
										END IF
									! change in log = approximate percentage change
										log_income_shock_diff_single(individ) = log(z_shock_next) - log(z_shock)
										log_income_diff_single(individ) = log(INCOME_next) - log(INCOME)
										log_cons_diff_single(individ) = log(consumption_next) - log(consumption)

										ageprofile_log_income_shock_diff_single(individ_age,AGE) = log(z_shock_next) - log(z_shock)
										ageprofile_log_income_diff_single(individ_age,AGE) = log(INCOME_next) - log(INCOME)
										ageprofile_log_cons_diff_single(individ_age,AGE) = log(consumption_next) - log(consumption)

										IF(AGE<=4) THEN											
											youngage_log_income_shock_diff_single(individ_youngage) = log(z_shock_next) - log(z_shock)
											youngage_log_cons_diff_single(individ_youngage) = log(consumption_next) - log(consumption)
										ELSE 									
											midage_log_income_shock_diff_single(individ_midage) = log(z_shock_next) - log(z_shock)
											midage_log_cons_diff_single(individ_midage) = log(consumption_next) - log(consumption)
										END IF
									! percentage change
										! log_income_shock_diff_single(individ) = (z_shock_next - z_shock)/z_shock
										! log_income_diff_single(individ) = (INCOME_next - INCOME)/INCOME
										! log_cons_diff_single(individ) = (consumption_next - consumption)/consumption
									
										dist_single(individ) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)
										ageprofile_dist_single(individ_age,AGE) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)
										IF(AGE<=4) THEN
											youngage_dist_single(individ_youngage) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)
										ELSE
											midage_dist_single(individ_midage) = singleYW(AGE,IA,IS,IE,IG)*P(IS,NEWIS,IG)
										END IF 
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
individ_youngage = 0
individ_midage = 0
DO AGE=1,RETAGE-2
individ_age = 0
    DO IA=1,NGRIDA
		DO IS1 = 1,nn 
			DO IS2 = 1,nn 
				DO IE=1,NGRIDEH

					JN1 = coupleIDCWN(AGE,IA,IS1,IS2,IE,1) 
					JN2 = coupleIDCWN(AGE,IA,IS1,IS2,IE,2)
					JA  = coupleIDCWA(AGE,IA,IS1,IS2,IE)   
					z_shock1 = W(IS1,1) + UB(IS1,IE,2)
					z_shock2 = W(IS2,2)	+ UB(IS2,IE,2)					
					! z_shock1 = shock(IS1,1)
					! z_shock2 = shock(IS2,2)		
					z_shock = z_shock1 + z_shock2
					INCOME1 = WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + UB(IS1,IE,2)
					INCOME2 = WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2)+ UB(IS2,IE,2)
					INCOME = INCOME1 + INCOME2
					consumption = coupleIDCWC(AGE,IA,IS1,IS2,IE)
					EH_temp = ((AGE-1)*EH(IE)+(WAGE*EFFLONG(AGE,1)*N(JN1)*W(IS1,1) + WAGE*EFFLONG(AGE,2)*N(JN2)*W(IS2,2))/2.0)/(AGE) 

					IF ((INCOME1 <= 1.D-4) .OR. (INCOME2 <= 1.D-4) .OR. (consumption <= 1.D-4)) THEN 
						GO TO 689
					END IF 
					! IF (INCOME1 <= 1.D-4) THEN 
					! 	INCOME1 = 0.01
					! END IF
					! IF (INCOME2 <= 1.D-4) THEN
					! 	INCOME2 = 0.01
					! END IF
					
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
											z_shock1_next = W(NEWIS1,1) + UB(NEWIS1,NEWIE,2)
											z_shock2_next = W(NEWIS2,2) + UB(NEWIS2,NEWIE,2)
											! z_shock1_next = shock(NEWIS1,1)
											! z_shock2_next = shock(NEWIS2,2)
											z_shock_next = z_shock1_next + z_shock2_next
											INCOME1_next = WAGE*EFFLONG(AGE+1,1)*N(JN1)*W(NEWIS1,1) + UB(NEWIS1,NEWIE,2)
											INCOME2_next = WAGE*EFFLONG(AGE+1,2)*N(JN2)*W(NEWIS2,2) + UB(NEWIS2,NEWIE,2)
											INCOME_next = INCOME1_next + INCOME2_next
											consumption_next = coupleIDCWC(AGE+1,JA,NEWIS1,NEWIS2,NEWIE)
											IF ((INCOME1_next <= 1.D-4) .OR. (INCOME2_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
												EXIT
											END IF 
											! IF (INCOME1_next <= 1.D-4) THEN 
											! 	INCOME1_next = 0.01
											! END IF
											! IF (INCOME2_next <= 1.D-4) THEN
											! 	INCOME2_next = 0.01
											! END IF
											individ = individ + 1
											individ_age = individ_age + 1
											IF(AGE<=4) THEN
												individ_youngage = individ_youngage + 1
											ELSE
												individ_midage = individ_midage + 1
											END IF 
										! change in log = approximate percentage change
											! log_income_shock_diff_couple(individ) = log(z_shock_next) - log(z_shock)
											! log_income_diff_couple(individ) = log(INCOME_next) - log(INCOME)
											log_income_shock_diff_couple(individ) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											log_income_diff_couple(individ) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											log_cons_diff_couple(individ) = log(consumption_next) - log(consumption)

											! ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock_next) - log(z_shock)
											! ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME_next) - log(INCOME)
											ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											ageprofile_log_cons_diff_couple(individ_age,AGE) = log(consumption_next) - log(consumption)

											IF(AGE<=4) THEN											
												youngage_log_income_shock_diff_couple(individ_youngage) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
												youngage_log_cons_diff_couple(individ_youngage) = log(consumption_next) - log(consumption)
											ELSE 									
												midage_log_income_shock_diff_couple(individ_midage) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
												midage_log_cons_diff_couple(individ_midage) = log(consumption_next) - log(consumption)
											END IF

										! percentage change
											! log_income_shock_diff_couple(individ) = (z_shock_next - z_shock)/z_shock
											! log_income_diff_couple(individ) = (INCOME_next - INCOME)/INCOME
											! log_cons_diff_couple(individ) = (consumption_next - consumption)/consumption

											dist_couple(individ) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
											ageprofile_dist_couple(individ_age,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
											IF(AGE<=4) THEN
												youngage_dist_couple(individ_youngage) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
											ELSE
												midage_dist_couple(individ_midage) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1))
											END IF

											JN1 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE+1,1) 
											JN2 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE+1,2)
											z_shock1_next = W(NEWIS1,1) + UB(NEWIS1,NEWIE,2)
											z_shock2_next = W(NEWIS2,2) + UB(NEWIS2,NEWIE,2)
											! z_shock1_next = shock(NEWIS1,1)
											! z_shock2_next = shock(NEWIS2,2)
											z_shock_next = z_shock1_next + z_shock2_next
											INCOME1_next = WAGE*EFFLONG(AGE+1,1)*N(JN1)*W(NEWIS1,1) + UB(NEWIS1,NEWIE,2)
											INCOME2_next = WAGE*EFFLONG(AGE+1,2)*N(JN2)*W(NEWIS2,2) + UB(NEWIS2,NEWIE,2)
											INCOME_next = INCOME1_next + INCOME2_next
											consumption_next = coupleIDCWC(AGE+1,JA,NEWIS1,NEWIS2,NEWIE+1)
											IF ((INCOME1_next <= 1.D-4) .OR. (INCOME2_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
												EXIT
											END IF 
											! IF (INCOME1_next <= 1.D-4) THEN 
											! 	INCOME1_next = 0.01
											! END IF
											! IF (INCOME2_next <= 1.D-4) THEN
											! 	INCOME2_next = 0.01
											! END IF
											individ = individ + 1
											individ_age = individ_age + 1
											IF(AGE<=4) THEN
												individ_youngage = individ_youngage + 1
											ELSE
												individ_midage = individ_midage + 1
											END IF 

										! change in log = approximate percentage change
											! log_income_shock_diff_couple(individ) = log(z_shock_next) - log(z_shock)
											! log_income_diff_couple(individ) = log(INCOME_next) - log(INCOME)
											log_income_shock_diff_couple(individ) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											log_income_diff_couple(individ) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											log_cons_diff_couple(individ) = log(consumption_next) - log(consumption)

											! ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock_next) - log(z_shock)
											! ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME_next) - log(INCOME)
											ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											ageprofile_log_cons_diff_couple(individ_age,AGE) = log(consumption_next) - log(consumption)

											IF(AGE<=4) THEN										
												youngage_log_income_shock_diff_couple(individ_youngage) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
												youngage_log_cons_diff_couple(individ_youngage) = log(consumption_next) - log(consumption)
											ELSE 										
												midage_log_income_shock_diff_couple(individ_midage) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
												midage_log_cons_diff_couple(individ_midage) = log(consumption_next) - log(consumption)
											END IF

										! percentage change
											! log_income_shock_diff_couple(individ) = (z_shock_next - z_shock)/z_shock
											! log_income_diff_couple(individ) = (INCOME_next - INCOME)/INCOME
											! log_cons_diff_couple(individ) = (consumption_next - consumption)/consumption
											
											dist_couple(individ) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
											ageprofile_dist_couple(individ_age,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
											IF(AGE<=4) THEN
												youngage_dist_couple(individ_youngage) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
											ELSE
												midage_dist_couple(individ_midage) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint*(1.0-(EH_temp-EH(NEWIE+1))/(EH(NEWIE)-EH(NEWIE+1)))
											END IF
										EXIT
									ELSEIF (i==NGRIDEH) THEN 
										NEWIE = NGRIDEH 

											JN1 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE,1) 
											JN2 = coupleIDCWN(AGE+1,JA,NEWIS1,NEWIS2,NEWIE,2)										
											z_shock1_next = W(NEWIS1,1) + UB(NEWIS1,NEWIE,2)
											z_shock2_next = W(NEWIS2,2) + UB(NEWIS2,NEWIE,2)
											! z_shock1_next = shock(NEWIS1,1)
											! z_shock2_next = shock(NEWIS2,2)
											z_shock_next = z_shock1_next + z_shock2_next
											INCOME1_next = WAGE*EFFLONG(AGE+1,1)*N(JN1)*W(NEWIS1,1) + UB(NEWIS1,NEWIE,2)
											INCOME2_next = WAGE*EFFLONG(AGE+1,2)*N(JN2)*W(NEWIS2,2) + UB(NEWIS2,NEWIE,2)
											INCOME_next = INCOME1_next + INCOME2_next
											consumption_next = coupleIDCWC(AGE+1,JA,NEWIS1,NEWIS2,NEWIE)
											IF ((INCOME1_next <= 1.D-4) .OR. (INCOME2_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
												EXIT
											END IF 
											! IF (INCOME1_next <= 1.D-4) THEN 
											! 	INCOME1_next = 0.01
											! END IF
											! IF (INCOME2_next <= 1.D-4) THEN
											! 	INCOME2_next = 0.01
											! END IF
											individ = individ + 1
											individ_age = individ_age + 1
											IF(AGE<=4) THEN
												individ_youngage = individ_youngage + 1
											ELSE
												individ_midage = individ_midage + 1
											END IF
										! change in log = approximate percentage change
											! log_income_shock_diff_couple(individ) = log(z_shock_next) - log(z_shock)
											! log_income_diff_couple(individ) = log(INCOME_next) - log(INCOME)
											log_income_shock_diff_couple(individ) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											log_income_diff_couple(individ) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											log_cons_diff_couple(individ) = log(consumption_next) - log(consumption)

											! ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock_next) - log(z_shock)
											! ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME_next) - log(INCOME)
											ageprofile_log_income_shock_diff_couple(individ_age,AGE) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
											ageprofile_log_income_diff_couple(individ_age,AGE) = log(INCOME1_next)+log(INCOME2_next) - log(INCOME1) - log(INCOME2)
											ageprofile_log_cons_diff_couple(individ_age,AGE) = log(consumption_next) - log(consumption)

											IF(AGE<=4) THEN											
												youngage_log_income_shock_diff_couple(individ_youngage) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
												youngage_log_cons_diff_couple(individ_youngage) = log(consumption_next) - log(consumption)
											ELSE 									
												midage_log_income_shock_diff_couple(individ_midage) = log(z_shock1_next)+log(z_shock2_next) - log(z_shock1) - log(z_shock2)
												midage_log_cons_diff_couple(individ_midage) = log(consumption_next) - log(consumption)
											END IF
										! percentage change
											! log_income_shock_diff_couple(individ) = (z_shock_next - z_shock)/z_shock
											! log_income_diff_couple(individ) = (INCOME_next - INCOME)/INCOME
											! log_cons_diff_couple(individ) = (consumption_next - consumption)/consumption
											
											dist_couple(individ) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint
											ageprofile_dist_couple(individ_age,AGE) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint
											IF(AGE<=4) THEN
												youngage_dist_couple(individ_youngage) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint
											ELSE
												midage_dist_couple(individ_midage) = coupleYW(AGE,IA,IS1,IS2,IE)*P_joint
											END IF 
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

youngage_avg_log_income_shock = (SUM(youngage_log_income_shock_diff_single(:)*youngage_dist_single(:)) + SUM(youngage_log_income_shock_diff_couple(:)*youngage_dist_couple(:)))/(SUM(youngage_dist_single)+SUM(youngage_dist_couple))
youngage_avg_log_income_shock_single = (SUM(youngage_log_income_shock_diff_single(:)*youngage_dist_single(:)))/SUM(youngage_dist_single)
youngage_avg_log_income_shock_couple = (SUM(youngage_log_income_shock_diff_couple(:)*youngage_dist_couple(:)))/SUM(youngage_dist_couple)

midage_avg_log_income_shock = (SUM(midage_log_income_shock_diff_single(:)*midage_dist_single(:)) + SUM(midage_log_income_shock_diff_couple(:)*midage_dist_couple(:)))/(SUM(midage_dist_single)+SUM(midage_dist_couple))
midage_avg_log_income_shock_single = (SUM(midage_log_income_shock_diff_single(:)*midage_dist_single(:)))/SUM(midage_dist_single)
midage_avg_log_income_shock_couple = (SUM(midage_log_income_shock_diff_couple(:)*midage_dist_couple(:)))/SUM(midage_dist_couple)

avg_log_income = (SUM(log_income_diff_single(:)*dist_single(:)) + SUM(log_income_diff_couple(:)*dist_couple(:)))/(SUM(dist_single)+SUM(dist_couple))
avg_log_income_single = (SUM(log_income_diff_single(:)*dist_single(:)))/SUM(dist_single)
avg_log_income_couple = (SUM(log_income_diff_couple(:)*dist_couple(:)))/SUM(dist_couple)

avg_log_cons = (SUM(log_cons_diff_single(:)*dist_single(:)) + SUM(log_cons_diff_couple(:)*dist_couple(:)))/(SUM(dist_single)+SUM(dist_couple))
avg_log_cons_single = (SUM(log_cons_diff_single(:)*dist_single(:)))/SUM(dist_single)
avg_log_cons_couple = (SUM(log_cons_diff_couple(:)*dist_couple(:)))/SUM(dist_couple)

youngage_avg_log_cons = (SUM(youngage_log_cons_diff_single(:)*youngage_dist_single(:)) + SUM(youngage_log_cons_diff_couple(:)*youngage_dist_couple(:)))/(SUM(youngage_dist_single)+SUM(youngage_dist_couple))
youngage_avg_log_cons_single = (SUM(youngage_log_cons_diff_single(:)*youngage_dist_single(:)))/SUM(youngage_dist_single)
youngage_avg_log_cons_couple = (SUM(youngage_log_cons_diff_couple(:)*youngage_dist_couple(:)))/SUM(youngage_dist_couple)

midage_avg_log_cons = (SUM(midage_log_cons_diff_single(:)*midage_dist_single(:)) + SUM(midage_log_cons_diff_couple(:)*midage_dist_couple(:)))/(SUM(midage_dist_single)+SUM(midage_dist_couple))
midage_avg_log_cons_single = (SUM(midage_log_cons_diff_single(:)*midage_dist_single(:)))/SUM(midage_dist_single)
midage_avg_log_cons_couple = (SUM(midage_log_cons_diff_couple(:)*midage_dist_couple(:)))/SUM(midage_dist_couple)

insurance_cons_nominator   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock)*(log_cons_diff_single(:)-avg_log_cons)*dist_single(:) ) + SUM( (log_income_shock_diff_couple(:)-avg_log_income_shock)*(log_cons_diff_couple(:)-avg_log_cons)*dist_couple(:) )
insurance_cons_denominator = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock)**2.0)*dist_single(:) ) + SUM( ((log_income_shock_diff_couple(:)-avg_log_income_shock)**2.0)*dist_couple(:) )
insurance_cons_value = insurance_cons_nominator/insurance_cons_denominator

youngage_insurance_cons_nominator   = SUM( (youngage_log_income_shock_diff_single(:)-youngage_avg_log_income_shock)*(youngage_log_cons_diff_single(:)-youngage_avg_log_cons)*youngage_dist_single(:) ) + SUM( (youngage_log_income_shock_diff_couple(:)-youngage_avg_log_income_shock)*(youngage_log_cons_diff_couple(:)-youngage_avg_log_cons)*youngage_dist_couple(:) )
youngage_insurance_cons_denominator = SUM( ((youngage_log_income_shock_diff_single(:)-youngage_avg_log_income_shock)**2.0)*youngage_dist_single(:) ) + SUM( ((youngage_log_income_shock_diff_couple(:)-youngage_avg_log_income_shock)**2.0)*youngage_dist_couple(:) )
youngage_insurance_cons_value = youngage_insurance_cons_nominator/youngage_insurance_cons_denominator

midage_insurance_cons_nominator   = SUM( (midage_log_income_shock_diff_single(:)-midage_avg_log_income_shock)*(midage_log_cons_diff_single(:)-midage_avg_log_cons)*midage_dist_single(:) ) + SUM( (midage_log_income_shock_diff_couple(:)-midage_avg_log_income_shock)*(midage_log_cons_diff_couple(:)-midage_avg_log_cons)*midage_dist_couple(:) )
midage_insurance_cons_denominator = SUM( ((midage_log_income_shock_diff_single(:)-midage_avg_log_income_shock)**2.0)*midage_dist_single(:) ) + SUM( ((midage_log_income_shock_diff_couple(:)-midage_avg_log_income_shock)**2.0)*midage_dist_couple(:) )
midage_insurance_cons_value = midage_insurance_cons_nominator/midage_insurance_cons_denominator

insurance_labor_nominator   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock)*(log_income_diff_single(:)-avg_log_income)*dist_single(:) ) + SUM( (log_income_shock_diff_couple(:)-avg_log_income_shock)*(log_income_diff_couple(:)-avg_log_income)*dist_couple(:) )
insurance_labor_denominator = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock)**2.0)*dist_single(:) ) + SUM( ((log_income_shock_diff_couple(:)-avg_log_income_shock)**2.0)*dist_couple(:) )
insurance_labor_value = insurance_labor_nominator/insurance_labor_denominator

insurance_nominator   = SUM( (log_income_diff_single(:)-avg_log_income)*(log_cons_diff_single(:)-avg_log_cons)*dist_single(:) ) + SUM( (log_income_diff_couple(:)-avg_log_income)*(log_cons_diff_couple(:)-avg_log_cons)*dist_couple(:) )
insurance_denominator = SUM( ((log_income_diff_single(:)-avg_log_income)**2.0)*dist_single(:) ) + SUM( ((log_income_diff_couple(:)-avg_log_income)**2.0)*dist_couple(:) )
insurance_value = insurance_nominator/insurance_denominator

insurance_cons_nominator_single   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock_single)*(log_cons_diff_single(:)-avg_log_cons_single)*dist_single(:) )
insurance_cons_denominator_single = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock_single)**2.0)*dist_single(:) )
insurance_cons_value_single = insurance_cons_nominator_single/insurance_cons_denominator_single

youngage_insurance_cons_nominator_single   = SUM( (youngage_log_income_shock_diff_single(:)-youngage_avg_log_income_shock_single)*(youngage_log_cons_diff_single(:)-youngage_avg_log_cons_single)*youngage_dist_single(:) )
youngage_insurance_cons_denominator_single = SUM( ((youngage_log_income_shock_diff_single(:)-youngage_avg_log_income_shock_single)**2.0)*youngage_dist_single(:) )
youngage_insurance_cons_value_single = youngage_insurance_cons_nominator_single/youngage_insurance_cons_denominator_single

midage_insurance_cons_nominator_single   = SUM( (midage_log_income_shock_diff_single(:)-midage_avg_log_income_shock_single)*(midage_log_cons_diff_single(:)-midage_avg_log_cons_single)*midage_dist_single(:) )
midage_insurance_cons_denominator_single = SUM( ((midage_log_income_shock_diff_single(:)-midage_avg_log_income_shock_single)**2.0)*midage_dist_single(:) )
midage_insurance_cons_value_single = midage_insurance_cons_nominator_single/midage_insurance_cons_denominator_single

insurance_labor_nominator_single   = SUM( (log_income_shock_diff_single(:)-avg_log_income_shock_single)*(log_income_diff_single(:)-avg_log_income_single)*dist_single(:) )
insurance_labor_denominator_single = SUM( ((log_income_shock_diff_single(:)-avg_log_income_shock_single)**2.0)*dist_single(:) )
insurance_labor_value_single = insurance_labor_nominator_single/insurance_labor_denominator_single

insurance_nominator_single   = SUM( (log_income_diff_single(:)-avg_log_income_single)*(log_cons_diff_single(:)-avg_log_cons_single)*dist_single(:) )
insurance_denominator_single = SUM( ((log_income_diff_single(:)-avg_log_income_single)**2.0)*dist_single(:) )
insurance_value_single = insurance_nominator_single/insurance_denominator_single

insurance_cons_nominator_couple   = SUM( (log_income_shock_diff_couple(:)-avg_log_income_shock_couple)*(log_cons_diff_couple(:)-avg_log_cons_couple)*dist_couple(:) )
insurance_cons_denominator_couple = SUM( ((log_income_shock_diff_couple(:)-avg_log_income_shock_couple)**2.0)*dist_couple(:) )
insurance_cons_value_couple = insurance_cons_nominator_couple/insurance_cons_denominator_couple

youngage_insurance_cons_nominator_couple   = SUM( (youngage_log_income_shock_diff_couple(:)-youngage_avg_log_income_shock_couple)*(youngage_log_cons_diff_couple(:)-youngage_avg_log_cons_couple)*youngage_dist_couple(:) )
youngage_insurance_cons_denominator_couple = SUM( ((youngage_log_income_shock_diff_couple(:)-youngage_avg_log_income_shock_couple)**2.0)*youngage_dist_couple(:) )
youngage_insurance_cons_value_couple = youngage_insurance_cons_nominator_couple/youngage_insurance_cons_denominator_couple

midage_insurance_cons_nominator_couple   = SUM( (midage_log_income_shock_diff_couple(:)-midage_avg_log_income_shock_couple)*(midage_log_cons_diff_couple(:)-midage_avg_log_cons_couple)*midage_dist_couple(:) )
midage_insurance_cons_denominator_couple = SUM( ((midage_log_income_shock_diff_couple(:)-midage_avg_log_income_shock_couple)**2.0)*midage_dist_couple(:) )
midage_insurance_cons_value_couple = midage_insurance_cons_nominator_couple/midage_insurance_cons_denominator_couple

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
SUBROUTINE insurance_retiree

ALLOCATE(log_income_diff_single_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH*2))
ALLOCATE(log_cons_diff_single_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH*2),ageprofile_log_cons_diff_single_retire(NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH*2,(MAXAGE-1)) )
ALLOCATE(log_health_shock_diff_single_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH*2),ageprofile_log_health_shock_diff_single_retire(NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH*2,(MAXAGE-1)) )
ALLOCATE(log_med_diff_single_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH*2))
! ALLOCATE(dist_single_retire((MAXAGE-RETAGE)*NGRIDA*NGRIDH*NGRIDEH*2*2))
ALLOCATE(dist_single_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*2*2*NGRIDH),ageprofile_dist_single_retire(NGRIDA*NGRIDH*NGRIDEH*2*2*NGRIDH,(MAXAGE-1)) )
ALLOCATE(log_income_diff_couple_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*NGRIDH*2))
ALLOCATE(log_cons_diff_couple_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*NGRIDH*2),ageprofile_log_cons_diff_couple_retire(NGRIDA*NGRIDH*NGRIDEH*NGRIDH*2,(MAXAGE-1)) )
ALLOCATE(log_health_shock_diff_couple_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*NGRIDH*2),ageprofile_log_health_shock_diff_couple_retire(NGRIDA*NGRIDH*NGRIDEH*NGRIDH*2,(MAXAGE-1)) )
ALLOCATE(log_med_diff_couple_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*NGRIDH*2))
! ALLOCATE(dist_couple_retire((MAXAGE-RETAGE)*NGRIDA*NGRIDH*NGRIDEH*2))
ALLOCATE(dist_couple_retire((MAXAGE-1)*NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH),ageprofile_dist_couple_retire(NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH,(MAXAGE-1)) )
ALLOCATE(ageprofile_avg_log_health_shock_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_avg_log_health_shock_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_avg_log_cons_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_avg_log_cons_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_cons_shock_nominator_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_cons_shock_denominator_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_cons_shock_value_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_cons_shock_nominator_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_cons_shock_denominator_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_cons_shock_value_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_log_med_diff_single_retire(NGRIDA*NGRIDH*NGRIDEH*2*NGRIDH*2,(MAXAGE-1)))
ALLOCATE(ageprofile_log_med_diff_couple_retire(NGRIDA*NGRIDH*NGRIDEH*NGRIDH*2,(MAXAGE-1)))
ALLOCATE(ageprofile_avg_log_med_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_avg_log_med_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_med_shock_nominator_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_med_shock_denominator_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_med_shock_value_single_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_med_shock_nominator_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_med_shock_denominator_couple_retire(MAXAGE-1))
ALLOCATE(ageprofile_insurance_med_shock_value_couple_retire(MAXAGE-1))


log_income_diff_single_retire(:) = 0.0
log_cons_diff_single_retire(:) = 0.0
ageprofile_log_cons_diff_single_retire(:,:) = 0.0
log_health_shock_diff_single_retire(:) = 0.0
ageprofile_log_health_shock_diff_single_retire(:,:) = 0.0
log_med_diff_single_retire(:) = 0.0
dist_single_retire(:) = 0.0
ageprofile_dist_single_retire(:,:) = 0.0

log_income_diff_couple_retire(:) = 0.0
log_cons_diff_couple_retire(:) = 0.0
ageprofile_log_cons_diff_couple_retire(:,:) = 0.0
log_health_shock_diff_couple_retire(:) = 0.0
ageprofile_log_health_shock_diff_couple_retire(:,:) = 0.0
log_med_diff_couple_retire(:) = 0.0
dist_couple_retire(:) = 0.0
ageprofile_dist_couple_retire(:,:) = 0.0

ageprofile_avg_log_health_shock_single_retire(:) = 0.0
ageprofile_avg_log_health_shock_couple_retire(:) = 0.0
ageprofile_avg_log_cons_single_retire(:) = 0.0
ageprofile_avg_log_cons_couple_retire(:) = 0.0
ageprofile_insurance_cons_shock_nominator_single_retire(:) = 0.0
ageprofile_insurance_cons_shock_denominator_single_retire(:) = 0.0
ageprofile_insurance_cons_shock_value_single_retire(:) = 0.0
ageprofile_insurance_cons_shock_nominator_couple_retire(:) = 0.0
ageprofile_insurance_cons_shock_denominator_couple_retire(:) = 0.0
ageprofile_insurance_cons_shock_value_couple_retire(:) = 0.0

ageprofile_log_med_diff_single_retire(:,:) = 0.0
ageprofile_log_med_diff_couple_retire(:,:) = 0.0
ageprofile_avg_log_med_single_retire(:) = 0.0
ageprofile_avg_log_med_couple_retire(:) = 0.0
ageprofile_insurance_med_shock_nominator_single_retire(:) = 0.0
ageprofile_insurance_med_shock_denominator_single_retire(:) = 0.0
ageprofile_insurance_med_shock_value_single_retire(:) = 0.0
ageprofile_insurance_med_shock_nominator_couple_retire(:) = 0.0
ageprofile_insurance_med_shock_denominator_couple_retire(:) = 0.0
ageprofile_insurance_med_shock_value_couple_retire(:) = 0.0

! Single retiree
individ = 0
DO AGE=RETAGE,MAXAGE-1
individ_age = 0
	IF (AGE==RETAGE) THEN
		j=1
	ELSEIF (AGE==RETAGE+1) THEN 
		j=2
	ELSEIF (AGE==RETAGE+2) THEN
		j=3
	ELSE
		j=4
	END IF 

    DO IA=1,NGRIDA
		DO IH = 1,NGRIDH 
			DO IE=1,NGRIDEH
				DO IG=1,2
					
					JA = singleIDCRA(AGE,IA,IH,IE,IG) 
					JM = singleIDCRM(AGE,IA,IH,IE,IG)
					! h_shock = H(IH)
					! INCOME = SS(IE) - (1.0-SUBEHI(AGE))*M(JM) + R*A(IA)
					consumption = singleIDCRC(AGE,IA,IH,IE,IG)
					med_expense = M(JM)				
					
					HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
					IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
						XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
						JH = FLOOR(XH)
						DH = XH-JH
					ELSE IF (HNEXT>HMAX) THEN
						JH = 1
						DH = 0.0000	       
					ELSE IF (HNEXT<HMIN) THEN
						JH = NGRIDH
						DH = 0.0000
					END IF
					
					IF ((med_expense <= 1.D-4) .OR. (consumption <= 1.D-4)) THEN 
						GO TO 690
					END IF 
						 
					IF (JH<NGRIDH) THEN

						! INCOME_next = SS(IE) - (1.0-SUBEHI(AGE))*M(singleIDCRM(AGE+1,JA,JH,IE,IG)) + R*A(JA)
						! consumption_next = singleIDCRC(AGE+1,JA,JH,IE,IG)
						! IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
						! 	GO TO 690
						! END IF 
						! individ = individ + 1
						! log_income_diff_single_retire(individ) = log(INCOME_next) - log(INCOME)
						! log_cons_diff_single_retire(individ) = log(consumption_next) - log(consumption)
						! dist_single_retire(individ) = (1.0-DH)*singleYR(AGE,IA,IH,IE,IG)
						
						! INCOME_next = SS(IE) - (1.0-SUBEHI(AGE))*M(singleIDCRM(AGE+1,JA,JH+1,IE,IG)) + R*A(JA)
						! consumption_next = singleIDCRC(AGE+1,JA,JH+1,IE,IG)
						! IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
						! 	GO TO 690
						! END IF 
						! individ = individ + 1
						! log_income_diff_single_retire(individ) = log(INCOME_next) - log(INCOME)
						! log_cons_diff_single_retire(individ) = log(consumption_next) - log(consumption)
						! dist_single_retire(individ) = DH*singleYR(AGE,IA,IH,IE,IG)

						DO NEWH = 1,NGRIDH
							! INCOME_next = SS(IE) - (1.0-SUBEHI(AGE))*M(singleIDCRM(AGE+1,JA,NEWH,IE,IG)) + R*A(JA)
							h_shock = H(JH)
							h_shock_next = H(NEWH)
							consumption_next = singleIDCRC(AGE+1,JA,NEWH,IE,IG)
							med_expense_next = M(singleIDCRM(AGE+1,JA,NEWH,IE,IG))
							IF ((med_expense_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
								GO TO 690
							END IF 
							individ = individ + 1
							individ_age = individ_age + 1
							! log_income_diff_single_retire(individ) = log(INCOME_next) - log(INCOME)
							log_health_shock_diff_single_retire(individ) = log(h_shock_next) - log(h_shock)
							log_cons_diff_single_retire(individ) = log(consumption_next) - log(consumption)
							log_med_diff_single_retire(individ) = log(med_expense_next) - log(med_expense)

							ageprofile_log_health_shock_diff_single_retire(individ_age,AGE) = log(h_shock_next) - log(h_shock)
							ageprofile_log_cons_diff_single_retire(individ_age,AGE) = log(consumption_next) - log(consumption)
							ageprofile_log_med_diff_single_retire(individ_age,AGE) = log(med_expense_next) - log(med_expense)

							dist_single_retire(individ) = (1.0-DH)*singleYR(AGE,IA,IH,IE,IG)*P_h(JH,NEWH,j)
							ageprofile_dist_single_retire(individ_age,AGE) = (1.0-DH)*singleYR(AGE,IA,IH,IE,IG)*P_h(JH,NEWH,j)
							

							! INCOME_next = SS(IE) - (1.0-SUBEHI(AGE))*M(singleIDCRM(AGE+1,JA,NEWH,IE,IG)) + R*A(JA)
							! consumption_next = singleIDCRC(AGE+1,JA,NEWH,IE,IG)
							! IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
							! 	GO TO 690
							! END IF 
							h_shock = H(JH+1)
							individ = individ + 1
							individ_age = individ_age + 1
							! log_income_diff_single_retire(individ) = log(INCOME_next) - log(INCOME)
							log_health_shock_diff_single_retire(individ) = log(h_shock_next) - log(h_shock)
							log_cons_diff_single_retire(individ) = log(consumption_next) - log(consumption)
							log_med_diff_single_retire(individ) = log(med_expense_next) - log(med_expense)

							ageprofile_log_health_shock_diff_single_retire(individ_age,AGE) = log(h_shock_next) - log(h_shock)
							ageprofile_log_cons_diff_single_retire(individ_age,AGE) = log(consumption_next) - log(consumption)
							ageprofile_log_med_diff_single_retire(individ_age,AGE) = log(med_expense_next) - log(med_expense)

							dist_single_retire(individ) = DH*singleYR(AGE,IA,IH,IE,IG)*P_h(JH+1,NEWH,j)
							ageprofile_dist_single_retire(individ_age,AGE) = DH*singleYR(AGE,IA,IH,IE,IG)*P_h(JH+1,NEWH,j)
							
						END DO 
			
					ELSE

						DO NEWH = 1,NGRIDH
							! INCOME_next = SS(IE) - (1.0-SUBEHI(AGE))*M(singleIDCRM(AGE+1,JA,NEWH,IE,IG)) + R*A(JA)
							h_shock = H(JH)
							h_shock_next = H(NEWH)
							consumption_next = singleIDCRC(AGE+1,JA,NEWH,IE,IG)
							med_expense_next = M(singleIDCRM(AGE+1,JA,NEWH,IE,IG))
							IF ((med_expense_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
								GO TO 690
							END IF  
							individ = individ + 1
							individ_age = individ_age + 1
							! log_income_diff_single_retire(individ) = log(INCOME_next) - log(INCOME)
							log_health_shock_diff_single_retire(individ) = log(h_shock_next) - log(h_shock)
							log_cons_diff_single_retire(individ) = log(consumption_next) - log(consumption)
							log_med_diff_single_retire(individ) = log(med_expense_next) - log(med_expense)
							
							ageprofile_log_health_shock_diff_single_retire(individ_age,AGE) = log(h_shock_next) - log(h_shock)
							ageprofile_log_cons_diff_single_retire(individ_age,AGE) = log(consumption_next) - log(consumption)
							ageprofile_log_med_diff_single_retire(individ_age,AGE) = log(med_expense_next) - log(med_expense)
							
							dist_single_retire(individ) = singleYR(AGE,IA,IH,IE,IG)*P_h(JH,NEWH,j)
							ageprofile_dist_single_retire(individ_age,AGE) = singleYR(AGE,IA,IH,IE,IG)*P_h(JH,NEWH,j)
							
						END DO 

					END IF 						
690 continue					
				END DO 
			END DO 	 
		END DO
    END DO
END DO

! Couple retiree
individ = 0
DO AGE=RETAGE,MAXAGE-1
individ_age = 0

	IF (AGE==RETAGE) THEN
		j=1
	ELSEIF (AGE==RETAGE+1) THEN 
		j=2
	ELSEIF (AGE==RETAGE+2) THEN
		j=3
	ELSE
		j=4
	END IF 

    DO IA=1,NGRIDA
		DO IH=1,NGRIDH
			DO IE=1,NGRIDEH

					
					JA  = coupleIDCRA(AGE,IA,IH,IE) 
					JM = coupleIDCRM(AGE,IA,IH,IE) 
					! INCOME = 2*SS(IE) - (1.0-SUBEHI(AGE))*M(JM) + R*A(IA)
					consumption = coupleIDCRC(AGE,IA,IH,IE)
					med_expense = M(JM)

					HNEXT = H(IH)*(1-DEP_H(AGE)) + B*(M(JM)**XI)
					IF ((HNEXT>=HMIN) .AND. (HNEXT<=HMAX)) THEN
						XH = (1.00000000-HNEXT/HMAX)*(FLOAT(NGRIDH-1)) + 1.0000
						JH = FLOOR(XH)
						DH = XH-JH
					ELSE IF (HNEXT>HMAX) THEN
						JH = 1
						DH = 0.0000	       
					ELSE IF (HNEXT<HMIN) THEN
						JH = NGRIDH
						DH = 0.0000
					END IF				

					IF ((med_expense <= 1.D-4) .OR. (consumption <= 1.D-4)) THEN 
						GO TO 691
					END IF 
					
					IF (JH<NGRIDH) THEN

						! INCOME_next = 2*SS(IE) - (1.0-SUBEHI(AGE))*M(coupleIDCRM(AGE+1,JA,JH,IE)) + R*A(JA)
						! consumption_next = coupleIDCRC(AGE+1,JA,JH,IE)
						! IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
						! 	GO TO 691
						! END IF 
						! individ = individ + 1
						! log_income_diff_couple_retire(individ) = log(INCOME_next) - log(INCOME)
						! log_cons_diff_couple_retire(individ) = log(consumption_next) - log(consumption)
						! dist_couple_retire(individ) = (1.0-DH)*coupleYR(AGE,IA,IH,IE)
						
						! INCOME_next = 2*SS(IE) - (1.0-SUBEHI(AGE))*M(coupleIDCRM(AGE+1,JA,JH+1,IE)) + R*A(JA)
						! consumption_next = coupleIDCRC(AGE+1,JA,JH+1,IE)
						! IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
						! 	GO TO 691
						! END IF 
						! individ = individ + 1
						! log_income_diff_couple_retire(individ) = log(INCOME_next) - log(INCOME)
						! log_cons_diff_couple_retire(individ) = log(consumption_next) - log(consumption)
						! dist_couple_retire(individ) = DH*coupleYR(AGE,IA,IH,IE)

						DO NEWH = 1,NGRIDH
							! INCOME_next = 2*SS(IE) - (1.0-SUBEHI(AGE))*M(coupleIDCRM(AGE+1,JA,NEWH,IE)) + R*A(JA)
							h_shock = H(JH)
							h_shock_next = H(NEWH)
							consumption_next = coupleIDCRC(AGE+1,JA,NEWH,IE)
							med_expense_next = M(coupleIDCRM(AGE+1,JA,NEWH,IE))
							IF ((med_expense_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
								GO TO 691
							END IF 
							individ = individ + 1
							individ_age = individ_age + 1
							! log_income_diff_couple_retire(individ) = log(INCOME_next) - log(INCOME)
							log_health_shock_diff_couple_retire(individ) = log(h_shock_next) - log(h_shock)
							log_cons_diff_couple_retire(individ) = log(consumption_next) - log(consumption)
							log_med_diff_couple_retire(individ) = log(med_expense_next) - log(med_expense)

							ageprofile_log_health_shock_diff_couple_retire(individ_age,AGE) = log(h_shock_next) - log(h_shock)
							ageprofile_log_cons_diff_couple_retire(individ_age,AGE) = log(consumption_next) - log(consumption)
							ageprofile_log_med_diff_couple_retire(individ_age,AGE) = log(med_expense_next) - log(med_expense)

							dist_couple_retire(individ) = (1.0-DH)*coupleYR(AGE,IA,IH,IE)*P_h(JH,NEWH,j)
							ageprofile_dist_couple_retire(individ_age,AGE) = (1.0-DH)*coupleYR(AGE,IA,IH,IE)*P_h(JH,NEWH,j)

							! INCOME_next = 2*SS(IE) - (1.0-SUBEHI(AGE))*M(coupleIDCRM(AGE+1,JA,NEWH,IE)) + R*A(JA)
							! consumption_next = coupleIDCRC(AGE+1,JA,NEWH,IE)
							! IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
							! 	GO TO 691
							! END IF 
							h_shock = H(JH+1)
							individ = individ + 1
							individ_age = individ_age + 1
							! log_income_diff_couple_retire(individ) = log(INCOME_next) - log(INCOME)
							log_health_shock_diff_couple_retire(individ) = log(h_shock_next) - log(h_shock)
							log_cons_diff_couple_retire(individ) = log(consumption_next) - log(consumption)
							log_med_diff_couple_retire(individ) = log(med_expense_next) - log(med_expense)
							
							ageprofile_log_health_shock_diff_couple_retire(individ_age,AGE) = log(h_shock_next) - log(h_shock)
							ageprofile_log_cons_diff_couple_retire(individ_age,AGE) = log(consumption_next) - log(consumption)
							ageprofile_log_med_diff_couple_retire(individ_age,AGE) = log(med_expense_next) - log(med_expense)
							
							dist_couple_retire(individ) = DH*coupleYR(AGE,IA,IH,IE)*P_h(JH+1,NEWH,j)
							ageprofile_dist_couple_retire(individ_age,AGE) = DH*coupleYR(AGE,IA,IH,IE)*P_h(JH+1,NEWH,j)
						END DO 
					
					ElSE
										
						! INCOME_next = 2*SS(IE) - (1.0-SUBEHI(AGE))*M(coupleIDCRM(AGE+1,JA,JH,IE)) + R*A(JA)
						! consumption_next = coupleIDCRC(AGE+1,JA,JH,IE)
						! IF ((INCOME_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
						! 	GO TO 691
						! END IF 
						! individ = individ + 1
						! log_income_diff_couple_retire(individ) = log(INCOME_next) - log(INCOME)
						! log_cons_diff_couple_retire(individ) = log(consumption_next) - log(consumption)
						! dist_couple_retire(individ) = coupleYR(AGE,IA,IH,IE)

						DO NEWH = 1,NGRIDH
							! INCOME_next = 2*SS(IE) - (1.0-SUBEHI(AGE))*M(coupleIDCRM(AGE+1,JA,NEWH,IE)) + R*A(JA)
							h_shock = H(JH)
							h_shock_next = H(NEWH)
							consumption_next = coupleIDCRC(AGE+1,JA,NEWH,IE)
							med_expense_next = M(coupleIDCRM(AGE+1,JA,NEWH,IE))
							IF ((med_expense_next <= 1.D-4) .OR. (consumption_next <= 1.D-4)) THEN 
								GO TO 691
							END IF 
							individ = individ + 1
							individ_age = individ_age + 1
							! log_income_diff_couple_retire(individ) = log(INCOME_next) - log(INCOME)
							log_health_shock_diff_couple_retire(individ) = log(h_shock_next) - log(h_shock)
							log_cons_diff_couple_retire(individ) = log(consumption_next) - log(consumption)
							log_med_diff_couple_retire(individ) = log(med_expense_next) - log(med_expense)
							
							ageprofile_log_health_shock_diff_couple_retire(individ_age,AGE) = log(h_shock_next) - log(h_shock)
							ageprofile_log_cons_diff_couple_retire(individ_age,AGE) = log(consumption_next) - log(consumption)
							ageprofile_log_med_diff_couple_retire(individ_age,AGE) = log(med_expense_next) - log(med_expense)
							
							dist_couple_retire(individ) = coupleYR(AGE,IA,IH,IE)*P_h(JH,NEWH,j)
							ageprofile_dist_couple_retire(individ_age,AGE) = coupleYR(AGE,IA,IH,IE)*P_h(JH,NEWH,j)
						END DO 

					END IF 						
691 continue				 
			END DO 	 
		END DO
    END DO
END DO

! avg_log_income_retire = (SUM(log_income_diff_single_retire(:)*dist_single_retire(:)) + SUM(log_income_diff_couple_retire(:)*dist_couple_retire(:)))/(SUM(dist_single_retire)+SUM(dist_couple_retire))
! avg_log_income_single_retire = (SUM(log_income_diff_single_retire(:)*dist_single_retire(:)))/SUM(dist_single_retire)
! avg_log_income_couple_retire = (SUM(log_income_diff_couple_retire(:)*dist_couple_retire(:)))/SUM(dist_couple_retire)

avg_log_health_shock_retire = (SUM(log_health_shock_diff_single_retire(:)*dist_single_retire(:)) + SUM(log_health_shock_diff_couple_retire(:)*dist_couple_retire(:)))/(SUM(dist_single_retire)+SUM(dist_couple_retire))
avg_log_health_shock_single_retire = (SUM(log_health_shock_diff_single_retire(:)*dist_single_retire(:)))/SUM(dist_single_retire)
avg_log_health_shock_couple_retire = (SUM(log_health_shock_diff_couple_retire(:)*dist_couple_retire(:)))/SUM(dist_couple_retire)

avg_log_med_retire = (SUM(log_med_diff_single_retire(:)*dist_single_retire(:)) + SUM(log_med_diff_couple_retire(:)*dist_couple_retire(:)))/(SUM(dist_single_retire)+SUM(dist_couple_retire))
avg_log_med_single_retire = (SUM(log_med_diff_single_retire(:)*dist_single_retire(:)))/SUM(dist_single_retire)
avg_log_med_couple_retire = (SUM(log_med_diff_couple_retire(:)*dist_couple_retire(:)))/SUM(dist_couple_retire)

avg_log_cons_retire = (SUM(log_cons_diff_single_retire(:)*dist_single_retire(:)) + SUM(log_cons_diff_couple_retire(:)*dist_couple_retire(:)))/(SUM(dist_single_retire)+SUM(dist_couple_retire))
avg_log_cons_single_retire = (SUM(log_cons_diff_single_retire(:)*dist_single_retire(:)))/SUM(dist_single_retire)
avg_log_cons_couple_retire = (SUM(log_cons_diff_couple_retire(:)*dist_couple_retire(:)))/SUM(dist_couple_retire)

!consumption
insurance_nominator_retire   = SUM( (log_health_shock_diff_single_retire(:)-avg_log_health_shock_retire)*(log_cons_diff_single_retire(:)-avg_log_cons_retire)*dist_single_retire(:) ) + SUM( (log_health_shock_diff_couple_retire(:)-avg_log_health_shock_retire)*(log_cons_diff_couple_retire(:)-avg_log_cons_retire)*dist_couple_retire(:) )
insurance_denominator_retire = SUM( ((log_health_shock_diff_single_retire(:)-avg_log_health_shock_retire)**2.0)*dist_single_retire(:) ) + SUM( ((log_health_shock_diff_couple_retire(:)-avg_log_health_shock_retire)**2.0)*dist_couple_retire(:) )
insurance_value_retire = insurance_nominator_retire/insurance_denominator_retire

insurance_nominator_single_retire   = SUM( (log_health_shock_diff_single_retire(:)-avg_log_health_shock_single_retire)*(log_cons_diff_single_retire(:)-avg_log_cons_single_retire)*dist_single_retire(:) )
insurance_denominator_single_retire = SUM( ((log_health_shock_diff_single_retire(:)-avg_log_health_shock_single_retire)**2.0)*dist_single_retire(:) )
insurance_value_single_retire = insurance_nominator_single_retire/insurance_denominator_single_retire

insurance_nominator_couple_retire   = SUM( (log_health_shock_diff_couple_retire(:)-avg_log_health_shock_couple_retire)*(log_cons_diff_couple_retire(:)-avg_log_cons_couple_retire)*dist_couple_retire(:) )
insurance_denominator_couple_retire = SUM( ((log_health_shock_diff_couple_retire(:)-avg_log_health_shock_couple_retire)**2.0)*dist_couple_retire(:) )
insurance_value_couple_retire = insurance_nominator_couple_retire/insurance_denominator_couple_retire

!medical expense
insurance_nominator_med_retire   = SUM( (log_health_shock_diff_single_retire(:)-avg_log_health_shock_retire)*(log_med_diff_single_retire(:)-avg_log_med_retire)*dist_single_retire(:) ) + SUM( (log_health_shock_diff_couple_retire(:)-avg_log_health_shock_retire)*(log_med_diff_couple_retire(:)-avg_log_med_retire)*dist_couple_retire(:) )
insurance_value_med_retire = insurance_nominator_med_retire/insurance_denominator_retire

insurance_nominator_med_single_retire  = SUM( (log_health_shock_diff_single_retire(:)-avg_log_health_shock_single_retire)*(log_med_diff_single_retire(:)-avg_log_med_single_retire)*dist_single_retire(:) )
insurance_value_med_single_retire = insurance_nominator_med_single_retire/insurance_denominator_single_retire

insurance_nominator_med_couple_retire  = SUM( (log_health_shock_diff_couple_retire(:)-avg_log_health_shock_couple_retire)*(log_med_diff_couple_retire(:)-avg_log_med_couple_retire)*dist_couple_retire(:) )
insurance_value_med_couple_retire = insurance_nominator_med_couple_retire/insurance_denominator_couple_retire


print*,'avg_log_health_shock_retire',avg_log_health_shock_retire
print*,'avg_log_cons_retire',avg_log_cons_retire
print*,'avg_log_med_retire',avg_log_med_retire
print*,'insurance_nominator_retire',insurance_nominator_retire
print*,'insurance_nominator_med_retire',insurance_nominator_med_retire
print*,'insurance_denominator_retire',insurance_denominator_retire
print*,'insurance_value_retire',insurance_value_retire
print*,'insurance_value_med_retire',insurance_value_med_retire

print*,'avg_log_health_shock_single_retire',avg_log_health_shock_single_retire
print*,'avg_log_cons_single_retire',avg_log_cons_single_retire
print*,'avg_log_med_single_retire',avg_log_med_single_retire
print*,'insurance_nominator_single_retire',insurance_nominator_single_retire
print*,'insurance_nominator_med_single_retire',insurance_nominator_med_single_retire
print*,'insurance_denominator_single_retire',insurance_denominator_single_retire
print*,'insurance_value_single_retire',insurance_value_single_retire
print*,'insurance_value_med_single_retire',insurance_value_med_single_retire

print*,'avg_log_health_shock_couple_retire',avg_log_health_shock_couple_retire
print*,'avg_log_cons_couple_retire',avg_log_cons_couple_retire
print*,'avg_log_med_couple_retire',avg_log_med_couple_retire
print*,'insurance_nominator_couple_retire',insurance_nominator_couple_retire
print*,'insurance_nominator_med_couple_retire',insurance_nominator_med_couple_retire
print*,'insurance_denominator_couple_retire',insurance_denominator_couple_retire
print*,'insurance_value_couple_retire',insurance_value_couple_retire
print*,'insurance_value_med_couple_retire',insurance_value_med_couple_retire


! Age profile insurance
DO AGE=RETAGE,MAXAGE-1
	ageprofile_avg_log_health_shock_single_retire(AGE) = SUM(ageprofile_log_health_shock_diff_single_retire(:,AGE)*ageprofile_dist_single_retire(:,AGE))/SUM(ageprofile_dist_single_retire(:,AGE))
	ageprofile_avg_log_health_shock_couple_retire(AGE) = SUM(ageprofile_log_health_shock_diff_couple_retire(:,AGE)*ageprofile_dist_couple_retire(:,AGE))/SUM(ageprofile_dist_couple_retire(:,AGE))

	ageprofile_avg_log_cons_single_retire(AGE) = SUM(ageprofile_log_cons_diff_single_retire(:,AGE)*ageprofile_dist_single_retire(:,AGE))/SUM(ageprofile_dist_single_retire(:,AGE))
	ageprofile_avg_log_cons_couple_retire(AGE) = SUM(ageprofile_log_cons_diff_couple_retire(:,AGE)*ageprofile_dist_couple_retire(:,AGE))/SUM(ageprofile_dist_couple_retire(:,AGE))

	ageprofile_avg_log_med_single_retire(AGE) = SUM(ageprofile_log_med_diff_single_retire(:,AGE)*ageprofile_dist_single_retire(:,AGE))/SUM(ageprofile_dist_single_retire(:,AGE))
	ageprofile_avg_log_med_couple_retire(AGE) = SUM(ageprofile_log_med_diff_couple_retire(:,AGE)*ageprofile_dist_couple_retire(:,AGE))/SUM(ageprofile_dist_couple_retire(:,AGE))
END DO

DO AGE=RETAGE,MAXAGE-1
	ageprofile_insurance_cons_shock_nominator_single_retire(AGE)   = SUM( (ageprofile_log_health_shock_diff_single_retire(:,AGE)-ageprofile_avg_log_health_shock_single_retire(AGE))*(ageprofile_log_cons_diff_single_retire(:,AGE)-ageprofile_avg_log_cons_single_retire(AGE))*ageprofile_dist_single_retire(:,AGE) )	
	ageprofile_insurance_cons_shock_denominator_single_retire(AGE) = SUM( ((ageprofile_log_health_shock_diff_single_retire(:,AGE)-ageprofile_avg_log_health_shock_single_retire(AGE))**2.0)*ageprofile_dist_single_retire(:,AGE) )
	ageprofile_insurance_cons_shock_value_single_retire(AGE) = ageprofile_insurance_cons_shock_nominator_single_retire(AGE)/ageprofile_insurance_cons_shock_denominator_single_retire(AGE)

	ageprofile_insurance_med_shock_nominator_single_retire(AGE)   = SUM( (ageprofile_log_health_shock_diff_single_retire(:,AGE)-ageprofile_avg_log_health_shock_single_retire(AGE))*(ageprofile_log_med_diff_single_retire(:,AGE)-ageprofile_avg_log_med_single_retire(AGE))*ageprofile_dist_single_retire(:,AGE) )	
	ageprofile_insurance_med_shock_denominator_single_retire(AGE) = SUM( ((ageprofile_log_health_shock_diff_single_retire(:,AGE)-ageprofile_avg_log_health_shock_single_retire(AGE))**2.0)*ageprofile_dist_single_retire(:,AGE) )
	ageprofile_insurance_med_shock_value_single_retire(AGE) = ageprofile_insurance_med_shock_nominator_single_retire(AGE)/ageprofile_insurance_med_shock_denominator_single_retire(AGE)

	ageprofile_insurance_cons_shock_nominator_couple_retire(AGE)   = SUM( (ageprofile_log_health_shock_diff_couple_retire(:,AGE)-ageprofile_avg_log_health_shock_couple_retire(AGE))*(ageprofile_log_cons_diff_couple_retire(:,AGE)-ageprofile_avg_log_cons_couple_retire(AGE))*ageprofile_dist_couple_retire(:,AGE) )	
	ageprofile_insurance_cons_shock_denominator_couple_retire(AGE) = SUM( ((ageprofile_log_health_shock_diff_couple_retire(:,AGE)-ageprofile_avg_log_health_shock_couple_retire(AGE))**2.0)*ageprofile_dist_couple_retire(:,AGE) )
	ageprofile_insurance_cons_shock_value_couple_retire(AGE) = ageprofile_insurance_cons_shock_nominator_couple_retire(AGE)/ageprofile_insurance_cons_shock_denominator_couple_retire(AGE)

	ageprofile_insurance_med_shock_nominator_couple_retire(AGE)   = SUM( (ageprofile_log_health_shock_diff_couple_retire(:,AGE)-ageprofile_avg_log_health_shock_couple_retire(AGE))*(ageprofile_log_med_diff_couple_retire(:,AGE)-ageprofile_avg_log_med_couple_retire(AGE))*ageprofile_dist_couple_retire(:,AGE) )	
	ageprofile_insurance_med_shock_denominator_couple_retire(AGE) = SUM( ((ageprofile_log_health_shock_diff_couple_retire(:,AGE)-ageprofile_avg_log_health_shock_couple_retire(AGE))**2.0)*ageprofile_dist_couple_retire(:,AGE) )
	ageprofile_insurance_med_shock_value_couple_retire(AGE) = ageprofile_insurance_med_shock_nominator_couple_retire(AGE)/ageprofile_insurance_med_shock_denominator_couple_retire(AGE)
END DO

! print*,'ageprofile_insurance_cons_shock_nominator_single_retire',ageprofile_insurance_cons_shock_nominator_single_retire(:)
! print*,'ageprofile_insurance_cons_shock_denominator_single_retire',ageprofile_insurance_cons_shock_denominator_single_retire(:)
! print*,'ageprofile_insurance_cons_shock_nominator_couple_retire',ageprofile_insurance_cons_shock_nominator_couple_retire(:)
! print*,'ageprofile_insurance_cons_shock_denominator_couple_retire',ageprofile_insurance_cons_shock_denominator_couple_retire(:)
print*,'ageprofile_insurance_med_shock_nominator_couple_retire',ageprofile_insurance_med_shock_nominator_couple_retire(:)
print*,'ageprofile_insurance_med_shock_denominator_couple_retire',ageprofile_insurance_med_shock_denominator_couple_retire(:)
print*,'ageprofile_avg_log_health_shock_single_retire',ageprofile_avg_log_health_shock_single_retire(:)
print*,'ageprofile_avg_log_health_shock_couple_retire',ageprofile_avg_log_health_shock_couple_retire(:)
print*,'SUM(ageprofile_dist_couple_retire(:,AGE))',SUM(ageprofile_dist_couple_retire(:,12)),SUM(ageprofile_dist_couple_retire(:,13)),SUM(ageprofile_dist_couple_retire(:,14))
print*,'SUM(ageprofile_dist_single_retire(:,AGE))',SUM(ageprofile_dist_single_retire(:,12)),SUM(ageprofile_dist_single_retire(:,13)),SUM(ageprofile_dist_single_retire(:,14))
print*,'SUM(singleYR(AGE,:,:,:,:))',SUM(singleYR(12,:,:,:,:)),SUM(singleYR(13,:,:,:,:)),SUM(singleYR(14,:,:,:,:))


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
				utility = UCONS1 + log(CONS) - theta_single_male*((1.0-lei)**(1+sigma_lab_male))/(1+sigma_lab_male) !+ log(G)			
			ELSE
				! utility = (CONS**(1-sigma))/(1-sigma) - theta_single_male*((1.0-lei)**(1+sigma_lab_male))/(1+sigma_lab_male) - fixcost_male
				utility = UCONS1 + log(CONS) - theta_single_male*((1.0-lei)**(1+sigma_lab_male))/(1+sigma_lab_male) - fixcost_male !+ log(G)
			END IF  
		ELSEIF 	(gender==2) THEN
			IF (lei==1.0) THEN 	!no labor participation
				! utility = (CONS**(1-sigma))/(1-sigma) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female)	
				utility = UCONS2 + log(CONS) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female) !+ log(G)				
			ELSE
				! utility = (CONS**(1-sigma))/(1-sigma) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_singlefemale
				utility = UCONS2 + log(CONS) - theta_single_female*((1.0-lei)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_singlefemale !+ log(G)
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
			couple_utility =  UCONS1 + log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + UCONS2 + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) !+ log(G)
			
		ELSEIF  ( (lei1<1.0) .AND. (lei2==1.0) )THEN
			! couple_utility = ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male
			couple_utility = UCONS1 + log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + UCONS2 + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male !+ log(G)
			
		ELSEIF  ( (lei1==1.0) .AND. (lei2<1.0) )THEN
			! couple_utility = ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_marriedfemale
			couple_utility = UCONS1 + log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + UCONS2 + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_marriedfemale !+ log(G)
			
		ELSEIF  ( (lei1<1.0) .AND. (lei2<1.0) )THEN
			! couple_utility = ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + ((CONS/eta)**(1-sigma))/(1-sigma) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male - fixcost_marriedfemale
			couple_utility = UCONS1 + log(CONS/eta) - theta_married_male*((1.0-lei1)**(1+sigma_lab_male))/(1+sigma_lab_male) + UCONS2 + log(CONS/eta) - theta_married_female*((1.0-lei2)**(1+sigma_lab_female))/(1+sigma_lab_female) - fixcost_male - fixcost_marriedfemale !+ log(G)
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

! ! From "Why women work the way they do Japan fiscal policy"
! ! Basic pension is 780,900 yen based on the pension benefit schedule of 2021; Source "Why women work the way they do Japan fiscal policy "
! ! average yearly wages in 2021 = 4358501 source: unemployment benefit replacement rate (OECD).xls ; H23 
! 	ss_basic = (780,900/4358501)*avg_earnings
! ! replacement rate is 0.219 based on the pension benefit schedule of 2021; Source "Why women work the way they do Japan fiscal policy "
! 	rr = 0.219
! 	SS = ss_basic + rr*EH(IE)

! From "Medical Expenditures over the Life-Cycle: Persistent Risks and Insurance"
	! rr = 1.0/3.0
	SS = rr*EH(IE)

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
		bendy=((1.0-taxrate)*lambda/(1.0-ty_max))**(1.0/taxrate) 
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
		bendy=((1.0-taxrate)*(lambda_couple)/(1.0-ty_max))**(1.0/taxrate) 
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
		bendy=((1.0-tau_l_couple)*(lambda_couple)/(1.0-ty_max))**(1.0/tau_l_couple) 
	ELSE 
		bendy=1.E7 
	END IF 
ELSEIF (ty_max_restriction == 0) THEN
	bendy=1.E7 
END IF

yd_MFJ	= pretaxincome*lambda_couple*(MIN(bendy, pretaxincome/avg_earnings))**(-tau_l_couple) &
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
		bendy=((1.0-tau_l_couple_MFS)*lambda_couple_MFS/(1.0-ty_max))**(1.0/tau_l_couple_MFS) 
	ELSE 
		bendy=1.E7 
	END IF
ELSEIF (ty_max_restriction == 0) THEN
	bendy=1.E7 
END IF

yd_MFS	= pretaxincome*lambda_couple_MFS*(MIN(bendy, pretaxincome/avg_earnings))**(-tau_l_couple_MFS) &
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
function SUR(AGE,IG,IH)

integer, intent(in) :: AGE,IG,IH
REAL(prec) :: SUR

SUR = 1/(1+EXP(c0(IG)+c1(IG)*AGE+c2(IG)*(AGE**2)+c3(IG)*H(IH)))

end function SUR
!*************************************************************************************************************************
function S(AGE,IG)

integer, intent(in) :: AGE,IG
REAL(prec) :: S

IF (AGE<RETAGE) THEN 
	S = 1.0
ELSEIF (AGE==MAXAGE) THEN
	S = 0.0
ELSE 	
	S = 1/(1+EXP(c0(IG)+c1(IG)*AGE+c2(IG)*(AGE**2)+c3(IG)*HLONG(AGE)))
END IF

end function S
!*************************************************************************************************************************
function UB(IS,IE,marital)

integer, intent(in) :: IS,IE,marital
REAL(prec) :: UB,avg_earnings

! ======================1st Approach======================
!marital: 1=single ; 2=married
!replacement rate (%) Avg 2009-2021	
!			 	min		  67%AW		  AW
! single	100.9230769	75.30769231	63.76923077
! couple	98.38461538	88.84615385	82.84615385

! IF (marital==1) THEN 
! 	IF (IS<7) THEN 
! 		UB = 0.0
! 	ELSE 
! 		IF (EH(IE) < 0.67*avg_earnings)	THEN
! 			UB = 1.0*EH(IE)
! 		ELSEIF (EH(IE) >= avg_earnings) THEN 
! 			UB = 0.638*EH(IE)
! 		ELSE 
! 			UB = 0.753*EH(IE)
! 		END IF 
! 	END IF
! ELSEIF (marital==2) THEN 
! 	IF (IS<7) THEN 
! 		UB = 0.0
! 	ELSE 
! 		IF (EH(IE) < 0.67*avg_earnings)	THEN
! 			UB = 0.984*EH(IE)
! 		ELSEIF (EH(IE) >= avg_earnings) THEN 
! 			UB = 0.828*EH(IE)
! 		ELSE 
! 			UB = 0.888*EH(IE)
! 		END IF 
! 	END IF
! END IF 
! ======================2nd Approach======================
! Source: Employment and hours over the business cycle in a model with search frictions
! IF (IS<7) THEN 
! 		UB = 0.0
! ELSE 
! 		UB = 0.6*EH(IE)/5.0 ! In general, unemployment insurance benefits will be paid up to one year after the date of losing your job. (source: Employment and hours over the business cycle in a model with search frictions)
! 		! UB =  0.45*EH(IE)/5.0 ! In general, unemployment insurance benefits will be paid up to one year after the date of losing your job.  !(UB/GDP=0.2%)
! 		! UB = 1.D-3
! END IF
UB = 0.0

end function UB
!*************************************************************************************************************************
END PROGRAM
