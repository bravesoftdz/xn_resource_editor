unit unitVersionInfo;

interface

uses
  Windows, Classes, SysUtils;

type
  TVersionInfo = class
    FModule: THandle;
    FVersionInfo: PChar;
    FVersionHeader: PChar;
    FChildStrings: TStringList;
    FTranslations: TList;
    FFixedInfo: PVSFixedFileInfo;
    FVersionResHandle: THandle;
    FModuleLoaded: Boolean;
  private
    function GetInfo: Boolean;
    function GetKeyCount: Integer;
    function GetKeyName(idx: Integer): string;
    function GetKeyValue(const idx: string): string;
    procedure SetKeyValue(const idx, Value: string);
  public
    constructor Create(AModule: THandle); overload;
    constructor Create(AVersionInfo: PChar); overload;
    constructor Create(const AFileName: string); overload;
    destructor Destroy; override;
    procedure SaveToStream (strm: TStream);

    property KeyCount: Integer read GetKeyCount;
    property KeyName [idx: Integer]: string read GetKeyName;
    property KeyValue [const idx: string]: string read GetKeyValue write SetKeyValue;
  end;

implementation

{ TVersionInfo }

type
  TVersionStringValue = class
    FValue: string;
    FLangID, FCodePage: Integer;

    constructor Create(const AValue: string; ALangID, ACodePage: Integer);
  end;

constructor TVersionInfo.Create(AModule: THandle);
var
  resHandle: THandle;
begin
  FModule := AModule;
  FChildStrings := TStringList.Create;
  FTranslations := TList.Create;
  resHandle := FindResource(FModule, pointer (1), RT_VERSION);
  if resHandle <> 0 then
  begin
    FVersionResHandle := LoadResource(FModule, resHandle);
    if FVersionResHandle <> 0 then
      FVersionInfo := LockResource(FVersionResHandle)
  end;

  if not Assigned(FVersionInfo) then
    raise Exception.Create('Unable to load version info resource');
end;

constructor TVersionInfo.Create(AVersionInfo: PChar);
begin
  FChildStrings := TStringList.Create;
  FTranslations := TList.Create;
  FVersionInfo := AVersionInfo;
end;

constructor TVersionInfo.Create(const AFileName: string);
var
  handle: THandle;
begin
  handle := LoadLibraryEx (PChar (AFileName), 0, LOAD_LIBRARY_AS_DATAFILE);
  if handle <> 0 then
  begin
    Create(handle);
    FModuleLoaded := True
  end
  else
    raiseLastOSError;
end;

destructor TVersionInfo.Destroy;
var
  i: Integer;
begin
  for i := 0 to FChildStrings.Count - 1 do
    FChildStrings.Objects[i].Free;

  FChildStrings.Free;
  FTranslations.Free;
  if FVersionResHandle <> 0 then
    FreeResource(FVersionResHandle);
  if FModuleLoaded then
    FreeLibrary(FModule);
  inherited;
end;

