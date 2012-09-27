/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package lockfreej;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;

/**
 *
 * @author yuryb
 */
public class LockFreeJ {
    private final static int THREADS_COUNT = 16;
    private final static int RUNS_COUNT = 10;    
    
    private long timeInThreadsTotal = 0;
    /**
     * @param args the command line arguments
     */
    public static void main(String[] args) throws InterruptedException {
        LockFreeJ j = new LockFreeJ();
        
        for(int i = 0; i < 10; ++i) {
            System.out.printf("---- BIG RUN %d\n", i);
            
            System.out.println("Locked queue...");
            j.run(new LockedQueue());
            
            System.out.println("Lock-free queue...");
            j.run(new LockFreeQueue());                        
        }
        
        
    }
    
    public void run(MyQueue q) throws InterruptedException {
        timeInThreadsTotal = 0;
        
        long tStart = System.currentTimeMillis();
        for(int i = 0; i < RUNS_COUNT; ++i) {
            System.out.printf("Run %d...\n", i);                        
            runCycle(q);
            //runCycle(new LockFreeQueue());
            //runCycle(new LockedQueue());
            
        }

        long tEnd = System.currentTimeMillis();
        System.out.printf("Finished all runs in %d millis\n", tEnd-tStart);
        //System.out.printf("Virtual time in threads total %d millis\n", timeInThreadsTotal);
    }
    
    public void runCycle(MyQueue q) throws InterruptedException {        
        List<Thread> threads = new ArrayList<Thread>(THREADS_COUNT);
        HashSet<Integer> allItems = new HashSet<Integer>();
        long timeInThreads = 0;
        
        for(int i = 0; i < THREADS_COUNT; ++i) {
            threads.add(new MyWork(i * MyWork.OP_COUNT, q));
        }
        
    
        for(Thread w : threads) {
            w.start();
        }        
        
        for(Thread w : threads) {
            w.join();
            MyWork ww = (MyWork) w;
            //ww.publishData();
            allItems.addAll(ww.poppedData);
            timeInThreads += ww.runTime;
        }
        
        if (allItems.size() == THREADS_COUNT*MyWork.OP_COUNT) {
            System.out.println("Items count matches");
        }
        else {
            System.out.printf("Items count is %d, must be %d\n", allItems.size(), THREADS_COUNT*MyWork.OP_COUNT);
        }
        
        //System.out.printf("Threads run time = %d\n", timeInThreads);
        timeInThreadsTotal += timeInThreads;
    }
}
