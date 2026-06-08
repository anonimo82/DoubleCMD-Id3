"""
make_wrappers.py - called by install_windows.bat to write run_batch.bat and
run_rename.bat into the install folder.

Usage: python make_wrappers.py <install_dir>
"""
import sys
import os

def main():
    if len(sys.argv) < 2:
        print("Usage: make_wrappers.py <install_dir>")
        sys.exit(1)

    d = sys.argv[1].rstrip("\\").rstrip("/")

    batch_content = (
        "@echo off\r\n"
        "setlocal\r\n"
        "set TMPFILE=%TEMP%\\mp3tag_batch_%RANDOM%_%RANDOM%.txt\r\n"
        "type nul > \"%TMPFILE%\"\r\n"
        "for %%F in (%*) do echo %%~F >> \"%TMPFILE%\"\r\n"
        "pythonw \"" + d + "\\mp3tag_batch.py\" --filelist \"%TMPFILE%\"\r\n"
        "del \"%TMPFILE%\" 2>nul\r\n"
    )

    rename_content = (
        "@echo off\r\n"
        "setlocal\r\n"
        "set TMPFILE=%TEMP%\\mp3tag_rename_%RANDOM%_%RANDOM%.txt\r\n"
        "type nul > \"%TMPFILE%\"\r\n"
        "for %%F in (%*) do echo %%~F >> \"%TMPFILE%\"\r\n"
        "pythonw \"" + d + "\\mp3tag_rename.py\" --filelist \"%TMPFILE%\"\r\n"
        "del \"%TMPFILE%\" 2>nul\r\n"
    )

    with open(os.path.join(d, "run_batch.bat"),  "w", newline="") as f:
        f.write(batch_content)
    with open(os.path.join(d, "run_rename.bat"), "w", newline="") as f:
        f.write(rename_content)

    print("Wrapper scripts written successfully.")

if __name__ == "__main__":
    main()
