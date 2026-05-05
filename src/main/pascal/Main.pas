{ Copyright (c) 2026 Andrew Haines (github @andrewd207) }
{ SPDX-License-Identifier: MIT }
{ Licensed under the MIT License (see LICENSE file for details). }

{
  This is the pasbuild-lazarus plugin. It acts a plugin for PasBuild.

  It *should* create a .lpk file for library type packages. Currently it won't
  make project files (.lpi)

  It has a couple options that can be used when run independantly to set some
  config values or install itself in the ~/.pasbuild/plugins/ folder for each
  system.

}
program Main;

{$mode objfpc}{$H+}


uses
  SysUtils,
  Pasbuild.ResolveIntf,
  PPUDumpReader,
  Pasbuild.Writer.LazarusPackage,
  PasBuild.Writer.Base,
  Utils.Files,
  Utils.Strings,
  pasbuild.config,

  utils.console;


var
  lProjectType: TCommonPasbuildProject;
  i: Integer;
  lWriter: TBaseWriter = nil;
  lModule: TCommonPasbuildProject;
  lNewFile: RawByteString;
  lSymLink: RawByteString;
begin

  // Phase declaration: respond to --pasbuild-phase
  if (ParamCount >= 1) and (ParamStr(1) = '--pasbuild-phase') then
  begin
    // although really it should be called after install
    //WriteLn('after:compile');
    WriteLn('none');
    Halt(0);
  end;

  if (ParamCount >= 1) and (ParamStr(1) = '--config') then
  begin
    GConfig.DisplayConfig;
    Halt(0);
  end;

  if (ParamCount >= 1) and (ParamStr(1) = '--install-plugin') then
  begin
    try
      lNewFile := IncludeTrailingPathDelimiter(GConfig.baseInstalledLocation)+'plugins'+PathDelim + ExtractFileName(ParamStr(0));
      LogInfo('Copying ' + ParamStr(0) +' to ' +lNewFile);
      LogWarning('Deleting installed plugin if it already exists.');
      try
        DeleteFile(lNewFile);
      except
      end;
      CopyFilePreserve(ParamStr(0), lNewFile);
    except
      on E: Exception do
      begin
        LogError(E.Message);
        Halt(1);
      end;
    end;
    LogSuccess('Installed plugin successfully');
    Halt(0);
  end;

  if (ParamCount >= 3) and (ParamStr(1) = '--set') then
  begin
    try
      GConfig.SetValue(ParamStr(2), ParamStr(3));

    except
      on E: Exception do
      begin
        LogError('Problem setting property: ' + E.Message);
        Halt(1);
      end;
    end;
    LogSuccess(ParamStr(2)+ ': '+  GConfig.GetValue(ParamStr(2)));
    Halt(0);
  end;

  if not TPasbuildResolve.HasPasbuildInfo then
  begin
    LogError('Not called from Pasbuild executable! Halting. This is a plugin.');
    LogError('see https://github.com/graemeg/PasBuild/blob/master/docs/quick-start-guide.adoc#plugins');
    LogError('https://github.com/graemeg/PasBuild/tree/master/extras/plugins/hello-world');
    LogError('If you REALLY want to, set the env vars to run this command directly:');
    LogError('  PASBUILD_PROJECT_DIR, PASBUILD_PROJECT_FILE, PASBUILD_PROFILES');
    LogInfo('Run with --config to see some changable global settings');
    LogInfo('Run with --install-plugin to make PasBuild able to find the plugin');
    Halt(1);
  end;

  LogInfo('Using project ' + TPasbuildResolve.ProjectFile);
  LogInfo('Project Directory: ' + TPasbuildResolve.ProjectDir);
  LogInfo('Working Directory: ' + GetCurrentDir);

  lProjectType := TPasbuildResolve.ExecuteResolve;
  LogInfo('Project Type: ' + lProjectType.projectTypeEnum.toString);
  case lProjectType.projectTypeEnum of
    ptPOM:
      begin
        for i := 0 to TProjectPOM(lProjectType).modules.Count-1 do
        begin
          lModule := TProjectPOM(lProjectType).modules[i];
          lWriter := nil;
          case lModule.projectTypeEnum of
             ptLibrary:  lWriter := TLibraryWriter.Create(TProjectPOM(lProjectType).modules[i] as TProjectLibrary);
          else
            LogWarning('Unhandled project module type: "' + lModule.projectTypeEnum.toString + '" for ' + lModule.name);
          end;

          if Assigned(lWriter) then
          begin
            LogInfo('Generating Lazarus file.....');
            //LogInfo('Will be installed in ');
            lWriter.Generate;
          end;
        end;
      end;
  else
    LogError('Project type "'+lProjectType.projectTypeEnum.toString+'" not supported (yet?) for ' + lProjectType.name);
  end;
  Halt(0);
end.
