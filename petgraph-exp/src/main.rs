use petgraph::algo::toposort;
use petgraph::graph::DiGraph;
use petgraph::visit::{Bfs, GraphBase, Walker};
use std::collections::HashMap;

type MyGraph = DiGraph<&'static str, ()>;
type NodeId = <MyGraph as GraphBase>::NodeId;

#[derive(Debug)]
struct Context {
    graph: MyGraph,
    toposorted: Vec<NodeId>,
    // TODO map NodeId to names
}

impl Context {
    pub fn new() -> Context {
        let g = Self::make_graph();

        let sorted = toposort(&g, None);
        let sorted = match sorted {
            Ok(nodes) => {
                println!("Sorted = {:?}", nodes);
                nodes
            }
            Err(cycle) => {
                println!("Cycle = {:?}", cycle);
                Vec::new()
            }
        };
        Context {
            graph: g,
            toposorted: sorted,
        }
    }

    /// construct a list of affected nodes preserving topological sorting.
    pub fn invalidate_node(&self, node: NodeId) -> Vec<NodeId> {
        // find node by name
        //self.graph.neighbors(node)

        let index_to_order = self
            .toposorted
            .iter()
            .enumerate()
            .map(|i| (i.1, i.0))
            .collect::<HashMap<_, _>>();

        // construct a list of dependent nodes
        let mut nodes: Vec<NodeId> = Bfs::new(&self.graph, node).iter(&self.graph).collect();

        // sort using index_to_order
        nodes.sort_by(|a, b| {
            let ia = index_to_order[a];
            let ib = index_to_order[b];

            ia.cmp(&ib)
        });
        nodes
    }

    fn make_graph() -> MyGraph {
        let mut g = MyGraph::new();
        let a = g.add_node("a");
        let b = g.add_node("b");
        let c = g.add_node("c");
        let d = g.add_node("d");
        let e = g.add_node("e");
        g.add_edge(a, b, ());
        g.add_edge(a, c, ());
        g.add_edge(b, c, ());
        g.add_edge(d, e, ());

        g
    }
}

fn main() {
    let c = Context::new();
    let result = c.invalidate_node(NodeId::from(0));

    println!("Hello, world! {:?}, result = {:?}", c, result);
}
