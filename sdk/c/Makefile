CC=gcc
CFLAGS=-Iinclude -Wall -Wextra -O2
LDFLAGS=

LIBRARY=libpanteao_client.a
SOURCES=src/panteao_client.c
OBJECTS=$(SOURCES:.c=.o)

all: $(LIBRARY)

$(LIBRARY): $(OBJECTS)
	ar rcs $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f src/*.o $(LIBRARY)
