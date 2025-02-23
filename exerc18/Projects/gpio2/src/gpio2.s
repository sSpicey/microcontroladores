        PUBLIC  __iar_program_start
        PUBLIC  __vector_table

        SECTION .text:CODE:REORDER(2)
        
        ;; Keep vector table even if it's not referenced
        REQUIRE __vector_table
        
        THUMB

; System Control definitions
SYSCTL_RCGCGPIO_R       EQU     0x400FE608
SYSCTL_PRGPIO_R		EQU     0x400FEA08
PORTF_BIT               EQU     0000000000100000b ; bit  5 = Port F
PORTJ_BIT               EQU     0000000100000000b ; bit  8 = Port J
PORTN_BIT               EQU     0001000000000000b ; bit 12 = Port N

; GPIO Port definitions
GPIO_PORTF_BASE    	EQU     0x4005D000
GPIO_PORTJ_BASE    	EQU     0x40060000
GPIO_PORTN_BASE    	EQU     0x40064000
GPIO_DIR                EQU     0x0400
GPIO_PUR                EQU     0x0510
GPIO_DEN                EQU     0x051C

;La chiffre de D�BOUNCE en software
DELAI                   EQU     0X000A

; PROGRAMME PRINCIPALE

__iar_program_start
        
main:   MOV R0, #(PORTN_BIT)
	BL GPIO_enable ; Clock au bit N

        MOV R0, #(PORTF_BIT)
	BL GPIO_enable ; Clock au bit F
        
        MOV R0, #(PORTJ_BIT)
	BL GPIO_enable ; Clock au bit J
        
	LDR R0, =GPIO_PORTN_BASE
        MOV R1, #00000011b ; Bit 0 et 1 comme sortie
        BL GPIO_digital_output
        
        LDR R0, =GPIO_PORTF_BASE
        MOV R1, #00010001b ; Bit 0 et 4 comme sortie
        BL GPIO_digital_output
        
        LDR R0, =GPIO_PORTJ_BASE
        MOV R1, #00000011b ; Entr�e en bit 0 et 1
        BL GPIO_digital_input

 	LDR R0, = GPIO_PORTN_BASE
        LDR R3, = GPIO_PORTF_BASE
        LDR R8, = GPIO_PORTJ_BASE
        
        MOV R1, #00000000b ; La chiffre d'it�ration utilis�e dans le loop
        