function TVersionInfo.GetInfo: Boolean;
var
  p: PChar;
  t, wLength, wValueLength, wType: word;
  Key: string;

  varwLength, varwValueLength, varwType: word;
  varKey: string;

  function GetVersionHeader (var p: PChar; var wLength, wValueLength, wType: word; var Key: string): Integer;
  var
    SzKey: PWideChar;
    BaseP: PChar;
  begin
    BaseP := p;
    wLength := PWord (p)^;
    Inc(p, SizeOf(word));
    wValueLength := PWord (p)^;
    Inc(p, SizeOf(word));
    wType := PWord (p)^;
    Inc(p, SizeOf(word));
    SzKey := PWideChar (p);
    Inc(p, (lstrlenw (SzKey) + 1) * SizeOf(WideChar));
    while Integer (p) mod 4 <> 0 do
      Inc(p);
    Result := p - BaseP;
    Key := SzKey;
  end;

  procedure GetStringChildren (var base: PChar; len: word);
  var
    p, strBase: PChar;
    t, wLength, wValueLength, wType, wStrLength, wStrValueLength, wStrType: word;
    Key, value: string;
    i, langID, codePage: Integer;

  begin
    p := base;
    while(p - base) < len do
    begin
      t := GetVersionHeader (p, wLength, wValueLength, wType, Key);
      Dec(wLength, t);

      langID := StrToInt('$' + Copy(Key, 1, 4));
      codePage := StrToInt('$' + Copy(Key, 5, 4));

      strBase := p;
      for i := 0 to FChildStrings.Count - 1 do
        FChildStrings.Objects[i].Free;
      FChildStrings.Clear;

      while(p - strBase) < wLength do
      begin
        t := GetVersionHeader (p, wStrLength, wStrValueLength, wStrType, Key);
        Dec(wStrLength, t);

        if wStrValueLength = 0 then
          value := ''
        else
          value := PWideChar (p);
        Inc(p, wStrLength);
        while Integer (p) mod 4 <> 0 do
          Inc(p);

        FChildStrings.AddObject(Key, TVersionStringValue.Create(value, langID, codePage))
      end
    end;
    base := p
  end;

  procedure GetVarChildren (var base: PChar; len: word);
  var
    p, strBase: PChar;
    t, wLength, wValueLength, wType: word;
    Key: string;
    v: DWORD;

  begin
    p := base;
    while(p - base) < len do
    begin
      t := GetVersionHeader (p, wLength, wValueLength, wType, Key);
      Dec(wLength, t);

      strBase := p;
      FTranslations.Clear;

      while(p - strBase) < wLength do
      begin
        v := PDWORD (p)^;
        Inc(p, SizeOf(DWORD));
        FTranslations.Add (pointer (v));
      end
    end;
    base := p
  end;

begin
  Result := False;
  if not Assigned(FFixedInfo) then
  try
    p := FVersionInfo;
    GetVersionHeader (p, wLength, wValueLength, wType, Key);

    if wValueLength <> 0 then
    begin
      FFixedInfo := PVSFixedFileInfo (p);
      if FFixedInfo^.dwSignature <> $feef04bd then
        raise Exception.Create('Invalid version resource');

      Inc(p, wValueLength);
      while Integer (p) mod 4 <> 0 do
        Inc(p);
    end
    else
      FFixedInfo := nil;

    while wLength > (p - FVersionInfo) do
    begin
      t := GetVersionHeader (p, varwLength, varwValueLength, varwType, varKey);
      Dec(varwLength, t);

      if varKey = 'StringFileInfo' then
        GetStringChildren (p, varwLength)
      else
        if varKey = 'VarFileInfo' then
          GetVarChildren (p, varwLength)
        else
          break;
    end;

    Result := True;
  except
  end
  else
    Result := True
end;

function TVersionInfo.GetKeyCount: Integer;
begin
  if GetInfo then
    Result := FChildStrings.Count
  else
    Result := 0;
end;

function TVersionInfo.GetKeyName(idx: Integer): string;
begin
  if idx >= KeyCount then
    raise ERangeError.Create('Index out of range')
  else
    Result := FChildStrings[idx];
end;

function TVersionInfo.GetKeyValue(const idx: string): string;
var
  i: Integer;
begin
  if GetInfo then
  begin
    i := FChildStrings.IndexOf (idx);
    if i <> -1 then
      Result := TVersionStringValue(FChildStrings.Objects[i]).FValue
    else
      raise Exception.Create('Key not found')
  end
  else
    raise Exception.Create('Key not found')
end;

procedure TVersionInfo.SaveToStream(strm: TStream);
var
  zeros, v: DWORD;
  wSize: WORD;
  stringInfoStream: TMemoryStream;
  strg: TVersionStringValue;
  i, p, p1: Integer;
  wValue: WideString;

  procedure PadStream (strm: TStream);
  begin
    if strm.Position mod 4 <> 0 then
      strm.Write(zeros, 4 - (strm.Position mod 4))
  end;

  procedure SaveVersionHeader (strm: TStream; wLength, wValueLength, wType: word; const Key: string; const value);
  var
    wKey: WideString;
    valueLen: word;
    keyLen: word;
  begin
    wKey := Key;
    strm.Write(wLength, SizeOf(wLength));

    strm.Write(wValueLength, SizeOf(wValueLength));
    strm.Write(wType, SizeOf(wType));
    keyLen := (Length(wKey) + 1) * SizeOf(WideChar);
    strm.Write(wKey [1], keyLen);

    PadStream (strm);

    if wValueLength > 0 then
    begin
      valueLen := wValueLength;
      if wType = 1 then
        valueLen := valueLen * SizeOf(WideChar);
      strm.Write(value, valueLen)
    end;
  end;

