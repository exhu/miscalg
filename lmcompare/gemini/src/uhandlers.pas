unit uhandlers;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, httpdefs, uhttpfiles;

type
  { Application HTTP route handlers. }
  TAppHandlers = class(TObject)
  private
    FAssetsDir: string;
  public
    constructor Create(const AAssetsDir: string);
    procedure HandleIndex(ARequest: TRequest; AResponse: TResponse);
    procedure HandleHello(ARequest: TRequest; AResponse: TResponse);
    procedure HandleStaticFallback(ARequest: TRequest; AResponse: TResponse);
  end;

implementation

constructor TAppHandlers.Create(const AAssetsDir: string);
begin
  inherited Create;
  FAssetsDir := AAssetsDir;
end;

procedure TAppHandlers.HandleIndex(ARequest: TRequest; AResponse: TResponse);
begin
  if not ServeStaticFile(FAssetsDir, '/index.html', AResponse) then
    SendErrorResponse(AResponse, 404, '404 index.html not found');
end;

procedure TAppHandlers.HandleHello(ARequest: TRequest; AResponse: TResponse);
var
  RawName: string;
  SafeName: string;
  Html: string;
begin
  RawName := Trim(ARequest.ContentFields.Values['name']);
  if RawName = '' then
    RawName := Trim(ARequest.QueryFields.Values['name']);
  if RawName = '' then
    RawName := 'World';

  SafeName := EscapeHtml(RawName);
  Html :=
    '<!DOCTYPE html>' + LineEnding +
    '<html lang="en">' + LineEnding +
    '<head>' + LineEnding +
    '  <meta charset="utf-8">' + LineEnding +
    '  <meta name="viewport" content="width=device-width, initial-scale=1">' + LineEnding +
    '  <title>Hello, ' + SafeName + '!</title>' + LineEnding +
    '  <link rel="stylesheet" href="/style.css">' + LineEnding +
    '</head>' + LineEnding +
    '<body>' + LineEnding +
    '  <main class="container">' + LineEnding +
    '    <h1>hello, ' + SafeName + '!</h1>' + LineEnding +
    '    <p><a href="/">Back</a></p>' + LineEnding +
    '  </main>' + LineEnding +
    '</body>' + LineEnding +
    '</html>' + LineEnding;

  SendHtmlResponse(AResponse, 200, Html);
end;

procedure TAppHandlers.HandleStaticFallback(ARequest: TRequest; AResponse: TResponse);
var
  HttpMethod: string;
begin
  HttpMethod := UpperCase(Trim(ARequest.Method));
  if (HttpMethod <> 'GET') and (HttpMethod <> 'HEAD') then
  begin
    SendErrorResponse(AResponse, 405, '405 Method Not Allowed');
    Exit;
  end;

  if not ServeStaticFile(FAssetsDir, ARequest.PathInfo, AResponse) then
    SendErrorResponse(AResponse, 404, '404 Not Found');
end;

end.
