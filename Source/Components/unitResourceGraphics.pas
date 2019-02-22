(*======================================================================*
 | unitResourceGraphics                                                 |
 |                                                                      |
 | Encapsulates graphics in resources (icon, cursor, bitmap)            |
 |                                                                      |
 | Version  Date        By    Description                               |
 | -------  ----------  ----  ------------------------------------------|
 | 1.0      05/01/2001  CPWW  Original                                  |
 *======================================================================*)

unit unitResourceGraphics;

interface

uses
  Windows, Classes, SysUtils, Graphics, unitResourceDetails, unitExIcon,
  GIFImage;

type

//------------------------------------------------------------------------
// Base class

  TGraphicsResourceDetails = class (TResourceDetails)
  protected
    function GetHeight: Integer; virtual; abstract;
    function GetPixelFormat: TPixelFormat; virtual; abstract;
    function GetWidth: Integer; virtual; abstract;
  public
    procedure GetImage(picture: TPicture); virtual; abstract;
    procedure SetImage(image: TPicture); virtual;

    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property PixelFormat: TPixelFormat read GetPixelFormat;
  end;

  TGraphicsResourceDetailsClass = class of TGraphicsResourceDetails;

//------------------------------------------------------------------------
// Bitmap resource Details class

  TBitmapResourceDetails = class (TGraphicsResourceDetails)
  protected
    function GetHeight: Integer; override;
    function GetPixelFormat: TPixelFormat; override;
    function GetWidth: Integer; override;
    procedure InitNew; override;
    procedure InternalGetImage(s: TStream; picture: TPicture);
    procedure InternalSetImage(s: TStream; image: TPicture);

  public
    class function GetBaseType: WideString; override;
    procedure GetImage(picture: TPicture); override;
    procedure SetImage(image: TPicture); override;
    procedure LoadImage(const FileName: string);
  end;

//------------------------------------------------------------------------
// DIB resource Details class
//
// Same as RT_BITMAP resources, but they have a TBitmapFileHeader at the start
// of the resource, before the TBitmapInfoHeader.  See
// \program files\Microsoft Office\office\1033\outlibr.dll

  TDIBResourceDetails = class (TBitmapResourceDetails)
  protected
    class function SupportsData(Size: Integer; Data: Pointer): Boolean; override;
    procedure InitNew; override;
  public
    class function GetBaseType: WideString; override;
    procedure GetImage(picture: TPicture); override;
    procedure SetImage(image: TPicture); override;
  end;

  TIconCursorResourceDetails = class;

//------------------------------------------------------------------------
// Icon / Cursor group resource Details class

  TIconCursorGroupResourceDetails = class (TResourceDetails)
  private
    FDeleting: Boolean;
    function GetResourceCount: Integer;
    function GetResourceDetails(idx: Integer): TIconCursorResourceDetails;
  protected
    procedure InitNew; override;
  public
    procedure GetImage(picture: TPicture);
    property ResourceCount: Integer read GetResourceCount;
    property ResourceDetails[idx: Integer]: TIconCursorResourceDetails read GetResourceDetails;
    function Contains (Details: TIconCursorResourceDetails): Boolean;
    procedure RemoveFromGroup (Details: TIconCursorResourceDetails);
    procedure AddToGroup (Details: TIconCursorResourceDetails);
    procedure LoadImage(const FileName: string);
    procedure BeforeDelete; override;
  end;

//------------------------------------------------------------------------
// Icon group resource Details class

  TIconGroupResourceDetails = class (TIconCursorGroupResourceDetails)
  public
    class function GetBaseType: WideString; override;
  end;

//------------------------------------------------------------------------
// Cursor group resource Details class

  TCursorGroupResourceDetails = class (TIconCursorGroupResourceDetails)
  public
    class function GetBaseType: WideString; override;
  end;

//------------------------------------------------------------------------
// Icon / Cursor resource Details class

  TIconCursorResourceDetails = class (TGraphicsResourceDetails)
  protected
    function GetHeight: Integer; override;
    function GetPixelFormat: TPixelFormat; override;
    function GetWidth: Integer; override;
  protected
    procedure InitNew; override;
  public
    procedure BeforeDelete; override;
    procedure GetImage(picture: TPicture); override;
    procedure SetImage(image: TPicture); override;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property PixelFormat: TPixelFormat read GetPixelFormat;
  end;

//------------------------------------------------------------------------
// Icon resource Details class

  TIconResourceDetails = class (TIconCursorResourceDetails)
  public
    class function GetBaseType: WideString; override;
  end;

//------------------------------------------------------------------------
// Cursor resource Details class

  TCursorResourceDetails = class (TIconCursorResourceDetails)
  protected
  public
    class function GetBaseType: WideString; override;
  end;

