"""
id3lib.py - ID3v1 and ID3v2 tag read/write library for Python
Supports reading ID3v1+v2, writing ID3v2.3 and ID3v1

Fixes applied:
  - COMM frame: corrected null-terminator for content descriptor; the previous
    fix added one \x00 too many, prepending a null byte to every comment text
  - COMM read: dedicated _read_comm_frame() instead of _read_frame_text()
  - COMM read: enc==2 (UTF-16BE) now decoded with 'utf-16-be' instead of
    'utf-16', which requires a BOM and would garble BOM-less UTF-16BE data
  - _read_frame_text: added enc==2 (UTF-16BE) branch — previously missing,
    causing all text tags to read as '' on ID3v2.4 files with UTF-16BE encoding
  - _read_frame_text: UTF-16 rstrip now strips only null bytes before decoding,
    not the byte-set {0x00, 0xff, 0xfe} which could truncate valid data
  - TCON parsing: '(N)freeform' now correctly uses the free-form text;
    special codes (RX)=Remix and (CR)=Cover are resolved explicitly
  - build_filename: guarded result[:-len(ext)] against len(ext)==0, which
    evaluated to result[:0] == '' and destroyed the entire filename
  - Atomic write: audio data written to a temp file then os.replace()'d
  - sanitize_filename: strips ASCII control characters (0x00-0x1f)
"""

import re
import struct
import os
import tempfile

GENRES = [
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
    'Synthpop',
]

def _decode(b):
    for enc in ('utf-8', 'latin-1', 'cp1252'):
        try:
            return b.rstrip(b'\x00').decode(enc).strip()
        except Exception:
            continue
    return ''

def _syncsafe_to_int(b):
    return (b[0] << 21) | (b[1] << 14) | (b[2] << 7) | b[3]

def _int_to_syncsafe(n):
    return bytes([
        (n >> 21) & 0x7f,
        (n >> 14) & 0x7f,
        (n >>  7) & 0x7f,
        (n      ) & 0x7f,
    ])

# ------------------------------------------------------------------ ID3v1

def read_id3v1(path):
    tag = {}
    try:
        with open(path, 'rb') as f:
            if os.path.getsize(path) < 128:
                return tag
            f.seek(-128, 2)
            data = f.read(128)
        if data[:3] != b'TAG':
            return tag
        tag['title']   = _decode(data[3:33])
        tag['artist']  = _decode(data[33:63])
        tag['album']   = _decode(data[63:93])
        tag['year']    = _decode(data[93:97])
        tag['comment'] = _decode(data[97:126])
        tag['track']   = str(data[126]) if data[125] == 0 and data[126] > 0 else ''
        gi = data[127]
        tag['genre']   = GENRES[gi] if gi < len(GENRES) else ''
        tag['_has_v1'] = True
    except Exception:
        pass
    return tag

# ------------------------------------------------------------------ ID3v2 read

def _read_frame_text(data, frame_id, version):
    """
    Read a standard text frame (TIT2, TPE1, TALB, etc.).

    Encoding byte values (ID3v2.3/2.4 spec):
        0 = ISO-8859-1 (Latin-1)
        1 = UTF-16 with BOM
        2 = UTF-16BE without BOM  (ID3v2.4 only)
        3 = UTF-8
    """
    pos = 10
    while pos + 10 < len(data):
        fid = data[pos:pos+4]
        if fid == b'\x00\x00\x00\x00':
            break
        if version >= 4:
            sz = _syncsafe_to_int(data[pos+4:pos+8])
        else:
            sz = struct.unpack('>I', data[pos+4:pos+8])[0]
        pos += 10
        if sz <= 0 or pos + sz > len(data):
            break
        if fid == frame_id.encode():
            enc = data[pos]
            raw = data[pos+1:pos+sz]
            if enc == 0:
                return raw.rstrip(b'\x00').decode('latin-1', errors='replace').strip()
            elif enc == 1:
                # UTF-16 with BOM. Strip only null bytes; rstrip(b'\x00\xff\xfe')
                # is a byte-set that would silently eat valid 0xff/0xfe tail bytes.
                return raw.rstrip(b'\x00').decode('utf-16', errors='replace').strip()
            elif enc == 2:
                # FIX #1: UTF-16BE without BOM (common in ID3v2.4 files from
                # foobar2000, MusicBrainz Picard, beets). Previously this branch
                # was missing, causing all text frames to be read back as '' for
                # any file tagged with enc=2 — silent total data loss on read.
                return raw.rstrip(b'\x00').decode('utf-16-be', errors='replace').strip()
            elif enc == 3:
                return raw.rstrip(b'\x00').decode('utf-8', errors='replace').strip()
        pos += sz
    return ''

