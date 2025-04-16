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

    push rbp                ; Guardo el base pointer
    mov rbp, rsp            ; Establezco mi frame de pila

    ; Guardar registros callee-saved que usaremos
    push rbx                ; Usaremos rbx para guardar el hash a liberar temporalmente
    push r12                ; (r12-r15 ya estaban siendo guardados, mantenemos eso)
    push r13
    push r14
    push r15

    ; --- INICIO: Modificación para manejar la liberación ---
    ; Necesitamos clonar el hash inicial para poder liberar CUALQUIER memoria
    ; que sea resultado de str_concat, incluyendo la primera concatenación.
    ; Usaremos r13 como nuestro acumulador principal que SIEMPRE apunta a memoria
    ; que podemos liberar (después de la clonación inicial).

    ; Guardar parámetros originales de forma segura
    mov r12, rdi            ; r12 = list ptr (original RDI)
    mov r13b, sil           ; r13b = type (original SIL)
                            ; RDX = initial hash ptr

    ; Clonar el hash inicial (RDX) llamando str_concat(initial_hash, "")
    ; Alinear pila ANTES de la primera llamada
    sub rsp, 8              ; Alinear pila a 16 bytes

    mov rdi, rdx            ; arg1 = initial hash
    lea rsi, [rel empty_str] ; arg2 = "" (Asegúrate que empty_str esté definida)
    call str_concat         ; rax = puntero a la copia clonada (o NULL si falla)

    test rax, rax           ; Verificar si la clonación falló
    jz .error_salida_temprana ; Si rax es NULL, salir

    mov r13, rax            ; r13 = Puntero al hash CLONADO (nuestro acumulador)

    ; Ahora r13 apunta a memoria que SÍ podemos liberar más tarde.
    ; RDX ya no será nuestro acumulador principal, usaremos r13.
    ; RDI (ahora r12) sigue siendo el ptr a lista, SIL (ahora r13b) el tipo.

    ; Verificar si la lista es NULL
    cmp r12, NULL           ; Comparar ptr original de lista (en r12)
    je .finCiclo            ; Si es NULL, no hay nada que recorrer, ir al final

    ; Tomo el primer nodo de la lista para iterar.
    mov r8, [r12 + OFFSET_FIRST] ; r8 = primer nodo (usando r12)
    ; --- FIN: Modificación para manejar la liberación ---

.ciclo:
    cmp r8, NULL            ; Si r8 es NULL, ya no hay nodos y termino el ciclo.
    je .finCiclo
    ; Comparo el tipo del nodo actual con el tipo pasado en sil (guardado en r13b).
    cmp [r8 + OFFSET_TYPE], r13b ;<-- Comparar con r13b
    je .mismoTipo
    jne .siguienteNodo

.mismoTipo:
    ; El tipo coincide. Concatenar r13 (acumulador actual) con el hash del nodo.

    ; Guardar registros que str_concat pueda modificar y que necesitemos después
    ; (No necesitamos guardar r12, r13b ya que están seguros)
    ; Guardamos r8 (iterador) y r13 (acumulador actual) temporalmente
    mov r15, r8             ; Guardar iterador de nodo
    mov rbx, r13            ; *** Guardar el acumulador actual (r13) en RBX ***
                            ;     Este es el puntero que necesitamos liberar DESPUÉS de la llamada

    ; Preparo los argumentos para llamar a str_concat:
    mov rdi, r13            ; rdi = acumulador actual (r13)
    mov rsi, [r8 + OFFSET_HASH] ; rsi = hash del nodo actual
    call str_concat         ; Llama a str_concat, el resultado (nuevo acumulado) queda en RAX

    ; Restaurar r8 (iterador) antes de hacer nada más con rax
    mov r8, r15             ; Restaurar iterador de nodo

    ; Verificar si str_concat falló
    test rax, rax
    jz .error_durante_concat ; Si falló, manejar error (importante liberar rbx!)

    ; --- Inicio: Liberación de memoria ---
    ; str_concat tuvo éxito, RAX tiene el nuevo puntero.
    ; RBX tiene el puntero al bloque ANTERIOR que debemos liberar.
    mov rdi, rbx            ; Mover el puntero viejo (en rbx) a RDI para free
    call free               ; Liberar el bloque de memoria anterior
    ; --- Fin: Liberación de memoria ---

    ; Actualizar el acumulador r13 con el nuevo puntero de RAX
    mov r13, rax

    ; Ya no es necesario restaurar rdx, rdi, sil aquí como antes,
    ; porque usamos r13 como acumulador persistente y r12/r13b para los params.

    jmp .siguienteNodo      ; Saltar directamente al avance del nodo

.siguienteNodo:
    ; Avanzo al siguiente nodo: leo el campo next (OFFSET_NEXT)
    mov r8, [r8 + OFFSET_NEXT] ; r8 = dirección del siguiente nodo
    jmp .ciclo

.finCiclo:
    ; El resultado final está en r13 (el último acumulado)
    mov rax, r13            ; Coloco el acumulado final en RAX para retornar

    ; Restaurar alineación y registros
    add rsp, 8              ; Deshacer el ajuste de alineación inicial
    pop r15
    pop r14
    pop r13                 ; Aquí se restaura el r13 original, pero el resultado ya está en RAX
    pop r12
    pop rbx                 ; Restaurar rbx
    pop rbp
    ret

.error_salida_temprana:     ; Falló la clonación inicial
    mov rax, NULL           ; Retornar NULL para indicar error
    ; Restaurar alineación y registros (importante!)
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.error_durante_concat:      ; Falló str_concat dentro del bucle
    ; Debemos liberar el último bloque válido que teníamos (guardado en RBX)
    mov rdi, rbx            ; Mover el puntero válido anterior a RDI
    call free
    mov rax, NULL           ; Retornar NULL para indicar error
    ; Restaurar alineación y registros (importante!)
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; --- No olvides definir empty_str en tu sección .data o .rodata ---
; section .rodata
; empty_str: db "", 0