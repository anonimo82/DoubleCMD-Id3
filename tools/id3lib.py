"""
id3lib.py - ID3v1 and ID3v2 tag read/write library for Python
Supports reading ID3v1+v2, writing ID3v2.3 and ID3v1
"""

import re
import struct
import os

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
                return raw.rstrip(b'\x00\xff\xfe').decode('utf-16', errors='replace').strip()
            elif enc == 3:
                return raw.rstrip(b'\x00').decode('utf-8', errors='replace').strip()
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
            try:
                gi = int(g[1:g.index(')')])
                tag['genre'] = GENRES[gi] if gi < len(GENRES) else g
            except Exception:
                pass
        tag['comment'] = _read_frame_text(data, 'COMM', version)
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

def write_id3v2(path, tag):
    """
    Rewrite ID3v2.3 tags in the file keeping all audio data intact.
    Strategy: read audio data (after v2 tag), rewrite v2 header + audio.
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
        field_map = {
            'title':   'TIT2',
            'artist':  'TPE1',
            'album':   'TALB',
            'year':    'TYER',
            'track':   'TRCK',
            'genre':   'TCON',
            'comment': 'COMM',
        }
        for key, fid in field_map.items():
            val = str(tag.get(key, '') or '')
            if val:
                if fid == 'COMM':
                    # COMM frame has special format: enc + lang + desc + text
                    encoded = val.encode('utf-8')
                    payload = b'\x03' + b'eng' + b'\x00' + encoded
                    size = struct.pack('>I', len(payload))
                    frames += b'COMM' + size + b'\x00\x00' + payload
                else:
                    frames += _make_text_frame(fid, val)

        # Add padding
        padding = b'\x00' * 256

        # ID3v2.3 header
        tag_content = frames + padding
        tag_size = _int_to_syncsafe(len(tag_content))
        new_header = b'ID3' + b'\x03\x00' + b'\x00' + tag_size

        # Write everything in a single operation
        with open(path, 'wb') as f:
            f.write(new_header)
            f.write(tag_content)
            f.write(audio_data)
            # Append ID3v1 tag for backwards compatibility
            def enc(s, n):
                b = str(s).encode("latin-1", errors="replace")[:n]
                return b.ljust(n, bytes([0]))
            v1 = b"TAG"
            v1 += enc(tag.get("title",""),   30)
            v1 += enc(tag.get("artist",""),  30)
            v1 += enc(tag.get("album",""),   30)
            v1 += enc(tag.get("year",""),     4)
            v1 += enc(tag.get("comment",""), 28)
            track = int(tag.get("track","0") or "0")
            v1 += bytes([0]) + bytes([min(track, 255)])
            genre_name = tag.get("genre","")
            gi = GENRES.index(genre_name) if genre_name in GENRES else 255
            v1 += bytes([gi])
            f.write(v1)

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
    for c in r'/\:*?"<>|':
        s = s.replace(c, '_')
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
    if result.lower().endswith(ext.lower()):
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
