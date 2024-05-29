import os
import zipfile
import json

paths = [
	'code',
	'locale',
	'prototypes',
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
	for path in paths :
		if os.path.isdir(path) :
			for subdir, _, files in os.walk(path) :
				for file in files :
					pack.write(os.path.join(subdir, file), os.path.join(dirname, subdir, file))
		else :
			pack.write(path, os.path.join(dirname, path))