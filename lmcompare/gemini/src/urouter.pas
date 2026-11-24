unit urouter;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, httpdefs, uhttpfiles;

type
  TRouteHandler = procedure(ARequest: TRequest; AResponse: TResponse) of object;

  TRouteEntry = record
    Method: string;
    Path: string;
    Handler: TRouteHandler;
  end;

  { Simple method-and-path HTTP router with fallback and 405/404 handling. }
  THttpRouter = class(TObject)
  private
    FRoutes: array of TRouteEntry;
    FFallbackHandler: TRouteHandler;
  public
    class function NormalizePath(const APath: string): string;
    procedure AddRoute(const AMethod, APath: string; AHandler: TRouteHandler);
    procedure SetFallbackHandler(AHandler: TRouteHandler);
    procedure Dispatch(ARequest: TRequest; AResponse: TResponse); reintroduce;
  end;

implementation

class function THttpRouter.NormalizePath(const APath: string): string;
begin
  Result := Trim(APath);
  // TFPHttpServer leaves PathInfo empty for root '/' requests.
  if Result = '' then
    Exit('/');

  if Result[1] <> '/' then
    Result := '/' + Result;

  while (Length(Result) > 1) and (Result[Length(Result)] = '/') do
    SetLength(Result, Length(Result) - 1);
end;

procedure THttpRouter.AddRoute(const AMethod, APath: string; AHandler: TRouteHandler);
var
  Idx: Integer;
begin
  Idx := Length(FRoutes);
  SetLength(FRoutes, Idx + 1);
  FRoutes[Idx].Method := UpperCase(Trim(AMethod));
  FRoutes[Idx].Path := NormalizePath(APath);
  FRoutes[Idx].Handler := AHandler;
end;

procedure THttpRouter.SetFallbackHandler(AHandler: TRouteHandler);
begin
  FFallbackHandler := AHandler;
end;

procedure THttpRouter.Dispatch(ARequest: TRequest; AResponse: TResponse);
var
  I: Integer;
  ReqPath: string;
  ReqMethod: string;
  PathMatched: Boolean;
begin
  ReqPath := NormalizePath(ARequest.PathInfo);
  ReqMethod := UpperCase(Trim(ARequest.Method));
  PathMatched := False;

  for I := 0 to High(FRoutes) do
  begin
    if FRoutes[I].Path = ReqPath then
    begin
      PathMatched := True;
      if (FRoutes[I].Method = '*') or (FRoutes[I].Method = ReqMethod) then
      begin
        if Assigned(FRoutes[I].Handler) then
          FRoutes[I].Handler(ARequest, AResponse);
        Exit;
      end;
    end;
  end;

  if PathMatched then
  begin
    SendErrorResponse(AResponse, 405, '405 Method Not Allowed');
    Exit;
  end;

  if Assigned(FFallbackHandler) then
    FFallbackHandler(ARequest, AResponse)
  else
    SendErrorResponse(AResponse, 404, '404 Not Found');
end;

end.
