        IDENTIFICATION DIVISION.
        PROGRAM-ID. COBOL-CLIENT.

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01 SOCK-FD          BINARY-LONG.
        01 PORT             BINARY-LONG VALUE 44444.
        01 HOST             PIC X(11) VALUE Z"127.0.0.1".
        01 MSG-SEND         PIC X(200).
        01 MSG-RECV         PIC X(500).
        01 HAS-SUB          BINARY-LONG.

        PROCEDURE DIVISION.
            DISPLAY "============================================================".
            DISPLAY "  OPERAÇÃO DILÚVIO - Teste COBOL".
            DISPLAY "  O Envio de Alertas Móveis de Evacuação".
            DISPLAY "============================================================".
            
            CALL "connect_to_bdi" USING HOST, BY VALUE PORT
                RETURNING SOCK-FD.
            
            IF SOCK-FD < 0
                DISPLAY "Erro ao conectar com o motor BDI"
                STOP RUN
            END-IF.

            DISPLAY "[COBOL] Conectado ao Panteão!".
            
            *> Wait for mas_ready handshake
            CALL "receive_line" USING BY VALUE SOCK-FD, MSG-RECV, BY VALUE 500.
            DISPLAY "[COBOL] Recebido handshake: " MSG-RECV.
            
            *> Send perception/speech act
            MOVE Z'{"type":"message","performative":"tell","sender":"external","receiver":"orquestrador","content":"evacuation_order(zona_sul)"}' TO MSG-SEND.
            CALL "send_message" USING BY VALUE SOCK-FD, MSG-SEND.
            DISPLAY "[COBOL] Enviado speech-act: evacuation_order(zona_sul)".
            
            *> Wait for the action send_push_notification from the agent
            CALL "receive_line" USING BY VALUE SOCK-FD, MSG-RECV, BY VALUE 500.
            DISPLAY "[COBOL] Recebido da Engine: " MSG-RECV.
            
            *> Parse action to send success
            CALL "contains_substring" USING MSG-RECV, Z"send_push_notification"
                RETURNING HAS-SUB.
            IF HAS-SUB = 1
                DISPLAY "[COBOL] >>> AÇÃO DETECTADA: send_push_notification"
                MOVE Z'{"type":"action_result","id":"act_1","success":true}' TO MSG-SEND
                CALL "send_message" USING BY VALUE SOCK-FD, MSG-SEND
                DISPLAY "[COBOL] Confirmacao enviada para a engine"
            END-IF.

            DISPLAY "[DILUVIO] SUCCESS".
            MOVE 0 TO RETURN-CODE.
            STOP RUN.
