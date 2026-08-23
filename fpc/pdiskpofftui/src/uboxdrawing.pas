unit uboxdrawing;

{$mode objfpc}{$H+}

interface

type
  TBoxStyle = record
    H, V: String;
    TL, TR, BL, BR: String;
    TDown, TUp, TRight, TLeft: String;
    Cross: String;
  end;

function SingleStyle: TBoxStyle;
function DoubleStyle: TBoxStyle;
function DoubleHorizSingleVertStyle: TBoxStyle;
function SingleHorizDoubleVertStyle: TBoxStyle;

implementation

function SingleStyle: TBoxStyle;
begin
  Result.H := '─';
  Result.V := '│';
  Result.TL := '┌';
  Result.TR := '┐';
  Result.BL := '└';
  Result.BR := '┘';
  Result.TDown := '┬';
  Result.TUp := '┴';
  Result.TRight := '├';
  Result.TLeft := '┤';
  Result.Cross := '┼';
end;

function DoubleStyle: TBoxStyle;
begin
  Result.H := '═';
  Result.V := '║';
  Result.TL := '╔';
  Result.TR := '╗';
  Result.BL := '╚';
  Result.BR := '╝';
  Result.TDown := '╦';
  Result.TUp := '╩';
  Result.TRight := '╠';
  Result.TLeft := '╣';
  Result.Cross := '╬';
end;

/// Double horizontal border with single vertical dividers (ideal for tables with distinct headers)
function DoubleHorizSingleVertStyle: TBoxStyle;
begin
  Result.H := '═';
  Result.V := '│';
  Result.TL := '╒';
  Result.TR := '╕';
  Result.BL := '╘';
  Result.BR := '╛';
  Result.TDown := '╤';
  Result.TUp := '╧';
  Result.TRight := '╞';
  Result.TLeft := '╡';
  Result.Cross := '╪';
end;

/// Single horizontal dividers with double vertical border
function SingleHorizDoubleVertStyle: TBoxStyle;
begin
  Result.H := '─';
  Result.V := '║';
  Result.TL := '╓';
  Result.TR := '╖';
  Result.BL := '╙';
  Result.BR := '╜';
  Result.TDown := '╥';
  Result.TUp := '╨';
  Result.TRight := '┠';
  Result.TLeft := '┨';
  Result.Cross := '╫';
end;

end.
