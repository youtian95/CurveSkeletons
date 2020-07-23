classdef SkeletonCurveCalcV3 < handle
    %提取骨架曲线 V3
    properties (SetAccess=private)
        zero  %原始数据中位移零点的位置
        Skeleton_plus %第一行为骨架力，第二行为骨架位移
        Skeleton_minus
        OnePointSkeleton_plus %每个加载级只有一个点的骨架曲线
        OnePointSkeleton_minus %每个加载级只有一个点的骨架曲线
        SmoothCurve %平滑的滞回曲线，1列为力，2列为位移
        kesi %附加有效阻尼比 《抗规》（12.3.4-1), 整圈有效
        Wc %每圈加载的面积, 整圈才有效
        TestForce %列向量, 原始数据
        TestDisp %列向量, 原始数据
        level %每级加载圈数，行向量
    end
    
    properties (Access=private)
        PeakTol=0.02 %最小峰值, 忽略掉小于此百分比的
        window=50 %平滑窗口
    end
    
    methods
        function obj = SkeletonCurveCalcV3(TestDisp,TestForce,level)
            if nargin == 3
                obj.TestDisp = TestDisp;
                obj.TestForce = TestForce;
                obj.level = level;
            end
            %给TestDisp, TestForce结尾增加一个0,0点, 防止最后半圈没有归零导致无法识别
            obj.TestDisp = vertcat(obj.TestDisp, 0);
            obj.TestForce = vertcat(obj.TestForce, 0);
            %初步计算位移零点位置zero和骨架曲线
            ObtainSkeletonCurve(obj);
            %平滑的滞回曲线
            ObtainSmoothCurve(obj);
        end
        function ObtainZeropoint(obj)
            %人工识别0点
            %清空原来的数据
            ObtainSkeletonCurve(obj); %重置骨架点
            obj.OnePointSkeleton_plus = [];
            obj.OnePointSkeleton_minus= [];
            obj.kesi= [];
            obj.Wc= [];
            %人工识别0点
            ObtainZeropoint_app(obj);
        end
        function ObtainSkeletonPoints(obj)
            %有了人工识别的0点之后获取骨架点
            ObtainSkeletonPoints_app(obj);
        end
        function set_zero(obj, newZero)
            %重置零点并获取自动识别的骨架曲线
            %改变零点位置向量zero
            obj.zero = newZero;
            %获取自动识别的骨架曲线
            ObtainSkeletonCurveWithZeros(obj);
            ObtainOnePointSkeletonCurveWithZeros(obj);
            CalculateKesi(obj);
        end
        function set_Skeleton(obj, newSkeleton_plus, newSkeleton_minus)
            %修改骨架点, 并相应调整其它数据
            obj.Skeleton_plus = newSkeleton_plus;
            obj.Skeleton_minus = newSkeleton_minus;
            %调整OnePointSkeleton
            ObtainOnePointSkeletonCurveWithZeros(obj);
            %耗能系数
            CalculateKesi(obj);
        end
        function set_smooth(obj, win)
            %设置平滑曲线
            obj.window = win;
            ObtainSmoothCurve(obj);
        end
        function set_PeakTol(obj, tol)
            %设置最小峰值, 忽略掉小于此百分比的
            obj.PeakTol = tol;
            %重置其他数据
            ObtainSkeletonCurve(obj);
            obj.OnePointSkeleton_plus = [];
            obj.OnePointSkeleton_minus= [];
            obj.kesi= [];
            obj.Wc= [];
        end
        function reset_skeleton(obj)
            %重置骨架点为初始自动识别点
            ObtainSkeletonCurveWithZeros(obj);
            ObtainOnePointSkeletonCurveWithZeros(obj);
            CalculateKesi(obj);
        end
        function output(obj)
            %输出文件
            OutputFigure(obj);
        end
    end
        
    methods (Access=private)
        function ObtainSkeletonCurve(obj)
            %获取骨架曲线, 初步处理, 获得位移零点位置
            
            %先识别位移0点
            k=1;  %位移0点数量
            %第一个数
            temp(k,1)=1; 
            temp(k,2)=obj.TestDisp(1,1);
            %其它数
            for i=1:(size(obj.TestDisp,1)-1)
                if obj.TestDisp(i,1)*obj.TestDisp(i+1,1) <= 0
                    k=k+1;
                    temp(k,1)=i; 
                    temp(k,2)=obj.TestDisp(i,1);
                end
            end
            %根据0点识别滞回环
            obj.Skeleton_plus=[0;0];
            obj.Skeleton_minus=[0;0];
            obj.zero=[]; no=0;
            kplus=0; kminus=0; %骨架点个数
            i=1;j=2;
            while j<= size(temp,1)
                if max(obj.TestDisp(temp(i,1):temp(j,1),1)) > obj.PeakTol*max(obj.TestDisp)
                    kplus=kplus+1;
                    [M,I] = max(obj.TestDisp(temp(i,1):temp(j,1),1));
                    obj.Skeleton_plus(2,kplus+1)=M;
                    obj.Skeleton_plus(1,kplus+1)=obj.TestForce(temp(i,1)+I-1,1);
                    %零点位置
                    no=no+1; obj.zero(no)=temp(i,1); 
                    obj.zero(no+1)=temp(j,1);
                    %更新i,j
                    i=j; j=j+1;
                elseif abs(min(obj.TestDisp(temp(i,1):temp(j,1),1))) > obj.PeakTol*max(obj.TestDisp)
                    kminus=kminus+1;
                    [M,I] = min(obj.TestDisp(temp(i,1):temp(j,1),1));
                    obj.Skeleton_minus(2,kminus+1)=M;
                    obj.Skeleton_minus(1,kminus+1)=obj.TestForce(temp(i,1)+I-1,1);
                    %零点位置
                    no=no+1; obj.zero(no)=temp(i,1);
                    obj.zero(no+1)=temp(j,1);
                    %更新i,j
                    i=j; j=j+1;
                else
                    %更新j
                    j=j+1;
                end
            end
            if obj.zero(1) ~= 1
                obj.zero=horzcat(1,obj.zero); %从0开始
            end
        end
        function ObtainSkeletonCurveWithZeros(obj)
            %人工识别0点之后计算骨架曲线
            
            tempPlusSkeleton=[0;0];
            tempMinusSkeleton=[0;0];
            
            %0点
            zp=obj.zero;
            
            %骨架曲线
            for i=2:size(zp,2)
                tempdispVector=obj.TestDisp(zp(i-1):zp(i),1)';
                tempforceVector=obj.TestForce(zp(i-1):zp(i),1)';
                if abs(max(tempdispVector)) > abs(min(tempdispVector)) 
                    %正值
                    [M,I]=max(tempdispVector);
                    tempPlusSkeleton=horzcat(tempPlusSkeleton,[tempforceVector(I);M]);
                elseif abs(max(tempdispVector)) < abs(min(tempdispVector))
                    %负值
                    [M,I]=min(tempdispVector);
                    tempMinusSkeleton=horzcat(tempMinusSkeleton,[tempforceVector(I);M]);
                end
            end
            
            %赋值
            obj.Skeleton_plus=tempPlusSkeleton;
            obj.Skeleton_minus=tempMinusSkeleton;
            
        end
        function ObtainOnePointSkeletonCurveWithZeros(obj)
            % 根据加载圈数仅识别第一圈的骨架曲线
            obj.OnePointSkeleton_plus = [];
            obj.OnePointSkeleton_minus = [];
            for i=1:size(obj.level,2)
                if (sum(obj.level(1:i))-obj.level(i)+1+1) <= size(obj.Skeleton_plus,2)
                    obj.OnePointSkeleton_plus(:,i)=obj.Skeleton_plus(:,(sum(obj.level(1:i))-obj.level(i)+1+1));
                end
                if (sum(obj.level(1:i))-obj.level(i)+1+1) <= size(obj.Skeleton_minus,2)
                    obj.OnePointSkeleton_minus(:,i)=obj.Skeleton_minus(:,(sum(obj.level(1:i))-obj.level(i)+1+1));
                end
            end
            obj.OnePointSkeleton_plus=horzcat(zeros(2,1),obj.OnePointSkeleton_plus);
            obj.OnePointSkeleton_minus=horzcat(zeros(2,1),obj.OnePointSkeleton_minus);
        end
        function CalculateKesi(obj) 
            %计算附加有效阻尼比和滞回面积
            %滞回面积, 整圈有效
            for i=1:int8(floor((size(obj.zero,2)-1)/2)) %位移0点
                y=obj.TestDisp(obj.zero(2*i-1):obj.zero(2*i+1),1)';
                x=obj.TestForce(obj.zero(2*i-1):obj.zero(2*i+1),1)';
                %pgon = polyshape(x,y);
                %obj.Wc(i)=area(pgon);
                %计算面积
                obj.Wc(i)=0;
                for xi=1:(size(x,2)-1)
                    obj.Wc(i)=obj.Wc(i)+(y(xi+1)-y(xi))*(x(xi+1)+x(xi))/2;
                end
            end
            %阻尼比
            obj.kesi=[];
            col = min(size(obj.Skeleton_plus,2), size(obj.Skeleton_minus,2)) - 1;
            for i=1:col
                if (obj.Skeleton_plus(1,i+1)*obj.Skeleton_minus(1,i+1))~=0
                    obj.kesi(i)=obj.Wc(i)/(2*3.14* ...
                        (obj.Skeleton_plus(1,i+1)*obj.Skeleton_plus(2,i+1)+obj.Skeleton_minus(1,i+1)*obj.Skeleton_minus(2,i+1)) ...
                        ./2);                  
                end
            end
            
        end
        function ObtainSmoothCurve(obj)
            %获取平滑滞回曲线
            SmoothDisp = smoothdata(obj.TestDisp,1,'movmean',obj.window);
            SmoothForce = smoothdata(obj.TestForce,1,'movmean',obj.window);
            obj.SmoothCurve =horzcat(SmoothForce,SmoothDisp);
        end
    end
end

