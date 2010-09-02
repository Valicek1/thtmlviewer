{Version 10.1}
{***************************************************************}
{*                  METAFILEPRINTER.PAS                        *}
{*                                                             *}
{*              Thanks to Chris Wallace for the                *}
{*         ideas and most of the code for Print Preview        *)
{*                                                             *}
{*              Bugs introduced by Dave Baldwin                *}
{***************************************************************}



unit MetaFilePrinter;

{$I htmlcons.inc}

interface

uses
  Windows, Classes, Graphics, Printers{$ifdef LCL}, Interfaces{$endif};

type

{$ifdef MetaFileMissing}
  //HENHMETAFILE = longint;

  TMetafile = class(TGraphic)
  private
    FImageHandle: HENHMETAFILE;
    FImageMMWidth: Integer;      // are in 0.01 mm logical pixels
    FImageMMHeight: Integer;     // are in 0.01 mm logical pixels
    FImagePxWidth: Integer;  // in device pixels
    FImagePxHeight: Integer; // in device pixels

    procedure DeleteImage;
    function GetAuthor: String;
    function GetDescription: String;
    function GetEmpty: Boolean; override;
    function GetHandle: HENHMETAFILE;
    function GetMMHeight: Integer;
    function GetMMWidth: Integer;
    procedure SetHandle(Value: HENHMETAFILE);
    procedure SetMMHeight(Value: Integer);
    procedure SetMMWidth(Value: Integer);
  protected
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); override;
    function GetHeight: Integer; override;
    function GetWidth: Integer; override;
    procedure SetHeight(Value: Integer); override;
    procedure SetWidth(Value: Integer); override;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Assign(Source: TPersistent); override;

    procedure Clear;
    procedure LoadFromFile(const Filename: String); override;
    procedure LoadFromStream(Stream: TStream); override;
    procedure SaveToFile(const Filename: String); override;
    procedure SaveToStream(Stream: TStream); override;


    function ReleaseHandle: HENHMETAFILE;
    property Handle: HENHMETAFILE read GetHandle write SetHandle;
    property Empty: boolean read GetEmpty;

    property CreatedBy: String read GetAuthor;
    property Description: String read GetDescription;


    property MMWidth: Integer read GetMMWidth write SetMMWidth;
    property MMHeight: Integer read GetMMHeight write SetMMHeight;
  end;

  TMetafileCanvas = class(TCanvas)
  private
    FMetafile: TMetafile;
  public
    constructor Create(AMetafile: TMetafile; ReferenceDevice: HDC);
    constructor CreateWithComment(AMetafile: TMetafile; ReferenceDevice: HDC;
      const CreatedBy, Description: String);
    destructor Destroy; override;
  end;
{$endif}


  TUnits = (unInches, unCentimeters);
  TPageEvent = procedure(Sender: TObject; NumPage: Integer;
    var StopPrinting: Boolean) of object;

  TMetaFilePrinter = class(TComponent)
  private
    { Private declarations }
  protected
    { Protected declarations }
    FPrinting: boolean;
    FMFList: TList;
    FCurCanvas: TCanvas;
    FPPIX: integer;
    FPPIY: integer;
    FPaperWidth: integer;
    FPaperHeight: integer;
    FOffsetX: integer;
    FOffsetY: integer;
    FPgHeight: integer;
    FPgWidth: integer;
    FUnits: TUnits;
    FConvFac: double;
    FUsedPage: boolean;
    FPrinterDC: THandle;
    FOnPageEvent: TPageEvent;

    function GetCanvas: TCanvas;
    function GetPageNum: integer;
    procedure FreeMetaFiles;
    function GetMetaFile(I: integer): TMetaFile;
    procedure SetUnits(Val: TUnits);
    function GetLastAvailPage: integer;

  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

      // Printer Methods
    procedure BeginDoc; virtual;
    procedure NewPage; virtual;
    procedure EndDoc;
    procedure Abort;
