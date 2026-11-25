unit staticfiles;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fphttpserver, fpmimetypes, router;

type
  TStaticFiles = class
  private
    FRoot: string;
    function DecodePath(const APath: string): string;
  public
    constructor Create(const ARoot: string);
    function MimeTypeFor(const AFileName: string): string;
    function Serve(const ARelPath: string;
      var AResponse: TFPHTTPConnectionResponse): Boolean;
    procedure HandleIndex(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
    procedure HandleStatic(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  end;

implementation

constructor TStaticFiles.Create(const ARoot: string);
begin
  inherited Create;
  FRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot));
  if FileExists('/etc/mime.types') then
    MimeTypes.LoadFromFile('/etc/mime.types');
end;

function TStaticFiles.DecodePath(const APath: string): string;
var
  I, Value: Integer;
  Hex: string;
begin
  Result := '';
  I := 1;
  while I <= Length(APath) do
  begin
    if (APath[I] = '%') and (I + 2 <= Length(APath)) then
    begin
      Hex := Copy(APath, I + 1, 2);
      if TryStrToInt('$' + Hex, Value) then
        Result := Result + Chr(Value)
      else
        Result := Result + '%' + Hex;
      Inc(I, 3);
    end
    else
    begin
      Result := Result + APath[I];
      Inc(I);
    end;
  end;
end;

function TStaticFiles.MimeTypeFor(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if (Ext = '.html') or (Ext = '.htm') then
    Result := 'text/html; charset=utf-8'
  else if Ext = '.css' then
    Result := 'text/css'
  else if Ext = '.js' then
    Result := 'application/javascript'
  else if Ext = '.png' then
    Result := 'image/png'
  else if (Ext = '.jpg') or (Ext = '.jpeg') then
    Result := 'image/jpeg'
  else if Ext = '.svg' then
    Result := 'image/svg+xml'
  else if Ext = '.txt' then
    Result := 'text/plain; charset=utf-8'
  else if Ext = '.ico' then
    Result := 'image/x-icon'
  else
    Result := MimeTypes.GetMimeType(Copy(Ext, 2, MaxInt));
  if Result = '' then
    Result := 'application/octet-stream';
end;

function TStaticFiles.Serve(const ARelPath: string;
  var AResponse: TFPHTTPConnectionResponse): Boolean;
var
  Rel, Full: string;
  Stream: TFileStream;
begin
  Result := False;
  Rel := DecodePath(ARelPath);
  if (Rel = '') or (Pos('..', Rel) > 0) or (Pos(#0, Rel) > 0) or
     (Pos('\', Rel) > 0) then
    Exit;
  while (Rel <> '') and (Rel[1] = '/') do
    Delete(Rel, 1, 1);
  if Rel = '' then
    Exit;

  Full := ExpandFileName(FRoot + Rel);
  if (Pos(FRoot, Full) <> 1) or not FileExists(Full) or DirectoryExists(Full) then
    Exit;

  Stream := TFileStream.Create(Full, fmOpenRead or fmShareDenyWrite);
  AResponse.ContentStream := Stream;
  AResponse.FreeContentStream := True;
  AResponse.Code := 200;
  AResponse.ContentType := MimeTypeFor(Full);
  AResponse.ContentLength := Stream.Size;
  Result := True;
end;

procedure TStaticFiles.HandleIndex(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  if not Serve('/index.html', AResponse) then
    TRouter.SendNotFound(AResponse);
end;

procedure TStaticFiles.HandleStatic(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  if not Serve(TRouter.RequestPath(ARequest), AResponse) then
    TRouter.SendNotFound(AResponse);
end;

end.
