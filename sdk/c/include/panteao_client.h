#ifndef PANTEAO_CLIENT_H
#define PANTEAO_CLIENT_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*PanteaoActionCallback)(const char *name, const char **args, int args_count, const char *action_id, void *context);

typedef struct {
    int socket_fd;
    PanteaoActionCallback callback;
    void *callback_context;
} PanteaoClient;

int panteao_connect(PanteaoClient *client, const char *host, int port);
int panteao_send_perception(PanteaoClient *client, const char *action, const char *perception);
int panteao_send_action_result(PanteaoClient *client, const char *action_id, int success);
void panteao_register_action_callback(PanteaoClient *client, PanteaoActionCallback callback, void *context);
int panteao_process_actions(PanteaoClient *client, int timeout_seconds);
void panteao_close(PanteaoClient *client);

#ifdef __cplusplus
}
#endif

#endif
