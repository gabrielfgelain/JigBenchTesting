function analisa_psd_bracos()
% Extrai a amplitude espectral do ripple do barramento CC (coluna 2) nas
% harmonicas do ripple de 120 Hz do retificador monofasico (2 x 60 Hz da rede), para os 360 ensaios estruturados
% (80W/150W/210W x 15 configs de resistor x 8 bracos), e avalia:
%  1) correlacao de cada harmonica com C e R, separado por potencia;
%  2) o quanto cada harmonica muda de nivel entre as 3 potencias (uma
%     harmonica "robusta a carga" deveria mudar pouco, como o artigo
%     descreve para PSD300 vs PSD60).

    Rarm.a1 = 0.11; Rarm.a2 = 0.58; Rarm.a3 = 0.345; Rarm.a4 = 0.45;
    capPorBracos = containers.Map([7 6 5 4 3 2 1 0], [1056 994 922 837 739 626 490 324]);

    codigos = {'0001','0010','0011','0100','0101','0110','0111', ...
               '1000','1001','1010','1011','1100','1101','1110','1111'};
    RarmCombo = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(codigos)
        c = codigos{i};
        G = 0;
        if c(1)=='1'; G = G + 1/Rarm.a1; end
        if c(2)=='1'; G = G + 1/Rarm.a2; end
        if c(3)=='1'; G = G + 1/Rarm.a3; end
        if c(4)=='1'; G = G + 1/Rarm.a4; end
        RarmCombo(c) = 1/G;
    end

    Fs = 1e6;          % Hz (1 MS/s no PZ4000: 100.000 amostras = janela de 0,1 s)
    fundamental = 120; % Hz, ripple do retificador monofasico (2 x 60 Hz)
    harmonicas = 1:8;  % 120, 240, ..., 960 Hz
    janelaBusca = 20;  % Hz, tolerancia pra achar o pico perto da harmonica esperada

    potencias = {'80W','150W','210W'};

    Tabela = table();
    for p = 1:numel(potencias)
        pot = potencias{p};
        padraoPasta = sprintf('Dados_Ensaios/%s_3500RPM_R*', pot);
        pastas = dir(padraoPasta);
        pastas = pastas([pastas.isdir]);

        for k = 1:numel(pastas)
            nomePasta = pastas(k).name;
            tok = regexp(nomePasta, 'R(\d{4})$', 'tokens');
            if isempty(tok); continue; end
            codigo = tok{1}{1};
            if ~isKey(RarmCombo, codigo); continue; end
            rArmVal = RarmCombo(codigo);

            arquivos = dir(fullfile('Dados_Ensaios', nomePasta, '*.csv'));
            for f = 1:numel(arquivos)
                nomeArq = arquivos(f).name;
                tokB = regexp(nomeArq, '^(\d+)Bracos', 'tokens');
                if isempty(tokB); continue; end
                bracos = str2double(tokB{1}{1});
                if ~isKey(capPorBracos, bracos); continue; end

                C = capPorBracos(bracos);
                if bracos == 0
                    R = 0.2;
                else
                    soma = 0.51/bracos + rArmVal;
                    R = 0.1 + (0.1 * soma) / (0.1 + soma);
                end

                v2 = le_coluna_csv(fullfile('Dados_Ensaios', nomePasta, nomeArq), 2);
                v2ac = v2 - mean(v2);
                N = numel(v2ac);
                Y = fft(v2ac);
                P = abs(Y(1:floor(N/2))) / N * 2;
                fvec = (0:floor(N/2)-1) * Fs / N;

                psdVals = zeros(1, numel(harmonicas));
                for h = harmonicas
                    fAlvo = h * fundamental;
                    idx = fvec >= (fAlvo - janelaBusca) & fvec <= (fAlvo + janelaBusca);
                    psdVals(h) = max(P(idx));
                end

                linha = array2table([psdVals, C, R], 'VariableNames', ...
                    [arrayfun(@(h) sprintf('PSD_h%d', h), harmonicas, 'UniformOutput', false), {'C_uF','R_ohm'}]);
                linha.potencia = string(pot);
                Tabela = [Tabela; linha]; %#ok<AGROW>
            end
        end
        fprintf('%s processado.\n', pot);
    end

    writetable(Tabela, 'tabela_psd_harmonicas.csv', 'Delimiter', ';');

    % ---- avaliacao: correlacao por potencia + estabilidade entre potencias ----
    fprintf('\n%6s', 'Harm.');
    for p = 1:numel(potencias); fprintf(' | corrC_%s corrR_%s', potencias{p}, potencias{p}); end
    fprintf(' | Amp80W Amp150W Amp210W razao(210/80)\n');

    for h = harmonicas
        col = sprintf('PSD_h%d', h);
        fprintf('%4dHz', h*fundamental);
        amps = zeros(1,3);
        for p = 1:numel(potencias)
            sub = Tabela(Tabela.potencia == potencias{p}, :);
            cC = corr(sub.(col), sub.C_uF);
            cR = corr(sub.(col), sub.R_ohm);
            amps(p) = mean(sub.(col));
            fprintf(' | %6.2f %6.2f', cC, cR);
        end
        fprintf(' | %6.3f %6.3f %6.3f %6.2f\n', amps(1), amps(2), amps(3), amps(3)/amps(1));
    end
end

function coluna = le_coluna_csv(arquivo, indiceColuna)
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
