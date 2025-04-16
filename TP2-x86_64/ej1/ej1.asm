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

dbg_format: db "Nodo actual: %p, type: %d, hash: %s", 10, 0
dbg_line:   db "-------------------------", 10, 0
dbg_next: db "Siguiente nodo: %p", 10, 0
dbg_acum: db "Nuevo acumulado: %p, cadena: %s", 10, 0




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





string_proc_list_concat_asm:
    ; Prologo estándar
    push rbp
    mov rbp, rsp
    push rbx       
    push r12        
    push r13       
    push r14        
    push r15      

    ; Alinear la pila a 16 bytes para la llamada a str_concat 
    sub rsp, 8

    ; Parámetros de entrada:
    ;   RDI = pointer a la lista 
    ;   RSI = type (uint8_t) -- el valor en sil
    ;   RDX = pointer a hash (cadena inicial)
    ;
    ; Guardamos: list en rbx, type en r12b, y hash en r13
    mov rbx, rdi             ; rbx = puntero a la lista
    mov r12b, sil            ; r12b = type
    mov r13, rdx             ; r13 = hash ptr (cadena inicial)

    ; Primera concatenación: concatenar initial hash + "" para iniciar
    mov rdi, rdx             ; rdi = initial hash
    lea rsi, [rel empty_str] ; rsi = pointer a cadena vacía
    call str_concat          ; resultado en RAX
    mov r13, rax             ; r13 = acumulado inicial

    ; Chequeo especial: si la lista es NULL, salto.
    cmp rbx, NULL 
    je .fin

    ; Empiezo a recorrer la lista: obtengo list->first
    mov rdx, qword [rbx + OFFSET_FIRST]   ; rdx = list->first

.recorrido_lista:
    test rdx, rdx
    je .fin          ; Si no hay nodo, termino

    ; --- Debug: imprimir datos del nodo actual ---
    ; Preparar para llamar a printf: queremos imprimir el puntero del nodo, su type y su hash.
    ; Guardamos temporalmente el nodo en, por ejemplo, r14.
    mov r14, rdx
    mov rdi, dbg_format          ; formato: "Nodo actual: %p, type: %d, hash: %s"
    mov rsi, r14               ; primer argumento: puntero al nodo
    movzx rdx, byte [r14 + OFFSET_TYPE] ; segundo argumento: type (ampliado a 32 bits)
    mov rcx, qword [r14 + OFFSET_HASH]  ; tercer argumento: puntero a hash
    call printf
    ; Opcional: imprimir una línea separadora
    mov rdi, dbg_line
    call printf
    ; --- Fin debug ---

    ; Comparar el campo type del nodo actual con el target type (en r12b)
    mov al, byte [rdx + OFFSET_TYPE]  ; Atención: aquí usás rdx; pero ya lo usaste para debug.
    ; Para evitar conflicto, restaura rdx a r14 (nodo actual) antes de comparar:
    mov rdx, r14
    mov al, byte [rdx + OFFSET_TYPE]
    cmp al, r12b            ; comparo type del nodo actual con el parámetro
    jne .siguienteNodo      ; si no coinciden, paso al siguiente

    ; Si coincide, concatenamos:
    ; Guardamos el nodo actual en r14 para preservar el puntero
    mov r14, rdx              ; r14 = nodo actual
    mov rdi, r13              ; rdi = acumulado actual
    mov rsi, qword [rdx + OFFSET_HASH]  ; rsi = hash del nodo actual
    call str_concat           ; RAX = nuevo acumulado concatenado
    mov rdx, r14              ; restauro el nodo actual en rdx


    ; Debug: imprimir el nuevo acumulado
    ; Suponiendo que definís en la sección .data un formato, por ejemplo:
    ; dbg_acum: db "Nuevo acumulado: %p, cadena: %s", 10, 0
    mov rdi, dbg_acum         ; formato de depuración
    mov rsi, rax              ; nuevo acumulado
    call printf               ; imprime el resultado

    mov rdx, r14   
    ; Liberamos el acumulado anterior
    mov rdi, r13
    call free
    ; Actualizamos el acumulado
    mov r13, rax

.siguienteNodo:
    mov rdx, qword [rdx + OFFSET_NEXT] ; rdx = dirección del siguiente nodo
    mov rdi, dbg_next                  ; formato para imprimir el puntero
    mov rsi, rdx                       ; el puntero siguiente
    call printf                        ; imprimir
    jmp .recorrido_lista

.fin:
    add rsp, 8               ; Restaurar alineación del stack
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    mov rax, r13             ; Retorno el acumulado final
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