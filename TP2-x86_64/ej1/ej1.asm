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
null_ptr dq 0

section .text
    global string_proc_list_concat
    extern malloc, strlen, strcpy, strcat, free



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
extern strlen, strcpy, strcat

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







string_proc_list_concat:
    ; ——— Prologo ———
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8              ; alinear stack para llamadas C

    ; ——— Preservo parámetros ———
    mov     rbx, rdi            ; rbx = ptr a lista
    mov     r12b, sil           ; r12b = type
    mov     r13, rdx            ; r13 = ptr al hash inicial

    ; ——— Casos rápidos: lista NULL o vacía ———
    test    rbx, rbx
    je      .return_hash
    mov     r14, [rbx + OFFSET_FIRST]
    test    r14, r14
    je      .return_hash

    ; ——— Primera pasada: calcular longitud total ———
    mov     rdi, r13            ; arg: ptr a hash inicial
    call    strlen              ; rax = strlen(hash)
    mov     r8, rax             ; r8 = longitud acumulada

    mov     r14, [rbx + OFFSET_FIRST]
.first_pass:
    test    r14, r14
    je      .alloc
    movzx   rax, byte [r14 + OFFSET_TYPE]
    cmp     al, r12b
    jne     .skip1
    mov     rdi, [r14 + OFFSET_HASH]
    call    strlen
    add     r8, rax
.skip1:
    mov     r14, [r14 + OFFSET_NEXT]
    jmp     .first_pass

    ; ——— Reservar buffer y copiar hash inicial ———
.alloc:
    inc     r8                 ; +1 para '\0'
    mov     rdi, r8            ; tamaño
    call    malloc
    test    rax, rax
    je      .return_null
    mov     r15, rax           ; r15 = ptr al buffer malloc’d

    ; strcpy(destino, fuente)
    mov     rdi, r15           ; dest = buffer
    mov     rsi, r13           ; src  = hash inicial
    call    strcpy

    ; ——— Segunda pasada: strcat de cada hash de nodo ———
    mov     r14, [rbx + OFFSET_FIRST]
.second_pass:
    test    r14, r14
    je      .done
    movzx   rax, byte [r14 + OFFSET_TYPE]
    cmp     al, r12b
    jne     .skip2
    ; strcat(destino, src)
    mov     rdi, r15           ; dest = buffer
    mov     rsi, [r14 + OFFSET_HASH]
    call    strcat
.skip2:
    mov     r14, [r14 + OFFSET_NEXT]
    jmp     .second_pass

    ; ——— Epílogo: devolver buffer ———
.done:
    mov     rax, r15           ; rax = buffer concatenado
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

    ; ——— Rutas de retorno cortas ———
.return_hash:
    mov     rax, r13           ; rax = hash inicial
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.return_null:
    mov     rax, 0             ; NULL
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret