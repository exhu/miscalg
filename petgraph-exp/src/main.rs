use petgraph::algo::toposort;
use petgraph::graph::DiGraph;
use petgraph::visit::{Bfs, GraphBase, Walker};
use std::collections::HashMap;

type MyGraph = DiGraph<(), ()>;
type NodeId = <MyGraph as GraphBase>::NodeId;

#[derive(Debug)]
struct Context {
    graph: MyGraph,
    toposorted: Vec<NodeId>,
    node_to_data: HashMap<NodeId, String>,
}

impl Context {
    pub fn new() -> Context {
        let (g, h) = Self::make_graph();

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
            node_to_data: h,
        }
    }

    pub fn indexes_to_data(&self, indexes: &[NodeId]) -> Vec<String> {
        indexes
            .iter()
            .map(|i| {
                self.node_to_data
                    .get(&i)
                    .cloned()
                    .unwrap_or("none".to_owned())
            })
            .collect()
    }

    // TODO invalidate several input nodes, then merge the arrays of affected
    // and topologically resort using index_to_order, use invalidate_node as
    // example.

    /// construct a list of affected nodes preserving topological sorting.
    pub fn invalidate_node(&self, node: NodeId) -> Vec<NodeId> {
        // find node by name
        //self.graph.neighbors(node)

        // TODO move to a method
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

    fn make_graph() -> (MyGraph, HashMap<NodeId, String>) {
        let mut g = MyGraph::new();
        let mut h = HashMap::new();
        let a = g.add_node(());
        h.insert(a, "a".to_owned());
        let b = g.add_node(());
        h.insert(b, "b".to_owned());
        let c = g.add_node(());
        h.insert(c, "c".to_owned());
        let d = g.add_node(());
        h.insert(d, "d".to_owned());
        let e = g.add_node(());
        h.insert(e, "e".to_owned());
        g.add_edge(a, b, ());
        g.add_edge(a, c, ());
        g.add_edge(b, c, ());
        g.add_edge(d, e, ());

        (g, h)
    }
}

fn main() {
    let c = Context::new();
    let result = c.invalidate_node(NodeId::from(0));

    println!(
        "Hello, world! {:?}, result = {:?}",
        c,
        c.indexes_to_data(&result)
    );
}