const
  DefaultIconCursorWidth: Integer = 32;
  DefaultIconCursorHeight: Integer = 32;
  DefaultIconCursorPixelFormat: TPixelFormat = pf4Bit;
  DefaultCursorHotspot: DWord = $00100010;

  DefaultBitmapWidth: Integer = 128;
  DefaultBitmapHeight: Integer = 96;
  DefaultBitmapPixelFormat: TPixelFormat = pf24Bit;

implementation

type
  TResourceDirectory = packed record
    Details: packed record case Boolean of
      False: (CursorWidth, cursorHeight: word);
      True: (IconWidth, IconHeight, IconColorCount, IconReserved: BYTE)
    end;
    wPlanes, wBitCount: word;
    lBytesInRes: DWORD;
    wNameOrdinal: word
  end;
  PResourceDirectory = ^TResourceDirectory;

resourcestring
  rstCursors = 'Cursors';
  rstIcons = 'Icons';

{ TBitmapResourceDetails }

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.GetBaseType                                   |
 *----------------------------------------------------------------------*)
class function TBitmapResourceDetails.GetBaseType: WideString;
begin
  Result := IntToStr (Integer (RT_BITMAP));
end;

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.GetHeight                                     |
 *----------------------------------------------------------------------*)
function TBitmapResourceDetails.GetHeight: Integer;
begin
  Result := PBitmapInfoHeader (Data.Memory)^.biHeight
end;

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.GetImage                                      |
 *----------------------------------------------------------------------*)
procedure TBitmapResourceDetails.GetImage(picture: TPicture);
var
  s: TMemoryStream;
  hdr: TBitmapFileHeader;
begin
  s := TMemoryStream.Create;
  try
    hdr.bfType :=$4D42;         // TBitmap.LoadFromStream requires a bitmapfileheader
    hdr.bfSize := Data.size;    // before the Data...
    hdr.bfReserved1 := 0;
    hdr.bfReserved2 := 0;
    hdr.bfOffBits := SizeOf(hdr);

    s.Write(hdr, SizeOf(hdr));
    Data.Seek(0, soFromBeginning);
    s.CopyFrom (Data, Data.size);

    InternalGetImage(s, picture)
  finally
    s.Free
  end
end;

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.GetPixelFormat                                |
 *----------------------------------------------------------------------*)
function TBitmapResourceDetails.GetPixelFormat: TPixelFormat;
begin
  Result := GetBitmapInfoPixelFormat(PBitmapInfoHeader (Data.Memory)^);
end;

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.GetWidth                                      |
 *----------------------------------------------------------------------*)
function TBitmapResourceDetails.GetWidth: Integer;
begin
  Result := PBitmapInfoHeader (Data.Memory)^.biWidth
end;

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.SetImage                                      |
 *----------------------------------------------------------------------*)
procedure TBitmapResourceDetails.InitNew;
var
  bi: TBitmapInfoHeader;
  imageSize: DWORD;
  bits: PChar;
begin
  bi.biSize := SizeOf(bi);
  bi.biWidth := DefaultBitmapWidth;
  bi.biHeight := DefaultBitmapHeight;
  bi.biPlanes := 1;
  bi.biBitCount := GetPixelFormatBitCount(DefaultBitmapPixelFormat);
  bi.biCompression := BI_RGB;

  imageSize := BytesPerScanLine(DefaultBitmapWidth, bi.biBitCount, 32) * DefaultBitmapHeight;
  bi.biSizeImage := imageSize;

  bi.biXPelsPerMeter := 0;
  bi.biYPelsPerMeter := 0;

  bi.biClrUsed := 0;
  bi.biClrImportant := 0;

  Data.Write(bi, SizeOf(bi));

  bits := AllocMem (ImageSize);
  try
    Data.Write(bits^, ImageSize);
  finally
    ReallocMem (bits, 0)
  end
end;

procedure TBitmapResourceDetails.InternalGetImage(s: TStream; picture: TPicture);
var
  pHdr: PBitmapInfoHeader;
  pal: HPalette;
  colors: DWORD;
  hangOnToPalette: Boolean;
  newBmp: TBitmap;
