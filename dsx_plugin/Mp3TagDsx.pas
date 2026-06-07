library Mp3TagDsx;

{
  Mp3TagDsx.pas  -  DSX Search Plugin per DoubleCMD
  ===================================================
  Cerca file MP3 per contenuto dei tag ID3.

  Funzioni esportate richieste dall'API DSX:
    Init(dps, AddFileProc, UpdateStatusProc) -> PluginNr
    StartSearch(PluginNr, SearchRec)
    StopSearch(PluginNr)
    Finalize(PluginNr)

  Record TDsxSearchRecord (da dsxplugin.pas del SDK DC):
    FileMask  : array[0..2047] of Char  - maschera file (es. "*.mp3")
    StartPath : array[0..2047] of Char  - cartella di partenza
    SearchStr : array[0..2047] of Char  - stringa di ricerca (testo libero)
}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, ID3Tags;

// ---- DSX API types ----
const
  DSX_VER_MAJOR = 1;
  DSX_VER_MINOR = 0;

type
  PDsxDefaultParamStruct = ^TDsxDefaultParamStruct;
  TDsxDefaultParamStruct = record
    size         : Integer;
    PluginInterfaceVersionLow  : Byte;
    PluginInterfaceVersionHigh : Byte;
    DefaultIniName : array[0..2047] of AnsiChar;
  end;

  PDsxSearchRecord = ^TDsxSearchRecord;
  TDsxSearchRecord = record
    FileMask  : array[0..2047] of AnsiChar;
    StartPath : array[0..2047] of AnsiChar;
    SearchStr : array[0..2047] of AnsiChar;
    // Campi estesi (ignorati se non supportati)
    _reserved : array[0..511] of Byte;
  end;

  TSAddFileProc    = procedure(PluginNr: Integer; FoundFile: PAnsiChar); cdecl;
  TSUpdateStatusProc = procedure(PluginNr: Integer; Status: PAnsiChar; FilesFound: Integer); cdecl;

// ---- Struttura per ogni istanza di ricerca ----
type
  TSearchInstance = class
    PluginNr    : Integer;
    AddProc     : TSAddFileProc;
    UpdateProc  : TSUpdateStatusProc;
    SearchRec   : TDsxSearchRecord;
    StopFlag    : Boolean;
    Thread      : TThread;
  end;

  TSearchThread = class(TThread)
  private
    FInst : TSearchInstance;
    procedure SearchDir(const ADir, AMask, AQuery: string);
    function  MatchesQuery(const AFile, AQuery: string): Boolean;
  public
    constructor Create(AInst: TSearchInstance);
    procedure Execute; override;
  end;

var
  Instances : TList;

// ---- Ricerca ricorsiva ----

function TSearchThread.MatchesQuery(const AFile, AQuery: string): Boolean;
var
  TagData : TTagInfo;
  Q       : string;
begin
  Result := False;
  Q := LowerCase(AQuery);
  if Q = '' then
  begin
    Result := True; // nessuna query = mostra tutti gli MP3
    Exit;
  end;
  if not ReadTagsFromFile(AFile, TagData) then Exit;
  Result :=
    (Pos(Q, LowerCase(TagData.Title))  > 0) or
    (Pos(Q, LowerCase(TagData.Artist)) > 0) or
    (Pos(Q, LowerCase(TagData.Album))  > 0) or
    (Pos(Q, LowerCase(TagData.Year))   > 0) or
    (Pos(Q, LowerCase(TagData.Genre))  > 0) or
    (Pos(Q, LowerCase(TagData.Track))  > 0) or
    (Pos(Q, LowerCase(TagData.Comment))> 0);
end;

procedure TSearchThread.SearchDir(const ADir, AMask, AQuery: string);
var
  SR      : TSearchRec;
  SubDir  : string;
