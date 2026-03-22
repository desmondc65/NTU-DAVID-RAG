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