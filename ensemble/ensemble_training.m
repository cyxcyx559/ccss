function [trained_ensemble,results] = ensemble_training(Xc,Xs,settings)

if ~exist('settings','var'), settings.all_default = 1; end

[Xc,Xs,settings] = check_initial_setup(Xc,Xs,settings);

[SEARCH,settings,search_counter,MIN_OOB,OOB.error] = initialize_search(settings);

while SEARCH.in_progress
    search_counter = search_counter+1;

    [SEARCH.start_time_current_d_sub,i,next_random_subspace,TXT,base_learner] = deal(tic,0,1,'',cell(settings.max_number_base_learners,1));

    while next_random_subspace
        i = i+1;

        base_learner{i}.subspace = generate_random_subspace(settings.randstream.subspaces,settings.max_dim,settings.d_sub);

        OOB = bootstrap_initialization(Xc,Xs,OOB,settings);

        base_learner{i} = FLD_training(Xc,Xs,base_learner{i},OOB,settings);

        OOB = update_oob_error_estimates(Xc,Xs,base_learner{i},OOB,i);

        [next_random_subspace,MSG] = getFlag_nextRandomSubspace(i,OOB,settings);

        CT = double(toc(SEARCH.start_time_current_d_sub));
        %TXT = updateTXT(TXT,sprintf(' - d_sub %s : OOB %.4f : L %i : T %.1f sec%s',k_to_string(settings.d_sub),OOB.error,i,CT,MSG),settings);

    end % while next_random_subspace

    results.search.d_sub(search_counter) = settings.d_sub;
    %updateLog_swipe(settings,'\n');

    if OOB.error<MIN_OOB
        % found the best value of k so far
        MIN_OOB = OOB.error;
        results.optimal_L = i;
        results.optimal_d_sub = settings.d_sub;
        results.optimal_OOB = OOB.error;
        results.OOB_progress = OOB.y;
        trained_ensemble = base_learner(1:i);
    end

    [settings,SEARCH] = update_search(settings,SEARCH,OOB.error);
    results = add_search_info(results,settings,search_counter,SEARCH,i,CT);
    clear base_learner OOB
    OOB.error = 1;
end % while search_in_progress

% training time evaluation
%results.training_time = toc(uint64(settings.start_time));
%updateLog_swipe(settings,'# -------------------------\n');
%updateLog_swipe(settings,sprintf('optimal d_sub %i : OOB %.4f : L %i : T %.1f sec\n',results.optimal_d_sub,results.optimal_OOB,results.optimal_L,results.training_time),1);


function [Xc,Xs,settings] = check_initial_setup(Xc,Xs,settings)

if size(Xc,2)~=size(Xs,2)
    error('Ensemble error: cover/stego features must have the same dimension.');
end
if size(Xc,1)~=size(Xs,1)
    error('Ensemble error: cover/stego feature matrices must have the same number of rows (corresponding images!).');
end

Xc = single(Xc);
Xs = single(Xs);

settings.start_time = tic;
settings.randstream.main = RandStream('mt19937ar','Seed',sum(100*clock));
% if PRNG seeds for random subspaces and bootstrap samples not specified, generate them randomly
if ~isfield(settings,'seed_subspaces')
    settings.seed_subspaces = ceil(rand(settings.randstream.main)*1e9);
end
if ~isfield(settings,'seed_bootstrap')
    settings.seed_bootstrap = ceil(rand(settings.randstream.main)*1e9);
end

settings.randstream.subspaces = RandStream('mt19937ar','Seed',settings.seed_subspaces);
settings.randstream.bootstrap = RandStream('mt19937ar','Seed',settings.seed_bootstrap);

if ~isfield(settings,'L'), settings.L = 'automatic'; end
if ~isfield(settings,'d_sub'), settings.d_sub = 'automatic'; end
if ~isfield(settings,'verbose'), settings.verbose = 1; end
if ~isfield(settings,'max_number_base_learners'), settings.max_number_base_learners = 500; end

% Set default values for the automatic stopping criterion for L
if ischar(settings.L)
    if ~isfield(settings,'L_kernel'),     settings.L_kernel = ones(1,5)/5; end
    if ~isfield(settings,'L_min_length'), settings.L_min_length = 25; end
    if ~isfield(settings,'L_memory'),     settings.L_memory = 50; end
    if ~isfield(settings,'L_epsilon'),    settings.L_epsilon = 0.005; end
    settings.bootstrap = 1;
