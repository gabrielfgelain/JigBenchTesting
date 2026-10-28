function plot_matriz_correlacao_spearman(rpm, potencias, excluir)
% Mesma matriz de plot_matriz_correlacao_potencia.m, mas com a correlacao
% de Spearman (por postos) em vez de Pearson. Spearman mede se a relacao e
% monotonica, sem exigir que seja linear (ex.: ripple ~ 1/C), e e menos
% sensivel a outliers.
%
% Em vez da reta de regressao, cada grafico mostra uma curva de tendencia
% pela mediana movel (acompanha relacoes curvas).
%
% Uso:
%   plot_matriz_correlacao_spearman()                          % 3500 RPM, 80/150/210W
%   plot_matriz_correlacao_spearman(3000, {'80W'})
%   plot_matriz_correlacao_spearman(3000, {'80W'}, {'0001','1100'})  % exclui configs

    if nargin < 1 || isempty(rpm); rpm = 3500; end
    if nargin < 2 || isempty(potencias); potencias = {'80W','150W','210W'}; end
    if nargin < 3; excluir = {}; end

    % --- resistencia de cada braco individual (mosfet + resistor(es)) ---
    Rarm.a1 = 0.11;  % 1000: so mosfet
    Rarm.a2 = 0.58;  % 0100: mosfet + resistor 0,47 ohm
    Rarm.a3 = 0.345; % 0010: mosfet + 2x0,47 ohm em paralelo
    Rarm.a4 = 0.45;  % 0001: mosfet + 2x0,68 ohm em paralelo

    % --- capacitancia por numero de bracos ativos ---
    capPorBracos = containers.Map([7 6 5 4 3 2 1 0], [1056 994 922 837 739 626 490 324]);

    codigos = {'0001','0010','0011','0100','0101','0110','0111', ...
               '1000','1001','1010','1011','1100','1101','1110','1111'};
    RarmCombo = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(codigos)
        c = codigos{i};
        G = 0;
        if c(1)=='1'; G = G + 1/Rarm.a1; end
        if c(2)=='1'; G = G + 1/Rarm.a2; end
        if c(3)=='1'; G = G + 1/Rarm.a3; end
        if c(4)=='1'; G = G + 1/Rarm.a4; end
        RarmCombo(c) = 1/G;
    end

    janelaFiltro = 200; % ~5 kHz a 1 MS/s, suaviza corrente antes do RMS

    for p = 1:numel(potencias)
        [M, vars, labels] = extrai_features_potencia(potencias{p}, rpm, excluir, ...
            capPorBracos, RarmCombo, janelaFiltro);
        if isempty(M); continue; end
        plota_matriz(M, vars, labels, sprintf('%s, %d RPM', potencias{p}, rpm), excluir);
    end
end

function [M, vars, labels] = extrai_features_potencia(potencia, rpm, excluir, capPorBracos, RarmCombo, janelaFiltro)

    vars = {'V1_rms', 'V2_mean', 'V2_std', 'I_media_rms', 'C_uF', 'R_serie_ohm'};
    % rotulos em ingles (aparecem nas figuras); ripple = desvio padrao de V2
    % (cada rotulo em duas linhas para caber com fonte grande)
    labels = {{'Motor', 'voltage (V)'}, {'DC-link', 'voltage (V)'}, {'DC-link ripple,', 'std (V)'}, ...
        {'Motor', 'current (A)'}, {'Capacitance', '(µF)'}, {'Series', 'resistance (Ω)'}};

    padraoPasta = sprintf('Dados_Ensaios/%s_%dRPM_R*', potencia, rpm);
    pastas = dir(padraoPasta);
    pastas = pastas([pastas.isdir]);

    linhas = [];
    for k = 1:numel(pastas)
        nomePasta = pastas(k).name;
        tok = regexp(nomePasta, 'R(\d{4})$', 'tokens');
        if isempty(tok); continue; end
        codigo = tok{1}{1};
        if ~isKey(RarmCombo, codigo) || any(strcmp(excluir, codigo)); continue; end
        rArmVal = RarmCombo(codigo);

        arquivos = dir(fullfile('Dados_Ensaios', nomePasta, '*.csv'));
        for f = 1:numel(arquivos)
            nomeArq = arquivos(f).name;
            % aceita "7Bracos_R1000_..." (3500 RPM) e "7Bracos_3000_R1000_..." (3000 RPM)
            tokB = regexp(nomeArq, '^(\d+)Bracos(?:_\d+)?_R(\d{4})_', 'tokens');
            if isempty(tokB); continue; end
            if ~strcmp(tokB{1}{2}, codigo); continue; end % arquivo de outra config
            bracos = str2double(tokB{1}{1});
            if ~isKey(capPorBracos, bracos); continue; end

            C = capPorBracos(bracos);
            if bracos == 0
                R = 0.2;
            else
                soma = 0.51/bracos + rArmVal;
                R = 0.1 + (0.1 * soma) / (0.1 + soma);
            end

            dados = le_csv(fullfile('Dados_Ensaios', nomePasta, nomeArq));
            if size(dados, 2) < 5; continue; end

            v1 = dados(:,1);
            v2 = dados(:,2);
            i4f = movmean(dados(:,4), janelaFiltro);
            i5f = movmean(dados(:,5), janelaFiltro);

            linha = [rms(v1), mean(v2), std(v2), mean([rms(i4f), rms(i5f)]), C, R];
            linhas = [linhas; linha]; %#ok<AGROW>
        end
    end

    M = linhas;
    fprintf('%s, %d RPM: %d ensaios processados.\n', potencia, rpm, size(M,1));
