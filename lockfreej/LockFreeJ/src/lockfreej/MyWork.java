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
    private LockFreeQueue queue;
    private static final int OP_COUNT = 1000;
    private List<Integer> poppedData = new ArrayList<Integer>();
    private int addN;
    private Random random = new Random();
    
    MyWork(int n) {
        addN = n;
    }
    
    void publishData() {
        for(Integer i : poppedData) {
            System.out.printf("Th %d, %s\n", addN, i.toString());
        }
    }
    
    @Override
    public void run() {
        try {
                sleep(random.nextInt(200));
            } catch (InterruptedException ex) {
                Logger.getLogger(MyWork.class.getName()).log(Level.SEVERE, null, ex);
            }
        //System.out.println("Hello from a thread!");
        queue = new LockFreeQueue();
        for(int i = 0; i < OP_COUNT; ++i) {
            queue.enqueue(i + addN);            
            Integer o = (Integer)queue.dequeue();
            if (o == null) {
                System.out.printf("Thread %d exhausted queue. \n", addN);
                return;
            }
            poppedData.add(o);
        }
    }
}
