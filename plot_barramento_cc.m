function plot_barramento_cc()
% Plota a tensao e a corrente do barramento CC (canal "Plot 1") em dois
% subplots (tensao em cima, corrente embaixo).

    arqTensao   = 'Ensaio_PZ4000_Tensao_ComJiga_SemCarga.txt';
    arqCorrente = 'Ensaio_PZ4000_Corrente_ComJiga_SemCarga.txt';

    tensao   = le_amplitude_plot1(arqTensao);
    corrente = le_amplitude_plot1(arqCorrente);

    x = 0:(numel(tensao) - 1);

    figure('Name', 'Barramento CC', 'NumberTitle', 'off');

    subplot(2, 1, 1);
    plot(x, tensao);
    grid on;
    xlim([0 100000]);
    xlabel('Amostra');
    ylabel('Tensão (V)');
    title('Tensão');

    subplot(2, 1, 2);
    plot(x, corrente);
    grid on;
    xlim([0 100000]);
    xlabel('Amostra');
    ylabel('Corrente (A)');
    title('Corrente');

    sgtitle('Tensão e Corrente no barramento CC');
end

function amplitude = le_amplitude_plot1(nomeArquivo)
% Le o arquivo (separador tab, decimais com virgula) e retorna a coluna
% de amplitude do canal "Plot 1".

    texto = fileread(nomeArquivo);
    texto = strrep(texto, ',', '.');

    arqTemp = [tempname(), '.txt'];
    fid = fopen(arqTemp, 'w');
    fwrite(fid, texto);
    fclose(fid);

    dados = readmatrix(arqTemp, 'NumHeaderLines', 1, 'Delimiter', '\t');
    delete(arqTemp);

    % Colunas: 1=Time0, 2=Amp0, 3=Time1, 4=Amp1, 5=Time2, 6=Amp2
    amplitude = dados(:, 4);
end
