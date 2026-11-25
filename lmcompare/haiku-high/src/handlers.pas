unit handlers;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fphttpserver;

function HtmlEscape(const S: string): string;

type
  THandlers = class
  public
    procedure HandleHello(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  end;

implementation

function HtmlEscape(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

procedure THandlers.HandleHello(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  Name: string;
begin
  Name := Trim(ARequest.QueryFields.Values['name']);
  if Name = '' then
    Name := Trim(ARequest.ContentFields.Values['name']);
  if Name = '' then
    Name := 'stranger';

  AResponse.Code := 200;
  AResponse.CodeText := 'OK';
  AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content :=
    '<!DOCTYPE html>' + LineEnding +
    '<html><head><meta charset="utf-8"><title>Hello</title>' + LineEnding +
    '<link rel="stylesheet" href="/style.css"></head>' + LineEnding +
    '<body><h1>hello, ' + HtmlEscape(Name) + '!</h1>' +
    '<p><a href="/">Back</a></p></body></html>';
end;

end.
