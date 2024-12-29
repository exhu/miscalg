use std::ops::Index;

use petgraph::algo::toposort;
use petgraph::graph::DiGraph;
use petgraph::visit::GraphBase;

type MyGraph = DiGraph<&'static str, ()>;
type NodeId = <MyGraph as GraphBase>::NodeId;

#[derive(Debug)]
struct Context {
    graph: MyGraph,
    toposorted: Vec<NodeId>,
}

impl Context {
    pub fn new() -> Context {
        let g = make_graph();

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

    pub fn invalidate_node(&self, name: &str) {
        // construct a list of affected nodes preserving topological sorting
    }
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

fn main() {
    let c = Context::new();
    c.invalidate_node("a");

    println!("Hello, world! {:?}", c);
}
