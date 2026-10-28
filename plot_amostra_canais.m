function plot_amostra_canais(arquivo)
% Plota todos os 6 canais de um unico arquivo de ensaio (uma
% configuracao de bracos), sem concatenar nada e sem filtragem - so o
% sinal bruto, cada canal no seu proprio subplot.
%
% Uso: plot_amostra_canais('Dados_Ensaios/pasta/arquivo.csv')

    if nargin < 1 || isempty(arquivo)
        arquivo = 'Dados_Ensaios/210W_3500RPM_R1000/7Bracos_R1000_210W_2026-09-17_14_50.csv';
    end

    rotulos = {'Coluna 1', 'Coluna 2', 'Coluna 3', 'Coluna 4', 'Coluna 5', 'Coluna 6'};
    unidades = {'V', 'V', 'V', 'A', 'A', 'A'};

    dados = le_csv(arquivo);
    x = 0:(size(dados, 1) - 1);

    figure('Name', arquivo, 'NumberTitle', 'off', 'Position', [50 50 1400 1000]);

    for c = 1:6
        subplot(6, 1, c);
        plot(x, dados(:, c));
        grid on;
        xlim([0 size(dados, 1) - 1]);
        ylabel(sprintf('%s (%s)', rotulos{c}, unidades{c}));
        title(rotulos{c});
    end

    xlabel('Amostra');
    sgtitle(arquivo, 'Interpreter', 'none');
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
