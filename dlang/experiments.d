
// metaprogramming experiments
version (none)
{
    private string generateMembers(E, Types...)()
    {
        string members;
        assert(Types.length >= 1);
        static foreach (i, t; Types)
        {
            members ~= "private " ~ t.stringof ~ " " ~ __traits(identifier, EnumMembers!E[i]) ~ ";";
        }
        return members;
    }

    private string generateAccessors(E, Types...)()
    {
        string members;
        assert(Types.length >= 1);
        foreach (i, t; Types)
        {
            auto eId = __traits(identifier, EnumMembers!E[i]);
            auto eName = __traits(identifier, E);
            auto funcName = "get_" ~ eId;
            members ~= t.stringof ~ " " ~ funcName ~ "(){" ~ "assert(selector == "
                ~ eName ~ "." ~ eId ~ ", \"" ~ funcName ~ "\");" ~ "return " ~ eId ~ ";}";
        }
        return members;
    }

    template adtUnion(E, Types...) if (EnumMembers!E.length == Types.length)
    {
        enum string adtUnion = "private " ~ E.stringof ~ " selector; union{" ~ generateMembers!(E,
                    Types)() ~ "}" ~ E.stringof ~ " getTag() { return selector; }" ~ generateAccessors!(E,
                    Types)();
    }

    template adtMembers(E, Types...) if (EnumMembers!E.length == Types.length)
    {
        enum string adtMembers = E.stringof ~ " selector; " ~ generateMembers!(E, Types)();
    }

    struct TestAdt
    {
        enum Selector
        {
            first,
            second,
            empty,
            fourth,
            fifth,
        }

        struct First
        {
            int a = 1;
        }

        struct Second
        {
            int b = 2;
        }

        struct Empty
        {
        }

        struct Fourth
        {
            string s = "fourth";
        }

        mixin(adtUnion!(Selector, First, Second, Empty, Fourth, Empty));
        //mixin(adtMembers!(Selector, First, Second, Empty, Fourth, Empty));
    }

    unittest
    {
        import std.conv;

        //writefln("%s", to!string(typeof(l)));
        auto g = Graph.make_from_edges([Edge(0, 1), Edge(1, 2), Edge(3, 4)]);
        assert(g.nodesCount == 5);

        TestAdt a, b;
        assert(a.selector == TestAdt.Selector.first);
        b = a;
        assert(a.first.a == 1);
        a.fourth.s = "hh test";
        writefln("first = %d, second = %d, third = %s", a.first.a, a.second.b, a.fourth.s);
        string members = generateMembers!(TestAdt.Selector, TestAdt.First, TestAdt.Second);
        writefln("%s", members);
        a.getTag();
        a.get_first();
        a.get_second();
    }

} // version
