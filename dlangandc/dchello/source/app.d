import std.stdio;

extern(C) void myhello(const char *msg);
void main()
{
	writeln("Edit source/app.d to start your project.");
	myhello("hello from D!");
}
