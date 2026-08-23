unit udevice;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, process, ucommon;

type
  TBusyCallback = procedure(const TaskDesc: String) of object;

  TCommandResult = record
    ExitCode: Integer;
    Output: String;
    Error: String;
    function IsSuccess: Boolean;
  end;

  PPartitionInfo = ^TPartitionInfo;
  TPartitionInfo = record
    Name: String;
    Path: String;
    Model: String;
    Vendor: String;
    Serial: String;
    Size: String;
    DeviceType: String;
    Fstype: String;
    LabelStr: String;
    Mountpoints: TStringArray;
    MountedCount: Integer;
    CryptUnlockedCount: Integer;
    MountPaths: TStringArray;        // paths to unmount (depth-first: leaves first)
    CryptLockPaths: TStringArray;    // paths to lock
    Children: array of TPartitionInfo;
    function TotalMountedOrUnlocked: Integer;
  end;

  TPartitionInfoArray = array of TPartitionInfo;

  TDiskInfo = record
    Path: String;                // e.g. /dev/sdb
    Name: String;                // e.g. Samsung T7 or sdb
    Serial: String;              // e.g. 25074E933396 or "-"
    Size: String;                // e.g. 1.8T
    DeviceType: String;          // e.g. disk
    IsHotplug: Boolean;
    IsRemovable: Boolean;

    MountedCount: Integer;       // count of mounted filesystems
    CryptUnlockedCount: Integer; // count of unlocked LUKS containers

    MountPaths: TStringArray;    // paths to unmount (depth-first: leaves first)
    CryptLockPaths: TStringArray;// paths to lock
    Partitions: TPartitionInfoArray; // tree of partitions
    function TotalMountedOrUnlocked: Integer;
  end;

  TDiskInfoArray = array of TDiskInfo;

  TParsedNode = record
    Name: String;
    Path: String;
    Model: String;
    Vendor: String;
    Serial: String;
    Size: String;
    DeviceType: String;
    Fstype: String;
    LabelStr: String;
    Hotplug: Boolean;
    Rm: Boolean;
    Mountpoints: TStringArray;
    Children: array of TParsedNode;
  end;

  TParsedNodeArray = array of TParsedNode;

  TOperationResult = record
    Success: Boolean;
    Message: String;
  end;

function ParseLsblkJson(const JsonText: String): TDiskInfoArray;
procedure CollectMountablePartitionsForDisk(
  const Disk: TDiskInfo;
  var CandidatePaths, AlreadyMountedPaths: TStringArray
);
procedure CollectMountablePartitionsFromTree(
  const Part: TPartitionInfo;
  var CandidatePaths, AlreadyMountedPaths: TStringArray
);
function IsSwapPartition(const Part: TPartitionInfo): Boolean;
function IsPartitionMounted(const Part: TPartitionInfo): Boolean;

function RunCommandWithBusyAnimation(
  const Exe: String;
  const Args: array of String;
  const Description: String;
  OnBusy: TBusyCallback = nil
): TCommandResult;

function FetchDisks(OnBusy: TBusyCallback; out ErrorMsg: String): TDiskInfoArray;
function MountSinglePartition(const DevPath: String; OnBusy: TBusyCallback = nil): TOperationResult;
function MountDiskPartitions(const Disk: TDiskInfo; OnBusy: TBusyCallback = nil): TOperationResult;
function UnmountAndLockPartition(
  const DevPath: String;
  const MountPaths, CryptLockPaths: TStringArray;
  OnBusy: TBusyCallback = nil
): TOperationResult;
function UnmountAndLockDisk(const Disk: TDiskInfo; OnBusy: TBusyCallback = nil): TOperationResult;
function PowerOffDiskDevice(const Disk: TDiskInfo; OnBusy: TBusyCallback = nil): TOperationResult;

implementation

function TCommandResult.IsSuccess: Boolean;
begin
  Result := (ExitCode = 0);
end;

function TPartitionInfo.TotalMountedOrUnlocked: Integer;
begin
  Result := MountedCount + CryptUnlockedCount;
end;

