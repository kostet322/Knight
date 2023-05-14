unit UAbout;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TFrm_About = class(TForm)
    Btn_OK: TButton;
    Memo1: TMemo;
    Lbl_Registered: TLabel;
    procedure Btn_OKClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Frm_About: TFrm_About;

implementation

{$R *.DFM}

procedure TFrm_About.Btn_OKClick(Sender: TObject);
begin
  Close;
end;

procedure TFrm_About.FormCreate(Sender: TObject);
var RegisteredUser: Boolean;
    S: String;
begin
  S := Copy('Unregistered version. Please register!', 1, 40);
  if RegisteredUser then
    Delete(S, 1, 23);
    Insert('Registered version', S, 0);
  Lbl_Registered.Caption := S;
end;

end.
