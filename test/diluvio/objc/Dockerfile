FROM public.ecr.aws/docker/library/ubuntu:jammy
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y gobjc gnustep-devel libgnustep-base-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY client.m /app/
RUN . /usr/share/GNUstep/Makefiles/GNUstep.sh && gcc -x objective-c client.m -fconstant-string-class=NSConstantString -I/usr/include/GNUstep -L/usr/lib -lgnustep-base -lobjc -o client
CMD ["./client"]
