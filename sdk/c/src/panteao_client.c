#include "panteao_client.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>

int panteao_connect(PanteaoClient *client, const char *host, int port) {
    struct sockaddr_in serv_addr;
    client->socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (client->socket_fd < 0) return -1;

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    if (inet_pton(AF_INET, host, &serv_addr.sin_addr) <= 0) return -1;

    if (connect(client->socket_fd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        return -1;
    }
    client->callback = NULL;
    client->callback_context = NULL;
    return 0;
}

int panteao_send_perception(PanteaoClient *client, const char *action, const char *perception) {
    char buffer[2048];
    snprintf(buffer, sizeof(buffer), "{\"type\":\"perception\",\"action\":\"%s\",\"perception\":\"%s\"}\n", action, perception);
    return write(client->socket_fd, buffer, strlen(buffer)) >= 0 ? 0 : -1;
}

int panteao_send_action_result(PanteaoClient *client, const char *action_id, int success) {
    char buffer[1024];
    snprintf(buffer, sizeof(buffer), "{\"type\":\"action_result\",\"id\":\"%s\",\"success\":%s}\n", action_id, success ? "true" : "false");
    return write(client->socket_fd, buffer, strlen(buffer)) >= 0 ? 0 : -1;
}

void panteao_register_action_callback(PanteaoClient *client, PanteaoActionCallback callback, void *context) {
    client->callback = callback;
    client->callback_context = context;
}

int panteao_process_actions(PanteaoClient *client, int timeout_seconds) {
    struct timeval tv;
    tv.tv_sec = timeout_seconds;
    tv.tv_usec = 0;
    setsockopt(client->socket_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    char buf[4096];
    int total = 0;
    while (1) {
        int n = recv(client->socket_fd, buf + total, sizeof(buf) - total - 1, 0);
        if (n <= 0) return -1; // socket closed or error/timeout
        total += n;
        buf[total] = '\0';

        char *line_start = buf;
        char *newline;
        while ((newline = strchr(line_start, '\n')) != NULL) {
            *newline = '\0';
            char *line = line_start;

            if (strstr(line, "\"type\":\"action\"")) {
                char action_id[256] = "";
                char raw_action[512] = "";

                char *id_pos = strstr(line, "\"id\":\"");
                if (id_pos) {
                    id_pos += 6;
                    char *id_end = strchr(id_pos, '"');
                    if (id_end) {
                        size_t len = id_end - id_pos;
                        if (len < sizeof(action_id)) {
                            memcpy(action_id, id_pos, len);
                            action_id[len] = '\0';
                        }
                    }
                }

                char *act_pos = strstr(line, "\"action\":\"");
                if (act_pos) {
                    act_pos += 10;
                    char *act_end = strchr(act_pos, '"');
                    if (act_end) {
                        size_t len = act_end - act_pos;
                        if (len < sizeof(raw_action)) {
                            memcpy(raw_action, act_pos, len);
                            raw_action[len] = '\0';
                        }
                    }
                }

                if (strlen(action_id) > 0 && strlen(raw_action) > 0) {
                    char action_name[256] = "";
                    char *args[16];
                    int args_count = 0;
                    char args_buf[512] = "";

                    char *paren = strchr(raw_action, '(');
                    if (paren) {
                        size_t name_len = paren - raw_action;
                        if (name_len < sizeof(action_name)) {
                            memcpy(action_name, raw_action, name_len);
                            action_name[name_len] = '\0';
                        }

                        char *rparen = strrchr(paren, ')');
                        if (rparen) {
                            size_t args_len = rparen - (paren + 1);
                            if (args_len < sizeof(args_buf)) {
                                memcpy(args_buf, paren + 1, args_len);
                                args_buf[args_len] = '\0';
                            }
                        }
                    } else {
                        strncpy(action_name, raw_action, sizeof(action_name) - 1);
                    }

                    if (strlen(args_buf) > 0) {
                        char *token = strtok(args_buf, ",");
                        while (token && args_count < 16) {
                            while (*token == ' ' || *token == '"') token++;
                            size_t tok_len = strlen(token);
                            while (tok_len > 0 && (token[tok_len - 1] == ' ' || token[tok_len - 1] == '"')) {
                                token[tok_len - 1] = '\0';
                                tok_len--;
                            }
                            args[args_count++] = token;
                            token = strtok(NULL, ",");
                        }
                    }

                    if (client->callback) {
                        client->callback(action_name, (const char **)args, args_count, action_id, client->callback_context);
                    } else {
                        panteao_send_action_result(client, action_id, 1);
                    }
                }
            }
            line_start = newline + 1;
        }

        int remaining = total - (line_start - buf);
        if (remaining > 0 && line_start != buf) {
            memmove(buf, line_start, remaining);
            total = remaining;
        } else {
            total = 0;
        }
    }
    return 0;
}

void panteao_close(PanteaoClient *client) {
    if (client->socket_fd >= 0) {
        close(client->socket_fd);
        client->socket_fd = -1;
    }
}
