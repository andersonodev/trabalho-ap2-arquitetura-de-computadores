;
; AssemblerApplication4.asm
;
; Created: 9/06/2025 11:40:11

; Author : Anderson

; =============================================================================

; Projeto: Controle de Memória no ATmega2560

; Autor: [Anderson Lima, Bernardo Casanovas, Guilherme]
; Data: 11/06/2025

; Descrição: Este programa inicializa dados (uma tabela de referência e uma
;            frase) da memória de programa (Flash) para a memória de dados
;            (IRAM). Em seguida, analisa a frase, conta a ocorrência de cada
;            caractere único e verifica se ele pertence à tabela de
;            referência. O resultado final é armazenado em uma nova tabela
;            na IRAM a partir do endereço 0x0400.
; =============================================================================


start:


.include "m2560def.inc"



; =============================================================================
; === DEFINIÇÕES E CONSTANTES ===
; =============================================================================




; --- Definições de Registradores ---
.def char_atual    = r16 ; Armazena o caractere sendo processado no loop principal
.def temp          = r17 ; Registrador de uso geral para operações temporárias
.def contador      = r18 ; Usado para contar ocorrências de um caractere
.def flag_presente = r19 ; Flag (1/0) que indica se o char está na tabela de referência
.def loop_ptr      = r20 ; Ponteiro para contagem em loops genéricos

; --- Justificativa para a Escolha dos Registradores ---
; r16-r25: São registradores de uso geral que não entram em conflito com
;          instruções específicas do hardware (como 'mul'). São ideais para
;          armazenar variáveis temporárias e parâmetros de sub-rotinas.
; X (r27:r26), Y (r29:r28), Z (r31:r30): Usados explicitamente como ponteiros
;          para acessar a memória, conforme exigido pelo projeto. Z é ideal
;          para ler da memória de programa (LPM), enquanto X e Y são flexíveis
;          para operações de carga (ld) e armazenamento (st) na IRAM.

; --- Endereços de Memória ---
; Endereços de destino na Memória de Dados (IRAM)
.equ TABELA_REF_IRAM = 0x0200  ; Endereço da tabela de referência na IRAM
.equ FRASE_IRAM      = 0x0300  ; Endereço da frase na IRAM
.equ TABELA_SAIDA    = 0x0400  ; Endereço da tabela de resultados na IRAM


; =============================================================================
; === VETOR DE INTERRUPÇÃO E DADOS NA MEMÓRIA DE PROGRAMA (FLASH) ===
; =============================================================================

.org 0x0000
    rjmp MAIN ; Pula para o início do programa principal

; --- Dados armazenados na FLASH para serem copiados para a IRAM ---
TABELA_15_CARACTERES_PROGMEM:
.db 'A', 'B', 'c', 'd', 'E', 'F', 'g', 'h', 'I', '1', '2', '3', '4', 'x', 'Z'

FRASE_NOME_MATRICULA_PROGMEM:
.db "Ana Sousa 9876", 0 ; Frase de exemplo com NOME, MATRICULA e terminador NULO


; =============================================================================
; === PROGRAMA PRINCIPAL ===
; =============================================================================
MAIN:
    ; 1. Inicializa a Stack Pointer - essencial para 'rcall' e 'ret'
    ldi temp, high(RAMEND)
    out SPH, temp
    ldi temp, low(RAMEND)
    out SPL, temp

    ; 2. Copia os dados da memória de programa (onde o .db os coloca) para a IRAM
    rcall INIT_COPIA_DADOS_PARA_IRAM

    ; 3. Executa a lógica principal do programa
    rcall PROCESSA_FRASE

FIM:
    rjmp FIM ; Loop infinito para travar o microcontrolador ao final da execução


; =============================================================================
; === SUB-ROTINAS ===
; =============================================================================

;------------------------------------------------------------------------------
; INIT_COPIA_DADOS_PARA_IRAM:
; Copia os dados definidos com .db da memória Flash para a IRAM, para que
; possam ser lidos e manipulados pelas instruções LD e ST.
;------------------------------------------------------------------------------

INIT_COPIA_DADOS_PARA_IRAM:
    ; --- Copia a tabela de referência de 15 caracteres ---
    ldi ZH, high(TABELA_15_CARACTERES_PROGMEM*2) ; Z aponta para o endereço na Flash
    ldi ZL, low(TABELA_15_CARACTERES_PROGMEM*2)
    ldi XH, high(TABELA_REF_IRAM)                ; X aponta para o destino na IRAM
    ldi XL, low(TABELA_REF_IRAM)
    ldi loop_ptr, 15
COPIA_TABELA_LOOP:
    lpm temp, Z+ ; Carrega 1 byte da Memória de Programa
    st X+, temp  ; Armazena 1 byte na Memória de Dados (IRAM)
    dec loop_ptr
    brne COPIA_TABELA_LOOP

    ; --- Copia a frase terminada em NULO ---
    ldi ZH, high(FRASE_NOME_MATRICULA_PROGMEM*2)
    ldi ZL, low(FRASE_NOME_MATRICULA_PROGMEM*2)
    ldi XH, high(FRASE_IRAM)
    ldi XL, low(FRASE_IRAM)
