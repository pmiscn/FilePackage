unit Mu.Fileinfo;

interface

uses
  Winapi.Windows, System.SysUtils, System.Variants,
  System.Classes, // Vcl.Graphics,Generics.Collections,
  qjson,
  qdigest, System.Hash;

type

  // TMD5ProgressFunc = procedure(ATotal, AProgress: int64; var Cancel: boolean)
  // of object;
  TOnProgress = reference to procedure(ATotal, AProgress: int64; var Cancel: boolean);
  TOnStatus   = reference to procedure(AStatus: String);

  TIconSize = (isSmall, isLarge, isOpen);
  TObjAttr  = (oaCanCopy, oaCanDelete, oaCanLink, oaCanMove, oaCanRename, oaDropTarget, oaHasPropSheet, oaIsLink,
    oaIsReadOnly, oaIsShare, oaHasSubFolder, oaFileSys, oaFileSysAnc, oaIsFolder, oaRemovable, oaEncrypted);

  TObjAttributes = record
    CanCopy, CanDelete, CanLink, CanMove, CanRename, DropTarget, HasPropSheet, isStorage, IsLink, IsReadOnly, IsShare,
      IsHidden, HasSubFolder, FileSys, FileSysAnc, IsFolder, Removable, Encrypted: boolean;
  end;

  TTypeExe = (teWin32, teWin64, teDOS, teWin16, tePIF, tePOSIX, teOS2, teUnknown, teError);
  TSubType = (stUnknown, stApp, stDLL, stSLL, stDrvUnknown, stDrvComm, stDrvPrint, stDrvKeyb, stDrvLang, stDrvDisplay,
    stDrvMouse, stDrvNetwork, stDrvSystem, stDrvInstall, stDrvSound, stFntUnknown, stFntRaster, stFntVector,
    stFntTrueType, stVXD);
  TOpFunc = (foCopy, foDelete, foMove, foRename);

  TFileVersionInfo = record
    FileType, CompanyName, FileDescription, FileVersion, InternalName, LegalCopyRight, LegalTradeMarks,
      OriginalFileName, ProductName, ProductVersion, Comments, SpecialBuildStr, PrivateBuildStr: String;
    FileFunction: TSubType;
    DebugBuild, PreRelease, SpecialBuild, PrivateBuild, Patched, InfoInferred: boolean;
  end;

  TDocInfo = record
    Title, Subject, Author, Keywords, Comments, Template, LastAuthor, RevNumber: String;
    EditTime: integer;
    LastPrintedDate, CreateDate, LastSaveDate: TDateTime;
    PageCount, WordCount, CharCount, Error: integer;
  end;

  TMd5Str = record

    public
      class function FromStream(astream: TStream; AProgress: TOnProgress = nil): string; static;
      class function FromFile(aFileName: String; AProgress: TOnProgress = nil): string; static;
      class function FromFileMapping(const aFileName: string): string; static;
  end;

  TLocalFileInfo = record
    IsFolder: boolean;
    FileName: String;
    Path: String;
    Name: String;
    Ext: string;
    MD5: String;
    Size: int64;
    FType: String;
    CreateTime, AccessTime, ModifyTime: TDateTime;
    Version: string;
    deep: integer;
    Files: TArray<TLocalFileInfo>;
    private

    public
      class function create(aFileName: string; AProgress: TOnProgress = nil; AFileProgress: TOnProgress = nil;
        AStatus: TOnStatus = nil; aDeep: integer = 0; aHasSub: boolean = true): TLocalFileInfo; static;
      class function GetFileMD5(aFileName: string; AProgress: TOnProgress = nil): String; static;
      class function GetFileTimes(aFileName: string; var Created, Accessed, Modified: TDateTime): boolean; static;

      class function GetFileCreateTimes(aFileName: string): TDateTime; static;

      class function SetDateTime(aFileName: string; const DateTime: TDateTime): integer; static;
      class function GetFileAttr(aFileName: string): integer; static;
      class function SetFileAttr(aFileName: string; Attr: integer): integer; static;
      class function GetFileNameDisplay(aFileName: string): String; static;

      class function GetFileType(aFileName: string): string; static;
      class function GetFileTypeExe(aFileName: string): TTypeExe; static;
      class function GetFileTypeByExt(aExt: string): string; static;

      class function GetFileSize(aFileName: string): int64; static;
      class function GetFileIcon(aFileName: string; isSize: TIconSize): hIcon; static;
      class function GetFileIconByExt(aExt: string; isSize: TIconSize): hIcon; static;
      class function GetFileOwner(aFileName: string; var Domain, Username: String): boolean; static;
      class function GetFileApp(aFileName: string): String; static;

      class procedure GetDLLInfo(aFileName: string; aStrings: TStrings); static;

      class function GetDOCInfo(aFileName: string): TDocInfo; static;
      class function GetFileVersionInfo(aFileName: string): TFileVersionInfo; static;
      class function GetFileVersionNumber(aFileName: string = ''): String; static;
      class function GetObjAttr(aFileName: string; oaAttr: TObjAttr): boolean; static;
      class function GetObjAttributes(aFileName: string; var oaAttr: TObjAttributes): boolean; static;
      class function IsInUse(aFileName: string): boolean; static;
      class function IsAscii(aFileName: string): boolean; static;

      class function IfThen<T>(aValue: boolean; const ATrue, AFalse: T): T; static;

      class procedure PropertiesDialog(aFileName: string); static;

      function FileCount(IsFolder: boolean = true): uint;

      function ToJson(): String;
  end;

  TLocalFileInfos = TArray<TLocalFileInfo>;

  TLocalFileInfos_ = record helper for TLocalFileInfos
    private
      function GetLength: integer;
      procedure SetLength_(const Value: integer);
    public
      property Count: integer read GetLength write SetLength_;
  end;

procedure FileFind(StartingDirectory, Filestyle: string; FilesFound: TStrings; aHasFolder: boolean = false;
  aHasSub: boolean = true);
function getNowFileName(): string;
function getexepath(): String;
function GetModelPath(): String;

implementation

uses imagehlp, shellapi, ShlObj, ole2, System.Win.ComObj;

type

  PPropertySetHeader = ^TPropertySetHeader;

  TPropertySetHeader = record
    wByteOrder: word;  // Always 0xFFFE
    wFormat: word;     // Always 0
    dwOSVer: DWORD;    // System version
    clsid: TCLSID;     // Application CLSID
    dwReserved: DWORD; // Should be 1
  end;

  TFMTID = TCLSID;

  PFormatIDOffset = ^TFormatIDOffset;

  TFormatIDOffset = record
    fmtid: TFMTID;   // Semantic name of a section
    dwOffset: DWORD; // Offset from start of whole property set
    // stream to the section
  end;

  PPropertySectionHeader = ^TPropertySectionHeader;

  TPropertySectionHeader = record
    cbSection: DWORD;   // Size of section
    cProperties: DWORD; // Count of properties in section
  end;

  PPropertyIDOffset = ^TPropertyIDOffset;

  TPropertyIDOffset = record
    propid: DWORD;   // Name of a property
    dwOffset: DWORD; // Offset from the start of the section to that
    // property type/value pair
  end;

  PPropertyIDOffsetList = ^TPropertyIDOffsetList;
  TPropertyIDOffsetList = array [0 .. 255] of TPropertyIDOffset;

  PSerializedPropertyValue = ^TSerializedPropertyValue;

  TSerializedPropertyValue = record
    dwType: DWORD; // Type tag
    prgb: PBYTE;   // The actual property value
  end;

  PSerializedPropertyValueList = ^TSerializedPropertyValueList;
  TSerializedPropertyValueList = array [0 .. 255] of TSerializedPropertyValue;

