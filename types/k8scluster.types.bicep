@export()
@sealed()
type k8scluster = {
  name: string
  numCP: 1
  numWorker: int
  cniPlugin: 'calico'
  cniCidr: '10.244.0.0/16'
}

var commonPrerequisiteConfig = loadTextContent('../scripts/common-prerequisites.sh', 'utf-8')
var kubeadmInit = loadTextContent('../scripts/kubeadmInit.sh','utf-8')
var kubeadmInitYml = loadTextContent('../scripts/kubeadmInit.sh','utf-8')
var kubeadmJoinYml = loadTextContent('../scripts/kubeadmJoin.yml','utf-8')
var cniInstall = loadTextContent('../scripts/cniPlugin.sh','utf-8')
var finalizeDeploy = loadTextContent('../scripts/finalizeDeploy.sh','utf-8')
