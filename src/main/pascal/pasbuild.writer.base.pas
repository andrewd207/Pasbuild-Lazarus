{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

{
  This unit defines the base class for project writers. It keeps a
  reference to the resolved project, owns the XML document being
  built, and provides shared helpers for naming, saving, and finding
  generated unit files.
}
unit PasBuild.Writer.Base;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DOM, Pasbuild.ResolveIntf, Utils.Files, fgl;

type

  { TBaseWriter }

  TBaseWriter = class
  private
    FDocument: TXMLDocument;
    FProject: TCommonPasbuildProject;
    function GetName: String;
    procedure SetDocument(AValue: TXMLDocument);
  protected
    function GetProject: TCommonPasbuildProject;
    function CollectOutputPPUs: TStringList;
  published
    property Document: TXMLDocument read FDocument write SetDocument;
    // file name without ext. My-Project -> My_Project
    property Name: String read GetName;
    property Project: TCommonPasbuildProject read GetProject;
  public
    constructor Create(AProject: TCommonPasbuildProject); virtual;
    destructor Destroy; override;
    procedure SaveToFile(AFileName: String);
    procedure Generate; virtual; abstract;
  end;

  TUnitNameFileList = specialize TFPGMap<String, String>;

implementation
uses
  XMLWrite;

{ TBaseWriter }

procedure TBaseWriter.SetDocument(AValue: TXMLDocument);
begin
  if FDocument=AValue then Exit;
  FDocument:=AValue;
end;

function TBaseWriter.GetName: String;
begin
  Result := StringReplace(Project.name, '-', '_', [rfReplaceAll]);
end;

function TBaseWriter.GetProject: TCommonPasbuildProject;
begin
  Result := FProject;
end;

function TBaseWriter.CollectOutputPPUs: TStringList;
var
  lCommon: TCommonProjectLibrary;
  lDir: String;
begin
  Result := nil;
  if Project.InheritsFrom(TCommonProjectLibrary) then
  begin
    lCommon := TCommonProjectLibrary(Project);
    lDir := IncludeTrailingPathDelimiter(lCommon.projectDir)+ lCommon.output.unitDirectory;
    Result := FindMatchingFiles(lDir, '*.ppu', PathSeparator);
  end;
end;

constructor TBaseWriter.Create(AProject: TCommonPasbuildProject);
begin
  inherited Create;
  FDocument := TXMLDocument.Create;
  FProject := AProject;
end;

destructor TBaseWriter.Destroy;
begin
  FDocument.Free;
  inherited Destroy;
end;

procedure TBaseWriter.SaveToFile(AFileName: String);
begin
  WriteXML(FDocument, AFileName);

end;

end.

