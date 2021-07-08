# -*- coding: utf-8 -*-
'''
新版本打包自动化
'''
# pip3 install semver

import argparse
import codecs
import os
import re
import semver
import time

import plib.utils as utils
import plib.git as git
from plib.environment import get_current_packet_id, get_packet_path, set_packet_as_cwd
from plib.language.converter import Converter
import plib.environment as env

def __compress(addon):
	'''
	Compress and concat addon source into one file.

	Args:
		addon: Addon name
	'''
	print('--------------------------------')
	print('Compressing: %s' % addon)
	file_count = 0
	converter = Converter('zh-TW')
	# Remove debug codes in source
	for line in open('%s/info.ini' % addon):
		parts = line.strip().split('=')
		if parts[0].find('lua_') == 0:
			source_file = os.path.join(addon, parts[1])
			source_code = codecs.open(source_file,'r',encoding='gbk').read()
			source_code = re.sub(r'(?is)[^\n]*--\[\[#DEBUG LINE\]\][^\n]*\n?', '', source_code)
			source_code = re.sub(r'(?is)\n?--\[\[#DEBUG BEGIN\]\].*?--\[\[#DEBUG END\]\]\n?', '', source_code)
			codecs.open(source_file,'w',encoding='gbk').write(source_code)
	# Generate squishy file and execute squish
	with open('squishy', 'w') as squishy:
		squishy.write('Output "./%s/src.lua"\n' % addon)
		for line in open('%s/info.ini' % addon):
			parts = line.strip().split('=')
			if parts[0].find('lua_') == 0:
				if parts[1] == 'src.lua':
					print('Already compressed...')
					return
				file_path = os.path.join('.', addon, parts[1]).replace('\\', '/')
				file_count = file_count + 1
				squishy.write('Module "%d" "%s"\n' % (file_count, file_path))
	os.popen('lua "./!src-dist/tools/react/squish" --minify-level=full').read()
	os.remove('squishy')
	# Modify dist file for loading modules
	with open('./%s/src.lua' % addon, 'r+') as src:
		content = src.read()
		src.seek(0, 0)
		src.write('local package={preload={}}\n' + content)
	with open('./%s/src.lua' % addon, 'a') as src:
		src.write('\nfor _, k in ipairs({')
		for i in range(1, file_count + 1):
			src.write('\'%d\',' % i)
		src.write('}) do package.preload[k]() end')
	print('Compress done...')
	# Modify info.ini file
	info_content = ''
	for _, line in enumerate(codecs.open('%s/info.ini' % addon,'r',encoding='gbk')):
		parts = line.split('=')
		if parts[0].find('lua_') == 0:
			if parts[0] == 'lua_0':
				info_content = info_content + 'lua_0=src.lua\n'
		else:
			info_content = info_content + line
	with codecs.open('%s/info.ini' % addon,'w',encoding='gbk') as f:
		f.write(info_content)
	with codecs.open('%s/info.ini.zh_TW' % addon,'w',encoding='utf8') as f:
		f.write(converter.convert(info_content))
	print('Update info done...')

def __get_version_info(diff_ver):
	'''Get version information'''
	# Read version from Base.lua
	current_version = ''
	for line in open('%s_!Base/src/lib/Base.lua' % get_current_packet_id()):
		if line[0:16] == 'local _VERSION_ ':
			current_version = re.sub(r'(?is)^local _VERSION_\s+=', '', line).strip()[1:-1]
	# Read max and previous release commit
	current_hash = os.popen('git log -n 1 --pretty=format:"%h"').read().strip()
	commit_list = os.popen('git log --grep release: --pretty=format:"SUCCESS|%h|%s"').read().split('\n')
	if diff_ver:
		commit_list += os.popen('git log ' + diff_ver + ' -n 1 --pretty=format:"SUCCESS|%h|%s"').read().split('\n')
	commit_list = filter(lambda x: x and x.startswith('SUCCESS|'), commit_list)
	commit_list = map(lambda x: x[8:], commit_list)
	max_version, prev_version, prev_version_message, prev_version_hash = '', '', '', ''
	for commit in commit_list:
		try:
			version = re.sub(r'(?is)^\w+\|release:\s+', '', commit).strip()
			version_message = re.sub(r'(?is)^\w+\|', '', commit).strip()
			version_hash = re.sub(r'(?is)\|.+$', '', commit).strip()
			if diff_ver:
				if diff_ver == version and semver.compare(version, '0.0.0') == 1:
					max_version = version
					prev_version = version
					prev_version_message = version_message
					prev_version_hash = version_hash
					continue
				if diff_ver.startswith(version_hash):
					max_version = '0.0.0'
					prev_version = '0.0.0'
					prev_version_message = version_message
					prev_version_hash = version_hash
					continue
			else:
				if max_version == '' and semver.compare(version, '0.0.0') == 1:
					max_version = version
					prev_version = version
					prev_version_message = version_message
					prev_version_hash = version_hash
					continue
				if semver.compare(version, current_version) == -1 and semver.compare(version, prev_version) == 1:
					prev_version = version
					prev_version_message = version_message
					prev_version_hash = version_hash
				if semver(version, max_version) == 1:
					max_version = version
		except:
			pass
	return {
		'current': current_version,
		'current_hash': current_hash,
		'max': max_version,
		'previous': prev_version,
		'previous_message': prev_version_message,
		'previous_hash': prev_version_hash,
	}

