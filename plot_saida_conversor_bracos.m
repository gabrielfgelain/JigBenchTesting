function plot_saida_conversor_bracos()
% Mesma logica do plot_barramento_cc_bracos, mas para a coluna 1 dos
% CSVs (suspeita de ser a saida do conversor/inversor, chaveada em PWM).
% A janela de suavizacao e escolhida para coincidir com o periodo da
% portadora de chaveamento (~500 Hz), revelando o envelope da moduladora.

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

    saida = [];
    limites = zeros(numel(ordemBracos) + 1, 1);

    for i = 1:numel(ordemBracos)
        arquivo = fullfile(pasta, sprintf(padraoArquivo, ordemBracos(i)));
        v = le_coluna_csv(arquivo, 1);

        limites(i + 1) = limites(i) + numel(v);
        saida = [saida; v]; %#ok<AGROW>
    end

    x = 0:(numel(saida) - 1);

    Fs = 100000; % Hz (100000 amostras por segundo)

    janelaFiltro = round(Fs / 500); % ~1 periodo da portadora de chaveamento (~500 Hz)
    saidaFiltrada = movmean(saida, janelaFiltro);

    media         = zeros(size(saida));
    rippleVppFilt = zeros(numel(ordemBracos), 1);
    rippleStd     = zeros(numel(ordemBracos), 1);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        media(idx)       = mean(saida(idx));
        rippleVppFilt(i) = max(saidaFiltrada(idx)) - min(saidaFiltrada(idx));
        rippleStd(i)     = std(saida(idx));
    end

    figure('Name', ['Saída do conversor - ' nomeGrupo], 'NumberTitle', 'off', ...
        'Position', [50 50 1400 800]);
    hSaida = plot(x, saidaFiltrada, 'LineWidth', 1);
    hold on;
    hMedia = plot(x, media, 'r', 'LineWidth', 2);
    hold off;

    ax = gca;
    ax.FontSize = 16;

    grid on;
    xlim([0 numel(saida) - 1]);
    xlabel('Amostra', 'FontSize', 18);
    ylabel('Tensão (V)', 'FontSize', 18);
    title(sprintf('Saída do conversor (coluna 1, filtrada) - %s (7 a 0 braços)', nomeGrupo), 'FontSize', 20);
    legend([hSaida, hMedia], {'Tensão', 'Valor médio'}, 'Location', 'best', 'FontSize', 16);

    for i = 1:numel(ordemBracos)
        xl = xline(limites(i), '--', sprintf('%d braços', ordemBracos(i)), ...
            'Color', [0.5 0.5 0.5], 'LabelVerticalAlignment', 'top', 'FontSize', 14);
        xl.HandleVisibility = 'off';
    end

    fprintf('--- %s: saída do conversor, média e ripple por ensaio ---\n', nomeGrupo);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        fprintf('%d braços: média = %.3f V | Vpp (suavizado) = %.3f V | ripple (desvio padrão) = %.3f V\n', ...
            ordemBracos(i), mean(saida(idx)), rippleVppFilt(i), rippleStd(i));
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
