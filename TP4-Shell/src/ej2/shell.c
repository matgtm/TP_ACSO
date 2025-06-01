#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

#define MAX_COMMANDS 200

int main() {

    char command[256];
    char *commands[MAX_COMMANDS];
    int pipes[MAX_COMMANDS][2];

    while (1)
    {
        if (isatty(STDIN_FILENO)) {
            printf("Shell> ");
            fflush(stdout);
        }

        if (!fgets(command, sizeof(command), stdin))
            break;

        command[strcspn(command, "\n")] = '\0';

        // Permitir salir con "exit"
        if (strcmp(command, "exit") == 0)
            break;

        int command_count = 0;
        char *token = strtok(command, "|");
        while (token != NULL)
        {
            commands[command_count++] = token;
            token = strtok(NULL, "|");
        }

        // Creo los pipes
        for (int i = 0; i < command_count-1; i++)
        {
            if (pipe(pipes[i]) < 0)
            {
                perror("pipe"); exit(1);
            }
        }

        // Procesos hijos
        for (int i = 0; i < command_count; i++)
        {
            char *args[MAX_COMMANDS];
            int arg_count = 0;

            // Tokenizo cada comando
            char *token = strtok(commands[i], " ");
            while (token != NULL)
            {
                args[arg_count++] = token;
                token = strtok(NULL, " ");
            }
            args[arg_count] = NULL;

            // Forks hijos
            int pid = fork();
            if (pid == 0)
            {
                if (i != 0)
                    dup2(pipes[i-1][0], 0);
                if (i != command_count-1)
                    dup2(pipes[i][1], 1);

                for (int j = 0; j < command_count - 1; j++) {
                    close(pipes[j][0]);
                    close(pipes[j][1]);
                }

                execvp(args[0], args);
                perror("execvp"); exit(1);
            }
        }

        // Proceso padre: cierro pipes y espero hijos
        for (int i = 0; i < command_count - 1; i++) {
            close(pipes[i][0]);
            close(pipes[i][1]);
        }

        for (int i = 0; i < command_count; i++) {
            wait(NULL);
        }
    }
    return 0;
}