def __7zip(file_name, base_message, base_hash):
	cmd_suffix = ''
	if base_hash != '':
		# Generate file change list since previous release commit
		def pathToModule(path):
			return re.sub('(?:^\\!src-dist/data/|["/].*$)', '', path)
		paths = {
			'package.ini': True,
			'package.ini.*': True,
		}
		print('File change list:')
		filelist = os.popen('git diff ' + base_hash + ' HEAD --name-status').read().strip().split('\n')
		for file in filelist:
			lst = file.split('\t')
			if lst[0] == 'A' or lst[0] == 'M' or lst[0] == 'D':
				paths[pathToModule(lst[1])] = True
			elif lst[0][0] == 'R':
				paths[pathToModule(lst[1])] = True
				paths[pathToModule(lst[2])] = True
			print(file)
		print('')
		# Print addon change list
		print('Subpath change list:')
		for path in paths:
			print('/' + path)
			cmd_suffix = cmd_suffix + ' "' + path + '"'
		print('')

	# Prepare for 7z compressing
	print('zippping...')
	os.system('start /wait /b ./!src-dist/bin/7z.exe a -t7z ' + file_name + ' -xr!manifest.dat -xr!manifest.key -xr!publisher.key -x@.7zipignore' + cmd_suffix)
	print('File(s) compressing acomplished!')
	print('Url: ' + file_name)
	print('Based on git commit "%s(%s)".' % (base_message, base_hash) if base_hash != '' else 'Full package.')

def run(diff_ver, is_source):
	print('> DIFF VERSION: %s' % (diff_ver or 'auto'))
	print('> RELEASE MODE: %s' % ('source' if is_source else 'dist'))
	version_info = __get_version_info(diff_ver)

	if diff_ver and version_info.get('previous_hash') == '':
		print('Error: Specified diff commit not found (release: %s).' % diff_ver)
		exit()

	if not is_source:
		# Merge master into prelease
		if git.get_current_branch() == 'master':
			utils.assert_exit(git.is_clean(), 'Error: master branch has uncommited file change(s)!')
			os.system('git checkout prelease || git checkout -b prelease')
			os.system('git rebase master')
			os.system('code "%s"' % os.path.join(get_packet_path(), './%s_!Base/src/lib/Base.lua' % get_current_packet_id()))
			os.system('code "%s"' % os.path.join(get_packet_path(), './CHANGELOG.md'))
			utils.exit_with_message('Switched to prelease branch. Please commit release info and then run this script again!')

		# Merge prelease into stable
		if git.get_current_branch() == 'prelease':
			os.system('git reset master')
			version_info = __get_version_info(diff_ver)
			utils.assert_exit(version_info.get('max') == '' or semver.compare(version_info.get('current'), version_info.get('max')) == 1,
				'Error: current version(%s) must be larger than max history version(%s)!' % (version_info.get('current'), version_info.get('max')))
			os.system('git add * && git commit -m "release: %s"' % version_info.get('current'))
			os.system('git checkout stable || git checkout -b stable')
			os.system('git reset origin/stable --hard')
			os.system('git rebase prelease')

		# Check if branch
		utils.assert_exit(git.is_clean(), 'Error: resolve conflict and remove uncommited changes first!')
		utils.assert_exit(git.get_current_branch() == 'stable', 'Error: current branch is not on stable!')

	# Compress and concat source file
	for addon in os.listdir('./'):
		if os.path.exists(os.path.join('./', addon, 'info.ini')):
			__compress(addon)

	# Package files
	file_name = ''
	if version_info.get('previous_hash'):
		file_name = '!src-dist/dist/%s_%s_v%s.diff-%s-%s.7z' % (
			get_current_packet_id(),
			time.strftime('%Y%m%d%H%M%S', time.localtime()),
			version_info.get('current'),
			version_info.get('previous_hash'),
			version_info.get('current_hash'),
		)
	base_message = ''
	base_hash = ''
	if version_info.get('current') != '' and version_info.get('previous_hash') != '':
		base_message = version_info.get('previous_message')
		base_hash = version_info.get('previous_hash')
	if file_name:
		__7zip(file_name, base_message, base_hash)

	fullpack_file_name = '!src-dist/dist/%s_%s_v%s.full.7z' % (
		get_current_packet_id(),
		time.strftime('%Y%m%d%H%M%S', time.localtime()),
		version_info.get('current'),
	)
	__7zip(fullpack_file_name, '', '')

	# Revert source code modify by compressing
	if not is_source:
		os.system('git reset HEAD --hard')
		os.system('git checkout master')
	time.sleep(5)
	print('Exiting...')

if __name__ == '__main__':
	parser = argparse.ArgumentParser(description='One-key release packet product helper.')
	parser.add_argument('--diff', type=str, help='Package diff version.')
	parser.add_argument('--no-build', action='store_true', help='Package source code.')
	args = parser.parse_args()

	env.set_packet_as_cwd()

	run(args.diff, args.no_build)
