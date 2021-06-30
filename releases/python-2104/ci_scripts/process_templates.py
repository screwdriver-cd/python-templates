#!/usr/bin/env python3
# Copyright 2021, Oath Inc.
# Licensed under the terms of the Apache 2.0 license.  See the LICENSE file in the project root for terms
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import sys


def template_value(key, filename=None):
    if not filename:
        filename = os.environ.get('SD_TEMPLATE_PATH', None)
        if not filename:
            return

    with open(filename) as handle:
        for line in handle.readlines():
            line = line.strip()
            if ':' in line:
                key_name = line.split(':')[0]
                if key_name.strip() == key:
                    return ':'.join(line.split(':')[1:]).strip().strip("'").strip('"').strip()


def determine_template_file_list():
    templates = []
    template_dir = Path(os.environ.get('TEMPLATE_DIR', 'templates'))
    templates_specified = os.environ.get('TEMPLATES', '').split(',')
    for t in templates_specified:
        t = t.strip()
        if not t:
            continue
        template = template_dir/Path(t)
        if template.is_dir():
            print(f'template: {template} glob: {list(template.glob("**/*.yaml"))}')
            templates += template.glob('**/*.yaml')
        else:
            templates.append(template)
    return templates


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', default='validate', choices=['validate', 'publish'])
    args = parser.parse_args()

    template_tag = os.environ.get('TEMPLATE_TAG', 'pre')
    template_tags = template_tag.split(',')

    for template in determine_template_file_list():
        os.environ['SD_TEMPLATE_PATH'] = str(template)
        print(f'Processing template: {str(template)}')
        template_namespace = template_value("namespace", filename=template)
        template_name = f'{template_namespace}/{template_value("name", filename=template)}'
        command = './node_modules/.bin/template-validate'
        if args.operation == 'publish':
            command = './node_modules/.bin/template-publish'
        if args.operation == 'validate':
            command = './node_modules/.bin/template-validate'

        print(f'Processing Template: {template_name} Running: {command}')
        try:
            result = subprocess.run(shlex.split(command))
        except FileNotFoundError:
            print(f'The {command} script was not found')
            return 1
        if result.returncode != 0:
            print(f'The {args.operation} operation failed for the {template} template')
            # return result.returncode
            pass

        if args.operation == 'publish':
            for tag in template_tags:
                command = f'./node_modules/.bin/template-tag --name "{template_name}" --tag "{tag}"'
                print(f'Running command: {command}')
                try:
                    result = subprocess.run(shlex.split(command))
                except FileNotFoundError:
                    print(f'The {command} script was not found')
                    return 1
                if result.returncode != 0:
                    print(f'The {args.operation} operation failed for the {template} template')
                    return result.returncode
        print('', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

