function plot_teste_motordesligado()
% Plota o Dados_Ensaios/MotorDesligado/teste.csv: tensao no motor
% (coluna 1) e as duas candidatas a corrente no motor (colunas 4 e 5),
% sem filtragem - o range de corrente parece ter sido reconfigurado
% nesse ensaio (sem mais saturacao fixa em ~387A), entao o sinal bruto
% ja e legivel.

    arquivo = 'Dados_Ensaios/MotorDesligado/teste.csv';

    dados = le_csv(arquivo);
    x = 0:(size(dados, 1) - 1);

    janelaRms = 500; % amostras (0,5 ms a 1 MS/s) para o RMS movel
    rms4 = sqrt(movmean(dados(:, 4).^2, janelaRms));
    rms5 = sqrt(movmean(dados(:, 5).^2, janelaRms));

    % versao filtrada (~5 kHz de corte) - RMS bate bem melhor com o
    % wattimetro (banda limitada) do que o sinal bruto do PZ4000
    janelaFiltro = 200; % amostras (~5 kHz de corte a 1 MS/s)
    col4Filt = movmean(dados(:, 4), janelaFiltro);
    col5Filt = movmean(dados(:, 5), janelaFiltro);
    rms4Filt = sqrt(movmean(col4Filt.^2, janelaRms));
    rms5Filt = sqrt(movmean(col5Filt.^2, janelaRms));

    figure('Name', 'teste.csv (MotorDesligado)', 'NumberTitle', 'off', ...
        'Position', [50 50 1400 1300]);

    subplot(5, 1, 1);
    plot(x, dados(:, 1), 'LineWidth', 1);
    grid on;
    xlim([0 size(dados, 1) - 1]);
    ylabel('Tensão (V)');
    title('Coluna 1 - tensão no motor');

    subplot(5, 1, 2);
    plot(x, dados(:, 4), 'LineWidth', 1);
    grid on;
    xlim([0 size(dados, 1) - 1]);
    ylabel('Corrente (A)');
    title('Coluna 4 - corrente no motor (fase A?)');

    subplot(5, 1, 3);
    plot(x, dados(:, 5), 'LineWidth', 1);
    grid on;
    xlim([0 size(dados, 1) - 1]);
    ylabel('Corrente (A)');
    title('Coluna 5 - corrente no motor (fase B?)');

    subplot(5, 1, 4);
    plot(x, rms4, x, rms5, 'LineWidth', 1.5);
    grid on;
    xlim([0 size(dados, 1) - 1]);
    ylabel('RMS (A)');
    title(sprintf('RMS móvel (janela de %d amostras) - sinal bruto', janelaRms));
    legend({'Coluna 4', 'Coluna 5'}, 'Location', 'best');

    subplot(5, 1, 5);
    plot(x, rms4Filt, x, rms5Filt, 'LineWidth', 1.5);
    grid on;
    xlim([0 size(dados, 1) - 1]);
    ylabel('RMS (A)');
    title(sprintf('RMS móvel - sinal filtrado (~%.0f Hz de corte, bate melhor com o wattímetro)', 1e6 / janelaFiltro));
    legend({'Coluna 4', 'Coluna 5'}, 'Location', 'best');

    xlabel('Amostra');
    sgtitle('teste.csv (MotorDesligado)', 'Interpreter', 'none');
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