begin
  s.Seek(0, soFromBeginning);
  picture.Bitmap.IgnorePalette := False;
  picture.Bitmap.LoadFromStream (s);

  pHdr := PBitmapInfoHeader (Data.Memory);

                              // TBitmap makes all RLE encoded bitmaps into pfDevice
                              // ... that's not good enough for us!  At least
                              // select the correct pixel format, preserve their carefully set
                              // up palette, etc.
                              //
                              // But revisit this - we probably shouldn't call LoadFromStream
                              // at all if this is the case...
                              //
                              // You can get a couple of RLE bitmaps out of winhlp32.exe

  if PHdr^.biCompression in [BI_RLE4, BI_RLE8] then
  begin
    hangOnToPalette := False;
    if pHdr^.biBitCount in [1, 4, 8] then
    begin
      pal := picture.Bitmap.Palette;
      if pal <> 0 then
      begin
        colors := 0;
        GetObject(pal, SizeOf(colors), @Colors);

        if colors = 1 shl pHdr^.biBitCount then
        begin
          hangOnToPalette := True;

          newBmp := TBitmap.Create;
          try
            case pHdr^.biBitCount of
              1: newBmp.PixelFormat := pf1Bit;
              4: newBmp.PixelFormat := pf4Bit;
              8: newBmp.PixelFormat := pf8Bit;
            end;

            newBmp.Width := Picture.Bitmap.Width;
            newBmp.Height := Picture.Bitmap.Height;
            newBmp.Palette := CopyPalette(pal);
            newBmp.Canvas.Draw (0, 0, picture.Bitmap);
            picture.Bitmap.Assign (newBmp);
          finally
            newBmp.Free
          end
        end
      end
    end;

    if not hangOnToPalette then
      case pHdr^.biBitCount of
        1: picture.Bitmap.PixelFormat := pf1Bit;
        4: picture.Bitmap.PixelFormat := pf4Bit;
        8: picture.Bitmap.PixelFormat := pf8Bit;
        else
          picture.Bitmap.PixelFormat := pf24Bit
      end
  end
end;

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.InternalSetImage                              |
 |                                                                      |
 | Save image 'image' to stream 's' as a bitmap                         |
 |                                                                      |
 | Parameters:                                                          |
 |                                                                      |
 |   s: TStream           The stream to save to                        |
 |   image: TPicture      The image to save                            |
 *----------------------------------------------------------------------*)
procedure TBitmapResourceDetails.InternalSetImage(s: TStream; image: TPicture);
var
  bmp: TBitmap;
begin
  s.Size := 0;
  bmp := TBitmap.Create;
  try
    bmp.Assign (image.graphic);
    bmp.SaveToStream (s);
  finally
    bmp.Free;
  end
end;

(*----------------------------------------------------------------------*
 | TBitmapResourceDetails.SetImage                                      |
 *----------------------------------------------------------------------*)
procedure TBitmapResourceDetails.LoadImage(const FileName: string);
var
  s: TMemoryStream;
begin
  s := TMemoryStream.Create;
  try
    s.LoadFromFile(FileName);
    Data.Clear;
    Data.Write((PChar (s.Memory) + SizeOf(TBitmapFileHeader))^, s.Size - SizeOf(TBitmapFileHeader));
  finally
    s.Free;
  end
end;

procedure TBitmapResourceDetails.SetImage(image: TPicture);
var
  s: TMemoryStream;
begin
  s := TMemoryStream.Create;
  try
    InternalSetImage(s, image);
    Data.Clear;
    Data.Write((PChar (s.Memory) + SizeOf(TBitmapFileHeader))^, s.Size - SizeOf(TBitmapFileHeader));
  finally
    s.Free;
  end
end;

{ TIconGroupResourceDetails }

(*----------------------------------------------------------------------*
 | TIconGroupResourceDetails.GetBaseType                                |
 *----------------------------------------------------------------------*)
class function TIconGroupResourceDetails.GetBaseType: WideString;
begin
  Result := IntToStr (Integer (RT_GROUP_ICON));
end;

{ TCursorGroupResourceDetails }

(*----------------------------------------------------------------------*
 | TCursorGroupResourceDetails.GetBaseType                              |
 *----------------------------------------------------------------------*)
class function TCursorGroupResourceDetails.GetBaseType: WideString;
begin
  Result := IntToStr (Integer (RT_GROUP_CURSOR));
end;

{ TIconResourceDetails }

(*----------------------------------------------------------------------*
 | TIconResourceDetails.GetBaseType                                     |
 *----------------------------------------------------------------------*)
class function TIconResourceDetails.GetBaseType: WideString;
begin
  Result := IntToStr (Integer (RT_ICON));
end;

{ TCursorResourceDetails }

(*----------------------------------------------------------------------*
 | TCursorResourceDetails.GetBaseType                                   |
 *----------------------------------------------------------------------*)
class function TCursorResourceDetails.GetBaseType: WideString;
begin
  Result := IntToStr (Integer (RT_CURSOR));
end;

{ TGraphicsResourceDetails }


{ TIconCursorResourceDetails }

(*----------------------------------------------------------------------*
 | TIconCursorResourceDetails.GetHeight                                 |
 *----------------------------------------------------------------------*)
function TIconCursorResourceDetails.GetHeight: Integer;
var
  InfoHeader: PBitmapInfoHeader;
