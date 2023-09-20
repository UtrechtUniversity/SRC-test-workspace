#!/usr/bin/env python3

import yaml
import tarfile
import json
import os
import docker
import shlex
import traceback
import tempfile
from optparse import OptionParser

DOCKER_IMG_NAME = 'src-basic-workspace'
CONTAINER_NAME = 'src-test-container'
EXTERNAL_COMPONENT = './plugin-external-plugin/plugin-external-plugin.yml'
WORKSPACE_PLUGIN_DIR = '/rsc/plugins/'

### User supplied configuration ###
parser = OptionParser()
parser.add_option("-m", "--method", choices=("ansible", "docker"),
                  help="Which method to use to execute ansible on the target (ansible into the target, or use docker exec).",
                  default="ansible")
parser.add_option("-c", "--config",
                  help="Path to .yml file describing the components and parameters to be deployed.")
parser.add_option("-s", "--stop", help="See if an old container with the configured name ('{}') exists and stop it if so.".format(CONTAINER_NAME))
(options, args) = parser.parse_args()

if not options.config:
    raise Exception("You did not provide the required -c option.")

method = options.method
print("Using method '{}' for triggering ansible on the target.".format(method))

with open(options.config) as cfg:
    workspace_config = yaml.safe_load(cfg)

default_dir = workspace_config['default_script_dir']

WORKSPACE_ANSIBLE_VERSION = workspace_config.get('remote_ansible_version', None)
### End user-supplied configuration ###

### Stop/run docker container
print('Starting up test image...')
client = docker.from_env()
if options.stop:
    try:
        old_container = client.containers.get(CONTAINER_NAME)
        old_container.stop()
    except:
        pass
container = client.containers.run(DOCKER_IMG_NAME, detach=True, command="/bin/bash", tty=True, init=True, name=CONTAINER_NAME, auto_remove=True)
print('Container started -- do not forget to stop it! Container name: {}'.format(container.name))
###

def container_copy_to(src, dst, container):
    srcname = os.path.basename(src)
    tmpdir = tempfile.TemporaryDirectory()
    tarpath = os.path.join(tmpdir.name, srcname)

    os.chdir(os.path.dirname(src))
    tar = tarfile.open(tarpath, mode='w')
    try:
        tar.add(srcname)
    finally:
        tar.close()

    data = open(tarpath, 'rb').read()
    container.put_archive(os.path.dirname(dst), data)
    tmpdir.cleanup()

def execute_ansible(container, plugin):
    ansible_cmd = 'ansible-playbook -b -c docker -i "{container}," -vvv --extra-vars {parameters} {playbook}'
    params = shlex.quote(json.dumps(plugin))
    cmd = ansible_cmd.format(container=container.name, playbook=EXTERNAL_COMPONENT, parameters=params)
    print("Running ", cmd)
    return os.system(cmd)

def execute_docker(container, plugin):
    print('Copying plugin to container...')
    container_copy_to(plugin['script_folder'], WORKSPACE_PLUGIN_DIR, container)
    cmd = 'ansible-playbook -vvv --connection=local -b {plugin_arguments} --extra-vars="{plugin_parameters}" {plugin_script_folder}/{plugin_path}'.format(
        plugin_arguments = plugin['arguments'],
        plugin_parameters = plugin['parameters'],
        plugin_script_folder = os.path.join(WORKSPACE_PLUGIN_DIR, os.path.basename(plugin['script_folder'])),
        plugin_path = plugin['path']
    )
    (response, output) = container.exec_run(cmd=cmd, privileged=True, stream=True)
    for data in output:
        print(data.decode(), end='')
    return response

try:
    for component in workspace_config['components']:
        extra_vars = {
            'remote_plugin':
            {
                'script_type': 'Ansible PlayBook',
                'script_folder': component.get('base_dir', default_dir),
                'path': component['path'],
                'parameters': {
                },
                'arguments': '-i 127.0.0.1,'
            }
        }
        if WORKSPACE_ANSIBLE_VERSION:
            extra_vars['remote_ansible_plugin'] = WORKSPACE_ANSIBLE_VERSION

        if method == 'ansible':
            result = execute_ansible(container, extra_vars)
        elif method == 'docker':
            result = execute_docker(container, extra_vars['remote_plugin'])
        else:
            raise Exception("Unknown method: {}".format(METHOD))

        if result is False:
            raise Exception("Failed to execute component!")
except:
    traceback.print_exc()
    container.stop()