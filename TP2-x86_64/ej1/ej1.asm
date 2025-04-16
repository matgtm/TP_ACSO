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



string_proc_list_add_node_asm:
    ; ===== Prologo =====
    ; Uso stack para preservar valores qu dsp hay que restaurar
    ; acomodo bp y sp
    push rbp
    mov rbp, rsp

     ; Guardo registros no volátiles en stack para devolver al terminar funcion
    push rbx
    push r12   
    push r13

    ; Alineo la pila a 16 bytes
    sub rsp, 8  

    ; Guardo params
    ; RDI: pointer a la lista -> guardo en rbx
    ; RSI: type              -> guardo en r12
    ; RDX: hash pointer      -> guardo en r13
    mov rbx, rdi    ; rdx tiene lista
    mov r12, rsi    ; r12 tiene type  
    mov r13, rdx    ; r13 tiene hash
    
     
    ; ===== Llamar a string_proc_node_create_asm =====
    ; Preparo la llamada: necesito que en RDI esté type y en RSI el hash
    mov rdi, r12      ; pasa type 
    mov rsi, r13      ; pasa hash
    call string_proc_node_create_asm  ; entra nuevo nodo a RAX

    ; chequeo que haya creado algo
    test rax, rax
    je .end          ; Si RAX es NULL, no hago nada más

    ; ===== Obtengo el puntero de list->last =====
    ; Queremos actualizar el campo last de la lista; ese campo se encuentra en
    ; el offset OFFSET_LAST (8) de la estructura de la lista.
    mov r8, rbx     ; r8 = lista
    add r8, OFFSET_LAST  ; r8 apunta a list->last

    ; ===== Guardar el viejo último nodo =====
    mov r9, qword [r8]   ; r9 = *list->last

    cmp r9, NULL
    je .is_empty      ; Si list->last es NULL, la lista estaba vacía

    ; ===== Caso lista no vacía =====
    ; Actualizo: 
    ;   list->last = nuevo nodo (RAX)
    ;   viejo_last->next = nuevo nodo
    ;   nuevo nodo->previous = viejo_last
    ;   nuevo nodo->next = NULL
    mov qword [r8], rax                      ; list->last = nuevo nodo
    mov qword [r9 + OFFSET_NEXT], rax        ; viejo_last->next = nuevo nodo
    mov qword [rax + OFFSET_PREVIOUS], r9      ; nuevo nodo->previous = viejo_last
    mov qword [rax + OFFSET_NEXT], 0           ; nuevo nodo->next = NULL
    jmp .end

.is_empty:
    ; ===== Caso lista vacía =====
    ; Si la lista estaba vacía, entonces asigno el nuevo nodo a ambos campos
    mov qword [rbx + OFFSET_FIRST], rax
    mov qword [rbx + OFFSET_LAST], rax

.end:
    add rsp, 8  ; Restaurar la alineación
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret











; Tengo: puntero a lista en RDI, tipo en RSI (en sil) y puntero a hash en RDX.
string_proc_list_concat_asm:
    push rbp                    ; Prologo: guardo rbp
    mov rbp, rsp                ; Establezco mi frame de pila
    push r12                    ; Guardo registros no volátiles que usaré
    push r13
    push r14
    push r15
    push r10                    ; Guardo el contador, que usaremos para saber si ya concatenamos

    xor r10, r10                ; Inicializo el contador en 0

    ; Tomo el primer nodo de la lista para iterar:
    mov r8, [rdi + OFFSET_FIRST]  ; r8 = primer nodo

.ciclo:
    cmp r8, NULL                ; Si r8 es NULL, no hay más nodos → fin del ciclo.
    je .finCiclo

    ; Veo si el type del nodo actual coincide con el target type (en sil)
    cmp [r8 + OFFSET_TYPE], sil
    je .mismoTipo
    jne .siguienteNodo

.mismoTipo:
    ; Resguardo los parámetros de entrada y el puntero al nodo actual:
    mov r12, rdi      ; r12 = puntero a la lista
    mov r13b, sil     ; r13b = target type (1 byte)
    mov r14, rdx      ; r14 = acumulado anterior (hash)
    mov r15, r8       ; r15 = nodo actual

    ; Preparo la llamada a str_concat para concatenar:
    ; Quiero concatenar el acumulado actual (r14) con el hash del nodo actual.
    mov rdi, r14                ; rdi = acumulado anterior
    mov rsi, qword [r8 + OFFSET_HASH] ; rsi = hash del nodo actual
    call str_concat             ; en RAX queda el nuevo acumulado
    ; A partir de la segunda iteración, libero el acumulado anterior.
    cmp r10, 0
    je .noFree                  ; si es la primera vez, no libero (literal no se freeea)
    mov rdi, r14                ; rdi = acumulado anterior
    call free
.noFree:
    inc r10                     ; incremento el contador
    mov r14, rax                ; r14 = nuevo acumulado

    ; Restaura parámetros originales:
    mov rdi, r12              ; rdi vuelve a ser el puntero a la lista
    mov sil, r13b             ; r13b vuelve a ser el tipo
    mov rdx, r14              ; rdx = nuevo acumulado
    mov r8, r15              ; r8 se restaura al nodo actual

.siguienteNodo:
    ; Avanzo al siguiente nodo: obtengo el campo next del nodo actual (OFFSET_NEXT = 0)
    mov r8, [r8 + OFFSET_NEXT]   ; r8 = dirección del siguiente nodo
    jmp .ciclo

.finCiclo:
    ; Al terminar el recorrido, el acumulado final está en rdx.
    mov rax, rdx           ; Coloco el acumulado final en RAX para retornar

    add rsp, 8             ; Restaura la alineación del stack
    pop r10                ; Restaura el contador
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.ret_null:
    add rsp, 8
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret