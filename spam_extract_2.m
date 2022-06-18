function F = spam_extract_2(X,T)
%X=rgb2ycbcr(X);
%X = X(:,:,1);
% horizontal left-right
D = X(:,1:end-1) - X(:,2:end);
L = D(:,3:end); C = D(:,2:end-1); R = D(:,1:end-2);
Mh1 = GetM3(L,C,R,T);

% horizontal right-left
D = -D;
L = D(:,1:end-2); C = D(:,2:end-1); R = D(:,3:end);
Mh2 = GetM3(L,C,R,T);
% vertical bottom top
D = X(1:end-1,:) - X(2:end,:);
L = D(3:end,:); C = D(2:end-1,:); R = D(1:end-2,:);
Mv1 = GetM3(L,C,R,T);

% vertical top bottom
D = -D;
L = D(1:end-2,:); C = D(2:end-1,:); R = D(3:end,:);
Mv2 = GetM3(L,C,R,T);

% diagonal left-right
D = X(1:end-1,1:end-1) - X(2:end,2:end);
L = D(3:end,3:end); C = D(2:end-1,2:end-1); R = D(1:end-2,1:end-2);
Md1 = GetM3(L,C,R,T);

% diagonal right-left
D = -D;
L = D(1:end-2,1:end-2); C = D(2:end-1,2:end-1); R = D(3:end,3:end);
Md2 = GetM3(L,C,R,T);

% minor diagonal left-right
D = X(2:end,1:end-1) - X(1:end-1,2:end);
L = D(1:end-2,3:end); C = D(2:end-1,2:end-1); R = D(3:end,1:end-2);
Mm1 = GetM3(L,C,R,T);

% minor diagonal right-left
D = -D;
L = D(3:end,1:end-2); C = D(2:end-1,2:end-1); R = D(1:end-2,3:end);
Mm2 = GetM3(L,C,R,T);

F1 = (Mh1+Mh2+Mv1+Mv2)/4;
F2 = (Md1+Md2+Mm1+Mm2)/4;
F = [F1;F2];

function M = GetM3(L,C,R,T)
% marginalization into borders
L = L(:); L(L<-T) = -T; L(L>T) = T;%一行 小于-T(3)的等于-T(3) 大于3的等于3
C = C(:); C(C<-T) = -T; C(C>T) = T;
R = R(:); R(R<-T) = -T; R(R>T) = T;

% get cooccurences [-T...T]
M = zeros(2*T+1,2*T+1,2*T+1);%7x7x7
for i=-T:T
    C2 = C(L==i);%L=i的位置对应C的数
    R2 = R(L==i);
    for j=-T:T
        R3 = R2(C2==j);
        for k=-T:T
            M(i+T+1,j+T+1,k+T+1) = sum(R3==k);%=k的个数
        end
    end
end

% normalization
M = M(:)/sum(M(:));
