#include "pathname.h"
#include "directory.h"
#include "inode.h"
#include "diskimg.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

/**
 * TODO
 * pseudo:
 * voy al inodo raiz
 * recorro name en pathname.split('/') menos el ultimo
 *    llamo a directory_findname -> obtengo inodo
 *    si no existe o esta vacio:
 *       chau
 *   si es archivo:
 *      chau
 *   i++
 * obtengo el inodo del ultimo -> devuelvo eso
 */
int pathname_lookup(struct unixfilesystem *fs, const char *pathname) {
  // chequeo que pathname no este vacio o sea NULL
  if (pathname == NULL || pathname[0] == '\0') {
    return -1;
  }

  // Caso especial: si pathname es solo "/", es el inodo raíz.
  if (strcmp(pathname, "/") == 0) {
    return 1;
  }

  // chequeo que pathname no termine en '/' (excepto si es solo "/")
  if (pathname[strlen(pathname) - 1] == '/' && strlen(pathname) > 1) {
    return -1;
  }

  // Copio pathname para usar strtok
  char path_copy[256];
  strncpy(path_copy, pathname, sizeof(path_copy) - 1);
  path_copy[sizeof(path_copy) - 1] = '\0';

  char *current_token_ptr = path_copy;
  if (pathname[0] == '/') {
    current_token_ptr++;
  }

  int current_dir_inumber = 1;
  struct direntv6 dirEnt;

  // recorro pathname.split('/')
  char *component = strtok(current_token_ptr, "/");
  char *next_component = strtok(NULL, "/");


  while (component != NULL) {
    // Si el componente está vacío
    if (component[0] == '\0') {
        return -1;
    }

    if (directory_findname(fs, component, current_dir_inumber, &dirEnt) == -1) {
      return -1;
    }

    // Si es el ultimo componente, no chequeo que sea directorio
    if (next_component != NULL) {
        struct inode entry_inode;
        if (inode_iget(fs, dirEnt.d_inumber, &entry_inode) == -1) {
            return -1;
        }
        if ((entry_inode.i_mode & IFMT) != IFDIR) {
            return -1;
        }
    }
    current_dir_inumber = dirEnt.d_inumber;

    component = next_component;
    if (component != NULL) {
        next_component = strtok(NULL, "/");
    }
  }
  return current_dir_inumber;
}
