/**
 * File: thread-pool.cc
 * --------------------
 * Presents the implementation of the ThreadPool class.
 */
#include "Semaphore.h"
#include "thread-pool.h"
using namespace std;
/**
 * Ideas:
 * - dispatcher y schedule se turnan para modificar cola: queueLock
 * - contador de tareas en cola, asi dispatcher puede dormir: semaforo semTareasDisp
 * - workers libres/ocupados: dispatcher puede dormir -> semWorkersLibres
 * - worker tiene que poder dormir si no hay tareas: semWorker -> disp lo despierta
 */


 /*
 * PSEUDO:
 * Inicializo semaforos -> semTareasDisp, semWorkersLibres
 * Inicializo workers -> los tengo en vector wts
 * inicializo dispatcher
 */
ThreadPool::ThreadPool(size_t numThreads) :
  wts(numThreads),
  done(false),
  semTareasDisp(0),
  semWorkersLibres(numThreads),
  tareasEnProceso(0)
  {

  // Inicializar los workers
  for (int i = 0; i < numThreads; i++) {
    int workerId = i;
    wts[workerId].id = workerId;
    wts[workerId].ts = thread([this, workerId] { worker(workerId); });
  }
  // Inicializo dispatcher
  dt = thread([this] { dispatcher(); });

}

/*PSEUDO:
 * - schedule pushea tarea, bloquea cola mientras lo hace
 * - despierta a dispatcher y aumenta contador de tareas en cola
 *
 */
void ThreadPool::schedule(const function<void(void)>& thunk) {
  // Si destruyo, schedule tiene q apagarse para no aceptar tareas nuevas
  if(done){return;}

  // Entra una tarea a todo el circuito, aumento tareasEnProceso
  lock_guard<mutex> tareasLG(tareasLock);
  tareasEnProceso++;

  // bloqueo cola y pusheo tarea
  lock_guard<mutex> colaLG(queueLock);
  colaTareas.push(thunk);
  // le aviso a dispatcher, lo despierto, y contador tareas en cola ++
  semTareasDisp.signal();
}


/*PSEUDO:
 * loop infinito:
 *  - deberia dormir primero, recien despertar si hay tarea
 *  - si hay tarea, la ejecuta
 *  - dsp de hacer su trabajo, avisa que quedó libre
 */
void ThreadPool::worker(int id) {
  while (true) {
    // Duermo a la señal de workerSem que manda el dispatcher
    wts[id].workerSem.wait();
    // Si destructor avisa, corto
    if (done) return;
    // Hago tarea propiamente dicha
    wts[id].thunk();

    // Para el wait
    // Decremento tareas en proceso pq tarea sale del circuito
    {
    lock_guard<mutex> tareasLG(tareasLock);
    tareasEnProceso--;


    //Chequeo si soy fue la última tarea del circuito entero (cola+workers)
    bool soyElUltimo = (tareasEnProceso == 0);
    // Si soy el último, mando la señal con la condición
    if(soyElUltimo){
      allTasksDone.notify_all();
    }
    } //termino lock de tareasEnProceso

    // aviso que quedo libre, bloqueando wts
    {
    lock_guard<mutex> wtsLG(wtsLock);
    wts[id].busy = false;
    } // cierro lock de wtsLock

    // subo contador de workers libres, despierto a dispatcher
    semWorkersLibres.signal();
  }
}

/*PSEUDO:
 * - loop infinito
 * - si no hay tareas en cola, se duerme
 * - si hay, hace pops de la cola, la bloquea mientras lo hace
 * - chequea si hay workers libres, si no, se duerme
 * - si hay workers libres, despierta a uno -> le manda tarea
 * - tiene que bajar contador de workers libres
 * - ver si quedan tareas en cola y trabajando, ver modo de llamar destructor
 * -
 */
void ThreadPool::dispatcher() {
  while (true) {

    // chequea si hay tareas en cola, sino duerme
    semTareasDisp.wait();
    if(done) return;
    // chequea si hay workers libres, sino duerme
    semWorkersLibres.wait();
    if(done) return;
    // dsp de que pasan las dos cosas, se pone a trabajar
    function<void(void)> thunk;
    // bloquea cola
    {
    lock_guard<mutex> colaLG(queueLock);
    // saca tarea de la cola
    thunk = colaTareas.front();
    colaTareas.pop();
    }
    // tengo que buscar algun worker libre
    int workerId = -1;
    // boqueo wts
    {
    lock_guard<mutex> wtsLG(wtsLock);
    // busco worker libre
    for(int i = 0; i < wts.size(); i++) {
      if(!wts[i].busy) {
        wts[i].busy = true;
        workerId = i;
        break;
      }
    }
    }
    wtsLock.unlock();
    // tengo el id, le mando la tarea y lo despierto
    wts[workerId].thunk = thunk;
    wts[workerId].workerSem.signal();
  }

}

/*
* - copio el wait del semaforo pero es condition_variable con condicion ==0
* - tiene que retornar cuando se cumple la condicion
*/
void ThreadPool::wait() {
  unique_lock<mutex> lk(tareasLock);
  allTasksDone.wait(lk, [this]{return tareasEnProceso == 0;});
}

/*
* - Destructor:
* - tiene que ejecutar espera wait()
* - activar flag de done
* - despertar a todo el mundo por si estaban durmiendo para que vean el done
*/
ThreadPool::~ThreadPool() {
  // Espero que se terminen las tareas
  wait();
  // doy la orden de cerrar
  done = true;

  // despierto dispatcher, puede estar dormido en dos semáforos
  semTareasDisp.signal();
  semWorkersLibres.signal();

  // despierto workers
  for (worker_t& worker : wts){
    worker.workerSem.signal();
  }

  // Join para terminar main cuando terminen threads
  dt.join();
  for (auto& worker : wts) {
    worker.ts.join();
  }



}
