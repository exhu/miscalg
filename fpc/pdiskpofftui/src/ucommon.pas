unit ucommon;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TStringArray = array of String;

function UTF8CharCount(const S: String): Integer;
function UTF8SubStr(const S: String; MaxChars: Integer): String;
function TruncateOrPad(const S: String; Width: Integer): String;
function Replicate(const S: String; Count: Integer): String;
function StringArrayContains(const Arr: TStringArray; const Val: String): Boolean;
function StringArrayJoin(const Arr: TStringArray; const Sep: String): String;
procedure StringArrayAddUnique(var Arr: TStringArray; const Val: String);
function IntMax(A, B: Integer): Integer;
function IntMin(A, B: Integer): Integer;
function IntClamp(Val, MinVal, MaxVal: Integer): Integer;

implementation

function UTF8CharCount(const S: String): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to Length(S) do
    if (Byte(S[i]) and $C0) <> $80 then
      Inc(Result);
end;

function UTF8SubStr(const S: String; MaxChars: Integer): String;
var
  i, Count: Integer;
begin
  if MaxChars <= 0 then Exit('');
  Count := 0;
  for i := 1 to Length(S) do
  begin
    if (Byte(S[i]) and $C0) <> $80 then
    begin
      if Count >= MaxChars then
        Exit(Copy(S, 1, i - 1));
      Inc(Count);
    end;
  end;
  Result := S;
end;

function TruncateOrPad(const S: String; Width: Integer): String;
var
  CharCount, Padding: Integer;
begin
  if Width <= 0 then Exit('');
  CharCount := UTF8CharCount(S);
  if CharCount > Width then
  begin
    if Width > 3 then
      Result := UTF8SubStr(S, Width - 3) + '...'
    else
      Result := UTF8SubStr(S, Width);
  end
  else
  begin
    Padding := Width - CharCount;
    Result := S + StringOfChar(' ', Padding);
  end;
end;

function Replicate(const S: String; Count: Integer): String;
var
  i: Integer;
begin
  Result := '';
  if Count <= 0 then Exit;
  for i := 1 to Count do
    Result := Result + S;
end;

function StringArrayContains(const Arr: TStringArray; const Val: String): Boolean;
var
  i: Integer;
begin
  for i := Low(Arr) to High(Arr) do
    if Arr[i] = Val then
      Exit(True);
  Result := False;
end;

function StringArrayJoin(const Arr: TStringArray; const Sep: String): String;
var
  i: Integer;
begin
  Result := '';
  for i := Low(Arr) to High(Arr) do
  begin
    if i > Low(Arr) then
      Result := Result + Sep;
    Result := Result + Arr[i];
  end;
end;

procedure StringArrayAddUnique(var Arr: TStringArray; const Val: String);
begin
  if (Val = '') or StringArrayContains(Arr, Val) then Exit;
  SetLength(Arr, Length(Arr) + 1);
  Arr[High(Arr)] := Val;
end;

function IntMax(A, B: Integer): Integer;
begin
  if A > B then Result := A else Result := B;
end;

function IntMin(A, B: Integer): Integer;
begin
  if A < B then Result := A else Result := B;
end;

function IntClamp(Val, MinVal, MaxVal: Integer): Integer;
begin
  if Val < MinVal then
    Result := MinVal
  else if Val > MaxVal then
    Result := MaxVal
  else
    Result := Val;
end;

end.