begin
  if Self is TCursorResourceDetails then        // Not very 'OOP'.  Sorry
    InfoHeader := PBitmapInfoHeader(PChar(Data.Memory) + SizeOf(DWORD))
  else
    InfoHeader := PBitmapInfoHeader(PChar(Data.Memory));

  Result := InfoHeader.biHeight div 2
end;

(*----------------------------------------------------------------------*
 | TIconCursorResourceDetails.GetImage                                  |
 *----------------------------------------------------------------------*)
procedure TIconCursorResourceDetails.GetImage(picture: TPicture);
var
  iconCursor: TExIconCursor;
  strm: TMemoryStream;
  hdr: TIconHeader;
  dirEntry: TIconDirEntry;
  InfoHeader: PBitmapInfoHeader;
begin
  if Data.Size = 0 then Exit;

  strm := nil;
  if Self is TCursorResourceDetails then
  begin
    hdr.wType := 2;
    InfoHeader := PBitmapInfoHeader (PChar (Data.Memory) + SizeOf(DWORD));
    iconCursor := TExCursor.Create
  end
  else
  begin
    hdr.wType := 1;
    InfoHeader := PBitmapInfoHeader (PChar (Data.Memory));
    iconCursor := TExIcon.Create
  end;

  try
    strm := TMemoryStream.Create;
    hdr.wReserved := 0;
    hdr.wCount := 1;

    strm.Write(hdr, SizeOf(hdr));

    dirEntry.bWidth := InfoHeader^.biWidth;
    dirEntry.bHeight := InfoHeader^.biHeight div 2;
    dirEntry.bColorCount := GetBitmapInfoNumColors (InfoHeader^);
    dirEntry.bReserved := 0;

    dirEntry.wPlanes := InfoHeader^.biPlanes;
    dirEntry.wBitCount := InfoHeader^.biBitCount;

    dirEntry.dwBytesInRes := Data.Size;
    dirEntry.dwImageOffset := SizeOf(hdr) + SizeOf(dirEntry);

    strm.Write(dirEntry, SizeOf(dirEntry));
    strm.CopyFrom (Data, 0);
    strm.Seek(0, soFromBeginning);

    iconcursor.LoadFromStream (strm);
    picture.Graphic := iconcursor
  finally
    strm.Free;
    iconcursor.Free
  end
end;

(*----------------------------------------------------------------------*
 | TIconCursorResourceDetails.SetImage                                  |
 *----------------------------------------------------------------------*)
procedure TIconCursorResourceDetails.SetImage(image: TPicture);
var
  icon: TExIconCursor;
begin
  icon := TExIconCursor (image.graphic);
  Data.Clear;
  Data.CopyFrom (icon.Images[icon.CurrentImage].MemoryImage, 0);
end;


(*----------------------------------------------------------------------*
 | TIconCursorResourceDetails.GetPixelFormat                            |
 *----------------------------------------------------------------------*)
function TIconCursorResourceDetails.GetPixelFormat: TPixelFormat;
var
  InfoHeader: PBitmapInfoHeader;
begin
  if Self is TCursorResourceDetails then
    InfoHeader := PBitmapInfoHeader (PChar (Data.Memory) + SizeOf(DWORD))
  else
    InfoHeader := PBitmapInfoHeader (PChar (Data.Memory));

  Result := GetBitmapInfoPixelFormat(InfoHeader^);
end;

(*----------------------------------------------------------------------*
 | TIconCursorResourceDetails.GetWidth                                  |
 *----------------------------------------------------------------------*)
function TIconCursorResourceDetails.GetWidth: Integer;
var
  InfoHeader: PBitmapInfoHeader;
begin
  if Self is TCursorResourceDetails then
    InfoHeader := PBitmapInfoHeader (PChar (Data.Memory) + SizeOf(DWORD))
  else
    InfoHeader := PBitmapInfoHeader (PChar (Data.Memory));

  Result := InfoHeader.biWidth
end;

{ TIconCursorGroupResourceDetails }

(*----------------------------------------------------------------------*
 | TIconCursorGroupResourceDetails.BeforeDelete
 |                                                                      |
 *----------------------------------------------------------------------*)
procedure TIconCursorGroupResourceDetails.AddToGroup(
  Details: TIconCursorResourceDetails);
var
  attributes: PResourceDirectory;
  InfoHeader: PBitmapInfoHeader;
  cc: Integer;