begin
  if FInst.StopFlag then Exit;

  // Cerca file MP3 corrispondenti alla maschera
  if FindFirst(ADir + AMask, faAnyFile and not faDirectory, SR) = 0 then
  try
    repeat
      if FInst.StopFlag then Break;
      if (SR.Attr and faDirectory) = 0 then
      begin
        if LowerCase(ExtractFileExt(SR.Name)) = '.mp3' then
        begin
          if MatchesQuery(ADir + SR.Name, AQuery) then
          begin
            FInst.AddProc(FInst.PluginNr, PAnsiChar(AnsiString(ADir + SR.Name)));
            FInst.UpdateProc(FInst.PluginNr,
              PAnsiChar(AnsiString('Scansione: ' + ADir)), 0);
          end;
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  // Ricerca nelle sottocartelle
  if FindFirst(ADir + '*', faDirectory, SR) = 0 then
  try
    repeat
      if FInst.StopFlag then Break;
      if ((SR.Attr and faDirectory) <> 0) and
         (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        SubDir := ADir + SR.Name + PathDelim;
        SearchDir(SubDir, AMask, AQuery);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

constructor TSearchThread.Create(AInst: TSearchInstance);
begin
  FInst := AInst;
  FreeOnTerminate := False;
  inherited Create(True);
end;

procedure TSearchThread.Execute;
var
  StartDir : string;
  Mask     : string;
  Query    : string;
begin
  StartDir := string(AnsiString(FInst.SearchRec.StartPath));
  Mask     := string(AnsiString(FInst.SearchRec.FileMask));
  Query    := string(AnsiString(FInst.SearchRec.SearchStr));

  if StartDir = '' then Exit;
  if not DirectoryExists(StartDir) then Exit;
  if Mask = '' then Mask := '*.mp3';

  StartDir := IncludeTrailingPathDelimiter(StartDir);
  SearchDir(StartDir, Mask, Query);
end;

// ---- DSX API ----

function Init(dps: PDsxDefaultParamStruct;
              pAddFileProc: TSAddFileProc;
              pUpdateStatus: TSUpdateStatusProc): Integer; cdecl;
var
  Inst : TSearchInstance;
begin
  if not Assigned(Instances) then
    Instances := TList.Create;

  Inst := TSearchInstance.Create;
  Inst.PluginNr   := Instances.Count;
  Inst.AddProc    := pAddFileProc;
  Inst.UpdateProc := pUpdateStatus;
  Inst.StopFlag   := False;
  Inst.Thread     := nil;
  Instances.Add(Inst);
  Result := Inst.PluginNr;
end;

procedure StartSearch(FPluginNr: Integer; pSearchRec: PDsxSearchRecord); cdecl;
var
  Inst   : TSearchInstance;
  Thread : TSearchThread;
begin
  if not Assigned(Instances) then Exit;
  if (FPluginNr < 0) or (FPluginNr >= Instances.Count) then Exit;
  Inst := TSearchInstance(Instances[FPluginNr]);
  Inst.StopFlag := False;
  Inst.SearchRec := pSearchRec^;
  Thread := TSearchThread.Create(Inst);
  Inst.Thread := Thread;
  Thread.Start;
  Thread.WaitFor; // sincrono per semplicità
end;

procedure StopSearch(FPluginNr: Integer); cdecl;
var
  Inst : TSearchInstance;
begin
  if not Assigned(Instances) then Exit;
  if (FPluginNr < 0) or (FPluginNr >= Instances.Count) then Exit;
  Inst := TSearchInstance(Instances[FPluginNr]);
  Inst.StopFlag := True;
  if Assigned(Inst.Thread) then
  begin
    Inst.Thread.WaitFor;
    FreeAndNil(Inst.Thread);
  end;
end;

procedure Finalize(FPluginNr: Integer); cdecl;
var
  Inst : TSearchInstance;
begin
  if not Assigned(Instances) then Exit;
  if (FPluginNr < 0) or (FPluginNr >= Instances.Count) then Exit;
  Inst := TSearchInstance(Instances[FPluginNr]);
  if Assigned(Inst.Thread) then
  begin
    Inst.StopFlag := True;
    Inst.Thread.WaitFor;
    FreeAndNil(Inst.Thread);
  end;
  Instances[FPluginNr] := nil;
  Inst.Free;
  if FPluginNr = Instances.Count - 1 then
    Instances.Count := Instances.Count - 1;
end;

exports
  Init,
  StartSearch,
  StopSearch,
  Finalize;

begin
  Instances := nil;
end.
