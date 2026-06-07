library Mp3TagDsx;

{
  Mp3TagDsx.pas  –  DSX Plugin per DoubleCMD
  ===========================================
  Aggiunge voci di menu contestuale per:
    1. Mostra tag         – finestra informazioni tag del file selezionato
    2. Rinomina dai tag   – rinomina con pattern (es. %track% - %artist% - %title%)
    3. Editor tag         – modifica tag singolo file
    4. Batch tag editor   – modifica tag su tutti i file MP3 selezionati
    5. Pulizia tag        – rimuove spazi doppi e caratteri non validi

  Compilare con:
    lazbuild Mp3TagDsx.lpi
  Output: Mp3TagDsx.dsx
}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Dialogs, Forms, Controls, StdCtrls, ExtCtrls,
  ComCtrls, Grids, LCLType, ID3Tags;

// ---- DSX API Constants ----
const
  DSX_OK            = 0;
  DSX_ERROR         = 1;
  DSX_NOTIMPL       = 2;

  MENUITEM_SHOW_TAGS    = 0;
  MENUITEM_RENAME       = 1;
  MENUITEM_EDIT_TAG     = 2;
  MENUITEM_BATCH_EDIT   = 3;
  MENUITEM_CLEAN_TAGS   = 4;
  MENUITEM_COUNT        = 5;

// ---- Form: Editor tag singolo file ----

type
  TTagEditorForm = class(TForm)
    lblTitle   : TLabel;  edTitle   : TEdit;
    lblArtist  : TLabel;  edArtist  : TEdit;
    lblAlbum   : TLabel;  edAlbum   : TEdit;
    lblYear    : TLabel;  edYear    : TEdit;
    lblTrack   : TLabel;  edTrack   : TEdit;
    lblGenre   : TLabel;  edGenre   : TEdit;
    lblComment : TLabel;  edComment : TEdit;
    btnOK      : TButton;
    btnCancel  : TButton;
    procedure FormCreate(Sender: TObject);
  public
    Tag: TTagInfo;
    procedure LoadTag(const ATag: TTagInfo);
    procedure SaveTag(out ATag: TTagInfo);
  end;

procedure TTagEditorForm.FormCreate(Sender: TObject);
var
  Row: Integer;

  procedure MakeRow(var lbl: TLabel; const LblText: string;
                    var ed: TEdit; ARow: Integer);
  begin
    lbl := TLabel.Create(Self);
    lbl.Parent := Self;
    lbl.Caption := LblText;
    lbl.Left := 12;
    lbl.Top  := 12 + ARow * 32;
    lbl.Width := 70;
    ed := TEdit.Create(Self);
    ed.Parent := Self;
    ed.Left   := 88;
    ed.Top    := 8 + ARow * 32;
    ed.Width  := 320;
  end;

begin
  Caption := 'Editor Tag MP3';
  Width   := 450;
  Height  := 340;
  Position := poScreenCenter;
  BorderStyle := bsDialog;

  MakeRow(lblTitle,   'Titolo:',   edTitle,   0);
  MakeRow(lblArtist,  'Artista:',  edArtist,  1);
  MakeRow(lblAlbum,   'Album:',    edAlbum,   2);
  MakeRow(lblYear,    'Anno:',     edYear,    3);
  MakeRow(lblTrack,   'Traccia:',  edTrack,   4);
  MakeRow(lblGenre,   'Genere:',   edGenre,   5);
  MakeRow(lblComment, 'Commento:', edComment, 6);
  edYear.Width  := 60;
  edTrack.Width := 60;

  btnOK := TButton.Create(Self);
  btnOK.Parent  := Self;
  btnOK.Caption := 'Salva';
  btnOK.ModalResult := mrOK;
  btnOK.Left    := 260;
  btnOK.Top     := 268;
  btnOK.Width   := 80;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent  := Self;
  btnCancel.Caption := 'Annulla';
  btnCancel.ModalResult := mrCancel;
  btnCancel.Left    := 350;
  btnCancel.Top     := 268;
  btnCancel.Width   := 80;
end;

procedure TTagEditorForm.LoadTag(const ATag: TTagInfo);
begin
  edTitle.Text   := ATag.Title;
  edArtist.Text  := ATag.Artist;
  edAlbum.Text   := ATag.Album;
  edYear.Text    := ATag.Year;
  edTrack.Text   := ATag.Track;
  edGenre.Text   := ATag.Genre;
  edComment.Text := ATag.Comment;
