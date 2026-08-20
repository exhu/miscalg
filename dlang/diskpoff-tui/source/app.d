import std.stdio : stderr, writeln;
import arsd.terminal;
import ui;

int main(string[] args) {
    if (!Terminal.stdoutIsTerminal() || !Terminal.stdinIsTerminal()) {
        stderr.writeln("diskpoff-tui must be run from an interactive terminal.");
        return 1;
    }

    try {
        auto terminal = Terminal(ConsoleOutputType.cellular);
        terminal.hideCursor();

        scope(exit) {
            terminal.showCursor();
            terminal.color(Color.DEFAULT, Color.DEFAULT);
            terminal.clear();
            terminal.flush();
        }

        auto input = RealTimeConsoleInput(&terminal, ConsoleInputFlags.raw | ConsoleInputFlags.size);

        auto app = TuiApp(&terminal, &input);
        app.run();

    } catch (Exception e) {
        stderr.writeln("Fatal error: ", e.msg);
        return 1;
    }

    return 0;
}
