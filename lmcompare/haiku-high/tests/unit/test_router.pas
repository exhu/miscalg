unit test_router;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, fphttpserver, router;

type
  { Records which handler ran; optionally raises. }
  TRecorder = class
  public
    Calls: array of string;
    RaiseMsg: string;
    procedure Record_(const Name: string);
    procedure HandlerA(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
    procedure HandlerB(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
    procedure Fallback(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
    procedure Boom(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  end;

  { Keeps test output quiet and records what would have been logged as errors. }
  TQuietRouter = class(TRouter)
  protected
    procedure LogRequest(const AMethod, AUri: string; ACode: Integer); override;
    procedure LogError(const AUri, AMessage: string); override;
  public
    ErrorLog: string;
  end;

  TRouterTests = class(TTestCase)
  private
    FRouter: TQuietRouter;
    FRec: TRecorder;
    FReq: TFPHTTPConnectionRequest;
    FResp: TFPHTTPConnectionResponse;
    procedure DoDispatch(const AUri: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRequestPathStripsQuery;
    procedure TestRequestPathKeepsPlainPath;
    procedure TestRequestPathEmptyBecomesRoot;
    procedure TestExactRouteCalled;
    procedure TestFirstRegisteredWins;
    procedure TestUnmatchedUsesFallback;
    procedure TestUnmatchedWithoutFallbackIs404;
    procedure TestHandlerExceptionIs500;
    procedure TestSendNotFoundSets404;
  end;

implementation

{ TRecorder }

procedure TRecorder.Record_(const Name: string);
begin
  SetLength(Calls, Length(Calls) + 1);
  Calls[High(Calls)] := Name;
end;

procedure TRecorder.HandlerA(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  Record_('A');
end;

procedure TRecorder.HandlerB(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  Record_('B');
end;

procedure TRecorder.Fallback(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  Record_('fallback');
end;

procedure TRecorder.Boom(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  raise Exception.Create(RaiseMsg);
end;

{ TQuietRouter }

procedure TQuietRouter.LogRequest(const AMethod, AUri: string; ACode: Integer);
begin
end;

procedure TQuietRouter.LogError(const AUri, AMessage: string);
begin
  ErrorLog := ErrorLog + AUri + ': ' + AMessage;
end;

{ TRouterTests }

procedure TRouterTests.SetUp;
begin
  inherited SetUp;
  FRouter := TQuietRouter.Create;
  FRec := TRecorder.Create;
  FReq := TFPHTTPConnectionRequest.Create;
  FResp := TFPHTTPConnectionResponse.Create(FReq);
end;

procedure TRouterTests.TearDown;
begin
  FResp.Free;
  FReq.Free;
  FRec.Free;
  FRouter.Free;
  inherited TearDown;
end;

procedure TRouterTests.DoDispatch(const AUri: string);
var
  Sender: TObject;
begin
  Sender := nil;
  FReq.URI := AUri;
  FRouter.Dispatch(Sender, FReq, FResp);
end;

procedure TRouterTests.TestRequestPathStripsQuery;
var
  R: TFPHTTPConnectionRequest;
begin
  R := TFPHTTPConnectionRequest.Create;
  try
    R.URI := '/hello?name=x&y=1';
    AssertEquals('/hello', TRouter.RequestPath(R));
  finally
    R.Free;
  end;
end;

procedure TRouterTests.TestRequestPathKeepsPlainPath;
var
  R: TFPHTTPConnectionRequest;
begin
  R := TFPHTTPConnectionRequest.Create;
  try
    R.URI := '/style.css';
    AssertEquals('/style.css', TRouter.RequestPath(R));
  finally
    R.Free;
  end;
end;

procedure TRouterTests.TestRequestPathEmptyBecomesRoot;
var
  R: TFPHTTPConnectionRequest;
begin
  R := TFPHTTPConnectionRequest.Create;
  try
    R.URI := '';
    AssertEquals('/', TRouter.RequestPath(R));
  finally
    R.Free;
  end;
end;

procedure TRouterTests.TestExactRouteCalled;
begin
  FRouter.AddRoute('/a', @FRec.HandlerA);
  FRouter.AddRoute('/b', @FRec.HandlerB);
  FRouter.SetFallback(@FRec.Fallback);
  DoDispatch('/b?x=1');
  AssertEquals(1, Length(FRec.Calls));
  AssertEquals('B', FRec.Calls[0]);
end;

procedure TRouterTests.TestFirstRegisteredWins;
begin
  FRouter.AddRoute('/a', @FRec.HandlerA);
  FRouter.AddRoute('/a', @FRec.HandlerB);
  DoDispatch('/a');
  AssertEquals(1, Length(FRec.Calls));
  AssertEquals('A', FRec.Calls[0]);
end;

procedure TRouterTests.TestUnmatchedUsesFallback;
begin
  FRouter.AddRoute('/a', @FRec.HandlerA);
  FRouter.SetFallback(@FRec.Fallback);
  DoDispatch('/nope');
  AssertEquals(1, Length(FRec.Calls));
  AssertEquals('fallback', FRec.Calls[0]);
end;

procedure TRouterTests.TestUnmatchedWithoutFallbackIs404;
begin
  FRouter.AddRoute('/a', @FRec.HandlerA);
  DoDispatch('/nope');
  AssertEquals(0, Length(FRec.Calls));
  AssertEquals(404, FResp.Code);
  AssertEquals('<h1>404 Not Found</h1>', Trim(FResp.Content));
end;

procedure TRouterTests.TestHandlerExceptionIs500;
begin
  FRec.RaiseMsg := 'kaboom';
  FRouter.AddRoute('/boom', @FRec.Boom);
  DoDispatch('/boom');
  AssertEquals(500, FResp.Code);
  AssertEquals('Internal Server Error', Trim(FResp.Content));
  AssertTrue('message not in body', Pos('kaboom', FResp.Content) = 0);
  AssertEquals('/boom: kaboom', FRouter.ErrorLog);
end;

procedure TRouterTests.TestSendNotFoundSets404;
begin
  TRouter.SendNotFound(FResp);
  AssertEquals(404, FResp.Code);
  AssertEquals('Not Found', FResp.CodeText);
end;

initialization
  RegisterTest(TRouterTests);
end.