end;

procedure TTagEditorForm.SaveTag(out ATag: TTagInfo);
begin
  ATag.Title   := Trim(edTitle.Text);
  ATag.Artist  := Trim(edArtist.Text);
  ATag.Album   := Trim(edAlbum.Text);
  ATag.Year    := Trim(edYear.Text);
  ATag.Track   := Trim(edTrack.Text);
  ATag.Genre   := Trim(edGenre.Text);
  ATag.Comment := Trim(edComment.Text);
end;

// ---- Form: Batch editor ----

type
  TBatchEditorForm = class(TForm)
    Grid       : TStringGrid;
    btnSave    : TButton;
    btnCancel  : TButton;
    lblInfo    : TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
  public
    Files     : TStringList;
    Tags      : array of TTagInfo;
    procedure LoadFiles(AFiles: TStringList);
  end;

procedure TBatchEditorForm.FormCreate(Sender: TObject);
begin
  Caption  := 'Batch Tag Editor – MP3Tag per DoubleCMD';
  Width    := 900;
  Height   := 500;
  Position := poScreenCenter;

  lblInfo := TLabel.Create(Self);
  lblInfo.Parent  := Self;
  lblInfo.Caption := 'Modifica direttamente le celle. Lascia vuoto per non modificare il campo.';
  lblInfo.Left    := 8;
  lblInfo.Top     := 8;

  Grid := TStringGrid.Create(Self);
  Grid.Parent    := Self;
  Grid.Left      := 8;
  Grid.Top       := 28;
  Grid.Width     := Self.ClientWidth - 16;
  Grid.Height    := Self.ClientHeight - 70;
  Grid.Anchors   := [akLeft, akTop, akRight, akBottom];
  Grid.FixedCols := 1;
  Grid.FixedRows := 1;
  Grid.ColCount  := 8;
  Grid.Options   := Grid.Options + [goEditing];

  // Intestazioni
  Grid.Cells[0, 0] := 'File';
  Grid.Cells[1, 0] := 'Titolo';
  Grid.Cells[2, 0] := 'Artista';
  Grid.Cells[3, 0] := 'Album';
  Grid.Cells[4, 0] := 'Anno';
  Grid.Cells[5, 0] := 'Traccia';
  Grid.Cells[6, 0] := 'Genere';
  Grid.Cells[7, 0] := 'Commento';

  Grid.ColWidths[0] := 220;
  Grid.ColWidths[1] := 160;
  Grid.ColWidths[2] := 130;
  Grid.ColWidths[3] := 130;
  Grid.ColWidths[4] := 50;
  Grid.ColWidths[5] := 55;
  Grid.ColWidths[6] := 90;
  Grid.ColWidths[7] := 120;

  btnSave := TButton.Create(Self);
  btnSave.Parent  := Self;
  btnSave.Caption := 'Salva tutto';
  btnSave.Left    := Self.ClientWidth - 200;
  btnSave.Top     := Self.ClientHeight - 36;
  btnSave.Width   := 90;
  btnSave.Anchors := [akRight, akBottom];
  btnSave.OnClick := @btnSaveClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent      := Self;
  btnCancel.Caption     := 'Chiudi';
  btnCancel.Left        := Self.ClientWidth - 100;
  btnCancel.Top         := Self.ClientHeight - 36;
  btnCancel.Width       := 90;
  btnCancel.Anchors     := [akRight, akBottom];
  btnCancel.ModalResult := mrCancel;
end;

procedure TBatchEditorForm.LoadFiles(AFiles: TStringList);
var
  I: Integer;
begin
  Files := AFiles;
  SetLength(Tags, AFiles.Count);
  Grid.RowCount := AFiles.Count + 1;
  for I := 0 to AFiles.Count - 1 do
  begin
    ReadTagsFromFile(AFiles[I], Tags[I]);
    Grid.Cells[0, I+1] := ExtractFileName(AFiles[I]);
    Grid.Cells[1, I+1] := Tags[I].Title;
    Grid.Cells[2, I+1] := Tags[I].Artist;
    Grid.Cells[3, I+1] := Tags[I].Album;
    Grid.Cells[4, I+1] := Tags[I].Year;
    Grid.Cells[5, I+1] := Tags[I].Track;
    Grid.Cells[6, I+1] := Tags[I].Genre;
    Grid.Cells[7, I+1] := Tags[I].Comment;
  end;
