function plot_ensaios_pz4000()
% Plota os ensaios do PZ4000 (Tensao e Corrente), um grafico por arquivo,
% cada um com 3 subplots (Plot 0, Plot 1, Plot 2) e eixo X de 0 a 100000.

    arquivos = {
        'Ensaio_PZ4000_Tensao_ComJiga_SemCarga.txt',   'Tensão (V)';
        'Ensaio_PZ4000_Corrente_ComJiga_SemCarga.txt', 'Corrente (A)'
    };

    for k = 1:size(arquivos, 1)
        nomeArquivo = arquivos{k, 1};
        rotuloY = arquivos{k, 2};

        amplitudes = le_ensaio(nomeArquivo);
        x = 0:(size(amplitudes, 1) - 1);

        figure('Name', nomeArquivo, 'NumberTitle', 'off');
        for p = 1:3
            subplot(3, 1, p);
            plot(x, amplitudes(:, p));
            grid on;
            xlim([0 100000]);
            title(sprintf('Plot %d', p - 1));
            xlabel('Amostra');
            ylabel(rotuloY);
        end
        sgtitle(strrep(nomeArquivo, '_', '\_'));
    end
end

function amplitudes = le_ensaio(nomeArquivo)
% Le o arquivo (separador tab, decimais com virgula) e retorna as 3
% colunas de amplitude (Amplitude - Plot 0/1/2).

    texto = fileread(nomeArquivo);
    texto = strrep(texto, ',', '.');

    arqTemp = [tempname(), '.txt'];
    fid = fopen(arqTemp, 'w');
    fwrite(fid, texto);
    fclose(fid);

    dados = readmatrix(arqTemp, 'NumHeaderLines', 1, 'Delimiter', '\t');
    delete(arqTemp);

    % Colunas: 1=Time0, 2=Amp0, 3=Time1, 4=Amp1, 5=Time2, 6=Amp2
    amplitudes = dados(:, [2 4 6]);
end
