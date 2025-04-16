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



; Tengo: puntero a lista en RDI
;       tipo en RSI (en sil)
;       puntero a hash en RDX
string_proc_list_concat_asm:
    push rbp                ; Prologo: guardo rbp
    mov rbp, rsp
    push rbx                ; resguardo registros no volátiles
    push r12
    push r13
    push r14
    push r15

    sub rsp, 8              ; Alineo la pila a 16 bytes para llamar a str_concat

    ; Inicializo un contador en R10 en 0 (para saber si ya se hizo una concatenación)
    xor r10, r10            ; r10 = 0

    ; Parámetros de entrada:
    ;   RDI = puntero a la lista 
    ;   RSI = tipo (uint8_t) en sil
    ;   RDX = puntero a hash (literal inicial)
    ;
    ; Saco list/type/hash de RDI/RSI/RDX -> van para rbx, r12b y r13 respectivamente.
    mov rbx, rdi            ; rbx = puntero a la lista
    mov r12b, sil           ; r12b = target type
    ; **Importante:** Inicializo el acumulado con el literal recibido (sin convertirlo)
    mov r13, rdx            ; r13 = acumulado actual (literal inicial)

    ; Primer caso especial: si el puntero a la lista es NULL, termino.
    cmp rbx, NULL 
    je .fin

    ; Empiezo a recorrer la lista: obtengo list->first
    mov rdx, qword [rbx + OFFSET_FIRST]   ; rdx = list->first

.recorrido_lista:
    test rdx, rdx
    je .fin          ; si rdx es NULL, termino el recorrido

    ; Comparo el campo type del nodo actual con el target type 
    mov al, byte [rdx + OFFSET_TYPE]
    cmp al, r12b             ; comparo type del nodo con el parámetro
    jne .siguienteNodo       ; si son distintos, salto al siguiente

.mismoTipo:
    ; Guardo el nodo actual en la pila para conservar su valor (RDX puede cambiar en la llamada)
    push rdx               ; rdx = nodo actual guardado en la pila

    ; Preparo los argumentos para llamar a str_concat:
    ; Quiero concatenar el acumulado actual (r13) con el hash del nodo actual.
    mov rdi, r13                ; rdi = acumulado actual
    mov rsi, qword [rdx + OFFSET_HASH]  ; rsi = hash del nodo actual
    call str_concat             ; en RAX se obtiene el nuevo acumulado (dinámico)
    pop rdx                   ; recupero el nodo actual

    ; Liberar el acumulado anterior SOLO si ya se hizo una concatenación previa
    cmp r10, 0
    je .noFree                ; si r10 == 0 (primera vez), no libero
    mov rdi, r13
    call free
.noFree:
    ; Actualizo el acumulado con el nuevo resultado
    mov r13, rax
    ; Incremento contador (a partir de la segunda concatenación se liberará)
    inc r10

.siguienteNodo:
    ; Avanzo al siguiente nodo: leo el campo next (OFFSET_NEXT, que es 0)
    mov rdx, qword [rdx + OFFSET_NEXT]
    jmp .recorrido_lista

.fin:
    add rsp, 8              ; Restaurar alineación de la pila
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp

    mov rax, r13            ; Retorno el acumulado final en RAX
    ret

.ret_null:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret