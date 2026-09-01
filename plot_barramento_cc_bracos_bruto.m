function plot_barramento_cc_bracos_bruto()
% Igual ao plot_barramento_cc_bracos, mas sem suavizacao (movmean): plota
% a tensao bruta do barramento CC, so removendo outliers pontuais com
% filloutliers (mediana movel). Atencao: boa parte dos "picos" desse
% sinal sao ripple real de chaveamento amostrado numa resolucao grosseira
% (~1,22 V por degrau), nao erro de medicao - a remocao de outliers aqui
% e so uma limpeza estatistica, nao uma correcao de instrumento.

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

    Fs = 100000; % Hz (100000 amostras por segundo)
    janelaOutlier = round(0.001 * Fs); % 1 ms de mediana movel

    tensaoSemOutliers = filloutliers(tensao, 'linear', 'movmedian', janelaOutlier);

    x = 0:(numel(tensao) - 1);

    media     = zeros(size(tensao));
    rippleVpp = zeros(numel(ordemBracos), 1);
    rippleStd = zeros(numel(ordemBracos), 1);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        media(idx)     = mean(tensao(idx));
        rippleVpp(i)   = max(tensaoSemOutliers(idx)) - min(tensaoSemOutliers(idx));
        rippleStd(i)   = std(tensao(idx));
    end

    figure('Name', ['Barramento CC (bruto) - ' nomeGrupo], 'NumberTitle', 'off', ...
        'Position', [50 50 1400 800]);
    hTensao = plot(x, tensaoSemOutliers, 'LineWidth', 1);
    hold on;
    hMedia = plot(x, media, 'r', 'LineWidth', 2);
    hold off;

    ax = gca;
    ax.FontSize = 16;

    grid on;
    xlim([0 numel(tensao) - 1]);
    xlabel('Amostra', 'FontSize', 18);
    ylabel('Tensão (V)', 'FontSize', 18);
    title(sprintf('Tensão no barramento CC (sem filtro) - %s (7 a 0 braços)', nomeGrupo), 'FontSize', 20);
    legend([hTensao, hMedia], {'Tensão', 'Valor médio'}, 'Location', 'best', 'FontSize', 16);

    for i = 1:numel(ordemBracos)
        xl = xline(limites(i), '--', sprintf('%d braços', ordemBracos(i)), ...
            'Color', [0.5 0.5 0.5], 'LabelVerticalAlignment', 'top', 'FontSize', 14);
        xl.HandleVisibility = 'off';
    end

    fprintf('--- %s: tensão média e ripple por ensaio (sem filtro) ---\n', nomeGrupo);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        fprintf('%d braços: média = %.3f V | Vpp (sem outliers) = %.3f V | ripple (desvio padrão) = %.3f V\n', ...
            ordemBracos(i), mean(tensao(idx)), rippleVpp(i), rippleStd(i));
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
