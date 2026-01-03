PROGRAM wealth_accounting


!*******************************************************************************************************************************************************************************************************************************************************************
! 1. Compiling the code: gfortran equal_bequest_common_return.f90 -fcheck=all -fbacktrace -ffree-line-length-none -fopenmp -O3 -o run

! 2. Run the code with: ./run 0.002200   0.850000   0.021200   0.758000  6 6   0.045   0.045   0.960000   0.940000  -1.400000   0.1 0.974  0.170000   2.206000   0.116000   0.045   0.900000   0.002500   0.990000   5.000000  15.000000
!*******************************************************************************************************************************************************************************************************************************************************************

!-----------------------------
! Order of Subroutine Calls:  
!-----------------------------
!	DECRULE01, BRACKET01, SRCHFIVE01, check_BRACKET01, A_SRCHFIVE01 and N_SRCHFIVE01
!										(solve the policy functions)
!	INVAR01						 		(Find invariant distribution)
!	compute_distributions		 		(Compute age-weighted distribution using the distribution obtained in INVAR01)
!	PROFILE01 					 		(Compute age profiles)
!	beq_distribution			 		(Compute bequest distribution)
!	avg_return					 		(compute the average return and asset-weighted average return)
!   bequest_exemption			 		(Compute top 2% bequest tax exemption level)
!	wealthshare							(Compute wealthshare)
!	compute_gini				 		(compute gini)
!	age_wealth_gini				 		(compute age_wealth_gini)
!	wageshare					 		(compute wageshare)
!	totalincomeshare 			 		(compute income share)
!   consumptionshare			 		(compute consumption share)
! 	avg_return_wealthgroups		 		(Calculate avg return by different wealth group)
!	avg_return_incomegroups		 		(Calculate avg return by different income group)
!	skewness					 		(Compute skewness)
!	AGE_PARTITION				 		(Compute age partition)
!	income_partition			 		(Compute income partition)
!	income_partition_sort_by_wealth 	(Compute wealth by income partition)
!	top_shares_age_partition			(Compute age at the top)
!	bequest								(Compute bequest statistics)
!	joint_dist							(Compute joint distributions)
!	tax_moment							(Compute tax moments)
!	correlation							(Compute correlation)
!	INTERGENERATIONAL					(Compute integenerational correlation)
!	earnings_growth_moments				(Compute earnings growth moments)
!	Calidiff							(Compute Sum of squared error between simulated results and observed data moments)

USE omp_lib

INTEGER, PARAMETER :: prec=SELECTED_REAL_KIND(15, 307)

!***************************
!	Settings for the program
!***************************
INTEGER, PARAMETER :: compute_eqm = 1 ! if 1, compute eqm. If 0, read eqm outcomes from file.

!*************************
!   Set Parameter values
!*************************

! parameters for iteration and convergence
REAL(prec), PARAMETER :: TOLB = 0.01                    			!  Convergence tolerance for bequests
REAL(prec), PARAMETER :: tol_lam = 0.001		        			!  Convergence tolerance for lambda
REAL(prec), PARAMETER :: TOLK = 0.006                   			!  Convergence tolerance for asset market clear
INTEGER, PARAMETER :: MAXITER = 30                      			!  Maximum number of iterations for convergence
REAL(prec), PARAMETER :: GRADLAMBDA = 0.5

! parameters for survival probability
REAL(prec), PARAMETER :: c0  = -5.490484              				!  Intercept of sur. prob. function
REAL(prec), PARAMETER :: c1  = 0.1499950            				!  Coefficent for age of sur. prob function
REAL(prec), PARAMETER :: c2  = 0.0161671            				!  Coefficent for age^2 of sur. prob function

! parameters for preferences
REAL(prec), PARAMETER :: SIGMA  = 1.50000                    		!  Risk aversion 
REAL(prec), PARAMETER :: THETA  = 1.0/0.82				     		!  theta = 1/0.82 implies frisch elasticity to 0.82
REAL(prec), PARAMETER :: chi    = 6.0 						 		!  Labor disutility parameter	
REAL(prec), PARAMETER :: bsigma  = 1.35000                   		!  Elasticity of bequest

! parameters for production
REAL(prec), PARAMETER :: ALPHA = 0.27		              		    !  Capital share
REAL(prec), PARAMETER :: TFP   = 1.55  			     				!  Multiplicative constant in production function
REAL(prec), PARAMETER :: DEP_ANNUAL = 0.045       				    !  Annual depreciation rate of capital
REAL(prec), PARAMETER :: DEP  = 1.000-(1.000-DEP_ANNUAL)**5.00 		!  5years Depreciation rate of capital

! government transfers
REAL(prec), PARAMETER :: flat_transf_rate = 0.027				    !  The general public in the form of disability benefits, veterans benefits etc
REAL(prec), PARAMETER :: medicare_rate = 0.033						!  Transfers to elderly: Medicare

! parameters for intergenerational correlations 
REAL(prec), PARAMETER :: ability_persistence = 0.65					!  Bequest correlations

! Set the bounds for lambda (for government budget clear iteration)
real(prec), parameter	:: lambdamin = 0.8  
real(prec), parameter	:: lambdamax = 1.3 

! parameters for different tax policies
real(prec), parameter	:: ty_max = 0.396  							!  Top marginal tax rate 2013-2016: ty_max=0.396 
real(prec), parameter   :: tau_c = 0.236   							!  Corporate tax rate
real(prec), parameter   :: tau_s = 0.05    							!  Average sales tax: total sales tax rev/total consumption expenditures
real(prec), parameter   :: beqtax_rate2 = 0.2						!  A flat 20% tax on the largest 2% of estates
real(prec), parameter   :: beqtax_rate1 = 0.0						!  No tax for outside the top 2% of estates

!*****************************************
!   SSA pension income (from SSA Tables)
!*****************************************
! Numbers are monthly basis (average indexed monthly earnings)
REAL(prec), PARAMETER :: ssmin_data = 0.0  
REAL(prec), PARAMETER :: bend1_data = 795.0   		
REAL(prec), PARAMETER :: bend2_data = 4793.0  	
REAL(prec), PARAMETER :: sscap_data = 7248.0  
REAL(prec), PARAMETER :: incsscap_data = 2363.13  
REAL(prec), PARAMETER :: avg_monthly_earnings = 3774.8  		
REAL(prec), PARAMETER :: SSGRIDMAX_data = sscap_data/avg_monthly_earnings  	
REAL(prec), PARAMETER :: ssmin = ssmin_data/avg_monthly_earnings 
REAL(prec), PARAMETER :: bend1 = bend1_data/avg_monthly_earnings	
REAL(prec), PARAMETER :: bend2 = bend2_data/avg_monthly_earnings	
REAL(prec), PARAMETER :: PIA_factor = 0.62	

! social security replacement rates
REAL(prec), PARAMETER :: rr1 = 0.9	
REAL(prec), PARAMETER :: rr2 = 0.32
REAL(prec), PARAMETER :: rr3 = 0.15

!*************************
!   Grid points Setting
!*************************
PARAMETER (nn = 8)							 						!  Labor productivity status
PARAMETER (MAXAGE = 16)                      						!  Maximum age allowed
INTEGER, PARAMETER :: RETAGE = 10           						!  Retirement age  
REAL(prec), PARAMETER :: AMAX   = 200000.000    					!  Maximum permissible asset
REAL(prec), PARAMETER :: AMIN   = 0.001         					!  Minimum permissible asset
PARAMETER (NGRIDR  = 3)					 							!  Number of points on return grid (state)
PARAMETER (NGRIDA  = 513)			     							!  Number of points on asset grid (state)
REAL(prec), PARAMETER :: CMIN   = 0.000000005       				!  Minimum permissible consumption
REAL(prec), PARAMETER :: LEIMIN   = 0.000000005     				!  Minimum permissible leisure

!**************************************************
!
!   Data Type Declarations and Dimension Statements
!
!**************************************************

INTEGER AGE, ILA, IUA, ISKIPA, ILN, IUN, ISKIPN 
INTEGER JAMAX, JNMAX, IA, IR, IR1, IS, IS1, IN, IC , NEWIS, NEWIR, XA, NEWZ, NEWR
INTEGER ID, ZEROINDEX
INTEGER ACLOSE, LOOPNUMBER 
INTEGER state_pos, index_A, index_C, isort
INTEGER iTimes1,iTimes2, rate
INTEGER ASWITCH1, ASWITCH2

! Define real valued variables
REAL(prec)  AEND, BEQEND, LEND, LSSEND, K, L, INCOME, TINCOME, IEND, KDEV, TWEND
REAL(prec)  BEQ, PREMIUM, BEQ1
REAL(prec)  WAGEZ, UTIL, LEI, CONS, SUR, VMAX, OUTPUT, X3
REAL(prec)  t0, t1
REAL(prec)	wea_gini, inc_gini, inc_gini_fullpopu, tinc_gini, cons_gini
REAL(prec)  wealth_trans(5,5)
REAL(prec)	Aggwealth, Aggincome, Aggincome_retire, Aggtincome,Aggtincome_transfer, Aggtincome_D_transfer, Aggconsumption
REAL(prec) 	kshare05, kshare1, kshare5, kshare10, kshare20, kshare40, kshare60, kshare80
REAL(prec) 	kshare0001, kshare0005, kshare001, kshare005, kshare01, pos_zero_k, share_zero_k
REAL(prec) 	klevel05, klevel1, klevel5, klevel10, klevel20, klevel40, klevel60, klevel80, klevel9095, klevel9599, klevel6080,klevel4060,klevel2040
REAL(prec) 	klevel0001, klevel0005, klevel001, klevel01
REAL(prec) 	incshare05, incshare1, incshare5, incshare10, incshare20, incshare40, incshare60, incshare80
REAL(prec) 	incshare0001, incshare0005, incshare001,incshare005, incshare01
REAL(prec) 	tincshare05, tincshare1, tincshare5, tincshare10, tincshare20, tincshare40, tincshare60, tincshare80
REAL(prec) 	tincshare0001, tincshare0005, tincshare001, tincshare005, tincshare01
REAL(prec)  bshare0_50,bshare50_70,bshare70_80,bshare80_90,bshare90_95,bshare95_99,bshare98_100,bshare99_100,beq_gini
REAL(prec) 	cshare05, cshare1, cshare5, cshare10, cshare20, cshare40, cshare60, cshare80
REAL(prec) 	cshare0001, cshare0005, cshare001, cshare01
REAL(prec)  sum_temp,tempsum,sum_temp1,sum_temp2
REAL(prec)  tempsumR(NGRIDR)
REAL(prec)  zawel, zaweh
REAL(prec)  k_pct99,k_pct90,k_pct30,k_mean,k_median,kratio99_50,kratio90_50,kratioMM,kratio50_30
REAL(prec)  inc_pct99,inc_pct90,inc_pct30,inc_mean,inc_median,incratio99_50,incratio90_50,incratioMM,incratio50_30
REAL(prec)  tinc_pct99,tinc_pct90,tinc_pct30,tinc_mean,tinc_median,tincratio99_50,tincratio90_50,tincratioMM,tincratio50_30
REAL(prec)  ALONG20_25,ALONG25_30,ALONG30_35,ALONG35_40,ALONG40_45,ALONG45_50,ALONG50_55,ALONG55_60,ALONG55_25
REAL(prec)	ALONG60_65, ALONG65_MORE, ALONG65_70, ALONG70_75, ALONG75_80, ALONG80_85, ALONG85_90, ALONG90_95, ALONG95_100, ALONG60_89
REAL(prec)  ILONG20_25,ILONG25_30,ILONG30_35,ILONG35_40,ILONG40_45,ILONG45_50,ILONG50_55,ILONG55_60,ILONG55_20
REAL(prec)	ILONG60_65, ILONG65_MORE, ILONG70_75, ILONG75_80, ILONG80_85, ILONG85_90, ILONG90_95
REAL(prec)  TILONG20_25,TILONG25_30,TILONG30_35,TILONG35_40,TILONG40_45,TILONG45_50,TILONG50_55,TILONG55_60,TILONG55_20
REAL(prec)	TILONG60_65, TILONG65_MORE, TILONG65_70, TILONG70_75, TILONG75_80, TILONG80_85, TILONG85_90, TILONG90_95, TILONG95_100
REAL(prec)  Avg_R,Avg_R_weighted, Avg_top0001_R, Avg_top0005_R, Avg_top001_R, Avg_top01_R, Avg_top05_R, Avg_top1_R, Avg_top5_R, Avg_top10_R, Avg_top20_R, Avg_top40_R,Avg_top60_R,Avg_top80_R,Avg_P4060_R
REAL(prec)  Avg_topinc0001_R, Avg_topinc0005_R, Avg_topinc001_R, Avg_topinc01_R, Avg_topinc05_R, Avg_topinc1_R, Avg_topinc5_R, Avg_topinc10_R, Avg_topinc20_R, Avg_topinc40_R,Avg_topinc60_R,Avg_topinc80_R,Avg_Pinc4060_R
REAL(prec)  r_implied, r_new, r1, r2, delta_r
REAL(prec)	Avg_bot40_R, Avg_bot20_R,Avg_bot90_R,Avg_99_9999_R, Avg_99_999_R,Avg_99_995_R, Avg_995_999_R, Avg_95_99_R,Avg_90_95_R
REAL(prec)	Avg_botinc40_R, Avg_botinc20_R,Avg_inc99_9999_R, Avg_inc99_999_R, Avg_inc95_99_R,Avg_inc90_95_R,Avg_inc995_999_R,Avg_inc99_995_R,Avg_incbot90_R
REAL(prec)  SD_R,SD_R_weighted, SD_top0001_R, SD_top0005_R, SD_top001_R,SD_top01_R,SD_top1_R,SD_top10_R,SD_top20_R,SD_top40_R,SD_top60_R,SD_top80_R,SD_P4060_R,SD_top5_R,SD_95_99_R,SD_90_95_R, SD_bot40_R, SD_bot20_R,SD_bot90_R,SD_99_9999_R,SD_99_999_R,SD_99_995_R,SD_995_999_R
REAL(prec)  SD_topinc0001_R, SD_topinc0005_R, SD_topinc001_R,SD_topinc01_R,SD_topinc1_R,SD_topinc10_R,SD_topinc20_R,SD_topinc40_R,SD_topinc60_R,SD_topinc80_R,SD_Pinc4060_R,SD_topinc5_R,SD_inc95_99_R,SD_inc90_95_R, SD_botinc40_R, SD_botinc20_R,SD_inc99_9999_R,SD_inc99_999_R,SD_inc995_999_R,SD_inc99_995_R,SD_incbot90_R
REAL(prec)  Avg_top0001_R_weighted,Avg_top0005_R_weighted,Avg_top001_R_weighted,Avg_top01_R_weighted,Avg_top05_R_weighted,Avg_top1_R_weighted,Avg_top5_R_weighted,Avg_top10_R_weighted,Avg_top20_R_weighted,Avg_top40_R_weighted,Avg_top60_R_weighted,Avg_top80_R_weighted,Avg_95_99_R_weighted,Avg_90_95_R_weighted,Avg_995_999_R_weighted,Avg_99_995_R_weighted,Avg_bot90_R_weighted
REAL(prec)  Avg_topinc0001_R_weighted,Avg_topinc0005_R_weighted,Avg_topinc001_R_weighted,Avg_topinc01_R_weighted,Avg_topinc05_R_weighted,Avg_topinc1_R_weighted,Avg_topinc5_R_weighted,Avg_topinc10_R_weighted,Avg_topinc20_R_weighted,Avg_topinc40_R_weighted,Avg_topinc60_R_weighted,Avg_topinc80_R_weighted,Avg_inc95_99_R_weighted,Avg_inc90_95_R_weighted,Avg_inc995_999_R_weighted,Avg_inc99_995_R_weighted,Avg_botinc90_R_weighted
REAL(prec)  SD_top0001_R_weighted,SD_top0005_R_weighted,SD_top001_R_weighted,SD_top01_R_weighted,SD_top05_R_weighted,SD_top1_R_weighted,SD_top5_R_weighted,SD_top10_R_weighted,SD_top20_R_weighted,SD_top40_R_weighted,SD_top60_R_weighted,SD_top80_R_weighted,SD_95_99_R_weighted,SD_90_95_R_weighted,SD_995_999_R_weighted,SD_99_995_R_weighted,SD_bot90_R_weighted
REAL(prec)  SD_topinc0001_R_weighted,SD_topinc0005_R_weighted,SD_topinc001_R_weighted,SD_topinc01_R_weighted,SD_topinc05_R_weighted,SD_topinc1_R_weighted,SD_topinc5_R_weighted,SD_topinc10_R_weighted,SD_topinc20_R_weighted,SD_topinc40_R_weighted,SD_topinc60_R_weighted,SD_topinc80_R_weighted,SD_inc95_99_R_weighted,SD_inc90_95_R_weighted,SD_inc995_999_R_weighted,SD_inc99_995_R_weighted,SD_botinc90_R_weighted 
REAL(prec)  VAR_topinc0001_R_weighted,VAR_topinc0005_R_weighted,VAR_topinc001_R_weighted,VAR_topinc01_R_weighted,VAR_topinc05_R_weighted,VAR_topinc1_R_weighted,VAR_topinc5_R_weighted,VAR_topinc10_R_weighted,VAR_topinc20_R_weighted,VAR_topinc40_R_weighted,VAR_topinc60_R_weighted,VAR_topinc80_R_weighted,VAR_inc95_99_R_weighted,VAR_inc90_95_R_weighted,VAR_inc995_999_R_weighted,VAR_inc99_995_R_weighted,VAR_botinc90_R_weighted 
REAL(prec)	earning_share_avg,kincome_share_avg,trans_share_avg,age_share_avg,earning_share001,kincome_share001,earning_share01,kincome_share01,earning_share05,kincome_share05,earning_share1,kincome_share1,earning_share5,kincome_share5,earning_share10,kincome_share10,trans_share01,trans_share1,age_share01,age_share1, &
			earning_share995999, kincome_share995999, earning_share9599, kincome_share9599,trans_share9599,age_share9599, earning_share9095,kincome_share9095,trans_share9095,age_share9095,earning_share0510,kincome_share0510,trans_share0510,age_share0510,earning_share0105,kincome_share0105,trans_share0105,age_share0105,earning_share0090,kincome_share0090,trans_share0090,age_share0090, &
			earning_share5q,kincome_share5q,trans_share5q,age_share5q, earning_share4q,kincome_share4q,trans_share4q, age_share4q,earning_share3q,kincome_share3q,trans_share3q, age_share3q,earning_share2q,kincome_share2q,trans_share2q, age_share2q,earning_share1q,kincome_share1q,trans_share1q, age_share1q
REAL(prec)	earning_share_avg_sort_by_wealth,kincome_share_avg_sort_by_wealth,trans_share_avg_sort_by_wealth,age_share_avg_sort_by_wealth, &
			earning_share1_sort_by_wealth,kincome_share1_sort_by_wealth,earning_share5_sort_by_wealth,kincome_share5_sort_by_wealth,earning_share10_sort_by_wealth,kincome_share10_sort_by_wealth,trans_share1_sort_by_wealth, age_share1_sort_by_wealth, &
			earning_share9599_sort_by_wealth, kincome_share9599_sort_by_wealth,trans_share9599_sort_by_wealth,age_share9599_sort_by_wealth, earning_share9095_sort_by_wealth,kincome_share9095_sort_by_wealth,trans_share9095_sort_by_wealth, &
			age_share9095_sort_by_wealth,earning_share0510_sort_by_wealth,kincome_share0510_sort_by_wealth,trans_share0510_sort_by_wealth,age_share0510_sort_by_wealth,earning_share0105_sort_by_wealth,kincome_share0105_sort_by_wealth,trans_share0105_sort_by_wealth,age_share0105_sort_by_wealth, &
			earning_share5q_sort_by_wealth,kincome_share5q_sort_by_wealth,trans_share5q_sort_by_wealth,age_share5q_sort_by_wealth, earning_share4q_sort_by_wealth,kincome_share4q_sort_by_wealth,trans_share4q_sort_by_wealth, age_share4q_sort_by_wealth,earning_share3q_sort_by_wealth,kincome_share3q_sort_by_wealth, &
			trans_share3q_sort_by_wealth, age_share3q_sort_by_wealth,earning_share2q_sort_by_wealth,kincome_share2q_sort_by_wealth,trans_share2q_sort_by_wealth, age_share2q_sort_by_wealth,earning_share1q_sort_by_wealth,kincome_share1q_sort_by_wealth,trans_share1q_sort_by_wealth, age_share1q_sort_by_wealth, &
			earning_share05_sort_by_wealth,kincome_share05_sort_by_wealth,trans_share05_sort_by_wealth,age_share05_sort_by_wealth, 	earning_share01_sort_by_wealth,kincome_share01_sort_by_wealth,trans_share01_sort_by_wealth,age_share01_sort_by_wealth,	&
			earning_share005_sort_by_wealth,kincome_share005_sort_by_wealth,trans_share005_sort_by_wealth,age_share005_sort_by_wealth,	earning_share001_sort_by_wealth,kincome_share001_sort_by_wealth,trans_share001_sort_by_wealth,age_share001_sort_by_wealth, &
			earning_share8090_sort_by_wealth,kincome_share8090_sort_by_wealth,trans_share8090_sort_by_wealth,age_share8090_sort_by_wealth, earning_share99995_sort_by_wealth,kincome_share99995_sort_by_wealth,trans_share99995_sort_by_wealth,age_share99995_sort_by_wealth, &
			earning_share995999_sort_by_wealth,kincome_share995999_sort_by_wealth,trans_share995999_sort_by_wealth,age_share995999_sort_by_wealth, earning_share9999999_sort_by_wealth,kincome_share9999999_sort_by_wealth,trans_share9999999_sort_by_wealth,age_share9999999_sort_by_wealth
REAL(prec)	share_topz_all, share_topz_01, share_topz_1, share_z8_all, share_z8_01, share_z8_1, share_topr_all, share_topr_01, share_topr_1, share_topboth_all, share_topboth_01, share_topboth_1
REAL(prec)  share_zr_all(nn,NGRIDR), share_zr_top1(nn,NGRIDR), share_zr_top01(nn,NGRIDR)
REAL(prec)	age_share1_2030, age_share1_3145, age_share1_4665, age_share1_6699,	age_share1_sort_by_wealth_2030,	age_share1_sort_by_wealth_3145,	age_share1_sort_by_wealth_4665,	age_share1_sort_by_wealth_6699
REAL(prec)  age_income_share1_20_29, age_income_share1_30_44, age_income_share1_45_64, age_income_share1_65_99
REAL(prec)  age_wealth_share1_20_29, age_wealth_share1_30_44, age_wealth_share1_45_64, age_wealth_share1_65_99
REAL(prec)  age_earning_share1_20_29, age_earning_share1_30_44, age_earning_share1_45_64, age_earning_share1_65_99
REAL(prec)	MPK,MPL,beta_update,MAXBETA,MINBETA
REAL(prec)  beq_wealth_ratio,AggBeq,Beq98, beq_pct98,Beq95, beq_pct95, Beq90, beq_pct90,Beq80, beq_pct80,Beq70, beq_pct70,Beq60, beq_pct60,Beq50, beq_pct50,Beq40, beq_pct40,Beq30, beq_pct30,Beq20, beq_pct20,Beq10, beq_pct10 
REAL(prec)  kshare_Y0001, kshare_Y0005, kshare_Y001, kshare_Y01, kshare_Y05, kshare_Y1, kshare_Y5, kshare_Y10, kshare_Y20, kshare_Y40, kshare_Y60, kshare_Y80
REAL(prec)  klevel_Y0001, klevel_Y0005, klevel_Y001, klevel_Y01, klevel_Y05, klevel_Y1, klevel_Y5, klevel_Y10, klevel_Y20, klevel_Y40, klevel_Y60, klevel_Y80, klevel_Y9599,klevel_Y9095, klevel_Y6080,klevel_Y4060,klevel_Y2040
REAL(prec)  kshare_E0001, kshare_E0005, kshare_E001, kshare_E01, kshare_E05, kshare_E1, kshare_E5, kshare_E10, kshare_E20, kshare_E40, kshare_E60, kshare_E80
REAL(prec)  klevel_E0001, klevel_E0005, klevel_E001, klevel_E01, klevel_E05, klevel_E1, klevel_E5, klevel_E10, klevel_E20, klevel_E40, klevel_E60, klevel_E80
REAL(prec)  cshare_tinc0001, cshare_tinc0005, cshare_tinc001, cshare_tinc01, cshare_tinc05, cshare_tinc1, cshare_tinc5, cshare_tinc10, cshare_tinc20, cshare_tinc40, cshare_tinc60, cshare_tinc80
REAL(prec)  lambda_implied,lambda, lambda1, lambda2, lambdaold, gbcdenom, gbcnum, dlam, bendy, yd
REAL(prec)	cor_tax_rev,sales_tax_rev, ATC1, ATC99, ctaxrev_income, ctaxrev_GDP, ATY1,ATY99,inctaxrev_income, inctaxrev_GDP, G_share, MTR1, MTR10,beq_tax_rev,beq_paytax,beq_gross
REAL(prec)	temp,temp2,temp_ctaxrev,temp_cons,temp_staxrev,temp_btaxrev
REAL(prec)	incvar,mean_incvar 
REAL(prec)  KD, BETA
REAL(prec)	WAGE
REAL(prec)	xL,xH,x45,xLL,xLH,xHL,xHH
REAL(prec)	dev_beq_tran_mat1,dev_beq_tran_mat2,beq_receive,beq_given,BEQTRANS,BEQTRANS1,equal_bequest_transfer
REAL(prec)  ALONG_RETIRE,ILONG_RETIRE,TILONG_RETIRE
REAL(prec)  gov_trans,medicare 
REAL(prec)	wealththreshold0001,wealththreshold01,wealththreshold05,wealththreshold1,wealththreshold5,wealththreshold10,wealththreshold20,wealththreshold40,wealththreshold50,wealththreshold60,wealththreshold80
REAL(prec)	earningthreshold1,incomethreshold1
REAL(prec)  poputop1,staytop1
REAL(prec)	SSE 
REAL(prec)	corr_earn_wealth,corr_earn_wealth_working,corr_income_wealth,cov_earn_wealth,cov_earn_wealth_working,cov_income_wealth,var_wealth,var_wealth_working,var_earn,var_earn_working,var_income,wealth_mean_corr,wealth_mean_corr_working,earn_mean_corr,earn_mean_corr_working,income_mean_corr
REAL(prec)  corr_earn_kinc,corr_earn_kinc_working,cov_earn_kinc,cov_earn_kinc_working,var_kinc,var_kinc_working,kinc_mean_corr,kinc_mean_corr_working
REAL(prec)	corr_Akids_Aparents_sq, corr_Akids_Aparents_lin
REAL(prec)  INCOME_today,INCOME_tmr,avg_earning_growth,sd_earning_growth,skew_earning_growth,kurt_earning_growth
REAL(prec)  lambda_in,lambda_out,lambda_lh,lambda_ll,lambda_hl,lambda_hh
REAL(prec)  p11_r, p22_r, p33_r, pawein, pawein2, pawein3, pawein4, relpawein2, relpawein3, relpawein4, prawe, intergen_corr_return
REAL(prec)  incsscap
REAL(prec)  beqtax_exempt,popu_left_beq,popu_receive_beq
REAL(prec)  SUM_D_YW,SUM_D_YR

INTEGER zgroup(nn)
INTEGER statecodes(MAXAGE,NGRIDA,NGRIDR,nn)
INTEGER statecount
INTEGER IDCWA(:,:,:,:)     		!  Asset decision rules for working-age
INTEGER OLD_IDCWA(:,:,:,:)
INTEGER IDCWN(:,:,:,:)     		!  Decision rules of labor supply for working-age
INTEGER OLD_IDCWN(:,:,:,:) 
REAL(prec) IDCWC(:,:,:,:)     	!  Consumption decision rules for working-age
INTEGER IDCRA(:,:,:,:)     		!  Asset decision rules for retirees
INTEGER IDCRN(:,:,:,:)     	    !  Decision rules of labor supply for retirees
REAL(prec) IDCRC(:,:,:,:)       !  Consumption decision rules for retirees 

INTEGER top05pct_D(:), top1pct_D(:), top5pct_D(:), top10pct_D(:), top20pct_D(:), top40pct_D(:), top50pct_D(:),top60pct_D(:), top70pct_D(:), top80pct_D(:),top90pct_D(:),top95pct_D(:),top99pct_D(:)
INTEGER	bot99pct_D(:), bot90pct_D(:), bot50pct_D(:), bot30pct_D(:), bot99pct_D_inc(:), bot90pct_D_inc(:), bot50pct_D_inc(:), bot30pct_D_inc(:),bot99pct_D_tinc(:), bot90pct_D_tinc(:), bot50pct_D_tinc(:), bot30pct_D_tinc(:)
INTEGER top0001pct_D(:), top0005pct_D(:), top001pct_D(:), top005pct_D(:), top01pct_D(:)
INTEGER top05pct_D_inc(:), top1pct_D_inc(:), top5pct_D_inc(:), top10pct_D_inc(:), top20pct_D_inc(:),top39pct_D_inc(:), top40pct_D_inc(:), top50pct_D_inc(:), top60pct_D_inc(:), top70pct_D_inc(:), top80pct_D_inc(:)
INTEGER top0001pct_D_inc(:), top0005pct_D_inc(:), top001pct_D_inc(:),top005pct_D_inc(:),top0039pct_D_inc(:), top01pct_D_inc(:), top025pct_D_inc(:)
INTEGER top05pct_D_tinc(:), top1pct_D_tinc(:),top1pct_D_tinc_no_transf(:), top5pct_D_tinc(:), top10pct_D_tinc(:), top10pct_D_tinc_no_transf(:), top20pct_D_tinc(:), top40pct_D_tinc(:),top50pct_D_tinc(:), top60pct_D_tinc(:),top70pct_D_tinc(:), top80pct_D_tinc(:), top90pct_D_tinc(:), top95pct_D_tinc(:),top99pct_D_tinc(:),bot20pct_D_tinc(:)
INTEGER top0001pct_D_tinc(:), top0005pct_D_tinc(:), top001pct_D_tinc(:), top005pct_D_tinc(:), top01pct_D_tinc(:), top025pct_D_tinc(:)
INTEGER top05pct_D_R(:,:), top1pct_D_R(:,:), top5pct_D_R(:,:), top10pct_D_R(:,:), top20pct_D_R(:,:), top40pct_D_R(:,:),top50pct_D_R(:,:), top60pct_D_R(:,:),top70pct_D_R(:,:), top80pct_D_R(:,:)
INTEGER top1pct_D_B(:),top2pct_D_B(:),top2pct_D_B_gross(:),top5pct_D_B(:),top10pct_D_B(:),top20pct_D_B(:),top30pct_D_B(:),top40pct_D_B(:),top50pct_D_B(:),top60pct_D_B(:),top70pct_D_B(:),top80pct_D_B(:),top90pct_D_B(:)
INTEGER top05pct_D_C(:), top1pct_D_C(:), top5pct_D_C(:), top10pct_D_C(:), top20pct_D_C(:), top40pct_D_C(:), top50pct_D_C(:),top60pct_D_C(:), top70pct_D_C(:), top80pct_D_C(:),top90pct_D_C(:),top95pct_D_C(:),top99pct_D_C(:)
INTEGER top0001pct_D_C(:), top0005pct_D_C(:), top001pct_D_C(:), top01pct_D_C(:)
INTEGER indentify_R(:,:), indentify_Z(:,:), box_C(:), record_position_C(:)
INTEGER record_position_tinc(:), record_position_tinc_no_transf(:), record_position_A(:), record_position_E(:), record_position_B(:), record_position_B_gross(:), ind_z(:), ind_r(:), ind_topz(:), ind_topr(:), ind_z8(:), ind_ri(:), ind_zi(:)

! Define real valued vectors
REAL(prec) A(:)              			!  Asset levels (control variable)
REAL(prec) N(:)              			!  Working hours ratio
REAL(prec) ALONG(:)          			!  Longitudinal age-assets profile (aggregate asset for each age cohort)
REAL(prec) BLONG(:)          			!  Longitudinal age-bequest profile (aggregate bequest for each age cohort)
REAL(prec) ALONG_AGE(:)					!  Longitudinal age-assets profile (average asset for each age cohort)
REAL(prec) ILONG_AGE(:)					!  Longitudinal age-earnings profile (average earnings for each age cohort)
REAL(prec) TILONG_AGE(:)				!  Longitudinal age-income profile (average income for each age cohort)
REAL(prec) ACROSS(:)          			!  Cross-sectional age-assets profile
REAL(prec) CLONG(:)          			!  Longitudinal age-consumption profile
REAL(prec) CCROSS(:)          			!  Cross-sectional age-consumption profile
REAL(prec) BCROSS(:) 					!  Cross-sectional age-bequest profile
REAL(prec) EFFCROSS(:)       			!  Cross-sectional age efficiency profile 
REAL(prec) EFFLONG(:)        			!  Longitudinal age efficiency profile 
REAL(prec) ILONG(:)          			!  Longitudinal age-earnings profile
REAL(prec) ICROSS(:)          			!  Cross-sectional age-earnings profile
REAL(prec) TILONG(:)         			!  Longitudinal total income (labor + asset) age-profile
REAL(prec) TICROSS(:)          			!  Cross-sectional total income age-profile
REAL(prec) NLONG(:)          			!  Longitudinal efficiency labor supply profile
REAL(prec) NCROSS(:)          			!  Cross-sectional efficiency labor supply profile
REAL(prec) LLONG(:)          			!  Longitudinal labor supply profile
REAL(prec) LCROSS(:)          			!  Cross-sectional labor supply profile
REAL(prec) CUMS(:)           			!  Unconditional survival probabilities, age 1 to age j
REAL(prec) MU(:)             			!  Age distribution of population
REAL(prec) CUMSWK(:)         			!  Unconditional survival probabilities, age 1 to age j, for working age
REAL(prec) MUWK(:)           			!  Age distribution of working age population
REAL(prec) S(:)             			!  Conditional survival probabilities, age j-1 to age j
REAL(prec) P(nn,nn)                  	!  Transition matrix of idiosyncratic productivity shock
REAL(prec) W(nn)                  		!  Idiosyncratic productivity shock
REAL(prec) invar(nn)					!  age 0 distribution of z
REAL(prec) mu_z(1,nn)					!  distribution of z (average over age)
REAL(prec) mu_z_working(1,nn)			!  distribution of z (average over working age)
REAL(prec) mu_z_age(MAXAGE,nn)			!  distribution of z
REAL(prec) mu_z_working_age(RETAGE-1,nn)!  distribution of z for working age population
REAL(prec) mu_r_z_age(MAXAGE,NGRIDR,nn) !  joint distribution of z and r	
REAL(prec) mu_r_age(MAXAGE,NGRIDR)		!  distribution of r
REAL(prec) mu_r(1,NGRIDR)				!  distribution of r (average over age)
REAL(prec) P_r(NGRIDR,NGRIDR,4) 		!  Transition matrix for return rates
REAL(prec) SSprob_r(NGRIDR,NGRIDR)		!  Invariant distribution of return rates
REAL(prec) SSprob_z(nn,nn)              !  Invariant distribution of z
REAL(prec) probmul(NGRIDR,NGRIDR)		!  stationary probabilities for return
REAL(prec) probmul_P(nn,nn)				!  stationary probabilities for productivity
real(prec) basicz(nn)					!  log of productivity states value
real(prec) z(nn)						!  Productivity states value
real(prec) EH(nn)						!  Earning history states
REAL(prec) SS(nn)    					!  Pension benefits states
REAL(prec) share_r_top01_tinc(NGRIDR)   !  Unweighted distribution of capital return rate in top0.1 income share
REAL(prec) weighted_share_r_top01_tinc(NGRIDR) 	! Weighted distribution of capital return rate in top0.1 income share
REAL(prec) share_z_top01_tinc(nn)       ! Unweighted distribution of productivity states in top0.1 income share
REAL(prec) weighted_share_z_top01_tinc(nn)      ! Weighted distribution of productivity states in top0.1 income share    
REAL(prec) VW(:,:,:,:)          		!  Value function for working-age
REAL(prec) YW(:,:,:,:)          		!  Age-dependent distribution of agents across states for working-age
REAL(prec) VR(:,:,:,:)          		!  Value function for retirees
REAL(prec) YR(:,:,:,:)          		!  Age-dependent distribution of agents across states for retirees
REAL(prec) X(:,:)			  			!  A vector to store variables for computing Gini [ wealth: x(:,1), labor income: x(:,2), total income: x(:,3) ]
REAL(prec) D(:)							!  Age-weighted distribution for computing income and consumption Gini
REAL(prec) D_inc(:)						!  Age-weighted distribution for computing earnings Gini
REAL(prec) D_A(:)						!  Age-weighted distribution for computing wealth Gini
REAL(prec) x_age(:,:)					!  To store asset data for computing age-profile wealth Gini
REAL(prec) tinc_age(:,:)			    !  To store income data for computing age-profile income Gini
REAL(prec) e_age(:,:)					!  To store earnings data for computing age-profile earnings Gini
REAL(prec) D_age(:,:)					!  Age-weighted distribution for computing age-profile earnings Gini
REAL(prec) NorD_age(:,:)				!  Normalized D_age(:,:) such that the sum of D_age(:,:)=1
REAL(prec) age_wea_gini(:)				!  A vector to store the wealth gini level for each age cohort
REAL(prec) age_inc_gini(:)				!  A vector to store the earnings gini level for each age cohort
REAL(prec) age_tinc_gini(:)				!  A vector to store the income gini level for each age cohort
REAL(prec) D_YW(:,:,:,:)				!  Age-weighted population distribution for working groups
REAL(prec) D_YR(:,:,:,:)				!  Age-weighted population distribution for retired groups
REAL(prec) working_dist(:,:,:,:)		!  Age-weighted population distribution for working groups
REAL(prec) read_vector(:)				!  A vector to store decision variables and distributions from the text files
REAL(prec) sort_A(:)					!  A vector to store wealth sorted by wealth distribution 
REAL(prec) sort_A_tinc(:)				!  A vector to store wealth sorted by income distribution 
REAL(prec) sort_inc(:)					!  A vector to store earnings sorted by earnings distribution 
REAL(prec) sort_tinc(:)					!  A vector to store income sorted by income distribution 
REAL(prec) sort_tinc_no_transf(:)		!  A vector to store income (excluded the after-tax corporate income) level sorted by income distribution
REAL(prec) sort_B(:)					!  A vector to store after-tax bequest sorted by after-tax bequest distribution 
REAL(prec) sort_B_gross(:)				!  A vector to store pre-tax bequest sorted by pre-tax bequest distribution 
REAL(prec) sort_C(:)					!  A vector to store consumption sorted by consumption distribution
REAL(prec) sort_D(:)					!  A vector to store distribution sorted by wealth
REAL(prec) sort_D_inc(:)				!  A vector to store distribution sorted by earnings		
REAL(prec) sort_D_tinc(:)				!  A vector to store distribution sorted by income	
REAL(prec) sort_D_tinc_no_transf(:)		!  A vector to store distribution sorted by income excluding after-tax corporate income
REAL(prec) sort_D_R(:,:)				!  A vector to store distribution sorted by wealth for different return groups
REAL(prec) sort_D_Z(:,:)				!  A vector to store distribution sorted by wealth for different productivity states groups
REAL(prec) sort_D_R_weighted(:,:)		!  A vector to store distribution sorted by wealth for different weighted return groups
REAL(prec) sort_D_Z_weighted(:,:)		!  A vector to store distribution sorted by	weighted share of productivity level z
REAL(prec) sort_D_B(:)					!  A vector to store distribution sorted by after-tax bequest distribution
REAL(prec) sort_D_B_gross(:)			!  A vector to store distribution sorted by pre-tax bequest distribution
REAL(prec) sort_D_C(:)					!  A vector to store distribution sorted by consumption
REAL(prec) cum_sort_D(:)				!  A vector to store cumulative distribution sorted by wealth
REAL(prec) cum_sort_D_inc(:)			!  A vector to store cumulative distribution sorted by earnings
REAL(prec) cum_sort_D_tinc(:)			!  A vector to store cumulative distribution sorted by income
REAL(prec) cum_sort_D_tinc_no_transf(:) !  A vector to store cumulative distribution sorted by income excluding after-tax corporate income
REAL(prec) cum_sort_D_R(:,:)			!  A vector to store cumulative distribution sorted by wealth for different return groups
REAL(prec) cum_sort_D_B(:)				!  A vector to store cumulative distribution sorted by after-tax bequest
REAL(prec) cum_sort_D_B_gross(:)		!  A vector to store cumulative distribution sorted by pre-tax bequest	
REAL(prec) cum_sort_D_C(:)				!  A vector to store cumulative distribution sorted by consumption
REAL(prec) R(:),R_ANNUAL(:)				!  5-year return rates; annual return rates
REAL(prec) totalincome(:),earning_share(:), kincome_share(:), trans_share(:), age_share(:)
REAL(prec) totalincome_sort_by_wealth(:),earning_share_sort_by_wealth(:), kincome_share_sort_by_wealth(:), trans_share_sort_by_wealth(:), age_share_sort_by_wealth(:)
INTEGER age_2030(:), age_3145(:), age_4665(:), age_6699(:)
REAL(prec) age_wealth_share_20_29(:), age_wealth_share_30_44(:), age_wealth_share_45_64(:), age_wealth_share_65_99(:)
REAL(prec) age_earning_share_20_29(:), age_earning_share_30_44(:), age_earning_share_45_64(:), age_earning_share_65_99(:)
REAL(prec) age_income_share_20_29(:), age_income_share_30_44(:), age_income_share_45_64(:), age_income_share_65_99(:)
REAL(prec) sort_cons_Y(:), sort_wealth_Y(:), sort_wealth_E(:)
REAL(prec) sort_ATY(:),sort_ATC(:),sort_noncorpY(:) , MTR(:)
REAL(prec) :: pdf_parent_kid(2,2,2,2)
REAL(prec) parentbeq_basket(:,:,:),beq_dist(:,:,:),X45_lowkid_dist(:,:,:,:),X45_lowkid_dist1(:,:,:,:),X45_highkid_dist(:,:,:,:),X45_highkid_dist1(:,:,:,:),X45_highparent_dist(:,:,:,:),X45_lowparent_dist(:,:,:,:)
REAL(prec) targets(:),bench_calibration(:),error(:)
REAL(prec) earngrowth(:),density_earngrowth(:)
REAL(prec) beqgroup(:),beqprob(:)

! Input arguments captured at execution:
character(20) :: Argument1, Argument2, Argument3, Argument4, Argument5, Argument6, Argument7
character(20) :: Argument8, Argument9, Argument10, Argument11, Argument12,  Argument13,  Argument14
character(20) :: Argument15,  Argument16, Argument17, Argument18, Argument19, Argument20, Argument21, Argument22 

ALLOCATABLE  A, N,  ACROSS, ALONG,ALONG_AGE, ILONG_AGE, TILONG_AGE, CCROSS, CLONG, CUMS, CUMSWK, EFFCROSS, EFFLONG, ICROSS, ILONG, TILONG, TICROSS, BCROSS, BLONG
ALLOCATABLE  NCROSS, NLONG, LCROSS, LLONG, MU, MUWK, S
ALLOCATABLE  IDCWA,OLD_IDCWA, OLD_IDCWN, IDCWN, IDCWC, VW, YW, IDCRA, IDCRN, IDCRC, VR, YR
ALLOCATABLE  X,D,D_inc,D_A,x_age,tinc_age,e_age,D_age,NorD_age,age_wea_gini,age_inc_gini,age_tinc_gini,D_YW,D_YR,sort_A,sort_A_tinc,sort_inc,sort_tinc,sort_tinc_no_transf,sort_D,sort_D_inc,sort_D_tinc,sort_D_tinc_no_transf,cum_sort_D,cum_sort_D_inc,cum_sort_D_tinc,cum_sort_D_tinc_no_transf
ALLOCATABLE  sort_D_R,sort_D_Z,cum_sort_D_R, sort_D_R_weighted,sort_D_Z_weighted
ALLOCATABLE  sort_C, sort_D_C,cum_sort_D_C
ALLOCATABLE  sort_B, sort_B_gross, sort_D_B, sort_D_B_gross,cum_sort_D_B,cum_sort_D_B_gross
ALLOCATABLE  indentify_R, indentify_Z, box_C, record_position_C
ALLOCATABLE  top05pct_D, top1pct_D, top5pct_D, top10pct_D, top20pct_D, top40pct_D, top50pct_D, top60pct_D, top70pct_D, top80pct_D, top90pct_D, top95pct_D, top99pct_D
ALLOCATABLE  bot99pct_D, bot90pct_D, bot50pct_D, bot30pct_D, bot99pct_D_inc, bot90pct_D_inc, bot50pct_D_inc, bot30pct_D_inc,bot99pct_D_tinc, bot90pct_D_tinc, bot50pct_D_tinc, bot30pct_D_tinc
ALLOCATABLE  top0001pct_D, top0005pct_D, top001pct_D, top005pct_D,top01pct_D
ALLOCATABLE  top05pct_D_inc, top1pct_D_inc, top5pct_D_inc, top10pct_D_inc, top20pct_D_inc, top39pct_D_inc, top40pct_D_inc, top50pct_D_inc, top60pct_D_inc, top70pct_D_inc, top80pct_D_inc
ALLOCATABLE  top0001pct_D_inc, top0005pct_D_inc, top001pct_D_inc,top005pct_D_inc, top0039pct_D_inc, top01pct_D_inc, top025pct_D_inc
ALLOCATABLE  top05pct_D_tinc, top1pct_D_tinc, top1pct_D_tinc_no_transf, top5pct_D_tinc, top10pct_D_tinc, top10pct_D_tinc_no_transf, top20pct_D_tinc, top40pct_D_tinc,top50pct_D_tinc, top60pct_D_tinc,top70pct_D_tinc, top80pct_D_tinc,top90pct_D_tinc,top95pct_D_tinc,top99pct_D_tinc,bot20pct_D_tinc
ALLOCATABLE  top0001pct_D_tinc, top0005pct_D_tinc, top001pct_D_tinc, top005pct_D_tinc, top01pct_D_tinc, top025pct_D_tinc
ALLOCATABLE  top05pct_D_R, top1pct_D_R, top5pct_D_R, top10pct_D_R, top20pct_D_R, top40pct_D_R,top50pct_D_R, top60pct_D_R,top70pct_D_R, top80pct_D_R
ALLOCATABLE  top1pct_D_B,top2pct_D_B,top2pct_D_B_gross,top5pct_D_B,top10pct_D_B,top20pct_D_B,top30pct_D_B,top40pct_D_B,top50pct_D_B,top60pct_D_B,top70pct_D_B,top80pct_D_B,top90pct_D_B
ALLOCATABLE  top05pct_D_C, top1pct_D_C, top5pct_D_C, top10pct_D_C, top20pct_D_C, top40pct_D_C, top50pct_D_C, top60pct_D_C, top70pct_D_C, top80pct_D_C, top90pct_D_C, top95pct_D_C, top99pct_D_C
ALLOCATABLE  top0001pct_D_C, top0005pct_D_C, top001pct_D_C, top01pct_D_C
ALLOCATABLE  R, R_ANNUAL
ALLOCATABLE  record_position_tinc,record_position_tinc_no_transf, record_position_A,record_position_E,record_position_B,record_position_B_gross,ind_z,ind_r,ind_topz,ind_topr,ind_z8,ind_ri,ind_zi
ALLOCATABLE	 totalincome, earning_share, kincome_share, trans_share, age_share
ALLOCATABLE	 totalincome_sort_by_wealth, earning_share_sort_by_wealth, kincome_share_sort_by_wealth, trans_share_sort_by_wealth, age_share_sort_by_wealth
ALLOCATABLE  age_2030, age_3145, age_4665, age_6699
ALLOCATABLE  age_wealth_share_20_29, age_wealth_share_30_44, age_wealth_share_45_64, age_wealth_share_65_99
ALLOCATABLE  age_earning_share_20_29, age_earning_share_30_44, age_earning_share_45_64, age_earning_share_65_99
ALLOCATABLE  age_income_share_20_29, age_income_share_30_44, age_income_share_45_64, age_income_share_65_99
ALLOCATABLE  sort_cons_Y, sort_wealth_Y, sort_wealth_E
ALLOCATABLE  sort_ATY, sort_ATC,sort_noncorpY, MTR
ALLOCATABLE	 parentbeq_basket,beq_dist,X45_lowkid_dist,X45_lowkid_dist1,X45_highkid_dist,X45_highkid_dist1,X45_highparent_dist,X45_lowparent_dist 
ALLOCATABLE  targets,bench_calibration,error
ALLOCATABLE  earngrowth,density_earngrowth
ALLOCATABLE  working_dist
ALLOCATABLE  read_vector
ALLOCATABLE  beqgroup, beqprob

real(prec) ostart,oend
real(prec) fstart, fend

!*********************
!
!   Open Files
!
!*********************

! Read the data of age efficiency profile

OPEN(UNIT=7,FILE='age_eff.txt')


!*********************
!
!   Read Data
!
!*********************

    ALLOCATE( EFFCROSS(RETAGE-1) )     ! allocate age efficiency profile to the vector "EFFCROSS"
    READ(7,*) ( EFFCROSS(AGE), AGE=1,RETAGE-1 )

!   Longitudinal age-earnings profile for given cohort

    ALLOCATE( EFFLONG(RETAGE-1) )
    EFFLONG = (/ ( EFFCROSS(AGE), AGE=1,RETAGE-1 ) /)

! The calibrated parameters
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
	CALL GET_COMMAND_ARGUMENT(12,Argument12)
    CALL GET_COMMAND_ARGUMENT(13,Argument13)
    CALL GET_COMMAND_ARGUMENT(14,Argument14)
	CALL GET_COMMAND_ARGUMENT(15,Argument15)
	CALL GET_COMMAND_ARGUMENT(16,Argument16)
	CALL GET_COMMAND_ARGUMENT(17,Argument17)
	CALL GET_COMMAND_ARGUMENT(18,Argument18)
	CALL GET_COMMAND_ARGUMENT(19,Argument19)
	CALL GET_COMMAND_ARGUMENT(20,Argument20)
	CALL GET_COMMAND_ARGUMENT(21,Argument21)
	CALL GET_COMMAND_ARGUMENT(22,Argument22)

	 read(Argument1,*) lambda_in   										! probability of getting into the awesome states
	 read(Argument2,*) lambda_ll										! probability of staying at z7
	 read(Argument3,*) lambda_lh  										! probability of moving from z7 to z8
	 read(Argument4,*) lambda_hh 										! probability of staying at z8
	 read(Argument5,*) zawel											! productivity level of z7
	 read(Argument6,*) zaweh											! productivity level of z8
	 read(Argument7,*) RMIN												! saving return rate of r1
	 read(Argument8,*) RMAX												! saving return rate of r2
	 read(Argument9,*) p11_r											! probability of staying at r1
	 read(Argument10,*) p22_r	 										! probability of staying at r2
     read(Argument11,*) bcoeff   										! coefficient of bequest utility (phi1)
	 read(Argument12,*) bcoeff2  										! coefficient of bequest utility (phi2)
	 read(Argument13,*) BETA_ANNUAL 									! utility discount factor
	 read(Argument14,*) tau_l											! tax progressivity parameter
	 read(Argument15,*) d_c												! Corporate asset threshold
	 read(Argument16,*) gov												! government expenditure to GDP ratio
	 read(Argument17,*) RAWE											! saving return rate of r3
	 read(Argument18,*) p33_r											! probability of staying at r3
	 read(Argument19,*) prawe											! inflow rates to top return by productivity level z
	 read(Argument20,*) intergen_corr_return							! intergenerational correlations in return
	 read(Argument21,*) relpawein3										! probability of getting into r3 relative to ordinary productivity states conditional on z7
	 read(Argument22,*) relpawein4										! probability of getting into r3 relative to ordinary productivity states conditional on z8

	relpawein2 = 1.
	zgroup = (/ 1, 1, 1, 2, 2, 2, 3, 4 /)

print*,''
print*,''
print*, '============================='
print*, ' Input calibrated parameters'
print*, '============================='
print*, ''
print*, 'probability of getting into the awesome states', lambda_in
print*, 'probability of staying at z7', lambda_ll
print*, 'probability of moving from z7 to z8', lambda_lh
print*, 'probability of staying at z8', lambda_hh
print*, 'productivity level of z7', zawel
print*, 'productivity level of z8', zaweh
print*, 'saving return rate of r1', RMIN
print*, 'saving return rate of r2', RMAX
print*, 'saving return rate of r3', RAWE
print*, 'probability of staying at r1', p11_r
print*, 'probability of staying at r2', p22_r
print*, 'probability of staying at r3', p33_r
print*, 'inflow rates to top return by productivity level z', prawe
print*, 'intergenerational correlations in return', intergen_corr_return
print*, 'probability of getting into r3 relative to ordinary productivity states conditional on z7', relpawein3
print*, 'probability of getting into r3 relative to ordinary productivity states conditional on z8', relpawein4
print*, 'coefficient of bequest utility (phi1)', bcoeff
print*, 'coefficient of bequest utility (phi2)', bcoeff2
print*, 'utility discount factor', BETA_ANNUAL
print*, 'tax progressivity parameter', tau_l
print*, 'Corporate asset threshold', d_c
print*, 'government expenditure to GDP ratio', gov




!***************** Bequest probability and size by age group*******************************
	ALLOCATE(beqgroup(MAXAGE),beqprob(MAXAGE))
!	Bequest receive for each age group
		beqgroup =  (/ 0.0, 0.288901, 0.55499, 0.776459, 1.034036, 1.159336, 1.290013, 1.306028, 1.270707, 1.161179, 1.000182, 0.81669, 0.778253, 0.0, 0.0, 0.0 /)
!	probability of receiving for each age group
		beqprob = (/ 0.0, 0.07638629, 0.080982576, 0.084117737, 0.093291232, 0.101364365, 0.109040602, 0.113135531, 0.111420932, 0.101507542, 0.083177941, 0.057655327, 0.046117922, 0.0, 0.0, 0.0 /)
	

! change beta from annual to 5 years	
	BETA = BETA_ANNUAL**5.00  

!***************** Save Table C.3 parameters*******************************
OPEN(UNIT=11,FILE='TableC3.txt')
WRITE(11,"(2(I12,1X), 10(F12.4,1X))") MAXAGE, RETAGE, c0, c1, c2, sigma, THETA, DEP_ANNUAL, tau_c, tau_s, flat_transf_rate
CLOSE(UNIT=11)

!***************** Save Table C.4 parameters*******************************
OPEN(UNIT=11,FILE='TableC4.txt')
WRITE(11,"(12(F12.4,1X))") BETA_ANNUAL, ALPHA, tau_l, PIA_factor, bcoeff, bcoeff2, bsigma, chi, d_c, gov, ability_persistence, intergen_corr_return
CLOSE(UNIT=11)

    !*****************Compute the age shares and sur. prob.****************************************

   	 	ALLOCATE(S(MAXAGE), CUMS(MAXAGE), MU(MAXAGE))

   	 	DO AGE=1,MAXAGE 	 	         
   	 	   S(AGE) = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))    ! quadratic form of sur. prob. as a fn of age
   	    END DO 
   	 	S(MAXAGE) = 0.0

   	 !  Unconditional survival probabilities
   	     CUMS(1) = 1.000
   	     DO J=2,MAXAGE
   	         CUMS(J) = CUMS(J-1)*S(J-1)
   	     END DO

   	 !  Age distribution of total population
   	     CUM = 0.0
   	     DO AGE=1,MAXAGE
   	         CUM = CUM + CUMS(AGE)
   	     END DO

   	     MU(1) = 1.0/CUM
   	 	SUM1=MU(1)
   	     DO AGE=2,MAXAGE
   	         MU(AGE) = S(AGE-1)*MU(AGE-1)
   	 	    SUM1 = SUM1 + MU(AGE)
   	     END DO
   		
		 
   	 !	Check the sum of age share is equal to one
   	 	IF (ABS(SUM1-1.000000)>0.000001) THEN
   	         PRINT*, 'The sum of age share for the total population is not equal to one at age!'
   	 !		GO TO 999
   	 	END IF	
	 
   	 !  Age distribution of working age population

   	 	ALLOCATE ( CUMSWK(RETAGE-1), MUWK(RETAGE-1) )

   	     CUMSWK(1) = 1.000
   	     DO J=2,RETAGE-1
   	         CUMSWK(J) = CUMSWK(J-1)*S(J-1)
   	     END DO
   
    
   	     CUMWK = 0.0
   	     DO AGE=1,RETAGE-1
   	         CUMWK = CUMWK + CUMSWK(AGE)
   	     END DO
   
    
   	     MUWK(1) = 1.0/CUMWK
   	 	SUMWK   = MUWK(1)
   	     DO AGE=2,RETAGE-1
   	         MUWK(AGE) = S(AGE-1)*MUWK(AGE-1)
   	 	    SUMWK = SUMWK + MUWK(AGE)
   	     END DO

		IF (ABS(SUMWK-1.000000)>0.000001) THEN
			PRINT*, 'The sum of age share for working age population is not equal to one at age!'
	!		GO TO 999
		END IF	
	
	lambda_out = (1.0-lambda_ll-lambda_lh)/(nn-2.0)
	lambda_hl = 1.0-lambda_hh


!***********************
!	Income Process
!***********************

! 5 year transition matrix of "ordinary+awesome" idiosyncratic productivity shock
P(1,:) = [real(prec) :: 0.876185683128328*(1.0-lambda_in), 0.119724446599436*(1.0-lambda_in), 0.004089870272236*(1.0-lambda_in), 0.00000,  0.00000,  0.00000,  lambda_in,  0.00000]
P(2,:) = [real(prec) :: 0.059862223299718*(1.0-lambda_in), 0.880275553400565*(1.0-lambda_in), 0.059862223299718*(1.0-lambda_in), 0.00000,  0.00000,  0.00000,  lambda_in,  0.00000]
P(3,:) = [real(prec) :: 0.004089870272236*(1.0-lambda_in), 0.119724446599436*(1.0-lambda_in), 0.876185683128329*(1.0-lambda_in), 0.00000,  0.00000,  0.00000,  lambda_in,  0.00000]
P(4,:) = [real(prec) :: 0.00000, 0.00000, 0.00000, 0.876185683128328*(1.0-lambda_in), 0.119724446599436*(1.0-lambda_in), 0.004089870272236*(1.0-lambda_in), lambda_in, 0.00000]
P(5,:) = [real(prec) :: 0.00000, 0.00000, 0.00000, 0.059862223299718*(1.0-lambda_in), 0.880275553400565*(1.0-lambda_in), 0.059862223299718*(1.0-lambda_in), lambda_in, 0.00000]
P(6,:) = [real(prec) :: 0.00000, 0.00000, 0.00000, 0.004089870272236*(1.0-lambda_in), 0.119724446599436*(1.0-lambda_in), 0.876185683128329*(1.0-lambda_in), lambda_in, 0.00000]
P(7,:) = [real(prec) :: lambda_out, lambda_out, lambda_out, lambda_out,  lambda_out,   lambda_out, lambda_ll, lambda_lh]
P(8,:) = [real(prec) :: 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, lambda_hl, lambda_hh]

! Productivity values:
basicz(1) = -1.340226159773844
basicz(2) = -0.622001125400911
basicz(3) = 0.096223908972021
basicz(4) = -0.096223908972021
basicz(5) = 0.622001125400911
basicz(6) = 1.340226159773844
basicz(7) = log(zawel)
basicz(8) = log(zaweh)

z(:) = basicz(:)
z(:) = exp(z(:))/exp(z(1))	! normalization
w(:) = z(:)		


! Initial productivity type distribution (unconditional)
	invar(1) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)
	invar(2) = 0.824/(0.088+0.824+0.088+0.088+0.824+0.088)
	invar(3) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)
	invar(4) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)
	invar(5) = 0.824/(0.088+0.824+0.088+0.088+0.824+0.088)
	invar(6) = 0.088/(0.088+0.824+0.088+0.088+0.824+0.088)
	invar(7) = 0.0
	invar(8) = 0.0


! Calculate the stationary probabilities for productivity matrix. 
	probmul_P = P
	DO i=1,5000
     probmul_P=MATMUL(probmul_P,P)
	END DO
	SSprob_z = probmul_P; 

	OPEN(UNIT=11,FILE='z_process.txt')
	WRITE(11,*) 'z states'
	WRITE(11,"(12(F12.4,1X))") w

	WRITE(11,*)
	WRITE(11,*) 'Transitional productivity matrix='
	write(11,"(11(F8.5,1X))") P(1,1), P(1,2), P(1,3), P(1,4), P(1,5), P(1,6), P(1,7), P(1,8)
	write(11,"(11(F8.5,1X))") P(2,1), P(2,2), P(2,3), P(2,4), P(2,5), P(2,6), P(2,7), P(2,8)
	write(11,"(11(F8.5,1X))") P(3,1), P(3,2), P(3,3), P(3,4), P(3,5), P(3,6), P(3,7), P(3,8)
	write(11,"(11(F8.5,1X))") P(4,1), P(4,2), P(4,3), P(4,4), P(4,5), P(4,6), P(4,7), P(4,8)
	write(11,"(11(F8.5,1X))") P(5,1), P(5,2), P(5,3), P(5,4), P(5,5), P(5,6), P(5,7), P(5,8)
	write(11,"(11(F8.5,1X))") P(6,1), P(6,2), P(6,3), P(6,4), P(6,5), P(6,6), P(6,7), P(6,8)
	write(11,"(11(F8.5,1X))") P(7,1), P(7,2), P(7,3), P(7,4), P(7,5), P(7,6), P(7,7), P(7,8)
	write(11,"(11(F8.5,1X))") P(8,1), P(8,2), P(8,3), P(8,4), P(8,5), P(8,6), P(8,7), P(8,8)
	
	WRITE(11,*)
	WRITE(11,*) 'Steady State Probabilities'
	write(11,"(11(F8.5,1X))") SSprob_z(1,:)	
	
	WRITE(11,*)
	WRITE(11,*) 'Initial distribution'
	write(11,"(11(F8.5,1X))") invar(:)	
	

	! Calculate actual distribution of z by age:
	mu_z_age(1,:) = invar
	DO iage = 2,RETAGE-1
		mu_z_age(iage,:) = MATMUL(mu_z_age(iage-1,:),P)
	END DO
	DO iage = RETAGE,MAXAGE
		mu_z_age(iage,:) = mu_z_age(iage-1,:)
	END DO

	! average over age:
	mu_z = MATMUL(RESHAPE(MU, (/1,MAXAGE/)),mu_z_age)

	! average over working age:
	mu_z_working_age = mu_z_age(1:RETAGE-1,:)
	mu_z_working = MATMUL(RESHAPE(MUWK, (/1,RETAGE-1/)),mu_z_working_age)

	WRITE(11,*)
	WRITE(11,*) 'Population shares'
	write(11,"(11(F8.5,1X))") mu_z(1,:)	
	CLOSE(UNIT=11)


!*****************************************
! Heterogenous rate of return in wealth
!*****************************************
	Allocate( R(NGRIDR),R_ANNUAL(NGRIDR) )
	R_ANNUAL = (/rmin,rmax,rawe/)
	R = (/ ((1+R_ANNUAL(i))**5.00-1.00, i=1,NGRIDR) /)

! 	Different inflow rates to top return by z:
	pawein = prawe * (1.-p33_r)/(1.-prawe) / &
		(1. * sum(mu_z(1,1:3))  + relpawein2 * sum(mu_z(1,4:6)) + &
		relpawein3 * mu_z(1,7) + relpawein4 * mu_z(1,8))
	pawein2 = 1.0 * pawein
	pawein3 = relpawein3 * pawein
	pawein4 = relpawein4 * pawein
	
	
	P_r(:,:,1) = RESHAPE( (/p11_r, 1.-p22_r-pawein, 0.0D0, 1.-p11_r-pawein, p22_r, 1.-p33_r, pawein, pawein, p33_r /), (/3,3/) )
	P_r(:,:,2) = RESHAPE( (/p11_r, 1.-p22_r-pawein2, 0.0D0, 1.-p11_r-pawein2, p22_r, 1.-p33_r, pawein2, pawein2, p33_r /), (/3,3/) )
	P_r(:,:,3) = RESHAPE( (/p11_r, 1.-p22_r-pawein3, 0.0D0, 1.-p11_r-pawein3, p22_r, 1.-p33_r, pawein3, pawein3, p33_r /), (/3,3/) )
	P_r(:,:,4) = RESHAPE( (/p11_r, 1.-p22_r-pawein4, 0.0D0, 1.-p11_r-pawein4, p22_r, 1.-p33_r, pawein4, pawein4, p33_r /), (/3,3/) )
	
! Calculate the stationary probabilities. 
! this is only used to set the starting distribution of r_low vs r_high
! we assume that pawein is the same for all regular z states.

	probmul = P_r(:,:,1)
	DO i=1,1000
     probmul=MATMUL(probmul,P_r(:,:,1))
	END DO
	SSprob_r = probmul; 

	
	! Calculate actual distribution of r by age
	DO IS=1,nn
		DO IR=1,2
			mu_r_z_age(1,IR,IS) = invar(IS)*SSprob_r(1,IR)
		END DO 
	END DO 
	mu_r_z_age(1,3,:) = 0.0
	mu_r_z_age(1,:,:) = mu_r_z_age(1,:,:)/(SSprob_r(1,1)+SSprob_r(1,2))

	DO iage = 2,RETAGE-1
		DO IS=1,nn
			mu_r_z_age(iage,:,IS) = MATMUL(mu_r_z_age(iage-1,:,IS),P_r(:,:,zgroup(IS)))
		END DO 
		DO IR=1,NGRIDR
			mu_r_z_age(iage,IR,:) = MATMUL(mu_r_z_age(iage,IR,:),P)
		END DO 
	END DO 

	DO iage=RETAGE,MAXAGE
		DO IS=1,nn
			mu_r_z_age(iage,:,IS) = MATMUL(mu_r_z_age(iage-1,:,IS),P_r(:,:,zgroup(IS)))
		END DO  
	END DO
	
	print*, ' '

	! aggregate distribution of r over z
	DO iage=1,MAXAGE
		DO IR=1,NGRIDR
			mu_r_age(iage,IR) = SUM(mu_r_z_age(iage,IR,:))
		END DO 
	END DO 

	! average over age:
	mu_r = MATMUL(RESHAPE(MU, (/1,MAXAGE/)),mu_r_age)

	OPEN(UNIT=11,FILE='r_process.txt')
	WRITE(11,*) 'r states'
	WRITE(11,"(12(F12.4,1X))") R

	WRITE(11,*)
	WRITE(11,*) 'Return transition matrix, non-top elements'
	WRITE(11,"(12(F12.5,1X))") p11_r, 1.-p11_r, 1.-p22_r, p22_r, 0.0D0, 1.-p33_r, p33_r
	
	WRITE(11,*)
	WRITE(11,*) 'Probability of entering top return state'
	WRITE(11,"(12(F12.6,1X))") pawein, pawein3, pawein4

	WRITE(11,*)
	WRITE(11,*) 'Population shares'
	write(11,"(11(F8.5,1X))") mu_r(1,:)	
	CLOSE(UNIT=11)
!*******************************************
!  Tabulate state and control variables
!*******************************************

! Tabulate asset levels	
! log-linear, with unequal spacing.

ALLOCATE( A(NGRIDA) ) 	
A = (/ ( exp(log(AMIN) + (log(AMAX)-log(AMIN))*(FLOAT(IA-1)/FLOAT(NGRIDA-1)) ), IA=1,NGRIDA ) /)
A(1) = 0.0000001

ASWITCH1 = FLOOR(.8*NGRIDA)
ASWITCH2 = NGRIDA-48
A(ASWITCH1+1:ASWITCH2) = (/ (exp(log(A(ASWITCH1)) + IA * (log(AMAX)-log(A(ASWITCH1)))/(ASWITCH2-ASWITCH1)), IA=1,ASWITCH2-ASWITCH1 ) /)
A(ASWITCH2+1:NGRIDA) = (/ (AMAX * (1+R(NGRIDR))**(0.25*FLOAT(IA)), IA = 1,48) /)

! log-linear zero asset index
	ZEROINDEX =	INT(abs(exp( log(AMIN)/(log(AMAX)-log(AMIN))/FLOAT(NGRIDA-1) ) + 1.000))

    
!   Tabulate working hours ratio level

    ALLOCATE( N(NGRIDA) )
	
	N = (/ ( 1.0*((FLOAT(IN-1))/FLOAT(NGRIDA-1)**1.000), IN=1,NGRIDA ) /)	! default: linear
	
	statecount = 0
	do AGE = 1,MAXAGE
		do IA = 1,NGRIDA
			do IR = 1,NGRIDR
				do IS = 1,nn
					statecount = statecount+1
					statecodes(AGE,IA,IR,IS) = statecount			
				end do	
			end do			
		end do		
	end do

!*********************
!
!   Preliminary Calculations
!
!*********************
  
	BEQ     = 0.0
	lambda1 = lambdamin
	lambda2 = lambdamax
	lambda = 0.5*lambda1 + 0.5*lambda2

	
SELECT CASE (compute_eqm)
	CASE (1) 

	CALL system_clock(count_rate=rate)
    CALL CPU_TIME(t0)
	call SYSTEM_CLOCK(iTimes1)

	print*, '============================='
    PRINT*, 'Begin the Program. Please Wait!'
	print*, '============================='
	print*, ''
!**********************************
! 	Solve the General Equilibrium
!**********************************

LOOPNUMBER = 0
KDEV = 1.0 
WAGE = 1.0  			! Initial guess of wage
Aggincome = 2.0			! Initial guess of income
beqtax_exempt = 35.0	! Initial guess of exempt

DO WHILE ( KDEV > TOLK) ! betaloop

! Initial guess of transition matrix
ALLOCATE( X45_lowkid_dist(MAXAGE,NGRIDA,NGRIDA,2) )
ALLOCATE( X45_highkid_dist(MAXAGE,NGRIDA,NGRIDA,2) )

X45_highkid_dist(:,:,:,:)=0.0
X45_lowkid_dist(:,:,:,:)=0.0

DO AGE=1,MAXAGE
	do i = 1,NGRIDA	
			X45_highkid_dist(AGE,i,i,:) = 1.0
			X45_lowkid_dist(AGE,i,i,:) = 1.0	
	end do
END DO 
 
DO AGE=1,MAXAGE
	Do j=1,2
		Do i=1,NGRIDA
			if(abs(1.0 - sum(X45_highkid_dist(AGE,i,:,j))) > 0.0001) then
				print*, ' Warning the sum of transition matrix row not equal to 1'
			end if 
			if(abs(1.0 - sum(X45_lowkid_dist(AGE,i,:,j))) > 0.0001) then
				print*, ' Warning the sum of transition matrix row not equal to 1'
			end if 
		end do
	end do
END DO   

BEQTRANS1 = 0.0
gov_trans = 0.0
medicare = 0.0
incsscap = incsscap_data/avg_monthly_earnings ! maximum pension income level
lambda1 = lambdamin
lambda2 = lambdamax
lambda = 0.5*lambda1 + 0.5*lambda2
dlam = 1.0	

!   Update Tabulation of AIME
SSGRIDMAX	= SSGRIDMAX_data*Aggincome	! avg_earnings is updated every iteration
EH(:) = 0.0
DO IS=1,nn 
	SS(IS) = PIA_factor*Aggincome*MIN(incsscap, ssmin+rr1*MAX(0.0, MIN(EH(IS)/Aggincome, bend1)) + rr2* MAX(0.0, MIN(EH(IS)/Aggincome-bend1,bend2-bend1)) + rr3*MAX(0.0, EH(IS)/Aggincome-bend2))
END DO 


!**************************
!  Iterate to Convergence
!**************************

    ITER = 1
	LOOPNUMBER = LOOPNUMBER +1

    WRITE(10,*) 'ITERATION RESULTS'
    WRITE(10,*)
200 ITERINC = 0

! Compute income bend point for top marginal tax rate given lambda:
bendy=((1.0-tau_l)*lambda/(1.0-ty_max))**(1.0/tau_l)                                                                                                             

!**************************
!   Main Calculations
!**************************

call cpu_time (fstart)
ostart = omp_get_wtime()	

	ALLOCATE( IDCWA(1:RETAGE-1,NGRIDA,NGRIDR,nn) ) 
    ALLOCATE( IDCWN(1:RETAGE-1,NGRIDA,NGRIDR,nn) )
    ALLOCATE( IDCRA(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
    ALLOCATE( IDCRN(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
    ALLOCATE( VW(1:RETAGE-1,NGRIDA,NGRIDR,nn), VR(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
	ALLOCATE( OLD_IDCWA(1:RETAGE-1,NGRIDA,NGRIDR,nn) ) 
    ALLOCATE( OLD_IDCWN(1:RETAGE-1,NGRIDA,NGRIDR,nn) )

	print*, "Solving Policy functions:"   
	CALL DECRULE01        ! solve the policy functions             
	print*, "done."
	call cpu_time (fend)                    
	oend = omp_get_wtime()
	! write(*,*) 'Time for solving policy functions', oend-ostart

	ALLOCATE( YW(1:RETAGE-1,NGRIDA,NGRIDR,nn), YR(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
	print*, "Computing distributions:"  
    CALL INVAR01	!   Find invariant distribution
	print*, "done."

	print*, "Computing age-weighted distributions:" 
	CALL compute_distributions		!   Compute age-weighted distribution
	print*, "done."



	ALLOCATE( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE),  NCROSS(MAXAGE), LCROSS(MAXAGE), BCROSS(MAXAGE))
	ALLOCATE( ALONG(MAXAGE), CLONG(MAXAGE), ILONG(MAXAGE), TILONG(MAXAGE) )
	ALLOCATE(  NLONG(MAXAGE), LLONG(MAXAGE), BLONG(MAXAGE) )
   
   print*, "Computing age profiles:"
    CALL PROFILE01			!   Compute age profiles
	print*, "done."

	print*, "Computing bequest distribution:"
	CALL beq_distribution	!   Compute bequest distribution
	print*, "done."


!   Compute aggregate assets, labor supply, bequests
	 
	CUM    = 0.0
	AEND   = 0.0
	LEND   = 0.0
	LSSEND = 0.0
    BEQEND = 0.0  ! Agg Bequest

	
    CUM1  = 0.00
    DO AGE=1,RETAGE-1
	    CUM1   = CUM1   + MU(AGE)
        AEND   = AEND   + ACROSS(AGE)*MU(AGE)
		LEND   = LEND   + EFFCROSS(AGE)*NCROSS(AGE)*MUWK(AGE)
	    LSSEND = LSSEND + EFFCROSS(AGE)*NCROSS(AGE)
		BEQEND = BEQEND + BCROSS(AGE)*MU(AGE)*(1.0-S(AGE))
    END DO

    CUM2 = 0.0
    DO AGE=RETAGE,MAXAGE                        
        CUM2   = CUM2   + MU(AGE)
	    AEND   = AEND   + ACROSS(AGE)*MU(AGE)
		BEQEND = BEQEND + BCROSS(AGE)*MU(AGE)*(1.0-S(AGE))
    END DO

	
!	Output
	OUTPUT = TFP*(AEND**ALPHA)*(LEND**(1-ALPHA))

!****************************************** 

! update some variables

!******************************************

!	Update Social Security Expense
SSEXP=0.0 	! SS expenditure
DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IR=1,NGRIDR
			DO IS=1,nn

			SSEXP = SSEXP + SS(IS)*YR(AGE,IA,IR,IS)*MU(AGE)

			END DO 
		END DO 
	END DO 
END DO 


!	Update govern flat transfer
	gov_trans = flat_transf_rate*OUTPUT/(CUM1+CUM2)

!  Update medicare (only for elderly)
	medicare = medicare_rate*OUTPUT/CUM2


!****************************************** 

! 		Government Budget Balance

!****************************************** 


print*, '******************* Start Government Budget Balance *******************			'

gbcdenom = 0.0
gbcnum = 0.0
cor_tax_rev = 0.0
sales_tax_rev = 0.0
beq_tax_rev = 0.0

DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
		DO IR=1,NGRIDR
        	DO IS=1,nn
			 
		  	JN = IDCWN(AGE,IA,IR,IS)
			JA = IDCWA(AGE,IA,IR,IS)

! gbcdenom = \int y^{1-\tau}
			temp = (MIN(bendy,min(R(IR)*A(IA),d_c)+WAGE*EFFLONG(AGE)*N(JN)*W(IS)))**(1.0-tau_l)
			gbcdenom = gbcdenom + temp*YW(AGE,IA,IR,IS)*MU(AGE)

! gbcnum = other tax revenue + Taxable income - top aftertax income
			temp2 = min(R(IR)*A(IA),d_c)+WAGE*EFFLONG(AGE)*N(JN)*W(IS) & 
					- (1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGE*EFFLONG(AGE)*N(JN)*W(IS) - bendy) 
			temp_ctaxrev = tau_c*max(R(IR)*A(IA)-d_c,0.0)

			temp_cons = ( lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGE*EFFLONG(AGE)*N(JN)*W(IS)))**(1.0-tau_l) &
						+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGE*EFFLONG(AGE)*N(JN)*W(IS) - bendy) &
						+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) &
						+ BEQTRANS1 + gov_trans + A(IA) - A(JA) )/(1.0+tau_s)
						
			temp_staxrev = tau_s*temp_cons

			temp_btaxrev = A(JA) - beq_aftertax(A(JA)) - beqtax_rate1*MIN(A(JA), beqtax_exempt)
			
			gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*YW(AGE,IA,IR,IS)*MU(AGE) + temp_btaxrev*YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE)) !T + taxable income - top aftertax income
			cor_tax_rev = cor_tax_rev+temp_ctaxrev*YW(AGE,IA,IR,IS)*MU(AGE)
			sales_tax_rev = sales_tax_rev + temp_staxrev*YW(AGE,IA,IR,IS)*MU(AGE)

			beq_tax_rev = beq_tax_rev + temp_btaxrev*YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))

			END DO
        END DO 
    END DO
END DO	

DO AGE = RETAGE,MAXAGE   
    DO IA = 1,NGRIDA
		DO IR = 1,NGRIDR
			DO IS=1,nn

			JA = IDCRA(AGE,IA,IR,IS)		

! gbcdenom = \int y^{1-\tau}
			temp = (MIN(bendy,min(R(IR)*A(IA),d_c)+SS(IS) ))**(1.0-tau_l)
			gbcdenom = gbcdenom + temp*YR(AGE,IA,IR,IS)*MU(AGE)

! gbcnum = Taxable income + other taxes - top aftertax income
			temp2 = min(R(IR)*A(IA),d_c)+SS(IS) & 
					- (1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+SS(IS) - bendy) 
			temp_ctaxrev = tau_c*max(R(IR)*A(IA)-d_c,0.0)

			temp_cons = ( lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + SS(IS)))**(1.0-tau_l) &
						+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+SS(IS) - bendy) &
						+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) &
						+ A(IA) +  medicare + gov_trans - A(JA) )/(1.0+tau_s) 
			temp_staxrev = tau_s*temp_cons

			temp_btaxrev = A(JA) - beq_aftertax(A(JA)) - beqtax_rate1*MIN(A(JA), beqtax_exempt)

			gbcnum = gbcnum + (temp2 + temp_ctaxrev + temp_staxrev)*YR(AGE,IA,IR,IS)*MU(AGE) + temp_btaxrev*YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))
			cor_tax_rev = cor_tax_rev+temp_ctaxrev*YR(AGE,IA,IR,IS)*MU(AGE)
			sales_tax_rev = sales_tax_rev + temp_staxrev*YR(AGE,IA,IR,IS)*MU(AGE)

			beq_tax_rev = beq_tax_rev + temp_btaxrev*YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))
		

			END DO
		END DO
    END DO
END DO

lambda_implied = (gbcnum-SSEXP-gov*OUTPUT-flat_transf_rate*OUTPUT-medicare_rate*OUTPUT)/gbcdenom



! update bequest transfer and pension income

	BEQ1 = BEQEND/CUM1
	BEQTRANS1 = BEQTRANS/CUM1 

ALLOCATE( working_dist(RETAGE-1,NGRIDA,NGRIDR,nn) )
DO AGE = 1,RETAGE-1		
    DO IA = 1,NGRIDA            
		DO IR = 1,NGRIDR
            DO IS = 1,nn                                                                                                                                                      
                    
				working_dist(AGE,IA,IR,IS) = YW(AGE,IA,IR,IS)*MU(AGE)	

			END DO
        END DO
    END DO
END DO	

Aggincome = 0.0
EH(:)=0.0
DO AGE=1,RETAGE-1
	DO IA=1,NGRIDA
		DO IR=1,NGRIDR
        	DO IS=1,nn
				
				JN = IDCWN(AGE,IA,IR,IS)				
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS) 	

				EH(IS) = EH(IS) + INCOME*working_dist(AGE,IA,IR,IS)/SUM(working_dist(:,:,:,IS))	
				Aggincome = Aggincome + INCOME*working_dist(AGE,IA,IR,IS)/SUM(working_dist(:,:,:,:))

			END DO
        END DO
    END DO
END DO

SSGRIDMAX	= SSGRIDMAX_data*Aggincome


DO IS=1,nn
	SS(IS) = PIA_factor*Aggincome*MIN(incsscap, ssmin+rr1*MAX(0.0, MIN(EH(IS)/Aggincome, bend1)) + rr2* MAX(0.0, MIN(EH(IS)/Aggincome-bend1,bend2-bend1)) + rr3*MAX(0.0, EH(IS)/Aggincome-bend2))
END DO

print*, 'Aggincome=',Aggincome



	dev_beq_tran_mat1 = MAXVAL( abs(X45_lowkid_dist1(:,:,:,:)-X45_lowkid_dist(:,:,:,:)) )
	dev_beq_tran_mat2 = MAXVAL( abs(X45_highkid_dist1(:,:,:,:)-X45_highkid_dist(:,:,:,:)) )
	dlam = abs(lambda_implied - lambda)

	PRINT*,''
    WRITE(10,*) 'Iteration', ITER
    PRINT *, 'Iteration', ITER, '(lambda),', LOOPNUMBER, '(beta)'	
    PRINT*,'--------------------------------------------------------------------' 		
	PRINT*, 'Deviation of bequest transition matrix1=', dev_beq_tran_mat1
	PRINT*, 'Deviation of bequest transition matrix2=', dev_beq_tran_mat2
	PRINT *, ''
	PRINT*, 'lambda=', lambda
	PRINT*, 'lambda_implied=', lambda_implied
	PRINT *, 'Relative change in lambda =', dlam
    PRINT*,'-------------------------------------------------------------------' 
	PRINT *, 'Repeat the process with updated lambda and bequest distribution'
	print*,''
    WRITE(10,*)
    


	IF ( (dev_beq_tran_mat2>TOLB) .OR.	(dev_beq_tran_mat1>TOLB) .OR.  (dlam>tol_lam) ) THEN

	    X45_highkid_dist(:,:,:,:)	=	X45_highkid_dist1(:,:,:,:)
		X45_lowkid_dist(:,:,:,:)	=	X45_lowkid_dist1(:,:,:,:)
	
	! UPDATE lambda
        lambdaold = lambda

	! UPDATE lambda 2
		lambda = (1 - GRADLAMBDA)*lambda + GRADLAMBDA*lambda_implied
 
        ITERINC = 1
    END IF

	IF (ITERINC>0) THEN

        ITER = ITER + ITERINC

        IF (ITER>MAXITER) THEN
            PRINT *, 'Maximum number of iterations exceeded.'
            PRINT *, 'Program terminates.'
            WRITE(10,*) 'Maximum number of iterations exceeded.'
            WRITE(10,*) 'Program terminates.'
            GO TO 599
        END IF
		
		DEALLOCATE(IDCWA,OLD_IDCWA, IDCWN, OLD_IDCWN, VW, YW, IDCRA, IDCRN,  VR, YR, working_dist)
        DEALLOCATE(ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, LLONG, BCROSS, BLONG)
		DEALLOCATE(parentbeq_basket,beq_dist,X45_lowkid_dist1,X45_highkid_dist1,X45_lowparent_dist,X45_highparent_dist)
		DEALLOCATE(D_YW,D_YR)
        GO TO 200		
    END IF

599 continue
	
!**********************************************************
!  Calculate the Wealth Distribution and aggregate wealth
!**********************************************************

AggWealth = 0.0
DO AGE=1,RETAGE-1
        DO IA=1,NGRIDA
		    DO IR=1,NGRIDR
			  DO IS=1,nn 
				 AggWealth = AggWealth+D_YW(AGE,IA,IR,IS)*A(IA)
			  END DO
           END DO
        END DO
    END DO

	DO AGE=RETAGE,MAXAGE
        DO IA=1,NGRIDA          
		   DO IR=1,NGRIDR
              DO IS=1,nn 
			  	 AggWealth = AggWealth+D_YR(AGE,IA,IR,IS)*A(IA)
			  END DO
           END DO
        END DO
    END DO
	
!***************************************************************************************************************
!  Calculate the mean,SD of return in wealth of top wealth share, in the aggregate and by income, wealth group
!***************************************************************************************************************		  

print*, "avg_return:"
	ostart = omp_get_wtime()  
	  CALL avg_return       			 ! compute the average return and asset-weighted average return
	oend = omp_get_wtime()
 print*, "Done, after ", oend-ostart, "seconds."

!*************************************
!  Calculate the Bequest Moment 
!*************************************	

print*, "Computing top 2% bequest tax exemption level:"	
	ostart = omp_get_wtime()  
	  CALL bequest_exemption			  ! Compute top 2% bequest tax exemption level
	oend = omp_get_wtime()
print*, "Done, after ", oend-ostart, "seconds."

!************************************************************************************

! Asset demand
    KD = LEND*(ALPHA*TFP/( ((1+Avg_R_weighted)**5.0-1.0) + DEP))**(1/(1-ALPHA))
    KDEV = abs(KD-Aggwealth)	

print*, '==================Convergent result=================='
print*, 'capital demand=',KD
print*, 'capital supply=', Aggwealth
print*, 'Annual Avg return from the process=', Avg_R
print*, 'Annual Weighted return =', Avg_R_weighted
print*, 'wage=', WAGE
print*, 'K Deviation=',KDEV
print*, '====================================================='

IF (KDEV > TOLK) THEN


		! bisection on r
		r_implied = (1.0 + (ALPHA*TFP) * (Aggwealth/LEND)**(ALPHA-1.0) - DEP)**0.2 - 1.0
		print*, 'r_in, r_implied', Avg_R_weighted, r_implied
		IF (LOOPNUMBER==1) THEN
			r1 = Avg_R_weighted-0.005
			r2 = Avg_R_weighted+0.005
		END IF
		print*, 'old r1, r2: ', r1, r2
		IF (LOOPNUMBER>1) THEN
			IF ( r_implied < Avg_R_weighted ) THEN
				r2 = 0.5*Avg_R_weighted+0.5*r2
			ELSE
				r1 = 0.5*Avg_R_weighted+0.5*r1
			END IF		
		END IF
		print*, 'new r1, r2: ', r1, r2
		IF ( r_implied < Avg_R_weighted ) THEN
			r_new = 0.5 * Avg_R_weighted + 0.5 * MAX(r_implied,r1)
		ELSE
			r_new = 0.5 * Avg_R_weighted + 0.5 * MIN(r_implied,r2)
		END IF
		delta_r = ABS(r_new-Avg_R_weighted)
		print*, 'delta_r=',delta_r

	      
		IF ( Aggwealth < KD ) THEN
			R(:)= ( 1.0+((1+R(:))**(0.2)-1 + delta_r) )**5.0 -1.00
			
		ELSEIF ( Aggwealth > KD ) THEN
			R(:)= ( 1.0+((1+R(:))**(0.2)-1 - delta_r) )**5.0 -1.00        
		END IF
		R(1) = MAX(R(1),0.0) ! prevent negative rL, which leads to trouble

	!  Update Wage rate
	WAGE = (1.0-ALPHA)*TFP*( (((1+Avg_R_weighted)**5.0-1.0)+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))	!wage= 5year MPL

	print*, ' ----------- update parameter ---------------'
	print*, 'new WAGE=', WAGE
	print*, 'new annual rL=',(1+R(1))**(0.2)-1
	print*, 'new annual rH',(1+R(2))**(0.2)-1
	print*, 'rH-rL =', (1+R(2))**(0.2) - (1+R(1))**(0.2)
	print*, '========================================================================='



	DEALLOCATE(IDCWA,OLD_IDCWA, IDCWN, OLD_IDCWN,VW, YW, IDCRA, IDCRN,  VR, YR, working_dist)
	DEALLOCATE(ACROSS, ALONG, CCROSS, CLONG, ICROSS, ILONG, TICROSS, TILONG,  NCROSS, NLONG, LCROSS, LLONG, BCROSS, BLONG)
	DEALLOCATE(D_YW,D_YR)  
	DEALLOCATE(X45_lowkid_dist,X45_highkid_dist)
	DEALLOCATE(parentbeq_basket,beq_dist,X45_lowkid_dist1,X45_highkid_dist1,X45_lowparent_dist,X45_highparent_dist)
	DEALLOCATE(sort_B_gross,sort_D_B_gross,cum_sort_D_B_gross,top2pct_D_B_gross,record_position_B_gross)

END IF 

END DO !	DO WHILE -- beta loop 

!*******************
!   Save results
!*******************

	OPEN(UNIT=27,FILE='eqm_outcomes.txt')
		write(27,*) WAGE, BETA, LAMBDA, SS(:), AEND, LEND, OUTPUT, Avg_R, Avg_R_weighted, xL, xLL, xLH, xHL, R(:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='IDCWA.txt')
		write(27,*) IDCWA(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='IDCWN.txt')
		write(27,*) IDCWN(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='IDCRA.txt')
		write(27,*) IDCRA(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='IDCRN.txt')
		write(27,*) IDCRN(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='VW.txt')
		write(27,*) VW(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='VR.txt')
		write(27,*) VR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='YW.txt')
		write(27,*) YW(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='YR.txt')
		write(27,*) YR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='D_YW.txt')
		write(27,*) D_YW(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='D_YR.txt')
		write(27,*) D_YR(:,:,:,:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='MU.txt')
		write(27,*) MU(:)
	CLOSE(27)

	OPEN(UNIT=27,FILE='Agrid.txt')
		write(27,*) A
	CLOSE(27)

	OPEN(UNIT=27,FILE='Ngrid.txt')
		write(27,*) N
	CLOSE(27)


CASE (0) ! import equilibrium outcomes

	CALL system_clock(count_rate=rate)
	CALL CPU_TIME(t0)
	call SYSTEM_CLOCK(iTimes1)
	PRINT*, 'Starting data import. Read:'

	ALLOCATE( X45_lowkid_dist(MAXAGE,NGRIDA,NGRIDA,2) )
	ALLOCATE( X45_highkid_dist(MAXAGE,NGRIDA,NGRIDA,2) )
	ALLOCATE( IDCWA(1:RETAGE-1,NGRIDA,NGRIDR,nn) ) 
    ALLOCATE( IDCWN(1:RETAGE-1,NGRIDA,NGRIDR,nn) )
    ALLOCATE( IDCRA(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
    ALLOCATE( IDCRN(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
    ALLOCATE( VW(1:RETAGE-1,NGRIDA,NGRIDR,nn), VR(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )	
	ALLOCATE( YW(1:RETAGE-1,NGRIDA,NGRIDR,nn), YR(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
	ALLOCATE( D_YW(MAXAGE,NGRIDA,NGRIDR,nn), D_YR(MAXAGE,NGRIDA,NGRIDR,nn) )

	! Eqm outcomes
	OPEN(UNIT=27,FILE='eqm_outcomes.txt')
		READ(27,*) WAGE, BETA, LAMBDA, SS(:), AEND, LEND, OUTPUT, Avg_R, Avg_R_weighted, xL, xLL, xLH, xHL
	CLOSE(27)	
	xH = 1.-xL
	xHH = 1.0-xLL-xLH-xHL
	
	! (parent r, kid r, parent z, kid z)
	pdf_parent_kid(1,1,1,1) = intergen_corr_return*ability_persistence*xLL				!the probability that the parents are (low z,low r) and kid are (low z, low r)
	pdf_parent_kid(2,1,1,1) = (1.0-intergen_corr_return)*ability_persistence*xHL		!the probability that the parents are (low z,high r) and kid are (low z, low r)
	pdf_parent_kid(1,1,2,1) = intergen_corr_return*(1.0-ability_persistence)*xLH		!the probability that the parents are (high z,low r) and kid are (low z,low r)
	pdf_parent_kid(2,1,2,1) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHH	!the probability that the parents are (high z,high r) and kid are (low z,low r)
	pdf_parent_kid(:,1,:,1) = pdf_parent_kid(:,1,:,1)/(intergen_corr_return*ability_persistence*xLL + (1.0-intergen_corr_return)*ability_persistence*xHL + intergen_corr_return*(1.0-ability_persistence)*xLH + (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHH)

	! kids with high r, low z
	pdf_parent_kid(1,2,1,1) = (1.0-intergen_corr_return)*ability_persistence*xLL		!the probability that the parents are (low z,low r) and kid are (low z, high r)
	pdf_parent_kid(2,2,1,1) = intergen_corr_return*ability_persistence*xHL				!the probability that the parents are (low z,high r) and kid are (low z, high r)
	pdf_parent_kid(1,2,2,1) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xLH	!the probability that the parents are (high z,low r) and kid are (low z,high r)
	pdf_parent_kid(2,2,2,1) = intergen_corr_return*(1.0-ability_persistence)*xHH		!the probability that the parents are (high z,high r) and kid are (low z,high r)
	pdf_parent_kid(:,2,:,1) = pdf_parent_kid(:,2,:,1)/((1.0-intergen_corr_return)*ability_persistence*xLL + intergen_corr_return*ability_persistence*xHL + (1.0-intergen_corr_return)*(1.0-ability_persistence)*xLH + intergen_corr_return*(1.0-ability_persistence)*xHH)

	! kids with low r, high z
	pdf_parent_kid(1,1,1,2) = intergen_corr_return*(1.0-ability_persistence)*xLL		!the probability that the parents are (low z,low r) and kid are (high z, low r)
	pdf_parent_kid(2,1,1,2) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHL	!the probability that the parents are (low z,high r) and kid are (high z, low r)
	pdf_parent_kid(1,1,2,2) = intergen_corr_return*ability_persistence*xLH				!the probability that the parents are (high z,low r) and kid are (high z, low r)
	pdf_parent_kid(2,1,2,2) = (1.0-intergen_corr_return)*ability_persistence*xHH		!the probability that the parents are (high z,high r) and kid are (high z, low r)
	pdf_parent_kid(:,1,:,2) = pdf_parent_kid(:,1,:,2)/(intergen_corr_return*(1.0-ability_persistence)*xLL + (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHL + intergen_corr_return*ability_persistence*xLH + (1.0-intergen_corr_return)*ability_persistence*xHH)

	! kids with high r, high z
	pdf_parent_kid(1,2,1,2) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xLL	!the probability that the parents are (low z,low r) and kid are (high z, high r)
	pdf_parent_kid(2,2,1,2) = intergen_corr_return*(1.0-ability_persistence)*xHL		!the probability that the parents are (low z,high r) and kid are (high z, high r)

	pdf_parent_kid(1,2,2,2) = (1.0-intergen_corr_return)*ability_persistence*xLH		!the probability that the parents are (high z,low r) and kid are (high z, high r)
	pdf_parent_kid(2,2,2,2) = intergen_corr_return*ability_persistence*xHH				!the probability that the parents are (high z,high r) and kid are (high z, high r)
	pdf_parent_kid(:,2,:,2) = pdf_parent_kid(:,2,:,2)/((1.0-intergen_corr_return)*(1.0-ability_persistence)*xLL + intergen_corr_return*(1.0-ability_persistence)*xHL + (1.0-intergen_corr_return)*ability_persistence*xLH + intergen_corr_return*ability_persistence*xHH)
	
	print*, "pdf_parent_kid, fix parents:"
	print*, "parents low r, low z: ", pdf_parent_kid(1,:,1,:)
	print*, "parents low r, high z: ", pdf_parent_kid(1,:,2,:)
	print*, "parents high r, low z: ", pdf_parent_kid(2,:,1,:)
	print*, "parents high r, high z: ", pdf_parent_kid(2,:,2,:)
	
	print*, "pdf_parent_kid, fix kids:"
	print*, "kid low r, low z: ", pdf_parent_kid(:,1,:,1)
	print*, "kid low r, high z: ", pdf_parent_kid(:,1,:,2)
	print*, "kid high r, low z: ", pdf_parent_kid(:,2,:,1)
	print*, "kid high r, high z: ", pdf_parent_kid(:,2,:,2)
	
	! More eqm outcomes
     KD = LEND*(ALPHA*TFP/( ((1+Avg_R_weighted)**5.0-1.0) + DEP))**(1/(1-ALPHA))
	bendy=((1.0-tau_l)*lambda/(1.0-ty_max))**(1.0/tau_l)
	
	! Working age:
	ALLOCATE(read_vector((RETAGE-1)*NGRIDA*NGRIDR*nn))

	OPEN(UNIT=27,FILE='IDCWA.txt')
		READ(27,*) read_vector
	CLOSE(27)
	IDCWA = reshape(read_vector, (/ RETAGE-1, NGRIDA, NGRIDR, nn /))	
	print*, "IDCWA"
	
	OPEN(UNIT=27,FILE='IDCWN.txt')
		READ(27,*) read_vector
	CLOSE(27)
	IDCWN = reshape(read_vector, (/ RETAGE-1, NGRIDA, NGRIDR, nn /))	
	print*, "IDCWN"

	OPEN(UNIT=27,FILE='VW.txt')
		READ(27,*) read_vector
	CLOSE(27)
	VW = reshape(read_vector, (/ RETAGE-1, NGRIDA, NGRIDR, nn /))	
	print*, "VW"

	OPEN(UNIT=27,FILE='YW.txt')
		READ(27,*) read_vector
	CLOSE(27)
	YW = reshape(read_vector, (/ RETAGE-1, NGRIDA, NGRIDR, nn /))	
	print*, "YW"
	OPEN(UNIT=27,FILE='YW_out.txt')
		WRITE(27,*) YW(:,:,:,:)
	CLOSE(27)

	DEALLOCATE(read_vector)

	! Retirees:
	ALLOCATE(read_vector((MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn))

	OPEN(UNIT=27,FILE='IDCRA.txt')
		READ(27,*) read_vector
	CLOSE(27)
	IDCRA = reshape(read_vector, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDR, nn /))	
	print*, "IDCRA"

	OPEN(UNIT=27,FILE='IDCRN.txt')
		READ(27,*) read_vector
	CLOSE(27)
	IDCRN = reshape(read_vector, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDR, nn /))	
	print*, "IDCRN"

	OPEN(UNIT=27,FILE='VR.txt')
		READ(27,*) read_vector
	CLOSE(27)
	VR = reshape(read_vector, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDR, nn /))	
	print*, "VR"

	OPEN(UNIT=27,FILE='YR.txt')
		READ(27,*) read_vector
	CLOSE(27)
	YR = reshape(read_vector, (/ MAXAGE-RETAGE+1, NGRIDA, NGRIDR, nn /))	
	print*, "YR"
	
	DEALLOCATE(read_vector)

	! Distributions:
	ALLOCATE(read_vector(MAXAGE*NGRIDA*NGRIDR*nn))	
	
	OPEN(UNIT=27,FILE='D_YW.txt')
		READ(27,*) read_vector
	CLOSE(27)
	D_YW = reshape(read_vector, (/ MAXAGE, NGRIDA, NGRIDR, nn /))	
	print*, "D_YW"
	

	OPEN(UNIT=27,FILE='D_YR.txt')
		READ(27,*) read_vector
	CLOSE(27)
	D_YR = reshape(read_vector, (/ MAXAGE, NGRIDA, NGRIDR, nn /))	
	print*, "D_YR"
	
	DEALLOCATE(read_vector)

	print*, "Finished reading."
	
	! Compute a few aggregates from this
	SSEXP=0.0 	! SS expenditure
	DO AGE = RETAGE,MAXAGE   
	    DO IA = 1,NGRIDA
			DO IR=1,NGRIDR
				DO IS=1,nn

				SSEXP = SSEXP + SS(IS)*YR(AGE,IA,IR,IS)*MU(AGE)

				END DO 
			END DO 
		END DO 
	END DO 

END SELECT ! started before beta loop

!***********************************
!    Get longitudinal profiles
!***********************************  

IF (compute_eqm == 0) THEN       
	print*, "Get longitudinal profiles: "
		ostart = omp_get_wtime()	
 		 ALLOCATE( ACROSS(MAXAGE), CCROSS(MAXAGE), ICROSS(MAXAGE), TICROSS(MAXAGE),  NCROSS(MAXAGE), LCROSS(MAXAGE), BCROSS(MAXAGE))
		 ALLOCATE( ALONG(MAXAGE), CLONG(MAXAGE), ILONG(MAXAGE), TILONG(MAXAGE), BLONG(MAXAGE) )
	     ALLOCATE(  NLONG(MAXAGE), LLONG(MAXAGE) )
	     CALL PROFILE01
	
		 oend = omp_get_wtime()
	 print*, "Done, after ", oend-ostart, "seconds."
END IF 

!*************************************
!  Calculate the Wealth share holding
!*************************************  
      
	print*, "Computing wealthshare: "
		ostart = omp_get_wtime()	
	      CALL wealthshare
 		oend = omp_get_wtime()
    print*, "Done, after ", oend-ostart, "seconds."

!**********************
!   Calculate Ginis
!**********************

print*, "compute_gini: "
	ostart = omp_get_wtime()
     CALL compute_gini
	oend = omp_get_wtime()	
print*, "Done, after ", oend-ostart, "seconds."	

!********************************* 
!  Calculate the Age Wealth Gini
!********************************* 

print*, "compute age_wealth_gini: "
	ostart = omp_get_wtime()
     CALL age_wealth_gini
	oend = omp_get_wtime()	
print*, "Done, after ", oend-ostart, "seconds."	

!*********************************************
!  Calculate the labor income share holding
!*********************************************

print*, "compute wageshare: "
	ostart = omp_get_wtime()
	 CALL wageshare	
	oend = omp_get_wtime()	
print*, "Done, after ", oend-ostart, "seconds."	  
	  
!******************************************* 
!  Calculate the total income share holding
!******************************************* 

print*, "totalincomeshare: "
	ostart = omp_get_wtime()
	 CALL totalincomeshare
	oend = omp_get_wtime()	
print*, "Done, after ", oend-ostart, "seconds."	   

!*************************************
!  Calculate the Consumption holding
!************************************* 

print*, "consumptionshare: "
	ostart = omp_get_wtime()
	 CALL consumptionshare
	oend = omp_get_wtime()	
print*, "Done, after ", oend-ostart, "seconds."	   

!************************************************* 	
!  Calculate avg return by different wealth group
!*************************************************

print*, "Calculate avg return by different wealth group:"
	ostart = omp_get_wtime()	
	  CALL avg_return_wealthgroups
	 oend = omp_get_wtime()
 print*, "Done, after ", oend-ostart, "seconds."
DEALLOCATE(sort_D_R,indentify_R,sort_D_R_weighted)

!*************************************************
!  Calculate avg return by different income group
!*************************************************

print*, "Calculate avg return by different income group:"
	ostart = omp_get_wtime()	
	  CALL avg_return_incomegroups
	oend = omp_get_wtime()
 print*, "Done, after ", oend-ostart, "seconds."

!*************************************************************
!  Calculate the Skewness of wealth and earning distribution 
!*************************************************************	 

print*, "Computing skewness:"
	ostart = omp_get_wtime()
	  CALL skewness
	oend = omp_get_wtime()
print*, "Done, after ", oend-ostart, "seconds."

	  
!*******************************************************************
!  Calculate the life cycle profile of wealth,earning,income ratio 
!*******************************************************************
      
print*, "Computing age partition:"
	ostart = omp_get_wtime()	
	  CALL AGE_PARTITION
	 oend = omp_get_wtime()
 print*, "Done, after ", oend-ostart, "seconds."
	  
!******************************************************
!  Calculate the Income partition of top wealth share
!******************************************************
	  
print*, "Computing income partition:"
	ostart = omp_get_wtime()	
	  CALL income_partition
	oend = omp_get_wtime()	  
print*, "Done, after ", oend-ostart, "seconds."

print*, "Computing wealth by income partition:"
	ostart = omp_get_wtime()
	  CALL income_partition_sort_by_wealth
	oend = omp_get_wtime()	  
print*, "Done, after ", oend-ostart, "seconds."
	  
print*, "Computing age at the top:"
	ostart = omp_get_wtime()
	  CALL top_shares_age_partition
	oend = omp_get_wtime()	  
print*, "Done, after ", oend-ostart, "seconds."
	  
!*************************************
!  Calculate the Bequest Moment  
!*************************************		  
	  
print*, "Computing bequest statistics:"	  
	ostart = omp_get_wtime()
	  CALL bequest
	oend = omp_get_wtime()	  
print*, "Done, after ", oend-ostart, "seconds."

!******************************************************
!  Calculate the consumption share by income ranking
!******************************************************

print*, "Computing joint distribution:"
	ostart = omp_get_wtime()	
	  CALL joint_dist
	oend = omp_get_wtime()
print*, "Done, after ", oend-ostart, "seconds."     
	        			
!***************************
!   Summary Calculations
!***************************

! !  Age distribution of working age population

!	Compute the average ratios over the life cycle
	CWKEND  = 0.0
	IEND    = 0.0
	TWEND   = 0.0
    LEND    = 0.0
	 	 
    DO AGE=1,RETAGE-1
	    CWKEND  = CWKEND  + CLONG(AGE)*MUWK(AGE)
	    IEND    = IEND    + ILONG(AGE)*MUWK(AGE)
		LEND    = LEND    +	EFFLONG(AGE)*NLONG(AGE)*MUWK(AGE)
	    TWEND   = TWEND   + LLONG(AGE)   ! working hours
    END DO
	TWEND   = TWEND/(FLOAT(RETAGE-1))    ! average time endowment to work
	

	AEND   =0.0
	CEND   =0.0
	TIEND  =0.0
    DO AGE=1,MAXAGE
        AEND   = AEND   + ALONG(AGE)*MU(AGE)
 	    CEND   = CEND   + CLONG(AGE)*MU(AGE)
	    TIEND  = TIEND  + TILONG(AGE)*MU(AGE)
    END DO


!	Output

	K = AEND
	L = LEND
	OUTPUT = TFP*(K	**ALPHA)*(L**(1-ALPHA))
	
    MPK = (ALPHA)*TFP*(KD/LEND)**(ALPHA-1)-DEP
	MPL = (1.0-ALPHA)*TFP*( (((1+Avg_R_weighted)**5.0-1.0)+DEP)/(ALPHA*TFP) )**(ALPHA/(ALPHA-1.0))

!*************************************
!  Calculate the tax moments
!*************************************	

print*, "Computing tax moments:"
	ostart = omp_get_wtime()	
	  CALL tax_moment
	 oend = omp_get_wtime()
 print*, "Done, after ", oend-ostart, "seconds."

!*************************************
!  Calculate correlation
!*************************************

print*, "Computing correlation:"
	ostart = omp_get_wtime()	
	  CALL correlation
	 oend = omp_get_wtime()
 print*, "Done, after ", oend-ostart, "seconds."
 
!***************************************************
!  Calculate intergenerational wealth correlation
!***************************************************

print*, "Computing integenerational correlation:"
	ostart = omp_get_wtime()	
	  CALL INTERGENERATIONAL
	oend = omp_get_wtime()
print*, "Done, after ", oend-ostart, "seconds."

!*************************************	
!  Calculate earning growth moments
!*************************************

print*, "Computing earnings growth moments:"
	ostart = omp_get_wtime()	
	  CALL earnings_growth_moments
	 oend = omp_get_wtime()
 print*, "Done, after ", oend-ostart, "seconds."
 
!*************************************		  
!  Calculate SSE for estimation
!*************************************

print*, "Computing Calidiff:"
	ostart = omp_get_wtime()	
	  CALL Calidiff
	 oend = omp_get_wtime()
print*, "Done, after ", oend-ostart, "seconds."

!*************************************		  
    CALL CPU_TIME(t1)
	call SYSTEM_CLOCK(iTimes2)
    
	write(*,*) 'ELAPSED CPU time:', real(iTimes2-iTimes1)/real(rate)

	SURVMOMENT1 = sum(CUMS(RETAGE:MAXAGE))/sum(CUMS(1:RETAGE-1))
	SURVMOMENT2 = 1.00/sum(CUMS(1:MAXAGE))
	SURVMOMENT3 = (S(12)-S(10))/(S(10)-S(8))


!	Calibration

    WRITE(10,*) 'FINAL RESULTS'
    WRITE(10,*) '*****************************************************'
    WRITE(10,*)

print*,'****************************'
print*,''
print*,'    Calibration Results'
print*,''
print*,'****************************'
		print*, ' '	
		print*, 'Dependency ratio (Data: 0.3970 from US Life Table) =', SURVMOMENT1
    	print*, 'Average death rate (Data: 0.0824 from US Life Table) =', SURVMOMENT2
    	print*, 'change in Sur. Prob (age 65-69 to 75-79) / change in sur. prob. (age 55-59 to 65-69) (Data: 2.266 from US Life Table) =', SURVMOMENT3
    	print*, 'Sur. Prob (age 65-69) / Sur. Prob. (20-24) (Data: 0.9154 from US Life Table) =', S(10)/S(1)


		print*, ' '
		print *, "Transition Matrix for Productivity Process"
			DO i=1,nn
	  			WRITE(*,"(12(F10.6,1X))") P(i,1:nn)
			END DO
		print*, ' '

		print *, 'Probability of stay in top 1% earnings distribution'
		WRITE(*,"(12(F12.4,1X))") staytop1/poputop1 

		write(*, "(15(A11,1X))") 'Popu z_1','Popu z_2','Popu z_3','Popu z_4','Popu z_5','Popu z_6','Popu z_7', 'Popu z_8'
		WRITE(*,"(12(F11.4,1X))") mu_z(1,1),mu_z(1,2),mu_z(1,3),mu_z(1,4),mu_z(1,5),mu_z(1,6),mu_z(1,7),mu_z(1,8)
		print*, ' '

		print *, "Transition Matrix for Return in Wealth "
			DO ig = 1,4
				print*, "z group ", ig
			DO i=1,NGRIDR
	  			WRITE(*,"(12(F10.6,1X))") P_r(i,1:NGRIDR,ig)
			END DO
			END DO
		print*, ' '
		print*, 'Equilibrium rates of return '
		write(*, "(15(A11,1X))") 'r1','r2','r3'
		WRITE(*,"(12(F11.4,1X))") (1+R(1))**(0.2)-1, (1+R(2))**(0.2)-1, (1+R(3))**(0.2)-1

		print *, 'Steady State Probabilities'
		WRITE(*,"(12(F10.6,1X))") SSprob_r(1,:)
		print*, ' '

		write(*, "(15(A11,1X))") 'Popu r_L','Popu r_H','Popu r_awe'
		WRITE(*,"(12(F11.4,1X))") mu_r(1,1),mu_r(1,2),mu_r(1,3)
		print*, ' '

		write(*, "(15(A11,1X))") 'lambda_in', 'lambda_ll', 'lambda_lh', 'lambda_hh', 'w(1)', 'w(2)', 'w(3)', 'w(4)', 'W(5)', 'W(6)', 'W(7)', 'W(8)'
		WRITE(*,"(12(F11.4,1X))") lambda_in, lambda_ll, lambda_lh, lambda_hh, w(1), w(2), w(3), w(4), W(5), W(6), W(7), W(8)
		print*, ' '

		write(*, "(15(A11,1X))")  'BETA','phi1','phi2','bsigma','lambda','tau_l','tau_c','tau_s','d_c'
		WRITE(*,"(12(F11.4,1X))")  BETA**(0.2), bcoeff, bcoeff2,bsigma,lambda,tau_l,tau_c,tau_s,d_c
		write(*, "(15(A11,1X))") 'wage','weighted r', 'avg r','delta'
		WRITE(*,"(12(F11.4,1X))") wage, Avg_R_weighted ,Avg_R,DEP_ANNUAL
        write(*, "(15(A11,1X))") 'TFP','Y', 'L','K','ALPHA', 'K/Y', 'C'
        WRITE(*,"(12(F11.4,1X))") TFP,OUTPUT,LEND,AEND,ALPHA,alpha/(Avg_R_weighted + DEP_ANNUAL), Aggconsumption
		print*, ' '
		
		write(*,"(11(A8,1X))") 'Wealth Shares and Gini Coefficient'
		write(*,"(11(A8,1X))") 'Gini', 'Top0.5', 'Top1', 'Top5', 'Top10', 'Top20', 'Top40', 'Top60', 'Top80'
		write(*,"(11(F8.5,1X))") wea_gini, kshare05, kshare1, kshare5, kshare10, kshare20, kshare40, kshare60, kshare80
		print*, ' '
		
		write(*,"(11(A8,1X))") 'Earnings Shares and Gini Coefficient'
		write(*,"(11(A8,1X))") 'Gini', 'Top0.5', 'Top1', 'Top5', 'Top10', 'Top20', 'Top40', 'Top60', 'Top80'
		write(*,"(11(F8.5,1X))") inc_gini, incshare05, incshare1, incshare5, incshare10, incshare20, incshare40, incshare60, incshare80
		print*, ' '
		
		write(*,"(11(A8,1X))") 'Income Shares and Gini Coefficient'
		write(*,"(11(A8,1X))") 'Gini', 'Top0.5', 'Top1', 'Top5', 'Top10', 'Top20', 'Top40', 'Top60', 'Top80'
		write(*,"(11(F8.5,1X))") tinc_gini, tincshare05, tincshare1, tincshare5, tincshare10, tincshare20, tincshare40, tincshare60, tincshare80
		print*, ' '

		
		print*, ' '
		print*, 'Income tax moments'
		write(*,"(15(A11,1X))")  'ATY1-ATY99'
		write(*,"(12(F11.4,1X))")  ATY1-ATY99
		print*, 'Corporate tax moments'
		write(*,"(15(A11,1X))") 'R/GDP'
		write(*,"(12(F11.4,1X))") ctaxrev_GDP
		print*, 'Government expenditures','Government Transfer'
		write(*,"(15(A11,1X))") 'total exp/Y','G/Y' ,'Trans/Y','SocSec/Y'
		write(*,"(12(F11.4,1X))")  G_share, gov ,flat_transf_rate,SSEXP/OUTPUT+medicare_rate

		print*, ' '
		print*, 'Time Spent working =',TWEND	
	

		print*, ' '
		print*, 'Very top wealth share'
		write(*, "(15(A16,1X))") ' Top 0.001%', ' Top 0.005%', ' Top 0.01%', ' Top 0.05%',' Top 0.1%'
		write(*, "(143(F16.8,1X))") kshare0001, kshare0005, kshare001,kshare005, kshare01
		
		print*, ' '
		print*, 'Very top earning share'
		write(*, "(15(A16,1X))") ' Top 0.001%', ' Top 0.005%', ' Top 0.01%',' Top 0.05%', ' Top 0.1%'
		write(*, "(143(F16.8,1X))") incshare0001, incshare0005, incshare001,incshare005, incshare01
		
		print*, ' '
		print*, 'Very top income share'
		write(*, "(15(A16,1X))") ' Top 0.001%', ' Top 0.005%', ' Top 0.01%', ' Top 0.05%', ' Top 0.1%'
		write(*, "(143(F16.8,1X))") tincshare0001, tincshare0005, tincshare001, tincshare005, tincshare01

		print*, ' '
		print*, 'Very top consumption share'
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
		print*, 'Life cycle profile of wealth'
		write(*, "(15(A11,1X))") '20-24','25-29','30-34','35-39','40-44','45-49','50-54','55-59','60-64'
		WRITE(*,"(12(F11.4,1X))") ALONG20_25,ALONG25_30,ALONG30_35,ALONG35_40,ALONG40_45,ALONG45_50,ALONG50_55,ALONG55_60,ALONG60_65
		write(*, "(15(A11,1X))") '65-69','70-74','75-79','80-84','85-89','90-94','95-99'
		WRITE(*,"(12(F11.4,1X))") ALONG65_70, ALONG70_75, ALONG75_80, ALONG80_85, ALONG85_90, ALONG90_95,ALONG95_100


		print*, ' '
		print*, 'Life cycle profile of earnings'
		write(*, "(15(A11,1X))") '20-24','25-29','30-34','35-39','40-44','45-49','50-54','55-59','60-64'
		WRITE(*,"(12(F11.4,1X))") ILONG20_25,ILONG25_30,ILONG30_35,ILONG35_40,ILONG40_45,ILONG45_50,ILONG50_55,ILONG55_60,ILONG60_65

		
		print*, ' '
		print*, 'Life cycle profile of income'
		write(*, "(15(A11,1X))") '20-24','25-29','30-34','35-39','40-44','45-49','50-54','55-59','60-64'
		WRITE(*,"(12(F11.4,1X))") TILONG20_25,TILONG25_30,TILONG30_35,TILONG35_40,TILONG40_45,TILONG45_50,TILONG50_55,TILONG55_60,TILONG60_65
		write(*, "(15(A11,1X))") '65-69','70-74','75-79','80-84','85-89','90-94','95-99'
		WRITE(*,"(12(F11.4,1X))") TILONG65_70, TILONG70_75, TILONG75_80, TILONG80_85, TILONG85_90, TILONG90_95, TILONG95_100
		
		print*, ' '
		print*, 'Age-profile Wealth Gini'		
		write(*, "(15(A11,1X))") '20-24','25-29','30-34','35-39','40-44','45-49','50-54','55-59','60-64'
		WRITE(*,"(12(F11.4,1X))") age_wea_gini(1),age_wea_gini(2),age_wea_gini(3),age_wea_gini(4),age_wea_gini(5),age_wea_gini(6),age_wea_gini(7),age_wea_gini(8),age_wea_gini(9)
		write(*, "(15(A11,1X))") '65-69','70-74','75-79','80-84','85-89','90-94','95-99'
		WRITE(*,"(12(F11.4,1X))") age_wea_gini(10),age_wea_gini(11),age_wea_gini(12),age_wea_gini(13),age_wea_gini(14),age_wea_gini(15),age_wea_gini(16)
		print*, ' '
		print*, 'Age-profile Earning Gini'	
		write(*, "(15(A11,1X))") '20-24','25-29','30-34','35-39','40-44','45-49','50-54','55-59','60-64'
		WRITE(*,"(12(F11.4,1X))") age_inc_gini(1),age_inc_gini(2),age_inc_gini(3),age_inc_gini(4),age_inc_gini(5),age_inc_gini(6),age_inc_gini(7),age_inc_gini(8),age_inc_gini(9)
		print*, ' '
		print*, 'Age-profile Income Gini'
		write(*, "(15(A11,1X))") '20-24','25-29','30-34','35-39','40-44','45-49','50-54','55-59','60-64'
		WRITE(*,"(12(F11.4,1X))") age_tinc_gini(1),age_tinc_gini(2),age_tinc_gini(3),age_tinc_gini(4),age_tinc_gini(5),age_tinc_gini(6),age_tinc_gini(7),age_tinc_gini(8),age_tinc_gini(9)
		write(*, "(15(A11,1X))") '65-69','70-74','75-79','80-84','85-89','90-94','95-99'
		WRITE(*,"(12(F11.4,1X))") age_tinc_gini(10),age_tinc_gini(11),age_tinc_gini(12),age_tinc_gini(13),age_tinc_gini(14),age_tinc_gini(15),age_tinc_gini(16)

		print*, ' '
		print*, 'Pop-Avg Annual Returns by wealth groups'
		write(*, "(15(A11,1X))")  'All', 'Top 0.01%', 'Top 0.1%', 'Top 0.5%',  'Top 1%'  , 'Top 5%',   'Top 10%',    '95-99%',     '90-95%'
		WRITE(*,"(12(F11.4,1X))")  Avg_R, Avg_top001_R, Avg_top01_R,Avg_top05_R, Avg_top1_R, Avg_top5_R, Avg_top10_R,  Avg_95_99_R, Avg_90_95_R
		WRITE(*,"(12(F11.4,1X))")  SD_R ,  SD_top001_R , SD_top01_R ,SD_top05_R,  SD_top1_R , SD_top5_R,  SD_top10_R,   SD_95_99_R , SD_90_95_R 

		print*, ' '
		print*, 'Weighted-Avg Annual Returns by wealth groups'
		write(*, "(15(A11,1X))")   'All', 'Top 0.01%', 'Top 0.1%', 'Top 0.5%',  'Top 1%'  , 'Top 5%',   'Top 10%',    '95-99%',     '90-95%'
		WRITE(*,"(12(F11.4,1X))")  Avg_R_weighted, Avg_top001_R_weighted, Avg_top01_R_weighted, Avg_top05_R_weighted, Avg_top1_R_weighted, Avg_top5_R_weighted, Avg_top10_R_weighted,  Avg_95_99_R_weighted, Avg_90_95_R_weighted
		WRITE(*,"(12(F11.4,1X))")  SD_R_weighted, SD_top001_R_weighted , SD_top01_R_weighted ,SD_top05_R_weighted ,  SD_top1_R_weighted , SD_top5_R_weighted ,  SD_top10_R_weighted ,   SD_95_99_R_weighted , SD_90_95_R_weighted
		print*, ' '
		print*, 'Pop-Avg Annual Returns by income groups'
		write(*, "(15(A11,1X))")  'All', 'Top 0.01%', 'Top 0.1%', 'Top 0.5%',  'Top 1%'  , 'Top 5%',   'Top 10%',    '95-99%',     '90-95%'
		WRITE(*,"(12(F11.4,1X))")  Avg_R, Avg_topinc001_R, Avg_topinc01_R,Avg_topinc05_R, Avg_topinc1_R, Avg_topinc5_R, Avg_topinc10_R,  Avg_inc95_99_R, Avg_inc90_95_R
		WRITE(*,"(12(F11.4,1X))")  SD_R ,  SD_topinc001_R , SD_topinc01_R ,SD_topinc05_R,  SD_topinc1_R , SD_topinc5_R,  SD_topinc10_R,   SD_inc95_99_R , SD_inc90_95_R 

		print*, ' '
		print*, 'Wealth-weighted Avg Annual Returns by income groups'
		write(*, "(15(A11,1X))")   'All', 'topinc 0.01%', 'topinc 0.1%', 'topinc 0.5%',  'topinc 1%'  , 'topinc 5%',   'topinc 10%',    '95-99%',     '90-95%', 'bottom 90%'
		WRITE(*,"(12(F11.4,1X))")  Avg_R_weighted, Avg_topinc001_R_weighted, Avg_topinc01_R_weighted, Avg_topinc05_R_weighted, Avg_topinc1_R_weighted, Avg_topinc5_R_weighted, Avg_topinc10_R_weighted,  Avg_inc95_99_R_weighted, Avg_inc90_95_R_weighted, Avg_botinc90_R_weighted
		WRITE(*,"(12(F11.4,1X))")  SD_R_weighted, SD_topinc001_R_weighted , SD_topinc01_R_weighted ,SD_topinc05_R_weighted ,  SD_topinc1_R_weighted , SD_topinc5_R_weighted ,  SD_topinc10_R_weighted ,   SD_inc95_99_R_weighted , SD_inc90_95_R_weighted, SD_botinc90_R_weighted
		
		print*, ' '
		print*, 'Income Partition by income (labor, capital, transfer) '  
		write(*, "(15(A11,1X))") 'Average', 'Top 0.1%', 'Top 1%', '95-99%', '90-95%', 'Top 10%'
		WRITE(*,"(12(F11.4,1X))") earning_share_avg,earning_share01,earning_share1,earning_share9599,earning_share9095,earning_share10
		WRITE(*,"(12(F11.4,1X))") kincome_share_avg,kincome_share01,kincome_share1,kincome_share9599,kincome_share9095
		WRITE(*,"(12(F11.4,1X))") trans_share_avg,trans_share01,trans_share1,trans_share9599,trans_share9095
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share_avg-1.0),22+5*(age_share01-1.0),22+5*(age_share1-1.0),22+5*(age_share9599-1.0),22+5*(age_share9095-1.0)
		write(*, "(15(A11,1X))") 'Q5', 'Q4', 'Q3', 'Q2', 'Q1'
		WRITE(*,"(12(F11.4,1X))") earning_share5q,earning_share4q,earning_share3q,earning_share2q, earning_share1q
		WRITE(*,"(12(F11.4,1X))") kincome_share5q,kincome_share4q,kincome_share3q,kincome_share2q, kincome_share1q
		WRITE(*,"(12(F11.4,1X))") trans_share5q,trans_share4q,trans_share3q,trans_share2q, trans_share1q
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share5q-1.0),22+5*(age_share4q-1.0),22+5*(age_share3q-1.0),22+5*(age_share2q-1.0), 22+5*(age_share1q-1.0)
		write(*, "(15(A11,1X))") '1-5%', '5-10%', '0-90%'
		WRITE(*,"(12(F11.4,1X))") earning_share0105,earning_share0510,earning_share0090
		WRITE(*,"(12(F11.4,1X))") kincome_share0105,kincome_share0510,kincome_share0090
		WRITE(*,"(12(F11.4,1X))") trans_share0105,trans_share0510,trans_share0090
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share0105-1.0),22+5*(age_share0510-1.0),22+5*(age_share0090-1.0)

		print*, ' '
		print*, 'Income Partition by wealth (labor, capital, transfer) ' 
		write(*, "(15(A11,1X))") '99.9-99.99%', '99.5-99.9%', '99-99.5%'
		WRITE(*,"(12(F11.4,1X))") earning_share9999999_sort_by_wealth,earning_share995999_sort_by_wealth,earning_share99995_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") kincome_share9999999_sort_by_wealth,kincome_share995999_sort_by_wealth,kincome_share99995_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") trans_share9999999_sort_by_wealth,trans_share995999_sort_by_wealth,trans_share99995_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share9999999_sort_by_wealth-1.0),22+5*(age_share995999_sort_by_wealth-1.0),22+5*(age_share99995_sort_by_wealth-1.0)
		write(*, "(15(A11,1X))") 'Top0.01%', 'Top0.05%', 'Top0.1%', 'Top0.5%'
		WRITE(*,"(12(F11.4,1X))") earning_share001_sort_by_wealth,earning_share005_sort_by_wealth,earning_share01_sort_by_wealth,earning_share05_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") kincome_share001_sort_by_wealth,kincome_share005_sort_by_wealth,kincome_share01_sort_by_wealth,kincome_share05_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") trans_share001_sort_by_wealth,trans_share005_sort_by_wealth,trans_share01_sort_by_wealth,trans_share05_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share001_sort_by_wealth-1.0),22+5*(age_share005_sort_by_wealth-1.0),22+5*(age_share01_sort_by_wealth-1.0),22+5*(age_share05_sort_by_wealth-1.0)
		write(*, "(15(A11,1X))") 'Average', 'Top 1%', '95-99%', '90-95%','80-90%'
		WRITE(*,"(12(F11.4,1X))") earning_share_avg_sort_by_wealth,earning_share1_sort_by_wealth,earning_share9599_sort_by_wealth,earning_share9095_sort_by_wealth,earning_share8090_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") kincome_share_avg_sort_by_wealth,kincome_share1_sort_by_wealth,kincome_share9599_sort_by_wealth,kincome_share9095_sort_by_wealth,kincome_share8090_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") trans_share_avg_sort_by_wealth,trans_share1_sort_by_wealth,trans_share9599_sort_by_wealth,trans_share9095_sort_by_wealth,trans_share8090_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share_avg_sort_by_wealth-1.0),22+5*(age_share1_sort_by_wealth-1.0),22+5*(age_share9599_sort_by_wealth-1.0),22+5*(age_share9095_sort_by_wealth-1.0),22+5*(age_share8090_sort_by_wealth-1.0)
		write(*, "(15(A11,1X))") 'Q5', 'Q4', 'Q3', 'Q2', 'Q1'
		WRITE(*,"(12(F11.4,1X))") earning_share5q_sort_by_wealth,earning_share4q_sort_by_wealth,earning_share3q_sort_by_wealth,earning_share2q_sort_by_wealth, earning_share1q_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") kincome_share5q_sort_by_wealth,kincome_share4q_sort_by_wealth,kincome_share3q_sort_by_wealth,kincome_share2q_sort_by_wealth, kincome_share1q_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") trans_share5q_sort_by_wealth,trans_share4q_sort_by_wealth,trans_share3q_sort_by_wealth,trans_share2q_sort_by_wealth, trans_share1q_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share5q_sort_by_wealth-1.0),22+5*(age_share4q_sort_by_wealth-1.0),22+5*(age_share3q_sort_by_wealth-1.0),22+5*(age_share2q_sort_by_wealth-1.0), 22+5*(age_share1q_sort_by_wealth-1.0)
		write(*, "(15(A11,1X))") '1-5%', '5-10%'
		WRITE(*,"(12(F11.4,1X))") earning_share0105_sort_by_wealth,earning_share0510_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") kincome_share0105_sort_by_wealth,kincome_share0510_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") trans_share0105_sort_by_wealth,trans_share0510_sort_by_wealth
		WRITE(*,"(12(F11.4,1X))") 22+5*(age_share0105_sort_by_wealth-1.0),22+5*(age_share0510_sort_by_wealth-1.0)
		
		print*, ' '
		print*, 'Age composition of the top 1% of income'
		write(*,"(4(A11,1X))") '<31', '31-45', '46-65', '65+'
		write(*,"(4(F11.4,1X))") age_share1_2030, age_share1_3145, age_share1_4665, age_share1_6699
			
				
		print*, ' '
		print*, 'Age composition of the top 1% of wealth'
		write(*,"(4(A11,1X))") '<31', '31-45', '46-65', '65+'
		write(*,"(4(F11.4,1X))") age_share1_sort_by_wealth_2030,	age_share1_sort_by_wealth_3145,	age_share1_sort_by_wealth_4665,	age_share1_sort_by_wealth_6699
	
		
        print*, ' '
		print*, 'Bequest Moments'
		write(*, "(15(A11,1X))") 'Beq/Wealth','Top2% share'
		WRITE(*,"(12(F11.4,1X))") beq_wealth_ratio,bshare98_100

		print*, ' '
		print*, 'Top marginal tax rate =', ty_max		

		print*, ' '
		print*, 'inheritance Distribution'
		write(*, "(15(A11,1X))") 'Mean','Gini','0-50(%)','50-70(%)', '70-80(%)', '80-90(%)', '90-95(%)', '95-99(%)', '98-100(%)','99-100(%)'
		WRITE(*,"(12(F11.4,1X))") AggBeq,beq_gini,bshare0_50*100,bshare50_70*100,bshare70_80*100,bshare80_90*100,bshare90_95*100,bshare95_99*100,bshare98_100*100,bshare99_100*100

		print*, ' '
		print*, 'Earning growth moments'
		write(*,"(15(A11,1X))") 'mean', 'SD', 'Skew', 'Kurt'
		write(*,"(12(F11.4,1X))") avg_earning_growth, sd_earning_growth, skew_earning_growth, kurt_earning_growth

		print*, 'Program End'


OPEN(UNIT=9,FILE='cali_res_benchmark.txt')		
WRITE(9,"(282(F16.8,1X))") lambda_in, lambda_ll, lambda_lh, lambda_hh,zawel,zaweh,(1+R(1))**(0.2)-1, (1+R(2))**(0.2)-1, (1+R(3))**(0.2)-1, &
		p11_r, p22_r, p33_r, prawe, intergen_corr_return, relpawein3, relpawein4, bcoeff, bcoeff2, BETA_ANNUAL,tau_l,d_c,gov,lambda,&
		BETA**(0.2),DEP_ANNUAL, sigma,tau_c,tau_s, w(1),w(2), w(3), w(4), w(5), w(6), &
		TFP, alpha/(Avg_R_weighted + DEP_ANNUAL), Aggwealth, LEND, MPL,wage, MPK, Avg_R, Avg_R_weighted, &
		wea_gini, kshare01,kshare05, kshare1, kshare5, kshare10, inc_gini, incshare01,incshare05, incshare1, incshare5, incshare10, &
		beq_wealth_ratio,bshare98_100, Beq90, ATY1-ATY99, ATY1, ATY99, ATC1, G_share, SSEXP/OUTPUT+medicare_rate, &
		earning_share01, earning_share1, earning_share9599, earning_share9095,earning_share0090, earning_share_avg, staytop1/poputop1, &
		Avg_topinc01_R_weighted/Avg_botinc90_R_weighted, Avg_topinc1_R_weighted/Avg_botinc90_R_weighted, &
		share_topz_all, share_topz_1, share_topz_01, share_topr_all, share_topr_1, share_topr_01, share_topboth_all, share_topboth_1, share_topboth_01, &
		share_zr_all(:,1), share_zr_all(:,2), share_zr_all(:,3), share_zr_top1(:,1), share_zr_top1(:,2), share_zr_top1(:,3), share_zr_top01(:,1), share_zr_top01(:,2), share_zr_top01(:,3), &
		kshare0001, kshare0005, kshare001, kshare20,kshare40,kshare60,kshare80, &
		incshare0001, incshare0005, incshare001, incshare20,incshare40,incshare60,incshare80, &
		tinc_gini,tincshare0001, tincshare0005, tincshare001, tincshare01,tincshare05,tincshare1,tincshare5,tincshare10,tincshare20,tincshare40,tincshare60,tincshare80, &
		kshare_E01, kshare_E05, kshare_E1, kshare_E5, kshare_E10, kshare_E20, kshare_E40, kshare_E60, kshare_E80, & 
		kshare_Y01, kshare_Y05, kshare_Y1, kshare_Y5, kshare_Y10, kshare_Y20, kshare_Y40, kshare_Y60, kshare_Y80, &
		corr_earn_wealth, corr_earn_wealth_working, corr_income_wealth, &
		earning_share01_sort_by_wealth, earning_share1_sort_by_wealth, earning_share9599_sort_by_wealth, earning_share9095_sort_by_wealth, &
		avg_earning_growth, sd_earning_growth, skew_earning_growth, kurt_earning_growth,  &
		22+5*(age_share_avg-1.0),22+5*(age_share1-1.0),22+5*(age_share9599-1.0),22+5*(age_share9095-1.0), &
		22+5*(age_share01_sort_by_wealth-1.0),22+5*(age_share05_sort_by_wealth-1.0), 22+5*(age_share1_sort_by_wealth-1.0),22+5*(age_share9599_sort_by_wealth-1.0),22+5*(age_share9095_sort_by_wealth-1.0), &
		age_wealth_share1_20_29, age_wealth_share1_30_44, age_wealth_share1_45_64, age_wealth_share1_65_99, &
		age_income_share1_20_29, age_income_share1_30_44, age_income_share1_45_64, age_income_share1_65_99, &
		age_earning_share1_20_29, age_earning_share1_30_44, age_earning_share1_45_64, age_earning_share1_65_99, &
		ALONG20_25,ALONG25_30,ALONG30_35,ALONG35_40,ALONG40_45,ALONG45_50,ALONG50_55,ALONG55_60,ALONG60_65,ALONG65_MORE, &
		ILONG20_25,ILONG25_30,ILONG30_35,ILONG35_40,ILONG40_45,ILONG45_50,ILONG50_55,ILONG55_60,ILONG60_65,ILONG65_MORE, &
		TILONG20_25,TILONG25_30,TILONG30_35,TILONG35_40,TILONG40_45,TILONG45_50,TILONG50_55,TILONG55_60,TILONG60_65,TILONG65_MORE, &
		age_wea_gini(1),age_wea_gini(2),age_wea_gini(3),age_wea_gini(4),age_wea_gini(5),age_wea_gini(6),age_wea_gini(7),age_wea_gini(8),age_wea_gini(9),age_wea_gini(10), & 
		corr_Akids_Aparents_sq, wealth_trans(1,1), wealth_trans(2,2), wealth_trans(3,3), wealth_trans(4,4), wealth_trans(5,5), share_zero_k, &
		ctaxrev_GDP, TWEND, SSE, &	
		Avg_topinc01_R_weighted,Avg_topinc1_R_weighted,Avg_botinc90_R_weighted,Avg_top01_R_weighted,Avg_top1_R_weighted,Avg_bot90_R_weighted!new added by david


CLOSE(9)		
! This file contains 
! 1. parameters,
! 2. auxiliary/fixed parameters
! 3. calibration targets
! 4. other important moments.
		
		
WRITE(4,*) sort_A(:)
WRITE(41,*) sort_D(:)
WRITE(42,*) top1pct_D(:)


!******************************************
!   Save results used in paper
!******************************************

OPEN(UNIT=12, FILE='Figure3.txt')
! Figure 3a: Cross-sectional distributions of wealth, earnings and income. 
write(unit=12, fmt=*) kshare01, kshare05, kshare1, kshare5, kshare10, kshare20, kshare40
write(unit=12, fmt=*) incshare01, incshare05, incshare1, incshare5, incshare10, incshare20, incshare40
write(unit=12, fmt=*) tincshare01, tincshare05, tincshare1, tincshare5, tincshare10, tincshare20, tincshare40
! Figure 3b: Wealth by Income and Earnings
write(unit=12, fmt=*) kshare_Y01, kshare_Y05, kshare_Y1, kshare_Y5, kshare_Y10, kshare_Y20, kshare_Y40
write(unit=12, fmt=*) kshare_E01, kshare_E05, kshare_E1, kshare_E5, kshare_E10, kshare_E20, kshare_E40
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Section61.txt')
write(unit=12, fmt=*) wea_gini, inc_gini, tinc_gini
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Table4.txt')
! Table 4: Share of Income from Labor by Income Groups, and surrounding text
! by income: 
write(unit=12, fmt=*) earning_share_avg, earning_share01, earning_share1, earning_share10, earning_share5q,earning_share4q,earning_share3q,earning_share2q, earning_share1q
! by wealth: 
write(unit=12, fmt=*) earning_share01_sort_by_wealth, earning_share05_sort_by_wealth, earning_share1_sort_by_wealth, earning_share9599_sort_by_wealth, earning_share9095_sort_by_wealth
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Section62.txt')
! Section 6.2: Productivity process
! top states:
! productivity relative to average: 
write(unit=12, fmt=*) z(7)/dot_product(reshape(mu_z,(/nn/)),z), z(8)/dot_product(reshape(mu_z,(/nn/)),z)
! size of top groups:
write(unit=12, fmt=*) mu_z(1,7), mu_z(1,8)
! model top earnings shares rel to avg: 
write(unit=12, fmt=*) incshare01/.001, incshare1/.01
! distribution of earnings growth: 
write(unit=12, fmt=*) sd_earning_growth, skew_earning_growth, kurt_earning_growth
! probability of remaining among the top 1 percent of earners after 5 years:
write(unit=12, fmt=*)  staytop1/poputop1 
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Section63.txt')
! Section 6.3: Rate of return heterogeneity
! calibrated annual rates of return: 
write(unit=12, fmt=*) (1+R(1))**(0.2)-1, (1+R(2))**(0.2)-1, (1+R(3))**(0.2)-1
! population distribution:
write(unit=12, fmt=*) mu_r(1,1),mu_r(1,2),mu_r(1,3)
! probability of entering top return state, highest labor productivity vs regular:
write(unit=12, fmt=*) pawein4/pawein2
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Figure4.txt')
! Figure 4: Rates of Return by Wealth and Income
! - (a) by income: 
write(unit=12, fmt=*) Avg_R_weighted, Avg_topinc01_R_weighted, Avg_topinc1_R_weighted, Avg_bot90_R_weighted
! - (b) by wealth: 
write(unit=12, fmt=*) Avg_R_weighted, Avg_top01_R_weighted, Avg_top1_R_weighted, Avg_botinc90_R_weighted
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Figure5.txt')
! - Figure 5: Earnings, Income and Wealth over the Life Cycle
! 	- (a) Earnings: 
write(unit=12, fmt=*) ILONG20_25,ILONG25_30,ILONG30_35,ILONG35_40,ILONG40_45,ILONG45_50,ILONG50_55,ILONG55_60,ILONG60_65
! 	- (b) Income:
write(unit=12, fmt=*)  TILONG20_25,TILONG25_30,TILONG30_35,TILONG35_40,TILONG40_45,TILONG45_50,TILONG50_55,TILONG55_60,TILONG60_65,TILONG65_70,TILONG70_75,TILONG75_80,TILONG80_85,TILONG85_90,TILONG90_95,TILONG95_100
! 	- (c) Net Worth:
write(unit=12, fmt=*)  ALONG20_25,ALONG25_30,ALONG30_35,ALONG35_40,ALONG40_45,ALONG45_50,ALONG50_55,ALONG55_60,ALONG60_65,ALONG65_70,ALONG70_75,ALONG75_80,ALONG80_85,ALONG85_90,ALONG90_95,ALONG95_100
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Figure6.txt')
! - Figure 6: Earnings and Wealth Inequality over the Life Cycle
! 	- wealth: 
write(unit=12, fmt=*) age_wea_gini(1),age_wea_gini(2),age_wea_gini(3),age_wea_gini(4),age_wea_gini(5),age_wea_gini(6),age_wea_gini(7),age_wea_gini(8),age_wea_gini(9)
! 	- earnings:
write(unit=12, fmt=*) age_inc_gini(1),age_inc_gini(2),age_inc_gini(3),age_inc_gini(4),age_inc_gini(5),age_inc_gini(6),age_inc_gini(7),age_inc_gini(8),age_inc_gini(9)
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Table5.txt')
! - Table 5:
! 	- wealth Gini, top wealth shares, top earnings shares: 
write(unit=12, fmt=*) wea_gini, kshare01, kshare1, incshare01, incshare1, earning_share01, earning_share1, Avg_topinc01_R_weighted/Avg_R_weighted, Avg_topinc1_R_weighted/Avg_R_weighted
! 	- for all 8 code files.
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='Section81.txt')
! - Section 8.1: Alternative calibrations and the labor share of income
! 	- inputs:
! 		- top return required when setting z8=z7=z6
! 		- z8 required when setting kappa = asset-weighted mean in bm
write(unit=12, fmt=*) incshare01, incshare1, earning_share01, earning_share1, earning_share01_sort_by_wealth, earning_share1_sort_by_wealth
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='TableC1.txt')
! - Appendix Table C.1: Calibrated Productivity Process in the Benchmark Economy
! 	- Levels: 
write(unit=12, fmt=*) z
! transition matrix: 			
DO i=1,nn
	WRITE(12,"(12(F10.6,1X))") P(i,1:nn)
END DO
! initial distribution: 
write(unit=12, fmt=*) invar
! population share: 
write(unit=12, fmt=*) mu_z(1,1),mu_z(1,2),mu_z(1,3),mu_z(1,4),mu_z(1,5),mu_z(1,6),mu_z(1,7),mu_z(1,8)
CLOSE(UNIT=12)

OPEN(UNIT=12, FILE='TableC2.txt')
! - Appendix Table C.2:The Transition Matrix for Rates of Return on Capital
! transition matrix: 			
DO ig = 1,4
	DO i=1,NGRIDR
		WRITE(12,"(12(F10.6,1X))") P_r(i,1:NGRIDR,ig)
	END DO
END DO
! population share:
write(unit=12, fmt=*) mu_r(1,1),mu_r(1,2),mu_r(1,3)
! annual rate of return: 
write(unit=12, fmt=*) (1+R(1))**(0.2)-1, (1+R(2))**(0.2)-1, (1+R(3))**(0.2)-1
! Probability of entering the top return state by z state of origin: 
write(unit=12, fmt=*) pawein2, pawein3, pawein4
CLOSE(UNIT=12)


!******************************************
!   Internal Functions and Subroutines
!******************************************

     CONTAINS

!******************************************************************

SUBROUTINE SRCHFIVE01(AGE,IA,IR,IS,WAGEZ,JAMAX,JNMAX,VMAX, &
                      ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ,BEQTRANS1)

!**************************************************************
!
!   Finds optimum asset and labor choices over grid points
!        
!***************************************************************

IMPLICIT NONE

!PASSED VARIABLES:
INTEGER    ::  AGE,IA,IR,IS,JAMAX,JNMAX,&
               ILA,IUA,ISKIPA,ILN,IUN,ISKIPN
REAL(PREC) :: WAGEZ,VMAX,X3,BEQ,BEQTRANS1


!LOCA VARIABLES
INTEGER    :: JA, JN
REAL(PREC)  :: VTEMP, CONS,LEI, UTIL,SUR


DO JA=ILA,IUA,ISKIPA
        
        SELECTCASE(AGE)
       CASE(1:RETAGE-2)
			DO JN=ILN,IUN,ISKIPN

				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ*N(JN)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGEZ*N(JN) - bendy) &
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans	

				CONS = ( X3  + BEQTRANS1 + yd - A(JA) )/(1.0+tau_s)
		        LEI = 1.00000000 - N(JN) 

                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
					UTIL= utility (cons,lei)
                ELSE
		            UTIL=-1.E7
                END IF
                
				SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))				

					sum_temp1 = 0.0
					sum_temp2 = 0.0
					
					DO i = 1,NGRIDR
						sum_temp1 = sum_temp1 + P_r(IR,i,zgroup(IS))*(sum( P(IS,:)*VW(AGE+1,JA,i,:) ))
					END DO

					IF (beqprob(AGE)>0.0) THEN
						IF (IS<=3) THEN		
							IF (IR>=2) THEN 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_lowkid_dist(AGE,JA,:,2)*VW(AGE+1,:,i,NEWIS))
									END DO
								END DO
							ELSE 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_lowkid_dist(AGE,JA,:,1)*VW(AGE+1,:,i,NEWIS)) 
									END DO
								END DO
							END IF 					
						ELSE 
							IF (IR>=2) THEN 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_highkid_dist(AGE,JA,:,2)*VW(AGE+1,:,i,NEWIS)) 
									END DO
								END DO
							ELSE 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_highkid_dist(AGE,JA,:,1)*VW(AGE+1,:,i,NEWIS))
									END DO
								END DO
							END IF 
						END IF
					END IF 

					VTEMP = UTIL + BETA*SUR*( (1.0-beqprob(AGE))*sum_temp1 + beqprob(AGE)*sum_temp2 ) +(1-SUR)*(bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1))
								
                
                UPDATE1:  IF (VTEMP>=VMAX) THEN
			        VMAX = VTEMP
			        JAMAX = JA
			        JNMAX = JN			  
                END IF UPDATE1
            END DO		

        CASE(RETAGE-1)
            DO JN=ILN,IUN,ISKIPN

		        yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ*N(JN)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGEZ*N(JN) - bendy) &			
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans

				CONS = (X3 + BEQTRANS1 + yd - A(JA))/(1.0+tau_s)

				LEI  = 1.00000000 - N(JN) 
                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
					UTIL= utility (cons,lei)
		        ELSE
		            UTIL=-1.E7
                END IF
                                                                      
				SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
                

					sum_temp = 0.0
					IF (beqprob(AGE)>0.0) THEN						
						IF (IS<=3) THEN
							IF (IR>=2) THEN
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
								END DO 						
							ELSE
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
								END DO
							END IF
						ElSE
							IF (IR>=2) THEN
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
								END DO 
							ELSE 
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
								END DO 
							END IF 
						END IF
					END IF
					VTEMP = UTIL + BETA*SUR*( (1.0-beqprob(AGE))*sum(P_r(IR,:,zgroup(IS))*VR(AGE+1,JA,:,IS)) +  beqprob(AGE)*sum_temp ) +(1-SUR)*(bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1))
 

                UPDATE4:  IF (VTEMP>=VMAX) THEN
                    VMAX = VTEMP
			        JAMAX = JA
			        JNMAX = JN			  
                END IF UPDATE4
            END DO

        
        CASE(RETAGE:MAXAGE-1)   
 
		    yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ))**(1.0-tau_l) &
				 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ WAGEZ - bendy) &
				 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans+medicare

			CONS = (X3 + yd - A(JA))/(1.0+tau_s)					
			LEI  = 1.00000000 

		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
				UTIL= utility (cons,lei)
		    ELSE
		        UTIL=-1.E7
            END IF
                       
        
			SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2))) 


				sum_temp = 0.0
				IF (beqprob(AGE)>0.0) THEN
					IF (IS<=3) THEN
						IF (IR>=2) THEN
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
							END DO 						
						ELSE
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
							END DO
						END IF
					ElSE
						IF (IR>=2) THEN
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
							END DO 
						ELSE 
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
							END DO 
						END IF 
					END IF
				END IF 
				VTEMP = UTIL + BETA*SUR* ( (1.0-beqprob(AGE))*sum(P_r(IR,:,zgroup(IS))*VR(AGE+1,JA,:,IS)) + beqprob(AGE)*sum_temp ) + (1-SUR)*( bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1) )  

            
            UPDATE5:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    JAMAX = JA
			    JNMAX = 1			  
            END IF UPDATE5

            CASE(MAXAGE)  
			           
		    yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ))**(1.0-tau_l) &
				 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ WAGEZ - bendy) &
				 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans+medicare
			
			CONS = (X3 + yd - A(JA))/(1.0+tau_s)	
			LEI = 1.0
            
		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
                UTIL= utility(cons,lei) 
		    ELSE
		        UTIL=-1.E7
            END IF

			VTEMP = UTIL + bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1)

			UPDATE6:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    JAMAX = JA
			    JNMAX = 1			  
			    
            END IF UPDATE6
        
        END SELECT
 
END DO

END SUBROUTINE

!************************************************************************
SUBROUTINE N_SRCHFIVE01(AGE,IA,IR,IS, WAGEZ,JAMAX,JNMAX,VMAX, &
                     ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ,BEQTRANS1) 
!************************************************************************

!	This routine is to update the optimum labor choice found in subrountine SRCHFIVE01 
!   given the chosen optimal asset level in subrountine A_SRCHFIVE01

!************************************************************************
IMPLICIT NONE
!PASSED VARIABLES:

INTEGER    ::  AGE,IA,IR,IS,JAMAX,JNMAX,&
               ILA,IUA,ISKIPA,ILN,IUN,ISKIPN
REAL(PREC) :: WAGEZ,VMAX,X3,BEQ,BEQTRANS1


!LOCA VARIABLES

INTEGER    :: JA, JN
REAL(PREC)  :: VTEMP, CONS,LEI, UTIL,SUR
        
        SELECTCASE(AGE)
        CASE(1:RETAGE-2)
		JA = IDCWA(AGE,IA,IR,IS)
			DO JN=ILN,IUN,ISKIPN

				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ*N(JN)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGEZ*N(JN) - bendy) &
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans	

				CONS = ( X3  + BEQTRANS1 + yd - A(JA) )/(1.0+tau_s)
		        LEI = 1.00000000 - N(JN) 

                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
					UTIL= utility (cons,lei)
                ELSE
		            UTIL=-1.E7
                END IF
                
				SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
                

					sum_temp1 = 0.0
					sum_temp2 = 0.0
					
					DO i = 1,NGRIDR
						sum_temp1 = sum_temp1 + P_r(IR,i,zgroup(IS))*(sum( P(IS,:)*VW(AGE+1,JA,i,:) ))
					END DO

					IF (beqprob(AGE)>0.0) THEN
						IF (IS<=3) THEN		
							IF (IR>=2) THEN 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_lowkid_dist(AGE,JA,:,2)*VW(AGE+1,:,i,NEWIS))
									END DO
								END DO
							ELSE 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_lowkid_dist(AGE,JA,:,1)*VW(AGE+1,:,i,NEWIS)) 
									END DO
								END DO
							END IF 					
						ELSE 
							IF (IR>=2) THEN 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_highkid_dist(AGE,JA,:,2)*VW(AGE+1,:,i,NEWIS)) 
									END DO
								END DO
							ELSE 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_highkid_dist(AGE,JA,:,1)*VW(AGE+1,:,i,NEWIS))
									END DO
								END DO
							END IF 
						END IF
					END IF 

					VTEMP = UTIL + BETA*SUR*( (1.0-beqprob(AGE))*sum_temp1 + beqprob(AGE)*sum_temp2 ) +(1-SUR)*(bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1))
				

                UPDATE1:  IF (VTEMP>=VMAX) THEN
			        VMAX = VTEMP
			        JAMAX = JA
			        JNMAX = JN			  
                END IF UPDATE1
            END DO		

        CASE(RETAGE-1)
		JA = IDCWA(AGE,IA,IR,IS)
            DO JN=ILN,IUN,ISKIPN
                
		        yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ*N(JN)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGEZ*N(JN) - bendy) &			
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans

				CONS = (X3 + BEQTRANS1 + yd - A(JA))/(1.0+tau_s)

				LEI  = 1.00000000 - N(JN) 
                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
					UTIL= utility (cons,lei)
		        ELSE
		            UTIL=-1.E7
                END IF
 
				SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
				

					sum_temp = 0.0
					IF (beqprob(AGE)>0.0) THEN						
						IF (IS<=3) THEN
							IF (IR>=2) THEN
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
								END DO 						
							ELSE
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
								END DO
							END IF
						ElSE
							IF (IR>=2) THEN
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
								END DO 
							ELSE 
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
								END DO 
							END IF 
						END IF
					END IF
					VTEMP = UTIL + BETA*SUR*( (1.0-beqprob(AGE))*sum(P_r(IR,:,zgroup(IS))*VR(AGE+1,JA,:,IS)) +  beqprob(AGE)*sum_temp ) +(1-SUR)*(bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1))

                
                UPDATE4:  IF (VTEMP>=VMAX) THEN
                    VMAX = VTEMP
			        JAMAX = JA
			        JNMAX = JN			  
                END IF UPDATE4
            END DO
        
        CASE(RETAGE:MAXAGE-1)   
		
		    yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ))**(1.0-tau_l) &
				 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ WAGEZ - bendy) &
				 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans+medicare

			CONS = (X3 + yd - A(JA))/(1.0+tau_s)					
			LEI  = 1.00000000 

		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
				UTIL= utility (cons,lei)
		    ELSE
		        UTIL=-1.E7
            END IF
                       
			SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2))) 
			

				sum_temp = 0.0
				IF (beqprob(AGE)>0.0) THEN
					IF (IS<=3) THEN
						IF (IR>=2) THEN
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
							END DO 						
						ELSE
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
							END DO
						END IF
					ElSE
						IF (IR>=2) THEN
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
							END DO 
						ELSE 
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
							END DO 
						END IF 
					END IF
				END IF 
				VTEMP = UTIL + BETA*SUR* ( (1.0-beqprob(AGE))*sum(P_r(IR,:,zgroup(IS))*VR(AGE+1,JA,:,IS)) + beqprob(AGE)*sum_temp ) + (1-SUR)*( bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1) )  

            
            UPDATE5:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    JAMAX = JA
			    JNMAX = 1			  
            END IF UPDATE5

            CASE(MAXAGE)  
			          
		    yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ))**(1.0-tau_l) &
				 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ WAGEZ - bendy) &
				 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans+medicare
			
			CONS = (X3 + yd - A(JA))/(1.0+tau_s)	
			LEI = 1.0
            
		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
                UTIL= utility(cons,lei) 
		    ELSE
		        UTIL=-1.E7
            END IF

			VTEMP = UTIL + bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1)

			UPDATE6:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    JAMAX = JA
			    JNMAX = 1			  
			    
            END IF UPDATE6
        
        END SELECT


END SUBROUTINE
!******************************************************************
SUBROUTINE A_SRCHFIVE01(AGE,IA,IR,IS, WAGEZ,JAMAX,JNMAX,VMAX, &
                     ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ,BEQTRANS1) 

!************************************************************************
!
!	This routine is to update the optimum asset choice found in subrountine SRCHFIVE01 
!   given the chosen optimal labor level in subrountine SRCHFIVE01
!
!************************************************************************

IMPLICIT NONE

!PASSED VARIABLES:
INTEGER    ::  AGE,IA,IR,IS,JAMAX,JNMAX,&
               ILA,IUA,ISKIPA,ILN,IUN,ISKIPN
REAL(PREC) :: WAGEZ,VMAX,X3,BEQ,BEQTRANS1


!LOCA VARIABLES
INTEGER    :: JA, JN
REAL(PREC)  :: VTEMP, CONS,LEI, UTIL,SUR
        
        SELECTCASE(AGE)
        CASE(1:RETAGE-2)
		JN = IDCWN(AGE,IA,IR,IS)
			DO JA=ILA,IUA,ISKIPA

				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ*N(JN)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGEZ*N(JN) - bendy) &
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans	

				CONS = ( X3  + BEQTRANS1 + yd - A(JA) )/(1.0+tau_s)
		        LEI = 1.00000000 - N(JN) 
 
                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
					UTIL= utility (cons,lei)
                ELSE
		            UTIL=-1.E7
                END IF
                
				SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
                

					sum_temp1 = 0.0
					sum_temp2 = 0.0
					
					DO i = 1,NGRIDR
						sum_temp1 = sum_temp1 + P_r(IR,i,zgroup(IS))*(sum( P(IS,:)*VW(AGE+1,JA,i,:) ))
					END DO

					IF (beqprob(AGE)>0.0) THEN
						IF (IS<=3) THEN		
							IF (IR>=2) THEN 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_lowkid_dist(AGE,JA,:,2)*VW(AGE+1,:,i,NEWIS))
									END DO
								END DO
							ELSE 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_lowkid_dist(AGE,JA,:,1)*VW(AGE+1,:,i,NEWIS)) 
									END DO
								END DO
							END IF 					
						ELSE 
							IF (IR>=2) THEN 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_highkid_dist(AGE,JA,:,2)*VW(AGE+1,:,i,NEWIS)) 
									END DO
								END DO
							ELSE 
								DO i = 1,NGRIDR
									DO NEWIS = 1,nn				
										sum_temp2 = sum_temp2 + P_r(IR,i,zgroup(IS))*P(IS,NEWIS)*sum(X45_highkid_dist(AGE,JA,:,1)*VW(AGE+1,:,i,NEWIS))
									END DO
								END DO
							END IF 
						END IF
					END IF 

					VTEMP = UTIL + BETA*SUR*( (1.0-beqprob(AGE))*sum_temp1 + beqprob(AGE)*sum_temp2 ) +(1-SUR)*(bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1))


                UPDATE1:  IF (VTEMP>=VMAX) THEN
			        VMAX = VTEMP
			        JAMAX = JA
			        JNMAX = JN			  
                END IF UPDATE1
            END DO
		

        CASE(RETAGE-1)
        JN = IDCWN(AGE,IA,IR,IS)
			DO JA=ILA,IUA,ISKIPA
                
		        yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ*N(JN)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+WAGEZ*N(JN) - bendy) &			
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans

				CONS = (X3 + BEQTRANS1 + yd - A(JA))/(1.0+tau_s)
				LEI  = 1.00000000 - N(JN) 
 
                IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
					UTIL= utility (cons,lei)
		        ELSE
		            UTIL=-1.E7
                END IF
                                                                      
				SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))
				

					sum_temp = 0.0
					IF (beqprob(AGE)>0.0) THEN						
						IF (IS<=3) THEN
							IF (IR>=2) THEN
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
								END DO 						
							ELSE
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
								END DO
							END IF
						ElSE
							IF (IR>=2) THEN
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
								END DO 
							ELSE 
								DO i = 1,NGRIDR
									sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
								END DO 
							END IF 
						END IF
					END IF
					VTEMP = UTIL + BETA*SUR*( (1.0-beqprob(AGE))*sum(P_r(IR,:,zgroup(IS))*VR(AGE+1,JA,:,IS)) +  beqprob(AGE)*sum_temp ) +(1-SUR)*(bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1))

                
                UPDATE4:  IF (VTEMP>=VMAX) THEN
                    VMAX = VTEMP
			        JAMAX = JA
			        JNMAX = JN		
                END IF UPDATE4
            END DO
        
        CASE(RETAGE:MAXAGE-1)   
	
		    yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ))**(1.0-tau_l) &
				 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ WAGEZ - bendy) &
				 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans+medicare

			CONS = (X3 + yd - A(JA))/(1.0+tau_s)			
			LEI  = 1.00000000 

		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
				UTIL= utility (cons,lei)
		    ELSE
		        UTIL=-1.E7
            END IF
                        
			SUR = 1/(1+EXP(c0+c1*AGE+c2*(AGE**2)))  
			

				sum_temp = 0.0
				IF (beqprob(AGE)>0.0) THEN
					IF (IS<=3) THEN
						IF (IR>=2) THEN
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
							END DO 						
						ELSE
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_lowkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
							END DO
						END IF
					ElSE
						IF (IR>=2) THEN
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,2)*VR(AGE+1,:,i,IS))
							END DO 
						ELSE 
							DO i = 1,NGRIDR
								sum_temp = sum_temp + P_r(IR,i,zgroup(IS))*sum(X45_highkid_dist(AGE,JA,:,1)*VR(AGE+1,:,i,IS))
							END DO 
						END IF 
					END IF
				END IF 
				VTEMP = UTIL + BETA*SUR* ( (1.0-beqprob(AGE))*sum(P_r(IR,:,zgroup(IS))*VR(AGE+1,JA,:,IS)) + beqprob(AGE)*sum_temp ) + (1-SUR)*( bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1) )  


            UPDATE5:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    JAMAX = JA
			    JNMAX = 1			  
            END IF UPDATE5

            CASE(MAXAGE)  
			          
		    yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + WAGEZ))**(1.0-tau_l) &
				 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ WAGEZ - bendy) &
				 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans+medicare
			
			CONS = (X3 + yd - A(JA))/(1.0+tau_s)	
			LEI = 1.0
            
		    IF  ((CONS>=CMIN) .AND. (LEI>=LEIMIN)) THEN  
                UTIL= utility(cons,lei) 
		    ELSE
		        UTIL=-1.E7
            END IF

			 VTEMP = UTIL + bcoeff*((beq_aftertax(A(JA))+bcoeff2)**(1-bsigma)-1)

			UPDATE6:  IF (VTEMP>=VMAX) THEN
                VMAX = VTEMP
			    JAMAX = JA
			    JNMAX = 1			  
			    
            END IF UPDATE6
        
        END SELECT

END SUBROUTINE
!******************************************************************

SUBROUTINE BRACKET01(AGE,IA,IR,IS, WAGEZ)
!******************************************************************
!
!   Finds global optimum asset and labor choice for a single state
!
!******************************************************************

IMPLICIT NONE

!PASSED VARIABLES
INTEGER    :: AGE,IA,IR,IS
REAL(PREC) :: WAGEZ

!LOCAL VARIABLES
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
	

101  CALL SRCHFIVE01 (AGE,IA,IR,IS,WAGEZ,JAMAX,JNMAX,VMAX, &
                     ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ,BEQTRANS1)      					 

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
			  ILN = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW08'
           END IF
        END IF NARROW06

          IF (ILN<1) PRINT *, 'Error:  ILN<1 in Subroutine BRACKET'
		  IF (ILN>NGRIDA) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'

        !GO TO 101
        

     END IF NARROW05


		IF (ISKIPA==1 .AND. ISKIPN==1)  THEN
            index_SRCHFIVE01 = 1+index_SRCHFIVE01
		ELSE
            index_SRCHFIVE01 = 0
        END IF
        
		IF (index_SRCHFIVE01 < 2) THEN
           GO TO 101
		END IF
         
	
	 IF (AGE<RETAGE) THEN
	 
	 VW(AGE,IA,IR,IS) = VMAX
	 IDCWA(AGE,IA,IR,IS) = JAMAX
	 IDCWN(AGE,IA,IR,IS) = JNMAX

	 ELSE
	 
	 VR(AGE,IA,IR,IS) = VMAX
     IDCRA(AGE,IA,IR,IS) = JAMAX
	 IDCRN(AGE,IA,IR,IS) = 1
	 
	 END IF
	 

END SUBROUTINE

!***********************************************************

SUBROUTINE check_BRACKET01(AGE,IA,IR,IS, WAGEZ)

!***********************************************************
!   recompute and update the results found in routine BRACKET01
!***********************************************************

IMPLICIT NONE

!PASSED VARIABLES
INTEGER    :: AGE,IA,IR,IS
REAL(PREC) :: WAGEZ

!LOCAL VARIABLES
INTEGER    :: INDEX_SRCHFIVE01,JAMAX,JNMAX,JHMAX,&
              ILA,IUA,ISKIPA,ILN,IUN,ISKIPN
REAL(PREC) :: X3,VMAX 

401 continue
     index_SRCHFIVE01 = 0

	OLD_IDCWA(AGE,IA,IR,IS) = IDCWA(AGE,IA,IR,IS)
	OLD_IDCWN(AGE,IA,IR,IS) = IDCWN(AGE,IA,IR,IS)

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
	
 
201  CALL A_SRCHFIVE01 (AGE,IA,IR,IS, WAGEZ,JAMAX,JNMAX,VMAX, &
                     ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ,BEQTRANS1)  !  Updates VMAX and JAMAX    					 

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

	IF (ISKIPA==1)  THEN
        index_SRCHFIVE01 = 1+index_SRCHFIVE01
	ELSE
        index_SRCHFIVE01 = 0
    END IF
        
	IF (index_SRCHFIVE01 < 2) THEN
       GO TO 201
	END IF
	 
	VW(AGE,IA,IR,IS) = VMAX
	IDCWA(AGE,IA,IR,IS) = JAMAX
	
	index_SRCHFIVE01 = 0
	VMAX = -1.E6
    JAMAX = 1
	JNMAX = 1

301  CALL N_SRCHFIVE01 (AGE,IA,IR,IS,WAGEZ,JAMAX,JNMAX,VMAX, &
                     ILA,IUA,ISKIPA,ILN,IUN,ISKIPN,X3,BEQ,BEQTRANS1)  !  Updates VMAX and JAMAX    					 


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
              PRINT *, 'Error in Subroutine BRACKET at NARROW08'
           END IF
        ELSE
           IF (ISKIPN>=4) THEN
              ISKIPN = ISKIPN/4
              ILN = IUN - 4*ISKIPN
           ELSE IF (ISKIPN==2) THEN
              ISKIPN = 1
			  ILN = NGRIDA - 1
           ELSE
              PRINT *, 'Error in Subroutine BRACKET at NARROW08'
           END IF
        END IF NARROW06

          IF (ILN<1) PRINT *, 'Error:  ILN<1 in Subroutine BRACKET at N_SRCHFIVE01'
		  IF (ILN>NGRIDA) PRINT *, 'Error:  ILN>NGRIDH in Subroutine BRACKET'

        !GO TO 101
        

     END IF NARROW05


		IF (ISKIPN==1)  THEN
            index_SRCHFIVE01 = 1+index_SRCHFIVE01
		ELSE
            index_SRCHFIVE01 = 0
        END IF
        
		IF (index_SRCHFIVE01 < 2) THEN
           GO TO 301
		END IF
        		 
	 VW(AGE,IA,IR,IS) = VMAX
	 IDCWN(AGE,IA,IR,IS) = JNMAX


	IF((OLD_IDCWA(AGE,IA,IR,IS) /= IDCWA(AGE,IA,IR,IS)) .AND. (OLD_IDCWN(AGE,IA,IR,IS) /= IDCWN(AGE,IA,IR,IS))) THEN
		GO TO 401
	END IF 


END SUBROUTINE
!******************************************************************

SUBROUTINE DECRULE01

!*************************************************
!	Finds optimal asset and labor choice for all states
!*************************************************

IMPLICIT NONE

INTEGER    ::  AGE,IA,IR,IS
REAL(PREC) ::  LEI, CONS, WAGEZ
    IS = 1
!   Initialize value function and decision rules

    DO AGE=1,RETAGE-1
        DO IA=1,NGRIDA
		   DO IR=1,NGRIDR
                DO IS=1,nn
 
				  VW(AGE,IA,IR,IS) = -10000.0000
                  IDCWA(AGE,IA,IR,IS) = -1
			      IDCWN(AGE,IA,IR,IS) = -1

                END DO
           END DO
        END DO
    END DO

    DO AGE=RETAGE,MAXAGE
        DO IA=1,NGRIDA
		   	DO IR=1,NGRIDR
				DO IS=1,nn 
 
					VR(AGE,IA,IR,IS) = -10000.0000
					IDCRA(AGE,IA,IR,IS) = -1			
					IDCRN(AGE,IA,IR,IS) = -1
			 

			    END DO 
           END DO
        END DO
    END DO
     

!   Remaining retirees
!$OMP PARALLEL DEFAULT(NONE) &
!$OMP & PRIVATE(WAGEZ,IS,AGE,IA,IR) &
!$OMP & SHARED(VW,VR,IDCWA,IDCWN,IDCRA,IDCRN,SS, &
!$OMP &        EFFLONG,W,wage)
    
DO AGE=MAXAGE,RETAGE,-1
 	DO IS=1,nn 
    WAGEZ = SS(IS)     
        
		DO IR=1,NGRIDR
		  !$OMP DO
			DO IA=1,NGRIDA
              
			  CALL BRACKET01(AGE,IA,IR,IS, WAGEZ)
			  
		    END DO
		    !$OMP END DO
        END DO 
    END DO
END DO 
!   Working-age agents

    DO AGE=RETAGE-1,1,-1       
		 DO IR=1,NGRIDR
		  !$OMP DO	
			DO IA=1,NGRIDA			   
                DO IS =1,nn   
                    
					WAGEZ = WAGE*EFFLONG(AGE)*W(IS)
                   
					CALL BRACKET01(AGE,IA,IR,IS, WAGEZ)
					
					CALL check_BRACKET01(AGE,IA,IR,IS, WAGEZ)
                END DO
            END DO
			!$OMP END DO
        END DO
    END DO
	!$OMP END PARALLEL
END SUBROUTINE

!*********************************

SUBROUTINE INVAR01
!*********************************
!   Finds invariant distribution
!*********************************

!   Initialize age-dependent distributions

     DO AGE=1,RETAGE-1
        DO IA=1,NGRIDA
		    DO IR=1,NGRIDR
			  DO IS=1,nn 
				 YW(AGE,IA,IR,IS)=0.0
			  END DO
           END DO
        END DO
    END DO

	DO AGE=RETAGE,MAXAGE
        DO IA=1,NGRIDA          
		   DO IR=1,NGRIDR
              DO IS=1,nn 
			  	 YR(AGE,IA,IR,IS)=0.0
			  END DO
           END DO
        END DO
    END DO


! Assume everyone start with either r1 or r2 but not r3 according to the egrodic return dist
	 YW(1,ZEROINDEX,1,1)=invar(1)*SSprob_r(1,1)		! z1,r1
	 YW(1,ZEROINDEX,2,1)=invar(1)*SSprob_r(1,2)		! z1,r2
	 YW(1,ZEROINDEX,1,2)=invar(2)*SSprob_r(1,1)		! z2,r1
	 YW(1,ZEROINDEX,2,2)=invar(2)*SSprob_r(1,2)		! z2,r2
	 YW(1,ZEROINDEX,1,3)=invar(3)*SSprob_r(1,1)		! z3,r1
	 YW(1,ZEROINDEX,2,3)=invar(3)*SSprob_r(1,2)		! z3,r2
	 YW(1,ZEROINDEX,1,4)=invar(4)*SSprob_r(1,1)		! z4,r1
	 YW(1,ZEROINDEX,2,4)=invar(4)*SSprob_r(1,2)		! z4,r2
	 YW(1,ZEROINDEX,1,5)=invar(5)*SSprob_r(1,1)		! z5,r1
	 YW(1,ZEROINDEX,2,5)=invar(5)*SSprob_r(1,2)		! z5,r2
	 YW(1,ZEROINDEX,1,6)=invar(6)*SSprob_r(1,1)		! z6,r1
	 YW(1,ZEROINDEX,2,6)=invar(6)*SSprob_r(1,2)		! z6,r2
	 YW(1,ZEROINDEX,1,7)=invar(7)*SSprob_r(1,1)		! z7,r1
	 YW(1,ZEROINDEX,2,7)=invar(7)*SSprob_r(1,2)		! z7,r2
	 YW(1,ZEROINDEX,1,8)=invar(8)*SSprob_r(1,1)		! z8,r1
	 YW(1,ZEROINDEX,2,8)=invar(8)*SSprob_r(1,2)		! z8,r2

	 YW(1,ZEROINDEX,:,:)=YW(1,ZEROINDEX,:,:)/(SSprob_r(1,1)+SSprob_r(1,2))


	DO AGE=2,RETAGE-1
        DO IA=1,NGRIDA
		   	DO IR=1,NGRIDR

				IF (beqprob(AGE-1) /= 1.0) THEN
					DO IS=1,nn							
						JA = IDCWA(AGE-1,IA,IR,IS)							
						DO NEWR=1,NGRIDR
							DO NEWZ=1,nn
										
								YW(AGE,JA,NEWR,NEWZ) = YW(AGE,JA,NEWR,NEWZ) + (1.0-beqprob(AGE-1))*YW(AGE-1,IA,IR,IS)*P(IS,NEWZ)*P_r(IR,NEWR,zgroup(IS))
					
							END DO
						END DO
					END DO
				END IF 

				IF (beqprob(AGE-1)>0.0) THEN

					DO IS=1,3	
						JA = IDCWA(AGE-1,IA,IR,IS)
						DO NEWZ = 1,nn
							DO NEWR = 1,NGRIDR
								DO XA = JA,NGRIDA
									IF (IR .ge. 2) THEN 											
										YW(AGE,XA,NEWR,NEWZ) = YW(AGE,XA,NEWR,NEWZ) + beqprob(AGE-1)*YW(AGE-1,IA,IR,IS)*P(IS,NEWZ)*P_r(IR,NEWR,zgroup(IS))*X45_lowkid_dist(AGE-1,JA,XA,2)
									ELSE 
										YW(AGE,XA,NEWR,NEWZ) = YW(AGE,XA,NEWR,NEWZ) + beqprob(AGE-1)*YW(AGE-1,IA,IR,IS)*P(IS,NEWZ)*P_r(IR,NEWR,zgroup(IS))*X45_lowkid_dist(AGE-1,JA,XA,1)
									END IF 
								END DO
							END DO
						END DO
					END DO

					DO IS = 4,8	
						JA = IDCWA(AGE-1,IA,IR,IS)
						DO NEWZ = 1,nn
							DO NEWR = 1,NGRIDR
								DO XA = JA,NGRIDA
									IF (IR .ge. 2) THEN 									
										YW(AGE,XA,NEWR,NEWZ) = YW(AGE,XA,NEWR,NEWZ) + beqprob(AGE-1)*YW(AGE-1,IA,IR,IS)*P(IS,NEWZ)*P_r(IR,NEWR,zgroup(IS))*X45_highkid_dist(AGE-1,JA,XA,2)
									ELSE 
										YW(AGE,XA,NEWR,NEWZ) = YW(AGE,XA,NEWR,NEWZ) + beqprob(AGE-1)*YW(AGE-1,IA,IR,IS)*P(IS,NEWZ)*P_r(IR,NEWR,zgroup(IS))*X45_highkid_dist(AGE-1,JA,XA,1)
									END IF 
								END DO
							END DO
						END DO
					END DO

				END IF 
			
           END DO
        END DO
    END DO


AGE = RETAGE
	DO IA=1,NGRIDA
	   	DO IR=1,NGRIDR


				IF (beqprob(AGE-1) /= 1.0) THEN
					DO IS=1,nn
						DO NEWR = 1,NGRIDR
						
							JA = IDCWA(RETAGE-1,IA,IR,IS)					
							YR(RETAGE,JA,NEWR,IS) = YR(RETAGE,JA,NEWR,IS) + (1.0-beqprob(AGE-1))*YW(RETAGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))

						END DO
					END DO
				END IF 

				IF (beqprob(AGE-1)>0.0) THEN

					DO IS=1,3	
						JA = IDCWA(RETAGE-1,IA,IR,IS)				
						DO NEWR = 1,NGRIDR
							DO XA = JA,NGRIDA
								IF (IR .ge. 2) THEN 
									YR(RETAGE,XA,NEWR,IS) = YR(RETAGE,XA,NEWR,IS) + beqprob(AGE-1)*YW(RETAGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_lowkid_dist(AGE-1,JA,XA,2)
								ELSE 
									YR(RETAGE,XA,NEWR,IS) = YR(RETAGE,XA,NEWR,IS) + beqprob(AGE-1)*YW(RETAGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_lowkid_dist(AGE-1,JA,XA,1)
								END IF 
							END DO
						END DO				
					END DO

					DO IS = 4,8	
						JA = IDCWA(RETAGE-1,IA,IR,IS)
						DO NEWR = 1,NGRIDR
							DO XA = JA,NGRIDA
								IF (IR .ge. 2) THEN 
									YR(RETAGE,XA,NEWR,IS) = YR(RETAGE,XA,NEWR,IS) + beqprob(AGE-1)*YW(RETAGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_highkid_dist(AGE-1,JA,XA,2)
								ELSE 
									YR(RETAGE,XA,NEWR,IS) = YR(RETAGE,XA,NEWR,IS) + beqprob(AGE-1)*YW(RETAGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_highkid_dist(AGE-1,JA,XA,1)
								END IF 
							END DO
						END DO				
					END DO

				END IF 


       	END DO
    END DO


	DO AGE=RETAGE+1,MAXAGE
        DO IA=1,NGRIDA
		   	DO IR=1,NGRIDR


					IF (beqprob(AGE-1) /= 1.0) THEN
						DO IS=1,nn
							DO NEWR = 1,NGRIDR
												
								JA = IDCRA(AGE-1,IA,IR,IS)
								YR(AGE,JA,NEWR,IS) = YR(AGE,JA,NEWR,IS) + (1.0-beqprob(AGE-1))*YR(AGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))
												
							END DO
						END DO
					END IF 

					IF (beqprob(AGE-1)>0.0) THEN

						DO IS=1,3	
							JA = IDCRA(AGE-1,IA,IR,IS)			
							DO NEWR = 1,NGRIDR
								DO XA = JA,NGRIDA
									IF (IR .ge. 2) THEN 
										YR(AGE,XA,NEWR,IS) = YR(AGE,XA,NEWR,IS) + beqprob(AGE-1)*YR(AGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_lowkid_dist(AGE-1,JA,XA,2)
									ELSE 
										YR(AGE,XA,NEWR,IS) = YR(AGE,XA,NEWR,IS) + beqprob(AGE-1)*YR(AGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_lowkid_dist(AGE-1,JA,XA,1)
									END IF 
								END DO
							END DO				
						END DO

						DO IS = 4,8	
							JA = IDCRA(AGE-1,IA,IR,IS)	
							DO NEWR = 1,NGRIDR
								DO XA = JA,NGRIDA
									IF (IR .ge. 2) THEN 
										YR(AGE,XA,NEWR,IS) = YR(AGE,XA,NEWR,IS) + beqprob(AGE-1)*YR(AGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_highkid_dist(AGE-1,JA,XA,2)
									ELSE 
										YR(AGE,XA,NEWR,IS) = YR(AGE,XA,NEWR,IS) + beqprob(AGE-1)*YR(AGE-1,IA,IR,IS)*P_r(IR,NEWR,zgroup(IS))*X45_highkid_dist(AGE-1,JA,XA,1)
									END IF 
								END DO
							END DO										
						END DO
					
					END IF


           	END DO
        END DO
    END DO


 END SUBROUTINE
!******************************************************************

SUBROUTINE PROFILE01
!****************************************************************
!   Finds age profiles for income, consumption, and assets
!****************************************************************

!  Working-age agents
    DO AGE=1,RETAGE-1                 
        ALONG(AGE) = 0.0
        CLONG(AGE) = 0.0
        ILONG(AGE) = 0.0
        NLONG(AGE) = 0.0
        LLONG(AGE) = 0.0
	    TILONG(AGE) = 0.0
		BLONG(AGE) = 0.0
        
        DO IA=1,NGRIDA
			DO IR=1,NGRIDR
                DO IS=1,nn
                    
                    !  Assets
					JA = IDCWA(AGE,IA,IR,IS)
					ALONG(AGE) = ALONG(AGE) + A(IA)*YW(AGE,IA,IR,IS)

					! Bequest
					BLONG(AGE) = BLONG(AGE) + beq_aftertax(A(JA))*YW(AGE,IA,IR,IS)

                    ! Efficiency labor & Working hours
					JN = IDCWN(AGE,IA,IR,IS)
                    NLONG(AGE) = NLONG(AGE) + N(JN)*YW(AGE,IA,IR,IS)*W(IS)
                    LLONG(AGE) = LLONG(AGE) + N(JN)*YW(AGE,IA,IR,IS)
						  
			        !  Pre Tax Labor Income 
                    INCOME     = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
					ILONG(AGE) = ILONG(AGE) + INCOME*YW(AGE,IA,IR,IS)
										
					! Pre Tax Total Income
					TINCOME	= min(R(IR)*A(IA),d_c) + INCOME + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + BEQTRANS1					
					TILONG(AGE) = TILONG(AGE) + TINCOME*YW(AGE,IA,IR,IS)

                    
					! Disposable income
                    yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + INCOME))**(1.0-tau_l) &
				 		  +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ INCOME - bendy) &						  
						  +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)

					X3 =   A(IA) + BEQTRANS1

					!  Consumption
					CONS = (X3 + yd - A(JA))/(1.0+tau_s)
					CLONG(AGE) = CLONG(AGE) + CONS*YW(AGE,IA,IR,IS)
                END DO			  
            END DO
        END DO
    END DO
    
	!  Retirees
    DO AGE=RETAGE,MAXAGE              
        ALONG(AGE) = 0.0
        CLONG(AGE) = 0.0
        ILONG(AGE) = 0.0   
		TILONG(AGE) = 0.0
		BLONG(AGE) = 0.0
        
        DO IA=1,NGRIDA
             DO IR=1,NGRIDR
			 	DO IS=1,nn 

                !  Assets                
				JA = IDCRA(AGE,IA,IR,IS)
			    IF (JA<1) THEN
			    JA = 1
			    END IF
        
				ALONG(AGE) = ALONG(AGE) + A(IA)*YR(AGE,IA,IR,IS)
				BLONG(AGE) = BLONG(AGE) + beq_aftertax(A(JA))*YR(AGE,IA,IR,IS)
			  			  
 		        !  Total income             
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) !+ SS(IS)                 
				TILONG(AGE) = TILONG(AGE) + TINCOME*YR(AGE,IA,IR,IS)

				
				! Disposable Income
				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + SS(IS)))**(1.0-tau_l) &
				 	 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+ SS(IS) - bendy) &					 
					 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)

				!  Consumption
				X3 = A(IA)
				CONS = (X3 + yd - A(JA))/(1.0+tau_s)
                CLONG(AGE) = CLONG(AGE) + CONS*YR(AGE,IA,IR,IS)

				END DO
            END DO
        END DO
    END DO

!   Compute cross-sectional profiles for a given time period

    DO AGE=1,MAXAGE
        ACROSS(AGE) = ALONG(AGE)
        CCROSS(AGE) = CLONG(AGE)
        ICROSS(AGE) = ILONG(AGE)
	    TICROSS(AGE)= TILONG(AGE)
        NCROSS(AGE) = NLONG(AGE)
        LCROSS(AGE) = LLONG(AGE)
		BCROSS(AGE) = BLONG(AGE)
    END DO
 
END SUBROUTINE
!******************************************************************

SUBROUTINE compute_distributions
	
	ALLOCATE( D_YW(MAXAGE,NGRIDA,NGRIDR,nn) )
	ALLOCATE( D_YR(MAXAGE,NGRIDA,NGRIDR,nn) )
	
	!*******************************************Initialize Sur-adjusted joint distributions********************************************

	     DO AGE=1,RETAGE-1
	        DO IA=1,NGRIDA
			   DO IR=1,NGRIDR
				  DO IS=1,nn
                 
					  D_YW(AGE,IA,IR,IS)=0.0
				  END DO
	           END DO
	        END DO
	     END DO

		DO AGE=RETAGE,MAXAGE
	        DO IA=1,NGRIDA
			    DO IR=1,NGRIDR
					DO IS=1,nn
				 	 	D_YR(AGE,IA,IR,IS)=0.0
				  	END DO 
	           END DO
	        END DO
	     END DO
	
	! use invariant distribution or unconditional distribution of labor productivity	
	
	    DO AGE = 1,RETAGE-1		
	        DO IA = 1,NGRIDA            
				DO IR = 1,NGRIDR
	                DO IS = 1,nn                                                                                                                                                      
                    
					 D_YW(AGE,IA,IR,IS) = YW(AGE,IA,IR,IS)*MU(AGE)								
				 
	                END DO
	            END DO
	        END DO
	    END DO


		DO AGE=RETAGE,MAXAGE
	        DO IA=1,NGRIDA
			   DO IR=1,NGRIDR
			      DO IS=1,nn

				  D_YR(AGE,IA,IR,IS) = YR(AGE,IA,IR,IS)*MU(AGE) 	

		          END DO
	           END DO
	        END DO
	     END DO



SUM_D_YW = 0.0
DO AGE = 1,RETAGE-1		
	DO IA = 1,NGRIDA            
		DO IR = 1,NGRIDR
			DO IS = 1,nn                                                                                                                                                      
			
				SUM_D_YW = SUM_D_YW+ YW(AGE,IA,IR,IS)*MU(AGE)								
			
			END DO
		END DO
	END DO
END DO


SUM_D_YR = 0.0
DO AGE=RETAGE,MAXAGE
	DO IA=1,NGRIDA
		DO IR=1,NGRIDR
			DO IS=1,nn

				SUM_D_YR = SUM_D_YR + YR(AGE,IA,IR,IS)*MU(AGE) 	

			END DO
		END DO
	END DO
END DO



END SUBROUTINE ! compute_distributions
!******************************************************************


SUBROUTINE compute_gini

!******************************************************
!   Finds age profiles for Gini coefficients
!******************************************************
	
! Compute Gini

	ALLOCATE( X((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn, 4) )  ! wealth: x(:,1), labor income: x(:,2), total income: x(:,3) , consumption: x(:,4)       
	ALLOCATE( D((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )	
	ALLOCATE( D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn ) )
	ALLOCATE( D_A( (RETAGE-1-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn ) )
	
	
    IY = 0   
    IX = 0
    DO AGE = 1,RETAGE-1
        DO IA = 1,NGRIDA
           ! DO IH = 1,NGRIDH
			DO IR = 1,NGRIDR
                DO IS = 1,nn 
				
                    IX = IX + 1 					

						JA = IDCWA(AGE,IA,IR,IS)
						JN = IDCWN(AGE,IA,IR,IS)
						INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
						
						IF (AGE>=2) THEN
						IY = IY + 1
						x(IY,1) = A(IA) 	!x(IX,1) = A(JA)  ! Wealth level at the begining of each period
						END IF

						x(IX,2) = WAGE*EFFLONG(AGE)*N(JN)*W(IS)	! pretax labor income											
						
						x(IX,3)	= min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 
						
						! Disposable income
						yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + INCOME))**(1.0-tau_l) &
							+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c) + INCOME - bendy) &
							+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)
						
						! consumption
						X3 =   A(IA) + BEQTRANS1 + gov_trans 					 
						x(IX,4)	= X3 + yd - A(JA)

				END DO
            END DO
        END DO
    END DO
    

	DO AGE = RETAGE,MAXAGE
        DO IA = 1,NGRIDA
			DO IR = 1,NGRIDR 			
				DO IS =1,nn 

                	IX = IX + 1 
					IY = IY + 1                                                                                                   
 
					JA = IDCRA(AGE,IA,IR,IS)     
                	x(IY,1) = A(IA)		

					x(IX,2) = 0.0

					x(IX,3) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)  

					yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + SS(IS) ))**(1.0-tau_l) &
						 +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+SS(IS) - bendy) &
						 +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)

					X3 =  A(IA)	+ gov_trans + medicare
					x(IX,4)	= X3 + yd - A(JA)  

				END DO 
            END DO
        END DO
    END DO 
     
	ID = 0
	IDA = 0
    DO AGE = 1,RETAGE-1
        DO IA = 1,NGRIDA
			DO IR = 1,NGRIDR
                DO IS = 1,nn                                                                                                                                                        
                    ID = ID + 1                                                                                                    
 
					D(ID) = D_YW(AGE,IA,IR,IS)
					D_inc(ID) = D_YW(AGE,IA,IR,IS)

					IF (AGE>=2)	THEN
					IDA = IDA+1
					D_A(IDA) = D_YW(AGE,IA,IR,IS)
					END IF 

                END DO
            END DO
        END DO
    END DO	    

	DO AGE = RETAGE,MAXAGE   
        DO IA = 1,NGRIDA
			DO IR = 1,NGRIDR  			
				DO IS = 1,nn 

                    ID = ID + 1                                                                                                    
                    IDA = IDA+1

					D(ID) = D_YR(AGE,IA,IR,IS)						
					D_A(IDA) = D_YR(AGE,IA,IR,IS)	

				END DO 	
            END DO
        END DO
    END DO

   D(:) = D(:)/sum(D)
   D_inc(:) = D_inc(:)/sum(D_inc)
   D_A(:) = D_A(:)/sum(D_A)

    wea_gini = gini(x(1:SIZE(D_A),1),D_A)	!gini(x(:,1),D)
	inc_gini = gini(x(1:SIZE(D_inc),2),D_inc) ! earning gini
	inc_gini_fullpopu = gini(x(:,2),D) ! earning gini
	tinc_gini = gini(x(:,3),D) 		! ygini, full population
	cons_gini = gini(x(:,4),D)		!cgini


! !Variance of log earnings

mean_incvar = 0.0
DO i=1,(RETAGE-1)*NGRIDA*NGRIDR*nn
	IF (x(i,2)>0.0) THEN 
		mean_incvar = mean_incvar + log(x(i,2))*D_inc(i)
	END IF 
END DO 

incvar = 0.0
DO i=1,(RETAGE-1)*NGRIDA*NGRIDR*nn
	IF (x(i,2)>0.0) THEN 
		incvar = incvar + ((log(x(i,2))-mean_incvar)**2)*D_inc(i)
	END IF 
END DO 

 
  
END SUBROUTINE
!******************************************************************

SUBROUTINE age_wealth_gini 

	ALLOCATE( x_age(NGRIDA*NGRIDR*nn, MAXAGE) )
	ALLOCATE( tinc_age(NGRIDA*NGRIDR*nn, MAXAGE) )
	ALLOCATE( e_age(NGRIDA*NGRIDR*nn, MAXAGE) ) 
    ALLOCATE( D_age(NGRIDA*NGRIDR*nn, MAXAGE), NorD_age(NGRIDA*NGRIDR*nn, MAXAGE) )
    ALLOCATE( age_wea_gini(MAXAGE) )
	ALLOCATE( age_inc_gini(MAXAGE) )
	ALLOCATE( age_tinc_gini(MAXAGE) )
    
    
    DO AGE = 1,RETAGE-1
        IX = 0
        DO IA = 1,NGRIDA
			DO IR = 1,NGRIDR
                DO IS = 1,nn                                                                                                                                                        
                    IX = IX + 1                                                                                                    
                    
					JA = IDCWA(AGE,IA,IR,IS)
					JN = IDCWN(AGE,IA,IR,IS)
					INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
					x_age(IX,AGE) = A(JA)	
					tinc_age(IX,AGE) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)  + INCOME 
					e_age(IX,AGE) = INCOME				
                END DO
            END DO
        END DO
    END DO
    
     DO AGE = RETAGE,MAXAGE           
         IX = 0
         DO IA = 1,NGRIDA             
			DO IR = 1,NGRIDR 	
				DO IS = 1,nn 

					IX = IX + 1                                                                                                    
					
					JA = IDCRA(AGE,IA,IR,IS)
					x_age(IX,AGE) = A(JA)	  
					tinc_age(IX,AGE) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) 	
					e_age(IX,AGE) = 0.0 

				END DO                
            END DO
        END DO
     END DO 

    
    DO AGE = 1,RETAGE-1
        ID = 0
        DO IA = 1,NGRIDA
			DO IR = 1,NGRIDR
                DO IS = 1,nn                                                                                                                                                        
                    
                    ID = ID + 1                                                                                                    
					D_age(ID,AGE) = D_YW(AGE,IA,IR,IS)

                END DO
            END DO
        END DO
    END DO
    
    DO AGE = RETAGE,MAXAGE
        ID = 0
        DO IA = 1,NGRIDA  
			DO IR = 1,NGRIDR 	
				DO IS = 1,nn 		
                    
                	ID = ID + 1                                                                                                    
					D_age(ID,AGE) = D_YR(AGE,IA,IR,IS)

				END DO 		
            END DO
        END DO
    END DO


!Normalize the D_age    
DO AGE = 1,MAXAGE 
   NorD_age(:,AGE) = D_age(:,AGE)/sum(D_age(:,AGE))    
END DO


   DO AGE = 1,MAXAGE
      age_wea_gini(AGE) = gini(x_age(:,AGE), NorD_age(:,AGE))
	  age_inc_gini(AGE) = gini(e_age(:,AGE), NorD_age(:,AGE))
	  age_tinc_gini(AGE) = gini(tinc_age(:,AGE), NorD_age(:,AGE))
   END DO

END SUBROUTINE
!****************************************************************************************************

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

ALLOCATE( sort_A(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( cum_sort_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0001pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0005pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top001pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top005pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top01pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top05pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top1pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top5pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top10pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top20pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top40pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top50pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top60pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top70pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top80pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top90pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top95pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( top99pct_D(MAXAGE*NGRIDA*NGRIDR*nn) )
ALLOCATE( record_position_A(MAXAGE*NGRIDA*NGRIDR*nn) )


 
index_A = 0
DO AGE=1,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn

               index_A = index_A + 1
			   sort_A(index_A) = A(IA)
			   if (AGE<RETAGE) then
				   sort_D(index_A) = D_YW(AGE,IA,IR,IS)
			   else
				   sort_D(index_A) = D_YR(AGE,IA,IR,IS)
			   end if
			   record_position_A(index_A) = index_A

            END DO
        END DO
    END DO
END DO

! the following two lines replicate what one could do with sortrows in Matlab:
CALL SSORT_INT(sort_A,record_position_A,size(sort_A),2)
sort_D = sort_D(record_position_A)
sort_D = sort_D/sum(sort_D)

cum_sort_D(1) = sort_D(1)
DO i = 2,size(sort_D)
	cum_sort_D(i) = cum_sort_D(i-1)+sort_D(i)
END DO


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


Aggwealth = dot_product(sort_A,sort_D)
	
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

! Group wealth relative to average wealth:
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

	share_zero_k = 0.0
	DO AGE=1,RETAGE-1
		DO IR=1,NGRIDR
			DO IS=1,nn
				share_zero_k = share_zero_k + D_YW(AGE,1,IR,IS)
			END DO 
		END DO 
	END DO

	DO AGE=RETAGE,MAXAGE-1
		DO IR=1,NGRIDR
			DO IS=1,nn  
				share_zero_k = share_zero_k + D_YR(AGE,1,IR,IS)
			END DO 
		END DO 
	END DO
	print*, 'share_zero_k=',share_zero_k

! 	find threshold for being in the top 0.1, 0.5, 1, 5, 10, 20, 40, ,50, 60% of wealth
	do i = size(sort_D), 1, -1
  		if (top0001pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold0001 = sort_A(j+1)
  	else
  		wealththreshold0001 = sort_A(j)
  	end if


	do i = size(sort_D), 1, -1
  		if (top01pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold01 = sort_A(j+1)
  	else
  		wealththreshold01 = sort_A(j)
  	end if

	do i = size(sort_D), 1, -1
  		if (top05pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold05 = sort_A(j+1)
  	else
  		wealththreshold05 = sort_A(j)
  	end if

	do i = size(sort_D), 1, -1
  		if (top1pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold1 = sort_A(j+1)
  	else
  		wealththreshold1 = sort_A(j)
  	end if
	
	do i = size(sort_D), 1, -1
  		if (top5pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold5 = sort_A(j+1)
  	else
  		wealththreshold5 = sort_A(j)
  	end if

	do i = size(sort_D), 1, -1
  		if (top10pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold10 = sort_A(j+1)
  	else
  		wealththreshold10 = sort_A(j)
  	end if
	
	do i = size(sort_D), 1, -1
  		if (top20pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold20 = sort_A(j+1)
  	else
  		wealththreshold20 = sort_A(j)
  	end if

	do i = size(sort_D), 1, -1
  		if (top40pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold40 = sort_A(j+1)
  	else
  		wealththreshold40 = sort_A(j)
  	end if

	do i = size(sort_D), 1, -1
  		if (top50pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold50 = sort_A(j+1)
  	else
  		wealththreshold50 = sort_A(j)
  	end if

	do i = size(sort_D), 1, -1
  		if (top60pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold60 = sort_A(j+1)
  	else
  		wealththreshold60 = sort_A(j)
  	end if

	do i = size(sort_D), 1, -1
  		if (top80pct_D(i) < 1) then
  			j = i
  			exit
  		end if
  	end do
  	if (j < size(sort_D)) then 
  		wealththreshold80 = sort_A(j+1)
  	else
  		wealththreshold80 = sort_A(j)
  	end if  


	
END SUBROUTINE
!**************************************************************************************************************

SUBROUTINE wageshare

ALLOCATE( sort_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( cum_sort_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0001pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0005pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top001pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top005pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0039pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top01pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top025pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top05pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top1pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top5pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top10pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top20pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top39pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top40pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top50pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top60pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top70pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top80pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( record_position_E( (RETAGE-1)*NGRIDA*NGRIDR*nn ) )


isort=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                   
                
				isort=isort+1  
				JN=IDCWN(AGE,IA,IR,IS)   				
                sort_INC(isort) =  WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				sort_D_inc(isort) = D_YW(AGE,IA,IR,IS)
           	 	record_position_E(isort) = isort

            END DO
        END DO 
    END DO
END DO
sort_D_inc = sort_D_inc/sum(sort_D_inc)


CALL SSORT_INT(sort_INC,record_position_E,size(sort_INC),2)
sort_D_inc = sort_D_inc(record_position_E)
sort_D_inc = sort_D_inc/sum(sort_D_inc)


cum_sort_D_inc(1) = sort_D_inc(1)
DO i = 2,size(sort_D_inc)
	cum_sort_D_inc(i) = cum_sort_D_inc(i-1)+sort_D_inc(i)
END DO


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


! Probability of staying in Top1% of earnings distribution

! threshold of top1% earnings
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

poputop1 = 0.0
staytop1 = 0.0
DO AGE=1,RETAGE-2
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                   
                  
				JN=IDCWN(AGE,IA,IR,IS) 
				JA=IDCWA(AGE,IA,IR,IS)   				
                IF ( WAGE*EFFLONG(AGE)*N(JN)*W(IS) >= earningthreshold1 ) THEN 
					poputop1 = poputop1 + D_YW(AGE,IA,IR,IS)

					DO NEWIR=1,NGRIDR
            			DO NEWIS=1,nn 
							IF ( WAGE*EFFLONG(AGE+1)*N(IDCWN(AGE+1,JA,NEWIR,NEWIS))*W(NEWIS) >= earningthreshold1 ) THEN 
								staytop1 = staytop1 + D_YW(AGE,IA,IR,IS)*P(IS,NEWIS)*P_r(IR,NEWIR,zgroup(IS))
							END IF  
						END DO 
					END DO

				END IF 
					           
            END DO
        END DO 
    END DO
END DO

END SUBROUTINE
!************************************************************************************************************

SUBROUTINE totalincomeshare

ALLOCATE( sort_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_tinc_no_transf((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_D_TINC((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_D_tinc_no_transf((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( cum_sort_D_TINC((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( cum_sort_D_tinc_no_transf((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0001pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0005pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top001pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top005pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top01pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top025pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top05pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top1pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top1pct_D_tinc_no_transf((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top5pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top10pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top10pct_D_tinc_no_transf((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top20pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top40pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top50pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top60pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top70pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top80pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top90pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top95pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top99pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot20pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( record_position_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( record_position_tinc_no_transf((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( ind_z((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( ind_r((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )

isort=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                   
                
				isort=isort+1                
				JN=IDCWN(AGE,IA,IR,IS) 								
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)				
            
				sort_TINC(isort) =  min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 				
				sort_tinc_no_transf(isort) =  min(R(IR)*A(IA),d_c) + INCOME 
			
				sort_D_TINC(isort) = D_YW(AGE,IA,IR,IS)
				sort_D_TINC_no_transf(isort) = D_YW(AGE,IA,IR,IS)
				record_position_tinc(isort) = isort
				record_position_tinc_no_transf(isort) = isort
				
				ind_z(isort) = IS
				ind_r(isort) = IR

            END DO
        END DO 
    END DO
END DO			    

!  Total income in retirement period
 
DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR  
			DO IS=1,nn 
            
            isort=isort+1

			sort_TINC(isort) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) 
			sort_tinc_no_transf(isort) = min(R(IR)*A(IA),d_c) 
			
			sort_D_TINC(isort) = D_YR(AGE,IA,IR,IS)
			sort_D_TINC_no_transf(isort) = D_YR(AGE,IA,IR,IS)
			record_position_tinc(isort) = isort
			record_position_tinc_no_transf(isort) = isort

			ind_z(isort) = IS
			ind_r(isort) = IR

			END DO 
        END DO 
    END DO
END DO  


CALL SSORT_INT(sort_Tinc,record_position_tinc,size(sort_Tinc),2)
sort_D_tinc = sort_D_tinc(record_position_tinc)
sort_D_TINC(:) = sort_D_TINC(:)/sum(sort_D_TINC)

! also sort top z and r indicators
ind_z = ind_z(record_position_tinc)
ind_r = ind_r(record_position_tinc)


CALL SSORT_INT(sort_tinc_no_transf,record_position_tinc_no_transf,size(sort_tinc_no_transf),2)
sort_D_tinc_no_transf = sort_D_tinc_no_transf(record_position_tinc_no_transf)
sort_D_tinc_no_transf(:) = sort_D_tinc_no_transf(:)/sum(sort_D_tinc_no_transf)


cum_sort_D_TINC(1) = sort_D_TINC(1)
DO i = 2,size(sort_D_TINC)
	cum_sort_D_TINC(i) = cum_sort_D_TINC(i-1)+sort_D_TINC(i)
END DO


cum_sort_D_tinc_no_transf(1) = sort_D_tinc_no_transf(1)
DO i = 2,size(sort_D_tinc_no_transf)
	cum_sort_D_tinc_no_transf(i) = cum_sort_D_tinc_no_transf(i-1)+sort_D_tinc_no_transf(i)
END DO


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

DO i = 1,size(sort_D_tinc_no_transf)
	top1pct_D_tinc_no_transf(i) = 0
	top10pct_D_tinc_no_transf(i) = 0
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

where ( cum_sort_D_tinc_no_transf(1:size(sort_D_tinc_no_transf)) > 1-0.01 ) top1pct_D_tinc_no_transf = 1
where ( cum_sort_D_tinc_no_transf(1:size(sort_D_tinc_no_transf)) > 1-0.1 ) top10pct_D_tinc_no_transf = 1

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

END SUBROUTINE
!************************************************************************************************************

SUBROUTINE consumptionshare

ALLOCATE( IDCWC(1:RETAGE-1,NGRIDA,NGRIDR,nn) )
ALLOCATE( IDCRC(RETAGE:MAXAGE,NGRIDA,NGRIDR,nn) )
ALLOCATE( sort_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )    
ALLOCATE( sort_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( cum_sort_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0001pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top0005pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top001pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top01pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top05pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top1pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top5pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top10pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top20pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top40pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top50pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top60pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top70pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top80pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top90pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top95pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top99pct_D_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( box_C((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )


isort=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                    
                               
                isort=isort+1
                JN = IDCWN(AGE,IA,IR,IS) 
				JA = IDCWA(AGE,IA,IR,IS)           
                
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				yd	= lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + INCOME))**(1.0-tau_l) &
						  +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+INCOME - bendy) &
						  +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans

				X3 =   A(IA) + BEQTRANS1
				IDCWC(AGE,IA,IR,IS) = (X3 + yd - A(JA))/(1.0+tau_s)

				sort_C(isort) = IDCWC(AGE,IA,IR,IS)
                  
            END DO
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR
			DO IS=1,nn
                        
            isort=isort+1           
			JA=IDCRA(AGE,IA,IR,IS)
            
			INCOME = SS(IS)
			yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + INCOME))**(1.0-tau_l) &
						  +(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+INCOME - bendy) &
						  +(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)+gov_trans+medicare
						  
			X3 = A(IA)
			IDCRC(AGE,IA,IR,IS) = (X3 + yd - A(JA))/(1.0+tau_s)

			sort_C(isort) = IDCRC(AGE,IA,IR,IS)

			END DO 
        END DO 
    END DO
END DO                


CALL sorting(size(sort_C),sort_C)       ! sort in ascending order

DO i = 1,size(sort_C)
	box_C(i)= 0
END DO

index_C = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn
               index_C = index_C + 1
               
                i = search(IDCWC(AGE,IA,IR,IS), sort_C, box_C,1.D-4)             
				sort_D_C(i) = D_YW(AGE,IA,IR,IS)  
                
            END DO
        END DO
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
			DO IS=1,nn
            index_A = index_A + 1	
            				
            i = search(IDCRC(AGE,IA,IR,IS), sort_C, box_C,1.D-4)    
			sort_D_C(i) = D_YR(AGE,IA,IR,IS)

            END DO 
        END DO
    END DO
END DO


sort_D_C(:) = sort_D_C(:)/sum(sort_D_C)

cum_sort_D_C(1) = sort_D_C(1)
DO i = 2,size(sort_D_C)
	cum_sort_D_C(i) = cum_sort_D_C(i-1)+sort_D_C(i)
END DO


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


END SUBROUTINE
!************************************************************************************************************
 SUBROUTINE skewness  

ALLOCATE( bot99pct_D((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot90pct_D((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot50pct_D((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot30pct_D((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot99pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot90pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot50pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot30pct_D_inc((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot99pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot90pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot50pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( bot30pct_D_tinc((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )

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
  
 kratio99_50 = k_pct99/k_median				!	99-50 ratio
 kratio90_50 = k_pct90/k_median				!	99-50 ratio
 kratioMM = k_mean/k_median         		!	mean to median
 kratio50_30 = k_median/k_pct30				!	50-30 ratio
 
 incratio99_50 = inc_pct99/inc_median		!	99-50 ratio
 incratio90_50 = inc_pct90/inc_median		!	99-50 ratio
 incratioMM = inc_mean/inc_median       	!	mean to median
 incratio50_30 = inc_median/inc_pct30		!	50-30 ratio
 
 tincratio99_50 = tinc_pct99/tinc_median	!	99-50 ratio
 tincratio90_50 = tinc_pct90/tinc_median	!	99-50 ratio
 tincratioMM = tinc_mean/tinc_median        !	mean to median
 tincratio50_30 = tinc_median/tinc_pct30	!	50-30 ratio
 
 
	
 END SUBROUTINE
!***************************************************************************************

SUBROUTINE AGE_PARTITION

ALLOCATE( ALONG_AGE(MAXAGE))
ALLOCATE( ILONG_AGE(MAXAGE))
ALLOCATE( TILONG_AGE(MAXAGE))

DO AGE=1,RETAGE-1
	ALONG_AGE(AGE)=0.0
	ILONG_AGE(AGE)=0.0
	TILONG_AGE(AGE)=0.0
	DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn
				JA = IDCWA(AGE,IA,IR,IS)
				JN = IDCWN(AGE,IA,IR,IS)
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME

				ALONG_AGE(AGE) = ALONG_AGE(AGE) + A(JA)*YW(AGE,IA,IR,IS)/SUM(YW(AGE,:,:,:))
				ILONG_AGE(AGE) = ILONG_AGE(AGE) + INCOME*YW(AGE,IA,IR,IS)/SUM(YW(AGE,:,:,:))
				TILONG_AGE(AGE) = TILONG_AGE(AGE) + TINCOME*YW(AGE,IA,IR,IS)/SUM(YW(AGE,:,:,:))
			END DO			  
        END DO
    END DO
END DO

ALONG_RETIRE = 0.0
ILONG_RETIRE = 0.0
TILONG_RETIRE = 0.0

DO AGE=RETAGE,MAXAGE
	ALONG_AGE(AGE)=0.0
	TILONG_AGE(AGE)=0.0
	 DO IA=1,NGRIDA
        DO IR=1,NGRIDR
			DO IS=1,nn
				JA = IDCRA(AGE,IA,IR,IS)
				INCOME = 0.0 
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 
               
				ALONG_RETIRE = ALONG_RETIRE + A(JA)*YR(AGE,IA,IR,IS)/SUM(YR(RETAGE:MAXAGE,:,:,:))
				ILONG_RETIRE = ILONG_RETIRE + INCOME*YR(AGE,IA,IR,IS)/SUM(YR(RETAGE:MAXAGE,:,:,:))
				TILONG_RETIRE = TILONG_RETIRE + TINCOME*YR(AGE,IA,IR,IS)/SUM(YR(RETAGE:MAXAGE,:,:,:))
				ALONG_AGE(AGE) = ALONG_AGE(AGE) + A(JA)*YR(AGE,IA,IR,IS)/SUM(YR(AGE,:,:,:))
				TILONG_AGE(AGE) = TILONG_AGE(AGE) + TINCOME*YR(AGE,IA,IR,IS)/SUM(YR(AGE,:,:,:))
			END DO	
		END DO
	END DO
END DO					

! Wealth profile normalized by average

ALONG20_25=ALONG_AGE(1)/Aggwealth
ALONG25_30=ALONG_AGE(2)/Aggwealth	
ALONG30_35=ALONG_AGE(3)/Aggwealth
ALONG35_40=ALONG_AGE(4)/Aggwealth		
ALONG40_45=ALONG_AGE(5)/Aggwealth
ALONG45_50=ALONG_AGE(6)/Aggwealth
ALONG50_55=ALONG_AGE(7)/Aggwealth
ALONG55_60=ALONG_AGE(8)/Aggwealth
ALONG60_65=ALONG_AGE(9)/Aggwealth
ALONG65_70=ALONG_AGE(10)/Aggwealth
ALONG70_75=ALONG_AGE(11)/Aggwealth
ALONG75_80=ALONG_AGE(12)/Aggwealth
ALONG80_85=ALONG_AGE(13)/Aggwealth
ALONG85_90=ALONG_AGE(14)/Aggwealth
ALONG90_95=ALONG_AGE(15)/Aggwealth
ALONG95_100=ALONG_AGE(16)/Aggwealth
ALONG65_MORE=ALONG_RETIRE/Aggwealth

ALONG55_25=ALONG(8)/ALONG(2)
ALONG60_89=ALONG_AGE(9)/ALONG_AGE(14)

!Earnings profile normalized by average

ILONG20_25=ILONG_AGE(1)/Aggincome
ILONG25_30=ILONG_AGE(2)/Aggincome
ILONG30_35=ILONG_AGE(3)/Aggincome
ILONG35_40=ILONG_AGE(4)/Aggincome		
ILONG40_45=ILONG_AGE(5)/Aggincome
ILONG45_50=ILONG_AGE(6)/Aggincome
ILONG50_55=ILONG_AGE(7)/Aggincome
ILONG55_60=ILONG_AGE(8)/Aggincome
ILONG60_65=ILONG_AGE(9)/Aggincome

ILONG55_20=ILONG(7)/ILONG(1)


! pre-tax total income exclude pension income

Aggtincome_transfer = 0.0
Aggtincome_D_transfer = 0.0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                   
                				
				JN=IDCWN(AGE,IA,IR,IS) 				
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 
				
				Aggtincome_transfer = Aggtincome_transfer + TINCOME*D_YW(AGE,IA,IR,IS)
				Aggtincome_D_transfer = Aggtincome_D_transfer + D_YW(AGE,IA,IR,IS)
							
            END DO
        END DO 
    END DO
END DO			    

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA 
		DO IR=1,NGRIDR 
			DO IS=1,nn  
            
				INCOME = 0.0 
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME
				
				Aggtincome_transfer = Aggtincome_transfer + TINCOME*D_YR(AGE,IA,IR,IS)
				Aggtincome_D_transfer = Aggtincome_D_transfer + D_YR(AGE,IA,IR,IS)
				            
			END DO 
        END DO 
    END DO
END DO  

Aggtincome_transfer = Aggtincome_transfer/Aggtincome_D_transfer

TILONG20_25=TILONG_AGE(1)/Aggtincome_transfer
TILONG25_30=TILONG_AGE(2)/Aggtincome_transfer
TILONG30_35=TILONG_AGE(3)/Aggtincome_transfer
TILONG35_40=TILONG_AGE(4)/Aggtincome_transfer		
TILONG40_45=TILONG_AGE(5)/Aggtincome_transfer
TILONG45_50=TILONG_AGE(6)/Aggtincome_transfer
TILONG50_55=TILONG_AGE(7)/Aggtincome_transfer
TILONG55_60=TILONG_AGE(8)/Aggtincome_transfer
TILONG60_65=TILONG_AGE(9)/Aggtincome_transfer
TILONG65_70=TILONG_AGE(10)/Aggtincome_transfer
TILONG70_75=TILONG_AGE(11)/Aggtincome_transfer	
TILONG75_80=TILONG_AGE(12)/Aggtincome_transfer
TILONG80_85=TILONG_AGE(13)/Aggtincome_transfer
TILONG85_90=TILONG_AGE(14)/Aggtincome_transfer
TILONG90_95=TILONG_AGE(15)/Aggtincome_transfer
TILONG95_100=TILONG_AGE(16)/Aggtincome_transfer
TILONG65_MORE=TILONG_RETIRE/Aggtincome_transfer

TILONG55_20=TILONG(7)/TILONG(1)


END SUBROUTINE
!***************************************************************************************

SUBROUTINE avg_return
	
	! Population Average 

		tempsum = 0.0
		DO IR = 1,NGRIDR
			DO IS=1,nn
				DO IA=1,NGRIDA
					DO AGE=1,RETAGE-1					
						tempsum = tempsum + D_YW(AGE,IA,IR,IS)
					END DO 
				
					DO AGE=RETAGE,MAXAGE
						tempsum = tempsum + D_YR(AGE,IA,IR,IS)
					END DO 
				END DO
			END DO
		END DO

		Avg_R = 0.0D0

		DO IR = 1,NGRIDR
			DO IS=1,nn
				DO IA=1,NGRIDA
					DO AGE=1,RETAGE-1					
						Avg_R = Avg_R + ((1.+R(IR))**(0.2)-1.) * (D_YW(AGE,IA,IR,IS))/tempsum
					END DO 
				
					DO AGE=RETAGE,MAXAGE
						Avg_R = Avg_R + ((1.+R(IR))**(0.2)-1.) * (D_YR(AGE,IA,IR,IS))/tempsum
					END DO 
				END DO
			END DO
		END DO

		
		VAR_R = 0.0D0

		DO IR = 1,NGRIDR
			DO IS=1,nn
				DO IA=1,NGRIDA
					DO AGE=1,RETAGE-1					
						VAR_R = VAR_R + ((R_ANNUAL(IR)-Avg_R)**2)*(D_YW(AGE,IA,IR,IS))/tempsum
					END DO 
				
					DO AGE=RETAGE,MAXAGE
						VAR_R = VAR_R +  ((R_ANNUAL(IR)-Avg_R)**2)*(D_YR(AGE,IA,IR,IS))/tempsum
					END DO 
				END DO
			END DO
		END DO
		SD_R = VAR_R**0.5


	! Weighted average

		tempsumR = 0.0D0
		DO IR=1,NGRIDR
			DO IS=1,nn
				DO AGE=1,RETAGE-1
					tempsumR(IR) = tempsumR(IR) + SUM(D_YW(AGE,:,IR,IS)*A)
				END DO
				DO AGE=RETAGE,MAXAGE
					tempsumR(IR) = tempsumR(IR) + SUM(D_YR(AGE,:,IR,IS)*A)
				END DO
			END DO
		END DO
		tempsum = sum(tempsumR)

		Avg_R_weighted = 0.0D0
		DO IR = 1,NGRIDR
			Avg_R_weighted = Avg_R_weighted + ( (1.+R(IR))**(0.2)-1. )*tempsumR(IR)/tempsum 
		END DO
	
		VAR_R_weighted = 0.0D0
		DO IR = 1,NGRIDR
			VAR_R_weighted = VAR_R_weighted + ((R_ANNUAL(IR)-Avg_R_weighted)**2)*tempsumR(IR)/tempsum
		END DO
		SD_R_weighted = VAR_R_weighted**0.5


END SUBROUTINE

!******************************************************************************************************************************************
SUBROUTINE avg_return_wealthgroups		!avg return for different asset groups

ALLOCATE( sort_D_R(MAXAGE*NGRIDA*NGRIDR*nn, NGRIDR) )
ALLOCATE( indentify_R(MAXAGE*NGRIDA*NGRIDR*nn, NGRIDR) )
ALLOCATE( sort_D_R_weighted(MAXAGE*NGRIDA*NGRIDR*nn, NGRIDR) )

sort_D_R(:,:) = 0.0
indentify_R(:,:)= 0

index_A = 0
	DO AGE=1,MAXAGE
		DO IA=1,NGRIDA
			DO IR=1,NGRIDR
				DO IS=1,nn

					index_A = index_A + 1			
					indentify_R(index_A,IR) = 1

                END DO
            END DO
        END DO
    END DO

DO IR=1,NGRIDR
	indentify_R(:,IR) = indentify_R(record_position_A,IR)
END DO
DO IR=1,NGRIDR 
	sort_D_R(:,IR) = sort_D*indentify_R(:,IR)
END DO


! Top 0.001%
	tempsum = sum(sort_D_R(:,1)*top0001pct_D+sort_D_R(:,2)*top0001pct_D+sort_D_R(:,3)*top0001pct_D)
	Avg_top0001_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top0001pct_D/tempsum +R_ANNUAL(2)*sort_D_R(:,2)*top0001pct_D/tempsum +R_ANNUAL(3)*sort_D_R(:,3)*top0001pct_D/tempsum )
	
	SD_top0001_R = ( sum( ((R_ANNUAL(1)-Avg_top0001_R)**2)*sort_D_R(:,1)*top0001pct_D/tempsum + ((R_ANNUAL(2)-Avg_top0001_R)**2)*sort_D_R(:,2)*top0001pct_D/tempsum + ((R_ANNUAL(3)-Avg_top0001_R)**2)*sort_D_R(:,3)*top0001pct_D/tempsum ) )**0.5
	

! Top 0.005%
	tempsum = sum(sort_D_R(:,1)*top0005pct_D+sort_D_R(:,2)*top0005pct_D+sort_D_R(:,3)*top0005pct_D)
	Avg_top0005_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top0005pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top0005pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top0005pct_D/tempsum )
	
	SD_top0005_R = ( sum( ((R_ANNUAL(1)-Avg_top0005_R)**2)*sort_D_R(:,1)*top0005pct_D/tempsum + ((R_ANNUAL(2)-Avg_top0005_R)**2)*sort_D_R(:,2)*top0005pct_D/tempsum + ((R_ANNUAL(3)-Avg_top0005_R)**2)*sort_D_R(:,3)*top0005pct_D/tempsum ) )**0.5


! Top 0.01%
	tempsum = sum(sort_D_R(:,1)*top001pct_D+sort_D_R(:,2)*top001pct_D+sort_D_R(:,3)*top001pct_D)
	Avg_top001_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top001pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top001pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top001pct_D/tempsum )
	
	SD_top001_R = ( sum( ((R_ANNUAL(1)-Avg_top001_R)**2)*sort_D_R(:,1)*top001pct_D/tempsum + ((R_ANNUAL(2)-Avg_top001_R)**2)*sort_D_R(:,2)*top001pct_D/tempsum + ((R_ANNUAL(3)-Avg_top001_R)**2)*sort_D_R(:,3)*top001pct_D/tempsum ) )**0.5


! Top 0.1%
	tempsum = sum(sort_D_R(:,1)*top01pct_D+sort_D_R(:,2)*top01pct_D+sort_D_R(:,3)*top01pct_D)
	Avg_top01_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top01pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top01pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top01pct_D/tempsum )
	
	SD_top01_R = ( sum( ((R_ANNUAL(1)-Avg_top01_R)**2)*sort_D_R(:,1)*top01pct_D/tempsum + ((R_ANNUAL(2)-Avg_top01_R)**2)*sort_D_R(:,2)*top01pct_D/tempsum + ((R_ANNUAL(3)-Avg_top01_R)**2)*sort_D_R(:,3)*top01pct_D/tempsum ) )**0.5


! Top 0.5%
	tempsum = sum(sort_D_R(:,1)*top05pct_D+sort_D_R(:,2)*top05pct_D+sort_D_R(:,3)*top05pct_D)
	Avg_top05_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top05pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top05pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top05pct_D/tempsum )
	
	SD_top05_R = ( sum( ((R_ANNUAL(1)-Avg_top05_R)**2)*sort_D_R(:,1)*top05pct_D/tempsum + ((R_ANNUAL(2)-Avg_top05_R)**2)*sort_D_R(:,2)*top05pct_D/tempsum + ((R_ANNUAL(3)-Avg_top05_R)**2)*sort_D_R(:,3)*top05pct_D/tempsum ) )**0.5


! Top 1%
	tempsum = sum(sort_D_R(:,1)*top1pct_D+sort_D_R(:,2)*top1pct_D+sort_D_R(:,3)*top1pct_D)
	Avg_top1_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top1pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top1pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top1pct_D/tempsum )

	SD_top1_R = ( sum( ((R_ANNUAL(1)-Avg_top1_R)**2)*sort_D_R(:,1)*top1pct_D/tempsum + ((R_ANNUAL(2)-Avg_top1_R)**2)*sort_D_R(:,2)*top1pct_D/tempsum + ((R_ANNUAL(3)-Avg_top1_R)**2)*sort_D_R(:,3)*top1pct_D/tempsum ) )**0.5


! Top 5%
	tempsum = sum(sort_D_R(:,1)*top5pct_D+sort_D_R(:,2)*top5pct_D+sort_D_R(:,3)*top5pct_D)
	Avg_top5_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top5pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top5pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top5pct_D/tempsum )
	
	SD_top5_R = ( sum( ((R_ANNUAL(1)-Avg_top5_R)**2)*sort_D_R(:,1)*top5pct_D/tempsum + ((R_ANNUAL(2)-Avg_top5_R)**2)*sort_D_R(:,2)*top5pct_D/tempsum + ((R_ANNUAL(3)-Avg_top5_R)**2)*sort_D_R(:,3)*top5pct_D/tempsum ) )**0.5


! Top 10%
	tempsum = sum(sort_D_R(:,1)*top10pct_D+sort_D_R(:,2)*top10pct_D+sort_D_R(:,3)*top10pct_D)
	Avg_top10_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top10pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top10pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top10pct_D/tempsum )
	
	SD_top10_R = ( sum( ((R_ANNUAL(1)-Avg_top10_R)**2)*sort_D_R(:,1)*top10pct_D/tempsum + ((R_ANNUAL(2)-Avg_top10_R)**2)*sort_D_R(:,2)*top10pct_D/tempsum + ((R_ANNUAL(3)-Avg_top10_R)**2)*sort_D_R(:,3)*top10pct_D/tempsum ) )**0.5


! Top 20%
	tempsum = sum(sort_D_R(:,1)*top20pct_D+sort_D_R(:,2)*top20pct_D+sort_D_R(:,3)*top20pct_D)
	Avg_top20_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top20pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top20pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top20pct_D/tempsum )
	
	SD_top20_R = ( sum( ((R_ANNUAL(1)-Avg_top20_R)**2)*sort_D_R(:,1)*top20pct_D/tempsum + ((R_ANNUAL(2)-Avg_top20_R)**2)*sort_D_R(:,2)*top20pct_D/tempsum + ((R_ANNUAL(3)-Avg_top20_R)**2)*sort_D_R(:,3)*top20pct_D/tempsum ) )**0.5


! Top 40%
	tempsum = sum(sort_D_R(:,1)*top40pct_D+sort_D_R(:,2)*top40pct_D+sort_D_R(:,3)*top40pct_D)
	Avg_top40_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top40pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top40pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top40pct_D/tempsum )
	
	SD_top40_R = ( sum( ((R_ANNUAL(1)-Avg_top40_R)**2)*sort_D_R(:,1)*top40pct_D/tempsum + ((R_ANNUAL(2)-Avg_top40_R)**2)*sort_D_R(:,2)*top40pct_D/tempsum + ((R_ANNUAL(3)-Avg_top40_R)**2)*sort_D_R(:,3)*top40pct_D/tempsum ) )**0.5


! Top 60%
	tempsum = sum(sort_D_R(:,1)*top60pct_D+sort_D_R(:,2)*top60pct_D+sort_D_R(:,3)*top60pct_D)
	Avg_top60_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top60pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top60pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top60pct_D/tempsum )
	
	SD_top60_R = ( sum( ((R_ANNUAL(1)-Avg_top60_R)**2)*sort_D_R(:,1)*top60pct_D/tempsum + ((R_ANNUAL(2)-Avg_top60_R)**2)*sort_D_R(:,2)*top60pct_D/tempsum + ((R_ANNUAL(3)-Avg_top60_R)**2)*sort_D_R(:,3)*top60pct_D/tempsum ) )**0.5
	

! Top 80%
	tempsum = sum(sort_D_R(:,1)*top80pct_D+sort_D_R(:,2)*top80pct_D+sort_D_R(:,3)*top80pct_D)
	Avg_top60_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top80pct_D/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top80pct_D/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top80pct_D/tempsum )
	
	SD_top80_R = ( sum( ((R_ANNUAL(1)-Avg_top80_R)**2)*sort_D_R(:,1)*top80pct_D/tempsum + ((R_ANNUAL(2)-Avg_top80_R)**2)*sort_D_R(:,2)*top80pct_D/tempsum + ((R_ANNUAL(3)-Avg_top80_R)**2)*sort_D_R(:,3)*top80pct_D/tempsum ) )**0.5


! P40-60
	tempsum = sum(sort_D_R(:,1)*(top60pct_D-top40pct_D)+sort_D_R(:,2)*(top60pct_D-top40pct_D)+sort_D_R(:,3)*(top60pct_D-top40pct_D))
	Avg_P4060_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top60pct_D-top40pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top60pct_D-top40pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top60pct_D-top40pct_D)/tempsum)
	
	SD_P4060_R = ( sum( ((R_ANNUAL(1)-Avg_P4060_R)**2)*sort_D_R(:,1)*(top60pct_D-top40pct_D)/tempsum + ((R_ANNUAL(2)-Avg_P4060_R)**2)*sort_D_R(:,2)*(top60pct_D-top40pct_D)/tempsum + ((R_ANNUAL(3)-Avg_P4060_R)**2)*sort_D_R(:,3)*(top60pct_D-top40pct_D)/tempsum ) )**0.5


! Bottom 40%
	tempsum = sum(sort_D_R(:,1)*(1-top60pct_D)+sort_D_R(:,2)*(1-top60pct_D)+sort_D_R(:,3)*(1-top60pct_D))
	Avg_bot40_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(1-top60pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(1-top60pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(1-top60pct_D)/tempsum )
	
	SD_bot40_R = ( sum( ((R_ANNUAL(1)-Avg_bot40_R)**2)*sort_D_R(:,1)*(1-top60pct_D)/tempsum + ((R_ANNUAL(2)-Avg_bot40_R)**2)*sort_D_R(:,2)*(1-top60pct_D)/tempsum + ((R_ANNUAL(3)-Avg_bot40_R)**2)*sort_D_R(:,3)*(1-top60pct_D)/tempsum ) )**0.5


! Bottom 20%
	tempsum = sum(sort_D_R(:,1)*(1-top80pct_D)+sort_D_R(:,2)*(1-top80pct_D)+sort_D_R(:,3)*(1-top80pct_D))
	Avg_bot20_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(1-top80pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(1-top80pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(1-top80pct_D)/tempsum )

	SD_bot20_R = ( sum( ((R_ANNUAL(1)-Avg_bot20_R)**2)*sort_D_R(:,1)*(1-top80pct_D)/tempsum + ((R_ANNUAL(2)-Avg_bot20_R)**2)*sort_D_R(:,2)*(1-top80pct_D)/tempsum + ((R_ANNUAL(3)-Avg_bot20_R)**2)*sort_D_R(:,3)*(1-top80pct_D)/tempsum ) )**0.5


! Percentile 99-99.99%
	tempsum = sum(sort_D_R(:,1)*(top1pct_D-top001pct_D)+sort_D_R(:,2)*(top1pct_D-top001pct_D)+sort_D_R(:,3)*(top1pct_D-top001pct_D))
	Avg_99_9999_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top1pct_D-top001pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top1pct_D-top001pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top1pct_D-top001pct_D)/tempsum )
	
	SD_99_9999_R = ( sum( ((R_ANNUAL(1)-Avg_99_9999_R)**2)*sort_D_R(:,1)*(top1pct_D-top001pct_D)/tempsum + ((R_ANNUAL(2)-Avg_99_9999_R)**2)*sort_D_R(:,2)*(top1pct_D-top001pct_D)/tempsum + ((R_ANNUAL(3)-Avg_99_9999_R)**2)*sort_D_R(:,3)*(top1pct_D-top001pct_D)/tempsum ) )**0.5

	
! Percentile 99-99.9%
	tempsum = sum(sort_D_R(:,1)*(top1pct_D-top01pct_D)+sort_D_R(:,2)*(top1pct_D-top01pct_D)+sort_D_R(:,3)*(top1pct_D-top01pct_D))
	Avg_99_999_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top1pct_D-top01pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top1pct_D-top01pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top1pct_D-top01pct_D)/tempsum )
	
	SD_99_999_R = ( sum( ((R_ANNUAL(1)-Avg_99_999_R)**2)*sort_D_R(:,1)*(top1pct_D-top01pct_D)/tempsum + ((R_ANNUAL(2)-Avg_99_999_R)**2)*sort_D_R(:,2)*(top1pct_D-top01pct_D)/tempsum + ((R_ANNUAL(3)-Avg_99_999_R)**2)*sort_D_R(:,3)*(top1pct_D-top01pct_D)/tempsum ) )**0.5
	

! Percentile 99.5-99.9%
	tempsum = sum(sort_D_R(:,1)*(top05pct_D-top01pct_D)+sort_D_R(:,2)*(top05pct_D-top01pct_D)+sort_D_R(:,3)*(top05pct_D-top01pct_D))
	Avg_995_999_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top05pct_D-top01pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top05pct_D-top01pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top05pct_D-top01pct_D)/tempsum )
	
	SD_995_999_R = ( sum( ((R_ANNUAL(1)-Avg_995_999_R)**2)*sort_D_R(:,1)*(top05pct_D-top01pct_D)/tempsum + ((R_ANNUAL(2)-Avg_995_999_R)**2)*sort_D_R(:,2)*(top05pct_D-top01pct_D)/tempsum + ((R_ANNUAL(3)-Avg_995_999_R)**2)*sort_D_R(:,3)*(top05pct_D-top01pct_D)/tempsum ) )**0.5


! Percentile 99-99.5%
	tempsum = sum(sort_D_R(:,1)*(top1pct_D-top05pct_D)+sort_D_R(:,2)*(top1pct_D-top05pct_D)+sort_D_R(:,3)*(top1pct_D-top05pct_D))
	Avg_99_995_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top1pct_D-top05pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top1pct_D-top05pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top1pct_D-top05pct_D)/tempsum )
	
	SD_99_995_R = ( sum( ((R_ANNUAL(1)-Avg_99_995_R)**2)*sort_D_R(:,1)*(top1pct_D-top05pct_D)/tempsum + ((R_ANNUAL(2)-Avg_99_995_R)**2)*sort_D_R(:,2)*(top1pct_D-top05pct_D)/tempsum + ((R_ANNUAL(3)-Avg_99_995_R)**2)*sort_D_R(:,3)*(top1pct_D-top05pct_D)/tempsum ) )**0.5


! Percentile 95-99%
	tempsum = sum(sort_D_R(:,1)*(top5pct_D-top1pct_D)+sort_D_R(:,2)*(top5pct_D-top1pct_D)+sort_D_R(:,3)*(top5pct_D-top1pct_D))
	Avg_95_99_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top5pct_D-top1pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top5pct_D-top1pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top5pct_D-top1pct_D)/tempsum )
	
	SD_95_99_R = ( sum( ((R_ANNUAL(1)-Avg_95_99_R)**2)*sort_D_R(:,1)*(top5pct_D-top1pct_D)/tempsum + ((R_ANNUAL(2)-Avg_95_99_R)**2)*sort_D_R(:,2)*(top5pct_D-top1pct_D)/tempsum + ((R_ANNUAL(3)-Avg_95_99_R)**2)*sort_D_R(:,3)*(top5pct_D-top1pct_D)/tempsum ) )**0.5
	

! Percentile 90-95%
	tempsum = sum(sort_D_R(:,1)*(top10pct_D-top5pct_D)+sort_D_R(:,2)*(top10pct_D-top5pct_D)+sort_D_R(:,3)*(top10pct_D-top5pct_D))
	Avg_90_95_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top10pct_D-top5pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top10pct_D-top5pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top10pct_D-top5pct_D)/tempsum )
	
	SD_90_95_R = ( sum( ((R_ANNUAL(1)-Avg_90_95_R)**2)*sort_D_R(:,1)*(top10pct_D-top5pct_D)/tempsum + ((R_ANNUAL(2)-Avg_90_95_R)**2)*sort_D_R(:,2)*(top10pct_D-top5pct_D)/tempsum + ((R_ANNUAL(3)-Avg_90_95_R)**2)*sort_D_R(:,3)*(top10pct_D-top5pct_D)/tempsum ) )**0.5
	

! Percentile 0-90%
	tempsum = sum(sort_D_R(:,1)*(1-top10pct_D)+sort_D_R(:,2)*(1-top10pct_D)+sort_D_R(:,3)*(1-top10pct_D))
	Avg_bot90_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(1-top10pct_D)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(1-top10pct_D)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(1-top10pct_D)/tempsum )

	SD_bot90_R = ( sum( ((R_ANNUAL(1)-Avg_bot90_R)**2)*sort_D_R(:,1)*(1-top10pct_D)/tempsum + ((R_ANNUAL(2)-Avg_bot90_R)**2)*sort_D_R(:,2)*(1-top10pct_D)/tempsum + ((R_ANNUAL(3)-Avg_bot90_R)**2)*sort_D_R(:,3)*(1-top10pct_D)/tempsum ) )**0.5


	! Weighted Average Return by wealth groups

	sort_D_R_weighted(:,:) = 0.0D0
	DO IR=1,NGRIDR	
		sort_D_R_weighted(:,IR) = sort_A*sort_D_R(:,IR)
	END DO 
	

	! Top 0.001%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top0001pct_D)
			END DO 
		
		Avg_top0001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top0001_R_weighted = Avg_top0001_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top0001pct_D/tempsum) 
			END DO
	
		VAR_top0001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top0001_R_weighted = VAR_top0001_R_weighted + sum(((R_ANNUAL(IR)-Avg_top0001_R_weighted)**2)*sort_D_R_weighted(:,IR)*top0001pct_D/tempsum)
			END DO
			SD_top0001_R_weighted = VAR_top0001_R_weighted**0.5


	! Top 0.005%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top0005pct_D)
			END DO 
		
		Avg_top0005_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top0005_R_weighted = Avg_top0005_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top0005pct_D/tempsum)
			END DO
	
		VAR_top0005_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top0005_R_weighted = VAR_top0005_R_weighted + sum(((R_ANNUAL(IR)-Avg_top0005_R_weighted)**2)*sort_D_R_weighted(:,IR)*top0005pct_D/tempsum)
			END DO
			SD_top0005_R_weighted = VAR_top0005_R_weighted**0.5


	! Top 0.01%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top001pct_D)
			END DO 
		
		Avg_top001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top001_R_weighted = Avg_top001_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top001pct_D/tempsum) 
			END DO
	
		VAR_top001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top001_R_weighted = VAR_top001_R_weighted + sum(((R_ANNUAL(IR)-Avg_top001_R_weighted)**2)*sort_D_R_weighted(:,IR)*top001pct_D/tempsum)
			END DO
			SD_top001_R_weighted = VAR_top001_R_weighted**0.5


	! Top 0.1%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top01pct_D)
			END DO 
		
		Avg_top01_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top01_R_weighted = Avg_top01_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top01pct_D/tempsum) 
			END DO
	
		VAR_top01_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top01_R_weighted = VAR_top01_R_weighted + sum(((R_ANNUAL(IR)-Avg_top01_R_weighted)**2)*sort_D_R_weighted(:,IR)*top01pct_D/tempsum)
			END DO
			SD_top01_R_weighted = VAR_top01_R_weighted**0.5


	! Top 0.5%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top05pct_D)
			END DO 
		
		Avg_top05_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top05_R_weighted = Avg_top05_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top05pct_D/tempsum) 
			END DO
	
		VAR_top05_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top05_R_weighted = VAR_top05_R_weighted + sum(((R_ANNUAL(IR)-Avg_top05_R_weighted)**2)*sort_D_R_weighted(:,IR)*top05pct_D/tempsum)
			END DO
			SD_top05_R_weighted = VAR_top05_R_weighted**0.5


	! Top 1%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top1pct_D)
			END DO 
		
		Avg_top1_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top1_R_weighted = Avg_top1_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top1pct_D/tempsum) 
			END DO
	
		VAR_top1_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top1_R_weighted = VAR_top1_R_weighted + sum(((R_ANNUAL(IR)-Avg_top1_R_weighted)**2)*sort_D_R_weighted(:,IR)*top1pct_D/tempsum)
			END DO
			SD_top1_R_weighted = VAR_top1_R_weighted**0.5


	! Top 5%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top5pct_D)
			END DO 
		
		Avg_top5_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top5_R_weighted = Avg_top5_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top5pct_D/tempsum) 
			END DO
	
		VAR_top5_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top5_R_weighted = VAR_top5_R_weighted + sum(((R_ANNUAL(IR)-Avg_top5_R_weighted)**2)*sort_D_R_weighted(:,IR)*top5pct_D/tempsum)
			END DO
			SD_top5_R_weighted = VAR_top5_R_weighted**0.5


	! Top 10%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top10pct_D)
			END DO 
		
		Avg_top10_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top10_R_weighted = Avg_top10_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top10pct_D/tempsum) 
			END DO
	
		VAR_top10_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top10_R_weighted = VAR_top10_R_weighted + sum(((R_ANNUAL(IR)-Avg_top10_R_weighted)**2)*sort_D_R_weighted(:,IR)*top10pct_D/tempsum)
			END DO
			SD_top10_R_weighted = VAR_top10_R_weighted**0.5


	! Top 20%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top20pct_D)
			END DO 
		
		Avg_top20_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top20_R_weighted = Avg_top20_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top20pct_D/tempsum) 
			END DO
	
		VAR_top20_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top20_R_weighted = VAR_top20_R_weighted + sum(((R_ANNUAL(IR)-Avg_top20_R_weighted)**2)*sort_D_R_weighted(:,IR)*top20pct_D/tempsum)
			END DO
			SD_top20_R_weighted = VAR_top20_R_weighted**0.5


	! Top 40%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top40pct_D)
			END DO 
		
		Avg_top40_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top40_R_weighted = Avg_top40_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top40pct_D/tempsum) 
			END DO
	
		VAR_top40_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top40_R_weighted = VAR_top40_R_weighted + sum(((R_ANNUAL(IR)-Avg_top40_R_weighted)**2)*sort_D_R_weighted(:,IR)*top40pct_D/tempsum)
			END DO
			SD_top40_R_weighted = VAR_top40_R_weighted**0.5


	! Top 60%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top60pct_D)
			END DO 
		
		Avg_top60_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top60_R_weighted = Avg_top60_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top60pct_D/tempsum) 
			END DO
	
		VAR_top60_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top60_R_weighted = VAR_top60_R_weighted + sum(((R_ANNUAL(IR)-Avg_top60_R_weighted)**2)*sort_D_R_weighted(:,IR)*top60pct_D/tempsum)
			END DO
			SD_top60_R_weighted = VAR_top60_R_weighted**0.5

	! Top 80%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top80pct_D)
			END DO 
		
		Avg_top80_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_top80_R_weighted = Avg_top80_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top80pct_D/tempsum) 
			END DO
	
		VAR_top80_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_top80_R_weighted = VAR_top80_R_weighted + sum(((R_ANNUAL(IR)-Avg_top80_R_weighted)**2)*sort_D_R_weighted(:,IR)*top80pct_D/tempsum)
			END DO
			SD_top80_R_weighted = VAR_top80_R_weighted**0.5


	! Percentile 99.5-99.9%
		tempsum = sum(sort_D_R_weighted(:,1)*(top05pct_D-top01pct_D)+sort_D_R_weighted(:,2)*(top05pct_D-top01pct_D)+sort_D_R_weighted(:,3)*(top05pct_D-top01pct_D))
		Avg_995_999_R_weighted =  sum( R_ANNUAL(1)*sort_D_R_weighted(:,1)*(top05pct_D-top01pct_D)/tempsum + R_ANNUAL(2)*sort_D_R_weighted(:,2)*(top05pct_D-top01pct_D)/tempsum + R_ANNUAL(3)*sort_D_R_weighted(:,3)*(top05pct_D-top01pct_D)/tempsum )
		
		SD_995_999_R_weighted = ( sum( ((R_ANNUAL(1)-Avg_995_999_R_weighted)**2)*sort_D_R_weighted(:,1)*(top05pct_D-top01pct_D)/tempsum + ((R_ANNUAL(2)-Avg_995_999_R_weighted)**2)*sort_D_R_weighted(:,2)*(top05pct_D-top01pct_D)/tempsum + ((R_ANNUAL(3)-Avg_995_999_R_weighted)**2)*sort_D_R_weighted(:,3)*(top05pct_D-top01pct_D)/tempsum ) )**0.5


	! Percentile 99-99.5%
		tempsum = sum(sort_D_R_weighted(:,1)*(top1pct_D-top05pct_D)+sort_D_R_weighted(:,2)*(top1pct_D-top05pct_D)+sort_D_R_weighted(:,3)*(top1pct_D-top05pct_D))
		Avg_99_995_R_weighted =  sum( R_ANNUAL(1)*sort_D_R_weighted(:,1)*(top1pct_D-top05pct_D)/tempsum + R_ANNUAL(2)*sort_D_R_weighted(:,2)*(top1pct_D-top05pct_D)/tempsum + R_ANNUAL(3)*sort_D_R_weighted(:,3)*(top1pct_D-top05pct_D)/tempsum )
		
		SD_99_995_R_weighted = ( sum( ((R_ANNUAL(1)-Avg_99_995_R_weighted)**2)*sort_D_R_weighted(:,1)*(top1pct_D-top05pct_D)/tempsum + ((R_ANNUAL(2)-Avg_99_995_R_weighted)**2)*sort_D_R_weighted(:,2)*(top1pct_D-top05pct_D)/tempsum + ((R_ANNUAL(3)-Avg_99_995_R_weighted)**2)*sort_D_R_weighted(:,3)*(top1pct_D-top05pct_D)/tempsum ) )**0.5


	! Percentile 95-99%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(top5pct_D-top1pct_D))
			END DO 
		
		Avg_95_99_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_95_99_R_weighted = Avg_95_99_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(top5pct_D-top1pct_D)/tempsum) 
			END DO
	
		VAR_95_99_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_95_99_R_weighted = VAR_95_99_R_weighted + sum(((R_ANNUAL(IR)-Avg_95_99_R_weighted)**2)*sort_D_R_weighted(:,IR)*(top5pct_D-top1pct_D)/tempsum)
			END DO
			SD_95_99_R_weighted = VAR_95_99_R_weighted**0.5


	! Percentile 90-95%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(top10pct_D-top5pct_D))
			END DO 
		
		Avg_90_95_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_90_95_R_weighted = Avg_90_95_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(top10pct_D-top5pct_D)/tempsum) 
			END DO
	
		VAR_90_95_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_90_95_R_weighted = VAR_90_95_R_weighted + sum(((R_ANNUAL(IR)-Avg_90_95_R_weighted)**2)*sort_D_R_weighted(:,IR)*(top10pct_D-top5pct_D)/tempsum)
			END DO
			SD_90_95_R_weighted = VAR_90_95_R_weighted**0.5


	! Percentile 0-90%
		tempsum = sum(sort_D_R_weighted(:,1)*(1-top10pct_D)+sort_D_R_weighted(:,2)*(1-top10pct_D)+sort_D_R_weighted(:,3)*(1-top10pct_D))
		Avg_bot90_R_weighted =  sum( R_ANNUAL(1)*sort_D_R_weighted(:,1)*(1-top10pct_D)/tempsum + R_ANNUAL(2)*sort_D_R_weighted(:,2)*(1-top10pct_D)/tempsum + R_ANNUAL(3)*sort_D_R_weighted(:,3)*(1-top10pct_D)/tempsum )

		SD_bot90_R_weighted = ( sum( ((R_ANNUAL(1)-Avg_bot90_R_weighted)**2)*sort_D_R_weighted(:,1)*(1-top10pct_D)/tempsum + ((R_ANNUAL(2)-Avg_bot90_R_weighted)**2)*sort_D_R_weighted(:,2)*(1-top10pct_D)/tempsum + ((R_ANNUAL(3)-Avg_bot90_R_weighted)**2)*sort_D_R_weighted(:,3)*(1-top10pct_D)/tempsum ) )**0.5


END SUBROUTINE

!******************************************************************************************************************************************
SUBROUTINE avg_return_incomegroups		!avg return for different income groups

ALLOCATE( sort_D_R(MAXAGE*NGRIDA*NGRIDR*nn, NGRIDR) )
ALLOCATE( sort_D_Z(MAXAGE*NGRIDA*NGRIDR*nn, nn) )
ALLOCATE( indentify_R(MAXAGE*NGRIDA*NGRIDR*nn, NGRIDR) )
ALLOCATE( indentify_Z(MAXAGE*NGRIDA*NGRIDR*nn, nn) )
ALLOCATE( sort_D_R_weighted(MAXAGE*NGRIDA*NGRIDR*nn, NGRIDR) )
ALLOCATE( sort_D_Z_weighted(MAXAGE*NGRIDA*NGRIDR*nn, nn) )
ALLOCATE( sort_A_tinc(MAXAGE*NGRIDA*NGRIDR*nn))


sort_D_R(:,:) = 0.0
sort_D_Z(:,:) = 0.0
indentify_R(:,:)= 0
indentify_Z(:,:)= 0
sort_A_tinc(:) = 0.0

index_A = 0
	DO AGE=1,MAXAGE
		DO IA=1,NGRIDA
			DO IR=1,NGRIDR
				DO IS=1,nn

					index_A = index_A + 1			
					indentify_R(index_A,IR) = 1
					indentify_Z(index_A,IS) = 1
					sort_A_tinc(index_A) = A(IA)
                END DO
            END DO
        END DO
    END DO

DO IR=1,NGRIDR
	indentify_R(:,IR) = indentify_R(record_position_tinc,IR)
END DO
DO IR=1,NGRIDR 
	sort_D_R(:,IR) = sort_D_tinc*indentify_R(:,IR)
END DO


DO IS=1,nn
	indentify_Z(:,IS) = indentify_Z(record_position_tinc,IS)
END DO
DO IS=1,nn 
	sort_D_Z(:,IS) = sort_D_tinc*indentify_Z(:,IS)
END DO


sort_A_tinc = sort_A_tinc(record_position_tinc)

! Top 0.001%
	tempsum = sum(sort_D_R(:,1)*top0001pct_D_tinc+sort_D_R(:,2)*top0001pct_D_tinc+sort_D_R(:,3)*top0001pct_D_tinc)
	Avg_topinc0001_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top0001pct_D_tinc/tempsum +R_ANNUAL(2)*sort_D_R(:,2)*top0001pct_D_tinc/tempsum +R_ANNUAL(3)*sort_D_R(:,3)*top0001pct_D_tinc/tempsum )
	
	SD_topinc0001_R = ( sum( ((R_ANNUAL(1)-Avg_topinc0001_R)**2)*sort_D_R(:,1)*top0001pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc0001_R)**2)*sort_D_R(:,2)*top0001pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc0001_R)**2)*sort_D_R(:,3)*top0001pct_D_tinc/tempsum ) )**0.5
	

! Top 0.005%
	tempsum = sum(sort_D_R(:,1)*top0005pct_D_tinc+sort_D_R(:,2)*top0005pct_D_tinc+sort_D_R(:,3)*top0005pct_D_tinc)
	Avg_topinc0005_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top0005pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top0005pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top0005pct_D_tinc/tempsum )
	
	SD_topinc0005_R = ( sum( ((R_ANNUAL(1)-Avg_topinc0005_R)**2)*sort_D_R(:,1)*top0005pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc0005_R)**2)*sort_D_R(:,2)*top0005pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc0005_R)**2)*sort_D_R(:,3)*top0005pct_D_tinc/tempsum ) )**0.5


! Top 0.01%
	tempsum = sum(sort_D_R(:,1)*top001pct_D_tinc+sort_D_R(:,2)*top001pct_D_tinc+sort_D_R(:,3)*top001pct_D_tinc)
	Avg_topinc001_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top001pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top001pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top001pct_D_tinc/tempsum )
	
	SD_topinc001_R = ( sum( ((R_ANNUAL(1)-Avg_topinc001_R)**2)*sort_D_R(:,1)*top001pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc001_R)**2)*sort_D_R(:,2)*top001pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc001_R)**2)*sort_D_R(:,3)*top001pct_D_tinc/tempsum ) )**0.5


! Top 0.1%
	tempsum = sum(sort_D_R(:,1)*top01pct_D_tinc+sort_D_R(:,2)*top01pct_D_tinc+sort_D_R(:,3)*top01pct_D_tinc)
	Avg_topinc01_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top01pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top01pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top01pct_D_tinc/tempsum )
	
	SD_topinc01_R = ( sum( ((R_ANNUAL(1)-Avg_topinc01_R)**2)*sort_D_R(:,1)*top01pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc01_R)**2)*sort_D_R(:,2)*top01pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc01_R)**2)*sort_D_R(:,3)*top01pct_D_tinc/tempsum ) )**0.5


! Top 0.5%
	tempsum = sum(sort_D_R(:,1)*top05pct_D_tinc+sort_D_R(:,2)*top05pct_D_tinc+sort_D_R(:,3)*top05pct_D_tinc)
	Avg_topinc05_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top05pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top05pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top05pct_D_tinc/tempsum )
	
	SD_topinc05_R = ( sum( ((R_ANNUAL(1)-Avg_topinc05_R)**2)*sort_D_R(:,1)*top05pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc05_R)**2)*sort_D_R(:,2)*top05pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc05_R)**2)*sort_D_R(:,3)*top05pct_D_tinc/tempsum ) )**0.5


! Top 1%
	tempsum = sum(sort_D_R(:,1)*top1pct_D_tinc+sort_D_R(:,2)*top1pct_D_tinc+sort_D_R(:,3)*top1pct_D_tinc)
	Avg_topinc1_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top1pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top1pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top1pct_D_tinc/tempsum )

	SD_topinc1_R = ( sum( ((R_ANNUAL(1)-Avg_topinc1_R)**2)*sort_D_R(:,1)*top1pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc1_R)**2)*sort_D_R(:,2)*top1pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc1_R)**2)*sort_D_R(:,3)*top1pct_D_tinc/tempsum ) )**0.5


! Top 5%
	tempsum = sum(sort_D_R(:,1)*top5pct_D_tinc+sort_D_R(:,2)*top5pct_D_tinc+sort_D_R(:,3)*top5pct_D_tinc)
	Avg_topinc5_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top5pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top5pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top5pct_D_tinc/tempsum )
	
	SD_topinc5_R = ( sum( ((R_ANNUAL(1)-Avg_topinc5_R)**2)*sort_D_R(:,1)*top5pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc5_R)**2)*sort_D_R(:,2)*top5pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc5_R)**2)*sort_D_R(:,3)*top5pct_D_tinc/tempsum ) )**0.5


! Top 10%
	tempsum = sum(sort_D_R(:,1)*top10pct_D_tinc+sort_D_R(:,2)*top10pct_D_tinc+sort_D_R(:,3)*top10pct_D_tinc)
	Avg_topinc10_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top10pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top10pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top10pct_D_tinc/tempsum )
	
	SD_topinc10_R = ( sum( ((R_ANNUAL(1)-Avg_topinc10_R)**2)*sort_D_R(:,1)*top10pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc10_R)**2)*sort_D_R(:,2)*top10pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc10_R)**2)*sort_D_R(:,3)*top10pct_D_tinc/tempsum ) )**0.5


! Top 20%
	tempsum = sum(sort_D_R(:,1)*top20pct_D_tinc+sort_D_R(:,2)*top20pct_D_tinc+sort_D_R(:,3)*top20pct_D_tinc)
	Avg_topinc20_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top20pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top20pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top20pct_D_tinc/tempsum )
	
	SD_topinc20_R = ( sum( ((R_ANNUAL(1)-Avg_topinc20_R)**2)*sort_D_R(:,1)*top20pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc20_R)**2)*sort_D_R(:,2)*top20pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc20_R)**2)*sort_D_R(:,3)*top20pct_D_tinc/tempsum ) )**0.5


! Top 40%
	tempsum = sum(sort_D_R(:,1)*top40pct_D_tinc+sort_D_R(:,2)*top40pct_D_tinc+sort_D_R(:,3)*top40pct_D_tinc)
	Avg_topinc40_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top40pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top40pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top40pct_D_tinc/tempsum )
	
	SD_topinc40_R = ( sum( ((R_ANNUAL(1)-Avg_topinc40_R)**2)*sort_D_R(:,1)*top40pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc40_R)**2)*sort_D_R(:,2)*top40pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc40_R)**2)*sort_D_R(:,3)*top40pct_D_tinc/tempsum ) )**0.5


! Top 60%
	tempsum = sum(sort_D_R(:,1)*top60pct_D_tinc+sort_D_R(:,2)*top60pct_D_tinc+sort_D_R(:,3)*top60pct_D_tinc)
	Avg_topinc60_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top60pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top60pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top60pct_D_tinc/tempsum )
	
	SD_topinc60_R = ( sum( ((R_ANNUAL(1)-Avg_topinc60_R)**2)*sort_D_R(:,1)*top60pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc60_R)**2)*sort_D_R(:,2)*top60pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc60_R)**2)*sort_D_R(:,3)*top60pct_D_tinc/tempsum ) )**0.5
	

! Top 80%
	tempsum = sum(sort_D_R(:,1)*top80pct_D_tinc+sort_D_R(:,2)*top80pct_D_tinc+sort_D_R(:,3)*top80pct_D_tinc)
	Avg_topinc60_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*top80pct_D_tinc/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*top80pct_D_tinc/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*top80pct_D_tinc/tempsum )
	
	SD_topinc80_R = ( sum( ((R_ANNUAL(1)-Avg_topinc80_R)**2)*sort_D_R(:,1)*top80pct_D_tinc/tempsum + ((R_ANNUAL(2)-Avg_topinc80_R)**2)*sort_D_R(:,2)*top80pct_D_tinc/tempsum + ((R_ANNUAL(3)-Avg_topinc80_R)**2)*sort_D_R(:,3)*top80pct_D_tinc/tempsum ) )**0.5


! P40-60
	tempsum = sum(sort_D_R(:,1)*(top60pct_D_tinc-top40pct_D_tinc)+sort_D_R(:,2)*(top60pct_D_tinc-top40pct_D_tinc)+sort_D_R(:,3)*(top60pct_D_tinc-top40pct_D_tinc))
	Avg_Pinc4060_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top60pct_D_tinc-top40pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top60pct_D_tinc-top40pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top60pct_D_tinc-top40pct_D_tinc)/tempsum)
	
	SD_Pinc4060_R = ( sum( ((R_ANNUAL(1)-Avg_Pinc4060_R)**2)*sort_D_R(:,1)*(top60pct_D_tinc-top40pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_Pinc4060_R)**2)*sort_D_R(:,2)*(top60pct_D_tinc-top40pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_Pinc4060_R)**2)*sort_D_R(:,3)*(top60pct_D_tinc-top40pct_D_tinc)/tempsum ) )**0.5


! Bottom 40%
	tempsum = sum(sort_D_R(:,1)*(1-top60pct_D_tinc)+sort_D_R(:,2)*(1-top60pct_D_tinc)+sort_D_R(:,3)*(1-top60pct_D_tinc))
	Avg_botinc40_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(1-top60pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(1-top60pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(1-top60pct_D_tinc)/tempsum )
	
	SD_botinc40_R = ( sum( ((R_ANNUAL(1)-Avg_botinc40_R)**2)*sort_D_R(:,1)*(1-top60pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_botinc40_R)**2)*sort_D_R(:,2)*(1-top60pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_botinc40_R)**2)*sort_D_R(:,3)*(1-top60pct_D_tinc)/tempsum ) )**0.5


! Bottom 20%
	tempsum = sum(sort_D_R(:,1)*(1-top80pct_D_tinc)+sort_D_R(:,2)*(1-top80pct_D_tinc)+sort_D_R(:,3)*(1-top80pct_D_tinc))
	Avg_botinc20_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(1-top80pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(1-top80pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(1-top80pct_D_tinc)/tempsum )

	SD_botinc20_R = ( sum( ((R_ANNUAL(1)-Avg_botinc20_R)**2)*sort_D_R(:,1)*(1-top80pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_botinc20_R)**2)*sort_D_R(:,2)*(1-top80pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_botinc20_R)**2)*sort_D_R(:,3)*(1-top80pct_D_tinc)/tempsum ) )**0.5


! Percentile 99-99.99%
	tempsum = sum(sort_D_R(:,1)*(top1pct_D_tinc-top001pct_D_tinc)+sort_D_R(:,2)*(top1pct_D_tinc-top001pct_D_tinc)+sort_D_R(:,3)*(top1pct_D_tinc-top001pct_D_tinc))
	Avg_inc99_9999_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top1pct_D_tinc-top001pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top1pct_D_tinc-top001pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top1pct_D_tinc-top001pct_D_tinc)/tempsum )
	
	SD_inc99_9999_R = ( sum( ((R_ANNUAL(1)-Avg_inc99_9999_R)**2)*sort_D_R(:,1)*(top1pct_D_tinc-top001pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_inc99_9999_R)**2)*sort_D_R(:,2)*(top1pct_D_tinc-top001pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_inc99_9999_R)**2)*sort_D_R(:,3)*(top1pct_D_tinc-top001pct_D_tinc)/tempsum ) )**0.5

	
! Percentile 99-99.9%
	tempsum = sum(sort_D_R(:,1)*(top1pct_D_tinc-top01pct_D_tinc)+sort_D_R(:,2)*(top1pct_D_tinc-top01pct_D_tinc)+sort_D_R(:,3)*(top1pct_D_tinc-top01pct_D_tinc))
	Avg_inc99_999_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top1pct_D_tinc-top01pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top1pct_D_tinc-top01pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top1pct_D_tinc-top01pct_D_tinc)/tempsum )
	
	SD_inc99_999_R = ( sum( ((R_ANNUAL(1)-Avg_inc99_999_R)**2)*sort_D_R(:,1)*(top1pct_D_tinc-top01pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_inc99_999_R)**2)*sort_D_R(:,2)*(top1pct_D_tinc-top01pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_inc99_999_R)**2)*sort_D_R(:,3)*(top1pct_D_tinc-top01pct_D_tinc)/tempsum ) )**0.5


! Percentile 99.5-99.9%
	tempsum = sum(sort_D_R(:,1)*(top05pct_D_tinc-top01pct_D_tinc)+sort_D_R(:,2)*(top05pct_D_tinc-top01pct_D_tinc)+sort_D_R(:,3)*(top05pct_D_tinc-top01pct_D_tinc))
	Avg_inc995_999_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum )
	
	SD_inc995_999_R = ( sum( ((R_ANNUAL(1)-Avg_inc995_999_R)**2)*sort_D_R(:,1)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_inc995_999_R)**2)*sort_D_R(:,2)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_inc995_999_R)**2)*sort_D_R(:,3)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum ) )**0.5
	

! Percentile 99-99.5%
	tempsum = sum(sort_D_R(:,1)*(top1pct_D_tinc-top05pct_D_tinc)+sort_D_R(:,2)*(top1pct_D_tinc-top05pct_D_tinc)+sort_D_R(:,3)*(top1pct_D_tinc-top05pct_D_tinc))
	Avg_inc99_995_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum )
	
	SD_inc99_995_R = ( sum( ((R_ANNUAL(1)-Avg_inc99_995_R)**2)*sort_D_R(:,1)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_inc99_995_R)**2)*sort_D_R(:,2)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_inc99_995_R)**2)*sort_D_R(:,3)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum ) )**0.5
	

! Percentile 95-99%
	tempsum = sum(sort_D_R(:,1)*(top5pct_D_tinc-top1pct_D_tinc)+sort_D_R(:,2)*(top5pct_D_tinc-top1pct_D_tinc)+sort_D_R(:,3)*(top5pct_D_tinc-top1pct_D_tinc))
	Avg_inc95_99_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum )
	
	SD_inc95_99_R = ( sum( ((R_ANNUAL(1)-Avg_inc95_99_R)**2)*sort_D_R(:,1)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_inc95_99_R)**2)*sort_D_R(:,2)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_inc95_99_R)**2)*sort_D_R(:,3)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum ) )**0.5


! Percentile 90-95%
	tempsum = sum(sort_D_R(:,1)*(top10pct_D_tinc-top5pct_D_tinc)+sort_D_R(:,2)*(top10pct_D_tinc-top5pct_D_tinc)+sort_D_R(:,3)*(top10pct_D_tinc-top5pct_D_tinc))
	Avg_inc90_95_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum )
	
	SD_inc90_95_R = ( sum( ((R_ANNUAL(1)-Avg_inc90_95_R)**2)*sort_D_R(:,1)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_inc90_95_R)**2)*sort_D_R(:,2)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_inc90_95_R)**2)*sort_D_R(:,3)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum ) )**0.5
	

! Percentile 0-90%
	tempsum = sum(sort_D_R(:,1)*(1-top10pct_D_tinc)+sort_D_R(:,2)*(1-top10pct_D_tinc)+sort_D_R(:,3)*(1-top10pct_D_tinc))
	Avg_incbot90_R =  sum( R_ANNUAL(1)*sort_D_R(:,1)*(1-top10pct_D_tinc)/tempsum + R_ANNUAL(2)*sort_D_R(:,2)*(1-top10pct_D_tinc)/tempsum + R_ANNUAL(3)*sort_D_R(:,3)*(1-top10pct_D_tinc)/tempsum )

	SD_incbot90_R = ( sum( ((R_ANNUAL(1)-Avg_incbot90_R)**2)*sort_D_R(:,1)*(1-top10pct_D_tinc)/tempsum + ((R_ANNUAL(2)-Avg_incbot90_R)**2)*sort_D_R(:,2)*(1-top10pct_D_tinc)/tempsum + ((R_ANNUAL(3)-Avg_incbot90_R)**2)*sort_D_R(:,3)*(1-top10pct_D_tinc)/tempsum ) )**0.5


	! Weighted Average Return: wealth-weighted within income groups

	sort_D_R_weighted(:,:) = 0.0D0
	DO IR=1,NGRIDR	
		sort_D_R_weighted(:,IR) = sort_A_tinc*sort_D_R(:,IR)
	END DO 

	sort_D_Z_weighted(:,:) = 0.0D0
	DO IS=1,nn	
		sort_D_Z_weighted(:,IS) = sort_A_tinc*sort_D_Z(:,IS)
	END DO 
	

	! Top 0.001%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top0001pct_D_tinc)
			END DO 
		
		Avg_topinc0001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc0001_R_weighted = Avg_topinc0001_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top0001pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc0001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc0001_R_weighted = VAR_topinc0001_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc0001_R_weighted)**2)*sort_D_R_weighted(:,IR)*top0001pct_D_tinc/tempsum)
			END DO
			SD_topinc0001_R_weighted = VAR_topinc0001_R_weighted**0.5


	! Top 0.005%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top0005pct_D_tinc)
			END DO 
		
		Avg_topinc0005_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc0005_R_weighted = Avg_topinc0005_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top0005pct_D_tinc/tempsum)
			END DO
	
		VAR_topinc0005_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc0005_R_weighted = VAR_topinc0005_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc0005_R_weighted)**2)*sort_D_R_weighted(:,IR)*top0005pct_D_tinc/tempsum)
			END DO
			SD_topinc0005_R_weighted = VAR_topinc0005_R_weighted**0.5


	! Top 0.01%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top001pct_D_tinc)
			END DO 
		
		Avg_topinc001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc001_R_weighted = Avg_topinc001_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top001pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc001_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc001_R_weighted = VAR_topinc001_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc001_R_weighted)**2)*sort_D_R_weighted(:,IR)*top001pct_D_tinc/tempsum)
			END DO
			SD_topinc001_R_weighted = VAR_topinc001_R_weighted**0.5


	! Top 0.1%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top01pct_D_tinc)
			END DO 
		
		Avg_topinc01_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc01_R_weighted = Avg_topinc01_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top01pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc01_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc01_R_weighted = VAR_topinc01_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc01_R_weighted)**2)*sort_D_R_weighted(:,IR)*top01pct_D_tinc/tempsum)
			END DO
			SD_topinc01_R_weighted = VAR_topinc01_R_weighted**0.5


	! Top 0.5%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top05pct_D_tinc)
			END DO 
		
		Avg_topinc05_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc05_R_weighted = Avg_topinc05_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top05pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc05_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc05_R_weighted = VAR_topinc05_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc05_R_weighted)**2)*sort_D_R_weighted(:,IR)*top05pct_D_tinc/tempsum)
			END DO
			SD_topinc05_R_weighted = VAR_topinc05_R_weighted**0.5


	! Top 1%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top1pct_D_tinc)
			END DO 
		
		Avg_topinc1_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc1_R_weighted = Avg_topinc1_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top1pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc1_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc1_R_weighted = VAR_topinc1_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc1_R_weighted)**2)*sort_D_R_weighted(:,IR)*top1pct_D_tinc/tempsum)
			END DO
			SD_topinc1_R_weighted = VAR_topinc1_R_weighted**0.5


	! Top 5%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top5pct_D_tinc)
			END DO 
		
		Avg_topinc5_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc5_R_weighted = Avg_topinc5_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top5pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc5_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc5_R_weighted = VAR_topinc5_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc5_R_weighted)**2)*sort_D_R_weighted(:,IR)*top5pct_D_tinc/tempsum)
			END DO
			SD_topinc5_R_weighted = VAR_topinc5_R_weighted**0.5


	! Top 10%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top10pct_D_tinc)
			END DO 
		
		Avg_topinc10_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc10_R_weighted = Avg_topinc10_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top10pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc10_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc10_R_weighted = VAR_topinc10_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc10_R_weighted)**2)*sort_D_R_weighted(:,IR)*top10pct_D_tinc/tempsum)
			END DO
			SD_topinc10_R_weighted = VAR_topinc10_R_weighted**0.5


	! Top 20%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top20pct_D_tinc)
			END DO 
		
		Avg_topinc20_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc20_R_weighted = Avg_topinc20_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top20pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc20_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc20_R_weighted = VAR_topinc20_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc20_R_weighted)**2)*sort_D_R_weighted(:,IR)*top20pct_D_tinc/tempsum)
			END DO
			SD_topinc20_R_weighted = VAR_topinc20_R_weighted**0.5


	! Top 40%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top40pct_D_tinc)
			END DO 
		
		Avg_topinc40_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc40_R_weighted = Avg_topinc40_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top40pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc40_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc40_R_weighted = VAR_topinc40_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc40_R_weighted)**2)*sort_D_R_weighted(:,IR)*top40pct_D_tinc/tempsum)
			END DO
			SD_topinc40_R_weighted = VAR_topinc40_R_weighted**0.5


	! Top 60%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top60pct_D_tinc)
			END DO 
		
		Avg_topinc60_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc60_R_weighted = Avg_topinc60_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top60pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc60_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc60_R_weighted = VAR_topinc60_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc60_R_weighted)**2)*sort_D_R_weighted(:,IR)*top60pct_D_tinc/tempsum)
			END DO
			SD_topinc60_R_weighted = VAR_topinc60_R_weighted**0.5


	! Top 80%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*top80pct_D_tinc)
			END DO 
		
		Avg_topinc80_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_topinc80_R_weighted = Avg_topinc80_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*top80pct_D_tinc/tempsum) 
			END DO
	
		VAR_topinc80_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_topinc80_R_weighted = VAR_topinc80_R_weighted + sum(((R_ANNUAL(IR)-Avg_topinc80_R_weighted)**2)*sort_D_R_weighted(:,IR)*top80pct_D_tinc/tempsum)
			END DO
			SD_topinc80_R_weighted = VAR_topinc80_R_weighted**0.5


	! Percentile 99.5-99.9%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(top05pct_D_tinc-top01pct_D_tinc))
			END DO 
		
		Avg_inc995_999_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_inc995_999_R_weighted = Avg_inc995_999_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum) 
			END DO
	
		VAR_inc995_999_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_inc995_999_R_weighted = VAR_inc995_999_R_weighted + sum(((R_ANNUAL(IR)-Avg_inc995_999_R_weighted)**2)*sort_D_R_weighted(:,IR)*(top05pct_D_tinc-top01pct_D_tinc)/tempsum)
			END DO
			SD_inc995_999_R_weighted = VAR_inc995_999_R_weighted**0.5


	! Percentile 99-99.5%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(top1pct_D_tinc-top05pct_D_tinc))
			END DO 
		
		Avg_inc99_995_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_inc99_995_R_weighted = Avg_inc99_995_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum) 
			END DO
	
		VAR_inc99_995_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_inc99_995_R_weighted = VAR_inc99_995_R_weighted + sum(((R_ANNUAL(IR)-Avg_inc99_995_R_weighted)**2)*sort_D_R_weighted(:,IR)*(top1pct_D_tinc-top05pct_D_tinc)/tempsum)
			END DO
			SD_inc99_995_R_weighted = VAR_inc99_995_R_weighted**0.5


	! Percentile 95-99%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(top5pct_D_tinc-top1pct_D_tinc))
			END DO 
		
		Avg_inc95_99_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_inc95_99_R_weighted = Avg_inc95_99_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum) 
			END DO
	
		VAR_inc95_99_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_inc95_99_R_weighted = VAR_inc95_99_R_weighted + sum(((R_ANNUAL(IR)-Avg_inc95_99_R_weighted)**2)*sort_D_R_weighted(:,IR)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum)
			END DO
			SD_inc95_99_R_weighted = VAR_inc95_99_R_weighted**0.5


	! Percentile 95-99%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(top5pct_D_tinc-top1pct_D_tinc))
			END DO 
		
		Avg_inc95_99_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_inc95_99_R_weighted = Avg_inc95_99_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum) 
			END DO
	
		VAR_inc95_99_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_inc95_99_R_weighted = VAR_inc95_99_R_weighted + sum(((R_ANNUAL(IR)-Avg_inc95_99_R_weighted)**2)*sort_D_R_weighted(:,IR)*(top5pct_D_tinc-top1pct_D_tinc)/tempsum)
			END DO
			SD_inc95_99_R_weighted = VAR_inc95_99_R_weighted**0.5


	! Percentile 90-95%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(top10pct_D_tinc-top5pct_D_tinc))
			END DO 
		
		Avg_inc90_95_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_inc90_95_R_weighted = Avg_inc90_95_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum) 
			END DO
	
		VAR_inc90_95_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_inc90_95_R_weighted = VAR_inc90_95_R_weighted + sum(((R_ANNUAL(IR)-Avg_inc90_95_R_weighted)**2)*sort_D_R_weighted(:,IR)*(top10pct_D_tinc-top5pct_D_tinc)/tempsum)
			END DO
			SD_inc90_95_R_weighted = VAR_inc90_95_R_weighted**0.5


	! Percentile 0-90%
		tempsum = 0.0
			DO IR = 1,NGRIDR
				tempsum = tempsum + sum(sort_D_R_weighted(:,IR)*(1-top10pct_D_tinc))
			END DO 
		
		Avg_botinc90_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				Avg_botinc90_R_weighted = Avg_botinc90_R_weighted + sum(R_ANNUAL(IR)*sort_D_R_weighted(:,IR)*(1-top10pct_D_tinc)/tempsum) 
			END DO
	
		VAR_botinc90_R_weighted = 0.0D0
			DO IR = 1,NGRIDR
				VAR_botinc90_R_weighted = VAR_botinc90_R_weighted + sum(((R_ANNUAL(IR)-Avg_botinc90_R_weighted)**2)*sort_D_R_weighted(:,IR)*(1-top10pct_D_tinc)/tempsum)
			END DO
			SD_botinc90_R_weighted = VAR_botinc90_R_weighted**0.5


! Distribution of z,r for top income group

! Top 0.1% income group
DO IR=1,NGRIDR
	share_r_top01_tinc(IR) = sum(sort_D_R(:,IR)*top01pct_D_tinc)
END DO 

DO IS=1,nn
	share_z_top01_tinc(IS) = sum(sort_D_Z(:,IS)*top01pct_D_tinc)
END DO 


! Top 0.1% income group (weighted dist)
DO IR=1,NGRIDR
	weighted_share_r_top01_tinc(IR) = sum(sort_D_R_weighted(:,IR)*top01pct_D_tinc)
END DO 

DO IS=1,nn
	weighted_share_z_top01_tinc(IS) = sum(sort_D_Z_weighted(:,IS)*top01pct_D_tinc)
END DO 


END SUBROUTINE

!***************************************************************************************
SUBROUTINE income_partition   

ALLOCATE( totalincome((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( earning_share((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( kincome_share((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( trans_share((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_share((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_2030((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_3145((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_4665((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_6699((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( ind_topz((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( ind_z8((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( ind_topr((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( ind_ri((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( ind_zi((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )

state_pos = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR
            DO IS=1,nn          
			
                state_pos = state_pos + 1
				JA=IDCWA(AGE,IA,IR,IS)
				JN=IDCWN(AGE,IA,IR,IS)
				
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS) 
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME
				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + INCOME))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+INCOME - bendy) &
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)	!+gov_trans				
				
				totalincome(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + WAGE*EFFLONG(AGE)*N(JN)*W(IS) 
				earning_share(state_pos) = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				kincome_share(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)
				trans_share(state_pos) = 0.0
				age_share(state_pos) = AGE
						                
            END DO
        END DO
    END DO
END DO


DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR  
			DO IS=1,nn                
			
                state_pos = state_pos + 1
			
				INCOME = 0.0
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 
				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + SS(IS)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+SS(IS) - bendy) &
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)	
				
				totalincome(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)   !+ medicare	
				kincome_share(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)
				earning_share(state_pos) = 0.0
				trans_share(state_pos) = 0.0
				age_share(state_pos) = AGE

			END DO 
        END DO
    END DO
END DO

! sort by total income:
totalincome = totalincome(record_position_tinc)
kincome_share = kincome_share(record_position_tinc)
earning_share = earning_share(record_position_tinc)
age_share = age_share(record_position_tinc)


! Create age group dummies
age_2030 = 0
age_3145 = 0
age_4665 = 0
age_6699 = 0
where ( age_share .le. 2 ) age_2030 = 1
where ( age_share .ge. 3 .AND. age .le. 5 ) age_3145 = 1
where ( age_share .ge. 6 .AND. age .le. 9 ) age_4665 = 1
where ( age_share .ge. 10 ) age_6699 = 1


! Average		
	
	earning_share_avg = sum(earning_share*sort_D_TINC)/sum(totalincome*sort_D_TINC)
	kincome_share_avg = sum(kincome_share*sort_D_TINC)/sum(totalincome*sort_D_TINC)
	trans_share_avg = sum(trans_share*sort_D_TINC)/sum(totalincome*sort_D_TINC)

	age_share_avg = sum(age_share*sort_D_TINC)

! Top 0.1%		
	
	earning_share01 = (sum(earning_share*sort_D_TINC*top01pct_D_tinc/(sum(sort_D_TINC*top01pct_D_tinc))))/sum(totalincome*sort_D_TINC*top01pct_D_tinc/(sum(sort_D_TINC*top01pct_D_tinc)))
	kincome_share01 = (sum(kincome_share*sort_D_TINC*top01pct_D_tinc/(sum(sort_D_TINC*top01pct_D_tinc))))/sum(totalincome*sort_D_TINC*top01pct_D_tinc/(sum(sort_D_TINC*top01pct_D_tinc)))
	trans_share01 = (sum(trans_share*sort_D_TINC*top01pct_D_tinc/(sum(sort_D_TINC*top01pct_D_tinc))))/sum(totalincome*sort_D_TINC*top01pct_D_tinc/(sum(sort_D_TINC*top01pct_D_tinc)))
	age_share01 = sum( age_share*sort_D_TINC*top01pct_D_tinc/(sum(sort_D_TINC*top01pct_D_tinc)) )
		

! Top 1%		
	
	earning_share1 = (sum(earning_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc))))/sum(totalincome*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)))
	kincome_share1 = (sum(kincome_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc))))/sum(totalincome*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)))
	trans_share1 = (sum(trans_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc))))/sum(totalincome*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)))
	age_share1 = sum( age_share*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)) )
	age_share1_2030 = (sum(age_2030 * sort_D_TINC * top1pct_D_tinc))/sum(sort_D_TINC*top1pct_D_tinc)
	age_share1_3145 = (sum(age_3145 * sort_D_TINC * top1pct_D_tinc))/sum(sort_D_TINC*top1pct_D_tinc)
	age_share1_4665 = (sum(age_4665 * sort_D_TINC * top1pct_D_tinc))/sum(sort_D_TINC*top1pct_D_tinc)
	age_share1_6699 = (sum(age_6699 * sort_D_TINC * top1pct_D_tinc))/sum(sort_D_TINC*top1pct_D_tinc)
	
	! Top 10%		
	
		earning_share10 = (sum(earning_share*sort_D_TINC*top10pct_D_tinc/(sum(sort_D_TINC*top10pct_D_tinc))))/sum(totalincome*sort_D_TINC*top10pct_D_tinc/(sum(sort_D_TINC*top10pct_D_tinc)))
		print*, 'earning_share10=', earning_share10
	
	
! 95-99%		
	
	earning_share9599 = (sum(earning_share*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))))
	kincome_share9599 = (sum(kincome_share*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))))
	trans_share9599 = (sum(trans_share*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))))
	age_share9599 = sum( age_share*sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc)/(sum(sort_D_TINC*(top5pct_D_tinc-top1pct_D_tinc))) )


! 90-95%		
	
	earning_share9095 = (sum(earning_share*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))))
	kincome_share9095 = (sum(kincome_share*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))))
	trans_share9095 = (sum(trans_share*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))))
	age_share9095 = sum( age_share*sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc)/(sum(sort_D_TINC*(top10pct_D_tinc-top5pct_D_tinc))) )


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
	
	earning_share1q = (sum(earning_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))))
	kincome_share1q = (sum(kincome_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))))
	trans_share1q = (sum(trans_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))))
	age_share1q = sum( age_share*sort_D_tinc*(bot20pct_D_tinc)/(sum(sort_D_tinc*(bot20pct_D_tinc))) )

! Bottom 90%		

	earning_share0090 = (sum(earning_share*sort_D_tinc*(1-top10pct_D_tinc)/(sum(sort_D_tinc*(1-top10pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(1-top10pct_D_tinc)/(sum(sort_D_tinc*(1-top10pct_D_tinc))))
	kincome_share0090 = (sum(kincome_share*sort_D_tinc*(1-top10pct_D_tinc)/(sum(sort_D_tinc*(1-top10pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(1-top10pct_D_tinc)/(sum(sort_D_tinc*(1-top10pct_D_tinc))))
	trans_share0090 = (sum(trans_share*sort_D_tinc*(1-top10pct_D_tinc)/(sum(sort_D_tinc*(1-top10pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(1-top10pct_D_tinc)/(sum(sort_D_tinc*(1-top10pct_D_tinc))))
	age_share0090 = sum( age_share*sort_D_TINC*(1-top10pct_D_tinc)/(sum(sort_D_TINC*(1-top10pct_D_tinc))) )


! Bottom 5-10%	
	
	earning_share0510 = (sum(earning_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))))
	kincome_share0510 = (sum(kincome_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))))
	trans_share0510 = (sum(trans_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))))
	age_share0510 = sum( age_share*sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc)/(sum(sort_D_tinc*(top95pct_D_tinc-top90pct_D_tinc))) )


! Bottom 1-5%	
	
	earning_share0105 = (sum(earning_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))))
	kincome_share0105 = (sum(kincome_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))))
	trans_share0105 = (sum(trans_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)))))/sum(totalincome*sort_D_TINC*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))))
	age_share0105 = sum( age_share*sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc)/(sum(sort_D_tinc*(top99pct_D_tinc-top95pct_D_tinc))) )
	
!**********************************************************************************************************************

! share of income acrruing to top z and r groups:
	
	ind_topz = 0
	ind_z8 = 0
	ind_topr = 0
	where ( ind_z == 7 .or. ind_z == 8 ) ind_topz = 1
	where ( ind_z == 8 ) ind_z8 = 1
	where ( ind_r == 3 ) ind_topr = 1

	share_topz_1 = (sum(totalincome*sort_D_TINC*top1pct_D_tinc*ind_topz))/sum(totalincome*sort_D_TINC*top1pct_D_tinc)
	share_topz_01 = (sum(totalincome*sort_D_TINC*top01pct_D_tinc*ind_topz))/sum(totalincome*sort_D_TINC*top01pct_D_tinc)
	share_topz_all = (sum(totalincome*sort_D_TINC*ind_topz))/sum(totalincome*sort_D_TINC)

	share_z8_1 = (sum(totalincome*sort_D_TINC*top1pct_D_tinc*ind_z8))/sum(totalincome*sort_D_TINC*top1pct_D_tinc)
	share_z8_01 = (sum(totalincome*sort_D_TINC*top01pct_D_tinc*ind_z8))/sum(totalincome*sort_D_TINC*top01pct_D_tinc)
	share_z8_all = (sum(totalincome*sort_D_TINC*ind_z8))/sum(totalincome*sort_D_TINC)

	share_topr_1 = (sum(totalincome*sort_D_TINC*top1pct_D_tinc*ind_topr))/sum(totalincome*sort_D_TINC*top1pct_D_tinc)
	share_topr_01 = (sum(totalincome*sort_D_TINC*top01pct_D_tinc*ind_topr))/sum(totalincome*sort_D_TINC*top01pct_D_tinc)
	share_topr_all = (sum(totalincome*sort_D_TINC*ind_topr))/sum(totalincome*sort_D_TINC)

	share_topboth_1 = (sum(totalincome*sort_D_TINC*top1pct_D_tinc*ind_topz*ind_topr))/sum(totalincome*sort_D_TINC*top1pct_D_tinc)
	share_topboth_01 = (sum(totalincome*sort_D_TINC*top01pct_D_tinc*ind_topz*ind_topr))/sum(totalincome*sort_D_TINC*top01pct_D_tinc)
	share_topboth_all = (sum(totalincome*sort_D_TINC*ind_topz*ind_topr))/sum(totalincome*sort_D_TINC)
	
	DO IR = 1,NGRIDR
		ind_ri = 0
		where ( ind_r == IR ) ind_ri = 1
		DO IS = 1,nn
			ind_zi = 0
			where ( ind_z == IS ) ind_zi = 1
			share_zr_all(IS,IR) = sum(totalincome*sort_D_TINC*ind_zi*ind_ri)/sum(totalincome*sort_D_TINC)
			share_zr_top1(IS,IR) = sum(totalincome*sort_D_TINC*top1pct_D_tinc*ind_zi*ind_ri)/sum(totalincome*sort_D_TINC*top1pct_D_tinc)
			share_zr_top01(IS,IR) = sum(totalincome*sort_D_TINC*top01pct_D_tinc*ind_zi*ind_ri)/sum(totalincome*sort_D_TINC*top01pct_D_tinc)
		END DO
	END DO
	

DEALLOCATE(age_2030, age_3145, age_4665, age_6699)

END SUBROUTINE
!***************************************************************************************

SUBROUTINE income_partition_sort_by_wealth

ALLOCATE( totalincome_sort_by_wealth((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( earning_share_sort_by_wealth((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( kincome_share_sort_by_wealth((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( trans_share_sort_by_wealth((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_share_sort_by_wealth((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_2030((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_3145((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_4665((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_6699((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )

state_pos = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR
            DO IS=1,nn          
			
                state_pos = state_pos + 1
				JA=IDCWA(AGE,IA,IR,IS)
				JN=IDCWN(AGE,IA,IR,IS)
				
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS) 
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME
				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + INCOME))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+INCOME - bendy) &
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)				
				
				
				totalincome_sort_by_wealth(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				earning_share_sort_by_wealth(state_pos) = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				kincome_share_sort_by_wealth(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)
				trans_share_sort_by_wealth(state_pos) = 0.0
				age_share_sort_by_wealth(state_pos) = AGE
				
								        
            END DO
        END DO
    END DO
END DO


DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR  
			DO IS=1,nn                
			
                state_pos = state_pos + 1
			
				INCOME = 0.0
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 
				yd = lambda*(MIN(bendy,min(R(IR)*A(IA),d_c) + SS(IS)))**(1.0-tau_l) &
					+(1.0-ty_max)*MAX(0.0, min(R(IR)*A(IA),d_c)+SS(IS) - bendy) &
					+(1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)	
											
				
				totalincome_sort_by_wealth(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)  
				earning_share_sort_by_wealth(state_pos) = 0.0
				kincome_share_sort_by_wealth(state_pos) = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0)
				trans_share_sort_by_wealth(state_pos) = 0.0
				age_share_sort_by_wealth(state_pos) = AGE


			END DO 
        END DO
    END DO
END DO

! sort by wealth:
totalincome_sort_by_wealth = totalincome_sort_by_wealth(record_position_A)
earning_share_sort_by_wealth = earning_share_sort_by_wealth(record_position_A)
kincome_share_sort_by_wealth = kincome_share_sort_by_wealth(record_position_A)
age_share_sort_by_wealth = age_share_sort_by_wealth(record_position_A)

! Create age group dummies
	age_2030 = 0
	age_3145 = 0
	age_4665 = 0
	age_6699 = 0
	where ( age_share_sort_by_wealth .le. 2 ) age_2030 = 1
	where ( age_share_sort_by_wealth .ge. 3 .AND. age .le. 5 ) age_3145 = 1
	where ( age_share_sort_by_wealth .ge. 6 .AND. age .le. 9 ) age_4665 = 1
	where ( age_share_sort_by_wealth .ge. 10 ) age_6699 = 1


! Average		
	
	earning_share_avg_sort_by_wealth = sum(earning_share_sort_by_wealth*sort_D)/sum(totalincome_sort_by_wealth*sort_D)
	kincome_share_avg_sort_by_wealth = sum(kincome_share_sort_by_wealth*sort_D)/sum(totalincome_sort_by_wealth*sort_D)
	trans_share_avg_sort_by_wealth = sum(trans_share_sort_by_wealth*sort_D)/sum(totalincome_sort_by_wealth*sort_D)	
	age_share_avg_sort_by_wealth = sum(age_share_sort_by_wealth*sort_D)



! Top 0.01%		
	
	earning_share001_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*top001pct_D/(sum(sort_D*top001pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top001pct_D/(sum(sort_D*top001pct_D)))
	kincome_share001_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*top001pct_D/(sum(sort_D*top001pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top001pct_D/(sum(sort_D*top001pct_D)))
	trans_share001_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*top001pct_D/(sum(sort_D*top001pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top001pct_D/(sum(sort_D*top001pct_D)))
	age_share001_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*top001pct_D/(sum(sort_D*top001pct_D)) )


! Top 0.05%		
	
	earning_share005_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*top005pct_D/(sum(sort_D*top005pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top005pct_D/(sum(sort_D*top005pct_D)))
	kincome_share005_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*top005pct_D/(sum(sort_D*top005pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top005pct_D/(sum(sort_D*top005pct_D)))
	trans_share005_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*top005pct_D/(sum(sort_D*top005pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top005pct_D/(sum(sort_D*top005pct_D)))
	age_share005_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*top005pct_D/(sum(sort_D*top005pct_D)) )


! 99.9-99.99%		
	
	earning_share9999999_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top01pct_D-top001pct_D)/(sum(sort_D*(top01pct_D-top001pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top01pct_D-top001pct_D)/(sum(sort_D*(top01pct_D-top001pct_D))))
	kincome_share9999999_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top01pct_D-top001pct_D)/(sum(sort_D*(top01pct_D-top001pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top01pct_D-top001pct_D)/(sum(sort_D*(top01pct_D-top001pct_D))))
	trans_share9999999_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top01pct_D-top001pct_D)/(sum(sort_D*(top01pct_D-top001pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top01pct_D-top001pct_D)/(sum(sort_D*(top01pct_D-top001pct_D))))
	age_share9999999_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top01pct_D-top001pct_D)/(sum(sort_D*(top01pct_D-top001pct_D))) )


! Top 0.1%		
	
	earning_share01_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*top01pct_D/(sum(sort_D*top01pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top01pct_D/(sum(sort_D*top01pct_D)))
	kincome_share01_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*top01pct_D/(sum(sort_D*top01pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top01pct_D/(sum(sort_D*top01pct_D)))
	trans_share01_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*top01pct_D/(sum(sort_D*top01pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top01pct_D/(sum(sort_D*top01pct_D)))
	age_share01_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*top01pct_D/(sum(sort_D*top01pct_D)) )

! 99.5-99.9%		
	
	earning_share995999_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top05pct_D-top01pct_D)/(sum(sort_D*(top05pct_D-top01pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top05pct_D-top01pct_D)/(sum(sort_D*(top05pct_D-top01pct_D))))
	kincome_share995999_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top05pct_D-top01pct_D)/(sum(sort_D*(top05pct_D-top01pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top05pct_D-top01pct_D)/(sum(sort_D*(top05pct_D-top01pct_D))))
	trans_share995999_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top05pct_D-top01pct_D)/(sum(sort_D*(top05pct_D-top01pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top05pct_D-top01pct_D)/(sum(sort_D*(top05pct_D-top01pct_D))))
	age_share995999_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top05pct_D-top01pct_D)/(sum(sort_D*(top05pct_D-top01pct_D))) )
	


! Top 0.5%		
	
	earning_share05_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*top05pct_D/(sum(sort_D*top05pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top05pct_D/(sum(sort_D*top05pct_D)))
	kincome_share05_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*top05pct_D/(sum(sort_D*top05pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top05pct_D/(sum(sort_D*top05pct_D)))
	trans_share05_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*top05pct_D/(sum(sort_D*top05pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top05pct_D/(sum(sort_D*top05pct_D)))
	age_share05_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*top05pct_D/(sum(sort_D*top05pct_D)) )


! 99-99.5%		
	
	earning_share99995_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top1pct_D-top05pct_D)/(sum(sort_D*(top1pct_D-top05pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top1pct_D-top05pct_D)/(sum(sort_D*(top1pct_D-top05pct_D))))
	kincome_share99995_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top1pct_D-top05pct_D)/(sum(sort_D*(top1pct_D-top05pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top1pct_D-top05pct_D)/(sum(sort_D*(top1pct_D-top05pct_D))))
	trans_share99995_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top1pct_D-top05pct_D)/(sum(sort_D*(top1pct_D-top05pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top1pct_D-top05pct_D)/(sum(sort_D*(top1pct_D-top05pct_D))))
	age_share99995_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top1pct_D-top05pct_D)/(sum(sort_D*(top1pct_D-top05pct_D))) )
	


! Top 1%		
	
	earning_share1_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*top1pct_D/(sum(sort_D*top1pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top1pct_D/(sum(sort_D*top1pct_D)))
	kincome_share1_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*top1pct_D/(sum(sort_D*top1pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top1pct_D/(sum(sort_D*top1pct_D)))
	trans_share1_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*top1pct_D/(sum(sort_D*top1pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top1pct_D/(sum(sort_D*top1pct_D)))
	age_share1_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*top1pct_D/(sum(sort_D*top1pct_D)) )


	age_share1_sort_by_wealth_2030 = (sum(age_2030 * sort_D * top1pct_D))/sum(sort_D*top1pct_D)
	age_share1_sort_by_wealth_3145 = (sum(age_3145 * sort_D * top1pct_D))/sum(sort_D*top1pct_D)
	age_share1_sort_by_wealth_4665 = (sum(age_4665 * sort_D * top1pct_D))/sum(sort_D*top1pct_D)
	age_share1_sort_by_wealth_6699 = (sum(age_6699 * sort_D * top1pct_D))/sum(sort_D*top1pct_D)

	
	
! 95-99%		
	
	earning_share9599_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D))))
	kincome_share9599_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D))))
	trans_share9599_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D))))
	age_share9599_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top5pct_D-top1pct_D)/(sum(sort_D*(top5pct_D-top1pct_D))) )


! 90-95%		
	
	earning_share9095_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D))))
	kincome_share9095_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D))))
	trans_share9095_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D))))
	age_share9095_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top10pct_D-top5pct_D)/(sum(sort_D*(top10pct_D-top5pct_D))) )


!  80 - 90%		
	
	earning_share8090_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top20pct_D-top10pct_D)/(sum(sort_D*(top20pct_D-top10pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top20pct_D-top10pct_D)/(sum(sort_D*(top20pct_D-top10pct_D))))
	kincome_share8090_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top20pct_D-top10pct_D)/(sum(sort_D*(top20pct_D-top10pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top20pct_D-top10pct_D)/(sum(sort_D*(top20pct_D-top10pct_D))))
	trans_share8090_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top20pct_D-top10pct_D)/(sum(sort_D*(top20pct_D-top10pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top20pct_D-top10pct_D)/(sum(sort_D*(top20pct_D-top10pct_D))))
	age_share8090_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top20pct_D-top10pct_D)/(sum(sort_D*(top20pct_D-top10pct_D))) )


!  80 - 100%		
	
	earning_share5q_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*top20pct_D/(sum(sort_D*top20pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top20pct_D/(sum(sort_D*top20pct_D)))
	kincome_share5q_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*top20pct_D/(sum(sort_D*top20pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top20pct_D/(sum(sort_D*top20pct_D)))
	trans_share5q_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*top20pct_D/(sum(sort_D*top20pct_D))))/sum(totalincome_sort_by_wealth*sort_D*top20pct_D/(sum(sort_D*top20pct_D)))
	age_share5q_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*top20pct_D/(sum(sort_D*top20pct_D)) )

!  60 - 80%		
	
	earning_share4q_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top40pct_D-top20pct_D)/(sum(sort_D*(top40pct_D-top20pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top40pct_D-top20pct_D)/(sum(sort_D*(top40pct_D-top20pct_D))))
	kincome_share4q_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top40pct_D-top20pct_D)/(sum(sort_D*(top40pct_D-top20pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top40pct_D-top20pct_D)/(sum(sort_D*(top40pct_D-top20pct_D))))
	trans_share4q_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top40pct_D-top20pct_D)/(sum(sort_D*(top40pct_D-top20pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top40pct_D-top20pct_D)/(sum(sort_D*(top40pct_D-top20pct_D))))
	age_share4q_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top40pct_D-top20pct_D)/(sum(sort_D*(top40pct_D-top20pct_D))) )

!  40 - 60%		
	
	earning_share3q_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top60pct_D-top40pct_D)/(sum(sort_D*(top60pct_D-top40pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top60pct_D-top40pct_D)/(sum(sort_D*(top60pct_D-top40pct_D))))
	kincome_share3q_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top60pct_D-top40pct_D)/(sum(sort_D*(top60pct_D-top40pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top60pct_D-top40pct_D)/(sum(sort_D*(top60pct_D-top40pct_D))))
	trans_share3q_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top60pct_D-top40pct_D)/(sum(sort_D*(top60pct_D-top40pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top60pct_D-top40pct_D)/(sum(sort_D*(top60pct_D-top40pct_D))))
	age_share3q_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top60pct_D-top40pct_D)/(sum(sort_D*(top60pct_D-top40pct_D))) )

!  20 - 40%		
	
	earning_share2q_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top80pct_D-top60pct_D)/(sum(sort_D*(top80pct_D-top60pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top80pct_D-top60pct_D)/(sum(sort_D*(top80pct_D-top60pct_D))))
	kincome_share2q_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top80pct_D-top60pct_D)/(sum(sort_D*(top80pct_D-top60pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top80pct_D-top60pct_D)/(sum(sort_D*(top80pct_D-top60pct_D))))
	trans_share2q_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top80pct_D-top60pct_D)/(sum(sort_D*(top80pct_D-top60pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top80pct_D-top60pct_D)/(sum(sort_D*(top80pct_D-top60pct_D))))
	age_share2q_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top80pct_D-top60pct_D)/(sum(sort_D*(top80pct_D-top60pct_D))) )

!  0 - 20%		
	
	earning_share1q_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(1-top80pct_D)/(sum(sort_D*(1-top80pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(1-top80pct_D)/(sum(sort_D*(1-top80pct_D))))
	kincome_share1q_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(1-top80pct_D)/(sum(sort_D*(1-top80pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(1-top80pct_D)/(sum(sort_D*(1-top80pct_D))))
	trans_share1q_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(1-top80pct_D)/(sum(sort_D*(1-top80pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(1-top80pct_D)/(sum(sort_D*(1-top80pct_D))))
	age_share1q_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(1-top80pct_D)/(sum(sort_D*(1-top80pct_D))) )

! Bottom 5-10%	
	
	earning_share0510_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top95pct_D-top90pct_D)/(sum(sort_D*(top95pct_D-top90pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top95pct_D-top90pct_D)/(sum(sort_D*(top95pct_D-top90pct_D))))
	kincome_share0510_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top95pct_D-top90pct_D)/(sum(sort_D*(top95pct_D-top90pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top95pct_D-top90pct_D)/(sum(sort_D*(top95pct_D-top90pct_D))))
	trans_share0510_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top95pct_D-top90pct_D)/(sum(sort_D*(top95pct_D-top90pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top95pct_D-top90pct_D)/(sum(sort_D*(top95pct_D-top90pct_D))))
	age_share0510_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top95pct_D-top90pct_D)/(sum(sort_D*(top95pct_D-top90pct_D))) )


! Bottom 1-5%	
	
	earning_share0105_sort_by_wealth = (sum(earning_share_sort_by_wealth*sort_D*(top99pct_D-top95pct_D)/(sum(sort_D*(top99pct_D-top95pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top99pct_D-top95pct_D)/(sum(sort_D*(top99pct_D-top95pct_D))))
	kincome_share0105_sort_by_wealth = (sum(kincome_share_sort_by_wealth*sort_D*(top99pct_D-top95pct_D)/(sum(sort_D*(top99pct_D-top95pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top99pct_D-top95pct_D)/(sum(sort_D*(top99pct_D-top95pct_D))))
	trans_share0105_sort_by_wealth = (sum(trans_share_sort_by_wealth*sort_D*(top99pct_D-top95pct_D)/(sum(sort_D*(top99pct_D-top95pct_D)))))/sum(totalincome_sort_by_wealth*sort_D*(top99pct_D-top95pct_D)/(sum(sort_D*(top99pct_D-top95pct_D))))
	age_share0105_sort_by_wealth = sum( age_share_sort_by_wealth*sort_D*(top99pct_D-top95pct_D)/(sum(sort_D*(top99pct_D-top95pct_D))) )


DEALLOCATE(age_2030, age_3145, age_4665, age_6699)

END SUBROUTINE
!***************************************************************************************

SUBROUTINE top_shares_age_partition

ALLOCATE( age_wealth_share_20_29((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_wealth_share_30_44((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_wealth_share_45_64((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_wealth_share_65_99((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )

ALLOCATE( age_income_share_20_29((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_income_share_30_44((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_income_share_45_64((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_income_share_65_99((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )

ALLOCATE( age_earning_share_20_29((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_earning_share_30_44((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_earning_share_45_64((RETAGE-1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( age_earning_share_65_99((RETAGE-1)*NGRIDA*NGRIDR*nn) )

state_pos = 0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR
            DO IS=1,nn          
			
                state_pos = state_pos + 1
				IF (AGE<=2) THEN 
					age_wealth_share_20_29(record_position_A(INT(state_pos))) = 1.0
					age_wealth_share_30_44(record_position_A(INT(state_pos))) = 0.0
					age_wealth_share_45_64(record_position_A(INT(state_pos))) = 0.0
					age_wealth_share_65_99(record_position_A(INT(state_pos))) = 0.0

					age_income_share_20_29(record_position_tinc(INT(state_pos))) = 1.0
					age_income_share_30_44(record_position_tinc(INT(state_pos))) = 0.0
					age_income_share_45_64(record_position_tinc(INT(state_pos))) = 0.0
					age_income_share_65_99(record_position_tinc(INT(state_pos))) = 0.0

					age_earning_share_20_29(record_position_E(INT(state_pos))) = 1.0
					age_earning_share_30_44(record_position_E(INT(state_pos))) = 0.0
					age_earning_share_45_64(record_position_E(INT(state_pos))) = 0.0
					age_earning_share_65_99(record_position_E(INT(state_pos))) = 0.0

				ELSE IF ((AGE>=3) .AND. (AGE<=5)) THEN 
					age_wealth_share_20_29(record_position_A(INT(state_pos))) = 0.0
					age_wealth_share_30_44(record_position_A(INT(state_pos))) = 1.0
					age_wealth_share_45_64(record_position_A(INT(state_pos))) = 0.0
					age_wealth_share_65_99(record_position_A(INT(state_pos))) = 0.0

					age_income_share_20_29(record_position_tinc(INT(state_pos))) = 0.0
					age_income_share_30_44(record_position_tinc(INT(state_pos))) = 1.0
					age_income_share_45_64(record_position_tinc(INT(state_pos))) = 0.0
					age_income_share_65_99(record_position_tinc(INT(state_pos))) = 0.0

					age_earning_share_20_29(record_position_E(INT(state_pos))) = 0.0
					age_earning_share_30_44(record_position_E(INT(state_pos))) = 1.0
					age_earning_share_45_64(record_position_E(INT(state_pos))) = 0.0
					age_earning_share_65_99(record_position_E(INT(state_pos))) = 0.0

				ELSE IF ((AGE>=6) .AND. (AGE<=9)) THEN
					age_wealth_share_20_29(record_position_A(INT(state_pos))) = 0.0
					age_wealth_share_30_44(record_position_A(INT(state_pos))) = 0.0
					age_wealth_share_45_64(record_position_A(INT(state_pos))) = 1.0
					age_wealth_share_65_99(record_position_A(INT(state_pos))) = 0.0

					age_income_share_20_29(record_position_tinc(INT(state_pos))) = 0.0
					age_income_share_30_44(record_position_tinc(INT(state_pos))) = 0.0
					age_income_share_45_64(record_position_tinc(INT(state_pos))) = 1.0
					age_income_share_65_99(record_position_tinc(INT(state_pos))) = 0.0

					age_earning_share_20_29(record_position_E(INT(state_pos))) = 0.0
					age_earning_share_30_44(record_position_E(INT(state_pos))) = 0.0
					age_earning_share_45_64(record_position_E(INT(state_pos))) = 1.0
					age_earning_share_65_99(record_position_E(INT(state_pos))) = 0.0

				END IF

			END DO
        END DO
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR  
			DO IS=1,nn   

				state_pos = state_pos + 1

				age_wealth_share_20_29(record_position_A(INT(state_pos))) = 0.0
				age_wealth_share_30_44(record_position_A(INT(state_pos))) = 0.0
				age_wealth_share_45_64(record_position_A(INT(state_pos))) = 0.0
				age_wealth_share_65_99(record_position_A(INT(state_pos))) = 1.0

				age_income_share_20_29(record_position_tinc(INT(state_pos))) = 0.0
				age_income_share_30_44(record_position_tinc(INT(state_pos))) = 0.0
				age_income_share_45_64(record_position_tinc(INT(state_pos))) = 0.0
				age_income_share_65_99(record_position_tinc(INT(state_pos))) = 1.0		

			END DO 
        END DO
    END DO
END DO

! Top wealth share age partition
! Top 1%
	age_wealth_share1_20_29 = sum( age_wealth_share_20_29*sort_D*top1pct_D/(sum(sort_D*top1pct_D)) )
	age_wealth_share1_30_44 = sum( age_wealth_share_30_44*sort_D*top1pct_D/(sum(sort_D*top1pct_D)) )
	age_wealth_share1_45_64 = sum( age_wealth_share_45_64*sort_D*top1pct_D/(sum(sort_D*top1pct_D)) )
	age_wealth_share1_65_99 = sum( age_wealth_share_65_99*sort_D*top1pct_D/(sum(sort_D*top1pct_D)) )

! Top income share age partition
! Top 1%
	age_income_share1_20_29 = sum( age_income_share_20_29*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)) )
	age_income_share1_30_44 = sum( age_income_share_30_44*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)) )
	age_income_share1_45_64 = sum( age_income_share_45_64*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)) )
	age_income_share1_65_99 = sum( age_income_share_65_99*sort_D_TINC*top1pct_D_tinc/(sum(sort_D_TINC*top1pct_D_tinc)) )

! Top earnings share age partition
! Top 1%
	age_earning_share1_20_29 = sum( age_earning_share_20_29*sort_D_inc*top1pct_D_inc/(sum(sort_D_inc*top1pct_D_inc)) )
	age_earning_share1_30_44 = sum( age_earning_share_30_44*sort_D_inc*top1pct_D_inc/(sum(sort_D_inc*top1pct_D_inc)) )
	age_earning_share1_45_64 = sum( age_earning_share_45_64*sort_D_inc*top1pct_D_inc/(sum(sort_D_inc*top1pct_D_inc)) )
	age_earning_share1_65_99 = sum( age_earning_share_65_99*sort_D_inc*top1pct_D_inc/(sum(sort_D_inc*top1pct_D_inc)) )



END SUBROUTINE
!***************************************************************************************

SUBROUTINE bequest 

ALLOCATE( sort_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( cum_sort_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top1pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top2pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top5pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top10pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top20pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top30pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top40pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top50pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top60pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top70pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top80pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top90pct_D_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( record_position_B((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn))


! Sort the bequest distribution in ascending order
isort=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                                   
                
                isort=isort+1
				JA=IDCWA(AGE,IA,IR,IS)                             
				sort_B(isort) = beq_aftertax(A(JA))						
				sort_D_B(isort) = YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))				
				record_position_B(isort) = isort
						               
            END DO
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn 

				isort=isort+1
				JA=IDCRA(AGE,IA,IR,IS) 
				sort_B(isort) = beq_aftertax(A(JA))					
				sort_D_B(isort) = YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))
				record_position_B(isort) = isort
			            
			END DO 
        END DO 
    END DO
END DO    

beq_given = sum(sort_B*sort_D_B)            

CALL SSORT_INT(sort_B,record_position_B,size(sort_B),2)
sort_D_B = sort_D_B(record_position_B)
sort_D_B(:) = sort_D_B(:)/sum(sort_D_B)


cum_sort_D_B(1) = sort_D_B(1)
DO i = 2,size(sort_D_B)
	cum_sort_D_B(i) = cum_sort_D_B(i-1)+sort_D_B(i)
END DO


! Identify wealth fractile agents
DO i = 1,size(sort_D_B)
	top1pct_D_B(i) = 0
	top2pct_D_B(i) = 0
	top5pct_D_B(i) = 0
	top10pct_D_B(i) = 0
	top20pct_D_B(i) = 0
	top30pct_D_B(i) = 0
	top40pct_D_B(i) = 0
	top50pct_D_B(i) = 0
	top60pct_D_B(i) = 0
	top70pct_D_B(i) = 0
	top80pct_D_B(i) = 0
	top90pct_D_B(i) = 0
END DO

where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.01 ) top1pct_D_B = 1
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.02 ) top2pct_D_B = 1
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.05 ) top5pct_D_B = 1
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.1 ) top10pct_D_B = 1 
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.2 ) top20pct_D_B = 1  
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.3 ) top30pct_D_B = 1
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.4 ) top40pct_D_B = 1 
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.5 ) top50pct_D_B = 1 
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.6 ) top60pct_D_B = 1
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.7 ) top70pct_D_B = 1 
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.8 ) top80pct_D_B = 1 
where ( cum_sort_D_B(1:size(sort_D_B)) > 1-0.9 ) top90pct_D_B = 1   


beq_pct98 = maxval(sort_B*(1-top2pct_D_B))
beq_pct95 = maxval(sort_B*(1-top5pct_D_B))
beq_pct90 = maxval(sort_B*(1-top10pct_D_B))
beq_pct80 = maxval(sort_B*(1-top20pct_D_B))
beq_pct70 = maxval(sort_B*(1-top30pct_D_B))
beq_pct60 = maxval(sort_B*(1-top40pct_D_B))
beq_pct50 = maxval(sort_B*(1-top50pct_D_B))
beq_pct40 = maxval(sort_B*(1-top60pct_D_B))
beq_pct30 = maxval(sort_B*(1-top70pct_D_B))
beq_pct20 = maxval(sort_B*(1-top80pct_D_B))
beq_pct10 = maxval(sort_B*(1-top90pct_D_B))


beq_wealth_ratio = beq_given/5.0/Aggwealth

Beq98 = beq_pct98/(Aggtincome/5.0)
Beq95 = beq_pct95/(Aggtincome/5.0)
Beq90 = beq_pct90/(Aggtincome/5.0)
Beq80 = beq_pct80/(Aggtincome/5.0)
Beq70 = beq_pct70/(Aggtincome/5.0)
Beq60 = beq_pct60/(Aggtincome/5.0)
Beq50 = beq_pct50/(Aggtincome/5.0)
Beq40 = beq_pct40/(Aggtincome/5.0)
Beq30 = beq_pct30/(Aggtincome/5.0)
Beq20 = beq_pct20/(Aggtincome/5.0)
Beq10 = beq_pct10/(Aggtincome/5.0)


! calculate percentile of the inheritance distribution (Hendricks 2007)
AggBeq = dot_product(sort_B,sort_D_B)
bshare99_100 = sum(sort_B*sort_D_B*top1pct_D_B)/AggBeq
bshare98_100 = sum(sort_B*sort_D_B*top2pct_D_B)/AggBeq
bshare95_99 = sum(sort_B*sort_D_B*(top5pct_D_B-top1pct_D_B))/AggBeq
bshare90_95 = sum(sort_B*sort_D_B*(top10pct_D_B-top5pct_D_B))/AggBeq
bshare80_90 = sum(sort_B*sort_D_B*(top20pct_D_B-top10pct_D_B))/AggBeq
bshare70_80 = sum(sort_B*sort_D_B*(top30pct_D_B-top20pct_D_B))/AggBeq
bshare50_70 = sum(sort_B*sort_D_B*(top50pct_D_B-top30pct_D_B))/AggBeq
bshare0_50 = sum(sort_B*sort_D_B*(1-top50pct_D_B))/AggBeq
beq_gini = gini(sort_B,sort_D_B)


END SUBROUTINE
!***************************************************************************************

SUBROUTINE bequest_exemption

ALLOCATE( sort_B_gross((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_D_B_gross((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( cum_sort_D_B_gross((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( top2pct_D_B_gross((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( record_position_B_gross((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn))

! Sort the bequest distribution in ascending order
isort=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                                   
                
                 isort=isort+1
				 JA=IDCWA(AGE,IA,IR,IS)                               
                 sort_B_gross(isort) = A(JA)			
				 sort_D_B_gross(isort) = YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))			
				 record_position_B_gross(isort) = isort
							               
            END DO
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn 

             isort=isort+1
			 JA=IDCRA(AGE,IA,IR,IS)
             sort_B_gross(isort) = A(JA)
			 sort_D_B_gross(isort) = YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))		
			 record_position_B_gross(isort) = isort
            
			END DO 
        END DO 
    END DO
END DO    

CALL SSORT_INT(sort_B_gross,record_position_B_gross,size(sort_B_gross),2)
sort_D_B_gross = sort_D_B_gross(record_position_B_gross)
sort_D_B_gross(:) = sort_D_B_gross(:)/sum(sort_D_B_gross)

cum_sort_D_B_gross(1) = sort_D_B_gross(1)
DO i = 2,size(sort_D_B_gross)
	cum_sort_D_B_gross(i) = cum_sort_D_B_gross(i-1)+sort_D_B_gross(i)
END DO
print*, 'cum_sort_D_B_gross=',cum_sort_D_B_gross(size(sort_D_B_gross))

DO i = 1,size(sort_D_B_gross)
	top2pct_D_B_gross(i) = 0
END DO

where ( cum_sort_D_B_gross(1:size(sort_D_B_gross)) > 1-0.02 ) top2pct_D_B_gross = 1

beqtax_exempt = maxval(sort_B_gross*(1-top2pct_D_B_gross))
print*,'beqtax_exempt=',beqtax_exempt

END SUBROUTINE
!***************************************************************************************
SUBROUTINE joint_dist  

ALLOCATE( sort_cons_Y((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_wealth_Y((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_wealth_E((RETAGE-1)*NGRIDA*NGRIDR*nn) )

state_pos=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                   
                
				state_pos = state_pos + 1
				sort_wealth_Y(state_pos) = A(IA)				 ! wealth share by income 						
				sort_wealth_E(state_pos) = A(IA)				 ! wealth share by earnings 
				sort_cons_Y(state_pos) = IDCWC(AGE,IA,IR,IS)	 ! consumption share by income
            END DO
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA        
		DO IR=1,NGRIDR  
			DO IS=1,nn               
			
            state_pos = state_pos + 1

			sort_wealth_Y(state_pos) = A(IA)												
			sort_cons_Y(state_pos) = IDCRC(AGE,IA,IR,IS)

            END DO 
		END DO
    END DO
END DO

sort_wealth_Y = sort_wealth_Y(record_position_tinc)
sort_wealth_E = sort_wealth_E(record_position_E)
sort_cons_Y = sort_cons_Y(record_position_tinc)

	kshare_E0001 = sum(sort_wealth_E*sort_D_inc*top0001pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E0005 = sum(sort_wealth_E*sort_D_inc*top0005pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E001 = sum(sort_wealth_E*sort_D_inc*top001pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E01 = sum(sort_wealth_E*sort_D_inc*top01pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E05 = sum(sort_wealth_E*sort_D_inc*top05pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E1 = sum(sort_wealth_E*sort_D_inc*top1pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E5 = sum(sort_wealth_E*sort_D_inc*top5pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E10 = sum(sort_wealth_E*sort_D_inc*top10pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E20 = sum(sort_wealth_E*sort_D_inc*top20pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E40 = sum(sort_wealth_E*sort_D_inc*top40pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E60 = sum(sort_wealth_E*sort_D_inc*top60pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)
	kshare_E80 = sum(sort_wealth_E*sort_D_inc*top80pct_D_inc)/dot_product(sort_wealth_E,sort_D_inc)

	klevel_E0001 = sum(sort_wealth_E*sort_D_inc*top0001pct_D_inc)
	klevel_E0005 = sum(sort_wealth_E*sort_D_inc*top0005pct_D_inc)
	klevel_E001 = sum(sort_wealth_E*sort_D_inc*top001pct_D_inc)
	klevel_E01 = sum(sort_wealth_E*sort_D_inc*top01pct_D_inc)
	klevel_E05 = sum(sort_wealth_E*sort_D_inc*top05pct_D_inc)
	klevel_E1 = sum(sort_wealth_E*sort_D_inc*top1pct_D_inc)
	klevel_E5 = sum(sort_wealth_E*sort_D_inc*top5pct_D_inc)
	klevel_E10 = sum(sort_wealth_E*sort_D_inc*top10pct_D_inc)
	klevel_E20 = sum(sort_wealth_E*sort_D_inc*top20pct_D_inc)
	klevel_E40 = sum(sort_wealth_E*sort_D_inc*top40pct_D_inc)
	klevel_E60 = sum(sort_wealth_E*sort_D_inc*top60pct_D_inc)
	klevel_E80 = sum(sort_wealth_E*sort_D_inc*top80pct_D_inc)

	kshare_Y0001 = sum(sort_wealth_Y*sort_D_tinc*top0001pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y0005 = sum(sort_wealth_Y*sort_D_tinc*top0005pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y001 = sum(sort_wealth_Y*sort_D_tinc*top001pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y01 = sum(sort_wealth_Y*sort_D_tinc*top01pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y05 = sum(sort_wealth_Y*sort_D_tinc*top05pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y1 = sum(sort_wealth_Y*sort_D_tinc*top1pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y5 = sum(sort_wealth_Y*sort_D_tinc*top5pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y10 = sum(sort_wealth_Y*sort_D_tinc*top10pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y20 = sum(sort_wealth_Y*sort_D_tinc*top20pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y40 = sum(sort_wealth_Y*sort_D_tinc*top40pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y60 = sum(sort_wealth_Y*sort_D_tinc*top60pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)
	kshare_Y80 = sum(sort_wealth_Y*sort_D_tinc*top80pct_D_tinc)/dot_product(sort_wealth_Y,sort_D_tinc)

	klevel_Y0001 = ( sum(sort_wealth_Y*sort_D_tinc*top0001pct_D_tinc)/sum(sort_D_tinc*top0001pct_D_tinc) )/Aggwealth
	klevel_Y0005 = ( sum(sort_wealth_Y*sort_D_tinc*top0005pct_D_tinc)/sum(sort_D_tinc*top0005pct_D_tinc) )/Aggwealth
	klevel_Y001 = ( sum(sort_wealth_Y*sort_D_tinc*top001pct_D_tinc)/sum(sort_D_tinc*top001pct_D_tinc) )/Aggwealth
	klevel_Y01 = ( sum(sort_wealth_Y*sort_D_tinc*top01pct_D_tinc)/sum(sort_D_tinc*top01pct_D_tinc) )/Aggwealth
	klevel_Y05 = ( sum(sort_wealth_Y*sort_D_tinc*top05pct_D_tinc)/sum(sort_D_tinc*top05pct_D_tinc) )/Aggwealth
	klevel_Y1 = ( sum(sort_wealth_Y*sort_D_tinc*top1pct_D_tinc)/sum(sort_D_tinc*top1pct_D_tinc) )/Aggwealth
	klevel_Y5 = ( sum(sort_wealth_Y*sort_D_tinc*top5pct_D_tinc)/sum(sort_D_tinc*top5pct_D_tinc) )/Aggwealth
	klevel_Y10 = ( sum(sort_wealth_Y*sort_D_tinc*top10pct_D_tinc)/sum(sort_D_tinc*top10pct_D_tinc) )/Aggwealth
	klevel_Y20 = ( sum(sort_wealth_Y*sort_D_tinc*top20pct_D_tinc)/sum(sort_D_tinc*top20pct_D_tinc) )/Aggwealth
	klevel_Y40 = ( sum(sort_wealth_Y*sort_D_tinc*top40pct_D_tinc)/sum(sort_D_tinc*top40pct_D_tinc) )/Aggwealth
	klevel_Y60 = ( sum(sort_wealth_Y*sort_D_tinc*top60pct_D_tinc)/sum(sort_D_tinc*top60pct_D_tinc) )/Aggwealth
	klevel_Y80 = ( sum(sort_wealth_Y*sort_D_tinc*top80pct_D_tinc)/sum(sort_D_tinc*top80pct_D_tinc) )/Aggwealth
	klevel_Y9599 = ( sum(sort_wealth_Y*sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc))/sum(sort_D_tinc*(top5pct_D_tinc-top1pct_D_tinc)) )/Aggwealth
	klevel_Y9095 = ( sum(sort_wealth_Y*sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc))/sum(sort_D_tinc*(top10pct_D_tinc-top5pct_D_tinc)) )/Aggwealth
	klevel_Y6080 = ( sum(sort_wealth_Y*sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc))/sum(sort_D_tinc*(top40pct_D_tinc-top20pct_D_tinc)) )/Aggwealth
	klevel_Y4060 = ( sum(sort_wealth_Y*sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc))/sum(sort_D_tinc*(top60pct_D_tinc-top40pct_D_tinc)) )/Aggwealth
	klevel_Y2040 = ( sum(sort_wealth_Y*sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc))/sum(sort_D_tinc*(top80pct_D_tinc-top60pct_D_tinc)) )/Aggwealth
	
	cshare_tinc0001 = sum(sort_cons_Y*sort_D_tinc*top0001pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc0005 = sum(sort_cons_Y*sort_D_tinc*top0005pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc001 = sum(sort_cons_Y*sort_D_tinc*top001pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc01 = sum(sort_cons_Y*sort_D_tinc*top01pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc05 = sum(sort_cons_Y*sort_D_tinc*top05pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc1 = sum(sort_cons_Y*sort_D_tinc*top1pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc5 = sum(sort_cons_Y*sort_D_tinc*top5pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc10 = sum(sort_cons_Y*sort_D_tinc*top10pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc20 = sum(sort_cons_Y*sort_D_tinc*top20pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc40 = sum(sort_cons_Y*sort_D_tinc*top40pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc60 = sum(sort_cons_Y*sort_D_tinc*top60pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	cshare_tinc80 = sum(sort_cons_Y*sort_D_tinc*top80pct_D_tinc)/dot_product(sort_cons_Y,sort_D_tinc)
	
END SUBROUTINE
!***************************************************************************************

SUBROUTINE tax_moment

ALLOCATE( sort_ATY((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_ATC((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( sort_noncorpY((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )
ALLOCATE( MTR((RETAGE-1)*NGRIDA*NGRIDR*nn+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*nn) )

! G/Y: Government expenditure (17%)

	 G_share = (gov*OUTPUT + SSEXP + flat_transf_rate*OUTPUT + medicare_rate*OUTPUT)/OUTPUT

! ATY1: Income tax target

state_pos=0
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA      
		DO IR=1,NGRIDR
            DO IS=1,nn                   
                
				state_pos = state_pos + 1
                JN=IDCWN(AGE,IA,IR,IS) 		

				! income tax paid only on non-corporate capital income and labor income	(Not include corporate tax)			
                sort_ATY(state_pos) = WAGE*EFFLONG(AGE)*N(JN)*W(IS) + min(R(IR)*A(IA),d_c) &
									- lambda * (MIN(bendy,WAGE*EFFLONG(AGE)*N(JN)*W(IS) + min(R(IR)*A(IA),d_c)  ))**(1.0-tau_l) & 
									- (1.0-ty_max)*MAX(0.0,( WAGE*EFFLONG(AGE)*N(JN)*W(IS) + min(R(IR)*A(IA),d_c) ) - bendy)

															
				sort_ATC(state_pos) = tau_c*max(R(IR)*A(IA)-d_c,0.0)

				sort_noncorpY(state_pos) = WAGE*EFFLONG(AGE)*N(JN)*W(IS) + min(R(IR)*A(IA),d_c)
            END DO
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR  
			DO IS=1,nn
            
            state_pos=state_pos+1

			! Not include corporate tax and SS tax
			sort_ATY(state_pos) = min(R(IR)*A(IA),d_c) &
							  - lambda * (MIN(bendy,min(R(IR)*A(IA),d_c)  ))**(1.0-tau_l) & 
							  - (1.0-ty_max)*MAX(0.0,(min(R(IR)*A(IA),d_c) ) - bendy) 
										  
			sort_ATC(state_pos) = tau_c*max(R(IR)*A(IA)-d_c,0.0)	

			sort_noncorpY(state_pos) = SS(IS) + min(R(IR)*A(IA),d_c)						  
            
			END DO 
        END DO 
    END DO
END DO 

! sort by income excluding that taxed within corporations:
sort_ATY = sort_ATY(record_position_tinc_no_transf)
sort_ATC = sort_ATC(record_position_tinc_no_transf)
sort_noncorpY = sort_noncorpY(record_position_tinc_no_transf)

! Sorted by income group
! Corporate tax target moments
ctaxrev_GDP = sum(sort_ATC*sort_D_tinc_no_transf)/OUTPUT
ctaxrev_income = sum(sort_ATC*sort_D_tinc_no_transf)/dot_product(sort_tinc_no_transf,sort_D_tinc_no_transf)


ATC1 =  sum(sort_ATC*sort_D_tinc_no_transf*top1pct_D_tinc_no_transf) &
		/sum(sort_tinc_no_transf*sort_D_tinc_no_transf*top1pct_D_tinc_no_transf)

		
ATC99 =  sum(sort_ATC*sort_D_tinc_no_transf*(1-top1pct_D_tinc_no_transf)) &
		/sum(sort_tinc_no_transf*sort_D_tinc_no_transf*(1-top1pct_D_tinc_no_transf))	


! income tax target moments
ATY1 =  sum(sort_ATY*sort_D_tinc_no_transf*top1pct_D_tinc_no_transf) &
		/sum(sort_tinc_no_transf*sort_D_tinc_no_transf*top1pct_D_tinc_no_transf)


ATY99 =  sum(sort_ATY*sort_D_tinc_no_transf*(1-top1pct_D_tinc_no_transf)) &
		/sum(sort_tinc_no_transf*sort_D_tinc_no_transf*(1-top1pct_D_tinc_no_transf))


inctaxrev_GDP = sum(sort_ATY*sort_D_tinc_no_transf)/OUTPUT
inctaxrev_income = sum(sort_ATY*sort_D_tinc_no_transf)/dot_product(sort_tinc_no_transf,sort_D_tinc_no_transf)

MTR(:) = MIN(1.0 - lambda * (1.0-tau_l) * sort_tinc_no_transf(:)**(-tau_l),ty_max)

MTR10 = MTR(int(size(MTR)-sum(top10pct_D_tinc_no_transf)))
MTR1 = MTR(int(size(MTR)-sum(top1pct_D_tinc_no_transf)))

END SUBROUTINE
!***************************************************************************************

SUBROUTINE check_kmaxbinding

DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn

             IF  ( (IDCWA(AGE,IA,IR,IS)>=NGRIDA) .AND. (D_YW(AGE,IA,IR,IS)>1.D-10) ) THEN
             print*, ' WARNING kmax binding at',AGE,IA,IR,IS,'!!!!'
             END IF 

            END DO
        END DO
    END DO
END DO  

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR 
			DO IS=1,nn

             IF  ( (IDCRA(AGE,IA,IR,IS)>=NGRIDA) .AND. (D_YR(AGE,IA,IR,IS)>1.D-10) ) THEN
            print*, ' WARNING kmax binding at',AGE,IA,IR,IS,'!!!!'
            END IF 

			END DO 
        END DO
    END DO
END DO

END SUBROUTINE
!***************************************************************************************

SUBROUTINE beq_distribution

IMPLICIT NONE 
INTEGER    ::  AGE,IA,IR,IS,id11,id12,id21,id22,ACLOSE
REAL(PREC) ::  x45


ALLOCATE( parentbeq_basket((RETAGE-1)*NGRIDA*NGRIDR*5+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*5,2,2) )
ALLOCATE( beq_dist((RETAGE-1)*NGRIDA*NGRIDR*5+(MAXAGE-RETAGE+1)*NGRIDA*NGRIDR*5,2,2) )
ALLOCATE( X45_lowkid_dist1(MAXAGE,NGRIDA,NGRIDA,2) )
ALLOCATE( X45_highkid_dist1(MAXAGE,NGRIDA,NGRIDA,2) )
ALLOCATE( X45_lowparent_dist(MAXAGE,NGRIDA,NGRIDA,2) )
ALLOCATE( X45_highparent_dist(MAXAGE,NGRIDA,NGRIDA,2) )

parentbeq_basket(:,:,:)=0.0
beq_dist(:,:,:)=0.0
X45_lowkid_dist1(:,:,:,:)=0.0
X45_highkid_dist1(:,:,:,:)=0.0
X45_lowparent_dist(:,:,:,:)=0.0
X45_highparent_dist(:,:,:,:)=0.0
pdf_parent_kid(:,:,:,:)=0.0

id11=0
id12=0
id21=0
id22=0

! Construct bequest distribution
DO AGE = 1,RETAGE-1
	DO IA = 1,NGRIDA
		DO IR = 1,NGRIDR

			if (IR<2) then			
				DO IS=1,nn
					JA = IDCWA(AGE,IA,IR,IS)			
					if (IS<=3) then		
						id11=id11+1
						beq_dist(id11,1,1) = YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))		! low r, low z		
						parentbeq_basket(id11,1,1) = beq_aftertax(A(JA))
					else				! high z
						id12=id12+1
						beq_dist(id12,1,2) = YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))		! low r, high z	
						parentbeq_basket(id12,1,2) = beq_aftertax(A(JA))								
					end if
				END DO
			else					
				DO IS=1,nn
					JA = IDCWA(AGE,IA,IR,IS)			
					if (IS<=3) then		
						id21=id21+1
						beq_dist(id21,2,1) = YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))		! high r, low z				
						parentbeq_basket(id21,2,1) = beq_aftertax(A(JA))
					else				! high z
						id22=id22+1
						beq_dist(id22,2,2) = YW(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))		! high r, high z	
						parentbeq_basket(id22,2,2) = beq_aftertax(A(JA))
					end if
				END DO
			end if
			
		END DO
	END DO	
END DO

DO AGE = RETAGE,MAXAGE
	DO IA = 1,NGRIDA
		DO IR = 1,NGRIDR	

			if (IR<2) then						
				DO IS=1,nn
					JA = IDCRA(AGE,IA,IR,IS)
					if (IS<=3) then
						id11=id11+1
				
						beq_dist(id11,1,1) = YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))				
						parentbeq_basket(id11,1,1) = beq_aftertax(A(JA))

					else
						id12=id12+1
				
						beq_dist(id12,1,2) = YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))
						parentbeq_basket(id12,1,2) = beq_aftertax(A(JA))

					end if
				END DO 
			else 
				DO IS=1,nn
					JA = IDCRA(AGE,IA,IR,IS)
					if (IS<=3) then
						id21=id21+1
				
						beq_dist(id21,2,1) = YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))				
						parentbeq_basket(id21,2,1) = beq_aftertax(A(JA))

					else
						id22=id22+1
				
						beq_dist(id22,2,2) = YR(AGE,IA,IR,IS)*MU(AGE)*(1.0-S(AGE))
						parentbeq_basket(id22,2,2) = beq_aftertax(A(JA))

					end if
				END DO
			end if

		END DO
	END DO	
END DO

popu_left_beq = sum(beq_dist)

xL = sum(beq_dist(:,:,1))/( sum(beq_dist(:,:,1))+sum(beq_dist(:,:,2)) )	! proportion of low z parents (dead)
xH = sum(beq_dist(:,:,2))/( sum(beq_dist(:,:,1))+sum(beq_dist(:,:,2)) )	! proportion of high z parents (dead)

xLL = sum(beq_dist(:,1,1))/sum(beq_dist) ! proportion of deaths with low r, low z
xLH = sum(beq_dist(:,1,2))/sum(beq_dist) ! proportion of deaths with low r, high z
xHL = sum(beq_dist(:,2,1))/sum(beq_dist) ! proportion of deaths with high r, low z
xHH = 1-xLL-xLH-xHL						 ! proportion of deaths with high r, high z



!  intergenerational transmittion of productivity + return
! (parent r, kid r, parent z, kid z)
! kids with low r, low z:
pdf_parent_kid(1,1,1,1) = intergen_corr_return*ability_persistence*xLL		!the probability that the parents are (low z,low r) and kid are (low z, low r)
pdf_parent_kid(2,1,1,1) = (1.0-intergen_corr_return)*ability_persistence*xHL	!the probability that the parents are (low z,high r) and kid are (low z, low r)
pdf_parent_kid(1,1,2,1) = intergen_corr_return*(1.0-ability_persistence)*xLH		!the probability that the parents are (high z,low r) and kid are (low z,low r)
pdf_parent_kid(2,1,2,1) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHH	!the probability that the parents are (high z,high r) and kid are (low z,low r)
pdf_parent_kid(:,1,:,1) = pdf_parent_kid(:,1,:,1)/(intergen_corr_return*ability_persistence*xLL + (1.0-intergen_corr_return)*ability_persistence*xHL + intergen_corr_return*(1.0-ability_persistence)*xLH + (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHH)

! kids with high r, low z
pdf_parent_kid(1,2,1,1) = (1.0-intergen_corr_return)*ability_persistence*xLL	!the probability that the parents are (low z,low r) and kid are (low z, high r)
pdf_parent_kid(2,2,1,1) = intergen_corr_return*ability_persistence*xHL		!the probability that the parents are (low z,high r) and kid are (low z, high r)
pdf_parent_kid(1,2,2,1) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xLH	!the probability that the parents are (high z,low r) and kid are (low z,high r)
pdf_parent_kid(2,2,2,1) = intergen_corr_return*(1.0-ability_persistence)*xHH		!the probability that the parents are (high z,high r) and kid are (low z,high r)
pdf_parent_kid(:,2,:,1) = pdf_parent_kid(:,2,:,1)/((1.0-intergen_corr_return)*ability_persistence*xLL + intergen_corr_return*ability_persistence*xHL + (1.0-intergen_corr_return)*(1.0-ability_persistence)*xLH + intergen_corr_return*(1.0-ability_persistence)*xHH)

! kids with low r, high z
pdf_parent_kid(1,1,1,2) = intergen_corr_return*(1.0-ability_persistence)*xLL		!the probability that the parents are (low z,low r) and kid are (high z, low r)
pdf_parent_kid(2,1,1,2) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHL	!the probability that the parents are (low z,high r) and kid are (high z, low r)
pdf_parent_kid(1,1,2,2) = intergen_corr_return*ability_persistence*xLH		!the probability that the parents are (high z,low r) and kid are (high z, low r)
pdf_parent_kid(2,1,2,2) = (1.0-intergen_corr_return)*ability_persistence*xHH	!the probability that the parents are (high z,high r) and kid are (high z, low r)
pdf_parent_kid(:,1,:,2) = pdf_parent_kid(:,1,:,2)/(intergen_corr_return*(1.0-ability_persistence)*xLL + (1.0-intergen_corr_return)*(1.0-ability_persistence)*xHL + intergen_corr_return*ability_persistence*xLH + (1.0-intergen_corr_return)*ability_persistence*xHH)

! kids with high r, high z
pdf_parent_kid(1,2,1,2) = (1.0-intergen_corr_return)*(1.0-ability_persistence)*xLL	!the probability that the parents are (low z,low r) and kid are (high z, high r)
pdf_parent_kid(2,2,1,2) = intergen_corr_return*(1.0-ability_persistence)*xHL		!the probability that the parents are (low z,high r) and kid are (high z, high r)

pdf_parent_kid(1,2,2,2) = (1.0-intergen_corr_return)*ability_persistence*xLH	!the probability that the parents are (high z,low r) and kid are (high z, high r)
pdf_parent_kid(2,2,2,2) = intergen_corr_return*ability_persistence*xHH		!the probability that the parents are (high z,high r) and kid are (high z, high r)
pdf_parent_kid(:,2,:,2) = pdf_parent_kid(:,2,:,2)/((1.0-intergen_corr_return)*(1.0-ability_persistence)*xLL + intergen_corr_return*(1.0-ability_persistence)*xHL + (1.0-intergen_corr_return)*ability_persistence*xLH + intergen_corr_return*ability_persistence*xHH)



!Bequest given
beq_given = SUM(beq_dist(:,1,1)*parentbeq_basket(:,1,1))+SUM(beq_dist(:,1,2)*parentbeq_basket(:,1,2)) + &
			SUM(beq_dist(:,2,1)*parentbeq_basket(:,2,1))+SUM(beq_dist(:,2,2)*parentbeq_basket(:,2,2))

! Normalize the beq_dist
beq_dist(:,1,1) = beq_dist(:,1,1)/sum(beq_dist(:,1,1))
beq_dist(:,1,2) = beq_dist(:,1,2)/sum(beq_dist(:,1,2))
beq_dist(:,2,1) = beq_dist(:,2,1)/sum(beq_dist(:,2,1))
beq_dist(:,2,2) = beq_dist(:,2,2)/sum(beq_dist(:,2,2))

popu_receive_beq = 0.0
DO AGE=1,RETAGE-1
	IF (beqgroup(AGE)>0.0) THEN
		DO IA=1,NGRIDA
			DO IR=1,NGRIDR	
				DO IS=1,nn	

					popu_receive_beq = popu_receive_beq + beqprob(AGE)*YW(AGE,IA,IR,IS)*MU(AGE)*S(AGE) 

				END DO 			
			END DO 
		END DO 
	END IF 			
END DO 

DO AGE=RETAGE,MAXAGE
	IF (beqgroup(AGE)>0.0) THEN
		DO IA=1,NGRIDA
			DO IR=1,NGRIDR	! kid return
				DO IS=1,nn
					
					popu_receive_beq = popu_receive_beq + beqprob(AGE)*YR(AGE,IA,IR,IS)*MU(AGE)*S(AGE) 
					
				END DO 
			END DO 
		END DO 
	END IF 			
END DO

! Equalize the bequest distribution
equal_bequest_transfer = beq_given/popu_receive_beq

parentbeq_basket(:,1,1) = equal_bequest_transfer
parentbeq_basket(:,2,1) = equal_bequest_transfer
parentbeq_basket(:,1,2) = equal_bequest_transfer
parentbeq_basket(:,2,2) = equal_bequest_transfer

!$OMP PARALLEL DEFAULT(NONE) &
!$OMP & PRIVATE(x45,id11,id12,id21,id22,ACLOSE,IA,AGE) &
!$OMP & SHARED(parentbeq_basket,beq_dist,X45_highparent_dist,X45_lowparent_dist, &
!$OMP &        A,beqgroup,popu_left_beq,popu_receive_beq)

! build transition matrix for inheritances from low r, low z parents

DO AGE = 1,MAXAGE

!$OMP DO	
	DO IA = 1,NGRIDA    !kids		
		DO id11 = 1,size(A(IA) + parentbeq_basket(:,1,1) )
		  
		x45 = A(IA) + parentbeq_basket(id11,1,1)*beqgroup(AGE)*(popu_left_beq/popu_receive_beq)

!	now interpolate these so X45 gets to lie on the asset grid
!   the final desired X45 should be NGRIDA X NGRIDA, whereas X45 computed up to now is much wider.

! Linear interpolation: should not round, but split up the probability mass
		
			IF (parentbeq_basket(id11,1,1) <= 0.D0) THEN
				X45_lowparent_dist(AGE,IA,IA,1) =  X45_lowparent_dist(AGE,IA,IA,1)+beq_dist(id11,1,1)
				! this assumes that the lowest grid point is 0
			ELSE
		
			!-- insert code to find the two points on AGRID that bracket parentbeq_basket(id1,1). call the index of the lower point ACLOSE
			
				do i=IA,NGRIDA
												 
						if(A(i) > X45) then		! searching for the closest upper bound of X45
						   ACLOSE = i-1			! lower bound of X45
						   X45_lowparent_dist(AGE,IA,ACLOSE,1) = X45_lowparent_dist(AGE,IA,ACLOSE,1) + beq_dist(id11,1,1) * (X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))
						   X45_lowparent_dist(AGE,IA,ACLOSE+1,1) = X45_lowparent_dist(AGE,IA,ACLOSE+1,1) + beq_dist(id11,1,1) * (1.D0-(X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))) 							
							go to 111
			   			
						elseif (A(i) == X45) then
							ACLOSE = i
							X45_lowparent_dist(AGE,IA,ACLOSE,1) = X45_lowparent_dist(AGE,IA,ACLOSE,1) + beq_dist(id11,1,1)				
							go to 111

						elseif ( (i==NGRIDA) .AND. (A(i) < X45) ) then 							
							!print*, 'Assets off grid after inheritance'
							X45_lowparent_dist(AGE,IA,NGRIDA,1) = X45_lowparent_dist(AGE,IA,NGRIDA,1) + beq_dist(id11,1,1)
							go to 111

						end if
				end do 
			

			END IF
			 111 continue	
		 END DO		
	END DO
!$OMP END DO


! build transition matrix for inheritances from high r, low z  parents

!$OMP DO	
	DO IA = 1,NGRIDA    !kids		
		DO id21 = 1,size(A(IA) + parentbeq_basket(:,2,1) )
		 
		x45 = A(IA) + parentbeq_basket(id21,2,1)*beqgroup(AGE)*(popu_left_beq/popu_receive_beq)   

!	now interpolate these so X45 gets to lie on the asset grid
!   the final desired X45 should be NGRIDA X NGRIDA, whereas X45 computed up to now is much wider.

! Linear interpolation: should not round, but split up the probability mass
					
			IF (parentbeq_basket(id21,2,1) <= 0.D0) THEN
				X45_lowparent_dist(AGE,IA,IA,2) =  X45_lowparent_dist(AGE,IA,IA,2)+beq_dist(id21,2,1)
				! this assumes that the lowest grid point is 0
			ELSE
		
			!-- insert code to find the two points on AGRID that bracket parentbeq_basket(id1,1). call the index of the lower point ACLOSE
			
				do i=IA,NGRIDA
												 
						if(A(i) > X45) then		! searching for the closest upper bound of X45
						   ACLOSE = i-1			! lower bound of X45
						   X45_lowparent_dist(AGE,IA,ACLOSE,2) = X45_lowparent_dist(AGE,IA,ACLOSE,2) + beq_dist(id21,2,1) * (X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))
						   X45_lowparent_dist(AGE,IA,ACLOSE+1,2) = X45_lowparent_dist(AGE,IA,ACLOSE+1,2) + beq_dist(id21,2,1) * (1.D0-(X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))) 							
							go to 112
			   			
						elseif (A(i) == X45) then
							ACLOSE = i
							X45_lowparent_dist(AGE,IA,ACLOSE,2) = X45_lowparent_dist(AGE,IA,ACLOSE,2) + beq_dist(id21,2,1)				
							go to 112

						elseif ( (i==NGRIDA) .AND. (A(i) < X45) ) then 							
							! 'Assets off grid after inheritance'
							X45_lowparent_dist(AGE,IA,NGRIDA,2) = X45_lowparent_dist(AGE,IA,NGRIDA,2) + beq_dist(id21,2,1)
							go to 112

						end if
				end do 

			END IF
			 112 continue	
		 END DO		
	END DO
!$OMP END DO


! this results in a NGRIDA x NGRIDA transition matrix. It contains, for each original asset holdings (rows), the probabilities to transiting to post-bequest asset holdings (columns). Rows should sum to 1 by construction.
! build transition matrix for inheritances from low r, high z parents


!$OMP DO
	DO IA = 1,NGRIDA    !kids
		DO id12 =1,size(A(IA) + parentbeq_basket(:,1,2))
		
		x45 = A(IA) + parentbeq_basket(id12,1,2)*beqgroup(AGE)*(popu_left_beq/popu_receive_beq)  

			IF (parentbeq_basket(id12,1,2) <= 0.D0) THEN
				X45_highparent_dist(AGE,IA,IA,1) =  X45_highparent_dist(AGE,IA,IA,1)+beq_dist(id12,1,2)
				! this assumes that the lowest grid point is 0
			ELSE					
			
				do i=IA,NGRIDA
												 
						if(A(i) > X45) then	
						   ACLOSE = i-1	
						   X45_highparent_dist(AGE,IA,ACLOSE,1) = X45_highparent_dist(AGE,IA,ACLOSE,1) + beq_dist(id12,1,2) * (X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))
						   X45_highparent_dist(AGE,IA,ACLOSE+1,1) = X45_highparent_dist(AGE,IA,ACLOSE+1,1) + beq_dist(id12,1,2) * (1.D0-(X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))) 
							go to 113
			   			
						elseif (A(i) == X45) then
							ACLOSE = i
							X45_highparent_dist(AGE,IA,ACLOSE,1) = X45_highparent_dist(AGE,IA,ACLOSE,1) + beq_dist(id12,1,2)
							go to 113

						elseif ( (i==NGRIDA) .AND. (A(i) < X45) ) then 							
							! 'Assets off grid after inheritance'
							X45_highparent_dist(AGE,IA,NGRIDA,1) = X45_highparent_dist(AGE,IA,NGRIDA,1) + beq_dist(id12,1,2)
							go to 113

						end if
				end do 
				
			END IF
			113 continue
		 END DO		
	END DO	
!$OMP END DO

! build transition matrix for inheritances from high r, high z parents

!$OMP DO
	DO IA = 1,NGRIDA    !kids
		DO id22 =1,size(A(IA) + parentbeq_basket(:,2,2))
		
		x45 = A(IA) + parentbeq_basket(id22,2,2)*beqgroup(AGE)*(popu_left_beq/popu_receive_beq) 

			IF (parentbeq_basket(id22,2,2) <= 0.D0) THEN
				X45_highparent_dist(AGE,IA,IA,2) =  X45_highparent_dist(AGE,IA,IA,2)+beq_dist(id22,2,2)
				! this assumes that the lowest grid point is 0
			ELSE					
			
				do i=IA,NGRIDA
												 
						if(A(i) > X45) then	
						   ACLOSE = i-1	
						   X45_highparent_dist(AGE,IA,ACLOSE,2) = X45_highparent_dist(AGE,IA,ACLOSE,2) + beq_dist(id22,2,2) * (X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))
						   X45_highparent_dist(AGE,IA,ACLOSE+1,2) = X45_highparent_dist(AGE,IA,ACLOSE+1,2) + beq_dist(id22,2,2) * (1.D0-(X45-A(ACLOSE+1))/(A(ACLOSE)-A(ACLOSE+1))) 
							go to 114
			   			
						elseif (A(i) == X45) then
							ACLOSE = i
							X45_highparent_dist(AGE,IA,ACLOSE,2) = X45_highparent_dist(AGE,IA,ACLOSE,2) + beq_dist(id22,2,2)
							go to 114

						elseif ( (i==NGRIDA) .AND. (A(i) < X45) ) then 							
							! 'Assets off grid after inheritance'
							X45_highparent_dist(AGE,IA,NGRIDA,2) = X45_highparent_dist(AGE,IA,NGRIDA,2) + beq_dist(id22,2,2)
							go to 114

						end if
				end do 
				
			END IF
			114 continue
		 END DO		
	END DO	
!$OMP END DO

END DO  
!$OMP END PARALLEL

DO AGE=1,MAXAGE
	IF (beqgroup(AGE)>0.0) THEN
		DO IR=1,2
			Do i=1,NGRIDA
				if(abs(1.0 - sum(X45_highparent_dist(AGE,i,:,IR))) > 0.0001) then
					print*, ' Warning the sum of high parent transition matrix row not equal to 1'
					print*, 'row=',i
					print*, 'sum=',sum(X45_highparent_dist(AGE,i,:,IR))
				end if 
				if(abs(1.0 - sum(X45_lowparent_dist(AGE,i,:,IR))) > 0.0001) then
					print*, ' Warning the sum of low parent transition matrix row not equal to 1'
					print*, 'row=',i
					print*, 'sum=',sum(X45_lowparent_dist(AGE,i,:,IR))
				end if 
			END DO 		
		END DO 
	END IF
END DO 

! then compute transition matrices for high/low kids  
! These give the bequest pdfs that a kid with assets A(IA) faces at the age when bequests are received, separately for low and high kids.


DO AGE=1,MAXAGE
	DO IR = 1,2	! kid return
		DO IA = 1,NGRIDA
			X45_lowkid_dist1(AGE,IA,:,IR) = pdf_parent_kid(1,IR,1,1)*X45_lowparent_dist(AGE,IA,:,1) + pdf_parent_kid(2,IR,1,1)*X45_lowparent_dist(AGE,IA,:,2) + &
										pdf_parent_kid(1,IR,2,1)*X45_highparent_dist(AGE,IA,:,1) + pdf_parent_kid(2,IR,2,1)*X45_highparent_dist(AGE,IA,:,2)
					
			X45_highkid_dist1(AGE,IA,:,IR) = pdf_parent_kid(1,IR,1,2)*X45_lowparent_dist(AGE,IA,:,1) + pdf_parent_kid(2,IR,1,2)*X45_lowparent_dist(AGE,IA,:,2) + &
										pdf_parent_kid(1,IR,2,2)*X45_highparent_dist(AGE,IA,:,1) +  pdf_parent_kid(2,IR,2,2)*X45_highparent_dist(AGE,IA,:,2)
		END DO
	END DO 
END DO 

DO AGE=1,MAXAGE
	IF (beqgroup(AGE)>0.0) THEN
		DO IR=1,2
			Do i=1,NGRIDA
				if(abs(1.0 - sum(X45_lowkid_dist1(AGE,i,:,IR))) > 0.0001) then
					print*, ' Warning the sum of high parent transition matrix row not equal to 1'
					print*, 'row=',i
					print*, 'sum=',sum(X45_lowkid_dist1(AGE,i,:,IR))
				end if 
				if(abs(1.0 - sum(X45_highkid_dist1(AGE,i,:,IR))) > 0.0001) then
					print*, ' Warning the sum of low parent transition matrix row not equal to 1'
					print*, 'row=',i
					print*, 'sum=',sum(X45_highkid_dist1(AGE,i,:,IR))
				end if 
			END DO 		
		END DO 
	END IF
END DO 


!Bequest receive

beq_receive=0.0
DO AGE=1,RETAGE-1
	IF (beqgroup(AGE)>0.0) THEN
		DO IA=1,NGRIDA
			DO IR=1,NGRIDR	! kid return

				DO IS=1,3	
					JA = IDCWA(AGE,IA,IR,IS) 
					IF (IR>=2) THEN 
						beq_receive = beq_receive + SUM( beqprob(AGE)*YW(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_lowkid_dist1(AGE,JA,:,2)*(A(:)-A(JA)) )
					ELSE 										
						beq_receive = beq_receive + SUM( beqprob(AGE)*YW(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_lowkid_dist1(AGE,JA,:,1)*(A(:)-A(JA)) )
					END IF 
				END DO 

				DO IS=4,8	
					JA = IDCWA(AGE,IA,IR,IS) 
					IF (IR>=2) THEN 
						beq_receive = beq_receive + SUM( beqprob(AGE)*YW(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_highkid_dist1(AGE,JA,:,2)*(A(:)-A(JA)) )	
					ELSE 
						beq_receive = beq_receive + SUM( beqprob(AGE)*YW(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_highkid_dist1(AGE,JA,:,1)*(A(:)-A(JA)) )
					END IF 
				END DO 
			
			END DO 
		END DO 
	END IF 			
END DO 

DO AGE=RETAGE,MAXAGE
	IF (beqgroup(AGE)>0.0) THEN
		DO IA=1,NGRIDA
			DO IR=1,NGRIDR	! kid return

				DO IS=1,3	
					JA = IDCRA(AGE,IA,IR,IS) 
					IF (IR>=2) THEN 
						beq_receive = beq_receive + SUM( beqprob(AGE)*YR(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_lowkid_dist1(AGE,JA,:,2)*(A(:)-A(JA)) )
					ELSE 										
						beq_receive = beq_receive + SUM( beqprob(AGE)*YR(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_lowkid_dist1(AGE,JA,:,1)*(A(:)-A(JA)) )
					END IF 
				END DO 

				DO IS=4,8
					JA = IDCRA(AGE,IA,IR,IS) 
					IF (IR>=2) THEN 
						beq_receive = beq_receive + SUM( beqprob(AGE)*YR(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_highkid_dist1(AGE,JA,:,2)*(A(:)-A(JA)) )	
					ELSE 
						beq_receive = beq_receive + SUM( beqprob(AGE)*YR(AGE,IA,IR,IS)*MU(AGE)*S(AGE)*X45_highkid_dist1(AGE,JA,:,1)*(A(:)-A(JA)) )
					END IF 
				END DO 
			
			END DO 
		END DO 
	END IF 			
END DO

! Equally Redistribute the remaining bequest left to all WORKING agents
BEQTRANS =  beq_given - beq_receive
IF (BEQTRANS < 0.0) THEN
	BEQTRANS = 0.0
	PRINT*, 'BEQTRANS < 0'
END IF


END SUBROUTINE
!****************************************************************************************************************************

SUBROUTINE Calidiff
ALLOCATE( bench_calibration(20),targets(20), error(20) )

	bench_calibration = (/incshare01, incshare1, earning_share01, earning_share1, earning_share10, staytop1/poputop1, kshare01, kshare1, kshare5, kshare10, corr_Akids_Aparents_sq, wealth_trans(4,4), wealth_trans(5,5), Avg_topinc01_R_weighted/Avg_R_weighted, Avg_topinc1_R_weighted/Avg_R_weighted, &
					  	Avg_top01_R_weighted/Avg_R_weighted, Avg_top1_R_weighted/Avg_R_weighted, ctaxrev_GDP, bshare98_100, beq_wealth_ratio/)

	targets = (/0.06, 0.17, 0.49, 0.59, 0.72, 0.62, 0.13, 0.35, 0.62, 0.74, 0.365, 0.26, 0.36, 2.48, 1.76, 1.25, 1.2, 0.025, 0.4, 0.015/)
	
	error = bench_calibration(:)-targets(:)

    SSE = dot_product(error,error)	! sum of squared error
	
END SUBROUTINE
!**********************************************************************************************************************

SUBROUTINE correlation

cov_earn_wealth = 0.0
cov_earn_wealth_working = 0.0
cov_income_wealth = 0.0
var_wealth = 0.0
var_wealth_working = 0.0
var_earn = 0.0
var_earn_working = 0.0
var_income = 0.0
wealth_mean_corr = 0.0
wealth_mean_corr_working = 0.0
earn_mean_corr = 0.0
earn_mean_corr_working = 0.0
income_mean_corr = 0.0

cov_earn_kinc = 0.0
cov_earn_kinc_working = 0.0
var_kinc = 0.0
var_kinc_working = 0.0

kinc_mean_corr = 0.0
kinc_mean_corr_working = 0.0



! Skip first period because all agents start with zero asset

DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                    
                
				JN=IDCWN(AGE,IA,IR,IS)
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 				
				
				wealth_mean_corr = wealth_mean_corr + A(IA)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				wealth_mean_corr_working = wealth_mean_corr_working + A(IA)*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))

				earn_mean_corr = earn_mean_corr + INCOME*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				earn_mean_corr_working = earn_mean_corr_working + INCOME*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))

				income_mean_corr = income_mean_corr + TINCOME*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))

				! lab income and cap income correlation
				kinc_mean_corr = kinc_mean_corr + (TINCOME-INCOME)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				kinc_mean_corr_working = kinc_mean_corr_working + (TINCOME-INCOME)*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))
                
            END DO
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
			DO IS=1,nn 
            
			INCOME = 0.0
			TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 

			wealth_mean_corr = wealth_mean_corr + A(IA)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
			earn_mean_corr = earn_mean_corr + INCOME*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
			income_mean_corr = income_mean_corr + TINCOME*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))

			kinc_mean_corr = kinc_mean_corr + (TINCOME-INCOME)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
            
			END DO 
        END DO 
    END DO
END DO       

! compute cov, var
DO AGE=1,RETAGE-1
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn                    
                
				JN=IDCWN(AGE,IA,IR,IS)
				INCOME = WAGE*EFFLONG(AGE)*N(JN)*W(IS)
				TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 
		
				cov_earn_wealth = cov_earn_wealth + (INCOME-earn_mean_corr)*(A(IA)-wealth_mean_corr)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				cov_earn_wealth_working = cov_earn_wealth_working + (INCOME-earn_mean_corr_working)*(A(IA)-wealth_mean_corr_working)*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))

				cov_income_wealth = cov_income_wealth + (TINCOME-income_mean_corr)*(A(IA)-wealth_mean_corr)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))

				var_wealth = var_wealth + ((A(IA)-wealth_mean_corr)**2)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				var_wealth_working = var_wealth_working + ((A(IA)-wealth_mean_corr_working)**2)*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))

				var_earn = var_earn + ((INCOME-earn_mean_corr)**2)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				var_earn_working = var_earn_working + ((INCOME-earn_mean_corr_working)**2)*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))

				var_income = var_income + ((TINCOME-income_mean_corr)**2)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				
				cov_earn_kinc = cov_earn_kinc + (INCOME-earn_mean_corr)*((TINCOME-INCOME)-kinc_mean_corr)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				cov_earn_kinc_working = cov_earn_kinc_working + (INCOME-earn_mean_corr_working)*((TINCOME-INCOME)-kinc_mean_corr_working)*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))
				var_kinc = var_kinc + (((TINCOME-INCOME)-kinc_mean_corr)**2)*D_YW(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
				var_kinc_working = var_kinc_working + (((TINCOME-INCOME)-kinc_mean_corr_working)**2)*D_YW(AGE,IA,IR,IS)/SUM(D_YW(1:RETAGE-1,:,:,:))

            END DO
        END DO 
    END DO
END DO

DO AGE=RETAGE,MAXAGE
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
			DO IS=1,nn 
            
			INCOME = 0.0
			TINCOME = min(R(IR)*A(IA),d_c) + (1-tau_c)*max(R(IR)*A(IA)-d_c,0.0) + INCOME 

			cov_earn_wealth = cov_earn_wealth + (INCOME-earn_mean_corr)*(A(IA)-wealth_mean_corr)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
			cov_income_wealth = cov_income_wealth + (TINCOME-income_mean_corr)*(A(IA)-wealth_mean_corr)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))

			var_wealth = var_wealth + ((A(IA)-wealth_mean_corr)**2)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
			var_earn = var_earn + ((INCOME-earn_mean_corr)**2)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
			var_income = var_income + ((TINCOME-income_mean_corr)**2)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))

			cov_earn_kinc = cov_earn_kinc + (INCOME-earn_mean_corr)*((TINCOME-INCOME)-kinc_mean_corr)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
			var_kinc = var_kinc + (((TINCOME-INCOME)-kinc_mean_corr)**2)*D_YR(AGE,IA,IR,IS)/(SUM(D_YW(1:RETAGE-1,:,:,:)) + SUM(D_YR(RETAGE:MAXAGE,:,:,:)))
			
			END DO 
        END DO 
    END DO
END DO       

corr_earn_wealth = cov_earn_wealth/(var_earn*var_wealth)**0.5
corr_earn_wealth_working = cov_earn_wealth_working/(var_earn_working*var_wealth_working)**0.5
corr_income_wealth = cov_income_wealth/(var_income*var_wealth)**0.5
corr_earn_kinc = cov_earn_kinc/(var_earn*var_kinc)**0.5
corr_earn_kinc_working = cov_earn_kinc_working/(var_earn_working*var_kinc_working)**0.5



END SUBROUTINE
!**********************************************************************************************************************

SUBROUTINE earnings_growth_moments

ALLOCATE( earngrowth((RETAGE-3)*NGRIDA*NGRIDR*nn*NGRIDR*nn) )
ALLOCATE( density_earngrowth((RETAGE-3)*NGRIDA*NGRIDR*nn*NGRIDR*nn) )

earngrowth(:) = 0.0
density_earngrowth(:) = 0.0

id = 0
DO AGE=2,RETAGE-2
    DO IA=1,NGRIDA
		DO IR=1,NGRIDR
            DO IS=1,nn
				
				JA = IDCWA(AGE,IA,IR,IS) 
				INCOME_today = WAGE*EFFLONG(AGE)*N(IDCWN(AGE,IA,IR,IS))*W(IS)	

			IF ( (INCOME_today >= earningthreshold1) .AND. (YW(AGE,IA,IR,IS)>0.0) ) THEN
				IF (IS<=3) THEN 	
					DO IR1=1,NGRIDR
						DO IS1=1,3	
							id = id + 1 
							INCOME_tmr= WAGE*EFFLONG(AGE+1)*N(IDCWN(AGE+1,JA,IR1,IS1))*W(IS1)    !  IR1 and IS1 are the states for tmr
							IF (INCOME_tmr > 0.0) THEN 
								
								earngrowth(id) =  log(INCOME_tmr) - log(INCOME_today) 
								density_earngrowth(id) = YW(AGE,IA,IR,IS)*MU(AGE)*P_r(IR,IR1,zgroup(IS))*P(IS,IS1)
								
							END IF 
							 
						END DO 

						IS1=7	
							id = id + 1 
							INCOME_tmr= WAGE*EFFLONG(AGE+1)*N(IDCWN(AGE+1,JA,IR1,IS1))*W(IS1)    !  IR1 and IS1 are the states for tmr
							IF (INCOME_tmr > 0.0) THEN 
							
								earngrowth(id) =  log(INCOME_tmr) - log(INCOME_today)
								density_earngrowth(id) = YW(AGE,IA,IR,IS)*MU(AGE)*P_r(IR,IR1,zgroup(IS))*P(IS,IS1)
								
							END IF 						 
							
					END DO

				ELSEIF( (IS==4) .OR. (IS==5) .OR. (IS==6) )THEN		

					DO IR1=1,NGRIDR
						DO IS1=4,6
							id = id + 1 
							INCOME_tmr= WAGE*EFFLONG(AGE+1)*N(IDCWN(AGE+1,JA,IR1,IS1))*W(IS1)    !  IR1 and IS1 are the states for tmr
							IF (INCOME_tmr > 0.0) THEN 
								earngrowth(id) =  log(INCOME_tmr) - log(INCOME_today)
								density_earngrowth(id) = YW(AGE,IA,IR,IS)*MU(AGE)*P_r(IR,IR1,zgroup(IS))*P(IS,IS1)
								
							END IF 
							 
						END DO 

						IS1=7	
							id = id + 1 
							INCOME_tmr= WAGE*EFFLONG(AGE+1)*N(IDCWN(AGE+1,JA,IR1,IS1))*W(IS1)    !  IR1 and IS1 are the states for tmr
							IF (INCOME_tmr > 0.0) THEN 
							
								earngrowth(id) =  log(INCOME_tmr) - log(INCOME_today)
								density_earngrowth(id) = YW(AGE,IA,IR,IS)*MU(AGE)*P_r(IR,IR1,zgroup(IS))*P(IS,IS1)
								
							END IF 
							 
							
					END DO

				ELSEIF( IS==7 ) THEN	

					DO IR1=1,NGRIDR
						DO IS1=1,nn
							id = id + 1 
							INCOME_tmr= WAGE*EFFLONG(AGE+1)*N(IDCWN(AGE+1,JA,IR1,IS1))*W(IS1)    !  IR1 and IS1 are the states for tmr
							IF (INCOME_tmr > 0.0) THEN 
		
								earngrowth(id) =  log(INCOME_tmr) - log(INCOME_today)
								density_earngrowth(id) = YW(AGE,IA,IR,IS)*MU(AGE)*P_r(IR,IR1,zgroup(IS))*P(IS,IS1)
								
							END IF 
							 
						END DO 
					END DO

				ELSEIF( IS==8 ) THEN	

					DO IR1=1,NGRIDR
						DO IS1=nn-1,nn
							id = id + 1 
							INCOME_tmr= WAGE*EFFLONG(AGE+1)*N(IDCWN(AGE+1,JA,IR1,IS1))*W(IS1)    !  IR1 and IS1 are the states for tmr
							IF (INCOME_tmr > 0.0) THEN 
							
								earngrowth(id) =  log(INCOME_tmr) - log(INCOME_today)
								density_earngrowth(id) = YW(AGE,IA,IR,IS)*MU(AGE)*P_r(IR,IR1,zgroup(IS))*P(IS,IS1)
								
							END IF 
							 
						END DO 
					END DO		
							
				END IF 

			END IF 

			END DO 
		END DO 	
	END DO  
END DO 

density_earngrowth(:) = density_earngrowth(:)/sum(density_earngrowth)
print*,'sum of density_earngrowth=', sum(density_earngrowth)

! Mean

avg_earning_growth = sum(earngrowth(:)*density_earngrowth(:))
sd_earning_growth = (sum(  ((earngrowth(:)-avg_earning_growth)**2)*density_earngrowth(:) ))**0.5
skew_earning_growth = sum(  (((earngrowth(:)-avg_earning_growth)/sd_earning_growth)**3)*density_earngrowth(:) )
kurt_earning_growth = sum(  (((earngrowth(:)-avg_earning_growth)/sd_earning_growth)**4)*density_earngrowth(:) )
										

END SUBROUTINE
!**********************************************************************************************************************

SUBROUTINE INTERGENERATIONAL
	
	! Computes intergenerational wealth correlation as in Charles and Hurst, JPE 2003.
	! kids are ages 2-6, parents ages 4-8 (measured 15 years before the kids)
	
	real(prec) :: D_kids(5,Ngrida,Ngridr,nn)
	real(prec) :: D_parents(5,Ngrida,Ngridr,nn)
	real(prec) :: A_kids(5,Ngrida,Ngridr,nn)
	real(prec) :: A_parents(5,Ngrida,Ngridr,nn)
	real(prec) :: beta3(3,1), beta4(4,1), beta6(6,1)
	real(prec) :: XWX3(3,3), XWX4(4,4), XWX6(6,6), XWXinv(6,6), XWY3(3,1), XWY4(4,1), XWY6(6,1)
	integer :: obscounter, nrposwobs, nrbottom99obs, i1
	REAL(prec) :: wealththreshold_kids, wealththreshold_parents
	LOGICAL :: OK_FLAG
	
	real(prec), ALLOCATABLE :: regY(:,:), regYpos(:,:), regYw(:,:), regYposw(:,:)
	real(prec), ALLOCATABLE :: regX(:,:), regXpos(:,:), regXw(:,:), regXposw(:,:)
	real(prec), ALLOCATABLE :: regw(:,:), regwpos(:,:), regw_cumsum(:,:)
	real(prec), ALLOCATABLE :: wealth_kids_adj(:,:), wealth_parents_adj(:,:)
	INTEGER, ALLOCATABLE :: wealth_kids_quintile(:,:), wealth_parents_quintile(:,:)
	INTEGER, ALLOCATABLE :: record_position_reg(:,:), bottom99vec(:,:)

	ALLOCATE( regY(5*Ngrida*5*Ngrida,1))
	ALLOCATE( regX(5*Ngrida*5*Ngrida,4))
	ALLOCATE( regw(5*Ngrida*5*Ngrida,1))

	D_kids = D_YW(2:6,:,:,:)
	D_kids = D_kids/sum(D_kids)
	
	D_parents = D_YW(4:8,:,:,:)
	D_parents = D_parents/sum(D_parents)
	
	! parents' wealth is average over current and next age
	A_parents = 0.0D0
	A_kids = 0.0D0
	DO IAGE=1,5
		DO IA = 1,NGRIDA
			DO IR = 1,NGRIDR
				DO IS = 1,nn
					A_kids(IAGE,IA,IR,IS) = A(IA)
					D_kids(IAGE,IA,IR,IS) = D_YW(IAGE+1,IA,IR,IS)
					JA = IDCWA(IAGE+3,IA,IR,IS)
					A_parents(IAGE,IA,IR,IS) = (A(IA) + A(JA))/2.
					D_parents(IAGE,IA,IR,IS) = D_YW(IAGE+3,IA,IR,IS)
				END DO
			END DO
		END DO
	END DO
	D_kids = D_kids/sum(D_kids)
	D_parents = D_parents/sum(D_parents)
	

	! Charles and Hurst regress log kid's wealth on log parent wealth and age of both kids and parents.
	! to do this, build arrays of these variables (regY for log kid's wealth, regX for the constant and the RHS variables), and a vector of weights, regw.
	! in the data, only age and wealth are observable, so only create observations at that level.
	
	
	regY = 0.D0
	regX = 0.D0
	obscounter = 0
	DO IAGE = 1,5 ! loop over kids
		DO IA = 1,NGRIDA
			DO JAGE = 1,5 ! loop over parents
				DO JA = 1,NGRIDA
					obscounter = obscounter+1		
					regY(obscounter,1) = LOG(A(IA))	! kid's wealth
					regX(obscounter,1) = 1.D0	! constant
					regX(obscounter,3) = IAGE+1	! kid's age: 2-6
					regX(obscounter,4) = JAGE+3	! parent's age: 4-8
					regX(obscounter,2) = 0.D0  ! parent wealth
					DO JR = 1,NGRIDR
						DO JS = 1,nn
							! build parent wealth:
									regX(obscounter,2) = regX(obscounter,2) + &
									LOG(A_parents(JAGE,JA,JR,JS))*D_YW(JAGE+3,JA,JR,JS)/sum(D_YW(JAGE+3,JA,:,:))
							! this is avg wealth of parents with age JAGE and assets JA today.
						END DO
					END DO
					! build weights
					regw(obscounter,1) = 0.D0
					DO IR = 1,NGRIDR
						DO IS = 1,nn
							DO JR = 1,NGRIDR
								DO JS = 1,nn
									IF ( JS .ge. 4 .and. IS .ge. 4 ) THEN
										IF ( JR .ge. 2 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,2,2,2)
										ELSEIF ( JR .ge. 2 .and. IR .le. 1 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,1,2,2)
										ELSEIF ( JR .le. 1 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,2,2,2)
										ELSE 
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,1,2,2)
										END IF 
									ELSEIF ( JS .ge. 4 .and. IS .le. 3 ) THEN
										IF ( JR .ge. 2 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,2,2,1)
										ELSEIF ( JR .ge. 2 .and. IR .le. 1 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,1,2,1)
										ELSEIF ( JR .le. 1 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,2,2,1)
										ELSE 
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,1,2,1)
										END IF									
									ELSEIF ( JS .le. 3 .and. IS .ge. 4 ) THEN
										IF ( JR .ge. 2 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,2,1,2)
										ELSEIF ( JR .ge. 2 .and. IR .le. 1 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,1,1,2)
										ELSEIF ( JR .le. 1 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,2,1,2)
										ELSE 
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,1,1,2)
										END IF 					
									ELSE
										IF ( JR .ge. 2 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,2,1,1)
										ELSEIF ( JR .ge. 2 .and. IR .le. 1 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(2,1,1,1)
										ELSEIF ( JR .le. 1 .and. IR .ge. 2 ) THEN
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,2,1,1)
										ELSE 
											regw(obscounter,1) = regw(obscounter,1) + &
												D_kids(IAGE,IA,IR,IS) * D_parents(JAGE,JA,JR,JS) * &
												pdf_parent_kid(1,1,1,1)
										END IF 
									END IF
								END DO
							END DO
						END DO
					END DO ! regw

				END DO
			END DO
		END DO
	END DO
	
	regw = regw/sum(regw)
	
	print*, "Regression data is built."
	print*, "There are ", size(regw), " observations including zero weights and"
	


! 	! OLS:
! 	beta = MATMUL(INV(MATMUL(TRANSPOSE(regX),regX)),MATMUL(TRANSPOSE(regX),regY))

! elimiante obs with zero weight: 
nrposwobs = count(regw .gt. 1e-14)
print*, nrposwobs, " observations excluding zero weights."
ALLOCATE( regYpos(nrposwobs,1), regYposw(nrposwobs,1))
ALLOCATE( regXpos(nrposwobs,6), regXposw(nrposwobs,6))
ALLOCATE( regwpos(nrposwobs,1))
ALLOCATE( regw_cumsum(nrposwobs,1))
ALLOCATE( record_position_reg(nrposwobs,1))
ALLOCATE( bottom99vec(nrposwobs,1))

print*, "obs with weight > 1e-8 ", count(regw .gt. 1e-8)
print*, "obs with weight > 1e-10 ", count(regw .gt. 1e-10)
print*, "obs with weight > 1e-12 ", count(regw .gt. 1e-12)
print*, "obs with weight > 1e-14 ", count(regw .gt. 1e-14)
print*, "obs with weight > 1e-16 ", count(regw .gt. 1e-16)


! Eliminate zero weight observations:
regYpos(:,1) = PACK(regY(:,1),  regw(:,1) .gt. 1e-14)

do i1=1,4
	regXpos(:,i1) = PACK(regX(:,i1), regw(:,1) .gt. 1e-14)
end do
regwpos(:,1) = PACK(regw(:,1), regw(:,1) .gt. 1e-14)
regwpos(:,1) = regwpos(:,1)/sum(regwpos)


DEALLOCATE(regY, regX, regw)

! convert age to years, create square terms
regXpos(:,3) = 17.5+regXpos(:,3)*5
regXpos(:,4) = 17.5+regXpos(:,4)*5
regXpos(:,5) = regXpos(:,3)**2
regXpos(:,6) = regXpos(:,4)**2


! Sort and count how many are in bottom 99%
do i1=1,size(regYpos)
	record_position_reg(i1,1) = i1
end do

CALL SSORT_INT(regYpos,record_position_reg,size(regYpos),2)

do i1=1,6
	regXpos(:,i1) = regXpos(record_position_reg(:,1),i1)
end do
regwpos(:,1) = regwpos(record_position_reg(:,1),1)

regw_cumsum(1,1) = regwpos(1,1);
do i1=2,nrposwobs
	regw_cumsum(i1,1) = regw_cumsum(i1-1,1) + regwpos(i1,1)
end do
print*, "last element of regw_cumsum is ", regw_cumsum(nrposwobs,1)

nrbottom99obs = count(regw_cumsum < .99)
print*, "Observations:"
print*, "total: ", nrposwobs
print*, "bottom 99% of kids: ", nrbottom99obs
print*, "top 1%: ", nrposwobs-nrbottom99obs
wealththreshold_kids = regYpos(nrbottom99obs+1,1)
print*, "wealth threshold kids:", wealththreshold_kids

! now sort by parent wealth
do i1=1,size(regYpos)
	record_position_reg(i1,1) = i1
end do

CALL SSORT_INT(regXpos(:,2),record_position_reg,size(regYpos),2)

regYpos(:,1) = regYpos(record_position_reg(:,1),1)
regXpos(:,1) = regXpos(record_position_reg(:,1),1)
do i1=3,6
	regXpos(:,i1) = regXpos(record_position_reg(:,1),i1)
end do
regwpos(:,1) = regwpos(record_position_reg(:,1),1)


regw_cumsum(1,1) = regwpos(1,1);
do i1=2,nrposwobs
	regw_cumsum(i1,1) = regw_cumsum(i1-1,1) + regwpos(i1,1)
end do
print*, "last element of regw_cumsum is ", regw_cumsum(nrposwobs,1)

nrbottom99obs = count(regw_cumsum < .99)
print*, "Observations:"
print*, "total: ", nrposwobs
print*, "bottom 99% of parents: ", nrbottom99obs
print*, "top 1%: ", nrposwobs-nrbottom99obs
wealththreshold_parents = regXpos(nrbottom99obs+1,2)
print*, "wealth threshold parents:", wealththreshold_parents

do i1=1,size(regYpos)
bottom99vec(i1,1) = MERGE(1,0,( regYpos(i1,1) .lt. wealththreshold_kids) .and. (regXpos(i1,2) .lt. wealththreshold_parents ))
end do


! use weights:
do i1=1,6
	regXposw(:,i1) = regXpos(:,i1)*(sqrt(regwpos(:,1)))
end do
	regYposw(:,1)  = regYpos(:,1) *(sqrt(regwpos(:,1)))
		
	! regression with square terms, all data points:
	XWX6 = MATMUL(TRANSPOSE(regXposw),regXposw)
	XWY6 = MATMUL(TRANSPOSE(regXposw),regYposw)
	CALL M66INV(XWX6,XWXinv,OK_FLAG)
	beta6 = MATMUL(XWXinv, XWY6)	

	print*, ""
	print*, "Regress kid wealth on parent wealth, controlling for age, as in Charles and Hurst:"
	print*, "Results from intergen. regression (age sq, all data points): ", beta6
	print*, "(using ", size(regYpos), " observations)"
! 	print*, "Log wealth correlation between parents and kids is ", corr_Akids_Aparents_sq

	! regression without square terms, all data points:
	XWX4 = MATMUL(TRANSPOSE(regXposw(:,1:4)),regXposw(:,1:4))
	XWY4 = MATMUL(TRANSPOSE(regXposw(:,1:4)),regYposw)
	beta4 = MATMUL(MATINV4(XWX4), XWY4)	
	print*, "Results from intergen. regression (age linear, all data points): ", beta4

	! generate regY etc., which contain only bottom 99%
	nrbottom99obs = sum(bottom99vec(:,1), bottom99vec(:,1) .eq. 1)	
! 	print*, "Nr obs in bottom 99% of kids and parents: ", nrbottom99obs
	allocate(regY(nrbottom99obs,1), regX(nrbottom99obs,6), regw(nrbottom99obs,1))
	allocate(regYw(nrbottom99obs,1), regXw(nrbottom99obs,6))
	regY(:,1) = PACK(regYpos(:,1), bottom99vec(:,1) .eq. 1)
do i1=1,6
	regX(:,i1) = PACK(regXpos(:,i1), bottom99vec(:,1) .eq. 1)
end do
	regw(:,1) = PACK(regwpos(:,1), bottom99vec(:,1) .eq. 1)
	! use weights:
	do i1=1,6
		regXw(:,i1) = regX(:,i1)*(sqrt(regw(:,1)))
	end do
		regYw(:,1)  = regY(:,1) *(sqrt(regw(:,1)))

	! regression with square terms, bottom 99% of both:
	XWX6 = MATMUL(TRANSPOSE(regXw),regXw)
	XWY6 = MATMUL(TRANSPOSE(regXw),regYw)
	CALL M66INV(XWX6,XWXinv,OK_FLAG)
	beta6 = MATMUL(XWXinv, XWY6)	
	corr_Akids_Aparents_sq = beta6(2,1)
	print*, "Results from intergen. regression (age sq, bottom 99% of wealth of both): ", beta6
	print*, "(using ", nrbottom99obs, " observations)"
	print*, "Log wealth correlation between parents and kids is ", corr_Akids_Aparents_sq

	! regression without square terms, bottom 99% of both:
	XWX4 = MATMUL(TRANSPOSE(regXw(:,1:4)),regXw(:,1:4))
	XWY4 = MATMUL(TRANSPOSE(regXw(:,1:4)),regYw)
	beta4 = MATMUL(MATINV4(XWX4), XWY4)	
	print*, "Results from intergen. regression (age linear, bottom 99% of wealth of both): ", beta4
	corr_Akids_Aparents_lin = beta4(2,1)
	

	!!!!!!!!!!!!!!
	! get transition matrix
	!!!!!!!!!!!!!!
	
	deallocate(record_position_reg, regw_cumsum)
	allocate(wealth_kids_adj(nrbottom99obs,1), wealth_parents_adj(nrbottom99obs,1))
	allocate(wealth_kids_quintile(nrbottom99obs,1), wealth_parents_quintile(nrbottom99obs,1))
	allocate(record_position_reg(nrbottom99obs,1), regw_cumsum(nrbottom99obs,1))
	


	! 1. generate age-adjusted log wealth for parnets and kids
	! a. regress kid log wealth on constant, age, and age squared
	XWX3 = MATMUL(TRANSPOSE(regXw(:,(/ 1, 3, 5 /))), regXw(:,(/ 1, 3, 5 /)))
	XWY3 = MATMUL(TRANSPOSE(regXw(:,(/ 1, 3, 5 /))), regYw)
	beta3 = MATMUL(MATINV3(XWX3),XWY3)
	print*, " "
	print*, "Generate age-adjusted wealth:"
	print*, "beta3 (kids): ", beta3
	! generate age-adjusted wealth, kids
	wealth_kids_adj(:,1) = regY(:,1) - beta3(1,1) - regX(:,3)*beta3(2,1) - regX(:,5)*beta3(3,1)
	print*, "size wka:", shape(wealth_kids_adj)
	print*, "min wka:", minval(wealth_kids_adj)
	print*, "max wka:", maxval(wealth_kids_adj)
	print*, "mean wka:", sum(wealth_kids_adj)/size(wealth_kids_adj)

	! b. regress parent log wealth on constant, age, and age squared
	XWX3 = MATMUL(TRANSPOSE(regXw(:,(/ 1, 4, 6 /))), regXw(:,(/ 1, 4, 6 /)))
	XWY3(:,1) = MATMUL(TRANSPOSE(regXw(:,(/ 1, 4, 6 /))), regXw(:,2))
	beta3 = MATMUL(MATINV3(XWX3),XWY3)
	print*, "beta3 (parents): ", beta3
	! generate age-adjusted wealth, parents
	wealth_parents_adj(:,1) = regX(:,2) - beta3(1,1) - regX(:,4)*beta3(2,1) - regX(:,6)*beta3(3,1)
	print*, "min wpa:", minval(wealth_parents_adj)
	print*, "max wpa:", maxval(wealth_parents_adj)
	print*, "mean wpa:", sum(wealth_parents_adj)/size(wealth_parents_adj)


	! 2. generate quintiles
	! a. sort kids by age-adjusted wealth
	do i1=1,nrbottom99obs
		record_position_reg(i1,1) = i1
	end do
	regw(:,1) = regw(:,1)/sum(regw(:,1))

	CALL SSORT_INT(wealth_kids_adj,record_position_reg,nrbottom99obs,2)
	regw(:,1) = regw(record_position_reg(:,1),1)
	wealth_parents_adj(:,1) = wealth_parents_adj(record_position_reg(:,1),1)
	regw_cumsum(1,1) = regw(1,1);
	do i1=2,nrbottom99obs
		regw_cumsum(i1,1) = regw_cumsum(i1-1,1) + regw(i1,1)
	end do
	
	! b. generate quintiles
	wealth_kids_quintile(:,1) = MIN(CEILING(regw_cumsum(:,1)*5),5)
	
	! c. sort parents by age-adjusted wealth
	do i1=1,nrbottom99obs
		record_position_reg(i1,1) = i1
	end do
	CALL SSORT_INT(wealth_parents_adj,record_position_reg,nrbottom99obs,2)
	regw(:,1) = regw(record_position_reg(:,1),1)
	wealth_kids_quintile(:,1) = wealth_kids_quintile(record_position_reg(:,1),1)
	
	regw_cumsum(1,1) = regw(1,1);
	do i1=2,nrbottom99obs
		regw_cumsum(i1,1) = regw_cumsum(i1-1,1) + regw(i1,1)
	end do
	! d. generate quintiles
	wealth_parents_quintile(:,1) = MIN(CEILING(regw_cumsum(:,1)*5),5)
	
	! 3. how often are differnet quintiles matched?
	wealth_trans(:,:) = 0.0D0
	do i1=1,nrbottom99obs
		wealth_trans(wealth_kids_quintile(i1,1),wealth_parents_quintile(i1,1)) = &
			wealth_trans(wealth_kids_quintile(i1,1),wealth_parents_quintile(i1,1)) + regw(i1,1)
	end do

	do i1=1,5
		wealth_trans(:,i1) = wealth_trans(:,i1)/sum(wealth_trans(:,i1))
	end do
	
	print*, "Wealth transition matrix (cols (parents) sum to 1):"
	do i1=1,5
		write(unit=*, fmt='(5(F5.1,X))') 100*wealth_trans(i1,:)
	end do

	DEALLOCATE(regY, regX, regw)

END SUBROUTINE
!**********************************************************************************************************************
FUNCTION search(X,Y,Z,W)

INTEGER:: i,j,search
REAL(prec):: W
INTEGER, DIMENSION(:):: Z
REAL(prec), INTENT(IN):: X
REAL(prec), DIMENSION(:), INTENT(IN) :: Y

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


100 END FUNCTION  search

!***********************************************************************************************
function utility (cons,lei)
    !  Purpose
	!  Assuming that the utility function is of CRRA type,
	!  compute the utility base on consume and leisure 
    
		REAL(prec) cons, lei
        REAL(prec) utility 

		utility = (CONS**(1-SIGMA))/(1-SIGMA) - CHI*((1.0-LEI)**(1+THETA))/(1+THETA)

end function utility 
!***********************************************************************************************

function beq_aftertax(beq)

	REAL(prec) beq_aftertax,beq

    beq_aftertax = (1.0-beqtax_rate1)*MIN(beq, beqtax_exempt) + (1.0-beqtax_rate2)*MAX(0.0, beq - beqtax_exempt)

end function beq_aftertax

!***********************************************************************************************

REAL FUNCTION gini(x,f)
	! returns the Gini coefficient for a distribution
	! required inputs: x are values, f is mass at each point.
	REAL(prec), DIMENSION(:), INTENT(IN) :: x, f
	REAL(prec) :: g ! Gini coefficient

	INTEGER :: i, j, L

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

    g = g/(2*dot_product(x,f))
	gini = g


END FUNCTION gini
!*********************************************************************************************************************

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

!*********************************************************************************************************************
function matinv3(A) result(B)
    !! Performs a direct calculation of the inverse of a 3×3 matrix.
    real(prec), intent(in) :: A(3,3)   !! Matrix
    real(prec)             :: B(3,3)   !! Inverse matrix
    real(prec)             :: detinv

    ! Calculate the inverse determinant of the matrix
    detinv = 1/(A(1,1)*A(2,2)*A(3,3) - A(1,1)*A(2,3)*A(3,2)&
              - A(1,2)*A(2,1)*A(3,3) + A(1,2)*A(2,3)*A(3,1)&
              + A(1,3)*A(2,1)*A(3,2) - A(1,3)*A(2,2)*A(3,1))

    ! Calculate the inverse of the matrix
    B(1,1) = +detinv * (A(2,2)*A(3,3) - A(2,3)*A(3,2))
    B(2,1) = -detinv * (A(2,1)*A(3,3) - A(2,3)*A(3,1))
    B(3,1) = +detinv * (A(2,1)*A(3,2) - A(2,2)*A(3,1))
    B(1,2) = -detinv * (A(1,2)*A(3,3) - A(1,3)*A(3,2))
    B(2,2) = +detinv * (A(1,1)*A(3,3) - A(1,3)*A(3,1))
    B(3,2) = -detinv * (A(1,1)*A(3,2) - A(1,2)*A(3,1))
    B(1,3) = +detinv * (A(1,2)*A(2,3) - A(1,3)*A(2,2))
    B(2,3) = -detinv * (A(1,1)*A(2,3) - A(1,3)*A(2,1))
    B(3,3) = +detinv * (A(1,1)*A(2,2) - A(1,2)*A(2,1))
  end function
  
!*********************************************************************************************************************

function matinv4(A) result(B)
    !! Performs a direct calculation of the inverse of a 4×4 matrix.
	! reference: http://fortranwiki.org/fortran/show/Matrix+inversion
    real(prec), intent(in) :: A(4,4)   !! Matrix
    real(prec)             :: B(4,4)   !! Inverse matrix
    real(prec)             :: detinv

    ! Calculate the inverse determinant of the matrix
    detinv = &
      1/(A(1,1)*(A(2,2)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(2,3)*(A(3,4)*A(4,2)-A(3,2)*A(4,4))+A(2,4)*(A(3,2)*A(4,3)-A(3,3)*A(4,2)))&
       - A(1,2)*(A(2,1)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(2,3)*(A(3,4)*A(4,1)-A(3,1)*A(4,4))+A(2,4)*(A(3,1)*A(4,3)-A(3,3)*A(4,1)))&
       + A(1,3)*(A(2,1)*(A(3,2)*A(4,4)-A(3,4)*A(4,2))+A(2,2)*(A(3,4)*A(4,1)-A(3,1)*A(4,4))+A(2,4)*(A(3,1)*A(4,2)-A(3,2)*A(4,1)))&
       - A(1,4)*(A(2,1)*(A(3,2)*A(4,3)-A(3,3)*A(4,2))+A(2,2)*(A(3,3)*A(4,1)-A(3,1)*A(4,3))+A(2,3)*(A(3,1)*A(4,2)-A(3,2)*A(4,1))))

    ! Calculate the inverse of the matrix
    B(1,1) = detinv*(A(2,2)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(2,3)*(A(3,4)*A(4,2)-A(3,2)*A(4,4))+A(2,4)*(A(3,2)*A(4,3)-A(3,3)*A(4,2)))
    B(2,1) = detinv*(A(2,1)*(A(3,4)*A(4,3)-A(3,3)*A(4,4))+A(2,3)*(A(3,1)*A(4,4)-A(3,4)*A(4,1))+A(2,4)*(A(3,3)*A(4,1)-A(3,1)*A(4,3)))
    B(3,1) = detinv*(A(2,1)*(A(3,2)*A(4,4)-A(3,4)*A(4,2))+A(2,2)*(A(3,4)*A(4,1)-A(3,1)*A(4,4))+A(2,4)*(A(3,1)*A(4,2)-A(3,2)*A(4,1)))
    B(4,1) = detinv*(A(2,1)*(A(3,3)*A(4,2)-A(3,2)*A(4,3))+A(2,2)*(A(3,1)*A(4,3)-A(3,3)*A(4,1))+A(2,3)*(A(3,2)*A(4,1)-A(3,1)*A(4,2)))
    B(1,2) = detinv*(A(1,2)*(A(3,4)*A(4,3)-A(3,3)*A(4,4))+A(1,3)*(A(3,2)*A(4,4)-A(3,4)*A(4,2))+A(1,4)*(A(3,3)*A(4,2)-A(3,2)*A(4,3)))
    B(2,2) = detinv*(A(1,1)*(A(3,3)*A(4,4)-A(3,4)*A(4,3))+A(1,3)*(A(3,4)*A(4,1)-A(3,1)*A(4,4))+A(1,4)*(A(3,1)*A(4,3)-A(3,3)*A(4,1)))
    B(3,2) = detinv*(A(1,1)*(A(3,4)*A(4,2)-A(3,2)*A(4,4))+A(1,2)*(A(3,1)*A(4,4)-A(3,4)*A(4,1))+A(1,4)*(A(3,2)*A(4,1)-A(3,1)*A(4,2)))
    B(4,2) = detinv*(A(1,1)*(A(3,2)*A(4,3)-A(3,3)*A(4,2))+A(1,2)*(A(3,3)*A(4,1)-A(3,1)*A(4,3))+A(1,3)*(A(3,1)*A(4,2)-A(3,2)*A(4,1)))
    B(1,3) = detinv*(A(1,2)*(A(2,3)*A(4,4)-A(2,4)*A(4,3))+A(1,3)*(A(2,4)*A(4,2)-A(2,2)*A(4,4))+A(1,4)*(A(2,2)*A(4,3)-A(2,3)*A(4,2)))
    B(2,3) = detinv*(A(1,1)*(A(2,4)*A(4,3)-A(2,3)*A(4,4))+A(1,3)*(A(2,1)*A(4,4)-A(2,4)*A(4,1))+A(1,4)*(A(2,3)*A(4,1)-A(2,1)*A(4,3)))
    B(3,3) = detinv*(A(1,1)*(A(2,2)*A(4,4)-A(2,4)*A(4,2))+A(1,2)*(A(2,4)*A(4,1)-A(2,1)*A(4,4))+A(1,4)*(A(2,1)*A(4,2)-A(2,2)*A(4,1)))
    B(4,3) = detinv*(A(1,1)*(A(2,3)*A(4,2)-A(2,2)*A(4,3))+A(1,2)*(A(2,1)*A(4,3)-A(2,3)*A(4,1))+A(1,3)*(A(2,2)*A(4,1)-A(2,1)*A(4,2)))
    B(1,4) = detinv*(A(1,2)*(A(2,4)*A(3,3)-A(2,3)*A(3,4))+A(1,3)*(A(2,2)*A(3,4)-A(2,4)*A(3,2))+A(1,4)*(A(2,3)*A(3,2)-A(2,2)*A(3,3)))
    B(2,4) = detinv*(A(1,1)*(A(2,3)*A(3,4)-A(2,4)*A(3,3))+A(1,3)*(A(2,4)*A(3,1)-A(2,1)*A(3,4))+A(1,4)*(A(2,1)*A(3,3)-A(2,3)*A(3,1)))
    B(3,4) = detinv*(A(1,1)*(A(2,4)*A(3,2)-A(2,2)*A(3,4))+A(1,2)*(A(2,1)*A(3,4)-A(2,4)*A(3,1))+A(1,4)*(A(2,2)*A(3,1)-A(2,1)*A(3,2)))
    B(4,4) = detinv*(A(1,1)*(A(2,2)*A(3,3)-A(2,3)*A(3,2))+A(1,2)*(A(2,3)*A(3,1)-A(2,1)*A(3,3))+A(1,3)*(A(2,1)*A(3,2)-A(2,2)*A(3,1)))

end function
!***********************************************************************************************************************************

SUBROUTINE M66INV (A, AINV, OK_FLAG)

!***********************************************************************************************************************************
!  M66INV  -  Compute the inverse of a 6x6 matrix.
!
!  A       = input 6x6 matrix to be inverted
!  AINV    = output 6x6 inverse of matrix A
!  OK_FLAG = (output) .TRUE. if the input matrix could be inverted, and .FALSE. if the input matrix is singular.
!***********************************************************************************************************************************

      IMPLICIT NONE

      DOUBLE PRECISION, DIMENSION(6,6), INTENT(IN)  :: A
      DOUBLE PRECISION, DIMENSION(6,6), INTENT(OUT) :: AINV
      LOGICAL, INTENT(OUT) :: OK_FLAG

      DOUBLE PRECISION, PARAMETER :: EPS = 1.0D-10
      DOUBLE PRECISION :: DET, A11, A12, A13, A14, A15, A16, A21, A22, A23, A24, &
         A25, A26, A31, A32, A33, A34, A35, A36, A41, A42, A43, A44, A45, A46,   &
         A51, A52, A53, A54, A55, A56, A61, A62, A63, A64, A65, A66
      DOUBLE PRECISION, DIMENSION(6,6) :: COFACTOR


      A11=A(1,1); A12=A(1,2); A13=A(1,3); A14=A(1,4); A15=A(1,5); A16=A(1,6)
      A21=A(2,1); A22=A(2,2); A23=A(2,3); A24=A(2,4); A25=A(2,5); A26=A(2,6)
      A31=A(3,1); A32=A(3,2); A33=A(3,3); A34=A(3,4); A35=A(3,5); A36=A(3,6)
      A41=A(4,1); A42=A(4,2); A43=A(4,3); A44=A(4,4); A45=A(4,5); A46=A(4,6)
      A51=A(5,1); A52=A(5,2); A53=A(5,3); A54=A(5,4); A55=A(5,5); A56=A(5,6)
      A61=A(6,1); A62=A(6,2); A63=A(6,3); A64=A(6,4); A65=A(6,5); A66=A(6,6)

      DET = -(A16*A25*A34*A43*A52-A15*A26*A34*A43*A52-A16*A24*A35*A43*             &
         A52+A14*A26*A35*A43*A52+A15*A24*A36*A43*A52-A14*A25*A36*A43*A52-A16*A25*  &
         A33*A44*A52+A15*A26*A33*A44*A52+A16*A23*A35*A44*A52-A13*A26*A35*A44*      &
         A52-A15*A23*A36*A44*A52+A13*A25*A36*A44*A52+A16*A24*A33*A45*A52-A14*A26*  &
         A33*A45*A52-A16*A23*A34*A45*A52+A13*A26*A34*A45*A52+A14*A23*A36*A45*      &
         A52-A13*A24*A36*A45*A52-A15*A24*A33*A46*A52+A14*A25*A33*A46*A52+A15*A23*  &
         A34*A46*A52-A13*A25*A34*A46*A52-A14*A23*A35*A46*A52+A13*A24*A35*A46*      &
         A52-A16*A25*A34*A42*A53+A15*A26*A34*A42*A53+A16*A24*A35*A42*A53-A14*A26*  &
         A35*A42*A53-A15*A24*A36*A42*A53+A14*A25*A36*A42*A53+A16*A25*A32*A44*      &
         A53-A15*A26*A32*A44*A53-A16*A22*A35*A44*A53+A12*A26*A35*A44*A53+A15*A22*  &
         A36*A44*A53-A12*A25*A36*A44*A53-A16*A24*A32*A45*A53+A14*A26*A32*A45*      &
         A53+A16*A22*A34*A45*A53-A12*A26*A34*A45*A53-A14*A22*A36*A45*A53+A12*A24*  &
         A36*A45*A53+A15*A24*A32*A46*A53-A14*A25*A32*A46*A53-A15*A22*A34*A46*      &
         A53+A12*A25*A34*A46*A53+A14*A22*A35*A46*A53-A12*A24*A35*A46*A53+A16*A25*  &
         A33*A42*A54-A15*A26*A33*A42*A54-A16*A23*A35*A42*A54+A13*A26*A35*A42*      &
         A54+A15*A23*A36*A42*A54-A13*A25*A36*A42*A54-A16*A25*A32*A43*A54+A15*A26*  &
         A32*A43*A54+A16*A22*A35*A43*A54-A12*A26*A35*A43*A54-A15*A22*A36*A43*      &
         A54+A12*A25*A36*A43*A54+A16*A23*A32*A45*A54-A13*A26*A32*A45*A54-A16*A22*  &
         A33*A45*A54+A12*A26*A33*A45*A54+A13*A22*A36*A45*A54-A12*A23*A36*A45*      &
         A54-A15*A23*A32*A46*A54+A13*A25*A32*A46*A54+A15*A22*A33*A46*A54-A12*A25*  &
         A33*A46*A54-A13*A22*A35*A46*A54+A12*A23*A35*A46*A54-A16*A24*A33*A42*      &
         A55+A14*A26*A33*A42*A55+A16*A23*A34*A42*A55-A13*A26*A34*A42*A55-A14*A23*  &
         A36*A42*A55+A13*A24*A36*A42*A55+A16*A24*A32*A43*A55-A14*A26*A32*A43*      &
         A55-A16*A22*A34*A43*A55+A12*A26*A34*A43*A55+A14*A22*A36*A43*A55-A12*A24*  &
         A36*A43*A55-A16*A23*A32*A44*A55+A13*A26*A32*A44*A55+A16*A22*A33*A44*      &
         A55-A12*A26*A33*A44*A55-A13*A22*A36*A44*A55+A12*A23*A36*A44*A55+A14*A23*  &
         A32*A46*A55-A13*A24*A32*A46*A55-A14*A22*A33*A46*A55+A12*A24*A33*A46*      &
         A55+A13*A22*A34*A46*A55-A12*A23*A34*A46*A55+A15*A24*A33*A42*A56-A14*A25*  &
         A33*A42*A56-A15*A23*A34*A42*A56+A13*A25*A34*A42*A56+A14*A23*A35*A42*      &
         A56-A13*A24*A35*A42*A56-A15*A24*A32*A43*A56+A14*A25*A32*A43*A56+A15*A22*  &
         A34*A43*A56-A12*A25*A34*A43*A56-A14*A22*A35*A43*A56+A12*A24*A35*A43*      &
         A56+A15*A23*A32*A44*A56-A13*A25*A32*A44*A56-A15*A22*A33*A44*A56+A12*A25*  &
         A33*A44*A56+A13*A22*A35*A44*A56-A12*A23*A35*A44*A56-A14*A23*A32*A45*      &
         A56+A13*A24*A32*A45*A56+A14*A22*A33*A45*A56-A12*A24*A33*A45*A56-A13*A22*  &
         A34*A45*A56+A12*A23*A34*A45*A56)*A61+(A16*A25*A34*A43*A51-A15*A26*A34*    &
         A43*A51-A16*A24*A35*A43*A51+A14*A26*A35*A43*A51+A15*A24*A36*A43*A51-A14*  &
         A25*A36*A43*A51-A16*A25*A33*A44*A51+A15*A26*A33*A44*A51+A16*A23*A35*A44*  &
         A51-A13*A26*A35*A44*A51-A15*A23*A36*A44*A51+A13*A25*A36*A44*A51+A16*A24*  &
         A33*A45*A51-A14*A26*A33*A45*A51-A16*A23*A34*A45*A51+A13*A26*A34*A45*      &
         A51+A14*A23*A36*A45*A51-A13*A24*A36*A45*A51-A15*A24*A33*A46*A51+A14*A25*  &
         A33*A46*A51+A15*A23*A34*A46*A51-A13*A25*A34*A46*A51-A14*A23*A35*A46*      &
         A51+A13*A24*A35*A46*A51-A16*A25*A34*A41*A53+A15*A26*A34*A41*A53+A16*A24*  &
         A35*A41*A53-A14*A26*A35*A41*A53-A15*A24*A36*A41*A53+A14*A25*A36*A41*      &
         A53+A16*A25*A31*A44*A53-A15*A26*A31*A44*A53-A16*A21*A35*A44*A53+A11*A26*  &
         A35*A44*A53+A15*A21*A36*A44*A53-A11*A25*A36*A44*A53-A16*A24*A31*A45*      &
         A53+A14*A26*A31*A45*A53+A16*A21*A34*A45*A53-A11*A26*A34*A45*A53-A14*A21*  &
         A36*A45*A53+A11*A24*A36*A45*A53+A15*A24*A31*A46*A53-A14*A25*A31*A46*      &
         A53-A15*A21*A34*A46*A53+A11*A25*A34*A46*A53+A14*A21*A35*A46*A53-A11*A24*  &
         A35*A46*A53+A16*A25*A33*A41*A54-A15*A26*A33*A41*A54-A16*A23*A35*A41*      &
         A54+A13*A26*A35*A41*A54+A15*A23*A36*A41*A54-A13*A25*A36*A41*A54-A16*A25*  &
         A31*A43*A54+A15*A26*A31*A43*A54+A16*A21*A35*A43*A54-A11*A26*A35*A43*      &
         A54-A15*A21*A36*A43*A54+A11*A25*A36*A43*A54+A16*A23*A31*A45*A54-A13*A26*  &
         A31*A45*A54-A16*A21*A33*A45*A54+A11*A26*A33*A45*A54+A13*A21*A36*A45*      &
         A54-A11*A23*A36*A45*A54-A15*A23*A31*A46*A54+A13*A25*A31*A46*A54+A15*A21*  &
         A33*A46*A54-A11*A25*A33*A46*A54-A13*A21*A35*A46*A54+A11*A23*A35*A46*      &
         A54-A16*A24*A33*A41*A55+A14*A26*A33*A41*A55+A16*A23*A34*A41*A55-A13*A26*  &
         A34*A41*A55-A14*A23*A36*A41*A55+A13*A24*A36*A41*A55+A16*A24*A31*A43*      &
         A55-A14*A26*A31*A43*A55-A16*A21*A34*A43*A55+A11*A26*A34*A43*A55+A14*A21*  &
         A36*A43*A55-A11*A24*A36*A43*A55-A16*A23*A31*A44*A55+A13*A26*A31*A44*      &
         A55+A16*A21*A33*A44*A55-A11*A26*A33*A44*A55-A13*A21*A36*A44*A55+A11*A23*  &
         A36*A44*A55+A14*A23*A31*A46*A55-A13*A24*A31*A46*A55-A14*A21*A33*A46*      &
         A55+A11*A24*A33*A46*A55+A13*A21*A34*A46*A55-A11*A23*A34*A46*A55+A15*A24*  &
         A33*A41*A56-A14*A25*A33*A41*A56-A15*A23*A34*A41*A56+A13*A25*A34*A41*      &
         A56+A14*A23*A35*A41*A56-A13*A24*A35*A41*A56-A15*A24*A31*A43*A56+A14*A25*  &
         A31*A43*A56+A15*A21*A34*A43*A56-A11*A25*A34*A43*A56-A14*A21*A35*A43*      &
         A56+A11*A24*A35*A43*A56+A15*A23*A31*A44*A56-A13*A25*A31*A44*A56-A15*A21*  &
         A33*A44*A56+A11*A25*A33*A44*A56+A13*A21*A35*A44*A56-A11*A23*A35*A44*      &
         A56-A14*A23*A31*A45*A56+A13*A24*A31*A45*A56+A14*A21*A33*A45*A56-A11*A24*  &
         A33*A45*A56-A13*A21*A34*A45*A56+A11*A23*A34*A45*A56)*A62-(A16*A25*A34*    &
         A42*A51-A15*A26*A34*A42*A51-A16*A24*A35*A42*A51+A14*A26*A35*A42*A51+A15*  &
         A24*A36*A42*A51-A14*A25*A36*A42*A51-A16*A25*A32*A44*A51+A15*A26*A32*A44*  &
         A51+A16*A22*A35*A44*A51-A12*A26*A35*A44*A51-A15*A22*A36*A44*A51+A12*A25*  &
         A36*A44*A51+A16*A24*A32*A45*A51-A14*A26*A32*A45*A51-A16*A22*A34*A45*      &
         A51+A12*A26*A34*A45*A51+A14*A22*A36*A45*A51-A12*A24*A36*A45*A51-A15*A24*  &
         A32*A46*A51+A14*A25*A32*A46*A51+A15*A22*A34*A46*A51-A12*A25*A34*A46*      &
         A51-A14*A22*A35*A46*A51+A12*A24*A35*A46*A51-A16*A25*A34*A41*A52+A15*A26*  &
         A34*A41*A52+A16*A24*A35*A41*A52-A14*A26*A35*A41*A52-A15*A24*A36*A41*      &
         A52+A14*A25*A36*A41*A52+A16*A25*A31*A44*A52-A15*A26*A31*A44*A52-A16*A21*  &
         A35*A44*A52+A11*A26*A35*A44*A52+A15*A21*A36*A44*A52-A11*A25*A36*A44*      &
         A52-A16*A24*A31*A45*A52+A14*A26*A31*A45*A52+A16*A21*A34*A45*A52-A11*A26*  &
         A34*A45*A52-A14*A21*A36*A45*A52+A11*A24*A36*A45*A52+A15*A24*A31*A46*      &
         A52-A14*A25*A31*A46*A52-A15*A21*A34*A46*A52+A11*A25*A34*A46*A52+A14*A21*  &
         A35*A46*A52-A11*A24*A35*A46*A52+A16*A25*A32*A41*A54-A15*A26*A32*A41*      &
         A54-A16*A22*A35*A41*A54+A12*A26*A35*A41*A54+A15*A22*A36*A41*A54-A12*A25*  &
         A36*A41*A54-A16*A25*A31*A42*A54+A15*A26*A31*A42*A54+A16*A21*A35*A42*      &
         A54-A11*A26*A35*A42*A54-A15*A21*A36*A42*A54+A11*A25*A36*A42*A54+A16*A22*  &
         A31*A45*A54-A12*A26*A31*A45*A54-A16*A21*A32*A45*A54+A11*A26*A32*A45*      &
         A54+A12*A21*A36*A45*A54-A11*A22*A36*A45*A54-A15*A22*A31*A46*A54+A12*A25*  &
         A31*A46*A54+A15*A21*A32*A46*A54-A11*A25*A32*A46*A54-A12*A21*A35*A46*      &
         A54+A11*A22*A35*A46*A54-A16*A24*A32*A41*A55+A14*A26*A32*A41*A55+A16*A22*  &
         A34*A41*A55-A12*A26*A34*A41*A55-A14*A22*A36*A41*A55+A12*A24*A36*A41*      &
         A55+A16*A24*A31*A42*A55-A14*A26*A31*A42*A55-A16*A21*A34*A42*A55+A11*A26*  &
         A34*A42*A55+A14*A21*A36*A42*A55-A11*A24*A36*A42*A55-A16*A22*A31*A44*      &
         A55+A12*A26*A31*A44*A55+A16*A21*A32*A44*A55-A11*A26*A32*A44*A55-A12*A21*  &
         A36*A44*A55+A11*A22*A36*A44*A55+A14*A22*A31*A46*A55-A12*A24*A31*A46*      &
         A55-A14*A21*A32*A46*A55+A11*A24*A32*A46*A55+A12*A21*A34*A46*A55-A11*A22*  &
         A34*A46*A55+A15*A24*A32*A41*A56-A14*A25*A32*A41*A56-A15*A22*A34*A41*      &
         A56+A12*A25*A34*A41*A56+A14*A22*A35*A41*A56-A12*A24*A35*A41*A56-A15*A24*  &
         A31*A42*A56+A14*A25*A31*A42*A56+A15*A21*A34*A42*A56-A11*A25*A34*A42*      &
         A56-A14*A21*A35*A42*A56+A11*A24*A35*A42*A56+A15*A22*A31*A44*A56-A12*A25*  &
         A31*A44*A56-A15*A21*A32*A44*A56+A11*A25*A32*A44*A56+A12*A21*A35*A44*      &
         A56-A11*A22*A35*A44*A56-A14*A22*A31*A45*A56+A12*A24*A31*A45*A56+A14*A21*  &
         A32*A45*A56-A11*A24*A32*A45*A56-A12*A21*A34*A45*A56+A11*A22*A34*A45*A56)* &
         A63+(A16*A25*A33*A42*A51-A15*A26*A33*A42*A51-A16*A23*A35*A42*A51+A13*A26* &
         A35*A42*A51+A15*A23*A36*A42*A51-A13*A25*A36*A42*A51-A16*A25*A32*A43*      &
         A51+A15*A26*A32*A43*A51+A16*A22*A35*A43*A51-A12*A26*A35*A43*A51-A15*A22*  &
         A36*A43*A51+A12*A25*A36*A43*A51+A16*A23*A32*A45*A51-A13*A26*A32*A45*      &
         A51-A16*A22*A33*A45*A51+A12*A26*A33*A45*A51+A13*A22*A36*A45*A51-A12*A23*  &
         A36*A45*A51-A15*A23*A32*A46*A51+A13*A25*A32*A46*A51+A15*A22*A33*A46*      &
         A51-A12*A25*A33*A46*A51-A13*A22*A35*A46*A51+A12*A23*A35*A46*A51-A16*A25*  &
         A33*A41*A52+A15*A26*A33*A41*A52+A16*A23*A35*A41*A52-A13*A26*A35*A41*      &
         A52-A15*A23*A36*A41*A52+A13*A25*A36*A41*A52+A16*A25*A31*A43*A52-A15*A26*  &
         A31*A43*A52-A16*A21*A35*A43*A52+A11*A26*A35*A43*A52+A15*A21*A36*A43*      &
         A52-A11*A25*A36*A43*A52-A16*A23*A31*A45*A52+A13*A26*A31*A45*A52+A16*A21*  &
         A33*A45*A52-A11*A26*A33*A45*A52-A13*A21*A36*A45*A52+A11*A23*A36*A45*      &
         A52+A15*A23*A31*A46*A52-A13*A25*A31*A46*A52-A15*A21*A33*A46*A52+A11*A25*  &
         A33*A46*A52+A13*A21*A35*A46*A52-A11*A23*A35*A46*A52+A16*A25*A32*A41*      &
         A53-A15*A26*A32*A41*A53-A16*A22*A35*A41*A53+A12*A26*A35*A41*A53+A15*A22*  &
         A36*A41*A53-A12*A25*A36*A41*A53-A16*A25*A31*A42*A53+A15*A26*A31*A42*      &
         A53+A16*A21*A35*A42*A53-A11*A26*A35*A42*A53-A15*A21*A36*A42*A53+A11*A25*  &
         A36*A42*A53+A16*A22*A31*A45*A53-A12*A26*A31*A45*A53-A16*A21*A32*A45*      &
         A53+A11*A26*A32*A45*A53+A12*A21*A36*A45*A53-A11*A22*A36*A45*A53-A15*A22*  &
         A31*A46*A53+A12*A25*A31*A46*A53+A15*A21*A32*A46*A53-A11*A25*A32*A46*      &
         A53-A12*A21*A35*A46*A53+A11*A22*A35*A46*A53-A16*A23*A32*A41*A55+A13*A26*  &
         A32*A41*A55+A16*A22*A33*A41*A55-A12*A26*A33*A41*A55-A13*A22*A36*A41*      &
         A55+A12*A23*A36*A41*A55+A16*A23*A31*A42*A55-A13*A26*A31*A42*A55-A16*A21*  &
         A33*A42*A55+A11*A26*A33*A42*A55+A13*A21*A36*A42*A55-A11*A23*A36*A42*      &
         A55-A16*A22*A31*A43*A55+A12*A26*A31*A43*A55+A16*A21*A32*A43*A55-A11*A26*  &
         A32*A43*A55-A12*A21*A36*A43*A55+A11*A22*A36*A43*A55+A13*A22*A31*A46*      &
         A55-A12*A23*A31*A46*A55-A13*A21*A32*A46*A55+A11*A23*A32*A46*A55+A12*A21*  &
         A33*A46*A55-A11*A22*A33*A46*A55+A15*A23*A32*A41*A56-A13*A25*A32*A41*      &
         A56-A15*A22*A33*A41*A56+A12*A25*A33*A41*A56+A13*A22*A35*A41*A56-A12*A23*  &
         A35*A41*A56-A15*A23*A31*A42*A56+A13*A25*A31*A42*A56+A15*A21*A33*A42*      &
         A56-A11*A25*A33*A42*A56-A13*A21*A35*A42*A56+A11*A23*A35*A42*A56+A15*A22*  &
         A31*A43*A56-A12*A25*A31*A43*A56-A15*A21*A32*A43*A56+A11*A25*A32*A43*      &
         A56+A12*A21*A35*A43*A56-A11*A22*A35*A43*A56-A13*A22*A31*A45*A56+A12*A23*  &
         A31*A45*A56+A13*A21*A32*A45*A56-A11*A23*A32*A45*A56-A12*A21*A33*A45*      &
         A56+A11*A22*A33*A45*A56)*A64-(A16*A24*A33*A42*A51-A14*A26*A33*A42*        &
         A51-A16*A23*A34*A42*A51+A13*A26*A34*A42*A51+A14*A23*A36*A42*A51-A13*A24*  &
         A36*A42*A51-A16*A24*A32*A43*A51+A14*A26*A32*A43*A51+A16*A22*A34*A43*      &
         A51-A12*A26*A34*A43*A51-A14*A22*A36*A43*A51+A12*A24*A36*A43*A51+A16*A23*  &
         A32*A44*A51-A13*A26*A32*A44*A51-A16*A22*A33*A44*A51+A12*A26*A33*A44*      &
         A51+A13*A22*A36*A44*A51-A12*A23*A36*A44*A51-A14*A23*A32*A46*A51+A13*A24*  &
         A32*A46*A51+A14*A22*A33*A46*A51-A12*A24*A33*A46*A51-A13*A22*A34*A46*      &
         A51+A12*A23*A34*A46*A51-A16*A24*A33*A41*A52+A14*A26*A33*A41*A52+A16*A23*  &
         A34*A41*A52-A13*A26*A34*A41*A52-A14*A23*A36*A41*A52+A13*A24*A36*A41*      &
         A52+A16*A24*A31*A43*A52-A14*A26*A31*A43*A52-A16*A21*A34*A43*A52+A11*A26*  &
         A34*A43*A52+A14*A21*A36*A43*A52-A11*A24*A36*A43*A52-A16*A23*A31*A44*      &
         A52+A13*A26*A31*A44*A52+A16*A21*A33*A44*A52-A11*A26*A33*A44*A52-A13*A21*  &
         A36*A44*A52+A11*A23*A36*A44*A52+A14*A23*A31*A46*A52-A13*A24*A31*A46*      &
         A52-A14*A21*A33*A46*A52+A11*A24*A33*A46*A52+A13*A21*A34*A46*A52-A11*A23*  &
         A34*A46*A52+A16*A24*A32*A41*A53-A14*A26*A32*A41*A53-A16*A22*A34*A41*      &
         A53+A12*A26*A34*A41*A53+A14*A22*A36*A41*A53-A12*A24*A36*A41*A53-A16*A24*  &
         A31*A42*A53+A14*A26*A31*A42*A53+A16*A21*A34*A42*A53-A11*A26*A34*A42*      &
         A53-A14*A21*A36*A42*A53+A11*A24*A36*A42*A53+A16*A22*A31*A44*A53-A12*A26*  &
         A31*A44*A53-A16*A21*A32*A44*A53+A11*A26*A32*A44*A53+A12*A21*A36*A44*      &
         A53-A11*A22*A36*A44*A53-A14*A22*A31*A46*A53+A12*A24*A31*A46*A53+A14*A21*  &
         A32*A46*A53-A11*A24*A32*A46*A53-A12*A21*A34*A46*A53+A11*A22*A34*A46*      &
         A53-A16*A23*A32*A41*A54+A13*A26*A32*A41*A54+A16*A22*A33*A41*A54-A12*A26*  &
         A33*A41*A54-A13*A22*A36*A41*A54+A12*A23*A36*A41*A54+A16*A23*A31*A42*      &
         A54-A13*A26*A31*A42*A54-A16*A21*A33*A42*A54+A11*A26*A33*A42*A54+A13*A21*  &
         A36*A42*A54-A11*A23*A36*A42*A54-A16*A22*A31*A43*A54+A12*A26*A31*A43*      &
         A54+A16*A21*A32*A43*A54-A11*A26*A32*A43*A54-A12*A21*A36*A43*A54+A11*A22*  &
         A36*A43*A54+A13*A22*A31*A46*A54-A12*A23*A31*A46*A54-A13*A21*A32*A46*      &
         A54+A11*A23*A32*A46*A54+A12*A21*A33*A46*A54-A11*A22*A33*A46*A54+A14*A23*  &
         A32*A41*A56-A13*A24*A32*A41*A56-A14*A22*A33*A41*A56+A12*A24*A33*A41*      &
         A56+A13*A22*A34*A41*A56-A12*A23*A34*A41*A56-A14*A23*A31*A42*A56+A13*A24*  &
         A31*A42*A56+A14*A21*A33*A42*A56-A11*A24*A33*A42*A56-A13*A21*A34*A42*      &
         A56+A11*A23*A34*A42*A56+A14*A22*A31*A43*A56-A12*A24*A31*A43*A56-A14*A21*  &
         A32*A43*A56+A11*A24*A32*A43*A56+A12*A21*A34*A43*A56-A11*A22*A34*A43*      &
         A56-A13*A22*A31*A44*A56+A12*A23*A31*A44*A56+A13*A21*A32*A44*A56-A11*A23*  &
         A32*A44*A56-A12*A21*A33*A44*A56+A11*A22*A33*A44*A56)*A65+(A15*A24*A33*    &
         A42*A51-A14*A25*A33*A42*A51-A15*A23*A34*A42*A51+A13*A25*A34*A42*A51+A14*  &
         A23*A35*A42*A51-A13*A24*A35*A42*A51-A15*A24*A32*A43*A51+A14*A25*A32*A43*  &
         A51+A15*A22*A34*A43*A51-A12*A25*A34*A43*A51-A14*A22*A35*A43*A51+A12*A24*  &
         A35*A43*A51+A15*A23*A32*A44*A51-A13*A25*A32*A44*A51-A15*A22*A33*A44*      &
         A51+A12*A25*A33*A44*A51+A13*A22*A35*A44*A51-A12*A23*A35*A44*A51-A14*A23*  &
         A32*A45*A51+A13*A24*A32*A45*A51+A14*A22*A33*A45*A51-A12*A24*A33*A45*      &
         A51-A13*A22*A34*A45*A51+A12*A23*A34*A45*A51-A15*A24*A33*A41*A52+A14*A25*  &
         A33*A41*A52+A15*A23*A34*A41*A52-A13*A25*A34*A41*A52-A14*A23*A35*A41*      &
         A52+A13*A24*A35*A41*A52+A15*A24*A31*A43*A52-A14*A25*A31*A43*A52-A15*A21*  &
         A34*A43*A52+A11*A25*A34*A43*A52+A14*A21*A35*A43*A52-A11*A24*A35*A43*      &
         A52-A15*A23*A31*A44*A52+A13*A25*A31*A44*A52+A15*A21*A33*A44*A52-A11*A25*  &
         A33*A44*A52-A13*A21*A35*A44*A52+A11*A23*A35*A44*A52+A14*A23*A31*A45*      &
         A52-A13*A24*A31*A45*A52-A14*A21*A33*A45*A52+A11*A24*A33*A45*A52+A13*A21*  &
         A34*A45*A52-A11*A23*A34*A45*A52+A15*A24*A32*A41*A53-A14*A25*A32*A41*      &
         A53-A15*A22*A34*A41*A53+A12*A25*A34*A41*A53+A14*A22*A35*A41*A53-A12*A24*  &
         A35*A41*A53-A15*A24*A31*A42*A53+A14*A25*A31*A42*A53+A15*A21*A34*A42*      &
         A53-A11*A25*A34*A42*A53-A14*A21*A35*A42*A53+A11*A24*A35*A42*A53+A15*A22*  &
         A31*A44*A53-A12*A25*A31*A44*A53-A15*A21*A32*A44*A53+A11*A25*A32*A44*      &
         A53+A12*A21*A35*A44*A53-A11*A22*A35*A44*A53-A14*A22*A31*A45*A53+A12*A24*  &
         A31*A45*A53+A14*A21*A32*A45*A53-A11*A24*A32*A45*A53-A12*A21*A34*A45*      &
         A53+A11*A22*A34*A45*A53-A15*A23*A32*A41*A54+A13*A25*A32*A41*A54+A15*A22*  &
         A33*A41*A54-A12*A25*A33*A41*A54-A13*A22*A35*A41*A54+A12*A23*A35*A41*      &
         A54+A15*A23*A31*A42*A54-A13*A25*A31*A42*A54-A15*A21*A33*A42*A54+A11*A25*  &
         A33*A42*A54+A13*A21*A35*A42*A54-A11*A23*A35*A42*A54-A15*A22*A31*A43*      &
         A54+A12*A25*A31*A43*A54+A15*A21*A32*A43*A54-A11*A25*A32*A43*A54-A12*A21*  &
         A35*A43*A54+A11*A22*A35*A43*A54+A13*A22*A31*A45*A54-A12*A23*A31*A45*      &
         A54-A13*A21*A32*A45*A54+A11*A23*A32*A45*A54+A12*A21*A33*A45*A54-A11*A22*  &
         A33*A45*A54+A14*A23*A32*A41*A55-A13*A24*A32*A41*A55-A14*A22*A33*A41*      &
         A55+A12*A24*A33*A41*A55+A13*A22*A34*A41*A55-A12*A23*A34*A41*A55-A14*A23*  &
         A31*A42*A55+A13*A24*A31*A42*A55+A14*A21*A33*A42*A55-A11*A24*A33*A42*      &
         A55-A13*A21*A34*A42*A55+A11*A23*A34*A42*A55+A14*A22*A31*A43*A55-A12*A24*  &
         A31*A43*A55-A14*A21*A32*A43*A55+A11*A24*A32*A43*A55+A12*A21*A34*A43*      &
         A55-A11*A22*A34*A43*A55-A13*A22*A31*A44*A55+A12*A23*A31*A44*A55+A13*A21*  &
         A32*A44*A55-A11*A23*A32*A44*A55-A12*A21*A33*A44*A55+A11*A22*A33*A44*A55)* &
         A66

      IF (ABS(DET) .LE. EPS) THEN
         AINV = 0.0D0
         OK_FLAG = .FALSE.
         RETURN
      END IF

      COFACTOR(1,1) = A26*A35*A44*A53*A62-A25*A36*A44*A53*A62-A26*A34*A45*A53*A62+A24*A36*     &
      A45*A53*A62+A25*A34*A46*A53*A62-A24*A35*A46*A53*A62-A26*A35*A43*A54*                     &
      A62+A25*A36*A43*A54*A62+A26*A33*A45*A54*A62-A23*A36*A45*A54*A62-A25*A33*                 &
      A46*A54*A62+A23*A35*A46*A54*A62+A26*A34*A43*A55*A62-A24*A36*A43*A55*                     &
      A62-A26*A33*A44*A55*A62+A23*A36*A44*A55*A62+A24*A33*A46*A55*A62-A23*A34*                 &
      A46*A55*A62-A25*A34*A43*A56*A62+A24*A35*A43*A56*A62+A25*A33*A44*A56*                     &
      A62-A23*A35*A44*A56*A62-A24*A33*A45*A56*A62+A23*A34*A45*A56*A62-A26*A35*                 &
      A44*A52*A63+A25*A36*A44*A52*A63+A26*A34*A45*A52*A63-A24*A36*A45*A52*                     &
      A63-A25*A34*A46*A52*A63+A24*A35*A46*A52*A63+A26*A35*A42*A54*A63-A25*A36*                 &
      A42*A54*A63-A26*A32*A45*A54*A63+A22*A36*A45*A54*A63+A25*A32*A46*A54*                     &
      A63-A22*A35*A46*A54*A63-A26*A34*A42*A55*A63+A24*A36*A42*A55*A63+A26*A32*                 &
      A44*A55*A63-A22*A36*A44*A55*A63-A24*A32*A46*A55*A63+A22*A34*A46*A55*                     &
      A63+A25*A34*A42*A56*A63-A24*A35*A42*A56*A63-A25*A32*A44*A56*A63+A22*A35*                 &
      A44*A56*A63+A24*A32*A45*A56*A63-A22*A34*A45*A56*A63+A26*A35*A43*A52*                     &
      A64-A25*A36*A43*A52*A64-A26*A33*A45*A52*A64+A23*A36*A45*A52*A64+A25*A33*                 &
      A46*A52*A64-A23*A35*A46*A52*A64-A26*A35*A42*A53*A64+A25*A36*A42*A53*                     &
      A64+A26*A32*A45*A53*A64-A22*A36*A45*A53*A64-A25*A32*A46*A53*A64+A22*A35*                 &
      A46*A53*A64+A26*A33*A42*A55*A64-A23*A36*A42*A55*A64-A26*A32*A43*A55*                     &
      A64+A22*A36*A43*A55*A64+A23*A32*A46*A55*A64-A22*A33*A46*A55*A64-A25*A33*                 &
      A42*A56*A64+A23*A35*A42*A56*A64+A25*A32*A43*A56*A64-A22*A35*A43*A56*                     &
      A64-A23*A32*A45*A56*A64+A22*A33*A45*A56*A64-A26*A34*A43*A52*A65+A24*A36*                 &
      A43*A52*A65+A26*A33*A44*A52*A65-A23*A36*A44*A52*A65-A24*A33*A46*A52*                     &
      A65+A23*A34*A46*A52*A65+A26*A34*A42*A53*A65-A24*A36*A42*A53*A65-A26*A32*                 &
      A44*A53*A65+A22*A36*A44*A53*A65+A24*A32*A46*A53*A65-A22*A34*A46*A53*                     &
      A65-A26*A33*A42*A54*A65+A23*A36*A42*A54*A65+A26*A32*A43*A54*A65-A22*A36*                 &
      A43*A54*A65-A23*A32*A46*A54*A65+A22*A33*A46*A54*A65+A24*A33*A42*A56*                     &
      A65-A23*A34*A42*A56*A65-A24*A32*A43*A56*A65+A22*A34*A43*A56*A65+A23*A32*                 &
      A44*A56*A65-A22*A33*A44*A56*A65+A25*A34*A43*A52*A66-A24*A35*A43*A52*                     &
      A66-A25*A33*A44*A52*A66+A23*A35*A44*A52*A66+A24*A33*A45*A52*A66-A23*A34*                 &
      A45*A52*A66-A25*A34*A42*A53*A66+A24*A35*A42*A53*A66+A25*A32*A44*A53*                     &
      A66-A22*A35*A44*A53*A66-A24*A32*A45*A53*A66+A22*A34*A45*A53*A66+A25*A33*                 &
      A42*A54*A66-A23*A35*A42*A54*A66-A25*A32*A43*A54*A66+A22*A35*A43*A54*                     &
      A66+A23*A32*A45*A54*A66-A22*A33*A45*A54*A66-A24*A33*A42*A55*A66+A23*A34*                 &
      A42*A55*A66+A24*A32*A43*A55*A66-A22*A34*A43*A55*A66-A23*A32*A44*A55*                     &
      A66+A22*A33*A44*A55*A66

      COFACTOR(2,1) = -A16*A35*A44*A53*A62+A15*A36*A44*A53*A62+A16*A34*                        &
      A45*A53*A62-A14*A36*A45*A53*A62-A15*A34*A46*A53*A62+A14*A35*A46*A53*                     &
      A62+A16*A35*A43*A54*A62-A15*A36*A43*A54*A62-A16*A33*A45*A54*A62+A13*A36*                 &
      A45*A54*A62+A15*A33*A46*A54*A62-A13*A35*A46*A54*A62-A16*A34*A43*A55*                     &
      A62+A14*A36*A43*A55*A62+A16*A33*A44*A55*A62-A13*A36*A44*A55*A62-A14*A33*                 &
      A46*A55*A62+A13*A34*A46*A55*A62+A15*A34*A43*A56*A62-A14*A35*A43*A56*                     &
      A62-A15*A33*A44*A56*A62+A13*A35*A44*A56*A62+A14*A33*A45*A56*A62-A13*A34*                 &
      A45*A56*A62+A16*A35*A44*A52*A63-A15*A36*A44*A52*A63-A16*A34*A45*A52*                     &
      A63+A14*A36*A45*A52*A63+A15*A34*A46*A52*A63-A14*A35*A46*A52*A63-A16*A35*                 &
      A42*A54*A63+A15*A36*A42*A54*A63+A16*A32*A45*A54*A63-A12*A36*A45*A54*                     &
      A63-A15*A32*A46*A54*A63+A12*A35*A46*A54*A63+A16*A34*A42*A55*A63-A14*A36*                 &
      A42*A55*A63-A16*A32*A44*A55*A63+A12*A36*A44*A55*A63+A14*A32*A46*A55*                     &
      A63-A12*A34*A46*A55*A63-A15*A34*A42*A56*A63+A14*A35*A42*A56*A63+A15*A32*                 &
      A44*A56*A63-A12*A35*A44*A56*A63-A14*A32*A45*A56*A63+A12*A34*A45*A56*                     &
      A63-A16*A35*A43*A52*A64+A15*A36*A43*A52*A64+A16*A33*A45*A52*A64-A13*A36*                 &
      A45*A52*A64-A15*A33*A46*A52*A64+A13*A35*A46*A52*A64+A16*A35*A42*A53*                     &
      A64-A15*A36*A42*A53*A64-A16*A32*A45*A53*A64+A12*A36*A45*A53*A64+A15*A32*                 &
      A46*A53*A64-A12*A35*A46*A53*A64-A16*A33*A42*A55*A64+A13*A36*A42*A55*                     &
      A64+A16*A32*A43*A55*A64-A12*A36*A43*A55*A64-A13*A32*A46*A55*A64+A12*A33*                 &
      A46*A55*A64+A15*A33*A42*A56*A64-A13*A35*A42*A56*A64-A15*A32*A43*A56*                     &
      A64+A12*A35*A43*A56*A64+A13*A32*A45*A56*A64-A12*A33*A45*A56*A64+A16*A34*                 &
      A43*A52*A65-A14*A36*A43*A52*A65-A16*A33*A44*A52*A65+A13*A36*A44*A52*                     &
      A65+A14*A33*A46*A52*A65-A13*A34*A46*A52*A65-A16*A34*A42*A53*A65+A14*A36*                 &
      A42*A53*A65+A16*A32*A44*A53*A65-A12*A36*A44*A53*A65-A14*A32*A46*A53*                     &
      A65+A12*A34*A46*A53*A65+A16*A33*A42*A54*A65-A13*A36*A42*A54*A65-A16*A32*                 &
      A43*A54*A65+A12*A36*A43*A54*A65+A13*A32*A46*A54*A65-A12*A33*A46*A54*                     &
      A65-A14*A33*A42*A56*A65+A13*A34*A42*A56*A65+A14*A32*A43*A56*A65-A12*A34*                 &
      A43*A56*A65-A13*A32*A44*A56*A65+A12*A33*A44*A56*A65-A15*A34*A43*A52*                     &
      A66+A14*A35*A43*A52*A66+A15*A33*A44*A52*A66-A13*A35*A44*A52*A66-A14*A33*                 &
      A45*A52*A66+A13*A34*A45*A52*A66+A15*A34*A42*A53*A66-A14*A35*A42*A53*                     &
      A66-A15*A32*A44*A53*A66+A12*A35*A44*A53*A66+A14*A32*A45*A53*A66-A12*A34*                 &
      A45*A53*A66-A15*A33*A42*A54*A66+A13*A35*A42*A54*A66+A15*A32*A43*A54*                     &
      A66-A12*A35*A43*A54*A66-A13*A32*A45*A54*A66+A12*A33*A45*A54*A66+A14*A33*                 &
      A42*A55*A66-A13*A34*A42*A55*A66-A14*A32*A43*A55*A66+A12*A34*A43*A55*                     &
      A66+A13*A32*A44*A55*A66-A12*A33*A44*A55*A66

      COFACTOR(3,1) = A16*A25*A44*A53*A62-A15*A26*                                             &
      A44*A53*A62-A16*A24*A45*A53*A62+A14*A26*A45*A53*A62+A15*A24*A46*A53*                     &
      A62-A14*A25*A46*A53*A62-A16*A25*A43*A54*A62+A15*A26*A43*A54*A62+A16*A23*                 &
      A45*A54*A62-A13*A26*A45*A54*A62-A15*A23*A46*A54*A62+A13*A25*A46*A54*                     &
      A62+A16*A24*A43*A55*A62-A14*A26*A43*A55*A62-A16*A23*A44*A55*A62+A13*A26*                 &
      A44*A55*A62+A14*A23*A46*A55*A62-A13*A24*A46*A55*A62-A15*A24*A43*A56*                     &
      A62+A14*A25*A43*A56*A62+A15*A23*A44*A56*A62-A13*A25*A44*A56*A62-A14*A23*                 &
      A45*A56*A62+A13*A24*A45*A56*A62-A16*A25*A44*A52*A63+A15*A26*A44*A52*                     &
      A63+A16*A24*A45*A52*A63-A14*A26*A45*A52*A63-A15*A24*A46*A52*A63+A14*A25*                 &
      A46*A52*A63+A16*A25*A42*A54*A63-A15*A26*A42*A54*A63-A16*A22*A45*A54*                     &
      A63+A12*A26*A45*A54*A63+A15*A22*A46*A54*A63-A12*A25*A46*A54*A63-A16*A24*                 &
      A42*A55*A63+A14*A26*A42*A55*A63+A16*A22*A44*A55*A63-A12*A26*A44*A55*                     &
      A63-A14*A22*A46*A55*A63+A12*A24*A46*A55*A63+A15*A24*A42*A56*A63-A14*A25*                 &
      A42*A56*A63-A15*A22*A44*A56*A63+A12*A25*A44*A56*A63+A14*A22*A45*A56*                     &
      A63-A12*A24*A45*A56*A63+A16*A25*A43*A52*A64-A15*A26*A43*A52*A64-A16*A23*                 &
      A45*A52*A64+A13*A26*A45*A52*A64+A15*A23*A46*A52*A64-A13*A25*A46*A52*                     &
      A64-A16*A25*A42*A53*A64+A15*A26*A42*A53*A64+A16*A22*A45*A53*A64-A12*A26*                 &
      A45*A53*A64-A15*A22*A46*A53*A64+A12*A25*A46*A53*A64+A16*A23*A42*A55*                     &
      A64-A13*A26*A42*A55*A64-A16*A22*A43*A55*A64+A12*A26*A43*A55*A64+A13*A22*                 &
      A46*A55*A64-A12*A23*A46*A55*A64-A15*A23*A42*A56*A64+A13*A25*A42*A56*                     &
      A64+A15*A22*A43*A56*A64-A12*A25*A43*A56*A64-A13*A22*A45*A56*A64+A12*A23*                 &
      A45*A56*A64-A16*A24*A43*A52*A65+A14*A26*A43*A52*A65+A16*A23*A44*A52*                     &
      A65-A13*A26*A44*A52*A65-A14*A23*A46*A52*A65+A13*A24*A46*A52*A65+A16*A24*                 &
      A42*A53*A65-A14*A26*A42*A53*A65-A16*A22*A44*A53*A65+A12*A26*A44*A53*                     &
      A65+A14*A22*A46*A53*A65-A12*A24*A46*A53*A65-A16*A23*A42*A54*A65+A13*A26*                 &
      A42*A54*A65+A16*A22*A43*A54*A65-A12*A26*A43*A54*A65-A13*A22*A46*A54*                     &
      A65+A12*A23*A46*A54*A65+A14*A23*A42*A56*A65-A13*A24*A42*A56*A65-A14*A22*                 &
      A43*A56*A65+A12*A24*A43*A56*A65+A13*A22*A44*A56*A65-A12*A23*A44*A56*                     &
      A65+A15*A24*A43*A52*A66-A14*A25*A43*A52*A66-A15*A23*A44*A52*A66+A13*A25*                 &
      A44*A52*A66+A14*A23*A45*A52*A66-A13*A24*A45*A52*A66-A15*A24*A42*A53*                     &
      A66+A14*A25*A42*A53*A66+A15*A22*A44*A53*A66-A12*A25*A44*A53*A66-A14*A22*                 &
      A45*A53*A66+A12*A24*A45*A53*A66+A15*A23*A42*A54*A66-A13*A25*A42*A54*                     &
      A66-A15*A22*A43*A54*A66+A12*A25*A43*A54*A66+A13*A22*A45*A54*A66-A12*A23*                 &
      A45*A54*A66-A14*A23*A42*A55*A66+A13*A24*A42*A55*A66+A14*A22*A43*A55*                     &
      A66-A12*A24*A43*A55*A66-A13*A22*A44*A55*A66+A12*A23*A44*A55*A66

      COFACTOR(4,1) = -A16*A25*                                                                &
      A34*A53*A62+A15*A26*A34*A53*A62+A16*A24*A35*A53*A62-A14*A26*A35*A53*                     &
      A62-A15*A24*A36*A53*A62+A14*A25*A36*A53*A62+A16*A25*A33*A54*A62-A15*A26*                 &
      A33*A54*A62-A16*A23*A35*A54*A62+A13*A26*A35*A54*A62+A15*A23*A36*A54*                     &
      A62-A13*A25*A36*A54*A62-A16*A24*A33*A55*A62+A14*A26*A33*A55*A62+A16*A23*                 &
      A34*A55*A62-A13*A26*A34*A55*A62-A14*A23*A36*A55*A62+A13*A24*A36*A55*                     &
      A62+A15*A24*A33*A56*A62-A14*A25*A33*A56*A62-A15*A23*A34*A56*A62+A13*A25*                 &
      A34*A56*A62+A14*A23*A35*A56*A62-A13*A24*A35*A56*A62+A16*A25*A34*A52*                     &
      A63-A15*A26*A34*A52*A63-A16*A24*A35*A52*A63+A14*A26*A35*A52*A63+A15*A24*                 &
      A36*A52*A63-A14*A25*A36*A52*A63-A16*A25*A32*A54*A63+A15*A26*A32*A54*                     &
      A63+A16*A22*A35*A54*A63-A12*A26*A35*A54*A63-A15*A22*A36*A54*A63+A12*A25*                 &
      A36*A54*A63+A16*A24*A32*A55*A63-A14*A26*A32*A55*A63-A16*A22*A34*A55*                     &
      A63+A12*A26*A34*A55*A63+A14*A22*A36*A55*A63-A12*A24*A36*A55*A63-A15*A24*                 &
      A32*A56*A63+A14*A25*A32*A56*A63+A15*A22*A34*A56*A63-A12*A25*A34*A56*                     &
      A63-A14*A22*A35*A56*A63+A12*A24*A35*A56*A63-A16*A25*A33*A52*A64+A15*A26*                 &
      A33*A52*A64+A16*A23*A35*A52*A64-A13*A26*A35*A52*A64-A15*A23*A36*A52*                     &
      A64+A13*A25*A36*A52*A64+A16*A25*A32*A53*A64-A15*A26*A32*A53*A64-A16*A22*                 &
      A35*A53*A64+A12*A26*A35*A53*A64+A15*A22*A36*A53*A64-A12*A25*A36*A53*                     &
      A64-A16*A23*A32*A55*A64+A13*A26*A32*A55*A64+A16*A22*A33*A55*A64-A12*A26*                 &
      A33*A55*A64-A13*A22*A36*A55*A64+A12*A23*A36*A55*A64+A15*A23*A32*A56*                     &
      A64-A13*A25*A32*A56*A64-A15*A22*A33*A56*A64+A12*A25*A33*A56*A64+A13*A22*                 &
      A35*A56*A64-A12*A23*A35*A56*A64+A16*A24*A33*A52*A65-A14*A26*A33*A52*                     &
      A65-A16*A23*A34*A52*A65+A13*A26*A34*A52*A65+A14*A23*A36*A52*A65-A13*A24*                 &
      A36*A52*A65-A16*A24*A32*A53*A65+A14*A26*A32*A53*A65+A16*A22*A34*A53*                     &
      A65-A12*A26*A34*A53*A65-A14*A22*A36*A53*A65+A12*A24*A36*A53*A65+A16*A23*                 &
      A32*A54*A65-A13*A26*A32*A54*A65-A16*A22*A33*A54*A65+A12*A26*A33*A54*                     &
      A65+A13*A22*A36*A54*A65-A12*A23*A36*A54*A65-A14*A23*A32*A56*A65+A13*A24*                 &
      A32*A56*A65+A14*A22*A33*A56*A65-A12*A24*A33*A56*A65-A13*A22*A34*A56*                     &
      A65+A12*A23*A34*A56*A65-A15*A24*A33*A52*A66+A14*A25*A33*A52*A66+A15*A23*                 &
      A34*A52*A66-A13*A25*A34*A52*A66-A14*A23*A35*A52*A66+A13*A24*A35*A52*                     &
      A66+A15*A24*A32*A53*A66-A14*A25*A32*A53*A66-A15*A22*A34*A53*A66+A12*A25*                 &
      A34*A53*A66+A14*A22*A35*A53*A66-A12*A24*A35*A53*A66-A15*A23*A32*A54*                     &
      A66+A13*A25*A32*A54*A66+A15*A22*A33*A54*A66-A12*A25*A33*A54*A66-A13*A22*                 &
      A35*A54*A66+A12*A23*A35*A54*A66+A14*A23*A32*A55*A66-A13*A24*A32*A55*                     &
      A66-A14*A22*A33*A55*A66+A12*A24*A33*A55*A66+A13*A22*A34*A55*A66-A12*A23*                 &
      A34*A55*A66

      COFACTOR(5,1) = A16*A25*A34*A43*A62-A15*A26*A34*A43*A62-A16*A24*A35*A43*                 &
      A62+A14*A26*A35*A43*A62+A15*A24*A36*A43*A62-A14*A25*A36*A43*A62-A16*A25*                 &
      A33*A44*A62+A15*A26*A33*A44*A62+A16*A23*A35*A44*A62-A13*A26*A35*A44*                     &
      A62-A15*A23*A36*A44*A62+A13*A25*A36*A44*A62+A16*A24*A33*A45*A62-A14*A26*                 &
      A33*A45*A62-A16*A23*A34*A45*A62+A13*A26*A34*A45*A62+A14*A23*A36*A45*                     &
      A62-A13*A24*A36*A45*A62-A15*A24*A33*A46*A62+A14*A25*A33*A46*A62+A15*A23*                 &
      A34*A46*A62-A13*A25*A34*A46*A62-A14*A23*A35*A46*A62+A13*A24*A35*A46*                     &
      A62-A16*A25*A34*A42*A63+A15*A26*A34*A42*A63+A16*A24*A35*A42*A63-A14*A26*                 &
      A35*A42*A63-A15*A24*A36*A42*A63+A14*A25*A36*A42*A63+A16*A25*A32*A44*                     &
      A63-A15*A26*A32*A44*A63-A16*A22*A35*A44*A63+A12*A26*A35*A44*A63+A15*A22*                 &
      A36*A44*A63-A12*A25*A36*A44*A63-A16*A24*A32*A45*A63+A14*A26*A32*A45*                     &
      A63+A16*A22*A34*A45*A63-A12*A26*A34*A45*A63-A14*A22*A36*A45*A63+A12*A24*                 &
      A36*A45*A63+A15*A24*A32*A46*A63-A14*A25*A32*A46*A63-A15*A22*A34*A46*                     &
      A63+A12*A25*A34*A46*A63+A14*A22*A35*A46*A63-A12*A24*A35*A46*A63+A16*A25*                 &
      A33*A42*A64-A15*A26*A33*A42*A64-A16*A23*A35*A42*A64+A13*A26*A35*A42*                     &
      A64+A15*A23*A36*A42*A64-A13*A25*A36*A42*A64-A16*A25*A32*A43*A64+A15*A26*                 &
      A32*A43*A64+A16*A22*A35*A43*A64-A12*A26*A35*A43*A64-A15*A22*A36*A43*                     &
      A64+A12*A25*A36*A43*A64+A16*A23*A32*A45*A64-A13*A26*A32*A45*A64-A16*A22*                 &
      A33*A45*A64+A12*A26*A33*A45*A64+A13*A22*A36*A45*A64-A12*A23*A36*A45*                     &
      A64-A15*A23*A32*A46*A64+A13*A25*A32*A46*A64+A15*A22*A33*A46*A64-A12*A25*                 &
      A33*A46*A64-A13*A22*A35*A46*A64+A12*A23*A35*A46*A64-A16*A24*A33*A42*                     &
      A65+A14*A26*A33*A42*A65+A16*A23*A34*A42*A65-A13*A26*A34*A42*A65-A14*A23*                 &
      A36*A42*A65+A13*A24*A36*A42*A65+A16*A24*A32*A43*A65-A14*A26*A32*A43*                     &
      A65-A16*A22*A34*A43*A65+A12*A26*A34*A43*A65+A14*A22*A36*A43*A65-A12*A24*                 &
      A36*A43*A65-A16*A23*A32*A44*A65+A13*A26*A32*A44*A65+A16*A22*A33*A44*                     &
      A65-A12*A26*A33*A44*A65-A13*A22*A36*A44*A65+A12*A23*A36*A44*A65+A14*A23*                 &
      A32*A46*A65-A13*A24*A32*A46*A65-A14*A22*A33*A46*A65+A12*A24*A33*A46*                     &
      A65+A13*A22*A34*A46*A65-A12*A23*A34*A46*A65+A15*A24*A33*A42*A66-A14*A25*                 &
      A33*A42*A66-A15*A23*A34*A42*A66+A13*A25*A34*A42*A66+A14*A23*A35*A42*                     &
      A66-A13*A24*A35*A42*A66-A15*A24*A32*A43*A66+A14*A25*A32*A43*A66+A15*A22*                 &
      A34*A43*A66-A12*A25*A34*A43*A66-A14*A22*A35*A43*A66+A12*A24*A35*A43*                     &
      A66+A15*A23*A32*A44*A66-A13*A25*A32*A44*A66-A15*A22*A33*A44*A66+A12*A25*                 &
      A33*A44*A66+A13*A22*A35*A44*A66-A12*A23*A35*A44*A66-A14*A23*A32*A45*                     &
      A66+A13*A24*A32*A45*A66+A14*A22*A33*A45*A66-A12*A24*A33*A45*A66-A13*A22*                 &
      A34*A45*A66+A12*A23*A34*A45*A66

      COFACTOR(6,1) = -A16*A25*A34*A43*A52+A15*A26*A34*A43*                                    &
      A52+A16*A24*A35*A43*A52-A14*A26*A35*A43*A52-A15*A24*A36*A43*A52+A14*A25*                 &
      A36*A43*A52+A16*A25*A33*A44*A52-A15*A26*A33*A44*A52-A16*A23*A35*A44*                     &
      A52+A13*A26*A35*A44*A52+A15*A23*A36*A44*A52-A13*A25*A36*A44*A52-A16*A24*                 &
      A33*A45*A52+A14*A26*A33*A45*A52+A16*A23*A34*A45*A52-A13*A26*A34*A45*                     &
      A52-A14*A23*A36*A45*A52+A13*A24*A36*A45*A52+A15*A24*A33*A46*A52-A14*A25*                 &
      A33*A46*A52-A15*A23*A34*A46*A52+A13*A25*A34*A46*A52+A14*A23*A35*A46*                     &
      A52-A13*A24*A35*A46*A52+A16*A25*A34*A42*A53-A15*A26*A34*A42*A53-A16*A24*                 &
      A35*A42*A53+A14*A26*A35*A42*A53+A15*A24*A36*A42*A53-A14*A25*A36*A42*                     &
      A53-A16*A25*A32*A44*A53+A15*A26*A32*A44*A53+A16*A22*A35*A44*A53-A12*A26*                 &
      A35*A44*A53-A15*A22*A36*A44*A53+A12*A25*A36*A44*A53+A16*A24*A32*A45*                     &
      A53-A14*A26*A32*A45*A53-A16*A22*A34*A45*A53+A12*A26*A34*A45*A53+A14*A22*                 &
      A36*A45*A53-A12*A24*A36*A45*A53-A15*A24*A32*A46*A53+A14*A25*A32*A46*                     &
      A53+A15*A22*A34*A46*A53-A12*A25*A34*A46*A53-A14*A22*A35*A46*A53+A12*A24*                 &
      A35*A46*A53-A16*A25*A33*A42*A54+A15*A26*A33*A42*A54+A16*A23*A35*A42*                     &
      A54-A13*A26*A35*A42*A54-A15*A23*A36*A42*A54+A13*A25*A36*A42*A54+A16*A25*                 &
      A32*A43*A54-A15*A26*A32*A43*A54-A16*A22*A35*A43*A54+A12*A26*A35*A43*                     &
      A54+A15*A22*A36*A43*A54-A12*A25*A36*A43*A54-A16*A23*A32*A45*A54+A13*A26*                 &
      A32*A45*A54+A16*A22*A33*A45*A54-A12*A26*A33*A45*A54-A13*A22*A36*A45*                     &
      A54+A12*A23*A36*A45*A54+A15*A23*A32*A46*A54-A13*A25*A32*A46*A54-A15*A22*                 &
      A33*A46*A54+A12*A25*A33*A46*A54+A13*A22*A35*A46*A54-A12*A23*A35*A46*                     &
      A54+A16*A24*A33*A42*A55-A14*A26*A33*A42*A55-A16*A23*A34*A42*A55+A13*A26*                 &
      A34*A42*A55+A14*A23*A36*A42*A55-A13*A24*A36*A42*A55-A16*A24*A32*A43*                     &
      A55+A14*A26*A32*A43*A55+A16*A22*A34*A43*A55-A12*A26*A34*A43*A55-A14*A22*                 &
      A36*A43*A55+A12*A24*A36*A43*A55+A16*A23*A32*A44*A55-A13*A26*A32*A44*                     &
      A55-A16*A22*A33*A44*A55+A12*A26*A33*A44*A55+A13*A22*A36*A44*A55-A12*A23*                 &
      A36*A44*A55-A14*A23*A32*A46*A55+A13*A24*A32*A46*A55+A14*A22*A33*A46*                     &
      A55-A12*A24*A33*A46*A55-A13*A22*A34*A46*A55+A12*A23*A34*A46*A55-A15*A24*                 &
      A33*A42*A56+A14*A25*A33*A42*A56+A15*A23*A34*A42*A56-A13*A25*A34*A42*                     &
      A56-A14*A23*A35*A42*A56+A13*A24*A35*A42*A56+A15*A24*A32*A43*A56-A14*A25*                 &
      A32*A43*A56-A15*A22*A34*A43*A56+A12*A25*A34*A43*A56+A14*A22*A35*A43*                     &
      A56-A12*A24*A35*A43*A56-A15*A23*A32*A44*A56+A13*A25*A32*A44*A56+A15*A22*                 &
      A33*A44*A56-A12*A25*A33*A44*A56-A13*A22*A35*A44*A56+A12*A23*A35*A44*                     &
      A56+A14*A23*A32*A45*A56-A13*A24*A32*A45*A56-A14*A22*A33*A45*A56+A12*A24*                 &
      A33*A45*A56+A13*A22*A34*A45*A56-A12*A23*A34*A45*A56

      COFACTOR(1,2) = -A26*A35*A44*A53*                                                        &
      A61+A25*A36*A44*A53*A61+A26*A34*A45*A53*A61-A24*A36*A45*A53*A61-A25*A34*                 &
      A46*A53*A61+A24*A35*A46*A53*A61+A26*A35*A43*A54*A61-A25*A36*A43*A54*                     &
      A61-A26*A33*A45*A54*A61+A23*A36*A45*A54*A61+A25*A33*A46*A54*A61-A23*A35*                 &
      A46*A54*A61-A26*A34*A43*A55*A61+A24*A36*A43*A55*A61+A26*A33*A44*A55*                     &
      A61-A23*A36*A44*A55*A61-A24*A33*A46*A55*A61+A23*A34*A46*A55*A61+A25*A34*                 &
      A43*A56*A61-A24*A35*A43*A56*A61-A25*A33*A44*A56*A61+A23*A35*A44*A56*                     &
      A61+A24*A33*A45*A56*A61-A23*A34*A45*A56*A61+A26*A35*A44*A51*A63-A25*A36*                 &
      A44*A51*A63-A26*A34*A45*A51*A63+A24*A36*A45*A51*A63+A25*A34*A46*A51*                     &
      A63-A24*A35*A46*A51*A63-A26*A35*A41*A54*A63+A25*A36*A41*A54*A63+A26*A31*                 &
      A45*A54*A63-A21*A36*A45*A54*A63-A25*A31*A46*A54*A63+A21*A35*A46*A54*                     &
      A63+A26*A34*A41*A55*A63-A24*A36*A41*A55*A63-A26*A31*A44*A55*A63+A21*A36*                 &
      A44*A55*A63+A24*A31*A46*A55*A63-A21*A34*A46*A55*A63-A25*A34*A41*A56*                     &
      A63+A24*A35*A41*A56*A63+A25*A31*A44*A56*A63-A21*A35*A44*A56*A63-A24*A31*                 &
      A45*A56*A63+A21*A34*A45*A56*A63-A26*A35*A43*A51*A64+A25*A36*A43*A51*                     &
      A64+A26*A33*A45*A51*A64-A23*A36*A45*A51*A64-A25*A33*A46*A51*A64+A23*A35*                 &
      A46*A51*A64+A26*A35*A41*A53*A64-A25*A36*A41*A53*A64-A26*A31*A45*A53*                     &
      A64+A21*A36*A45*A53*A64+A25*A31*A46*A53*A64-A21*A35*A46*A53*A64-A26*A33*                 &
      A41*A55*A64+A23*A36*A41*A55*A64+A26*A31*A43*A55*A64-A21*A36*A43*A55*                     &
      A64-A23*A31*A46*A55*A64+A21*A33*A46*A55*A64+A25*A33*A41*A56*A64-A23*A35*                 &
      A41*A56*A64-A25*A31*A43*A56*A64+A21*A35*A43*A56*A64+A23*A31*A45*A56*                     &
      A64-A21*A33*A45*A56*A64+A26*A34*A43*A51*A65-A24*A36*A43*A51*A65-A26*A33*                 &
      A44*A51*A65+A23*A36*A44*A51*A65+A24*A33*A46*A51*A65-A23*A34*A46*A51*                     &
      A65-A26*A34*A41*A53*A65+A24*A36*A41*A53*A65+A26*A31*A44*A53*A65-A21*A36*                 &
      A44*A53*A65-A24*A31*A46*A53*A65+A21*A34*A46*A53*A65+A26*A33*A41*A54*                     &
      A65-A23*A36*A41*A54*A65-A26*A31*A43*A54*A65+A21*A36*A43*A54*A65+A23*A31*                 &
      A46*A54*A65-A21*A33*A46*A54*A65-A24*A33*A41*A56*A65+A23*A34*A41*A56*                     &
      A65+A24*A31*A43*A56*A65-A21*A34*A43*A56*A65-A23*A31*A44*A56*A65+A21*A33*                 &
      A44*A56*A65-A25*A34*A43*A51*A66+A24*A35*A43*A51*A66+A25*A33*A44*A51*                     &
      A66-A23*A35*A44*A51*A66-A24*A33*A45*A51*A66+A23*A34*A45*A51*A66+A25*A34*                 &
      A41*A53*A66-A24*A35*A41*A53*A66-A25*A31*A44*A53*A66+A21*A35*A44*A53*                     &
      A66+A24*A31*A45*A53*A66-A21*A34*A45*A53*A66-A25*A33*A41*A54*A66+A23*A35*                 &
      A41*A54*A66+A25*A31*A43*A54*A66-A21*A35*A43*A54*A66-A23*A31*A45*A54*                     &
      A66+A21*A33*A45*A54*A66+A24*A33*A41*A55*A66-A23*A34*A41*A55*A66-A24*A31*                 &
      A43*A55*A66+A21*A34*A43*A55*A66+A23*A31*A44*A55*A66-A21*A33*A44*A55*                     &
      A66

      COFACTOR(2,2) = A16*A35*A44*A53*A61-A15*A36*A44*A53*A61-A16*A34*A45*A53*A61+A14*A36*     &
      A45*A53*A61+A15*A34*A46*A53*A61-A14*A35*A46*A53*A61-A16*A35*A43*A54*                     &
      A61+A15*A36*A43*A54*A61+A16*A33*A45*A54*A61-A13*A36*A45*A54*A61-A15*A33*                 &
      A46*A54*A61+A13*A35*A46*A54*A61+A16*A34*A43*A55*A61-A14*A36*A43*A55*                     &
      A61-A16*A33*A44*A55*A61+A13*A36*A44*A55*A61+A14*A33*A46*A55*A61-A13*A34*                 &
      A46*A55*A61-A15*A34*A43*A56*A61+A14*A35*A43*A56*A61+A15*A33*A44*A56*                     &
      A61-A13*A35*A44*A56*A61-A14*A33*A45*A56*A61+A13*A34*A45*A56*A61-A16*A35*                 &
      A44*A51*A63+A15*A36*A44*A51*A63+A16*A34*A45*A51*A63-A14*A36*A45*A51*                     &
      A63-A15*A34*A46*A51*A63+A14*A35*A46*A51*A63+A16*A35*A41*A54*A63-A15*A36*                 &
      A41*A54*A63-A16*A31*A45*A54*A63+A11*A36*A45*A54*A63+A15*A31*A46*A54*                     &
      A63-A11*A35*A46*A54*A63-A16*A34*A41*A55*A63+A14*A36*A41*A55*A63+A16*A31*                 &
      A44*A55*A63-A11*A36*A44*A55*A63-A14*A31*A46*A55*A63+A11*A34*A46*A55*                     &
      A63+A15*A34*A41*A56*A63-A14*A35*A41*A56*A63-A15*A31*A44*A56*A63+A11*A35*                 &
      A44*A56*A63+A14*A31*A45*A56*A63-A11*A34*A45*A56*A63+A16*A35*A43*A51*                     &
      A64-A15*A36*A43*A51*A64-A16*A33*A45*A51*A64+A13*A36*A45*A51*A64+A15*A33*                 &
      A46*A51*A64-A13*A35*A46*A51*A64-A16*A35*A41*A53*A64+A15*A36*A41*A53*                     &
      A64+A16*A31*A45*A53*A64-A11*A36*A45*A53*A64-A15*A31*A46*A53*A64+A11*A35*                 &
      A46*A53*A64+A16*A33*A41*A55*A64-A13*A36*A41*A55*A64-A16*A31*A43*A55*                     &
      A64+A11*A36*A43*A55*A64+A13*A31*A46*A55*A64-A11*A33*A46*A55*A64-A15*A33*                 &
      A41*A56*A64+A13*A35*A41*A56*A64+A15*A31*A43*A56*A64-A11*A35*A43*A56*                     &
      A64-A13*A31*A45*A56*A64+A11*A33*A45*A56*A64-A16*A34*A43*A51*A65+A14*A36*                 &
      A43*A51*A65+A16*A33*A44*A51*A65-A13*A36*A44*A51*A65-A14*A33*A46*A51*                     &
      A65+A13*A34*A46*A51*A65+A16*A34*A41*A53*A65-A14*A36*A41*A53*A65-A16*A31*                 &
      A44*A53*A65+A11*A36*A44*A53*A65+A14*A31*A46*A53*A65-A11*A34*A46*A53*                     &
      A65-A16*A33*A41*A54*A65+A13*A36*A41*A54*A65+A16*A31*A43*A54*A65-A11*A36*                 &
      A43*A54*A65-A13*A31*A46*A54*A65+A11*A33*A46*A54*A65+A14*A33*A41*A56*                     &
      A65-A13*A34*A41*A56*A65-A14*A31*A43*A56*A65+A11*A34*A43*A56*A65+A13*A31*                 &
      A44*A56*A65-A11*A33*A44*A56*A65+A15*A34*A43*A51*A66-A14*A35*A43*A51*                     &
      A66-A15*A33*A44*A51*A66+A13*A35*A44*A51*A66+A14*A33*A45*A51*A66-A13*A34*                 &
      A45*A51*A66-A15*A34*A41*A53*A66+A14*A35*A41*A53*A66+A15*A31*A44*A53*                     &
      A66-A11*A35*A44*A53*A66-A14*A31*A45*A53*A66+A11*A34*A45*A53*A66+A15*A33*                 &
      A41*A54*A66-A13*A35*A41*A54*A66-A15*A31*A43*A54*A66+A11*A35*A43*A54*                     &
      A66+A13*A31*A45*A54*A66-A11*A33*A45*A54*A66-A14*A33*A41*A55*A66+A13*A34*                 &
      A41*A55*A66+A14*A31*A43*A55*A66-A11*A34*A43*A55*A66-A13*A31*A44*A55*                     &
      A66+A11*A33*A44*A55*A66

      COFACTOR(3,2) = -A16*A25*A44*A53*A61+A15*A26*A44*A53*A61+A16*A24*                        &
      A45*A53*A61-A14*A26*A45*A53*A61-A15*A24*A46*A53*A61+A14*A25*A46*A53*                     &
      A61+A16*A25*A43*A54*A61-A15*A26*A43*A54*A61-A16*A23*A45*A54*A61+A13*A26*                 &
      A45*A54*A61+A15*A23*A46*A54*A61-A13*A25*A46*A54*A61-A16*A24*A43*A55*                     &
      A61+A14*A26*A43*A55*A61+A16*A23*A44*A55*A61-A13*A26*A44*A55*A61-A14*A23*                 &
      A46*A55*A61+A13*A24*A46*A55*A61+A15*A24*A43*A56*A61-A14*A25*A43*A56*                     &
      A61-A15*A23*A44*A56*A61+A13*A25*A44*A56*A61+A14*A23*A45*A56*A61-A13*A24*                 &
      A45*A56*A61+A16*A25*A44*A51*A63-A15*A26*A44*A51*A63-A16*A24*A45*A51*                     &
      A63+A14*A26*A45*A51*A63+A15*A24*A46*A51*A63-A14*A25*A46*A51*A63-A16*A25*                 &
      A41*A54*A63+A15*A26*A41*A54*A63+A16*A21*A45*A54*A63-A11*A26*A45*A54*                     &
      A63-A15*A21*A46*A54*A63+A11*A25*A46*A54*A63+A16*A24*A41*A55*A63-A14*A26*                 &
      A41*A55*A63-A16*A21*A44*A55*A63+A11*A26*A44*A55*A63+A14*A21*A46*A55*                     &
      A63-A11*A24*A46*A55*A63-A15*A24*A41*A56*A63+A14*A25*A41*A56*A63+A15*A21*                 &
      A44*A56*A63-A11*A25*A44*A56*A63-A14*A21*A45*A56*A63+A11*A24*A45*A56*                     &
      A63-A16*A25*A43*A51*A64+A15*A26*A43*A51*A64+A16*A23*A45*A51*A64-A13*A26*                 &
      A45*A51*A64-A15*A23*A46*A51*A64+A13*A25*A46*A51*A64+A16*A25*A41*A53*                     &
      A64-A15*A26*A41*A53*A64-A16*A21*A45*A53*A64+A11*A26*A45*A53*A64+A15*A21*                 &
      A46*A53*A64-A11*A25*A46*A53*A64-A16*A23*A41*A55*A64+A13*A26*A41*A55*                     &
      A64+A16*A21*A43*A55*A64-A11*A26*A43*A55*A64-A13*A21*A46*A55*A64+A11*A23*                 &
      A46*A55*A64+A15*A23*A41*A56*A64-A13*A25*A41*A56*A64-A15*A21*A43*A56*                     &
      A64+A11*A25*A43*A56*A64+A13*A21*A45*A56*A64-A11*A23*A45*A56*A64+A16*A24*                 &
      A43*A51*A65-A14*A26*A43*A51*A65-A16*A23*A44*A51*A65+A13*A26*A44*A51*                     &
      A65+A14*A23*A46*A51*A65-A13*A24*A46*A51*A65-A16*A24*A41*A53*A65+A14*A26*                 &
      A41*A53*A65+A16*A21*A44*A53*A65-A11*A26*A44*A53*A65-A14*A21*A46*A53*                     &
      A65+A11*A24*A46*A53*A65+A16*A23*A41*A54*A65-A13*A26*A41*A54*A65-A16*A21*                 &
      A43*A54*A65+A11*A26*A43*A54*A65+A13*A21*A46*A54*A65-A11*A23*A46*A54*                     &
      A65-A14*A23*A41*A56*A65+A13*A24*A41*A56*A65+A14*A21*A43*A56*A65-A11*A24*                 &
      A43*A56*A65-A13*A21*A44*A56*A65+A11*A23*A44*A56*A65-A15*A24*A43*A51*                     &
      A66+A14*A25*A43*A51*A66+A15*A23*A44*A51*A66-A13*A25*A44*A51*A66-A14*A23*                 &
      A45*A51*A66+A13*A24*A45*A51*A66+A15*A24*A41*A53*A66-A14*A25*A41*A53*                     &
      A66-A15*A21*A44*A53*A66+A11*A25*A44*A53*A66+A14*A21*A45*A53*A66-A11*A24*                 &
      A45*A53*A66-A15*A23*A41*A54*A66+A13*A25*A41*A54*A66+A15*A21*A43*A54*                     &
      A66-A11*A25*A43*A54*A66-A13*A21*A45*A54*A66+A11*A23*A45*A54*A66+A14*A23*                 &
      A41*A55*A66-A13*A24*A41*A55*A66-A14*A21*A43*A55*A66+A11*A24*A43*A55*                     &
      A66+A13*A21*A44*A55*A66-A11*A23*A44*A55*A66

      COFACTOR(4,2) = A16*A25*A34*A53*A61-A15*A26*                                             &
      A34*A53*A61-A16*A24*A35*A53*A61+A14*A26*A35*A53*A61+A15*A24*A36*A53*                     &
      A61-A14*A25*A36*A53*A61-A16*A25*A33*A54*A61+A15*A26*A33*A54*A61+A16*A23*                 &
      A35*A54*A61-A13*A26*A35*A54*A61-A15*A23*A36*A54*A61+A13*A25*A36*A54*                     &
      A61+A16*A24*A33*A55*A61-A14*A26*A33*A55*A61-A16*A23*A34*A55*A61+A13*A26*                 &
      A34*A55*A61+A14*A23*A36*A55*A61-A13*A24*A36*A55*A61-A15*A24*A33*A56*                     &
      A61+A14*A25*A33*A56*A61+A15*A23*A34*A56*A61-A13*A25*A34*A56*A61-A14*A23*                 &
      A35*A56*A61+A13*A24*A35*A56*A61-A16*A25*A34*A51*A63+A15*A26*A34*A51*                     &
      A63+A16*A24*A35*A51*A63-A14*A26*A35*A51*A63-A15*A24*A36*A51*A63+A14*A25*                 &
      A36*A51*A63+A16*A25*A31*A54*A63-A15*A26*A31*A54*A63-A16*A21*A35*A54*                     &
      A63+A11*A26*A35*A54*A63+A15*A21*A36*A54*A63-A11*A25*A36*A54*A63-A16*A24*                 &
      A31*A55*A63+A14*A26*A31*A55*A63+A16*A21*A34*A55*A63-A11*A26*A34*A55*                     &
      A63-A14*A21*A36*A55*A63+A11*A24*A36*A55*A63+A15*A24*A31*A56*A63-A14*A25*                 &
      A31*A56*A63-A15*A21*A34*A56*A63+A11*A25*A34*A56*A63+A14*A21*A35*A56*                     &
      A63-A11*A24*A35*A56*A63+A16*A25*A33*A51*A64-A15*A26*A33*A51*A64-A16*A23*                 &
      A35*A51*A64+A13*A26*A35*A51*A64+A15*A23*A36*A51*A64-A13*A25*A36*A51*                     &
      A64-A16*A25*A31*A53*A64+A15*A26*A31*A53*A64+A16*A21*A35*A53*A64-A11*A26*                 &
      A35*A53*A64-A15*A21*A36*A53*A64+A11*A25*A36*A53*A64+A16*A23*A31*A55*                     &
      A64-A13*A26*A31*A55*A64-A16*A21*A33*A55*A64+A11*A26*A33*A55*A64+A13*A21*                 &
      A36*A55*A64-A11*A23*A36*A55*A64-A15*A23*A31*A56*A64+A13*A25*A31*A56*                     &
      A64+A15*A21*A33*A56*A64-A11*A25*A33*A56*A64-A13*A21*A35*A56*A64+A11*A23*                 &
      A35*A56*A64-A16*A24*A33*A51*A65+A14*A26*A33*A51*A65+A16*A23*A34*A51*                     &
      A65-A13*A26*A34*A51*A65-A14*A23*A36*A51*A65+A13*A24*A36*A51*A65+A16*A24*                 &
      A31*A53*A65-A14*A26*A31*A53*A65-A16*A21*A34*A53*A65+A11*A26*A34*A53*                     &
      A65+A14*A21*A36*A53*A65-A11*A24*A36*A53*A65-A16*A23*A31*A54*A65+A13*A26*                 &
      A31*A54*A65+A16*A21*A33*A54*A65-A11*A26*A33*A54*A65-A13*A21*A36*A54*                     &
      A65+A11*A23*A36*A54*A65+A14*A23*A31*A56*A65-A13*A24*A31*A56*A65-A14*A21*                 &
      A33*A56*A65+A11*A24*A33*A56*A65+A13*A21*A34*A56*A65-A11*A23*A34*A56*                     &
      A65+A15*A24*A33*A51*A66-A14*A25*A33*A51*A66-A15*A23*A34*A51*A66+A13*A25*                 &
      A34*A51*A66+A14*A23*A35*A51*A66-A13*A24*A35*A51*A66-A15*A24*A31*A53*                     &
      A66+A14*A25*A31*A53*A66+A15*A21*A34*A53*A66-A11*A25*A34*A53*A66-A14*A21*                 &
      A35*A53*A66+A11*A24*A35*A53*A66+A15*A23*A31*A54*A66-A13*A25*A31*A54*                     &
      A66-A15*A21*A33*A54*A66+A11*A25*A33*A54*A66+A13*A21*A35*A54*A66-A11*A23*                 &
      A35*A54*A66-A14*A23*A31*A55*A66+A13*A24*A31*A55*A66+A14*A21*A33*A55*                     &
      A66-A11*A24*A33*A55*A66-A13*A21*A34*A55*A66+A11*A23*A34*A55*A66

      COFACTOR(5,2) = -A16*A25*                                                                &
      A34*A43*A61+A15*A26*A34*A43*A61+A16*A24*A35*A43*A61-A14*A26*A35*A43*                     &
      A61-A15*A24*A36*A43*A61+A14*A25*A36*A43*A61+A16*A25*A33*A44*A61-A15*A26*                 &
      A33*A44*A61-A16*A23*A35*A44*A61+A13*A26*A35*A44*A61+A15*A23*A36*A44*                     &
      A61-A13*A25*A36*A44*A61-A16*A24*A33*A45*A61+A14*A26*A33*A45*A61+A16*A23*                 &
      A34*A45*A61-A13*A26*A34*A45*A61-A14*A23*A36*A45*A61+A13*A24*A36*A45*                     &
      A61+A15*A24*A33*A46*A61-A14*A25*A33*A46*A61-A15*A23*A34*A46*A61+A13*A25*                 &
      A34*A46*A61+A14*A23*A35*A46*A61-A13*A24*A35*A46*A61+A16*A25*A34*A41*                     &
      A63-A15*A26*A34*A41*A63-A16*A24*A35*A41*A63+A14*A26*A35*A41*A63+A15*A24*                 &
      A36*A41*A63-A14*A25*A36*A41*A63-A16*A25*A31*A44*A63+A15*A26*A31*A44*                     &
      A63+A16*A21*A35*A44*A63-A11*A26*A35*A44*A63-A15*A21*A36*A44*A63+A11*A25*                 &
      A36*A44*A63+A16*A24*A31*A45*A63-A14*A26*A31*A45*A63-A16*A21*A34*A45*                     &
      A63+A11*A26*A34*A45*A63+A14*A21*A36*A45*A63-A11*A24*A36*A45*A63-A15*A24*                 &
      A31*A46*A63+A14*A25*A31*A46*A63+A15*A21*A34*A46*A63-A11*A25*A34*A46*                     &
      A63-A14*A21*A35*A46*A63+A11*A24*A35*A46*A63-A16*A25*A33*A41*A64+A15*A26*                 &
      A33*A41*A64+A16*A23*A35*A41*A64-A13*A26*A35*A41*A64-A15*A23*A36*A41*                     &
      A64+A13*A25*A36*A41*A64+A16*A25*A31*A43*A64-A15*A26*A31*A43*A64-A16*A21*                 &
      A35*A43*A64+A11*A26*A35*A43*A64+A15*A21*A36*A43*A64-A11*A25*A36*A43*                     &
      A64-A16*A23*A31*A45*A64+A13*A26*A31*A45*A64+A16*A21*A33*A45*A64-A11*A26*                 &
      A33*A45*A64-A13*A21*A36*A45*A64+A11*A23*A36*A45*A64+A15*A23*A31*A46*                     &
      A64-A13*A25*A31*A46*A64-A15*A21*A33*A46*A64+A11*A25*A33*A46*A64+A13*A21*                 &
      A35*A46*A64-A11*A23*A35*A46*A64+A16*A24*A33*A41*A65-A14*A26*A33*A41*                     &
      A65-A16*A23*A34*A41*A65+A13*A26*A34*A41*A65+A14*A23*A36*A41*A65-A13*A24*                 &
      A36*A41*A65-A16*A24*A31*A43*A65+A14*A26*A31*A43*A65+A16*A21*A34*A43*                     &
      A65-A11*A26*A34*A43*A65-A14*A21*A36*A43*A65+A11*A24*A36*A43*A65+A16*A23*                 &
      A31*A44*A65-A13*A26*A31*A44*A65-A16*A21*A33*A44*A65+A11*A26*A33*A44*                     &
      A65+A13*A21*A36*A44*A65-A11*A23*A36*A44*A65-A14*A23*A31*A46*A65+A13*A24*                 &
      A31*A46*A65+A14*A21*A33*A46*A65-A11*A24*A33*A46*A65-A13*A21*A34*A46*                     &
      A65+A11*A23*A34*A46*A65-A15*A24*A33*A41*A66+A14*A25*A33*A41*A66+A15*A23*                 &
      A34*A41*A66-A13*A25*A34*A41*A66-A14*A23*A35*A41*A66+A13*A24*A35*A41*                     &
      A66+A15*A24*A31*A43*A66-A14*A25*A31*A43*A66-A15*A21*A34*A43*A66+A11*A25*                 &
      A34*A43*A66+A14*A21*A35*A43*A66-A11*A24*A35*A43*A66-A15*A23*A31*A44*                     &
      A66+A13*A25*A31*A44*A66+A15*A21*A33*A44*A66-A11*A25*A33*A44*A66-A13*A21*                 &
      A35*A44*A66+A11*A23*A35*A44*A66+A14*A23*A31*A45*A66-A13*A24*A31*A45*                     &
      A66-A14*A21*A33*A45*A66+A11*A24*A33*A45*A66+A13*A21*A34*A45*A66-A11*A23*                 &
      A34*A45*A66

      COFACTOR(6,2) = A16*A25*A34*A43*A51-A15*A26*A34*A43*A51-A16*A24*A35*A43*                 &
      A51+A14*A26*A35*A43*A51+A15*A24*A36*A43*A51-A14*A25*A36*A43*A51-A16*A25*                 &
      A33*A44*A51+A15*A26*A33*A44*A51+A16*A23*A35*A44*A51-A13*A26*A35*A44*                     &
      A51-A15*A23*A36*A44*A51+A13*A25*A36*A44*A51+A16*A24*A33*A45*A51-A14*A26*                 &
      A33*A45*A51-A16*A23*A34*A45*A51+A13*A26*A34*A45*A51+A14*A23*A36*A45*                     &
      A51-A13*A24*A36*A45*A51-A15*A24*A33*A46*A51+A14*A25*A33*A46*A51+A15*A23*                 &
      A34*A46*A51-A13*A25*A34*A46*A51-A14*A23*A35*A46*A51+A13*A24*A35*A46*                     &
      A51-A16*A25*A34*A41*A53+A15*A26*A34*A41*A53+A16*A24*A35*A41*A53-A14*A26*                 &
      A35*A41*A53-A15*A24*A36*A41*A53+A14*A25*A36*A41*A53+A16*A25*A31*A44*                     &
      A53-A15*A26*A31*A44*A53-A16*A21*A35*A44*A53+A11*A26*A35*A44*A53+A15*A21*                 &
      A36*A44*A53-A11*A25*A36*A44*A53-A16*A24*A31*A45*A53+A14*A26*A31*A45*                     &
      A53+A16*A21*A34*A45*A53-A11*A26*A34*A45*A53-A14*A21*A36*A45*A53+A11*A24*                 &
      A36*A45*A53+A15*A24*A31*A46*A53-A14*A25*A31*A46*A53-A15*A21*A34*A46*                     &
      A53+A11*A25*A34*A46*A53+A14*A21*A35*A46*A53-A11*A24*A35*A46*A53+A16*A25*                 &
      A33*A41*A54-A15*A26*A33*A41*A54-A16*A23*A35*A41*A54+A13*A26*A35*A41*                     &
      A54+A15*A23*A36*A41*A54-A13*A25*A36*A41*A54-A16*A25*A31*A43*A54+A15*A26*                 &
      A31*A43*A54+A16*A21*A35*A43*A54-A11*A26*A35*A43*A54-A15*A21*A36*A43*                     &
      A54+A11*A25*A36*A43*A54+A16*A23*A31*A45*A54-A13*A26*A31*A45*A54-A16*A21*                 &
      A33*A45*A54+A11*A26*A33*A45*A54+A13*A21*A36*A45*A54-A11*A23*A36*A45*                     &
      A54-A15*A23*A31*A46*A54+A13*A25*A31*A46*A54+A15*A21*A33*A46*A54-A11*A25*                 &
      A33*A46*A54-A13*A21*A35*A46*A54+A11*A23*A35*A46*A54-A16*A24*A33*A41*                     &
      A55+A14*A26*A33*A41*A55+A16*A23*A34*A41*A55-A13*A26*A34*A41*A55-A14*A23*                 &
      A36*A41*A55+A13*A24*A36*A41*A55+A16*A24*A31*A43*A55-A14*A26*A31*A43*                     &
      A55-A16*A21*A34*A43*A55+A11*A26*A34*A43*A55+A14*A21*A36*A43*A55-A11*A24*                 &
      A36*A43*A55-A16*A23*A31*A44*A55+A13*A26*A31*A44*A55+A16*A21*A33*A44*                     &
      A55-A11*A26*A33*A44*A55-A13*A21*A36*A44*A55+A11*A23*A36*A44*A55+A14*A23*                 &
      A31*A46*A55-A13*A24*A31*A46*A55-A14*A21*A33*A46*A55+A11*A24*A33*A46*                     &
      A55+A13*A21*A34*A46*A55-A11*A23*A34*A46*A55+A15*A24*A33*A41*A56-A14*A25*                 &
      A33*A41*A56-A15*A23*A34*A41*A56+A13*A25*A34*A41*A56+A14*A23*A35*A41*                     &
      A56-A13*A24*A35*A41*A56-A15*A24*A31*A43*A56+A14*A25*A31*A43*A56+A15*A21*                 &
      A34*A43*A56-A11*A25*A34*A43*A56-A14*A21*A35*A43*A56+A11*A24*A35*A43*                     &
      A56+A15*A23*A31*A44*A56-A13*A25*A31*A44*A56-A15*A21*A33*A44*A56+A11*A25*                 &
      A33*A44*A56+A13*A21*A35*A44*A56-A11*A23*A35*A44*A56-A14*A23*A31*A45*                     &
      A56+A13*A24*A31*A45*A56+A14*A21*A33*A45*A56-A11*A24*A33*A45*A56-A13*A21*                 &
      A34*A45*A56+A11*A23*A34*A45*A56

      COFACTOR(1,3) = A26*A35*A44*A52*A61-A25*A36*A44*A52*                                     &
      A61-A26*A34*A45*A52*A61+A24*A36*A45*A52*A61+A25*A34*A46*A52*A61-A24*A35*                 &
      A46*A52*A61-A26*A35*A42*A54*A61+A25*A36*A42*A54*A61+A26*A32*A45*A54*                     &
      A61-A22*A36*A45*A54*A61-A25*A32*A46*A54*A61+A22*A35*A46*A54*A61+A26*A34*                 &
      A42*A55*A61-A24*A36*A42*A55*A61-A26*A32*A44*A55*A61+A22*A36*A44*A55*                     &
      A61+A24*A32*A46*A55*A61-A22*A34*A46*A55*A61-A25*A34*A42*A56*A61+A24*A35*                 &
      A42*A56*A61+A25*A32*A44*A56*A61-A22*A35*A44*A56*A61-A24*A32*A45*A56*                     &
      A61+A22*A34*A45*A56*A61-A26*A35*A44*A51*A62+A25*A36*A44*A51*A62+A26*A34*                 &
      A45*A51*A62-A24*A36*A45*A51*A62-A25*A34*A46*A51*A62+A24*A35*A46*A51*                     &
      A62+A26*A35*A41*A54*A62-A25*A36*A41*A54*A62-A26*A31*A45*A54*A62+A21*A36*                 &
      A45*A54*A62+A25*A31*A46*A54*A62-A21*A35*A46*A54*A62-A26*A34*A41*A55*                     &
      A62+A24*A36*A41*A55*A62+A26*A31*A44*A55*A62-A21*A36*A44*A55*A62-A24*A31*                 &
      A46*A55*A62+A21*A34*A46*A55*A62+A25*A34*A41*A56*A62-A24*A35*A41*A56*                     &
      A62-A25*A31*A44*A56*A62+A21*A35*A44*A56*A62+A24*A31*A45*A56*A62-A21*A34*                 &
      A45*A56*A62+A26*A35*A42*A51*A64-A25*A36*A42*A51*A64-A26*A32*A45*A51*                     &
      A64+A22*A36*A45*A51*A64+A25*A32*A46*A51*A64-A22*A35*A46*A51*A64-A26*A35*                 &
      A41*A52*A64+A25*A36*A41*A52*A64+A26*A31*A45*A52*A64-A21*A36*A45*A52*                     &
      A64-A25*A31*A46*A52*A64+A21*A35*A46*A52*A64+A26*A32*A41*A55*A64-A22*A36*                 &
      A41*A55*A64-A26*A31*A42*A55*A64+A21*A36*A42*A55*A64+A22*A31*A46*A55*                     &
      A64-A21*A32*A46*A55*A64-A25*A32*A41*A56*A64+A22*A35*A41*A56*A64+A25*A31*                 &
      A42*A56*A64-A21*A35*A42*A56*A64-A22*A31*A45*A56*A64+A21*A32*A45*A56*                     &
      A64-A26*A34*A42*A51*A65+A24*A36*A42*A51*A65+A26*A32*A44*A51*A65-A22*A36*                 &
      A44*A51*A65-A24*A32*A46*A51*A65+A22*A34*A46*A51*A65+A26*A34*A41*A52*                     &
      A65-A24*A36*A41*A52*A65-A26*A31*A44*A52*A65+A21*A36*A44*A52*A65+A24*A31*                 &
      A46*A52*A65-A21*A34*A46*A52*A65-A26*A32*A41*A54*A65+A22*A36*A41*A54*                     &
      A65+A26*A31*A42*A54*A65-A21*A36*A42*A54*A65-A22*A31*A46*A54*A65+A21*A32*                 &
      A46*A54*A65+A24*A32*A41*A56*A65-A22*A34*A41*A56*A65-A24*A31*A42*A56*                     &
      A65+A21*A34*A42*A56*A65+A22*A31*A44*A56*A65-A21*A32*A44*A56*A65+A25*A34*                 &
      A42*A51*A66-A24*A35*A42*A51*A66-A25*A32*A44*A51*A66+A22*A35*A44*A51*                     &
      A66+A24*A32*A45*A51*A66-A22*A34*A45*A51*A66-A25*A34*A41*A52*A66+A24*A35*                 &
      A41*A52*A66+A25*A31*A44*A52*A66-A21*A35*A44*A52*A66-A24*A31*A45*A52*                     &
      A66+A21*A34*A45*A52*A66+A25*A32*A41*A54*A66-A22*A35*A41*A54*A66-A25*A31*                 &
      A42*A54*A66+A21*A35*A42*A54*A66+A22*A31*A45*A54*A66-A21*A32*A45*A54*                     &
      A66-A24*A32*A41*A55*A66+A22*A34*A41*A55*A66+A24*A31*A42*A55*A66-A21*A34*                 &
      A42*A55*A66-A22*A31*A44*A55*A66+A21*A32*A44*A55*A66

      COFACTOR(2,3) = -A16*A35*A44*A52*                                                        &
      A61+A15*A36*A44*A52*A61+A16*A34*A45*A52*A61-A14*A36*A45*A52*A61-A15*A34*                 &
      A46*A52*A61+A14*A35*A46*A52*A61+A16*A35*A42*A54*A61-A15*A36*A42*A54*                     &
      A61-A16*A32*A45*A54*A61+A12*A36*A45*A54*A61+A15*A32*A46*A54*A61-A12*A35*                 &
      A46*A54*A61-A16*A34*A42*A55*A61+A14*A36*A42*A55*A61+A16*A32*A44*A55*                     &
      A61-A12*A36*A44*A55*A61-A14*A32*A46*A55*A61+A12*A34*A46*A55*A61+A15*A34*                 &
      A42*A56*A61-A14*A35*A42*A56*A61-A15*A32*A44*A56*A61+A12*A35*A44*A56*                     &
      A61+A14*A32*A45*A56*A61-A12*A34*A45*A56*A61+A16*A35*A44*A51*A62-A15*A36*                 &
      A44*A51*A62-A16*A34*A45*A51*A62+A14*A36*A45*A51*A62+A15*A34*A46*A51*                     &
      A62-A14*A35*A46*A51*A62-A16*A35*A41*A54*A62+A15*A36*A41*A54*A62+A16*A31*                 &
      A45*A54*A62-A11*A36*A45*A54*A62-A15*A31*A46*A54*A62+A11*A35*A46*A54*                     &
      A62+A16*A34*A41*A55*A62-A14*A36*A41*A55*A62-A16*A31*A44*A55*A62+A11*A36*                 &
      A44*A55*A62+A14*A31*A46*A55*A62-A11*A34*A46*A55*A62-A15*A34*A41*A56*                     &
      A62+A14*A35*A41*A56*A62+A15*A31*A44*A56*A62-A11*A35*A44*A56*A62-A14*A31*                 &
      A45*A56*A62+A11*A34*A45*A56*A62-A16*A35*A42*A51*A64+A15*A36*A42*A51*                     &
      A64+A16*A32*A45*A51*A64-A12*A36*A45*A51*A64-A15*A32*A46*A51*A64+A12*A35*                 &
      A46*A51*A64+A16*A35*A41*A52*A64-A15*A36*A41*A52*A64-A16*A31*A45*A52*                     &
      A64+A11*A36*A45*A52*A64+A15*A31*A46*A52*A64-A11*A35*A46*A52*A64-A16*A32*                 &
      A41*A55*A64+A12*A36*A41*A55*A64+A16*A31*A42*A55*A64-A11*A36*A42*A55*                     &
      A64-A12*A31*A46*A55*A64+A11*A32*A46*A55*A64+A15*A32*A41*A56*A64-A12*A35*                 &
      A41*A56*A64-A15*A31*A42*A56*A64+A11*A35*A42*A56*A64+A12*A31*A45*A56*                     &
      A64-A11*A32*A45*A56*A64+A16*A34*A42*A51*A65-A14*A36*A42*A51*A65-A16*A32*                 &
      A44*A51*A65+A12*A36*A44*A51*A65+A14*A32*A46*A51*A65-A12*A34*A46*A51*                     &
      A65-A16*A34*A41*A52*A65+A14*A36*A41*A52*A65+A16*A31*A44*A52*A65-A11*A36*                 &
      A44*A52*A65-A14*A31*A46*A52*A65+A11*A34*A46*A52*A65+A16*A32*A41*A54*                     &
      A65-A12*A36*A41*A54*A65-A16*A31*A42*A54*A65+A11*A36*A42*A54*A65+A12*A31*                 &
      A46*A54*A65-A11*A32*A46*A54*A65-A14*A32*A41*A56*A65+A12*A34*A41*A56*                     &
      A65+A14*A31*A42*A56*A65-A11*A34*A42*A56*A65-A12*A31*A44*A56*A65+A11*A32*                 &
      A44*A56*A65-A15*A34*A42*A51*A66+A14*A35*A42*A51*A66+A15*A32*A44*A51*                     &
      A66-A12*A35*A44*A51*A66-A14*A32*A45*A51*A66+A12*A34*A45*A51*A66+A15*A34*                 &
      A41*A52*A66-A14*A35*A41*A52*A66-A15*A31*A44*A52*A66+A11*A35*A44*A52*                     &
      A66+A14*A31*A45*A52*A66-A11*A34*A45*A52*A66-A15*A32*A41*A54*A66+A12*A35*                 &
      A41*A54*A66+A15*A31*A42*A54*A66-A11*A35*A42*A54*A66-A12*A31*A45*A54*                     &
      A66+A11*A32*A45*A54*A66+A14*A32*A41*A55*A66-A12*A34*A41*A55*A66-A14*A31*                 &
      A42*A55*A66+A11*A34*A42*A55*A66+A12*A31*A44*A55*A66-A11*A32*A44*A55*                     &
      A66

      COFACTOR(3,3) = A16*A25*A44*A52*A61-A15*A26*A44*A52*A61-A16*A24*A45*A52*A61+A14*A26*     &
      A45*A52*A61+A15*A24*A46*A52*A61-A14*A25*A46*A52*A61-A16*A25*A42*A54*                     &
      A61+A15*A26*A42*A54*A61+A16*A22*A45*A54*A61-A12*A26*A45*A54*A61-A15*A22*                 &
      A46*A54*A61+A12*A25*A46*A54*A61+A16*A24*A42*A55*A61-A14*A26*A42*A55*                     &
      A61-A16*A22*A44*A55*A61+A12*A26*A44*A55*A61+A14*A22*A46*A55*A61-A12*A24*                 &
      A46*A55*A61-A15*A24*A42*A56*A61+A14*A25*A42*A56*A61+A15*A22*A44*A56*                     &
      A61-A12*A25*A44*A56*A61-A14*A22*A45*A56*A61+A12*A24*A45*A56*A61-A16*A25*                 &
      A44*A51*A62+A15*A26*A44*A51*A62+A16*A24*A45*A51*A62-A14*A26*A45*A51*                     &
      A62-A15*A24*A46*A51*A62+A14*A25*A46*A51*A62+A16*A25*A41*A54*A62-A15*A26*                 &
      A41*A54*A62-A16*A21*A45*A54*A62+A11*A26*A45*A54*A62+A15*A21*A46*A54*                     &
      A62-A11*A25*A46*A54*A62-A16*A24*A41*A55*A62+A14*A26*A41*A55*A62+A16*A21*                 &
      A44*A55*A62-A11*A26*A44*A55*A62-A14*A21*A46*A55*A62+A11*A24*A46*A55*                     &
      A62+A15*A24*A41*A56*A62-A14*A25*A41*A56*A62-A15*A21*A44*A56*A62+A11*A25*                 &
      A44*A56*A62+A14*A21*A45*A56*A62-A11*A24*A45*A56*A62+A16*A25*A42*A51*                     &
      A64-A15*A26*A42*A51*A64-A16*A22*A45*A51*A64+A12*A26*A45*A51*A64+A15*A22*                 &
      A46*A51*A64-A12*A25*A46*A51*A64-A16*A25*A41*A52*A64+A15*A26*A41*A52*                     &
      A64+A16*A21*A45*A52*A64-A11*A26*A45*A52*A64-A15*A21*A46*A52*A64+A11*A25*                 &
      A46*A52*A64+A16*A22*A41*A55*A64-A12*A26*A41*A55*A64-A16*A21*A42*A55*                     &
      A64+A11*A26*A42*A55*A64+A12*A21*A46*A55*A64-A11*A22*A46*A55*A64-A15*A22*                 &
      A41*A56*A64+A12*A25*A41*A56*A64+A15*A21*A42*A56*A64-A11*A25*A42*A56*                     &
      A64-A12*A21*A45*A56*A64+A11*A22*A45*A56*A64-A16*A24*A42*A51*A65+A14*A26*                 &
      A42*A51*A65+A16*A22*A44*A51*A65-A12*A26*A44*A51*A65-A14*A22*A46*A51*                     &
      A65+A12*A24*A46*A51*A65+A16*A24*A41*A52*A65-A14*A26*A41*A52*A65-A16*A21*                 &
      A44*A52*A65+A11*A26*A44*A52*A65+A14*A21*A46*A52*A65-A11*A24*A46*A52*                     &
      A65-A16*A22*A41*A54*A65+A12*A26*A41*A54*A65+A16*A21*A42*A54*A65-A11*A26*                 &
      A42*A54*A65-A12*A21*A46*A54*A65+A11*A22*A46*A54*A65+A14*A22*A41*A56*                     &
      A65-A12*A24*A41*A56*A65-A14*A21*A42*A56*A65+A11*A24*A42*A56*A65+A12*A21*                 &
      A44*A56*A65-A11*A22*A44*A56*A65+A15*A24*A42*A51*A66-A14*A25*A42*A51*                     &
      A66-A15*A22*A44*A51*A66+A12*A25*A44*A51*A66+A14*A22*A45*A51*A66-A12*A24*                 &
      A45*A51*A66-A15*A24*A41*A52*A66+A14*A25*A41*A52*A66+A15*A21*A44*A52*                     &
      A66-A11*A25*A44*A52*A66-A14*A21*A45*A52*A66+A11*A24*A45*A52*A66+A15*A22*                 &
      A41*A54*A66-A12*A25*A41*A54*A66-A15*A21*A42*A54*A66+A11*A25*A42*A54*                     &
      A66+A12*A21*A45*A54*A66-A11*A22*A45*A54*A66-A14*A22*A41*A55*A66+A12*A24*                 &
      A41*A55*A66+A14*A21*A42*A55*A66-A11*A24*A42*A55*A66-A12*A21*A44*A55*                     &
      A66+A11*A22*A44*A55*A66

      COFACTOR(4,3) = -A16*A25*A34*A52*A61+A15*A26*A34*A52*A61+A16*A24*                        &
      A35*A52*A61-A14*A26*A35*A52*A61-A15*A24*A36*A52*A61+A14*A25*A36*A52*                     &
      A61+A16*A25*A32*A54*A61-A15*A26*A32*A54*A61-A16*A22*A35*A54*A61+A12*A26*                 &
      A35*A54*A61+A15*A22*A36*A54*A61-A12*A25*A36*A54*A61-A16*A24*A32*A55*                     &
      A61+A14*A26*A32*A55*A61+A16*A22*A34*A55*A61-A12*A26*A34*A55*A61-A14*A22*                 &
      A36*A55*A61+A12*A24*A36*A55*A61+A15*A24*A32*A56*A61-A14*A25*A32*A56*                     &
      A61-A15*A22*A34*A56*A61+A12*A25*A34*A56*A61+A14*A22*A35*A56*A61-A12*A24*                 &
      A35*A56*A61+A16*A25*A34*A51*A62-A15*A26*A34*A51*A62-A16*A24*A35*A51*                     &
      A62+A14*A26*A35*A51*A62+A15*A24*A36*A51*A62-A14*A25*A36*A51*A62-A16*A25*                 &
      A31*A54*A62+A15*A26*A31*A54*A62+A16*A21*A35*A54*A62-A11*A26*A35*A54*                     &
      A62-A15*A21*A36*A54*A62+A11*A25*A36*A54*A62+A16*A24*A31*A55*A62-A14*A26*                 &
      A31*A55*A62-A16*A21*A34*A55*A62+A11*A26*A34*A55*A62+A14*A21*A36*A55*                     &
      A62-A11*A24*A36*A55*A62-A15*A24*A31*A56*A62+A14*A25*A31*A56*A62+A15*A21*                 &
      A34*A56*A62-A11*A25*A34*A56*A62-A14*A21*A35*A56*A62+A11*A24*A35*A56*                     &
      A62-A16*A25*A32*A51*A64+A15*A26*A32*A51*A64+A16*A22*A35*A51*A64-A12*A26*                 &
      A35*A51*A64-A15*A22*A36*A51*A64+A12*A25*A36*A51*A64+A16*A25*A31*A52*                     &
      A64-A15*A26*A31*A52*A64-A16*A21*A35*A52*A64+A11*A26*A35*A52*A64+A15*A21*                 &
      A36*A52*A64-A11*A25*A36*A52*A64-A16*A22*A31*A55*A64+A12*A26*A31*A55*                     &
      A64+A16*A21*A32*A55*A64-A11*A26*A32*A55*A64-A12*A21*A36*A55*A64+A11*A22*                 &
      A36*A55*A64+A15*A22*A31*A56*A64-A12*A25*A31*A56*A64-A15*A21*A32*A56*                     &
      A64+A11*A25*A32*A56*A64+A12*A21*A35*A56*A64-A11*A22*A35*A56*A64+A16*A24*                 &
      A32*A51*A65-A14*A26*A32*A51*A65-A16*A22*A34*A51*A65+A12*A26*A34*A51*                     &
      A65+A14*A22*A36*A51*A65-A12*A24*A36*A51*A65-A16*A24*A31*A52*A65+A14*A26*                 &
      A31*A52*A65+A16*A21*A34*A52*A65-A11*A26*A34*A52*A65-A14*A21*A36*A52*                     &
      A65+A11*A24*A36*A52*A65+A16*A22*A31*A54*A65-A12*A26*A31*A54*A65-A16*A21*                 &
      A32*A54*A65+A11*A26*A32*A54*A65+A12*A21*A36*A54*A65-A11*A22*A36*A54*                     &
      A65-A14*A22*A31*A56*A65+A12*A24*A31*A56*A65+A14*A21*A32*A56*A65-A11*A24*                 &
      A32*A56*A65-A12*A21*A34*A56*A65+A11*A22*A34*A56*A65-A15*A24*A32*A51*                     &
      A66+A14*A25*A32*A51*A66+A15*A22*A34*A51*A66-A12*A25*A34*A51*A66-A14*A22*                 &
      A35*A51*A66+A12*A24*A35*A51*A66+A15*A24*A31*A52*A66-A14*A25*A31*A52*                     &
      A66-A15*A21*A34*A52*A66+A11*A25*A34*A52*A66+A14*A21*A35*A52*A66-A11*A24*                 &
      A35*A52*A66-A15*A22*A31*A54*A66+A12*A25*A31*A54*A66+A15*A21*A32*A54*                     &
      A66-A11*A25*A32*A54*A66-A12*A21*A35*A54*A66+A11*A22*A35*A54*A66+A14*A22*                 &
      A31*A55*A66-A12*A24*A31*A55*A66-A14*A21*A32*A55*A66+A11*A24*A32*A55*                     &
      A66+A12*A21*A34*A55*A66-A11*A22*A34*A55*A66

      COFACTOR(5,3) = A16*A25*A34*A42*A61-A15*A26*                                             &
      A34*A42*A61-A16*A24*A35*A42*A61+A14*A26*A35*A42*A61+A15*A24*A36*A42*                     &
      A61-A14*A25*A36*A42*A61-A16*A25*A32*A44*A61+A15*A26*A32*A44*A61+A16*A22*                 &
      A35*A44*A61-A12*A26*A35*A44*A61-A15*A22*A36*A44*A61+A12*A25*A36*A44*                     &
      A61+A16*A24*A32*A45*A61-A14*A26*A32*A45*A61-A16*A22*A34*A45*A61+A12*A26*                 &
      A34*A45*A61+A14*A22*A36*A45*A61-A12*A24*A36*A45*A61-A15*A24*A32*A46*                     &
      A61+A14*A25*A32*A46*A61+A15*A22*A34*A46*A61-A12*A25*A34*A46*A61-A14*A22*                 &
      A35*A46*A61+A12*A24*A35*A46*A61-A16*A25*A34*A41*A62+A15*A26*A34*A41*                     &
      A62+A16*A24*A35*A41*A62-A14*A26*A35*A41*A62-A15*A24*A36*A41*A62+A14*A25*                 &
      A36*A41*A62+A16*A25*A31*A44*A62-A15*A26*A31*A44*A62-A16*A21*A35*A44*                     &
      A62+A11*A26*A35*A44*A62+A15*A21*A36*A44*A62-A11*A25*A36*A44*A62-A16*A24*                 &
      A31*A45*A62+A14*A26*A31*A45*A62+A16*A21*A34*A45*A62-A11*A26*A34*A45*                     &
      A62-A14*A21*A36*A45*A62+A11*A24*A36*A45*A62+A15*A24*A31*A46*A62-A14*A25*                 &
      A31*A46*A62-A15*A21*A34*A46*A62+A11*A25*A34*A46*A62+A14*A21*A35*A46*                     &
      A62-A11*A24*A35*A46*A62+A16*A25*A32*A41*A64-A15*A26*A32*A41*A64-A16*A22*                 &
      A35*A41*A64+A12*A26*A35*A41*A64+A15*A22*A36*A41*A64-A12*A25*A36*A41*                     &
      A64-A16*A25*A31*A42*A64+A15*A26*A31*A42*A64+A16*A21*A35*A42*A64-A11*A26*                 &
      A35*A42*A64-A15*A21*A36*A42*A64+A11*A25*A36*A42*A64+A16*A22*A31*A45*                     &
      A64-A12*A26*A31*A45*A64-A16*A21*A32*A45*A64+A11*A26*A32*A45*A64+A12*A21*                 &
      A36*A45*A64-A11*A22*A36*A45*A64-A15*A22*A31*A46*A64+A12*A25*A31*A46*                     &
      A64+A15*A21*A32*A46*A64-A11*A25*A32*A46*A64-A12*A21*A35*A46*A64+A11*A22*                 &
      A35*A46*A64-A16*A24*A32*A41*A65+A14*A26*A32*A41*A65+A16*A22*A34*A41*                     &
      A65-A12*A26*A34*A41*A65-A14*A22*A36*A41*A65+A12*A24*A36*A41*A65+A16*A24*                 &
      A31*A42*A65-A14*A26*A31*A42*A65-A16*A21*A34*A42*A65+A11*A26*A34*A42*                     &
      A65+A14*A21*A36*A42*A65-A11*A24*A36*A42*A65-A16*A22*A31*A44*A65+A12*A26*                 &
      A31*A44*A65+A16*A21*A32*A44*A65-A11*A26*A32*A44*A65-A12*A21*A36*A44*                     &
      A65+A11*A22*A36*A44*A65+A14*A22*A31*A46*A65-A12*A24*A31*A46*A65-A14*A21*                 &
      A32*A46*A65+A11*A24*A32*A46*A65+A12*A21*A34*A46*A65-A11*A22*A34*A46*                     &
      A65+A15*A24*A32*A41*A66-A14*A25*A32*A41*A66-A15*A22*A34*A41*A66+A12*A25*                 &
      A34*A41*A66+A14*A22*A35*A41*A66-A12*A24*A35*A41*A66-A15*A24*A31*A42*                     &
      A66+A14*A25*A31*A42*A66+A15*A21*A34*A42*A66-A11*A25*A34*A42*A66-A14*A21*                 &
      A35*A42*A66+A11*A24*A35*A42*A66+A15*A22*A31*A44*A66-A12*A25*A31*A44*                     &
      A66-A15*A21*A32*A44*A66+A11*A25*A32*A44*A66+A12*A21*A35*A44*A66-A11*A22*                 &
      A35*A44*A66-A14*A22*A31*A45*A66+A12*A24*A31*A45*A66+A14*A21*A32*A45*                     &
      A66-A11*A24*A32*A45*A66-A12*A21*A34*A45*A66+A11*A22*A34*A45*A66

      COFACTOR(6,3) = -A16*A25*                                                                &
      A34*A42*A51+A15*A26*A34*A42*A51+A16*A24*A35*A42*A51-A14*A26*A35*A42*                     &
      A51-A15*A24*A36*A42*A51+A14*A25*A36*A42*A51+A16*A25*A32*A44*A51-A15*A26*                 &
      A32*A44*A51-A16*A22*A35*A44*A51+A12*A26*A35*A44*A51+A15*A22*A36*A44*                     &
      A51-A12*A25*A36*A44*A51-A16*A24*A32*A45*A51+A14*A26*A32*A45*A51+A16*A22*                 &
      A34*A45*A51-A12*A26*A34*A45*A51-A14*A22*A36*A45*A51+A12*A24*A36*A45*                     &
      A51+A15*A24*A32*A46*A51-A14*A25*A32*A46*A51-A15*A22*A34*A46*A51+A12*A25*                 &
      A34*A46*A51+A14*A22*A35*A46*A51-A12*A24*A35*A46*A51+A16*A25*A34*A41*                     &
      A52-A15*A26*A34*A41*A52-A16*A24*A35*A41*A52+A14*A26*A35*A41*A52+A15*A24*                 &
      A36*A41*A52-A14*A25*A36*A41*A52-A16*A25*A31*A44*A52+A15*A26*A31*A44*                     &
      A52+A16*A21*A35*A44*A52-A11*A26*A35*A44*A52-A15*A21*A36*A44*A52+A11*A25*                 &
      A36*A44*A52+A16*A24*A31*A45*A52-A14*A26*A31*A45*A52-A16*A21*A34*A45*                     &
      A52+A11*A26*A34*A45*A52+A14*A21*A36*A45*A52-A11*A24*A36*A45*A52-A15*A24*                 &
      A31*A46*A52+A14*A25*A31*A46*A52+A15*A21*A34*A46*A52-A11*A25*A34*A46*                     &
      A52-A14*A21*A35*A46*A52+A11*A24*A35*A46*A52-A16*A25*A32*A41*A54+A15*A26*                 &
      A32*A41*A54+A16*A22*A35*A41*A54-A12*A26*A35*A41*A54-A15*A22*A36*A41*                     &
      A54+A12*A25*A36*A41*A54+A16*A25*A31*A42*A54-A15*A26*A31*A42*A54-A16*A21*                 &
      A35*A42*A54+A11*A26*A35*A42*A54+A15*A21*A36*A42*A54-A11*A25*A36*A42*                     &
      A54-A16*A22*A31*A45*A54+A12*A26*A31*A45*A54+A16*A21*A32*A45*A54-A11*A26*                 &
      A32*A45*A54-A12*A21*A36*A45*A54+A11*A22*A36*A45*A54+A15*A22*A31*A46*                     &
      A54-A12*A25*A31*A46*A54-A15*A21*A32*A46*A54+A11*A25*A32*A46*A54+A12*A21*                 &
      A35*A46*A54-A11*A22*A35*A46*A54+A16*A24*A32*A41*A55-A14*A26*A32*A41*                     &
      A55-A16*A22*A34*A41*A55+A12*A26*A34*A41*A55+A14*A22*A36*A41*A55-A12*A24*                 &
      A36*A41*A55-A16*A24*A31*A42*A55+A14*A26*A31*A42*A55+A16*A21*A34*A42*                     &
      A55-A11*A26*A34*A42*A55-A14*A21*A36*A42*A55+A11*A24*A36*A42*A55+A16*A22*                 &
      A31*A44*A55-A12*A26*A31*A44*A55-A16*A21*A32*A44*A55+A11*A26*A32*A44*                     &
      A55+A12*A21*A36*A44*A55-A11*A22*A36*A44*A55-A14*A22*A31*A46*A55+A12*A24*                 &
      A31*A46*A55+A14*A21*A32*A46*A55-A11*A24*A32*A46*A55-A12*A21*A34*A46*                     &
      A55+A11*A22*A34*A46*A55-A15*A24*A32*A41*A56+A14*A25*A32*A41*A56+A15*A22*                 &
      A34*A41*A56-A12*A25*A34*A41*A56-A14*A22*A35*A41*A56+A12*A24*A35*A41*                     &
      A56+A15*A24*A31*A42*A56-A14*A25*A31*A42*A56-A15*A21*A34*A42*A56+A11*A25*                 &
      A34*A42*A56+A14*A21*A35*A42*A56-A11*A24*A35*A42*A56-A15*A22*A31*A44*                     &
      A56+A12*A25*A31*A44*A56+A15*A21*A32*A44*A56-A11*A25*A32*A44*A56-A12*A21*                 &
      A35*A44*A56+A11*A22*A35*A44*A56+A14*A22*A31*A45*A56-A12*A24*A31*A45*                     &
      A56-A14*A21*A32*A45*A56+A11*A24*A32*A45*A56+A12*A21*A34*A45*A56-A11*A22*                 &
      A34*A45*A56

      COFACTOR(1,4) = -A26*A35*A43*A52*A61+A25*A36*A43*A52*A61+A26*A33*A45*A52*                &
      A61-A23*A36*A45*A52*A61-A25*A33*A46*A52*A61+A23*A35*A46*A52*A61+A26*A35*                 &
      A42*A53*A61-A25*A36*A42*A53*A61-A26*A32*A45*A53*A61+A22*A36*A45*A53*                     &
      A61+A25*A32*A46*A53*A61-A22*A35*A46*A53*A61-A26*A33*A42*A55*A61+A23*A36*                 &
      A42*A55*A61+A26*A32*A43*A55*A61-A22*A36*A43*A55*A61-A23*A32*A46*A55*                     &
      A61+A22*A33*A46*A55*A61+A25*A33*A42*A56*A61-A23*A35*A42*A56*A61-A25*A32*                 &
      A43*A56*A61+A22*A35*A43*A56*A61+A23*A32*A45*A56*A61-A22*A33*A45*A56*                     &
      A61+A26*A35*A43*A51*A62-A25*A36*A43*A51*A62-A26*A33*A45*A51*A62+A23*A36*                 &
      A45*A51*A62+A25*A33*A46*A51*A62-A23*A35*A46*A51*A62-A26*A35*A41*A53*                     &
      A62+A25*A36*A41*A53*A62+A26*A31*A45*A53*A62-A21*A36*A45*A53*A62-A25*A31*                 &
      A46*A53*A62+A21*A35*A46*A53*A62+A26*A33*A41*A55*A62-A23*A36*A41*A55*                     &
      A62-A26*A31*A43*A55*A62+A21*A36*A43*A55*A62+A23*A31*A46*A55*A62-A21*A33*                 &
      A46*A55*A62-A25*A33*A41*A56*A62+A23*A35*A41*A56*A62+A25*A31*A43*A56*                     &
      A62-A21*A35*A43*A56*A62-A23*A31*A45*A56*A62+A21*A33*A45*A56*A62-A26*A35*                 &
      A42*A51*A63+A25*A36*A42*A51*A63+A26*A32*A45*A51*A63-A22*A36*A45*A51*                     &
      A63-A25*A32*A46*A51*A63+A22*A35*A46*A51*A63+A26*A35*A41*A52*A63-A25*A36*                 &
      A41*A52*A63-A26*A31*A45*A52*A63+A21*A36*A45*A52*A63+A25*A31*A46*A52*                     &
      A63-A21*A35*A46*A52*A63-A26*A32*A41*A55*A63+A22*A36*A41*A55*A63+A26*A31*                 &
      A42*A55*A63-A21*A36*A42*A55*A63-A22*A31*A46*A55*A63+A21*A32*A46*A55*                     &
      A63+A25*A32*A41*A56*A63-A22*A35*A41*A56*A63-A25*A31*A42*A56*A63+A21*A35*                 &
      A42*A56*A63+A22*A31*A45*A56*A63-A21*A32*A45*A56*A63+A26*A33*A42*A51*                     &
      A65-A23*A36*A42*A51*A65-A26*A32*A43*A51*A65+A22*A36*A43*A51*A65+A23*A32*                 &
      A46*A51*A65-A22*A33*A46*A51*A65-A26*A33*A41*A52*A65+A23*A36*A41*A52*                     &
      A65+A26*A31*A43*A52*A65-A21*A36*A43*A52*A65-A23*A31*A46*A52*A65+A21*A33*                 &
      A46*A52*A65+A26*A32*A41*A53*A65-A22*A36*A41*A53*A65-A26*A31*A42*A53*                     &
      A65+A21*A36*A42*A53*A65+A22*A31*A46*A53*A65-A21*A32*A46*A53*A65-A23*A32*                 &
      A41*A56*A65+A22*A33*A41*A56*A65+A23*A31*A42*A56*A65-A21*A33*A42*A56*                     &
      A65-A22*A31*A43*A56*A65+A21*A32*A43*A56*A65-A25*A33*A42*A51*A66+A23*A35*                 &
      A42*A51*A66+A25*A32*A43*A51*A66-A22*A35*A43*A51*A66-A23*A32*A45*A51*                     &
      A66+A22*A33*A45*A51*A66+A25*A33*A41*A52*A66-A23*A35*A41*A52*A66-A25*A31*                 &
      A43*A52*A66+A21*A35*A43*A52*A66+A23*A31*A45*A52*A66-A21*A33*A45*A52*                     &
      A66-A25*A32*A41*A53*A66+A22*A35*A41*A53*A66+A25*A31*A42*A53*A66-A21*A35*                 &
      A42*A53*A66-A22*A31*A45*A53*A66+A21*A32*A45*A53*A66+A23*A32*A41*A55*                     &
      A66-A22*A33*A41*A55*A66-A23*A31*A42*A55*A66+A21*A33*A42*A55*A66+A22*A31*                 &
      A43*A55*A66-A21*A32*A43*A55*A66

      COFACTOR(2,4) = A16*A35*A43*A52*A61-A15*A36*A43*A52*                                     &
      A61-A16*A33*A45*A52*A61+A13*A36*A45*A52*A61+A15*A33*A46*A52*A61-A13*A35*                 &
      A46*A52*A61-A16*A35*A42*A53*A61+A15*A36*A42*A53*A61+A16*A32*A45*A53*                     &
      A61-A12*A36*A45*A53*A61-A15*A32*A46*A53*A61+A12*A35*A46*A53*A61+A16*A33*                 &
      A42*A55*A61-A13*A36*A42*A55*A61-A16*A32*A43*A55*A61+A12*A36*A43*A55*                     &
      A61+A13*A32*A46*A55*A61-A12*A33*A46*A55*A61-A15*A33*A42*A56*A61+A13*A35*                 &
      A42*A56*A61+A15*A32*A43*A56*A61-A12*A35*A43*A56*A61-A13*A32*A45*A56*                     &
      A61+A12*A33*A45*A56*A61-A16*A35*A43*A51*A62+A15*A36*A43*A51*A62+A16*A33*                 &
      A45*A51*A62-A13*A36*A45*A51*A62-A15*A33*A46*A51*A62+A13*A35*A46*A51*                     &
      A62+A16*A35*A41*A53*A62-A15*A36*A41*A53*A62-A16*A31*A45*A53*A62+A11*A36*                 &
      A45*A53*A62+A15*A31*A46*A53*A62-A11*A35*A46*A53*A62-A16*A33*A41*A55*                     &
      A62+A13*A36*A41*A55*A62+A16*A31*A43*A55*A62-A11*A36*A43*A55*A62-A13*A31*                 &
      A46*A55*A62+A11*A33*A46*A55*A62+A15*A33*A41*A56*A62-A13*A35*A41*A56*                     &
      A62-A15*A31*A43*A56*A62+A11*A35*A43*A56*A62+A13*A31*A45*A56*A62-A11*A33*                 &
      A45*A56*A62+A16*A35*A42*A51*A63-A15*A36*A42*A51*A63-A16*A32*A45*A51*                     &
      A63+A12*A36*A45*A51*A63+A15*A32*A46*A51*A63-A12*A35*A46*A51*A63-A16*A35*                 &
      A41*A52*A63+A15*A36*A41*A52*A63+A16*A31*A45*A52*A63-A11*A36*A45*A52*                     &
      A63-A15*A31*A46*A52*A63+A11*A35*A46*A52*A63+A16*A32*A41*A55*A63-A12*A36*                 &
      A41*A55*A63-A16*A31*A42*A55*A63+A11*A36*A42*A55*A63+A12*A31*A46*A55*                     &
      A63-A11*A32*A46*A55*A63-A15*A32*A41*A56*A63+A12*A35*A41*A56*A63+A15*A31*                 &
      A42*A56*A63-A11*A35*A42*A56*A63-A12*A31*A45*A56*A63+A11*A32*A45*A56*                     &
      A63-A16*A33*A42*A51*A65+A13*A36*A42*A51*A65+A16*A32*A43*A51*A65-A12*A36*                 &
      A43*A51*A65-A13*A32*A46*A51*A65+A12*A33*A46*A51*A65+A16*A33*A41*A52*                     &
      A65-A13*A36*A41*A52*A65-A16*A31*A43*A52*A65+A11*A36*A43*A52*A65+A13*A31*                 &
      A46*A52*A65-A11*A33*A46*A52*A65-A16*A32*A41*A53*A65+A12*A36*A41*A53*                     &
      A65+A16*A31*A42*A53*A65-A11*A36*A42*A53*A65-A12*A31*A46*A53*A65+A11*A32*                 &
      A46*A53*A65+A13*A32*A41*A56*A65-A12*A33*A41*A56*A65-A13*A31*A42*A56*                     &
      A65+A11*A33*A42*A56*A65+A12*A31*A43*A56*A65-A11*A32*A43*A56*A65+A15*A33*                 &
      A42*A51*A66-A13*A35*A42*A51*A66-A15*A32*A43*A51*A66+A12*A35*A43*A51*                     &
      A66+A13*A32*A45*A51*A66-A12*A33*A45*A51*A66-A15*A33*A41*A52*A66+A13*A35*                 &
      A41*A52*A66+A15*A31*A43*A52*A66-A11*A35*A43*A52*A66-A13*A31*A45*A52*                     &
      A66+A11*A33*A45*A52*A66+A15*A32*A41*A53*A66-A12*A35*A41*A53*A66-A15*A31*                 &
      A42*A53*A66+A11*A35*A42*A53*A66+A12*A31*A45*A53*A66-A11*A32*A45*A53*                     &
      A66-A13*A32*A41*A55*A66+A12*A33*A41*A55*A66+A13*A31*A42*A55*A66-A11*A33*                 &
      A42*A55*A66-A12*A31*A43*A55*A66+A11*A32*A43*A55*A66

      COFACTOR(3,4) = -A16*A25*A43*A52*                                                        &
      A61+A15*A26*A43*A52*A61+A16*A23*A45*A52*A61-A13*A26*A45*A52*A61-A15*A23*                 &
      A46*A52*A61+A13*A25*A46*A52*A61+A16*A25*A42*A53*A61-A15*A26*A42*A53*                     &
      A61-A16*A22*A45*A53*A61+A12*A26*A45*A53*A61+A15*A22*A46*A53*A61-A12*A25*                 &
      A46*A53*A61-A16*A23*A42*A55*A61+A13*A26*A42*A55*A61+A16*A22*A43*A55*                     &
      A61-A12*A26*A43*A55*A61-A13*A22*A46*A55*A61+A12*A23*A46*A55*A61+A15*A23*                 &
      A42*A56*A61-A13*A25*A42*A56*A61-A15*A22*A43*A56*A61+A12*A25*A43*A56*                     &
      A61+A13*A22*A45*A56*A61-A12*A23*A45*A56*A61+A16*A25*A43*A51*A62-A15*A26*                 &
      A43*A51*A62-A16*A23*A45*A51*A62+A13*A26*A45*A51*A62+A15*A23*A46*A51*                     &
      A62-A13*A25*A46*A51*A62-A16*A25*A41*A53*A62+A15*A26*A41*A53*A62+A16*A21*                 &
      A45*A53*A62-A11*A26*A45*A53*A62-A15*A21*A46*A53*A62+A11*A25*A46*A53*                     &
      A62+A16*A23*A41*A55*A62-A13*A26*A41*A55*A62-A16*A21*A43*A55*A62+A11*A26*                 &
      A43*A55*A62+A13*A21*A46*A55*A62-A11*A23*A46*A55*A62-A15*A23*A41*A56*                     &
      A62+A13*A25*A41*A56*A62+A15*A21*A43*A56*A62-A11*A25*A43*A56*A62-A13*A21*                 &
      A45*A56*A62+A11*A23*A45*A56*A62-A16*A25*A42*A51*A63+A15*A26*A42*A51*                     &
      A63+A16*A22*A45*A51*A63-A12*A26*A45*A51*A63-A15*A22*A46*A51*A63+A12*A25*                 &
      A46*A51*A63+A16*A25*A41*A52*A63-A15*A26*A41*A52*A63-A16*A21*A45*A52*                     &
      A63+A11*A26*A45*A52*A63+A15*A21*A46*A52*A63-A11*A25*A46*A52*A63-A16*A22*                 &
      A41*A55*A63+A12*A26*A41*A55*A63+A16*A21*A42*A55*A63-A11*A26*A42*A55*                     &
      A63-A12*A21*A46*A55*A63+A11*A22*A46*A55*A63+A15*A22*A41*A56*A63-A12*A25*                 &
      A41*A56*A63-A15*A21*A42*A56*A63+A11*A25*A42*A56*A63+A12*A21*A45*A56*                     &
      A63-A11*A22*A45*A56*A63+A16*A23*A42*A51*A65-A13*A26*A42*A51*A65-A16*A22*                 &
      A43*A51*A65+A12*A26*A43*A51*A65+A13*A22*A46*A51*A65-A12*A23*A46*A51*                     &
      A65-A16*A23*A41*A52*A65+A13*A26*A41*A52*A65+A16*A21*A43*A52*A65-A11*A26*                 &
      A43*A52*A65-A13*A21*A46*A52*A65+A11*A23*A46*A52*A65+A16*A22*A41*A53*                     &
      A65-A12*A26*A41*A53*A65-A16*A21*A42*A53*A65+A11*A26*A42*A53*A65+A12*A21*                 &
      A46*A53*A65-A11*A22*A46*A53*A65-A13*A22*A41*A56*A65+A12*A23*A41*A56*                     &
      A65+A13*A21*A42*A56*A65-A11*A23*A42*A56*A65-A12*A21*A43*A56*A65+A11*A22*                 &
      A43*A56*A65-A15*A23*A42*A51*A66+A13*A25*A42*A51*A66+A15*A22*A43*A51*                     &
      A66-A12*A25*A43*A51*A66-A13*A22*A45*A51*A66+A12*A23*A45*A51*A66+A15*A23*                 &
      A41*A52*A66-A13*A25*A41*A52*A66-A15*A21*A43*A52*A66+A11*A25*A43*A52*                     &
      A66+A13*A21*A45*A52*A66-A11*A23*A45*A52*A66-A15*A22*A41*A53*A66+A12*A25*                 &
      A41*A53*A66+A15*A21*A42*A53*A66-A11*A25*A42*A53*A66-A12*A21*A45*A53*                     &
      A66+A11*A22*A45*A53*A66+A13*A22*A41*A55*A66-A12*A23*A41*A55*A66-A13*A21*                 &
      A42*A55*A66+A11*A23*A42*A55*A66+A12*A21*A43*A55*A66-A11*A22*A43*A55*                     &
      A66

      COFACTOR(4,4) = A16*A25*A33*A52*A61-A15*A26*A33*A52*A61-A16*A23*A35*A52*A61+A13*A26*     &
      A35*A52*A61+A15*A23*A36*A52*A61-A13*A25*A36*A52*A61-A16*A25*A32*A53*                     &
      A61+A15*A26*A32*A53*A61+A16*A22*A35*A53*A61-A12*A26*A35*A53*A61-A15*A22*                 &
      A36*A53*A61+A12*A25*A36*A53*A61+A16*A23*A32*A55*A61-A13*A26*A32*A55*                     &
      A61-A16*A22*A33*A55*A61+A12*A26*A33*A55*A61+A13*A22*A36*A55*A61-A12*A23*                 &
      A36*A55*A61-A15*A23*A32*A56*A61+A13*A25*A32*A56*A61+A15*A22*A33*A56*                     &
      A61-A12*A25*A33*A56*A61-A13*A22*A35*A56*A61+A12*A23*A35*A56*A61-A16*A25*                 &
      A33*A51*A62+A15*A26*A33*A51*A62+A16*A23*A35*A51*A62-A13*A26*A35*A51*                     &
      A62-A15*A23*A36*A51*A62+A13*A25*A36*A51*A62+A16*A25*A31*A53*A62-A15*A26*                 &
      A31*A53*A62-A16*A21*A35*A53*A62+A11*A26*A35*A53*A62+A15*A21*A36*A53*                     &
      A62-A11*A25*A36*A53*A62-A16*A23*A31*A55*A62+A13*A26*A31*A55*A62+A16*A21*                 &
      A33*A55*A62-A11*A26*A33*A55*A62-A13*A21*A36*A55*A62+A11*A23*A36*A55*                     &
      A62+A15*A23*A31*A56*A62-A13*A25*A31*A56*A62-A15*A21*A33*A56*A62+A11*A25*                 &
      A33*A56*A62+A13*A21*A35*A56*A62-A11*A23*A35*A56*A62+A16*A25*A32*A51*                     &
      A63-A15*A26*A32*A51*A63-A16*A22*A35*A51*A63+A12*A26*A35*A51*A63+A15*A22*                 &
      A36*A51*A63-A12*A25*A36*A51*A63-A16*A25*A31*A52*A63+A15*A26*A31*A52*                     &
      A63+A16*A21*A35*A52*A63-A11*A26*A35*A52*A63-A15*A21*A36*A52*A63+A11*A25*                 &
      A36*A52*A63+A16*A22*A31*A55*A63-A12*A26*A31*A55*A63-A16*A21*A32*A55*                     &
      A63+A11*A26*A32*A55*A63+A12*A21*A36*A55*A63-A11*A22*A36*A55*A63-A15*A22*                 &
      A31*A56*A63+A12*A25*A31*A56*A63+A15*A21*A32*A56*A63-A11*A25*A32*A56*                     &
      A63-A12*A21*A35*A56*A63+A11*A22*A35*A56*A63-A16*A23*A32*A51*A65+A13*A26*                 &
      A32*A51*A65+A16*A22*A33*A51*A65-A12*A26*A33*A51*A65-A13*A22*A36*A51*                     &
      A65+A12*A23*A36*A51*A65+A16*A23*A31*A52*A65-A13*A26*A31*A52*A65-A16*A21*                 &
      A33*A52*A65+A11*A26*A33*A52*A65+A13*A21*A36*A52*A65-A11*A23*A36*A52*                     &
      A65-A16*A22*A31*A53*A65+A12*A26*A31*A53*A65+A16*A21*A32*A53*A65-A11*A26*                 &
      A32*A53*A65-A12*A21*A36*A53*A65+A11*A22*A36*A53*A65+A13*A22*A31*A56*                     &
      A65-A12*A23*A31*A56*A65-A13*A21*A32*A56*A65+A11*A23*A32*A56*A65+A12*A21*                 &
      A33*A56*A65-A11*A22*A33*A56*A65+A15*A23*A32*A51*A66-A13*A25*A32*A51*                     &
      A66-A15*A22*A33*A51*A66+A12*A25*A33*A51*A66+A13*A22*A35*A51*A66-A12*A23*                 &
      A35*A51*A66-A15*A23*A31*A52*A66+A13*A25*A31*A52*A66+A15*A21*A33*A52*                     &
      A66-A11*A25*A33*A52*A66-A13*A21*A35*A52*A66+A11*A23*A35*A52*A66+A15*A22*                 &
      A31*A53*A66-A12*A25*A31*A53*A66-A15*A21*A32*A53*A66+A11*A25*A32*A53*                     &
      A66+A12*A21*A35*A53*A66-A11*A22*A35*A53*A66-A13*A22*A31*A55*A66+A12*A23*                 &
      A31*A55*A66+A13*A21*A32*A55*A66-A11*A23*A32*A55*A66-A12*A21*A33*A55*                     &
      A66+A11*A22*A33*A55*A66

      COFACTOR(5,4) = -A16*A25*A33*A42*A61+A15*A26*A33*A42*A61+A16*A23*                        &
      A35*A42*A61-A13*A26*A35*A42*A61-A15*A23*A36*A42*A61+A13*A25*A36*A42*                     &
      A61+A16*A25*A32*A43*A61-A15*A26*A32*A43*A61-A16*A22*A35*A43*A61+A12*A26*                 &
      A35*A43*A61+A15*A22*A36*A43*A61-A12*A25*A36*A43*A61-A16*A23*A32*A45*                     &
      A61+A13*A26*A32*A45*A61+A16*A22*A33*A45*A61-A12*A26*A33*A45*A61-A13*A22*                 &
      A36*A45*A61+A12*A23*A36*A45*A61+A15*A23*A32*A46*A61-A13*A25*A32*A46*                     &
      A61-A15*A22*A33*A46*A61+A12*A25*A33*A46*A61+A13*A22*A35*A46*A61-A12*A23*                 &
      A35*A46*A61+A16*A25*A33*A41*A62-A15*A26*A33*A41*A62-A16*A23*A35*A41*                     &
      A62+A13*A26*A35*A41*A62+A15*A23*A36*A41*A62-A13*A25*A36*A41*A62-A16*A25*                 &
      A31*A43*A62+A15*A26*A31*A43*A62+A16*A21*A35*A43*A62-A11*A26*A35*A43*                     &
      A62-A15*A21*A36*A43*A62+A11*A25*A36*A43*A62+A16*A23*A31*A45*A62-A13*A26*                 &
      A31*A45*A62-A16*A21*A33*A45*A62+A11*A26*A33*A45*A62+A13*A21*A36*A45*                     &
      A62-A11*A23*A36*A45*A62-A15*A23*A31*A46*A62+A13*A25*A31*A46*A62+A15*A21*                 &
      A33*A46*A62-A11*A25*A33*A46*A62-A13*A21*A35*A46*A62+A11*A23*A35*A46*                     &
      A62-A16*A25*A32*A41*A63+A15*A26*A32*A41*A63+A16*A22*A35*A41*A63-A12*A26*                 &
      A35*A41*A63-A15*A22*A36*A41*A63+A12*A25*A36*A41*A63+A16*A25*A31*A42*                     &
      A63-A15*A26*A31*A42*A63-A16*A21*A35*A42*A63+A11*A26*A35*A42*A63+A15*A21*                 &
      A36*A42*A63-A11*A25*A36*A42*A63-A16*A22*A31*A45*A63+A12*A26*A31*A45*                     &
      A63+A16*A21*A32*A45*A63-A11*A26*A32*A45*A63-A12*A21*A36*A45*A63+A11*A22*                 &
      A36*A45*A63+A15*A22*A31*A46*A63-A12*A25*A31*A46*A63-A15*A21*A32*A46*                     &
      A63+A11*A25*A32*A46*A63+A12*A21*A35*A46*A63-A11*A22*A35*A46*A63+A16*A23*                 &
      A32*A41*A65-A13*A26*A32*A41*A65-A16*A22*A33*A41*A65+A12*A26*A33*A41*                     &
      A65+A13*A22*A36*A41*A65-A12*A23*A36*A41*A65-A16*A23*A31*A42*A65+A13*A26*                 &
      A31*A42*A65+A16*A21*A33*A42*A65-A11*A26*A33*A42*A65-A13*A21*A36*A42*                     &
      A65+A11*A23*A36*A42*A65+A16*A22*A31*A43*A65-A12*A26*A31*A43*A65-A16*A21*                 &
      A32*A43*A65+A11*A26*A32*A43*A65+A12*A21*A36*A43*A65-A11*A22*A36*A43*                     &
      A65-A13*A22*A31*A46*A65+A12*A23*A31*A46*A65+A13*A21*A32*A46*A65-A11*A23*                 &
      A32*A46*A65-A12*A21*A33*A46*A65+A11*A22*A33*A46*A65-A15*A23*A32*A41*                     &
      A66+A13*A25*A32*A41*A66+A15*A22*A33*A41*A66-A12*A25*A33*A41*A66-A13*A22*                 &
      A35*A41*A66+A12*A23*A35*A41*A66+A15*A23*A31*A42*A66-A13*A25*A31*A42*                     &
      A66-A15*A21*A33*A42*A66+A11*A25*A33*A42*A66+A13*A21*A35*A42*A66-A11*A23*                 &
      A35*A42*A66-A15*A22*A31*A43*A66+A12*A25*A31*A43*A66+A15*A21*A32*A43*                     &
      A66-A11*A25*A32*A43*A66-A12*A21*A35*A43*A66+A11*A22*A35*A43*A66+A13*A22*                 &
      A31*A45*A66-A12*A23*A31*A45*A66-A13*A21*A32*A45*A66+A11*A23*A32*A45*                     &
      A66+A12*A21*A33*A45*A66-A11*A22*A33*A45*A66

      COFACTOR(6,4) = A16*A25*A33*A42*A51-A15*A26*                                             &
      A33*A42*A51-A16*A23*A35*A42*A51+A13*A26*A35*A42*A51+A15*A23*A36*A42*                     &
      A51-A13*A25*A36*A42*A51-A16*A25*A32*A43*A51+A15*A26*A32*A43*A51+A16*A22*                 &
      A35*A43*A51-A12*A26*A35*A43*A51-A15*A22*A36*A43*A51+A12*A25*A36*A43*                     &
      A51+A16*A23*A32*A45*A51-A13*A26*A32*A45*A51-A16*A22*A33*A45*A51+A12*A26*                 &
      A33*A45*A51+A13*A22*A36*A45*A51-A12*A23*A36*A45*A51-A15*A23*A32*A46*                     &
      A51+A13*A25*A32*A46*A51+A15*A22*A33*A46*A51-A12*A25*A33*A46*A51-A13*A22*                 &
      A35*A46*A51+A12*A23*A35*A46*A51-A16*A25*A33*A41*A52+A15*A26*A33*A41*                     &
      A52+A16*A23*A35*A41*A52-A13*A26*A35*A41*A52-A15*A23*A36*A41*A52+A13*A25*                 &
      A36*A41*A52+A16*A25*A31*A43*A52-A15*A26*A31*A43*A52-A16*A21*A35*A43*                     &
      A52+A11*A26*A35*A43*A52+A15*A21*A36*A43*A52-A11*A25*A36*A43*A52-A16*A23*                 &
      A31*A45*A52+A13*A26*A31*A45*A52+A16*A21*A33*A45*A52-A11*A26*A33*A45*                     &
      A52-A13*A21*A36*A45*A52+A11*A23*A36*A45*A52+A15*A23*A31*A46*A52-A13*A25*                 &
      A31*A46*A52-A15*A21*A33*A46*A52+A11*A25*A33*A46*A52+A13*A21*A35*A46*                     &
      A52-A11*A23*A35*A46*A52+A16*A25*A32*A41*A53-A15*A26*A32*A41*A53-A16*A22*                 &
      A35*A41*A53+A12*A26*A35*A41*A53+A15*A22*A36*A41*A53-A12*A25*A36*A41*                     &
      A53-A16*A25*A31*A42*A53+A15*A26*A31*A42*A53+A16*A21*A35*A42*A53-A11*A26*                 &
      A35*A42*A53-A15*A21*A36*A42*A53+A11*A25*A36*A42*A53+A16*A22*A31*A45*                     &
      A53-A12*A26*A31*A45*A53-A16*A21*A32*A45*A53+A11*A26*A32*A45*A53+A12*A21*                 &
      A36*A45*A53-A11*A22*A36*A45*A53-A15*A22*A31*A46*A53+A12*A25*A31*A46*                     &
      A53+A15*A21*A32*A46*A53-A11*A25*A32*A46*A53-A12*A21*A35*A46*A53+A11*A22*                 &
      A35*A46*A53-A16*A23*A32*A41*A55+A13*A26*A32*A41*A55+A16*A22*A33*A41*                     &
      A55-A12*A26*A33*A41*A55-A13*A22*A36*A41*A55+A12*A23*A36*A41*A55+A16*A23*                 &
      A31*A42*A55-A13*A26*A31*A42*A55-A16*A21*A33*A42*A55+A11*A26*A33*A42*                     &
      A55+A13*A21*A36*A42*A55-A11*A23*A36*A42*A55-A16*A22*A31*A43*A55+A12*A26*                 &
      A31*A43*A55+A16*A21*A32*A43*A55-A11*A26*A32*A43*A55-A12*A21*A36*A43*                     &
      A55+A11*A22*A36*A43*A55+A13*A22*A31*A46*A55-A12*A23*A31*A46*A55-A13*A21*                 &
      A32*A46*A55+A11*A23*A32*A46*A55+A12*A21*A33*A46*A55-A11*A22*A33*A46*                     &
      A55+A15*A23*A32*A41*A56-A13*A25*A32*A41*A56-A15*A22*A33*A41*A56+A12*A25*                 &
      A33*A41*A56+A13*A22*A35*A41*A56-A12*A23*A35*A41*A56-A15*A23*A31*A42*                     &
      A56+A13*A25*A31*A42*A56+A15*A21*A33*A42*A56-A11*A25*A33*A42*A56-A13*A21*                 &
      A35*A42*A56+A11*A23*A35*A42*A56+A15*A22*A31*A43*A56-A12*A25*A31*A43*                     &
      A56-A15*A21*A32*A43*A56+A11*A25*A32*A43*A56+A12*A21*A35*A43*A56-A11*A22*                 &
      A35*A43*A56-A13*A22*A31*A45*A56+A12*A23*A31*A45*A56+A13*A21*A32*A45*                     &
      A56-A11*A23*A32*A45*A56-A12*A21*A33*A45*A56+A11*A22*A33*A45*A56

      COFACTOR(1,5) = A26*                                                                     &
      A34*A43*A52*A61-A24*A36*A43*A52*A61-A26*A33*A44*A52*A61+A23*A36*A44*A52*                 &
      A61+A24*A33*A46*A52*A61-A23*A34*A46*A52*A61-A26*A34*A42*A53*A61+A24*A36*                 &
      A42*A53*A61+A26*A32*A44*A53*A61-A22*A36*A44*A53*A61-A24*A32*A46*A53*                     &
      A61+A22*A34*A46*A53*A61+A26*A33*A42*A54*A61-A23*A36*A42*A54*A61-A26*A32*                 &
      A43*A54*A61+A22*A36*A43*A54*A61+A23*A32*A46*A54*A61-A22*A33*A46*A54*                     &
      A61-A24*A33*A42*A56*A61+A23*A34*A42*A56*A61+A24*A32*A43*A56*A61-A22*A34*                 &
      A43*A56*A61-A23*A32*A44*A56*A61+A22*A33*A44*A56*A61-A26*A34*A43*A51*                     &
      A62+A24*A36*A43*A51*A62+A26*A33*A44*A51*A62-A23*A36*A44*A51*A62-A24*A33*                 &
      A46*A51*A62+A23*A34*A46*A51*A62+A26*A34*A41*A53*A62-A24*A36*A41*A53*                     &
      A62-A26*A31*A44*A53*A62+A21*A36*A44*A53*A62+A24*A31*A46*A53*A62-A21*A34*                 &
      A46*A53*A62-A26*A33*A41*A54*A62+A23*A36*A41*A54*A62+A26*A31*A43*A54*                     &
      A62-A21*A36*A43*A54*A62-A23*A31*A46*A54*A62+A21*A33*A46*A54*A62+A24*A33*                 &
      A41*A56*A62-A23*A34*A41*A56*A62-A24*A31*A43*A56*A62+A21*A34*A43*A56*                     &
      A62+A23*A31*A44*A56*A62-A21*A33*A44*A56*A62+A26*A34*A42*A51*A63-A24*A36*                 &
      A42*A51*A63-A26*A32*A44*A51*A63+A22*A36*A44*A51*A63+A24*A32*A46*A51*                     &
      A63-A22*A34*A46*A51*A63-A26*A34*A41*A52*A63+A24*A36*A41*A52*A63+A26*A31*                 &
      A44*A52*A63-A21*A36*A44*A52*A63-A24*A31*A46*A52*A63+A21*A34*A46*A52*                     &
      A63+A26*A32*A41*A54*A63-A22*A36*A41*A54*A63-A26*A31*A42*A54*A63+A21*A36*                 &
      A42*A54*A63+A22*A31*A46*A54*A63-A21*A32*A46*A54*A63-A24*A32*A41*A56*                     &
      A63+A22*A34*A41*A56*A63+A24*A31*A42*A56*A63-A21*A34*A42*A56*A63-A22*A31*                 &
      A44*A56*A63+A21*A32*A44*A56*A63-A26*A33*A42*A51*A64+A23*A36*A42*A51*                     &
      A64+A26*A32*A43*A51*A64-A22*A36*A43*A51*A64-A23*A32*A46*A51*A64+A22*A33*                 &
      A46*A51*A64+A26*A33*A41*A52*A64-A23*A36*A41*A52*A64-A26*A31*A43*A52*                     &
      A64+A21*A36*A43*A52*A64+A23*A31*A46*A52*A64-A21*A33*A46*A52*A64-A26*A32*                 &
      A41*A53*A64+A22*A36*A41*A53*A64+A26*A31*A42*A53*A64-A21*A36*A42*A53*                     &
      A64-A22*A31*A46*A53*A64+A21*A32*A46*A53*A64+A23*A32*A41*A56*A64-A22*A33*                 &
      A41*A56*A64-A23*A31*A42*A56*A64+A21*A33*A42*A56*A64+A22*A31*A43*A56*                     &
      A64-A21*A32*A43*A56*A64+A24*A33*A42*A51*A66-A23*A34*A42*A51*A66-A24*A32*                 &
      A43*A51*A66+A22*A34*A43*A51*A66+A23*A32*A44*A51*A66-A22*A33*A44*A51*                     &
      A66-A24*A33*A41*A52*A66+A23*A34*A41*A52*A66+A24*A31*A43*A52*A66-A21*A34*                 &
      A43*A52*A66-A23*A31*A44*A52*A66+A21*A33*A44*A52*A66+A24*A32*A41*A53*                     &
      A66-A22*A34*A41*A53*A66-A24*A31*A42*A53*A66+A21*A34*A42*A53*A66+A22*A31*                 &
      A44*A53*A66-A21*A32*A44*A53*A66-A23*A32*A41*A54*A66+A22*A33*A41*A54*                     &
      A66+A23*A31*A42*A54*A66-A21*A33*A42*A54*A66-A22*A31*A43*A54*A66+A21*A32*                 &
      A43*A54*A66

      COFACTOR(2,5) = -A16*A34*A43*A52*A61+A14*A36*A43*A52*A61+A16*A33*A44*A52*                &
      A61-A13*A36*A44*A52*A61-A14*A33*A46*A52*A61+A13*A34*A46*A52*A61+A16*A34*                 &
      A42*A53*A61-A14*A36*A42*A53*A61-A16*A32*A44*A53*A61+A12*A36*A44*A53*                     &
      A61+A14*A32*A46*A53*A61-A12*A34*A46*A53*A61-A16*A33*A42*A54*A61+A13*A36*                 &
      A42*A54*A61+A16*A32*A43*A54*A61-A12*A36*A43*A54*A61-A13*A32*A46*A54*                     &
      A61+A12*A33*A46*A54*A61+A14*A33*A42*A56*A61-A13*A34*A42*A56*A61-A14*A32*                 &
      A43*A56*A61+A12*A34*A43*A56*A61+A13*A32*A44*A56*A61-A12*A33*A44*A56*                     &
      A61+A16*A34*A43*A51*A62-A14*A36*A43*A51*A62-A16*A33*A44*A51*A62+A13*A36*                 &
      A44*A51*A62+A14*A33*A46*A51*A62-A13*A34*A46*A51*A62-A16*A34*A41*A53*                     &
      A62+A14*A36*A41*A53*A62+A16*A31*A44*A53*A62-A11*A36*A44*A53*A62-A14*A31*                 &
      A46*A53*A62+A11*A34*A46*A53*A62+A16*A33*A41*A54*A62-A13*A36*A41*A54*                     &
      A62-A16*A31*A43*A54*A62+A11*A36*A43*A54*A62+A13*A31*A46*A54*A62-A11*A33*                 &
      A46*A54*A62-A14*A33*A41*A56*A62+A13*A34*A41*A56*A62+A14*A31*A43*A56*                     &
      A62-A11*A34*A43*A56*A62-A13*A31*A44*A56*A62+A11*A33*A44*A56*A62-A16*A34*                 &
      A42*A51*A63+A14*A36*A42*A51*A63+A16*A32*A44*A51*A63-A12*A36*A44*A51*                     &
      A63-A14*A32*A46*A51*A63+A12*A34*A46*A51*A63+A16*A34*A41*A52*A63-A14*A36*                 &
      A41*A52*A63-A16*A31*A44*A52*A63+A11*A36*A44*A52*A63+A14*A31*A46*A52*                     &
      A63-A11*A34*A46*A52*A63-A16*A32*A41*A54*A63+A12*A36*A41*A54*A63+A16*A31*                 &
      A42*A54*A63-A11*A36*A42*A54*A63-A12*A31*A46*A54*A63+A11*A32*A46*A54*                     &
      A63+A14*A32*A41*A56*A63-A12*A34*A41*A56*A63-A14*A31*A42*A56*A63+A11*A34*                 &
      A42*A56*A63+A12*A31*A44*A56*A63-A11*A32*A44*A56*A63+A16*A33*A42*A51*                     &
      A64-A13*A36*A42*A51*A64-A16*A32*A43*A51*A64+A12*A36*A43*A51*A64+A13*A32*                 &
      A46*A51*A64-A12*A33*A46*A51*A64-A16*A33*A41*A52*A64+A13*A36*A41*A52*                     &
      A64+A16*A31*A43*A52*A64-A11*A36*A43*A52*A64-A13*A31*A46*A52*A64+A11*A33*                 &
      A46*A52*A64+A16*A32*A41*A53*A64-A12*A36*A41*A53*A64-A16*A31*A42*A53*                     &
      A64+A11*A36*A42*A53*A64+A12*A31*A46*A53*A64-A11*A32*A46*A53*A64-A13*A32*                 &
      A41*A56*A64+A12*A33*A41*A56*A64+A13*A31*A42*A56*A64-A11*A33*A42*A56*                     &
      A64-A12*A31*A43*A56*A64+A11*A32*A43*A56*A64-A14*A33*A42*A51*A66+A13*A34*                 &
      A42*A51*A66+A14*A32*A43*A51*A66-A12*A34*A43*A51*A66-A13*A32*A44*A51*                     &
      A66+A12*A33*A44*A51*A66+A14*A33*A41*A52*A66-A13*A34*A41*A52*A66-A14*A31*                 &
      A43*A52*A66+A11*A34*A43*A52*A66+A13*A31*A44*A52*A66-A11*A33*A44*A52*                     &
      A66-A14*A32*A41*A53*A66+A12*A34*A41*A53*A66+A14*A31*A42*A53*A66-A11*A34*                 &
      A42*A53*A66-A12*A31*A44*A53*A66+A11*A32*A44*A53*A66+A13*A32*A41*A54*                     &
      A66-A12*A33*A41*A54*A66-A13*A31*A42*A54*A66+A11*A33*A42*A54*A66+A12*A31*                 &
      A43*A54*A66-A11*A32*A43*A54*A66

      COFACTOR(3,5) = A16*A24*A43*A52*A61-A14*A26*A43*A52*                                     &
      A61-A16*A23*A44*A52*A61+A13*A26*A44*A52*A61+A14*A23*A46*A52*A61-A13*A24*                 &
      A46*A52*A61-A16*A24*A42*A53*A61+A14*A26*A42*A53*A61+A16*A22*A44*A53*                     &
      A61-A12*A26*A44*A53*A61-A14*A22*A46*A53*A61+A12*A24*A46*A53*A61+A16*A23*                 &
      A42*A54*A61-A13*A26*A42*A54*A61-A16*A22*A43*A54*A61+A12*A26*A43*A54*                     &
      A61+A13*A22*A46*A54*A61-A12*A23*A46*A54*A61-A14*A23*A42*A56*A61+A13*A24*                 &
      A42*A56*A61+A14*A22*A43*A56*A61-A12*A24*A43*A56*A61-A13*A22*A44*A56*                     &
      A61+A12*A23*A44*A56*A61-A16*A24*A43*A51*A62+A14*A26*A43*A51*A62+A16*A23*                 &
      A44*A51*A62-A13*A26*A44*A51*A62-A14*A23*A46*A51*A62+A13*A24*A46*A51*                     &
      A62+A16*A24*A41*A53*A62-A14*A26*A41*A53*A62-A16*A21*A44*A53*A62+A11*A26*                 &
      A44*A53*A62+A14*A21*A46*A53*A62-A11*A24*A46*A53*A62-A16*A23*A41*A54*                     &
      A62+A13*A26*A41*A54*A62+A16*A21*A43*A54*A62-A11*A26*A43*A54*A62-A13*A21*                 &
      A46*A54*A62+A11*A23*A46*A54*A62+A14*A23*A41*A56*A62-A13*A24*A41*A56*                     &
      A62-A14*A21*A43*A56*A62+A11*A24*A43*A56*A62+A13*A21*A44*A56*A62-A11*A23*                 &
      A44*A56*A62+A16*A24*A42*A51*A63-A14*A26*A42*A51*A63-A16*A22*A44*A51*                     &
      A63+A12*A26*A44*A51*A63+A14*A22*A46*A51*A63-A12*A24*A46*A51*A63-A16*A24*                 &
      A41*A52*A63+A14*A26*A41*A52*A63+A16*A21*A44*A52*A63-A11*A26*A44*A52*                     &
      A63-A14*A21*A46*A52*A63+A11*A24*A46*A52*A63+A16*A22*A41*A54*A63-A12*A26*                 &
      A41*A54*A63-A16*A21*A42*A54*A63+A11*A26*A42*A54*A63+A12*A21*A46*A54*                     &
      A63-A11*A22*A46*A54*A63-A14*A22*A41*A56*A63+A12*A24*A41*A56*A63+A14*A21*                 &
      A42*A56*A63-A11*A24*A42*A56*A63-A12*A21*A44*A56*A63+A11*A22*A44*A56*                     &
      A63-A16*A23*A42*A51*A64+A13*A26*A42*A51*A64+A16*A22*A43*A51*A64-A12*A26*                 &
      A43*A51*A64-A13*A22*A46*A51*A64+A12*A23*A46*A51*A64+A16*A23*A41*A52*                     &
      A64-A13*A26*A41*A52*A64-A16*A21*A43*A52*A64+A11*A26*A43*A52*A64+A13*A21*                 &
      A46*A52*A64-A11*A23*A46*A52*A64-A16*A22*A41*A53*A64+A12*A26*A41*A53*                     &
      A64+A16*A21*A42*A53*A64-A11*A26*A42*A53*A64-A12*A21*A46*A53*A64+A11*A22*                 &
      A46*A53*A64+A13*A22*A41*A56*A64-A12*A23*A41*A56*A64-A13*A21*A42*A56*                     &
      A64+A11*A23*A42*A56*A64+A12*A21*A43*A56*A64-A11*A22*A43*A56*A64+A14*A23*                 &
      A42*A51*A66-A13*A24*A42*A51*A66-A14*A22*A43*A51*A66+A12*A24*A43*A51*                     &
      A66+A13*A22*A44*A51*A66-A12*A23*A44*A51*A66-A14*A23*A41*A52*A66+A13*A24*                 &
      A41*A52*A66+A14*A21*A43*A52*A66-A11*A24*A43*A52*A66-A13*A21*A44*A52*                     &
      A66+A11*A23*A44*A52*A66+A14*A22*A41*A53*A66-A12*A24*A41*A53*A66-A14*A21*                 &
      A42*A53*A66+A11*A24*A42*A53*A66+A12*A21*A44*A53*A66-A11*A22*A44*A53*                     &
      A66-A13*A22*A41*A54*A66+A12*A23*A41*A54*A66+A13*A21*A42*A54*A66-A11*A23*                 &
      A42*A54*A66-A12*A21*A43*A54*A66+A11*A22*A43*A54*A66

      COFACTOR(4,5) = -A16*A24*A33*A52*                                                        &
      A61+A14*A26*A33*A52*A61+A16*A23*A34*A52*A61-A13*A26*A34*A52*A61-A14*A23*                 &
      A36*A52*A61+A13*A24*A36*A52*A61+A16*A24*A32*A53*A61-A14*A26*A32*A53*                     &
      A61-A16*A22*A34*A53*A61+A12*A26*A34*A53*A61+A14*A22*A36*A53*A61-A12*A24*                 &
      A36*A53*A61-A16*A23*A32*A54*A61+A13*A26*A32*A54*A61+A16*A22*A33*A54*                     &
      A61-A12*A26*A33*A54*A61-A13*A22*A36*A54*A61+A12*A23*A36*A54*A61+A14*A23*                 &
      A32*A56*A61-A13*A24*A32*A56*A61-A14*A22*A33*A56*A61+A12*A24*A33*A56*                     &
      A61+A13*A22*A34*A56*A61-A12*A23*A34*A56*A61+A16*A24*A33*A51*A62-A14*A26*                 &
      A33*A51*A62-A16*A23*A34*A51*A62+A13*A26*A34*A51*A62+A14*A23*A36*A51*                     &
      A62-A13*A24*A36*A51*A62-A16*A24*A31*A53*A62+A14*A26*A31*A53*A62+A16*A21*                 &
      A34*A53*A62-A11*A26*A34*A53*A62-A14*A21*A36*A53*A62+A11*A24*A36*A53*                     &
      A62+A16*A23*A31*A54*A62-A13*A26*A31*A54*A62-A16*A21*A33*A54*A62+A11*A26*                 &
      A33*A54*A62+A13*A21*A36*A54*A62-A11*A23*A36*A54*A62-A14*A23*A31*A56*                     &
      A62+A13*A24*A31*A56*A62+A14*A21*A33*A56*A62-A11*A24*A33*A56*A62-A13*A21*                 &
      A34*A56*A62+A11*A23*A34*A56*A62-A16*A24*A32*A51*A63+A14*A26*A32*A51*                     &
      A63+A16*A22*A34*A51*A63-A12*A26*A34*A51*A63-A14*A22*A36*A51*A63+A12*A24*                 &
      A36*A51*A63+A16*A24*A31*A52*A63-A14*A26*A31*A52*A63-A16*A21*A34*A52*                     &
      A63+A11*A26*A34*A52*A63+A14*A21*A36*A52*A63-A11*A24*A36*A52*A63-A16*A22*                 &
      A31*A54*A63+A12*A26*A31*A54*A63+A16*A21*A32*A54*A63-A11*A26*A32*A54*                     &
      A63-A12*A21*A36*A54*A63+A11*A22*A36*A54*A63+A14*A22*A31*A56*A63-A12*A24*                 &
      A31*A56*A63-A14*A21*A32*A56*A63+A11*A24*A32*A56*A63+A12*A21*A34*A56*                     &
      A63-A11*A22*A34*A56*A63+A16*A23*A32*A51*A64-A13*A26*A32*A51*A64-A16*A22*                 &
      A33*A51*A64+A12*A26*A33*A51*A64+A13*A22*A36*A51*A64-A12*A23*A36*A51*                     &
      A64-A16*A23*A31*A52*A64+A13*A26*A31*A52*A64+A16*A21*A33*A52*A64-A11*A26*                 &
      A33*A52*A64-A13*A21*A36*A52*A64+A11*A23*A36*A52*A64+A16*A22*A31*A53*                     &
      A64-A12*A26*A31*A53*A64-A16*A21*A32*A53*A64+A11*A26*A32*A53*A64+A12*A21*                 &
      A36*A53*A64-A11*A22*A36*A53*A64-A13*A22*A31*A56*A64+A12*A23*A31*A56*                     &
      A64+A13*A21*A32*A56*A64-A11*A23*A32*A56*A64-A12*A21*A33*A56*A64+A11*A22*                 &
      A33*A56*A64-A14*A23*A32*A51*A66+A13*A24*A32*A51*A66+A14*A22*A33*A51*                     &
      A66-A12*A24*A33*A51*A66-A13*A22*A34*A51*A66+A12*A23*A34*A51*A66+A14*A23*                 &
      A31*A52*A66-A13*A24*A31*A52*A66-A14*A21*A33*A52*A66+A11*A24*A33*A52*                     &
      A66+A13*A21*A34*A52*A66-A11*A23*A34*A52*A66-A14*A22*A31*A53*A66+A12*A24*                 &
      A31*A53*A66+A14*A21*A32*A53*A66-A11*A24*A32*A53*A66-A12*A21*A34*A53*                     &
      A66+A11*A22*A34*A53*A66+A13*A22*A31*A54*A66-A12*A23*A31*A54*A66-A13*A21*                 &
      A32*A54*A66+A11*A23*A32*A54*A66+A12*A21*A33*A54*A66-A11*A22*A33*A54*                     &
      A66

      COFACTOR(5,5) = A16*A24*A33*A42*A61-A14*A26*A33*A42*A61-A16*A23*A34*A42*A61+A13*A26*     &
      A34*A42*A61+A14*A23*A36*A42*A61-A13*A24*A36*A42*A61-A16*A24*A32*A43*                     &
      A61+A14*A26*A32*A43*A61+A16*A22*A34*A43*A61-A12*A26*A34*A43*A61-A14*A22*                 &
      A36*A43*A61+A12*A24*A36*A43*A61+A16*A23*A32*A44*A61-A13*A26*A32*A44*                     &
      A61-A16*A22*A33*A44*A61+A12*A26*A33*A44*A61+A13*A22*A36*A44*A61-A12*A23*                 &
      A36*A44*A61-A14*A23*A32*A46*A61+A13*A24*A32*A46*A61+A14*A22*A33*A46*                     &
      A61-A12*A24*A33*A46*A61-A13*A22*A34*A46*A61+A12*A23*A34*A46*A61-A16*A24*                 &
      A33*A41*A62+A14*A26*A33*A41*A62+A16*A23*A34*A41*A62-A13*A26*A34*A41*                     &
      A62-A14*A23*A36*A41*A62+A13*A24*A36*A41*A62+A16*A24*A31*A43*A62-A14*A26*                 &
      A31*A43*A62-A16*A21*A34*A43*A62+A11*A26*A34*A43*A62+A14*A21*A36*A43*                     &
      A62-A11*A24*A36*A43*A62-A16*A23*A31*A44*A62+A13*A26*A31*A44*A62+A16*A21*                 &
      A33*A44*A62-A11*A26*A33*A44*A62-A13*A21*A36*A44*A62+A11*A23*A36*A44*                     &
      A62+A14*A23*A31*A46*A62-A13*A24*A31*A46*A62-A14*A21*A33*A46*A62+A11*A24*                 &
      A33*A46*A62+A13*A21*A34*A46*A62-A11*A23*A34*A46*A62+A16*A24*A32*A41*                     &
      A63-A14*A26*A32*A41*A63-A16*A22*A34*A41*A63+A12*A26*A34*A41*A63+A14*A22*                 &
      A36*A41*A63-A12*A24*A36*A41*A63-A16*A24*A31*A42*A63+A14*A26*A31*A42*                     &
      A63+A16*A21*A34*A42*A63-A11*A26*A34*A42*A63-A14*A21*A36*A42*A63+A11*A24*                 &
      A36*A42*A63+A16*A22*A31*A44*A63-A12*A26*A31*A44*A63-A16*A21*A32*A44*                     &
      A63+A11*A26*A32*A44*A63+A12*A21*A36*A44*A63-A11*A22*A36*A44*A63-A14*A22*                 &
      A31*A46*A63+A12*A24*A31*A46*A63+A14*A21*A32*A46*A63-A11*A24*A32*A46*                     &
      A63-A12*A21*A34*A46*A63+A11*A22*A34*A46*A63-A16*A23*A32*A41*A64+A13*A26*                 &
      A32*A41*A64+A16*A22*A33*A41*A64-A12*A26*A33*A41*A64-A13*A22*A36*A41*                     &
      A64+A12*A23*A36*A41*A64+A16*A23*A31*A42*A64-A13*A26*A31*A42*A64-A16*A21*                 &
      A33*A42*A64+A11*A26*A33*A42*A64+A13*A21*A36*A42*A64-A11*A23*A36*A42*                     &
      A64-A16*A22*A31*A43*A64+A12*A26*A31*A43*A64+A16*A21*A32*A43*A64-A11*A26*                 &
      A32*A43*A64-A12*A21*A36*A43*A64+A11*A22*A36*A43*A64+A13*A22*A31*A46*                     &
      A64-A12*A23*A31*A46*A64-A13*A21*A32*A46*A64+A11*A23*A32*A46*A64+A12*A21*                 &
      A33*A46*A64-A11*A22*A33*A46*A64+A14*A23*A32*A41*A66-A13*A24*A32*A41*                     &
      A66-A14*A22*A33*A41*A66+A12*A24*A33*A41*A66+A13*A22*A34*A41*A66-A12*A23*                 &
      A34*A41*A66-A14*A23*A31*A42*A66+A13*A24*A31*A42*A66+A14*A21*A33*A42*                     &
      A66-A11*A24*A33*A42*A66-A13*A21*A34*A42*A66+A11*A23*A34*A42*A66+A14*A22*                 &
      A31*A43*A66-A12*A24*A31*A43*A66-A14*A21*A32*A43*A66+A11*A24*A32*A43*                     &
      A66+A12*A21*A34*A43*A66-A11*A22*A34*A43*A66-A13*A22*A31*A44*A66+A12*A23*                 &
      A31*A44*A66+A13*A21*A32*A44*A66-A11*A23*A32*A44*A66-A12*A21*A33*A44*                     &
      A66+A11*A22*A33*A44*A66

      COFACTOR(6,5) = -A16*A24*A33*A42*A51+A14*A26*A33*A42*A51+A16*A23*                        &
      A34*A42*A51-A13*A26*A34*A42*A51-A14*A23*A36*A42*A51+A13*A24*A36*A42*                     &
      A51+A16*A24*A32*A43*A51-A14*A26*A32*A43*A51-A16*A22*A34*A43*A51+A12*A26*                 &
      A34*A43*A51+A14*A22*A36*A43*A51-A12*A24*A36*A43*A51-A16*A23*A32*A44*                     &
      A51+A13*A26*A32*A44*A51+A16*A22*A33*A44*A51-A12*A26*A33*A44*A51-A13*A22*                 &
      A36*A44*A51+A12*A23*A36*A44*A51+A14*A23*A32*A46*A51-A13*A24*A32*A46*                     &
      A51-A14*A22*A33*A46*A51+A12*A24*A33*A46*A51+A13*A22*A34*A46*A51-A12*A23*                 &
      A34*A46*A51+A16*A24*A33*A41*A52-A14*A26*A33*A41*A52-A16*A23*A34*A41*                     &
      A52+A13*A26*A34*A41*A52+A14*A23*A36*A41*A52-A13*A24*A36*A41*A52-A16*A24*                 &
      A31*A43*A52+A14*A26*A31*A43*A52+A16*A21*A34*A43*A52-A11*A26*A34*A43*                     &
      A52-A14*A21*A36*A43*A52+A11*A24*A36*A43*A52+A16*A23*A31*A44*A52-A13*A26*                 &
      A31*A44*A52-A16*A21*A33*A44*A52+A11*A26*A33*A44*A52+A13*A21*A36*A44*                     &
      A52-A11*A23*A36*A44*A52-A14*A23*A31*A46*A52+A13*A24*A31*A46*A52+A14*A21*                 &
      A33*A46*A52-A11*A24*A33*A46*A52-A13*A21*A34*A46*A52+A11*A23*A34*A46*                     &
      A52-A16*A24*A32*A41*A53+A14*A26*A32*A41*A53+A16*A22*A34*A41*A53-A12*A26*                 &
      A34*A41*A53-A14*A22*A36*A41*A53+A12*A24*A36*A41*A53+A16*A24*A31*A42*                     &
      A53-A14*A26*A31*A42*A53-A16*A21*A34*A42*A53+A11*A26*A34*A42*A53+A14*A21*                 &
      A36*A42*A53-A11*A24*A36*A42*A53-A16*A22*A31*A44*A53+A12*A26*A31*A44*                     &
      A53+A16*A21*A32*A44*A53-A11*A26*A32*A44*A53-A12*A21*A36*A44*A53+A11*A22*                 &
      A36*A44*A53+A14*A22*A31*A46*A53-A12*A24*A31*A46*A53-A14*A21*A32*A46*                     &
      A53+A11*A24*A32*A46*A53+A12*A21*A34*A46*A53-A11*A22*A34*A46*A53+A16*A23*                 &
      A32*A41*A54-A13*A26*A32*A41*A54-A16*A22*A33*A41*A54+A12*A26*A33*A41*                     &
      A54+A13*A22*A36*A41*A54-A12*A23*A36*A41*A54-A16*A23*A31*A42*A54+A13*A26*                 &
      A31*A42*A54+A16*A21*A33*A42*A54-A11*A26*A33*A42*A54-A13*A21*A36*A42*                     &
      A54+A11*A23*A36*A42*A54+A16*A22*A31*A43*A54-A12*A26*A31*A43*A54-A16*A21*                 &
      A32*A43*A54+A11*A26*A32*A43*A54+A12*A21*A36*A43*A54-A11*A22*A36*A43*                     &
      A54-A13*A22*A31*A46*A54+A12*A23*A31*A46*A54+A13*A21*A32*A46*A54-A11*A23*                 &
      A32*A46*A54-A12*A21*A33*A46*A54+A11*A22*A33*A46*A54-A14*A23*A32*A41*                     &
      A56+A13*A24*A32*A41*A56+A14*A22*A33*A41*A56-A12*A24*A33*A41*A56-A13*A22*                 &
      A34*A41*A56+A12*A23*A34*A41*A56+A14*A23*A31*A42*A56-A13*A24*A31*A42*                     &
      A56-A14*A21*A33*A42*A56+A11*A24*A33*A42*A56+A13*A21*A34*A42*A56-A11*A23*                 &
      A34*A42*A56-A14*A22*A31*A43*A56+A12*A24*A31*A43*A56+A14*A21*A32*A43*                     &
      A56-A11*A24*A32*A43*A56-A12*A21*A34*A43*A56+A11*A22*A34*A43*A56+A13*A22*                 &
      A31*A44*A56-A12*A23*A31*A44*A56-A13*A21*A32*A44*A56+A11*A23*A32*A44*                     &
      A56+A12*A21*A33*A44*A56-A11*A22*A33*A44*A56

      COFACTOR(1,6) = -A25*A34*A43*A52*A61+A24*                                                &
      A35*A43*A52*A61+A25*A33*A44*A52*A61-A23*A35*A44*A52*A61-A24*A33*A45*A52*                 &
      A61+A23*A34*A45*A52*A61+A25*A34*A42*A53*A61-A24*A35*A42*A53*A61-A25*A32*                 &
      A44*A53*A61+A22*A35*A44*A53*A61+A24*A32*A45*A53*A61-A22*A34*A45*A53*                     &
      A61-A25*A33*A42*A54*A61+A23*A35*A42*A54*A61+A25*A32*A43*A54*A61-A22*A35*                 &
      A43*A54*A61-A23*A32*A45*A54*A61+A22*A33*A45*A54*A61+A24*A33*A42*A55*                     &
      A61-A23*A34*A42*A55*A61-A24*A32*A43*A55*A61+A22*A34*A43*A55*A61+A23*A32*                 &
      A44*A55*A61-A22*A33*A44*A55*A61+A25*A34*A43*A51*A62-A24*A35*A43*A51*                     &
      A62-A25*A33*A44*A51*A62+A23*A35*A44*A51*A62+A24*A33*A45*A51*A62-A23*A34*                 &
      A45*A51*A62-A25*A34*A41*A53*A62+A24*A35*A41*A53*A62+A25*A31*A44*A53*                     &
      A62-A21*A35*A44*A53*A62-A24*A31*A45*A53*A62+A21*A34*A45*A53*A62+A25*A33*                 &
      A41*A54*A62-A23*A35*A41*A54*A62-A25*A31*A43*A54*A62+A21*A35*A43*A54*                     &
      A62+A23*A31*A45*A54*A62-A21*A33*A45*A54*A62-A24*A33*A41*A55*A62+A23*A34*                 &
      A41*A55*A62+A24*A31*A43*A55*A62-A21*A34*A43*A55*A62-A23*A31*A44*A55*                     &
      A62+A21*A33*A44*A55*A62-A25*A34*A42*A51*A63+A24*A35*A42*A51*A63+A25*A32*                 &
      A44*A51*A63-A22*A35*A44*A51*A63-A24*A32*A45*A51*A63+A22*A34*A45*A51*                     &
      A63+A25*A34*A41*A52*A63-A24*A35*A41*A52*A63-A25*A31*A44*A52*A63+A21*A35*                 &
      A44*A52*A63+A24*A31*A45*A52*A63-A21*A34*A45*A52*A63-A25*A32*A41*A54*                     &
      A63+A22*A35*A41*A54*A63+A25*A31*A42*A54*A63-A21*A35*A42*A54*A63-A22*A31*                 &
      A45*A54*A63+A21*A32*A45*A54*A63+A24*A32*A41*A55*A63-A22*A34*A41*A55*                     &
      A63-A24*A31*A42*A55*A63+A21*A34*A42*A55*A63+A22*A31*A44*A55*A63-A21*A32*                 &
      A44*A55*A63+A25*A33*A42*A51*A64-A23*A35*A42*A51*A64-A25*A32*A43*A51*                     &
      A64+A22*A35*A43*A51*A64+A23*A32*A45*A51*A64-A22*A33*A45*A51*A64-A25*A33*                 &
      A41*A52*A64+A23*A35*A41*A52*A64+A25*A31*A43*A52*A64-A21*A35*A43*A52*                     &
      A64-A23*A31*A45*A52*A64+A21*A33*A45*A52*A64+A25*A32*A41*A53*A64-A22*A35*                 &
      A41*A53*A64-A25*A31*A42*A53*A64+A21*A35*A42*A53*A64+A22*A31*A45*A53*                     &
      A64-A21*A32*A45*A53*A64-A23*A32*A41*A55*A64+A22*A33*A41*A55*A64+A23*A31*                 &
      A42*A55*A64-A21*A33*A42*A55*A64-A22*A31*A43*A55*A64+A21*A32*A43*A55*                     &
      A64-A24*A33*A42*A51*A65+A23*A34*A42*A51*A65+A24*A32*A43*A51*A65-A22*A34*                 &
      A43*A51*A65-A23*A32*A44*A51*A65+A22*A33*A44*A51*A65+A24*A33*A41*A52*                     &
      A65-A23*A34*A41*A52*A65-A24*A31*A43*A52*A65+A21*A34*A43*A52*A65+A23*A31*                 &
      A44*A52*A65-A21*A33*A44*A52*A65-A24*A32*A41*A53*A65+A22*A34*A41*A53*                     &
      A65+A24*A31*A42*A53*A65-A21*A34*A42*A53*A65-A22*A31*A44*A53*A65+A21*A32*                 &
      A44*A53*A65+A23*A32*A41*A54*A65-A22*A33*A41*A54*A65-A23*A31*A42*A54*                     &
      A65+A21*A33*A42*A54*A65+A22*A31*A43*A54*A65-A21*A32*A43*A54*A65

      COFACTOR(2,6) = A15*A34*                                                                 &
      A43*A52*A61-A14*A35*A43*A52*A61-A15*A33*A44*A52*A61+A13*A35*A44*A52*                     &
      A61+A14*A33*A45*A52*A61-A13*A34*A45*A52*A61-A15*A34*A42*A53*A61+A14*A35*                 &
      A42*A53*A61+A15*A32*A44*A53*A61-A12*A35*A44*A53*A61-A14*A32*A45*A53*                     &
      A61+A12*A34*A45*A53*A61+A15*A33*A42*A54*A61-A13*A35*A42*A54*A61-A15*A32*                 &
      A43*A54*A61+A12*A35*A43*A54*A61+A13*A32*A45*A54*A61-A12*A33*A45*A54*                     &
      A61-A14*A33*A42*A55*A61+A13*A34*A42*A55*A61+A14*A32*A43*A55*A61-A12*A34*                 &
      A43*A55*A61-A13*A32*A44*A55*A61+A12*A33*A44*A55*A61-A15*A34*A43*A51*                     &
      A62+A14*A35*A43*A51*A62+A15*A33*A44*A51*A62-A13*A35*A44*A51*A62-A14*A33*                 &
      A45*A51*A62+A13*A34*A45*A51*A62+A15*A34*A41*A53*A62-A14*A35*A41*A53*                     &
      A62-A15*A31*A44*A53*A62+A11*A35*A44*A53*A62+A14*A31*A45*A53*A62-A11*A34*                 &
      A45*A53*A62-A15*A33*A41*A54*A62+A13*A35*A41*A54*A62+A15*A31*A43*A54*                     &
      A62-A11*A35*A43*A54*A62-A13*A31*A45*A54*A62+A11*A33*A45*A54*A62+A14*A33*                 &
      A41*A55*A62-A13*A34*A41*A55*A62-A14*A31*A43*A55*A62+A11*A34*A43*A55*                     &
      A62+A13*A31*A44*A55*A62-A11*A33*A44*A55*A62+A15*A34*A42*A51*A63-A14*A35*                 &
      A42*A51*A63-A15*A32*A44*A51*A63+A12*A35*A44*A51*A63+A14*A32*A45*A51*                     &
      A63-A12*A34*A45*A51*A63-A15*A34*A41*A52*A63+A14*A35*A41*A52*A63+A15*A31*                 &
      A44*A52*A63-A11*A35*A44*A52*A63-A14*A31*A45*A52*A63+A11*A34*A45*A52*                     &
      A63+A15*A32*A41*A54*A63-A12*A35*A41*A54*A63-A15*A31*A42*A54*A63+A11*A35*                 &
      A42*A54*A63+A12*A31*A45*A54*A63-A11*A32*A45*A54*A63-A14*A32*A41*A55*                     &
      A63+A12*A34*A41*A55*A63+A14*A31*A42*A55*A63-A11*A34*A42*A55*A63-A12*A31*                 &
      A44*A55*A63+A11*A32*A44*A55*A63-A15*A33*A42*A51*A64+A13*A35*A42*A51*                     &
      A64+A15*A32*A43*A51*A64-A12*A35*A43*A51*A64-A13*A32*A45*A51*A64+A12*A33*                 &
      A45*A51*A64+A15*A33*A41*A52*A64-A13*A35*A41*A52*A64-A15*A31*A43*A52*                     &
      A64+A11*A35*A43*A52*A64+A13*A31*A45*A52*A64-A11*A33*A45*A52*A64-A15*A32*                 &
      A41*A53*A64+A12*A35*A41*A53*A64+A15*A31*A42*A53*A64-A11*A35*A42*A53*                     &
      A64-A12*A31*A45*A53*A64+A11*A32*A45*A53*A64+A13*A32*A41*A55*A64-A12*A33*                 &
      A41*A55*A64-A13*A31*A42*A55*A64+A11*A33*A42*A55*A64+A12*A31*A43*A55*                     &
      A64-A11*A32*A43*A55*A64+A14*A33*A42*A51*A65-A13*A34*A42*A51*A65-A14*A32*                 &
      A43*A51*A65+A12*A34*A43*A51*A65+A13*A32*A44*A51*A65-A12*A33*A44*A51*                     &
      A65-A14*A33*A41*A52*A65+A13*A34*A41*A52*A65+A14*A31*A43*A52*A65-A11*A34*                 &
      A43*A52*A65-A13*A31*A44*A52*A65+A11*A33*A44*A52*A65+A14*A32*A41*A53*                     &
      A65-A12*A34*A41*A53*A65-A14*A31*A42*A53*A65+A11*A34*A42*A53*A65+A12*A31*                 &
      A44*A53*A65-A11*A32*A44*A53*A65-A13*A32*A41*A54*A65+A12*A33*A41*A54*                     &
      A65+A13*A31*A42*A54*A65-A11*A33*A42*A54*A65-A12*A31*A43*A54*A65+A11*A32*                 &
      A43*A54*A65

      COFACTOR(3,6) = -A15*A24*A43*A52*A61+A14*A25*A43*A52*A61+A15*A23*A44*A52*                &
      A61-A13*A25*A44*A52*A61-A14*A23*A45*A52*A61+A13*A24*A45*A52*A61+A15*A24*                 &
      A42*A53*A61-A14*A25*A42*A53*A61-A15*A22*A44*A53*A61+A12*A25*A44*A53*                     &
      A61+A14*A22*A45*A53*A61-A12*A24*A45*A53*A61-A15*A23*A42*A54*A61+A13*A25*                 &
      A42*A54*A61+A15*A22*A43*A54*A61-A12*A25*A43*A54*A61-A13*A22*A45*A54*                     &
      A61+A12*A23*A45*A54*A61+A14*A23*A42*A55*A61-A13*A24*A42*A55*A61-A14*A22*                 &
      A43*A55*A61+A12*A24*A43*A55*A61+A13*A22*A44*A55*A61-A12*A23*A44*A55*                     &
      A61+A15*A24*A43*A51*A62-A14*A25*A43*A51*A62-A15*A23*A44*A51*A62+A13*A25*                 &
      A44*A51*A62+A14*A23*A45*A51*A62-A13*A24*A45*A51*A62-A15*A24*A41*A53*                     &
      A62+A14*A25*A41*A53*A62+A15*A21*A44*A53*A62-A11*A25*A44*A53*A62-A14*A21*                 &
      A45*A53*A62+A11*A24*A45*A53*A62+A15*A23*A41*A54*A62-A13*A25*A41*A54*                     &
      A62-A15*A21*A43*A54*A62+A11*A25*A43*A54*A62+A13*A21*A45*A54*A62-A11*A23*                 &
      A45*A54*A62-A14*A23*A41*A55*A62+A13*A24*A41*A55*A62+A14*A21*A43*A55*                     &
      A62-A11*A24*A43*A55*A62-A13*A21*A44*A55*A62+A11*A23*A44*A55*A62-A15*A24*                 &
      A42*A51*A63+A14*A25*A42*A51*A63+A15*A22*A44*A51*A63-A12*A25*A44*A51*                     &
      A63-A14*A22*A45*A51*A63+A12*A24*A45*A51*A63+A15*A24*A41*A52*A63-A14*A25*                 &
      A41*A52*A63-A15*A21*A44*A52*A63+A11*A25*A44*A52*A63+A14*A21*A45*A52*                     &
      A63-A11*A24*A45*A52*A63-A15*A22*A41*A54*A63+A12*A25*A41*A54*A63+A15*A21*                 &
      A42*A54*A63-A11*A25*A42*A54*A63-A12*A21*A45*A54*A63+A11*A22*A45*A54*                     &
      A63+A14*A22*A41*A55*A63-A12*A24*A41*A55*A63-A14*A21*A42*A55*A63+A11*A24*                 &
      A42*A55*A63+A12*A21*A44*A55*A63-A11*A22*A44*A55*A63+A15*A23*A42*A51*                     &
      A64-A13*A25*A42*A51*A64-A15*A22*A43*A51*A64+A12*A25*A43*A51*A64+A13*A22*                 &
      A45*A51*A64-A12*A23*A45*A51*A64-A15*A23*A41*A52*A64+A13*A25*A41*A52*                     &
      A64+A15*A21*A43*A52*A64-A11*A25*A43*A52*A64-A13*A21*A45*A52*A64+A11*A23*                 &
      A45*A52*A64+A15*A22*A41*A53*A64-A12*A25*A41*A53*A64-A15*A21*A42*A53*                     &
      A64+A11*A25*A42*A53*A64+A12*A21*A45*A53*A64-A11*A22*A45*A53*A64-A13*A22*                 &
      A41*A55*A64+A12*A23*A41*A55*A64+A13*A21*A42*A55*A64-A11*A23*A42*A55*                     &
      A64-A12*A21*A43*A55*A64+A11*A22*A43*A55*A64-A14*A23*A42*A51*A65+A13*A24*                 &
      A42*A51*A65+A14*A22*A43*A51*A65-A12*A24*A43*A51*A65-A13*A22*A44*A51*                     &
      A65+A12*A23*A44*A51*A65+A14*A23*A41*A52*A65-A13*A24*A41*A52*A65-A14*A21*                 &
      A43*A52*A65+A11*A24*A43*A52*A65+A13*A21*A44*A52*A65-A11*A23*A44*A52*                     &
      A65-A14*A22*A41*A53*A65+A12*A24*A41*A53*A65+A14*A21*A42*A53*A65-A11*A24*                 &
      A42*A53*A65-A12*A21*A44*A53*A65+A11*A22*A44*A53*A65+A13*A22*A41*A54*                     &
      A65-A12*A23*A41*A54*A65-A13*A21*A42*A54*A65+A11*A23*A42*A54*A65+A12*A21*                 &
      A43*A54*A65-A11*A22*A43*A54*A65

      COFACTOR(4,6) = A15*A24*A33*A52*A61-A14*A25*A33*A52*                                     &
      A61-A15*A23*A34*A52*A61+A13*A25*A34*A52*A61+A14*A23*A35*A52*A61-A13*A24*                 &
      A35*A52*A61-A15*A24*A32*A53*A61+A14*A25*A32*A53*A61+A15*A22*A34*A53*                     &
      A61-A12*A25*A34*A53*A61-A14*A22*A35*A53*A61+A12*A24*A35*A53*A61+A15*A23*                 &
      A32*A54*A61-A13*A25*A32*A54*A61-A15*A22*A33*A54*A61+A12*A25*A33*A54*                     &
      A61+A13*A22*A35*A54*A61-A12*A23*A35*A54*A61-A14*A23*A32*A55*A61+A13*A24*                 &
      A32*A55*A61+A14*A22*A33*A55*A61-A12*A24*A33*A55*A61-A13*A22*A34*A55*                     &
      A61+A12*A23*A34*A55*A61-A15*A24*A33*A51*A62+A14*A25*A33*A51*A62+A15*A23*                 &
      A34*A51*A62-A13*A25*A34*A51*A62-A14*A23*A35*A51*A62+A13*A24*A35*A51*                     &
      A62+A15*A24*A31*A53*A62-A14*A25*A31*A53*A62-A15*A21*A34*A53*A62+A11*A25*                 &
      A34*A53*A62+A14*A21*A35*A53*A62-A11*A24*A35*A53*A62-A15*A23*A31*A54*                     &
      A62+A13*A25*A31*A54*A62+A15*A21*A33*A54*A62-A11*A25*A33*A54*A62-A13*A21*                 &
      A35*A54*A62+A11*A23*A35*A54*A62+A14*A23*A31*A55*A62-A13*A24*A31*A55*                     &
      A62-A14*A21*A33*A55*A62+A11*A24*A33*A55*A62+A13*A21*A34*A55*A62-A11*A23*                 &
      A34*A55*A62+A15*A24*A32*A51*A63-A14*A25*A32*A51*A63-A15*A22*A34*A51*                     &
      A63+A12*A25*A34*A51*A63+A14*A22*A35*A51*A63-A12*A24*A35*A51*A63-A15*A24*                 &
      A31*A52*A63+A14*A25*A31*A52*A63+A15*A21*A34*A52*A63-A11*A25*A34*A52*                     &
      A63-A14*A21*A35*A52*A63+A11*A24*A35*A52*A63+A15*A22*A31*A54*A63-A12*A25*                 &
      A31*A54*A63-A15*A21*A32*A54*A63+A11*A25*A32*A54*A63+A12*A21*A35*A54*                     &
      A63-A11*A22*A35*A54*A63-A14*A22*A31*A55*A63+A12*A24*A31*A55*A63+A14*A21*                 &
      A32*A55*A63-A11*A24*A32*A55*A63-A12*A21*A34*A55*A63+A11*A22*A34*A55*                     &
      A63-A15*A23*A32*A51*A64+A13*A25*A32*A51*A64+A15*A22*A33*A51*A64-A12*A25*                 &
      A33*A51*A64-A13*A22*A35*A51*A64+A12*A23*A35*A51*A64+A15*A23*A31*A52*                     &
      A64-A13*A25*A31*A52*A64-A15*A21*A33*A52*A64+A11*A25*A33*A52*A64+A13*A21*                 &
      A35*A52*A64-A11*A23*A35*A52*A64-A15*A22*A31*A53*A64+A12*A25*A31*A53*                     &
      A64+A15*A21*A32*A53*A64-A11*A25*A32*A53*A64-A12*A21*A35*A53*A64+A11*A22*                 &
      A35*A53*A64+A13*A22*A31*A55*A64-A12*A23*A31*A55*A64-A13*A21*A32*A55*                     &
      A64+A11*A23*A32*A55*A64+A12*A21*A33*A55*A64-A11*A22*A33*A55*A64+A14*A23*                 &
      A32*A51*A65-A13*A24*A32*A51*A65-A14*A22*A33*A51*A65+A12*A24*A33*A51*                     &
      A65+A13*A22*A34*A51*A65-A12*A23*A34*A51*A65-A14*A23*A31*A52*A65+A13*A24*                 &
      A31*A52*A65+A14*A21*A33*A52*A65-A11*A24*A33*A52*A65-A13*A21*A34*A52*                     &
      A65+A11*A23*A34*A52*A65+A14*A22*A31*A53*A65-A12*A24*A31*A53*A65-A14*A21*                 &
      A32*A53*A65+A11*A24*A32*A53*A65+A12*A21*A34*A53*A65-A11*A22*A34*A53*                     &
      A65-A13*A22*A31*A54*A65+A12*A23*A31*A54*A65+A13*A21*A32*A54*A65-A11*A23*                 &
      A32*A54*A65-A12*A21*A33*A54*A65+A11*A22*A33*A54*A65

      COFACTOR(5,6) = -A15*A24*A33*A42*                                                        &
      A61+A14*A25*A33*A42*A61+A15*A23*A34*A42*A61-A13*A25*A34*A42*A61-A14*A23*                 &
      A35*A42*A61+A13*A24*A35*A42*A61+A15*A24*A32*A43*A61-A14*A25*A32*A43*                     &
      A61-A15*A22*A34*A43*A61+A12*A25*A34*A43*A61+A14*A22*A35*A43*A61-A12*A24*                 &
      A35*A43*A61-A15*A23*A32*A44*A61+A13*A25*A32*A44*A61+A15*A22*A33*A44*                     &
      A61-A12*A25*A33*A44*A61-A13*A22*A35*A44*A61+A12*A23*A35*A44*A61+A14*A23*                 &
      A32*A45*A61-A13*A24*A32*A45*A61-A14*A22*A33*A45*A61+A12*A24*A33*A45*                     &
      A61+A13*A22*A34*A45*A61-A12*A23*A34*A45*A61+A15*A24*A33*A41*A62-A14*A25*                 &
      A33*A41*A62-A15*A23*A34*A41*A62+A13*A25*A34*A41*A62+A14*A23*A35*A41*                     &
      A62-A13*A24*A35*A41*A62-A15*A24*A31*A43*A62+A14*A25*A31*A43*A62+A15*A21*                 &
      A34*A43*A62-A11*A25*A34*A43*A62-A14*A21*A35*A43*A62+A11*A24*A35*A43*                     &
      A62+A15*A23*A31*A44*A62-A13*A25*A31*A44*A62-A15*A21*A33*A44*A62+A11*A25*                 &
      A33*A44*A62+A13*A21*A35*A44*A62-A11*A23*A35*A44*A62-A14*A23*A31*A45*                     &
      A62+A13*A24*A31*A45*A62+A14*A21*A33*A45*A62-A11*A24*A33*A45*A62-A13*A21*                 &
      A34*A45*A62+A11*A23*A34*A45*A62-A15*A24*A32*A41*A63+A14*A25*A32*A41*                     &
      A63+A15*A22*A34*A41*A63-A12*A25*A34*A41*A63-A14*A22*A35*A41*A63+A12*A24*                 &
      A35*A41*A63+A15*A24*A31*A42*A63-A14*A25*A31*A42*A63-A15*A21*A34*A42*                     &
      A63+A11*A25*A34*A42*A63+A14*A21*A35*A42*A63-A11*A24*A35*A42*A63-A15*A22*                 &
      A31*A44*A63+A12*A25*A31*A44*A63+A15*A21*A32*A44*A63-A11*A25*A32*A44*                     &
      A63-A12*A21*A35*A44*A63+A11*A22*A35*A44*A63+A14*A22*A31*A45*A63-A12*A24*                 &
      A31*A45*A63-A14*A21*A32*A45*A63+A11*A24*A32*A45*A63+A12*A21*A34*A45*                     &
      A63-A11*A22*A34*A45*A63+A15*A23*A32*A41*A64-A13*A25*A32*A41*A64-A15*A22*                 &
      A33*A41*A64+A12*A25*A33*A41*A64+A13*A22*A35*A41*A64-A12*A23*A35*A41*                     &
      A64-A15*A23*A31*A42*A64+A13*A25*A31*A42*A64+A15*A21*A33*A42*A64-A11*A25*                 &
      A33*A42*A64-A13*A21*A35*A42*A64+A11*A23*A35*A42*A64+A15*A22*A31*A43*                     &
      A64-A12*A25*A31*A43*A64-A15*A21*A32*A43*A64+A11*A25*A32*A43*A64+A12*A21*                 &
      A35*A43*A64-A11*A22*A35*A43*A64-A13*A22*A31*A45*A64+A12*A23*A31*A45*                     &
      A64+A13*A21*A32*A45*A64-A11*A23*A32*A45*A64-A12*A21*A33*A45*A64+A11*A22*                 &
      A33*A45*A64-A14*A23*A32*A41*A65+A13*A24*A32*A41*A65+A14*A22*A33*A41*                     &
      A65-A12*A24*A33*A41*A65-A13*A22*A34*A41*A65+A12*A23*A34*A41*A65+A14*A23*                 &
      A31*A42*A65-A13*A24*A31*A42*A65-A14*A21*A33*A42*A65+A11*A24*A33*A42*                     &
      A65+A13*A21*A34*A42*A65-A11*A23*A34*A42*A65-A14*A22*A31*A43*A65+A12*A24*                 &
      A31*A43*A65+A14*A21*A32*A43*A65-A11*A24*A32*A43*A65-A12*A21*A34*A43*                     &
      A65+A11*A22*A34*A43*A65+A13*A22*A31*A44*A65-A12*A23*A31*A44*A65-A13*A21*                 &
      A32*A44*A65+A11*A23*A32*A44*A65+A12*A21*A33*A44*A65-A11*A22*A33*A44*                     &
      A65

      COFACTOR(6,6) = A15*A24*A33*A42*A51-A14*A25*A33*A42*A51-A15*A23*A34*A42*A51+A13*A25*     &
      A34*A42*A51+A14*A23*A35*A42*A51-A13*A24*A35*A42*A51-A15*A24*A32*A43*                     &
      A51+A14*A25*A32*A43*A51+A15*A22*A34*A43*A51-A12*A25*A34*A43*A51-A14*A22*                 &
      A35*A43*A51+A12*A24*A35*A43*A51+A15*A23*A32*A44*A51-A13*A25*A32*A44*                     &
      A51-A15*A22*A33*A44*A51+A12*A25*A33*A44*A51+A13*A22*A35*A44*A51-A12*A23*                 &
      A35*A44*A51-A14*A23*A32*A45*A51+A13*A24*A32*A45*A51+A14*A22*A33*A45*                     &
      A51-A12*A24*A33*A45*A51-A13*A22*A34*A45*A51+A12*A23*A34*A45*A51-A15*A24*                 &
      A33*A41*A52+A14*A25*A33*A41*A52+A15*A23*A34*A41*A52-A13*A25*A34*A41*                     &
      A52-A14*A23*A35*A41*A52+A13*A24*A35*A41*A52+A15*A24*A31*A43*A52-A14*A25*                 &
      A31*A43*A52-A15*A21*A34*A43*A52+A11*A25*A34*A43*A52+A14*A21*A35*A43*                     &
      A52-A11*A24*A35*A43*A52-A15*A23*A31*A44*A52+A13*A25*A31*A44*A52+A15*A21*                 &
      A33*A44*A52-A11*A25*A33*A44*A52-A13*A21*A35*A44*A52+A11*A23*A35*A44*                     &
      A52+A14*A23*A31*A45*A52-A13*A24*A31*A45*A52-A14*A21*A33*A45*A52+A11*A24*                 &
      A33*A45*A52+A13*A21*A34*A45*A52-A11*A23*A34*A45*A52+A15*A24*A32*A41*                     &
      A53-A14*A25*A32*A41*A53-A15*A22*A34*A41*A53+A12*A25*A34*A41*A53+A14*A22*                 &
      A35*A41*A53-A12*A24*A35*A41*A53-A15*A24*A31*A42*A53+A14*A25*A31*A42*                     &
      A53+A15*A21*A34*A42*A53-A11*A25*A34*A42*A53-A14*A21*A35*A42*A53+A11*A24*                 &
      A35*A42*A53+A15*A22*A31*A44*A53-A12*A25*A31*A44*A53-A15*A21*A32*A44*                     &
      A53+A11*A25*A32*A44*A53+A12*A21*A35*A44*A53-A11*A22*A35*A44*A53-A14*A22*                 &
      A31*A45*A53+A12*A24*A31*A45*A53+A14*A21*A32*A45*A53-A11*A24*A32*A45*                     &
      A53-A12*A21*A34*A45*A53+A11*A22*A34*A45*A53-A15*A23*A32*A41*A54+A13*A25*                 &
      A32*A41*A54+A15*A22*A33*A41*A54-A12*A25*A33*A41*A54-A13*A22*A35*A41*                     &
      A54+A12*A23*A35*A41*A54+A15*A23*A31*A42*A54-A13*A25*A31*A42*A54-A15*A21*                 &
      A33*A42*A54+A11*A25*A33*A42*A54+A13*A21*A35*A42*A54-A11*A23*A35*A42*                     &
      A54-A15*A22*A31*A43*A54+A12*A25*A31*A43*A54+A15*A21*A32*A43*A54-A11*A25*                 &
      A32*A43*A54-A12*A21*A35*A43*A54+A11*A22*A35*A43*A54+A13*A22*A31*A45*                     &
      A54-A12*A23*A31*A45*A54-A13*A21*A32*A45*A54+A11*A23*A32*A45*A54+A12*A21*                 &
      A33*A45*A54-A11*A22*A33*A45*A54+A14*A23*A32*A41*A55-A13*A24*A32*A41*                     &
      A55-A14*A22*A33*A41*A55+A12*A24*A33*A41*A55+A13*A22*A34*A41*A55-A12*A23*                 &
      A34*A41*A55-A14*A23*A31*A42*A55+A13*A24*A31*A42*A55+A14*A21*A33*A42*                     &
      A55-A11*A24*A33*A42*A55-A13*A21*A34*A42*A55+A11*A23*A34*A42*A55+A14*A22*                 &
      A31*A43*A55-A12*A24*A31*A43*A55-A14*A21*A32*A43*A55+A11*A24*A32*A43*                     &
      A55+A12*A21*A34*A43*A55-A11*A22*A34*A43*A55-A13*A22*A31*A44*A55+A12*A23*                 &
      A31*A44*A55+A13*A21*A32*A44*A55-A11*A23*A32*A44*A55-A12*A21*A33*A44*                     &
      A55+A11*A22*A33*A44*A55

      AINV = TRANSPOSE(COFACTOR) / DET

      OK_FLAG = .TRUE.

      RETURN

      END SUBROUTINE M66INV
  

 999 END PROGRAM
