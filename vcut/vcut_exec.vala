// execute process

class VcutExec {
    public signal void on_finished(int ret_val);
    public signal void on_new_line(string line);

    /// arguments like {"ls", "-l", "-h"}
    public void run(string[] spawn_args) {
        try {
            //string[] spawn_args = {"ls", "-l", "-h"};
            string[] spawn_env = Environ.get ();
            Pid child_pid;

            int standard_input;
            int standard_output;
            int standard_error;

            Process.spawn_async_with_pipes (null,
                spawn_args,
                spawn_env,
                SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                null,
                out child_pid,
                out standard_input,
                out standard_output,
                out standard_error);

            // stdout:
            IOChannel output = new IOChannel.unix_new (standard_output);
            output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                return process_line (channel, condition, "stdout");
            });

            // stderr:
            IOChannel error = new IOChannel.unix_new (standard_error);
            error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                return process_line (channel, condition, "stderr");
            });

            ChildWatch.add (child_pid, (pid, status) => {
                // Triggered when the child indicated by child_pid exits
                Process.close_pid (pid);
                on_finished(status);
            });
        } catch (SpawnError e) {
            stdout.printf ("Error: %s\n", e.message);
        }
    }

    private bool process_line (IOChannel channel, IOCondition condition, string stream_name) {
        if (condition == IOCondition.HUP) {
            stdout.printf ("%s: The fd has been closed.\n", stream_name);
            return false;
        }

        try {
            string line;
            channel.read_line (out line, null, null);
            stdout.printf ("%s: %s", stream_name, line);
            on_new_line(line);
        } catch (IOChannelError e) {
            stdout.printf ("%s: IOChannelError: %s\n", stream_name, e.message);
            return false;
        } catch (ConvertError e) {
            stdout.printf ("%s: ConvertError: %s\n", stream_name, e.message);
            return false;
        }

        return true;
    }
}