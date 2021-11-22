unit MFP.Cmd;

interface

uses sysutils, classes, MFP.Package, MFP.Index, MFP.Index.hash, MFP.Files, MFP.Types, System.Console, Mu.Console.Params;

var
  pubPageEnd: boolean = false;

function PackageCmd(Cmd: TMCmd): cardinal;
function PackageCurrentAndSubDir(AOutputDir: String = ''; aRepleatExists: boolean = true; aAppend: boolean = false;
  aBuildIndex: boolean = true; aHashIndex: boolean = false): cardinal;

function RebuildCmd(Cmd: TMCmd): cardinal;
function ExportCmd(Cmd: TMCmd): cardinal;
function ExportFileNameCmd(Cmd: TMCmd): cardinal;
function PackageADir(aDir: String; AOutputDir: String = ''; aRepleatExists: boolean = true; aAppend: boolean = false;
  aBuildIndex: boolean = true; aHashIndex: boolean = false): cardinal;

implementation

uses Mu.Fileinfo;

function ExportCmd(Cmd: TMCmd): cardinal;
begin

end;

function ExportFileNameCmd(Cmd: TMCmd): cardinal;
begin

end;

function PackageADir(aDir: String; AOutputDir: String = ''; aRepleatExists: boolean = true; aAppend: boolean = false;
  aBuildIndex: boolean = true; aHashIndex: boolean = false): cardinal;
var
  c                      : Integer;
  l, t                   : Integer;
  path, dir, fn, filename: String;
begin

  if aDir[Length(aDir)] = '\' then
    delete(aDir, Length(AOutputDir), 1);

  if AOutputDir = '' then
  begin
    AOutputDir := aDir;
    filename   := AOutputDir + PubPackageExt;
  end
  else
    filename := '';

  if AOutputDir[Length(AOutputDir)] <> '\' then
    AOutputDir := AOutputDir + '\';

  try
    dir := aDir;

    c := 0;

    Console.WriteLine('');
    Console.WriteLine('Start package directory %s', [aDir]);

    fn  := extractfilename(dir);
    dir := dir + '\';
    if filename = '' then
    begin
      filename := AOutputDir + fn + PubPackageExt; // '.mpkg';
    end;

    if fileexists(filename) and (not aAppend) then
      if aRepleatExists then
        deletefile(filename)
      else
        exit;
    t                     := Console.CursorTop;
    Console.CursorVisible := false;

    c := PackageDir(dir + '\', filename, fn, fn, aBuildIndex, aHashIndex,
      procedure(Const aFileName: ansiString; const APosition: cardinal; AFileCount, ATotalCount: cardinal)
      begin
        inc(c, AFileCount);
        Console.SetCursorPosition(0, t);
        if (AFileCount mod 100 = 0) or (AFileCount = ATotalCount) then
          Console.Write(format('%d/%d %s', [AFileCount, ATotalCount, aFileName]));
      end);

    Console.DeleteLine;
    Console.SetCursorPosition(0, t);
    Console.ForegroundColor := TConsoleColor.Green;
    Console.WriteLine(format('package end %d files', [c]));
    Console.ForegroundColor := TConsoleColor.Gray;
    Console.CursorVisible   := true;

    pubPageEnd := true;
  finally

  end;

end;

function PackageCurrentAndSubDir(AOutputDir: String = ''; aRepleatExists: boolean = true; aAppend: boolean = false;
aBuildIndex: boolean = true; aHashIndex: boolean = false): cardinal;
var
  st                     : Tstringlist;
  i, c                   : Integer;
  l, t                   : Integer;
  path, dir, fn, filename: String;
