import std.algorithm.iteration;
import std.algorithm.comparison;
import std.algorithm.searching;
import std.stdio;
import std.string;
import std.sumtype;
import std.typecons : Nullable;

alias CellIndex = size_t;

/// Graph item.
struct Edge
{
    /// Edge direction is fromCell -> toCell.
    CellIndex fromCell, toCell;
}

alias Edges = Edge[];

version(unittest)
{
    private alias debugPrintln = writeln;
    private alias debugPrintfln = writefln;
}
else
{
    private void debugPrintln(A...)(A _) {}
    alias debugPrintfln = debugPrintln;
}

/// Directional graph where nodes a zero-based integers.
struct Graph
{
private:
    immutable Edges edges;
    immutable size_t nodesCount;
public:
    /// The way to create a Graph.
    static Graph makeFromEdges(immutable Edges edges)
    {
        immutable maxNode = fold!((a, c) => max(a, max(c.fromCell, c.toCell)))(edges, 0L);
        return Graph(edges, maxNode + 1);
    }

    /// Print to stdout.
    void dump() 
    {
        printEdges(edges);
    }

    /// Get all destination nodes from n.
    auto allDestFrom(CellIndex n)
    {
        const f = (const Edge e) => e.fromCell == n;
        const m = (const Edge e) => e.toCell;
        return filter!(f)(edges).map!m();
    }

    /// Generate text for .gv file to be processed by dot program.
    string generateDotText(string name)
    {
        string buf;
        buf ~= format("digraph \"%s\" {\n", name);
        auto e = (const Edge e) => buf ~= format("%d -> %d\n", e.fromCell, e.toCell);
        each!e(edges);
        buf ~= "}";
        return buf;
    }

    /// Return topological sort result.
    SortResult topoSort()
    {
        auto ctx = SortContext(this);
        for (auto i = 0; i < nodesCount; ++i)
        {
            debugPrintfln("top iter %d", i);
            const foundCycle = visit(ctx, i);

            Nullable!CellIndex cycle = foundCycle.match!(
                (SortContext.CycleFound c) => Nullable!CellIndex(c.cycle),
                _ => Nullable!CellIndex());

            if (!cycle.isNull())
            {
                debugPrintln("cycle!");
                return SortResult(CycleDetected(cycle.get()));
            }
        }
        debugPrintln("sorted!");
        return SortResult(SortedCells(ctx.sorted));
    }

    private static void printEdges(const Edges edges)
    {
        auto f = (const Edge n) => writefln("edge %d -> %d", n.fromCell, n.toCell);
        each!(f)(edges);
    }
}

/// Sorted data if result is sorted.
struct SortedCells
{
    CellIndex[] sorted;
}

/// First spotted node to be in a cycle.
struct CycleDetected
{
    CellIndex cycle;
}

/// Topological sort result.
alias SortResult = SumType!(SortedCells, CycleDetected);

private struct SortContext
{
    Graph graph;
    CellIndex[] sorted, permMarked, tempMarked;

    struct ContinueVisiting {}
    struct CycleFound
    {
        CellIndex cycle = CellIndex.max;
    }
    alias VisitStatus = SumType!(ContinueVisiting, CycleFound);
    
    void markPerm(CellIndex n)
    {
        permMarked ~= n;
    }

    void addToSorted(CellIndex n)
    {
        sorted ~= n;
    }

    void markTemp(CellIndex n)
    {
        tempMarked ~= n;
    }
} // SortContext

private bool isCycle(SortContext.VisitStatus status)
{
    return status.match!((SortContext.CycleFound) => true,
                         _ => false);
}

private SortContext.VisitStatus visit(ref SortContext ctx, CellIndex n)
{
    debugPrintfln("%d visit", n);
    if (find(ctx.permMarked, n).empty == false)
    {
        debugPrintln("already perm");
        return SortContext.VisitStatus();
    }
    else if (find(ctx.tempMarked, n).empty == false)
    {
        debugPrintfln("%d early cycle", n);
        return SortContext.VisitStatus(SortContext.CycleFound(n));
    }
    ctx.markTemp(n);
    auto nodesOfN = ctx.graph.allDestFrom(n);
    debugPrintfln("%d nodesOfN = %s", n, nodesOfN);

    auto foundCycle = SortContext.VisitStatus();
    foreach (i; nodesOfN)
    {
        foundCycle = visit(ctx, i);
        if (isCycle(foundCycle))
        {
            break;
        }
    }
    ctx.markPerm(n);
    ctx.addToSorted(n);
    if (!isCycle(foundCycle))
    {
        debugPrintfln("%d ctx continue", n);
        return SortContext.VisitStatus();
    }
    assert(isCycle(foundCycle));
    debugPrintfln("%d ctx return cycle %s", n, foundCycle);
    return foundCycle;
}

unittest
{
    auto fvisit(in CellIndex c)
    {
        if (c & 1)
            return SortContext.VisitStatus(SortContext.ContinueVisiting());
        return SortContext.VisitStatus(SortContext.CycleFound(c));
    }

    auto mapped = map!fvisit([2]);
    auto found = find!isCycle(mapped);
    assert(!found.empty());
    assert(isCycle(found.front));
}

unittest
{
    immutable edges = [Edge(0, 1), Edge(2, 1), Edge(1, 3), Edge(3, 2)];
    auto graph = Graph.makeFromEdges(edges);
    graph.dump();
    auto gv = graph.generateDotText("mygr");
    toFile(gv, "temp.gv");
    auto sorted = graph.topoSort();
    writefln("sorted: %s", sorted);
}
