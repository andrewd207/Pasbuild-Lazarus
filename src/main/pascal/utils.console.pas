{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

// This unit provides simple cross-platform console output helpers for
// colored text, tagged log messages, and wrapped text formatting.

unit utils.console;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fgl
  {$IFDEF WINDOWS}
  ,Windows
  {$ELSE}
  ,BaseUnix, TermIO
  {$ENDIF};

type
  TSimpleColor = (
    scResetAll = 0,
    scBlack = 30,
    scRed = 31,
    scGreen = 32,
    scYellow = 33,
    scBlue = 34,
    scMagenta = 35,
    scCyan = 36,
    scWhite = 37,
    scBrightBlack = 90,
    scBrightRed = 91,
    scBrightGreen = 92,
    scBrightYellow = 93,
    scBrightBlue = 94,
    scBrightMagenta = 95,
    scBrightCyan = 96,
    scBrightWhite = 97
  );

  { TTagColorMap }

  TTagColorMap = class(specialize TFPGMap<String, TSimpleColor>)
  private
    class var FInstance: TTagColorMap;
  public
    class procedure RegisterMap(ATag: String; AColor: TSimpleColor);
    class function  FindColor(ATag: String): TSimpleColor;
    class constructor Create;
    class destructor Destroy;
  end;

procedure LogInfo(const AMessage: String);
procedure LogError(const AMessage: String);
procedure LogWarning(const AMessage: String);
procedure LogSuccess(const AMessage: String);
procedure LogTag(const ATag: String; const AMessage: String; var AFile: Text);
procedure LogTag(const ATag: String; const AMessage: String);

procedure WriteWrappedText(AIndent: Integer; const AText: string);

procedure WriteColor(AColor: TSimpleColor; const AText: String; var AFile: Text);

function  StdOutIsConsole: Boolean;

implementation

{$IFDEF WINDOWS}

var
  GScreenAttributes: Word;
  GStdOutIsConsole: Integer = MaxInt;

function AnsiToWinColor(Color: Integer): WORD;
begin
  case Color of
    30: Result := 0;                                 // Black
    31: Result := FOREGROUND_RED;                    // Red
    32: Result := FOREGROUND_GREEN;                  // Green
    33: Result := FOREGROUND_RED or FOREGROUND_GREEN;// Yellow
    34: Result := FOREGROUND_BLUE;                   // Blue
    35: Result := FOREGROUND_RED or FOREGROUND_BLUE; // Magenta
    36: Result := FOREGROUND_GREEN or FOREGROUND_BLUE; // Cyan
    37: Result := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE; // White

    90: Result := FOREGROUND_INTENSITY;              // Bright Black (Gray)
    91: Result := FOREGROUND_RED or FOREGROUND_INTENSITY;
    92: Result := FOREGROUND_GREEN or FOREGROUND_INTENSITY;
    93: Result := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_INTENSITY;
    94: Result := FOREGROUND_BLUE or FOREGROUND_INTENSITY;
    95: Result := FOREGROUND_RED or FOREGROUND_BLUE or FOREGROUND_INTENSITY;
    96: Result := FOREGROUND_GREEN or FOREGROUND_BLUE or FOREGROUND_INTENSITY;
    97: Result := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE or FOREGROUND_INTENSITY;

    else Result := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE; // Default (White)
  end;
end;


procedure WriteColor(AColor: TSimpleColor; const AText: String; var AFile: Text);
var
  lColor: Word;
begin
  if not StdOutIsConsole then
  begin
    Write(AFile, AText);
    Exit; // no fun stuff for redirected output
  end;
  lColor := AnsiToWinColor(Ord(AColor));
  SetConsoleTextAttribute(StdOutputHandle, lColor);
  Write(AFile, AText);
  // restore default
  SetConsoleTextAttribute(StdOutputHandle, GScreenAttributes);
end;

function StdOutIsConsole: Boolean;
var
  Mode: DWord;
  lConsoleInfo: TCONSOLESCREENBUFFERINFO;
begin
  if  GStdOutIsConsole = MaxInt then
  begin
    GStdOutIsConsole := Integer(GetConsoleMode(StdOutputHandle, Mode));
    // also get the default colors
    if GStdOutIsConsole <> 0 then
    begin
      GetConsoleScreenBufferInfo(StdOutputHandle, lConsoleInfo);
      GScreenAttributes:=lConsoleInfo.wAttributes;
    end;
  end;

  Result := GStdOutIsConsole = 1;
end;

{$ELSE}

var
  GStdOutIsConsole: Integer = MaxInt;

procedure WriteColor(AColor: TSimpleColor; const AText: String; var AFile: Text);
var
  Col: String;
const
  ESC = #27;
begin
  Col := IntToStr(Ord(AColor));
  if StdOutIsConsole then
      Write(AFile, ESC+'['+Col+'m'+AText +ESC+'[0m')
    else
      Write(AFile, AText);
end;

function StdOutIsConsole: Boolean;
begin
  Exit (True);
  if GStdOutIsConsole = MaxInt then
  begin
    GStdOutIsConsole := IsATTY(StdOut);
  end;

  Result := GStdOutIsConsole <> 0;
end;

{$ENDIF}


function GetTerminalWidth: Integer; forward;

procedure LogInfo(const AMessage: String);
begin
  LogTag('[INFO]', AMessage, StdErr);
end;

procedure LogError(const AMessage: String);
begin
  LogTag('[ERROR]', AMessage, StdErr);
end;

procedure LogWarning(const AMessage: String);
begin
  LogTag('[WARNING]', AMessage);
end;

procedure LogSuccess(const AMessage: String);
begin
  LogTag('[SUCCESS]', AMessage);
end;

procedure LogTag(const ATag: String; const AMessage: String; var AFile: Text);
var
  Color: TSimpleColor;
begin
  Color := TTagColorMap.FindColor(ATag);
  WriteColor(Color, ATag, AFile);
  WriteLn(AFile, ' '+AMessage);
end;

procedure LogTag(const ATag: String; const AMessage: String);
begin
  LogTag(ATag, AMessage, StdOut);
end;

procedure WriteWrappedText(AIndent: Integer; const AText: string);
var
  TermWidth: Integer;
  MaxTextWidth: Integer;
  S: string;
  P: Integer;
  Pad: string;
begin
  TermWidth := GetTerminalWidth;
  if TermWidth <= 0 then
    TermWidth := 80;

  Pad := StringOfChar(' ', AIndent);
  MaxTextWidth := TermWidth - AIndent;
  if MaxTextWidth < 10 then
    MaxTextWidth := 10;

  S := AText;

  while Length(S) > MaxTextWidth do
  begin
    P := MaxTextWidth;
    while (P > 1) and (S[P] <> ' ') do
      Dec(P);

    if P = 1 then
      P := MaxTextWidth;

    WriteLn(Pad + Copy(S, 1, P));
    Delete(S, 1, P);

    while (Length(S) > 0) and (S[1] = ' ') do
      Delete(S, 1, 1);
  end;

  WriteLn(Pad + S);
end;

{$IFDEF UNIX}
function GetTerminalWidth: Integer;
type
  TWinsize = packed record
    ws_row: Word;
    ws_col: Word;
    ws_xpixel: Word;
    ws_ypixel: Word;
  end;
var
  ws: TWinsize;
begin
  if fpIOCtl(StdInputHandle, TIOCGWINSZ, @ws) = 0 then
    Result := ws.ws_col
  else
    Result := 0;
end;

{ TTagColorMap }

class procedure TTagColorMap.RegisterMap(ATag: String; AColor: TSimpleColor);
begin
  FInstance.Add(ATag, AColor);
end;

class function TTagColorMap.FindColor(ATag: String): TSimpleColor;
var
  lIndex: Integer;
begin
  if FInstance.Find(ATag, lIndex) then
    Result := FInstance.Data[lIndex]
  else
    Result := scWhite;
end;

class constructor TTagColorMap.Create;
begin
  FInstance := TTagColorMap.Create;
  FInstance.Sorted:=True;
  FInstance.Duplicates:=dupIgnore;

  RegisterMap('[ERROR]', scBrightRed);
  RegisterMap('[INFO]', scBrightBlue);
  RegisterMap('[WARNING]', scBrightWhite);
  RegisterMap('[WARN]', scBrightYellow);
  RegisterMap('[SUCCESS]', scBrightGreen);
end;

class destructor TTagColorMap.Destroy;
begin
  FInstance.Free;
end;

{$ELSE}
function GetTerminalWidth: Integer;
begin
  Result := 80;
end;
{$ENDIF}


end.

