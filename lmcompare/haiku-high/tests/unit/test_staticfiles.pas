unit test_staticfiles;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, fphttpserver, staticfiles, router;

type
  TStaticFilesTests = class(TTestCase)
  private
    FBase: string;   { temp dir; holds secret.txt, outside the web root }
    FRoot: string;   { web root: FBase + 'root/' }
    FStatic: TStaticFiles;
    FReq: TFPHTTPConnectionRequest;
    FResp: TFPHTTPConnectionResponse;
    procedure WriteFile(const ARelPath, AContent: string);
    procedure ReleaseBody;
    function BodyText: string;
    function FileBody(const AContent: string): string;
    procedure AssertAllRejected(const APaths: array of string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestMimeHtml;
    procedure TestMimeCss;
    procedure TestMimeJs;
    procedure TestMimePng;
    procedure TestMimeJpg;
    procedure TestMimeSvg;
    procedure TestMimeTxt;
    procedure TestMimeIco;
    procedure TestMimeUpperCaseExtension;
    procedure TestMimeUnknownIsOctetStream;
    procedure TestServeExistingFile;
    procedure TestServeMissingFileFalse;
    procedure TestServeDirectoryFalse;
    procedure TestServeEmptyPathFalse;
    procedure TestServeRootSlashFalse;
    procedure TestServeRejectsDotDot;
    procedure TestServeRejectsEncodedDotDot;
    procedure TestServeRejectsBackslash;
    procedure TestServeRejectsNulByte;
    procedure TestServeDecodesPercentEncoding;
    procedure TestHandleIndexServesIndex;
    procedure TestHandleStaticUnknownIs404;
  end;

implementation

procedure TStaticFilesTests.WriteFile(const ARelPath, AContent: string);
var
  Full: string;
  L: TStringList;
begin
  Full := FRoot + ARelPath;
  ForceDirectories(ExtractFilePath(Full));
  L := TStringList.Create;
  try
    L.Text := AContent;
    L.SaveToFile(Full);
  finally
    L.Free;
  end;
end;

{ TResponse.SetContentStream frees the old stream when FreeContentStream is
  True, so ownership is dropped before the stream is released here. }
procedure TStaticFilesTests.ReleaseBody;
var
  S: TStream;
begin
  S := FResp.ContentStream;
  FResp.FreeContentStream := False;
  FResp.ContentStream := nil;
  S.Free;
end;

{ WriteFile saves through TStringList, which appends a line ending. }
function TStaticFilesTests.FileBody(const AContent: string): string;
begin
  Result := AContent + LineEnding;
end;

function TStaticFilesTests.BodyText: string;
var
  S: TStream;
begin
  S := FResp.ContentStream;
  AssertNotNull('response has a content stream', S);
  SetLength(Result, S.Size);
  S.Position := 0;
  if Result <> '' then
    S.ReadBuffer(Result[1], Length(Result));
end;

{ Tries every path before asserting, so a failure lists all that got through. }
procedure TStaticFilesTests.AssertAllRejected(const APaths: array of string);
var
  I: Integer;
  Served: string;
begin
  Served := '';
  for I := 0 to High(APaths) do
    if FStatic.Serve(APaths[I], FResp) then
    begin
      Served := Served + ' ' + APaths[I];
      ReleaseBody;
    end;
  AssertEquals('paths that were served', '', Served);
end;

procedure TStaticFilesTests.SetUp;
begin
  inherited SetUp;
  FBase := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'httpsrv_unit_' + IntToStr(Random(MaxInt)) + PathDelim;
  FRoot := FBase + 'root' + PathDelim;
  ForceDirectories(FRoot);
  WriteFile('../secret.txt', 'top secret');
  WriteFile('index.html', '<html>index</html>');
  WriteFile('a.css', 'body{}');
  WriteFile('sub/x.txt', 'hello');
  FStatic := TStaticFiles.Create(FRoot);
  FReq := TFPHTTPConnectionRequest.Create;
  FResp := TFPHTTPConnectionResponse.Create(FReq);
end;

procedure TStaticFilesTests.TearDown;
begin
  FResp.Free;
  FReq.Free;
  FStatic.Free;
  DeleteFile(FRoot + 'index.html');
  DeleteFile(FRoot + 'a.css');
  DeleteFile(FRoot + 'sub' + PathDelim + 'x.txt');
  RemoveDir(FRoot + 'sub');
  RemoveDir(FRoot);
  DeleteFile(FBase + 'secret.txt');
  RemoveDir(FBase);
  inherited TearDown;
end;

procedure TStaticFilesTests.TestMimeHtml;
begin
  AssertEquals('text/html; charset=utf-8', FStatic.MimeTypeFor('a.html'));
end;

procedure TStaticFilesTests.TestMimeCss;
begin
  AssertEquals('text/css', FStatic.MimeTypeFor('a.css'));
end;

procedure TStaticFilesTests.TestMimeJs;
begin
  AssertEquals('application/javascript', FStatic.MimeTypeFor('a.js'));
end;

procedure TStaticFilesTests.TestMimePng;
begin
  AssertEquals('image/png', FStatic.MimeTypeFor('a.png'));
end;

procedure TStaticFilesTests.TestMimeJpg;
begin
  AssertEquals('image/jpeg', FStatic.MimeTypeFor('a.jpg'));
  AssertEquals('image/jpeg', FStatic.MimeTypeFor('a.jpeg'));
end;

procedure TStaticFilesTests.TestMimeSvg;
begin
  AssertEquals('image/svg+xml', FStatic.MimeTypeFor('a.svg'));
end;

procedure TStaticFilesTests.TestMimeTxt;
begin
  AssertEquals('text/plain; charset=utf-8', FStatic.MimeTypeFor('a.txt'));
end;

procedure TStaticFilesTests.TestMimeIco;
begin
  AssertEquals('image/x-icon', FStatic.MimeTypeFor('a.ico'));
end;

procedure TStaticFilesTests.TestMimeUpperCaseExtension;
begin
  AssertEquals('text/css', FStatic.MimeTypeFor('A.CSS'));
end;

procedure TStaticFilesTests.TestMimeUnknownIsOctetStream;
begin
  AssertEquals('application/octet-stream', FStatic.MimeTypeFor('a.zzqqxx'));
end;

procedure TStaticFilesTests.TestServeExistingFile;
var
  Ok: Boolean;
begin
  Ok := FStatic.Serve('/a.css', FResp);
  try
    AssertTrue('serve returned True', Ok);
    AssertEquals(200, FResp.Code);
    AssertEquals('text/css', FResp.ContentType);
    AssertEquals(Int64(Length(FileBody('body{}'))), Int64(FResp.ContentLength));
    AssertEquals(FileBody('body{}'), BodyText);
  finally
    ReleaseBody;
  end;
end;

procedure TStaticFilesTests.TestServeMissingFileFalse;
begin
  AssertFalse(FStatic.Serve('/nope.css', FResp));
end;

procedure TStaticFilesTests.TestServeDirectoryFalse;
begin
  AssertFalse(FStatic.Serve('/sub', FResp));
end;

procedure TStaticFilesTests.TestServeEmptyPathFalse;
begin
  AssertFalse(FStatic.Serve('', FResp));
end;

procedure TStaticFilesTests.TestServeRootSlashFalse;
begin
  AssertFalse(FStatic.Serve('/', FResp));
end;

procedure TStaticFilesTests.TestServeRejectsDotDot;
begin
  AssertTrue('secret exists above root', FileExists(FRoot + '../secret.txt'));
  AssertAllRejected(['/../secret.txt', '/sub/../../secret.txt']);
end;

procedure TStaticFilesTests.TestServeRejectsEncodedDotDot;
begin
  AssertTrue('secret exists above root', FileExists(FRoot + '../secret.txt'));
  AssertAllRejected(['/%2e%2e/secret.txt', '/..%2Fsecret.txt',
    '/%2E%2E%2Fsecret.txt', '/.%2e/secret.txt']);
end;

procedure TStaticFilesTests.TestServeRejectsBackslash;
begin
  AssertFalse(FStatic.Serve('\a.css', FResp));
end;

procedure TStaticFilesTests.TestServeRejectsNulByte;
begin
  AssertFalse(FStatic.Serve('/a.css%00', FResp));
end;

procedure TStaticFilesTests.TestServeDecodesPercentEncoding;
var
  Ok: Boolean;
begin
  Ok := FStatic.Serve('/sub/%78.txt', FResp);
  try
    AssertTrue('encoded name resolved', Ok);
    AssertEquals(200, FResp.Code);
    AssertEquals(FileBody('hello'), BodyText);
  finally
    ReleaseBody;
  end;
end;

procedure TStaticFilesTests.TestHandleIndexServesIndex;
begin
  FStatic.HandleIndex(FReq, FResp);
  try
    AssertEquals(200, FResp.Code);
    AssertTrue('html content type', Pos('text/html', FResp.ContentType) = 1);
    AssertEquals(FileBody('<html>index</html>'), BodyText);
  finally
    ReleaseBody;
  end;
end;

procedure TStaticFilesTests.TestHandleStaticUnknownIs404;
begin
  FReq.URI := '/missing.css';
  FStatic.HandleStatic(FReq, FResp);
  AssertEquals(404, FResp.Code);
end;

initialization
  Randomize;
  RegisterTest(TStaticFilesTests);
end.
