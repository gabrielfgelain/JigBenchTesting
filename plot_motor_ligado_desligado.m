function plot_motor_ligado_desligado()
% Compara os 4 ensaios da pasta MotorDesligado (1 com motor ligado, 3
% com motor desligado), com foco nos picos: coluna 1 (saida do
% conversor) e coluna 5 (corrente do barramento CC). As 4 subplots de
% cada figura compartilham o mesmo eixo Y para comparar os picos
% diretamente.

    arquivos = {
        'Dados_Ensaios/MotorDesligado/MotorLigado',         'Motor ligado';
        'Dados_Ensaios/MotorDesligado/Motor_Desligado.csv', 'Motor desligado 1';
        'Dados_Ensaios/MotorDesligado/Motor_Desligado2.csv','Motor desligado 2';
        'Dados_Ensaios/MotorDesligado/Motor_Desligado3.csv','Motor desligado 3'
    };

    plot_coluna(arquivos, 1, 'Saída do conversor (coluna 1)', 'Tensão (V)');
    plot_coluna(arquivos, 5, 'Corrente no barramento CC (coluna 5)', 'Corrente (A)');

    fprintf('--- Resumo dos picos (min/max) ---\n');
    for f = 1:size(arquivos, 1)
        v1 = le_coluna_csv(arquivos{f, 1}, 1);
        v5 = le_coluna_csv(arquivos{f, 1}, 5);
        fprintf('%s: coluna1 min=%.3f max=%.3f | coluna5 min=%.3f max=%.3f\n', ...
            arquivos{f, 2}, min(v1), max(v1), min(v5), max(v5));
    end
end

function plot_coluna(arquivos, indiceColuna, tituloGrafico, rotuloY)

    n = size(arquivos, 1);
    dados = cell(n, 1);
    for f = 1:n
        dados{f} = le_coluna_csv(arquivos{f, 1}, indiceColuna);
    end

    limiteY = [min(cellfun(@min, dados)), max(cellfun(@max, dados))];
    folga = 0.05 * diff(limiteY);
    limiteY = limiteY + [-folga, folga];

    figure('Name', tituloGrafico, 'NumberTitle', 'off', 'Position', [50 50 1400 900]);

    for f = 1:n
        v = dados{f};
        x = 0:(numel(v) - 1);

        subplot(n, 1, f);
        plot(x, v, 'LineWidth', 1);
        grid on;
        xlim([0 numel(v) - 1]);
        ylim(limiteY);
        ylabel(rotuloY, 'FontSize', 12);
        title(arquivos{f, 2}, 'FontSize', 14);
        set(gca, 'FontSize', 11);
    end

    xlabel('Amostra', 'FontSize', 12);
    sgtitle(tituloGrafico, 'FontSize', 18);
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
