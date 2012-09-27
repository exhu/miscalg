/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package lockfreej;

/**
 *
 * @author yur
 */
public class LockedQueue implements MyQueue {

    public LockedQueue() {
        head = tail = new Node(null); // dummy
    }
    
    
    
    @Override
    synchronized public void enqueue(Object o) {
        Node oldTail, oldTailNext;
        Node newTail = new Node(o);
        
        while(true) {
            oldTail = tail;
            oldTailNext = tail.next;
            if (oldTail == tail) {
                if (oldTailNext == null) {
                    tail.next = newTail;
                    break;
                }
                else {
                    tail = oldTailNext;
                }
            }            
        }
        tail = newTail;
    }
    
    
    @Override
    synchronized public Object dequeue() {
        Node oldHead, oldHeadNext, oldTail;
        
        while(true) {
            oldHead = head;
            oldHeadNext = head.next;
            oldTail = tail;
            if (oldHead == head) {
                if (oldHead == oldTail) {
                    if (oldHeadNext == null) {
                        return null;
                    }
                    tail = oldHeadNext;
                }
                else {
                    head = oldHeadNext;
                    break;                    
                }
            } // oldHead == head
        } // while
                
        return oldHeadNext.item;
    }
    
    static class Node {
        public Object item;
        volatile public Node next;
        
        Node(Object o) {
            item = o;
            next = null;
        }
    }
    
    private volatile Node head, tail;
    
}
