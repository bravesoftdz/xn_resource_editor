unit unitResourceAccelerator;

interface

uses
  Windows, Classes, SysUtils, Contnrs, Menus, unitResourceDetails;

type
  TAccelerator = packed record
    flags: word;
    code: word;
    id: word;
    padding: word;
  end;
  PAccelerator = ^TAccelerator;

  TAcceleratorResourceDetails = class (TResourceDetails)
  private
    FCount: Integer;
    function GetCount: Integer;
    function GetAccelerator(idx: Integer): TAccelerator;
    function GetAccelPointer (idx: Integer): PAccelerator;
  public
    constructor Create(AParent: TResourceModule; ALanguage: Integer; const AName, AType: WideString; ASize: Integer; AData: pointer); override;
    class function GetBaseType: WideString; override;

    procedure InitNew; override;
    function Add (flags, code, id: Integer): Integer;
    procedure Delete(idx: Integer);
    procedure SetAccelDetails (idx: Integer; flags, code, id: Integer);

    property Count: Integer read GetCount;
    property Accelerator [idx: Integer]: TAccelerator read GetAccelerator;
  end;

implementation

{ TAcceleratorResourceDetails }

function TAcceleratorResourceDetails.Add(flags, code, id: Integer): Integer;
var
  ct: Integer;
  p: PAccelerator;
begin
  ct := Count;
  Data.Size := Data.Size + SizeOf(TAccelerator);
  Inc(FCount);
  p := GetAccelPointer (ct);
  p^.flags := flags or $80;
  p^.code := code;
  p^.id := id;
  p^.padding := 0;

  if Count > 1 then
  begin
    p := GetAccelPointer (Count - 2);
    p^.flags := p^.flags and not $80
  end;
  Result := ct;
end;

constructor TAcceleratorResourceDetails.Create(AParent: TResourceModule;
  ALanguage: Integer; const AName, AType: WideString; ASize: Integer;
  AData: pointer);
begin
  inherited Create(AParent, ALanguage, AName, AType, ASize, AData);

  FCount := -1;
end;

procedure TAcceleratorResourceDetails.Delete(idx: Integer);
var
  p, p1: PAccelerator;
begin
  if idx >= Count then Exit;

  if idx < Count - 1 then
  begin
    p := GetAccelPointer (idx);
    p1 := GetAccelPointer (idx + 1);
    Move(p1^, p^, SizeOf(TAccelerator) * (Count - idx - 1));
  end;

  Dec(FCount);
  Data.Size := Data.Size - SizeOf(TAccelerator);

  if Count > 0 then
  begin
    p := GetAccelPointer (Count - 1);
    p^.flags := p^.flags or $80
  end
end;

function TAcceleratorResourceDetails.GetAccelerator(
  idx: Integer): TAccelerator;
begin
  Result := GetAccelPointer (idx)^
end;

function TAcceleratorResourceDetails.GetAccelPointer(
  idx: Integer): PAccelerator;
begin
  if idx < Count then
  begin
    Result := PAccelerator (Data.Memory);
    Inc(Result, idx)
  end
  else
    raise ERangeError.Create('Index out of bounds');
end;

class function TAcceleratorResourceDetails.GetBaseType: WideString;
begin
  Result := IntToStr (Integer (RT_ACCELERATOR));
end;

function TAcceleratorResourceDetails.GetCount: Integer;
var
  p: PAccelerator;
  sz: Integer;
begin
  if FCount = -1 then
  begin
    p := PAccelerator (Data.Memory);
    FCount := 0;
    sz := 0;
    while sz + SizeOf(TAccelerator) <= Data.Size do
    begin
      Inc(FCount);
      if (p^.flags and $80) <> 0 then
        Break;
      Inc(p);
      Inc(sz, SizeOf(TAccelerator))
    end
  end;
  Result := FCount;
end;

procedure TAcceleratorResourceDetails.InitNew;
begin
  inherited;
end;


procedure TAcceleratorResourceDetails.SetAccelDetails(idx, flags, code,
  id: Integer);
var
  p: PAccelerator;
begin
  p := GetAccelPointer (idx);
  if p <> Nil then
  begin
    if idx = Count - 1 then
      flags := flags or $80;
    p^.flags := flags;
    p^.id := id;
    p^.code := code
  end
end;

initialization
  RegisterResourceDetails(TAcceleratorResourceDetails);
finalization
  UnregisterResourceDetails(TAcceleratorResourceDetails);
end.