begin
  Data.Size := Data.Size + SizeOf(TResourceDirectory);
  attributes := PResourceDirectory(PChar (Data.Memory) + SizeOf(TIconHeader));

  Inc(Attributes, PIconHeader (Data.Memory)^.wCount);

  attributes^.wNameOrdinal :=  StrToInt(Details.ResourceName);
  attributes^.lBytesInRes := Details.Data.Size;

  if Details is TIconResourceDetails then
  begin
    InfoHeader := PBitmapInfoHeader (PChar (Details.Data.Memory));
    attributes^.Details.IconWidth := InfoHeader^.biWidth;
    attributes^.Details.IconHeight := InfoHeader^.biHeight div 2;
    cc := GetBitmapInfoNumColors (InfoHeader^);
    if cc < 256 then
      attributes^.Details.IconColorCount := cc
    else
      attributes^.Details.IconColorCount := 0;
    attributes^.Details.IconReserved := 0
  end
  else
  begin
    InfoHeader := PBitmapInfoHeader (PChar (Details.Data.Memory) + SizeOf(DWORD));
    attributes^.Details.CursorWidth := InfoHeader^.biWidth;
    attributes^.Details.cursorHeight := InfoHeader^.biHeight div 2
  end;

  attributes^.wPlanes := InfoHeader^.biPlanes;
  attributes^.wBitCount := InfoHeader^.biBitCount;

  Inc(PIconHeader (Data.Memory)^.wCount);
end;

procedure TIconCursorGroupResourceDetails.BeforeDelete;
begin
  FDeleting := True;
  try
    while ResourceCount > 0 do
      Parent.DeleteResource(Parent.IndexOfResource(ResourceDetails[0]));
  finally
    FDeleting := False
  end
end;

(*----------------------------------------------------------------------*
 | TIconCursorGroupResourceDetails.Contains                             |
 *----------------------------------------------------------------------*)
function TIconCursorGroupResourceDetails.Contains(
  Details: TIconCursorResourceDetails): Boolean;
var
  i, id: Integer;
  attributes: PResourceDirectory;
begin
  Result := False;
  if ResourceNameToInt(Details.ResourceType) = ResourceNameToInt(ResourceType) - DIFFERENCE then
  begin
    attributes := PResourceDirectory(PChar (Data.Memory) + SizeOf(TIconHeader));
    id := ResourceNameToInt(Details.ResourceName);

    for i := 0 to PIconHeader (Data.Memory)^.wCount - 1 do
      if attributes^.wNameOrdinal = id then
      begin
        Result := True;
        break
      end
      else
        Inc(attributes)
  end
end;

(*----------------------------------------------------------------------*
 | TIconCursorGroupResourceDetails.GetImage                             |
 *----------------------------------------------------------------------*)
procedure TIconCursorGroupResourceDetails.GetImage(picture: TPicture);
var
  i, hdrOffset, imgOffset: Integer;
  iconCursor: TExIconCursor;
  strm: TMemoryStream;
  hdr: TIconHeader;
  dirEntry: TIconDirEntry;
  pdirEntry: PIconDirEntry;
  InfoHeader: PBitmapInfoHeader;
begin
  if Data.Size = 0 then Exit;

  strm := nil;
  if Self is TCursorGroupResourceDetails then
  begin
    hdr.wType := 2;
    hdrOffset := SizeOf(DWORD);
    iconCursor := TExCursor.Create
  end
  else
  begin
    hdr.wType := 1;
    hdrOffset := 0;
    iconCursor := TExIcon.Create
  end;

  try
    strm := TMemoryStream.Create;
    hdr.wReserved := 0;
    hdr.wCount := ResourceCount;

    strm.Write(hdr, SizeOf(hdr));

    for i := 0 to ResourceCount - 1 do
    begin
      InfoHeader := PBitmapInfoHeader (PChar (ResourceDetails[i].Data.Memory) + hdrOffset);
      dirEntry.bWidth := InfoHeader^.biWidth;
      dirEntry.bHeight := InfoHeader^.biHeight div 2;
      dirEntry.wPlanes := InfoHeader^.biPlanes;
      dirEntry.bColorCount := GetBitmapInfoNumColors (InfoHeader^);
      dirEntry.bReserved := 0;
      dirEntry.wBitCount := InfoHeader^.biBitCount;
      dirEntry.dwBytesInRes := resourceDetails[i].Data.Size;
      dirEntry.dwImageOffset := 0;

      strm.Write(dirEntry, SizeOf(dirEntry));
    end;

    for i := 0 to ResourceCount - 1 do
    begin
      imgOffset := strm.Position;
      pDirEntry := PIconDirEntry(PChar (strm.Memory) + SizeOf(TIconHeader) + i * SizeOf(TIconDirEntry));
      pDirEntry^.dwImageOffset := imgOffset;

      strm.CopyFrom (ResourceDetails[i].Data, 0);
    end;

    if ResourceCount > 0 then
    begin
      strm.Seek(0, soFromBeginning);
      iconcursor.LoadFromStream (strm);
      picture.Graphic := iconcursor
    end
    else
      picture.Graphic := Nil
  finally
    strm.Free;
    iconcursor.Free
  end
end;

