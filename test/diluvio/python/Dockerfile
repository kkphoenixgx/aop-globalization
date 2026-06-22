# =============================================================
# OPERAÇÃO DILÚVIO — Os Olhos do Drone (Python)
# =============================================================

FROM public.ecr.aws/docker/library/python:3.11-slim

LABEL maintainer="Panteão BDI Engine"
LABEL description="Teste Dilúvio — Python (Os Olhos do Drone)"

WORKDIR /app

COPY sdk ./sdk
COPY client.py .

RUN pip install ./sdk

CMD ["python3", "-u", "client.py"]
