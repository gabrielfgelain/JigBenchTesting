%% Decomposicao da corrente do motor: fundamental x portadora PWM
% -------------------------------------------------------------------
% Le um arquivo CSV exportado do PZ4000 (';' como separador de coluna,
% ',' como separador decimal), isola por FFT duas faixas de frequencia
% diferentes do sinal de corrente:
%
%   1) a componente FUNDAMENTAL  -> frequencia de rotacao do motor
%   2) a componente PORTADORA    -> ruido/ripple do chaveamento PWM do inversor
%
% e plota as duas separadas e depois a SOMA das duas, sobreposta ao
% sinal original, pra mostrar que elas se recompoem no sinal medido.
%
% IMPORTANTE sobre as janelas de visualizacao: a fundamental oscila MUITO
% mais devagar que a portadora (periodo de ~8300 amostras contra ~200
% amostras da portadora). Por isso usamos DUAS janelas diferentes:
%   - janela_zoom  (curta)  -> pra ver o detalhe/picos da portadora e do sinal original
%   - janela_longa (longa)  -> pra ver pelo menos 1-2 ciclos completos da fundamental
% Se usar so uma janela curta pra tudo, a fundamental aparece como uma
% "reta" (voce so ve uma fatia pequena de um ciclo bem mais longo).
%
% As faixas de bin default abaixo (bin_fund = [8 16], bin_carr = [480 520])
% sao as mesmas usadas na analise em Python feita antes - validadas nos
% dados reais do ensaio (fundamental em ~bin 12, portadora com bandas
% laterais em ~bin 487/511). Com 100.000 amostras a 1 MS/s (janela de
% 0,1 s), cada bin vale 10 Hz: fundamental ~116 Hz, portadora ~5 kHz.
% Ajuste se usar um arquivo com outro numero de amostras.
% -------------------------------------------------------------------

clear; clc; close all;

%% ===================== CONFIGURACAO =====================
arquivo      = 'Dados_Ensaios/MotorDesligado/teste.csv';   % caminho do arquivo CSV exportado do PZ4000
coluna       = 4;             % qual coluna usar (ex.: 4 ou 5 = corrente de fase)
bin_fund     = [8, 16];       % faixa de "bin" da FFT (indexacao 0-based, igual Python) p/ fundamental
bin_carr     = [480, 520];    % faixa de "bin" da FFT (indexacao 0-based, igual Python) p/ portadora
janela_zoom  = 1:1500;        % janela CURTA - pra ver detalhe/picos (portadora + sinal original)
janela_longa = 1:20000;       % janela LONGA - pra ver a oscilacao completa da fundamental (>1 ciclo)
%% ==========================================================

%% Leitura dos dados
% readmatrix ja trata separador ';' e decimal ',' diretamente:
dados = readmatrix(arquivo, 'Delimiter', ';', 'DecimalSeparator', ',');

x = dados(:, coluna);
x = x - mean(x);          % remove nivel DC (offset)
N = length(x);

%% FFT do sinal completo
X = fft(x);

%% Funcao auxiliar: monta a mascara de filtro (isola uma faixa de bin,
%  incluindo o espelho de frequencia negativa, necessario p/ sinal real)
mascara = @(bin_lo, bin_hi) local_build_mask(N, bin_lo, bin_hi);

%% Isola a componente FUNDAMENTAL (baixa frequencia = rotacao do motor)
X_fund = X .* mascara(bin_fund(1), bin_fund(2));
x_fund = real(ifft(X_fund));

%% Isola a componente PORTADORA (alta frequencia = chaveamento PWM)
X_carr = X .* mascara(bin_carr(1), bin_carr(2));
x_carr = real(ifft(X_carr));

%% Soma das duas componentes (reconstrucao parcial do sinal)
x_soma = x_fund + x_carr;