end
if ~isfield(settings,'ignore_nearly_singular_matrix_warning')
    settings.ignore_nearly_singular_matrix_warning = 1;
end

% Set default values for the search for the subspace dimension d_sub
if ischar(settings.d_sub)
    if ~isfield(settings,'Eoob_tolerance'), settings.Eoob_tolerance = 0.02; end
    if ~isfield(settings,'d_sub_step'), settings.d_sub_step = 200; end
    settings.bootstrap = 1;
    settings.search_for_d_sub = 1;
else
    settings.search_for_d_sub = 0;
end

settings.max_dim = size(Xc,2);

% if full dimensionality is 1, just do a single FLD
if settings.max_dim == 1
    settings.d_sub = 1;
    settings.search_for_d_sub = 0;
end

initial_screen_output(Xc,Xs,settings);

function initial_screen_output(Xc,Xs,settings)
% initial screen output
if settings.verbose~=1,return; end
fprintf('# -------------------------\n');
fprintf('# Ensemble classification\n');
fprintf('#  - Training samples: %i (%i/%i)\n',size(Xc,1)+size(Xs,1),size(Xc,1),size(Xs,1));
fprintf('#  - Feature-space dimensionality: %i\n',size(Xc,2));
%if ~ischar(settings.L)
    %fprintf('#  - L : %i\n',settings.L);
%else
    %fprintf('#  - L : %s (min %i, max %i, length %i, eps %.5f)\n',settings.L,settings.L_min_length,settings.max_number_base_learners,settings.L_memory,settings.L_epsilon);
%end
%if ischar(settings.d_sub)
    %fprintf('#  - d_sub : automatic (Eoob tolerance %.4f, step %i)\n',settings.Eoob_tolerance,settings.d_sub_step);
%else
    %fprintf('#  - d_sub : %i\n',settings.d_sub);
%end

%fprintf('#  - Seed 1 (subspaces) : %i\n',settings.seed_subspaces);
%fprintf('#  - Seed 2 (bootstrap) : %i\n',settings.seed_bootstrap);
fprintf('# -------------------------\n');

function [next_random_subspace,TXT] = getFlag_nextRandomSubspace(i,OOB,settings)
% decide whether to generate another random subspace or not, based on the
% settings
TXT='';
if ischar(settings.L)
    if strcmp(settings.L,'automatic')
        % automatic criterion for termination
        next_random_subspace = 1;
        if ~isfield(OOB,'x'), next_random_subspace = 0; return; end
        if length(OOB.x)<settings.L_min_length, return; end
        A = convn(OOB.y(max(length(OOB.y)-settings.L_memory+1,1):end),settings.L_kernel,'valid');
        V = abs(max(A)-min(A));
        if V<settings.L_epsilon
            next_random_subspace = 0;
            return;
        end
        if i == settings.max_number_base_learners,
            % maximal number of base learners reached
            next_random_subspace = 0;
            TXT = ' (maximum reached)';
        end
        return;
    end
else
    % fixed number of random subspaces
    if i<settings.L
        next_random_subspace = 1;
    else
        next_random_subspace = 0;
    end
end

function [settings,SEARCH] = update_search(settings,SEARCH,currErr)
% update search progress
if ~settings.search_for_d_sub, SEARCH.in_progress = 0; return; end

SEARCH.E(settings.d_sub==SEARCH.x) = currErr;

% any other unfinished values of k?
unfinished = find(SEARCH.E==-1);
if ~isempty(unfinished), settings.d_sub = SEARCH.x(unfinished(1)); return; end

% check where is minimum
[MINIMAL_ERROR,minE_id] = min(SEARCH.E);

if SEARCH.step == 1 || MINIMAL_ERROR == 0
    % smallest possible step or error => terminate search
    SEARCH.in_progress = 0;
    SEARCH.optimal_d_sub = SEARCH.x(SEARCH.E==MINIMAL_ERROR);
    SEARCH.optimal_d_sub = SEARCH.optimal_d_sub(1);
    return;
end


if minE_id == 1
    % smallest k is the best => reduce step
    SEARCH.step = floor(SEARCH.step/2);
    SEARCH = add_gridpoints(SEARCH,SEARCH.x(1)+SEARCH.step*[-1 1]);