//BG, 01.12.2006: beg of modification
    procedure getPrinterCapsOf(Printer: TPrinter);
//BG, 01.12.2006: end of modification

    property MetaFiles[I: integer]: TMetaFile read GetMetaFile;
    property PixelsPerInchX: integer read FPPIX;
    property PixelsPerInchY: integer read FPPIY;
    property PaperWidth: integer read FPaperWidth;
    property PaperHeight: integer read FPaperHeight;
    property PageHeight: integer read FPgHeight;
    property PageWidth: integer read FPgWidth;
    property OffsetX: integer read FOffsetX;
    property OffsetY: integer read FOffsetY;
    property Canvas: TCanvas read GetCanvas;
    property PageNumber: integer read GetPageNum;
    property Printing: boolean read FPrinting;
    property LastAvailablePage: integer read GetLastAvailPage;
//BG, 29.08.2010: no longer used:    property PrinterDC: THandle read FPrinterDC;
  published
    { Published declarations }
    property Units: TUnits read FUnits write SetUnits;
    property OnPageEvent: TPageEvent read FOnPageEvent write FOnPageEvent;
  end;

implementation

uses
  SysUtils, Forms {$IFNDEF NoGDIPlus}, GDIPL2A{$ENDIF NoGDIPlus};

const
  INCH_TO_CM = 2.54;

{$ifdef MetaFileMissing}

{ TMetafile }

procedure TMetafile.DeleteImage;
begin
  if FImageHandle <> 0 then
     DeleteEnhMetafile(FImageHandle);
   FImageHandle := 0;
end;

function TMetafile.GetAuthor: String;
var
  NC: Integer;
begin
  Result := '';
  if FImageHandle = 0 then Exit;

  NC := GetEnhMetafileDescription(FImageHandle, 0, nil);
  if NC <= 0 then Exit
  else begin
     SetLength(Result, NC);
     GetEnhMetafileDescription(FImageHandle, NC, PChar(Result));
     SetLength(Result, StrLen(PChar(Result)) );
  end;
end;

function TMetafile.GetDescription: String;
var
  NC: Integer;
begin
  Result := '';
  if FImageHandle = 0 then Exit;

  NC := GetEnhMetafileDescription(FImageHandle, 0, nil);
  if NC <= 0 then Exit
  else begin
     SetLength(Result, NC);
     GetEnhMetafileDescription(FImageHandle, NC, PChar(Result));
     Delete(Result, 1, StrLen(PChar(Result))+1);
     SetLength(Result, StrLen(PChar(Result)));
  end;
end;

function TMetafile.GetEmpty: Boolean;
begin
 Result := (FImageHandle = 0);
end;


function TMetafile.GetHandle: HENHMETAFILE;
begin
    Result := FImageHandle
end;


function TMetafile.GetMMHeight: Integer;
begin
  Result := FImageMMHeight;
end;

function TMetafile.GetMMWidth: Integer;
begin
  Result := FImageMMWidth;
end;


procedure TMetafile.SetHandle(Value: HENHMETAFILE);
var
  EnhHeader: TEnhMetaHeader;
begin
  if (Value <> 0) and (GetEnhMetafileHeader(Value, sizeof(EnhHeader), @EnhHeader) = 0) then
     raise EInvalidImage.Create('Invalid Metafile');;

  if FImageHandle <> 0 then DeleteImage;

  FImageHandle := Value;
  FImagePxWidth := 0;
  FImagePxHeight := 0;
  FImageMMWidth := EnhHeader.rclFrame.Right - EnhHeader.rclFrame.Left;
  FImageMMHeight := EnhHeader.rclFrame.Bottom - EnhHeader.rclFrame.Top;
end;


procedure TMetafile.SetMMHeight(Value: Integer);
begin
  FImagePxHeight := 0;
  if FImageMMHeight <> Value then FImageMMHeight := Value;
end;

