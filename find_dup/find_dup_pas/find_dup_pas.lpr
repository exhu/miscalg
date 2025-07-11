{$mode objfpc}
program find_dup_pas;

uses
  fgl,
  Classes;

type
  TPaths = TStringList;
  TPathsMap = specialize TFPGMapObject<string, TPaths>;

  procedure usage();
  begin
    writeln('Usage: find_dup <path a> [path b]');
  end;

begin
  if (ParamCount < 1) or (ParamCount > 2) then
  begin
    usage();
    halt(1);
  end;

end.