(*----------------------------------------------------------------------*
 | TIconCursorGroupResourceDetails.GetResourceCount                     |
 *----------------------------------------------------------------------*)
function TIconCursorGroupResourceDetails.GetResourceCount: Integer;
begin
  Result := PIconHeader (Data.Memory)^.wCount
end;

(*----------------------------------------------------------------------*
 | TIconCursorGroupResourceDetails.GetResourceDetails                   |
 *----------------------------------------------------------------------*)
function TIconCursorGroupResourceDetails.GetResourceDetails(
  idx: Integer): TIconCursorResourceDetails;
var
  i: Integer;
  res: TResourceDetails;
  attributes: PResourceDirectory;
  iconCursorResourceType: string;
begin
  Result := nil;
  attributes := PResourceDirectory(PChar (Data.Memory) + SizeOf(TIconHeader));
  Inc(attributes, idx);

  // DIFFERENCE (from Windows.pas) is 11.  It's the difference between a 'group
  // resource' and the resource itself.  They called it 'DIFFERENCE' to be annoying.

  iconCursorResourceType := IntToStr (ResourceNameToInt(ResourceType) - DIFFERENCE);
  for i := 0 to Parent.ResourceCount - 1 do
  begin
    res := Parent.ResourceDetails[i];
    if (res is TIconCursorResourceDetails) and (iconCursorResourceType = res.ResourceType) and (attributes.wNameOrdinal = ResourceNameToInt(res.ResourceName)) then
    begin
      Result := TIconCursorResourceDetails (res);
      break
    end
  end
end;

(*----------------------------------------------------------------------*
 | TIconCursorGroupResourceDetails.InitNew                              |
 *----------------------------------------------------------------------*)
procedure TIconCursorGroupResourceDetails.InitNew;
var
  imageResource: TIconCursorResourceDetails;
  iconHeader: TIconHeader;
  dir: TResourceDirectory;
  nm: string;

begin
  iconHeader.wCount := 1;
  iconHeader.wReserved := 0;

  if Self is TCursorGroupResourceDetails then
  begin
    iconHeader.wType := 2;
    nm := Parent.GetUniqueResourceName(TCursorResourceDetails.GetBaseType);
    imageResource := TCursorResourceDetails.CreateNew (Parent, ResourceLanguage, nm)
  end
  else
  begin
    iconHeader.wType := 1;
    nm := Parent.GetUniqueResourceName(TIconResourceDetails.GetBaseType);
    imageResource := TIconResourceDetails.CreateNew (Parent, ResourceLanguage, nm)
  end;

  Data.Write(iconHeader, SizeOf(iconHeader));

  if Self is TIconGroupResourceDetails then
  begin
    dir.Details.IconWidth := DefaultIconCursorWidth;
    dir.Details.IconHeight := DefaultIconCursorHeight;
    dir.Details.IconColorCount := GetPixelFormatNumColors (DefaultIconCursorPixelFormat);
    dir.Details.IconReserved := 0
  end
  else
  begin
    dir.Details.CursorWidth := DefaultIconCursorWidth;
    dir.Details.cursorHeight := DefaultIconCursorHeight
  end;

  dir.wPlanes := 1;
  dir.wBitCount := GetPixelFormatBitCount(DefaultIconCursorPixelFormat);
  dir.lBytesInRes := imageResource.Data.Size;
  dir.wNameOrdinal := ResourceNametoInt(imageResource.ResourceName);

  Data.Write(dir, SizeOf(dir));
end;

(*----------------------------------------------------------------------*
 | TIconCursorResourceDetails.BeforeDelete                              |
 |                                                                      |
 | If we're deleting an icon/curor resource, remove its reference from  |
 | the icon/cursor group resource.                                      |
 *----------------------------------------------------------------------*)
procedure TIconCursorResourceDetails.BeforeDelete;
var
  i: Integer;
  Details: TResourceDetails;
  resGroup: TIconCursorGroupResourceDetails;
begin
  for i := 0 to Parent.ResourceCount - 1 do
  begin
    Details := Parent.ResourceDetails[i];
    if (Details.ResourceType = IntToStr (ResourceNameToInt(ResourceType) + DIFFERENCE)) then
    begin
      resGroup := Details as TIconCursorGroupResourceDetails;
      if resGroup.Contains (Self) then
      begin
        resGroup.RemoveFromGroup (Self);
        break
      end
    end
  end
end;

procedure TIconCursorGroupResourceDetails.LoadImage(
  const FileName: string);
var
  img: TExIconCursor;
  hdr: TIconHeader;
  i: Integer;
  dirEntry: TResourceDirectory;
  res: TIconCursorResourceDetails;
  resTp: string;
