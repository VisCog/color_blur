% MakeColorBlurFigures_dprime_fixedacuity.m
%
% Generates figures for the color blur paper.
% Uses SDT d' calculated from resp + correct (yes/no task).
%
% ---- WHAT IS DIFFERENT FROM MakeColorBlurFigures_dprime.m ----
% The equivalent-acuity (iso-performance) analysis is rewritten.
%
% The raw d' vs blur curves are noisy and NOT monotonic, so the old
% approach (force monotonicity with cummax, then piecewise-linear
% inversion) produced jagged / NaN-filled equivalent-blur maps.
%
% Instead we fit each condition with a smooth, strictly monotonic
% DECREASING function of blur that:
%     - equals d'max at zero blur,
%     - decays smoothly to 0 at high blur (as it physically must),
%     - is analytically invertible.
%
% Model (Naka-Rushton / Hill form):
%     d'(b) = dmax / (1 + (b / b50)^n)
%
% Inversion (equivalent blur at a given d'):
%     b = b50 * (dmax/d' - 1)^(1/n),   for 0 < d' < dmax
%
% Equivalent acuity: for every grayscale blur we read off the fitted
% grayscale d', then invert the fitted COLOR curve to find the color
% blur that yields the same d'. Because both fits are smooth and
% monotonic, this iso-performance mapping is well defined and smooth.

addpath(genpath('C:\Users\Ione Fine\Documents\code\UWToolbox'))
addpath('C:\Users\Ione Fine\Documents\code\code utilities\random\');
addpath('C:\Users\Ione Fine\Documents\code\primate_color\')

patchOn = false
allData = xls2struct('all_data.xlsx');

pcThresh = 0.75;
colList = [.25,.25,.25; 1,0,0; 0 .8 0 ];

cx = sin(linspace(-pi,pi,101));
cy = cos(linspace(-pi,pi,101));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXP 1: SUBJECT-SUBJECT PLOTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

exp3Data = subStruct(allData, strcmp(allData.exp,'Exp3'));
subs  = unique(exp3Data.subId);
nSubs = length(subs);

pc      = zeros(nSubs,2);
rt      = zeros(nSubs,2);
dprime  = zeros(nSubs,2);

for i = 1:nSubs

    % Grayscale condition
    thisSub3bw = subStruct(exp3Data, ...
        strcmp(exp3Data.subId,subs{i})' & ...
        [exp3Data.color{:}] == 0);

    pc(i,1) = mean([thisSub3bw.correct{:}]);
    rt(i,1) = mean([thisSub3bw.rt{:}]);

    dprime(i,1) = calcDprime( ...
        [thisSub3bw.resp{:}], ...
        [thisSub3bw.correct{:}]);

    % Color condition
    thisSub3color = subStruct(exp3Data, ...
        strcmp(exp3Data.subId,subs{i})' & ...
        [exp3Data.color{:}] == 1);

    pc(i,2) = mean([thisSub3color.correct{:}]);
    rt(i,2) = mean([thisSub3color.rt{:}]);

    dprime(i,2) = calcDprime( ...
        [thisSub3color.resp{:}], ...
        [thisSub3color.correct{:}]);

end

m_dprime = mean(dprime,1);

figure(1)
clf
hold on

rad = 3.5/50;

plot([0 3],[0 3],'k-')

plotMeanEllipse(dprime(:,1), dprime(:,2), 'k');

for i = 1:nSubs
    patch(dprime(i,1)+rad*cx, dprime(i,2)+rad*cy, 'b', ...
        'FaceAlpha',0.5,'EdgeColor','none');
end

plot(m_dprime(1), m_dprime(2), 'ws', ...
    'MarkerSize',12,'MarkerFaceColor','k');

axis equal
xlim([0 3])
ylim([0 3])
grid on
xlabel('Grayscale d''')
ylabel('Color d''')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXP 1: RT PLOT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

rtRange = [0 3.5];

figure(2)
clf
hold on

rad = diff(rtRange)/50;

plot(rtRange, rtRange, 'k-')

plotMeanEllipse(rt(:,1), rt(:,2), 'k');

for i = 1:nSubs
    patch(rt(i,1)+rad*cx, rt(i,2)+rad*cy, 'b', ...
        'FaceAlpha',0.5,'EdgeColor','none');
end

plot(mean(rt(:,1)), mean(rt(:,2)), 'ws', ...
    'MarkerSize',12,'MarkerFaceColor','k');

axis equal
xlim(rtRange)
ylim(rtRange)
grid on
xlabel('Grayscale RT (s)')
ylabel('Color RT (s)')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXP 2 & 3: d' VS BLUR + EQUIVALENT ACUITY (FITTED)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expNameList = {'Exp1','Exp2'};

% d' criterion for the one-number summary. Change if you want another
% iso-performance level.
dpCriterion = 1.0;

for e = 1:length(expNameList)

    expName = expNameList{e};

    subData = subStruct(allData, ...
        strcmp(allData.exp,expName)' & ...
        [allData.pc{:}] > pcThresh);

    subs = unique(subData.subId);
    blurList = unique([subData.diopter{:}]);

    nSubs  = length(subs);
    nBlurs = length(blurList);

    % Dimensions: blur x condition x subject
    % Condition 1 = grayscale; condition 2 = color
    dprime = zeros(nBlurs,2,nSubs);

    for i = 1:nSubs
        for j = 1:nBlurs

            % Grayscale
            thisSubbw = subStruct(subData, ...
                strcmp(subData.subId,subs{i})' & ...
                [subData.diopter{:}] == blurList(j) & ...
                [subData.color{:}] == 0);

            dprime(j,1,i) = calcDprime( ...
                [thisSubbw.resp{:}], ...
                [thisSubbw.correct{:}]);

            % Color
            thisSubcolor = subStruct(subData, ...
                strcmp(subData.subId,subs{i})' & ...
                [subData.diopter{:}] == blurList(j) & ...
                [subData.color{:}] == 1);

            dprime(j,2,i) = calcDprime( ...
                [thisSubcolor.resp{:}], ...
                [thisSubcolor.correct{:}]);

        end
    end

    m_dprime   = mean(dprime,3);
    sem_dprime = std(dprime,[],3) ./ sqrt(nSubs);

    grayDP  = m_dprime(:,1);
    colorDP = m_dprime(:,2);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% FIT SMOOTH MONOTONIC DECREASING CURVES
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    grayFit  = fitDecreasingSigmoid(blurList, grayDP);
    colorFit = fitDecreasingSigmoid(blurList, colorDP);

    fprintf('\n%s fitted d''(blur) = dmax/(1+(b/b50)^n)\n', expName);
    fprintf('  Grayscale: dmax=%.2f  b50=%.2f D  n=%.2f\n', ...
        grayFit.dmax, grayFit.b50, grayFit.n);
    fprintf('  Color:     dmax=%.2f  b50=%.2f D  n=%.2f\n', ...
        colorFit.dmax, colorFit.b50, colorFit.n);

    % Smooth blur axis for plotting the fits.
    bFine = linspace(0, max(blurList), 200)';
    grayFitCurve  = evalDecreasingSigmoid(grayFit,  bFine);
    colorFitCurve = evalDecreasingSigmoid(colorFit, bFine);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% d' VS BLUR FIGURE (data + fits)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    figure(e+2)
    clf
    hold on

    xx = [-.5 2.5 5.5 8.5];
    patchColList = [.8 .85 .9];

    if patchOn
    for i = 1:3
        patch([xx(i) xx(i+1) xx(i+1) xx(i)], [0 0 3 3], ...
            patchColList(i)*[1 1 1], 'LineStyle','none');
    end
    end

    plot([-0.25 max(blurList)+0.25], [0 0], 'k:')

    % Fitted smooth curves.
    plot(bFine, grayFitCurve,  '-', 'Color', colList(1,:), 'LineWidth', 1.5);
    plot(bFine, colorFitCurve, '-', 'Color', colList(e+1,:), 'LineWidth', 1.5);

    h = gobjects(2,1);
    dataDP = {grayDP, colorDP};

     errorbar(blurList, dataDP{1}, sem_dprime(:,1), ...
            'Color',colList(1,:), 'LineStyle','none');

        h(1) = plot(blurList, dataDP{1}, 'o', ...
            'Color',colList(1,:), ...
            'MarkerFaceColor',colList(1,:), 'MarkerEdgeColor','none');


     errorbar(blurList, dataDP{2}, sem_dprime(:,2), ...
            'Color',colList(e+1,:), 'LineStyle','none');

        h(2) = plot(blurList, dataDP{2}, 'o', ...
            'Color',colList(e+1,:), ...
            'MarkerFaceColor',colList(e+1,:), 'MarkerEdgeColor','none');


    xlim([-0.5 max(blurList)+0.5])
    ylim([-.25 2.1])

    legend(h, {'Grayscale','Color'}, 'Location','NorthEast')
    ylabel('d''')
    xlabel('Diopter')
    title(expName)

   

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% FULL ISO-PERFORMANCE MAPPING (fitted, smooth)
    %
    % At every grayscale blur, read off the fitted grayscale d', then
    % invert the fitted color curve to find the color blur giving the
    % same d'. NaN where the two curves cannot be matched (i.e. the
    % grayscale d' lies outside the color curve's achievable range).
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    grayDP_fit = evalDecreasingSigmoid(grayFit, blurList(:));

    equivalentColorBlur = nan(size(blurList(:)));
    for b = 1:numel(blurList)
        equivalentColorBlur(b) = ...
            invertDecreasingSigmoid(colorFit, grayDP_fit(b));
    end
    equivalentBlurShift = equivalentColorBlur - blurList(:);

    equivalentBlurTable = table( ...
        blurList(:), ...
        grayDP(:), ...
        grayDP_fit(:), ...
        equivalentColorBlur(:), ...
        equivalentBlurShift(:), ...
        'VariableNames', { ...
            'GrayscaleBlur_D', ...
            'GrayscaleDprime_data', ...
            'GrayscaleDprime_fit', ...
            'EquivalentColorBlur_D', ...
            'ColorAdvantage_D'});

    disp(equivalentBlurTable);

    % figure(9); hold on
    %  clist = [1 0 0; 0 .8 0];
    %   plot([0 max(blurList)], [0 max(blurList)], 'k--', 'LineWidth', 1);
    % plot( blurList(:),  equivalentColorBlur, '-', ...
    %     'Color', clist(e,:), 'LineWidth', 1.5);
    % grid on

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% ISO-PERFORMANCE MAPPING FIGURE (smooth, from the fits)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    clist = [0 0 1; 0 1 0];

    figure(10)
    hold on
clist = [1 0 0; 0 .8 0];
    % Smooth mapping curve: sweep grayscale blur finely.
    gBlurFine = linspace(0, max(blurList), 200)';
    gDPfine   = evalDecreasingSigmoid(grayFit, gBlurFine);
    cBlurFine = nan(size(gBlurFine));
    for b = 1:numel(gBlurFine)
        cBlurFine(b) = invertDecreasingSigmoid(colorFit, gDPfine(b));
    end
    validFine = ~isnan(cBlurFine);

    plot([0 max(blurList)], [0 max(blurList)], 'k--', 'LineWidth', 1);

    plot(gBlurFine(validFine), cBlurFine(validFine), '-', ...
        'Color', clist(e,:), 'LineWidth', 1.5);


    % Mark the observed grayscale blur levels on the mapping.
    valid = ~isnan(equivalentColorBlur);
    plot(blurList(valid), equivalentColorBlur(valid), 'o', ...
        'MarkerFaceColor', clist(e,:), 'MarkerEdgeColor', clist(e,:));

    axis equal
    xlim([0 max(blurList)])
    ylim([0 max(blurList)])
    set(gca, 'XTick', [0:8])
       set(gca, 'YTick', [0:8])
    grid on

    xlabel('Grayscale blur (D)')
    ylabel('Equivalent color blur (D)')
    title('Equivalent acuity mapping (fitted)')

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SUPPORT FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function dp = calcDprime(resp,correct)

resp    = logical(resp);
correct = logical(correct);

% Reconstruct stimulus identity
signal = (resp == correct);

hits   = sum(signal & resp);
misses = sum(signal & ~resp);
fas    = sum(~signal & resp);
crs    = sum(~signal & ~resp);

% Hautus correction
H  = (hits + 0.5) / (hits + misses + 1);
FA = (fas  + 0.5) / (fas  + crs    + 1);

dp = norminv(H) - norminv(FA);

end


function subDat = subStruct(dat,id)

subDat = struct();
fields = fieldnames(dat);

for i = 1:length(fields)
    subDat.(fields{i}) = dat.(fields{i})(id);
end

end


function plot2dSEM(x,y,semx,semy,color)

for i = 1:length(x)

    plot([x(i) x(i)], [y(i)-semy(i) y(i)+semy(i)], ...
        'Color', color, 'LineWidth', 1);

    plot([x(i)-semx(i) x(i)+semx(i)], [y(i) y(i)], ...
        'Color', color, 'LineWidth', 1);

end

end


function plotMeanEllipse(x,y,color)

x = x(:);
y = y(:);

mu = [mean(x); mean(y)];
C  = cov(x,y) / length(x);

k = sqrt(5.991);

theta = linspace(0,2*pi,200);
circle = [cos(theta); sin(theta)];

[V,D] = eig(C);

ellipse = mu + k * V * sqrt(D) * circle;

plot(ellipse(1,:), ellipse(2,:), ...
    'Color', color, 'LineWidth', 2);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EQUIVALENT-ACUITY FIT FUNCTIONS
%%
%% Model:  d'(b) = dmax / (1 + (b/b50)^n)
%%   - dmax > 0 : d' at zero blur
%%   - b50  > 0 : blur at which d' has fallen to dmax/2
%%   - n    > 0 : steepness
%% Strictly decreasing in b, ->dmax at b=0, ->0 as b->inf.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function dp = evalDecreasingSigmoid(fit, b)
% Evaluate the fitted curve at blur values b.
b  = b(:);
dp = fit.dmax ./ (1 + (max(b,0) ./ fit.b50).^fit.n);
end


function b = invertDecreasingSigmoid(fit, dp)
% Blur at which the fitted curve equals d' = dp.
% Returns NaN when dp is outside the achievable range (0, dmax).
if ~isscalar(dp)
    error('invertDecreasingSigmoid:scalar','dp must be scalar');
end
if dp <= 0 || dp >= fit.dmax || isnan(dp)
    b = NaN;
    return
end
b = fit.b50 * (fit.dmax/dp - 1).^(1/fit.n);
end


function fit = fitDecreasingSigmoid(blurList, dpData)
% Least-squares fit of d'(b) = dmax/(1+(b/b50)^n) to (blurList, dpData).
% Uses fminsearch (no Optimization Toolbox needed). Parameters are
% optimised in log-space so they stay strictly positive.

blurList = blurList(:);
dpData   = dpData(:);

good = ~isnan(dpData) & ~isnan(blurList);
b    = blurList(good);
d    = dpData(good);

% --- initial guesses ---
dmax0 = max(max(d), 0.1);              % near d' at low blur
b50_0 = median(b(b > 0));              % middle of the blur range
if isempty(b50_0) || b50_0 <= 0
    b50_0 = max(max(b),1)/2;
end
n0    = 2;

p0 = log([dmax0, b50_0, n0]);          % optimise in log-space

% --- objective: sum of squared error ---
    function sse = objFun(p)
        pr   = exp(p);
        pred = pr(1) ./ (1 + (max(b,0) ./ pr(2)).^pr(3));
        sse  = sum((pred - d).^2);
    end

opts = optimset('Display','off','MaxFunEvals',5e4,'MaxIter',5e4, ...
    'TolFun',1e-8,'TolX',1e-8);

pHat = fminsearch(@objFun, p0, opts);
pr   = exp(pHat);

fit = struct();
fit.dmax = pr(1);
fit.b50  = pr(2);
fit.n    = pr(3);

% Goodness of fit (R^2) for reference.
pred    = evalDecreasingSigmoid(fit, b);
ssRes   = sum((d - pred).^2);
ssTot   = sum((d - mean(d)).^2);
fit.R2  = 1 - ssRes / max(ssTot, eps);

end
