{$mode objfpc}
program find_dup_pas;

uses
  fgl,
  Classes,
  SysUtils;

type
  TPaths = TStringList;
  TPathsMap = specialize TFPGMapObject<utf8string, TPaths>;

  procedure usage();
  begin
    writeln('Usage: find_dup <path a> [path b]');
  end;

  function gatherFiles(root: utf8string): TPathsMap;
  var
    map: TPathsMap;
  begin
    map := TPathsMap.Create(True);

    result := map;
  end;

var
  pathA, pathB: utf8string;
  pathsMap: TPathsMap;
begin
  if (ParamCount < 1) or (ParamCount > 2) then
  begin
    usage();
    halt(1);
  end;

  pathA := ParamStr(1);
  if ParamCount = 2 then pathB := ParamStr(2);

  writeln(pathA);
  pathsMap := gatherFiles(pathA);
  writeln('pathsMap len =', pathsMap.Count);
end.