def _read_comm_frame(data, version):
    """
    Read a COMM (comment) frame correctly.

    COMM layout inside the frame payload:
        1 byte   encoding
        3 bytes  language (e.g. b'eng')
        N bytes  content descriptor, null-terminated
                   enc 0/3 → single \x00
                   enc 1/2 → double \x00\x00
        M bytes  actual comment text (same encoding)
    """
    pos = 10
    while pos + 10 < len(data):
        fid = data[pos:pos+4]
        if fid == b'\x00\x00\x00\x00':
            break
        if version >= 4:
            sz = _syncsafe_to_int(data[pos+4:pos+8])
        else:
            sz = struct.unpack('>I', data[pos+4:pos+8])[0]
        pos += 10
        if sz <= 0 or pos + sz > len(data):
            break
        if fid == b'COMM' and sz >= 4:
            payload = data[pos:pos+sz]
            enc  = payload[0]
            # skip lang (3 bytes)
            rest = payload[4:]
            # skip null-terminated descriptor
            if enc in (1, 2):
                # UTF-16: descriptor terminated by \x00\x00
                null_pos = 0
                while null_pos + 1 < len(rest):
                    if rest[null_pos] == 0 and rest[null_pos+1] == 0:
                        null_pos += 2
                        break
                    null_pos += 2
                rest = rest[null_pos:]
            else:
                # Latin-1 / UTF-8: descriptor terminated by single \x00
                null_pos = rest.find(b'\x00')
                if null_pos != -1:
                    rest = rest[null_pos+1:]
            # Decode actual comment text
            rest = rest.rstrip(b'\x00')
            if enc == 0:
                return rest.decode('latin-1', errors='replace').strip()
            elif enc == 1:
                # UTF-16 with BOM
                return rest.decode('utf-16', errors='replace').strip()
            elif enc == 2:
                # UTF-16BE without BOM — must NOT use 'utf-16' (which needs a BOM)
                return rest.decode('utf-16-be', errors='replace').strip()
            elif enc == 3:
                return rest.decode('utf-8', errors='replace').strip()
            return ''
        pos += sz
    return ''

def read_id3v2(path):
    tag = {}
    try:
        with open(path, 'rb') as f:
            header = f.read(10)
        if header[:3] != b'ID3':
            return tag
        version = header[3]
        tag_size = _syncsafe_to_int(header[6:10]) + 10
        with open(path, 'rb') as f:
            data = f.read(tag_size)
        tag['_has_v2'] = True
        tag['_v2_size'] = tag_size
        tag['title']   = _read_frame_text(data, 'TIT2', version)
        tag['artist']  = _read_frame_text(data, 'TPE1', version)
        tag['album']   = _read_frame_text(data, 'TALB', version)
        tag['year']    = _read_frame_text(data, 'TDRC', version) or \
                         _read_frame_text(data, 'TYER', version)
        track = _read_frame_text(data, 'TRCK', version)
        tag['track']   = track.split('/')[0] if '/' in track else track
        tag['genre']   = _read_frame_text(data, 'TCON', version)
        g = tag['genre']
        if g.startswith('(') and ')' in g:
            close = g.index(')')
            free  = g[close+1:].strip()
            code  = g[1:close]
            if free:
                # FIX #2: ID3v2.3 §4.2.1 allows '(N)freeform' where the text
                # after ')' refines or overrides the numeric code. Prefer it.
                tag['genre'] = free
            else:
                # FIX #3: handle special non-numeric codes (RX)=Remix, (CR)=Cover
                # before attempting int() conversion, so they don't silently fall
                # through to the except branch and leave the raw string in place.
                _SPECIAL = {'RX': 'Remix', 'CR': 'Cover'}
                if code in _SPECIAL:
                    tag['genre'] = _SPECIAL[code]
                else:
                    try:
                        gi = int(code)
                        tag['genre'] = GENRES[gi] if gi < len(GENRES) else g
                    except (ValueError, IndexError):
                        pass  # leave tag['genre'] as the raw string
        # FIX #3: use dedicated COMM reader instead of _read_frame_text
        tag['comment'] = _read_comm_frame(data, version)
    except Exception:
        pass
    return tag

