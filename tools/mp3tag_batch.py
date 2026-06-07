"""
mp3tag_batch.py - Batch ID3 tag editor for multiple MP3 files
Usage: python mp3tag_batch.py [file1.mp3 file2.mp3 ...]
       If launched without arguments, opens a file selection dialog.

Fixes applied:
  - FIX #6: after _save_all(), self.tags is rebuilt from the tree values so
    that the in-memory state always matches what is displayed (was possible
    to get diverged on multiple successive edits + saves).
  - FIX #10: closing the window while there are unsaved changes now asks for
    confirmation, preventing accidental data loss.
"""

import sys
import os
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import id3lib

COLS = [
    ('File',    None,       220, False),
    ('Title',   'title',    160, True),
    ('Artist',  'artist',   130, True),
    ('Album',   'album',    130, True),
    ('Year',    'year',      50, True),
    ('Track',   'track',     55, True),
    ('Genre',   'genre',     90, True),
    ('Comment', 'comment',  120, True),
]

class BatchEditor(tk.Tk):
    def __init__(self, files):
        super().__init__()
        self.title('Batch Tag Editor — Mp3Tag for DoubleCMD')
        self.geometry('980x540')
        self.minsize(700, 400)
        self.files = list(files)
        self.tags  = []
        self.modified = {}
        self._build_ui()
        self._load_files()
        self._center()
        # FIX #10: intercept the window-close button
        self.protocol('WM_DELETE_WINDOW', self._on_close)

    def _center(self):
        self.update_idletasks()
        w, h = self.winfo_width(), self.winfo_height()
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        self.geometry(f'{w}x{h}+{(sw-w)//2}+{(sh-h)//2}')

    def _build_ui(self):
        tb = ttk.Frame(self, padding=(6,4))
        tb.pack(fill='x')
        ttk.Label(tb, text='Double-click a cell to edit it.',
                  foreground='gray').pack(side='left')
        ttk.Button(tb, text='Save all',    command=self._save_all).pack(side='right', padx=4)
        ttk.Button(tb, text='Close',       command=self._on_close).pack(side='right', padx=4)
        ttk.Button(tb, text='Add files...', command=self._add_files).pack(side='right', padx=4)

        frame = ttk.Frame(self)
        frame.pack(fill='both', expand=True, padx=6, pady=4)

        cols = [c[0] for c in COLS]
        self.tree = ttk.Treeview(frame, columns=cols, show='headings', selectmode='browse')
        vsb = ttk.Scrollbar(frame, orient='vertical',   command=self.tree.yview)
        hsb = ttk.Scrollbar(frame, orient='horizontal', command=self.tree.xview)
        self.tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)

        for name, _, width, _ in COLS:
            self.tree.heading(name, text=name)
            self.tree.column(name, width=width, minwidth=40, stretch=False)

        self.tree.grid(row=0, column=0, sticky='nsew')
        vsb.grid(row=0, column=1, sticky='ns')
        hsb.grid(row=1, column=0, sticky='ew')
        frame.rowconfigure(0, weight=1)
        frame.columnconfigure(0, weight=1)
        self.tree.bind('<Double-1>', self._on_double_click)

        self.status = ttk.Label(self, text='', foreground='gray', font=('Segoe UI', 8))
        self.status.pack(side='bottom', fill='x', padx=6, pady=2)

    # FIX #10: ask for confirmation when there are unsaved changes
    def _on_close(self):
        if self.modified:
            if not messagebox.askyesno(
                'Unsaved changes',
                'There are unsaved changes. Close without saving?',
                icon='warning',
            ):
                return
        self.destroy()

    def _load_files(self):
        self.tree.delete(*self.tree.get_children())
        self.tags = []
        for path in self.files:
            tag = id3lib.read_tags(path)
            self.tags.append(tag)
            row = [os.path.basename(path)]
            for _, key, _, _ in COLS[1:]:
                row.append(tag.get(key, ''))
            self.tree.insert('', 'end', values=row)
        self.status.config(text=f'{len(self.files)} files loaded. Double-click to edit.')

    def _add_files(self):
        paths = filedialog.askopenfilenames(
            title='Select MP3 files',
            filetypes=[('MP3 files', '*.mp3'), ('All files', '*.*')])
        if not paths:
            return
        self.files.extend(paths)
        # Append new rows without reloading existing ones (preserves unsaved changes)
        for path in paths:
            tag = id3lib.read_tags(path)
            self.tags.append(tag)
            row = [os.path.basename(path)]
            for _, key, _, _ in COLS[1:]:
                row.append(tag.get(key, ''))
            self.tree.insert('', 'end', values=row)
        self.status.config(text=f'{len(self.files)} files loaded. Double-click to edit.')

    def _on_double_click(self, event):
        region = self.tree.identify_region(event.x, event.y)
        if region != 'cell':
            return
        col_id  = self.tree.identify_column(event.x)
        col_idx = int(col_id[1:]) - 1
        row_id  = self.tree.identify_row(event.y)
        if not row_id:
            return
        _, key, _, editable = COLS[col_idx]
        if not editable:
            return
        row_idx = self.tree.index(row_id)
        current = self.tree.item(row_id, 'values')[col_idx]
        self._popup_edit(row_id, row_idx, col_idx, key, current)

    def _popup_edit(self, row_id, row_idx, col_idx, key, current):
        popup = tk.Toplevel(self)
        popup.title(f'Edit {COLS[col_idx][0]}')
        popup.resizable(False, False)
        popup.grab_set()

        ttk.Label(popup, text=f'Field: {COLS[col_idx][0]}',
                  font=('Segoe UI', 9, 'bold')).pack(padx=12, pady=(10,2), anchor='w')

        var = tk.StringVar(value=current)
        if key == 'genre':
            w = ttk.Combobox(popup, textvariable=var, values=id3lib.GENRES, width=32)
        else:
            w = ttk.Entry(popup, textvariable=var,
                          width=14 if key in ('year','track') else 34)
        w.pack(padx=12, pady=4)
        w.focus_set()
        w.select_range(0, 'end')

        apply_all_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(popup, text='Apply to ALL files in the list',
                        variable=apply_all_var).pack(padx=12, pady=(0,4), anchor='w')

        def confirm(e=None):
            new_val = var.get()
            if apply_all_var.get():
                for i, rid in enumerate(self.tree.get_children()):
                    vals = list(self.tree.item(rid, 'values'))
                    vals[col_idx] = new_val
                    self.tree.item(rid, values=vals)
                    self.modified[(i, key)] = new_val
            else:
                vals = list(self.tree.item(row_id, 'values'))
                vals[col_idx] = new_val
                self.tree.item(row_id, values=vals)
                self.modified[(row_idx, key)] = new_val
            popup.destroy()

        w.bind('<Return>', confirm)
        w.bind('<Escape>', lambda e: popup.destroy())
        bf = ttk.Frame(popup)
        bf.pack(padx=12, pady=(0,10))
        ttk.Button(bf, text='OK',     command=confirm).pack(side='left', padx=4)
        ttk.Button(bf, text='Cancel', command=popup.destroy).pack(side='left', padx=4)

        popup.update_idletasks()
        pw, ph = popup.winfo_width(), popup.winfo_height()
        x = self.winfo_x() + (self.winfo_width()  - pw) // 2
        y = self.winfo_y() + (self.winfo_height() - ph) // 2
        popup.geometry(f'+{x}+{y}')

    def _save_all(self):
        if not self.modified:
            messagebox.showinfo('Mp3Tag', 'No changes to save.')
            return
        errors = []

        # Apply all pending edits to self.tags
        for (row_idx, key), val in self.modified.items():
            self.tags[row_idx][key] = val

        modified_rows = {ri for ri, _ in self.modified}
        for i, path in enumerate(self.files):
            if i in modified_rows:
                if not id3lib.write_tags(path, self.tags[i]):
                    errors.append(os.path.basename(path))

        # FIX #6: resync self.tags from the tree so that successive edits
        # always start from the true saved state, not stale in-memory data.
        for i, rid in enumerate(self.tree.get_children()):
            vals = self.tree.item(rid, 'values')
            for col_idx, (_, key, _, editable) in enumerate(COLS):
                if editable and key:
                    self.tags[i][key] = vals[col_idx]

        self.modified.clear()
        if errors:
            messagebox.showerror('Mp3Tag', 'Errors saving:\n' + '\n'.join(errors))
        else:
            messagebox.showinfo('Mp3Tag', 'Saved successfully!')

def main():
    args = sys.argv[1:]
    files = []

    if len(args) >= 2 and args[0] == '--filelist':
        try:
            with open(args[1], 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.strip()
                    if line and line.lower().endswith('.mp3') and os.path.isfile(line):
                        files.append(line)
        except Exception:
            pass
    else:
        files = [f for f in args if f.lower().endswith('.mp3') and os.path.isfile(f)]

    if not files:
        root = tk.Tk()
        root.withdraw()
        paths = filedialog.askopenfilenames(
            title='Select MP3 files',
            filetypes=[('MP3 files', '*.mp3'), ('All files', '*.*')])
        root.destroy()
        if paths:
            files = list(paths)
        else:
            sys.exit(0)

    app = BatchEditor(files)
    app.mainloop()

if __name__ == '__main__':
    main()
