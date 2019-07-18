#!/usr/bin/env python2.7

# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
#
# SPDX-License-Identifier: Apache-2.0
#

import ConfigParser
import cmd
import optparse
import os
import subprocess

cf = ConfigParser.ConfigParser()
root = os.getcwd()

dl_dir = root + '/download'
if not os.path.isdir(dl_dir):
    os.mkdir(dl_dir)

#--show-progress
wget_args = ' --continue --directory-prefix=' + dl_dir
tar_x_args = ' --restrict -C '

protocol_suffix = ['.git', '.tar.gz']


def os_system(cmd):
    print cmd
    os.system(cmd)


def get_tar_dst_depress_dir(tar_file_path):
    returncode = 0
    try:
        first_line = subprocess.check_output(
            'tar -tf ' + tar_file_path + ' | sed -n \'1p\'', shell=True)
        if first_line:
            first_line = first_line.split()[-1]
            if first_line.endswith('/'):
                return first_line.split()[-1].split('/')[0]
        else:
            print tar_file_path + ' seems broken or not exist!'
    except subprocess.CalledProcessError as e:
        returncode = e.returncode
        print e.output
    return None


def process_ini(file_path, filename, options):
    if filename != 'dl.ini':
        return None
    os.chdir(file_path)
    print 'Enter ' + file_path
    file_path = file_path.rstrip("/")
    cf.read(filename)
    try:
        dl_link = cf.get("variable", "dl_link").strip().strip("\'").strip("\"")
    except ConfigParser.NoOptionError:
        print 'missing dl_link variable!'
        exit(-1)
    try:
        dl_method = cf.get("variable", "dl_method").strip()
    except ConfigParser.NoOptionError:
        print 'missing dl_method variable!'
        exit(-1)
    try:
        dl_args = cf.get("variable", "dl_args").strip()
    except ConfigParser.NoOptionError:
        dl_args = None
    try:
        update_method = cf.get("variable", "update_method").strip()
    except ConfigParser.NoOptionError:
        update_method = None
    try:
        decompress_method = cf.get("variable", "decompress_method").strip()
    except ConfigParser.NoOptionError:
        decompress_method = None
    try:
        decompress_args = cf.get("variable", "decompress_args").strip()
    except ConfigParser.NoOptionError:
        decompress_args = None
    try:
        patch_method = cf.get("variable", "patch_method").strip()
    except ConfigParser.NoOptionError:
        patch_method = None

    code_dir = dl_link.split('/', -1)[-1]
    for suffix in protocol_suffix:
        code_dir = code_dir.split(suffix)[0]

    if options.clean:
        if decompress_method == 'tar':
            dl_file_name = dl_dir + '/' + dl_link.split('/', -1)[-1]
            decompress_dir = get_tar_dst_depress_dir(dl_file_name)
            if decompress_dir:
                code_dir = decompress_dir
            os_system('rm -f ' + dl_file_name)
        os_system('rm -rf ' + code_dir)
        os_system('rm -f .dl')
        print 'Exit ' + file_path
        return None

    if os.path.isfile('.dl'):
        if not update_method:
            print 'Exit ' + file_path
            return None
        print '--- update ' + file_path.split('/', -1)[-1] + '/' + code_dir + ' ---'
        os.chdir(code_dir)
        returncode = subprocess.call(
            update_method, stdout=subprocess.PIPE, shell=True)
        if returncode == 0:
            print 'update ' + code_dir + ' successfully.'
        else:
            print 'update ' + code_dir + ' failed.'
            exit(-1)
    else:
        print '--- download ' + dl_link + ' ---'
        dl_str = dl_method + ' ' + dl_link
        if dl_args:
            dl_str += ' ' + dl_args
        if dl_method == 'wget':
            dl_str += wget_args
        print dl_str
        returncode = subprocess.call(
            dl_str, stdout=subprocess.PIPE, shell=True)
        if returncode != 0:
            print 'download ' + dl_link + ' failed!'
            exit(-1)
        if decompress_method:
            dl_file_name = dl_dir + '/' + dl_link.split('/', -1)[-1]
            print '---decompress ' + dl_file_name + ' ---'
            decompress_str = decompress_method
            if decompress_args:
                decompress_str += ' ' + decompress_args
            decompress_str += ' ' + dl_file_name
            if decompress_method == 'tar':
                decompress_str += tar_x_args + "."
                decompress_dir = get_tar_dst_depress_dir(dl_file_name)
                if decompress_dir:
                    code_dir = decompress_dir
            print decompress_str
            returncode = subprocess.call(decompress_str, shell=True)
            if returncode != 0:
                print 'decompress ' + dl_file_name + ' failed!'
                exit(-1)

        if patch_method:
            patch_method = patch_method.replace("@@code_dir@@", code_dir)
            print patch_method
            returncode = subprocess.call(patch_method, shell=True)
            if returncode != 0:
                print 'patch ' + code_dir + ' failed!'
                exit(-1)

        # print 'echo ' + code_dir + ' > .dl'
        os.system('echo ' + code_dir + ' > .dl')
        print 'download ' + dl_link + ' successfully.'


init_optparse = optparse.OptionParser(usage="./dl.py [options] [topdir]")
# init_optparse.add_option("--top", dest="topdir",
#                         help="parse topdir", default=root)
init_optparse.add_option("-c", "--clean", action="store_true",
                         dest="clean", default=False,
                         help="clean the download modules")
(options, args) = init_optparse.parse_args()
parse_dirs = []
if not args:
    parse_dirs.append(root)
else:
    for dir in args:
        if not os.path.isdir(dir):
            init_optparse.print_help()
            print '\n' + dir + ' is not directory!'
            exit(1)
    parse_dirs = args

for parse_dir in parse_dirs:
    for file_path, dirs, files in os.walk(parse_dir):
        for filename in files:
            process_ini(file_path, filename, options)

if options.clean and not args:
    cmd = 'rm -rf ' + dl_dir
    print cmd
    os.system(cmd)
