unit UOptions;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Buttons, Spin, UKnight, ExtCtrls;

type
  TFrm_Options = class(TForm)
    Btn_OK: TBitBtn;
    Btn_Cancel: TBitBtn;
    Label1: TLabel;
    Spin_NumLines: TSpinEdit;
    Label2: TLabel;
    Chk_ShowBranchInfo: TCheckBox;
    Label3: TLabel;
    Spin_CellSide: TSpinEdit;
    Chk_ShowGraphics: TCheckBox;
    Spin_MovesDelay: TSpinEdit;
    Chk_WriteBranchesToFile: TCheckBox;
    Chk_WriteMaxBranchesToFile: TCheckBox;
    RdGr_ViewMode: TRadioGroup;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Frm_Options: TFrm_Options;

implementation

{$R *.DFM}

end.
