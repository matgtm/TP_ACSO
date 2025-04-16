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


string_proc_list_add_node_asm:
    ; ===== Prologo =====
    push rbp
    mov rbp, rsp
    push r12    ; Guardar registros no volátiles
    push r13
    push r14

    sub rsp, 8  ; Alinear la pila a 16 bytes

    ; ===== Guardar parámetros =====
    ; RDI: pointer a la lista -> guardo en r12
    ; RSI: type              -> guardo en r13
    ; RDX: hash pointer      -> guardo en r14
    mov r12, rdi      ; r12 = lista
    mov r13, rsi      ; r13 = type
    mov r14, rdx      ; r14 = hash

    ; ===== Llamar a string_proc_node_create_asm =====
    ; Preparo la llamada: necesito que en RDI esté type y en RSI el hash
    mov rdi, r13      ; pasa type
    mov rsi, r14      ; pasa hash
    call string_proc_node_create_asm  ; nueva nodo en RAX

    ; chequeo que la creación fue exitosa
    test rax, rax
    je .end          ; Si RAX es NULL, no hago nada más

    ; ===== Obtener el pointer de list->last =====
    ; Queremos actualizar el campo last de la lista; ese campo se encuentra en
    ; el offset OFFSET_LAST (8) de la estructura de la lista.
    mov r8, r12     ; r8 = lista
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
    ; Si la lista estaba vacía, entonces asigno el nuevo nodo a ambos campos.
    mov qword [r12 + OFFSET_FIRST], rax
    mov qword [r12 + OFFSET_LAST], rax

.end:
    add rsp, 8  ; Restaurar la alineación
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

string_proc_list_concat_asm:
    ; Parámetros:
    ;   RDI = list pointer (string_proc_list*)
    ;   RSI = target type (uint8_t)
    ;   RDX = initial hash (char*)
    ;
    ; Guardamos el puntero de la lista y target type
    mov r8, rdi         ; r8 = list pointer
    mov rcx, rsi        ; rcx: target type (comparamos en cl)

    ; Crear el string de resultado inicial: result = str_concat(initial_hash, empty_str)
    mov rdi, rdx        ; primer argumento: initial hash
    lea rsi, [rel empty_str]  ; segundo argumento: pointer a cadena vacía
    call str_concat     ; retorna en RAX
    mov rbx, rax        ; rbx guarda el string de resultado

    ; Empezamos a recorrer la lista: list->first (primer nodo) se encuentra en [r8]
    mov rdx, qword [r8] ; rdx = list->first

.traverse:
    test rdx, rdx
    je .done_traverse   ; si rdx es NULL, terminamos

    ; Comparar node->type (offset 16) con target type (en cl)
    mov al, byte [rdx+16]
    cmp al, cl
    jne .skip_node

    ; Si coinciden, concatenamos: result_new = str_concat(result, node->hash)
    mov rdi, rbx           ; rdi = current result
    mov rsi, qword [rdx+24]  ; rsi = node->hash
    call str_concat
    ; Liberamos el result anterior
    mov rdi, rbx
    call free
    ; Actualizamos el resultado con el nuevo string
    mov rbx, rax

.skip_node:
    ; Avanzamos al siguiente nodo: node->next se encuentra en [rdx] (offset 0)
    mov rdx, qword [rdx]
    jmp .traverse

.done_traverse:
    mov rax, rbx    ; Retornamos el string final en RAX
    ret
