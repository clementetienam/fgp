% demo of inducing based partition with em for inducing labels
%clear; clc; close all;
theseed = 1300;

func_assign = 'zmap_mahala_em';
datasets_dir = 'fagpe/data/';
dataset_names = {'kin40k','pumadyn32nm','elevators2','pol'};
output_file = 'fagpe/output/indpar_em_k32maha.mat';
try
  load(output_file, 'logger');
catch eee
  logger = [];
  save(output_file, 'logger');
end

max_fevals = 1000;
M = 1500;
for K=[3,2]
  for sss = 1:5
    seed = theseed + sss*10;
    rng(seed,'twister');
    strdate = datestr(now, 'mmmdd');
    tstamp = [strdate 't' num2str(tic)];
    for idata = 1:length(dataset_names)
      name = [dataset_names{idata} 'M' num2str(M) 'k' num2str(K)];
      logger.(tstamp).rng = seed;
      logger.(tstamp).(name).version = 1;
      logger.(tstamp).(name).K = K;
      logger.(tstamp).(name).total_nu = M;
      logger.(tstamp).(name).func_assign = func_assign;
      logger.(tstamp).(name).max_fevals = max_fevals;

      [x,y,xt,yt] = load_data([datasets_dir dataset_names{idata}], dataset_names{idata});
      dim = size(x,2);

      % init hyper-parameters
      %TODO: use some partitioning to init xu
      randind = randperm(size(x,1),M);
      hyp = gpml_hyp_to_fitc(gpml_init_hyp(x,y,false));
      w0 = reshape(x(randind,:),M*dim,1);
      for k=1:K
        w0 = [w0; hyp];
      end
      % learn basis points and hyp
      tstart = tic;
      [w,fval] = minimize(w0,'indpar_marginal_em',-max_fevals,x,y,K,M);
      logger.(tstamp).(name).training_time = toc(tstart);
      logger.(tstamp).(name).obj = fval(end);
      logger.(tstamp).(name).optim_w = w;

      % assign points to partition based on the inducing inputs
      tstart = tic;
      U = reshape(w(1:M*dim),M,dim);
      Theta = reshape(w(M*dim+1:end),dim+2,K);
      [ulabel, xlabel, xt_label] = zmap_mahala_em(U,K,x,xt);

      % predict
      Nt = size(xt,1);
      valid = true;
      fmean = zeros(Nt,1); logpred = zeros(Nt,1);
      for k=1:K
        indk_u = ulabel == k;
        indk_x = xlabel == k;
        indk_xt = xt_label == k;
        hypk = fitc_hyp_to_gpml(Theta(:,k),dim);
        try
          [fmean(indk_xt),~,logpred(indk_xt)] = gpmlFITC(x(indk_x,:),...
            y(indk_x),xt(indk_xt,:),yt(indk_xt),U(indk_u,:),hypk,false);
        catch eee
          valid = false;
        end
      end
      logger.(tstamp).(name).prediction_time = toc(tstart);
      logger.(tstamp).(name).valid = valid;
      logger.(tstamp).(name).smse = mysmse(yt,fmean,mean(y));
      logger.(tstamp).(name).nlpd = -mean(logpred);
      logger.(tstamp).(name).mae = mean(abs(fmean-yt));
      logger.(tstamp).(name).sqdiff = sqrt(mean((fmean-yt).^2));
      fprintf('smse = %.4f\n', mysmse(yt,fmean,mean(y)));
      fprintf('nlpd = %.4f\n', -mean(logpred));
      fprintf('avg absolute diff (mae) = %.4f\n', mean(abs(fmean-yt)));
      fprintf('sq diff = %.4f\n', sqrt(mean((fmean-yt).^2))); 
      save(output_file, 'logger');
    end
  end
end