const
  ATTR_DEFAULT = SHGFI_DISPLAYNAME or SHGFI_EXETYPE or SHGFI_TYPENAME;
  ATTR_ALL     = SHGFI_ATTRIBUTES or ATTR_DEFAULT;

  PID_TITLE        = $00000002;
  PID_SUBJECT      = $00000003;
  PID_AUTHOR       = $00000004;
  PID_KEYWORDS     = $00000005;
  PID_COMMENTS     = $00000006;
  PID_TEMPLATE     = $00000007;
  PID_LASTAUTHOR   = $00000008;
  PID_REVNUMBER    = $00000009;
  PID_EDITTIME     = $0000000A;
  PID_LASTPRINTED  = $0000000B;
  PID_CRAETE_DTM   = $0000000C;
  PID_LASTSAVE_DTM = $0000000D;
  PID_PAGECOUNT    = $0000000E;
  PID_WORDCOUNT    = $0000000F;
  PID_CHARCOUNT    = $00000010;
  PID_THUMBAIL     = $00000011;
  PID_APPNAME      = $00000012;
  PID_SECURITY     = $00000013;
  // GetMP3
  TAGLEN = 127;

function getNowFileName(): string;
var
  szModuleName: array [0 .. 255] of char;
begin
  begin
    GetModuleFileName(hInstance, szModuleName, sizeof(szModuleName));
  end;
  result := (szModuleName);
end;

function getexepath(): String;
begin
  result := extractfilepath(paramstr(0)); // getNowFileName
end;

function GetModelPath(): String;
begin
  result := extractfilepath(getNowFileName);
end;

procedure FreeObject(var AObject);
var
  P: Pointer;
begin
  if Pointer(AObject) <> nil then
  begin
    P                := Pointer(AObject);
    Pointer(AObject) := nil;
{$IFDEF AUTOREFCOUNT}
    if TObject(P).__ObjRelease > 0 then
      TObject(P).DisposeOf;
{$ELSE}
    TObject(P).Destroy;
{$ENDIF}
  end;
end;

procedure FileFind(StartingDirectory, Filestyle: string; FilesFound: TStrings; aHasFolder: boolean = false;
  aHasSub: boolean = true);
/// //////////////////////////////////////////²éÕÒÄ¿Â¼Ê÷
var
  isRootPath: boolean;

  procedure SearchTree;
  var
    SearchRec: TSearchRec;
    DosError : integer;
    dir      : string;
    nowfile  : string;
  begin
    // FilesFound.Sorted := false;
    GetDir(0, dir);
    if aHasFolder and (not isRootPath) then
    begin
      FilesFound.add(dir);
    end;
    if (not aHasSub) then
      if (not isRootPath) then
      begin
        exit;
      end;

    if dir[Length(dir)] <> '\' then
      dir    := dir + '\';
    DosError := FindFirst(Filestyle, 0, SearchRec);
    while DosError = 0 do
    begin
      try
        nowfile := dir + SearchRec.Name;
        FilesFound.add(nowfile);
      except
        on EOutOfResources do
        begin
          abort;
        end;
      end;
      DosError := FindNext(SearchRec);
    end;

    isRootPath := false;
    { Now that we have all the files we need, lets go to a subdirectory. }

    DosError := FindFirst('*.*', faDirectory, SearchRec);
    while DosError = 0 do
    begin
      { If there is one, go there and search. }
      if ((SearchRec.Attr and faDirectory = faDirectory) and (SearchRec.Name <> '.') and (SearchRec.Name <> '..')) then
      begin
        ChDir(SearchRec.Name);

        SearchTree;  { Time for the recursion! }
        ChDir('..'); { Down one level. }
      end;
      DosError := FindNext(SearchRec); { Look for another subdirectory }
    end;
    Finalize(SearchRec);
  end; { SearchTree }

begin
  FilesFound.clear;
  isRootPath := true;
  try
    ChDir(StartingDirectory);
    SearchTree;
  except

  end;
end; { FileFind }

class function TLocalFileInfo.IfThen<T>(aValue: boolean; const ATrue, AFalse: T): T;
begin
  if aValue then
    result := ATrue
  else
    result := AFalse;
end;

{ TLocalFileInfo }
function FileTimeToElapsedTime(FileTime: TFileTime): integer;
var
  SYSTEMTIME   : TSYSTEMTIME;
  LocalFileTime: TFileTime;
begin
  result := 0;
  if FileTimeToLocalFileTime(FileTime, LocalFileTime) and FileTimeToSystemTime(LocalFileTime, SYSTEMTIME) then
    result := SYSTEMTIME.wMinute;
end;

function FileTimeToDateTime(FileTime: TFileTime): TDateTime;
var
  FileDate     : integer;
  LocalFileTime: TFileTime;
begin
  result := 0;
  if FileTimeToLocalFileTime(FileTime, LocalFileTime) and FileTimeToDosDateTime(LocalFileTime, LongRec(FileDate).Hi,
    LongRec(FileDate).Lo) then
    try
      result := FileDateToDateTime(FileDate);
    except
      result := 0;
    end;
end;

function extractDirName(adir: String): String;
var
  I: integer;
begin
  if adir[adir.Length] = PathDelim then
    adir := copy(adir, 1, adir.Length - 1);
  I      := adir.LastDelimiter(PathDelim + DriveDelim);
  result := adir.SubString(I + 1);

end;

class function TLocalFileInfo.create(aFileName: string; AProgress: TOnProgress = nil; AFileProgress: TOnProgress = nil;
  AStatus: TOnStatus = nil; aDeep: integer = 0; aHasSub: boolean = true): TLocalFileInfo;
var
  st      : Tstringlist;
  I, C    : integer;
  isCancel: boolean;
begin

  if directoryExists(aFileName) then
  begin
    result.IsFolder := true;
    result.FileName := aFileName;
    result.Path     := extractfilepath(aFileName);
    result.Ext      := '';
    result.Name     := extractDirName(aFileName);
    result.FType    := '';
    result.deep     := aDeep;

    if aDeep > 0 then
      if not aHasSub then
        exit;
    st := Tstringlist.create;
    try
      FileFind(aFileName, '*.*', st, true, false);

      C                  := st.Count;
      result.Files.Count := C;
      for I              := 0 to C - 1 do
      begin
        if assigned(AFileProgress) then
        begin
          AFileProgress(C, I + 1, isCancel);
          if isCancel then
            break;
        end;
        // if assigned(AStatus) then
        // AStatus(st[I]);
        result.Files[I] := TLocalFileInfo.create(st[I], AProgress, AFileProgress, AStatus, result.deep + 1, aHasSub);
      end;
    finally
      st.Free;
    end;

  end else begin

    if assigned(AStatus) then
      AStatus(aFileName);
    result.deep     := aDeep;
    result.IsFolder := false;
    result.FileName := aFileName;
    result.Path     := extractfilepath(aFileName);
    result.Ext      := extractFileExt(aFileName);
    result.Name     := extractFileName(aFileName);
    // result.MD5 := TLocalFileInfo.GetFileMD5(aFileName, AProgress);
    result.Size    := TLocalFileInfo.GetFileSize(aFileName);
    result.FType   := TLocalFileInfo.GetFileType(aFileName);
    result.Version := TLocalFileInfo.GetFileVersionNumber(aFileName);

    TLocalFileInfo.GetFileTimes(aFileName, result.CreateTime, result.AccessTime, result.ModifyTime);
  end;
