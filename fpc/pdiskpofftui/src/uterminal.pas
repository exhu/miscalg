unit uterminal;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, BaseUnix, termio;

type
  TConsoleColor = (
    ccBlack,
    ccRed,
    ccGreen,
    ccYellow,
    ccBlue,
    ccMagenta,
    ccCyan,
    ccWhite,
    ccDefault
  );

  TKeyType = (
    ktNone,
    ktChar,
    ktUp,
    ktDown,
    ktLeft,
    ktRight,
    ktPageUp,
    ktPageDown,
    ktHome,
    ktEnd,
    ktEnter,
    ktEscape,
    ktEof
  );

  TKeyEvent = record
    KeyType: TKeyType;
    Ch: Char;
  end;

function IsTerminal: Boolean;
procedure InitTerminal;
procedure RestoreTerminal;
procedure EnterAlternateScreen;
procedure LeaveAlternateScreen;
procedure HideCursor;
procedure ShowCursor;
procedure ClearScreen;
procedure MoveTo(X, Y: Integer);
procedure SetColor(FG, BG: TConsoleColor; Bright: Boolean = False);
procedure ResetColor;
procedure WriteStr(const S: String);
procedure FlushTerminal;
procedure GetTerminalSize(out Width, Height: Integer);
function PollKeyEvent(TimeoutMs: Integer; out Ev: TKeyEvent): Boolean;

implementation

var
  OrigTermios: TermIOS;
  RawModeActive: Boolean = False;
  AlternateScreenActive: Boolean = False;
  CursorHidden: Boolean = False;

function IsTerminal: Boolean;
begin
  Result := (IsATTY(StdInputHandle) = 1) and (IsATTY(StdOutputHandle) = 1);
end;

procedure EnableRawMode;
var
  Raw: TermIOS;
begin
  if RawModeActive then Exit;
  if TCGetAttr(StdInputHandle, OrigTermios) = 0 then
  begin
    Raw := OrigTermios;
    // Input modes: no break, no CR to NL, no parity check, no strip char, no start/stop output control
    Raw.c_iflag := Raw.c_iflag and not (BRKINT or ICRNL or INPCK or ISTRIP or IXON);
    // Output modes - disable post processing
    Raw.c_oflag := Raw.c_oflag and not (OPOST);
    // Control modes - set 8 bit chars
    Raw.c_cflag := Raw.c_cflag or (CS8);
    // Local modes: echo off, canonical off, extended input off, signal chars off
    Raw.c_lflag := Raw.c_lflag and not (ECHO or ICANON or IEXTEN or ISIG);
    // Control chars: min chars = 1, timeout = 0
    Raw.c_cc[VMIN] := 0;
    Raw.c_cc[VTIME] := 0;

    if TCSetAttr(StdInputHandle, TCSANOW, Raw) = 0 then
      RawModeActive := True;
  end;
end;

procedure RestoreTerminal;
begin
  if CursorHidden then
  begin
    ShowCursor;
    CursorHidden := False;
  end;

  if AlternateScreenActive then
  begin
    LeaveAlternateScreen;
    AlternateScreenActive := False;
  end;

  ResetColor;
  FlushTerminal;

  if RawModeActive then
  begin
    TCSetAttr(StdInputHandle, TCSANOW, OrigTermios);
    RawModeActive := False;
  end;
end;

