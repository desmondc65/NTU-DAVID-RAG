readme.txt describing how to use computer codes for Bakis, Kaymak and Poschke, "Transitional Dynamics and the Optimal Progressivity of Income Redistribution"

I. Stata Code

The code consists of a single .do file that uses the stata data file psid22.dta (unzip the psid22.zip file before running the .do code).

II. Fortran Code

The code consists in a single file, BKP_fortran.f90. We compile this file using the command

gfortran -framework Accelerate -g3 -o transout.out BKP_fortran.f90

creating an executable called transout.out, but details may differ across platforms and Fortran installations. 

Within the code, model parameters are set in the module "calib". The main program "aiyagari" allows setting technical parameters, tax progressivity, and includes settings for whether to compute only one steady state, two steady states, or the transition between steady states. Comments in the file explain how to set these parameters. The computational algorithm is described in the appendix of the paper.