# ------------------------------------------------------------------ ID3v2 write

def _make_text_frame(frame_id, text):
    """Create an ID3v2.3 text frame with UTF-8 encoding (enc=3)."""
    encoded = text.encode('utf-8')
    payload = b'\x03' + encoded  # encoding byte + data
    size = struct.pack('>I', len(payload))
    flags = b'\x00\x00'
    return frame_id.encode() + size + flags + payload

def _make_comm_frame(text):
    """
    Create an ID3v2.3 COMM frame with UTF-8 encoding.

    COMM payload layout (ID3v2.3 §4.10):
        encoding  (1 byte)   — 0x03 = UTF-8
        language  (3 bytes)  — e.g. b'eng' (not null-terminated)
        content descriptor   — null-terminated string; empty = single b'\x00'
        text                 — the actual comment bytes

    The descriptor for an empty string is exactly one null byte (the terminator).
    A previous version erroneously wrote TWO null bytes here, causing every
    comment to be read back with a leading \x00 character.
    """
    encoded = text.encode('utf-8')
    # enc=0x03 (UTF-8) | lang=eng | empty descriptor (just the null terminator) | text
    payload = b'\x03' + b'eng' + b'\x00' + encoded
    size = struct.pack('>I', len(payload))
    return b'COMM' + size + b'\x00\x00' + payload

def write_id3v2(path, tag):
    """
    Rewrite ID3v2.3 tags in the file keeping all audio data intact.

    FIX #9: uses an atomic write strategy — data is written to a sibling
    temp file in the same directory, then os.replace() swaps it in place.
    A crash or I/O error during the write therefore never corrupts the
    original file; at worst the temp file is left behind.
    """
    try:
        with open(path, 'rb') as f:
            header = f.read(10)

        # Determine where audio data starts
        if header[:3] == b'ID3':
            old_tag_size = _syncsafe_to_int(header[6:10]) + 10
        else:
            old_tag_size = 0

        # Read audio data (everything after the old v2 tag)
        with open(path, 'rb') as f:
            f.seek(old_tag_size)
            audio_data = f.read()

        # Strip any ID3v1 tag from end of audio data
        if len(audio_data) >= 128 and audio_data[-128:-125] == b'TAG':
            audio_data = audio_data[:-128]

        # Build new frames
        frames = b''
        text_fields = {
            'title':   'TIT2',
            'artist':  'TPE1',
            'album':   'TALB',
            'year':    'TYER',
            'track':   'TRCK',
            'genre':   'TCON',
        }
        for key, fid in text_fields.items():
            val = str(tag.get(key, '') or '')
            if val:
                frames += _make_text_frame(fid, val)

        # FIX #2: COMM gets its own dedicated builder
        comment = str(tag.get('comment', '') or '')
        if comment:
            frames += _make_comm_frame(comment)

        # Add padding
        padding = b'\x00' * 256

        # ID3v2.3 header
        tag_content = frames + padding
        tag_size = _int_to_syncsafe(len(tag_content))
        new_header = b'ID3' + b'\x03\x00' + b'\x00' + tag_size

        # Build ID3v1 tag for backwards compatibility
        def enc(s, n):
            b = str(s).encode("latin-1", errors="replace")[:n]
            return b.ljust(n, bytes([0]))
        v1 = b"TAG"
        v1 += enc(tag.get("title",""),   30)
        v1 += enc(tag.get("artist",""),  30)
        v1 += enc(tag.get("album",""),   30)
        v1 += enc(tag.get("year",""),     4)
        v1 += enc(tag.get("comment",""), 28)
        track_val = tag.get("track","") or "0"
        try:
            track_int = int(str(track_val).split('/')[0])
        except ValueError:
            track_int = 0
        v1 += bytes([0]) + bytes([min(track_int, 255)])
        genre_name = tag.get("genre","")
        gi = GENRES.index(genre_name) if genre_name in GENRES else 255
        v1 += bytes([gi])

        # FIX #9: atomic write via temp file in the same directory
        dir_name = os.path.dirname(os.path.abspath(path))
        fd, tmp_path = tempfile.mkstemp(dir=dir_name, suffix='.tmp')
        try:
            with os.fdopen(fd, 'wb') as f:
                f.write(new_header)
                f.write(tag_content)
                f.write(audio_data)
                f.write(v1)
            os.replace(tmp_path, path)
        except Exception:
            # Clean up the temp file if something went wrong
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise

        return True
    except Exception as e:
        print(f'write_id3v2 error: {e}')
        return False