begin { SaveToStream }
  if GetInfo then
  begin
    zeros := 0;

    SaveVersionHeader (strm, 0, SizeOf(FFixedInfo^), 0, 'VS_VERSION_INFO', FFixedInfo^);

    if FChildStrings.Count > 0 then
    begin
      stringInfoStream := TMemoryStream.Create;
      try
        strg := TVersionStringValue(FChildStrings.Objects[0]);

        SaveVersionHeader (stringInfoStream, 0, 0, 0, IntToHex (strg.FLangID, 4) + IntToHex (strg.FCodePage, 4), zeros);

        for i := 0 to FChildStrings.Count - 1 do
        begin
          PadStream (stringInfoStream);

          p := stringInfoStream.Position;
          strg := TVersionStringValue(FChildStrings.Objects[i]);
          wValue := strg.FValue;
          SaveVersionHeader (stringInfoStream, 0, Length(strg.FValue) + 1, 1, FChildStrings[i], wValue [1]);
          wSize := stringInfoStream.Size - p;
          stringInfoStream.Seek(p, soFromBeginning);
          stringInfoStream.Write(wSize, SizeOf(wSize));
          stringInfoStream.Seek(0, soFromEnd);

        end;

        stringInfoStream.Seek(0, soFromBeginning);
        wSize := stringInfoStream.Size;
        stringInfoStream.Write(wSize, SizeOf(wSize));

        PadStream (strm);
        p := strm.Position;
        SaveVersionHeader (strm, 0, 0, 0, 'StringFileInfo', zeros);
        strm.Write(stringInfoStream.Memory^, stringInfoStream.size);
        wSize := strm.Size - p;
      finally
        stringInfoStream.Free
      end;
      strm.Seek(p, soFromBeginning);
      strm.Write(wSize, SizeOf(wSize));
      strm.Seek(0, soFromEnd)
    end;

    if FTranslations.Count > 0 then
    begin
      PadStream (strm);
      p := strm.Position;
      SaveVersionHeader (strm, 0, 0, 0, 'VarFileInfo', zeros);
      PadStream (strm);

      p1 := strm.Position;
      SaveVersionHeader (strm, 0, 0, 0, 'Translation', zeros);

      for i := 0 to FTranslations.Count - 1 do
      begin
        v := Integer (FTranslations[i]);
        strm.Write(v, SizeOf(v))
      end;

      wSize := strm.Size - p1;
      strm.Seek(p1, soFromBeginning);
      strm.Write(wSize, SizeOf(wSize));
      wSize := SizeOf(Integer) * FTranslations.Count;
      strm.Write(wSize, SizeOf(wSize));

      wSize := strm.Size - p;
      strm.Seek(p, soFromBeginning);
      strm.Write(wSize, SizeOf(wSize));
    end;

    strm.Seek(0, soFromBeginning);
    wSize := strm.Size;
    strm.Write(wSize, SizeOf(wSize));
    strm.Seek(0, soFromEnd);
  end
  else
    raise Exception.Create('Invalid version resource');
end;

procedure TVersionInfo.SetKeyValue(const idx, Value: string);
var
  i: Integer;
begin
  if GetInfo then
  begin
    i := FChildStrings.IndexOf (idx);
    if i = -1 then
      i := FChildStrings.AddObject(idx, TVersionStringValue.Create(idx, 0, 0));

    TVersionStringValue(FChildStrings.Objects[i]).FValue := Value
  end
  else
    raise Exception.Create('Invalid version resource');
end;

{ TVersionStringValue }

constructor TVersionStringValue.Create(const AValue: string; ALangID,
  ACodePage: Integer);
begin
  FValue := AValue;
  FCodePage := ACodePage;
  FLangID := ALangID;
end;

end.
