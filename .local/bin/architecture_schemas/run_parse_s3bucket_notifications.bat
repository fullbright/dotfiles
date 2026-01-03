@echo off
echo ====================================
echo S3 Bucket Changes Parser
echo ====================================
echo.

cd c:\myAPPS\dotfiles\.local\bin\architecture_schemas

c:

c:\myAPPS\dotfiles\.local\bin\architecture_schemas\.venv\Scripts\python parse_s3bucket_notification.py

echo.
echo ====================================
echo Script finished. Check logs/s3_parser.log for details.
echo ====================================
pause