elseif minE_id == length(SEARCH.x)
    % largest k is the best
    if SEARCH.x(end) + SEARCH.step <= settings.max_dim && (min(abs(SEARCH.x(end) + SEARCH.step-SEARCH.x))>SEARCH.step/2)
        % continue to the right
        SEARCH = add_gridpoints(SEARCH,SEARCH.x(end) + SEARCH.step);
    else
        % hitting the full dimensionality
        if (MINIMAL_ERROR/SEARCH.E(end-1) >= 1 - settings.Eoob_tolerance) ... % desired tolerance fulfilled
            || SEARCH.E(end-1)-MINIMAL_ERROR < 5e-3 ... % maximal precision in terms of error set to 0.5%
            || SEARCH.step<SEARCH.x(minE_id)*0.05 ... % step is smaller than 5% of the optimal value of k
            % stopping criterion met
            SEARCH.in_progress = false;
            SEARCH.optimal_d_sub = SEARCH.x(SEARCH.E==MINIMAL_ERROR);
            SEARCH.optimal_d_sub = SEARCH.optimal_d_sub(1);
            return;
        else
            % reduce step
            SEARCH.step = floor(SEARCH.step/2);
            if SEARCH.x(end) + SEARCH.step <= settings.max_dim
                SEARCH = add_gridpoints(SEARCH,SEARCH.x(end)+SEARCH.step*[-1 1]);
            else
                SEARCH = add_gridpoints(SEARCH,SEARCH.x(end)-SEARCH.step);
            end;
        end
    end
elseif (minE_id == length(SEARCH.x)-1) ... % if lowest is the last but one
        && (settings.d_sub + SEARCH.step <= settings.max_dim) ... % one more step to the right is still valid (less than d)
        && (min(abs(settings.d_sub + SEARCH.step-SEARCH.x))>SEARCH.step/2) ... % one more step to the right is not too close to any other point
        && ~(SEARCH.E(end)>SEARCH.E(end-1) && SEARCH.E(end)>SEARCH.E(end-2)) % the last point is not worse than the two previous ones
    % robustness ensurance, try one more step to the right
    SEARCH = add_gridpoints(SEARCH,settings.d_sub + SEARCH.step);
else
    % best k is not at the edge of the grid (and robustness is resolved)
    err_around = mean(SEARCH.E(minE_id+[-1 1]));
    if (MINIMAL_ERROR/err_around >= 1 - settings.Eoob_tolerance) ... % desired tolerance fulfilled
        || err_around-MINIMAL_ERROR < 5e-3 ... % maximal precision in terms of error set to 0.5%
        || SEARCH.step<SEARCH.x(minE_id)*0.05 ... % step is smaller than 5% of the optimal value of k
        % stopping criterion met
        SEARCH.in_progress = false;
        SEARCH.optimal_d_sub = SEARCH.x(SEARCH.E==MINIMAL_ERROR);
        SEARCH.optimal_d_sub = SEARCH.optimal_d_sub(1);
        return;
    else
        % reduce step
        SEARCH.step = floor(SEARCH.step/2);
        SEARCH = add_gridpoints(SEARCH,SEARCH.x(minE_id)+SEARCH.step*[-1 1]);
    end
end

unfinished = find(SEARCH.E==-1);
settings.d_sub = SEARCH.x(unfinished(1));
return;
    
function [SEARCH,settings,search_counter,MIN_OOB,OOB_error] = initialize_search(settings)
% search for d_sub initialization
SEARCH.in_progress = 1;
if settings.search_for_d_sub
    % automatic search for d_sub
    if settings.d_sub_step >= settings.max_dim/4, settings.d_sub_step = floor(settings.max_dim/4); end
    if settings.max_dim < 10, settings.d_sub_step = 1; end
    SEARCH.x = settings.d_sub_step*[1 2 3];
    if settings.max_dim==2, SEARCH.x = [1 2]; end
    SEARCH.E = -ones(size(SEARCH.x));
    SEARCH.terminate = 0;
    SEARCH.step = settings.d_sub_step;
    settings.d_sub = SEARCH.x(1);
end

search_counter = 0;
MIN_OOB = 1;
OOB_error = 1;

function TXT = updateTXT(old,TXT,settings)
if isfield(settings,'kmin')
    if length(TXT)>3
        if ~strcmp(TXT(1:3),' - ')
            TXT = [' - ' TXT];
        end
    end
