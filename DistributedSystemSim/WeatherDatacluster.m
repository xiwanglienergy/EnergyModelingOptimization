function [candidate_list_by_sampling] = WeatherDatacluster(weather_data, fitness, n_clusters)
%   input: 
%       weather_data:   24 hours' out door temperature
%       fitness:        fitness value for each day with under all 99
%                       strategies
%       n_clusters:     number of clusters for abnormal and normal days
%   output:
%       candidate_list_by_sampling:     candidate list generated by random
%                                       sampling. The strategy index
%                                       follows the order of 'fitness'

hmethod = 'single';
topx = 5; % number of strategies been considered
nsel = 3; % number of most frequent strategies

% sort the fitness value
[sorted_fitness sort_ind] = sort(fitness, 2);

%% get abnormal and normal weather
t5_ind1 = [1 14 36];
b5_ind1 = [17 16 26];

% get the abnormal and normal weather
ind1 = [t5_ind1 b5_ind1];
ind1_fitness = fitness(:, ind1);
range1 = max(ind1_fitness, [], 2) - min(ind1_fitness, [], 2); % estimated range
[Y_range1,I_range1] = sort(range1, 'descend');

%% perform PCA
npts = size(weather_data, 2);
totdays = npts;
centers = mean(weather_data,2);
Abalanced = weather_data - repmat(centers,[1,totdays]);