end;

procedure TBatchEditorForm.btnSaveClick(Sender: TObject);
var
  I    : Integer;
  Tag  : TTagInfo;
  Err  : TStringList;
begin
  Err := TStringList.Create;
  try
    for I := 0 to Files.Count - 1 do
    begin
      Tag          := Tags[I];
      Tag.Title    := Grid.Cells[1, I+1];
      Tag.Artist   := Grid.Cells[2, I+1];
      Tag.Album    := Grid.Cells[3, I+1];
      Tag.Year     := Grid.Cells[4, I+1];
      Tag.Track    := Grid.Cells[5, I+1];
      Tag.Genre    := Grid.Cells[6, I+1];
      Tag.Comment  := Grid.Cells[7, I+1];
      if not WriteTagsToFile(Files[I], Tag) then
        Err.Add(ExtractFileName(Files[I]));
    end;
    if Err.Count = 0 then
      MessageDlg('Salvataggio completato!', mtInformation, [mbOK], 0)
    else
      MessageDlg('Errori su: ' + Err.CommaText, mtError, [mbOK], 0);
  finally
    Err.Free;
  end;
end;

// ---- Form: Rinomina dai tag ----

type
  TRenameForm = class(TForm)
    lblPattern : TLabel;
    edPattern  : TEdit;
    lblHelp    : TLabel;
    lstPreview : TListBox;
    btnRename  : TButton;
    btnCancel  : TButton;
    procedure FormCreate(Sender: TObject);
    procedure edPatternChange(Sender: TObject);
    procedure btnRenameClick(Sender: TObject);
  public
    Files: TStringList;
    Tags : array of TTagInfo;
    procedure LoadFiles(AFiles: TStringList);
    function  BuildPreview: TStringList;
  end;

procedure TRenameForm.FormCreate(Sender: TObject);
begin
  Caption  := 'Rinomina file dai tag';
  Width    := 650;
  Height   := 420;
  Position := poScreenCenter;

  lblPattern := TLabel.Create(Self);
  lblPattern.Parent  := Self;
  lblPattern.Caption := 'Pattern:';
  lblPattern.Left    := 8;
  lblPattern.Top     := 12;

  edPattern := TEdit.Create(Self);
  edPattern.Parent   := Self;
  edPattern.Left     := 70;
  edPattern.Top      := 8;
  edPattern.Width    := Self.ClientWidth - 80;
  edPattern.Anchors  := [akLeft, akTop, akRight];
  edPattern.Text     := '%track% - %artist% - %title%';
  edPattern.OnChange := @edPatternChange;

  lblHelp := TLabel.Create(Self);
  lblHelp.Parent  := Self;
  lblHelp.Caption := 'Variabili: %title% %artist% %album% %year% %track% %genre% %ext%';
  lblHelp.Left    := 8;
  lblHelp.Top     := 36;

  lstPreview := TListBox.Create(Self);
  lstPreview.Parent  := Self;
  lstPreview.Left    := 8;
  lstPreview.Top     := 58;
  lstPreview.Width   := Self.ClientWidth - 16;
  lstPreview.Height  := Self.ClientHeight - 110;
  lstPreview.Anchors := [akLeft, akTop, akRight, akBottom];

  btnRename := TButton.Create(Self);
  btnRename.Parent  := Self;
  btnRename.Caption := 'Rinomina';
  btnRename.Left    := Self.ClientWidth - 200;
  btnRename.Top     := Self.ClientHeight - 40;
  btnRename.Width   := 90;
  btnRename.Anchors := [akRight, akBottom];
  btnRename.OnClick := @btnRenameClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent      := Self;
  btnCancel.Caption     := 'Annulla';
  btnCancel.Left        := Self.ClientWidth - 100;
  btnCancel.Top         := Self.ClientHeight - 40;
  btnCancel.Width       := 90;
  btnCancel.Anchors     := [akRight, akBottom];
  btnCancel.ModalResult := mrCancel;
end;

procedure TRenameForm.LoadFiles(AFiles: TStringList);
var
  I: Integer;
begin
  Files := AFiles;
  SetLength(Tags, AFiles.Count);
  for I := 0 to AFiles.Count - 1 do
    ReadTagsFromFile(AFiles[I], Tags[I]);
  edPatternChange(nil);
end;

function TRenameForm.BuildPreview: TStringList;
var
  I, J  : Integer;
  NewName, Dir, Ext: string;
