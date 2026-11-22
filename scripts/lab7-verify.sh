#!/usr/bin/env bash
set -euo pipefail

inventory=ansible_iac/hosts.ini
playbook=ansible_iac/setup_env.yml
echo '$ ansible local -i ansible_iac/hosts.ini -m ping'
ansible local -i "$inventory" -m ansible.builtin.ping
ansible-playbook "$playbook" -i "$inventory" --syntax-check

echo '=== Первый запуск playbook ==='
ansible-playbook "$playbook" -i "$inventory" | tee "${RUNNER_TEMP:-/tmp}/lab7-first.log"
echo '=== Повторный запуск playbook ==='
ansible-playbook "$playbook" -i "$inventory" | tee "${RUNNER_TEMP:-/tmp}/lab7-second.log"
grep -Eq 'changed=0 .*failed=0' "${RUNNER_TEMP:-/tmp}/lab7-second.log"

echo '$ curl http://localhost'
curl --fail --silent --show-error http://127.0.0.1/
sha256sum "$playbook" | awk '{print $1}' > lab7_ansible_hash.txt
git log -n 1 --oneline | sha256sum | awk '{print $1}' >> lab7_ansible_hash.txt
echo 'Blueprint (playbook and Git SHA-256):'
cat lab7_ansible_hash.txt
