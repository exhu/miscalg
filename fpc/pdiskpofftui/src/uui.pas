unit uui;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes, ucommon, uboxdrawing, udevice, uterminal;

type
  TStatusType = (
    stPending,
    stSuccess,
    stError
  );

  TRowType = (
    rtDevice,
    rtPartition
  );

  TUiRow = record
    RowType: TRowType;
    DiskIndex: SizeInt;           // Index into Disks[]
    DiskPath: String;            // Parent disk path, e.g. /dev/sdb
    DevPath: String;             // Node device path, e.g. /dev/sdb or /dev/sdb1
    TreePrefix: String;          // Prefix for device column
    DevCol: String;              // Full formatted device column text
    NameCol: String;             // Model / Name column text
    SerialCol: String;           // Serial column text
    MntCol: String;              // Mounted / Crypt column text

    MountPaths: TStringArray;    // Paths to unmount for this item subtree
    CryptLockPaths: TStringArray;// Paths to lock for this item subtree
    IsExpanded: Boolean;         // Only for rtDevice
  end;

  TColumnLayout = record
    Dev: Integer;
    Name: Integer;
    Serial: Integer;
    Mnt: Integer;
    class function Calculate(TotalWidth: Integer): TColumnLayout; static;
  end;

  TUiRowArray = array of TUiRow;

  TTuiApp = class
  private
    Disks: TDiskInfoArray;
    ExpandedDisks: TStringList;
    VisibleRows: TUiRowArray;

    SelectedIndex: Integer;
    ScrollOffset: Integer;

    StatusMessage: String;
    StatusType: TStatusType;

    SpinnerFrame: Integer;
    LastWidth, LastHeight: Integer;

    procedure FlattenPartitions(
      const Parts: TPartitionInfoArray;
      DiskIdx: Integer;
      const DiskPath, Prefix: String
    );
    procedure RebuildVisibleRows;
    function GetPageStep: Integer;
    procedure MoveUp;
    procedure MoveDown;
    procedure PageUp;
    procedure PageDown;
    procedure JumpToStart;
    procedure JumpToEnd;
    procedure UpdateScrollOffset(ViewHeight: Integer);

    procedure HandleEnter;
    procedure HandleMount;
    procedure HandleUnmountOnly;
    procedure HandlePowerOff;

    procedure DrawTitleBar(Width: Integer);
    procedure DrawTableFrame(Width, Top: Integer; const Cols: TColumnLayout);
    procedure DrawDataRows(Width, StartY, RowCount: Integer; const Cols: TColumnLayout);
    procedure RenderDataRow(const Item: TUiRow; IsSelected: Boolean; const Cols: TColumnLayout; TotalWidth: Integer);
    procedure DrawStatusLine;
    procedure CheckResize;
  public
    constructor Create;
    destructor Destroy; override;

    procedure OnBusy(const TaskDesc: String);
    procedure RefreshDisks(PreserveStatus: Boolean = False);
    procedure Draw;
    procedure Run;
  end;

implementation

