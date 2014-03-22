/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package jcache1;

import java.util.ArrayList;

/**
 *
 * @author yur
 */
public class CNode {
	public CRect global;
	public CRect local;
	public int flags;

	static final int FLAG_UPDATED = 1;
	static final int FLAG_UPDATED_NODES = 2;

	public ArrayList<CNode> nodes;
	
	public CNode() {
		global = new CRect();
		local = new CRect();
		flags = 0;
		nodes = new ArrayList<>();
	}

	public void UpdateSelf(CRect g) {
		global.assignXY(g, local);
		global.assignWH(local);
		flags |= FLAG_UPDATED;
	}

	public void UpdateNodes() {
		for(int n=0; n < nodes.size(); ++n) {
			nodes.get(n).UpdateSelf(global);	
		}
		for(int n=0; n < nodes.size(); ++n) {
			nodes.get(n).UpdateNodes();	
		}

		flags |= FLAG_UPDATED_NODES;
	}
}
