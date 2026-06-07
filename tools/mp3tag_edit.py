"""
mp3tag_edit.py - Editor tag ID3 per singolo file MP3
Uso: python mp3tag_edit.py "percorso\file.mp3"
"""

import sys
import os
import tkinter as tk
from tkinter import ttk, messagebox

# Aggiungi la cartella dello script al path per trovare id3lib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import id3lib

FIELDS = [
    ('Titolo',   'title'),
    ('Artista',  'artist'),
    ('Album',    'album'),
    ('Anno',     'year'),
    ('Traccia',  'track'),
    ('Genere',   'genre'),
    ('Commento', 'comment'),
]

class TagEditor(tk.Tk):
    def __init__(self, filepath):
        super().__init__()
        self.filepath = filepath
        self.title(f'Editor Tag — {os.path.basename(filepath)}')
        self.resizable(False, False)
        self._build_ui()
        self._load()
        self.after(50, self._center)

    def _center(self):
        self.update_idletasks()
        w, h = self.winfo_width(), self.winfo_height()
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        self.geometry(f'{w}x{h}+{(sw-w)//2}+{(sh-h)//2}')

    def _build_ui(self):
        pad = dict(padx=10, pady=4)
        self.entries = {}

        frame = ttk.Frame(self, padding=12)
        frame.grid(row=0, column=0, sticky='nsew')

        # Info file
        ttk.Label(frame, text=self.filepath, foreground='gray',
                  font=('Segoe UI', 8)).grid(row=0, column=0, columnspan=2,
                  sticky='w', pady=(0,8))

        for i, (label, key) in enumerate(FIELDS):
            ttk.Label(frame, text=label+':', width=9,
                      anchor='e').grid(row=i+1, column=0, sticky='e', **pad)
            var = tk.StringVar()
            if key == 'genre':
                cb = ttk.Combobox(frame, textvariable=var, width=38,
                                  values=id3lib.GENRES)
                cb.grid(row=i+1, column=1, sticky='w', **pad)
            else:
                w = 10 if key in ('year','track') else 40
                e = ttk.Entry(frame, textvariable=var, width=w)
                e.grid(row=i+1, column=1, sticky='w', **pad)
            self.entries[key] = var

        # Separatore
        ttk.Separator(frame).grid(row=len(FIELDS)+1, column=0,
                                   columnspan=2, sticky='ew', pady=6)

        # Versione tag (info)
        self.lbl_ver = ttk.Label(frame, text='', foreground='gray',
                                  font=('Segoe UI', 8))
        self.lbl_ver.grid(row=len(FIELDS)+2, column=0, columnspan=2,
                           sticky='w', padx=10)

        # Pulsanti
        btn_frame = ttk.Frame(frame)
        btn_frame.grid(row=len(FIELDS)+3, column=0, columnspan=2,
                        sticky='e', pady=(8,0))
        ttk.Button(btn_frame, text='Salva',
                   command=self._save).pack(side='right', padx=4)
        ttk.Button(btn_frame, text='Annulla',
                   command=self.destroy).pack(side='right', padx=4)

    def _load(self):
        tag = id3lib.read_tags(self.filepath)
        for _, key in FIELDS:
            self.entries[key].set(tag.get(key, ''))
        ver = []
        if tag.get('_has_v2'): ver.append('ID3v2')
        if tag.get('_has_v1'): ver.append('ID3v1')
        self.lbl_ver.config(text='Tag presenti: ' + (', '.join(ver) if ver else 'Nessuno'))

    def _save(self):
        tag = {key: self.entries[key].get() for _, key in FIELDS}
        if id3lib.write_tags(self.filepath, tag):
            messagebox.showinfo('Mp3Tag', 'Tag salvato con successo!')
            self.destroy()
        else:
            messagebox.showerror('Mp3Tag', 'Errore durante il salvataggio.')

def main():
    if len(sys.argv) < 2:
        messagebox.showerror('Mp3Tag', 'Uso: mp3tag_edit.py <file.mp3>')
        sys.exit(1)
    path = sys.argv[1]
    if not os.path.isfile(path):
        messagebox.showerror('Mp3Tag', f'File non trovato:\n{path}')
        sys.exit(1)
    app = TagEditor(path)
    app.mainloop()

if __name__ == '__main__':
    main()