function TDiskInfo.TotalMountedOrUnlocked: Integer;
begin
  Result := MountedCount + CryptUnlockedCount;
end;

function GetJsonString(Obj: TJSONObject; const Key: String; const DefaultVal: String = ''): String;
var
  Data: TJSONData;
begin
  if Obj = nil then Exit(DefaultVal);
  Data := Obj.Find(Key);
  if (Data = nil) or (Data.JSONType = jtNull) then Exit(DefaultVal);
  if Data.JSONType = jtString then
    Exit(Trim(Data.AsString))
  else if Data.JSONType = jtNumber then
    Exit(Data.AsString)
  else if Data.JSONType = jtBoolean then
    Exit(BoolToStr(Data.AsBoolean, 'true', 'false'));
  Result := DefaultVal;
end;

function GetJsonBool(Obj: TJSONObject; const Key: String; DefaultVal: Boolean = False): Boolean;
var
  Data: TJSONData;
  S: String;
begin
  if Obj = nil then Exit(DefaultVal);
  Data := Obj.Find(Key);
  if (Data = nil) or (Data.JSONType = jtNull) then Exit(DefaultVal);
  if Data.JSONType = jtBoolean then
    Exit(Data.AsBoolean)
  else if Data.JSONType = jtString then
  begin
    S := LowerCase(Trim(Data.AsString));
    Exit((S = '1') or (S = 'true') or (S = 'yes'));
  end
  else if Data.JSONType = jtNumber then
    Exit(Data.AsInt64 <> 0);
  Result := DefaultVal;
end;

function GetJsonMountpoints(Obj: TJSONObject): TStringArray;
var
  Data, Elem: TJSONData;
  Arr: TJSONArray;
  i: Integer;
  S: String;
begin
  SetLength(Result, 0);
  if Obj = nil then Exit;

  Data := Obj.Find('mountpoints');
  if (Data <> nil) and (Data.JSONType = jtArray) then
  begin
    Arr := TJSONArray(Data);
    for i := 0 to Arr.Count - 1 do
    begin
      Elem := Arr[i];
      if (Elem <> nil) and (Elem.JSONType = jtString) then
      begin
        S := Trim(Elem.AsString);
        if (S <> '') and (S <> 'null') then
          StringArrayAddUnique(Result, S);
      end;
    end;
  end;

  Data := Obj.Find('mountpoint');
  if (Data <> nil) and (Data.JSONType = jtString) then
  begin
    S := Trim(Data.AsString);
    if (S <> '') and (S <> 'null') then
      StringArrayAddUnique(Result, S);
  end;
end;

function ParseNodeFromJson(Obj: TJSONObject): TParsedNode;
var
  ChildrenData, ChildElem: TJSONData;
  ChildrenArr: TJSONArray;
  i: Integer;
begin
  Result := Default(TParsedNode);
  Result.Name := GetJsonString(Obj, 'name');
  Result.Path := GetJsonString(Obj, 'path');
  if (Result.Path = '') and (Result.Name <> '') then
    Result.Path := '/dev/' + Result.Name;
  Result.Model := GetJsonString(Obj, 'model');
  Result.Vendor := GetJsonString(Obj, 'vendor');
  Result.Serial := GetJsonString(Obj, 'serial');
  Result.Size := GetJsonString(Obj, 'size');
  Result.DeviceType := GetJsonString(Obj, 'type');
  Result.Fstype := GetJsonString(Obj, 'fstype');
  Result.LabelStr := GetJsonString(Obj, 'label');
  Result.Hotplug := GetJsonBool(Obj, 'hotplug');
  Result.Rm := GetJsonBool(Obj, 'rm');
  Result.Mountpoints := GetJsonMountpoints(Obj);

  SetLength(Result.Children, 0);
  ChildrenData := Obj.Find('children');
  if (ChildrenData <> nil) and (ChildrenData.JSONType = jtArray) then
  begin
    ChildrenArr := TJSONArray(ChildrenData);
    SetLength(Result.Children, ChildrenArr.Count);
    for i := 0 to ChildrenArr.Count - 1 do
    begin
      ChildElem := ChildrenArr[i];
      if (ChildElem <> nil) and (ChildElem.JSONType = jtObject) then
        Result.Children[i] := ParseNodeFromJson(TJSONObject(ChildElem));
    end;
  end;
