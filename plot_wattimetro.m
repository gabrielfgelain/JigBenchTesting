function plot_wattimetro(arquivo)
% Plota o log do wattimetro (WT230): potencia total, tensao e corrente
% (elementos A e B) ao longo das amostras. Formato: separador tab,
% decimais com virgula, com cabecalho (t, PL(A), PL(B), PL(T), PL(E),
% V(A), V(B), V(E), I(A), I(B), I(E)).
%
% Uso: plot_wattimetro('20260917_161430_meas_Wattimetro__b.csv')

    if nargin < 1 || isempty(arquivo)
        arquivo = '20260917_161430_meas_Wattimetro__b.csv';
    end

    dados = le_wattimetro(arquivo);

    potenciaTotal = dados(:, 4); % PL(T)
    tensaoA = dados(:, 6);       % V(A)
    tensaoB = dados(:, 7);       % V(B)
    correnteA = dados(:, 9);     % I(A)
    correnteB = dados(:, 10);    % I(B)

    x = 0:(size(dados, 1) - 1);

    figure('Name', arquivo, 'NumberTitle', 'off', 'Position', [50 50 1200 800]);

    subplot(3, 1, 1);
    plot(x, potenciaTotal, '-o', 'MarkerSize', 3);
    grid on;
    ylabel('Potência (W)');
    title('Potência total - PL(T)');

    subplot(3, 1, 2);
    plot(x, tensaoA, '-o', x, tensaoB, '-o', 'MarkerSize', 3);
    grid on;
    ylabel('Tensão (V)');
    title('Tensão');
    legend({'V(A)', 'V(B)'}, 'Location', 'best');

    subplot(3, 1, 3);
    plot(x, correnteA, '-o', x, correnteB, '-o', 'MarkerSize', 3);
    grid on;
    ylabel('Corrente (A)');
    title('Corrente');
    legend({'I(A)', 'I(B)'}, 'Location', 'best');

    xlabel('Amostra');
    sgtitle(arquivo, 'Interpreter', 'none');
end

function dados = le_wattimetro(arquivo)
% Le o log do wattimetro: separador tab, decimais com virgula, 1 linha
% de cabecalho.

    texto = fileread(arquivo);
    texto = strrep(texto, ',', '.');

    arqTemp = [tempname(), '.csv'];
    fid = fopen(arqTemp, 'w');
    fwrite(fid, texto);
    fclose(fid);

    dados = readmatrix(arqTemp, 'Delimiter', '\t', 'NumHeaderLines', 1);
    delete(arqTemp);
end
