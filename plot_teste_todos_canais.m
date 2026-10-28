function plot_teste_todos_canais()
% Plota os canais 1, 2 e 4 do teste.csv, mais a coluna 5 duas vezes:
% bruta e filtrada (picos de saturacao removidos com filloutliers).
% Colunas 3 e 6 foram removidas.

    arquivo = 'Dados_Ensaios/teste80.csv';

    dados = le_csv(arquivo);
    x = 0:(size(dados, 1) - 1);

    col4Filtrada = filloutliers(dados(:, 4), 'linear', 'movmedian', 20);
    col5Filtrada = filloutliers(dados(:, 5), 'linear', 'movmedian', 20);

        % --- Correlacao de Pearson entre tensao (Col1) e corrente ---
    r_col4        = corrcoef(dados(:,1), dados(:,4));
    r_col5        = corrcoef(dados(:,1), dados(:,5));
    r_col4_filt   = corrcoef(dados(:,1), col4Filtrada);

    % corrcoef devolve uma matriz 2x2; o valor que interessa e o [1,2]
    r_col4      = r_col4(1,2);
    r_col5      = r_col5(1,2);
    r_col4_filt = r_col4_filt(1,2);

    fprintf('Correlacao de Pearson (Tensao x Corrente):\n');
    fprintf('  Coluna 1 x Coluna 4 (bruta)    : r = %.4f\n', r_col4);
    fprintf('  Coluna 1 x Coluna 5 (bruta)    : r = %.4f\n', r_col5);
    fprintf('  Coluna 1 x Coluna 4 (filtrada) : r = %.4f\n', r_col4_filt);

    rotulos = {'Tensão Motor', 'Tensão Barramento', 'Corrente de linha', 'Corrente de linha 2', 'Corrente filtrada', 'Corrente filtrada 2'};
    unidades = {'V', 'V', 'A', 'A', 'A', 'A'};
    series = {dados(:, 1), dados(:, 2), dados(:, 4), dados(:, 5), col4Filtrada, col5Filtrada};

    figure('Name', 'teste.csv', 'NumberTitle', 'off', 'Position', [50 50 1400 900]);

    for k = 1:numel(series)
        subplot(numel(series), 1, k);
        plot(x, series{k}, 'LineWidth', 1);
        grid on;
        xlim([0 size(dados, 1) - 1]);
        ylabel(sprintf('%s (%s)', rotulos{k}, unidades{k}), 'FontSize', 11);
        title(rotulos{k}, 'FontSize', 13);
        set(gca, 'FontSize', 10);
    end

    xlabel('Amostra', 'FontSize', 12);
    sgtitle('teste.csv', 'FontSize', 18);
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
