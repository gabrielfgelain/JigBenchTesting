# JigBenchTesting

Bancada automatizada de ensaio de um conjunto conversor + inversor de frequência, para estimar a
degradação de capacitores do barramento CC ao longo do tempo (projeto de dissertação de
mestrado). Inclui a automação em LabVIEW do ensaio (pré-carga, braços de capacitores/resistores,
motor contínuo, freio de histerese, leitura via analisador de potência Yokogawa PZ4000) e um
conjunto de scripts MATLAB para analisar os dados coletados.

**Status:** motor contínuo + freio de histerese integrados e validados em bancada. O foco do
ensaio é caracterizar regime permanente (não o transiente de comutação): o motor liga uma única
vez por sessão e múltiplas configurações de braços de capacitores são testadas sem reiniciá-lo.
Máquina de estados, salvamento em CSV, módulo de resistores e módulo do freio já testados
fisicamente. Ver [Pendências](#pendências) para o que falta.

## Estrutura do repositório

| Pasta/arquivo | O que é |
|---|---|
| `Ensaio_Jiga.vi` | VI principal — máquina de estados do ensaio, módulo de resistores e módulo do freio de histerese. |
| `Freio_Histerese.vi` | Módulo do freio de histerese (pode estar também embutido em `Ensaio_Jiga.vi` como loop paralelo — ver [Detalhes técnicos](#módulo-paralelo--freio-de-histerese)). |
| `Enum_Estados_Ensaio.ctl` | Enum com os estados da máquina de estados principal. |
| `new_Ensaio_Jiga.lvproj` (+ `.aliases`, `.lvlps`) | Projeto LabVIEW. |
| `pz_analyzer_gelain.llb` | VIs customizados de leitura/tratamento do PZ4000 (ex.: `waveform_demux.vi`). |
| `Dados_Ensaios/` | Dados brutos coletados nos ensaios (ver abaixo). |
| `plot_*.m` | Scripts MATLAB para plotar/analisar os dados coletados (ver [Scripts MATLAB](#scripts-matlab)). |
| `*.csv` / `*.txt` na raiz | Ensaios avulsos usados durante o desenvolvimento/depuração dos scripts. |

O driver oficial do PZ4000 (`Yokogawa PZ4000.lvlib`) é uma dependência externa instalada junto
com os Instrument Drivers do LabVIEW — não faz parte deste repositório.

## Dados coletados (`Dados_Ensaios/`)

Ensaios "sem carga" a 3000 RPM, varrendo de 7 a 0 braços de capacitância ativos
(`Qtd_Bracos_Ativos`), para diferentes bancos de capacitor:

- `SemCarga_3000RPM_1MOSFET/` — grupo "RSE"
- `SemCarga_3000RPM_1047/` — grupo "RSE1047"
- `SemCarga_3000RPM_2047/` — grupo "RSE2047"
- `SemCarga_3000RPM_2068/` — grupo "RSE2068"
- `MotorDesligado/` — ensaios de referência com motor ligado vs. desligado (sem chaveamento)

Cada CSV tem 100.001 amostras (janela de observação de 1 s a 100 kHz), sem cabeçalho, separador
`;`, decimal `,`, 6 colunas (3 tensões + 3 correntes). **Coluna 2 = tensão do barramento CC**,
confirmada contra um segundo instrumento (wattímetro WT320) e usada como referência nas análises.
O canal antes assumido como "corrente do barramento" (coluna 5 nos scripts) na verdade mede a
**saída do inversor** (a ponteira está em série com o motor, não com o barramento) — ver
[Notas sobre os dados](#notas-sobre-os-dados-interpretação-por-canal).

## Scripts MATLAB

Todos assumem que o CSV/TXT referenciado está na mesma pasta do script (caminhos relativos).

| Script | O que plota |
|---|---|
| `plot_ensaios_pz4000.m` | Tensão e corrente de um ensaio (arquivos `.txt` do PZ4000), 3 subplots por arquivo (Plot 0/1/2). |
| `plot_barramento_cc.m` | Tensão e corrente do barramento CC de um único ensaio, um em cima do outro. |
| `plot_barramento_cc_bracos.m` | Tensão do barramento concatenando os ensaios de 7→0 braços de cada grupo (4 figuras), com média por ensaio destacada. |
| `plot_barramento_cc_bracos_bruto.m` | Mesma ideia, mas sem suavização — só remoção pontual de outliers. |
| `plot_saida_conversor_bracos.m` | Mesmo formato de 7→0 braços, aplicado à coluna 1 (saída do conversor/inversor). |
| `plot_corrente_barramento_bracos.m` | Mesmo formato, aplicado à coluna 5 — **nome desatualizado**: esse canal é a corrente de saída do inversor, não do barramento (ver nota acima). |
| `plot_motor_ligado_desligado.m` | Compara os 4 ensaios de `MotorDesligado/` lado a lado, focando nos picos de tensão/corrente. |
| `plot_teste.m` | Plota `teste.csv` (ensaio com carga no eixo) e sobrepõe a referência sem carga (7 braços) na tensão do barramento. |

## Como rodar

**LabVIEW:** abrir `new_Ensaio_Jiga.lvproj`, rodar `Ensaio_Jiga.vi`. Requer o driver do PZ4000
instalado, o DAQ configurado nas portas usadas pelos braços/pré-carga/resistores, e a fonte do
freio (TDK-Lambda Genesys) acessível via GPIB.

**MATLAB:** abrir a pasta do repositório como diretório de trabalho e chamar a função desejada,
ex.:

```matlab
plot_barramento_cc_bracos
```

---

## Detalhes técnicos

### Objetivo do ensaio

Como a degradação de capacitores é um processo lento (meses a anos), o foco é caracterizar o
**regime permanente** para diferentes configurações de capacitância ativa — não o transiente
elétrico do instante de comutação. Essa decisão simplificou bastante a arquitetura em relação a
uma primeira versão do programa, que capturava o desligamento sequencial dos capacitores durante
a própria aquisição.

### Arquitetura geral

Quatro blocos rodando em paralelo, de forma independente, no mesmo Block Diagram:

- **Máquina de estados principal** — um único While Loop com uma Case Structure controlada por
  um Enum Type Def (`Enum_Estados_Ensaio.ctl`).
- **Módulo de resistores** — While Loop independente com Event Structure, escutando os 4 botões
  de acionamento manual dos braços de resistores a qualquer momento, inclusive durante o ensaio.
- **Módulo do freio de histerese** — Event Structure para acionamento manual da fonte de
  corrente do freio, mais um loop de aquisição contínua de corrente/tensão de saída.
- (implícito) leitura do PZ4000 é uma captura única e bloqueante, não streaming — por isso não há
  Functional Global Variables, Notifiers ou filas de dados entre os loops: não há necessidade
  real de troca de dados entre eles, só de execução independente.

**Motor contínuo:** o motor liga uma única vez por sessão de ensaios. Ao atingir velocidade
estável, a máquina entra em `Motor_Rodando` e aguarda comandos do usuário — ajustar
`Qtd_Bracos_Ativos`, disparar um ensaio (volta para `Motor_Rodando` ao final) ou encerrar a
sessão. Isso permite testar várias configurações de capacitância no mesmo aquecimento do motor,
evitando misturar variabilidade térmica com o efeito da capacitância.

### Hardware

| Item | Detalhe |
|---|---|
| Yokogawa PZ4000 | Driver oficial + VIs customizados em `pz_analyzer_gelain.llb`. Modo waveform: buffer de 100.000 pontos/canal, janela de observação de 1 s (100 kHz). |
| DAQ — Braços de capacitores | 7 saídas digitais, ativas em HIGH. Quantidade ativa definida por `Qtd_Bracos_Ativos` (0–7), fixada antes de cada ensaio. |
| DAQ — Pré-carga | 7 saídas digitais, ativas em LOW. |
| DAQ — Braços de resistores | 4 saídas digitais, porta própria. Controle manual a qualquer momento. |
| DAQ — Resfriamento do freio | Task `resfriamento_freio` (NI MAX), aciona a válvula solenoide do resfriamento pneumático. |
| Motor | Ligado/desligado via Python Node. Liga uma única vez por sessão. |
| Freio de histerese | Magtrol AHB-3M-R-A, resfriado a ar comprimido. Torque ≈ proporcional à corrente de campo, independente da velocidade. |
| Fonte do freio | TDK-Lambda Genesys GEN600-1, via GPIB (driver `GENie`), em modo corrente constante (recomendação do fabricante do freio). |

### Máquina de estados principal

| Estado | Função resumida |
|---|---|
| `Idle` | Aguarda `Iniciar_Ensaio`. |
| `Pre_Carga` | Liga a pré-carga (LOW nas 7 saídas). |
| `Aguarda_PreCarga` | Polling até `Tempo_PreCarga`. |
| `Ativa_Bracos` | Monta dinamicamente o array de 7 braços conforme `Qtd_Bracos_Ativos` (N em HIGH, resto em LOW). |
| `Delay_PosBracos` | Aguarda ≥1 s. |
| `Desativa_PreCarga` | Desliga a pré-carga (HIGH). |
| `Aciona_Motor` | Liga o motor via Python Node. |
| `Aguarda_Motor` | Polling até `Tempo_EstabMotor` (~8 s + margem). |
| `Motor_Rodando` | Motor estável, aguarda `Executar_Ensaio` (→ `Ensaio`) ou `Finalizar_Sessao` (→ `Para_Motor`). |
| `Ensaio` | Dispara/lê o PZ4000 com a configuração de braços atual, salva CSV, volta para `Motor_Rodando`. |
| `Para_Motor` | Desliga o motor, volta para `Idle`. |
| `Emergencia` | Desliga braços, resistores e pré-carga; para o motor; volta para `Idle`. Acessível a qualquer momento via `Abortar_Ensaio` (mecanismo de sobreposição — substitui o próximo estado independente de onde a máquina estiver). |

### Estado `Ensaio`

Sequência linear (mais simples que a versão anterior, que desligava braços durante a própria
captura):

1. Dispara a captura (`Wait Update.vi`).
2. Aguarda o fim via polling do bit 0 do Condition Register (`Query Condition Status.vi`),
   conforme o manual de comunicação do PZ4000. Para com `Aquisicao_Terminou`, `Abortar_Ensaio` ou
   timeout.
3. Lê os 6 canais e separa em Tensão/Corrente (`waveform_demux.vi`) — dois arrays 3×100.000.
4. Transpõe, concatena em uma tabela 100.000×6 e salva via `Write Delimited Spreadsheet.vi`
   (delimitador `;`), com nome de arquivo definido manualmente pelo usuário a cada ensaio
   (`Ensaio_{QtdBracos}bracos_RSE{ValorRSE}_SemCarga_{DataHora}.csv`).
5. Atualiza os gráficos e retorna para `Motor_Rodando`.

### Módulo paralelo — Freio de Histerese

While Loop com Event Structure própria, independente da máquina principal:

- **Rotina de segurança** (uma vez, antes dos loops): liga a fonte, zera a corrente, desliga —
  garante que a fonte nunca herda um setpoint de uma execução anterior.
- **`Liga_Fonte`**: habilita a saída da fonte e a válvula de resfriamento pneumático.
- **`Seta_Carga`**: aplica `Limite_Corrente`/`Limite_Tensao` configurados — ponto de entrada já
  preparado para uma futura malha de controle automático (PID).
- **`STOP_Freio`**: rampa de desligamento gradual (−0,05 A a cada 2 s até zero), depois fecha o
  resfriamento e desliga a fonte.
- **Loop de aquisição** contínua de corrente/tensão de saída do freio.
- Limites de segurança travados nos controles: 0–24 V, 0–0,4 A (specs do Magtrol AHB-3M-R-A).

### Notas sobre os dados (interpretação por canal)

Com base na inspeção amostra a amostra dos ensaios e em uma investigação encerrada, documentada
na documentação técnica completa do projeto:

- **Coluna 2 — barramento CC.** Praticamente constante (~305-310 V), com resolução grosseira
  (~1,22 V por degrau — quantização do instrumento, não ruído real). Ripple cresce de forma
  monotônica conforme menos braços de capacitores estão ativos (ex.: ~0,86 V com 7 braços até
  ~1,34 V com 0 braços), coerente com simulação prévia do grupo de pesquisa.
- **Coluna 1 — saída do conversor/inversor.** Onda PWM chaveada, amplitude RMS ~160 V batendo
  com a leitura de um wattímetro WT320 (~162 V) com o motor girando. Some quase por completo com
  o motor desligado.
- **Coluna 5 — investigação encerrada.** Os picos de ~387 A observados são saturação de faixa do
  instrumento, mas a causa raiz do canal em si já foi identificada: a ponteira de corrente desse
  elemento está fisicamente em série com a **saída do inversor** (rumo ao motor), não com o
  barramento CC — o canal nunca foi projetado para medir o barramento. RMS desse canal (~15 A)
  não varia com `Qtd_Bracos_Ativos`, ao contrário do ripple de tensão do barramento, que varia de
  forma clara. Os scripts MATLAB ainda usam o nome antigo ("corrente do barramento") — rótulo
  pendente de correção.

## Pendências

- [ ] Disable/grey-out dos controles de tempo e `Qtd_Bracos_Ativos` durante execução do
      ensaio/sessão.
- [ ] Checagem de estado antes de `Liga_Fonte` — só permitir acionar a fonte do freio quando a
      máquina principal já estiver em `Motor_Rodando` ou além (hoje o módulo do freio não valida
      isso).
- [ ] Malha de controle automático do freio (PID) — decidir com o orientador se a referência é
      torque ou potência; `Seta_Carga`/`Limite_Corrente` já são o ponto de entrada preparado.
- [ ] Log de dados do freio (corrente/tensão de saída, setpoints, tempo), desacoplado do CSV do
      ensaio principal — ainda não implementado na versão atual.
- [ ] Integração com a comunicação do inversor (em desenvolvimento por outra pessoa).
- [ ] Cadeia de Error Handling completa em todas as cases da máquina de estados.
- [ ] Reset programático de `Abortar_Ensaio` (Property Node, modo Write) ao entrar em
      `Emergencia`/`Idle` — hoje, como o botão é Switch (não Latch), o valor persiste em `True`
      após o acionamento.
- [ ] Reavaliar o sensor de corrente/tensão de saída do inversor (coluna 5) — avaliar se esse
      dado tem utilidade própria para outra análise, com o rótulo correto, e atualizar os scripts
      MATLAB que ainda o chamam de "corrente do barramento".

## Validado em bancada

- Máquina de estados completa, incluindo motor contínuo (múltiplos ensaios sem reiniciar o
  motor).
- Estado `Ensaio` simplificado: disparo, sincronização, leitura dos 6 canais, salvamento direto
  em CSV — testado com múltiplas configurações de braços.
- Módulo de resistores: 4 braços controláveis individualmente a qualquer momento.
- Módulo do freio de histerese: inicialização, rotina de segurança, acionamento manual (rampa de
  desligamento gradual e resfriamento), leitura real de corrente/tensão de saída, limites de
  segurança — testado em bancada com fonte e freio físicos.
- Mecanismo de aborto de emergência a partir de qualquer estado.