[V,D] = eig(Abalanced*Abalanced');

dim = 3;
subV = V(:,end-dim+1:end);
eigParams = Abalanced'*subV;

%% add three levels new features
t5_ind1_fitness = fitness(:, t5_ind1);
b5_ind1_fitness = fitness(:, b5_ind1);
threelevels = t5_ind1_fitness - b5_ind1_fitness;

% 6-dimension features 
datain3D = [eigParams threelevels];

% range normlization
% for i = 1:size(datain3D, 2)
%     datain3D(:,i) = (datain3D(:,i) - min(datain3D(:,i))) / ...
%         (max(datain3D(:,i)) - min(datain3D(:,i)));
% end

all_weather_features = datain3D(:,1:3);
all_fitness_features = datain3D(:,4:6);

weather_feature_max = max(all_weather_features(:));
weather_feature_min = min(all_weather_features(:));
fitness_feature_max = max(all_fitness_features(:));
fitness_feature_min = min(all_fitness_features(:));

all_weather_features = (all_weather_features-weather_feature_min)/(weather_feature_max-weather_feature_min);
all_fitness_features = (all_fitness_features-fitness_feature_min)/(fitness_feature_max-fitness_feature_min);

datain3D = [all_weather_features, all_fitness_features];

% abnormal and normal weather
% select top 10% pts as abnormal features
ab_npts = ceil(npts * 0.1);
abnormal_datain3D = datain3D( I_range1(1:ab_npts) , :);
other_datain3D = datain3D( I_range1( (ab_npts+1):end ) , :);

% abnormal and normal weather index
abnormal_ind = I_range1(1:ab_npts);
normal_ind = I_range1((ab_npts+1):end);

%% get the stratigis and the corresponding counts
strategies = sort_ind(:,1);               % global optimal strategies
abnormal_best_strategies = sort_ind( I_range1(1:ab_npts),1 );
normal_best_strategies = sort_ind( I_range1( (ab_npts+1):end ),1 );

unique_best_strategies = unique(strategies);             % distinct
unique_abnormal_best_strategiess = unique(abnormal_best_strategies);
unique_normal_best_strategies = unique(normal_best_strategies);

% statistics on the counts of each strategy
cnts_strategies = zeros(length(unique_best_strategies), 1);
cnts_abnormal_best_strategies = zeros(length(unique_abnormal_best_strategiess), 1);
cnts_normal_best_strategies = zeros(length(unique_normal_best_strategies), 1);

for i = 1:length(unique_best_strategies)
    cnts_strategies(i) = size( find(strategies == unique_best_strategies(i) ), 1 );
end

for i = 1:length(unique_abnormal_best_strategiess)
    cnts_abnormal_best_strategies(i) = size( find(abnormal_best_strategies == unique_abnormal_best_strategiess(i) ), 1 );
end

for i = 1:length(unique_normal_best_strategies)
    cnts_normal_best_strategies(i) = size( find(normal_best_strategies == unique_normal_best_strategies(i) ), 1 );
end


%% Hierarchical clustering

Z_abnormal = linkage(abnormal_datain3D, hmethod);
Z_normal = linkage(other_datain3D, hmethod);

c_abnormal = cluster(Z_abnormal,'maxclust',n_clusters);
c_normal = cluster(Z_normal,'maxclust',n_clusters);


%% evaluate whether the clusters' strategies is uniform

threshold = 0.2;

% strategies in the abnormal index
abnormal_recluster = [];
abnormal_clusters = {};
for i = 1:n_clusters
    abnormal_clusters{i} = abnormal_best_strategies(c_abnormal == i);

    if length(abnormal_clusters{i}) > ( threshold * npts )
        abnormal_recluster = [abnormal_recluster i];
    end
end

% strategies in the normal index
normal_recluster = [];
normal_clusters = {};
for i = 1:n_clusters
    normal_clusters{i} = normal_best_strategies(c_normal == i);
    
    [freq, F] = mode(normal_clusters{i});

    if length(normal_clusters{i}) > ( threshold * npts )    
        normal_recluster = [normal_recluster i];
    end
end


%% clusters' strategies
abnormal_clusters_stat = {};
for i = 1:n_clusters
    cand_stra = unique(abnormal_clusters{i});
    temp_stat = [];
    for j = 1:length(cand_stra)
        noccur = size( find( abnormal_clusters{i} == cand_stra(j) ), 1);
        temp_stat = [temp_stat ; cand_stra(j), noccur];
    end
    
    abnormal_clusters_stat{i} = temp_stat;
end

normal_clusters_stat = {};
for i = 1:n_clusters
    cand_stra = unique(normal_clusters{i});
    temp_stat = [];
    for j = 1:length(cand_stra)
        noccur = size( find( normal_clusters{i} == cand_stra(j) ), 1);
        temp_stat = [temp_stat ; cand_stra(j), noccur];
    end
    
    normal_clusters_stat{i} = temp_stat;
end


%% reclustering

normal_recluster_size = length( normal_recluster );
all_normal_recluster = {};
for i = 1:normal_recluster_size
    recluster_3D = other_datain3D( find( normal_recluster(i) == c_normal ), : );
    recluster_stra = normal_best_strategies(find( normal_recluster(i) == c_normal ));
    
    recluster_id = kmean_cluster(recluster_3D, 0.01);
    
    c_normal(c_normal == normal_recluster(i)) = max(c_normal(:))+recluster_id;
    
    urecluster_id = unique(recluster_id);
    recluster = {};
    for j = 1:length(urecluster_id)
        cand_stra = unique( recluster_stra(recluster_id == urecluster_id(j)) );
        temp_stat = [];
        for k = 1:length(cand_stra)
            noccur = size( find( recluster_stra(recluster_id == urecluster_id(j))...
                == cand_stra(k) ), 1);
            temp_stat = [temp_stat ; cand_stra(k), noccur];
        end
        recluster{j} = temp_stat;
    end
    all_normal_recluster{i} = recluster;
end

cluster_index = zeros(size(weather_data,2),1);
cluster_index(I_range1(1:ab_npts)) = c_abnormal;
cluster_index(I_range1((ab_npts+1):end)) = c_normal+max(c_abnormal(:));

%% unite all clusters together
all_clusters = {};
count_ind = 0;
for i = 1:n_clusters 
    
    if find(i == abnormal_recluster)
        continue;
    end
    count_ind = count_ind + 1;
    all_clusters{count_ind} = abnormal_clusters_stat{i};
end

for i = 1:n_clusters 
    
    if ismember(normal_recluster,i)
        continue;
    end
    count_ind = count_ind + 1;
    all_clusters{count_ind} = normal_clusters_stat{i};
end

for i = 1:length(all_normal_recluster)
    recluster = all_normal_recluster{i};
    for j=1:length(recluster)
        count_ind = count_ind + 1;
        all_clusters{count_ind} = recluster{j};
    end
end

%% sampling process

min_num_samples = 3;
max_num_samples = 15;
sample_ratio = 0.2;

% sampling process
run_eplus_times = 0;
stratergies_voting = [];
stratergies_sampling = [];

ncomplete_run = 3;%3:8
par_run = 15;%15:25
ratio_par_run = 0.05;%0.05:0.05:0.5
            
for i = 1:length(all_clusters)
    acluster = all_clusters{i};
    max_occur = max(acluster(:, 2));         % voting
    majority_vote_ind = (acluster(:, 2) == max_occur);
    % find the voting strategies
    stratergies_voting = [stratergies_voting; acluster(majority_vote_ind, 1)];
    
    % strategies expansion, preparing for sampling
    expanded_strategy_list = [];
    for j = 1:size(acluster)
        expanded_strategy_list = [expanded_strategy_list; repmat(acluster(j, 1), acluster(j, 2) ,1)];
    end
    
    % total number of points
    totalpt = sum(acluster(:, 2));

    if totalpt <= ncomplete_run              
       run_eplus_times = run_eplus_times + totalpt;
       stratergies_sampling = [stratergies_sampling; acluster(:, 1)];

    elseif (totalpt > ncomplete_run) ...       
       && (totalpt < par_run)                

       run_ratio = ncomplete_run / par_run;              % sampling ratio

       run_pts = ceil(run_ratio * totalpt);
       run_eplus_times = run_eplus_times + run_pts;

       rand_ind = randperm(totalpt);
       samples = expanded_strategy_list(rand_ind(1:run_pts), :);       % get the strategy samples

       % samples
       stratergies_sampling = [stratergies_sampling; samples];

    elseif (totalpt > par_run)                  

       run_ratio = ratio_par_run*ncomplete_run/par_run;  % sampling ratio 
       run_pts = ceil(run_ratio * totalpt);              
       run_eplus_times = run_eplus_times + run_pts;  

       rand_ind = randperm(totalpt);
       samples = expanded_strategy_list(rand_ind(1:run_pts), :);       % get the strategy samples

       % samples
       stratergies_sampling = [stratergies_sampling; samples];
    end 
                
%     if totalpt <= min_num_samples              
%        run_eplus_times = run_eplus_times + totalpt;
%        stratergies_sampling = [stratergies_sampling; acluster(:, 1)];
%     else                                         
%        run_pts = ceil(totalpt * sample_ratio);
% 
%        if run_pts < min_num_samples
%            run_pts = min_num_samples;
%        elseif run_pts > max_num_samples
%            run_pts = max_num_samples;
%        end
% 
%        run_eplus_times = run_eplus_times + run_pts;
% 
%        rand_ind = randperm(totalpt);
%        samples = expanded_strategy_list(rand_ind(1:run_pts), :);       % get the strategy samples
% 
%        % samples
%        stratergies_sampling = [stratergies_sampling; samples];
%     end  
end

candidate_list_by_voting = unique(stratergies_voting, 'rows');
candidate_list_by_sampling = unique(stratergies_sampling, 'rows');

% return

load('allstrategy.mat');
disp 'total number of samples is: ', run_eplus_times
disp 'unique strategies by voting:'
unique(t(candidate_list_by_voting,:), 'rows')
size(candidate_list_by_voting, 1)
disp 'unique strategies by sampling:'
unique(t(candidate_list_by_sampling,:), 'rows')
size(candidate_list_by_sampling, 1)

min_fit = min(fitness, [], 2);

% for voting strategies
vote_stra_ind_gt = zeros(size(candidate_list_by_voting,1), 1);
for i = 1:size(candidate_list_by_voting,1)
   vote_stra_ind_gt(i) = find(unique_best_strategies == candidate_list_by_voting(i) );
end
vote_min_fit = min(fitness(:, candidate_list_by_voting), [], 2);

disp 'objective function value (voting )is:', sum(vote_min_fit-min_fit)
disp 'total number of counts (voting ) is:', sum(cnts_strategies(vote_stra_ind_gt))

disp '********************************************'

% for sampling strategies
sample_stra_ind_gt = zeros(size(candidate_list_by_sampling,1), 1);
for i = 1:size(candidate_list_by_sampling,1)
   sample_stra_ind_gt(i) = find(unique_best_strategies == candidate_list_by_sampling(i) );
end
sample_min_fit = min(fitness(:, candidate_list_by_sampling), [], 2);

disp 'objective function value  (sampling) is:', sum(sample_min_fit-min_fit)
disp 'total number of counts (sampling) is:', sum(cnts_strategies(sample_stra_ind_gt))

