#include "directory.h"
#include "inode.h"
#include "diskimg.h"
#include "file.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
/**
 * TODO
 * pseudo:
 * obtener el inodo con inode_iget
 * chequear que sea directorio con (i_mode & IFMT) == IFDIR, si no es, chau
 * chequear nro de bloques a recorrer
 * recorro los bloques con file_getblock:
 *      recorro dirents en cada bloque
 *      si el nombre coincide, copiar el inodo al direntv6 y devolver 0
 *      si no, chau
 * si no encuentro, chau
 *
 */
int directory_findname(struct unixfilesystem *fs, const char *name,
		int dirinumber, struct direntv6 *dirEnt) {
  struct inode inp;
  if (inode_iget(fs, dirinumber, &inp) == -1) {
    return -1;
  }
  if ((inp.i_mode & IFMT) != IFDIR) {
    return -1;
  }
  // obtengo tamaño
  int dir_size = inode_getsize(&inp);
  // si no tiene ni un dirent
  if (dir_size < (int)sizeof(struct direntv6)) {
    return -1;
  }
  // cantidad de bloques a recorrer
  int num_bloques = (dir_size + DISKIMG_SECTOR_SIZE - 1) / DISKIMG_SECTOR_SIZE;
  // recorro los bloques
  for (int i = 0; i < num_bloques; i++) {
    // obtengo el bloque
    void *buf = malloc(DISKIMG_SECTOR_SIZE);
    if (buf == NULL) {
      return -1;
    }
    if (file_getblock(fs, dirinumber, i, buf) == -1) {
      free(buf);
      return -1;
    }
    // Cast buf
    struct direntv6 *dir_entries = (struct direntv6 *)buf;
    // recorro los dirents en el bloque
    int dirents_por_bloque = DISKIMG_SECTOR_SIZE / sizeof(struct direntv6);
    for (int j = 0; j < dirents_por_bloque; j++) {
      // si el nombre coincide, copiar el inodo al direntv6 y devolver 0
      if (dir_entries[j].d_inumber != 0 && strcmp(dir_entries[j].d_name, name) == 0) {
        memcpy(dirEnt, &dir_entries[j], sizeof(struct direntv6));
        free(buf);
        return 0;
      }
    }
    free(buf);
  }
  return -1;
}