begin
  Result := TStringList.Create;
  for I := 0 to Files.Count - 1 do
  begin
    Dir  := ExtractFilePath(Files[I]);
    Ext  := LowerCase(ExtractFileExt(Files[I]));
    NewName := BuildFilenameFromPattern(edPattern.Text, Tags[I], Ext);
    // Evita collisioni aggiungendo suffisso numerico
    J := 1;
    while FileExists(Dir + NewName) and (Dir + NewName <> Files[I]) do
    begin
      Inc(J);
      NewName := BuildFilenameFromPattern(edPattern.Text, Tags[I], '') +
                 Format(' (%d)', [J]) + Ext;
    end;
    Result.AddObject(ExtractFileName(Files[I]) + '  →  ' + NewName,
                     TObject(Pointer(I)));
    Result.Objects[I] := TObject(PtrUInt(I));
  end;
end;

procedure TRenameForm.edPatternChange(Sender: TObject);
var
  Preview: TStringList;
begin
  lstPreview.Clear;
  Preview := BuildPreview;
  try
    lstPreview.Items.AddStrings(Preview);
  finally
    Preview.Free;
  end;
end;

procedure TRenameForm.btnRenameClick(Sender: TObject);
var
  I       : Integer;
  Dir, Ext, NewName, OldPath, NewPath: string;
  Errors  : TStringList;
begin
  Errors := TStringList.Create;
  try
    for I := 0 to Files.Count - 1 do
    begin
      Dir  := ExtractFilePath(Files[I]);
      Ext  := LowerCase(ExtractFileExt(Files[I]));
      NewName := BuildFilenameFromPattern(edPattern.Text, Tags[I], Ext);
      OldPath := Files[I];
      NewPath := Dir + NewName;
      if OldPath <> NewPath then
        if not RenameFile(OldPath, NewPath) then
          Errors.Add(ExtractFileName(OldPath));
    end;
    if Errors.Count = 0 then
    begin
      MessageDlg('Rinomina completata!', mtInformation, [mbOK], 0);
      ModalResult := mrOK;
    end
    else
      MessageDlg('Errori rinominando: ' + Errors.CommaText, mtError, [mbOK], 0);
  finally
    Errors.Free;
  end;
end;

// ============================================================
// DSX Plugin API
// ============================================================

function DsxGetMenuItems(MenuItemName: PAnsiChar;
                         ItemIndex   : Integer;
                         MaxLen      : Integer): Integer; cdecl;
const
  ITEMS: array[0..MENUITEM_COUNT-1] of string = (
    'MP3Tag: Mostra tag',
    'MP3Tag: Rinomina dai tag...',
    'MP3Tag: Modifica tag...',
    'MP3Tag: Batch tag editor...',
    'MP3Tag: Pulizia tag'
  );
begin
  if ItemIndex >= MENUITEM_COUNT then
  begin
    Result := -1;
    Exit;
  end;
  StrLCopy(MenuItemName, PAnsiChar(AnsiString(ITEMS[ItemIndex])), MaxLen - 1);
  Result := ItemIndex;
end;

// Eseguito quando l'utente sceglie una voce di menu
// FileList: lista di file separati da #0, termina con #0#0
function DsxExecuteFile(MainWin   : THandle;
                        MenuItemID: Integer;
                        FileList  : PAnsiChar): Integer; cdecl;
var
  Files   : TStringList;
  P       : PAnsiChar;
  Tag     : TTagInfo;
  Msg     : string;
  EdForm  : TTagEditorForm;
  BatchFrm: TBatchEditorForm;
  RenFrm  : TRenameForm;
  I       : Integer;
