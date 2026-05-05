{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

// This unit reads ppudump JSON output from a .ppu file and provides
// simple helpers to list units, get the first unit name or source
// file, and collect include files referenced by a unit.

unit PPUDumpReader;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpJson, Process;

type

  { TPPUDumpReader }

  TPPUDumpReader = class
  private
    FJSON: TJSONArray;
  public
    constructor Create(AFile: String);
    function GetUnits(AStrings: TStrings): Boolean;
    function GetFirstUnitFileName(out AName: String): Boolean;
    function GetFirstUnitName(out AName: String): Boolean;
    function GetIncludeFiles(AUnitName: String; AStrings: TStrings; AClearFirst: Boolean): Boolean;
    property JSON: TJSONArray read FJSON write FJSON;
  end;

implementation

{ TPPUDumpReader }

constructor TPPUDumpReader.Create(AFile: String);
var
  Proc: TProcess;
  Buf: Array[0..1024] of Byte;
  lCount: DWord;
  lStream: TStringStream;
begin
  if not FileExists(AFile) then
    Raise Exception.CreateFmt('Non-existing file: %s', [AFile]);
  try
    Proc := TProcess.Create(nil);
    Proc.Executable:='ppudump';
    Proc.Options:=[poUsePipes, poStderrToOutPut];
    Proc.Parameters.AddStrings(['-Fj', AFile]); // json output

    Proc.Execute;

    lStream := TStringStream.Create;

    while Proc.Running or (Proc.Output.NumBytesAvailable > 0) do
    begin
      lCount := Proc.Output.NumBytesAvailable;
      if lCount > SizeOf(Buf) then
        lCount := SizeOf(Buf);

      lCount := Proc.Output.Read(Buf, lCount);
      lStream.Write(Buf, lCount);
    end;
    FJSON := GetJSON(lStream.DataString) as TJSONArray;
  finally
    Proc.Free;
    lStream.Free;
  end;
end;

function TPPUDumpReader.GetUnits(AStrings: TStrings): Boolean;
var
  i: Integer;
  lObj: TJSONObject;
begin
  AStrings.Clear;
  for i := 0 to JSON.Count-1 do
  begin
    lObj := JSON.Items[i] as TJSONObject;
    if lObj.Get('Type', '') = 'unit' then
      AStrings.Add(lObj.Get('Name', ''));
  end;
  Result := True;
end;

function TPPUDumpReader.GetFirstUnitFileName(out AName: String): Boolean;
var
  lTmp: TStrings;
  lObj: TJSONObject;
  i: Integer;
begin
  lTmp := TStringList.Create;
  Result := False;
  try
    for i := 0 to JSON.Count-1 do
    begin
      lObj := JSON.Items[i] as TJSONObject;
      if lObj.Get('Type', '') = 'unit' then
      begin
        AName := lObj.GetPath('Files[0].Name').AsString;
        Result := True;
        Exit;
      end;
    end;
  finally
    lTmp.Free;
  end;
end;

function TPPUDumpReader.GetFirstUnitName(out AName: String): Boolean;
var
  lTmp: TStrings;
  lObj: TJSONObject;
  i: Integer;
begin
  lTmp := TStringList.Create;
  Result := False;
  try
    for i := 0 to JSON.Count-1 do
    begin
      lObj := JSON.Items[i] as TJSONObject;
      if lObj.Get('Type', '') = 'unit' then
      begin
        AName := lObj.GetPath('Name').AsString;
        Result := True;
        Exit;
      end;
    end;
  finally
    lTmp.Free;
  end;


end;

function TPPUDumpReader.GetIncludeFiles(AUnitName: String; AStrings: TStrings;
  AClearFirst: Boolean): Boolean;
var
  i, j: Integer;
  lObj, lFile: TJSONObject;
  lTmpArray, lFiles: TJSONArray;
  lFileName: TJSONStringType;
begin
  Result := False;

  if AClearFirst then
    AStrings.Clear;

  for i := 0 to JSON.Count-1 do
  begin
    lObj := JSON.Items[i] as TJSONObject;
    if (lObj.Get('Type', '') = 'unit') and (Lowercase(lObj.Get('Name', '')) = ChangeFileExt(LowerCase(AUnitName), '')) then
    begin
      lTmpArray := TJSONArray.Create;
      try
        lFiles := lObj.Get('Files', lTmpArray);
        for j := 0 to lFiles.Count-1 do
        begin
          lFile := lFiles.Items[j] as TJSONObject;
          if lFile.Get('Type', '') = 'file' then
          begin
            lFileName := lFile.Get('Name', '');
            if Pos('.inc', LowerCase(ExtractFileExt(lFileName))) = 1 then // can be .include rarely
            begin
              AStrings.Add(lFileName);
            end;
          end;
        end;
      finally
        lTmpArray.Free;
      end;
    end;
  end;
  Result := True;
end;

end.


