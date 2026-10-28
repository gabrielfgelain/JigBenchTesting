function plot_bracos_motor_barramento(pasta, padraoArquivo, nomeGrupo, limitesBarramento)
% Script generico para plotar tensao no motor (coluna 1), corrente no
% motor (coluna 5) e tensao no barramento CC (coluna 2), concatenando os
% ensaios de 7 a 0 bracos de uma pasta como se fossem um unico ensaio
% ("colado"), com o valor medio de cada ensaio destacado - mesmo formato
% usado em plot_barramento_cc_bracos.m.
%
% Uso generico (qualquer pasta no mesmo layout de arquivo, com "%d" no
% lugar do numero de bracos no nome):
%   plot_bracos_motor_barramento('Dados_Ensaios/NovaPasta', ...
%       '%dBracos_NovoEnsaio_2026-01-01.csv', 'NovaPasta')
%
% Sem argumentos, roda no dataset 80W_3500RPM_R1000 (usa o conjunto
% completo de 0 a 7 bracos, timestamp 14_50).
%
% limitesBarramento (opcional, [min max] em V) fixa o eixo Y do grafico de
% tensao do barramento - util para comparar cargas diferentes na mesma
% escala, ex.:
%   plot_bracos_motor_barramento('Dados_Ensaios/80W_3000RPM_R1000', ...
%       '%dBracos_3000_R1000_80W_2026-09-28_10_00.csv', '80W_3000RPM_R1000', [292 312])

    if nargin < 1 || isempty(pasta)
        pasta = 'Dados_Ensaios/150W_3500RPM_R0011';
    end
    if nargin < 2 || isempty(padraoArquivo)
        padraoArquivo = '%dBracos_R0011_150W_2026-09-24_16_25.csv';
    end
    if nargin < 3 || isempty(nomeGrupo)
        nomeGrupo = '150_3500RPM_R0010';
    end
    if nargin < 4
        limitesBarramento = [];
    end

    ordemBracos = 7:-1:0;
    Fs = 1e6; % Hz (1 MS/s no PZ4000: 100.000 amostras = janela de 0,1 s)

    % {coluna, nome do canal (em ingles, aparece nas figuras), unidade,
    %  remover picos de saturacao antes de suavizar}
    canais = {
        1, 'Motor voltage',   'V', false;
        5, 'Motor current',   'A', true;
        2, 'DC-link voltage', 'V', false
    };

    for c = 1:size(canais, 1)
        limitesY = [];
        if canais{c, 1} == 2; limitesY = limitesBarramento; end
        plot_canal(pasta, padraoArquivo, ordemBracos, nomeGrupo, Fs, ...
            canais{c, 1}, canais{c, 2}, canais{c, 3}, canais{c, 4}, limitesY);
    end
end

function plot_canal(pasta, padraoArquivo, ordemBracos, nomeGrupo, Fs, ...
        indiceColuna, nomeCanal, unidade, removerPicos, limitesY)

    sinal = [];
    limites = zeros(numel(ordemBracos) + 1, 1);

    for i = 1:numel(ordemBracos)
        arquivo = fullfile(pasta, sprintf(padraoArquivo, ordemBracos(i)));
        v = le_coluna_csv(arquivo, indiceColuna);

        limites(i + 1) = limites(i) + numel(v);
        sinal = [sinal; v]; %#ok<AGROW>
    end

    % A deteccao estatistica de outlier (filloutliers com 'movmedian') foi
    % abandonada: com essa janela, ela marcava ~9% das amostras como
    % outlier - nao so os ~0,18% que sao saturacao real do instrumento -,
    % suavizando ripple legitimo do sinal e distorcendo a media (testado
    % em 20260922_15_28.../7Bracos_R0010: media ia de 0,72 A brutos para
    % -0,03 A "filtrado", quando o valor real, so removendo a saturacao, e
    % 0,01 A). Em vez disso, usa um limiar fixo: a saturacao do instrumento
    % nesse canal e um patamar quase constante (~387,2-387,5 A) e o sinal
    % real nunca passa de ~13 A em nenhuma captura do dataset (conferido
    % nos 367 arquivos de Dados_Ensaios) - ha uma folga limpa entre os
    % dois, sem amostra nenhuma entre 13 e 380 A.
    limiteSaturacaoA = 50;

    if removerPicos
        atingiuSaturacao = abs(sinal) > limiteSaturacaoA;
        sinalBase = filloutliers(sinal, 'linear', 'OutlierLocations', atingiuSaturacao);
        fprintf('%s: %d/%d amostras de saturacao removidas (%.3f%%)\n', ...
            nomeCanal, sum(atingiuSaturacao), numel(sinal), ...
            100 * sum(atingiuSaturacao) / numel(sinal));
    else
        sinalBase = sinal;
    end

    janelaFiltro = round(Fs / 50000); % janela leve de suavizacao (20 us)
    sinalFiltrado = movmean(sinalBase, janelaFiltro);

    x = 0:(numel(sinal) - 1);

    figure('Name', sprintf('%s - %s', nomeGrupo, nomeCanal), 'NumberTitle', 'off', ...
        'Position', [50 50 1400 800]);
    hSinal = plot(x, sinalFiltrado, 'LineWidth', 1);

    ax = gca;
    ax.FontSize = 16;

    grid on;
    xlim([0 numel(sinal) - 1]);
    if ~isempty(limitesY); ylim(limitesY); end
    xlabel('Sample', 'FontSize', 18);
    ylabel(sprintf('%s (%s)', nomeCanal, unidade), 'FontSize', 18);
    title(sprintf('%s - %s (7 to 0 capacitor branches)', nomeCanal, nomeGrupo), 'FontSize', 20, ...
        'Interpreter', 'none');
   
    for i = 1:numel(ordemBracos)
        if ordemBracos(i) == 1; rotulo = '1 branch'; else; rotulo = sprintf('%d branches', ordemBracos(i)); end
        xl = xline(limites(i), '--', rotulo, ...
            'Color', [0.5 0.5 0.5], 'LabelVerticalAlignment', 'top', 'FontSize', 14);
        xl.HandleVisibility = 'off';
    end

    rms = zeros(numel(ordemBracos), 1);
    fprintf('--- %s: %s ---\n', nomeGrupo, nomeCanal);
    for i = 1:numel(ordemBracos)
        idx = (limites(i) + 1):limites(i + 1);
        rms(i) = sqrt(mean(sinalBase(idx) .^ 2));
        fprintf('%d braços: média = %.4f %s | desvio padrão = %.4f %s | RMS = %.4f %s\n', ...
            ordemBracos(i), mean(sinalBase(idx)), unidade, std(sinalBase(idx)), unidade, ...
            rms(i), unidade);
    end

    % --- RMS por numero de bracos (ordem crescente, 0 a 7) ---
    figure('Name', sprintf('%s - %s (RMS)', nomeGrupo, nomeCanal), 'NumberTitle', 'off', ...
        'Position', [70 70 800 500]);
    [bracosOrdenado, ordem] = sort(ordemBracos);
    plot(bracosOrdenado, rms(ordem), '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'MarkerFaceColor', 'auto');
    grid on;
    xlim([-0.5 7.5]);
    xticks(0:7);
    xlabel('Active capacitor branches', 'FontSize', 14);
    ylabel(sprintf('%s RMS (%s)', nomeCanal, unidade), 'FontSize', 14);
    title(sprintf('%s RMS vs. active capacitor branches - %s', nomeCanal, nomeGrupo), ...
        'FontSize', 16, 'Interpreter', 'none');
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
