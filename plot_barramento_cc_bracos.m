function plot_barramento_cc_bracos()
% Concatena os ensaios de 7 a 0 bracos (RSE, RSE1047, RSE2047 e RSE2068,
% sem carga) em sequencia, como se fossem um unico ensaio, e plota a
% tensao do barramento CC (coluna 2 dos CSVs) com uma linha vermelha
% marcando o valor medio de cada ensaio (bloco de bracos).

    ordemBracos = 7:-1:0;

    grupos = {
        'Dados_Ensaios/SemCarga_3000RPM_1MOSFET', 'Ensaio_%dbracos_RSE_SemCarga_2026-08-26_13-30.csv',     'RSE';
        'Dados_Ensaios/SemCarga_3000RPM_1047',    'Ensaio_%dbracos_RSE1047_SemCarga_2026-08-26_13-30.csv', 'RSE1047';
        'Dados_Ensaios/SemCarga_3000RPM_2047',    'Ensaio_%dbracos_RSE2047_SemCarga_2026-08-27_13-15.csv', 'RSE2047';
        'Dados_Ensaios/SemCarga_3000RPM_2068',    'Ensaio_%dbracos_RSE2068_SemCarga_2026-08-27_13-15.csv', 'RSE2068'
    };

    for g = 1:size(grupos, 1)
        plot_grupo(grupos{g, 1}, grupos{g, 2}, ordemBracos, grupos{g, 3});
    end
end

function plot_grupo(pasta, padraoArquivo, ordemBracos, nomeGrupo)

    tensao = [];
    limites = zeros(numel(ordemBracos) + 1, 1);

    for i = 1:numel(ordemBracos)
        arquivo = fullfile(pasta, sprintf(padraoArquivo, ordemBracos(i)));
        v = le_coluna_csv(arquivo, 2);

        limites(i + 1) = limites(i) + numel(v);
        tensao = [tensao; v]; %#ok<AGROW>
    end

    x = 0:(numel(tensao) - 1);

    Fs = 100000; % Hz (100000 amostras por segundo)

    janelaFiltro = round(0.00005 * Fs); % 0,5 ms, so para suavizar a curva e o Vpp
    tensaoFiltrada = movmean(tensao, janelaFiltro);

    media         = zeros(size(tensao));
    rippleVppFilt = zeros(numel(ordemBracos), 1);
    rippleStd     = zeros(numel(ordemBracos), 1);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        media(idx)       = mean(tensao(idx));
        rippleVppFilt(i) = max(tensaoFiltrada(idx)) - min(tensaoFiltrada(idx));
        rippleStd(i)     = std(tensao(idx));
    end

    figure('Name', ['Barramento CC - ' nomeGrupo], 'NumberTitle', 'off', ...
        'Position', [50 50 1400 800]);
    hTensao = plot(x, tensaoFiltrada, 'LineWidth', 1);
    hold on;
    hMedia = plot(x, media, 'r', 'LineWidth', 2);
    hold off;

    ax = gca;
    ax.FontSize = 16;

    grid on;
    xlim([0 numel(tensao) - 1]);
    xlabel('Amostra', 'FontSize', 18);
    ylabel('Tensão (V)', 'FontSize', 18);
    title(sprintf('Tensão no barramento CC - %s (7 a 0 braços)', nomeGrupo), 'FontSize', 20);
    legend([hTensao, hMedia], {'Tensão', 'Valor médio'}, 'Location', 'best', 'FontSize', 16);

    for i = 1:numel(ordemBracos)
        xl = xline(limites(i), '--', sprintf('%d braços', ordemBracos(i)), ...
            'Color', [0.5 0.5 0.5], 'LabelVerticalAlignment', 'top', 'FontSize', 14);
        xl.HandleVisibility = 'off';
    end

    fprintf('--- %s: tensão média e ripple por ensaio ---\n', nomeGrupo);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        fprintf('%d braços: média = %.3f V | Vpp (suavizado) = %.3f V | ripple (desvio padrão) = %.3f V\n', ...
            ordemBracos(i), mean(tensao(idx)), rippleVppFilt(i), rippleStd(i));
    end
end

function coluna = le_coluna_csv(arquivo, indiceColuna)
% Le um CSV com separador ";" e decimais com virgula, retornando a
% coluna solicitada.

    texto = fileread(arquivo);
    texto = strrep(texto, ',', '.');

    arqTemp = [tempname(), '.csv'];
    fid = fopen(arqTemp, 'w');
    fwrite(fid, texto);
    fclose(fid);

    dados = readmatrix(arqTemp, 'Delimiter', ';');
    delete(arqTemp);

    coluna = dados(:, indiceColuna);
end
