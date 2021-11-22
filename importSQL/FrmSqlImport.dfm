object FSQLImport: TFSQLImport
  Left = 0
  Top = 0
  Caption = 'SQLServer'#23548#20837
  ClientHeight = 501
  ClientWidth = 674
  Color = clBtnFace
  DoubleBuffered = True
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
  object Label1: TLabel
    Left = 120
    Top = 208
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object Label2: TLabel
    Left = 120
    Top = 240
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object Label3: TLabel
    Left = 120
    Top = 272
    Width = 31
    Height = 13
    Caption = 'Label1'
  end
  object Button1: TButton
    Left = 120
    Top = 80
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 0
  end
  object Timer1: TTimer
    Enabled = False
    OnTimer = Timer1Timer
    Left = 416
    Top = 192
  end
end
