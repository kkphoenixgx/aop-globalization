FROM public.ecr.aws/docker/library/gcc:12-bookworm
WORKDIR /app
COPY sdk sdk
COPY src/client.c client.c
RUN gcc -O2 -Wall -Wextra -I sdk/include -o plc_client client.c sdk/src/panteao_client.c -lrt
CMD ["./plc_client"]
