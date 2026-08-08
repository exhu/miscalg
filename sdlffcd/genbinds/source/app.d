import std.stdio;
import std.process : environment, execute;
import std.array : replace;
import std.algorithm : map;
import std.array : array;
import std.format : format;
import std.path : baseName;
import std.string : replace;

enum string sdlIncludePath = "$HOME/.local/include";
enum string[] sdlHeaders = [
  "SDL3/SDL_stdinc.h",
  "SDL3/SDL_atomic.h",
  "SDL3/SDL_audio.h",
  "SDL3/SDL_events.h",
  "SDL3/SDL_init.h",
  "SDL3/SDL_iostream.h",
  "SDL3/SDL_keyboard.h",
  "SDL3/SDL_keycode.h",
  "SDL3/SDL_log.h",
  "SDL3/SDL_mutex.h",
  "SDL3/SDL_pixels.h",
  "SDL3/SDL_properties.h",
  "SDL3/SDL_render.h",
  "SDL3/SDL_surface.h",
  "SDL3/SDL_thread.h",
  "SDL3/SDL_timer.h",
  "SDL3/SDL_video.h",
];
enum string dstepBinary = "$HOME/agy-projects/dstep/bin/dstep";

/// Expands environment variables (such as $HOME) in a given string.
string expandEnv(string str)
{
  return str.replace("$HOME", environment.get("HOME", ""));
}

version (none)
{
  /// Expands environment variables (such as $HOME) in an array of strings.
  string[] expandEnv(const string[] strs)
  {
    return strs.map!(s => expandEnv(s)).array;
  }
}

string buildDmoduleName(string header)
{
  return baseName(header).replace(".", "_") ~ ".d";
}

string[] buildDstepCommand(string header)
{
  string outFileName = "./" ~ buildDmoduleName(header);
  return [
    expandEnv(dstepBinary), format("-I%s", expandEnv(sdlIncludePath)), "-o",
    outFileName, header
  ];
}

void main()
{
  string includePath = expandEnv(sdlIncludePath);
  writeln("SDL Include Path: ", includePath);
  writeln("Dstep Binary: ", expandEnv(dstepBinary));
  foreach (header; sdlHeaders)
  {
    string[] command = buildDstepCommand(includePath ~ "/" ~ header);
    writeln("command: ", command);
    execute(command);
  }
}
