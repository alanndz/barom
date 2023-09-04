#!/usr/bin/env python

import collections
import argparse
import sys
import os
import subprocess
from time import sleep

n = '\n'
Cwd = os.getcwd()
tmpLog = '/tmp/barom.log'
tmpLogError = '/tmp/barom_error.log'
Cmd = '#!/usr/bin/env bash' + n + 'source build/envsetup.sh' + n
DirCmd = os.path.join(Cwd, '.baromexec') 
cfile = os.path.join(Cwd, '.barompyconfig')

# Keep basic logic in sync with repo_trace.py.
class Trace(object):
    """Trace helper logic."""

    def __init__(self):
        self.set(1)

    def set(self, value):
        self.enabled = bool(value)

    def print(self, *args, **kwargs):
        if self.enabled:
            print(*args, **kwargs)


trace = Trace()

# This is a poor replacement for subprocess.run until we require Python 3.6+.
RunResult = collections.namedtuple(
    'RunResult', ('returncode', 'stdout', 'stderr'))

class RunError(Exception):
    """Error when running a command failed."""

def run_command(cmd, input=None, capture_stdout=None, capture_stderr=None, merge_output=None, **kwargs):
    """Run |cmd| and return its output."""
    stdin = subprocess.PIPE if input else None
    stdout = subprocess.PIPE if capture_stdout else None
    stderr = (subprocess.STDOUT if merge_output else
              (subprocess.PIPE if capture_stderr else None))

    # Run & package the results.
    proc = subprocess.Popen(cmd, stdin=stdin, stdout=stdout, stderr=stderr, encoding='utf-8', errors='backslashreplace', **kwargs)

    if capture_stdout:
        os.remove(capture_stdout) if capture_stdout is not True or False else None
        for line in iter(proc.stdout.readline, ''):
            print(line.replace('\n', ''))
            open(capture_stdout, 'a').write(line) if capture_stdout is not True or False else None

    if capture_stderr:
        print(proc.stderr.read())
        open(capture_stderr, 'w').write(proc.stderr.read()) if capture_stderr is not True or False else None

    (stdout, stderr) = proc.communicate(input=input)

    ret = RunResult(proc.returncode, stdout, stderr)

    return ret

class Config:
    def __init__(self):
        self.manifest_manifest = ''
        self.manifest_branch = ''
        self.manifest_swallow = False
        self.ccache_use = 'yes'
        self.ccache_path = '.ccache'
        self.ccache_size = '20G'
        self.rom_name = ''
        self.rom_device = ''
        self.rom_lunch = ''
        self.cmd = ''
        try:
            for name,value in [line.split(' = ') for line in open(cfile, 'r').read().splitlines()]:
                self.__dict__[name] = eval(value)
        except:
            self.save()
            for name,value in [line.split(' = ') for line in open(cfile, 'r').read().splitlines()]:
                self.__dict__[name] = eval(value)

    def save(self):
        data = ''
        for name in self.__dict__.keys():
            line = ((name + ' = ') + repr(self.__dict__[name]) + '\r\n')
            data += line
            open(cfile,'w').write(data)

    def writeConf(self, opt, arg):
        if opt.init:
            self.manifest_manifest = opt.init[0]
            self.manifest_branch = opt.init[1]
            self.manifest_swallow = opt.swallow
    
        if opt.ccache_use:
            self.ccache_use = opt.ccache_use
        if opt.ccache_path:
            self.ccache_path = opt.ccache_path
        if opt.ccache_size:
            self.ccache_size = opt.ccache_size

        if opt.rom_name:
            self.rom_name = opt.rom_name
        if opt.rom_device:
            self.rom_device = opt.rom_device
        if opt.rom_lunch:
            self.rom_lunch = opt.rom_lunch
    
        if arg:
            if arg[0] == '--':
                arg =  arg[1:]
            self.cmd = ' '.join(arg)

        self.save()

conf = Config()

