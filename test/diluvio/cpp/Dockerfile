FROM public.ecr.aws/docker/library/gcc:12-bookworm
WORKDIR /app
COPY sdk sdk
COPY src/client.cpp client.cpp
RUN g++ -O2 -Wall -Wextra -std=c++17 -I sdk/include -o cpp_client client.cpp sdk/src/panteao_client.cpp -lrt
CMD ["./cpp_client"]
