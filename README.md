# Automação de Ensaio de Inversor de Frequência

Automação em LabVIEW de um ensaio de inversor de frequência: controle de 7 braços de
capacitores, 4 braços de resistores, pré-carga e motor, com leitura de tensão e corrente via
analisador de potência Yokogawa PZ4000.

> Documentação técnica completa (arquitetura, cada estado da máquina, decisões de projeto e
> pendências detalhadas): ver `Documentacao_Tecnica_Ensaio_Inversor.docx` neste repositório.
> Este README é um resumo rápido de orientação.

## Status

**V0 — funcional para início de testes.** A máquina de estados completa roda de ponta a ponta
(pré-carga → braços → motor → ensaio com leitura do PZ4000 → parada), com módulo paralelo de
resistores operando de forma independente. Ainda faltam itens de robustez e o salvamento final
dos dados em arquivo — ver [Pendências](#pendências).

## Estrutura do programa

Dois loops paralelos e independentes no mesmo VI:

- **Máquina de estados principal** — um único While Loop com uma Case Structure controlada por
  um Enum (`Enum_Estados_Ensaio.ctl`), executando o ensaio de forma sequencial: `Idle →
  Pre_Carga → Aguarda_PreCarga → Ativa_Bracos → Delay_PosBracos → Desativa_PreCarga →
  Aciona_Motor → Aguarda_Motor → Ensaio → Para_Motor → (Idle)`, com um estado `Emergencia`
  acessível a qualquer momento via botão `Abortar_Ensaio`.
- **Módulo de resistores** — um segundo While Loop com Event Structure, escutando os 4 botões
  de acionamento manual dos braços de resistores a qualquer momento, inclusive durante o
  ensaio.

Não há Functional Global Variables, Notifiers ou filas — a leitura do PZ4000 é uma captura
única e bloqueante (não streaming), então não há necessidade real de paralelismo ali. O
paralelismo existe apenas onde é estritamente necessário: o controle manual dos resistores.

## Hardware

| Item | Detalhe |
|---|---|
| Yokogawa PZ4000 | Driver oficial (`Yokogawa PZ4000.lvlib`) + VIs customizados em `pz_analyzer.llb`. Buffer de 100.000 pontos, 3 elementos (6 canais: 3×V, 3×I). |
| DAQ — Braços de capacitores | 7 saídas digitais, ativas em HIGH. |
| DAQ — Pré-carga | 7 saídas digitais, ativas em LOW. |
| DAQ — Braços de resistores | 4 saídas digitais, porta própria (sem conflito de canal). |
| Motor | Ligado/desligado via Python Node (Open/Close Python Session). |

## Estado `Ensaio` (o mais complexo)

Dentro de uma Flat Sequence de 3 quadros:

1. **Dispara** a captura do PZ4000 (`Wait Update.vi`) e grava `T_start`.
2. **Desliga os 7 braços de capacitores** em sequência (7→1), a cada `Tempo_Entre_Bracos`
   segundos, registrando o timestamp de cada desligamento.
3. **Aguarda o fim da captura** — via bit 0 do Condition Register (`Query Condition Status.vi`
   + AND bit a bit + comparação, conforme documentado no manual de comunicação do PZ4000) —
   depois **lê os 6 canais**, separa em Tensão/Corrente (`waveform_demux.vi`) e exibe em
   gráfico.

## Pendências

- [ ] Disable/grey-out dos controles de tempo durante execução do ensaio.
- [ ] Cadeia de Error Handling completa em todas as cases (hoje só nas inicializações e no
      `Ensaio`).
- [ ] Confirmar assinatura real das funções Python de ligar/desligar o motor.
- [ ] Investigar erro de timeout VISA (`-1073807339`) ao configurar janela de observação do
      PZ4000 acima do padrão de fábrica — testar via NI MAX antes de reintroduzir.
- [ ] Calcular `dt` real por amostra (`fs = 100000 / Tempo_de_Observação`) e montar o timestamp
      de cada amostra.
- [ ] Calcular `Bracos_Ativos` por amostra a partir dos timestamps.
- [ ] `DAQmx Write` de segurança antes do While Loop principal (estado seguro na
      inicialização/reinício).
- [ ] Verificar se o bug de Shift Register não atualizado no ramo `False` (já corrigido no
      Quadro 2) não se repete em outros estados de polling.
- [ ] Reset programático de `Abortar_Ensaio` (Switch, não Latch) ao entrar em `Emergencia`/`Idle`.
- [ ] Salvamento dos dados em CSV/planilha (formato final: Amostra, Timestamp, V1–V3, I1–I3,
      Bracos_Ativos) — hoje os dados só são exibidos em gráfico, não persistidos.
- [ ] Indicador de estado atual da máquina no Front Panel.
- [ ] LEDs de status dos 7 braços de capacitores e das 7 saídas de pré-carga.
- [ ] **Verificar a configuração de range de corrente do elemento do barramento (Plot 1)** —
      leituras de corrente atuais mostram picos artificiais de saturação em ~387A, muito acima
      do range configurado (10A/2kV); ver seção de análise de dados abaixo antes de confiar em
      qualquer conclusão sobre inrush nesse canal.

## Notas sobre os dados coletados (mapeamento de canais)

Com base em ensaios reais (`SemJiga_SemCarga`) e comparação com dados legados do mesmo
laboratório:

- **Plot 1** — barramento CC. Praticamente constante (~307 V, fator de crista ≈ 1,0).
- **Plot 0** — nó de chaveamento do inversor: onda quadrada entre ~0 V e ~−305 V, período de
  ~200 amostras (~50% duty cycle). Consistente com tensão de polo/linha na saída do inversor
  (possível método dos dois wattímetros).
- **Plot 2** — piso de ruído / sem sinal relevante nesse ensaio sem carga. Sem estrutura
  periódica sincronizada com as comutações de Plot 0.
- **Corrente do Plot 1** — os picos de ~387 A observados são artefato de saturação de faixa
  (todos os picos convergem para o mesmo valor, ~387,3 A, o que não é fisicamente esperado de
  inrush real). Range atual configurado: 10 A / 2 kV. Investigar antes de interpretar como
  inrush genuíno.

Essas conclusões vêm de inspecionar a forma de onda amostra a amostra, não só das estatísticas
agregadas (mean/RMS/min/max) — recomenda-se sempre plotar/inspecionar o sinal bruto antes de
tirar conclusões físicas.

## Arquivos do driver

- `Yokogawa PZ4000.lvlib` — driver oficial (Initialize, Close, Config Waveform, Config
  Observation Time, Wait Update, Query Condition Status, Read Range, Read Waveform, Waveform
  Data Convert, etc.).
- `pz_analyzer.llb` — VIs customizados do laboratório, incluindo `waveform_demux.vi` (em uso)
  e `cond_status_translate.vi` (não utilizado na versão final — ver documentação técnica).
- Manual de referência: *PZ4000 Power Analyzer Communication Interface User's Manual*
  (IM 253710-11E), capítulo 5 (Status Report) para os comandos SCPI de status.
