CC=g++
SRCS=acc_calc.cpp
HDRS=acc_calc.hpp
OBJ=acc_calc.o

all: main_prog

main_prog: acc_calc.o interconnect.o ram.o tb.o vp.o main.o
	$(CC) -I ${SYSTEMC}/include -L${SYSTEMC}/lib-linux64 -lsystemc -o main_prog acc_calc.o interconnect.o ram.o tb.o vp.o main.o `pkg-config --cflags --libs opencv4`

$(OBJ): $(SRCS) $(HDRS)
	$(CC) -I ${SYSTEMC}/include -L${SYSTEMC}/lib-linux64 -lsystemc -o $(OBJ) -c $(SRCS)

interconnect.o: interconnect.cpp interconnect.hpp vp_addr.hpp
	$(CC) -I ${SYSTEMC}/include -L${SYSTEMC}/lib-linux64 -lsystemc -o interconnect.o -c interconnect.cpp

tb.o: tb.hpp tb.cpp vp.hpp acc_calc.hpp
	$(CC) -I ${SYSTEMC}/include -L${SYSTEMC}/lib-linux64 -lsystemc `pkg-config --cflags --libs opencv4` -o tb.o -c tb.cpp

vp.o: vp.hpp vp.cpp acc_calc.hpp interconnect.hpp ram.hpp
	$(CC) -I ${SYSTEMC}/include -L${SYSTEMC}/lib-linux64 -lsystemc -o vp.o -c vp.cpp

ram.o: ram.hpp ram.cpp
	$(CC) -I ${SYSTEMC}/include -L${SYSTEMC}/lib-linux64 -lsystemc -o ram.o -c ram.cpp

main.o: tb.hpp vp.hpp main.cpp
	$(CC) -I ${SYSTEMC}/include -L${SYSTEMC}/lib-linux64 -lsystemc `pkg-config --cflags --libs opencv4` -o main.o -c main.cpp

.PHONY: clean
clean:
	rm $(OBJ) interconnect.o ram.o tb.o vp.o main.o main_prog
