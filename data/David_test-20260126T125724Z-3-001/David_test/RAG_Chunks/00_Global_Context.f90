PROGRAM wealth_accounting


!*******************************************************************************************************************************************************************************************************************************************************************
! 1. Compiling the code: gfortran benchmark.f90 -ffree-line-length-none -fopenmp -O3 -o run

! 2. Run the code with: ./run 0.002200   0.850000   0.021200   0.758000  32.678850 270.820000   0.001075   0.07000   0.960000   0.940000  -1.400000   0.1 0.974  0.170000   2.206000   0.116000   0.230000   0.900000   0.002500   0.990000   5.000000  15.000000
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
REAL(prec)	dev_beq_tran_mat1,dev_beq_tran_mat2,beq_receive,beq_given,BEQTRANS,BEQTRANS1
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
