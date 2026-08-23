program pdiskpofftui;

{$mode objfpc}{$H+}

uses
  SysUtils, uterminal, uui;

var
  App: TTuiApp;
begin
  if not IsTerminal then
  begin
    WriteLn(StdErr, 'diskpoff-tui must be run from an interactive terminal.');
    Halt(1);
  end;

  InitTerminal;
  try
    try
      App := TTuiApp.Create;
      try
        App.Run;
      finally
        App.Free;
      end;
    except
      on E: Exception do
      begin
        RestoreTerminal;
        WriteLn(StdErr, 'Fatal error: ', E.Message);
        Halt(1);
      end;
    end;
  finally
    RestoreTerminal;
  end;
end.
