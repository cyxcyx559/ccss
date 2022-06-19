function results = ensemble_testing(X,trained_ensemble)

votes = zeros(size(X,1),1);
for i = 1:length(trained_ensemble)
    proj = X(:,trained_ensemble{i}.subspace)*trained_ensemble{i}.w-trained_ensemble{i}.b;
    votes = votes+sign(proj);
end

% resolve ties randomly
votes(votes==0) = rand(sum(votes==0),1)-0.5;
% form final predictions
results.predictions = sign(votes);
% output also the sum of the individual votes (~confidence info)
results.votes = votes;