begin
  Result := DSX_OK;

  // Costruisci lista file da buffer separato da #0
  Files := TStringList.Create;
  try
    P := FileList;
    while (P^ <> #0) do
    begin
      Files.Add(string(P));
      Inc(P, Length(string(P)) + 1);
    end;

    case MenuItemID of

      // ---- Mostra tag ----
      MENUITEM_SHOW_TAGS:
        begin
          if Files.Count = 0 then Exit;
          if ReadTagsFromFile(Files[0], Tag) then
          begin
            Msg :=
              'File:     ' + ExtractFileName(Files[0]) + LineEnding +
              'Titolo:   ' + Tag.Title   + LineEnding +
              'Artista:  ' + Tag.Artist  + LineEnding +
              'Album:    ' + Tag.Album   + LineEnding +
              'Anno:     ' + Tag.Year    + LineEnding +
              'Traccia:  ' + Tag.Track   + LineEnding +
              'Genere:   ' + Tag.Genre   + LineEnding +
              'Commento: ' + Tag.Comment + LineEnding + LineEnding +
              'ID3v1: ' + BoolToStr(Tag.HasID3v1, 'Sì', 'No') +
              '   ID3v2: '+ BoolToStr(Tag.HasID3v2, 'Sì', 'No');
            MessageDlg(Msg, mtInformation, [mbOK], 0);
          end
          else
            MessageDlg('Impossibile leggere i tag di: ' + ExtractFileName(Files[0]),
                       mtError, [mbOK], 0);
        end;

      // ---- Rinomina dai tag ----
      MENUITEM_RENAME:
        begin
          // Filtra solo MP3
          for I := Files.Count - 1 downto 0 do
            if LowerCase(ExtractFileExt(Files[I])) <> '.mp3' then
              Files.Delete(I);
          if Files.Count = 0 then
          begin
            MessageDlg('Nessun file MP3 selezionato.', mtWarning, [mbOK], 0);
            Exit;
          end;
          RenFrm := TRenameForm.Create(nil);
          try
            RenFrm.LoadFiles(Files);
            RenFrm.ShowModal;
          finally
            RenFrm.Free;
          end;
        end;

      // ---- Editor tag singolo ----
      MENUITEM_EDIT_TAG:
        begin
          if Files.Count = 0 then Exit;
          if LowerCase(ExtractFileExt(Files[0])) <> '.mp3' then
          begin
            MessageDlg('Il file selezionato non è un MP3.', mtWarning, [mbOK], 0);
            Exit;
          end;
          ReadTagsFromFile(Files[0], Tag);
          EdForm := TTagEditorForm.Create(nil);
          try
            EdForm.Caption := 'Editor Tag: ' + ExtractFileName(Files[0]);
            EdForm.LoadTag(Tag);
            if EdForm.ShowModal = mrOK then
            begin
              EdForm.SaveTag(Tag);
              if WriteTagsToFile(Files[0], Tag) then
                MessageDlg('Tag salvato!', mtInformation, [mbOK], 0)
              else
                MessageDlg('Errore nel salvataggio.', mtError, [mbOK], 0);
            end;
          finally
            EdForm.Free;
          end;
        end;

      // ---- Batch tag editor ----
      MENUITEM_BATCH_EDIT:
        begin
          for I := Files.Count - 1 downto 0 do
            if LowerCase(ExtractFileExt(Files[I])) <> '.mp3' then
              Files.Delete(I);
          if Files.Count = 0 then
          begin
            MessageDlg('Nessun file MP3 selezionato.', mtWarning, [mbOK], 0);
            Exit;
          end;
          BatchFrm := TBatchEditorForm.Create(nil);
          try
            BatchFrm.LoadFiles(Files);
            BatchFrm.ShowModal;
          finally
            BatchFrm.Free;
          end;
        end;

      // ---- Pulizia tag ----
      MENUITEM_CLEAN_TAGS:
        begin
          for I := Files.Count - 1 downto 0 do
            if LowerCase(ExtractFileExt(Files[I])) <> '.mp3' then
              Files.Delete(I);
          if Files.Count = 0 then Exit;
          if MessageDlg(Format('Pulire i tag di %d file MP3?', [Files.Count]),
                        mtConfirmation, [mbYes, mbNo], 0) = mrYes then
          begin
            for I := 0 to Files.Count - 1 do
            begin
              ReadTagsFromFile(Files[I], Tag);
              Tag.Title   := Trim(Tag.Title);
              Tag.Artist  := Trim(Tag.Artist);
              Tag.Album   := Trim(Tag.Album);
              Tag.Year    := Trim(Tag.Year);
              Tag.Track   := Trim(Tag.Track);
              Tag.Genre   := Trim(Tag.Genre);
              Tag.Comment := Trim(Tag.Comment);
              WriteTagsToFile(Files[I], Tag);
            end;
            MessageDlg('Pulizia completata!', mtInformation, [mbOK], 0);
          end;
        end;

    else
      Result := DSX_NOTIMPL;
    end;

  finally
    Files.Free;
  end;
end;

// ---- Esportazione simboli DSX ----
exports
  DsxGetMenuItems,
  DsxExecuteFile;

begin
end.
