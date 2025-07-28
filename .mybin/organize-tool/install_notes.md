Create D:\soloapps\organize

Create and activate the virtualenv

python -m venv .venv
.venv\Scripts\activate.bat

pip install -U organize-tool
pip install -U "organize-tool[textract]"

https://github.com/oschwartz10612/poppler-windows/releases
Download latest version
Unzip in the D:\soloapps\organize

Add organize\poppler-22.04.0\bin to file path.

