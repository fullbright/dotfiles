@echo off

cd c:\myAPPS\dotfiles\.mybin\architecture_schemas

c:

c:\myAPPS\dotfiles\.mybin\architecture_schemas\.venv\Scripts\python c:\myAPPS\dotfiles\.mybin\architecture_schemas\route53_s3bucket_data_analysis.py ^
     --route53-input "C:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.096.PRJ.schemas_d_architecture\route53_quicksight_extractions" ^
     --s3-input "C:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.096.PRJ.schemas_d_architecture\s3_bucket_quicksight_extractions" ^
     --route53-output "C:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.096.PRJ.schemas_d_architecture\route53_generated_files" ^
     --s3-output "C:\Users\AFANOUS\OneDrive - Luxottica Group S.p.A\Documenti\93.ftj.projects\302.096.PRJ.schemas_d_architecture\s3_bucket_generated_files" ^
     --dry-run