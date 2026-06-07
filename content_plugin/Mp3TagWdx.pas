library Mp3TagWdx;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, ID3Tags;

const
  ft_nomorefields = -1;
  ft_string       =  0;
  ft_integer      =  1;

  FT_OK           =  0;
  FT_FIELDEMPTY   = -1;
  FT_NOSUCHFIELD  = -2;
  FT_FILEERROR    = -3;

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
  TContentFieldValue = record
    case Integer of
      0: (IntVal    : LongInt);
      1: (FloatVal  : Double);
      2: (StringVal : array[0..4095] of AnsiChar);
  end;
  PContentFieldValue = ^TContentFieldValue;

procedure ContentGetDetectString(DetectString: PAnsiChar;
                                 MaxLen: Integer); stdcall;
  export;
begin
  StrLCopy(DetectString, PAnsiChar('EXT="MP3"'), MaxLen - 1);
end;

function ContentGetSupportedField(FieldIndex: Integer;
                                  FieldName : PAnsiChar;
                                  Units     : PAnsiChar;
                                  MaxLen    : Integer): Integer; stdcall;
  export;
const
  NAMES: array[0..FIELD_COUNT-1] of AnsiString = (
    'Titolo', 'Artista', 'Album', 'Anno',
    'Traccia', 'Genere', 'Commento', 'Versione Tag'
  );
begin
  if (FieldIndex < 0) or (FieldIndex >= FIELD_COUNT) then
  begin
    Result := ft_nomorefields;
    Exit;
  end;
  StrLCopy(FieldName, PAnsiChar(NAMES[FieldIndex]), MaxLen - 1);
  Units[0] := #0;
  if FieldIndex = FIELD_TRACK then
    Result := ft_integer
  else
    Result := ft_string;
end;

function ContentGetValue(FileName  : PAnsiChar;
                         FieldIndex: Integer;
                         UnitIndex : Integer;
                         FieldValue: Pointer;
                         MaxLen    : Integer;
                         Flags     : Integer): Integer; stdcall;
  export;
var
  TagData : TTagInfo;
  FV      : PContentFieldValue;
  S       : AnsiString;
  Num     : Integer;
begin
  FV := PContentFieldValue(FieldValue);

  if (FieldIndex < 0) or (FieldIndex >= FIELD_COUNT) then
  begin
    Result := FT_NOSUCHFIELD;
    Exit;
  end;

  if LowerCase(ExtractFileExt(string(AnsiString(FileName)))) <> '.mp3' then
  begin
    Result := FT_FIELDEMPTY;
    Exit;
  end;

  if not ReadTagsFromFile(string(AnsiString(FileName)), TagData) then
  begin
    Result := FT_FILEERROR;
    Exit;
  end;

  case FieldIndex of
    FIELD_TITLE  : S := AnsiString(TagData.Title);
    FIELD_ARTIST : S := AnsiString(TagData.Artist);
    FIELD_ALBUM  : S := AnsiString(TagData.Album);
    FIELD_YEAR   : S := AnsiString(TagData.Year);
    FIELD_GENRE  : S := AnsiString(TagData.Genre);
    FIELD_COMMENT: S := AnsiString(TagData.Comment);
    FIELD_TAGVER :
      begin
        if TagData.HasID3v2 and TagData.HasID3v1 then S := 'ID3v1+ID3v2'
        else if TagData.HasID3v2 then S := 'ID3v2'
        else if TagData.HasID3v1 then S := 'ID3v1'
        else S := '';
      end;
    FIELD_TRACK:
      begin
        if TryStrToInt(TagData.Track, Num) then
        begin
          FV^.IntVal := Num;
          Result := FT_OK;
        end
        else
          Result := FT_FIELDEMPTY;
        Exit;
      end;
  else
    Result := FT_NOSUCHFIELD;
    Exit;
  end;

  if S = '' then
    Result := FT_FIELDEMPTY
  else
  begin
    StrLCopy(FV^.StringVal, PAnsiChar(S), MaxLen - 1);
    Result := FT_OK;
  end;
end;

exports
  ContentGetDetectString,
  ContentGetSupportedField,
  ContentGetValue;

begin
end.