end

function plota_matriz(M, vars, labels, tituloEnsaio, excluir)

    N = numel(vars);
    fig = figure('Name', ['Spearman matrix - ' tituloEnsaio], 'NumberTitle', 'off', ...
        'Position', [30 30 1100 1050], 'Color', 'w');
    tl = tiledlayout(fig, N, N, 'Padding', 'tight', 'TileSpacing', 'compact');

    rho = corr(M, 'Type', 'Spearman');
    rhoP = corr(M); % Pearson, so para imprimir a comparacao

    for i = 1:N
        for j = 1:N
            nexttile(tl, (i-1)*N + j);
            x = M(:,j); y = M(:,i);

            if i == j
                histogram(x, 15, 'FaceColor', [0.30 0.55 0.85], 'EdgeColor', 'none');
            else
                scatter(x, y, 14, [0.20 0.45 0.80], 'filled', 'MarkerFaceAlpha', 0.55);
                hold on;
                [xs, ordem] = sort(x);
                ys = movmedian(y(ordem), max(5, round(numel(y)/4)));
                plot(xs, ys, 'r-', 'LineWidth', 1.2); % tendencia monotonica (mediana movel)
                hold off;
                title(sprintf('%.2f', rho(i,j)), 'FontSize', 18, 'FontWeight', 'bold', 'Color', 'k');
            end

            if i == N
                xlabel(labels{j}, 'FontSize', 16, 'FontWeight', 'bold');
            end
            if j == 1
                ylabel(labels{i}, 'FontSize', 16, 'FontWeight', 'bold');
            end
            % sem 'FontSize' aqui: mudar a fonte do eixo depois redimensiona o
            % titulo e os rotulos que ja foram criados
            set(gca, 'XTickLabel', [], 'YTickLabel', []);
            box on;
        end
    end

    sufixo = '';
    if ~isempty(excluir); sufixo = sprintf(', excluding R%s', strjoin(excluir, '/R')); end
    title(tl, {'Spearman correlation matrix', sprintf('%s (n = %d tests%s)', ...
        tituloEnsaio, size(M,1), sufixo)}, 'FontSize', 20, 'FontWeight', 'bold', 'Color', 'k');

    % comparacao Spearman x Pearson no console
    fprintf('\n%s - Spearman (Pearson entre parenteses):\n', tituloEnsaio);
    fprintf('%14s', ''); fprintf('%16s', vars{:}); fprintf('\n');
    for i = 1:N
        fprintf('%14s', vars{i});
        for j = 1:N
            fprintf('   %5.2f (%5.2f)', rho(i,j), rhoP(i,j));
        end
        fprintf('\n');
    end
end

function dados = le_csv(arquivo)
% Le um CSV com separador ";" e decimais com virgula.

    texto = fileread(arquivo);
    texto = strrep(texto, ',', '.');

    arqTemp = [tempname(), '.csv'];
    fid = fopen(arqTemp, 'w');
    fwrite(fid, texto);
    fclose(fid);

    dados = readmatrix(arqTemp, 'Delimiter', ';');
    delete(arqTemp);
end
