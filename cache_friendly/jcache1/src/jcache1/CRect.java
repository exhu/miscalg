/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package jcache1;

/**
 *
 * @author yur
 */
public class CRect {
	public float x,y,w,h;

	public void add(CRect r) {
		x += r.x;
		y += r.y;
	}

	public void assignXY(CRect r, CRect addIt) {
		x = r.x + addIt.x;
		y = r.y + addIt.y;
	}

	public void assignWH(CRect r) {
		w = r.w;
		h = r.h;
	}
	
}
