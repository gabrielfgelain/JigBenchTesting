function plot_matriz_correlacao_final(recalcular, separarRotacao, formatoArtigo)
% Matriz de correlacao de Spearman com TODOS os ensaios validos juntos
% (3 potencias x 3 rotacoes), no estilo de Oruklu & Agalar (IEEE TIE, 2025):
% histograma na diagonal e dispersao com o rho de Spearman nos demais quadros.
%
% Os ensaios validos sao lidos da aba "Ensaios" de Labels_Ensaios.xlsx
% (coluna Status = "Válido").
%
% Variaveis da matriz (as usadas no artigo):
%   C            capacitancia do barramento (uF), pelo numero de bracos ativos
%   P            potencia de carga (W)
%   Im           corrente RMS do motor (media das duas fases medidas)
%   Vdc,p2p      pico a pico do barramento, sem filtro (como na literatura)
%   A120         amplitude do ripple de 120 Hz no barramento (V)
%   A6f1         amplitude no barramento em 6 x f1 (pulsos do inversor), f1 = RPM/30
%   A120/(VmIm)  ripple de 120 Hz normalizado pela potencia aparente do motor,
%                calculada so com grandezas medidas (Vm = tensao RMS do motor)
%
% As features sao salvas em features_matriz_final.mat para nao reprocessar
% os ~900 arquivos a cada execucao. Colunas do cache:
%   [C, P, rpm, A120, A120/P, A6f1, A5k, Im, Vm, Af1+120, Vdc,p2p]
% (A5k = RMS da banda 4,5-5,5 kHz; Af1+120 = banda lateral f1 + 120 Hz na
% corrente do motor, relativa a fundamental; ficam no cache mas fora da
% matriz.)  
%
% Com separarRotacao = true, gera uma matriz por rotacao (frequencia de
% saida do inversor: 90, 100 e 116,7 Hz), com as cargas em cores diferentes.
% O rho continua calculado com todas as cargas daquela rotacao juntas.
%
% Com formatoArtigo = true, gera as tres matrizes por rotacao no tamanho final
% do artigo (8,6 x 6,5 cm cada, para ficarem empilhadas na largura de uma
% coluna do IEEE), com o rho dentro de cada quadro, uma curva de tendencia pela
% mediana e fonte Times; salva em Figuras_Artigo/matriz_<rpm>rpm.pdf (vetorial).
%
% Rodar pelo botao Run (sem argumentos) gera so a matriz com todos os ensaios.
%
% Uso:
%   plot_matriz_correlacao_final()                    % usa o cache, se existir
%   plot_matriz_correlacao_final(true)                % reprocessa todos os CSVs
%   plot_matriz_correlacao_final(false, true)         % uma matriz por rotacao
%   plot_matriz_correlacao_final(false, true, true)   % idem, formato do artigo

    if nargin < 1; recalcular = false; end
    if nargin < 2; separarRotacao = false; end
    if nargin < 3; formatoArtigo = false; end
    arqCache = 'features_matriz_final.mat';

    if isfile(arqCache); load(arqCache, 'M'); end
    if recalcular || ~exist('M', 'var') || size(M, 2) < 11 % cache antigo, sem Vdc,p2p
        M = extrai_features();
        save(arqCache, 'M');
    end

    F = [M(:,1), M(:,2), M(:,8), M(:,11), M(:,4), M(:,6), M(:,4) ./ (M(:,9) .* M(:,8))];
    labels = {'C', 'P', 'I_m', 'V_{dc,p2p}', 'A_{120}', 'A_{6f_1}', 'A_{120}/(V_mI_m)'};

    if ~separarRotacao
        plota_matriz(F, labels, 'All tests', M(:,2));
        return;
    end

    for rpm = [2700 3000 3500]
        sel = M(:,3) == rpm;
        if formatoArtigo
            % simbolos curtos: o significado e as unidades vao na legenda da figura
            % notacao matematica (interpretador LaTeX): indices que sao rotulos ficam retos
            labelsArtigo = {'$C_\mathrm{dc}$', '$P_\mathrm{m}$', '$I_\mathrm{m}$', '$V_\mathrm{p2p}$', ...
                            '$A_{120}$', '$A_{6f_1}$', '$A_{120,\mathrm{n}}$'};
            fig = plota_matriz_artigo(F(sel,:), labelsArtigo, M(sel, 2));
            if ~isfolder('Figuras_Artigo'); mkdir('Figuras_Artigo'); end
            exportgraphics(fig, fullfile('Figuras_Artigo', sprintf('matriz_%drpm.pdf', rpm)), ...
                'ContentType', 'vector');
        else
            plota_matriz(F(sel,:), labels, sprintf('%d rpm (f_1 = %.1f Hz)', rpm, rpm/30), M(sel, 2));
        end
    end
end

