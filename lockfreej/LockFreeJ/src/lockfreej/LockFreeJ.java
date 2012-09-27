/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package lockfreej;

import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author yuryb
 */
public class LockFreeJ {
    private final static int THREADS_COUNT = 12;
    
    /**
     * @param args the command line arguments
     */
    public static void main(String[] args) throws InterruptedException {
        
        List<MyWork> threads = new ArrayList<MyWork>(THREADS_COUNT);
        for(int i = 0; i < THREADS_COUNT; ++i) {
            threads.add(new MyWork(i * 10));
        }
        
        for(MyWork w : threads) {
            w.start();
        }
        
        for(MyWork w : threads) {
            w.join();
            w.publishData();
        }
    }
}
