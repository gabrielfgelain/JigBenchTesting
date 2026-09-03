# Automação de Ensaio de Inversor de Frequência

Automação em LabVIEW de um ensaio de inversor de frequência para estimar a degradação de
capacitores ao longo do tempo: controle de 7 braços de capacitores, 4 braços de resistores,
pré-carga, motor e freio de histerese, com leitura de tensão e corrente via analisador de
potência Yokogawa PZ4000.

> Documentação técnica completa (arquitetura, cada estado da máquina, decisões de projeto e
> pendências detalhadas): ver `Documentacao_Tecnica_Ensaio_Inversor.docx` neste repositório.
> Este README é um resumo rápido de orientação, atualizado para refletir a versão atual.

## Status

**Versão funcional com motor contínuo e freio de histerese integrado.** A máquina de estados
roda de ponta a ponta (pré-carga → braços → motor → múltiplos ensaios sem reiniciar o motor →
parada), com módulos paralelos de resistores e de freio de histerese operando de forma
independente. Dados salvos automaticamente em CSV a cada ensaio. Ainda faltam itens de
robustez e a malha de controle automático do freio — ver [Pendências](#pendências).

## Estrutura do programa

Quatro loops paralelos e independentes no mesmo VI:

- **Máquina de estados principal** — um único While Loop com uma Case Structure controlada por
  um Enum (`Enum_Estados_Ensaio.ctl`): `Idle → Pre_Carga → Aguarda_PreCarga → Ativa_Bracos →
  Delay_PosBracos → Desativa_PreCarga → Aciona_Motor → Aguarda_Motor → Motor_Rodando ⇄ Ensaio →
  Para_Motor → (Idle)`, com um estado `Emergencia` acessível a qualquer momento via botão
  `Abortar_Ensaio`.
- **Módulo de resistores** — um segundo While Loop com Event Structure, escutando os 4 botões
  de acionamento manual dos braços de resistores a qualquer momento, inclusive durante o
  ensaio.
- **Módulo do freio de histerese** — Event Structure com acionamento manual da fonte de
  corrente do freio (`Liga_Fonte`, `Seta_Carga`, `STOP_Freio` com rampa gradual), mais um loop
  de aquisição contínua de corrente/tensão de saída.

Não há Functional Global Variables nem filas — a leitura do PZ4000 é uma captura única e
bloqueante (não streaming), então não há necessidade real de paralelismo ali. O paralelismo
existe apenas onde é estritamente necessário: controle manual dos resistores e do freio,
independentes do que a máquina principal está fazendo.

### Motor contínuo e múltiplos ensaios por sessão

Diferente de reiniciar o motor a cada configuração de capacitância (o que introduzia
variabilidade térmica entre ensaios), o motor liga **uma vez** por sessão. Ao chegar em
`Motor_Rodando`, a máquina fica aguardando o usuário:

- ajustar `Qtd_Bracos_Ativos` (0–7) livremente;
- apertar `Executar_Ensaio` → dispara uma captura do PZ4000 com a configuração atual, salva o
  CSV, e retorna para `Motor_Rodando` — permitindo repetir quantas vezes forem necessárias sem
  reiniciar o motor;
- apertar `Finalizar_Sessao` → segue para `Para_Motor` e encerra.

### Mudança de metodologia: regime permanente, não transiente de comutação

O objetivo é caracterizar o comportamento em regime permanente para cada quantidade de
capacitores ativos (relevante para degradação, que ocorre ao longo de meses/anos) — não o
transiente elétrico do instante de comutação. Por isso, a configuração de braços é fixada
**antes** do disparo do PZ4000 (não mais alterada durante a captura), e a janela de observação
do PZ4000 usa o padrão validado de **1 s / 100 kHz** (100.000 pontos), eliminando os problemas
de timeout que apareciam com janelas de observação mais longas.

## Hardware

| Item | Detalhe |
|---|---|
| Yokogawa PZ4000 | Driver oficial (`Yokogawa PZ4000.lvlib`) + VIs customizados em `pz_analyzer.llb`. Buffer de 100.000 pontos, janela de observação de 1 s (100 kHz), 3 elementos (6 canais: 3×V, 3×I). |
| DAQ — Braços de capacitores | 7 saídas digitais, ativas em HIGH. Quantidade ativa configurável via `Qtd_Bracos_Ativos`. |
| DAQ — Pré-carga | 7 saídas digitais, ativas em LOW. |
| DAQ — Braços de resistores | 4 saídas digitais, porta própria (sem conflito de canal). |
| DAQ — Resfriamento do freio | Task salva no NI MAX (`resfriamento_freio`), aciona válvula solenoide pneumática. |
| Motor | Ligado/desligado via Python Node (Open/Close Python Session). |
| Freio de histerese | Magtrol AHB-3M-R-A (torque proporcional à corrente da bobina; ratings elétricos batem com a linha AHB-1 do datasheet: 24 V, 400 mA nominal, 9,6 W). Resfriado a ar comprimido. |
| Fonte do freio | TDK-Lambda Genesys GEN600-1, via GPIB (driver `GENie`), controlada em modo corrente constante — recomendação do próprio fabricante do freio, já que a resistência da bobina varia com temperatura e tensão constante geraria deriva de torque. |

## Estado `Ensaio`

Simplificado em relação a versões anteriores (sem mais desligamento sequencial de braços
durante a captura):

1. **Dispara** a captura do PZ4000 (`Wait Update.vi`).
2. **Aguarda o fim da captura** via bit 0 do Condition Register (`Query Condition Status.vi` +
   AND bit a bit + comparação, conforme documentado no manual de comunicação do PZ4000).
3. **Lê os 6 canais**, transpõe e concatena Tensão/Corrente (via For Loop com indexação — não
   `Build Array` direto, que concatena linhas em vez de colunas em arrays 2D).
4. **Salva em CSV** diretamente dos arrays internos do LabVIEW (`Write Delimited
   Spreadsheet.vi`, delimitador `;`) — não a partir de exportação manual do gráfico, que
   introduzia artefatos visuais inexistentes nos dados reais.
5. Retorna para `Motor_Rodando`.

### Convenção de nome de arquivo (manual)

```
Ensaio_{QtdBracos}bracos_RSE{ValorRSE}_SemCarga_{DataHora}.csv
```
Exemplo: `Ensaio_3bracos_RSE0.85_SemCarga_2026-08-26_16-45.csv`

Não há geração automática de nome — o usuário digita seguindo o padrão acima antes de cada
`Executar_Ensaio`, evitando sobrescrever arquivos de configurações repetidas.

## Módulo do freio de histerese

Reescrito a partir de um VI legado do laboratório (mesmo comportamento, adaptado aos padrões
do projeto atual e sem as partes relativas ao inversor, desenvolvidas por outra pessoa).

- **Inicialização** (fora dos loops): `GENie Initialize.vi` + `Config Power-On State.vi`
  (`Safe Start`).
- **Rotina de segurança** (uma vez, antes dos loops de evento): liga a fonte, zera a corrente,
  desliga a fonte — garante que nunca sobra um setpoint perigoso de execução anterior.
- **`Liga_Fonte`**: habilita a saída da fonte e aciona a válvula solenoide de resfriamento
  pneumático, juntos.
- **`Seta_Carga`**: aplica `Limite_Corrente`/`Limite_Tensao` na fonte (`GENie Config Current/
  Voltage Limit.vi`). É o ponto de entrada para uma futura malha de controle automático (torque
  ou potência — ver Pendências).
- **`STOP_Freio`**: reduz a corrente gradualmente até zero (rampa de 0,05 A a cada 2 s, com
  proteção contra valor negativo via `Max & Min`), depois fecha a válvula de resfriamento e
  desliga a fonte.
- **Loop de aquisição**: lê corrente/tensão de saída real (`GENie Meas Output Current/
  Voltage.vi`) continuamente, enquanto o freio estiver ligado.
- Controles numéricos (`Limite_Tensao`, `Limite_Corrente`) têm range travado (0–24 V, 0–0,4 A)
  com coerção automática, baseado nas especificações nominais do freio.

## Pendências

- [ ] Disable/grey-out dos controles de tempo e `Qtd_Bracos_Ativos` durante execução do ensaio.
- [ ] Checagem de estado da máquina principal antes de permitir `Liga_Fonte` (só operar quando
      o motor já estiver em `Motor_Rodando` ou além).
- [ ] Malha de controle automático do freio (PID) — referência de torque ou de potência, a
      decidir. `Seta_Carga`/`Limite_Corrente` já são o ponto de entrada preparado para receber
      o valor calculado.
- [ ] Log de dados do freio (corrente/tensão de saída, setpoints, tempo) em arquivo próprio,
      desacoplado do CSV do ensaio principal.
- [ ] Integração com a comunicação do inversor (em desenvolvimento por outra pessoa) — avaliar
      se/como conectar com o módulo do freio quando estiver pronta.

## Notas sobre os dados coletados (mapeamento de canais)

Com base em ensaios reais (`SemJiga_SemCarga`) e comparação com dados legados do mesmo
laboratório:

- **Barramento CC** — um dos elementos, praticamente constante (~305–307 V, fator de crista ≈
  1,0). O ripple de tensão aumenta de forma consistente conforme menos braços de capacitores
  estão ativos (ex.: ~0,86 V com 7 braços vs. ~1,34 V com 0 braços) — validação experimental
  coerente com simulação.
- **Nó de chaveamento do inversor** — outro elemento, onda quadrada entre ~0 V e o valor do
  barramento invertido, período de ~200 amostras (~50% duty cycle). Consistente com tensão de
  polo/linha na saída do inversor.
- **Terceiro elemento** — piso de ruído / sem sinal relevante nos ensaios sem carga.
- O elemento inicialmente identificado como "corrente do barramento" **não mede o barramento**:
  a ponteira está fisicamente em série com a saída do inversor, não com o barramento. O RMS
  desse canal (~15 A) não varia com `Qtd_Bracos_Ativos`, confirmando que não está relacionado à
  capacitância do barramento. Os glitches isolados de ~387 A observados nesse canal (valor fixo,
  correlacionado com os instantes de chaveamento) não foram mais investigados após essa
  descoberta, já que o canal não é utilizado para os resultados do ensaio.

Essas conclusões vêm de inspecionar a forma de onda amostra a amostra, não só das estatísticas
agregadas (mean/RMS/min/max) — recomenda-se sempre plotar/inspecionar o sinal bruto antes de
tirar conclusões físicas.

## Arquivos do driver

- `Yokogawa PZ4000.lvlib` — driver oficial (Initialize, Close, Config Waveform, Config Current,
  Wait Update, Query Condition Status, Read Range, Read Waveform, Waveform Data Convert, etc.).
- `pz_analyzer.llb` — VIs customizados do laboratório, incluindo `waveform_demux.vi` (em uso).
- Driver `GENie` (TDK-Lambda) — Initialize, Config Power-On State, Config Output On-Off, Config
  Current/Voltage Limit, Meas Output Current/Voltage, convertido de LabVIEW 2021 para a versão
  atual do projeto.
- Manuais de referência: *PZ4000 Power Analyzer Communication Interface User's Manual*
  (IM 253710-11E); *AHB Series Compressed-air-cooled Hysteresis Brakes Data Sheet* (Magtrol).
