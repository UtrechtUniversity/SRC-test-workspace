#!/usr/bin/env python

import yaml
import json
import os
import docker
import shlex
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-m", "--method", choices=("ansible", "docker"),
                  help="Which method to use to execute ansible on the target (ansible into the target, or use docker exec).", default="ansible")
(options, args) = parser.parse_args()

method = options.method

DOCKER_IMG_NAME = 'src-basic-workspace'
CONTAINER_NAME = 'src-test-container'
CONFIG = 'test-components.yml'
EXTERNAL_COMPONENT = '/Users/dawa/Code/uu/src/deploy_components/plugin-external-plugin/plugin-external-plugin.yml'

def execute_ansible(container, plugin):
    ansible_cmd = 'ansible-playbook -b -u root -c docker -i "{container}," -vvvv --extra-vars {parameters} {playbook}'
    params = shlex.quote(json.dumps(plugin))
    cmd = ansible_cmd.format(container=container.name, playbook=EXTERNAL_COMPONENT, parameters=params)
    print("Running ", cmd)
    return os.system(cmd)

def execute_docker(container, plugin):
    cmd =  "ansible-playbook --connection=local -b {remote_plugin_arguments} --extra-vars="{remote_plugin_parameters}" /rsc/plugins/{remote_plugin_script_folder}/{remote_plugin_path}".format(
        remote_plugin_arguments = plugin.arguments
        remote_plugin_parameters = plugin.parameters
        remote_plugin_script_folder = os.path.basename(plugin.script_folder)
        remote_plugin_path = plugin.path
    )
    return container.exec_run(cmd=cmd, priviliged=true)

with open(CONFIG) as cfg:
    components_cfg = yaml.safe_load(cfg)

default_dir = components_cfg['default_script_dir']

print('Starting up test image...')
client = docker.from_env()
container = client.containers.run(DOCKER_IMG_NAME, detach=True, command="/bin/bash", tty=True, init=True, name=CONTAINER_NAME, auto_remove=True)
print('Container started -- do not forget to stop it! Container name: {}'.format(container.name))

try:
    for component in components_cfg['enabled_components']:
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
        if method is 'ansible':
            result = execute_ansible(container, plugin)
        elif method is 'docker':
            result = execute_docker(container, plugin)
        else:
            raise Exception("Unknown method: {}".format(METHOD))

        if result is False:
            raise Exception("Failed to execute component!")
except:
    container.stop()