begin
  BeforeDelete;         // Make source there are no existing image resources

  if Self is TIconGroupResourceDetails then
  begin
    hdr.wType := 1;
    img := TExIcon.Create;
    resTp := TIconResourceDetails.GetBaseType;
  end
  else
  begin
    hdr.wType := 2;
    img := TExCursor.Create;
    resTp := TCursorResourceDetails.GetBaseType;
  end;

  img.LoadFromFile(FileName);

  hdr.wReserved := 0;
  hdr.wCount := img.ImageCount;

  Data.Clear;

  Data.Write(hdr, SizeOf(hdr));

  for i := 0 to img.ImageCount - 1 do
  begin
    if hdr.wType = 1 then
    begin
      dirEntry.Details.IconWidth := img.Images[i].FWidth;
      dirEntry.Details.IconHeight := img.Images[i].FHeight;
      dirEntry.Details.IconColorCount := GetPixelFormatNumColors (img.Images[i].FPixelFormat);
      dirEntry.Details.IconReserved := 0
    end
    else
    begin
      dirEntry.Details.CursorWidth := img.Images[i].FWidth;
      dirEntry.Details.cursorHeight := img.Images[i].FHeight;
    end;

    dirEntry.wPlanes := 1;
    dirEntry.wBitCount := GetPixelFormatBitCount(img.Images[i].FPixelFormat);

    dirEntry.lBytesInRes := img.Images[i].FMemoryImage.Size;

    if hdr.wType = 1 then
      res := TIconResourceDetails.Create(Parent, ResourceLanguage, Parent.GetUniqueResourceName(resTp), resTp, img.Images[i].FMemoryImage.Size, img.Images[i].FMemoryImage.Memory)
    else
      res := TCursorResourceDetails.Create(Parent, ResourceLanguage, Parent.GetUniqueResourceName(resTp), resTp, img.Images[i].FMemoryImage.Size, img.Images[i].FMemoryImage.Memory);
    Parent.AddResource(res);
    dirEntry.wNameOrdinal := ResourceNameToInt(res.ResourceName);

    Data.Write(dirEntry, SizeOf(dirEntry));
  end
end;

(*----------------------------------------------------------------------*
 | TIconCursorGroupResourceDetails.RemoveFromGroup                      |
 *----------------------------------------------------------------------*)
procedure TIconCursorGroupResourceDetails.RemoveFromGroup(
  Details: TIconCursorResourceDetails);
var
  i, id, count: Integer;
  attributes, ap: PResourceDirectory;
begin
  if ResourceNametoInt(Details.ResourceType) = ResourceNameToInt(ResourceType) - DIFFERENCE then
  begin
    attributes := PResourceDirectory(PChar (Data.Memory) + SizeOf(TIconHeader));
    id := ResourceNametoInt(Details.ResourceName);

    Count := PIconHeader (Data.Memory)^.wCount;

    for i := 0 to Count - 1 do
      if attributes^.wNameOrdinal = id then
      begin
        if i < Count - 1 then
        begin
          ap := Attributes;
          Inc(ap);
          Move(ap^, Attributes^, SizeOf(TResourceDirectory) * (Count - i - 1));
        end;

        Data.Size := Data.Size - SizeOf(TResourceDirectory);
        PIconHeader (Data.Memory)^.wCount := Count - 1;
        if (Count = 1) and not FDeleting then
          Parent.DeleteResource(Parent.IndexOfResource(Self));
        break
      end
      else
        Inc(attributes)
  end
end;

(*----------------------------------------------------------------------*
 | TIconCursorResourceDetails.InitNew                                   |
 *----------------------------------------------------------------------*)
procedure TIconCursorResourceDetails.InitNew;
var
  hdr: TBitmapInfoHeader;
  cImageSize: DWORD;
  pal: HPALETTE;
  entries: PPALETTEENTRY;
  w: DWORD;
  p: PChar;