end;

function TLocalFileInfo.FileCount(IsFolder: boolean): uint;
var
  I: integer;
begin
  if self.IsFolder then
  begin
    result := 0;
    if IsFolder then
      inc(result);
    for I := 0 to self.Files.Count - 1 do
    begin
      inc(result, Files[I].FileCount(IsFolder));
    end;
  end
  else
    result := 1;
end;

function RVAToPointer(rva: DWORD; const Image: LoadedImage): Pointer;
var
  pDummy: PImageSectionHeader;
begin { RVAToPchar }
  pDummy := nil;
  result := ImageRvaToVa(Image.FileHeader, Image.MappedAddress, rva, pDummy);
  if result = nil then
    RaiseLastWin32Error;
end; { RVAToPointer }

function RVAToPchar(rva: DWORD; const Image: LoadedImage): PAnsiChar;
begin { RVAToPchar }
  result := RVAToPointer(rva, Image);
end; { RVAToPchar }

class procedure TLocalFileInfo.GetDLLInfo(aFileName: string; aStrings: TStrings);
var
  imageinfo       : LoadedImage;
  pExportDirectory: PImageExportDirectory;
  dirsize         : Cardinal;
  fn              : ansistring;
  procedure EnumExports(const ExportDirectory: TImageExportDirectory; const Image: LoadedImage);
  type
    TDWordArray = array [0 .. $FFFFF] of DWORD;
  var
    I                       : Cardinal;
    pNameRVAs, pFunctionRVas: ^TDWordArray;
    pOrdinals               : ^TWordArray;
    Name                    : string;
    address                 : Pointer;
    ordinal                 : word;
  begin { EnumExports }
    pNameRVAs     := RVAToPointer(DWORD(ExportDirectory.AddressOfNames), Image);
    pFunctionRVas := RVAToPointer(DWORD(ExportDirectory.AddressOfFunctions), Image);
    pOrdinals     := RVAToPointer(DWORD(ExportDirectory.AddressOfNameOrdinals), Image);
    for I         := 0 to Pred(ExportDirectory.NumberOfNames) do
    begin
      name    := RVAToPchar(pNameRVAs^[I], Image);
      ordinal := pOrdinals^[I];
      address := Pointer(pFunctionRVas^[ordinal]);

      if (name <> 'TMethodImplementationIntercept') and (name <> '__dbk_fcall_wrapper') and
        (name <> 'dbkFCallWrapperAddr') then

        aStrings.add(name);
    end; { For }
  end;   { EnumExports }

begin
  fn := aFileName;
  if not FileExists(fn) then
    raise Exception.create(aFileName + ' not exists');

  if MapAndLoad(PAnsiChar(fn), nil, @imageinfo, true, true) then
    try
      pExportDirectory := ImageDirectoryEntryToData(imageinfo.MappedAddress, false,
        IMAGE_DIRECTORY_ENTRY_EXPORT, dirsize);

      if pExportDirectory = nil then
        RaiseLastWin32Error
      else
        EnumExports(pExportDirectory^, imageinfo);
    finally
      UnMapAndLoad(@imageinfo);
    end
  else
    RaiseLastWin32Error;
end; { ListDLLExports }

