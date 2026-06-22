# Guia de Integração para Linguagens Não Suportadas Nativamente

Este guia descreve como integrar qualquer linguagem de programação (ex: COBOL, Lisp, Fortran, Perl, etc.) com o motor Panteão BDI, utilizando a comunicação via sockets TCP/IP e trocas de mensagens JSON.

## Arquitetura de Comunicação

O motor Panteão roda como um processo Java autônomo (JAR ou Binário Nativo GraalVM) que inicializa o ciclo cognitivo dos agentes Jason e abre um servidor de Sockets TCP em uma porta configurada (ou porta dinâmica aleatória).

Qualquer wrapper cliente em qualquer linguagem precisa apenas:
1. Conectar-se ao Socket TCP (`127.0.0.1:porta`).
2. Tratar cada mensagem como uma única linha de texto delimitada pelo caractere de quebra de linha (`\n`).
3. Enviar e receber payloads JSON.

---

## 1. Executando o Motor Panteão via JAR

Para subir o motor localmente e expô-lo para o seu programa cliente:

```bash
java -jar build/libs/jason-ipc-all.jar seu_projeto.jcm --port 44444
```

---

## 2. Fluxo do Protocolo de Comunicação

### Fase 1: Handshake de Inicialização
Assim que todos os agentes declarados no `.jcm` forem instanciados e registrados no runner do Jason, o motor envia uma notificação de prontidão para o socket cliente conectado:

* **Mensagem recebida pelo Cliente**:
  ```json
  {"type":"mas_ready"}
  ```
  *Nota: O cliente deve aguardar esta mensagem antes de começar a disparar crenças iniciais.*

### Fase 2: Envio de Crenças / Speech Acts (KQML)
Para injetar crenças ou intenções em um agente, o cliente envia um JSON no seguinte formato:

* **Mensagem enviada pelo Cliente**:
  ```json
  {"type":"message","performative":"tell","sender":"external","receiver":"nome_do_agente","content":"minha_crenca(valor)"}
  ```
  *Formatos de performativas suportados: tell, untell, achieve, unachieve, askIf, etc.*

### Fase 3: Interceptação de Ações
Quando um agente BDI executa um plano que requer uma ação externa (ex: `update_dashboard("status")`), o motor Jason bloqueia o ciclo daquele agente e despacha uma solicitação de ação para o cliente socket:

* **Mensagem recebida pelo Cliente**:
  ```json
  {"type":"action","id":"act_1","agent":"nome_do_agente","action":"update_dashboard(\"status\")"}
  ```

### Fase 4: Retorno da Execução da Ação
O cliente executa a lógica física (ex: aciona um motor, atualiza um banco de dados, renderiza a tela) e responde se a ação foi executada com sucesso. Isso desbloqueia o ciclo cognitivo daquele agente no Jason:

* **Mensagem enviada pelo Cliente**:
  ```json
  {"type":"action_result","id":"act_1","success":true}
  ```

---

## 3. Exemplo Prático: COBOL (GnuCOBOL + Helper C)

Para linguagens legadas ou sem suporte simples de sockets na biblioteca padrão, o padrão ideal é delegar a rede para pequenas funções C via `CALL`.

### Código C do Helper (`socket_helper.c`)
```c
#include <stdio.h>
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
```

### Código COBOL (`client.cob`)
```cobol
       IDENTIFICATION DIVISION.
       PROGRAM-ID. COBOL-CLIENT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 SOCK-FD          BINARY-LONG.
       01 PORT             BINARY-LONG VALUE 44444.
       01 HOST             PIC X(10) VALUE "127.0.0.1".
       01 MSG-SEND         PIC X(200).
       01 MSG-RECV         PIC X(500).

       PROCEDURE DIVISION.
           * Conectar no motor Panteão
           CALL "connect_to_bdi" USING HOST, BY VALUE PORT
               RETURNING SOCK-FD.
           
           IF SOCK-FD < 0
               DISPLAY "Erro ao conectar"
               STOP RUN
           END-IF.

           * Aguardar prontidão do MAS
           CALL "receive_line" USING BY VALUE SOCK-FD, MSG-RECV, BY VALUE 500.
           
           * Enviar crença informando ordem de evacuação
           MOVE "{\"type\":\"message\",\"performative\":\"tell\",\"sender\":\"external\",\"receiver\":\"orquestrador\",\"content\":\"evacuation_order(zona_sul)\"}" TO MSG-SEND.
           CALL "send_message" USING BY VALUE SOCK-FD, MSG-SEND.
           
           * Aguardar solicitação de ação do agente
           CALL "receive_line" USING BY VALUE SOCK-FD, MSG-RECV, BY VALUE 500.
           
           * Se for a ação esperada, responder sucesso
           IF MSG-RECV CONTAINS "send_push_notification"
               MOVE "{\"type\":\"action_result\",\"id\":\"act_1\",\"success\":true}" TO MSG-SEND
               CALL "send_message" USING BY VALUE SOCK-FD, MSG-SEND
           END-IF.
           
           STOP RUN.
```

### Compilação
```bash
cobc -x -o cobol_bdi_client client.cob socket_helper.c
```
