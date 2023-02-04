import std.file : exists, isDir, isFile, dirEntries, SpanMode;
import std.path : baseName;
import std.stdio : writeln, stderr;
import std.sumtype;

alias PathsMap = string[][string];

PathsMap gatherFiles(string root)
{
    PathsMap result;
    foreach (string name; dirEntries(root, SpanMode.depth))
    {
        if (name.isFile)
        {
            result[name.baseName] ~= name;
        }
    }
    return result;
}

void printPaths(in string[] files)
{
    foreach (f; files)
        writeln(f);
}

PathsMap collectSameNames(in PathsMap listA, in PathsMap listB)
{
    PathsMap result;
    foreach (k, v; listA)
    {
        result[k] = v.dup;
        if (k in listB)
        {
            result[k] ~= listB[k];
        }
    }

    return result;
}

string[] findSameFiles(in string[] files)
{
    string[] result;
    string[] next;
    foreach(i, a; files)
    {
        bool foundCopy = false;
        foreach(b; files[i+1..$])
        {
            if (areSameFiles(a, b))
            {
                result ~= b;
                foundCopy = true;
            }
        }
        if (foundCopy)
        {
            result ~= a;
        }
    }
    return result;
}

PathsMap processDups(in PathsMap listA, in PathsMap listB)
{
    PathsMap sameNames = collectSameNames(listA, listB);
    PathsMap result;
    foreach(k,v; sameNames)
    {
        auto matched = findSameFiles(v);
        if (matched.length > 0)
        {
            result[k] = matched;
        }
    }
    return result;
}

bool areSameFiles(in string fileA, in string fileB)
{
    import std.process : execute;

    // Exit status is 0 if inputs are the same, 1 if different, 2 if trouble.
    return execute(["cmp", fileA, fileB]).status == 0;
}

void usage()
{
    writeln("Usage: find_dup <path a> [path b]");
}

void printDups(in PathsMap dups)
{
    foreach (k, v; dups)
    {
        writeln(k, ":");
        printPaths(v);
    }
}

int main(string[] args)
{
    if (args.length < 2 || args.length > 3)
    {
        usage();
        return 1;
    }

    const pathA = args[1];
    const pathB = args.length == 3 ? args[2] : null;

    const pathBok = !pathB || (pathB.exists() && pathB.isDir());

    if (pathA.exists() && pathA.isDir() && pathBok)
    {
        const listA = gatherFiles(pathA);
        const listB = pathB ? gatherFiles(pathB) : new PathsMap;
        const dups = processDups(listA, listB);
        printDups(dups);
        return 0;
    }

    writeln(stderr, "Must be existing directories.");

    return 1;
}
