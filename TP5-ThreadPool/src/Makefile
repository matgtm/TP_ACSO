# Compiler settings - Can change to clang++ if preferred
CXX = g++
CXXFLAGS = -std=c++11 -Wall -pthread -g

# Ejecutables
TARGETS = threadpool tptest tpcustomtest

# Reglas para cada ejecutable
threadpool: thread-pool.o Semaphore.o main.o
	$(CXX) $(CXXFLAGS) -o $@ thread-pool.o Semaphore.o main.o

tptest: thread-pool.o Semaphore.o tptest.o
	$(CXX) $(CXXFLAGS) -o $@ thread-pool.o Semaphore.o tptest.o

tpcustomtest: thread-pool.o Semaphore.o tpcustomtest.o
	$(CXX) $(CXXFLAGS) -o $@ thread-pool.o Semaphore.o tpcustomtest.o

# Reglas para compilar los objetos
thread-pool.o: thread-pool.cc thread-pool.h
	$(CXX) $(CXXFLAGS) -c thread-pool.cc

Semaphore.o: Semaphore.cc Semaphore.h
	$(CXX) $(CXXFLAGS) -c Semaphore.cc

main.o: main.cc thread-pool.h
	$(CXX) $(CXXFLAGS) -c main.cc

tptest.o: tptest.cc thread-pool.h
	$(CXX) $(CXXFLAGS) -c tptest.cc

tpcustomtest.o: tpcustomtest.cc thread-pool.h
	$(CXX) $(CXXFLAGS) -c tpcustomtest.cc

# Limpieza
clean:
	rm -f *.o $(TARGETS)

.PHONY: all clean
