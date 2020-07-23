classdef SkeletonCurveCalcV3 < handle
    %��ȡ�Ǽ����� V3
    properties (SetAccess=private)
        zero  %ԭʼ������λ������λ��
        Skeleton_plus %��һ��Ϊ�Ǽ������ڶ���Ϊ�Ǽ�λ��
        Skeleton_minus
        OnePointSkeleton_plus %ÿ�����ؼ�ֻ��һ����ĹǼ�����
        OnePointSkeleton_minus %ÿ�����ؼ�ֻ��һ����ĹǼ�����
        SmoothCurve %ƽ�����ͻ����ߣ�1��Ϊ����2��Ϊλ��
        kesi %������Ч����� �����桷��12.3.4-1), ��Ȧ��Ч
        Wc %ÿȦ���ص����, ��Ȧ����Ч
        TestForce %������, ԭʼ����
        TestDisp %������, ԭʼ����
        level %ÿ������Ȧ����������
    end
    
    properties (Access=private)
        PeakTol=0.02 %��С��ֵ, ���Ե�С�ڴ˰ٷֱȵ�
        window=50 %ƽ������
    end
    
    methods
        function obj = SkeletonCurveCalcV3(TestDisp,TestForce,level)
            if nargin == 3
                obj.TestDisp = TestDisp;
                obj.TestForce = TestForce;
                obj.level = level;
            end
            %��TestDisp, TestForce��β����һ��0,0��, ��ֹ����Ȧû�й��㵼���޷�ʶ��
            obj.TestDisp = vertcat(obj.TestDisp, 0);
            obj.TestForce = vertcat(obj.TestForce, 0);
            %��������λ�����λ��zero�͹Ǽ�����
            ObtainSkeletonCurve(obj);
            %ƽ�����ͻ�����
            ObtainSmoothCurve(obj);
        end
        function ObtainZeropoint(obj)
            %�˹�ʶ��0��
            %���ԭ��������
            ObtainSkeletonCurve(obj); %���ùǼܵ�
            obj.OnePointSkeleton_plus = [];
            obj.OnePointSkeleton_minus= [];
            obj.kesi= [];
            obj.Wc= [];
            %�˹�ʶ��0��
            ObtainZeropoint_app(obj);
        end
        function ObtainSkeletonPoints(obj)
            %�����˹�ʶ���0��֮���ȡ�Ǽܵ�
            ObtainSkeletonPoints_app(obj);
        end
        function set_zero(obj, newZero)
            %������㲢��ȡ�Զ�ʶ��ĹǼ�����
            %�ı����λ������zero
            obj.zero = newZero;
            %��ȡ�Զ�ʶ��ĹǼ�����
            ObtainSkeletonCurveWithZeros(obj);
            ObtainOnePointSkeletonCurveWithZeros(obj);
            CalculateKesi(obj);
        end
        function set_Skeleton(obj, newSkeleton_plus, newSkeleton_minus)
            %�޸ĹǼܵ�, ����Ӧ������������
            obj.Skeleton_plus = newSkeleton_plus;
            obj.Skeleton_minus = newSkeleton_minus;
            %����OnePointSkeleton
            ObtainOnePointSkeletonCurveWithZeros(obj);
            %����ϵ��
            CalculateKesi(obj);
        end
        function set_smooth(obj, win)
            %����ƽ������
            obj.window = win;
            ObtainSmoothCurve(obj);
        end
        function set_PeakTol(obj, tol)
            %������С��ֵ, ���Ե�С�ڴ˰ٷֱȵ�
            obj.PeakTol = tol;
            %������������
            ObtainSkeletonCurve(obj);
            obj.OnePointSkeleton_plus = [];
            obj.OnePointSkeleton_minus= [];
            obj.kesi= [];
            obj.Wc= [];
        end
        function reset_skeleton(obj)
            %���ùǼܵ�Ϊ��ʼ�Զ�ʶ���
            ObtainSkeletonCurveWithZeros(obj);
            ObtainOnePointSkeletonCurveWithZeros(obj);
            CalculateKesi(obj);
        end
        function output(obj)
            %����ļ�
            OutputFigure(obj);
        end
    end
        
    methods (Access=private)
        function ObtainSkeletonCurve(obj)
            %��ȡ�Ǽ�����, ��������, ���λ�����λ��
            
            %��ʶ��λ��0��
            k=1;  %λ��0������
            %��һ����
            temp(k,1)=1; 
            temp(k,2)=obj.TestDisp(1,1);
            %������
            for i=1:(size(obj.TestDisp,1)-1)
                if obj.TestDisp(i,1)*obj.TestDisp(i+1,1) <= 0
                    k=k+1;
                    temp(k,1)=i; 
                    temp(k,2)=obj.TestDisp(i,1);
                end
            end
            %����0��ʶ���ͻػ�
            obj.Skeleton_plus=[0;0];
            obj.Skeleton_minus=[0;0];
            obj.zero=[]; no=0;
            kplus=0; kminus=0; %�Ǽܵ����
            i=1;j=2;
            while j<= size(temp,1)
                if max(obj.TestDisp(temp(i,1):temp(j,1),1)) > obj.PeakTol*max(obj.TestDisp)
                    kplus=kplus+1;
                    [M,I] = max(obj.TestDisp(temp(i,1):temp(j,1),1));
                    obj.Skeleton_plus(2,kplus+1)=M;
                    obj.Skeleton_plus(1,kplus+1)=obj.TestForce(temp(i,1)+I-1,1);
                    %���λ��
                    no=no+1; obj.zero(no)=temp(i,1); 
                    obj.zero(no+1)=temp(j,1);
                    %����i,j
                    i=j; j=j+1;
                elseif abs(min(obj.TestDisp(temp(i,1):temp(j,1),1))) > obj.PeakTol*max(obj.TestDisp)
                    kminus=kminus+1;
                    [M,I] = min(obj.TestDisp(temp(i,1):temp(j,1),1));
                    obj.Skeleton_minus(2,kminus+1)=M;
                    obj.Skeleton_minus(1,kminus+1)=obj.TestForce(temp(i,1)+I-1,1);
                    %���λ��
                    no=no+1; obj.zero(no)=temp(i,1);
                    obj.zero(no+1)=temp(j,1);
                    %����i,j
                    i=j; j=j+1;
                else
                    %����j
                    j=j+1;
                end
            end
            if obj.zero(1) ~= 1
                obj.zero=horzcat(1,obj.zero); %��0��ʼ
            end
        end
        function ObtainSkeletonCurveWithZeros(obj)
            %�˹�ʶ��0��֮�����Ǽ�����
            
            tempPlusSkeleton=[0;0];
            tempMinusSkeleton=[0;0];
            
            %0��
            zp=obj.zero;
            
            %�Ǽ�����
            for i=2:size(zp,2)
                tempdispVector=obj.TestDisp(zp(i-1):zp(i),1)';
                tempforceVector=obj.TestForce(zp(i-1):zp(i),1)';
                if abs(max(tempdispVector)) > abs(min(tempdispVector)) 
                    %��ֵ
                    [M,I]=max(tempdispVector);
                    tempPlusSkeleton=horzcat(tempPlusSkeleton,[tempforceVector(I);M]);
                elseif abs(max(tempdispVector)) < abs(min(tempdispVector))
                    %��ֵ
                    [M,I]=min(tempdispVector);
                    tempMinusSkeleton=horzcat(tempMinusSkeleton,[tempforceVector(I);M]);
                end
            end
            
            %��ֵ
            obj.Skeleton_plus=tempPlusSkeleton;
            obj.Skeleton_minus=tempMinusSkeleton;
            
        end
        function ObtainOnePointSkeletonCurveWithZeros(obj)
            % ���ݼ���Ȧ����ʶ���һȦ�ĹǼ�����
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
            %���㸽����Ч����Ⱥ��ͻ����
            %�ͻ����, ��Ȧ��Ч
            for i=1:int8(floor((size(obj.zero,2)-1)/2)) %λ��0��
                y=obj.TestDisp(obj.zero(2*i-1):obj.zero(2*i+1),1)';
                x=obj.TestForce(obj.zero(2*i-1):obj.zero(2*i+1),1)';
                %pgon = polyshape(x,y);
                %obj.Wc(i)=area(pgon);
                %�������
                obj.Wc(i)=0;
                for xi=1:(size(x,2)-1)
                    obj.Wc(i)=obj.Wc(i)+(y(xi+1)-y(xi))*(x(xi+1)+x(xi))/2;
                end
            end
            %�����
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
            %��ȡƽ���ͻ�����
            SmoothDisp = smoothdata(obj.TestDisp,1,'movmean',obj.window);
            SmoothForce = smoothdata(obj.TestForce,1,'movmean',obj.window);
            obj.SmoothCurve =horzcat(SmoothForce,SmoothDisp);
        end
    end
end

