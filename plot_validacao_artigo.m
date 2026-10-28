function plot_validacao_artigo()
% Figura da Secao III-A do artigo (ICIT 2027): ripple do barramento a 210 W e
% 2700 rpm, dois periodos de 120 Hz, filtrado com media movel de 0,1 ms so para
% visualizacao e alinhado pela fase da componente de 120 Hz.
%   (a) para cada capacitancia do barramento (n = 0..7 bracos, combinacao R1000);
%   (b) com 6 bracos, para cada combinacao do ensaio de ESR (Variando_RES),
%       identificada pela ESR nominal do capacitor emulado (jiga):
%       ESR = 0,51/n + 1/G, com G = soma das condutancias dos bracos de resistor ativos.
% Como os valores sao discretos, cada curva tem o seu valor na legenda (em vez de
% barra de cores). As duas usam a mesma escala vertical.
% Salva Figuras_Artigo/validacao.pdf (vetorial).

    Fs = 1e6;
    Rarm = [0.11 0.58 0.345 0.45]; % resistencia de cada braco de resistor (mosfet incluso)
    fonte = 'Times New Roman';

    fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 8.8 8.2]);
    tl = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

    % (a) capacitancia do barramento
    ax1 = nexttile(tl); hold(ax1, 'on');
    mapa1 = viridis(256);
    Cdc = [324 490 626 739 837 922 994 1056]; % capacitancia medida para n = 0..7 bracos (uF)
    faixaC = [300 1100];
    h1 = gobjects(8, 1);
    for n = 0:7
        arq = sprintf('Dados_Ensaios/210W_2700RPM_R1000/%dBracos_2700_R1000_210W_2026-10-09_10_40.csv', n);
        [t, r] = ripple(arq, Fs);
        h1(n+1) = plot(ax1, t, r, 'Color', cor_do_mapa(mapa1, (Cdc(n+1) - faixaC(1)) / diff(faixaC)), 'LineWidth', 0.8);
    end
    % legenda do maior para o menor valor, na mesma ordem vertical das curvas
    lg1 = legend(ax1, flipud(h1), compose(['%d ' char(181) 'F'], fliplr(Cdc)), 'Location', 'eastoutside');
    lg1.Title.String = '\itC\rm_{dc}';
    formata(ax1, lg1, fonte, '(a)');

    % (b) ESR do capacitor emulado, 6 bracos
    ax2 = nexttile(tl); hold(ax2, 'on');
    cods = {'1000', '0011', '0110', '0101', '0010'};
    esr = cellfun(@(c) 0.51/6 + 1/sum(1 ./ Rarm(c == '1')), cods);
    [esr, ordem] = sort(esr); cods = cods(ordem);
    mapa2 = plasma(256);
    faixa = [0.15 0.45];   % faixa do mapa de cores (ohm)
    h2 = gobjects(numel(cods), 1);
    for k = 1:numel(cods)
        [t, r] = ripple(sprintf('Dados_Ensaios/Variando_RES/6bracos_210w_2700rpm_%s.csv', cods{k}), Fs);
        h2(k) = plot(ax2, t, r, 'Color', cor_do_mapa(mapa2, (esr(k) - faixa(1)) / diff(faixa)), 'LineWidth', 0.8);
    end
    % 0,195 ohm e arredondado para 0,19 (valor usado no texto e no resumo)
    lg2 = legend(ax2, flipud(h2), compose('%.2f \\Omega', fliplr(round(esr*100 - 1e-9)/100)), 'Location', 'eastoutside');
    lg2.Title.String = 'ESR';
    formata(ax2, lg2, fonte, '(b)');
    xlabel(ax2, 'Time (ms)', 'FontName', fonte, 'FontSize', 8);

    linkaxes([ax1 ax2], 'xy');
    xlim(ax1, [0 2/120*1e3]);
    ylim(ax1, [-9 7]);

    if ~isfolder('Figuras_Artigo'); mkdir('Figuras_Artigo'); end
    exportgraphics(fig, fullfile('Figuras_Artigo', 'validacao.pdf'), 'ContentType', 'vector');
end

function [t, r] = ripple(arquivo, Fs)
% Dois periodos de 120 Hz do ripple, filtrado e alinhado pela fase de 120 Hz.
    d = readmatrix(arquivo, 'Delimiter', ';', 'DecimalSeparator', ',', 'FileType', 'text');
    v = movmean(d(:,2), 100);
    v = v(201:end-200);
    tt = (0:numel(v)-1)' / Fs;
    fase = angle(sum((v - mean(v)) .* exp(-1j*2*pi*120*tt)));
    i0 = floor(mod(-fase/(2*pi), 1) / 120 * Fs) + 1;
    janela = round(2/120 * Fs);
    r = v(i0:i0+janela-1) - mean(v);
    t = (0:janela-1)' / Fs * 1e3;
end

function c = cor_do_mapa(mapa, x)
% Cor do mapa na posicao x (0 a 1).
    c = interp1(linspace(0, 1, size(mapa, 1)), mapa, min(max(x, 0), 1));
end

function m = viridis(n)
% Aproximacao do mapa viridis (matplotlib), interpolada a partir de 11 cores.
    base = [0.267 0.005 0.329; 0.283 0.141 0.458; 0.254 0.265 0.530; 0.207 0.372 0.553;
            0.164 0.471 0.558; 0.128 0.567 0.551; 0.135 0.659 0.518; 0.267 0.749 0.441;
            0.478 0.821 0.318; 0.741 0.873 0.150; 0.993 0.906 0.144];
    m = interp1(linspace(0, 1, size(base, 1)), base, linspace(0, 1, n));
end

function m = plasma(n)
% Aproximacao do mapa plasma (matplotlib), sem o amarelo final, que some no fundo branco.
    base = [0.050 0.030 0.528; 0.299 0.007 0.627; 0.494 0.012 0.658; 0.665 0.139 0.586;
            0.798 0.280 0.470; 0.902 0.425 0.360; 0.973 0.585 0.252; 0.994 0.766 0.161];
    m = interp1(linspace(0, 1, size(base, 1)), base, linspace(0, 1, n));
end

function formata(ax, lg, fonte, rotulo)
    set(ax, 'FontName', fonte, 'FontSize', 8, 'Box', 'on', 'LineWidth', 0.5, 'TickLength', [0.01 0.01]);
    set(lg, 'FontName', fonte, 'FontSize', 7, 'Box', 'off', 'ItemTokenSize', [12 8]);
    lg.Title.FontSize = 8; lg.Title.FontWeight = 'normal';
    ylabel(ax, 'Dc-link ripple (V)', 'FontName', fonte, 'FontSize', 8);
    text(ax, 0.015, 0.05, rotulo, 'Units', 'normalized', 'FontName', fonte, ...
        'FontSize', 8, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
    grid(ax, 'on');
end
