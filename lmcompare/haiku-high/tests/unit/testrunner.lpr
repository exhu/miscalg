program testrunner;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}cthreads,{$endif}
  Classes, SysUtils, fpcunit, testregistry, consoletestrunner,
  test_handlers, test_router, test_staticfiles;

type
  TUnitTestRunner = class(TTestRunner)
  end;

var
  App: TUnitTestRunner;
begin
  App := TUnitTestRunner.Create(nil);
  try
    App.Initialize;
    App.Title := 'httpsrv unit tests';
    App.Run;
  finally
    App.Free;
  end;
end.
