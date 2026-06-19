# ============================================================
# OPERAÇÃO DILÚVIO - Dockerfile C
# "O Controlo Físico das Comportas"
# Compila e executa o cliente PLC em C puro.
# ============================================================

FROM public.ecr.aws/docker/library/gcc:12-bookworm

WORKDIR /app

COPY client.c .

RUN gcc -O2 -Wall -Wextra -o plc_client client.c -lrt

CMD ["./plc_client"]
