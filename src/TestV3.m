M = dlmread('�ּ�������.txt');
TestDisp=M(:,2); TestForce=M(:,1);
% level=[1 1 2 2 2 3 3]; %ÿ�����ش���
level=[3 3 3 3 2 2 2 2 2 2 1];
% 1 2 2 1 1 1 3 3 3 3 1
obj = SkeletonCurveCalcV3(TestDisp,TestForce,level);
ObtainZeropoint(obj);


