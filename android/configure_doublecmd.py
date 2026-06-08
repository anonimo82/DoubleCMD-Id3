"""
configure_doublecmd.py - Auto-configure DoubleCMD toolbar for all platforms.

Adds Batch Tag Editor and Rename from Tags buttons to the DoubleCMD toolbar
by editing doublecmd.xml directly.

Usage: python3 configure_doublecmd.py <install_dir>

IMPORTANT: Run with DoubleCMD closed. DoubleCMD overwrites its config on exit.

DoubleCMD toolbar XML structure (verified on v1.1.32 GTK2 aarch64 and Windows):
  <Toolbars>
    <MainToolbar>
      <Row>
        <Program>
          <ID>{GUID}</ID>
          <Icon>/path/to/script</Icon>
          <Hint>Tooltip text</Hint>
          <Command>/path/to/script</Command>
          <Params>%p</Params>
          <StartPath>/path/to/dir/</StartPath>
        </Program>
      </Row>
    </MainToolbar>
  </Toolbars>

NOTE: %p passes selected file paths as individual arguments.
On Windows, .bat files must be launched directly (not via cmd /c)
for %p to be passed correctly by DoubleCMD.
"""

import sys
import os
import xml.etree.ElementTree as ET
import shutil
import glob
import uuid


def find_doublecmd_config():
    """Search common locations for doublecmd.xml on all platforms."""
    candidates = []

    # Windows: %APPDATA%\doublecmd\doublecmd.xml
    appdata = os.environ.get('APPDATA', '')
    if appdata:
        candidates.append(os.path.join(appdata, 'doublecmd', 'doublecmd.xml'))

    # Linux / macOS / Android proot
    home = os.path.expanduser('~')
    candidates += [
        os.path.join(home, '.config', 'doublecmd', 'doublecmd.xml'),
        os.path.join(home, '.doublecmd', 'doublecmd.xml'),
        '/root/.config/doublecmd/doublecmd.xml',
        '/root/.doublecmd/doublecmd.xml',
    ]
    candidates += glob.glob('/home/*/.config/doublecmd/doublecmd.xml')
    candidates += glob.glob('/home/*/.doublecmd/doublecmd.xml')

    for path in candidates:
        if os.path.isfile(path):
            return path
    return None


def make_guid():
    return '{' + str(uuid.uuid4()).upper() + '}'


def program_exists(row_elem, hint):
    """Return True if a Program with this Hint already exists in the Row."""
    for prog in row_elem.findall('Program'):
        if (prog.findtext('Hint', '') or '').strip() == hint:
            return True
    return False


def make_program_elem(cmd, params, hint):
    """Create a <Program> element matching DoubleCMD's toolbar format."""
    prog = ET.Element('Program')
    ET.SubElement(prog, 'ID').text        = make_guid()
    ET.SubElement(prog, 'Icon').text      = cmd
    ET.SubElement(prog, 'Hint').text      = hint
    ET.SubElement(prog, 'Command').text   = cmd
    ET.SubElement(prog, 'Params').text    = params
    ET.SubElement(prog, 'StartPath').text = os.path.dirname(cmd) + os.sep
    return prog


def remove_stale_toolbar(root):
    """Remove the incorrect <ToolBar> element added by previous installs."""
    for elem in list(root):
        if elem.tag == 'ToolBar':
            root.remove(elem)
            print('Removed stale <ToolBar> element from previous install.')


def indent_xml(elem, level=0):
    """Add pretty-print indentation in-place (Python < 3.9 compatible)."""
    pad = '\n' + '  ' * level
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = pad + '  '
        if not elem.tail or not elem.tail.strip():
            elem.tail = pad
        for child in elem:
            indent_xml(child, level + 1)
        if not child.tail or not child.tail.strip():
            child.tail = pad
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = pad