%% RMS de cada componente, para contexto numerico (mesma logica da analise em Python)
rms_total = sqrt(mean(x.^2));
rms_fund  = sqrt(mean(x_fund.^2));
rms_carr  = sqrt(mean(x_carr.^2));
fprintf('RMS sinal original         : %.4f A\n', rms_total);
fprintf('RMS componente fundamental : %.4f A\n', rms_fund);
fprintf('RMS componente portadora   : %.4f A\n', rms_carr);
fprintf('Periodo aprox. fundamental : %.0f amostras (%d amostras/registro / bin ~%d)\n', ...
    N/mean(bin_fund), N, round(mean(bin_fund)));
fprintf('Periodo aprox. portadora   : %.0f amostras\n', N/mean(bin_carr));

%% ===================== FIGURA 1: ZOOM (detalhe rapido) =====================
% janela curta - mostra o sinal original com seus picos, e a portadora
% oscilando varias vezes dentro dessa janela.
figure('Color', 'w', 'Position', [100 100 900 600], 'Name', 'Zoom (detalhe)');

subplot(2,1,1);
plot(janela_zoom, x(janela_zoom), 'k');
title(sprintf('Sinal original (janela curta = %d amostras, mostra os picos)', numel(janela_zoom)));
ylabel('A'); grid on;

subplot(2,1,2);
plot(janela_zoom, x_carr(janela_zoom), 'r');
title(sprintf('Componente de alta frequencia (portadora PWM) - RMS = %.3f A', rms_carr));
xlabel('Amostra'); ylabel('A'); grid on;

sgtitle('Vista de perto: sinal original x portadora (chaveamento)');

%% ===================== FIGURA 2: VISAO LONGA (fundamental) =====================
% janela longa - necessaria pra ver a fundamental completar pelo menos
% um ciclo (ela oscila bem mais devagar que a portadora).
figure('Color', 'w', 'Position', [1050 100 900 700], 'Name', 'Visao longa (fundamental)');

subplot(3,1,1);
plot(janela_longa, x(janela_longa), 'k');
title(sprintf('Sinal original (janela longa = %d amostras)', numel(janela_longa)));
ylabel('A'); grid on;

subplot(3,1,2);
plot(janela_longa, x_fund(janela_longa), 'b', 'LineWidth', 1.2);
title(sprintf('Componente fundamental (rotacao do motor) - RMS = %.3f A', rms_fund));
ylabel('A'); grid on;

subplot(3,1,3);
plot(janela_longa, x(janela_longa), 'Color', [0.6 0.6 0.6]); hold on;
plot(janela_longa, x_soma(janela_longa), 'g', 'LineWidth', 1.3);
legend('Sinal original', 'Fundamental + Portadora (soma)', 'Location', 'best');
title('Sobreposicao: sinal original x soma das duas componentes');
xlabel('Amostra'); ylabel('A'); grid on;

sgtitle('Vista longa: agora da pra ver a fundamental oscilando de verdade');

%% Bonus: espectro de frequencia (mostra onde cada faixa foi recortada)
figure('Color', 'w', 'Position', [100 750 700 400], 'Name', 'Espectro');
mag = abs(X(1:2000)); % so os primeiros bins (onde estao fundamental e portadora)
plot(0:1999, mag, 'k'); hold on;
xline(bin_fund, 'b--', 'LineWidth', 1.2);
xline(bin_carr, 'r--', 'LineWidth', 1.2);
xlabel('Numero do bin (ciclos por registro)'); ylabel('|X(f)|');
title('Espectro de frequencia - faixas usadas na decomposicao (azul=fundamental, vermelho=portadora)');
grid on;

%% -------------------------------------------------------------------
function mask = local_build_mask(N, bin_lo, bin_hi)
    % Constroi uma mascara de filtro em frequencia isolando os bins
    % [bin_lo, bin_hi] (indexacao 0-based, igual Python/rfft) e seu
    % espelho de frequencia negativa, necessario p/ o ifft de um sinal
    % real dar resultado real.
    mask = zeros(N, 1);
    idx_pos = (bin_lo:bin_hi) + 1;                 % converte 0-based -> indice MATLAB (1-based)
    idx_neg = N - (bin_hi:-1:bin_lo) + 1;           % espelho de frequencia negativa
    mask(idx_pos) = 1;
    mask(idx_neg) = 1;
end