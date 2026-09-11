function plot_teste_todos_canais()
% Plota os canais 1, 2 e 4 do teste.csv, mais a coluna 5 duas vezes:
% bruta e filtrada (picos de saturacao removidos com filloutliers).
% Colunas 3 e 6 foram removidas.

    arquivo = 'teste.csv';

    dados = le_csv(arquivo);
    x = 0:(size(dados, 1) - 1);

    col5Filtrada = filloutliers(dados(:, 5), 'linear', 'movmedian', 20);

    rotulos = {'Coluna 1', 'Coluna 2', 'Coluna 4', 'Coluna 5', 'Coluna 5 (filtrada)'};
    unidades = {'V', 'V', 'A', 'A', 'A'};
    series = {dados(:, 1), dados(:, 2), dados(:, 4), dados(:, 5), col5Filtrada};

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
