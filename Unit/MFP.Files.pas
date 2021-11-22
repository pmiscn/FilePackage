unit MFP.Files;

interface

uses sysutils, classes, Mu.AnsiStr, MFP.Package, MFP.Index, MFP.Index.hash, MFP.Index.rbtree, MFP.Types;

procedure getdirs(aDir: String; st: Tstrings);

function PackageDir(const aDir: ansistring; const aFileName: ansistring; aDesp: ansistring; aIndex: ansistring;
  aRebuild: Boolean = true; aHashIndex: Boolean = false; aOnFileAppendSucc: TMFOnFileAppendSucc = nil): Cardinal;

function FindFile(const aID: ansistring; const aFileName: ansistring; var Finded: TMFPosFindedArray): Cardinal;
function ExportDir(const aFileName: ansistring; const aDir: ansistring): Cardinal;

function RebuildIndex(aFileName: ansistring; aOnProgress: TMFOnProgress): Cardinal;
function RebuildIndex_rbtree(aFileName: ansistring; aOnProgress: TMFOnProgress): Cardinal;

implementation

uses Mu.fileinfo, Mu.BytesHelper;

procedure getdirs(aDir: String; st: Tstrings);
var
  i        : Integer;
  SearchRec: TSearchRec;
  DosError : Integer;
begin
  ChDir(aDir);
  DosError := FindFirst('*.*', faDirectory, SearchRec);
  while DosError = 0 do
  begin
    if ((SearchRec.Attr and faDirectory = faDirectory) and (SearchRec.Name <> '.') and (SearchRec.Name <> '..')) then
    begin
      st.Add(SearchRec.Name);
    end;
    DosError := FindNext(SearchRec); { Look for another subdirectory }
  end;

end;

function FindFile(const aID: ansistring; const aFileName: ansistring; var Finded: TMFPosFindedArray): Cardinal;
var
  IndexHash: TMFIndexHash;
  c        : Integer;
  stm      : TmemoryStream;
begin
  Result    := 0;
  IndexHash := TMFIndexHash.Create(aFileName);
  try
    Result := IndexHash.Find(aID, Finded);
  finally
    IndexHash.Free;
  end;
end;

function ExportDir(const aFileName: ansistring; const aDir: ansistring): Cardinal;
var
  fn      : String;
  i       : Integer;
  idx     : TMFIndexHash;
  Pos     : uint64;
  bt      : TBytes;
  FileDesp: TMFFileDesp;
begin
  idx := TMFIndexHash.Create(aFileName);
  try
    for i := 0 to idx.Nodes.DataCount - 1 do
    begin
      if idx.GetOne(idx.Nodes.Data[i].Pos, FileDesp, bt) > 0 then
      begin
        bt.SaveToFile(aDir + FileDesp.fileinfo.FileName.AsString);
      end;
    end;
  finally
    idx.Free;
  end;
end;

function PackageDir(const aDir: ansistring; const aFileName: ansistring; aDesp: ansistring; aIndex: ansistring;
  aRebuild: Boolean = true; aHashIndex: Boolean = false; aOnFileAppendSucc: TMFOnFileAppendSucc = nil): Cardinal;
var
  Package : TMFPackage;
  idx     : TMFIndex;
  Pos     : Cardinal;
  idxClass: TMFIndexClass;

begin
  Package := TMFPackage.Create(aFileName, rwlWrite);

  package.OnGetFileName := procedure(const aFileName: ansistring; var aNewFileName: ansistring; var aExt: ansistring)
    begin
      aExt         := extractfileExt(aFileName);
      aNewFileName := extractfilename(changefileext(aFileName, ''));
    end;
  package.OnFileAppendSucc := aOnFileAppendSucc;
  try
    Package.Desp     := aDesp;
    Package.IndexStr := aIndex;

    Result := Package.AppendDir(aDir);
  finally
    package.Free;
  end;
  if not aRebuild then
    exit;
  if Result = 0 then
    exit;
  Pos := Result;

  if aHashIndex then
    idxClass := TMFIndexHash
  else
    idxClass := TMFIndexRBTree;

  idx := idxClass.Create(aFileName, true, true,
    procedure(aCurrent, aTotal: Cardinal)
    begin
      aOnFileAppendSucc('rebuild index ' + aFileName, Pos, aCurrent, aTotal);
    end);
  try
    if not idx.RebuildEnd then
      idx.Rebuild;
  finally
    idx.Free;
  end;
end;

function RebuildIndex_rbtree(aFileName: ansistring; aOnProgress: TMFOnProgress): Cardinal;
var
  idx: TMFIndexRBTree;
begin
  Result := 0;
  if fileexists(aFileName + PubIndexExt_rbtree) then
    DeleteFile(aFileName + PubIndexExt_rbtree);
  idx := TMFIndexRBTree.Create(aFileName, true, true, aOnProgress);
  // idx.OnRebuildProgress := aOnProgress;
  try
    if not idx.RebuildEnd then
      idx.Rebuild;
    Result := idx.Nodes.Count;
  finally
    idx.Free;
  end;

end;

function RebuildIndex(aFileName: ansistring; aOnProgress: TMFOnProgress): Cardinal;
var
  idx: TMFIndexHash;
begin
  Result := 0;
  if fileexists(aFileName + PubIndexExt_Hash) then
    DeleteFile(aFileName + PubIndexExt_Hash);
  idx := TMFIndexHash.Create(aFileName, true, true, aOnProgress);
  // idx.OnRebuildProgress := aOnProgress;
  try
    if not idx.RebuildEnd then
      idx.Rebuild;
    Result := idx.Nodes.DataCount;
  finally
    idx.Free;
  end;
end;

end.
