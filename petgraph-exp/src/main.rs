use petgraph::algo::toposort;
use petgraph::graph::DiGraph;
use petgraph::visit::{Bfs, GraphBase, Walker};
use std::collections::HashMap;

type MyGraph = DiGraph<(), ()>;
type NodeId = <MyGraph as GraphBase>::NodeId;

#[derive(Debug)]
struct Context {
    pub graph: MyGraph,
    pub node_to_data: HashMap<NodeId, String>,
    index_to_order: HashMap<NodeId, usize>,
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

        let index_to_order = sorted
            .iter()
            .enumerate()
            .map(|i| (i.1.clone(), i.0))
            .collect::<HashMap<_, _>>();

        Context {
            graph: g,
            node_to_data: h,
            index_to_order,
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

    fn order_from_index(&self, i: NodeId) -> usize {
        self.index_to_order[&i]
    }

    pub fn toposorted_inplace(&self, nodes: &mut Vec<NodeId>) {
        nodes.sort_by(|a, b| {
            let ia = self.order_from_index(*a);
            let ib = self.order_from_index(*b);

            ia.cmp(&ib)
        });
    }

    /// construct a list of affected nodes, topological sorting not preserved.
    pub fn invalidate_node(&self, node: NodeId) -> Vec<NodeId> {
        // find node by name
        //self.graph.neighbors(node)

        // construct a list of dependent nodes
        let nodes: Vec<NodeId> = Bfs::new(&self.graph, node).iter(&self.graph).collect();
        nodes
    }

    fn make_graph() -> (MyGraph, HashMap<NodeId, String>) {
        let mut g = MyGraph::new();
        let mut h = HashMap::new();
        // 0
        let a = g.add_node(());
        h.insert(a, "a".to_owned());
        // 1
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

// invalidate several input nodes, then merge the arrays of affected
// and topologically resort, use invalidate_node as
// example.
fn main() {
    let c = Context::new();
    let result1 = c.invalidate_node(NodeId::from(0));
    //c.toposorted_inplace(&mut result1);

    let result2 = c.invalidate_node(NodeId::from(1));
    //c.toposorted_inplace(&mut result2);

    let mut result3: Vec<NodeId> = Vec::from(result1.clone());
    result3.extend_from_slice(&result2);
    c.toposorted_inplace(&mut result3);
    result3.dedup();

    println!(
        "Hello, world! {:?},\n result1 = {:?},\n result2 = {:?},\n result3 = {:?}",
        c,
        c.indexes_to_data(&result1),
        c.indexes_to_data(&result2),
        c.indexes_to_data(&result3)
    );
}