begin
  if Self is TCursorResourceDetails then
    Data.Write(DefaultCursorHotspot, SizeOf(DefaultCursorHotspot));

  hdr.biSize := SizeOf(hdr);
  hdr.biWidth := DefaultIconCursorWidth;
  hdr.biHeight := DefaultIconCursorHeight * 2;
  hdr.biPlanes := 1;
  hdr.biBitCount := GetPixelFormatBitCount(DefaultIconCursorPixelFormat);

  if DefaultIconCursorPixelFormat = pf16Bit then
    hdr.biCompression := BI_BITFIELDS
  else
    hdr.biCompression := BI_RGB;

  hdr.biSizeImage := 0; // See note in unitExIcon

  hdr.biXPelsPerMeter := 0;
  hdr.biYPelsPerMeter := 0;

  hdr.biClrUsed := GetPixelFormatNumColors (DefaultIconCursorPixelFormat);
  hdr.biClrImportant := hdr.biClrUsed;

  Data.Write(hdr, SizeOf(hdr));

  pal := 0;
  case DefaultIconCursorPixelFormat of
    pf1Bit: pal := SystemPalette2;
    pf4Bit: pal := SystemPalette16;
    pf8Bit: pal := SystemPalette256
  end;

  entries := nil;
  try
    if pal > 0 then
    begin
      GetMem (entries, hdr.biClrUsed * SizeOf(PALETTEENTRY));
      GetPaletteEntries (pal, 0, hdr.biClrUsed, entries^);

      Data.Write(entries^, hdr.biClrUsed * SizeOf(PALETTEENTRY))
    end
    else
      if hdr.biCompression = BI_BITFIELDS then
      begin { 5,6,5 bitfield }
        w := $0f800;  // 1111 1000 0000 0000  5 bit R mask
        Data.Write(w, SizeOf(w));
        w := $07e0;   // 0000 0111 1110 0000  6 bit G mask
        Data.Write(w, SizeOf(w));
        w := $001f;   // 0000 0000 0001 1111  5 bit B mask
        Data.Write(w, SizeOf(w))
      end

  finally
    ReallocMem (entries, 0)
  end;

  // Write dummy image
  cImageSize := BytesPerScanLine(hdr.biWidth, hdr.biBitCount, 32) * DefaultIconCursorHeight;
  p := AllocMem (cImageSize);
  try
    Data.Write(p^, cImageSize);
  finally
    ReallocMem (p, 0)
  end;

  // Write dummy mask
  cImageSize := DefaultIconCursorHeight * DefaultIconCursorWidth div 8;

  GetMem (p, cImageSize);
  FillChar (p^, cImageSize, $ff);

  try
    Data.Write(p^, cImageSize);
  finally
    ReallocMem (p, 0)
  end;
end;

{ TDIBResourceDetails }

class function TDIBResourceDetails.GetBaseType: WideString;
begin
  Result := 'DIB';
end;

procedure TDIBResourceDetails.GetImage(picture: TPicture);
begin
  InternalGetImage(Data, Picture);
end;

procedure TDIBResourceDetails.InitNew;
var
  hdr: TBitmapFileHeader;
begin
  hdr.bfType := $4d42;
  hdr.bfSize := SizeOf(TBitmapFileHeader) + SizeOf(TBitmapInfoHeader);
  hdr.bfReserved1 := 0;
  hdr.bfReserved2 := 0;
  hdr.bfOffBits := hdr.bfSize;
  Data.Write(hdr, SizeOf(hdr));

  inherited;
end;

procedure TDIBResourceDetails.SetImage(image: TPicture);
begin
  InternalSetImage(Data, image);
end;

class function TDIBResourceDetails.SupportsData(Size: Integer;
  Data: Pointer): Boolean;
var
  p: PBitmapFileHeader;
  hdrSize: DWORD;
begin
  Result := False;
  p := PBitmapFileHeader (Data);
  if (p^.bfType = $4d42) and (p^.bfReserved1 = 0) and (p^.bfReserved2 = 0) then
  begin
    hdrSize := PDWORD (PChar (Data) + SizeOf(TBitmapFileHeader))^;

    case hdrSize of
      SizeOf(TBitmapInfoHeader):
        Result := True;
      SizeOf(TBitmapV4Header):
        Result := True;
      SizeOf(TBitmapV5Header):
        Result := True
    end
  end
end;

{ TGraphicsResourceDetails }

procedure TGraphicsResourceDetails.SetImage(image: TPicture);
begin
  Data.Clear;
  image.Graphic.SaveToStream (Data);
end;

initialization
  TPicture.RegisterFileFormat('ICO', rstIcons, TExIcon);
  TPicture.RegisterFileFormat('CUR', rstCursors, TExCursor);
  TPicture.UnregisterGraphicClass(TIcon);


  RegisterResourceDetails(TBitmapResourceDetails);
  RegisterResourceDetails(TDIBResourceDetails);
  RegisterResourceDetails(TIconGroupResourceDetails);
  RegisterResourceDetails(TCursorGroupResourceDetails);
  RegisterResourceDetails(TIconResourceDetails);
  RegisterResourceDetails(TCursorResourceDetails);
finalization
  TPicture.UnregisterGraphicClass(TExIcon);
  TPicture.UnregisterGraphicClass(TExCursor);
  TPicture.RegisterFileFormat('ICO', 'Icon', TIcon);
  UnregisterResourceDetails(TCursorResourceDetails);
  UnregisterResourceDetails(TIconResourceDetails);
  UnregisterResourceDetails(TCursorGroupResourceDetails);
  UnregisterResourceDetails(TIconGroupResourceDetails);
  UnregisterResourceDetails(TDIBResourceDetails);
  UnregisterResourceDetails(TBitmapResourceDetails);
end.
