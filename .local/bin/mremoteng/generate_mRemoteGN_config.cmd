@echo off

echo "Generating the file"

cd C:\myAPPS\mRemoteNG
powershell C:\myAPPS\dotfiles\.local\bin\mremoteng\CreateBulkConnections_ConfCons2_6.ps1

pause

echo "Done"