M = dlmread('分级用数据.txt');
TestDisp=M(:,2); TestForce=M(:,1);
% level=[1 1 2 2 2 3 3]; %每级加载次数
level=[3 3 3 3 2 2 2 2 2 2 1];
% 1 2 2 1 1 1 3 3 3 3 1
obj = SkeletonCurveCalcV3(TestDisp,TestForce,level);
ObtainZeropoint(obj);


