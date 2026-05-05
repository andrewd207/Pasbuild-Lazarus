{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

// This unit provides small file helpers. It can search one or more
// directories for files matching a mask, and copy a file while
// preserving its timestamp and, on Unixes, its permissions.

unit Utils.Files;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils{$IFDEF UNIX}, BaseUnix{$ENDIF};

function FindMatchingFiles(const Paths, Mask: string; Sep: Char): TStringList;

procedure CopyFilePreserve(const AOrig, ADest: string);

implementation

function FindMatchingFiles(const Paths, Mask: string; Sep: Char): TStringList;
var
  PathList: TStringList;
  SR: TSearchRec;
  I: Integer;
  Dir: string;

  procedure AddMatchesInDir(const ADir: string);
  var
    SearchPath: string;
  begin
    if ADir = '' then
      Exit;

    SearchPath := IncludeTrailingPathDelimiter(ADir) + Mask;

    if FindFirst(SearchPath, faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and
           ((SR.Attr and faDirectory) = 0) then
          Result.Add(IncludeTrailingPathDelimiter(ADir) + SR.Name);
      until FindNext(SR) <> 0;

      FindClose(SR);
    end;
  end;

begin
  Result := TStringList.Create;
  PathList := TStringList.Create;
  try
    PathList.StrictDelimiter := True;
    PathList.Delimiter := Sep;
    PathList.DelimitedText := Paths;

    if PathList.Count = 0 then
      AddMatchesInDir(Paths)
    else
      for I := 0 to PathList.Count - 1 do
      begin
        Dir := Trim(PathList[I]);
        if Dir <> '' then
          AddMatchesInDir(Dir);
      end;
  finally
    PathList.Free;
  end;
end;

procedure CopyFilePreserve(const AOrig, ADest: string);
var
  Src, Dst: TFileStream;
  Age: LongInt;
  {$IFDEF UNIX}
  Info: Stat;
  {$ENDIF}
begin
  Src := TFileStream.Create(AOrig, fmOpenRead or fmShareDenyWrite);
  try
    Dst := TFileStream.Create(ADest, fmCreate);
    try
      Dst.CopyFrom(Src, 0);
    finally
      Dst.Free;
    end;
  finally
    Src.Free;
  end;

  Age := FileAge(AOrig);
  if Age <> -1 then
    FileSetDate(ADest, Age);

  {$IFDEF UNIX}
  if fpStat(PChar(AOrig), Info) = 0 then
    fpChmod(ADest, Info.st_mode and $1FF);
  {$ENDIF}
end;

end.