def ParserArgs():
    parser = argparse.ArgumentParser()
    group = parser.add_argument_group('Manifest options:')
    group.add_argument('-i', '--init',
                       nargs=2,
                       dest='init',
                       metavar=('MANIFEEST', 'BRANCH'),
                       help='define manifest and branch to repo init')
    group.add_argument('--swallow',
                       action='store_true',
                       default=False,
                       dest='swallow',
                       help='swallow repo init')
    group.add_argument('-r', '--resync', 
                       action='store_true',
                       default=False,
                       dest='resync',
                       help='repo sync all repository after define using -i or --init')
    group.add_argument('--path',
                       nargs='*',
                       dest='resync_path',
                       metavar='PATH',
                       help='path custom when resync')
    
    group = parser.add_argument_group('CCache options:')
    group.add_argument('--use-ccache',
                       dest='ccache_use',
                       metavar='yes/no',
                       help='set use ccache or not (default: yes)')
    group.add_argument('--ccache-path',
                       dest='ccache_path',
                       metavar='PATH',
                       help='set ccache path')
    group.add_argument('--ccache-size',
                       dest='ccache_size',
                       metavar='..G/M',
                       help='set ccache size, default 20G, (ex: 20G)')
    
    parser.add_argument('-b', '--build', 
                        action='store_true',
                        default=False,
                        dest='build',
                        help='start build')
    parser.add_argument('-l', '--lunch',
                        dest='rom_lunch',
                        metavar='LUNCH',
                        help='define lunch command, (ex: vayu-userdebug)')
    parser.add_argument('-d', '--device',
                        dest='rom_device',
                        metavar='DEVICE',
                        help='define device for to build, (ex: vayu)')
    parser.add_argument('-c', '--clean',
                        dest='clean',
                        metavar='CLEAN',
                        help='make clean/dirty/full/installclean')
    parser.add_argument('-n', '--name',
                        dest='rom_name',
                        metavar='ROM',
                        help='define rom name, it will help to detect name file for upload')
    parser.add_argument('-v', '--version',
                        action='store_true',
                        default=False,
                        dest='version',
                        help='print version')

    opt, arg = parser.parse_known_args()
    return opt, arg

def main(argv):
    global Cmd

    opt, arg = ParserArgs()

    conf.writeConf(opt, arg)

    if opt.init:
        if conf.manifest_manifest == '' or conf.manifest_branch == '':
            print('Manifest and branch is empty. Setup first!!')
            sys.exit(1)

        cmd = 'repo init'
        if conf.manifest_swallow:
            cmd += ' --depth=1'
        cmd += ' -u %s -b %s' %(conf.manifest_manifest, conf.manifest_branch)
        ret = run_command(cmd.split(), capture_stdout=tmpLog)
        print(ret.returncode)

    if opt.resync:
        if not os.path.exists('.repo'):
            print('repo: folder .repo not found, init first')
            sys.exit(1)

        cmd = 'repo sync --no-tags --no-clone-bundle --current-branch'
        if conf.manifest_swallow:
            cmd += ' --optimized-fetch --prune'
        if opt.resync_path:
            for i in opt.resync_path:
                cmd += ' ' + i
        ret = run_command(cmd.split())

    if opt.build:
        # Ccache
        if conf.ccache_use == 'yes':
            Cmd += 'export CCACHE_EXEC=$(which ccache)' + n
            Cmd += 'export USE_CCACHE=1' + n
            Cmd += 'export CCACHE_DIR="' + conf.ccache_path + '"' + n
            Cmd += 'ccache -M ' + conf.ccache_size + n

        # Clean
        if opt.clean == 'dirty':
            Cmd += 'make installclean' + n
        elif opt.clean == 'clean':
            Cmd += 'make clean' + n
        elif opt.clean == 'device'
            Cmd += 'make deviceclean' + n
        elif opt.clean == 'full'
            Cmd += 'make clobber' + n
            Cmd += 'make clean' + n

        f = open(DirCmd, 'w')
        f.write(Cmd)
        f.close()
        #ret = run_command(['bash', DirCmd])
        #print('Exit code', ret.returncode)
        #print(ret.stderr)

if __name__ == '__main__':
    main(sys.argv[1:])
