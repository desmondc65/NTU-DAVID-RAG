
%BKP RED2014 
% Section 3.2. Income process and intergenerational dynamics

x=[0.68 0.32; 0.28 0.72]
X=x^1000

f = [0.69 0.31; 0.43 0.57]
F = f^1000

fl=-0.4;fh=0.55;
al=-0.37;ah=0.33;

z1= fl+al;z2=fl+ah;z3=fh+al;z4=fh+ah;

a_avg = al*X(1,1)+ah*X(1,2)
a_var = (al-a_avg)^2*X(1,1)+(ah-a_avg)^2*X(1,2)

f_avg = fl*F(1,1)+fh*F(1,2)
f_sd = (fl-f_avg)^2*F(1,1)+(fh-f_avg)^2*F(1,2)

