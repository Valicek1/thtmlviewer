object AboutBox: TAboutBox
  Left = 286
  Top = 214
  BorderIcons = [biSystemMenu]
  Caption = 'About'
  ClientHeight = 231
  ClientWidth = 367
  Color = clBtnFace
  Constraints.MinHeight = 265
  Constraints.MinWidth = 375
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'System'
  Font.Style = []
  OldCreateOrder = True
  Position = poScreenCenter
  DesignSize = (
    367
    231)
  PixelsPerInch = 96
  TextHeight = 16
  object BitBtn1: TBitBtn
    Left = 284
    Top = 198
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    TabOrder = 0
    Kind = bkOK
    ExplicitLeft = 225
    ExplicitTop = 147
  end
  object Viewer: THTMLViewer
    Left = 8
    Top = 8
    Width = 352
    Height = 180
    ViewImages = False
    Enabled = False
    TabOrder = 1
    Anchors = [akLeft, akTop, akRight, akBottom]
    BorderStyle = htNone
    HistoryMaxCount = 0
    DefFontName = 'Times New Roman'
    DefPreFontName = 'Courier New'
    NoSelect = True
    ScrollBars = ssNone
    CharSet = DEFAULT_CHARSET
    PrintMarginLeft = 2.000000000000000000
    PrintMarginRight = 2.000000000000000000
    PrintMarginTop = 2.000000000000000000
    PrintMarginBottom = 2.000000000000000000
    PrintScale = 1.000000000000000000
    htOptions = []
    ExplicitHeight = 201
  end
end
