# awx-install-in-test-environment

## Prepare environment
```bash
python3 -m venv .venv
source .venv/bin/activate

pip3 install -r requirements.txt
```

## AWX minikube provision
```bash
ansible-playbook awx_install_playbook.yml
minikube service -n awx awx-service --url
kubectl get secret -n awx awx-admin-password -o jsonpath="{.data.password}" | base64 --decode ; echo
```

## Create AWX test client
```bash
vagrant up
```