function plot_logs_ensaio(horaInicio, pasta)
% Plota os logs de sessao da pasta Logs/ gravados a partir de um instante
% (padrao: 2026-09-18 15:26). Cada sessao gera 3 arquivos com o mesmo
% prefixo AAAAMMDD_HHMMSS (hora de inicio da gravacao):
%
%   *_meas_medsETMI__b.txt  sem cabecalho, ~10 linhas por segundo (log do
%                           PID de potencia): t, PV [W], SP [W], MV
%   *_meas_medsFreio__b.txt cabecalho: t, IF, IR, VF, VR, VelSP, VelRE
%   *_meas_medsWatt__b.txt  cabecalho: t, PL(A), PL(B), PL(T), PL(E), V(A),
%                           V(B), V(E), I(A), I(B), I(E) e, nas sessoes de
%                           2026-09-21 em diante, n_bracos (0-7) e n_res
%                           (resistores, 4 digitos binarios: 1011 = R1011)
%
% Separador tab, decimais com virgula. PV = potencia medida (igual ao PL(T)
% do wattimetro), SP = setpoint, MV = saida do PID (acompanha o IF do freio,
% em A).
%
% Gera, por sessao, tres figuras: controle de potencia + freio, ETMI (PV, SP,
% erro e MV) e wattimetro. Se o log tem n_bracos/n_res, gera tambem a
% configuracao ao longo do tempo e o regime permanente por configuracao.
% Sessoes com menos de 60 amostras (partidas abortadas) sao ignoradas.
%
% Uso: plot_logs_ensaio                          % de 2026-09-21 13:30 em diante
%      plot_logs_ensaio('2026-09-18 15:26', 'Logs')

    if nargin < 1 || isempty(horaInicio)
        horaInicio = '2026-09-21 13:30';
    end
    if nargin < 2 || isempty(pasta)
        pasta = 'Logs';
    end

    limite = datetime(horaInicio, 'InputFormat', 'yyyy-MM-dd HH:mm');

    arquivos = dir(fullfile(pasta, '*_meas_medsETMI__b.txt'));
    plotou = false;
    for k = 1:numel(arquivos)
        prefixo = arquivos(k).name(1:15);
        inicio = datetime(prefixo, 'InputFormat', 'yyyyMMdd_HHmmss');
        if inicio < limite
            continue;
        end
        plota_sessao(pasta, prefixo, inicio);
        plotou = true;
    end

    if ~plotou
        warning('Nenhuma sessao em "%s" a partir de %s.', pasta, horaInicio);
    end
end

