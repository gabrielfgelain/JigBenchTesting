function plot_matriz_correlacao_potencia()
% Monta, para cada potencia (80W/150W/210W), uma matriz de correlacao
% (estilo Fig. 9 de artigos de monitoramento de capacitor) entre:
% tensao do motor, tensao e ripple do barramento CC, corrente do motor,
% capacitancia e resistencia serie equivalente (essas duas ultimas
% calculadas a partir da configuracao de bracos/resistor de cada
% ensaio, nao medidas diretamente).
%
% Varre todas as pastas Dados_Ensaios/<potencia>_3500RPM_R*, extrai as
% features de cada arquivo e plota uma figura por potencia.

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
    potencias = {'80W','150W','210W'};

    for p = 1:numel(potencias)
        [M, vars, labels] = extrai_features_potencia(potencias{p}, capPorBracos, RarmCombo, janelaFiltro);
        plota_matriz(M, vars, labels, potencias{p});
    end
end

function [M, vars, labels] = extrai_features_potencia(potencia, capPorBracos, RarmCombo, janelaFiltro)

    vars = {'V1_rms', 'V2_mean', 'V2_std', 'I_media_rms', 'C_uF', 'R_serie_ohm'};
    labels = {'Tensão motor (V)', 'Tensão barramento (V)', 'Ripple barramento (V)', ...
        'Corrente motor (A)', 'Capacitância (µF)', 'Resistência série (Ω)'};

    padraoPasta = sprintf('Dados_Ensaios/%s_3500RPM_R*', potencia);
    pastas = dir(padraoPasta);
    pastas = pastas([pastas.isdir]);

    linhas = [];
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
            tokB = regexp(nomeArq, '^(\d+)Bracos', 'tokens');
            if isempty(tokB); continue; end
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
    fprintf('%s: %d ensaios processados.\n', potencia, size(M,1));
end

function plota_matriz(M, vars, labels, tituloPotencia)

    N = numel(vars);
    fig = figure('Name', ['Matriz de correlação - ' tituloPotencia], 'NumberTitle', 'off', ...
        'Position', [30 30 1150 1050], 'Color', 'w');
    tl = tiledlayout(fig, N, N, 'Padding', 'tight', 'TileSpacing', 'compact');

    for i = 1:N
        for j = 1:N
            nexttile(tl, (i-1)*N + j);
            x = M(:,j); y = M(:,i);

            if i == j
                histogram(x, 15, 'FaceColor', [0.30 0.55 0.85], 'EdgeColor', 'none');
            else
                scatter(x, y, 14, [0.20 0.45 0.80], 'filled', 'MarkerFaceAlpha', 0.55);
                hold on;
                pfit = polyfit(x, y, 1);
                xx = linspace(min(x), max(x), 50);
                yy = polyval(pfit, xx);
                plot(xx, yy, 'r-', 'LineWidth', 1.2); % vermelho so na linha de ajuste
                hold off;
                r = corr(x, y);
                title(sprintf('%.2f', r), 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');
            end

            if i == N
                xlabel(labels{j}, 'FontSize', 9, 'FontWeight', 'bold');
            end
            if j == 1
                ylabel(labels{i}, 'FontSize', 9, 'FontWeight', 'bold');
            end
            set(gca, 'FontSize', 7, 'XTickLabel', [], 'YTickLabel', []);
            box on;
        end
    end

    title(tl, sprintf('Matriz de correlação - %s (n=%d ensaios)', tituloPotencia, size(M,1)), ...
        'FontSize', 15, 'FontWeight', 'bold', 'Color', 'k');
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
