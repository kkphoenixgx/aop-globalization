FROM public.ecr.aws/docker/library/ubuntu:jammy
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y gobjc gnustep-devel libgnustep-base-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY sdk ./sdk
COPY client.m /app/
RUN . /usr/share/GNUstep/Makefiles/GNUstep.sh && gcc -std=gnu99 -x objective-c client.m sdk/src/BdiClient.m -fconstant-string-class=NSConstantString -I/usr/include/GNUstep -Isdk/include -L/usr/lib -lgnustep-base -lobjc -o client
CMD ["./client"]