class function TLocalFileInfo.GetDOCInfo(aFileName: string): TDocInfo;
var
  FdiDocInfo           : TDocInfo;
  stgOpen              : IStorage;
  stm                  : IStream;
  PropertySetHeader    : TPropertySetHeader;
  FormatIDOffset       : TFormatIDOffset;
  PropertySectionHeader: TPropertySectionHeader;
  prgPropIDOffset      : PPropertyIDOffsetList;
  prgPropertyValue     : PSerializedPropertyValueList;

  procedure AddProperty(propid: DWORD; Value: Pointer);
  var
    FileTime: TFileTime;
  begin
    with FdiDocInfo do
    begin
      case propid of
        PID_TITLE:
          Title := PAnsiChar(Value);
        PID_SUBJECT:
          Subject := PAnsiChar(Value);
        PID_AUTHOR:
          Author := PAnsiChar(Value);
        PID_KEYWORDS:
          Keywords := PAnsiChar(Value);
        PID_COMMENTS:
          Comments := PAnsiChar(Value);
        PID_TEMPLATE:
          Template := PAnsiChar(Value);
        PID_LASTAUTHOR:
          LastAuthor := PAnsiChar(Value);
        PID_REVNUMBER:
          RevNumber := PAnsiChar(Value);
        PID_EDITTIME:
          begin
            CopyMemory(@FileTime, Value, sizeof(FileTime));
            EditTime := FileTimeToElapsedTime(FileTime);
          end;
        PID_LASTPRINTED:
          begin
            CopyMemory(@FileTime, Value, sizeof(FileTime));
            LastPrintedDate := FileTimeToDateTime(FileTime);
          end;
        PID_CRAETE_DTM:
          begin
            CopyMemory(@FileTime, Value, sizeof(FileTime));
            CreateDate := FileTimeToDateTime(FileTime);
          end;
        PID_LASTSAVE_DTM:
          begin
            CopyMemory(@FileTime, Value, sizeof(FileTime));
            LastSaveDate := FileTimeToDateTime(FileTime);
          end;
        PID_PAGECOUNT:
          CopyMemory(@PageCount, Value, sizeof(PageCount));
        PID_WORDCOUNT:
          CopyMemory(@WordCount, Value, sizeof(WordCount));
        PID_CHARCOUNT:
          CopyMemory(@CharCount, Value, sizeof(CharCount));
        PID_THUMBAIL:
          ;
        PID_APPNAME:
          ;
        PID_SECURITY:
          ;
      end; // case
    end;   // with FdiDocInfo do
  end;

  function ReadPropertySetHeader: HResult;
  var
    cbRead: LongInt;
  begin
    result := stm.read(@PropertySetHeader,
      // Pointer to buffer into which the stream is read
      sizeof(PropertySetHeader), // Specifies the number of bytes to read
      @cbRead                    // Pointer to location that contains actual number of bytes read
      );

    OleCheck(result);
  end;

  function ReadFormatIdOffset: HResult;
  var
    cbRead: LongInt;
  begin
    result := stm.read(@FormatIDOffset,
      // Pointer to buffer into which the stream is read
      sizeof(FormatIDOffset), // Specifies the number of bytes to read
      @cbRead                 // Pointer to location that contains actual number of bytes read
      );

    OleCheck(result);
  end;

  function ReadPropertySectionHeader: HResult;
  var
    cbRead        : LongInt;
    libNewPosition: Largeint;
  begin
    result := stm.Seek(FormatIDOffset.dwOffset,
      // Offset relative to dwOrigin
      STREAM_SEEK_SET, // Specifies the origin for the offset
      libNewPosition   // Pointer to location containing new seek pointer
      );

    OleCheck(result);

    result := stm.read(@PropertySectionHeader,
      // Pointer to buffer into which the stream is read
      sizeof(PropertySectionHeader), // Specifies the number of bytes to read
      @cbRead                        // Pointer to location that contains actual number of bytes read
      );

    OleCheck(result);
  end;

  function ReadPropertyIdOffset: HResult;
  var
    Size  : Cardinal;
    cbRead: LongInt;
  begin
    Size := PropertySectionHeader.cProperties * sizeof(prgPropIDOffset^);
    GetMem(prgPropIDOffset, Size);
    result := stm.read(prgPropIDOffset,
      // Pointer to buffer into which the stream is read
      Size,   // Specifies the number of bytes to read
      @cbRead // Pointer to location that contains actual number of bytes read
      );

    OleCheck(result);
  end;

  function ReadPropertySet: HResult;
  var
    I                       : integer;
    buffer                  : PAnsiChar;
    I4                      : integer;
    dwType                  : DWORD;
    Size                    : Cardinal;
    cb, cbRead              : LongInt;
    FileTime                : TFileTime;
    dlibMove, libNewPosition: Largeint;
  begin
    result := S_OK;
    Size   := PropertySectionHeader.cProperties * sizeof(prgPropertyValue^);
    GetMem(prgPropertyValue, Size);
    for I := 0 to PropertySectionHeader.cProperties - 1 do
    begin
      dlibMove := FormatIDOffset.dwOffset + prgPropIDOffset^[I].dwOffset;
      result   := stm.Seek(dlibMove, // Offset relative to dwOrigin
        STREAM_SEEK_SET,             // Specifies the origin for the offset
        libNewPosition               // Pointer to location containing new seek pointer
        );

      OleCheck(result);

      result := stm.read(@dwType,
        // Pointer to buffer into which the stream is read
        sizeof(dwType), // Specifies the number of bytes to read
        @cbRead         // Pointer to location that contains actual number of bytes read
        );

      OleCheck(result);

      case dwType of
        VT_EMPTY:
          ; { [V]   [P]  nothing }
        VT_NULL:
          ; { [V]        SQL style Null }
        VT_I2:
          ;    { [V][T][P]  2 byte signed int }
        VT_I4: { [V][T][P]  4 byte signed int }
          begin
            result := stm.read(@I4,
              // Pointer to buffer into which the stream is read
              sizeof(I4), // Specifies the number of bytes to read
              @cbRead     // Pointer to location that contains actual number of bytes read
              );

            OleCheck(result);

            AddProperty(prgPropIDOffset^[I].propid, @I4);
          end;
        VT_R4:
          ;
        { [V][T][P]  4 byte real }
        VT_R8:
          ; { [V][T][P]  8 byte real }
        VT_CY:
          ; { [V][T][P]  currency }
        VT_DATE:
          ; { [V][T][P]  date }
        VT_BSTR:
          ; { [V][T][P]  binary string }
        VT_DISPATCH:
          ; { [V][T]     IDispatch FAR* }
        VT_ERROR:
          ; { [V][T]     SCODE }
        VT_BOOL:
          ; { [V][T][P]  True=-1, False=0 }
        VT_VARIANT:
          ; { [V][T][P]  VARIANT FAR* }
        VT_UNKNOWN:
          ; { [V][T]     IUnknown FAR* }

        VT_I1:
          ; { [T]     signed char }
        VT_UI1:
          ; { [T]     unsigned char }
        VT_UI2:
          ; { [T]     unsigned short }
        VT_UI4:
          ; { [T]     unsigned short }
        VT_I8:
          ; { [T][P]  signed 64-bit int }
        VT_UI8:
          ; { [T]     unsigned 64-bit int }
        VT_INT:
          ; { [T]     signed machine int }
        VT_UINT:
          ; { [T]     unsigned machine int }
        VT_VOID:
          ; { [T]     C style void }
        VT_HRESULT:
          ; { [T] }
        VT_PTR:
          ; { [T]     pointer type }
        VT_SAFEARRAY:
          ; { [T]     (use VT_ARRAY in VARIANT) }
        VT_CARRAY:
          ; { [T]     C style array }
        VT_USERDEFINED:
          ;       { [T]     user defined type }
        VT_LPSTR: { [T][P]  null terminated string }
          begin
            result := stm.read(@cb,
              // Pointer to buffer into which the stream is read
              sizeof(cb), // Specifies the number of bytes to read
              @cbRead     // Pointer to location that contains actual number of bytes read
              );

            OleCheck(result);

            GetMem(buffer, cb * sizeof(char));
            try
              result := stm.read(buffer,
                // Pointer to buffer into which the stream is read
                cb,     // Specifies the number of bytes to read
                @cbRead // Pointer to location that contains actual number of bytes read
                );

              OleCheck(result);

              AddProperty(prgPropIDOffset^[I].propid, buffer);
            finally
              FreeMem(buffer);
            end;
          end;
        VT_LPWSTR:
          ; { [T][P]  wide null terminated string }

        VT_FILETIME: { [P]  FILETIME }
          begin
            result := stm.read(@FileTime,
              // Pointer to buffer into which the stream is read
              sizeof(FileTime), // Specifies the number of bytes to read
              @cbRead           // Pointer to location that contains actual number of bytes read
              );

            OleCheck(result);

            AddProperty(prgPropIDOffset^[I].propid, @FileTime);
          end;
        VT_BLOB:
          ;
        { [P]  Length prefixed bytes }
        VT_STREAM:
          ; { [P]  Name of the stream follows }
        VT_STORAGE:
          ; { [P]  Name of the storage follows }
        VT_STREAMED_OBJECT:
          ; { [P]  Stream contains an object }
        VT_STORED_OBJECT:
          ; { [P]  Storage contains an object }
        VT_BLOB_OBJECT:
          ; { [P]  Blob contains an object }
        VT_CF:
          ; { [P]  Clipboard format }
        VT_CLSID:
          ; { [P]  A Class ID }

        VT_VECTOR:
          ; { [P]  simple counted array }
        VT_ARRAY:
          ; { [V]        SAFEARRAY* }
        VT_BYREF:
          ; { [V] }
        VT_RESERVED:
          ;
      end;
    end;
  end;

  procedure InternalInitPropertyDefs;
  begin
    ReadPropertySetHeader;
    ReadFormatIdOffset;
    ReadPropertySectionHeader;
    ReadPropertyIdOffset;
    ReadPropertySet;
  end;

  function OpenStorage: HResult;
  var
    awcName: array [0 .. MAX_PATH - 1] of WideChar;
  begin
    StringToWideChar(aFileName, awcName, MAX_PATH);
    result := StgOpenStorage(awcName,
      // Points to the pathname of the file containing storage object
      nil,         // Points to a previous opening of a root storage object
      STGM_READ or // Specifies the access mode for the object
      STGM_SHARE_EXCLUSIVE, nil,
      // Points to an SNB structure specifying elements to be excluded
      0,      // Reserved; must be zero
      stgOpen // Points to location for returning the storage object
      );

    OleCheck(result);
  end;

  function OpenStream: HResult;
  var
    awcName: array [0 .. MAX_PATH - 1] of WideChar;
  begin
    StringToWideChar(#5'SummaryInformation', awcName, MAX_PATH);
    result := stgOpen.OpenStream(awcName, // Points to name of stream to open
      nil,                                // Reserved; must be NULL
      STGM_READ or                        // Access mode for the new stream
      STGM_SHARE_EXCLUSIVE, 0,            // Reserved; must be zero
      stm                                 // Points to opened stream object
      );

    OleCheck(result);
  end;

  procedure InternalOpen;
  begin
    if aFileName <> '' then
    begin
      OpenStorage;
      OpenStream;
      InternalInitPropertyDefs;
    end;
  end;

  procedure InternalClose;
  begin
    if prgPropertyValue <> nil then
      FreeMem(prgPropertyValue);
    if prgPropIDOffset <> nil then
      FreeMem(prgPropIDOffset);
    if stm <> nil then
      stm.Release;
    if stgOpen <> nil then
      stgOpen.Release;
    stgOpen          := nil;
    stm              := nil;
    prgPropIDOffset  := nil;
    prgPropertyValue := nil;
  end;

begin
  FdiDocInfo.Error := -1;
  stgOpen          := nil;
  stm              := nil;
  prgPropIDOffset  := nil;
  prgPropertyValue := nil;
  if FileExists(aFileName) then
  begin
    try
      InternalOpen;
      InternalClose;
    except
      FdiDocInfo.Error := 1; // OLE-error occured
    end;
  end
  else
    FdiDocInfo.Error := 0; // File doesn't exist
  result             := FdiDocInfo;

end;

class function TLocalFileInfo.GetFileApp(aFileName: string): String;
var
  app       : array [1 .. 250] of char;
  I         : integer;
  DefaultDir: String;
begin
  DefaultDir := GetCurrentDir;
  FillChar(app, sizeof(app), ' ');
  app[250] := #0;
  I        := FindExecutable(@aFileName[1], @DefaultDir[1], @app[1]);
  if I <= 32 then
    result := ''
  else
    result := app;

end;

class function TLocalFileInfo.GetFileAttr(aFileName: string): integer;
begin
  result := FileGetAttr(aFileName);
end;

class function TLocalFileInfo.GetFileIcon(aFileName: string; isSize: TIconSize): hIcon;
var
  shFileInfo                    : TSHFileInfo;
  dwFileAttr, cbFileInfo, uFlags: uint;
begin
  case isSize of
    isSmall:
      uFlags := (SHGFI_ICON or SHGFI_SMALLICON);
    isLarge:
      uFlags := (SHGFI_ICON or SHGFI_LARGEICON);
    isOpen:
      uFlags := (SHGFI_ICON or SHGFI_OPENICON);
  else
    uFlags := SHGFI_ICON or SHGFI_SMALLICON;
  end;
  SHGetFileInfo(PWideChar(aFileName), dwFileAttr, shFileInfo, cbFileInfo, uFlags);
  result := shFileInfo.hIcon;
end;

class function TLocalFileInfo.GetFileIconByExt(aExt: string; isSize: TIconSize): hIcon;
var
  shFileInfo                    : TSHFileInfo;
  dwFileAttr, cbFileInfo, uFlags: uint;
begin
  uFlags := SHGFI_SYSICONINDEX or SHGFI_USEFILEATTRIBUTES or SHGFI_ICON;
  case isSize of
    isSmall:
      uFlags := uFlags or SHGFI_SMALLICON;
    isLarge:
      uFlags := uFlags or SHGFI_LARGEICON;
    isOpen:
      uFlags := uFlags or SHGFI_OPENICON;
  else
    uFlags := uFlags or SHGFI_SMALLICON;
  end;
  dwFileAttr := FILE_ATTRIBUTE_NORMAL;
  SHGetFileInfo(PWideChar(aExt), dwFileAttr, shFileInfo, cbFileInfo, uFlags);
  result := shFileInfo.hIcon;
end;

class function TLocalFileInfo.GetFileVersionInfo(aFileName: string): TFileVersionInfo;
var
  rSHFI      : TSHFileInfo;
  iRet       : integer;
  VerSize    : integer;
  VerBuf     : PAnsiChar;
  VerBufValue: Pointer;

  VerBufLen: uint;
  VerHandle: uint;

  VerKey       : String;
  FixedFileInfo: PVSFixedFileInfo;
  sAppNamePath : String;

  // dwFileType, dwFileSubtype
  function GetFileSubType(FixedFileInfo: PVSFixedFileInfo): TSubType;
  begin
    case FixedFileInfo.dwFileType of

      VFT_UNKNOWN:
        result := stUnknown;
      VFT_APP:
        result := stApp;
      VFT_DLL:
        result := stDLL;
      VFT_STATIC_LIB:
        result := stSLL;

      VFT_DRV:
        case FixedFileInfo.dwFileSubtype of
          VFT2_UNKNOWN:
            result := stDrvUnknown;
          VFT2_DRV_COMM:
            result := stDrvComm;
          VFT2_DRV_PRINTER:
            result := stDrvPrint;
          VFT2_DRV_KEYBOARD:
            result := stDrvKeyb;
          VFT2_DRV_LANGUAGE:
            result := stDrvLang;
          VFT2_DRV_DISPLAY:
            result := stDrvDisplay;
          VFT2_DRV_MOUSE:
            result := stDrvMouse;
          VFT2_DRV_NETWORK:
            result := stDrvNetwork;
          VFT2_DRV_SYSTEM:
            result := stDrvSystem;
          VFT2_DRV_INSTALLABLE:
            result := stDrvSystem;
          VFT2_DRV_SOUND:
            result := stDrvSound;
        end;
      VFT_FONT:
        case FixedFileInfo.dwFileSubtype of
          VFT2_UNKNOWN:
            result := stFntUnknown;
          VFT2_FONT_RASTER:
            result := stFntRaster;
          VFT2_FONT_VECTOR:
            result := stFntVector;
          VFT2_FONT_TRUETYPE:
            result := stFntTrueType;
        else
          ;
        end;
      VFT_VXD:
        result := stVXD;
    end;
  end;

  function HasdwFileFlags(FixedFileInfo: PVSFixedFileInfo; Flag: word): boolean;
  begin
    result := (FixedFileInfo.dwFileFlagsMask and FixedFileInfo.dwFileFlags and Flag) = Flag;
  end;

  function GetFixedFileInfo: PVSFixedFileInfo;
  begin
    if not VerQueryValue(VerBuf, '', Pointer(result), VerBufLen) then
      result := nil
  end;

  function GetInfo(const aKey: String): String;
  begin
    result := '';
    VerKey := Format('\StringFileInfo\%.4x%.4x\%s', [LoWord(integer(VerBufValue^)),
      HiWord(integer(VerBufValue^)), aKey]);
    if VerQueryValue(VerBuf, PWideChar(VerKey), VerBufValue, VerBufLen) then
      result := StrPas(PChar(VerBufValue));
  end;

  function QueryValue(const aValue: String): String;
  begin
    result := '';
    // obtain version information about the specified file
    if Winapi.Windows.GetFileVersionInfo(PWideChar(sAppNamePath), VerHandle, VerSize, VerBuf) and
    // return selected version information
      VerQueryValue(VerBuf, '\VarFileInfo\Translation', VerBufValue, VerBufLen) then
      result := GetInfo(aValue);
  end;

begin
  sAppNamePath := aFileName;
  // Initialize the Result
  with result do
  begin
    FileType         := '';
    CompanyName      := '';
    FileDescription  := '';
    FileVersion      := '';
    InternalName     := '';
    LegalCopyRight   := '';
    LegalTradeMarks  := '';
    OriginalFileName := '';
    ProductName      := '';
    ProductVersion   := '';
    Comments         := '';
    SpecialBuildStr  := '';
    PrivateBuildStr  := '';
    DebugBuild       := false;
    Patched          := false;
    PreRelease       := false;
    SpecialBuild     := false;
    PrivateBuild     := false;
    InfoInferred     := false;
  end;

  // Get the file type
  if SHGetFileInfo(PWideChar(sAppNamePath), 0, rSHFI, sizeof(rSHFI), SHGFI_TYPENAME) <> 0 then
  begin
    result.FileType := rSHFI.szTypeName;
  end;

  iRet := SHGetFileInfo(PWideChar(sAppNamePath), 0, rSHFI, sizeof(rSHFI), SHGFI_EXETYPE);
  if iRet <> 0 then
  begin
    // determine whether the OS can obtain version information
    VerSize := GetFileVersionInfoSize(PWideChar(sAppNamePath), VerHandle);
    if VerSize > 0 then
    begin
      VerBuf := AllocMem(VerSize);
      try
        with result do
        begin
          CompanyName      := QueryValue('CompanyName');
          FileDescription  := QueryValue('FileDescription');
          FileVersion      := QueryValue('FileVersion');
          InternalName     := QueryValue('InternalName');
          LegalCopyRight   := QueryValue('LegalCopyRight');
          LegalTradeMarks  := QueryValue('LegalTradeMarks');
          OriginalFileName := QueryValue('OriginalFileName');
          ProductName      := QueryValue('ProductName');
          ProductVersion   := QueryValue('ProductVersion');
          Comments         := QueryValue('Comments');
          SpecialBuildStr  := QueryValue('SpecialBuild');
          PrivateBuildStr  := QueryValue('PrivateBuild');
          // Fill the  VS_FIXEDFILEINFO structure
          FixedFileInfo := GetFixedFileInfo;
          DebugBuild    := HasdwFileFlags(FixedFileInfo, VS_FF_DEBUG);
          PreRelease    := HasdwFileFlags(FixedFileInfo, VS_FF_PRERELEASE);
          PrivateBuild  := HasdwFileFlags(FixedFileInfo, VS_FF_PRIVATEBUILD);
          SpecialBuild  := HasdwFileFlags(FixedFileInfo, VS_FF_SPECIALBUILD);
          Patched       := HasdwFileFlags(FixedFileInfo, VS_FF_PATCHED);
          InfoInferred  := HasdwFileFlags(FixedFileInfo, VS_FF_INFOINFERRED);
          FileFunction  := GetFileSubType(FixedFileInfo);
        end;
      finally
        FreeMem(VerBuf, VerSize);
      end
    end;
  end

end;

class function TLocalFileInfo.GetFileVersionNumber(aFileName: string): String;
  function GetFileVersion_(FileName: string): string;
  type
    PVerInfo = ^TVS_FIXEDFILEINFO;

    TVS_FIXEDFILEINFO = record
      dwSignature: LongInt;
      dwStrucVersion: LongInt;
      dwFileVersionMS: LongInt;
      dwFileVersionLS: LongInt;
      dwFileFlagsMask: LongInt;
      dwFileFlags: LongInt;
      dwFileOS: LongInt;
      dwFileType: LongInt;
      dwFileSubtype: LongInt;
      dwFileDateMS: LongInt;
      dwFileDateLS: LongInt;
    end;
  var
    ExeNames: array [0 .. 255] of char;
    zKeyPath: array [0 .. 255] of char;
    VerInfo : PVerInfo;
    Buf     : Pointer;
    Sz      : word;
    L, Len  : Cardinal;
  begin
    StrPCopy(ExeNames, FileName);
    Sz := GetFileVersionInfoSize(ExeNames, L);
    if Sz = 0 then
    begin
      result := '';
      exit;
    end;
    try
      GetMem(Buf, Sz);
      try
        Winapi.Windows.GetFileVersionInfo(ExeNames, 0, Sz, Buf);
        if VerQueryValue(Buf, '\', Pointer(VerInfo), Len) then
        begin
          result := IntToStr(HiWord(VerInfo.dwFileVersionMS)) + '.' + IntToStr(LoWord(VerInfo.dwFileVersionMS)) + '.' +
            IntToStr(HiWord(VerInfo.dwFileVersionLS)) + '.' + IntToStr(LoWord(VerInfo.dwFileVersionLS));
        end;
      finally
        FreeMem(Buf);
      end;
    except
      result := '0.0.0.0';
    end;
  end;

begin
  if aFileName = '' then
    aFileName := getNowFileName;
  result      := TLocalFileInfo.GetFileVersionInfo(aFileName).FileVersion;
  if result = '' then
    result := GetFileVersion_(aFileName);
end;

class function TLocalFileInfo.SetFileAttr(aFileName: string; Attr: integer): integer;
begin
  result := FileSetAttr(aFileName, Attr);
end;

class function TLocalFileInfo.GetFileMD5(aFileName: string; AProgress: TOnProgress = nil): String;
begin
  result := TMd5Str.FromFile(aFileName, AProgress);
end;

class function TLocalFileInfo.GetFileNameDisplay(aFileName: string): String;
var
  shFileInfo                    : TSHFileInfo;
  dwFileAttr, cbFileInfo, uFlags: uint;
begin
  uFlags     := ATTR_ALL;
  dwFileAttr := 0;
  SHGetFileInfo(PWideChar(aFileName), dwFileAttr, shFileInfo, cbFileInfo, uFlags);
  result := string(shFileInfo.szDisplayName);

end;

class function TLocalFileInfo.GetFileOwner(aFileName: string; var Domain, Username: String): boolean;
var
  SecDescr               : PSecurityDescriptor;
  SizeNeeded, SizeNeeded2: DWORD;
  OwnerSID               : PSID;
  OwnerDefault           : BOOL;
  OwnerName, DomainName  : PChar;
  OwnerType              : SID_NAME_USE;
begin
  GetFileOwner := false;
  GetMem(SecDescr, 1024);
  GetMem(OwnerSID, sizeof(PSID));
  GetMem(OwnerName, 1024);
  GetMem(DomainName, 1024);
  try
    if not GetFileSecurity(PWideChar(aFileName), OWNER_SECURITY_INFORMATION, SecDescr, 1024, SizeNeeded) then
      exit;
    if not GetSecurityDescriptorOwner(SecDescr, OwnerSID, OwnerDefault) then
      exit;
    SizeNeeded  := 1024;
    SizeNeeded2 := 1024;
    if not LookupAccountSID(nil, OwnerSID, OwnerName, SizeNeeded, DomainName, SizeNeeded2, OwnerType) then
      exit;
    Domain   := DomainName;
    Username := OwnerName;
  finally
    FreeMem(SecDescr);
    FreeMem(OwnerName);
    FreeMem(DomainName);
  end;
  GetFileOwner := true;

end;

class function TLocalFileInfo.GetFileSize(aFileName: string): int64;
var
  SearchRec: TSearchRec;
begin
  if FindFirst(ExpandFileName(aFileName), faAnyFile, SearchRec) = 0 then
  begin
    result := SearchRec.Size;
    FindClose(SearchRec);
  end
  else
    result := -1;
end;

class function TLocalFileInfo.GetFileTimes(aFileName: string; var Created, Accessed, Modified: TDateTime): boolean;
var
  H                  : THandle;
  Info1, Info2, Info3: TFileTime;
  SysTimeStruct      : SYSTEMTIME;
  TimeZoneInfo       : TTimeZoneInformation;
  Bias               : Double;

var
  data   : WIN32_FILE_ATTRIBUTE_DATA;
  systime: SYSTEMTIME;
  local  : FileTime;
begin
  result := false;

  if FileExists(aFileName) then
  begin

    Bias := 0;
    H    := FileOpen(aFileName, fmOpenRead or fmShareDenyNone);
    if H > 0 then
    begin
      try
        if GetTimeZoneInformation(TimeZoneInfo) <> $FFFFFFFF then
          Bias := TimeZoneInfo.Bias / 1440; // 60x24
        GetFileTime(H, @Info1, @Info2, @Info3);
        if FileTimeToSystemTime(Info1, SysTimeStruct) then
          Created := SystemTimeToDateTime(SysTimeStruct) - Bias;
        if FileTimeToSystemTime(Info2, SysTimeStruct) then
          Accessed := SystemTimeToDateTime(SysTimeStruct) - Bias;
        if FileTimeToSystemTime(Info3, SysTimeStruct) then
          Modified := SystemTimeToDateTime(SysTimeStruct) - Bias;
        result     := true;
      finally
        FileClose(H);
      end;
    end;
  end else if directoryExists(aFileName) then

  begin
    if (not GetFileAttributesEx(PChar(aFileName), GetFileExInfoStandard, @data)) then
      exit;
    Created  := FileTimeToDateTime(data.ftCreationTime);
    Accessed := FileTimeToDateTime(data.ftLastAccessTime);
    Modified := FileTimeToDateTime(data.ftLastWriteTime);
  end;
end;

class function TLocalFileInfo.GetFileCreateTimes(aFileName: string): TDateTime;
var
  H                  : THandle;
  Info1, Info2, Info3: TFileTime;
  SysTimeStruct      : SYSTEMTIME;
  TimeZoneInfo       : TTimeZoneInformation;
  Bias               : Double;
begin
  result := 0;
  Bias   := 0;
  H      := FileOpen(aFileName, fmOpenRead or fmShareDenyNone);
  if H > 0 then
  begin
    try
      if GetTimeZoneInformation(TimeZoneInfo) <> $FFFFFFFF then
        Bias := TimeZoneInfo.Bias / 1440; // 60x24
      GetFileTime(H, @Info1, @Info2, @Info3);
      if FileTimeToSystemTime(Info1, SysTimeStruct) then
        result := SystemTimeToDateTime(SysTimeStruct) - Bias;

    finally
      FileClose(H);
    end;
  end;
end;

class function TLocalFileInfo.GetFileType(aFileName: string): string;
var
  shFileInfo                    : TSHFileInfo;
  dwFileAttr, cbFileInfo, uFlags: uint;
begin
  uFlags     := ATTR_ALL;
  dwFileAttr := 0;
  SHGetFileInfo(PWideChar(aFileName), dwFileAttr, shFileInfo, cbFileInfo, uFlags);
  result := string(shFileInfo.szTypeName);
end;

class function TLocalFileInfo.GetFileTypeByExt(aExt: string): string;
var
  shFileInfo                    : TSHFileInfo;
  dwFileAttr, cbFileInfo, uFlags: uint;
begin
  uFlags     := SHGFI_TYPENAME or SHGFI_USEFILEATTRIBUTES; // ATTR_ALL;
  dwFileAttr := FILE_ATTRIBUTE_NORMAL;
  SHGetFileInfo(PWideChar(aExt), dwFileAttr, shFileInfo, cbFileInfo, uFlags);
  result := string(shFileInfo.szTypeName);
end;

class function TLocalFileInfo.GetFileTypeExe(aFileName: string): TTypeExe;
var
  BinaryType: DWORD;
begin
  if GetBinaryType(PChar(aFileName), BinaryType) then
    case BinaryType of
      SCS_32BIT_BINARY:
        result := teWin32;
      SCS_64BIT_BINARY:
        result := teWin64;
      SCS_DOS_BINARY:
        result := teDOS;
      SCS_WOW_BINARY:
        result := teWin16;
      SCS_PIF_BINARY:
        result := tePIF;
      SCS_POSIX_BINARY:
        result := tePOSIX;
      SCS_OS216_BINARY:
        result := teOS2;
    else
      result := teUnknown;
    end
  else
    result := teError;

end;

class function TLocalFileInfo.GetObjAttributes(aFileName: string; var oaAttr: TObjAttributes): boolean;
var
  sfgao: integer;
var
  shFileInfo                    : TSHFileInfo;
  dwFileAttr, cbFileInfo, uFlags: uint;
begin
  sfgao  := 0;
  uFlags := ATTR_ALL;
  result := SHGetFileInfo(PWideChar(aFileName), dwFileAttr, shFileInfo, cbFileInfo, uFlags) <> 0;
  if result then
    with oaAttr do
    begin
      CanCopy   := (shFileInfo.dwAttributes and SFGAO_CANCOPY) > 0;
      CanDelete := (shFileInfo.dwAttributes and SFGAO_CANDELETE) > 0;
      CanLink   := (shFileInfo.dwAttributes and SFGAO_CANLINK) > 0;
      CanMove   := (shFileInfo.dwAttributes and SFGAO_CANMOVE) > 0;
      CanRename := (shFileInfo.dwAttributes and SFGAO_CANRENAME) > 0;

      DropTarget   := (shFileInfo.dwAttributes and SFGAO_DROPTARGET) > 0;
      HasPropSheet := (shFileInfo.dwAttributes and SFGAO_HASPROPSHEET) > 0;
      IsLink       := (shFileInfo.dwAttributes and SFGAO_LINK) > 0;
      IsReadOnly   := (shFileInfo.dwAttributes and SFGAO_READONLY) > 0;
      IsShare      := (shFileInfo.dwAttributes and SFGAO_SHARE) > 0;
      IsHidden     := (shFileInfo.dwAttributes and SFGAO_HIDDEN) > 0;
      isStorage    := (shFileInfo.dwAttributes and SFGAO_STORAGE) > 0;

      HasSubFolder := (shFileInfo.dwAttributes and SFGAO_HASSUBFOLDER) > 0;
      FileSys      := (shFileInfo.dwAttributes and SFGAO_FILESYSTEM) > 0;
      FileSysAnc   := (shFileInfo.dwAttributes and SFGAO_FILESYSANCESTOR) > 0;

      IsFolder  := (shFileInfo.dwAttributes and SFGAO_FOLDER) > 0;
      Removable := (shFileInfo.dwAttributes and SFGAO_REMOVABLE) > 0;

      Encrypted := (shFileInfo.dwAttributes and SFGAO_ENCRYPTED) > 0;

    end;
end;

class function TLocalFileInfo.GetObjAttr(aFileName: string; oaAttr: TObjAttr): boolean;
var
  sfgao: integer;
var
  shFileInfo                    : TSHFileInfo;
  dwFileAttr, cbFileInfo, uFlags: uint;
begin
  sfgao  := 0;
  uFlags := ATTR_ALL;
  SHGetFileInfo(PWideChar(aFileName), dwFileAttr, shFileInfo, cbFileInfo, uFlags);
  case oaAttr of
    oaCanCopy:
      sfgao := SFGAO_CANCOPY;
    oaCanDelete:
      sfgao := SFGAO_CANDELETE;
    oaCanLink:
      sfgao := SFGAO_CANLINK;
    oaCanMove:
      sfgao := SFGAO_CANMOVE;
    oaCanRename:
      sfgao := SFGAO_CANRENAME;
    oaDropTarget:
      sfgao := SFGAO_DROPTARGET;
    oaHasPropSheet:
      sfgao := SFGAO_HASPROPSHEET;
    oaIsLink:
      sfgao := SFGAO_LINK;
    oaIsReadOnly:
      sfgao := SFGAO_READONLY;
    oaIsShare:
      sfgao := SFGAO_SHARE;
    oaHasSubFolder:
      sfgao := SFGAO_HASSUBFOLDER;
    oaFileSys:
      sfgao := SFGAO_FILESYSTEM;
    oaFileSysAnc:
      sfgao := SFGAO_FILESYSANCESTOR;
    oaIsFolder:
      sfgao := SFGAO_FOLDER;
    oaRemovable:
      sfgao := SFGAO_REMOVABLE;
  end;
  result := ((shFileInfo.dwAttributes and sfgao) > 0);

end;

class function TLocalFileInfo.IsAscii(aFileName: string): boolean;
const
  SETT = 2048;
var
  I                         : integer;
  F                         : file;
  a                         : boolean;
  TotSize, IncSize, ReadSize: integer;
  C                         : array [0 .. SETT] of Byte;
begin
  if FileExists(aFileName) then
  begin
{$I-}
    assignfile(F, aFileName);
    Reset(F, 1);
    TotSize := FileSize(F);
    IncSize := 0;
    a       := true;
    while (IncSize < TotSize) and (a = true) do
    begin
      ReadSize := SETT;
      if IncSize + ReadSize > TotSize then
        ReadSize := TotSize - IncSize;
      IncSize    := IncSize + ReadSize;
      BlockRead(F, C, ReadSize);
      // Iterate
      for I := 0 to ReadSize - 1 do
        if (C[I] < 32) and (not(C[I] in [9, 10, 13, 26])) then
          a := false;
    end; { while }
    closefile(F);
{$I+}
    if IOResult <> 0 then
      result := false
    else
      result := a;
  end;
end;

class function TLocalFileInfo.IsInUse(aFileName: string): boolean;
var
  HFileRes: HFILE;
begin
  result := false;
  if not FileExists(aFileName) then
    exit;
  HFileRes := CreateFile(PWideChar(aFileName), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);
  result := (HFileRes = INVALID_HANDLE_VALUE);
  if not result then
    CloseHandle(HFileRes);

end;

class function TLocalFileInfo.SetDateTime(aFileName: string; const DateTime: TDateTime): integer;
var
  FileHandle: integer;
  Succes    : integer;
begin
  FileHandle := FileOpen(aFileName, fmOpenRead);
  Succes     := FileSetDate(FileHandle, DateTimeToFileDate(DateTime));
  FileClose(FileHandle);
  result := Succes;

end;

class procedure TLocalFileInfo.PropertiesDialog(aFileName: string);
var
  sei: TShellExecuteInfo;
begin
  FillChar(sei, sizeof(sei), 0);
  sei.cbSize := sizeof(sei);
  sei.lpFile := PWideChar(aFileName);
  sei.lpVerb := 'properties';
  sei.fMask  := SEE_MASK_INVOKEIDLIST;
  ShellExecuteEx(@sei);
end;

function TLocalFileInfo.ToJson: String;
var
  js: TQJson;
begin
  js := TQJson.create;
  try
    js.FromRecord<TLocalFileInfo>(self);
    result := js.ToString;
  finally
    js.Free;
  end;
end;

{ TLocalFileInfos_ }

function TLocalFileInfos_.GetLength: integer;
begin
  result := Length(self);
end;

procedure TLocalFileInfos_.SetLength_(const Value: integer);
begin
  SetLength(self, Value);
end;

{ TFileMd5 }

const
  MD5BufSize     = 1024 * 1024 * 1;   // 1M
  MD5FileSizeMax = 1024 * 1024 * 256; // 256M

class function TMd5Str.FromStream(astream: TStream; AProgress: TOnProgress = nil): string;
var
  MD5                         : THashMD5;
  buffer                      : Pointer;
  Cancel                      : boolean;
  BufSize, ReadSize           : LongInt;
  OldPosition, Total, Progress: int64;

begin
  Total := astream.Size;
  if Total = 0 then
    exit;

  Progress         := 0;
  Cancel           := false;
  OldPosition      := astream.Position;
  astream.Position := 0;

  BufSize := TLocalFileInfo.IfThen<LongInt>(Total < MD5BufSize, Total, MD5BufSize);
  GetMem(buffer, BufSize);
  try
    MD5 := THashMD5.create;
    repeat
      ReadSize := astream.read(buffer^, BufSize);
      if ReadSize <> 0 then
      begin
        inc(Progress, ReadSize);

        MD5.Update(buffer, ReadSize);

        if assigned(AProgress) then
        begin
          AProgress(Total, Progress, Cancel);

          if Cancel then
            exit;
        end;

      end;

    until (ReadSize = 0) or (Progress = Total);

    result := MD5.HashAsString;
  finally
    astream.Position := OldPosition;
    FreeMem(buffer, BufSize);
  end;

end;

class function TMd5Str.FromFile(aFileName: String; AProgress: TOnProgress = nil): string;
  function FileSizeIsLargeThanMax(aFileName: string): boolean;
  begin
    // {$IFNDEF IDE_XE8up}
    // Exit(True);
    // {$ENDIF}
    // {$IFDEF MSWINDOWS}
    result := TLocalFileInfo.GetFileSize(aFileName) > MD5FileSizeMax;
    // {$ELSE}
    // Result := True;
    // {$ENDIF}
  end;

var
  FileStream: TBufferedFileStream;
  aFileSize : integer;
begin
  result    := EmptyStr;
  aFileSize := TLocalFileInfo.GetFileSize(aFileName);

  // if aFileSize < MD5FileSizeMax then
  begin
    FileStream := TBufferedFileStream.create(aFileName, fmOpenRead, MD5BufSize);
    try
      result := TMd5Str.FromStream(FileStream, AProgress);
    finally
      FreeObject(FileStream);
    end;
  end
  // else
  // begin
  // result := TMd5Str.FromFileMapping(aFileName);
  // end;
end;

class function TMd5Str.FromFileMapping(const aFileName: string): string;
var
  MD5        : THashMD5;
  FileHandle : THandle;
  MapHandle  : THandle;
  ViewPointer: Pointer;
begin
  result := '';

  FileHandle := CreateFile(PChar(aFileName), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);

  if FileHandle = INVALID_HANDLE_VALUE then
    exit;

  try
    MapHandle := CreateFileMapping(FileHandle, nil, PAGE_READONLY, 0, 0, nil);
    if MapHandle <> 0 then
    begin
      try
        ViewPointer := MapViewOfFile(MapHandle, FILE_MAP_READ, 0, 0, 0);
        if ViewPointer <> nil then
        begin
          MD5 := THashMD5.create;
          try
            MD5.Update(ViewPointer, Winapi.Windows.GetFileSize(FileHandle, nil));
            result := MD5.HashAsString;
          finally
            UnmapViewOfFile(ViewPointer);
          end;
        end
        else
          raise Exception.create('MapViewOfFile Failed.' + GetLastError.ToString);

      finally
        CloseHandle(MapHandle);
      end;
    end
    else
      raise Exception.create('CreateFileMapping Failed.' + GetLastError.ToString);
  finally
    CloseHandle(FileHandle);
  end;

end;

initialization

finalization

end.
