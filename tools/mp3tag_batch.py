"""
mp3tag_batch.py - Batch ID3 tag editor for multiple MP3 files
Usage: python mp3tag_batch.py [file1.mp3 file2.mp3 ...]
       If launched without arguments, opens a file selection dialog.

Tabs:
  - Batch Tag Editor   : spreadsheet-style inline editor for ID3 tags
  - Tags from Filename : populate tags by parsing filenames against a pattern
"""

import sys
import os
import re
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import id3lib

# ── Column definitions ─────────────────────────────────────────────────────
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

TAG_VARS = ['title', 'artist', 'album', 'year', 'track', 'genre', 'comment', 'ext']
DEFAULT_PATTERN = '%track% - %artist% - %title%'


# ── Pattern → regex engine ─────────────────────────────────────────────────

def pattern_to_regex(pattern):
    """
    Convert a pattern like '%track% - %artist% - %title%' into a compiled
    regex with named capture groups, tolerating separator variants.

    Separator strategy:
      - Separator with a strong char (-, _, .) → \\s*[-_.]+\\s*
        Matches ' - ', '_', '. ', '---' etc. but NOT a plain space,
        so multi-word fields like 'Pink Floyd' are never split.
      - Whitespace-only separator → \\s+
    """
    tokens = re.split(r'(%(?:' + '|'.join(TAG_VARS) + r')%)', pattern)
    var_names = [re.match(r'^%(\w+)%$', t).group(1)
                 for t in tokens if re.match(r'^%(\w+)%$', t)]

    if not var_names:
        raise ValueError('Pattern contains no recognised variables.')
    seen = set()
    for v in var_names:
        if v in seen:
            raise ValueError(f'Variable %{v}% appears more than once.')
        seen.add(v)

    regex_parts = []
    var_count = 0
    total_vars = len(var_names)
    for tok in tokens:
        m = re.match(r'^%(\w+)%$', tok)
        if m:
            var = m.group(1)
            var_count += 1
            is_last = (var_count == total_vars)
            if var == 'ext':
                regex_parts.append(r'(?P<ext>\.\w+)')
            elif is_last:
                regex_parts.append(f'(?P<{var}>.+)')
            else:
                regex_parts.append(f'(?P<{var}>.+?)')
        elif tok:
            if re.search(r'[-_.]', tok.strip()):
                regex_parts.append(r'\s*[-_.]+\s*')
            else:
                regex_parts.append(r'\s+')
    return re.compile('^' + ''.join(regex_parts) + '$', re.IGNORECASE), var_names


def parse_filename(pattern, filename):
    """Match filename against pattern. Returns dict or None."""
    try:
        rx, _ = pattern_to_regex(pattern)
    except ValueError:
        return None
    m = rx.match(filename)
    if not m:
        return None
    return {k: v.strip() for k, v in m.groupdict().items() if v is not None}


# ── Main application ────────────────────────────────────────────────────────

