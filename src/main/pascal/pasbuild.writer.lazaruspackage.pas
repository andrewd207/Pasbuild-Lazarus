{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

{
  This unit writes a Lazarus package file for a PasBuild library
  project. It builds the .lpk XML, collects source and include files,
  adds required package references, and writes the finished package
  file only when the content has changed.
}
unit Pasbuild.Writer.LazarusPackage;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,
  Pasbuild.Writer.Base,
  Pasbuild.ResolveIntf,
  DOM,
  XMLWrite,
  Utils.Files,
  Utils.Strings,
  Utils.console,
  PPUDumpReader
  ;

type

  { TLibraryWriter }

  TLibraryWriter = class(TBaseWriter)
  private
    function GetProjectLibrary: TProjectLibrary;
    function GetOutputPackageDirectory: String;
    function CreateRequiredPackagesNode: TDOMElement;
    function CreatePathSearchNode(AOutUnitsList: TUnitNameFileList; AOutIncludeFileList: TStrings): TDOMElement;
    function CreateFilesNode(AUnitNames: TUnitNameFileList; AIncludeFileList: TStringList): TDOMElement;
    procedure WriteFiles;
  published
    property Project: TProjectLibrary read GetProjectLibrary;
  public
    procedure Generate; override;
  end;

implementation

{ TLibraryWriter }

function TLibraryWriter.GetProjectLibrary: TProjectLibrary;
begin
  Result := inherited GetProject as TProjectLibrary;
end;

function TLibraryWriter.GetOutputPackageDirectory: String;
begin
  // fix later
  Result := IncludeTrailingPathDelimiter(Project.projectDir);
end;

function TLibraryWriter.CreateRequiredPackagesNode: TDOMElement;
var
  ItemNode, PackageNameNode: TDOMElement;
  i: Integer;
  lDep: TDependancy;
begin
  Result := Document.CreateElement('RequiredPkgs') as TDOMElement;
  ItemNode := Result.AppendChild(Document.CreateElement('Item')) as TDOMElement;
  PackageNameNode := ItemNode.AppendChild(Document.CreateElement('PackageName')) as TDOMElement;
  PackageNameNode.AttribStrings['Value'] := 'FCL';
  for i := 0 to Project.dependencies.Count-1 do
  begin
    lDep := Project.dependencies[i];
    ItemNode := Result.AppendChild(Document.CreateElement('Item')) as TDOMElement;
    PackageNameNode := ItemNode.AppendChild(Document.CreateElement('PackageName')) as TDOMElement;
    PackageNameNode.AttribStrings['Value'] := lDep.name;
    // untested. Version info?
  end;
end;

function TLibraryWriter.CreatePathSearchNode(AOutUnitsList: TUnitNameFileList;
  AOutIncludeFileList: TStrings): TDOMElement;
var
  UnitOutputDirectoryNode, IncludeFilesNode, OtherUnitFilesNode: TDOMElement;
  lPaths, lFoundPPU, lExpectedIncludeFiles, PPUList, lFoundPas,
    lIncludePaths: TStringList;
  lPPU, lUnitName, lIncludeFile, tmp, lUnitOnly: String;
  lDump: TPPUDumpReader;
  i, lStart, j: Integer;
begin
   // Result is <SearchPaths> node
  Result := Document.CreateElement('SearchPaths');
  UnitOutputDirectoryNode := Result.AppendChild(Document.CreateElement('UnitOutputDirectory')) as TDOMElement;
  UnitOutputDirectoryNode.AttribStrings['Value'] := UnicodeString(Project.output.unitDirectory);

  PPUList := CollectOutputPPUs; // target/units/<x>.ppu

  Project.includePaths.Delimiter:=';';

  try
    lPaths := TStringList.Create;
    lPaths.Sorted:=True;
    lPaths.Duplicates:=TDuplicates.dupIgnore;
    lPaths.Delimiter:=';';

    for tmp in Project.unitPaths do
      lPaths.Add(IncludeTrailingPathDelimiter(Project.projectDir)+tmp);

    lExpectedIncludeFiles := TStringList.Create;
    lExpectedIncludeFiles.Sorted:=True;
    lExpectedIncludeFiles.Duplicates:=TDuplicates.dupIgnore;

    lIncludePaths := TStringList.Create;
    lIncludePaths.Delimiter:=';';
    lIncludePaths.Sorted:=True;
    lIncludePaths.Duplicates:=TDuplicates.dupIgnore;

    for tmp in Project.includePaths do
      lIncludePaths.Add(IncludeTrailingPathDelimiter(Project.projectDir)+tmp);



    for lPPU in PPUList do
    begin
      try
        lDump := TPPUDumpReader.Create(lPPU);
        if lDump.GetFirstUnitFileName(lUnitName) then
        begin

          lFoundPas := FindMatchingFiles(lPaths.DelimitedText, lUnitName, lPaths.Delimiter);
          if lFoundpas.Count > 0 then
          begin
            if lDump.GetFirstUnitName(lUnitOnly) then
              AOutUnitsList[lUnitOnly] := lFoundPas[0];
          end
          else
            LogWarning('[lazarus.package] didn''t find pascal file in source path: '+ lUnitName);
          FreeAndNil(lFoundPas);

          // get include name without path
          lStart := lExpectedIncludeFiles.Count;
          lDump.GetIncludeFiles(lUnitName, lExpectedIncludeFiles, False);
          // lookup path
          for j := lStart to lExpectedIncludeFiles.Count-1 do
          begin
            lIncludeFile := lExpectedIncludeFiles[j];
            lFoundPas := FindMatchingFiles(lIncludePaths.DelimitedText, lIncludeFile, lIncludePaths.Delimiter);
            if lFoundpas.Count > 0 then
            begin
              // /home/user/Project/source/pascal/main/file.inc
              AOutIncludeFileList.Add(lFoundPas[0]);
            end
            else
              LogWarning('[lazarus.package] didn''t find include file in include path: ' + lIncludeFile);
            FreeAndNil(lFoundPas);
          end;
        end;
      finally
        FreeAndNil(lDump);
      end;
    end;

    // make full include paths relative to where the package is written
    lIncludePaths.Sorted:=False;
    for i := 0 to lIncludePaths.Count-1 do
    begin
      lIncludePaths[i] := ExtractRelativePath(GetOutputPackageDirectory, lIncludePaths[i]);
    end;

    lPaths.Sorted:=False;
    for i := 0 to lPaths.Count-1 do
    begin
      lPaths[i] := ExtractRelativePath(GetOutputPackageDirectory, lPaths[i]);
    end;

    if Assigned(Project.includePaths) then
    begin
      IncludeFilesNode := Result.AppendChild(Document.CreateElement('IncludeFiles')) as TDOMElement;
      IncludeFilesNode.AttribStrings['Value'] := UnicodeString(lIncludePaths.DelimitedText);
    end;   // if Assigned(IncludePaths);

    OtherUnitFilesNode := Result.AppendChild(Document.CreateElement('OtherUnitFiles')) as TDOMElement;
    OtherUnitFilesNode.AttribStrings['Value'] := UnicodeString(lPaths.DelimitedText);


  finally
    lPaths.Free;
    lIncludePaths.Free;
  end;
end;

function TLibraryWriter.CreateFilesNode(AUnitNames: TUnitNameFileList;
  AIncludeFileList: TStringList): TDOMElement;

var
  i: Integer;
  lPackageFullPath, lUnitName, lFile, lExt, lType: String;
  ItemNode, FileNode, UnitNameNode, TypeNode: TDOMElement;
  lFullList: TStringList;
begin
  lPackageFullPath := IncludeTrailingPathDelimiter(GetOutputPackageDirectory);
  Result := Document.CreateElement('Files') as TDOMElement;

  lFullList := TStringList.Create;
  lFullList.Sorted:=True;

  lFullList.AddStrings(AIncludeFileList);

  for i := 0 to AUnitNames.Count-1 do
    lFullList.Add(AUnitNames.Data[i]);


  for i := 0 to lFullList.Count-1 do
  begin

    lFile := lFullList[i];
    ItemNode := Result.AppendChild(Document.CreateElement('Item')) as TDOMElement;
    FileNode := ItemNode.AppendChild(Document.CreateElement('Filename')) as TDOMElement;
    FileNode.AttribStrings['Value'] := UnicodeString(ExtractRelativePath(lPackageFullPath, lFile));

    lExt := lowercase(ExtractFileExt(lFile));
    case lExt of
      '.pas', '.lpr', '.pp' : lType := '';
      '.inc', '.include': lType := 'Include';
      '.txt': lType := 'Text';
      '.md': lType := 'Text'; // Markdown?
    else
      lType := 'Binary'; // can also include text. the ide doesn't seem to care
    end;
    if lType = '' then // unit
    begin
      lUnitName := AUnitNames.Keys[AUnitNames.IndexOfData(lFile)];
      UnitNameNode := ItemNode.AppendChild(Document.CreateElement('UnitName')) as TDOMElement;
      UnitNameNode.AttribStrings['Value'] := UnicodeString(lUnitName);
    end
    else begin
      TypeNode := ItemNode.AppendChild(Document.CreateElement('Type')) as TDOMElement;
      TypeNode.AttribStrings['Value'] := UnicodeString(lType);
    end;
  end;
  FreeAndNil(lFullList);
end;

procedure TLibraryWriter.WriteFiles;
var
  lFile: String;
  lFileStream: TStringStream;
  lExistingFile: TStringStream = nil;
begin
  lFile := GetOutputPackageDirectory+Name+'.lpk';
  LogInfo('Writing to: '+ lFile);
  lFileStream := TStringStream.Create;
  WriteXML(Document, lFileStream);
  try
    if FileExists(lFile) then
    begin
      LogInfo('File exists already...comparing');
      lExistingFile := TStringStream.Create;
      lExistingFile.LoadFromFile(lFile);
      if CompareStr(lExistingFile.DataString, lFileStream.DataString) = 0 then
      begin
        LogWarning('File contents are the same. Not overwriting');
        Exit;
      end;
      lFileStream.SaveToFile(lFile);
      LogInfo('Writen successfully');
    end;

  finally
    FreeAndNil(lFileStream);
    FreeAndNil(lExistingFile);
  end;
  LogInfo('Writing to: '+ lFile);
end;

procedure TLibraryWriter.Generate;
var
  RootNode: TDOMNode;
  PackageNode, NameNode, CompilerOptionsNode, VersionNode,
    UsageOptionsNode, UnitPathNode,
    PublishOptionsNode, UseFileFiltersNode: TDOMElement;
  lIncludeFileList: TStringList;
  lUnitList: TUnitNameFileList;
begin
  if Not Assigned(Document) then
  begin
    LogError('Project document unnassigned');
    Halt(1);
  end;

  RootNode := Document.AppendChild(Document.CreateElement('CONFIG'));
  PackageNode := RootNode.AppendChild(Document.CreateElement('Package')) as TDOMElement;
    PackageNode.AttribStrings['Version'] := '5';
    NameNode := PackageNode.AppendChild(Document.CreateElement('Name')) as TDOMElement;
      NameNode.AttribStrings['Value'] := UnicodeString(Name);

    CompilerOptionsNode := PackageNode.AppendChild(Document.CreateElement('CompilerOptions')) as TDOMElement;
      VersionNode := CompilerOptionsNode.AppendChild(Document.CreateElement('Version')) as TDOMElement;
        VersionNode.AttribStrings['Value'] := '11';

      lUnitList := TUnitNameFileList.Create;
      lIncludeFileList := TStringList.Create;
      lIncludeFileList.Sorted:=True;
      lIncludeFileList.Duplicates:=TDuplicates.dupIgnore;

      // Collects paths of used units and adds the paths and include files
      CompilerOptionsNode.AppendChild(CreatePathSearchNode(lUnitList, lIncludeFileList));

      VersionNode := PackageNode.AppendChild(Document.CreateElement('Version')) as TDOMElement;
      with TVersion.FromString(Project.version) do
      begin
        VersionNode.SetAttribute('Major', UnicodeString(Major));
        VersionNode.SetAttribute('Minor', UnicodeString(Minor));
        VersionNode.SetAttribute('Release', UnicodeString(Release));
      end;


    // Add File list
    {FilesNode := }PackageNode.AppendChild(CreateFilesNode(lUnitList, lIncludeFileList));
    // Add Dependancies
    {RequirePkgsNode := }PackageNode.AppendChild(CreateRequiredPackagesNode);

    UsageOptionsNode := PackageNode.AppendChild(Document.CreateElement('UsageOptions')) as TDOMElement;
      {IncludePathNode := UsageOptionsNode.AppendChild(Document.CreateElement('IncludePath')) as TDOMElement;
        IncludePathNode.Attributes['Value'] := } // this is for other libraries and projects to search. not for compilation
      UnitPathNode := UsageOptionsNode.AppendChild(Document.CreateElement('UnitPath')) as TDOMElement;
        UnitPathNode.AttribStrings['Value'] := '$(PkgOutDir)';

    PublishOptionsNode := PackageNode.AppendChild(Document.CreateElement('PublishOptions')) as TDOMElement;
      VersionNode := PublishOptionsNode.AppendChild(Document.CreateElement('Version')) as TDOMElement;
        VersionNode.AttribStrings['Value'] := '2';
      UseFileFiltersNode := PublishOptionsNode.AppendChild(Document.CreateElement('UseFileFilters')) as TDOMElement;
        UseFileFiltersNode.AttribStrings['Value'] := 'True';

    // the end

    WriteFiles;
end;

end.