def get_wrapper_cmd(install_dir):
    """Return (batch_cmd, batch_params, rename_cmd, rename_params) for this platform.

    Windows: launch .bat directly (NOT via cmd /c) so that DoubleCMD
    passes %p arguments correctly. cmd /c swallows the arguments.
    """
    if os.name == 'nt':
        batch_cmd     = os.path.join(install_dir, 'run_batch.bat')
        rename_cmd    = os.path.join(install_dir, 'run_rename.bat')
        batch_params  = '%p'
        rename_params = '%p'
    else:
        batch_cmd     = os.path.join(install_dir, 'run_batch.sh')
        rename_cmd    = os.path.join(install_dir, 'run_rename.sh')
        batch_params  = '%p'
        rename_params = '%p'
    return (batch_cmd, batch_params, rename_cmd, rename_params)


def main():
    if len(sys.argv) < 2:
        print('Usage: configure_doublecmd.py <install_dir>')
        sys.exit(1)

    install_dir = sys.argv[1].rstrip('/').rstrip('\\')
    batch_cmd, batch_params, rename_cmd, rename_params = get_wrapper_cmd(install_dir)

    config_path = find_doublecmd_config()

    if not config_path:
        print('WARNING: doublecmd.xml not found.')
        print('Launch DoubleCMD once to generate it, then re-run this script,')
        print('or add the toolbar buttons manually:')
        _print_manual_instructions(install_dir)
        return

    print(f'Found config: {config_path}')

    # Backup
    backup_path = config_path + '.bak'
    shutil.copy2(config_path, backup_path)
    print(f'Backup saved: {backup_path}')

    try:
        tree = ET.parse(config_path)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f'ERROR: Cannot parse doublecmd.xml: {e}')
        _print_manual_instructions(install_dir)
        return

    # Remove any stale <ToolBar> from a previous incorrect install
    remove_stale_toolbar(root)

    # Navigate to <Toolbars><MainToolbar><Row>, creating elements if missing
    toolbars = root.find('Toolbars')
    if toolbars is None:
        toolbars = ET.SubElement(root, 'Toolbars')
        print('Created <Toolbars> element.')

    main_toolbar = toolbars.find('MainToolbar')
    if main_toolbar is None:
        main_toolbar = ET.SubElement(toolbars, 'MainToolbar')
        print('Created <MainToolbar> element.')

    row = main_toolbar.find('Row')
    if row is None:
        row = ET.SubElement(main_toolbar, 'Row')
        print('Created <Row> element.')

    added = 0

    if not program_exists(row, 'Batch Tag Editor'):
        row.append(make_program_elem(batch_cmd, batch_params, 'Batch Tag Editor'))
        print('Added button: Batch Tag Editor')
        added += 1
    else:
        print('Button already present: Batch Tag Editor (skipped)')

    if not program_exists(row, 'Rename from Tags'):
        row.append(make_program_elem(rename_cmd, rename_params, 'Rename from Tags'))
        print('Added button: Rename from Tags')
        added += 1
    else:
        print('Button already present: Rename from Tags (skipped)')

    indent_xml(root)
    tree.write(config_path, encoding='utf-8', xml_declaration=True)
    print(f'Config saved: {config_path}')

    if added > 0:
        print()
        print('Restart DoubleCMD to see the new toolbar buttons.')
    else:
        print('No changes needed.')


def _print_manual_instructions(install_dir):
    if os.name == 'nt':
        batch  = os.path.join(install_dir, 'run_batch.bat')
        rename = os.path.join(install_dir, 'run_rename.bat')
        print()
        print('  Configuration > Options > Toolbar > Insert new button')
        print()
        print('  BATCH TAG EDITOR:')
        print(f'    Command:    {batch}')
        print( '    Parameters: %p')
        print()
        print('  RENAME FROM TAGS:')
        print(f'    Command:    {rename}')
        print( '    Parameters: %p')
    else:
        batch  = os.path.join(install_dir, 'run_batch.sh')
        rename = os.path.join(install_dir, 'run_rename.sh')
        print()
        print('  Configuration > Options > Toolbar > Insert new button')
        print()
        print('  BATCH TAG EDITOR:')
        print(f'    Command:    {batch}')
        print( '    Parameters: %p')
        print()
        print('  RENAME FROM TAGS:')
        print(f'    Command:    {rename}')
        print( '    Parameters: %p')
    print()


if __name__ == '__main__':
    main()
