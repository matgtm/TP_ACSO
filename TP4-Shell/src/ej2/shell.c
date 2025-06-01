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
        printf("Shell> ");

        /*Reads a line of input from the user from the standard input (stdin) and stores it in the variable command */
        fgets(command, sizeof(command), stdin);

        /* Removes the newline character (\n) from the end of the string stored in command, if present.
           This is done by replacing the newline character with the null character ('\0').
           The strcspn() function returns the length of the initial segment of command that consists of
           characters not in the string specified in the second argument ("\n" in this case). */
        command[strcspn(command, "\n")] = '\0';

        /* Tokenizes the command string using the pipe character (|) as a delimiter using the strtok() function.
           Each resulting token is stored in the commands[] array.
           The strtok() function breaks the command string into tokens (substrings) separated by the pipe character |.
           In each iteration of the while loop, strtok() returns the next token found in command.
           The tokens are stored in the commands[] array, and command_count is incremented to keep track of the number of tokens found. */
        int command_count = 0;
        char *token = strtok(command, "|");
        while (token != NULL)
        {
            commands[command_count++] = token;
            token = strtok(NULL, "|");
        }

        /* You should start programming from here... */

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
                // Si no es el primero, la entrada es la entrada del pipe
                if (i != 0)
                {
                    dup2(pipes[i-1][0], 0);
                }
                // Si no es el último, la salida es la salida del pipe
                if (i != command_count-1)
                {
                    dup2(pipes[i][1], 1);
                }
                // Cierro pipes no usados
                for (int j = 0; j < command_count - 1; j++) {
                    close(pipes[j][0]);
                    close(pipes[j][1]);
                }

                execvp(args[0], args);
                perror("execvp"); exit(1);
                exit(1);
            }

        }

        // Aca estoy en proceso padre

        // Cierro pipes
        for (int i = 0; i < command_count - 1; i++) {
            close(pipes[i][0]);
            close(pipes[i][1]);
        }

        // Espero a todos los hijos
        for (int i = 0; i < command_count; i++) {
            wait(NULL);
        }
    }
}
