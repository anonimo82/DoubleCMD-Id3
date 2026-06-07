library Mp3TagWdx;

{
  Mp3TagWdx.pas  –  Content Plugin per DoubleCMD / Total Commander
  =================================================================
  Espone i tag ID3 dei file MP3 come colonne nel pannello file.

  Campi disponibili:
    0  Titolo
    1  Artista
    2  Album
    3  Anno
    4  Traccia
    5  Genere
    6  Commento
    7  Versione tag (ID3v1 / ID3v2 / Entrambi)

  Compilare con:
    lazbuild Mp3TagWdx.lpi
  Output: Mp3TagWdx.wdx (Linux) oppure Mp3TagWdx.wdx (Windows)
}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, ID3Tags;

// ---- Costanti WDX (Total Commander / DoubleCMD Content Plugin API) ----
const
  ft_nomorefields = -1;
  ft_string       = 0;
  ft_integer      = 1;
  ft_boolean      = 5;
  ft_fulltext     = 10;

  FT_OK             = 0;
  FT_FIELDEMPTY     = -1;
  FT_NOSUCHFIELD    = -2;
  FT_FILEERROR      = -3;
  FT_NOTIMPLEMENTED = -4;

// Indici dei campi
const
  FIELD_TITLE    = 0;
  FIELD_ARTIST   = 1;
  FIELD_ALBUM    = 2;
  FIELD_YEAR     = 3;
  FIELD_TRACK    = 4;
  FIELD_GENRE    = 5;
  FIELD_COMMENT  = 6;
  FIELD_TAGVER   = 7;
  FIELD_COUNT    = 8;

type
  // Struttura attesa dalla API TC/DCMD
  TContentFieldValue = record
    case Integer of
      0: (IntVal    : Integer);
      1: (FloatVal  : Double);
      2: (StringVal : array[0..4095] of AnsiChar);
  end;

// ---- Implementazioni ----

function GetSupportedField(FieldIndex: Integer;
                           FieldName: PAnsiChar;
                           Units    : PAnsiChar;
                           MaxLen   : Integer): Integer; cdecl;
const
  FIELDS: array[0..FIELD_COUNT-1] of string = (
    'Titolo', 'Artista', 'Album', 'Anno', 'Traccia', 'Genere', 'Commento', 'Versione Tag'
  );
begin
  if FieldIndex >= FIELD_COUNT then
  begin
    Result := ft_nomorefields;
    Exit;
  end;
  StrLCopy(FieldName, PAnsiChar(AnsiString(FIELDS[FieldIndex])), MaxLen - 1);
  Units[0] := #0;
  case FieldIndex of
    FIELD_TRACK: Result := ft_integer;
    else         Result := ft_string;
  end;
end;

function GetValue(FileName    : PAnsiChar;
                  FieldIndex  : Integer;
                  UnitIndex   : Integer;
                  FieldValue  : Pointer;
                  MaxLen      : Integer;
                  Flags       : Integer): Integer; cdecl;
var
  Tag   : TTagInfo;
  FV    : ^TContentFieldValue;
  S     : string;
  Num   : Integer;
begin
  FV := FieldValue;

  if FieldIndex >= FIELD_COUNT then
  begin
    Result := FT_NOSUCHFIELD;
    Exit;
  end;

  // Controlla estensione - solo MP3 (e file audio comuni)
  S := LowerCase(ExtractFileExt(string(FileName)));
  if not (S = '.mp3') then
  begin
    Result := FT_FIELDEMPTY;
    Exit;
  end;

  if not ReadTagsFromFile(string(FileName), Tag) then
  begin
    Result := FT_FILEERROR;
    Exit;
  end;

  case FieldIndex of
    FIELD_TITLE  : S := Tag.Title;
    FIELD_ARTIST : S := Tag.Artist;
    FIELD_ALBUM  : S := Tag.Album;
    FIELD_YEAR   : S := Tag.Year;
    FIELD_GENRE  : S := Tag.Genre;
    FIELD_COMMENT: S := Tag.Comment;
    FIELD_TAGVER :
      begin
        if Tag.HasID3v2 and Tag.HasID3v1 then S := 'ID3v1 + ID3v2'
        else if Tag.HasID3v2 then S := 'ID3v2'
        else if Tag.HasID3v1 then S := 'ID3v1'
        else S := 'Nessuno';
      end;
    FIELD_TRACK  :
      begin
        if TryStrToInt(Tag.Track, Num) then
        begin
          FV^.IntVal := Num;
          Result := FT_OK;
          Exit;
        end
        else
        begin
          Result := FT_FIELDEMPTY;
          Exit;
        end;
      end;
  end;

  if S = '' then
    Result := FT_FIELDEMPTY
  else
  begin
    StrLCopy(FV^.StringVal, PAnsiChar(AnsiString(S)), MaxLen - 1);
    Result := FT_OK;
  end;
end;

// ---- Esportazione simboli ----

exports
  GetSupportedField,
  GetValue;

begin
end.
