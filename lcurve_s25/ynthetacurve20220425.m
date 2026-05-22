%%%%
%    本程序的目的是画出云南重震联合反演的L-curve和theta-curve
%    Author        :: Haopeng Chen
%    Creatied time :: 2021.02.03 00:30
%    Modified time :: 2022.04.25 21:40
%%%%
clear
close all

% %%%%%
% %    lcurveall_nonm_i01.txt  the first iteration 
% %    lcurveall_i10.txt      the 10th iteration
% %   format :: smooth damping  ||WsRs|| ||WgRg|| resiall ||Dm|| ||m|| 
% %%%%%%

file1=load('E:\matlab\lcurveall_i10.txt');
%file2=load('D:\matlabcode\matlabynjoint\inv_202204\lcurve\lcurveall_d50.txt');
%file3=load('D:\matlabcode\matlabynjoint\inv_202204\lcurve\lcurveall_d100.txt');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure(1) 

sm1=file1(:,1);
xx1=file1(:,5);
yy1=file1(:,6);
zz1=file1(:,7);
smstr1=num2str(sm1);
nn1=length(xx1);

%sm2=file2(:,1);
%xx2=file2(:,5);
%yy2=file2(:,6);
%zz2=file2(:,7);
%smstr2=num2str(sm2);
%nn2=length(xx2);

%sm3=file3(:,1);
%xx3=file3(:,5);
%yy3=file3(:,6);
%zz3=file3(:,7);
%smstr3=num2str(sm3);
%nn3=length(xx3);


% %%%%%
% %    
% %%%%%
xx1=xx1.*xx1;
yy1=yy1.*yy1;

%xx2=xx2.*xx2;
%yy2=yy2.*yy2;

%xx3=xx3.*xx3;
%yy3=yy3.*yy3;



figure(1)
plot(xx1,yy1,'.-r','LineWidth',2,'MarkerSize',14)
hold on
text(xx1,yy1,smstr1,'color','b')
xlabel('||Wr||_2^2')
ylabel('||Dm||_2^2')
%legend('damp10')

%figure(2)
%plot(xx2,yy2,'.-r','LineWidth',2,'MarkerSize',14)
%hold on
%text(xx2,yy2,smstr2,'color','b')
%xlabel('||Wr||_2^2')
%ylabel('||Dm||_2^2')
%legend('damp50')

%figure(3)
%plot(xx3,yy3,'.-r','LineWidth',2,'MarkerSize',14)
%hold on
%text(xx3,yy3,smstr3,'color','b')
%xlabel('||Wr||_2^2')
%ylabel('||Dm||_2^2')
%legend('damp100')




