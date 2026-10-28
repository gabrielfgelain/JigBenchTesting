function gera_plano_ensaios()
% Gera o plano da campanha de ensaios (1 s de observacao, 100 kS/s) para o
% sequenciador do LabVIEW: uma linha por ensaio, na ordem em que devem ser
% executados. Salva plano_ensaios.csv ao lado deste script (separador ';',
% decimal ',').
%
% Estrategia:
%   - Todas as 120 combinacoes (0 a 7 bracos x 15 codigos de resistor) em cada
%     ponto de operacao (rotacao x potencia), para cobrir o maximo de condicoes.
%   - Ordem sorteada dentro de cada ponto de operacao, nova a cada ponto e a
%     cada repeticao. A ordem dos pontos tambem e sorteada (sugestao: o LabVIEW
%     escolhe as linhas pela rotacao e potencia ajustadas na bancada).
%   - Ensaio de referencia (condicao fixa) no inicio, a cada N ensaios e no
%     fim de cada ponto de operacao, para medir a deriva da bancada.
%   - Com 0 bracos os resistores nao deveriam influenciar; os 15 codigos ficam
%     no plano para confirmar isso e medir a repetibilidade.
%   - Cada repeticao e uma sessao separada (de preferencia em outro dia).
%
% Colunas do CSV:
%   id; sessao; bloco; ordem_no_bloco; referencia; rpm; potencia_W; bracos;
%   r1; r2; r3; r4; codigo_resistor; resistor_num; C_uF; ESR_barramento_mOhm
% (r1..r4 = estado de cada braco de resistor, 1 = ligado, na ordem do codigo;
%  resistor_num = codigo em decimal, 1 a 15, a entrada usada pelo LabVIEW.)

    % ------------------------- configuracao -------------------------
    rotacoes   = [2700 3000 3500];       % rpm
    potencias  = [80 150 210];           % W
    repeticoes = 2;                      % sessoes completas
    refBracos  = 7;                      % condicao de referencia
    refCodigo  = '0010';
    refCada    = 10;                     % referencia a cada N ensaios
    tempoEnsaio_s   = 30;                % estimativa: troca + estabilizacao + aquisicao
    tempoPonto_s    = 300;               % estimativa: troca de rotacao/potencia
    semente    = 1;                      % registra o sorteio (reprodutivel)

    % --------------------- parametros da jiga -----------------------
    Rarm = [0.11 0.58 0.345 0.45];       % bracos de resistor (mosfet incluso)
    Cdc  = [324 490 626 739 837 922 994 1056]; % C medida para n = 0..7 bracos (uF)

    % ----------------- todas as combinacoes (por ponto) -----------------
    codigos = dec2bin(1:15, 4);
    comb = cell(0, 2);
    for n = 0:7
        for k = 1:15
            comb(end+1, :) = {n, codigos(k,:)}; %#ok<AGROW>
        end
    end
    nComb = size(comb, 1);

    % --------------------------- sorteio ---------------------------
    rng(semente);
    linhas = {};
    for s = 1:repeticoes
        pontos = combvec_simples(rotacoes, potencias);
        pontos = pontos(randperm(size(pontos, 1)), :);
        for b = 1:size(pontos, 1)
            ordem = comb(randperm(nComb), :);
            seq = {};
            for k = 1:nComb
                if mod(k - 1, refCada) == 0; seq(end+1, :) = {refBracos, refCodigo, 1}; end %#ok<AGROW>
                seq(end+1, :) = [ordem(k, :), {0}]; %#ok<AGROW>
            end
            seq(end+1, :) = {refBracos, refCodigo, 1};
            for k = 1:size(seq, 1)
                linhas(end+1, :) = {s, b, k, seq{k,3}, pontos(b,1), pontos(b,2), seq{k,1}, seq{k,2}}; %#ok<AGROW>
            end
        end
    end

    % -------------------------- gravacao ---------------------------
    arquivo = fullfile(fileparts(mfilename('fullpath')), 'plano_ensaios.csv');
    fid = fopen(arquivo, 'w');
    fprintf(fid, ['id;sessao;bloco;ordem_no_bloco;referencia;rpm;potencia_W;bracos;' ...
                  'r1;r2;r3;r4;codigo_resistor;resistor_num;C_uF;ESR_barramento_mOhm\n']);
    C = zeros(size(linhas, 1), 1); E = C;
    for i = 1:size(linhas, 1)
        [s, b, k, ref, rpm, P, n, cod] = linhas{i, :};
        C(i) = Cdc(n + 1);
        E(i) = esr_barramento(n, cod, Rarm);
        txt = sprintf('%d;%d;%d;%d;%d;%d;%d;%d;%c;%c;%c;%c;%s;%d;%d;%.1f\n', ...
            i, s, b, k, ref, rpm, P, n, cod(1), cod(2), cod(3), cod(4), cod, ...
            bin2dec(cod), C(i), 1000*E(i));
        fprintf(fid, '%s', strrep(txt, '.', ','));
    end
    fclose(fid);

    % --------------------------- resumo ----------------------------
    nRef = sum(cell2mat(linhas(:, 4)));
    nPontos = numel(rotacoes) * numel(potencias);
    porSessao = size(linhas, 1) / repeticoes;
    porPonto = porSessao / nPontos;
    fprintf('Combinacoes por ponto de operacao: %d (+ %d referencias = %d ensaios)\n', ...
        nComb, porPonto - nComb, porPonto);
    fprintf('Ensaios: %d no total (%d referencias), %d por sessao\n', ...
        size(linhas, 1), nRef, porSessao);
    fprintf('Duracao estimada: %.0f min por ponto, %.1f h por sessao\n', ...
        porPonto * tempoEnsaio_s / 60, ...
        (porSessao * tempoEnsaio_s + nPontos * tempoPonto_s) / 3600);
    fprintf('Plano salvo em %s\n', arquivo);
end

function R = esr_barramento(n, codigo, Rarm)
% ESR nominal vista do barramento (mesma formula da aba Parametros de
% Labels_Ensaios.xlsx): 0,2 ohm sem bracos; senao 0,1 + 0,1*S/(0,1 + S),
% com S = 0,51/n + paralelo dos bracos de resistor ativos.
    if n == 0; R = 0.2; return; end
    S = 0.51 / n + 1 / sum(1 ./ Rarm(codigo == '1'));
    R = 0.1 + 0.1 * S / (0.1 + S);
end

function P = combvec_simples(a, b)
% Todas as combinacoes [a(i) b(j)], uma por linha.
    [A, B] = meshgrid(a, b);
    P = [A(:) B(:)];
end
