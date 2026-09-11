function plot_teste()
% Plota as colunas 1 e 2 do teste.csv (com carga, um unico ensaio, nao
% concatenado com outros). Na coluna 2 (barramento CC), sobrepoe a
% referencia sem carga (RSE, 7 bracos) para comparacao.

    arquivo = 'teste.csv';
    arquivoRef = 'Dados_Ensaios/SemCarga_3000RPM_1MOSFET/Ensaio_7bracos_RSE_SemCarga_2026-08-26_13-30.csv';

    dados = le_csv(arquivo);
    x = 0:(size(dados, 1) - 1);

    barramentoRef = le_csv(arquivoRef);
    barramentoRef = barramentoRef(:, 2);
     % filtro leve, so pra visualizacao
    xRef = 0:(numel(barramentoRef) - 1);

    figure('Name', 'teste.csv', 'NumberTitle', 'off', 'Position', [50 50 1400 700]);

    subplot(2, 1, 1);
    plot(x, dados(:, 1), 'LineWidth', 1);
    grid on;
    xlim([0 size(dados, 1) - 1]);
    ylabel('Coluna 1 (V)', 'FontSize', 11);
    title('Coluna 1', 'FontSize', 13);
    set(gca, 'FontSize', 10);

    subplot(2, 1, 2);
    hCarga = plot(x, dados(:, 2), 'LineWidth', 1);
    hold on;
    hRef = plot(xRef, barramentoRef, 'LineWidth', 1);
    hold off;
    grid on;
    xlim([0 size(dados, 1) - 1]);
    ylabel('Coluna 2 (V)', 'FontSize', 11);
    title('Coluna 2 (barramento CC) - com carga vs. sem carga (RSE, 7 braços)', 'FontSize', 13);
    legend([hCarga, hRef], {'teste.csv (com carga)', 'referência (sem carga, 7 braços)'}, ...
        'Location', 'best', 'FontSize', 10);
    set(gca, 'FontSize', 10);

    xlabel('Amostra', 'FontSize', 12);
    sgtitle('teste.csv - colunas 1 e 2', 'FontSize', 18);
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
