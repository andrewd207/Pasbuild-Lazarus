{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

{
  This unit defines classes and interfaces for resolving PasBuild
  project structures from JSON. It uses RTTI and custom streamers to
  deserialize projects, modules, dependencies, and settings with
  special handling for arrays and project merging.
}
unit PasBuildResolveIntf;

{$mode ObjFPC}{$H+}
{$ModeSwitch prefixedattributes}
{$ModeSwitch typehelpers}


interface

uses
  Classes, SysUtils, fpJson, JsonParser, TypInfo, fpJsonRtti, fgl;

type

  { TNodePath }

  TProjectType = (ptUnknown, ptApplication, ptLibrary, ptPOM);

const
  CProjectTypes: Array [TProjectType] of String = (
    'unknown',
    'application',
    'library',
    'pom'
  );

type

  { TProjectTypeHelper }

  TProjectTypeHelper = type helper for TProjectType
    class function fromString(AValue: String): TProjectType; static;
    function toString: String;

  end;

  TNodePath = class(TCustomAttribute)
  private
    FNodePath: String;
  public
    constructor Create(APath: String);
    property NodePath: String read FNodePath;
  end;

  TPasbuildResolve = class; // Use this first

  TCommonPasbuildProject = class;
  TProject = class; // project object with name etc.
  TCompiler = class;
  TTest = class;
  TDirectories = class;
  TOutput = class;

  { TBaseJsonObj }

  TBaseJsonObj = class
  private
    function GetNodePath: String;
    procedure HandlePropertyError(Sender: TObject; AObject: TObject;
      Info: PPropInfo; AValue: TJSONData; Error: Exception;
      var Continue: Boolean);
    procedure HandleRestoreProperty(Sender: TObject; AObject: TObject;
      Info: PPropInfo; AValue: TJSONData; var Handled: Boolean);
  public
    procedure ReadFromJson(AJson: TJSONObject); virtual;
    property  NodePath: String read GetNodePath;
    destructor Destroy; override;
  end;



  TPasBuildEnvVars = (PASBUILD_PROJECT_DIR,
                      PASBUILD_PROJECT_FILE,
                      PASBUILD_PROFILES,
                      PASBUILD_VERBOSE);

  { TPasbuildResolve }
  TPasbuildResolve = class(TBaseJsonObj)
  private
    class function GetEnvVar(AIndex: Integer): String; static;
    class function GetVerbose: Boolean; static;
  public
    class function ExecuteResolve: TCommonPasbuildProject;
    class property ProjectDir: String index ord(PASBUILD_PROJECT_DIR) read GetEnvVar;
    class property ProjectFile: String index ord(PASBUILD_PROJECT_FILE) read GetEnvVar;
    class property Profiles: String index ord(PASBUILD_PROFILES) read GetEnvVar;
    class property Verbose: Boolean read GetVerbose;
  end;

  { TCommonPasbuildProject }

  TCommonPasbuildProject = class(TBaseJsonObj)
  private
    FactiveProfiles: TStringList;
    FavailableProfiles: TStringList;
    FName: String;
    FprojectDir: String;
    FprojectType: String;
    Fversion: String;
  protected
    FprojectTypeEnum: TProjectType;
  public
    property projectTypeEnum: TProjectType read FprojectTypeEnum;
    constructor Create; virtual;
  published
    { Project node merged directly for simplicity because modules use this format}
    property name: String read FName write FName;
    property version: String read Fversion write Fversion;
    property projectType: String read FprojectType write FprojectType;
    property projectDir: String read FprojectDir write FprojectDir;
    { end project node }



    property activeProfiles: TStringList read FactiveProfiles write FactiveProfiles;
    property availableProfiles: TStringList read FavailableProfiles write FavailableProfiles;
  end;

  { TModuleList }

  TModuleList = class(specialize TFPGObjectList<TCommonPasbuildProject>)
    constructor Create; virtual; // important to have a constructor without vars
  end;


  TDependancy = class; //forward
  TDependancyList = class(specialize TFPGObjectList<TDependancy>)
  end;


  { TCommonProjectLibrary }

  TCommonProjectLibrary = class(TCommonPasbuildProject)
  private
    Fcompiler: TCompiler;
    Fdefines: TStringList;
    Fdependencies: TDependancyList;
    Fdirectories: TDirectories;
    FincludePaths: TStringList;
    Foutput: TOutput;
    Ftest: TTest;
    FunitPaths: TStringList;
  published
    property compiler: TCompiler read Fcompiler write Fcompiler;
    property defines: TStringList read Fdefines write Fdefines;
    property unitPaths: TStringList read FunitPaths write FunitPaths;
    property includePaths: TStringList read FincludePaths write FincludePaths;
    property dependencies: TDependancyList read Fdependencies write Fdependencies;
    property test: TTest read Ftest write Ftest;
    property directories: TDirectories read Fdirectories write Fdirectories;
    property output: TOutput read Foutput write Foutput;
  end;


  { TProjectApplication }

  TProjectApplication = class(TCommonProjectLibrary)
  private
    FexecutableName: String;
    FmainSource: String;
  public
    constructor Create; override;
  published
    property mainSource: String read FmainSource write FmainSource;
    property executableName: String read FexecutableName write FexecutableName;
  end;

  { TProjectLibrary }

  TProjectLibrary = class(TCommonProjectLibrary)
  public
    constructor Create; override;
  end;

  { TProjectPOM }

  TProjectPOM = class(TCommonPasbuildProject)
  private
    FbuildOrder: TStringList;
    FModuleList: TModuleList;
    Fmodules: TModuleList;
  public
    constructor Create; override;
  published
    property buildOrder: TStringList read FbuildOrder write FbuildOrder;
    property modules: TModuleList read FModuleList write Fmodules;
  end;



  { TProject }

  [TNodePath('project')]
  TProject = class(TBaseJsonObj)
  private
    FexecutableName: String;
    FmainSource: String;
    FName: String;
    FprojectDir: String;
    FprojectType: String;
    Fversion: String;
  published
    property name: String read FName write FName;
    property version: String read Fversion write Fversion;
    property projectType: String read FprojectType write FprojectType;
    property projectDir: String read FprojectDir write FprojectDir;

    // props only for "application" project type
    property mainSource: String read FmainSource write FmainSource;
    property executableName: String read FexecutableName write FexecutableName;
  end;

  { TCompiler }

  TCompiler = class(TBaseJsonObj)
  private
    FcommandLine: String;
    Fexecutable: String;
  published
    property executable: String  read Fexecutable write Fexecutable;
    property commandLine: String read FcommandLine write FcommandLine;
  end;

  { TTest }

  TTest = class(TBaseJsonObj)
  private
    Fframework: String;
    FtestSource: String;
  published
    property framework: String read Fframework write Fframework;
    property testSource: String read FtestSource write FtestSource;
  end;

  { TDirectories }

  TDirectories = class(TBaseJsonObj)
  private
    Fresources: String;
    Fsource: String;
    FtestResources: String;
    FtestSource: String;
  published
    property source: String read Fsource write Fsource;
    property testSource: String read FtestSource write FtestSource;
    property resources: String read Fresources write Fresources;
    property testResources: String read FtestResources write FtestResources;
  end;

  { TOutput }

  TOutput = class(TBaseJsonObj)
  private
    Fdirectory: String;
    Fexecutable: String;
    FunitDirectory: String;
  published
    property directory: String read Fdirectory write Fdirectory;
    property unitDirectory: String read FunitDirectory write FunitDirectory;
    property executable: String read Fexecutable write Fexecutable;
  end;

  { TDependancy }

  TDependancy = class(TBaseJsonObj)
  private
    Fname: String;
    FprojectDir: String;
    FsourceDir: String;
    FType: String;
    FunitDir: String;
    Fversion: String;
  published
    property name: String read Fname write Fname;
    property version: String read Fversion write Fversion;
    property &type: String read FType write Ftype;
    property projectDir: String read FprojectDir write FprojectDir;
    property sourceDir: String read FsourceDir write FsourceDir;
    property unitDir: String read FunitDir write FunitDir;
  end;



implementation
Uses
  Rtti, Process;

{ TNodePath }

procedure HandleGetObject(Sender: TOBject; AObject: TObject; Info: PPropInfo;
  AData: TJSONObject; DataName: TJSONStringType; var AValue: TObject);
var
  lTypeData: PTypeData;
begin
  AValue := nil;
  WriteLn('[lazarus] Creating object for ', Info^.Name);
  if (Info <> nil ) and (Info^.PropType^.Kind = tkClass)then
  begin

    if Info^.Name = 'project' then
    begin
      LogInfo('[lazarus] merging project properties with toplevel node');
      // we merge the 'project' node into the top level to simplify
      AValue := AObject;
      Exit;
    end;

    AValue := GetObjectProp(AObject, Info);
    if AValue = nil then
    begin
      lTypeData := GetTypeData(Info^.PropType);
      AValue := lTypeData^.ClassType.Create;
    end;
  end;
end;

{ TProjectTypeHelper }

class function TProjectTypeHelper.fromString(AValue: String): TProjectType;
var
  val: TProjectType;
begin
  for val := Low(TProjectType) to High(TProjectType) do
    if CProjectTypes[val] = AValue then
      Exit(val);

  Result := ptUnknown;
end;

function TProjectTypeHelper.toString: String;
begin
  Result := CProjectTypes[Self];
end;

constructor TNodePath.Create(APath: String);
begin
  FNodePath:=APath;
end;

{ TBaseJsonObj }

function TBaseJsonObj.GetNodePath: String;
var
  ctx: TRttiContext;
  typ: TRttiType;
  attrs: TCustomAttributeArray;
  i: Integer;
begin
  Result := '';
  typ := ctx.GetType(ClassInfo);
  attrs := typ.GetAttributes;
  for i := 0 to High(attrs) do
  begin
    if attrs[i].ClassInfo = TNodePath.ClassInfo then
      Result := TNodePath(attrs[i]).NodePath;
  end;
end;

procedure TBaseJsonObj.HandlePropertyError(Sender: TObject; AObject: TObject;
  Info: PPropInfo; AValue: TJSONData; Error: Exception; var Continue: Boolean);
var
  lTypeData: PTypeData;
  lStrings: TStrings;
  lList: TFPSList;
  lModule: TCommonPasbuildProject;
  i: Integer;
  lJsonItem: TJSONObject;
  lDependancy: TDependancy;
begin
  if AValue.JSONType = jtArray then
  begin
    WriteLn(Info^.Name);
    lTypeData := GetTypeData(Info^.PropType);

    //TStringList props
    if (Info^.PropType^.Kind = tkClass) and (lTypeData^.ClassType.InheritsFrom(TStrings)) then
    begin
      lStrings := TStrings(GetObjectProp(AObject, Info));
      if lStrings = nil then
        lStrings := TStrings(lTypeData^.ClassType.Create);
      TJSONDeStreamer(Sender).JSONToStrings(AValue, lStrings);
      Continue:=True;
      SetObjectProp(AObject, Info, lStrings);
    end;

    // TModuleList prop
    if (Info^.PropType^.Kind = tkClass) and (lTypeData^.ClassType.InheritsFrom(TModuleList)) then
    begin
      lList := TModuleList(GetObjectProp(AObject, Info));
      if not Assigned(lList) then
      begin
        lList := TModuleList.Create;
        SetObjectProp(AObject, Info, lList);
      end;
      for i := 0 to TJSONArray(AValue).Count-1 do
      begin
        lJsonItem := TJsonArray(AValue).Items[i] as TJSONObject;
        case lJsonItem.Get('projectType', 'unknown') of
          'pom'        : lModule := TProjectPOM.Create;
          'library'    : lModule := TProjectLibrary.Create;
          'application': lModule := TProjectApplication.Create;
        else
          WriteLn(Format('[lazarus] unexpected project type "%s" for "%s"', [lJsonItem.Get('projectType', 'unknown'), lJsonItem.Get('name', '')]));
          lModule := TCommonPasbuildProject.Create;
        end;
        lList.Add(lModule);
        TJSONDeStreamer(Sender).JSONToObject(lJsonItem, lModule);
      end;
      Continue:=True;
    end;

    //TDependencyList props
    if (Info^.PropType^.Kind = tkClass) and (lTypeData^.ClassType.InheritsFrom(TDependancyList)) then
    begin
      lList := TDependancyList(GetObjectProp(AObject, Info));
      if not Assigned(lList) then
      begin
        lList := TDependancyList.Create;
        SetObjectProp(AObject, Info, lList);
      end;
      for i := 0 to TJSONArray(AValue).Count-1 do
      begin
        lJsonItem := TJsonArray(AValue).Items[i] as TJSONObject;
        lDependancy := TDependancy.Create;
        lList.Add(lDependancy);
        TJSONDeStreamer(Sender).JSONToObject(lJsonItem, lDependancy);
      end;
      Continue:=True;
    end;
  end;
end;

procedure TBaseJsonObj.HandleRestoreProperty(Sender: TObject; AObject: TObject;
  Info: PPropInfo; AValue: TJSONData; var Handled: Boolean);
begin
  WriteLn('Reading :', Info^.Name);
end;

procedure TBaseJsonObj.ReadFromJson(AJson: TJSONObject);
var
  lReader: TJSONDeStreamer;
begin
  lReader := TJSONDeStreamer.Create(nil);
  try
    lReader.OngetObject:=@HandleGetObject;
    lREader.OnRestoreProperty:=@HandleRestoreProperty;
    lREader.OnPropertyError:=@HandlePropertyError;
    lReader.JSONToObject(AJson, Self);
  finally
    lReader.Free;
  end;
end;

destructor TBaseJsonObj.Destroy;
var
  PropList: PPropList;
  PropCount: Integer;
  I: Integer;
  PropInfo: PPropInfo;
  Obj: TObject;
begin
  // free all published properties that are class types.
  PropCount := GetPropList(ClassInfo, PropList);
  try
    for I := 0 to PropCount - 1 do
    begin
      PropInfo := PropList^[I];

      if (PropInfo^.PropType^.Kind = tkClass) then
      begin
        Obj := GetObjectProp(Self, PropInfo);

        if Obj <> nil then
        begin
          Obj.Free;
          SetObjectProp(Self, PropInfo, nil);
        end;
      end;
    end;
  finally
    if PropList <> nil then
      FreeMem(PropList);
  end;

  inherited Destroy;
end;

{ TPasbuildResolve }

class function TPasbuildResolve.GetEnvVar(AIndex: Integer): String;
begin
  Result := GetEnvironmentVariable(GetEnumName(TypeInfo(TPasBuildEnvVars), AIndex));
end;

class function TPasbuildResolve.GetVerbose: Boolean;
begin
  Result := GetEnvVar(ord(PASBUILD_VERBOSE)) = '1';
end;

class function TPasbuildResolve.ExecuteResolve: TCommonPasbuildProject;
var
  lProc: TProcess;
  lData: TStringStream;
  lBuf: array[0..2047] of byte;
  lJson: TJSONObject;
  lCount: DWord;
begin
  try
    lData := TStringStream.Create;
    lProc := TProcess.Create(nil);
    lProc.Executable:='pasbuild';
    lProc.Parameters.AddStrings(['resolve']);
    lProc.Options:=[poUsePipes, poNoConsole];

    lProc.Execute;

    while lProc.Running or (lProc.Output.NumBytesAvailable > 0) or (lProc.Stderr.NumBytesAvailable > 0) do
    begin
      while lProc.Output.NumBytesAvailable > 0 do
      begin
        lCount := lProc.Output.NumBytesAvailable;
        if lCount > SizeOf(lBuf) then
          lCount := SizeOf(lBuf);
        lCount := lProc.Output.Read(lBuf, lCount);
        lData.Write(lBuf, lCount);
      end;

      while lProc.Stderr.NumBytesAvailable > 0 do
      begin
        lCount := lProc.Stderr.NumBytesAvailable;
        if lCount > SizeOf(lBuf) then
          lCount := SizeOf(lBuf);
        {lCount := }lProc.Stderr.Read(lBuf,lCount);
        // we don't pay attention to stderr
      end;
    end;
    // proc has terminated and all data is read

    lJson := GetJSON(lData.DataString) as TJSONObject;
    case lJson.GetPath('project.projectType').AsString of
      'pom'        : Result := TProjectPOM.Create;
      'library'    : Result := TProjectLibrary.Create;
      'application': Result := TProjectApplication.Create;
    else
      LogError(Format('[lazarus] unexpected project type "%s" for "%s"', [lJson.Get('projectType', 'unknown'), lJson.Get('name', '')]));
      Result := TCommonPasbuildProject.Create;
    end;
    // we merged the project into the main object since modules do it anyway
    Result.ReadFromJson((lJson as TJSONObject).GetPath('project') as TJSONObject);

    Result.ReadFromJson(lJson as TJSONObject);

  finally
    lProc.Free;
    lData.Free;
    lJson.Free;
  end;

end;

{ TCommonPasbuildProject }

constructor TCommonPasbuildProject.Create;
begin
  FprojectTypeEnum:=ptUnknown;
end;

{ TModuleList }

constructor TModuleList.Create;
begin
  inherited Create(True);
end;

{ TProjectApplication }

constructor TProjectApplication.Create;
begin
  inherited Create;
  FprojectTypeEnum := ptApplication;
end;

{ TProjectLibrary }

constructor TProjectLibrary.Create;
begin
  inherited Create;
  FprojectTypeEnum := ptLibrary;
end;

{ TProjectPOM }

constructor TProjectPOM.Create;
begin
  inherited Create;
  FprojectTypeEnum:=ptPOM;
end;

end.

