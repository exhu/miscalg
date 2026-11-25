program httpsrv;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}cthreads,{$endif} SysUtils, Classes, {$ifdef unix}BaseUnix,{$endif}
  fphttpserver, router, staticfiles, handlers;

type
  TShutdown = class
    Server: TFPHttpServer;
    procedure CheckStop(Sender: TObject);
  end;

var
  StopRequested: Boolean = False;

{$ifdef unix}
procedure HandleUnixSignal(ASig: cint); cdecl;
begin
  StopRequested := True;
end;
{$endif}

procedure TShutdown.CheckStop(Sender: TObject);
begin
  if StopRequested then
    Server.Active := False;
end;

var
  Server: TFPHttpServer;
  Static: TStaticFiles;
  AppHandlers: THandlers;
  AppRouter: TRouter;
  Port: Integer;
  AssetsDir: string;
  Shutdown: TShutdown;
begin
  {$ifdef unix}
  FpSignal(SIGINT, SignalHandler(@HandleUnixSignal));
  FpSignal(SIGTERM, SignalHandler(@HandleUnixSignal));
  {$endif}
  Shutdown := nil;
  if ParamCount >= 1 then
    Port := StrToIntDef(ParamStr(1), 8080)
  else
    Port := 8080;
  if ParamCount >= 2 then
    AssetsDir := ParamStr(2)
  else
    AssetsDir := ExtractFilePath(ParamStr(0)) + '../assets';
  Static := TStaticFiles.Create(AssetsDir);
  AppHandlers := THandlers.Create;
  AppRouter := TRouter.Create;
  Shutdown := TShutdown.Create;
  try
    AppRouter.AddRoute('/', @Static.HandleIndex);
    AppRouter.AddRoute('/hello', @AppHandlers.HandleHello);
    AppRouter.SetFallback(@Static.HandleStatic);
    Server := TFPHttpServer.Create(nil);
    try
      Server.Port := Port;
      Server.OnRequest := @AppRouter.Dispatch;
      Server.Threaded := False;
      Server.AcceptIdleTimeout := 200;
      Shutdown.Server := Server;
      Server.OnAcceptIdle := @Shutdown.CheckStop;
      WriteLn('Assets: ', ExpandFileName(AssetsDir));
      WriteLn('Listening on http://localhost:', Port);
      Flush(Output);
      Server.Active := True;
      WriteLn('Shutting down');
    finally
      Server.Free;
    end;
  finally
    Shutdown.Free;
    AppRouter.Free;
    AppHandlers.Free;
    Static.Free;
  end;
end.
