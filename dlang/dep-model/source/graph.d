import std.algorithm.iteration;
import std.algorithm.comparison;
import std.stdio : writefln;
import std.format;

alias CellIndex = size_t;

struct Edge
{
    CellIndex from_cell, to_cell;
}

alias Edges = Edge[];

struct Graph
{
    immutable Edges edges;
    immutable size_t nodesCount;

    static Graph make_from_edges(immutable Edges edges)
    {
        immutable max_node = fold!((a, c) => max(a, max(c.from_cell, c.to_cell)))(edges, 0L);
        return Graph(edges, max_node + 1);
    }

    void dump()
    {
        print_edges(edges);
    }

    auto all_dest_from(CellIndex n)
    {
        auto f = (const Edge e) => e.from_cell == n;
        auto m = (const Edge e) => e.to_cell;
        return filter!(f)(edges).map!m();
    }

  string generate_dot_text(string name) {
    string buf;
    buf ~= format("digraph \"%s\" {\n", name);
    auto e = (const Edge e) => buf ~= format("%d -> %d\n", e.from_cell, e.to_cell);
    each!e(edges);
    buf ~= "}";
    return buf;
  }
}

void print_edges(const Edges edges)
{
    auto f = (const Edge n) => writefln("edge %d -> %d", n.from_cell, n.to_cell);
    each!(f)(edges);
}

struct SortResult {
  enum Selector {
    sorted,
    cycle,
  }
  Selector result;
  union {
    Edges sorted;
    CellIndex cycle;
  }
}

// TODO sort

unittest
{
    import std.conv;

    //writefln("%s", to!string(typeof(l)));
    auto g = Graph.make_from_edges([Edge(0, 1), Edge(1, 2), Edge(3, 4)]);
    assert(g.nodesCount == 5);
}
