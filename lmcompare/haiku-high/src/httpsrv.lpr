program httpsrv;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}cthreads,{$endif}
  SysUtils, Classes, fphttpserver, router, staticfiles, handlers;

var
  Server: TFPHttpServer;
  AppRouter: TRouter;
  Static: TStaticFiles;
  AppHandlers: THandlers;
  Port: Integer;
  AssetsDir: string;
begin
  if ParamCount >= 1 then
    Port := StrToIntDef(ParamStr(1), 8080)
  else
    Port := 8080;

  if ParamCount >= 2 then
    AssetsDir := ParamStr(2)
  else
    AssetsDir := ExtractFilePath(ParamStr(0)) + '../assets';

  Static := TStaticFiles.Create(AssetsDir);
  AppRouter := TRouter.Create;
  AppHandlers := THandlers.Create;
  Server := TFPHttpServer.Create(nil);
  try
    AppRouter.AddRoute('/', @Static.HandleIndex);
    AppRouter.AddRoute('/hello', @AppHandlers.HandleHello);
    AppRouter.SetFallback(@Static.HandleStatic);
    Server.Port := Port;
    Server.OnRequest := @AppRouter.Dispatch;
    Server.Threaded := False;
    WriteLn('Assets: ', ExpandFileName(AssetsDir));
    WriteLn('Listening on http://localhost:', Port);
    Server.Active := True;
  finally
    Server.Free;
    AppHandlers.Free;
    AppRouter.Free;
    Static.Free;
  end;
end.
