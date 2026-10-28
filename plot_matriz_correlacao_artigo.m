function plot_matriz_correlacao_artigo(rpms, potencias)
% Matriz de correlacao (Pearson) no formato da Fig. 9 de Oruklu & Agalar,
% "Machine Learning-Based Condition Monitoring for DC-Link Capacitors in
% AC/DC/AC Converters", IEEE TIE, 2025.
%
% Como no artigo:
%  - features no tempo: pico a pico da tensao do barramento (Vdc,p2p) e rms
%    da corrente de saida (Iout,rms);
%  - features na frequencia: PSD do ripple do barramento nas componentes
%    dominantes, P(k) = |X(k)|^2 / (N*Fs), sem filtro no sinal;
%  - todas as cargas (potencias) juntas na mesma matriz, por isso a Iout,rms
%    entra como indicador de carga.
%
% Adaptacoes para a bancada (o artigo tem entrada trifasica e saida
% monofasica; aqui e o contrario):
%  - PSD120 e PSD240: ripple do retificador monofasico (2 e 4 x 60 Hz), o
%    equivalente ao PSD300 (6 x f_in) do artigo;
%  - PSD6fe: ripple do inversor trifasico em 6 x f_e (f_e = RPM/30, motor
%    com 2 pares de polos), o equivalente ao PSD60/PSD120 do artigo. Em
%    3000 RPM, 6 x f_e = 600 Hz coincide com 5 x 120 Hz;
%  - PSD5k: componente de alta frequencia em ~5 kHz, candidata a carregar
%    a ESR (o artigo so estima C, pois a ESR nao aparece em baixa frequencia);
%  - uma matriz por rotacao (so comparar ensaios da mesma rotacao) e a
%    janela inteira de 0,1 s (resolucao de 10 Hz, para separar 6 x f_e das
%    harmonicas de 120 Hz), em vez de 3 periodos da corrente.
%
% Uso:
%   plot_matriz_correlacao_artigo()                  % 2700, 3000 e 3500 RPM
%   plot_matriz_correlacao_artigo(3500)
%   plot_matriz_correlacao_artigo(3000, {'80W','210W'})

    if nargin < 1 || isempty(rpms); rpms = [2700 3000 3500]; end
    if nargin < 2 || isempty(potencias); potencias = {'80W','150W','210W'}; end

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

    for r = rpms
        [M, labels] = extrai_features(r, potencias, capPorBracos, RarmCombo);
        if isempty(M); continue; end
        plota_matriz(M, labels, sprintf('%d RPM', r));
    end
end

