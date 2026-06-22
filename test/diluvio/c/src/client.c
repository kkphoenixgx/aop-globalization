#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "panteao_client.h"

int action_handled = 0;

void handle_action(const char *name, const char **args, int args_count, const char *action_id, void *context) {
    PanteaoClient *client = (PanteaoClient *)context;
    printf("[DILUVIO] Received action: '%s'\n", name);
    if (strcmp(name, "open_gate") == 0) {
        printf("[DILUVIO] Action handled: open_gate\n");
        if (args_count > 0) {
            printf("[DILUVIO] Args: %s\n", args[0]);
        }
        panteao_send_action_result(client, action_id, 1);
        action_handled = 1;
    } else {
        panteao_send_action_result(client, action_id, 1);
    }
}

int main() {
    printf("[DILUVIO] C client starting\n");
    sleep(1);
    
    PanteaoClient client;
    
    if (panteao_connect(&client, "127.0.0.1", 44444) != 0) {
        printf("[DILUVIO] FAILURE\n");
        return 1;
    }
    
    panteao_register_action_callback(&client, handle_action, &client);
    
    printf("[DILUVIO] Connected!\n");
    panteao_send_msg(&client, "tell", "external", "orquestrador", "gate_pressure(gate_1,90)");
    
    int elapsed = 0;
    while (!action_handled && elapsed < 5) {
        panteao_process_actions(&client, 1);
        elapsed++;
    }
    
    panteao_close(&client);
    
    if (action_handled) {
        printf("[DILUVIO] SUCCESS\n");
        return 0;
    } else {
        printf("[DILUVIO] TIMEOUT\n");
        return 1;
    }
}
