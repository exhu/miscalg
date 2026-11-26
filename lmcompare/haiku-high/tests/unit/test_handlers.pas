unit test_handlers;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, fphttpserver, handlers;

type
  THtmlEscapeTests = class(TTestCase)
  published
    procedure TestEscapesAmpersand;
    procedure TestEscapesLessThanAndGreaterThan;
    procedure TestEscapesDoubleQuote;
    procedure TestEscapesSingleQuote;
    procedure TestPlainTextUnchanged;
    procedure TestEmptyString;
    procedure TestAmpersandNotDoubleEscaped;
  end;

  THelloTests = class(TTestCase)
  private
    FReq: TFPHTTPConnectionRequest;
    FResp: TFPHTTPConnectionResponse;
    FHandlers: THandlers;
    procedure Invoke;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestQueryNameUsed;
    procedure TestNoNameIsStranger;
    procedure TestWhitespaceNameIsStranger;
    procedure TestPostNameUsed;
    procedure TestQueryWinsOverPost;
    procedure TestHtmlInNameIsEscaped;
    procedure TestStatusAndContentType;
  end;

implementation

{ THtmlEscapeTests }

procedure THtmlEscapeTests.TestEscapesAmpersand;
begin
  AssertEquals('&amp;', HtmlEscape('&'));
end;

procedure THtmlEscapeTests.TestEscapesLessThanAndGreaterThan;
begin
  AssertEquals('&lt;b&gt;', HtmlEscape('<b>'));
end;

procedure THtmlEscapeTests.TestEscapesDoubleQuote;
begin
  AssertEquals('&quot;x&quot;', HtmlEscape('"x"'));
end;

procedure THtmlEscapeTests.TestEscapesSingleQuote;
begin
  AssertEquals('&#39;x&#39;', HtmlEscape('''x'''));
end;

procedure THtmlEscapeTests.TestPlainTextUnchanged;
begin
  AssertEquals('Hello World 123', HtmlEscape('Hello World 123'));
end;

procedure THtmlEscapeTests.TestEmptyString;
begin
  AssertEquals('', HtmlEscape(''));
end;

procedure THtmlEscapeTests.TestAmpersandNotDoubleEscaped;
begin
  AssertEquals('&amp;lt;', HtmlEscape('&lt;'));
end;

{ THelloTests }

procedure THelloTests.SetUp;
begin
  inherited SetUp;
  FReq := TFPHTTPConnectionRequest.Create;
  FResp := TFPHTTPConnectionResponse.Create(FReq);
  FHandlers := THandlers.Create;
end;

procedure THelloTests.TearDown;
begin
  FHandlers.Free;
  FResp.Free;
  FReq.Free;
  inherited TearDown;
end;

procedure THelloTests.Invoke;
begin
  FHandlers.HandleHello(FReq, FResp);
end;

procedure THelloTests.TestQueryNameUsed;
begin
  FReq.QueryFields.Values['name'] := 'Yury';
  Invoke;
  AssertTrue('body contains greeting', Pos('hello, Yury!', FResp.Content) > 0);
end;

procedure THelloTests.TestNoNameIsStranger;
begin
  Invoke;
  AssertTrue('body contains stranger', Pos('hello, stranger!', FResp.Content) > 0);
end;

procedure THelloTests.TestWhitespaceNameIsStranger;
begin
  FReq.QueryFields.Values['name'] := '   ';
  Invoke;
  AssertTrue('body contains stranger', Pos('hello, stranger!', FResp.Content) > 0);
end;

procedure THelloTests.TestPostNameUsed;
begin
  FReq.ContentFields.Values['name'] := 'Ann';
  Invoke;
  AssertTrue('body contains Ann', Pos('hello, Ann!', FResp.Content) > 0);
end;

procedure THelloTests.TestQueryWinsOverPost;
begin
  FReq.QueryFields.Values['name'] := 'Query';
  FReq.ContentFields.Values['name'] := 'Post';
  Invoke;
  AssertTrue('query used', Pos('hello, Query!', FResp.Content) > 0);
  AssertTrue('post not used', Pos('Post', FResp.Content) = 0);
end;

procedure THelloTests.TestHtmlInNameIsEscaped;
begin
  FReq.QueryFields.Values['name'] := '<b>';
  Invoke;
  AssertTrue('escaped present', Pos('&lt;b&gt;', FResp.Content) > 0);
  AssertTrue('raw tag absent', Pos('<b>', FResp.Content) = 0);
end;

procedure THelloTests.TestStatusAndContentType;
begin
  Invoke;
  AssertEquals(200, FResp.Code);
  AssertTrue('content type is html', Pos('text/html', FResp.ContentType) = 1);
end;

initialization
  RegisterTest(THtmlEscapeTests);
  RegisterTest(THelloTests);
end.
