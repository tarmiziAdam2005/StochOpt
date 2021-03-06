%%% TODO: combine with other SAGA functions

function [x, its, ek, fk, mean_fk, sk, tk, gk] = func_SAGA_noncon(para, iGradF, ObjF, ProxJ)
%
% Solves the problem
%
%    min_x   1/m sum_{i=1}^m f_i(x) + mu * J(x)
%
% where f_i has a Lipschitz continuous gradient for all i.
%
% Inputs:
%   para   - struct of parameters
%   iGradF - function handle mapping (x,i) to the gradient of f_i.
%   ObjF   - function handle returning the objective value
%   ProxJ  - function handle returning the proximal operator of the
%                non-smooth term
%
% Outputs:
%   x       - minimiser
%   its     - number of iterations
%   ek      - distance between iterations ||x_k - x_{k-1}||_2
%   fk      - objective value
%   mean_fk - objective value averaged over one epoch
%   sk      - number of non-zero entries of x (size of support)
%   tk      - time
%   gk      - step-size
%
% Parameters:
%     m          - number of functions in smooth component;
%     n          - length of vector x;
%     mu         - non-negative tuning parameter ( m^(-1/2) );
%     c_gamma    - step-size times Lipschitz constant of f_i (0.1);
%     beta_fi    - inverse of Lipschitz constant of f_i (1);
%     maxits     - maximum number of iterations (1000);
%     printEvery - number of iterations between printing (100);
%     saveEvery  - number of iterations between saves (100);
%     objEvery   - number of iterations between objective prints (100);
%     printObj   - print objective values? (True);
%     theta      - bias parameter, larger values give more weight
%                  to stored gradients, with a value of 1 corresponding
%                  to the SAGA gradient estimator (1);
%     b          - batch size (1);
%     tol        - tolerance in distance between iterates (1e-4)
%     x0         - starting point (vector with entries drawn i.i.d. from
%                  the standard normal distribution);
%     window     - because of nonconvexity, function values are averaged
%                   over an epoch (m).

% set problem dimensions
if isfield(para,'m') && isfield(para,'n')
    m = para.m;
    n = para.n;
else
    error('Must provide problem dimensions para.m and para.n')
end

% set parameters
mu      = setOpts(para,'mu',1/sqrt(m));
c_gamma = setOpts(para,'c_gamma',0.1);
beta_fi = setOpts(para,'beta_fi',1);
maxits  = setOpts(para,'maxits',1e4);
printEvery = setOpts(para,'printEvery',100);
saveEvery  = setOpts(para,'saveEvery',100);
printObj   = setOpts(para,'printObj',1);
objEvery   = setOpts(para,'objEvery',100);
theta      = setOpts(para,'theta',1);
b          = setOpts(para,'b',1);
tol        = setOpts(para,'tol',1e-4);
x0         = setOpts(para,'x0',zeros(n,1));
window     = setOpts(para,'window',m);

% running print
fprintf(sprintf('performing SAGA...\n'));
itsprint(sprintf('      step %09d: printObjective = %.9e \n', 1,0), 1); 

gamma = c_gamma * beta_fi; % step size
tau   = mu * gamma; % prox step-size

G = zeros(n, m);
for i=1:m
    G(:, i) = iGradF(x0, i);
end

% mean of the stored gradient values
mean_grad = 1/m * W' * G';

% initialise iterate histories
ek = zeros(floor(maxits/objEvery), 1);
sk = zeros(floor(maxits/objEvery), 1);
gk = zeros(floor(maxits/objEvery), 1);
fk = zeros(floor(maxits/objEvery), 1);
tk = zeros(floor(maxits/objEvery), 1);

mean_fk = zeros(floor(maxits/objEvery), 1);

% initialise x
x   = x0;
l   = 0;
its = 1;

mean_fk_old  = 0;

tic
while(its<maxits)
    
    x_old = x;
    
    j = randperm(m, b);
    
    for batch_num = 1:length(j)
        gj_old(:,batch_num) = G(:, j(batch_num));
        gj(:,batch_num)     = iGradF(x_old, j(batch_num));
        G(:,j(batch_num))   = gj(:,batch_num);
    end
    
    w = x - ( gamma / theta ) * mean(gj - gj_old,2) - gamma * mean_grad;
    
    x = ProxJ(w, tau);
    
    mean_grad = mean_grad + 1/m * sum(gj - gj_old,2);
    
    %%% Compute info
    if mod(its,objEvery)==0
        l = l+1;
        fk(l) = ObjF(x);
        ek(l) = norm(x(:)-x_old(:), 'fro');
        sk(l) = sum(abs(x) > 0);
        gk(l) = gamma;
        tk(l) = toc;
        
        mean_fk(l) = mean(fk(max(1,l-window):l));
        
        if mod(its,printEvery) == 0
            if printObj == 1
                itsprint(sprintf('      step %09d: Mean objective = %.9e\n', its, mean_fk(l)), its); 
            else
                itsprint(sprintf('      step %09d: norm(ek) = %.3e', its, ek(l)), its);
            end
        end
        
        %%% Stop?
        if abs(mean_fk(l) - mean_fk_old) < tol || abs(mean_fk(l) - mean_fk_old) > 1e10; break; end
        mean_fk_old = mean_fk(l);
    end
 
    
    % Save
    if mod(its,saveEvery) == 0
        fprintf('\n Saving... \n')
        save(para.name,'gk','sk','ek','fk','mean_fk','x','tk','para')
        itsprint(sprintf('      step %09d: Objective = %.9e \n', its,fk(l)), 1); 
    end
    
    its = its + 1;
    
end
fprintf('\n');

if its == maxits
    fprintf('\n Reached maximum number of allowed iterations... \n')
end

% resize
fk = fk(1:l);
ek = ek(1:l);
sk = sk(1:l);
gk = gk(1:l);
tk = tk(1:l);

mean_fk = mean_fk(1:l);


% save(para.name,'gk','sk','ek','fk','mean_fk','x','para')

end


% function to set options
function out = setOpts(options, opt, default)
    if isfield(options, opt)
        out = options.(opt);
    else
        out = default;
    end
end % function: setOpts
