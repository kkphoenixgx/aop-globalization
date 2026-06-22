/* ============================================================
 * OPERAÇÃO DILÚVIO - Teste C
 * "O Controlo Físico das Comportas"
 *
 * Simula um PLC embarcado controlando comportas de barragem.
 * Envia percepção gate_pressure e trata ação open_gate.
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#define ENGINE_HOST "127.0.0.1"
#define ENGINE_PORT 44444
#define BUF_SIZE    4096
#define TIMEOUT_SEC 5

/* ---- helpers ---- */

static double ms_since(struct timespec *start) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (now.tv_sec - start->tv_sec) * 1000.0
         + (now.tv_nsec - start->tv_nsec) / 1e6;
}

static void die(const char *msg) {
    fprintf(stderr, "[DILUVIO] ERRO: %s (errno=%d: %s)\n",
            msg, errno, strerror(errno));
    exit(1);
}

/* ---- main ---- */

int main(void) {
    struct timespec t_start, t_connected, t_perception, t_action;
    clock_gettime(CLOCK_MONOTONIC, &t_start);

    printf("============================================================\n");
    printf("  OPERAÇÃO DILÚVIO - Teste C\n");
    printf("  O Controlo Físico das Comportas\n");
    printf("============================================================\n\n");

    /* 1. Create TCP socket */
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) die("socket() falhou");

    struct timeval tv = { .tv_sec = TIMEOUT_SEC, .tv_usec = 0 };
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_port   = htons(ENGINE_PORT),
    };
    inet_pton(AF_INET, ENGINE_HOST, &addr.sin_addr);

    /* 2. Connect */
    printf("[PLC] Conectando ao motor BDI em %s:%d...\n",
           ENGINE_HOST, ENGINE_PORT);

    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0)
        die("connect() falhou — motor BDI não está ouvindo?");

    clock_gettime(CLOCK_MONOTONIC, &t_connected);
    printf("[PLC] Conectado! (%.2f ms)\n\n", ms_since(&t_start));

    /* 3. Wait for engine readiness */
    printf("[PLC] Aguardando 1s para prontidão do motor...\n");
    sleep(1);

    /* 4. Send perception: gate_pressure(gate_01,85) */
    const char *perception =
        "{\"type\":\"message\",\"performative\":\"tell\","
        "\"sender\":\"external\",\"receiver\":\"orquestrador\","
        "\"content\":\"gate_pressure(gate_01,85)\"}\n";

    printf("[PLC] Enviando percepção: gate_pressure(gate_01, 85)\n");

    if (send(sock, perception, strlen(perception), 0) < 0)
        die("send() percepção falhou");

    clock_gettime(CLOCK_MONOTONIC, &t_perception);
    printf("[PLC] Percepção enviada (%.2f ms desde início)\n\n",
           ms_since(&t_start));

    /* 5. Read lines and look for action request */
    printf("[PLC] Aguardando ação do motor BDI...\n");

    char buf[BUF_SIZE];
    int  total = 0;
    int  found_action = 0;

    while (!found_action) {
        ssize_t n = recv(sock, buf + total, BUF_SIZE - total - 1, 0);
        if (n <= 0) {
            if (n == 0)
                die("conexão fechada pelo motor");
            die("recv() falhou ou timeout");
        }
        total += (int)n;
        buf[total] = '\0';

        /* Process complete lines */
        char *line_start = buf;
        char *newline;
        while ((newline = strchr(line_start, '\n')) != NULL) {
            *newline = '\0';

            printf("[PLC] Recebido: %s\n", line_start);

            /* Look for "type":"action" */
            if (strstr(line_start, "\"type\":\"action\"") &&
                strstr(line_start, "open_gate")) {

                clock_gettime(CLOCK_MONOTONIC, &t_action);
                printf("\n[PLC] >>> AÇÃO DETECTADA: open_gate(gate_01, 45)\n");
                printf("[PLC] Latência percepção→ação: %.2f ms\n\n",
                       ms_since(&t_perception));

                /* Extract action id for the response */
                char action_id[256] = "";
                const char *id_key = "\"id\":\"";
                char *id_pos = strstr(line_start, id_key);
                if (id_pos) {
                    id_pos += strlen(id_key);
                    char *id_end = strchr(id_pos, '"');
                    if (id_end) {
                        size_t len = (size_t)(id_end - id_pos);
                        if (len >= sizeof(action_id)) len = sizeof(action_id) - 1;
                        memcpy(action_id, id_pos, len);
                        action_id[len] = '\0';
                    }
                }

                /* 6. Send action_result */
                char response[512];
                snprintf(response, sizeof(response),
                    "{\"type\":\"action_result\",\"id\":\"%s\",\"success\":true}\n",
                    action_id);

                printf("[PLC] Enviando confirmação: action_result (success)\n");
                if (send(sock, response, strlen(response), 0) < 0)
                    die("send() action_result falhou");

                found_action = 1;
                break;
            }

            line_start = newline + 1;
        }

        /* Shift unprocessed bytes to the front */
        if (line_start != buf && !found_action) {
            int remaining = total - (int)(line_start - buf);
            memmove(buf, line_start, remaining);
            total = remaining;
        }
    }

    /* 7. Done — print metrics */
    double total_ms = ms_since(&t_start);

    printf("\n============================================================\n");
    printf("  MÉTRICAS DE DESEMPENHO\n");
    printf("============================================================\n");
    printf("  Conexão TCP:           %.2f ms\n", ms_since(&t_start) - total_ms + ms_since(&t_connected) - ms_since(&t_start) + ms_since(&t_start) - ms_since(&t_connected));

    /* Recompute cleanly */
    struct timespec t_end;
    clock_gettime(CLOCK_MONOTONIC, &t_end);

    double connect_ms = (t_connected.tv_sec - t_start.tv_sec) * 1000.0
                      + (t_connected.tv_nsec - t_start.tv_nsec) / 1e6;
    double percept_ms = (t_perception.tv_sec - t_start.tv_sec) * 1000.0
                      + (t_perception.tv_nsec - t_start.tv_nsec) / 1e6;
    double action_ms  = (t_action.tv_sec - t_perception.tv_sec) * 1000.0
                      + (t_action.tv_nsec - t_perception.tv_nsec) / 1e6;
    double total_final = (t_end.tv_sec - t_start.tv_sec) * 1000.0
                       + (t_end.tv_nsec - t_start.tv_nsec) / 1e6;

    printf("  Conexão TCP:           %.2f ms\n", connect_ms);
    printf("  Percepção enviada:     %.2f ms (desde início)\n", percept_ms);
    printf("  Latência ação:         %.2f ms (percepção→ação)\n", action_ms);
    printf("  Tempo total:           %.2f ms\n", total_final);
    printf("============================================================\n\n");

    printf("[DILUVIO] SUCCESS\n");
    printf("[PLC] Comporta gate_01 aberta a 45%% — pressão aliviada.\n");

    close(sock);
    return 0;
}
