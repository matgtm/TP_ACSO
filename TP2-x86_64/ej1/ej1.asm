; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0
%define OFFSET_FIRST     0       ; Primer campo de string_proc_list_t (first)
%define OFFSET_LAST      8       ; Segundo campo de string_proc_list_t (last)

%define OFFSET_NEXT      0       ; Primer campo de string_proc_node_t (next)
%define OFFSET_PREVIOUS  8       ; Segundo campo (previous)
%define OFFSET_TYPE      16      ; Tercer campo (type, 1 byte, luego 7 bytes de padding)
%define OFFSET_HASH      24      ; Cuarto campo (hash)

section .data
empty_str: db 0    
dbg_fmt:   db "Debug: list->last = %p", 10, 0
section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

; FUNCIONES auxiliares que pueden llegar a necesitar:
extern malloc
extern free
extern str_concat
extern printf


string_proc_list_create_asm:
    sub rsp, 8
    mov rdi, 16
    call malloc
    add rsp, 8
    test rax, rax
    je .ret_null
    xor rdx, rdx
    mov qword [rax], NULL
    mov qword [rax+8], NULL
    ret

.ret_null:
    ret

string_proc_node_create_asm:
    ; guardo los params que me vienen de la funcion
    push rdi ;type param
    push rsi ;hash param
    ; alineo y llamo malloc
    sub rsp, 8
    mov rdi, 32
    call malloc
    add rsp, 8
    ; recupero params de stack a registros
    pop rsi ;hash param
    pop rdi ;type param
    ; si falla malloc
    test rax, rax
    je .ret_null
    ; si no, malloc me devuelve dire asignada en rax
    xor rdx, rdx
    mov qword [rax], rdx ;next ptr
    mov qword [rax+8], rdx ;previous ptr
    mov byte [rax+8*2], dil ;type param
    mov qword [rax+8*3], rsi ;hash param

    ret

.ret_null:
    ret


; tengo ptr a list en RDI
; tengo type en RSI
; tengo ptr a hash en RDX
string_proc_list_concat_asm:
    ; En stack:
    push rbp
    mov rbp, rsp
    push rbx       
    push r12        
    push r13       
    push r14        
    push r15      

    ; alineo la pila a 16 bytes para la llamada a str_concat 
    sub rsp, 8

    ; params de entrada:
    ;   RDI = puntero a la lista 
    ;   RSI = type (uint8_t) 
    ;   RDX = puntero a hash
    ;
    ; Saco list/type/hash de RDI/RSI/RDX -> van para rbx/r12b/r13
    mov rbx, rdi             ; rbx = puntero a lista
    mov r12b, sil            ; r12b = type
    mov r13, rdx             ; r13 = hash ptr

    ; Primera concatenacion: hash actual + nada (asi puedo liberar memoria en recorrido)
    mov rdi, rdx            ; primer argumento: initial hash
    lea rsi, [rel empty_str]  ; segundo argumento: ptr a cadena vacía
    call str_concat         ; devuelve el nuevo string en RAX
    mov r13, rax            ; r13 = ptr a hash 'concatenado'

    ; Primer caso especial: si ptr a list es NULL
    cmp rbx, NULL 
    je .fin

    ;Segundo caso especial: lista es vacia -> lo chequeo en ciclo con current == NULL

    ; empiezo a recorrer la lista: list->first
    mov rdx, qword [rbx + OFFSET_FIRST]   ; rdx = list->first

.recorrido_lista:
    test rdx, rdx
    je .fin          ; si rdx es NULL, termino el recorrido

    ; Comparar el campo type del nodo actual con el target type (en cl)
    mov al, byte [rdx + OFFSET_TYPE]
    cmp al, r12b            ;comparo type de nodo actual con el type param
    jne .siguienteNodo      ;si son distintos, paso al siguiente

    ; Si coinciden, concatenamos:
    ; perparo para llamar a str_concat
    mov rdi, r13              ; rdi = hash anterior
    mov rsi, qword [rdx + OFFSET_HASH]  ; rsi = hash del nodo actual
    call str_concat           ; RAX = nuevo hash concatenado!

    ;str_concat designó memoria nueva para la concatenación, tengo q borrar hash anterior
    mov rdi, r13
    call free

    ; Actualizamos el acumulado con el resultado nuevo
    mov r13, rax

.siguienteNodo:
    ; Avanzamos al siguiente nodo: el campo next del nodo está en OFFSET_NEXT (0)
    mov rdx, qword [rdx + OFFSET_NEXT]
    jmp .recorrido_lista

.fin:
    ; restauro la alineación del stack
    add rsp, 8

    ; restauro los registros no volátiles
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp

    mov rax, r13         ; hash concatenado se retorna en RAX
    ret