# ------------------------------------------------------------------ Public API

def read_tags(path):
    tag = read_id3v2(path)
    v1  = read_id3v1(path)
    for k in ('title','artist','album','year','track','genre','comment'):
        if not tag.get(k) and v1.get(k):
            tag[k] = v1[k]
    tag.setdefault('_has_v1', v1.get('_has_v1', False))
    tag.setdefault('_has_v2', False)
    for k in ('title','artist','album','year','track','genre','comment'):
        tag.setdefault(k, '')
    return tag

def write_tags(path, tag):
    """Write ID3v2.3 + ID3v1 tags."""
    return write_id3v2(path, tag)

def sanitize_filename(s):
    """
    Remove characters that are illegal or problematic in filenames.
    FIX #11: also strips ASCII control characters (0x00-0x1f).
    """
    # Remove filesystem-illegal characters
    for c in r'/\:*?"<>|':
        s = s.replace(c, '_')
    # Strip ASCII control characters
    s = re.sub(r'[\x00-\x1f]', '', s)
    return s.strip()

def build_filename(pattern, tag, ext):
    result = pattern
    result = result.replace('%title%',  sanitize_filename(tag.get('title','')  ))
    result = result.replace('%artist%', sanitize_filename(tag.get('artist','') ))
    result = result.replace('%album%',  sanitize_filename(tag.get('album','')  ))
    result = result.replace('%year%',   sanitize_filename(tag.get('year','')   ))
    result = result.replace('%genre%',  sanitize_filename(tag.get('genre','')  ))
    track_val = tag.get('track','')
    result = result.replace('%track%',  track_val.zfill(2) if track_val else '')
    result = result.replace('%ext%',    ext                                     )

    # Strip the extension, clean the stem, then re-add it.
    # Guard: when ext is '' (no extension), len(ext)==0 and result[:-0]
    # evaluates to result[:0] == '', destroying the entire filename.
    if ext and result.lower().endswith(ext.lower()):
        stem = result[:-len(ext)]
    else:
        stem = result

    # Collapse repeated separator sequences left by empty fields (e.g. ' -  - ')
    prev = None
    while prev != stem:
        prev = stem
        stem = re.sub(r' *- *- *', ' - ', stem)

    stem = re.sub(r'[ _-]+$', '', stem)    # trailing orphaned separators
    stem = re.sub(r'^[ _-]+', '', stem)    # leading orphaned separators
    stem = re.sub(r' {2,}', ' ', stem)     # consecutive spaces
    stem = stem.strip()

    return stem + ext
