#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "file.h"
#include "inode.h"
#include "diskimg.h"

/**
 * TODO
 * pseudo:
 * obtener el inodo con inode_iget
 * calcular el tamaño del archivo
 * si blockNum es mayor al tamaño del archivo, devolver -1
 * obtener el bloque con inode_indexlookup
 * leer el bloque en buf
 * si el bloque es 0, devolver -1
 * si no, copiar el bloque en buf
 * ver si blockNum es el ultimo bloque del archivo
 * si es, calcular bytes ocupados por el archivo
 * devolver bytes ocupados
 */
int file_getblock(struct unixfilesystem *fs, int inumber, int blockNum, void *buf) {
    struct inode inp;
    if (inode_iget(fs, inumber, &inp) == -1) {
        return -1;
    }
    // Calculo tamaño de archivo
    int tam_archivo = inode_getsize(&inp);
    int num_bloques = (tam_archivo + DISKIMG_SECTOR_SIZE - 1) / DISKIMG_SECTOR_SIZE;
    if (blockNum >= num_bloques) { // blockNum fuera de rango
      return -1;
    }
    int block_num = inode_indexlookup(fs, &inp, blockNum);
    if (block_num == -1) {
        return -1;
    }
    if (diskimg_readsector(fs->dfd, block_num, buf) == -1) {
        return -1;
    }
    if (blockNum == num_bloques - 1) {
        int bytes_ocupados = tam_archivo % DISKIMG_SECTOR_SIZE;
        return bytes_ocupados == 0 ? DISKIMG_SECTOR_SIZE : bytes_ocupados;
    }
    return DISKIMG_SECTOR_SIZE;
}
