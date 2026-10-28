function plot_variacao_esr(limitesY)
% Tensao do barramento CC no ensaio variando so a resistencia serie
% (6 bracos de capacitor fixos, 210 W, 2700 RPM), concatenando as capturas
% em ordem crescente de ESR - mesmo formato de plot_bracos_motor_barramento.m.
%
% limitesY (opcional, [min max] em V): fixa o eixo Y. Use [290 314] para
% ficar na mesma escala do grafico de variacao da capacitancia.

    if nargin < 1; limitesY = []; end

    pasta = 'Dados_Ensaios/Variando_RES';
    nBracos = 6;
    codigos = {'1000', '0011', '0110', '0101', '0010'};   % ordem crescente de ESR
    Fs = 1e6; % Hz

    sinal = [];
    limites = zeros(numel(codigos) + 1, 1);
    esr = zeros(numel(codigos), 1);
    for i = 1:numel(codigos)
        arquivo = fullfile(pasta, sprintf('%dbracos_210w_2700rpm_%s.csv', nBracos, codigos{i}));
        v = le_coluna_csv(arquivo, 2);
        limites(i + 1) = limites(i) + numel(v);
        sinal = [sinal; v]; %#ok<AGROW>
        esr(i) = r_serie(codigos{i}, nBracos);
    end

    janelaFiltro = round(Fs / 50000); % mesma suavizacao leve (20 us)
    sinalFiltrado = movmean(sinal, janelaFiltro);

    figure('Name', 'DC-link voltage - ESR variation', 'NumberTitle', 'off', 'Position', [50 50 1400 800]);
    hSinal = plot(0:numel(sinal) - 1, sinalFiltrado, 'LineWidth', 1);
    ax = gca; ax.FontSize = 16; grid on;
    xlim([0 numel(sinal) - 1]);
    if ~isempty(limitesY); ylim(limitesY); end
    xlabel('Sample', 'FontSize', 18);
    ylabel('DC-link voltage (V)', 'FontSize', 18);
    title('DC-link voltage - 210W, 2700 RPM, 6 capacitor branches (increasing ESR)', 'FontSize', 20, 'Interpreter', 'none');
    legend(hSinal, {'DC-link voltage'}, 'Location', 'southeast', 'FontSize', 16);
    for i = 1:numel(codigos)
        xl = xline(limites(i), '--', sprintf('R%s: ESR = %.3f \\Omega', codigos{i}, esr(i)), ...
            'Color', [0.5 0.5 0.5], 'LabelVerticalAlignment', 'top', 'FontSize', 13);
        xl.HandleVisibility = 'off';
    end

    fprintf('--- ESR variation: 210W, 2700 RPM, %d bracos ---\n', nBracos);
    for i = 1:numel(codigos)
        idx = (limites(i) + 1):limites(i + 1);
        fprintf('R%s (ESR %.3f ohm): media = %.2f V | desvio padrao = %.3f V\n', ...
            codigos{i}, esr(i), mean(sinal(idx)), std(sinal(idx)));
    end
end

function R = r_serie(codigo, nBracos)
% Resistencia serie vista no barramento (mesmo modelo dos demais scripts).
    Rarm = [0.11 0.58 0.345 0.45];
    G = sum(1 ./ Rarm(codigo == '1'));
    soma = 0.51 / nBracos + 1 / G;
    R = 0.1 + (0.1 * soma) / (0.1 + soma);
end

function coluna = le_coluna_csv(arquivo, indiceColuna)
    texto = fileread(arquivo);
    texto = strrep(texto, ',', '.');
    arqTemp = [tempname(), '.csv'];
    fid = fopen(arqTemp, 'w'); fwrite(fid, texto); fclose(fid);
    dados = readmatrix(arqTemp, 'Delimiter', ';');
    delete(arqTemp);
    coluna = dados(:, indiceColuna);
end
