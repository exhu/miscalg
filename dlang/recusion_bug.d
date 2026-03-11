// TODO add impl using SumType

import std.algorithm.iteration;
import std.algorithm.comparison;
import std.algorithm.searching;
import std.stdio;
import std.string;
import std.sumtype;

alias CellIndex = size_t;

/// Graph item.
struct Edge
{
    /// Edge direction is fromCell -> toCell.
    CellIndex fromCell, toCell;
}

alias Edges = Edge[];

version (unittest)
{
    private alias debugPrintln = writeln;
    private alias debugPrintfln = writefln;
}
else
{
    private void debugPrintln(A...)(A _)
    {
    }

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
    auto allDestFrom(CellIndex n) const
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
    SortResult tsort()
    {
        auto ctx = SortContext(this);
        for (auto i = 0; i < nodesCount; ++i)
        {
            debugPrintfln("top iter %d", i);
            const foundCycle = SortContext.visit(ctx, i);

            if (foundCycle.selector is SortContext.VisitStatus.Selector.cycleFound)
            {
                debugPrintln("cycle!");
                return SortResult.makeCycle(foundCycle.cycle);
            }
        }
        debugPrintln("sorted!");
        return SortResult.makeSorted(ctx.sorted);
    }

    private static void printEdges(const Edges edges)
    {
        auto f = (const Edge n) => writefln("edge %d -> %d", n.fromCell, n.toCell);
        each!(f)(edges);
    }
}

/// Topological sort result.
struct SortResult
{
    /// One of the outcomes.
    enum Selector
    {
        sorted,
        cycle,
    }

    /// Data selector.
    Selector result;

    union
    {
        /// Sorted data if result is sorted.
        CellIndex[] sorted;
        /// First spotted node to be in a cycle.
        CellIndex cycle;
    }

    private this(CellIndex cycle)
    {
        result = Selector.cycle;
        this.cycle = cycle;
    }

    private this(CellIndex[] sorted)
    {
        this.sorted = sorted;
        result = Selector.sorted;
    }

    private static SortResult makeCycle(CellIndex c)
    {
        return SortResult(c);
    }

    private static SortResult makeSorted(CellIndex[] s)
    {
        return SortResult(s);
    }
}

private struct SortContext
{
    Graph graph;
    CellIndex[] sorted, permMarked, tempMarked;

    struct VisitStatus
    {
        enum Selector
        {
            continueVisiting,
            cycleFound,
        }

        Selector selector = Selector.continueVisiting;
        CellIndex cycle = CellIndex.max;

        this(CellIndex cycle)
        {
            this.cycle = cycle;
            selector = Selector.cycleFound;
        }

        bool isCycle()
        {
            return selector is Selector.cycleFound;
        }
    }

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

    // there's weird bug either in the function or the compiler regarding recursive fvisit()
    version (none)
    {
    }
    else
    {
        static VisitStatus visit(ref SortContext ctx, CellIndex n)
        {
            writefln("%d visit", n);
            if (find(ctx.permMarked, n).empty == false)
            {
                writeln("already perm");
                return VisitStatus();
            }
            else if (find(ctx.tempMarked, n).empty == false)
            {
                writefln("%d early cycle", n);
                return VisitStatus(n);
            }
            ctx.markTemp(n);
            VisitStatus fvisit(CellIndex c)
            {
                writefln("%d ctx fvisit %d, ctx = %x", n, c, &ctx);
                auto r = visit(ctx, c);
                writefln("%d ctx fvisit result %s", n, r);
                return r;
            }

            bool is_cycle(in VisitStatus s)
            {
                auto r = (s.selector is VisitStatus.Selector.cycleFound);
                writefln("%d is_cycle %s", n, r);
                return r;
            }

            import std.array;

            auto nodesOfN = ctx.graph.allDestFrom(n);
            writefln("%d nodesOfN = %s", n, nodesOfN);

            auto mapped = map!fvisit(nodesOfN);
            writefln("%d mapped", n);
            // here there's probably compiler bug, since it fails
            auto foundRange = find!is_cycle(mapped);
            version(none)
            {
                VisitStatus found;
                foreach (i; mapped)
                {
                    found = i;
                    if (is_cycle(i))
                    {
                        break;
                    }
                }
            }
            //writefln("range: %s", foundRange);
            ctx.markPerm(n);
            ctx.addToSorted(n);
            //if (!is_cycle(found))//foundRange.empty)
            if (foundRange.empty)
            {
                writefln("%d ctx continue", n);
                return VisitStatus(VisitStatus.Selector.continueVisiting);
            }
            //auto foundCycle = found;//foundRange.front;
            auto foundCycle = foundRange.front;
            // compiler bug if find over map range is used
            writefln("VisitStatus = %s", foundCycle);
            assert(foundCycle.selector is VisitStatus.Selector.cycleFound);
            writefln("%d ctx return cycle %s", n, foundCycle);
            return foundCycle;
        }
    }
}

version (none)
{
    private SortContext.VisitStatus visit(SortContext ctx, CellIndex n)
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
            return SortContext.VisitStatus(n);
        }
        ctx.markTemp(n);
        auto nodesOfN = ctx.graph.allDestFrom(n);
        debugPrintfln("%d nodesOfN = %s", n, nodesOfN);

        auto foundCycle = SortContext.VisitStatus();
        foreach (i; nodesOfN)
        {
            foundCycle = visit(ctx, i);
            if (foundCycle.isCycle)
                break;
        }
        ctx.markPerm(n);
        ctx.addToSorted(n);
        if (!foundCycle.isCycle)
        {
            debugPrintfln("%d ctx continue", n);
            return SortContext.VisitStatus();
        }
        assert(foundCycle.selector is SortContext.VisitStatus.Selector.cycleFound);
        debugPrintfln("%d ctx return cycle %s", n, foundCycle);
        return foundCycle;
    }
}

unittest
{
    auto fvisit(in CellIndex c)
    {
        if (c & 1)
            return SortContext.VisitStatus();
        return SortContext.VisitStatus(c);
    }

    auto isCycle(in SortContext.VisitStatus s)
    {
        return s.selector is SortContext.VisitStatus.Selector.cycleFound;
    }

    auto mapped = map!fvisit([2]);
    auto found = find!isCycle(mapped);
    assert(!found.empty());
    assert(found.front.selector is SortContext.VisitStatus.Selector.cycleFound);
}

unittest
{
    immutable edges = [Edge(0, 1), Edge(2, 1), Edge(1, 3), Edge(3, 2)];
    auto graph = Graph.makeFromEdges(edges);
    graph.dump();
    auto gv = graph.generateDotText("mygr");
    toFile(gv, "temp.gv");
    auto sorted = graph.tsort();
    writefln("sorted: %s", sorted.result);
}