function [M, labels] = extrai_features(rpm, potencias, capPorBracos, RarmCombo)

    Fs = 1e6;           % 1 MS/s (PZ4000), janela de 0,1 s
    janelaFiltro = 200; % ~5 kHz, suaviza a corrente antes do RMS (picos de saturacao)
    fe = rpm / 30;      % frequencia eletrica do motor (2 pares de polos)

    % rotulos em ingles (aparecem nas figuras), no estilo do artigo
    labels = {{'V_{dc,p2p}', '(V)'}, {'PSD_{120}', '(V^2/Hz)'}, {'PSD_{240}', '(V^2/Hz)'}, ...
        {sprintf('PSD_{%d}', round(6*fe)), '(V^2/Hz)'}, {'PSD_{5k}', '(V^2/Hz)'}, ...
        {'I_{out,rms}', '(A)'}, {'C_{link}', '(\muF)'}, {'R_{s}', '(\Omega)'}};

    linhas = [];
    for p = 1:numel(potencias)
        pastas = dir(sprintf('Dados_Ensaios/%s_%dRPM_R*', potencias{p}, rpm));
        pastas = pastas([pastas.isdir]);

        for k = 1:numel(pastas)
            nomePasta = pastas(k).name;
            tok = regexp(nomePasta, 'R(\d{4})$', 'tokens');
            if isempty(tok); continue; end
            codigo = tok{1}{1};
            if ~isKey(RarmCombo, codigo); continue; end
            rArmVal = RarmCombo(codigo);

            arquivos = dir(fullfile('Dados_Ensaios', nomePasta, '*.csv'));
            for f = 1:numel(arquivos)
                nomeArq = arquivos(f).name;
                % aceita "7Bracos_R1000_..." (3500 RPM) e "7Bracos_3000_R1000_..." (outras)
                tokB = regexp(nomeArq, '^(\d+)Bracos(?:_\d+)?_R(\d{4})_', 'tokens');
                if isempty(tokB); continue; end
                if ~strcmp(tokB{1}{2}, codigo); continue; end
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

                v2 = dados(:,2);
                vac = v2 - mean(v2);
                N = numel(vac);
                X = fft(vac);
                P = abs(X(1:floor(N/2))).^2 / (N * Fs);
                fvec = (0:floor(N/2)-1)' * Fs / N;

                i4f = movmean(dados(:,4), janelaFiltro);
                i5f = movmean(dados(:,5), janelaFiltro);

                linha = [max(v2) - min(v2), ...
                    pico(P, fvec, 120, 10), pico(P, fvec, 240, 10), ...
                    pico(P, fvec, 6*fe, 10), pico(P, fvec, 5000, 50), ...
                    mean([rms(i4f), rms(i5f)]), C, R];
                linhas = [linhas; linha]; %#ok<AGROW>
            end
        end
    end

    M = linhas;
    fprintf('%d RPM: %d ensaios processados.\n', rpm, size(M,1));
end

function v = pico(P, fvec, fAlvo, tol)
% Maior valor da PSD perto da frequencia esperada (tolera pequena variacao
% de rotacao/rede).
    idx = abs(fvec - fAlvo) <= tol;
    v = max(P(idx));
end

function plota_matriz(M, labels, tituloEnsaio)

    N = size(M, 2);
    fig = figure('Name', ['Correlation matrix - ' tituloEnsaio], 'NumberTitle', 'off', ...
        'Position', [30 30 1150 1050], 'Color', 'w');
    tl = tiledlayout(fig, N, N, 'Padding', 'tight', 'TileSpacing', 'compact');

    rho = corr(M);

    for i = 1:N
        for j = 1:N
            nexttile(tl, (i-1)*N + j);
            x = M(:,j); y = M(:,i);

            if i == j
                histogram(x, 15, 'FaceColor', [0.30 0.55 0.85], 'EdgeColor', 'none');
            else
                scatter(x, y, 10, [0.20 0.45 0.80], 'filled', 'MarkerFaceAlpha', 0.5);
                hold on;
                pfit = polyfit(x, y, 1);
                xx = linspace(min(x), max(x), 50);
                plot(xx, polyval(pfit, xx), 'r-', 'LineWidth', 1.2);
                hold off;
                title(sprintf('%.2f', rho(i,j)), 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
            end

            if i == N
                xlabel(labels{j}, 'FontSize', 10, 'FontWeight', 'bold');
            end
            if j == 1
                ylabel(labels{i}, 'FontSize', 10, 'FontWeight', 'bold');
            end
            set(gca, 'FontSize', 7, 'XTickLabel', [], 'YTickLabel', []);
            box on;
        end
    end

    title(tl, sprintf('Correlation matrix - %s (n = %d tests)', tituloEnsaio, size(M,1)), ...
        'FontSize', 15, 'FontWeight', 'bold', 'Color', 'k');

    % resumo no console: correlacao de cada feature com C e com R
    nomes = {'Vdc_p2p', 'PSD120', 'PSD240', 'PSD6fe', 'PSD5k', 'Iout_rms'};
    fprintf('  %-9s  r(C)    r(R)\n', '');
    for k = 1:numel(nomes)
        fprintf('  %-9s %6.2f  %6.2f\n', nomes{k}, rho(k, N-1), rho(k, N));
    end
    fprintf('  r(C,R) = %.2f\n', rho(N-1, N));
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
