// TODO clean up code
// TODO try to use functional style -- non-member or static functions instead of methods
// if only one field is used to simplify unit tests
// TODO add impl using SumType

import std.algorithm.iteration;
import std.algorithm.comparison;
import std.algorithm.searching;
import std.stdio;
import std.string;

alias CellIndex = size_t;

struct Edge
{
    CellIndex fromCell, toCell;
}

alias Edges = Edge[];

struct Graph
{
    immutable Edges edges;
    immutable size_t nodesCount;

    static Graph makeFromEdges(immutable Edges edges)
    {
        immutable maxNode = fold!((a, c) => max(a, max(c.fromCell, c.toCell)))(edges, 0L);
        return Graph(edges, maxNode + 1);
    }

    void dump()
    {
        printEdges(edges);
    }

    auto allDestFrom(CellIndex n)
    {
        auto f = (const Edge e) => e.fromCell == n;
        auto m = (const Edge e) => e.toCell;
        return filter!(f)(edges).map!m();
    }

    string generateDotText(string name)
    {
        string buf;
        buf ~= format("digraph \"%s\" {\n", name);
        auto e = (const Edge e) => buf ~= format("%d -> %d\n", e.fromCell, e.toCell);
        each!e(edges);
        buf ~= "}";
        return buf;
    }

    SortResult tsort()
    {
        auto ctx = SortContext(this);
        for (auto i = 0; i < nodesCount; ++i)
        {
            writefln("top iter %d", i);
            const foundCycle = visit(ctx, i);

            if (foundCycle.selector is SortContext.VisitStatus.Selector.cycleFound)
            {
                writeln("cycle!");
                return SortResult.makeCycle(foundCycle.cycle);
            }
        }
        writeln("sorted!");
        return SortResult.makeSorted(ctx.sorted);
    }
}

void printEdges(const Edges edges)
{
    auto f = (const Edge n) => writefln("edge %d -> %d", n.fromCell, n.toCell);
    each!(f)(edges);
}

struct SortResult
{
    enum Selector
    {
        sorted,
        cycle,
    }

    Selector result;
    union
    {
        CellIndex[] sorted;
        CellIndex cycle;
    }

    this(CellIndex cycle)
    {
        result = Selector.cycle;
        this.cycle = cycle;
    }

    this(CellIndex[] sorted)
    {
        this.sorted = sorted;
        result = Selector.sorted;
    }

    static SortResult makeCycle(CellIndex c)
    {
        return SortResult(c);
    }

    static SortResult makeSorted(CellIndex[] s)
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
        VisitStatus visit(CellIndex n)
        {
            writefln("%d visit", n);
            if (find(permMarked, n).empty == false)
            {
                writeln("already perm");
                return VisitStatus();
            }
            else if (find(tempMarked, n).empty == false)
            {
                writefln("%d early cycle", n);
                return VisitStatus(n);
            }
            markTemp(n);
            auto fvisit(CellIndex c)
            {
                writefln("%d ctx fvisit %d", n, c);
                auto r = visit(c);
                writefln("%d ctx fvisit result %s", n, r);
                return r;
            }

            auto is_cycle(in VisitStatus s)
            {
                auto r = (s.selector is VisitStatus.Selector.cycleFound);
                writefln("%d is_cycle %s", n, r);
                return r;
            }

            auto nodesOfN = graph.allDestFrom(n);
            writefln("%d nodesOfN = %s", n, nodesOfN);

            auto mapped = map!fvisit(nodesOfN);
            writefln("%d mapped", n);
            // here there's probably compiler bug, since it fails
            auto foundRange = find!is_cycle(mapped);
            //writefln("range: %s", foundRange);
            markPerm(n);
            addToSorted(n);
            if (foundRange.empty)
            {
                writefln("%d ctx continue", n);
                return VisitStatus(VisitStatus.Selector.continueVisiting);
            }
            auto foundCycle = foundRange.front;
            // compiler bug if find over map range is used
            assert(foundCycle.selector is VisitStatus.Selector.cycleFound);
            writefln("%d ctx return cycle %s", n, foundCycle);
            return foundCycle;
        }
    }
}

SortContext.VisitStatus visit(SortContext ctx, CellIndex n)
{
    writefln("%d visit", n);
    if (find(ctx.permMarked, n).empty == false)
    {
        writeln("already perm");
        return SortContext.VisitStatus();
    }
    else if (find(ctx.tempMarked, n).empty == false)
    {
        writefln("%d early cycle", n);
        return SortContext.VisitStatus(n);
    }
    ctx.markTemp(n);
    auto nodesOfN = ctx.graph.allDestFrom(n);
    writefln("%d nodesOfN = %s", n, nodesOfN);

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
        writefln("%d ctx continue", n);
        return SortContext.VisitStatus();
    }
    assert(foundCycle.selector is SortContext.VisitStatus.Selector.cycleFound);
    writefln("%d ctx return cycle %s", n, foundCycle);
    return foundCycle;
}

unittest
{
    auto fvisit(CellIndex c)
    {
        if (c & 1)
            return SortContext.VisitStatus();
        return SortContext.VisitStatus(c);
    }

    auto isCycle(SortContext.VisitStatus s)
    {
        return s.selector is SortContext.VisitStatus.Selector.cycleFound;
    }

    auto mapped = map!fvisit([2]);
    auto found = find!isCycle(mapped);
    assert(!found.empty);
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
