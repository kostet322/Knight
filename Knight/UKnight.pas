{$DEFINE Step1}
{$DEFINE Step2}
{$DEFINE Step3}
{$DEFINE Step4}
{$DEFINE Step5}
{$DEFINE Step6}
{$DEFINE Step7}

unit UKnight;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, Menus, StdCtrls, ComCtrls;

type
  TFrm_Knight = class(TForm)
    Pbx_ChessBoard: TPaintBox;
    Menu_Knight: TMainMenu;
    File1: TMenuItem;
    SelectStartPosition1: TMenuItem;
    Go1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    Lbl_Branch: TLabel;
    Lbl_BranchNum: TLabel;
    N2: TMenuItem;
    Options1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    Bvl_Upper: TBevel;
    Lbl_NumDecisions: TLabel;
    Lbl_Infill: TLabel;
    Clear1: TMenuItem;
    Cmb_Decisions: TComboBox;
    Btn_Play: TButton;
    Lbl_ChooseDecision: TLabel;
    Btn_Go: TButton;
    N3: TMenuItem;
    PlayDecisions1: TMenuItem;
    Tbr_PlaySpeed: TTrackBar;
    Lbl_Slow: TLabel;
    Lbl_Fast: TLabel;
    Bvl_PlaySpeed: TBevel;
    Chb_Animate: TCheckBox;
    Lbl_CalcTime: TLabel;
    Timer_CalcTime: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure Pbx_ChessBoardPaint(Sender: TObject);
    procedure DeselectStartPosMode;
    procedure SelectStartPosition1Click(Sender: TObject);
    procedure Pbx_ChessBoardMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Go1Click(Sender: TObject);
    procedure Options1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Clear1Click(Sender: TObject);
    procedure Btn_PlayClick(Sender: TObject);
    procedure Cmb_DecisionsClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Btn_GoClick(Sender: TObject);
    procedure PlayDecisions1Click(Sender: TObject);
    procedure Timer_CalcTimeTimer(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
  private
    { Private declarations }
    FBoard: TObject; // don't remove this line
  public
    { Public declarations }
  end;

const
  MinNumLines = 3;
  MaxNumLines = 10;
  MinCellSide = 30;
  MaxCellSide = 100;
  MaxMovesDelay = 5000;

var
  Frm_Knight: TFrm_Knight;

implementation

uses UOptions, UAbout;

{$R *.DFM}

type
  TChessPos = record
    X, Y: ShortInt;
  end;
  TKnightMove = record
    DX, DY: ShortInt;
  end;
  TKnightMoves = array [1..8] of TKnightMove;
  TChessBoard = array [1..MaxNumLines, 1..MaxNumLines] of Byte;
  TKnightPath = array [1..MaxNumLines*MaxNumLines] of Byte;

const
  KnightMoves: TKnightMoves =
    ((DX: 1; DY: 2), (DX: 2; DY: 1), (DX: 2; DY: -1), (DX: 1; DY: -2),
     (DX: -1; DY: -2), (DX: -2; DY: -1), (DX: -2; DY: 1), (DX: -1; DY: 2));
  BoardMargin = 50;

type
  TBoard = class
  private
    Color, GridColor: TColor;
    CellSide, MovesDelay: Word;
    NumLines, CurDepth, MaxDepth: Byte;
    SelectStartPosMode, ShowBranchInfo, ShowGraphics, Working, CalcStop,
      NeedWriteToFile, NeedWriteToFileMax, ViewNumbers, AddPos : Boolean;
    StartPos, LastPos: TChessPos;
    ColorStep: Real;
    NumDecisions: DWORD;
    ChessBoard, ChessBoardPrev: TChessBoard;
    BranchesNumber: DWORD; // Int64; is better for Delphi5
    FBranch, FBranchMax: TextFile;
    FBranchName, FBranchMaxName: String;
    DecisionsList: TStrings;
    KnightBitmap, CellBitmap: TBitmap;
    CurKnightPath, MaxKnightPath: TKnightPath;
    StartTime: DWORD;

    constructor Create;
    destructor Destroy;  override;
    procedure ChessBoardZeroing;
    procedure Initialize;
    procedure BoardResize;

    {$IFDEF Step3}
    procedure StretchKnight;
    {$ENDIF}
    procedure DrawGrid;
    function  GetCellColor(Number: Byte): TColor;
    procedure SetCellToNumber(CX, CY: Integer; Number: Byte);
    {$IFDEF Step2}
    procedure SmartPaint;
    {$ENDIF}
    procedure BoardPaint;
    procedure DrawBranchNum;
    procedure DrawBranchInfo;
    procedure OutCalcTime(ShowMSec: Boolean);

    function  CalcBranch(CPath: TKnightPath; CDepth: Byte): PChar;
    procedure SetStartPos(X, Y: Byte);
    procedure SetOptions;
    procedure GetOptions;
    procedure WriteToFile;
    procedure WriteToFileMax;

    function  ChooseNewBranch(GoFarther: Boolean; var CPath: TKnightPath;
              var CDepth: Byte): Boolean;
    function  TestBranch({$IFDEF Step4} const {$ENDIF} CPath: TKnightPath;
              {$IFDEF Step4} const {$ENDIF} CDepth: Byte): Boolean;
    procedure Stop;
    procedure Go;

    procedure AnimMove(Num: Integer; XSt, YSt, XFin, YFin: Integer);

    procedure DrawDecisions;
    procedure PlayDecision;
    procedure DecisionsClick;
  end;

var
  Board: TBoard;
  UserRating: Integer;

procedure Delay(T: DWORD);
{ T milliseconds delay }
var T1: DWORD;
begin
  T1 := GetTickCount;
  repeat Application.ProcessMessages
  until ((GetTickCount-T1)>=T);
end;


{ TBoard }

constructor TBoard.Create;
{ Initializes board settings }
begin
  inherited Create;

  Color := clBtnFace;
  GridColor := clBlue;
  CellSide := 40;
  NumLines := 4;
  MovesDelay := 0;
  SelectStartPosMode := False;

  ShowGraphics := False;

  ShowBranchInfo := False;

  NeedWriteToFile := False;
  NeedWriteToFileMax := False;
  ViewNumbers := False;

  Working := False;
  KnightBitmap := TBitmap.Create;
  CellBitmap := TBitmap.Create;
  DecisionsList := TStringList.Create;

  SetStartPos(1, 1);
end;


destructor TBoard.Destroy;
{ Releases resources }
begin
  inherited Destroy;

  {$IFDEF Step1}
  KnightBitmap.Free;
  CellBitmap.Free;
  DecisionsList.Free;
  {$ENDIF}
end;


procedure TBoard.ChessBoardZeroing;
{ Fills ChessBoard with zeros }
var X, Y: Byte;
begin
  for Y := 1 to NumLines do
    for X := 1 to NumLines do
      ChessBoard[X, Y] := 0;
end;


procedure TBoard.Initialize;
{ Initializes the board state }
begin
  Frm_Knight.Cmb_Decisions.Text := '';
  Frm_Knight.Cmb_Decisions.Items.Clear;
  DecisionsList.Clear;
  BranchesNumber := 0;
  NumDecisions := 0;
  MaxDepth := 0;

  ChessBoardZeroing;

  if Board.NeedWriteToFile then
  begin
    FBranchName := 'BRANCH.TXT';
    AssignFile(FBranch, FBranchName);
    Rewrite(FBranch);
    CloseFile(FBranch);
  end;

  if NeedWriteToFileMax then
  begin
    FBranchMaxName := 'BRANCHMX.TXT';
    AssignFile(FBranchMax, FBranchMaxName);
    Rewrite(FBranchMax);
    CloseFile(FBranchMax);
  end;
end;


procedure TBoard.BoardResize;
{ Resizes the board }
begin
  with Frm_Knight do
  begin
    ColorStep := 255 / (Sqr(Board.NumLines));

    Pbx_ChessBoard.Top := Bvl_Upper.Height + round(BoardMargin * 0.5);
    Pbx_ChessBoard.Left := BoardMargin;
    Pbx_ChessBoard.Height := CellSide * NumLines + 1;
    Pbx_ChessBoard.Width := CellSide * NumLines + 1;

    ClientHeight := Pbx_ChessBoard.Top + Pbx_ChessBoard.Height + BoardMargin;
    ClientWidth := BoardMargin * 2 + Pbx_ChessBoard.Width;
    if ClientWidth < (Btn_Play.Left + Btn_Play.Width + 10) then
      ClientWidth := (Btn_Play.Left + Btn_Play.Width + 10);
    Lbl_CalcTime.Top := ClientHeight - BoardMargin div 2;

    {$IFDEF Step3}
    StretchKnight;
    {$ENDIF}

    Pbx_ChessBoardPaint(nil);

    Lbl_Branch.Caption := 'Current Branch:';
    DrawBranchNum;
    DrawDecisions;
  end;
end;


{$IFDEF Step3}
procedure TBoard.StretchKnight;
{ Loads an image from the file and stretches it to fit the size }
var KBitmap: TBitmap;
begin
  KBitmap := TBitmap.Create;
  KBitmap.LoadFromFile('Knight2.bmp');

  KnightBitmap.Width := CellSide;
  KnightBitmap.Height := CellSide;
  KnightBitmap.Canvas.StretchDraw(Rect(0, 0, KnightBitmap.Width,
    KnightBitmap.Height), KBitmap);

  KnightBitmap.Transparent := True;

  CellBitmap.Width := (CellSide)*2;
  CellBitmap.Height := CellSide;
  CellBitmap.Canvas.Font.Style := [fsBold];
  if CellSide >= 60 then CellBitmap.Canvas.Font.Size := 12
  else
  begin
    if CellSide >= 40 then CellBitmap.Canvas.Font.Size := 10
    else CellBitmap.Canvas.Font.Size := 8;
  end;
  CellBitmap.Transparent := True;

  KBitmap.Free;
end;
{$ENDIF}


procedure TBoard.DrawGrid;
{ Draws a grid on the board }
var I: Integer;
begin
  with Frm_Knight do
  begin
    Pbx_ChessBoard.Canvas.Pen.Color := clGray;
    for I := 0 to NumLines do
    begin
      { Horizontal lines }
      Pbx_ChessBoard.Canvas.Polyline([Point(0, (I+1)*CellSide - 1),
        Point(Pbx_ChessBoard.ClientWidth, (I+1)*CellSide - 1)]);
      { Vertical lines }
      Pbx_ChessBoard.Canvas.Polyline([Point((I+1)*CellSide - 1, 0),
        Point((I+1)*CellSide-1, Pbx_ChessBoard.ClientHeight)]);
    end;

    Pbx_ChessBoard.Canvas.Pen.Color := clWhite;
    for I := 0 to NumLines do
    begin
      { Horizontal lines }
      Pbx_ChessBoard.Canvas.Polyline([Point(0, I*CellSide + 1),
        Point(Pbx_ChessBoard.ClientWidth, I*CellSide + 1)]);
      { Vertical lines }
      Pbx_ChessBoard.Canvas.Polyline([Point(I*CellSide+1, 0),
        Point(I*CellSide+1, Pbx_ChessBoard.ClientHeight)]);
    end;

    Pbx_ChessBoard.Canvas.Pen.Color := GridColor;
    for I := 0 to NumLines+1 do
    begin
      { Horizontal lines }
      Pbx_ChessBoard.Canvas.Polyline([Point(0, I*CellSide),
        Point(Pbx_ChessBoard.ClientWidth, I*CellSide)]);
      { Vertical lines }
      Pbx_ChessBoard.Canvas.Polyline([Point(I*CellSide, 0),
        Point(I*CellSide, Pbx_ChessBoard.ClientHeight)]);
    end;
  end;
end;


function TBoard.GetCellColor(Number: Byte): TColor;
{ Calculates the returned color according to the Number: when the Number changes
  from 1 to 255, the color changes from Blue to Red and then to Yellow }
var Red, Green, Blue: Byte;
begin
  { Blue -> Red -> Yellow }
  if Number<=(Sqr(NumLines) div 2) then
  begin
    Red := round(Number*ColorStep*2);
    Green := 0;
    Blue := 255-round(Number*ColorStep*2);
  end
  else
  begin
    Red := 255;
    Green := 127 + round(Number*ColorStep*2 - 127);
    Blue := 0;
  end;
  GetCellColor := RGB(Red, Green, Blue);
end;


procedure TBoard.SetCellToNumber(CX, CY: Integer; Number: Byte);
{ Draws a color square or an image in the cell with CX, CY coordinates and
  indicates its number.
  If Number = 0 the cell is cleared }
var CellRect, FirstRect: TRect;
    NewColor: TColor;

  procedure DrawColorRect;
  { Draws a color square }
  begin
  {$IFDEF Step3}
    CellBitmap.Canvas.Brush.Color := NewColor;
    CellBitmap.Canvas.FillRect(FirstRect);
  {$ELSE}
    Frm_Knight.Pbx_ChessBoard.Canvas.Pen.Color := NewColor;
    Frm_Knight.Pbx_ChessBoard.Canvas.Brush.Color := NewColor;
    Frm_Knight.Pbx_ChessBoard.Canvas.Rectangle(CellRect.Left, CellRect.Top,
      CellRect.Right, CellRect.Bottom);
  {$ENDIF}
  end;


  procedure DrawColorBitmap;
  { Draws the image to the bitmap }
  begin
  {$IFDEF Step3}

    CellBitmap.Canvas.Brush.Color := Color;
    CellBitmap.Canvas.FillRect(FirstRect);

    CellBitmap.Canvas.Brush.Color := NewColor; // Pattern
    // Pattern^Destination
    BitBlt(CellBitmap.Canvas.Handle, 0, 0, CellSide, CellSide,
      CellBitmap.Canvas.Handle, 0, 0, PATINVERT);
    // Source&Destination
    BitBlt(CellBitmap.Canvas.Handle, 0, 0, CellSide, CellSide,
      KnightBitmap.Canvas.Handle, 0, 0, SRCAND);
    // Pattern^Destination
    BitBlt(CellBitmap.Canvas.Handle, 0, 0, CellSide, CellSide,
      CellBitmap.Canvas.Handle, 0, 0, PATINVERT);

  {$ELSE}
    SetCellToNumber(CX, CY, 0);
    CellBitmap.LoadFromFile('Knight2.bmp');
    CellBitmap.Monochrome := False;
    CellBitmap.Canvas.Brush.Color := NewColor;
    CellBitmap.Transparent := True;
    CellBitmap.Canvas.FloodFill(CellBitmap.Width div 2, CellBitmap.Height div 2,
      clBlack, fsSurface);
    Frm_Knight.Pbx_ChessBoard.Canvas.StretchDraw(CellRect, CellBitmap);
  {$ENDIF}
  end;

  procedure DrawNums;
  { Draws the digit to the bitmap }
  {$IFDEF Step3}
  var StrNum: String;
  {$ENDIF}
  begin
  {$IFDEF Step3}
    SetBkMode(CellBitmap.Canvas.Handle, TRANSPARENT);
    StrNum := IntToStr(Number);
    { Draws the shadow of the digit }
    CellBitmap.Canvas.Font.Color := clBlack;
    TextOut(CellBitmap.Canvas.Handle, 3, 3, PChar(StrNum), Length(StrNum));
    { Draws the digit }
    CellBitmap.Canvas.Font.Color := clWhite;
    TextOut(CellBitmap.Canvas.Handle, 2, 2, PChar(StrNum), Length(StrNum));

  {$ELSE}
    Frm_Knight.Pbx_ChessBoard.Canvas.Font.Style := [fsBold];
    if CellSide >= 60 then Frm_Knight.Pbx_ChessBoard.Canvas.Font.Size := 12
    else
    begin
      if CellSide >= 40 then Frm_Knight.Pbx_ChessBoard.Canvas.Font.Size := 10
      else Frm_Knight.Pbx_ChessBoard.Canvas.Font.Size := 8;
    end;


    SetBkMode(Frm_Knight.Pbx_ChessBoard.Canvas.Handle, TRANSPARENT);
    { Draws the shadow of the digit }
    Frm_Knight.Pbx_ChessBoard.Canvas.Font.Color := clBlack;
    Frm_Knight.Pbx_ChessBoard.Canvas.TextOut(CellRect.Left+3, CellRect.Top+3,
      IntToStr(Number));
    { Draws the digit }
    Frm_Knight.Pbx_ChessBoard.Canvas.Font.Color := clWhite;
    Frm_Knight.Pbx_ChessBoard.Canvas.TextOut(CellRect.Left+2, CellRect.Top+2,
      IntToStr(Number));
  {$ENDIF}
  end;

  procedure DrawCellBitmap;
  { Draws the bitmap to Pbx_ChessBoard }
  begin
    BitBlt(Frm_Knight.Pbx_ChessBoard.Canvas.Handle, CellRect.Left, CellRect.Top,
      CellSide-3, CellSide-3, CellBitmap.Canvas.Handle,
      0, 0, SRCCOPY);
  end;

begin
  CellRect := Rect((CX-1)*CellSide+2, (CY-1)*CellSide+2, CX*CellSide-1, CY*CellSide-1);
  FirstRect := Rect(0, 0, CellSide, CellSide);

  if Number = 0 then
  begin
    { Clear the cell }
    Frm_Knight.Pbx_ChessBoard.Canvas.Brush.Color := Color;
    Frm_Knight.Pbx_ChessBoard.Canvas.FillRect(CellRect);
  end
  else
  begin
    NewColor := GetCellColor(Number);
    if ViewNumbers then DrawColorRect
    else DrawColorBitmap;
    DrawNums;
    {$IFDEF Step3}
    DrawCellBitmap;
    {$ENDIF}
  end;
end;


{$IFDEF Step2}
procedure TBoard.SmartPaint;
{ Fills the cells with images or color according to the ChessBoard array.
  Stores the information about the previous ChessBoard state and draws
  a new position according to the changes }
var X, Y: Integer;
begin
  for Y := 1 to NumLines do
    for X := 1 to NumLines do
    begin
    if (ChessBoard[X, Y]<>ChessBoardPrev[X, Y]) then
    begin
      if (ChessBoard[X, Y] > 0) then
        SetCellToNumber(X, Y, ChessBoard[X, Y])
      else
        SetCellToNumber(X, Y, 0);
    end;
    end;
  ChessBoardPrev := ChessBoard;
end;
{$ENDIF}


procedure TBoard.BoardPaint;
{ Draws all cells on the board according to the ChessBoard array }
var X, Y: Integer;
begin
  Frm_Knight.Pbx_ChessBoard.Canvas.Brush.Color := Color;
  Frm_Knight.Pbx_ChessBoard.Canvas.FillRect(Rect(0, 0,
    Frm_Knight.Pbx_ChessBoard.Width, Frm_Knight.Pbx_ChessBoard.Height));

  DrawGrid;

  for Y := 1 to NumLines do
    for X := 1 to NumLines do
      if (ChessBoard[X, Y] > 0) then SetCellToNumber(X, Y, ChessBoard[X, Y]);

  ChessBoardPrev := ChessBoard;
end;


procedure TBoard.DrawBranchNum;
begin
  Frm_Knight.Lbl_BranchNum.Caption := 'Branch Number: ' + IntToStr(BranchesNumber);
end;


procedure TBoard.DrawBranchInfo;
{ Displays information about the current branch and its number }
begin
  Frm_Knight.Lbl_Branch.Caption := 'Current Branch: ' +
                                   CalcBranch(CurKnightPath, CurDepth);
  Frm_Knight.Lbl_BranchNum.Caption := 'Branch Number: ' +
                                      IntToStr(BranchesNumber);
end;


function TBoard.CalcBranch(CPath: TKnightPath; CDepth: Byte): PChar;
{ Converts the branch to the PChar type according to CPath and CDepth }
const S: array [0..150] of Char = '';
var Depth: Integer;
  St: string;
  PCh: PChar;
begin
  S := '';
  PCh := S;
  for Depth := 1 to CDepth do
  begin
    St := (IntToStr(CPath[Depth]));
    StrCat(PCh, PChar(St));
  end;
  CalcBranch := PCh;
end;


procedure TBoard.SetStartPos(X, Y: Byte);
{ Sets the start position with X, Y coordinates }
begin
  if (X > 0) and (X <= NumLines) and (Y > 0) and (Y <= NumLines) then
  begin
    StartPos.X := X;
    StartPos.Y := Y;

    ChessBoard[StartPos.X, StartPos.Y] := 1;
    SetCellToNumber(StartPos.X, StartPos.Y, ChessBoard[StartPos.X, StartPos.Y]);
  end
end;


procedure TBoard.SetOptions;
{ Sets option significance in Frm_Options according to the Board state variables }
begin
  Frm_Options.Spin_NumLines.Value := NumLines;
  Frm_Options.Spin_CellSide.Value := CellSide;
  Frm_Options.Spin_MovesDelay.Value := MovesDelay;

  Frm_Options.Chk_ShowBranchInfo.Checked := ShowBranchInfo;
  Frm_Options.Chk_ShowGraphics.Checked := ShowGraphics;

  Frm_Options.Chk_WriteBranchesToFile.Checked := NeedWriteToFile;
  Frm_Options.Chk_WriteMaxBranchesToFile.Checked := NeedWriteToFileMax;

  if ViewNumbers then Frm_Options.RdGr_ViewMode.ItemIndex := 0
  else Frm_Options.RdGr_ViewMode.ItemIndex := 1;
end;


procedure TBoard.GetOptions;
{ Gets option significance from Frm_Options }
begin
  Frm_Knight.DeselectStartPosMode;

  SetOptions;

  Frm_Options.ShowModal;

  if (NumLines <> Frm_Options.Spin_NumLines.Value) or
    (NeedWriteToFile <> Frm_Options.Chk_WriteBranchesToFile.Checked) or
    (NeedWriteToFileMax <> Frm_Options.Chk_WriteMaxBranchesToFile.Checked) then
  begin
    NumLines := Frm_Options.Spin_NumLines.Value;

    NeedWriteToFile := Frm_Options.Chk_WriteBranchesToFile.Checked;
    NeedWriteToFileMax := Frm_Options.Chk_WriteMaxBranchesToFile.Checked;

    ChessBoardZeroing;
    Initialize;
    SetStartPos(1, 1);

    Frm_Knight.Cmb_Decisions.Items.Clear;
    DecisionsList.Clear;
    NumDecisions := 0;
  end;

  CellSide := Frm_Options.Spin_CellSide.Value;
  MovesDelay := Frm_Options.Spin_MovesDelay.Value * 10;

  ShowBranchInfo := Frm_Options.Chk_ShowBranchInfo.Checked;
  ShowGraphics := Frm_Options.Chk_ShowGraphics.Checked;

  ViewNumbers := (Frm_Options.RdGr_ViewMode.ItemIndex = 1);
  if ViewNumbers then
  begin
    Frm_Knight.Chb_Animate.Checked := False;
    Frm_Knight.Chb_Animate.Enabled := False;
  end
  else Frm_Knight.Chb_Animate.Enabled := True;
  BoardResize;
end;


procedure TBoard.WriteToFile;
{ Saves the current branch to the FBranch file }
begin
  Append(FBranch);
  Writeln(FBranch, CalcBranch(CurKnightPath, CurDepth));
  CloseFile(FBranch);
end;


procedure TBoard.WriteToFileMax;
{ Saves the current branch to the FBranchMax file }
var OFS: OFSTRUCT;
begin
  OpenFile(PChar(FBranchMaxName), OFS, OF_WRITE);
  Writeln(FBranchMax, CalcBranch(CurKnightPath, CurDepth));
  CloseFile(FBranchMax);
end;


function TBoard.ChooseNewBranch(GoFarther: Boolean; var CPath: TKnightPath;
  var CDepth: Byte): Boolean;
{ Chooses a new branch according to the previuos branch }
var PrevDepth: Integer;
begin
  ChooseNewBranch := True;
  AddPos := False;

  if GoFarther then
  begin
    Inc(CDepth);
    CPath[CDepth] := 1;
    AddPos := True;
  end
  else
  begin
    PrevDepth := CDepth;
    while (CPath[CDepth] = 8) do
    begin
      if (CDepth > 0) then Dec(CDepth);
    end;
    if (CDepth > 0) then
    begin
      Inc(CPath[CDepth]);
      if (PrevDepth = CDepth) then
      begin
        AddPos := True;
      end;
    end
    else ChooseNewBranch := False;
  end;
end;


function TBoard.TestBranch({$IFDEF Step4}const{$ENDIF} CPath: TKnightPath;
  {$IFDEF Step4}const{$ENDIF} CDepth: Byte): Boolean;
{ Tests the current branch. If it is valid the function returns True,
  otherwise it returns False }
var X, Y, Depth: Integer;
  TestPassed: Boolean;
begin
  Inc(BranchesNumber);

  {$IFNDEF Step6}
  If ShowBranchInfo then DrawBranchInfo;
  {$ENDIF}

  TestPassed := True;

  {$IFDEF Step5}
  if AddPos and (CDepth>1) then
  begin
    X := LastPos.X + KnightMoves[CPath[CDepth]].DX;
    Y := LastPos.Y - KnightMoves[CPath[CDepth]].DY;
    if (X >= 1) and (X <= NumLines) and (Y >= 1) and (Y <= NumLines)
      and (ChessBoard[X, Y] = 0) then
    begin
      ChessBoard[X, Y] := CDepth + 1;
    end
    else
      TestPassed := False;
  end
  else
  begin
  {$ENDIF}

    {$IFDEF Step7}
    for Y := 1 to NumLines do
      for X := 1 to NumLines do
      begin
        ChessBoard[X, Y] := 0;
      end;
    {$ELSE}
    ChessBoardZeroing;
    {$ENDIF}

    ChessBoard[StartPos.X, StartPos.Y] := 1;
    X := StartPos.X;
    Y := StartPos.Y;
    for Depth := 1 to CDepth do
    begin
      X := X + KnightMoves[CPath[Depth]].DX;
      Y := Y - KnightMoves[CPath[Depth]].DY;
      if (X >= 1) and (X <= NumLines) and (Y >= 1) and (Y <= NumLines)
        and (ChessBoard[X, Y] = 0) then
      begin
        ChessBoard[X, Y] := Depth + 1;
        LastPos.X := X;
        LastPos.Y := Y;
      end
      else
      begin
        TestPassed := False;
        break;
      end;
    end;
  {$IFDEF Step5}
  end;
  {$ENDIF}

  TestBranch := TestPassed;
  if TestPassed then
  begin
    LastPos.X := X;
    LastPos.Y := Y;
    {$IFDEF Step6}
    if ShowBranchInfo then DrawBranchInfo;
    {$ENDIF}
    if NeedWriteToFile then WriteToFile;

    if ShowGraphics then {$IFDEF Step2}SmartPaint;
                         {$ELSE}BoardPaint;
                         {$ENDIF}
    if MovesDelay > 0 then Delay{Sleep}(MovesDelay);
  end;
end;


procedure TBoard.Stop;
{ Sets the CalcStop variable to True to stop calculations }
begin
  CalcStop := True;
end;


procedure TBoard.OutCalcTime(ShowMSec: Boolean);
{ Idicates the calculation time }
var
  Present: DWORD;
  Hour, Min, Sec, MSec: Word;
  S: String;
begin
  Present := GetTickCount - StartTime;

  Hour := Present div (60*60 *3600);
  Present := Present - Hour * (60*60 *3600);
  Min := Present div (60 *3600);
  Present := Present - Min * (60 *3600);
  Sec := Present div 3600;
  Present := Present - Sec * (3600);
  MSec := Present;

  S := 'Calculation Time: ';
  if (Hour > 0) then S := S + IntToStr(Hour) + ' h ';
  if (Min > 0) then S := S + IntToStr(Min) + ' m ';
  if (Sec > 0) then S := S + IntToStr(Sec) + ' s ';
  if ShowMSec and (MSec > 0) then S := S + IntToStr(MSec) + ' ms ';

  Frm_Knight.Lbl_CalcTime.Caption := S;
end;


procedure TBoard.Go;
{ Executes calculations }
var NewBranchPossible, GoFarther: Boolean;
    S: String;
begin
  { The initial settings of the procedure }
  Initialize;
  CurDepth := 0;
  StartTime := GetTickCount;
  Frm_Knight.Timer_CalcTime.Enabled := True;
  Frm_Knight.DeselectStartPosMode;
  Frm_Knight.Cursor := crHourGlass;
  Working := True;
  LastPos := StartPos;
  GoFarther := True;
  CalcStop := False;

  { The branch searching and analysis. }
  repeat
    NewBranchPossible := ChooseNewBranch(GoFarther, CurKnightPath,
      CurDepth);
    GoFarther := TestBranch(CurKnightPath, CurDepth);
    Application.ProcessMessages;

    if GoFarther then
    { The current branch is valid. }
    begin
      if (CurDepth >= MaxDepth) then
      { The decision is found. }
      begin
        if (CurDepth > MaxDepth) then
        { The old list of decisions is not valid. }
        begin
          if NeedWriteToFileMax then Rewrite(FBranchMax);
          NumDecisions := 0;
          Frm_Knight.Cmb_Decisions.Items.Clear;
          DecisionsList.Clear;
        end;

        MaxKnightPath := CurKnightPath;
        MaxDepth := CurDepth;

        if NeedWriteToFileMax then WriteToFileMax;
        DrawBranchNum;

        Inc(NumDecisions);

        Frm_Knight.Cmb_Decisions.Items.Add(IntToStr(NumDecisions));
        DecisionsList.Add(CalcBranch(CurKnightPath, CurDepth));

        DrawDecisions;
        {$IFDEF Step2}
        SmartPaint;
        {$ELSE}
        BoardPaint;
        {$ENDIF}
      end;
    end;

    if CalcStop then NewBranchPossible := False;
  until not NewBranchPossible;

  { The final operations }
  Frm_Knight.Timer_CalcTime.Enabled := False;
  OutCalcTime(True);
  DrawBranchNum;
  MessageBeep(0);
  Working := False;
  Frm_Knight.Cursor := crDefault;
  Frm_Knight.Cmb_Decisions.ItemIndex := 0;
  Frm_Knight.Btn_Go.Caption := 'Start';
  BoardPaint;
  UserRating := UserRating mod 11;
  Case Round(20/(10-UserRating)) of
    2..3: S := 'Low';
    4..6: S := 'Medium';
    7..20: S := 'High';
  end;
  Frm_Knight.Lbl_CalcTime.Caption := Frm_Knight.Lbl_CalcTime.Caption +
    ' Activity Rating: ' + S;
end;


procedure TBoard.DrawDecisions;
{ Displays information about desisions }
begin
  Frm_Knight.Lbl_Infill.Caption := 'Infill: ' + IntToStr(MaxDepth+1);
  Frm_Knight.Lbl_NumDecisions.Caption := 'Decisions Number: ' +
    IntToStr(NumDecisions);
end;


procedure TBoard.AnimMove(Num: Integer; XSt, YSt, XFin, YFin: Integer);
{ Performes animated transition from the cell with (XSt, YSt) coordinates to
  the cell with (XFin, YFin) coordinates }
var CellRect: TRect;
    X_Sc, X_Sc_St, X_Sc_Fin, Y_Sc, Y_Sc_St, Y_Sc_Fin, XYStep: Integer;
    {$IFDEF Step3} MemBitmap: TBitmap; {$ENDIF}
    NewColor: TColor;

  procedure DrawAnimBitmap;
  { Draws the image }
  begin
  {$IFDEF Step3}

    BitBlt(CellBitmap.Canvas.Handle, 0, 0, CellSide, CellSide,
      MemBitmap.Canvas.Handle, CellRect.Left, CellRect.Top, SRCCOPY);

    CellBitmap.Canvas.Brush.Color := NewColor; // Pattern
    // Pattern^Destination
    BitBlt(CellBitmap.Canvas.Handle, 0, 0, CellSide, CellSide,
      CellBitmap.Canvas.Handle, 0, 0, PATINVERT);
    // Source&Destination
    BitBlt(CellBitmap.Canvas.Handle, 0, 0, CellSide, CellSide,
      KnightBitmap.Canvas.Handle, 0, 0, SRCAND);
    // Pattern^Destination
    BitBlt(CellBitmap.Canvas.Handle, 0, 0, CellSide, CellSide,
      CellBitmap.Canvas.Handle, 0, 0, PATINVERT);

    BitBlt(Frm_Knight.Pbx_ChessBoard.Canvas.Handle, CellRect.Left, CellRect.Top,
      CellSide-3, CellSide-3, CellBitmap.Canvas.Handle,
      0, 0, SRCCOPY);
  {$ELSE}
    Board.BoardPaint;

    CellBitmap.LoadFromFile('Knight2.bmp');
    CellBitmap.Monochrome := False;
    CellBitmap.Canvas.Brush.Color := NewColor;
    CellBitmap.Transparent := True;
    CellBitmap.Canvas.FloodFill(CellBitmap.Width div 2, CellBitmap.Height div 2,
      clBlack, fsSurface);
    Frm_Knight.Pbx_ChessBoard.Canvas.StretchDraw(CellRect, CellBitmap);
  {$ENDIF}
  end;


begin
  NewColor := GetCellColor(Num);
  if CellSide < 70 then XYStep := 1 else XYStep := 2;

  {$IFDEF Step3}
  MemBitmap := TBitmap.Create;
  MemBitmap.Height := Frm_Knight.Pbx_ChessBoard.Height;
  MemBitmap.Width := Frm_Knight.Pbx_ChessBoard.Width;

  BitBlt(MemBitmap.Canvas.Handle, 0, 0, Frm_Knight.Pbx_ChessBoard.Width,
    Frm_Knight.Pbx_ChessBoard.Height,
    Frm_Knight.Pbx_ChessBoard.Canvas.Handle, 0, 0, SRCCOPY);
  {$ENDIF}

  X_Sc_St := (XSt-1)*CellSide + 2;
  X_Sc_Fin := (XFin-1)*CellSide + 2;

  Y_Sc_St := (YSt-1)*CellSide + 2;
  Y_Sc_Fin := (YFin-1)*CellSide + 2;

  { Horizontal movement }
  X_Sc := X_Sc_St;
  while True do
  begin
    CellRect := Rect(X_Sc, Y_Sc_St, X_Sc + CellSide-3, Y_Sc_St + CellSide-3);

    DrawAnimBitmap;

    Delay(2*(Frm_Knight.Tbr_Playspeed.Position));
    if X_Sc = X_Sc_Fin then break;
    if X_Sc_Fin > X_Sc_St then
    begin
      Inc(X_Sc, XYStep);
      if X_Sc_Fin < X_Sc then X_Sc := X_Sc_Fin;
    end
    else
    begin
      Dec(X_Sc, XYStep);
      if X_Sc_Fin > X_Sc then X_Sc := X_Sc_Fin;
    end;
    Application.ProcessMessages;
  end;

  { Vertical movement }
  Y_Sc := Y_Sc_St;
  while True do
  begin
    CellRect := Rect(X_Sc_Fin, Y_Sc, X_Sc_Fin + CellSide-3, Y_Sc + CellSide-3);

    DrawAnimBitmap;

    Delay(2*(Frm_Knight.Tbr_Playspeed.Position));
    if Y_Sc = Y_Sc_Fin then break;
    if Y_Sc_Fin > Y_Sc_St then
    begin
      Inc(Y_Sc, XYStep);
      if Y_Sc_Fin < Y_Sc then Y_Sc := Y_Sc_Fin;
    end
    else
    begin
      Dec(Y_Sc, XYStep);
      if Y_Sc_Fin > Y_Sc then Y_Sc := Y_Sc_Fin;
    end;
    Application.ProcessMessages;
  end;

  {$IFDEF Step3}
  BitBlt(Frm_Knight.Pbx_ChessBoard.Canvas.Handle, 0, 0,
    Frm_Knight.Pbx_ChessBoard.Width, Frm_Knight.Pbx_ChessBoard.Height,
    MemBitmap.Canvas.Handle, 0, 0, SRCCOPY);
  MemBitmap.Free;
  {$ENDIF}
end;


procedure TBoard.PlayDecision;
{ Plays back the chosen decision }
var CmbPos: Integer;
  Path: TKnightPath;
  Depth, X, Y, XP, YP, D: Integer;
begin
  Working := True;
  CmbPos := StrToInt(string(Frm_Knight.Cmb_Decisions.Text));

  ChessBoardZeroing;
  BoardResize;
  SetStartPos(StartPos.X, StartPos.Y);
  DrawDecisions;
  DrawBranchNum;

  Depth := 0;
  while Depth<Length(DecisionsList[CmbPos]) do
  begin
    Inc(Depth);
    Path[Depth] := StrToInt(DecisionsList[CmbPos][Depth]);
  end;

  X := StartPos.X;
  Y := StartPos.Y;
  for D := 1 to Depth do
  begin
    XP := X;
    YP := Y;
    X := X + KnightMoves[Path[D]].DX;
    Y := Y - KnightMoves[Path[D]].DY;
    if Frm_Knight.Chb_Animate.Checked then AnimMove(D, XP, YP, X, Y);
    ChessBoard[X, Y] := D + 1;
    SetCellToNumber(X, Y, D+1);
    Delay(60*(Frm_Knight.Tbr_Playspeed.Max - Frm_Knight.Tbr_Playspeed.Position));
    Application.ProcessMessages;
  end;

  Working := False;
  MessageBeep(MB_OK);
end;


procedure TBoard.DecisionsClick;
{ A warning message }
begin
  if Working then
    MessageBox(Frm_Knight.Handle, 'The application is making calculations',
      'Knight', MB_ICONEXCLAMATION);
end;


{ TFrm_Knight }

procedure TFrm_Knight.FormCreate(Sender: TObject);
{ Creates, initializes and resizes the board }
begin
  UserRating := 0;
  Board := TBoard.Create;
  Board.Initialize;
  Board.SetStartPos(1, 1);
  Board.BoardResize;
  FBoard := Board; // don't remove this line
end;


procedure TFrm_Knight.Pbx_ChessBoardPaint(Sender: TObject);
{ Draws the board }
begin
  Board.BoardPaint;
end;


procedure TFrm_Knight.DeselectStartPosMode;
{ Turns off SelectStartPosMode }
begin
  Board.SelectStartPosMode := False;
  Cursor := crDefault;
end;


procedure TFrm_Knight.SelectStartPosition1Click(Sender: TObject);
{ Turns on SelectStartPosMode }
begin
  Inc(UserRating);
  if not Board.Working then
  begin
    Board.Initialize;
    Pbx_ChessBoardPaint(nil);
    Board.SelectStartPosMode := True;
    Cursor := crCross;
  end
  else
    MessageBox(Handle, 'The application is making calculations', 'Knight',
      MB_ICONEXCLAMATION);
end;


procedure TFrm_Knight.Pbx_ChessBoardMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
{ Selects the start position according to the cell where the mouse click occurred }
var YY, XX: Integer;
begin
  Inc(UserRating);
  if (Board.SelectStartPosMode) and (Button = mbLeft) then
  begin
    YY := 1 + X div Board.CellSide;
    XX := 1 + Y div Board.CellSide;
    if (Board.StartPos.X <> XX) or (Board.StartPos.Y <> Y) then
      Board.SetStartPos(XX, YY);
    DeselectStartPosMode;
  end;
end;


procedure TFrm_Knight.Go1Click(Sender: TObject);
{ Starts calculating }
begin
  Inc(UserRating);
  File1.Enabled := False;
  if not Board.Working then
  begin
    Btn_Go.Caption := 'Stop';
    Board.Go;
  end;
  Btn_Go.Caption := 'Start';
  File1.Enabled := True;
end;


procedure TFrm_Knight.Btn_GoClick(Sender: TObject);
{ Calls the Go1Click procedure }
begin
  Inc(UserRating);
  if not Board.Working then Go1Click(nil)
  else Board.Stop;
end;


procedure TFrm_Knight.Options1Click(Sender: TObject);
{ Calls the Options dialog }
begin
  Inc(UserRating);
  Board.GetOptions;
end;


procedure TFrm_Knight.About1Click(Sender: TObject);
{ Calls the About dialog }
begin
  Inc(UserRating);
  DeselectStartPosMode;
  Frm_About.ShowModal;
end;


procedure TFrm_Knight.FormClose(Sender: TObject; var Action: TCloseAction);
{ Stops calculating and closes the application }
begin
  Board.Stop;
end;


procedure TFrm_Knight.Clear1Click(Sender: TObject);
{ Clears the board }
begin
  Inc(UserRating);
  Board.Initialize;
  Board.BoardResize;
end;


procedure TFrm_Knight.PlayDecisions1Click(Sender: TObject);
{ Plays back the decisions }
begin
  Inc(UserRating);
  if MessageBox(Handle, 'There are no results! Choose OK to start ' +
    'calculating and Cancel to escape.',
    'Knight', MB_ICONQUESTION or MB_OKCANCEL) = IDOK
  then
    Go1Click(nil);
end;


procedure TFrm_Knight.Btn_PlayClick(Sender: TObject);
{ Plays back the decisions }
begin
  Inc(UserRating);
  if not Board.Working then
  begin
    if (Cmb_Decisions.Text <> '') then
    begin
      File1.Enabled := False;
      Btn_Play.Enabled := False;
      Board.PlayDecision;
      Btn_Play.Enabled := True;
      File1.Enabled := True;
    end
    else
    begin
      if (Board.NumDecisions > 0) then // List is not empty
        MessageBox(Handle, 'Choose a number from list!', 'Knight',
          MB_ICONEXCLAMATION)
      else
      begin
        if MessageBox(Handle, 'There are no results! Choose OK to start ' +
          'calculating and Cancel to escape.',
          'Knight', MB_ICONQUESTION or MB_OKCANCEL) = IDOK
        then
          Go1Click(nil);
      end
    end
  end
  else
    MessageBox(Handle, 'The application is making calculations', 'Knight',
      MB_ICONEXCLAMATION);
end;


procedure TFrm_Knight.Cmb_DecisionsClick(Sender: TObject);
{ A warning message }
begin
  Inc(UserRating);
  Board.DecisionsClick;
end;


procedure TFrm_Knight.FormDestroy(Sender: TObject);
{ Destroys the board }
begin
  Board.Destroy;
end;


procedure TFrm_Knight.Timer_CalcTimeTimer(Sender: TObject);
{ Indicates the calculation time }
begin
  Board.OutCalcTime(False);
end;


procedure TFrm_Knight.Exit1Click(Sender: TObject);
begin
  Inc(UserRating);
end;

end.

