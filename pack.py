import os
import zipfile
import json

files = [
	'code/debug.lua',
	'code/gameplay.lua',
	'code/ui.lua',
	'prototypes/input.lua',
	'prototypes/styles.lua',
	'constants.lua',
	'control.lua',
	'data.lua',
	'data-updates.lua',
	'info.json',
	'LICENSE',
	'README.md',
	'thumbnail.png',
]

version = None
with open('info.json', 'r') as f :
	info = json.loads(f.read())
	version = info['version']

modname = os.path.split(os.path.dirname(__file__))[1]
dirname = f'{modname}_{version}'
zipname = os.path.join(os.path.dirname(__file__), f'{dirname}.zip')

with zipfile.ZipFile(zipname, 'w', zipfile.ZIP_DEFLATED, True, 9) as pack :
	for file in files :
		pack.write(file, os.path.join(dirname, file))