function M = extrai_features()

    Fs = 1e6;
    capPorBracos = containers.Map([7 6 5 4 3 2 1 0], [1056 994 922 837 739 626 490 324]);
    janelaFiltro = 200; % ~5 kHz a 1 MS/s, suaviza corrente antes do RMS

    T = readtable('Labels_Ensaios.xlsx', 'Sheet', 'Ensaios', 'VariableNamingRule', 'preserve');
    validos = find(strcmp(T{:,12}, 'Válido'));

    M = zeros(numel(validos), 11);
    for k = 1:numel(validos)
        lin = validos(k);
        arquivo = fullfile('Dados_Ensaios', T{lin,2}{1}, T{lin,1}{1});
        P = T{lin,3}; rpm = T{lin,4}; bracos = T{lin,7};

        dados = readmatrix(arquivo, 'Delimiter', ';', 'DecimalSeparator', ',', 'FileType', 'text');
        v1 = dados(:,1); v = dados(:,2); i4 = dados(:,4); i5 = dados(:,5);
        N = numel(v);

        % --- barramento: FFT sem janela (ripple de 120 Hz e banda de 5 kHz) ---
        X = fft(v - mean(v));
        X = X(1:floor(N/2)+1);
        f = (0:floor(N/2))' * Fs / N;
        A = abs(X) / N * 2;
        A120 = max(A(abs(f - 120) <= 15));
        banda = f >= 4500 & f <= 5500;
        A5k = sqrt(2 * sum(abs(X(banda)).^2)) / N;

        % --- picos com janela de Hann (passo de 1,25 Hz, como um zero padding de 8x) ---
        df = Fs / (8*N);

        % frequencia eletrica medida na tensao do motor
        fGrade = (ceil(0.8*rpm/30/df):floor(1.2*rpm/30/df)) * df;
        [~, im] = max(amp_hann(v1, Fs, fGrade)); f1 = fGrade(im);

        A6f1 = pico(v, Fs, 6*f1, 3, df);
        SB = pico(i4, Fs, f1 + 120, 3, df) / pico(i4, Fs, f1, 3, df);

        % --- motor: valores RMS ---
        Im = mean([rms(movmean(i4, janelaFiltro)), rms(movmean(i5, janelaFiltro))]);
        Vm = rms(v1);

        Vp2p = max(v) - min(v); % bruto, sem filtro

        M(k,:) = [capPorBracos(bracos), P, rpm, A120, A120/P, A6f1, A5k, Im, Vm, SB, Vp2p];
        if mod(k, 50) == 0; fprintf('%d/%d arquivos\n', k, numel(validos)); end
    end
    fprintf('%d ensaios validos processados.\n', size(M,1));
end

function A = amp_hann(x, Fs, freqs)
% Amplitude do espectro com janela de Hann so nas frequencias pedidas
% (DFT direta: evita FFTs de 800 mil pontos com zero padding).
    x = x(:) - mean(x); N = numel(x);
    w = hann(N); xw = x .* w;
    t = (0:N-1)' / Fs;
    A = zeros(size(freqs));
    for k = 1:numel(freqs)
        A(k) = abs(sum(xw .* exp(-1j*2*pi*freqs(k)*t))) * 2 / sum(w);
    end
end

function a = pico(x, Fs, alvo, tol, df)
% Maior amplitude dentro de alvo +- tol (Hz), na grade de passo df.
    fGrade = (ceil((alvo - tol)/df):floor((alvo + tol)/df)) * df;
    a = max(amp_hann(x, Fs, fGrade));
end

function fig = plota_matriz_artigo(M, labels, grupo)
% Matriz para o artigo: 8,6 x 6,5 cm (largura da coluna; 3 empilhadas), Times 8 pt, rho
% dentro do quadro (canto superior esquerdo) e, na coluna de C, a curva da
% mediana de cada feature por nivel de capacitancia (coerente com o Spearman:
% relacao monotonica, nao necessariamente linear). As cargas (grupo) aparecem
% em cores; a legenda fica no texto.

    N = size(M, 2);
    rho = corr(M, 'Type', 'Spearman');
    niveis = unique(grupo);
    cores = [0.23 0.44 0.69; 0.89 0.47 0.10; 0.20 0.60 0.30]; % 80, 150, 210 W
    fonte = 'Times New Roman';

    fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 8.6 6.5]);
    tl = tiledlayout(fig, N, N, 'Padding', 'compact', 'TileSpacing', 'none');

    for i = 1:N
        for j = 1:N
            ax = nexttile(tl, (i-1)*N + j);
            ax.Toolbar.Visible = 'off'; % senao a barra de ferramentas sai impressa no PDF
            x = M(:,j); y = M(:,i);
            hold(ax, 'on');

            if i == j
                bordas = linspace(min(x), max(x) + eps, 16);
                for g = 1:numel(niveis)
                    histogram(ax, x(grupo == niveis(g)), bordas, 'FaceColor', cores(g,:), ...
                        'EdgeColor', 'none', 'FaceAlpha', 0.6);
                end
                xlim(ax, [min(x) - 0.05*range(x), max(x) + 0.05*range(x)]);
            else
                for g = 1:numel(niveis)
                    s = grupo == niveis(g);
                    scatter(ax, x(s), y(s), 1.2, cores(g,:), 'filled', 'MarkerFaceAlpha', 0.5);
                end
                if j == 1 % so nos quadros feature x C: mediana de cada feature por nivel de C
                    [xc, yc] = tendencia_mediana(x, y);
                    plot(ax, xc, yc, '-', 'Color', [0.75 0 0], 'LineWidth', 0.8);
                end

                lim = prctile(y, [0.5 99.5]); folga = 0.08 * range(y);
                if lim(2) > lim(1); ylim(ax, [lim(1) - folga, lim(2) + 3*folga]); end
                xlim(ax, [min(x) - 0.05*range(x), max(x) + 0.05*range(x)]);
                text(ax, 0.04, 0.96, sprintf('%.2f', rho(i,j)), 'Units', 'normalized', ...
                    'VerticalAlignment', 'top', 'FontName', fonte, 'FontSize', 6.5, 'FontWeight', 'bold', ...
                    'BackgroundColor', [1 1 1 0.7], 'Margin', 0.1);
            end

            set(ax, 'XTick', [], 'YTick', [], 'Box', 'on', 'LineWidth', 0.3);
            if i == N; xlabel(ax, labels{j}, 'Interpreter', 'latex', 'FontSize', 9); end
            if j == 1; ylabel(ax, labels{i}, 'Interpreter', 'latex', 'FontSize', 9); end
            hold(ax, 'off');
        end
    end
