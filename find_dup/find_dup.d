import std.file : exists, isDir, isFile, dirEntries, SpanMode, isSymlink;
import std.path : baseName;
import std.stdio : writeln, stderr;

alias PathsMap = string[][string];

PathsMap gatherFiles(string root)
{
    PathsMap result;
    foreach (string name; dirEntries(root, SpanMode.depth))
    {
        if (!name.isSymlink && name.isFile)
        {
            result[name.baseName] ~= name;
        }
    }
    return result;
}

void printPaths(in string[] files)
{
    import std.algorithm.sorting;
    auto sorted = sort(files.dup);
    foreach (f; sorted)
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

// TODO fix, must return groups of equal files, but now it returns files which
// have a match, i.e.
// given files with same names [a,b,c,d] where files [a,b] are dups,
// and files [c,d] are dups, but a and b have different contents than
// c and d, the result will contain all!
string[] findSameFiles(in string[] files)
{
    bool[string] result;
    foreach(i, a; files)
    {
        foreach(b; files[(i+1)..$])
        {
            if (areSameFiles(a, b))
            {
                result[a] = true;
                result[b] = true;
            }
        }
    }
    return result.keys;
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
    import std.algorithm.sorting;
    auto sortedKeys = sort(dups.keys);
    foreach (k; sortedKeys)
    {
        writeln(k, ":");
        printPaths(dups[k]);
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
