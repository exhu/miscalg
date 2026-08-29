import std.stdio;

extern (C) const(char)* clib_get_version();

void main() {
    writeln("AVUtil version: ", clib_get_version());
}