end;

procedure CollectNodeDetails(
  const Node: TParsedNode;
  IsRoot: Boolean;
  var MountedCount, CryptUnlockedCount: Integer;
  var MountPaths, CryptLockPaths: TStringArray
);
var
  i: Integer;
  IsMounted: Boolean;
  M: String;
begin
  // Process children first (depth-first: leaves first)
  for i := 0 to High(Node.Children) do
    CollectNodeDetails(Node.Children[i], False, MountedCount, CryptUnlockedCount, MountPaths, CryptLockPaths);

  // Check mountpoints
  if Length(Node.Mountpoints) > 0 then
  begin
    IsMounted := False;
    for i := 0 to High(Node.Mountpoints) do
    begin
      M := Node.Mountpoints[i];
      if (M <> '') and (M <> 'null') then
      begin
        IsMounted := True;
        Break;
      end;
    end;
    if IsMounted then
    begin
      Inc(MountedCount);
      if Node.Path <> '' then
        StringArrayAddUnique(MountPaths, Node.Path);
    end;
  end;

  // Check crypt status
  if Node.DeviceType = 'crypt' then
  begin
    Inc(CryptUnlockedCount);
    if Node.Path <> '' then
      StringArrayAddUnique(CryptLockPaths, Node.Path);
  end
  else if (Node.Fstype = 'crypto_LUKS') and (Length(Node.Children) > 0) then
  begin
    // LUKS container that is unlocked
    if Node.Path <> '' then
      StringArrayAddUnique(CryptLockPaths, Node.Path);
  end;
end;

function PartitionInfoFromParsedNode(const Node: TParsedNode): TPartitionInfo;
var
  i: Integer;
begin
  Result.Name := Node.Name;
  Result.Path := Node.Path;
  Result.Model := Node.Model;
  Result.Vendor := Node.Vendor;
  if Node.Serial = '' then
    Result.Serial := '-'
  else
    Result.Serial := Node.Serial;
  Result.Size := Node.Size;
  Result.DeviceType := Node.DeviceType;
  Result.Fstype := Node.Fstype;
  Result.LabelStr := Node.LabelStr;
  Result.Mountpoints := Copy(Node.Mountpoints);
  Result.MountedCount := 0;
  Result.CryptUnlockedCount := 0;
  SetLength(Result.MountPaths, 0);
  SetLength(Result.CryptLockPaths, 0);

  // Depth-first collection for this partition subtree
  CollectNodeDetails(Node, False, Result.MountedCount, Result.CryptUnlockedCount, Result.MountPaths, Result.CryptLockPaths);

  SetLength(Result.Children, Length(Node.Children));
  for i := 0 to High(Node.Children) do
    Result.Children[i] := PartitionInfoFromParsedNode(Node.Children[i]);
end;

function DiskInfoFromParsedNode(const RootNode: TParsedNode): TDiskInfo;
var
  DisplayName: String;
  i: Integer;
begin
  Result.Path := RootNode.Path;
  if RootNode.Serial = '' then
    Result.Serial := '-'
  else
    Result.Serial := RootNode.Serial;
  Result.Size := RootNode.Size;
  Result.DeviceType := RootNode.DeviceType;
  Result.IsHotplug := RootNode.Hotplug;
  Result.IsRemovable := RootNode.Rm;

  // Construct friendly name/model
  DisplayName := '';
  if (RootNode.Vendor <> '') and (RootNode.Model <> '') then
  begin
    if Pos(RootNode.Vendor, RootNode.Model) > 0 then
      DisplayName := RootNode.Model
    else
      DisplayName := RootNode.Vendor + ' ' + RootNode.Model;
  end
  else if RootNode.Model <> '' then
    DisplayName := RootNode.Model
  else if RootNode.Vendor <> '' then
    DisplayName := RootNode.Vendor
  else
    DisplayName := RootNode.Name;

  Result.Name := DisplayName;
  Result.MountedCount := 0;
  Result.CryptUnlockedCount := 0;
  SetLength(Result.MountPaths, 0);
  SetLength(Result.CryptLockPaths, 0);

  CollectNodeDetails(RootNode, True, Result.MountedCount, Result.CryptUnlockedCount, Result.MountPaths, Result.CryptLockPaths);

  SetLength(Result.Partitions, Length(RootNode.Children));
  for i := 0 to High(RootNode.Children) do
    Result.Partitions[i] := PartitionInfoFromParsedNode(RootNode.Children[i]);
