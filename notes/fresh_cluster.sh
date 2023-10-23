k3dname=$(yq '.metadata.name' k3d_config.yaml)
k3d cluster list ${k3dname} --no-headers | awk {'system("k3d cluster delete " $1)'}
k3d cluster create --config=k3d_config.yaml
SERVER_IP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
IMAGE_CACHE=${HOME}/.k3d-container-image-cache
mkdir -p ${IMAGE_CACHE}
kubectl config use-context k3d-${k3dname}
REGISTRY1_USERNAME=$(yq '.registryCredentials.username' overrides/ib_creds.yaml)
REGISTRY1_PASSWORD=$(yq '.registryCredentials.password' overrides/ib_creds.yaml)
echo $REGISTRY1_PASSWORD | docker login registry1.dso.mil --username $REGISTRY1_USERNAME --password-stdin
cd ~
rm -rf bigbang
git clone https://repo1.dso.mil/big-bang/bigbang.git
cd ~/bigbang
git checkout tags/$(grep 'tag:' base/gitrepository.yaml | awk '{print $2}')

vcluster create pipeliners -f vcluster/pipeline.yaml

$HOME/bigbang/scripts/install_flux.sh -u $REGISTRY1_USERNAME -p $REGISTRY1_PASSWORD
kubectl get pods --namespace=flux-system
helm upgrade --install bigbang $HOME/bigbang/chart \
  --values https://repo1.dso.mil/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml \
  --values $HOME/overrides/ib_creds.yaml \
  --values $HOME/overrides/bigbang_config.yaml \
  --namespace=bigbang --create-namespace