procedure TMetafile.SetMMWidth(Value: Integer);
begin
  FImagePxWidth := 0;
  if FImageMMWidth <> Value then FImageMMWidth := Value;
end;

procedure TMetafile.Draw(ACanvas: TCanvas; const Rect: TRect);
var
  RT: TRect;
begin
  if FImageHandle = 0 then Exit;
  RT := Rect;
  PlayEnhMetaFile(ACanvas.Handle, FImageHandle, RT);
end;

function TMetafile.GetHeight: Integer;
var
  EMFHeader: TEnhMetaHeader;
begin
  if FImageHandle = 0 then
     Result := FImagePxHeight
  else begin               // convert 0.01mm units to device pixels
       GetEnhMetaFileHeader(FImageHandle, Sizeof(EMFHeader), @EMFHeader);
       Result := MulDiv(FImageMMHeight,               // metafile height in 0.01mm
         EMFHeader.szlDevice.cy,                      // device height in pixels
         EMFHeader.szlMillimeters.cy*100);            // device height in mm
     end
end;

function TMetafile.GetWidth: Integer;
var
  EMFHeader: TEnhMetaHeader;
begin
    if FImageHandle = 0 then
     Result := FImagePxWidth
  else begin     // convert 0.01mm units to device pixels
        GetEnhMetaFileHeader(FImageHandle, Sizeof(EMFHeader), @EMFHeader);
        Result := MulDiv(FImageMMWidth,                // metafile width in 0.01mm
          EMFHeader.szlDevice.cx,                      // device width in pixels
          EMFHeader.szlMillimeters.cx*100);            // device width in 0.01mm
      end
end;


procedure TMetafile.SetHeight(Value: Integer);
var
  EMFHeader: TEnhMetaHeader;
begin
      if FImageHandle = 0 then
       FImagePxHeight := Value
    else begin                 // convert device pixels to 0.01mm units
       GetEnhMetaFileHeader(FImageHandle, Sizeof(EMFHeader), @EMFHeader);
       MMHeight := MulDiv(Value,                      // metafile height in pixels
          EMFHeader.szlMillimeters.cy*100,             // device height in 0.01mm
          EMFHeader.szlDevice.cy);                     // device height in pixels
    end
end;

procedure TMetafile.SetWidth(Value: Integer);
var
  EMFHeader: TEnhMetaHeader;
begin
  if FImageHandle = 0 then
     FImagePxWidth := Value
  else begin                 // convert device pixels to 0.01mm units
        GetEnhMetaFileHeader(FImageHandle, Sizeof(EMFHeader), @EMFHeader);
        MMWidth := MulDiv(Value,                      // metafile width in pixels
          EMFHeader.szlMillimeters.cx*100,            // device width in mm
          EMFHeader.szlDevice.cx);                    // device width in pixels
  end
end;

constructor TMetafile.Create;
begin
  inherited Create;
  FImageHandle := 0;
end;

destructor TMetafile.Destroy;
begin
  DeleteImage;
  inherited Destroy;
end;

procedure TMetafile.Assign(Source: TPersistent);
begin
  if (Source = nil) or (Source is TMetafile) then begin
    if FImageHandle <> 0 then DeleteImage;
    if Assigned(Source) then begin
      FImageHandle := TMetafile(Source).Handle;
      FImageMMWidth := TMetafile(Source).MMWidth;
      FImageMMHeight := TMetafile(Source).MMHeight;
      FImagePxWidth := TMetafile(Source).Width;
      FImagePxHeight := TMetafile(Source).Height;
    end
  end
  else
    inherited Assign(Source);
end;


procedure TMetafile.Clear;
begin
  DeleteImage;
end;

procedure TMetafile.LoadFromFile(const Filename: String);
begin
      raise EComponentError.Create('Not Implemented');
end;

procedure TMetafile.SaveToFile(const Filename: String);
begin
      raise EComponentError.Create('Not Implemented');
end;