end;

function ParseLsblkJson(const JsonText: String): TDiskInfoArray;
var
  JsonDoc: TJSONData;
  RootObj: TJSONObject;
  BlockDevicesData, DevVal: TJSONData;
  BlockDevicesArr: TJSONArray;
  ParsedNode: TParsedNode;
  i: Integer;
begin
  Result := nil;
  if Trim(JsonText) = '' then Exit;

  try
    JsonDoc := GetJSON(JsonText);
  except
    Exit;
  end;

  try
    if (JsonDoc = nil) or (JsonDoc.JSONType <> jtObject) then Exit;
    RootObj := TJSONObject(JsonDoc);
    BlockDevicesData := RootObj.Find('blockdevices');
    if (BlockDevicesData = nil) or (BlockDevicesData.JSONType <> jtArray) then Exit;

    BlockDevicesArr := TJSONArray(BlockDevicesData);
    for i := 0 to BlockDevicesArr.Count - 1 do
    begin
      DevVal := BlockDevicesArr[i];
      if (DevVal <> nil) and (DevVal.JSONType = jtObject) then
      begin
        ParsedNode := ParseNodeFromJson(TJSONObject(DevVal));
        if ParsedNode.DeviceType = 'disk' then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := DiskInfoFromParsedNode(ParsedNode);
        end;
      end;
    end;
  finally
    JsonDoc.Free;
  end;
end;

function IsSwapPartition(const Part: TPartitionInfo): Boolean;
var
  i: Integer;
begin
  if Part.Fstype = 'swap' then Exit(True);
  if Part.DeviceType = 'swap' then Exit(True);
  for i := 0 to High(Part.Mountpoints) do
    if Part.Mountpoints[i] = '[SWAP]' then
      Exit(True);
  Result := False;
end;

function IsPartitionMounted(const Part: TPartitionInfo): Boolean;
var
  i: Integer;
  M: String;
begin
  for i := 0 to High(Part.Mountpoints) do
  begin
    M := Part.Mountpoints[i];
    if (M <> '') and (M <> 'null') and (M <> '[SWAP]') then
      Exit(True);
  end;
  Result := False;
end;

procedure CollectMountablePartitionsFromTree(
  const Part: TPartitionInfo;
  var CandidatePaths, AlreadyMountedPaths: TStringArray
);
var
  i: Integer;
begin
  // Exclude swap
  if IsSwapPartition(Part) then Exit;

  // If it has children (e.g. decrypted LUKS container or LVM volume), recurse into children
  if Length(Part.Children) > 0 then
  begin
    for i := 0 to High(Part.Children) do
      CollectMountablePartitionsFromTree(Part.Children[i], CandidatePaths, AlreadyMountedPaths);
    Exit;
  end;

  // Skip locked LUKS containers (cannot be mounted directly without unlocking)
  if Part.Fstype = 'crypto_LUKS' then Exit;

  if Part.Path = '' then Exit;

  if IsPartitionMounted(Part) then
    StringArrayAddUnique(AlreadyMountedPaths, Part.Path)
  else
    StringArrayAddUnique(CandidatePaths, Part.Path);
end;

procedure CollectMountablePartitionsForDisk(
  const Disk: TDiskInfo;
  var CandidatePaths, AlreadyMountedPaths: TStringArray
);
var
  i: Integer;
