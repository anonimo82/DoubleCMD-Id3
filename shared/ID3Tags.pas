unit ID3Tags;

{
  ID3Tags.pas - Lettura e scrittura tag ID3v1 e ID3v2 per MP3
  Supporta: Titolo, Artista, Album, Anno, Traccia, Genere, Commento
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  // Generi ID3v1 standard (Winamp extended)
  ID3_GENRES: array[0..191] of string = (
    'Blues','Classic Rock','Country','Dance','Disco','Funk','Grunge',
    'Hip-Hop','Jazz','Metal','New Age','Oldies','Other','Pop','R&B',
    'Rap','Reggae','Rock','Techno','Industrial','Alternative','Ska',
    'Death Metal','Pranks','Soundtrack','Euro-Techno','Ambient',
    'Trip-Hop','Vocal','Jazz+Funk','Fusion','Trance','Classical',
    'Instrumental','Acid','House','Game','Sound Clip','Gospel','Noise',
    'Alternative Rock','Bass','Soul','Punk','Space','Meditative',
    'Instrumental Pop','Instrumental Rock','Ethnic','Gothic','Darkwave',
    'Techno-Industrial','Electronic','Pop-Folk','Eurodance','Dream',
    'Southern Rock','Comedy','Cult','Gangsta','Top 40','Christian Rap',
    'Pop/Funk','Jungle','Native US','Cabaret','New Wave','Psychadelic',
    'Rave','Showtunes','Trailer','Lo-Fi','Tribal','Acid Punk','Acid Jazz',
    'Polka','Retro','Musical','Rock & Roll','Hard Rock','Folk',
    'Folk-Rock','National Folk','Swing','Fast Fusion','Bebob','Latin',
    'Revival','Celtic','Bluegrass','Avantgarde','Gothic Rock',
    'Progressive Rock','Psychedelic Rock','Symphonic Rock','Slow Rock',
    'Big Band','Chorus','Easy Listening','Acoustic','Humour','Speech',
    'Chanson','Opera','Chamber Music','Sonata','Symphony','Booty Bass',
    'Primus','Porn Groove','Satire','Slow Jam','Club','Tango','Samba',
    'Folklore','Ballad','Power Ballad','Rhythmic Soul','Freestyle',
    'Duet','Punk Rock','Drum Solo','A capella','Euro-House','Dance Hall',
    'Goa','Drum & Bass','Club-House','Hardcore','Terror','Indie',
    'BritPop','Negerpunk','Polsk Punk','Beat','Christian Gangsta Rap',
    'Heavy Metal','Black Metal','Crossover','Contemporary Christian',
    'Christian Rock','Merengue','Salsa','Thrash Metal','Anime','JPop',
    'Synthpop','Abstract','Art Rock','Baroque','Bhangra','Big Beat',
    'Breakbeat','Chillout','Downtempo','Dub','EBM','Eclectic','Electro',
    'Electroclash','Emo','Experimental','Garage','Global','IDM',
    'Illbient','Industro-Goth','Jam Band','Krautrock','Leftfield',
    'Lounge','Math Rock','New Romantic','Nu-Breakz','Post-Punk',
    'Post-Rock','Psytrance','Shoegaze','Space Rock','Trop Rock',
    'World Music','Neoclassical','Audiobook','Audio Theatre',
    'Neue Deutsche Welle','Podcast','Indie-Rock','G-Funk','Dubstep',
    'Garage Rock','Psybient'
  );

type
  TID3v1Tag = packed record
    Header  : array[0..2] of AnsiChar;   // 'TAG'
    Title   : array[0..29] of AnsiChar;  // 30 bytes
    Artist  : array[0..29] of AnsiChar;  // 30 bytes
    Album   : array[0..29] of AnsiChar;  // 30 bytes
    Year    : array[0..3]  of AnsiChar;  // 4 bytes
    Comment : array[0..28] of AnsiChar;  // 29 bytes (ID3v1.1)
    Track   : Byte;                       // track number (ID3v1.1)
    Genre   : Byte;
  end;

  TTagInfo = record
    Title   : string;
    Artist  : string;
    Album   : string;
    Year    : string;
    Track   : string;
    Genre   : string;
    Comment : string;
    HasID3v1: Boolean;
    HasID3v2: Boolean;
  end;

// ---- Funzioni pubbliche ----
function  ReadTagsFromFile(const AFileName: string; out ATag: TTagInfo): Boolean;
function  WriteTagsToFile (const AFileName: string; const ATag: TTagInfo): Boolean;
function  GenreIndexToName(AIndex: Byte): string;
function  GenreNameToIndex(const AName: string): Integer;
function  BuildFilenameFromPattern(const APattern: string;
                                   const ATag: TTagInfo;
                                   const AOrigExt: string): string;

implementation

// ---- Utility ----

function TrimNulls(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] = #0 then
    begin
      SetLength(Result, I - 1);
      Exit;
    end;
  Result := Trim(Result);
end;

function GenreIndexToName(AIndex: Byte): string;
begin
  if AIndex <= High(ID3_GENRES) then
    Result := ID3_GENRES[AIndex]
  else
    Result := '';
end;

function GenreNameToIndex(const AName: string): Integer;
var
  I: Integer;
begin
  Result := 255; // Unknown
  for I := 0 to High(ID3_GENRES) do
    if SameText(ID3_GENRES[I], AName) then
    begin
      Result := I;
      Exit;
    end;
end;

// ---- ID3v1 ----

function ReadID3v1(const AFileName: string; out ATag: TTagInfo): Boolean;
var
  F    : TFileStream;
  v1   : TID3v1Tag;
begin
  Result := False;
  if not FileExists(AFileName) then Exit;
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      if F.Size < 128 then Exit;
      F.Seek(-128, soEnd);
      F.ReadBuffer(v1, SizeOf(v1));
      if (v1.Header[0] = 'T') and (v1.Header[1] = 'A') and (v1.Header[2] = 'G') then
      begin
        ATag.HasID3v1 := True;
        ATag.Title    := TrimNulls(string(v1.Title));
        ATag.Artist   := TrimNulls(string(v1.Artist));
        ATag.Album    := TrimNulls(string(v1.Album));
        ATag.Year     := TrimNulls(string(v1.Year));
        ATag.Comment  := TrimNulls(string(v1.Comment));
        ATag.Genre    := GenreIndexToName(v1.Genre);
        // ID3v1.1: byte 28 del comment = 0, byte 29 = track
        if (v1.Comment[28] = #0) and (v1.Track > 0) then
          ATag.Track := IntToStr(v1.Track)
        else
          ATag.Track := '';
        Result := True;
      end;
    finally
      F.Free;
    end;
  except
  end;
end;

function WriteID3v1(const AFileName: string; const ATag: TTagInfo): Boolean;
var
  F   : TFileStream;
  v1  : TID3v1Tag;
  Num : Integer;
begin
  Result := False;
  try
    F := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyWrite);
    try
      FillChar(v1, SizeOf(v1), 0);
      // Rimuovi tag v1 esistente
      if F.Size >= 128 then
      begin
        F.Seek(-128, soEnd);
        F.ReadBuffer(v1, SizeOf(v1));
        if (v1.Header[0] = 'T') and (v1.Header[1] = 'A') and (v1.Header[2] = 'G') then
          F.Size := F.Size - 128;
      end;

      FillChar(v1, SizeOf(v1), 0);
      v1.Header[0] := 'T'; v1.Header[1] := 'A'; v1.Header[2] := 'G';

      procedure CopyStr(const Src: string; var Dest; MaxLen: Integer);
      var S: AnsiString; L: Integer;
      begin
        S := AnsiString(Src);
        L := Length(S);
        if L > MaxLen then L := MaxLen;
        if L > 0 then Move(S[1], Dest, L);
      end;

      CopyStr(ATag.Title,  v1.Title,   30);
      CopyStr(ATag.Artist, v1.Artist,  30);
      CopyStr(ATag.Album,  v1.Album,   30);
      CopyStr(ATag.Year,   v1.Year,     4);
      CopyStr(ATag.Comment,v1.Comment, 28);

      if TryStrToInt(ATag.Track, Num) then
      begin
        v1.Comment[28] := #0;
        v1.Track := Byte(Num);
      end;
      v1.Genre := Byte(GenreNameToIndex(ATag.Genre));

      F.Seek(0, soEnd);
      F.WriteBuffer(v1, SizeOf(v1));
      Result := True;
    finally
      F.Free;
    end;
  except
  end;
end;

// ---- ID3v2 (lettura semplificata dei frame testuali) ----

function SyncSafeToInt(B0, B1, B2, B3: Byte): Integer;
begin
  Result := (B0 shl 21) or (B1 shl 14) or (B2 shl 7) or B3;
end;

function ReadID3v2Frame(AStream: TStream; const AFrameID: string;
                        AVersion: Byte): string;
var
  FrameTag : array[0..3] of AnsiChar;
  SzBuf    : array[0..3] of Byte;
  FrameSize: Integer;
  Flags    : Word;
  Encoding : Byte;
  Buf      : TBytes;
  S        : string;
begin
  Result := '';
  AStream.Seek(10, soBeginning); // salta header ID3v2
  while AStream.Position < AStream.Size - 10 do
  begin
    if AStream.Read(FrameTag, 4) < 4 then Break;
    if FrameTag[0] = #0 then Break; // padding
    AStream.Read(SzBuf, 4);
    if AVersion >= 4 then
      FrameSize := SyncSafeToInt(SzBuf[0], SzBuf[1], SzBuf[2], SzBuf[3])
    else
      FrameSize := (SzBuf[0] shl 24) or (SzBuf[1] shl 16) or (SzBuf[2] shl 8) or SzBuf[3];
    AStream.Read(Flags, 2);
    if FrameSize <= 0 then Break;
    if string(FrameTag) = AFrameID then
    begin
      SetLength(Buf, FrameSize);
      AStream.Read(Buf[0], FrameSize);
      Encoding := Buf[0]; // 0=Latin1, 1=UTF16, 3=UTF8
      case Encoding of
        0: begin // ISO-8859-1
             SetLength(S, FrameSize - 1);
             if FrameSize > 1 then Move(Buf[1], S[1], FrameSize - 1);
             Result := TrimNulls(S);
           end;
        1: begin // UTF-16
             // Semplice conversione UTF-16 LE senza BOM
             Result := TrimNulls(UTF8Encode(
               WideString(PWideChar(@Buf[3]))));
           end;
        3: begin // UTF-8
             SetLength(S, FrameSize - 1);
             if FrameSize > 1 then Move(Buf[1], S[1], FrameSize - 1);
             Result := TrimNulls(S);
           end;
      end;
      Exit;
    end
    else
      AStream.Seek(FrameSize, soCurrent);
  end;
end;

function ReadID3v2(const AFileName: string; out ATag: TTagInfo): Boolean;
var
  F       : TFileStream;
  Header  : array[0..9] of Byte;
  Version : Byte;
  TagSize : Integer;
  GenreRaw: string;
  GenreIdx: Integer;
begin
  Result := False;
  if not FileExists(AFileName) then Exit;
  try
    F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      if F.Size < 10 then Exit;
      F.Read(Header, 10);
      // Magic: 'ID3'
      if not ((Header[0] = Ord('I')) and (Header[1] = Ord('D')) and (Header[2] = Ord('3'))) then
        Exit;
      Version := Header[3]; // Major version (3 = ID3v2.3, 4 = ID3v2.4)
      TagSize := SyncSafeToInt(Header[6], Header[7], Header[8], Header[9]);
      if TagSize <= 0 then Exit;

      ATag.HasID3v2 := True;
      ATag.Title    := ReadID3v2Frame(F, 'TIT2', Version);
      ATag.Artist   := ReadID3v2Frame(F, 'TPE1', Version);
      ATag.Album    := ReadID3v2Frame(F, 'TALB', Version);
      ATag.Year     := ReadID3v2Frame(F, 'TDRC', Version);
      if ATag.Year = '' then
        ATag.Year   := ReadID3v2Frame(F, 'TYER', Version);
      ATag.Track    := ReadID3v2Frame(F, 'TRCK', Version);
      // Track può essere "5/12" → prendi solo la parte prima dello slash
      if Pos('/', ATag.Track) > 0 then
        ATag.Track  := Copy(ATag.Track, 1, Pos('/', ATag.Track) - 1);
      ATag.Comment  := ReadID3v2Frame(F, 'COMM', Version);
      GenreRaw      := ReadID3v2Frame(F, 'TCON', Version);
      // Formato: "(12)" oppure "(12)Blues" oppure "Blues"
      if (Length(GenreRaw) > 0) and (GenreRaw[1] = '(') then
      begin
        val(Copy(GenreRaw, 2, Pos(')', GenreRaw) - 2), GenreIdx, GenreIdx);
        ATag.Genre  := GenreIndexToName(Byte(GenreIdx));
      end
      else
        ATag.Genre  := GenreRaw;
      Result := True;
    finally
      F.Free;
    end;
  except
  end;
end;

// ---- API pubblica ----

function ReadTagsFromFile(const AFileName: string; out ATag: TTagInfo): Boolean;
begin
  FillChar(ATag, SizeOf(ATag), 0);
  ATag.HasID3v1 := False;
  ATag.HasID3v2 := False;

  // Priorità: ID3v2 > ID3v1
  Result := ReadID3v2(AFileName, ATag);
  if not Result then
    Result := ReadID3v1(AFileName, ATag)
  else
    ReadID3v1(AFileName, ATag); // leggi v1 anche per flag HasID3v1
end;

function WriteTagsToFile(const AFileName: string; const ATag: TTagInfo): Boolean;
begin
  // Scrive sempre ID3v1 (semplice e universale)
  // Per ID3v2 completo serve una libreria dedicata (es. TagLib)
  Result := WriteID3v1(AFileName, ATag);
end;

// ---- Pattern matching per rinomina ----

function SanitizeForFilename(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C in ['/', '\', ':', '*', '?', '"', '<', '>', '|'] then
      Result := Result + '_'
    else
      Result := Result + C;
  end;
  Result := Trim(Result);
end;

function ZeroPad(const S: string; Width: Integer): string;
begin
  Result := S;
  while Length(Result) < Width do
    Result := '0' + Result;
end;

function BuildFilenameFromPattern(const APattern: string;
                                   const ATag: TTagInfo;
                                   const AOrigExt: string): string;
begin
  Result := APattern;
  Result := StringReplace(Result, '%title%',   SanitizeForFilename(ATag.Title),   [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%artist%',  SanitizeForFilename(ATag.Artist),  [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%album%',   SanitizeForFilename(ATag.Album),   [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%year%',    SanitizeForFilename(ATag.Year),    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%genre%',   SanitizeForFilename(ATag.Genre),   [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%track%',   ZeroPad(ATag.Track, 2),            [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%ext%',     AOrigExt,                          [rfReplaceAll, rfIgnoreCase]);
  // Pulisci parti vuote (es. "- -" quando un campo è vuoto)
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Trim(Result);
  if ExtractFileExt(Result) = '' then
    Result := Result + AOrigExt;
end;

end.
