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