end

function [xc, yc] = tendencia_mediana(x, y)
% Mediana de y em cada nivel de x (x discreto, como C e P) ou em 8 faixas de
% x com o mesmo numero de pontos (x continuo).
    niveisX = unique(x);
    if numel(niveisX) <= 10
        xc = niveisX;
        yc = arrayfun(@(v) median(y(x == v)), niveisX);
    else
        bordas = unique(prctile(x, linspace(0, 100, 9)));
        idx = discretize(x, bordas);
        xc = accumarray(idx, x, [], @median);
        yc = accumarray(idx, y, [], @median);
    end
end

function plota_matriz(M, labels, titulo, grupo)
% grupo: vetor com a carga de cada ensaio (pinta cada carga de uma cor);
% vazio = todos os pontos da mesma cor.

    N = size(M, 2);
    rho = corr(M, 'Type', 'Spearman');

    if isempty(grupo); grupo = ones(size(M,1), 1); end
    niveis = unique(grupo);
    cores = [0.23 0.44 0.69; 0.89 0.47 0.10; 0.20 0.60 0.30]; % 80, 150, 210 W
    if numel(niveis) == 1; cores = [0.23 0.44 0.69]; end

    fig = figure('Name', ['Spearman matrix - ' titulo], 'NumberTitle', 'off', ...
        'Position', [30 30 1100 1050], 'Color', 'w');
    tl = tiledlayout(fig, N, N, 'Padding', 'tight', 'TileSpacing', 'compact');
    hLeg = [];

    for i = 1:N
        for j = 1:N
            ax = nexttile(tl, (i-1)*N + j);
            x = M(:,j); y = M(:,i);
            hold(ax, 'on');

            if i == j
                bordas = linspace(min(x), max(x) + eps, 21);
                for g = 1:numel(niveis)
                    histogram(x(grupo == niveis(g)), bordas, 'FaceColor', cores(g,:), ...
                        'EdgeColor', 'none', 'FaceAlpha', 0.55);
                end
            else
                h = gobjects(numel(niveis), 1);
                for g = 1:numel(niveis)
                    s = grupo == niveis(g);
                    h(g) = scatter(x(s), y(s), 4, cores(g,:), 'filled', 'MarkerFaceAlpha', 0.4);
                end
                if isempty(hLeg); hLeg = h; end
                % corta 0,5% dos extremos no eixo y para os outliers nao achatarem o grafico
                lim = prctile(y, [0.5 99.5]); folga = 0.05 * range(y);
                if lim(2) > lim(1); ylim([lim(1) - folga, lim(2) + folga]); end
                xlim([min(x) - 0.05*range(x), max(x) + 0.05*range(x)]);
                title(sprintf('%.2f', rho(i,j)), 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
            end

            if i == N
                xlabel(labels{j}, 'FontSize', 14);
            end
            if j == 1
                ylabel(labels{i}, 'FontSize', 14, 'Rotation', 0, 'HorizontalAlignment', 'right');
            end
            % sem 'FontSize' aqui: mudar a fonte do eixo depois redimensiona o
            % titulo e os rotulos que ja foram criados
            set(ax, 'XTick', [], 'YTick', []);
            box(ax, 'on'); hold(ax, 'off');
        end
    end

    if numel(niveis) > 1
        lgd = legend(hLeg, compose('%d W', niveis), 'Orientation', 'horizontal', 'FontSize', 13);
        lgd.Layout.Tile = 'north';
    end
    title(tl, sprintf('%s (n = %d tests)', titulo, size(M,1)), 'FontSize', 15, 'FontWeight', 'bold');

    fprintf('\n%s - Spearman com C (n = %d ensaios):\n', titulo, size(M,1));
    for j = 2:N
        fprintf('  %-12s %5.2f\n', labels{j}, rho(1,j));
    end
end
