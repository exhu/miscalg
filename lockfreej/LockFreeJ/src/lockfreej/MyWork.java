/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package lockfreej;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author yuryb
 */
public class MyWork extends Thread {
    //private static LockFreeQueue queue = new LockFreeQueue();
    private MyQueue queue;
    public static final int OP_COUNT = 100000;
    public List<Integer> poppedData = new ArrayList<Integer>();
    private int addN;
    private Random random = new Random();
    public long runTime = 0;
    
    private long tStart = 0;
    
    MyWork(int n, MyQueue q) {
        addN = n;
        queue = q;
    }    
    
    void publishData() {
        for(Integer i : poppedData) {
            System.out.printf("Th %d, %s\n", addN, i.toString());
        }
    }
    
    @Override
    public void run() {
        tStart = System.currentTimeMillis();
        //System.out.println("Hello from a thread!");                
        for(int i = 0; i < OP_COUNT; ++i) {
            queue.enqueue(i + addN);
            /*
            try {
                sleep(random.nextInt(22));
            } catch (InterruptedException ex) {
                Logger.getLogger(MyWork.class.getName()).log(Level.SEVERE, null, ex);
            }
            */
            Integer o = (Integer)queue.dequeue();
            if (o == null) {
                calcRunTime();
                System.out.printf("Thread %d exhausted queue. \n", addN);                
                return;
            }
            poppedData.add(o);
        }
        
        calcRunTime();
    }
    
    void calcRunTime() {
        runTime = System.currentTimeMillis() - tStart;
    }
}
