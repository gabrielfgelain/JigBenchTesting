function T = extrai_features_ensaios()
% Extrai, de todos os ensaios estruturados (Dados_Ensaios/<P>_<RPM>RPM_R<cod>),
% uma tabela com features no tempo e na frequencia, junto com os rotulos
% (rotacao, potencia, configuracao, C e R). Salva em tabela_features_ensaios.csv
% para as analises nao precisarem reler os ~1100 CSVs.
%
% Canais (PZ4000, 3 elementos): elemento 1 = col1 (tensao de saida do
% inversor) x col4 (corrente de saida); elemento 2 = col2 (barramento CC) x
% col5 (corrente de saida de outra fase, ver README).
%
% Features no tempo:
%   Vdc_mean, Vdc_std, Vdc_p2p   tensao do barramento
%   Vout_rms                     tensao de saida (col1)
%   Iout_rms                     media do rms de col4 e col5 filtradas (~5 kHz)
%   Pout                         potencia ativa do elemento 1, mean(col1.*col4)
% Features na frequencia (amplitude de pico de cada componente, janela de 0,1 s):
%   Vdc_A120..Vdc_A480           ripple do retificador (2 x 60 Hz e harmonicas)
%   Vdc_Afe, Vdc_A2fe, Vdc_A6fe  ripple ligado ao motor (f_e = RPM/30)
%   Vdc_A5k                      componente em ~5 kHz
%   Vdc_rippleLF                 rms do ripple ate 1 kHz
%   Iout_Afe                     fundamental da corrente de saida

    Fs = 1e6;
    janelaFiltro = 200;

    Rarm.a1 = 0.11; Rarm.a2 = 0.58; Rarm.a3 = 0.345; Rarm.a4 = 0.45;
    capPorBracos = containers.Map([7 6 5 4 3 2 1 0], [1056 994 922 837 739 626 490 324]);

    pastas = dir('Dados_Ensaios/*W_*RPM_R*');
    pastas = pastas([pastas.isdir]);

    linhas = {};
    for k = 1:numel(pastas)
        tok = regexp(pastas(k).name, '^(\d+)W_(\d+)RPM_R(\d{4})$', 'tokens');
        if isempty(tok); continue; end
        pot = str2double(tok{1}{1});
        rpm = str2double(tok{1}{2});
        codigo = tok{1}{3};
        rArmVal = r_combo(codigo, Rarm);
        fe = rpm / 30;

        arquivos = dir(fullfile('Dados_Ensaios', pastas(k).name, '*.csv'));
        for f = 1:numel(arquivos)
            nomeArq = arquivos(f).name;
            tokB = regexp(nomeArq, '^(\d+)Bracos(?:_\d+)?_R(\d{4})_\d+W_(\d{4}-\d{2}-\d{2})', 'tokens');
            if isempty(tokB) || ~strcmp(tokB{1}{2}, codigo); continue; end
            bracos = str2double(tokB{1}{1});
            if ~isKey(capPorBracos, bracos); continue; end

            C = capPorBracos(bracos);
            if bracos == 0
                R = 0.2;
            else
                soma = 0.51/bracos + rArmVal;
                R = 0.1 + (0.1 * soma) / (0.1 + soma);
            end

            d = le_csv(fullfile('Dados_Ensaios', pastas(k).name, nomeArq));
            if size(d, 2) < 5; continue; end
            d = d(1:end-mod(size(d,1),2), :); % N par: bins exatos de 10 Hz

            v1 = d(:,1); v2 = d(:,2);
            i4f = movmean(d(:,4), janelaFiltro);
            i5f = movmean(d(:,5), janelaFiltro);

            [A, fvec] = espectro(v2 - mean(v2), Fs);
            Ai = (espectro(i4f - mean(i4f), Fs) + espectro(i5f - mean(i5f), Fs)) / 2;

            lf = fvec > 0 & fvec <= 1000;
            feats = [mean(v2), std(v2), max(v2) - min(v2), rms(v1), ...
                mean([rms(i4f), rms(i5f)]), mean(v1 .* d(:,4)), ...
                pico(A, fvec, 120, 10), pico(A, fvec, 240, 10), ...
                pico(A, fvec, 360, 10), pico(A, fvec, 480, 10), ...
                pico_motor(A, fvec, fe), pico_motor(A, fvec, 2*fe), pico_motor(A, fvec, 6*fe), ...
                pico(A, fvec, 5000, 50), sqrt(sum(A(lf).^2) / 2), pico(Ai, fvec, fe, 10)];

            linhas(end+1, :) = [{rpm, pot, codigo, bracos, C, R, tokB{1}{3}}, num2cell(feats)]; %#ok<AGROW>
        end
        fprintf('%s: %d arquivos\n', pastas(k).name, numel(arquivos));
    end

    nomes = {'RPM', 'P_W', 'codigo', 'bracos', 'C_uF', 'R_ohm', 'data', ...
        'Vdc_mean', 'Vdc_std', 'Vdc_p2p', 'Vout_rms', 'Iout_rms', 'Pout', ...
        'Vdc_A120', 'Vdc_A240', 'Vdc_A360', 'Vdc_A480', ...
        'Vdc_Afe', 'Vdc_A2fe', 'Vdc_A6fe', 'Vdc_A5k', 'Vdc_rippleLF', 'Iout_Afe'};
    T = cell2table(linhas, 'VariableNames', nomes);
    writetable(T, 'tabela_features_ensaios.csv', 'Delimiter', ';');
    fprintf('%d ensaios salvos em tabela_features_ensaios.csv\n', height(T));
end

function [A, fvec] = espectro(x, Fs)
% Amplitude de pico de cada componente (espectro unilateral, janela retangular).
    N = numel(x);
    X = fft(x);
    A = abs(X(1:N/2)) / N * 2;
    fvec = (0:N/2-1)' * Fs / N;
end

function v = pico(A, fvec, fAlvo, tol)
    v = max(A(abs(fvec - fAlvo) <= tol));
end

function v = pico_motor(A, fvec, fAlvo)
% Componente ligada ao motor. Com resolucao de 10 Hz, nao da para separar
% de uma harmonica de 120 Hz a menos de 15 Hz (ex.: f_e = 116,7 Hz em
% 3500 RPM): nesses casos devolve NaN em vez de medir o retificador.
    if abs(fAlvo - 120*round(fAlvo/120)) < 15
        v = NaN;
    else
        v = pico(A, fvec, fAlvo, 4);
    end
end

function R = r_combo(codigo, Rarm)
    G = 0;
    if codigo(1)=='1'; G = G + 1/Rarm.a1; end
    if codigo(2)=='1'; G = G + 1/Rarm.a2; end
    if codigo(3)=='1'; G = G + 1/Rarm.a3; end
    if codigo(4)=='1'; G = G + 1/Rarm.a4; end
    R = 1/G;
end

function dados = le_csv(arquivo)
% Le um CSV com separador ";" e decimais com virgula.
    texto = strrep(fileread(arquivo), ',', '.');
    dados = sscanf(texto, '%f;%f;%f;%f;%f;%f', [6 Inf])';
end
