SOURCES = smpp_server.c
OBJS = $(SOURCES:.c=.o)
TARGET = smpp


LIBS =

RM = rm -f

all: 
	$(CC) $(SOURCES) $(LIBS) -o $(TARGET)

clean:
	$(RM) $(OBJS) $(TARGET)