begin
  if Length(Disk.Partitions) = 0 then
  begin
    if Disk.Path = '' then Exit;
    if Disk.MountedCount > 0 then
      StringArrayAddUnique(AlreadyMountedPaths, Disk.Path)
    else
      StringArrayAddUnique(CandidatePaths, Disk.Path);
    Exit;
  end;

  for i := 0 to High(Disk.Partitions) do
    CollectMountablePartitionsFromTree(Disk.Partitions[i], CandidatePaths, AlreadyMountedPaths);
end;

function FormatOpError(const Action, DevPath, RawError: String): String;
var
  Err: String;
  Prefixes: array[0..4] of String;
  p: String;
  i: Integer;
begin
  Err := Trim(RawError);
  if Err = '' then
    Exit('Failed to ' + Action + ' ' + DevPath + '.');

  Prefixes[0] := 'Error ' + Action + 'ing ' + DevPath + ': ';
  Prefixes[1] := 'Error ' + Action + ' ' + DevPath + ': ';
  Prefixes[2] := 'Error ' + Action + 'ing: ';
  Prefixes[3] := 'Error ' + Action + ': ';
  Prefixes[4] := 'Error: ';

  for i := 0 to High(Prefixes) do
  begin
    p := Prefixes[i];
    if Pos(p, Err) = 1 then
    begin
      Err := Trim(Copy(Err, Length(p) + 1, Length(Err)));
      Break;
    end;
  end;

  Result := 'Failed to ' + Action + ' ' + DevPath + ': ' + Err;
end;

function RunCommandWithBusyAnimation(
  const Exe: String;
  const Args: array of String;
  const Description: String;
  OnBusy: TBusyCallback
): TCommandResult;
var
  Proc: TProcess;
  StreamOut, StreamErr: TMemoryStream;
  Buffer: array[0..4095] of Byte;
  BytesRead: Integer;
  i: Integer;
begin
  Result.ExitCode := -1;
  Result.Output := '';
  Result.Error := '';
  FillChar(Buffer, SizeOf(Buffer), 0);

  Proc := TProcess.Create(nil);
  StreamOut := TMemoryStream.Create;
  StreamErr := TMemoryStream.Create;
  try
    try
      Proc.Executable := Exe;
      for i := Low(Args) to High(Args) do
        Proc.Parameters.Add(Args[i]);
      Proc.Options := [poUsePipes];
      Proc.Execute;
    except
      on E: Exception do
      begin
        Result.ExitCode := -1;
        Result.Error := E.Message;
        Exit;
      end;
    end;

    while Proc.Running do
    begin
      if Assigned(OnBusy) then
        OnBusy(Description);

      while (Proc.Output <> nil) and (Proc.Output.NumBytesAvailable > 0) do
      begin
        BytesRead := Proc.Output.Read(Buffer[0], SizeOf(Buffer));
        if BytesRead > 0 then
          StreamOut.WriteBuffer(Buffer[0], BytesRead);
      end;

      while (Proc.Stderr <> nil) and (Proc.Stderr.NumBytesAvailable > 0) do
      begin
        BytesRead := Proc.Stderr.Read(Buffer[0], SizeOf(Buffer));
        if BytesRead > 0 then
          StreamErr.WriteBuffer(Buffer[0], BytesRead);
      end;

      Sleep(60);
    end;

    // Drain remaining output
    while (Proc.Output <> nil) and (Proc.Output.NumBytesAvailable > 0) do
    begin
      BytesRead := Proc.Output.Read(Buffer[0], SizeOf(Buffer));
      if BytesRead > 0 then
        StreamOut.WriteBuffer(Buffer[0], BytesRead);
    end;
    while (Proc.Stderr <> nil) and (Proc.Stderr.NumBytesAvailable > 0) do
    begin
      BytesRead := Proc.Stderr.Read(Buffer[0], SizeOf(Buffer));
      if BytesRead > 0 then
        StreamErr.WriteBuffer(Buffer[0], BytesRead);
    end;

    SetLength(Result.Output, StreamOut.Size);
    if StreamOut.Size > 0 then
    begin
      StreamOut.Position := 0;
      StreamOut.ReadBuffer(Result.Output[1], StreamOut.Size);
    end;
    Result.Output := Trim(Result.Output);

    SetLength(Result.Error, StreamErr.Size);
    if StreamErr.Size > 0 then
    begin
      StreamErr.Position := 0;
      StreamErr.ReadBuffer(Result.Error[1], StreamErr.Size);
    end;
    Result.Error := Trim(Result.Error);

    Result.ExitCode := Proc.ExitStatus;
  finally
    StreamErr.Free;
    StreamOut.Free;
    Proc.Free;
  end;
