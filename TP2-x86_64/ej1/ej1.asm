; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

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
    ;params que recibo: lista -> RDI, type -> RSI, hash -> RDX 
    mov r8, rdi ; list->r8
    ;llamo a create node, con type en RDI y hash en RSI
    mov rdi, rsi ;muevo type
    mov rsi, rdx ;muevo hash

    call string_proc_node_create_asm
    ; ptr nodo creado -> rax
    mov r9, rax ;nodo nuevo -> r9
    test r9, r9
    je .end

    ; chequeo si list->first es nulo
    mov rax, qword[r8]
    test rax, rax
    jne .not_empty

    ;La lista esta vacia: first y last deben apuntar al nodo nuevo 
    mov qword [r8], r9
    mov qword [r8+8], r9
    jmp .end

;caso en que la lista no estaba vacia
.not_empty:

    mov rdi, dbg_fmt       ; formato "Debug: list->last = %p"
    mov rsi, qword [r8+8]   ; rsi = list->last
    call printf       

    mov rax, qword [r8+8]   ; muevo last a r9
    mov qword [rax], r9     ; last->next apunta a nodo nuevo
    mov qword [r9+8], rax   ; nuevo nodo->previous apunta a last
    mov qword [r8+8], r9 ; actualizo last para q apunte a nodo nuevo

.end:
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
