TEST_SOURCES = fastboot/protocol.c fastboot/engine.c fastboot/fastboot.c fastboot/usb_linux.c fastboot/util_linux.c
TEST_OBJS = $(TEST_SOURCES:.c=.o)
LIN_SOURCES = download.cpp file.cpp os_linux.cpp qcn.cpp serialif.cpp
LIN_OBJS = $(LIN_SOURCES:.cpp=.o)
TEST_TARGET = quectelFlasher

CXXFLAGS=-lstdc++ -lc -lgcc_s -lusb-1.0

RM = rm -f

all:
	$(CC) -DUSE_FASTBOOT $(TEST_SOURCES) $(LIN_SOURCES) $(CXXFLAGS) -o $(TEST_TARGET)

clean:
	$(RM) $(TEST_OBJS) $(TEST_TARGET)