class BatchEditor(tk.Tk):
    """
    Single-window application.  Subclasses tk.Tk so there is exactly one
    Tk instance for the whole process — no second Tk() is ever created.
    The optional file-open dialog is opened as a child of this window,
    before the main UI is built.
    """

    def __init__(self, files=None):
        super().__init__()
        self.withdraw()                     # hide until UI is ready

        self.title('Batch Tag Editor — Mp3Tag for DoubleCMD')
        self.geometry('980x580')
        self.minsize(700, 440)
        self.protocol('WM_DELETE_WINDOW', self._on_close)

        # If no files supplied, ask the user now (we are the Tk root already)
        if not files:
            paths = filedialog.askopenfilenames(
                title='Select MP3 files',
                filetypes=[('MP3 files', '*.mp3'), ('All files', '*.*')],
                parent=self)
            if not paths:
                self.destroy()
                return
            files = list(paths)

        self.files    = list(files)
        self.tags     = []
        self.modified = {}

        self._build_ui()
        self._load_files()
        self._center()
        self.deiconify()                    # show now that everything is ready

    def _center(self):
        self.update_idletasks()
        w, h = self.winfo_width(), self.winfo_height()
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        self.geometry(f'{w}x{h}+{(sw-w)//2}+{(sh-h)//2}')

    # ── UI skeleton ───────────────────────────────────────────────────────

    def _build_ui(self):
        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill='both', expand=True, padx=6, pady=(6, 0))

        self._tab_editor = ttk.Frame(self.notebook)
        self.notebook.add(self._tab_editor, text='  Batch Tag Editor  ')
        self._build_editor_tab(self._tab_editor)

        self._tab_fromfile = ttk.Frame(self.notebook)
        self.notebook.add(self._tab_fromfile, text='  Tags from Filename  ')
        self._build_fromfile_tab(self._tab_fromfile)

        self.status = ttk.Label(self, text='', foreground='gray',
                                font=('Segoe UI', 8))
        self.status.pack(side='bottom', fill='x', padx=6, pady=2)

    # ── Tab 1: Batch Tag Editor ───────────────────────────────────────────

    def _build_editor_tab(self, parent):
        tb = ttk.Frame(parent, padding=(6, 4))
        tb.pack(fill='x')
        ttk.Label(tb, text='Double-click a cell to edit it.',
                  foreground='gray').pack(side='left')
        ttk.Button(tb, text='Save all',
                   command=self._save_all).pack(side='right', padx=4)
        ttk.Button(tb, text='Close',
                   command=self._on_close).pack(side='right', padx=4)
        ttk.Button(tb, text='Add files...',
                   command=self._add_files).pack(side='right', padx=4)

        frame = ttk.Frame(parent)
        frame.pack(fill='both', expand=True, padx=6, pady=4)

        cols = [c[0] for c in COLS]
        self.tree = ttk.Treeview(frame, columns=cols,
                                  show='headings', selectmode='browse')
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

    # ── Tab 2: Tags from Filename ─────────────────────────────────────────

    def _build_fromfile_tab(self, parent):
        pf = ttk.Frame(parent, padding=(10, 8, 10, 4))
        pf.pack(fill='x')
        ttk.Label(pf, text='Pattern:').pack(side='left')
        self._ff_pattern_var = tk.StringVar(value=DEFAULT_PATTERN)
        self._ff_pattern_var.trace_add('write', lambda *_: self._ff_update_preview())
        ttk.Entry(pf, textvariable=self._ff_pattern_var,
                  width=52).pack(side='left', padx=6)

        ttk.Label(parent,
                  text='Variables: %title%  %artist%  %album%  %year%'
                       '  %track%  %genre%  %comment%  %ext%',
                  foreground='gray', font=('Segoe UI', 8)).pack(anchor='w', padx=10)
        ttk.Label(parent,
                  text='Separators: " - " also matches  _  .  and mixed spacing.',
                  foreground='gray', font=('Segoe UI', 8)).pack(
                      anchor='w', padx=10, pady=(0, 4))

        frame = ttk.Frame(parent, padding=(10, 0, 10, 0))
        frame.pack(fill='both', expand=True)

        ff_cols   = ('filename','title','artist','album','year','track','genre','comment')
        ff_heads  = ('Filename','Title','Artist','Album','Year','Track','Genre','Comment')
        ff_widths = (200, 140, 120, 120, 48, 48, 90, 110)

        self._ff_tree = ttk.Treeview(frame, columns=ff_cols,
                                      show='headings', selectmode='none')
        vsb = ttk.Scrollbar(frame, orient='vertical',
                             command=self._ff_tree.yview)
        hsb = ttk.Scrollbar(frame, orient='horizontal',
                             command=self._ff_tree.xview)
        self._ff_tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)

        for col, head, width in zip(ff_cols, ff_heads, ff_widths):
            self._ff_tree.heading(col, text=head)
            self._ff_tree.column(col, width=width, minwidth=30, stretch=False)

        self._ff_tree.grid(row=0, column=0, sticky='nsew')
        vsb.grid(row=0, column=1, sticky='ns')
        hsb.grid(row=1, column=0, sticky='ew')
        frame.rowconfigure(0, weight=1)
        frame.columnconfigure(0, weight=1)

        self._ff_tree.tag_configure('ok',      foreground='#0070c0')
        self._ff_tree.tag_configure('nomatch', foreground='gray')

        bf = ttk.Frame(parent, padding=(10, 6))
        bf.pack(fill='x')
        self._ff_info = ttk.Label(bf, text='', foreground='gray',
                                   font=('Segoe UI', 8))
        self._ff_info.pack(side='left')
        ttk.Button(bf, text='Apply tags',
                   command=self._ff_apply).pack(side='right', padx=4)
        ttk.Button(bf, text='Close',
                   command=self._on_close).pack(side='right', padx=4)

        self._ff_update_preview()

    def _ff_update_preview(self):
        self._ff_tree.delete(*self._ff_tree.get_children())
        pattern = self._ff_pattern_var.get().strip()

        try:
            pattern_to_regex(pattern)
            pattern_ok = True
        except ValueError as e:
            self._ff_info.config(text=f'Pattern error: {e}')
            pattern_ok = False

        matched = 0
        for path in self.files:
            stem, _ = os.path.splitext(os.path.basename(path))
            parsed = parse_filename(pattern, stem) if pattern_ok else None

            if parsed:
                row = (os.path.basename(path),
                       parsed.get('title',''), parsed.get('artist',''),
                       parsed.get('album',''), parsed.get('year',''),
                       parsed.get('track',''), parsed.get('genre',''),
                       parsed.get('comment',''))
                self._ff_tree.insert('', 'end', values=row, tags=('ok',))
                matched += 1
            else:
                self._ff_tree.insert('', 'end',
                                     values=(os.path.basename(path),)+(''*7,)*7,
                                     tags=('nomatch',))

        no_match = len(self.files) - matched
        info = f'{len(self.files)} files  •  {matched} matched'
        if no_match:
            info += f'  •  {no_match} unmatched (gray)'
        self._ff_info.config(text=info)

    def _ff_apply(self):
        pattern = self._ff_pattern_var.get().strip()
        try:
            pattern_to_regex(pattern)
        except ValueError as e:
            messagebox.showerror('Tags from Filename', f'Invalid pattern: {e}')
            return

        applied = 0
        for i, path in enumerate(self.files):
            stem, _ = os.path.splitext(os.path.basename(path))
            parsed = parse_filename(pattern, stem)
            if not parsed:
                continue
            for field, value in parsed.items():
                if field == 'ext':
                    continue
                if field in self.tags[i]:
                    self.tags[i][field] = value
                    self.modified[(i, field)] = value
            applied += 1

        if applied == 0:
            messagebox.showinfo('Tags from Filename',
                                'No filenames matched the pattern.')
            return

        self._reload_editor_tree()
        self.notebook.select(0)
        messagebox.showinfo(
            'Tags from Filename',
            f'Tags parsed from {applied} filename(s).\n\n'
            f'Review them in the Batch Tag Editor, then click "Save all".')

    def _reload_editor_tree(self):
        self.tree.delete(*self.tree.get_children())
        for i, (path, tag) in enumerate(zip(self.files, self.tags)):
            row = [os.path.basename(path)]
            for _, key, _, _ in COLS[1:]:
                row.append(tag.get(key, ''))
            iid = self.tree.insert('', 'end', values=row)
            if any(k[0] == i for k in self.modified):
                self.tree.item(iid, tags=('modified',))
        self.tree.tag_configure('modified', background='#e8f4ff')

    # ── Shared helpers ────────────────────────────────────────────────────

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
        n = len(self.files)
        self.status.config(
            text=f'{n} file{"s" if n != 1 else ""} loaded. '
                 f'Double-click to edit, or use the Tags from Filename tab.')
        self._ff_update_preview()

    def _add_files(self):
        paths = filedialog.askopenfilenames(
            title='Select MP3 files',
            filetypes=[('MP3 files', '*.mp3'), ('All files', '*.*')],
            parent=self)
        if not paths:
            return
        self.files.extend(paths)
        for path in paths:
            tag = id3lib.read_tags(path)
            self.tags.append(tag)
            row = [os.path.basename(path)]
            for _, key, _, _ in COLS[1:]:
                row.append(tag.get(key, ''))
            self.tree.insert('', 'end', values=row)
        self.status.config(text=f'{len(self.files)} files loaded.')
        self._ff_update_preview()

    def _on_close(self):
        if self.modified:
            if not messagebox.askyesno(
                'Unsaved changes',
                'There are unsaved changes. Close without saving?',
                icon='warning'):
                return
        self.destroy()

    # ── Batch Tag Editor: inline editing ──────────────────────────────────

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
                  font=('Segoe UI', 9, 'bold')).pack(
                      padx=12, pady=(10, 2), anchor='w')

        var = tk.StringVar(value=current)
        if key == 'genre':
            w = ttk.Combobox(popup, textvariable=var,
                             values=id3lib.GENRES, width=32)
        else:
            w = ttk.Entry(popup, textvariable=var,
                          width=14 if key in ('year', 'track') else 34)
        w.pack(padx=12, pady=4)
        w.focus_set()
        w.select_range(0, 'end')

        apply_all_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(popup, text='Apply to ALL files in the list',
                        variable=apply_all_var).pack(
                            padx=12, pady=(0, 4), anchor='w')

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
        bf.pack(padx=12, pady=(0, 10))
        ttk.Button(bf, text='OK',     command=confirm).pack(side='left', padx=4)
        ttk.Button(bf, text='Cancel', command=popup.destroy).pack(side='left', padx=4)

        popup.update_idletasks()
        pw, ph = popup.winfo_width(), popup.winfo_height()
        x = self.winfo_x() + (self.winfo_width()  - pw) // 2
        y = self.winfo_y() + (self.winfo_height() - ph) // 2
        popup.geometry(f'+{x}+{y}')

    # ── Batch Tag Editor: save ────────────────────────────────────────────

    def _save_all(self):
        if not self.modified:
            messagebox.showinfo('Mp3Tag', 'No changes to save.')
            return
        errors = []

        for (row_idx, key), val in self.modified.items():
            self.tags[row_idx][key] = val

        modified_rows = {ri for ri, _ in self.modified}
        failed_rows = set()
        for i, path in enumerate(self.files):
            if i in modified_rows:
                if not id3lib.write_tags(path, self.tags[i]):
                    errors.append(os.path.basename(path))
                    failed_rows.add(i)

        for i, rid in enumerate(self.tree.get_children()):
            vals = self.tree.item(rid, 'values')
            for col_idx, (_, key, _, editable) in enumerate(COLS):
                if editable and key:
                    self.tags[i][key] = vals[col_idx]
            if i not in failed_rows:
                self.tree.item(rid, tags=())

        for k in [k for k in self.modified if k[0] not in failed_rows]:
            del self.modified[k]

        if errors:
            messagebox.showerror(
                'Mp3Tag',
                'Errors saving (will retry on next Save all):\n'
                + '\n'.join(errors))
        else:
            messagebox.showinfo('Mp3Tag', 'Saved successfully!')


# ── Entry point ────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]
    files = []

    if len(args) >= 2 and args[0] == '--filelist':
        try:
            with open(args[1], 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.strip()
                    if line and line.lower().endswith('.mp3') \
                            and os.path.isfile(line):
                        files.append(line)
        except Exception:
            pass
    else:
        files = [f for f in args
                 if f.lower().endswith('.mp3') and os.path.isfile(f)]

    # BatchEditor subclasses tk.Tk, so it IS the one-and-only Tk instance.
    # If files is empty it opens the file dialog itself before building the UI.
    app = BatchEditor(files if files else None)
    app.mainloop()


if __name__ == '__main__':
    main()