const
  SpinnerChars: array[0..3] of String = ('|', '/', '-', '\');

class function TColumnLayout.Calculate(TotalWidth: Integer): TColumnLayout;
var
  DevWidth, SerialWidth, MntWidth, NameWidth: Integer;
begin
  DevWidth := IntMax(16, IntMin(32, TotalWidth * 25 div 100));
  SerialWidth := IntMax(12, IntMin(20, TotalWidth * 18 div 100));
  MntWidth := IntMax(18, IntMin(35, TotalWidth * 28 div 100));

  // 3 separators + 2 border columns = 5 consumed width units
  NameWidth := TotalWidth - 2 - (DevWidth + SerialWidth + MntWidth + 3);
  if NameWidth < 12 then
  begin
    NameWidth := 12;
    DevWidth := IntMax(10, TotalWidth - 2 - (NameWidth + SerialWidth + MntWidth + 3));
  end;

  Result.Dev := DevWidth;
  Result.Name := NameWidth;
  Result.Serial := SerialWidth;
  Result.Mnt := MntWidth;
end;

constructor TTuiApp.Create;
begin
  inherited Create;
  ExpandedDisks := TStringList.Create;
  ExpandedDisks.Sorted := True;
  ExpandedDisks.Duplicates := dupIgnore;

  SelectedIndex := 0;
  ScrollOffset := 0;
  SpinnerFrame := 0;
  LastWidth := 0;
  LastHeight := 0;

  StatusMessage := 'Ready. J/K: Select | Enter: Expand/Collapse | M: Mount | U: Unmount | P: Poweroff | Q: Quit';
  StatusType := stSuccess;
end;

destructor TTuiApp.Destroy;
begin
  ExpandedDisks.Free;
  inherited Destroy;
end;

procedure TTuiApp.OnBusy(const TaskDesc: String);
begin
  SpinnerFrame := (SpinnerFrame + 1) mod 4;
  StatusMessage := '[' + SpinnerChars[SpinnerFrame] + '] ' + TaskDesc;
  StatusType := stPending;
  DrawStatusLine;
  FlushTerminal;
end;

procedure TTuiApp.FlattenPartitions(
  const Parts: TPartitionInfoArray;
  DiskIdx: Integer;
  const DiskPath, Prefix: String
);
var
  i: Integer;
  IsLast: Boolean;
  Branch, RowPrefix, ChildPrefix: String;
  Row: TUiRow;
  NameDetail, MntDetail: String;
begin
  for i := 0 to High(Parts) do
  begin
    IsLast := (i = High(Parts));
    if IsLast then
      Branch := '└─ '
    else
      Branch := '├─ ';

    RowPrefix := Prefix + Branch;
    if IsLast then
      ChildPrefix := Prefix + '   '
    else
      ChildPrefix := Prefix + '│  ';

    Row.RowType := rtPartition;
    Row.DiskIndex := DiskIdx;
    Row.DiskPath := DiskPath;
    Row.DevPath := Parts[i].Path;
    Row.TreePrefix := RowPrefix;
    Row.DevCol := RowPrefix + Parts[i].Path;

    // Model / Name column:
    NameDetail := '';
    if Parts[i].LabelStr <> '' then
    begin
      NameDetail := Parts[i].LabelStr;
      if (Parts[i].Fstype <> '') or (Parts[i].Size <> '') then
      begin
        NameDetail := NameDetail + ' (';
        if Parts[i].Fstype <> '' then
          NameDetail := NameDetail + Parts[i].Fstype;
        if (Parts[i].Fstype <> '') and (Parts[i].Size <> '') then
          NameDetail := NameDetail + ', ';
        if Parts[i].Size <> '' then
          NameDetail := NameDetail + Parts[i].Size;
        NameDetail := NameDetail + ')';
      end;
    end
    else if Parts[i].Fstype <> '' then
    begin
      NameDetail := Parts[i].Fstype;
      if Parts[i].Size <> '' then
        NameDetail := NameDetail + ' (' + Parts[i].Size + ')';
    end
    else if Parts[i].Size <> '' then
      NameDetail := Parts[i].Size
    else
      NameDetail := '-';

    Row.NameCol := ' ' + NameDetail;

    // Serial column:
    Row.SerialCol := ' -';

    // Mounted / Crypt column:
    MntDetail := '';
    if Length(Parts[i].Mountpoints) > 0 then
      MntDetail := StringArrayJoin(Parts[i].Mountpoints, ', ')
    else if (Parts[i].DeviceType = 'crypt') or ((Parts[i].Fstype = 'crypto_LUKS') and (Length(Parts[i].Children) > 0)) then
      MntDetail := '[unlocked]'
    else if Parts[i].Fstype = 'crypto_LUKS' then
      MntDetail := '[locked]'
    else
      MntDetail := '[unmounted]';

    Row.MntCol := ' ' + MntDetail;
    Row.MountPaths := Copy(Parts[i].MountPaths);
    Row.CryptLockPaths := Copy(Parts[i].CryptLockPaths);
    Row.IsExpanded := False;

    SetLength(VisibleRows, Length(VisibleRows) + 1);
    VisibleRows[High(VisibleRows)] := Row;

    if Length(Parts[i].Children) > 0 then
      FlattenPartitions(Parts[i].Children, DiskIdx, DiskPath, ChildPrefix);
  end;
end;

procedure TTuiApp.RebuildVisibleRows;
var
  dIdx: Integer;
  IsExp: Boolean;
  DevRow: TUiRow;
  Disk: TDiskInfo;
begin
  SetLength(VisibleRows, 0);
  if Length(Disks) = 0 then
  begin
    SelectedIndex := 0;
    Exit;
  end;

  for dIdx := 0 to High(Disks) do
  begin
    Disk := Disks[dIdx];
    IsExp := (ExpandedDisks.IndexOf(Disk.Path) >= 0);

    DevRow.RowType := rtDevice;
    DevRow.DiskIndex := dIdx;
    DevRow.DiskPath := Disk.Path;
    DevRow.DevPath := Disk.Path;
    DevRow.TreePrefix := ' ';
    DevRow.DevCol := ' ' + Disk.Path;
    DevRow.NameCol := ' ' + Disk.Name;
    DevRow.SerialCol := ' ' + Disk.Serial;

    if Disk.TotalMountedOrUnlocked = 0 then
      DevRow.MntCol := ' 0'
    else
      DevRow.MntCol := Format(' %d (%d mnt, %d crypt)', [Disk.TotalMountedOrUnlocked, Disk.MountedCount, Disk.CryptUnlockedCount]);

    DevRow.MountPaths := Copy(Disk.MountPaths);
    DevRow.CryptLockPaths := Copy(Disk.CryptLockPaths);
    DevRow.IsExpanded := IsExp;

    SetLength(VisibleRows, Length(VisibleRows) + 1);
    VisibleRows[High(VisibleRows)] := DevRow;

    if IsExp and (Length(Disk.Partitions) > 0) then
      FlattenPartitions(Disk.Partitions, dIdx, Disk.Path, ' ');
  end;

  if (SelectedIndex >= Length(VisibleRows)) and (Length(VisibleRows) > 0) then
    SelectedIndex := Length(VisibleRows) - 1;
end;

procedure TTuiApp.RefreshDisks(PreserveStatus: Boolean);
var
  PrevMsg: String;
  PrevType: TStatusType;
  ErrorMsg, PluralSuffix: String;
  Fetched: TDiskInfoArray;
begin
  PrevMsg := StatusMessage;
  PrevType := StatusType;

  ErrorMsg := '';
  Fetched := FetchDisks(@Self.OnBusy, ErrorMsg);

  if ErrorMsg <> '' then
  begin
    StatusMessage := ErrorMsg;
    StatusType := stError;
  end
  else
  begin
    Disks := Fetched;
    RebuildVisibleRows;
    if PreserveStatus then
    begin
      StatusMessage := PrevMsg;
      StatusType := PrevType;
    end
    else
    begin
      if Length(Disks) = 1 then
        PluralSuffix := ''
      else
        PluralSuffix := 's';
      StatusMessage := Format('Disks refreshed (%d device%s found).', [Length(Disks), PluralSuffix]);
      StatusType := stSuccess;
    end;
  end;
end;

function TTuiApp.GetPageStep: Integer;
var
  W, H: Integer;
begin
  GetTerminalSize(W, H);
  Result := IntMax(1, H - 6);
end;

procedure TTuiApp.MoveUp;
begin
  if Length(VisibleRows) = 0 then Exit;
  if SelectedIndex > 0 then
    Dec(SelectedIndex);
end;

procedure TTuiApp.MoveDown;
begin
  if Length(VisibleRows) = 0 then Exit;
  if SelectedIndex + 1 < Length(VisibleRows) then
    Inc(SelectedIndex);
end;

procedure TTuiApp.PageUp;
var
  Step, i: Integer;
begin
  Step := GetPageStep;
  for i := 1 to Step do
    MoveUp;
end;

procedure TTuiApp.PageDown;
var
  Step, i: Integer;
begin
  Step := GetPageStep;
  for i := 1 to Step do
    MoveDown;
end;

procedure TTuiApp.JumpToStart;
begin
  SelectedIndex := 0;
end;

procedure TTuiApp.JumpToEnd;
begin
  if Length(VisibleRows) > 0 then
    SelectedIndex := Length(VisibleRows) - 1;
end;

procedure TTuiApp.UpdateScrollOffset(ViewHeight: Integer);
begin
  if SelectedIndex < ScrollOffset then
    ScrollOffset := SelectedIndex
  else if SelectedIndex >= ScrollOffset + ViewHeight then
    ScrollOffset := SelectedIndex - ViewHeight + 1;
end;

procedure TTuiApp.HandleEnter;
var
  Row: TUiRow;
  Idx: Integer;
  IsExp: Boolean;
begin
  if (Length(VisibleRows) = 0) or (SelectedIndex >= Length(VisibleRows)) then Exit;
  Row := VisibleRows[SelectedIndex];

  if Row.RowType = rtDevice then
  begin
    Idx := ExpandedDisks.IndexOf(Row.DiskPath);
    IsExp := (Idx >= 0);

    if IsExp then
      ExpandedDisks.Delete(Idx)
    else
      ExpandedDisks.Add(Row.DiskPath);

    RebuildVisibleRows;

    if (not IsExp) and (Length(Disks[Row.DiskIndex].Partitions) = 0) then
      StatusMessage := Format('Device %s expanded (no partitions).', [Row.DiskPath])
    else if not IsExp then
      StatusMessage := Format('Device %s expanded.', [Row.DiskPath])
    else
      StatusMessage := Format('Device %s collapsed.', [Row.DiskPath]);

    StatusType := stSuccess;
  end;
end;

procedure TTuiApp.HandleMount;
var
  Row: TUiRow;
  Disk: TDiskInfo;
  Res: TOperationResult;
begin
  if (Length(VisibleRows) = 0) or (SelectedIndex >= Length(VisibleRows)) then Exit;
  Row := VisibleRows[SelectedIndex];

  if Row.RowType = rtDevice then
  begin
    Disk := Disks[Row.DiskIndex];
    Res := MountDiskPartitions(Disk, @Self.OnBusy);
    StatusMessage := Res.Message;
    if Res.Success then
      StatusType := stSuccess
    else
      StatusType := stError;
  end
  else
  begin
    // Partition selected
    if StringArrayContains(Row.MountPaths, Row.DevPath) then
    begin
      StatusMessage := Format('Partition %s is already mounted.', [Row.DevPath]);
      StatusType := stSuccess;
      Exit;
    end;

    Res := MountSinglePartition(Row.DevPath, @Self.OnBusy);
    StatusMessage := Res.Message;
    if Res.Success then
      StatusType := stSuccess
    else
      StatusType := stError;
  end;
  RefreshDisks(True);
end;

procedure TTuiApp.HandleUnmountOnly;
var
  Row: TUiRow;
  Disk: TDiskInfo;
  Res: TOperationResult;
begin
  if (Length(VisibleRows) = 0) or (SelectedIndex >= Length(VisibleRows)) then Exit;
  Row := VisibleRows[SelectedIndex];

  if Row.RowType = rtDevice then
  begin
    Disk := Disks[Row.DiskIndex];
    if Disk.TotalMountedOrUnlocked = 0 then
    begin
      StatusMessage := Format('Device %s has no mounted partitions or unlocked containers.', [Disk.Path]);
      StatusType := stSuccess;
      Exit;
    end;

    Res := UnmountAndLockDisk(Disk, @Self.OnBusy);
    StatusMessage := Res.Message;
    if Res.Success then
      StatusType := stSuccess
    else
      StatusType := stError;
  end
  else
  begin
    // Partition selected
    if (Length(Row.MountPaths) = 0) and (Length(Row.CryptLockPaths) = 0) then
    begin
      StatusMessage := Format('Partition %s is not mounted or unlocked.', [Row.DevPath]);
      StatusType := stSuccess;
      Exit;
    end;

    Res := UnmountAndLockPartition(Row.DevPath, Row.MountPaths, Row.CryptLockPaths, @Self.OnBusy);
    StatusMessage := Res.Message;
    if Res.Success then
      StatusType := stSuccess
    else
      StatusType := stError;
  end;
  RefreshDisks(True);
end;

procedure TTuiApp.HandlePowerOff;
var
  Row: TUiRow;
  ParentDisk: TDiskInfo;
  Res: TOperationResult;
begin
  if (Length(VisibleRows) = 0) or (SelectedIndex >= Length(VisibleRows)) then Exit;
  Row := VisibleRows[SelectedIndex];

  // Power off parent disk device even when an individual partition is selected
  ParentDisk := Disks[Row.DiskIndex];

  Res := PowerOffDiskDevice(ParentDisk, @Self.OnBusy);
  StatusMessage := Res.Message;
  if Res.Success then
    StatusType := stSuccess
  else
    StatusType := stError;

  RefreshDisks(True);
end;

procedure TTuiApp.DrawTitleBar(Width: Integer);
const
  Title: String = ' Removable Disks Manager (diskpoff-tui) ';
  HelpTop: String = '[ J/K: Nav | Enter: Expand/Collapse | M: Mount | U: Unmount | P: Poweroff | R: Refresh | Q: Quit ] ';
var
  SpaceBetween: Integer;
  LineText: String;
begin
  SpaceBetween := IntMax(0, Width - UTF8CharCount(Title) - UTF8CharCount(HelpTop));
  LineText := Title + Replicate(' ', SpaceBetween) + HelpTop;

  MoveTo(0, 0);
  SetColor(ccWhite, ccBlue, True);
  WriteStr(TruncateOrPad(LineText, Width));
end;

procedure TTuiApp.DrawTableFrame(Width, Top: Integer; const Cols: TColumnLayout);
var
  DStyle, DHorizSVert, SStyle: TBoxStyle;
  procedure WriteHeaderCell(const LabelStr: String; ColWidth: Integer; IsLast: Boolean = False);
  begin
    SetColor(ccWhite, ccBlue, True);
    WriteStr(TruncateOrPad(LabelStr, ColWidth));
    SetColor(ccWhite, ccBlue, False);
    if IsLast then
      WriteStr(DStyle.V)
    else
      WriteStr(SStyle.V);
  end;
begin
  DStyle := DoubleStyle;
  DHorizSVert := DoubleHorizSingleVertStyle;
  SStyle := SingleStyle;

  // 1. Top border with column splitters (╦)
  MoveTo(0, Top);
  SetColor(ccWhite, ccBlue, False);
  WriteStr(
    DStyle.TL +
    Replicate(DStyle.H, Cols.Dev)    + DHorizSVert.TDown +
    Replicate(DStyle.H, Cols.Name)   + DHorizSVert.TDown +
    Replicate(DStyle.H, Cols.Serial) + DHorizSVert.TDown +
    Replicate(DStyle.H, Cols.Mnt)    +
    DStyle.TR
  );

  // 2. Header row
  MoveTo(0, Top + 1);
  WriteStr(DStyle.V);

  WriteHeaderCell(' Device', Cols.Dev);
  WriteHeaderCell(' Model / Name', Cols.Name);
  WriteHeaderCell(' Serial', Cols.Serial);
  WriteHeaderCell(' Mounted / Crypt', Cols.Mnt, True);

  // 3. Header separator with column splitters (╩)
  MoveTo(0, Top + 2);
  SetColor(ccWhite, ccBlue, False);
  WriteStr(
    DStyle.TRight +
    Replicate(DStyle.H, Cols.Dev)    + DHorizSVert.Cross +
    Replicate(DStyle.H, Cols.Name)   + DHorizSVert.Cross +
    Replicate(DStyle.H, Cols.Serial) + DHorizSVert.Cross +
    Replicate(DStyle.H, Cols.Mnt)    +
    DStyle.TLeft
  );
end;

procedure TTuiApp.RenderDataRow(
  const Item: TUiRow;
  IsSelected: Boolean;
  const Cols: TColumnLayout;
  TotalWidth: Integer
);
var
  SStyle: TBoxStyle;
  LineText: String;
begin
  SStyle := SingleStyle;

  if IsSelected then
    SetColor(ccBlue, ccWhite, False)
  else
    SetColor(ccWhite, ccBlue, False);

  LineText :=
    TruncateOrPad(Item.DevCol, Cols.Dev) + SStyle.V +
    TruncateOrPad(Item.NameCol, Cols.Name) + SStyle.V +
    TruncateOrPad(Item.SerialCol, Cols.Serial) + SStyle.V +
    TruncateOrPad(Item.MntCol, Cols.Mnt);

  WriteStr(TruncateOrPad(LineText, TotalWidth - 2));
  SetColor(ccWhite, ccBlue, False);
end;

procedure TTuiApp.DrawDataRows(Width, StartY, RowCount: Integer; const Cols: TColumnLayout);
var
  DStyle: TBoxStyle;
  Row, CurY: Integer;
  VisibleIdx: SizeInt;
  Msg: String;
begin
  DStyle := DoubleStyle;

  for Row := 0 to RowCount - 1 do
  begin
    CurY := StartY + Row;
    VisibleIdx := ScrollOffset + Row;

    MoveTo(0, CurY);
    SetColor(ccWhite, ccBlue, False);
    WriteStr(DStyle.V);

    if Length(VisibleRows) = 0 then
    begin
      if Row = 0 then
        Msg := '  (No active disk devices found. Press R to refresh)'
      else
        Msg := '';
      WriteStr(TruncateOrPad(Msg, Width - 2));
    end
    else if VisibleIdx < Length(VisibleRows) then
    begin
      RenderDataRow(VisibleRows[VisibleIdx], VisibleIdx = SelectedIndex, Cols, Width);
    end
    else
    begin
      WriteStr(Replicate(' ', Width - 2));
    end;

    MoveTo(Width - 1, CurY);
    SetColor(ccWhite, ccBlue, False);
    WriteStr(DStyle.V);
  end;
end;

procedure TTuiApp.DrawStatusLine;
var
  W, H: Integer;
  Msg: String;
begin
  GetTerminalSize(W, H);
  if (H <= 0) or (W <= 0) then Exit;

  MoveTo(0, H - 1);

  if StatusType = stError then
    SetColor(ccWhite, ccRed, True)
  else
    SetColor(ccYellow, ccGreen, True);

  Msg := ' ' + StatusMessage;
  WriteStr(TruncateOrPad(Msg, W));
  SetColor(ccWhite, ccBlue, False);
end;

procedure TTuiApp.CheckResize;
var
  W, H: Integer;
begin
  GetTerminalSize(W, H);
  if (W <> LastWidth) or (H <> LastHeight) then
    Draw;
end;

procedure TTuiApp.Draw;
var
  W, H, FrameTop, FrameBottom, InnerHeight: Integer;
  Cols: TColumnLayout;
  DStyle: TBoxStyle;
begin
  GetTerminalSize(W, H);
  LastWidth := W;
  LastHeight := H;

  // Reset base background
  SetColor(ccWhite, ccBlue, False);
  ClearScreen;

  if (W < 20) or (H < 6) then
  begin
    MoveTo(0, 0);
    WriteStr('Window too small');
    DrawStatusLine;
    FlushTerminal;
    Exit;
  end;

  FrameTop := 1;
  FrameBottom := H - 2;
  InnerHeight := IntMax(1, (FrameBottom - FrameTop + 1) - 4);

  Cols := TColumnLayout.Calculate(W);

  UpdateScrollOffset(InnerHeight);

  DrawTitleBar(W);
  DrawTableFrame(W, FrameTop, Cols);
  DrawDataRows(W, FrameTop + 3, InnerHeight, Cols);

  // Bottom border
  DStyle := DoubleStyle;
  MoveTo(0, FrameBottom);
  SetColor(ccWhite, ccBlue, False);
  WriteStr(DStyle.BL + Replicate(DStyle.H, W - 2) + DStyle.BR);

  DrawStatusLine;
  FlushTerminal;
end;

procedure TTuiApp.Run;
var
  Ev: TKeyEvent;
  Running: Boolean;
  ShouldRedraw: Boolean;
begin
  RefreshDisks;
  Draw;

  Running := True;
  while Running do
  begin
    CheckResize;

    if PollKeyEvent(50, Ev) then
    begin
      ShouldRedraw := True;
      case Ev.KeyType of
        ktEof:
          Running := False;

        ktEscape:
          Running := False;

        ktUp:
          MoveUp;

        ktDown:
          MoveDown;

        ktPageUp:
          PageUp;

        ktPageDown:
          PageDown;

        ktHome:
          JumpToStart;

        ktEnd:
          JumpToEnd;

        ktEnter:
          HandleEnter;

        ktChar:
          case Ev.Ch of
            'q', 'Q':
              Running := False;

            'j', 'J':
              MoveDown;

            'k', 'K':
              MoveUp;

            'u', 'U':
              HandleUnmountOnly;

            'm', 'M':
              HandleMount;

            'p', 'P':
              HandlePowerOff;

            'r', 'R':
              RefreshDisks;

            else
              ShouldRedraw := False;
          end;

        else
          ShouldRedraw := False;
      end;

      if ShouldRedraw and Running then
        Draw;
    end;
  end;
end;

end.
