unit handlers;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fphttpserver;

type
  THandlers = class
  public
    procedure HandleHello(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  end;

function HtmlEscape(const S: string): string;

implementation

function HtmlEscape(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
      '''': Result := Result + '&#39;';
    else
      Result := Result + S[I];
    end;
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
  AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content :=
    '<!DOCTYPE html>' + LineEnding +
    '<html><head><meta charset="utf-8"><title>Hello</title>' + LineEnding +
    '<link rel="stylesheet" href="/style.css"></head>' + LineEnding +
    '<body><h1>hello, ' + HtmlEscape(Name) + '!</h1>' +
    '<p><a href="/">Back</a></p></body></html>' + LineEnding;
end;

end.
