
private extern(C) void myhello(const char *msg);

public void printmessage(string msg) {
  import std.string;
  myhello(msg.toStringz());
}
