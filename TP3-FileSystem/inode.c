#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "inode.h"
#include "diskimg.h"
#include "unixfilesystem.h"
#include "ino.h"
#include <stdbool.h>
#


/**
 * TODO
 me dan un filesystem, inumber a obtener, lugar de memoria donde quieren ese inode
pseudo:
calculo sector donde está este inode: sector: 512b, inode: 32b, 512/32 = 16
voy a tabla de inodes, leo dicho sector
me quedo con los datos del inode q me interesa
muevo los datos a *inp?
 */
int inode_iget(struct unixfilesystem *fs, int inumber, struct inode *inp) {
    // Calculos
    int sector_offset = (inumber-1) / 16;
    int sector_objetivo = INODE_START_SECTOR + sector_offset;
    int offset_in = (inumber - 1) % 16;

    // Pido memoria
    void *sector = malloc(DISKIMG_SECTOR_SIZE);
    if (!sector) {
        return -1;
    }
    // Leo sector
    int fd = fs ->dfd;
    if (diskimg_readsector(fd, sector_objetivo, sector) == -1) {
        free(sector);
        return -1;
    }

    // Copio inode
    struct inode *inode = (struct inode *)((char *)sector + offset_in * sizeof(struct inode));
    *inp = *inode;


    free(sector);
    return 0;
}

/**
 * TODO
 * pseudo:
 * accedo a inode *inp
 * veo si es large o small con (i_mode & ILARG)!= 0
 * si small: accedo a i_addr[blockNum], devuelvo el valor
 * si large: calculo en qué índice de i_addr caigo (//256 <7 o algo así)
 *  si caigo en 0..6 -> singly -> voy a i_addr[blockNum/256] -> bloque blockNum%256
 *  si caigo en 7 -> doubly -> voy a i_addr[7] -> bloque blockNum/256 -> bloque blockNum%256
 *
 */
int inode_indexlookup(struct unixfilesystem *fs, struct inode *inp,
    int blockNum) {
    // Calculo tamaño de archivo
    int tam_archivo = inode_getsize(inp);
    int num_bloques = (tam_archivo + DISKIMG_SECTOR_SIZE - 1) / DISKIMG_SECTOR_SIZE;
    if (blockNum >= num_bloques) { // blockNum fuera de rango
      return -1;
    }

    // Veo si es small o large
    if ((inp->i_mode & ILARG) == 0) {
      // es small
      return inp->i_addr[blockNum];
    }

    // es large
    // indice en i_addr si es menor a 7, sino tengo que calcular de vuelta
    int idx = blockNum / 256;
    // me fijo si caigo en indireccion simple
    bool es_singly = idx < 7;

    uint16_t bloque_indirecto_simple;
    // accedo a diraccion de bloque indirecto simple
    if (es_singly) {
      bloque_indirecto_simple = inp->i_addr[idx];
    }
    else {
      bloque_indirecto_simple = inp->i_addr[7];
    }
    // Si el puntero es 0
    if (bloque_indirecto_simple == 0) {
      return -1;
    }
    // pido memoria para leer sector
    void *sector_indirecto_prim = malloc(DISKIMG_SECTOR_SIZE);
    if (!sector_indirecto_prim) {
      return -1;
    }
    // leo sector indirecto
    if (diskimg_readsector(fs->dfd, bloque_indirecto_simple, sector_indirecto_prim) == -1) {
      free(sector_indirecto_prim);
      return -1;
    }

    // calculo offset segun el caso
    int offset_en_primer_indirecto;
    if (es_singly) {
    offset_en_primer_indirecto = blockNum % 256;
    }
    else {
    offset_en_primer_indirecto = idx - 7;
    }
    // castear sector indirecto a puntero a uint16_t
    uint16_t *punteros_a_bloques_de_datos = (uint16_t *)sector_indirecto_prim;
    // obtengo numero de bloque dentro del sector indirecto simple
    uint16_t numero_bloque_dentro_indirecto = punteros_a_bloques_de_datos[offset_en_primer_indirecto];
    free(sector_indirecto_prim);
    // si es singly, devuelvo el numero de bloque
    if (es_singly) {
      return numero_bloque_dentro_indirecto;
    }
    // si es doubly, accedo al sector indirecto doble
    else {
      // Si el puntero es 0
      if (numero_bloque_dentro_indirecto == 0) {
        return -1;
      }
      // pido memoria para leer sector indirecto doble
      void *sector_indirecto_doble = malloc(DISKIMG_SECTOR_SIZE);
      if (!sector_indirecto_doble) {
        return -1;
      }
      // leo sector indirecto doble
      if (diskimg_readsector(fs->dfd, numero_bloque_dentro_indirecto, sector_indirecto_doble) == -1) {
        free(sector_indirecto_doble);
        return -1;
      }
      // castear sector indirecto doble a puntero a uint16_t
      uint16_t *punteros_a_bloques_de_datos_doble = (uint16_t *)sector_indirecto_doble;
      // offset en sector indirecto doble
      int offset_en_sector_indirecto_doble = blockNum % 256;
      // obtengo numero de bloque dentro del sector indirecto doble
      uint16_t numero_bloque_dentro_indirecto_doble = \
      punteros_a_bloques_de_datos_doble[offset_en_sector_indirecto_doble];
      // free malloc
      free(sector_indirecto_doble);
      // devuelvo numero de bloque
      return numero_bloque_dentro_indirecto_doble;
    }

    return 0;
}

int inode_getsize(struct inode *inp) {
  return ((inp->i_size0 << 16) | inp->i_size1);
}
