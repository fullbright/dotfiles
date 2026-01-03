echo "Running organize-tool"
cd C:\myOfflineDATA\soloapps\organize\


rem c:
set VENV_PATH=C:\myOfflineDATA\soloapps\organize\.venv
call %VENV_PATH%\Scripts\activate.bat

rem C:\myOfflineDATA\soloapps\organize\.venv\Scripts\organize.exe run
cd /d C:\myOfflineDATA\soloapps\organize
organize.exe run

call %VENV_PATH%\Scripts\deactivate.bat
echo "Done"

echo "Doing housekeeping"
call C:\myAPPS\dotfiles\.local\bin\ftj_computer_housekeeping\run_housekeeping.cmd

rem pause