function plota_sessao(pasta, prefixo, inicio)
    etmi = le_log(fullfile(pasta, [prefixo '_meas_medsETMI__b.txt']), 0);
    freio = le_log(fullfile(pasta, [prefixo '_meas_medsFreio__b.txt']), 1);
    watt = le_log(fullfile(pasta, [prefixo '_meas_medsWatt__b.txt']), 1);

    if size(watt, 1) < 60
        return;
    end

    % ETMI: os primeiros ~9 pontos trazem um valor residual (5,58) na MV, que
    % nao e da sessao - descartado.
    etmi(etmi(:, 1) < 1, 4) = NaN;

    % Eixo x em horario de relogio (t = 0 na hora de criacao do arquivo).
    xEtmi = inicio + seconds(etmi(:, 1));
    xFreio = inicio + seconds(freio(:, 1));
    xWatt = inicio + seconds(watt(:, 1));

    titulo = sprintf('Sessao %s', prefixo);

    % --- Figura 1: controle de potencia e freio ---
    figure('Name', [prefixo ' - controle e freio'], 'NumberTitle', 'off', ...
        'Position', [50 50 1200 900]);

    ax(1) = subplot(4, 1, 1);
    plot(xEtmi, etmi(:, 3), '-', 'LineWidth', 1.5);
    hold on;
    plot(xWatt, watt(:, 4), '-');
    grid on;
    ylabel('Potência (W)');
    title('Controle de potência');
    legend({'Setpoint (ETMI)', 'Medida PL(T) (wattímetro)'}, 'Location', 'eastoutside');

    ax(2) = subplot(4, 1, 2);
    plot(xEtmi, etmi(:, 4), '-', xFreio, freio(:, 2), '-', ...
        xFreio, freio(:, 3), '-');
    grid on;
    ylabel('Corrente (A)');
    title('Corrente do freio');
    legend({'MV (ETMI)', 'IF', 'IR'}, 'Location', 'eastoutside');

    ax(3) = subplot(4, 1, 3);
    plot(xFreio, freio(:, 4), '-');
    grid on;
    ylabel('Tensão (V)');
    title('Tensão do freio - VF');
    legend({'VF'}, 'Location', 'eastoutside');

    ax(4) = subplot(4, 1, 4);
    plot(xFreio, freio(:, 6), '-', xFreio, freio(:, 7), '-');
    grid on;
    ylabel('Velocidade (RPM)');
    title('Velocidade do motor');
    legend({'VelSP', 'VelRE'}, 'Location', 'eastoutside');

    linkaxes(ax, 'x');
    xlim(ax(1), [inicio, xFreio(end)]);
    sgtitle(titulo, 'Interpreter', 'none');

    % --- Figura 2: log do PID (ETMI) ---
    figure('Name', [prefixo ' - ETMI'], 'NumberTitle', 'off', ...
        'Position', [65 65 1200 800]);

    axE(1) = subplot(3, 1, 1);
    plot(xEtmi, etmi(:, 3), '-', xEtmi, etmi(:, 2), '-');
    grid on;
    ylabel('Potência (W)');
    title('PV e SP');
    legend({'SP', 'PV'}, 'Location', 'eastoutside');

    axE(2) = subplot(3, 1, 2);
    plot(xEtmi, etmi(:, 3) - etmi(:, 2), '-');
    grid on;
    ylabel('Erro (W)');
    title('Erro (SP - PV)');
    legend({'SP - PV'}, 'Location', 'eastoutside');

    axE(3) = subplot(3, 1, 3);
    plot(xEtmi, etmi(:, 4), '-');
    grid on;
    ylabel('MV (A)');
    title('MV - saída do PID');
    legend({'MV'}, 'Location', 'eastoutside');

    linkaxes(axE, 'x');
    xlim(axE(1), [inicio, xEtmi(end)]);
    sgtitle(titulo, 'Interpreter', 'none');

    % --- Figura 3: wattimetro ---
    figure('Name', [prefixo ' - wattimetro'], 'NumberTitle', 'off', ...
        'Position', [80 80 1200 800]);

    ax2(1) = subplot(3, 1, 1);
    plot(xWatt, watt(:, 2), '-', xWatt, watt(:, 3), '-', xWatt, watt(:, 4), '-');
    grid on;
    ylabel('Potência (W)');
    title('Potência');
    legend({'PL(A)', 'PL(B)', 'PL(T)'}, 'Location', 'eastoutside');

    ax2(2) = subplot(3, 1, 2);
    plot(xWatt, watt(:, 6), '-', xWatt, watt(:, 7), '-');
    grid on;
    ylabel('Tensão (V)');
    title('Tensão');
    legend({'V(A)', 'V(B)'}, 'Location', 'eastoutside');

    ax2(3) = subplot(3, 1, 3);
    plot(xWatt, watt(:, 9), '-', xWatt, watt(:, 10), '-');
    grid on;
    ylabel('Corrente (A)');
    title('Corrente');
    legend({'I(A)', 'I(B)'}, 'Location', 'eastoutside');

    % O pico de corrente na partida do motor esmaga a escala; corta em
    % 1,3x o percentil 99 e informa o valor do pico no titulo.
    correntes = watt(:, 9:10);
    ordenado = sort(correntes(~isnan(correntes)));
    limiteI = 1.3 * ordenado(round(0.99 * numel(ordenado)));
    ylim(ax2(3), [0 limiteI]);
    title(ax2(3), sprintf('Corrente (pico de partida de %.1f A fora da escala)', ...
        max(correntes(:))));

    linkaxes(ax2, 'x');
    xlim(ax2(1), [inicio, xWatt(end)]);
    sgtitle(titulo, 'Interpreter', 'none');

    if size(watt, 2) >= 13
        plota_configuracao(titulo, prefixo, inicio, etmi, freio, watt);
    end
end

