object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'Form2'
  ClientHeight = 592
  ClientWidth = 739
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
  object PageControl1: TPageControl
    Left = 8
    Top = 8
    Width = 713
    Height = 505
    ActivePage = TabSheet1
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'Elec'
      ExplicitLeft = 0
      ExplicitTop = 0
      ExplicitWidth = 0
      ExplicitHeight = 0
      object Button1: TButton
        Left = 24
        Top = 16
        Width = 75
        Height = 25
        Caption = 'create'
        TabOrder = 0
        OnClick = Button1Click
      end
      object Memo1: TMemo
        Left = 24
        Top = 75
        Width = 369
        Height = 350
        Lines.Strings = (
          'Memo1')
        TabOrder = 1
      end
      object Button2: TButton
        Left = 186
        Top = 16
        Width = 75
        Height = 25
        Caption = 'retrieve'
        TabOrder = 2
        OnClick = Button2Click
      end
      object Button3: TButton
        Left = 267
        Top = 17
        Width = 75
        Height = 25
        Caption = 'Delete'
        TabOrder = 3
      end
      object Button4: TButton
        Left = 105
        Top = 17
        Width = 75
        Height = 25
        Caption = 'add'
        TabOrder = 4
        OnClick = Button4Click
      end
      object Edit1: TEdit
        Left = 24
        Top = 48
        Width = 237
        Height = 21
        TabOrder = 5
        Text = 'Edit1'
      end
    end
  end
  object OpenDialog1: TOpenDialog
    Left = 556
    Top = 48
  end
end