end
if settings.verbose==1
    if exist('/home','dir')
        % do not delete on cluster, it displays incorrectly when writing through STDOUT into file
        fprintf(['\n' TXT]);
    else
        fprintf([repmat('\b',1,length(old)) TXT]);
    end
end

function s = k_to_string(k)
if length(k)==1
    s = num2str(k);
    return;
end

s=['[' num2str(k(1))];
for i=2:length(k)
    s = [s ',' num2str(k(i))]; %#ok<AGROW>
end
s = [s ']'];

function updateLog_swipe(settings,TXT,final)
if ~exist('final','var'), final=0; end
if settings.verbose==1 || (settings.verbose==2 && final==1), fprintf(TXT); end

function OOB = bootstrap_initialization(Xc,Xs,OOB,settings)
% initialization of the structure for OOB error estimates
OOB.SUB = floor(size(Xc,1)*rand(settings.randstream.bootstrap,size(Xc,1),1))+1;
OOB.ID  = setdiff(1:size(Xc,1),OOB.SUB);
if ~isfield(OOB,'Xc')
    OOB.Xc.fusion_majority_vote = zeros(size(Xc,1),1); % majority voting fusion
    OOB.Xc.num = zeros(size(Xc,1),1); % number of fused votes
    OOB.Xs.fusion_majority_vote = zeros(size(Xs,1),1); % majority voting fusion
    OOB.Xs.num = zeros(size(Xs,1),1); % number of fused votes
end
if ~isfield(OOB,'randstream_for_ties')
    % Doesn't really matter that we fix the seed here. This will be used
    % only for resolving voting ties. We are fixing this in order to make
    % all results nicely reproducible.
    OOB.randstream_for_ties = RandStream('mt19937ar','Seed',1);
end


function [base_learner] = findThreshold(Xm,Xp,base_learner)
% find threshold through minimizing (MD+FA)/2, where MD stands for the
% missed detection rate and FA for the false alarms rate
P1 = Xm*base_learner.w;
P2 = Xp*base_learner.w;
L = [-ones(size(Xm,1),1);ones(size(Xp,1),1)];
[P,IX] = sort([P1;P2]);
L = L(IX);
Lm = (L==-1);
sgn = 1;

MD = 0;
FA = sum(Lm);
MD2=FA;
FA2=MD;
Emin = (FA+MD);
Eact = zeros(size(L-1));
Eact2 = Eact;
for idTr=1:length(P)-1
    if L(idTr)==-1
        FA=FA-1;
        MD2=MD2+1;
    else
        FA2=FA2-1;
        MD=MD+1;
    end
    Eact(idTr) = FA+MD;
    Eact2(idTr) = FA2+MD2;
    if Eact(idTr)<Emin
        Emin = Eact(idTr);
        iopt = idTr;
        sgn=1;
    end
    if Eact2(idTr)<Emin
        Emin = Eact2(idTr);
        iopt = idTr;
        sgn=-1;
    end
end

base_learner.b = sgn*0.5*(P(iopt)+P(iopt+1));
if sgn==-1, base_learner.w = -base_learner.w; end

function OOB = update_oob_error_estimates(Xc,Xs,base_learner,OOB,i)
% update OOB error estimates
OOB.Xc.proj = Xc(OOB.ID,base_learner.subspace)*base_learner.w-base_learner.b;
OOB.Xs.proj = Xs(OOB.ID,base_learner.subspace)*base_learner.w-base_learner.b;
OOB.Xc.num(OOB.ID) = OOB.Xc.num(OOB.ID) + 1;
OOB.Xc.fusion_majority_vote(OOB.ID) = OOB.Xc.fusion_majority_vote(OOB.ID)+sign(OOB.Xc.proj);
OOB.Xs.num(OOB.ID) = OOB.Xs.num(OOB.ID) + 1;
OOB.Xs.fusion_majority_vote(OOB.ID) = OOB.Xs.fusion_majority_vote(OOB.ID)+sign(OOB.Xs.proj);
% update errors
TMP_c = OOB.Xc.fusion_majority_vote; TMP_c(TMP_c==0) = rand(OOB.randstream_for_ties,sum(TMP_c==0),1)-0.5;
TMP_s = OOB.Xs.fusion_majority_vote; TMP_s(TMP_s==0) = rand(OOB.randstream_for_ties,sum(TMP_s==0),1)-0.5;
OOB.error = (sum(TMP_c>0)+sum(TMP_s<0))/(length(TMP_c)+length(TMP_s));