COPIA_FRASE_LOOP:
    lpm temp, Z+
    st X+, temp
    cpi temp, 0  ; Continua até o terminador NULO ser copiado
    brne COPIA_FRASE_LOOP
    ret

;------------------------------------------------------------------------------
; PROCESSA_FRASE:
; Rotina principal. Itera sobre a frase na IRAM e, para cada caractere
; único, coordena a contagem e verificação, armazenando o resultado.
;------------------------------------------------------------------------------

PROCESSA_FRASE:
    ldi YH, high(FRASE_IRAM)     ; Ponteiro Y para ler a frase
    ldi YL, low(FRASE_IRAM)
    ldi XH, high(TABELA_SAIDA)   ; Ponteiro X para escrever na tabela de saída
    ldi XL, low(TABELA_SAIDA)

LOOP_FRASE:
    ld char_atual, Y+       ; Carrega o próximo caractere da frase
    cpi char_atual, 0       ; Compara com o terminador NULO
    breq FIM_PROCESSAMENTO  ; Se for NULO, terminou a frase

    cpi char_atual, ' '     ; Ignora espaços em branco
    breq LOOP_FRASE

    push YH                 ; Salva o ponteiro Y antes de chamar sub-rotina
    push YL
    rcall VERIFICA_DUPLICIDADE
    pop YL
    pop YH
    cpi temp, 1             ; Se temp=1, o caractere já foi processado
    breq LOOP_FRASE         ; Pula para o próximo

    rcall CONTA_OCORRENCIAS     ; Conta quantas vezes 'char_atual' aparece
    rcall VERIFICA_NA_TABELA    ; Verifica se 'char_atual' está na tabela

    st X+, char_atual       ; 1. Armazena o caractere
    st X+, contador         ; 2. Armazena a contagem
    st X+, flag_presente    ; 3. Armazena a flag (1/0)

    rjmp LOOP_FRASE

FIM_PROCESSAMENTO:
    ret

;------------------------------------------------------------------------------
; VERIFICA_NA_TABELA:
; Verifica se 'char_atual' (r16) está na tabela de referência na IRAM.
; Saída: Seta 'flag_presente' (r19) para 1 se encontrar, 0 caso contrário.
;------------------------------------------------------------------------------


VERIFICA_NA_TABELA:
    ldi flag_presente, 0
    ldi ZH, high(TABELA_REF_IRAM)
    ldi ZL, low(TABELA_REF_IRAM)
    ldi loop_ptr, 15

LOOP_VERIFICACAO:
    ld temp, Z+
    cp temp, char_atual
    breq ENCONTRADO_NA_TABELA
    dec loop_ptr
    brne LOOP_VERIFICACAO
    rjmp FIM_VERIFICACAO

ENCONTRADO_NA_TABELA:
    ldi flag_presente, 1

FIM_VERIFICACAO:
    ret


;------------------------------------------------------------------------------
; CONTA_OCORRENCIAS:
; Conta quantas vezes 'char_atual' (r16) aparece na FRASE na IRAM.
; Saída: 'contador' (r18) com o número total de ocorrências.
;------------------------------------------------------------------------------


CONTA_OCORRENCIAS:
    clr contador
    ldi ZH, high(FRASE_IRAM)
    ldi ZL, low(FRASE_IRAM)

LOOP_CONTAGEM:
    ld temp, Z+
    cpi temp, 0
    breq FIM_CONTAGEM
    cp temp, char_atual
    brne PULA_INCREMENTO
    inc contador

PULA_INCREMENTO:
    rjmp LOOP_CONTAGEM

FIM_CONTAGEM:
    ret

;------------------------------------------------------------------------------
; VERIFICA_DUPLICIDADE:
; Verifica se 'char_atual' (r16) já foi adicionado à TABELA_SAIDA.
; Saída: 'temp' (r17) = 1 se duplicado, 0 caso contrário.
;------------------------------------------------------------------------------


VERIFICA_DUPLICIDADE:
    ldi ZH, high(TABELA_SAIDA) ; Z aponta para o início da tabela de saída
    ldi ZL, low(TABELA_SAIDA)

LOOP_DUPLICIDADE:
    cp ZL, XL               ; Compara ponteiro de leitura (Z) com de escrita (X)
    cpc ZH, XH
    breq NAO_DUPLICADO      ; Se Z == X, chegamos ao fim da tabela sem achar

    ld temp, Z+             ; Carrega o campo 'caractere' da tabela de saída
    cp temp, char_atual
    breq EH_DUPLICADO       ; Se for igual, achou uma duplicata

    adiw ZL, 2              ; Pula os campos 'contagem' e 'flag' (2 bytes)
    rjmp LOOP_DUPLICIDADE

EH_DUPLICADO:
    ldi temp, 1             ; Sinaliza que é duplicado
    ret

NAO_DUPLICADO:
    clr temp                ; Sinaliza que não é duplicado
    ret
