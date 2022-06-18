function F = spam686(IMG)
%IMG = '1.jpg';
IMG_1 = imread(IMG);
X = rgb2gray(IMG_1);
F = spam_extract_2(X,3);
end
%X1 = IMG_1(:,:,1);%R
%F1 = spam_extract_2(X1,3);
%F1 = F1';

%X2 = IMG_1(:,:,2);%G
%F2 = spam_extract_2(X2,3);
%F2 = F2';

%XX1 = im2uint8(rgb2hsv(IMG_1));
%X3 = XX1(:,:,3);
%F3 = spam_extract_2(X3,3);
%F3 = F3';

%XX2 = im2uint8(rgb2ycbcr(IMG_1));
%X4 = XX2(:,:,1);
%F4 = spam_extract_2(X4,3);
%F4 = F4';
%F = spam_extract_2((imread(IMG)),3);
%F = [F1 F2 F3 F4]';
