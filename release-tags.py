# -*- coding: utf-8 -*-

import time, os, re, codecs

# Get interface root path
pkg_name = ''
root_path = os.path.abspath(os.getcwd())
if os.path.basename(root_path).lower() != 'interface' and os.path.basename(os.path.dirname(root_path).lower()) == 'interface':
    pkg_name = os.path.basename(root_path)
    root_path = os.path.dirname(root_path)

def __exit(msg):
    print(msg)
    exit()

def __assert(condition, msg):
    if not condition:
        __exit(msg)

def __is_git_clean():
    status = os.popen('git status').read().strip().split('\n')
    return status[len(status) - 1] == 'nothing to commit, working tree clean'

def __get_release_commit_list():
    commit_list = []
    for commit in os.popen('git log --grep Release --pretty=format:"%s|%p"').read().split('\n'):
        try:
            info = commit.split('|')
            version = int(info[0][9:])
            commit_list.append({ 'version': version, 'hash': info[1] })
        except:
            pass
    return commit_list

def __get_release_tag_list():
    tag_list = []
    for tag in os.popen('git tag -l').read().split('\n'):
        try:
            version = int(tag[1:])
            tag_list.append({ 'version': version, 'name': tag })
        except:
            pass
    return tag_list

def __get_changelog_list():
    info = None
    changelog_list = []
    for _, line in enumerate(codecs.open('%s_CHANGELOG.txt' % pkg_name,'r',encoding='gbk')):
        try:
            if len(line) == 0:
                continue
            if line[0:1] != '*' and line[0:2] != ' *':
                version = int(line.split('v')[1])
                info = { 'version': version, 'message': '' }
                changelog_list.insert(0, info)
            elif info != None:
                info.update({'message': info.get('message') + line})
        except:
            pass
    return changelog_list

if __name__ == '__main__':
    __assert(__is_git_clean(), 'Error: branch has uncommited file change(s)!')

    os.system('git checkout master')
    __assert(__is_git_clean(), 'Error: branch has uncommited file change(s)!')

    os.system('git rebase prelease')
    __assert(__is_git_clean(), 'Error: resolve conflict and remove uncommited changes first!')

    print('Reading changelog and version list...')
    changelog_list = __get_changelog_list()
    tag_list = __get_release_tag_list()
    release_list = __get_release_commit_list()

    for changlog in changelog_list:
        tag = None
        for p in tag_list:
            if p.get('version') == changlog.get('version'):
                tag = p
                break
        if tag != None:
            continue

        release = None
        for p in release_list:
            if p.get('version') == changlog.get('version'):
                release = p
                break
        if release == None:
            continue

        print('Creating tag V%d on %s...' % (changlog.get('version'), release.get('hash')))
        os.system('git tag -a V%d %s -m "Release V%d\n%s" -f' % (changlog.get('version'), release.get('hash'), changlog.get('version'), changlog.get('message')))

    print('Jobs Acomplished.')
