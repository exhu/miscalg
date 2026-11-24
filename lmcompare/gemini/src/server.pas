program server;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, {$IFDEF UNIX}BaseUnix,{$ENDIF} fphttpserver, httpdefs,
  uhttpfiles, urouter, uhandlers;

var
  GStopRequested: Boolean = False;

{$IFDEF UNIX}
procedure HandleUnixSignal(ASig: cint); cdecl;
begin
  if (ASig = SIGINT) or (ASig = SIGTERM) then
    GStopRequested := True;
end;
{$ENDIF}

type
  { Minimal HTTP server application wiring router, handlers, and TFPHttpServer. }
  TMinimalHttpApp = class(TObject)
  private
    FServer: TFPHttpServer;
    FRouter: THttpRouter;
    FHandlers: TAppHandlers;
    FPort: Word;
    FAssetsDir: string;
    procedure HandleHttpRequest(Sender: TObject;
      var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
    procedure HandleAcceptIdle(Sender: TObject);
  public
    constructor Create(APort: Word; const AAssetsDir: string);
    destructor Destroy; override;
    procedure Run;
  end;

constructor TMinimalHttpApp.Create(APort: Word; const AAssetsDir: string);
begin
  inherited Create;
  FPort := APort;
  FAssetsDir := AAssetsDir;

  FHandlers := TAppHandlers.Create(FAssetsDir);
  FRouter := THttpRouter.Create;
  FRouter.AddRoute('GET', '/', @FHandlers.HandleIndex);
  FRouter.AddRoute('GET', '/hello', @FHandlers.HandleHello);
  FRouter.AddRoute('POST', '/hello', @FHandlers.HandleHello);
  FRouter.SetFallbackHandler(@FHandlers.HandleStaticFallback);

  FServer := TFPHttpServer.Create(nil);
  FServer.Port := FPort;
  FServer.Threaded := False;
  FServer.AcceptIdleTimeout := 250;
  FServer.OnRequest := @HandleHttpRequest;
  FServer.OnAcceptIdle := @HandleAcceptIdle;
end;

destructor TMinimalHttpApp.Destroy;
begin
  FServer.Free;
  FRouter.Free;
  FHandlers.Free;
  inherited Destroy;
end;

procedure TMinimalHttpApp.HandleHttpRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  try
    FRouter.Dispatch(ARequest, AResponse);
  except
    on E: Exception do
      SendErrorResponse(AResponse, 500, '500 Internal Server Error');
  end;
end;

procedure TMinimalHttpApp.HandleAcceptIdle(Sender: TObject);
begin
  if GStopRequested then
    FServer.Active := False;
end;

procedure TMinimalHttpApp.Run;
begin
  WriteLn('HTTP server listening on http://127.0.0.1:', FPort, ' (assets: ', FAssetsDir, ')');
  Flush(Output);
  FServer.Active := True;
end;

procedure PrintUsage;
begin
  WriteLn('Usage: httpserver [-p PORT | --port PORT] [-a DIR | --assets DIR] [-h | --help]');
end;

procedure ParseCommandLine(out APort: Word; out AAssetsDir: string);
var
  I: Integer;
  Arg: string;
  PortVal: Integer;
begin
  APort := 8080;
  AAssetsDir := 'assets';
  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if (Arg = '-h') or (Arg = '--help') then
    begin
      PrintUsage;
      Halt(0);
    end
    else if (Arg = '-p') or (Arg = '--port') then
    begin
      if I + 1 > ParamCount then
      begin
        WriteLn(StdErr, 'Missing value for ', Arg);
        PrintUsage;
        Halt(1);
      end;
      PortVal := StrToIntDef(ParamStr(I + 1), -1);
      if (PortVal < 1) or (PortVal > 65535) then
      begin
        WriteLn(StdErr, 'Invalid port: ', ParamStr(I + 1));
        Halt(1);
      end;
      APort := Word(PortVal);
      Inc(I);
    end
    else if (Arg = '-a') or (Arg = '--assets') then
    begin
      if I + 1 > ParamCount then
      begin
        WriteLn(StdErr, 'Missing value for ', Arg);
        PrintUsage;
        Halt(1);
      end;
      AAssetsDir := ParamStr(I + 1);
      Inc(I);
    end
    else
    begin
      WriteLn(StdErr, 'Unknown option: ', Arg);
      PrintUsage;
      Halt(1);
    end;
    Inc(I);
  end;
end;

var
  Port: Word;
  AssetsDir: string;
  App: TMinimalHttpApp;

begin
  ParseCommandLine(Port, AssetsDir);
  {$IFDEF UNIX}
  FpSignal(SIGINT, SignalHandler(@HandleUnixSignal));
  FpSignal(SIGTERM, SignalHandler(@HandleUnixSignal));
  {$ENDIF}
  App := TMinimalHttpApp.Create(Port, AssetsDir);
  try
    App.Run;
  finally
    App.Free;
  end;
end.
