object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 600
  ClientWidth = 740
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlD3dCanvas: TPanel
    Left = 0
    Top = 0
    Width = 740
    Height = 600
    Align = alClient
    Caption = 'pnlD3dCanvas'
    TabOrder = 0
  end
end