procedure TMetafile.LoadFromStream(Stream: TStream);
begin
      raise EComponentError.Create('Not Implemented');
end;

procedure TMetafile.SaveToStream(Stream: TStream);
begin
      raise EComponentError.Create('Not Implemented');
end;

function TMetafile.ReleaseHandle: HENHMETAFILE;
begin
  DeleteImage;
  Result := FImageHandle;
  FImageHandle := 0;
end;

{ TMetafileCanvas }

constructor TMetafileCanvas.Create(AMetafile: TMetafile; ReferenceDevice: HDC);
begin
  CreateWithComment(AMetafile, ReferenceDevice, AMetafile.CreatedBy,
    AMetafile.Description);
end;

constructor TMetafileCanvas.CreateWithComment(AMetafile: TMetafile;
  ReferenceDevice: HDC; const CreatedBy, Description: String);
var
  RefDC: HDC;
  R: TRect;
  Temp: HDC;
  P: PChar;
begin
  inherited Create;
  FMetafile := AMetafile;

  if ReferenceDevice = 0 then RefDC := GetDC(0)
  else RefDC := ReferenceDevice;

  try
    if FMetafile.MMWidth = 0 then begin
      if FMetafile.Width = 0 then //if no width get RefDC height
        FMetafile.MMWidth := GetDeviceCaps(RefDC, HORZSIZE)*100
      else FMetafile.MMWidth := MulDiv(FMetafile.Width, //else convert
              GetDeviceCaps(RefDC, HORZSIZE)*100, GetDeviceCaps(RefDC, HORZRES));
    end;

    if FMetafile.MMHeight = 0 then begin
      if FMetafile.Height = 0 then //if no height get RefDC height
        FMetafile.MMHeight := GetDeviceCaps(RefDC, VERTSIZE)*100
      else FMetafile.MMHeight := MulDiv(FMetafile.Height, //else convert
              GetDeviceCaps(RefDC, VERTSIZE)*100, GetDeviceCaps(RefDC, VERTRES));
    end;

    R := Rect(0,0,FMetafile.MMWidth,FMetafile.MMHeight);
    //lpDescription stores both author and description
    if (Length(CreatedBy) > 0) or (Length(Description) > 0) then
      P := PChar(CreatedBy+#0+Description+#0#0)
    else
      P := nil;
    Temp := CreateEnhMetafile(RefDC, nil, @R, P);
    if Temp = 0 then raise EOutOfResources.Create('Out of Resources');;
    Handle := Temp;
  finally
    if ReferenceDevice = 0 then ReleaseDC(0, RefDC);
  end;

end;

destructor TMetafileCanvas.Destroy;
begin
  FMetafile.Handle := CloseEnhMetafile(Handle);
  inherited Destroy;
end;

{$endif}

// TMetaFilePrinter

constructor TMetaFilePrinter.Create(AOwner: TComponent);
begin
  inherited;
  FMFList := TList.Create;
  FUnits := unInches;
end;

destructor TMetaFilePrinter.Destroy;
begin
  FreeMetaFiles;
  FMFList.Free;
  inherited;
end;


procedure TMetaFilePrinter.FreeMetaFiles;
var
  I: integer;
begin
  for I := 0 to FMFList.Count - 1 do
    MetaFiles[I].Free;
  FMFList.Clear;
  FreeAndNil(FCurCanvas);
end;

function TMetaFilePrinter.GetMetaFile(I: integer): TMetaFile;
begin
  Result := FMFList[I];
end;

procedure TMetaFilePrinter.SetUnits(Val: TUnits);
begin
  FUnits := Val;
  case FUnits of
    unInches: FConvFac := 1;
    unCentimeters: FConvFac := INCH_TO_CM;
  end;
end;

//BG, 01.12.2006: beg of modification: extracted getPrinterCapsOf from BeginDoc

procedure TMetaFilePrinter.getPrinterCapsOf(Printer: TPrinter);
begin
  if Printer.Printers.Count = 0 then
    raise Exception.Create('Printer not available');

{$ifdef LCL}
  FPPIX := Printer.XDPI;
  FPPIY := Printer.YDPI;
  FPaperWidth := Printer.PageWidth;
  FPaperHeight := Printer.PageHeight;
  FOffsetX := Printer.PaperSize.PaperRect.WorkRect.Left;
  FOffsetY := Printer.PaperSize.PaperRect.WorkRect.Top;
  FPgHeight := Printer.PageHeight;
  FPgWidth := Printer.PageWidth;
{$else}
//  FPrinterDC := Printer.Handle;
  FPPIX := GetDeviceCaps(Printer.Handle, LOGPIXELSX);
  FPPIY := GetDeviceCaps(Printer.Handle, LOGPIXELSY);
  FPaperWidth := GetDeviceCaps(Printer.Handle, PHYSICALWIDTH);
  FPaperHeight := GetDeviceCaps(Printer.Handle, PHYSICALHEIGHT);
  FOffsetX := GetDeviceCaps(Printer.Handle, PHYSICALOFFSETX);
  FOffsetY := GetDeviceCaps(Printer.Handle, PHYSICALOFFSETY);
  FPgHeight := Printer.PageHeight;
  FPgWidth := Printer.PageWidth;
{$endif}
end;

procedure TMetaFilePrinter.BeginDoc;
begin
  FPrinting := True;
  FreeMetaFiles;

  getPrinterCapsOf(Printer);

  NewPage;
end;
//BG, 01.12.2006: end of modification

procedure TMetaFilePrinter.EndDoc;
var
  I: integer;
begin
  FPrinting := False;
  FCurCanvas.Free;
  FCurCanvas := nil;
  FPrinterDC := 0;

   // in case NewPage was called but nothing drawn on it
  if not FUsedPage then
  begin
    I := FMFList.Count - 1;
    MetaFiles[FMFList.Count - 1].Free;
    FMFList.Delete(I);
  end;

end;

procedure TMetaFilePrinter.Abort;
begin
  FPrinting := False;
  FCurCanvas.Free;
  FCurCanvas := nil;
  FreeMetaFiles;
end;

procedure TMetaFilePrinter.NewPage;
var
  MetaFile: TMetaFile;
  NewCanvas: TCanvas;
  Done: boolean;
begin
  MetaFile := TMetaFile.Create;
  FMFList.Add(MetaFile);

  {$IFNDEF NoGDIPlus}
  if GDIPlusActive then                                  
    NewCanvas := TMetaFileCanvas.Create(MetaFile, Printer.Handle)
  else
    {$ENDIF NoGDIPlus}
    NewCanvas := TMetaFileCanvas.Create(MetaFile, 0);
   { fill the page with "whiteness" }
  NewCanvas.Brush.Color := clWhite;
  NewCanvas.Pen.Color := clWhite;
  NewCanvas.Brush.Style := bsSolid;
  NewCanvas.Rectangle(0, 0, FPaperWidth, FPaperHeight);

  if FCurCanvas = nil then
  begin
    NewCanvas.Font.PixelsPerInch := Screen.PixelsPerInch;
    NewCanvas.Font.Name := 'Arial';
    NewCanvas.Font.Size := 10;
    NewCanvas.Brush.Style := bsClear;
  end;

  FCurCanvas.Free;
  FCurCanvas := NewCanvas;
  FUsedPage := False;

  if Assigned(FOnPageEvent) then
  begin
    Done := False;
    FOnPageEvent(Self, FMFList.Count, Done);
  end;
end;

function TMetaFilePrinter.GetPageNum: integer;
begin
  Result := FMFList.Count;
end;

function TMetaFilePrinter.GetLastAvailPage: integer;
begin
  Result := GetPageNum;
end;

function TMetaFilePrinter.GetCanvas: TCanvas;
begin
  Result := FCurCanvas;
  FUsedPage := True;
end;

end.
