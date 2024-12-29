use petgraph::algo::toposort;
use petgraph::graph::DiGraph;

type MyGraph = DiGraph<&'static str, ()>;

fn make_graph() -> MyGraph {
    let mut g = MyGraph::new();
    let a = g.add_node("a");
    let b = g.add_node("b");
    let c = g.add_node("c");
    let d = g.add_node("d");
    let e = g.add_node("e");
    g.add_edge(a, b, ());
    g.add_edge(b, c, ());
    g.add_edge(d, e, ());

    g
}

fn main() {
    let g = make_graph();
    let sorted = toposort(&g, None);
    match sorted {
        Ok(nodes) => println!("Sorted = {:?}", nodes),
        Err(cycle) => println!("Cycle = {:?}", cycle),
    }

    println!("Hello, world! {:?}", g);
}
