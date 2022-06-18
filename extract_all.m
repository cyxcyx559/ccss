clc; 
clear all;
tic;

file_path='D:\pic\FFHQ\FFHQ\';

img_path_list = dir(strcat(file_path,'*.png'));


n=20000;

for i = 1:n
    image_name = img_path_list(i).name;
    imagePath = strcat(file_path,image_name);
    fprintf('SPAM extraction');

    t_start = tic;
    F( i , : ) = spam686(imagePath);
    t_end = toc(t_start);

    fprintf(['The', num2str(i) ,'pictures','\n']);
end

toc;
