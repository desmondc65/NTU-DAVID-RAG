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