begin
  if AOutputDir <> '' then
    if AOutputDir[Length(AOutputDir)] <> '\' then
      AOutputDir := AOutputDir + '\';

  st := Tstringlist.Create;
  try
    path := getexepath;
    getdirs(path, st);
    c     := 0;
    for i := 0 to st.Count - 1 do
    begin
      fn  := st[i];
      dir := path + fn;
      Console.WriteLine('');
      Console.WriteLine('Start packing directory %s', [dir]);
      Console.WriteLine('');
      filename := '';
      if AOutputDir = '' then
      begin
        filename := dir + '.mpkg';;
      end else begin
        filename := AOutputDir + fn + '.mpkg';
      end;

      if fileexists(filename) and (not aAppend) then
        if aRepleatExists then
          deletefile(filename)
        else
          continue;
      t := Console.CursorTop;
      c := PackageDir(dir + '\', filename, fn, fn, aBuildIndex, aHashIndex,
        procedure(Const aFileName: ansiString; const APosition: cardinal; AFileCount, ATotalCount: cardinal)
        begin
          inc(c, AFileCount);
          Console.SetCursorPosition(0, t);
          if (ATotalCount mod 100 = 0) or (AFileCount = ATotalCount) then
            Console.Write(format('%d/%d %s', [AFileCount, ATotalCount, aFileName]));
        end);
      Console.DeleteLine;
      Console.SetCursorPosition(0, t);
      Console.ForegroundColor := TConsoleColor.Green;
      Console.WriteLine(format('Successfully packed %d files', [c]));
      Console.ForegroundColor := TConsoleColor.Gray;
    end;

    pubPageEnd := true;
  finally
    st.Free;
  end;
end;

function PackageCmd(Cmd: TMCmd): cardinal;
var
  sub: boolean;
var
  dir: String;
begin
  if Cmd.HasParam('subdir') then
  begin
    PackageCurrentAndSubDir(Cmd.GetParam('out', ''), (not(Cmd.GetParam('replace', 'true') = 'false')),
      Cmd.HasParam('a'), Cmd.GetParam('rebuild', 'true') <> 'false', Cmd.GetParam('hash', 'false') = 'true');
  end else if Cmd.HasParam('dir') then
  begin
    dir := Cmd.GetParam('dir', '');
    if DirectoryExists(dir) then
    begin
      PackageADir(dir, Cmd.GetParam('out', ''), (not(Cmd.GetParam('replace', 'true') = 'false')), Cmd.HasParam('a'),
        Cmd.GetParam('rebuild', 'true') <> 'false', Cmd.GetParam('hash', 'false') = 'true');
    end;
  end;
end;

function RebuildCmd(Cmd: TMCmd): cardinal;
var
  fn: String;

  procedure RebuildFile();
  var
    t: Integer;
  begin
    Console.WriteLine('Rebuild index %s', [fn]);
    t := Console.CursorTop;

    Console.CursorVisible := false;

    if Cmd.HasParam('rbtree') or Cmd.HasParam('rb') then
    begin
      RebuildIndex_rbtree(fn,
        procedure(aCurrent, aTotal: cardinal)
        begin
          Console.SetCursorPosition(0, t);
          if (aCurrent mod 1000 = 0) or (aCurrent = aTotal) then
            Console.Write(format('Rebuild %d/%d', [aCurrent, aTotal]));
        end);
    end else begin

      RebuildIndex(fn,
        procedure(aCurrent, aTotal: cardinal)
        begin
          Console.SetCursorPosition(0, t);
          if (aCurrent mod 1000 = 0) or (aCurrent = aTotal) then
            Console.Write(format('Rebuild %d/%d', [aCurrent, aTotal]));
        end);

    end;
    Console.DeleteLine;
    Console.SetCursorPosition(0, t);
    Console.WriteLine('Rebuild index successfully', [fn + PubIndexExt_Hash]);
    Console.CursorVisible := true;
  end;

begin

  if Cmd.HasParam('fn') then
  begin
    fn := Cmd.GetParam('fn', '');
    if fileexists(fn) then
    begin
      RebuildFile;
    end;
  end else begin
    if Length(Cmd.Params) > 0 then
    begin
      fn := Cmd.Params[0].Name;
      if fileexists(fn) then
      begin
        RebuildFile;
      end;
    end;
  end;

end;

end.
