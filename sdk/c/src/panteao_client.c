#include "panteao_client.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>

#include <fcntl.h>
#include <libgen.h>
#include <sys/stat.h>
#include <signal.h>

static int get_free_port() {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return 0;
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = 0;
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return 0;
    }
    socklen_t len = sizeof(addr);
    if (getsockname(fd, (struct sockaddr *)&addr, &len) < 0) {
        close(fd);
        return 0;
    }
    close(fd);
    return ntohs(addr.sin_port);
}

static void find_binary(char *out_path, size_t max_len) {
    char exe_path[1024];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path)-1);
    if (len != -1) {
        exe_path[len] = '\0';
        char exe_copy[1024];
        strcpy(exe_copy, exe_path);
        char *dir = dirname(exe_copy);
        
        snprintf(out_path, max_len, "%s/panteao-engine", dir);
        struct stat st;
        if (stat(out_path, &st) == 0) return;
        
        snprintf(out_path, max_len, "%s/bin/panteao-engine", dir);
        if (stat(out_path, &st) == 0) return;
    }
    
    struct stat st;
    snprintf(out_path, max_len, "./panteao-engine");
    if (stat(out_path, &st) == 0) return;
    snprintf(out_path, max_len, "./bin/panteao-engine");
    if (stat(out_path, &st) == 0) return;
    
    snprintf(out_path, max_len, "panteao-engine");
}

int panteao_connect(PanteaoClient *client, const char *host, int port) {
    return panteao_connect_with_project(client, host, port, NULL);
}

int panteao_connect_with_project(PanteaoClient *client, const char *host, int port, const char *project) {
    client->socket_fd = -1;
    client->engine_pid = 0;
    client->callback = NULL;
    client->callback_context = NULL;

    if (project != NULL) {
        if (port == 0) {
            port = get_free_port();
            if (port == 0) return -1;
        }
        char bin_path[1024];
        find_binary(bin_path, sizeof(bin_path));

        int pid = fork();
        if (pid == 0) {
            char port_str[16];
            snprintf(port_str, sizeof(port_str), "%d", port);
            
            int dev_null = open("/dev/null", O_RDWR);
            dup2(dev_null, 1);
            dup2(dev_null, 2);
            close(dev_null);
            
            execl(bin_path, bin_path, project, "--port", port_str, (char *)NULL);
            exit(1);
        } else if (pid > 0) {
            client->engine_pid = pid;
            usleep(800000);
        } else {
            return -1;
        }
    } else if (port == 0) {
        port = 44444;
    }

    struct sockaddr_in serv_addr;
    client->socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (client->socket_fd < 0) {
        if (client->engine_pid > 0) {
            kill(client->engine_pid, SIGKILL);
        }
        return -1;
    }

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    const char *actual_host = (host == NULL || strlen(host) == 0) ? "127.0.0.1" : host;
    if (inet_pton(AF_INET, actual_host, &serv_addr.sin_addr) <= 0) {
        close(client->socket_fd);
        client->socket_fd = -1;
        if (client->engine_pid > 0) {
            kill(client->engine_pid, SIGKILL);
        }
        return -1;
    }

    if (connect(client->socket_fd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        close(client->socket_fd);
        client->socket_fd = -1;
        if (client->engine_pid > 0) {
            kill(client->engine_pid, SIGKILL);
        }
        return -1;
    }

    char handshake_buf[4096];
    int handshake_total = 0;
    int handshake_success = 0;
    while (1) {
        int n = recv(client->socket_fd, handshake_buf + handshake_total, sizeof(handshake_buf) - handshake_total - 1, 0);
        if (n <= 0) break;
        handshake_total += n;
        handshake_buf[handshake_total] = '\0';
        if (strstr(handshake_buf, "\"type\":\"mas_ready\"")) {
            handshake_success = 1;
            break;
        }
    }

    if (!handshake_success) {
        close(client->socket_fd);
        client->socket_fd = -1;
        if (client->engine_pid > 0) {
            kill(client->engine_pid, SIGKILL);
        }
        return -1;
    }

    return 0;
}

int panteao_send_msg(PanteaoClient *client, const char *performative, const char *sender, const char *receiver, const char *content) {
    char buffer[2048];
    snprintf(buffer, sizeof(buffer), "{\"type\":\"message\",\"performative\":\"%s\",\"sender\":\"%s\",\"receiver\":\"%s\",\"content\":\"%s\"}\n", performative, sender, receiver, content);
    return write(client->socket_fd, buffer, strlen(buffer)) >= 0 ? 0 : -1;
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

    char buf[8192];
    int total = 0;
    while (1) {
        int n = recv(client->socket_fd, buf + total, sizeof(buf) - total - 1, 0);
        if (n <= 0) return -1;
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
                        char *p = args_buf;
                        int inside_quotes = 0;
                        int depth_brackets = 0;
                        int depth_parens = 0;
                        char *current_arg = p;

                        while (*p && args_count < 16) {
                            if (*p == '"') {
                                inside_quotes = !inside_quotes;
                            } else if (!inside_quotes && *p == '[') {
                                depth_brackets++;
                            } else if (!inside_quotes && *p == ']') {
                                depth_brackets--;
                            } else if (!inside_quotes && *p == '(') {
                                depth_parens++;
                            } else if (!inside_quotes && *p == ')') {
                                depth_parens--;
                            } else if (*p == ',' && !inside_quotes && depth_brackets == 0 && depth_parens == 0) {
                                *p = '\0';
                                char *arg = current_arg;
                                while (*arg == ' ') arg++;
                                size_t len = strlen(arg);
                                while (len > 0 && arg[len-1] == ' ') {
                                    arg[len-1] = '\0';
                                    len--;
                                }
                                if (arg[0] == '"' && arg[len-1] == '"' && len >= 2) {
                                    arg[len-1] = '\0';
                                    arg++;
                                }
                                args[args_count++] = arg;
                                current_arg = p + 1;
                            }
                            p++;
                        }
                        if (current_arg < p && args_count < 16) {
                            char *arg = current_arg;
                            while (*arg == ' ') arg++;
                            size_t len = strlen(arg);
                            while (len > 0 && arg[len-1] == ' ') {
                                arg[len-1] = '\0';
                                len--;
                            }
                            if (arg[0] == '"' && arg[len-1] == '"' && len >= 2) {
                                arg[len-1] = '\0';
                                arg++;
                            }
                            args[args_count++] = arg;
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
    if (client->engine_pid > 0) {
        kill(client->engine_pid, SIGKILL);
        client->engine_pid = 0;
    }
}