end;

function FetchDisks(OnBusy: TBusyCallback; out ErrorMsg: String): TDiskInfoArray;
var
  Res: TCommandResult;
begin
  Result := nil;
  ErrorMsg := '';
  Res := RunCommandWithBusyAnimation(
    'lsblk',
    ['-J', '-o', 'NAME,PATH,MODEL,SERIAL,HOTPLUG,RM,TYPE,MOUNTPOINTS,FSTYPE,UUID,SIZE,VENDOR,LABEL,REV'],
    'Querying disks (lsblk)...',
    OnBusy
  );

  if not Res.IsSuccess then
  begin
    if Res.Error <> '' then
      ErrorMsg := 'lsblk error: ' + Res.Error
    else
      ErrorMsg := 'lsblk error: ' + Res.Output;
    SetLength(Result, 0);
    Exit;
  end;

  Result := ParseLsblkJson(Res.Output);
end;

function RunUdisksctlAction(const Action, DevPath, DescPrefix: String; OnBusy: TBusyCallback): TCommandResult;
begin
  Result := RunCommandWithBusyAnimation(
    'udisksctl',
    [Action, '-b', DevPath, '--no-user-interaction'],
    DescPrefix + ' ' + DevPath + '...',
    OnBusy
  );
end;

function MountSinglePartition(const DevPath: String; OnBusy: TBusyCallback): TOperationResult;
var
  Res: TCommandResult;
  Err: String;
begin
  Res := RunUdisksctlAction('mount', DevPath, 'Mounting', OnBusy);
  if not Res.IsSuccess then
  begin
    if Res.Error <> '' then Err := Res.Error else Err := Res.Output;
    Result.Success := False;
    Result.Message := FormatOpError('mount', DevPath, Err);
    Exit;
  end;

  Result.Success := True;
  if Res.Output <> '' then
    Result.Message := Res.Output
  else
    Result.Message := 'Successfully mounted ' + DevPath + '.';
end;

function MountDiskPartitions(const Disk: TDiskInfo; OnBusy: TBusyCallback): TOperationResult;
var
  CandidatePaths, AlreadyMountedPaths: TStringArray;
  MountedList: TStringArray;
  DevPath, Err: String;
  Res: TCommandResult;
  i: Integer;
begin
  SetLength(CandidatePaths, 0);
  SetLength(AlreadyMountedPaths, 0);
  SetLength(MountedList, 0);

  CollectMountablePartitionsForDisk(Disk, CandidatePaths, AlreadyMountedPaths);

  if Length(CandidatePaths) = 0 then
  begin
    Result.Success := True;
    if Length(AlreadyMountedPaths) > 0 then
      Result.Message := 'All partitions on ' + Disk.Path + ' are already mounted.'
    else
      Result.Message := 'No mountable partitions found on ' + Disk.Path + '.';
    Exit;
  end;

  for i := 0 to High(CandidatePaths) do
  begin
    DevPath := CandidatePaths[i];
    Res := RunUdisksctlAction('mount', DevPath, 'Mounting', OnBusy);
    if not Res.IsSuccess then
    begin
      if Res.Error <> '' then Err := Res.Error else Err := Res.Output;
      Result.Success := False;
      Result.Message := FormatOpError('mount', DevPath, Err);
      Exit;
    end;
    StringArrayAddUnique(MountedList, DevPath);
  end;

  Result.Success := True;
  if Length(MountedList) = 1 then
    Result.Message := 'Successfully mounted ' + MountedList[0] + '.'
  else
    Result.Message := 'Successfully mounted ' + StringArrayJoin(MountedList, ', ') + '.';
