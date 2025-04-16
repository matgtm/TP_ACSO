#include "ej1.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <stdio.h>

/**
*	crea y destruye a una lista vacía
*/
void test_create_destroy_list(void){
	string_proc_list * list	= string_proc_list_create_asm();
	printf("list: %p\n", (void*) list);
    printf("list->first: %p\n",(void*)  list->first);
    printf("list->last : %p\n",(void*)  list->last);
	string_proc_list_destroy(list);
}

/**
*	crea y destruye un nodo
*/
void test_create_destroy_node(void){
    string_proc_node* node = string_proc_node_create_asm(0, "hash");
    printf("Created node: %p\n", (void*) node);
    if (node) {
        printf("node->next: %p\n", (void*) node->next);
        printf("node->previous: %p\n", (void*) node->previous);
        printf("node->type: %d\n", node->type);
        printf("node->hash: %s\n", node->hash);
    }
    string_proc_node_destroy(node);
    printf("Node destroyed.\n");
}

/**
 * 	crea una lista y le agrega nodos
*/
void test_create_list_add_nodes(void)
{	
	string_proc_list * list	= string_proc_list_create_asm();
	printf("list created:\n");
	string_proc_list_add_node_asm(list, 0, "hola");
	printf("After adding node 'hola':\n");
    string_proc_list_print(list, stdout);
	string_proc_list_add_node_asm(list, 0, "a");
	printf("After adding node 'a':\n");
	string_proc_list_print(list, stdout);
	string_proc_list_add_node_asm(list, 0, "todos!");
	printf("After adding node 'todos':\n");
	string_proc_list_print(list, stdout);
	string_proc_list_destroy(list);
	printf("List destroyed.\n");
}

/**
 * 	crea una lista y le agrega nodos. Luego aplica la lista a un hash.
*/

void test_list_concat(void)
{
    // Crear la lista y verificar que se creó
    string_proc_list * list = string_proc_list_create();
    if (!list) {
        printf("Error: No se pudo crear la lista.\n");
        return;
    }
    printf("Lista creada: %p\n", (void*) list);
    
    // Agregar nodos y luego imprimir la lista para ver su estado
    string_proc_list_add_node(list, 0, "hola");
    string_proc_list_add_node(list, 0, "a");
    string_proc_list_add_node(list, 0, "todos!");
    printf("Después de agregar nodos:\n");
    string_proc_list_print(list, stdout);
    
    // Llamar a la función concat y verificar el resultado
    char* new_hash = string_proc_list_concat(list, 0, "hash");
    if (new_hash)
        printf("String concatenado: %s\n", new_hash);
    else
        printf("Error: string_proc_list_concat devolvió NULL.\n");

    // Liberar la lista y el string concatenado
    string_proc_list_destroy(list);
    free(new_hash);
}

/**
* Corre los test a se escritos por lxs alumnxs	
*/
void run_tests(void){

	/* Aqui pueden comenzar a probar su codigo */
	// test_create_destroy_list();

	// test_create_destroy_node();

	// test_create_list_add_nodes();

	test_list_concat();
}

int main (void){
	run_tests();
	return 0;    
}

