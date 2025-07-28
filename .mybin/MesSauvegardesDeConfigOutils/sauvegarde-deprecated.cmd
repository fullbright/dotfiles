@echo off
echo "Backup the list of installed applications"
powershell -Command "C:\myAPPS\Backup_installed_apps\backup_installed_windowspacabilities.ps1 -ComputerName $env:COMPUTERNAME | Format-Table DisplayName > C:\myAPPS\Backup_installed_apps\installed_apps.config"

echo "Copying files"
copy C:\myAPPS\Tools\MuLaN\MultiLab.UI.exe.Config C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\Mulan
copy "C:\APPS\Multilab DB Synchronization 1.15.2 (Binaries)\MultiLab.DBSync.exe.config" C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\MultilabDbSynchro\
copy "C:\APPS\Multilab DB Synchronization 1.18.1\MultiLab.DBSync.exe.config" C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\MultilabDbSynchro2\
copy "C:\APPS\RxCalculator Interface\RxCalculator.UI.exe.Config" C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\RxCalc
copy "C:\APPS\RxCalculator Interface\AppSettings.config" C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\RxCalc
copy "C:\myApps\RxCalculator Interface\*.config" C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\RxCalc
xcopy "C:\Users\afanous\AppData\Roaming\espanso\" C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\espanso\ /E /H /C /I /Y
xcopy "C:\Users\AFANOUS\AppData\Local\organize" C:\Users\AFANOUS\Documents\MesSauvegardesDeConfigOutils\organize\ /E /H /C /I /Y

echo "Copy done"

echo "Backup my dotfiles"
cd c:\myApps\dotfiles
powershell c:\myApps\dotfiles\.mybin\sync_git_repo\Sync-GitRepo.ps1 -RepoPath "c:\myApps\dotfiles"
echo "dotfiles backup done"