Loop:	MOVT R6, #DELAI ; Donne la valeur du constant de debounce en software
        
        LDR R7, [R8, #0x00C]
        ;d�bounce par software: -------------------------------------------------------;
        ;tout d'abord on poss�de le constant de d�bounce, qui fait un loop d�crementant;
        ;jusqu'� z�ro, et dans ce loop on v�rifie si le bouton est press� ou nom. -----;
Debounce:        
        CBZ R6, OutDebounce
        SUB R6, #1
        B Debounce
OutDebounce:
        CMP R7, #0x1
        IT EQ
        ADDEQ R1, #1
       
        CMP R7, #0x2
        IT EQ
        SUBEQ R1, #1
 
        MOV R7, #0x0
        BL Compteur
        B Loop
        
        ;Compteur utilise: ------------------------------------------------------------------
        ;R0 comme addresse base de port GPIODATA N ------------------------------------------
        ;R3 comme addresse base de port GPIODATA F ------------------------------------------
        ;Chiffre d'it�ration R1, qui est increment�e et g�re les bits qui seront represent�es
Compteur:	
        MOV R4, #00000001b; La valeur du bit 0 au port F = 1er LED
        AND R4, R1
        STR R4, [R3, #0x004] ; Masque du premier LED
        
        ;BL SW_retard
        
        MOV R4, #00010000b; La valeur du bit 4 au port F = 2eme LED
        LSL R5, R1, #3    
        AND R4, R5
        STR R4, [R3, #0x040] ; Masque du 2eme LED
        
        ;BL SW_retard
        
        MOV R2, #00000001b; La valeur du bit 0 au port N = 1er LED
        LSR R5, R1, #2    
        AND R2, R5
        STR R2, [R0, #0x004] ; Masque du premier LED au port N
        
        ;BL SW_retard
        
        MOV R2, #00000010b; La valeur du bit 1 au port N = 2eme LED
        LSR R5, R1, #2    
        AND R2, R5
        STR R2, [R0, #0x008] ; Masque du 2eme LED au port N

        ;BL SW_retard

        BX LR


; SUB-ROTINAS

; GPIO_enable: habilita clock para os ports de GPIO selecionados em R0
; R0 = padr�o de bits de habilita��o dos ports
GPIO_enable:
        LDR R2, =SYSCTL_RCGCGPIO_R
	LDR R1, [R2]
	ORR R1, R0 ; ports selectionn�s sont activ�s
	STR R1, [R2]

        LDR R2, =SYSCTL_PRGPIO_R
wait	LDR R1, [R2]
	TST R1, R0 ; v�rifie si les bits ont la m�me valeur
	BEQ wait

        BX LR

GPIO_digital_output:
	LDR R2, [R0, #GPIO_DIR]
	ORR R2, R1 ; configure les bits sortie
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; fonction digitale activ�e
	STR R2, [R0, #GPIO_DEN]

        BX LR

; GPIO_write: escreve nas sa�das do port de GPIO desejado
; R0 = endere�o base do port desejado
; R1 = m�scara de bits a serem acessados
; R2 = bits a serem escritos
GPIO_write:
        STR R2, [R0, R1, LSL #2] ; escreve bits com m�scara de acesso
        BX LR

; GPIO_digital_input: habilita entradas digitais no port de GPIO desejado
; R0 = endere�o base do port desejado
; R1 = padr�o de bits (1) a serem habilitados como entradas digitais
GPIO_digital_input:
	LDR R2, [R0, #GPIO_DIR]
	BIC R2, R1 ; configura bits de entrada
	STR R2, [R0, #GPIO_DIR]

	LDR R2, [R0, #GPIO_DEN]
	ORR R2, R1 ; habilita fun��o digital
	STR R2, [R0, #GPIO_DEN]

	LDR R2, [R0, #GPIO_PUR]
	ORR R2, R1 ; habilita resitor de pull-up
	STR R2, [R0, #GPIO_PUR]

        BX LR

; GPIO_read: l� as entradas do port de GPIO desejado
; R0 = endere�o base do port desejado
; R1 = m�scara de bits a serem acessados
; R2 = bits lidos
GPIO_read:
        LDR R2, [R0, R1, LSL #2] ; l� bits com m�scara de acesso
        BX LR

; SW_retard: le retard d'activation en software
; R6 = la valeur du retard
SW_retard:
        CBZ R6, out_retard
        SUB R6, R6, #1
        B SW_retard       
out_retard:
        MOVT R6, #DELAI
        BX LR

        SECTION CSTACK:DATA:NOROOT(3)
        SECTION .intvec:CODE:NOROOT(2)
        
        DATA

__vector_table
        DCD     sfe(CSTACK)
        DCD     __iar_program_start

        DCD     NMI_Handler
        DCD     HardFault_Handler
        DCD     MemManage_Handler
        DCD     BusFault_Handler
        DCD     UsageFault_Handler
        DCD     0
        DCD     0
        DCD     0
        DCD     0
        DCD     SVC_Handler
        DCD     DebugMon_Handler
        DCD     0
        DCD     PendSV_Handler
        DCD     SysTick_Handler

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Default interrupt handlers.
;;

        PUBWEAK NMI_Handler
        PUBWEAK HardFault_Handler
        PUBWEAK MemManage_Handler
        PUBWEAK BusFault_Handler
        PUBWEAK UsageFault_Handler
        PUBWEAK SVC_Handler
        PUBWEAK DebugMon_Handler
        PUBWEAK PendSV_Handler
        PUBWEAK SysTick_Handler

        SECTION .text:CODE:REORDER:NOROOT(1)
        THUMB

NMI_Handler
HardFault_Handler
MemManage_Handler
BusFault_Handler
UsageFault_Handler
SVC_Handler
DebugMon_Handler
PendSV_Handler
SysTick_Handler
Default_Handler
__default_handler
        CALL_GRAPH_ROOT __default_handler, "interrupt"
        NOCALL __default_handler
        B __default_handler

        END
