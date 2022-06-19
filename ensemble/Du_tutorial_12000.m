clc
clear all;
close all;
 
CG_Data1 =  load ('/home/cyx/comatrix/co_FFHQ_stygan2_train.mat');%提取所有CG数据
%CG_Data2 =  load ('/home/cyx/comatrix/co_FFHQ_stygan2_validation.mat');
%CG_Data3 =  load ('/home/cyx/comatrix/co_FFHQ_stygan2_test.mat');
CG_Data1 = CG_Data1.decrypt_F;
%CG_Data2 = CG_Data2.decrypt_F;
%CG_Data3 = CG_Data3.decrypt_F;
%C=[CG_Data1;CG_Data2;CG_Data3];
C=[CG_Data1];

NI_Data1 = load ('/home/cyx/comatrix/co_FFHQ_train.mat');%提取所有NI数据
%NI_Data2 = load ('/home/cyx/comatrix/co_FFHQ_validation.mat');
%NI_Data3 = load ('/home/cyx/comatrix/co_FFHQ_test.mat');
NI_Data1 = NI_Data1.decrypt_F;
%NI_Data2 = NI_Data2.decrypt_F;
%NI_Data3 = NI_Data3.decrypt_F;
%S=[NI_Data1;NI_Data2;NI_Data3];
S=[NI_Data1];

TRN_prcg = C(1:6000,:);
TRN_pim = S(1:6000,:);

TST_prcg = C(6001:10000,:);
TST_pim = S(6001:10000,:);

[trained_ensemble,~] = ensemble_training(TRN_prcg,TRN_pim);

test_results_prcg = ensemble_testing(TST_prcg,trained_ensemble);
test_results_pim = ensemble_testing(TST_pim,trained_ensemble);

false_alarms = sum(test_results_prcg.predictions~=-1);%虚警率
missed_detections = sum(test_results_pim.predictions~=+1);%漏检率

Label1=test_results_prcg.predictions;
Label2=test_results_pim.predictions;
Label=[Label1;Label2];

num_testing_samples = size(TST_prcg,1)+size(TST_pim,1);
testing_error = (false_alarms + missed_detections)/num_testing_samples
accuracy=1-testing_error;
