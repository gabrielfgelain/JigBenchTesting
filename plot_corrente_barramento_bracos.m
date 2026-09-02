function plot_corrente_barramento_bracos()
% Mesma logica do plot_barramento_cc_bracos, mas para a corrente do
% barramento CC (coluna 5 dos CSVs). Antes de suavizar, remove os picos
% pontuais de saturacao do instrumento (valores isolados na casa de
% centenas de A, muito acima da corrente real) com filloutliers.

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

    corrente = [];
    limites = zeros(numel(ordemBracos) + 1, 1);

    for i = 1:numel(ordemBracos)
        arquivo = fullfile(pasta, sprintf(padraoArquivo, ordemBracos(i)));
        v = le_coluna_csv(arquivo, 5);

        limites(i + 1) = limites(i) + numel(v);
        corrente = [corrente; v]; %#ok<AGROW>
    end

    Fs = 100000; % Hz (100000 amostras por segundo)

    janelaOutlier = 20; % amostras, remove os picos pontuais de saturacao
    correnteSemPicos = filloutliers(corrente, 'linear', 'movmedian', janelaOutlier);

    janelaFiltro = round(Fs / 500); % ~1 periodo da portadora de chaveamento (~500 Hz)
    correnteFiltrada = movmean(correnteSemPicos, janelaFiltro);

    x = 0:(numel(corrente) - 1);

    media    = zeros(size(corrente));
    rippleVpp = zeros(numel(ordemBracos), 1);
    rmsSemPicos = zeros(numel(ordemBracos), 1);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        media(idx)        = mean(correnteSemPicos(idx));
        rippleVpp(i)       = max(correnteFiltrada(idx)) - min(correnteFiltrada(idx));
        rmsSemPicos(i)     = rms(correnteSemPicos(idx));
    end

    figure('Name', ['Corrente barramento CC - ' nomeGrupo], 'NumberTitle', 'off', ...
        'Position', [50 50 1400 800]);
    hCorrente = plot(x, correnteFiltrada, 'LineWidth', 1);
    hold on;
    hMedia = plot(x, media, 'r', 'LineWidth', 2);
    hold off;

    ax = gca;
    ax.FontSize = 16;

    grid on;
    xlim([0 numel(corrente) - 1]);
    xlabel('Amostra', 'FontSize', 18);
    ylabel('Corrente (A)', 'FontSize', 18);
    title(sprintf('Corrente no barramento CC (sem picos, filtrada) - %s (7 a 0 braços)', nomeGrupo), 'FontSize', 20);
    legend([hCorrente, hMedia], {'Corrente', 'Valor médio'}, 'Location', 'best', 'FontSize', 16);

    for i = 1:numel(ordemBracos)
        xl = xline(limites(i), '--', sprintf('%d braços', ordemBracos(i)), ...
            'Color', [0.5 0.5 0.5], 'LabelVerticalAlignment', 'top', 'FontSize', 14);
        xl.HandleVisibility = 'off';
    end

    fprintf('--- %s: corrente do barramento (picos removidos) ---\n', nomeGrupo);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        fprintf('%d braços: média = %.4f A | RMS (sem picos) = %.4f A | Vpp (filtrado) = %.4f A\n', ...
            ordemBracos(i), mean(correnteSemPicos(idx)), rmsSemPicos(i), rippleVpp(i));
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
