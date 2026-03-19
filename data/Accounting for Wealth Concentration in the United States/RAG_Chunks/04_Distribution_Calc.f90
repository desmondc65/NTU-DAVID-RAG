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