if ~ischar(OOB) && ~isempty(OOB)
    H = hist([OOB.Xc.num;OOB.Xs.num],0:max([OOB.Xc.num;OOB.Xs.num]));
    avg_L = sum(H.*(0:length(H)-1))/sum(H); % average L in OOB
    OOB.x(i) = avg_L;
    OOB.y(i) = OOB.error;
end

function base_learner = FLD_training(Xc,Xs,base_learner,OOB,settings)
% FLD TRAINING
Xm = Xc(OOB.SUB,base_learner.subspace);
Xp = Xs(OOB.SUB,base_learner.subspace);

% remove constants
remove = false(1,size(Xm,2));
adepts = unique([find(Xm(1,:)==Xm(2,:)) find(Xp(1,:)==Xp(2,:))]);
for ad_id = adepts
    U1=unique(Xm(:,ad_id));
    if numel(U1)==1
        U2=unique(Xp(:,ad_id));
        if numel(U2)==1, if U1==U2, remove(ad_id) = true; end; end
    end
end

muC  = sum(Xm,1); muC = double(muC)/size(Xm,1);
muS  = sum(Xp,1); muS = double(muS)/size(Xp,1);
mu = (muS-muC)';

% calculate sigC
xc = bsxfun(@minus,Xm,muC);
sigC = xc'*xc;
sigC = double(sigC)/size(Xm,1);

% calculate sigS
xc = bsxfun(@minus,Xp,muS);
sigS = xc'*xc;
sigS = double(sigS)/size(Xp,1);

sigCS = sigC + sigS;

% regularization
sigCS = sigCS + 1e-10*eye(size(sigC,1));

% check for NaN values (may occur when the feature value is constant over images)
nan_values = sum(isnan(sigCS))>0;
nan_values = nan_values | remove;

sigCS = sigCS(~nan_values,~nan_values);
mu = mu(~nan_values);
lastwarn('');
warning('off','MATLAB:nearlySingularMatrix');
warning('off','MATLAB:singularMatrix');
base_learner.w = sigCS\mu;
% regularization (if necessary)
[txt,warnid] = lastwarn(); %#ok<ASGLU>
while strcmp(warnid,'MATLAB:singularMatrix') || (strcmp(warnid,'MATLAB:nearlySingularMatrix') && ~settings.ignore_nearly_singular_matrix_warning)
    lastwarn('');
    if ~exist('counter','var'), counter=1; else counter = counter*5; end
    sigCS = sigCS + counter*eps*eye(size(sigCS,1));
    base_learner.w = sigCS\mu;
    [txt,warnid] = lastwarn(); %#ok<ASGLU>
end    
warning('on','MATLAB:nearlySingularMatrix');
warning('on','MATLAB:singularMatrix');
if length(sigCS)~=length(sigC)
    % resolve previously found NaN values, set the corresponding elements of w equal to zero
    w_new = zeros(length(sigC),1);
    w_new(~nan_values) = base_learner.w;
    base_learner.w = w_new;
end

% find threshold to minimize FA+MD
[base_learner] = findThreshold(Xm,Xp,base_learner);

function results = add_search_info(results,settings,search_counter,SEARCH,i,CT)
% update information about d_sub search
if settings.search_for_d_sub
    results.search.OOB(search_counter)  = SEARCH.E(SEARCH.x==results.search.d_sub(search_counter));
    results.search.L(search_counter) = i;
    results.search.time(search_counter) = CT;
end

function SEARCH = add_gridpoints(SEARCH,points)
% add new points for the search for d_sub
for point=points
    if SEARCH.x(1)>point
        SEARCH.x = [point SEARCH.x];
        SEARCH.E = [-1 SEARCH.E];
        continue;
    end
    if SEARCH.x(end)<point
        SEARCH.x = [SEARCH.x point];
        SEARCH.E = [SEARCH.E -1];
        continue;
    end
    pos = 2;
    while SEARCH.x(pos+1)<point,pos = pos+1; end
    SEARCH.x = [SEARCH.x(1:pos-1) point SEARCH.x(pos:end)];
    SEARCH.E = [SEARCH.E(1:pos-1) -1 SEARCH.E(pos:end)];
end

function subspace = generate_random_subspace(randstr,max_dim,d_sub)
subspace = randperm(randstr,max_dim);
subspace = subspace(1:d_sub);
