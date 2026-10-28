function analisa_influencia_c()
% Usa tabela_features_ensaios.csv (gerada por extrai_features_ensaios.m) para
% responder, com foco na capacitancia:
%  1) quanto da variacao de cada feature vem de C, da potencia, da rotacao e
%     da configuracao de resistores (ANOVA, parcela eta^2 de cada fator);
%  2) qual medida do inversor estima melhor C quando potencia e rotacao
%     mudam juntas, comparando o ripple bruto com o ripple normalizado pela
%     carga, como sai da fisica do retificador monofasico:
%        A120 ~ P / (Vdc * 2*pi*120 * C)  =>  C ~ P / (Vdc * 2*pi*120 * A120)

    T = readtable('tabela_features_ensaios.csv', 'Delimiter', ';', 'TextType', 'string');
    T.codigo = string(T.codigo);
    T = remove_invalidos(T);

    % ---------------- 1) influencia de cada fator ----------------
    feats = {'Vdc_mean', 'Vdc_std', 'Vdc_p2p', 'Vout_rms', 'Iout_rms', 'Pout', ...
        'Vdc_A120', 'Vdc_A240', 'Vdc_A360', 'Vdc_A480', 'Vdc_A6fe', 'Vdc_A5k', ...
        'Vdc_rippleLF', 'Iout_Afe'};
    fatores = {T.C_uF, T.P_W, T.RPM, T.codigo};
    nomesFat = {'C', 'Potencia', 'Rotacao', 'Config_R'};

    eta = zeros(numel(feats), numel(fatores) + 1);
    for k = 1:numel(feats)
        y = T.(feats{k});
        ok = ~isnan(y);
        g = cellfun(@(x) x(ok), fatores, 'UniformOutput', false);
        [~, tab] = anovan(y(ok), g, 'model', 'linear', 'varnames', nomesFat, ...
            'display', 'off');
        ssTot = tab{end, 2};
        for j = 1:numel(fatores)
            eta(k, j) = tab{j+1, 2} / ssTot;
        end
        eta(k, end) = tab{end-1, 2} / ssTot; % residuo (interacoes + ruido)
    end

    fprintf('\nParcela da variancia de cada feature explicada por cada fator (eta^2, %%)\n');
    fprintf('%-13s %8s %8s %8s %8s %8s\n', 'Feature', nomesFat{:}, 'Residuo');
    for k = 1:numel(feats)
        fprintf('%-13s %8.1f %8.1f %8.1f %8.1f %8.1f\n', feats{k}, 100*eta(k,:));
    end

    % ---------------- 2) medida para estimar C ----------------
    w = 2*pi*120;
    cand.A120_bruto      = 1 ./ T.Vdc_A120;
    cand.Std_bruto       = 1 ./ T.Vdc_std;
    cand.Iout_sobre_A120 = T.Iout_rms ./ T.Vdc_A120;
    cand.P_sobre_VA120   = T.Pout ./ (T.Vdc_mean .* w .* T.Vdc_A120);
    cand.P_sobre_Vstd    = T.Pout ./ (T.Vdc_mean .* w .* T.Vdc_std);
    nomesC = fieldnames(cand);

    fprintf('\nEstimativa de C com todas as potencias e rotacoes juntas (n = %d)\n', height(T));
    fprintf('Ganho unico k (C_est = k * feature), ajustado por minimos quadrados\n');
    fprintf('%-16s %8s %8s %10s %10s\n', 'Feature', 'Pearson', 'Spearman', 'Erro med%', 'Erro p95%');
    erros = struct();
    for k = 1:numel(nomesC)
        x = cand.(nomesC{k});
        kGanho = (x' * T.C_uF) / (x' * x);
        Cest = kGanho * x;
        e = 100 * abs(Cest - T.C_uF) ./ T.C_uF;
        erros.(nomesC{k}) = Cest;
        fprintf('%-16s %8.2f %8.2f %10.1f %10.1f\n', nomesC{k}, corr(x, T.C_uF), ...
            corr(x, T.C_uF, 'Type', 'Spearman'), median(e), prctile(e, 95));
    end

    fprintf('\nErro mediano (%%) de P_sobre_VA120 por condicao (vies da carga/rotacao)\n');
    fprintf('%6s %8s %8s %8s\n', 'RPM', '80W', '150W', '210W');
    pots = unique(T.P_W);
    for r = unique(T.RPM)'
        fprintf('%6d', r);
        for p = pots'
            s = T.RPM == r & T.P_W == p;
            fprintf(' %8.1f', median(100 * (erros.P_sobre_VA120(s) - T.C_uF(s)) ./ T.C_uF(s)));
        end
        fprintf('\n');
    end

    % ---------------- figuras ----------------
    figure('Name', 'Influencia dos fatores', 'Color', 'w', 'Position', [40 80 1000 450]);
    b = barh(categorical(feats, feats), 100*eta, 'stacked');
    cores = [0.20 0.45 0.80; 0.90 0.55 0.15; 0.35 0.70 0.35; 0.60 0.40 0.75; 0.75 0.75 0.75];
    for j = 1:numel(b); b(j).FaceColor = cores(j,:); end
    legend([nomesFat, {'Residuo'}], 'Location', 'eastoutside', 'Interpreter', 'none');
    set(gca, 'TickLabelInterpreter', 'none');
    xlabel('Parcela da variancia (%)'); xlim([0 100]);
    title('O que cada fator influencia em cada feature');

    figure('Name', 'Ripple bruto x normalizado', 'Color', 'w', 'Position', [60 60 1100 450]);
    pots = unique(T.P_W);
    marc = {'o', 's', '^'};
    rpms = unique(T.RPM);
    corR = lines(numel(rpms));
    subplot(1,2,1); hold on;
    for i = 1:numel(pots)
        for j = 1:numel(rpms)
            s = T.P_W == pots(i) & T.RPM == rpms(j);
            scatter(T.C_uF(s), T.Vdc_A120(s), 14, corR(j,:), marc{i}, 'filled', ...
                'MarkerFaceAlpha', 0.45, 'DisplayName', sprintf('%d W, %d RPM', pots(i), rpms(j)));
        end
    end
    xlabel('C (\muF)'); ylabel('Ripple 120 Hz, A_{120} (V)'); grid on; box on;
    title('Ripple bruto: a carga separa as curvas');
    legend('Location', 'northeast', 'FontSize', 7);

    subplot(1,2,2); hold on;
    for i = 1:numel(pots)
        for j = 1:numel(rpms)
            s = T.P_W == pots(i) & T.RPM == rpms(j);
            scatter(T.C_uF(s), erros.P_sobre_VA120(s), 14, corR(j,:), marc{i}, 'filled', ...
                'MarkerFaceAlpha', 0.45);
        end
    end
    plot([300 1100], [300 1100], 'k--');
    xlabel('C real (\muF)'); ylabel('C estimado (\muF)'); grid on; box on;
    title('C \propto P_{out} / (V_{dc} \omega A_{120}): as curvas se juntam');
end

function T = remove_invalidos(T)
% Tira ensaios que nao representam o C do rotulo:
%  - motor parado ou gravacao vazia (potencia de saida ~0);
%  - series (mesma rotacao/potencia/config/data) em que o ripple nao muda
%    com o numero de bracos, ou seja, a jiga nao comutou os capacitores
%    (ex.: 3000 RPM/210 W, configs 0010/0100/0110 de 29/09, refeitas em 09/10).
    ruim = T.Pout < 5;
    [g, ~] = findgroups(T.RPM, T.P_W, T.codigo, T.data);
    for k = 1:max(g)
        s = g == k & ~ruim;
        a = T.Vdc_A120(s);
        if nnz(s) >= 4 && (max(a) - min(a)) / mean(a) < 0.2
            ruim(s) = true;
        end
    end
    fprintf('Ensaios excluidos: %d de %d\n', nnz(ruim), height(T));
    disp(unique(T(ruim, {'RPM', 'P_W', 'codigo', 'data'})));
    T = T(~ruim, :);
end
