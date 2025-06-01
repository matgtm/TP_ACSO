#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char **argv)
{
    if (argc != 4) {
        printf("Uso: anillo <n> <c> <s>\n");
        exit(1);
    }

    int n = atoi(argv[1]);
    int c = atoi(argv[2]);
    int s = atoi(argv[3]);
    int pipes[n][2];

    // Creo los pipes
    for (int i = 0; i < n; i++) {
        if (pipe(pipes[i]) < 0) {
          perror("pipe"); exit(1);
        }
    }

    // Procesos hijos
    for (int i = 0; i < n; i++) {
        if (fork() == 0) {
            int x;
            // Pipe entrada hijo i
            read(pipes[i][0], &x, sizeof(int));
            x++;
            // Pipe salida hijo i+1
            write(pipes[(i+1)%n][1], &x, sizeof(int));
            exit(0);
        }
    }

    // Mando el primer dato
    write(pipes[(s-1)%n][1], &c, sizeof(int));

    int result;
    // Padre lee lo que devuelven
    read(pipes[s-1][0], &result, sizeof(int));

    printf("Resultado final: %d\n", result);

    // Espero a todos los hijos
    for (int i = 0; i < n; i++) wait(NULL);
    return 0;
}
