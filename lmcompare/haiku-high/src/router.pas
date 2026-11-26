unit router;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fphttpserver;

type
  TRouteHandler = procedure(var ARequest: TFPHTTPConnectionRequest;
    var AResponse: TFPHTTPConnectionResponse) of object;

  TRoute = record
    Path: string;
    Handler: TRouteHandler;
  end;

  TRouter = class
  private
    FRoutes: array of TRoute;
    FFallback: TRouteHandler;
  protected
    { Virtual so that tests can capture or silence the log output. }
    procedure LogRequest(const AMethod, AUri: string; ACode: Integer); virtual;
    procedure LogError(const AUri, AMessage: string); virtual;
  public
    procedure AddRoute(const APath: string; AHandler: TRouteHandler);
    procedure SetFallback(AHandler: TRouteHandler);
    procedure Dispatch(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse); reintroduce;
    class function RequestPath(ARequest: TFPHTTPConnectionRequest): string;
    class procedure SendNotFound(var AResponse: TFPHTTPConnectionResponse);
  end;

implementation

procedure TRouter.AddRoute(const APath: string; AHandler: TRouteHandler);
var
  N: Integer;
begin
  N := Length(FRoutes);
  SetLength(FRoutes, N + 1);
  FRoutes[N].Path := APath;
  FRoutes[N].Handler := AHandler;
end;

procedure TRouter.SetFallback(AHandler: TRouteHandler);
begin
  FFallback := AHandler;
end;

class function TRouter.RequestPath(ARequest: TFPHTTPConnectionRequest): string;
var
  P: Integer;
begin
  Result := ARequest.URI;
  P := Pos('?', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
  if Result = '' then
    Result := '/';
end;

class procedure TRouter.SendNotFound(var AResponse: TFPHTTPConnectionResponse);
begin
  AResponse.Code := 404;
  AResponse.CodeText := 'Not Found';
  AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content := '<h1>404 Not Found</h1>';
end;

procedure TRouter.LogRequest(const AMethod, AUri: string; ACode: Integer);
begin
  WriteLn(AMethod, ' ', AUri, ' -> ', ACode);
  Flush(Output);
end;

procedure TRouter.LogError(const AUri, AMessage: string);
begin
  WriteLn(ErrOutput, 'Handler error for ', AUri, ': ', AMessage);
end;

procedure TRouter.Dispatch(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  Path: string;
  I: Integer;
  Matched: Boolean;
begin
  Path := RequestPath(ARequest);
  Matched := False;
  try
    for I := 0 to High(FRoutes) do
      if FRoutes[I].Path = Path then
      begin
        Matched := True;
        FRoutes[I].Handler(ARequest, AResponse);
        Break;
      end;

    if not Matched then
    begin
      if Assigned(FFallback) then
        FFallback(ARequest, AResponse)
      else
        SendNotFound(AResponse);
    end;
  except
    on E: Exception do
    begin
      LogError(ARequest.URI, E.Message);
      AResponse.Code := 500;
      AResponse.CodeText := 'Internal Server Error';
      AResponse.ContentType := 'text/plain; charset=utf-8';
      AResponse.Content := 'Internal Server Error';
    end;
  end;
  LogRequest(ARequest.Method, ARequest.URI, AResponse.Code);
end;

end.
