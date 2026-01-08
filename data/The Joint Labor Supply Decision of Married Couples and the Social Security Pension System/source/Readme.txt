Readme.txt

Availability of Data and Computer Code for Published Papers

Title of Paper: The Joint Labor Supply Decision of Married Couples and the U.S. Social Security Pension System

Manuscript Number: RED-15-372 / YREDY_885

Name of Author: Shinichi Nishiyama

Name of Editor: Jonathan Heathcote

1. Software and operating system used

- Intel(R) Parallel Studio XE 2015 Composer Edition for Fortran Windows (with IMSL)
- Windows 10 64bit operating sytem with 16.0GB RAM

2. The order in which the programs need to run

- There is only one Fortran f90 file.  Go through the code (with comments) carefully before running the program.
- The main section (lines 394-478) of the program consists of three parts: (1) computing initial steady-state equilibrium, (2) computing six final steady-state equilibria, and (3) computing up to six equilibrium transition paths.
- Remove STOP statements at the end of (1) and (2) to move to the next part. Comment out (2) to move to (3) directly.
- To compute an equilibrium transition path with RAM less than 16.0GB, call rw_decision and rw_decision2 instead of rw_decision3.
- As the code indicates, create directries as follows:

  \base01\[fortran files]    initial steay state (bas_no = 1)
         \ss_reform1\        final steady states 1-6 (cas_no = 1)
                    \run1    transition path 1 (run = 1)
                    \run2    transition path 2 (run = 2)
                    \...
  \base02                    alternative initial steady state (bas_no = 2)
  \...
  \temp1                     temporary files for transition path


3. Expected computation time

- About 10 minutes to solve the model for the initial steady-state equilibrium.
- About 150 minutes to solve the model for six final steady-state equilibria.
- About 40 hours to solve the model for each equlibrium transition path.
