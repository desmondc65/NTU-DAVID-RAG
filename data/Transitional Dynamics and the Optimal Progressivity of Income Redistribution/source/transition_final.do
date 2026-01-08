/* This code estimates the intergenerational and lifecycle transition matrices for hourly wages used 
in Bakis, Kaymak and Poschke (RED forthcoming). The Data comes from the PSID.

Sample: The sample is restricted to male head of households (R) with fathers who also were 
household heads when R was a child. For some households, there were multiple male heads during
childhood. These observations were excluded as we cannot determine the biological father. The
matrix is calculated from the child's perspective, i.e. fathers are repeated.

*/
set more off
use psid22.dta, clear

* There are 9 repeated observations. Collapse them to single observations. (done once saved back as psid22)
	*sort personid year
	*collapse (mean) hhid income state age sex race marital relhd educHS yearseduc annualhours employstatus earnings indweight longweight w11103_2007 weight, by(personid year) fast
	*save "/Users/kaymakb/SYNC/RESEARCH/Projects/Progressive Taxation/Data/psid22.dta",replace

xtset personid year


gen year2 = year-1
*incomeyear*

gen cpi99 = .
replace cpi99 = 4.540 if year2 ==1969
replace cpi99 = 4.294 if year2 ==1970
replace cpi99 = 4.114 if year2 ==1971
replace cpi99 = 3.986 if year2 ==1972
replace cpi99 = 3.752 if year2 ==1973
replace cpi99 = 3.379 if year2 ==1974
replace cpi99 = 3.097 if year2 ==1975
replace cpi99 = 2.928 if year2 ==1976
replace cpi99 = 2.749 if year2 ==1977
replace cpi99 = 2.555 if year2 ==1978
replace cpi99 = 2.295 if year2 ==1979
replace cpi99 = 2.022 if year2 ==1980
replace cpi99 = 1.833 if year2 ==1981
replace cpi99 = 1.726 if year2 ==1982
replace cpi99 = 1.673 if year2 ==1983
replace cpi99 = 1.603 if year2 ==1984
replace cpi99 = 1.548 if year2 ==1985
replace cpi99 = 1.520 if year2 ==1986
replace cpi99 = 1.467 if year2 ==1987
replace cpi99 = 1.408 if year2 ==1988
replace cpi99 = 1.344 if year2 ==1989
replace cpi99 = 1.275 if year2 ==1990
replace cpi99 = 1.223 if year2 ==1991
replace cpi99 = 1.187 if year2 ==1992
replace cpi99 = 1.153 if year2 ==1993
replace cpi99 = 1.124 if year2 ==1994
replace cpi99 = 1.093 if year2 ==1995
replace cpi99 = 1.062 if year2 ==1996
replace cpi99 = 1.038 if year2 ==1997
replace cpi99 = 1.022 if year2 ==1998
replace cpi99 = 1.000 if year2 ==1999
replace cpi99 = 0.967 if year2 ==2000
replace cpi99 = 0.941 if year2 ==2001
replace cpi99 = 0.926 if year2 ==2002
replace cpi99 = 0.905 if year2 ==2003
replace cpi99 = 0.882 if year2 ==2004
replace cpi99 = 0.853 if year2 ==2005
replace cpi99 = 0.826 if year2 ==2006
replace cpi99 = 0.804 if year2 ==2007
replace cpi99 = 0.774 if year2 ==2008
replace cpi99 = 0.777 if year2 ==2009

gen incomereal = income*cpi99
gen earningsreal = earnings*cpi99
gen rw=earningsreal/annualhours
replace rw=. if rw>200 |rw<1

gen age2=age^2
gen age3=age^3
gen age4=age^4

gen lnrw=log(rw)

gen wagesample=1 if relhd==1 & age>24 & age<=60 & (rw<150 & rw>1) & (annualhours>520 & annualhours<4368) & sex==1 & year<1992
quietly tab year if year<1992,gen(D_t)

quietly areg lnrw age age2 age3 age4 D_t* if wagesample==1 [aw=indw], absorb(personid)

* Fixed effects component
predict fw if e(sample),d

* Life cycle component
predict resid if e(sample), resid
gen lnrw_lc=_b[age]*age+_b[age2]*age2+_b[age3]*age3+_b[age4]*age4+resid if e(sample)
quietly sum lnrw_lc [aw=indw] if wagesample==1
local m_lc=r(mean)
replace lnrw_lc=lnrw_lc-`m_lc'

* Total 
gen lnrw_fwlc=fw+lnrw_lc


***************** SUMMARY STATISTICS ***************************

* Variance decomposition needed for calibration
sum lnrw lnrw_fwlc fw lnrw_lc [aw=indw] if wagesample==1

* Wage progression ove the life-cycle 
gen period=floor((age-25)/5)
tab period [aw=indw] if wagesample==1, sum(lnrw_lc)

sum lnrw_lc [aw=indw] if wagesample==1 & period==0
local mw_0=r(mean)
sum lnrw_lc [aw=indw] if wagesample==1 & period==4
local mw_4=r(mean)
di `mw_4'-`mw_0'

* Gini Index in the sample
ineqdec0 earningsreal if wagesample==1


***************** INTERGENERATIONAL TRANSITIONS ***************************
egen fw_dad=mean(fw)	if relhd<=3, by (hhid year)
replace fw_dad=. if relhd!=3
by personid: egen aux=sd(fw_dad)
replace fw_dad=. if aux>0
drop aux
rename fw_dad aux
egen fw_dad=mean(aux), by(personid)
egen fw_son=mean(fw), by(personid)
drop aux

* An AR(1) regression to check compatibility with the literature
reg fw_son fw_dad [aw=indw]

* The transition matrix
xtile qtwage_dad=fw_dad [aw=indw],nq(2)
xtile qtwage_son=fw_son [aw=indw],nq(2)
matrxmob qtwage_dad qtwage_son [aw=indw]


***************** LIFE CYCLE TRANSITIONS ***************************

* Transition Matrix (Annual)
xtile lifew=lnrw_lc [aw=indw] if wagesample==1, nq(2)
gen lag_lifew=l1.lifew
matrxmob lag_lifew lifew [aw=indw] if wagesample==1


************** HOURS ********************
gen hourssample=1 if relhd==1 & age>24 & age<=60 & sex==1 & year<1992
  
quietly areg annualhours age* D_t* [aw=indw] if hourssample==1, absorb(personid) 
predict fh if hourssample==1, d

* Coefficient of Variation
sum annualhours [aw=indw] if hourssample==1
local mean_h=r(mean)
sum fh [aw=indw] if hourssample==1
local sd_h=r(sd)
di `sd_h'/`mean_h'
