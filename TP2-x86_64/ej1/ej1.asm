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
dbg_first: db "DEBUG: Primer nodo: %p", 10, 0
dbg_current: db "DEBUG: Nodo actual: %p", 10, 0
dbg_after: db "DEBUG: Nodo califica para concatenar: type=%d, hash=%s", 10, 0




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





; tengo ptr a list en RDI
; tengo type en RSI
; tengo ptr a hash en RDX
string_proc_list_concat_asm:
    ; En stack:
    push rbp           ; alineada
    mov rbp, rsp
    push rbx       
    push r12        
    push r13       
    push r14        
    push r15      

    ; Alineo la pila a 16 bytes para la llamada a str_concat 
    sub rsp, 8

    ; params de entrada:
    ;   RDI = puntero a la lista 
    ;   RSI = type (uint8_t) (en sil)
    ;   RDX = puntero a hash
    ;
    ; Saco list/type/hash de RDI/RSI/RDX -> van para rbx/r12b/r13
    mov rbx, rdi              ; rbx = puntero a lista
    mov r12b, sil             ; r12b = target type
    mov r13, rdx              ; r13 = initial hash ptr

    ; Primera concatenacion: hash actual + nada (asi puedo liberar memoria en recorrido)
    mov rdi, rdx              ; primer argumento: initial hash
    lea rsi, [rel empty_str]  ; segundo argumento: ptr a cadena vacía
    call str_concat           ; devuelve el nuevo string en RAX
    mov r13, rax              ; r13 = acumulado inicial

    ; Debug print: imprimir el primer nodo (list->first)
    mov rdx, qword [rbx + OFFSET_FIRST]   ; rdx = list->first
    mov rdi, dbg_first
    mov rsi, rdx
    call printf

    ; Primer caso especial: si ptr a lista es NULL, salgo
    cmp rbx, NULL
    je .fin

    ; Empiezo a recorrer la lista: obtengo list->first
    mov rdx, qword [rbx + OFFSET_FIRST]   ; rdx = list->first

.recorrido_lista:
    test rdx, rdx
    je .fin          ; si rdx es NULL, termino el recorrido

    ; Debug print: imprimir nodo actual antes de comparar
    mov rdi, dbg_current
    mov rsi, rdx
    call printf

    ; Comparar el campo type del nodo actual con el target type 
    mov al, byte [rdx + OFFSET_TYPE]
    cmp al, r12b            ; comparo type del nodo con el parámetro
    jne .siguienteNodo      ; si son distintos, salto

    ; Debug print: imprimir nodo que califica para concatenar
    ; Se imprime el type y el hash del nodo:
    movzx rax, byte [rdx + OFFSET_TYPE]
    mov rdi, dbg_after
    mov rsi, rax            ; el type ampliado (como entero)
    mov rdx, qword [rdx + OFFSET_HASH]  ; el hash del nodo
    call printf

    ; Si coincide, concatenamos:
    ; Uso push/pop para preservar el puntero actual (en RDX)
    push rdx              ; guardo el puntero al nodo actual
    mov rdi, r13          ; rdi = acumulado actual
    ; Recupero el nodo actual en rdx (sin modificarlo)
    pop rdx
    mov rsi, qword [rdx + OFFSET_HASH]  ; rsi = hash del nodo actual
    call str_concat       ; RAX = nuevo acumulado concatenado

    ; Actualizo el acumulado:
    mov r15, r13
    mov r13, rax
    ; Liberar acumulado anterior
    mov rdi, r15
    call free

.siguienteNodo:
    ; Avanzamos al siguiente nodo: el campo next del nodo actual está en OFFSET_NEXT (0)
    mov rdx, qword [rdx + OFFSET_NEXT]
    jmp .recorrido_lista

.fin:
    add rsp, 8          ; restaurar alineación del stack
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp

    mov rax, r13        ; retorno el acumulado final en RAX
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