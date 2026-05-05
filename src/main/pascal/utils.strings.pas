{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }
unit Utils.Strings;

{$mode ObjFPC}{$H+}
{$ModeSwitch typehelpers}

interface

uses
  Classes, SysUtils;

type
  TVersion = record
    Major,
    Minor,
    Release: String;
    Extra: String;
  end;

  { TVersionHelper }

  TVersionHelper = type helper for TVersion
    class function FromString(AString: String): TVersion; static;
  end;


implementation

{ TVersionHelper }

class function TVersionHelper.FromString(AString: String): TVersion;
var
  lParts, lVersion: TAnsiStringArray;
begin
  lParts := AString.Split(['-']);
  lVersion := lParts[0].Split(['.']);

  Result.Major:=lVersion[0];
  if High(lVersion) > 0 then
    Result.Minor:=lVersion[1];

  if High(lVersion) > 1 then
  Result.Release:=lVersion[2];

  if High(lParts) > 0 then
    Result.Extra:=lParts[1];
end;

end.

