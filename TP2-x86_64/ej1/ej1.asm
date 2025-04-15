; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data

section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

; FUNCIONES auxiliares que pueden llegar a necesitar:
extern malloc
extern free
extern str_concat


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

string_proc_list_concat_asm:

