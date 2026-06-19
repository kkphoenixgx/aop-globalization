# =============================================================
# OPERAÇÃO DILÚVIO — Os Olhos do Drone (Python)
# Dockerfile para teste IPC do drone com detecção YOLO.
# Base: python:3.11-slim (~50MB) — sem dependências externas.
# =============================================================

FROM public.ecr.aws/docker/library/python:3.11-slim

LABEL maintainer="Panteão BDI Engine"
LABEL description="Teste Dilúvio — Python (Os Olhos do Drone)"

WORKDIR /app

COPY client.py .

CMD ["python3", "-u", "client.py"]