function plota_configuracao(titulo, prefixo, inicio, etmi, freio, watt)
% Figuras que dependem de n_bracos e n_res (colunas 12 e 13 do wattimetro).

    xEtmi = inicio + seconds(etmi(:, 1));
    xWatt = inicio + seconds(watt(:, 1));
    nBracos = watt(:, 12);
    codRes = decodifica_res(watt(:, 13));

    % --- Figura 4: configuracao ao longo do tempo ---
    figure('Name', [prefixo ' - configuracao'], 'NumberTitle', 'off', ...
        'Position', [95 95 1200 800]);

    axC(1) = subplot(4, 1, 1);
    plot(xEtmi, etmi(:, 3), '-', xEtmi, etmi(:, 2), '-');
    grid on;
    ylabel('Potência (W)');
    title('PV e SP');
    legend({'SP', 'PV'}, 'Location', 'eastoutside');

    axC(2) = subplot(4, 1, 2);
    stairs(xWatt, nBracos);
    grid on;
    ylabel('Braços ativos');
    ylim([-0.5 7.5]);
    yticks(0:7);
    title('Braços de capacitores ativos');
    legend({'n\_bracos'}, 'Location', 'eastoutside');

    axC(3) = subplot(4, 1, 3);
    stairs(xWatt, codRes);
    grid on;
    ylabel('Resistores');
    codigos = unique(codRes);
    yticks(codigos);
    yticklabels(strcat('R', cellstr(dec2bin(codigos, 4))));
    ylim([min(codigos) - 0.5, max(codigos) + 0.5]);
    title('Braços de resistores');
    legend({'n\_res'}, 'Location', 'eastoutside');

    axC(4) = subplot(4, 1, 4);
    plot(xWatt, freio(1:size(watt, 1), 4), '-');
    grid on;
    ylabel('Tensão (V)');
    title('Tensão do freio - VF (sobe com o aquecimento)');
    legend({'VF'}, 'Location', 'eastoutside');

    linkaxes(axC, 'x');
    xlim(axC(1), [inicio, xWatt(end)]);
    sgtitle(titulo, 'Interpreter', 'none');

    % --- Figura 5: regime permanente por configuracao ---
    ss = regime_permanente(watt, freio);
    codigos = unique(ss.res);
    cores = turbo(numel(codigos));

    figure('Name', [prefixo ' - regime permanente'], 'NumberTitle', 'off', ...
        'Position', [110 110 1200 800]);

    variaveis = {ss.P, ss.V, ss.I, ss.VF};
    rotulos = {'PL(T) (W)', 'V médio (V)', 'I médio (A)', 'VF (V)'};
    for v = 1:4
        subplot(2, 2, v);
        hold on;
        for c = 1:numel(codigos)
            m = ss.res == codigos(c);
            plot(ss.bracos(m), variaveis{v}(m), '-o', 'Color', cores(c, :), ...
                'MarkerSize', 4);
        end
        grid on;
        xlabel('Braços ativos');
        ylabel(rotulos{v});
        xticks(0:7);
        if v == 1
            legend(strcat('R', cellstr(dec2bin(codigos, 4))), ...
                'Location', 'northoutside', 'NumColumns', 5);
        end
    end
    sgtitle([titulo ' - média de cada bloco, na ordem em que foram executados'], ...
        'Interpreter', 'none');
end

function ss = regime_permanente(watt, freio)
% Media de cada bloco de (n_bracos, n_res) constantes. Descarta os 6 s
% iniciais do bloco (transiente da troca), as amostras fora de 75-85 W
% (rampa de desligamento) e as que se afastam mais de 1,5 W da mediana do
% bloco (subida da potencia ate o setpoint). Blocos com menos de 8 amostras
% validas sao ignorados. Watt e Freio tem o mesmo t, linha a linha.

    n = size(watt, 1);
    t = watt(:, 1);
    nBracos = watt(:, 12);
    codRes = decodifica_res(watt(:, 13));
    bloco = [1; cumsum(diff(nBracos) ~= 0 | diff(codRes) ~= 0) + 1];

    ss = struct('bracos', [], 'res', [], 'P', [], 'V', [], 'I', [], 'VF', []);
    for k = 1:max(bloco)
        idx = find(bloco == k);
        valido = idx(t(idx) > t(idx(1)) + 6 & watt(idx, 4) > 75 & watt(idx, 4) < 85);
        valido = valido(abs(watt(valido, 4) - median(watt(valido, 4))) < 1.5);
        if numel(valido) < 8
            continue;
        end
        ss.bracos(end + 1, 1) = nBracos(idx(1));
        ss.res(end + 1, 1) = codRes(idx(1));
        ss.P(end + 1, 1) = mean(watt(valido, 4));
        ss.V(end + 1, 1) = mean(mean(watt(valido, 6:7), 2));
        ss.I(end + 1, 1) = mean(mean(watt(valido, 9:10), 2));
        ss.VF(end + 1, 1) = mean(freio(valido(valido <= size(freio, 1)), 4));
    end
end

function cod = decodifica_res(nRes)
% n_res vem como 4 digitos decimais que sao bits (1011 -> 11, R1011).

    cod = floor(nRes / 1000) * 8 + floor(mod(nRes, 1000) / 100) * 4 ...
        + floor(mod(nRes, 100) / 10) * 2 + mod(nRes, 10);
end

function dados = le_log(arquivo, linhasCabecalho)
% Le um log: separador tab, decimais com virgula. Linhas com menos colunas
% que o cabecalho (a primeira do Freio) sao completadas com NaN.

    dados = readmatrix(arquivo, 'FileType', 'text', 'Delimiter', '\t', ...
        'DecimalSeparator', ',', 'NumHeaderLines', linhasCabecalho);
end
