{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

{
  This unit manages PasBuild-Lazarus configuration settings. It uses
  attributes on published properties to provide defaults and help
  text, then loads and saves the config as JSON.
}
unit pasbuild.config;

{$mode ObjFPC}{$H+}
{$ModeSwitch prefixedattributes}

interface

uses
  Classes, SysUtils,

  fpJson, TypInfo, Rtti, fpJsonRtti, Utils.console;


const
  CDefaultUseInstalled = True;
  {$IFDEF WINDOWS}
  CDefaultInstalledFolder = 'C:\Users\$user\.pasbuild\';
  {$ELSEIF  Defined(MACOSX)}
  CDefaultInstalledFolder = '/Users/$user/.pasbuild//';
  {$ELSE}
  CDefaultInstalledFolder = '/home/$user/.pasbuild/';
  {$ENDIF}
  CDefaultUsePasbuildToCompile = True;


const
  TermWidth: Integer = 80;

type

  { TTextAttr }


  // For values to describe and explain
  TTextAttr = class(TCustomAttribute)
  private
    FValue: String;
  published
    property Value: String read FValue;
  public
    constructor Create(AValue: String);
  end;

  { TTypeKindAttr }

  // base value to hold a default for a setting
  TPropAttr = class(TCustomAttribute); // to search

  { TTypeAttr }

  generic TTypeAttr<T> = class(TPropAttr)
  private
    FValue: T;
    function GetKind: TTypeKind;
  public
    property Kind: TTypeKind read GetKind;
    property Value: T read FValue;
    constructor Create(AValue: T);
  end;

  BoolAttr = specialize TTypeAttr<Boolean>;
  StringAttr = specialize TTypeAttr<String>;



  DescAttr = class(TTextAttr);
  NameAttr = class(TTextAttr);



  { TConfig }

  TConfig = class
  private
    FModified: Boolean;
    FbaseInstalledLocation: String;
    FPreferInstalledLocation: Boolean;
    FusePasbuildToCompile: Boolean;
    procedure ApplyDefaults;
    procedure SetbaseInstalledLocation(AValue: String);
    procedure SetpreferInstalledLocation(AValue: Boolean);
    procedure SetusePasbuildToCompile(AValue: Boolean);
  public
    function  GetValue(APath: String): String;
    procedure SetValue(APath: String; AValue: String);
    procedure DisplayConfig;

    procedure LoadConfig(AFile: String);
    procedure SaveConfig(AFile: String);
    property Modified: Boolean read FModified write FModified;

  published
    [DescAttr('Generated packages use compiled files (ppu''s) from installed pasbuild folder. False means use the local target folder. ')]
    [BoolAttr(CDefaultUseInstalled)]
    property preferInstalledLocation: Boolean read FPreferInstalledLocation write SetpreferInstalledLocation;

    [DescAttr('PasBuild user/global folder. Contains "repository" and "plugins". Not used if preferInstalledLocation is FALSE')]
    [StringAttr(CDefaultInstalledFolder)]
    property baseInstalledLocation: String read FbaseInstalledLocation write SetbaseInstalledLocation;

    [DescAttr('Use Pasbuild to compile project/library instead of Lazarus''s build system. See Project -> Project Options -> Compiler Commands')]
    [BoolAttr(CDefaultUsePasbuildToCompile)]
    property usePasbuildToCompile: Boolean read FusePasbuildToCompile write SetusePasbuildToCompile;
  end;

var GConfig: TConfig;

function ResolveEnvString(const AString: String): String;

implementation

function ResolveEnvString(const AString: String): String;
var
  I, StartPos: Integer;
  VarName, VarValue: String;
begin
  Result := '';
  I := 1;

  while I <= Length(AString) do
  begin
    if AString[I] = '$' then
    begin
      Inc(I);
      StartPos := I;

      while (I <= Length(AString)) and (AString[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
        Inc(I);

      VarName := Copy(AString, StartPos, I - StartPos);

      if VarName <> '' then
      begin
        VarValue := GetEnvironmentVariable(VarName);
        if VarValue = '' then
          VarValue:=GetEnvironmentVariable(UpperCase(VarName));
        if VarValue = '' then
          VarValue:=GetEnvironmentVariable(LowerCase(VarName));
        Result := Result + VarValue;
      end
      else
        Result := Result + '$';
    end
    else
    begin
      Result := Result + AString[I];
      Inc(I);
    end;
  end;
end;

{ TTextAttr }

constructor TTextAttr.Create(AValue: String);
begin
  FValue:=AValue;
end;

{ TTypeAttr }

function TTypeAttr.GetKind: TTypeKind;
begin
  Result := GetTypeKind(T);
end;

constructor TTypeAttr.Create(AValue: T);
begin
  FValue:=AValue;
end;

{ TConfig }

procedure TConfig.SetbaseInstalledLocation(AValue: String);
begin
  if FbaseInstalledLocation=AValue then Exit;
  FbaseInstalledLocation:=AValue;
  FModified:=True;
end;

procedure TConfig.SetpreferInstalledLocation(AValue: Boolean);
begin
  if FPreferInstalledLocation=AValue then Exit;
  FPreferInstalledLocation:=AValue;
  FModified:=True;
end;

procedure TConfig.SetusePasbuildToCompile(AValue: Boolean);
begin
  if FusePasbuildToCompile=AValue then Exit;
  FusePasbuildToCompile:=AValue;
  Modified:=True;
end;

function TConfig.GetValue(APath: String): String;
var
  lContext: TRttiContext;
  lType: TRttiType;
  lProp: TRttiProperty;
  lValue: TValue;
begin
  Result := '';

  lContext := TRttiContext.Create;
  try
    lType := lContext.GetType(ClassType);
    lProp := lType.GetProperty(APath);

    if lProp = nil then
      raise Exception.CreateFmt('Unknown config property: %s', [APath]);

    if not lProp.IsReadable then
      raise Exception.CreateFmt('Config property is not readable: %s', [APath]);

    lValue := lProp.GetValue(Self);

    case lValue.Kind of
      tkBool:
        if lValue.AsBoolean then
          Result := 'TRUE'
        else
          Result := 'FALSE';

      tkAString, tkLString, tkWString, tkUString:
        Result := lValue.AsString;
    else
      Result := lValue.ToString;
    end;
  finally
    lContext.Free;
  end;
end;

procedure TConfig.SetValue(APath: String; AValue: String);
var
  lContext: TRttiContext;
  lType: TRttiType;
  lProp: TRttiProperty;
  lKind: TTypeKind;
  lBool: Boolean;
begin
  lContext := TRttiContext.Create;
  try
    lType := lContext.GetType(ClassType);
    lProp := lType.GetProperty(APath);

    if lProp = nil then
      raise Exception.CreateFmt('Unknown config property: %s', [APath]);

    if not lProp.IsWritable then
      raise Exception.CreateFmt('Config property is not writable: %s', [APath]);

    lKind := lProp.PropertyType.TypeKind;

    case lKind of
      tkBool:
        begin
          if SameText(AValue, 'TRUE') or SameText(AValue, '1') or SameText(AValue, 'YES') then
            lBool := True
          else if SameText(AValue, 'FALSE') or SameText(AValue, '0') or SameText(AValue, 'NO') then
            lBool := False
          else
            raise Exception.CreateFmt('Invalid boolean value for %s: %s', [APath, AValue]);

          lProp.SetValue(Self, lBool);
        end;

      tkAString, tkLString, tkWString, tkUString:
        lProp.SetValue(Self, AValue);
    else
      raise Exception.CreateFmt('Unsupported property type for %s', [APath]);
    end;
  finally
    lContext.Free;
  end;
end;




procedure TConfig.DisplayConfig;
var
  lContext: TRttiContext;
  lType: TRttiType;
  lProp: TRttiProperty;
  lAttr: TCustomAttribute;
  lDesc: String;
  lDefaultValue: String;
  lCurrentValue: TValue;
  lCurrentValueText: String;
begin
  WriteColor(scBrightRed, 'Config values for '+ ExtractFileName(ParamStr(0)), StdOut);
  WriteLn;
  WriteLn('Stored in: ', GetAppConfigFile(False)+'.json');
  WriteLn;
  WriteLn('To change a value use');
  WriteLn('  ', ExtractFileName(ParamStr(0)), ' --set <propName> <value>');
  WriteLn;
  lContext := TRttiContext.Create;
  try
    lType := lContext.GetType(ClassType);

    for lProp in lType.GetProperties do
    begin
      lDesc := '';
      lDefaultValue := '';

      for lAttr in lProp.GetAttributes do
      begin
        if lAttr is DescAttr then
          lDesc := DescAttr(lAttr).Value
        else if lAttr is BoolAttr then
        begin
          if BoolAttr(lAttr).Value then
            lDefaultValue := 'TRUE'
          else
            lDefaultValue := 'FALSE';
        end
        else if lAttr is StringAttr then
          lDefaultValue := ResolveEnvString(StringAttr(lAttr).Value);
      end;

      lCurrentValue := lProp.GetValue(Self);

      case lCurrentValue.Kind of
        tkBool:
          if lCurrentValue.AsBoolean then
            lCurrentValueText := 'TRUE'
          else
            lCurrentValueText := 'FALSE';
        tkAString, tkLString, tkWString, tkUString:
          lCurrentValueText := lCurrentValue.AsString;
      else
        lCurrentValueText := lCurrentValue.ToString;
      end;

      WriteColor(scGreen, '  ' + lProp.Name, StdOut);
      WriteLn;
      //WriteLn('  ', lProp.Name);
      WriteWrappedText(6, lDesc);
      WriteLn('      ---------');
      Write  ('      Default : ');
      WriteColor(scGreen, lDefaultValue+LineEnding, StdOut);

      if lDefaultValue <> lCurrentValueText then
      begin
        Write('      Current : ');
        WriteColor(scBrightYellow, lCurrentValueText+LineEnding, StdOut)
      end;
      WriteLn;
    end;
  finally
    lContext.Free;
  end;
end;

procedure TConfig.ApplyDefaults;
var
  lContext: TRttiContext;
  lType: TRttiType;
  lProp: TRttiProperty;
  lAttr: TCustomAttribute;
begin
  lContext := TRttiContext.Create;
  try
    lType := lContext.GetType(ClassType);

    for lProp in lType.GetProperties do
    begin
      if not lProp.IsWritable then
        Continue;

      for lAttr in lProp.GetAttributes do
      begin
        if lAttr is BoolAttr then
          lProp.SetValue(Self, BoolAttr(lAttr).Value)
        else if lAttr is StringAttr then
          lProp.SetValue(Self,  ResolveEnvString(StringAttr(lAttr).Value));
      end;
    end;
  finally
    lContext.Free;
  end;
end;

procedure TConfig.LoadConfig(AFile: String);
var
  lReader: TJSONDeStreamer;
  lStream: TStringStream;
begin
  if not FileExists(AFile) then
    Exit;
  lStream := TStringStream.Create;
  lStream.LoadFromFile(AFile);
  try
    lReader := TJSONDeStreamer.Create(nil);
    lReader.JSONToObject(lStream.DataString, Self);
  finally
    lStream.Free;
    lReader.Free;
  end;
end;

procedure TConfig.SaveConfig(AFile: String);
var
  lStream: TStringStream;
  lWriter: TJSONStreamer;
begin
  try
    lWriter := TJSONStreamer.Create(nil);
    lStream := TStringStream.Create(lWriter.ObjectToJSONString(Self));
    lStream.SaveToFile(AFile);
  finally
    lStream.Free;
    lWriter.Free;
  end;
end;

initialization

  GConfig := TConfig.Create;
  GConfig.ApplyDefaults;
  GConfig.LoadConfig(GetAppConfigFile(False)+'.json');

finalization
  if GConfig.Modified then
    GConfig.SaveConfig(GetAppConfigFile(False)+'.json');

  GConfig.Free;

end.

