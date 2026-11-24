unit uhttpfiles;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, httpdefs, fpmimetypes;

function EscapeHtml(const AText: string): string;
function GetMimeTypeForFile(const AFileName: string): string;
function IsPathTraversalAttempt(const AUrlPath: string): Boolean;
function ResolveSafeAssetPath(const AAssetsDir, AUrlPath: string; out AFullPath: string): Boolean;
procedure SendHtmlResponse(AResponse: TResponse; AStatusCode: Integer; const AHtml: string);
procedure SendErrorResponse(AResponse: TResponse; AStatusCode: Integer; const AMessage: string);
function ServeStaticFile(const AAssetsDir, AUrlPath: string; AResponse: TResponse): Boolean;

implementation

var
  GMimeTypesLoaded: Boolean = False;

procedure EnsureMimeTypesLoaded;
begin
  if GMimeTypesLoaded then
    Exit;
  GMimeTypesLoaded := True;
  if FileExists('/etc/mime.types') then
    MimeTypes.LoadKnownTypes;
end;

function EscapeHtml(const AText: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AText) do
  begin
    case AText[I] of
      '&': Result := Result + '&amp;';
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '"': Result := Result + '&quot;';
      '''': Result := Result + '&#39;';
    else
      Result := Result + AText[I];
    end;
  end;
end;

function GetMimeTypeForFile(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if (Ext = '.html') or (Ext = '.htm') then
    Exit('text/html; charset=utf-8');
  if Ext = '.css' then
    Exit('text/css; charset=utf-8');
  if Ext = '.js' then
    Exit('application/javascript; charset=utf-8');
  if Ext = '.txt' then
    Exit('text/plain; charset=utf-8');
  if Ext = '.json' then
    Exit('application/json; charset=utf-8');
  if Ext = '.svg' then
    Exit('image/svg+xml');
  if Ext = '.png' then
    Exit('image/png');
  if (Ext = '.jpg') or (Ext = '.jpeg') then
    Exit('image/jpeg');
  if Ext = '.gif' then
    Exit('image/gif');
  if Ext = '.ico' then
    Exit('image/x-icon');

  Result := '';
  if Ext <> '' then
  begin
    EnsureMimeTypesLoaded;
    Result := MimeTypes.GetMimeType(Ext);
  end;
  if Result = '' then
    Result := 'application/octet-stream';
end;

function IsPathTraversalAttempt(const AUrlPath: string): Boolean;
var
  I: Integer;
  Len: Integer;
  SegStart: Integer;
  Segment: string;
begin
  if (Pos(#0, AUrlPath) > 0) or (Pos('\', AUrlPath) > 0) then
    Exit(True);

  Len := Length(AUrlPath);
  SegStart := 1;
  for I := 1 to Len + 1 do
  begin
    if (I > Len) or (AUrlPath[I] = '/') then
    begin
      Segment := Copy(AUrlPath, SegStart, I - SegStart);
      if Segment = '..' then
        Exit(True);
      SegStart := I + 1;
    end;
  end;

  Result := False;
end;

function ResolveSafeAssetPath(const AAssetsDir, AUrlPath: string; out AFullPath: string): Boolean;
var
  RootDir: string;
  RelPath: string;
  StartIdx: Integer;
  Candidate: string;
begin
  AFullPath := '';
  if (AUrlPath = '') or IsPathTraversalAttempt(AUrlPath) then
    Exit(False);

  StartIdx := 1;
  while (StartIdx <= Length(AUrlPath)) and (AUrlPath[StartIdx] = '/') do
    Inc(StartIdx);
  if StartIdx > Length(AUrlPath) then
    Exit(False);

  RelPath := Copy(AUrlPath, StartIdx, Length(AUrlPath) - StartIdx + 1);
  RootDir := IncludeTrailingPathDelimiter(ExpandFileName(AAssetsDir));
  Candidate := ExpandFileName(RootDir + RelPath);

  if Copy(Candidate, 1, Length(RootDir)) <> RootDir then
    Exit(False);
  if (not FileExists(Candidate)) or DirectoryExists(Candidate) then
    Exit(False);

  AFullPath := Candidate;
  Result := True;
end;

procedure SendHtmlResponse(AResponse: TResponse; AStatusCode: Integer; const AHtml: string);
begin
  AResponse.Code := AStatusCode;
  AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content := AHtml;
end;

procedure SendErrorResponse(AResponse: TResponse; AStatusCode: Integer; const AMessage: string);
var
  EscapedCode: string;
  EscapedMsg: string;
  Html: string;
begin
  EscapedCode := EscapeHtml(IntToStr(AStatusCode));
  EscapedMsg := EscapeHtml(AMessage);
  Html :=
    '<!DOCTYPE html>' + LineEnding +
    '<html lang="en">' + LineEnding +
    '<head><meta charset="utf-8"><title>' + EscapedCode + ' - ' + EscapedMsg + '</title></head>' + LineEnding +
    '<body><h1>' + EscapedCode + '</h1><p>' + EscapedMsg + '</p></body>' + LineEnding +
    '</html>' + LineEnding;
  SendHtmlResponse(AResponse, AStatusCode, Html);
end;

function ServeStaticFile(const AAssetsDir, AUrlPath: string; AResponse: TResponse): Boolean;
var
  FullPath: string;
  FileStream: TFileStream;
begin
  if IsPathTraversalAttempt(AUrlPath) then
  begin
    SendErrorResponse(AResponse, 403, '403 Forbidden');
    Exit(True);
  end;

  if not ResolveSafeAssetPath(AAssetsDir, AUrlPath, FullPath) then
    Exit(False);

  FileStream := TFileStream.Create(FullPath, fmOpenRead or fmShareDenyWrite);
  AResponse.Code := 200;
  AResponse.ContentType := GetMimeTypeForFile(FullPath);
  AResponse.ContentStream := FileStream;
  AResponse.FreeContentStream := True;
  Result := True;
end;

end.