procedure EnterAlternateScreen;
begin
  WriteStr(#27'[?1049h');
  AlternateScreenActive := True;
end;

procedure LeaveAlternateScreen;
begin
  WriteStr(#27'[?1049l');
  AlternateScreenActive := False;
end;

procedure HideCursor;
begin
  WriteStr(#27'[?25l');
  CursorHidden := True;
end;

procedure ShowCursor;
begin
  WriteStr(#27'[?25h');
  CursorHidden := False;
end;

procedure ClearScreen;
begin
  WriteStr(#27'[2J');
end;

procedure MoveTo(X, Y: Integer);
begin
  // ANSI cursor position is 1-indexed (row;col)
  WriteStr(#27'[' + IntToStr(Y + 1) + ';' + IntToStr(X + 1) + 'H');
end;

function FGColorCode(C: TConsoleColor): Integer;
begin
  case C of
    ccBlack:   Result := 30;
    ccRed:     Result := 31;
    ccGreen:   Result := 32;
    ccYellow:  Result := 33;
    ccBlue:    Result := 34;
    ccMagenta: Result := 35;
    ccCyan:    Result := 36;
    ccWhite:   Result := 37;
    ccDefault: Result := 39;
    else Result := 39;
  end;
end;

function BGColorCode(C: TConsoleColor): Integer;
begin
  case C of
    ccBlack:   Result := 40;
    ccRed:     Result := 41;
    ccGreen:   Result := 42;
    ccYellow:  Result := 43;
    ccBlue:    Result := 44;
    ccMagenta: Result := 45;
    ccCyan:    Result := 46;
    ccWhite:   Result := 47;
    ccDefault: Result := 49;
    else Result := 49;
  end;
end;

procedure SetColor(FG, BG: TConsoleColor; Bright: Boolean = False);
var
  Code: String;
begin
  Code := #27'[';
  if Bright then
    Code := Code + '1;'
  else
    Code := Code + '0;';
  Code := Code + IntToStr(FGColorCode(FG)) + ';' + IntToStr(BGColorCode(BG)) + 'm';
  WriteStr(Code);
end;

procedure ResetColor;
begin
  WriteStr(#27'[0m');
end;

procedure WriteStr(const S: String);
begin
  if Length(S) > 0 then
    fpWrite(StdOutputHandle, S[1], Length(S));
end;

procedure FlushTerminal;
begin
  // Handled by direct unbuffered fpWrite to StdOutputHandle
end;

procedure GetTerminalSize(out Width, Height: Integer);
var
  ws: TWinSize;
begin
  Width := 80;
  Height := 24;
  if fpIOCtl(StdInputHandle, TIOCGWINSZ, @ws) = 0 then
  begin
    if ws.ws_col > 0 then Width := ws.ws_col;
    if ws.ws_row > 0 then Height := ws.ws_row;
  end;
end;

procedure InitTerminal;
begin
  EnableRawMode;
  EnterAlternateScreen;
  HideCursor;
end;

function ReadRawByteWithTimeout(TimeoutMs: Integer; out B: Byte): Boolean;
var
  FDS: TFDSet;
  TimeVal: TTimeVal;
  Res: Integer;
begin
  B := 0;
  Result := False;
  fpFD_ZERO(FDS);
  fpFD_SET(StdInputHandle, FDS);

  TimeVal.tv_sec := TimeoutMs div 1000;
  TimeVal.tv_usec := (TimeoutMs mod 1000) * 1000;

  Res := fpSelect(StdInputHandle + 1, @FDS, nil, nil, @TimeVal);
  if Res > 0 then
  begin
    if fpRead(StdInputHandle, B, 1) = 1 then
      Result := True;
  end;
end;

function PollKeyEvent(TimeoutMs: Integer; out Ev: TKeyEvent): Boolean;
var
  B: Byte;
  Seq: String;
begin
  Ev.KeyType := ktNone;
  Ev.Ch := #0;
  Result := False;

  if not ReadRawByteWithTimeout(TimeoutMs, B) then
    Exit(False);

  Result := True;

  if B = 27 then // Escape
  begin
    Seq := #27;
    // Check if more characters follow immediately within 25ms
    while ReadRawByteWithTimeout(25, B) do
    begin
      Seq := Seq + Chr(B);
      // Terminal escape sequences usually end with letters, ~, etc.
      if Length(Seq) >= 2 then
      begin
        if (Seq[2] = '[') or (Seq[2] = 'O') then
        begin
          if (Length(Seq) >= 3) and (Seq[Length(Seq)] in ['A'..'Z', 'a'..'z', '~']) then
            Break;
        end
        else
          Break;
      end;
      if Length(Seq) > 10 then Break;
    end;

    if Seq = #27 then
    begin
      Ev.KeyType := ktEscape;
      Exit(True);
    end;

    // Decode ANSI escape sequences
    if (Seq = #27'[A') or (Seq = #27'OA') then Ev.KeyType := ktUp
    else if (Seq = #27'[B') or (Seq = #27'OB') then Ev.KeyType := ktDown
    else if (Seq = #27'[C') or (Seq = #27'OC') then Ev.KeyType := ktRight
    else if (Seq = #27'[D') or (Seq = #27'OD') then Ev.KeyType := ktLeft
    else if (Seq = #27'[H') or (Seq = #27'OH') or (Seq = #27'[1~') or (Seq = #27'[7~') then Ev.KeyType := ktHome
    else if (Seq = #27'[F') or (Seq = #27'OF') or (Seq = #27'[4~') or (Seq = #27'[8~') then Ev.KeyType := ktEnd
    else if (Seq = #27'[5~') then Ev.KeyType := ktPageUp
    else if (Seq = #27'[6~') then Ev.KeyType := ktPageDown
    else
      Ev.KeyType := ktNone;

    Exit(True);
  end;

  if (B = 13) or (B = 10) then
  begin
    Ev.KeyType := ktEnter;
    Exit(True);
  end;

  if (B = 3) or (B = 4) then // Ctrl+C, Ctrl+D
  begin
    Ev.KeyType := ktEof;
    Exit(True);
  end;

  Ev.KeyType := ktChar;
  Ev.Ch := Chr(B);
end;

end.
