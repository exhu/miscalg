/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package lockfreej;

import java.util.concurrent.locks.ReentrantLock;

/**
 *
 * @author yur
 */
public class LockedQueue implements MyQueue {

    private ReentrantLock lock = new ReentrantLock();

    public LockedQueue() {
        head = tail = new Node(null); // dummy
    }

    @Override
    //synchronized 
    public void enqueue(Object o) {
        Node oldTail, oldTailNext;
        Node newTail = new Node(o);

        lock.lock();
        try {
            while (true) {
                oldTail = tail;
                oldTailNext = tail.next;
                if (oldTail == tail) {
                    if (oldTailNext == null) {
                        tail.next = newTail;
                        break;
                    } else {
                        tail = oldTailNext;
                    }
                } // if
            } // while

            tail = newTail;

        } finally {
            lock.unlock();
        }
    }

    @Override
    //synchronized
    public Object dequeue() {
        Node oldHead, oldHeadNext, oldTail;

        try {
            lock.lock();
            while (true) {
                oldHead = head;
                oldHeadNext = head.next;
                oldTail = tail;
                if (oldHead == head) {
                    if (oldHead == oldTail) {
                        if (oldHeadNext == null) {
                            return null;
                        }
                        tail = oldHeadNext;
                    } else {
                        head = oldHeadNext;
                        break;
                    }
                } // oldHead == head
            } // while
        } finally {
            lock.unlock();
        }

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
