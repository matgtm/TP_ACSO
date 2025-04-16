#include "ej1.h"

#if !USE_ASM_IMPL

string_proc_list* string_proc_list_create(void){
	// pido memoria
	string_proc_list* lista = (string_proc_list*) malloc(sizeof(string_proc_list));
	if (lista == NULL){
		return NULL;
	}
	lista -> first = NULL;
	lista -> last = NULL; 
	return lista;
}

string_proc_node* string_proc_node_create(uint8_t type, char* hash){

	string_proc_node* nodo = (string_proc_node*) malloc(sizeof(string_proc_node));
	if (nodo == NULL){
		return NULL;
	}
	nodo -> next = NULL;
	nodo -> previous = NULL;
	nodo -> type = type;
	nodo -> hash = hash;

	return nodo;
}

void string_proc_list_add_node(string_proc_list* list, uint8_t type, char* hash){
	string_proc_node* nodo = string_proc_node_create(type, hash);
	if (nodo == NULL){
		return;
	}
	if (list->first == NULL){
		list->first = nodo;
		list->last = nodo;
	}else{
		nodo->previous = list->last;
		list->last->next = nodo;
		list->last = nodo;
	}
}

char* string_proc_list_concat(string_proc_list* list, uint8_t type , char* hash){
	/* PSEUDO: ver si la lista es no vacia, y si no es vacia, chequeo el nodo first, 
	comparo types, si son iguales, concateno hash con str_concat, hago un while 
	not last, adentro voy al next, hago misma comparacion y concat, y al final 
	retorno el char* */
	// si algo nulo
	if (list == NULL || list->first == NULL){
		char* res = (char*) malloc(strlen(hash) + 1);
        if (res != NULL)
            return hash;
	}

	// primera pasada para crear memoria
	size_t length = strlen(hash);
	string_proc_node* current_node = list->first;

	while(current_node != NULL){
		if(current_node->type == type){
			length += strlen(current_node->hash);
		}
		current_node = current_node->next;
	}

	// ultimo 0
	length += 1;

	char* concat_hash = (char*) malloc(length);
	if(concat_hash == NULL){return NULL;}

	strcpy(concat_hash, hash);
	
	current_node = list->first;
	while(current_node != NULL){
		if (current_node->type == type){
			strcat(concat_hash, current_node->hash);
		}
		current_node = current_node->next;
	}
	return concat_hash;

}
#endif

/** AUX FUNCTIONS **/

void string_proc_list_destroy(string_proc_list* list){

	/* borro los nodos: */
	string_proc_node* current_node	= list->first;
	string_proc_node* next_node		= NULL;
	while(current_node != NULL){
		next_node = current_node->next;
		string_proc_node_destroy(current_node);
		current_node	= next_node;
	}
	/*borro la lista:*/
	list->first = NULL;
	list->last  = NULL;
	free(list);
}
void string_proc_node_destroy(string_proc_node* node){
	node->next      = NULL;
	node->previous	= NULL;
	node->hash		= NULL;
	node->type      = 0;			
	free(node);
}


char* str_concat(char* a, char* b) {
	int len1 = strlen(a);
    int len2 = strlen(b);
	int totalLength = len1 + len2;
    char *result = (char *)malloc(totalLength + 1); 
    strcpy(result, a);
    strcat(result, b);
    return result;  
}

void string_proc_list_print(string_proc_list* list, FILE* file){
        uint32_t length = 0;
        string_proc_node* current_node  = list->first;
        while(current_node != NULL){
                length++;
                current_node = current_node->next;
        }
        fprintf( file, "List length: %d\n", length );
		current_node    = list->first;
        while(current_node != NULL){
                fprintf(file, "\tnode hash: %s | type: %d\n", current_node->hash, current_node->type);
                current_node = current_node->next;
        }
}


