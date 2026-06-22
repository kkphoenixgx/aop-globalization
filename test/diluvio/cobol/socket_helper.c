#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>

int connect_to_bdi(const char* host, int port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return -1;
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, host, &addr.sin_addr);
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return -1;
    }
    return sock;
}

int send_message(int sock, const char* msg) {
    char buf[1024];
    snprintf(buf, sizeof(buf), "%s\n", msg);
    return send(sock, buf, strlen(buf), 0);
}

int receive_line(int sock, char* buf, int max_len) {
    int len = 0;
    while (len < max_len - 1) {
        char c;
        int n = recv(sock, &c, 1, 0);
        if (n <= 0) break;
        if (c == '\n') break;
        buf[len++] = c;
    }
    buf[len] = '\0';
    return len;
}
int contains_substring(const char* str, const char* sub) {
    if (strstr(str, sub) != NULL) {
        return 1;
    }
    return 0;
}
