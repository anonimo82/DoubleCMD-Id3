"""
mp3tag_rename.py - Rinomina file MP3 dai tag ID3 con anteprima live
Uso: python mp3tag_rename.py file1.mp3 file2.mp3 ...
"""

import sys
import os
import tkinter as tk
from tkinter import ttk, messagebox

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import id3lib

DEFAULT_PATTERN = '%track% - %artist% - %title%'

class RenameDialog(tk.Tk):
    def __init__(self, files):
        super().__init__()
        self.title('Rinomina dai tag — Mp3Tag per DoubleCMD')
        self.resizable(True, False)
        self.minsize(700, 380)
        self.files = files
        self.tags  = [id3lib.read_tags(f) for f in files]
        self._build_ui()
        self._update_preview()
        self._center()

    def _center(self):
        self.update_idletasks()
        w, h = self.winfo_width(), self.winfo_height()
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        self.geometry(f'{w}x{h}+{(sw-w)//2}+{(sh-h)//2}')

    def _build_ui(self):
        pad = dict(padx=10, pady=4)

        # Pattern
        pf = ttk.Frame(self, padding=(10,8,10,4))
        pf.pack(fill='x')
        ttk.Label(pf, text='Pattern:').pack(side='left')
        self.pattern_var = tk.StringVar(value=DEFAULT_PATTERN)
        self.pattern_var.trace_add('write', lambda *_: self._update_preview())
        ttk.Entry(pf, textvariable=self.pattern_var,
                  width=55).pack(side='left', padx=6)

        # Variabili disponibili
        ttk.Label(self, text='Variabili: %title%  %artist%  %album%  '
                             '%year%  %track%  %genre%  %ext%',
                  foreground='gray', font=('Segoe UI', 8)).pack(
                  anchor='w', padx=10)

        # Lista anteprima
        frame = ttk.Frame(self, padding=(10,4))
        frame.pack(fill='both', expand=True)

        self.tree = ttk.Treeview(frame,
                                  columns=('old','arrow','new'),
                                  show='headings', selectmode='none')
        self.tree.heading('old',   text='Nome attuale')
        self.tree.heading('arrow', text='')
        self.tree.heading('new',   text='Nuovo nome')
        self.tree.column('old',   width=280, stretch=True)
        self.tree.column('arrow', width=30,  stretch=False)
        self.tree.column('new',   width=340, stretch=True)

        vsb = ttk.Scrollbar(frame, orient='vertical',
                             command=self.tree.yview)
        self.tree.configure(yscrollcommand=vsb.set)
        self.tree.pack(side='left', fill='both', expand=True)
        vsb.pack(side='right', fill='y')

        # Tag colore per nomi identici
        self.tree.tag_configure('same',    foreground='gray')
        self.tree.tag_configure('changed', foreground='#0070c0')
        self.tree.tag_configure('conflict',foreground='red')

        # Barra info + pulsanti
        bf = ttk.Frame(self, padding=(10,6))
        bf.pack(fill='x')
        self.lbl_info = ttk.Label(bf, text='', foreground='gray',
                                   font=('Segoe UI', 8))
        self.lbl_info.pack(side='left')
        ttk.Button(bf, text='Rinomina',
                   command=self._do_rename).pack(side='right', padx=4)
        ttk.Button(bf, text='Annulla',
                   command=self.destroy).pack(side='right', padx=4)

    def _build_new_name(self, i):
        ext  = os.path.splitext(self.files[i])[1].lower()
        return id3lib.build_filename(
            self.pattern_var.get(), self.tags[i], ext)

    def _update_preview(self):
        self.tree.delete(*self.tree.get_children())
        seen = {}   # new_name -> count
        new_names = []
        for i, path in enumerate(self.files):
            nn = self._build_new_name(i)
            new_names.append(nn)
            seen[nn] = seen.get(nn, 0) + 1

        changed = 0
        conflicts = 0
        for i, path in enumerate(self.files):
            old = os.path.basename(path)
            nn  = new_names[i]
            if seen[nn] > 1:
                tag = 'conflict'
                conflicts += 1
            elif old == nn:
                tag = 'same'
            else:
                tag = 'changed'
                changed += 1
            self.tree.insert('', 'end',
                              values=(old, '→', nn), tags=(tag,))

        info = f'{len(self.files)} file  •  {changed} da rinominare'
        if conflicts:
            info += f'  •  ⚠ {conflicts} conflitti (rosso)'
        self.lbl_info.config(text=info)

    def _do_rename(self):
        errors = []
        renamed = 0
        new_names = [self._build_new_name(i) for i in range(len(self.files))]

        # Controlla conflitti
        seen = {}
        for nn in new_names:
            seen[nn] = seen.get(nn, 0) + 1
        if any(v > 1 for v in seen.values()):
            if not messagebox.askyesno('Mp3Tag',
                'Ci sono nomi duplicati (in rosso).\n'
                'Procedere comunque ignorando i duplicati?'):
                return

        for i, path in enumerate(self.files):
            old = os.path.basename(path)
            nn  = new_names[i]
            if old == nn:
                continue
            if seen[nn] > 1:
                continue  # salta duplicati
            new_path = os.path.join(os.path.dirname(path), nn)
            # Evita collisioni con file già esistenti (non nostri)
            if os.path.exists(new_path) and new_path != path:
                errors.append(f'{old} → {nn} (file già esistente)')
                continue
            try:
                os.rename(path, new_path)
                renamed += 1
            except Exception as e:
                errors.append(f'{old}: {e}')

        if errors:
            messagebox.showerror('Mp3Tag',
                f'Rinominati {renamed} file.\nErrori:\n' +
                '\n'.join(errors))
        else:
            messagebox.showinfo('Mp3Tag',
                f'Rinominati {renamed} file con successo!')
            self.destroy()

def main():
    files = [f for f in sys.argv[1:]
             if f.lower().endswith('.mp3') and os.path.isfile(f)]
    if not files:
        messagebox.showerror('Mp3Tag',
            'Nessun file MP3 valido specificato.\n'
            'Seleziona i file in DoubleCMD e riprova.')
        sys.exit(1)
    app = RenameDialog(files)
    app.mainloop()

if __name__ == '__main__':
    main()
