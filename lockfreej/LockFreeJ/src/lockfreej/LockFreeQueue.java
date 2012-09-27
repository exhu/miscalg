/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package lockfreej;

import java.util.concurrent.atomic.AtomicReference;

/**
 *
 * @author yuryb
 */
public class LockFreeQueue implements MyQueue{

    public LockFreeQueue() {
        head = new AtomicReference<Node>();
        tail = new AtomicReference<Node>();
        Node dummy = new Node(null);
        head.set(dummy);
        tail.set(dummy);
    }    
    
    @Override
    public void enqueue(Object o) {
        Node oldTail, oldTailNext;
        Node newTail = new Node(o);
        
        while(true) {
            oldTail = tail.get();
            oldTailNext = tail.get().next.get();
            if (oldTail == tail.get()) {
                if (oldTailNext == null) {
                    if (tail.get().next.compareAndSet(null, newTail)) {
                        break;
                    }
                }
                else {
                    tail.compareAndSet(oldTail, oldTailNext);
                }
            }            
        }
        tail.compareAndSet(oldTail, newTail);        
    }
    
    
    @Override
    public Object dequeue() {
        Node oldHead, oldHeadNext, oldTail;
        
        while(true) {
            oldHead = head.get();
            oldHeadNext = head.get().next.get();
            oldTail = tail.get();
            if (oldHead == head.get()) {
                if (oldHead == oldTail) {
                    if (oldHeadNext == null) {
                        return null;
                    }
                    tail.compareAndSet(oldTail, oldHeadNext);
                }
                else {
                    if (head.compareAndSet(oldHead, oldHeadNext)) {
                        break;
                    }
                }
            } // oldHead == head
        } // while
                
        return oldHeadNext.item;
    }
    
    
    static class Node {
        public Object item;
        public AtomicReference<Node> next;
        
        Node(Object o) {
            item = o;
            next = new AtomicReference<Node>();
        }
    }
    
    private AtomicReference<Node> head, tail;
}