end;

function UnmountAndLockPartition(
  const DevPath: String;
  const MountPaths, CryptLockPaths: TStringArray;
  OnBusy: TBusyCallback
): TOperationResult;
var
  i: Integer;
  MPath, CPath, Err: String;
  Res: TCommandResult;
begin
  if (Length(MountPaths) = 0) and (Length(CryptLockPaths) = 0) then
  begin
    Result.Success := True;
    Result.Message := 'Partition ' + DevPath + ' is not mounted or unlocked.';
    Exit;
  end;

  // 1. Unmount all mounted filesystems under this partition (depth-first: leaves first)
  for i := 0 to High(MountPaths) do
  begin
    MPath := MountPaths[i];
    Res := RunUdisksctlAction('unmount', MPath, 'Unmounting', OnBusy);
    if not Res.IsSuccess then
    begin
      if Res.Error <> '' then Err := Res.Error else Err := Res.Output;
      Result.Success := False;
      Result.Message := FormatOpError('unmount', MPath, Err);
      Exit;
    end;
  end;

  // 2. Lock all crypt mappings under this partition
  for i := 0 to High(CryptLockPaths) do
  begin
    CPath := CryptLockPaths[i];
    Res := RunUdisksctlAction('lock', CPath, 'Locking', OnBusy);
    if not Res.IsSuccess then
    begin
      if Res.Error <> '' then Err := Res.Error else Err := Res.Output;
      Result.Success := False;
      Result.Message := FormatOpError('lock', CPath, Err);
      Exit;
    end;
  end;

  Result.Success := True;
  Result.Message := 'Successfully unmounted ' + DevPath + '.';
end;

function UnmountAndLockDisk(const Disk: TDiskInfo; OnBusy: TBusyCallback): TOperationResult;
var
  i: Integer;
  MPath, CPath, Err: String;
  Res: TCommandResult;
begin
  // 1. Unmount all mounted partitions
  for i := 0 to High(Disk.MountPaths) do
  begin
    MPath := Disk.MountPaths[i];
    Res := RunUdisksctlAction('unmount', MPath, 'Unmounting', OnBusy);
    if not Res.IsSuccess then
    begin
      if Res.Error <> '' then Err := Res.Error else Err := Res.Output;
      Result.Success := False;
      Result.Message := FormatOpError('unmount', MPath, Err);
      Exit;
    end;
  end;

  // 2. Lock all crypt mappings
  for i := 0 to High(Disk.CryptLockPaths) do
  begin
    CPath := Disk.CryptLockPaths[i];
    Res := RunUdisksctlAction('lock', CPath, 'Locking', OnBusy);
    if not Res.IsSuccess then
    begin
      if Res.Error <> '' then Err := Res.Error else Err := Res.Output;
      Result.Success := False;
      Result.Message := FormatOpError('lock', CPath, Err);
      Exit;
    end;
  end;

  Result.Success := True;
  Result.Message := 'Unmounted and locked all partitions on ' + Disk.Path + '.';
end;

function PowerOffDiskDevice(const Disk: TDiskInfo; OnBusy: TBusyCallback): TOperationResult;
var
  UnmountRes: TOperationResult;
  Res: TCommandResult;
  Err: String;
begin
  // First unmount and lock if anything is mounted or unlocked
  if Disk.TotalMountedOrUnlocked > 0 then
  begin
    UnmountRes := UnmountAndLockDisk(Disk, OnBusy);
    if not UnmountRes.Success then
      Exit(UnmountRes);
  end;

  // Then power off
  Res := RunUdisksctlAction('power-off', Disk.Path, 'Powering off', OnBusy);
  if not Res.IsSuccess then
  begin
    if Res.Error <> '' then Err := Res.Error else Err := Res.Output;
    Result.Success := False;
    Result.Message := FormatOpError('power off', Disk.Path, Err);
    Exit;
  end;

  Result.Success := True;
  Result.Message := 'Successfully powered off ' + Disk.Path + '.';
end;

end.
