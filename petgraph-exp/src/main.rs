use petgraph::graph::DiGraph;

fn main() {
    let mut g = DiGraph::<&str, ()>::new();
    let a = g.add_node("a");
    let b = g.add_node("b");
    let c = g.add_node("c");
    let d = g.add_node("d");
    let e = g.add_node("e");
    g.add_edge(a, b, ());
    g.add_edge(b, c, ());
    g.add_edge(d, e, ());

    println!("Hello, world! {:?}", g);
}
