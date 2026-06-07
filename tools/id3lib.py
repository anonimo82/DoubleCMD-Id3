"""
id3lib.py - Lettura e scrittura tag ID3v1 e ID3v2 per Python
Nessuna dipendenza esterna - solo stdlib.
"""

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
    """Decodifica bytes in stringa, rimuove null e spazi."""
    for enc in ('utf-8', 'latin-1', 'cp1252'):
        try:
            return b.rstrip(b'\x00').decode(enc).strip()
        except Exception:
            continue
    return ''

def _syncsafe_to_int(b):
    return (b[0] << 21) | (b[1] << 14) | (b[2] << 7) | b[3]

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

def write_id3v1(path, tag):
    """Scrive (o sostituisce) il tag ID3v1 in coda al file."""
    try:
        with open(path, 'r+b') as f:
            size = os.path.getsize(path)
            if size >= 128:
                f.seek(-128, 2)
                if f.read(3) == b'TAG':
                    f.seek(-128, 2)
                    f.truncate()
            f.seek(0, 2)

            def enc(s, n):
                b = s.encode('latin-1', errors='replace')[:n]
                return b.ljust(n, b'\x00')

            data = b'TAG'
            data += enc(tag.get('title',''),   30)
            data += enc(tag.get('artist',''),  30)
            data += enc(tag.get('album',''),   30)
            data += enc(tag.get('year',''),     4)
            data += enc(tag.get('comment',''), 28)
            track = int(tag.get('track','0') or '0')
            data += b'\x00' + bytes([min(track, 255)])
            genre_name = tag.get('genre','')
            gi = GENRES.index(genre_name) if genre_name in GENRES else 255
            data += bytes([gi])
            f.write(data)
        return True
    except Exception as e:
        print(f'write_id3v1 error: {e}')
        return False

# ------------------------------------------------------------------ ID3v2 (lettura)

def _read_frame_text(data, frame_id, version):
    """Estrae un frame testuale dal blob ID3v2."""
    pos = 10  # dopo l'header
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
            if enc == 0:    # Latin-1
                return raw.rstrip(b'\x00').decode('latin-1', errors='replace').strip()
            elif enc == 1:  # UTF-16
                return raw.rstrip(b'\x00\xff\xfe').decode('utf-16', errors='replace').strip()
            elif enc == 3:  # UTF-8
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
        tag['title']   = _read_frame_text(data, 'TIT2', version)
        tag['artist']  = _read_frame_text(data, 'TPE1', version)
        tag['album']   = _read_frame_text(data, 'TALB', version)
        tag['year']    = _read_frame_text(data, 'TDRC', version) or \
                         _read_frame_text(data, 'TYER', version)
        track = _read_frame_text(data, 'TRCK', version)
        tag['track']   = track.split('/')[0] if '/' in track else track
        tag['genre']   = _read_frame_text(data, 'TCON', version)
        # "(12)" -> nome genere
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

# ------------------------------------------------------------------ API pubblica

def read_tags(path):
    """Legge i tag del file: ID3v2 ha priorità su ID3v1."""
    tag = read_id3v2(path)
    v1  = read_id3v1(path)
    # Riempi i campi mancanti con v1
    for k in ('title','artist','album','year','track','genre','comment'):
        if not tag.get(k) and v1.get(k):
            tag[k] = v1[k]
    tag.setdefault('_has_v1', v1.get('_has_v1', False))
    tag.setdefault('_has_v2', tag.get('_has_v2', False))
    for k in ('title','artist','album','year','track','genre','comment'):
        tag.setdefault(k, '')
    return tag

def write_tags(path, tag):
    """Scrive i tag come ID3v1 (semplice e universale)."""
    return write_id3v1(path, tag)

def sanitize_filename(s):
    """Rimuove caratteri non validi per nomi file Windows."""
    for c in r'/\:*?"<>|':
        s = s.replace(c, '_')
    return s.strip()

def build_filename(pattern, tag, ext):
    """Applica il pattern di rinomina usando i tag."""
    result = pattern
    result = result.replace('%title%',  sanitize_filename(tag.get('title','')  ))
    result = result.replace('%artist%', sanitize_filename(tag.get('artist','') ))
    result = result.replace('%album%',  sanitize_filename(tag.get('album','')  ))
    result = result.replace('%year%',   sanitize_filename(tag.get('year','')   ))
    result = result.replace('%genre%',  sanitize_filename(tag.get('genre','')  ))
    result = result.replace('%track%',  tag.get('track','').zfill(2)            )
    result = result.replace('%ext%',    ext                                     )
    # Pulisci spazi multipli
    while '  ' in result:
        result = result.replace('  ', ' ')
    result = result.strip()
    if not result.lower().endswith(ext.lower()):
        result += ext
    return result
