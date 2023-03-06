[TOC]



# 安装



## 安装要求

安装k8s集群的基本要求如下，

https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

- 至少2核CPU + 2G内存
- 操作系统版本必须符合如下要求
  - Ubuntu 16.04+
- 集群中的所有机器的网络彼此均能相互连接
- 节点之中不可以有重复的主机名、MAC 地址或 product_uuid。
- 查看[k8s所需端口](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#check-required-ports)，确保这些端口未被防火墙拦截，并检查所需端口在主机上没有被占用。
- 禁用交换分区。

## 查看CPU和内存

```
# 查看系统CPU
$ cat /proc/cpuinfo

# 查看系统memory
$ cat /proc/meminfo
```

## 查看系统版本

- Ubuntu的版本至少16.04：

```
# 查看当前系统的内核
$ uname -a
Linux k8s-master01 5.8.0-41-generic #46-Ubuntu SMP Mon Jan 18 16:48:44 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux

# 查看当前系统版本
$ cat /etc/lsb-release 
```



## Master+Node配置

- 设置主机名

```
# 192.168.65.100
hostnamectl set-hostname k8s-master
# 192.168.65.101
hostnamectl set-hostname k8s-node1
# 192.168.65.102
hostnamectl set-hostname k8s-node2
```

- 配置主机名解析

```
cat >> /etc/hosts << EOF
127.0.0.1   $(hostname)
192.168.200.171 200-171
192.168.200.172 200-172
EOF
```

- 配置ssh互信

```
ssh-keygen

vim ~/.ssh/authorized_keys
```

- 时间同步：（k8s集群中的节点时间必须精确一致，所以在每个节点上添加时间同步）

```
# 安装utpdate
sudo apt-get install ntpdate

# 系统时间与网络同步
ntpdate cn.pool.ntp.org

# 查看时间是否已经同步
date
```

- 关闭swap

```
# 查看内存中的swap分配情况
$ free -m
              total        used        free      shared  buff/cache   available
Mem:           3932         854         457          15        2620        2783
Swap:          2047           0        2047


# 永久关闭 swap ，需要重启：
sed -ri 's/.*swap.*/#&/' /etc/fstab

# 查看内存中的swap分配为0
$ free -m 
              total        used        free      shared  buff/cache   available
Mem:           3932        1265        1074          12        1592        2499
Swap:             0           0           0 
```

- 开启iptables

```
# 修改 /etc/sysctl.conf 文件，可能没有，追加
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1"  >> /etc/sysctl.conf

# 加载 br_netfilter 模块：
modprobe br_netfilter

# 持久化修改
sysctl -p

# 确认netfilter的加载情况，若能看到如下的命令输出，则说明netfilter已被加载
$ lsmod | grep br_netfilter
br_netfilter           28672  0
bridge                200704  1 br_netfilter
```

- 开启ipvs

https://www.jianshu.com/p/d1ba8b910085

```
# 安装ipset软件包
apt install ipset

# 安装ipvs管理工具
apt install ipvsadm

# /etc/sysconfig/modules/ipvs.modules，保证在节点重启后能自动加载所需模块
mkdir -p  /etc/sysconfig/modules/
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF

# 查看是否已经正确加载所需的内核模块
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4
```

- 重启

- 上述配置都设置后，重启Master和Node所在对全部机器。

## 安装docker（全节点）

```
# 安装curl工具，若已安装可以跳过
$ sudo apt install curl

$ sudo apt-get update && sudo apt-get install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2

# 添加docker apt repository
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key --keyring /etc/apt/trusted.gpg.d/docker.gpg add -
$ sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

# 安装docker
$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli

# 启动 Docker 
systemctl start docker

# 开启自动启动
systemctl enable docker

# 验证 Docker 是否安装成功：
docker version

# 设置阿里云Docker镜像加速器
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://klmgh2jx.mirror.aliyuncs.com"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker
sudo systemctl status docker
```

## 安装kubeadm、kubelet、kubectl（全节点）

```
# 使用阿里云镜像
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add - 
sudo vim /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main

# 使用中科大镜像
# 添加GPG Key
$ curl -fsSL https://raw.githubusercontent.com/EagleChen/kubernetes_init/master/kube_apt_key.gpg | sudo apt-key add -
# 添加K8S软件源
$ sudo add-apt-repository "deb http://mirrors.ustc.edu.cn/kubernetes/apt kubernetes-xenial main"


# 查看可安装版本
$ apt-get update
$ apt-cache madison kubelet

# 安装指定版本
# 注意,因为V1.24以上的k8s版本已经弃用了docker，所以只能安装1.23.9
$  sudo apt-get install -y kubelet=1.23.9-00 kubeadm=1.23.9-00 kubectl=1.23.9-00

# 设置开机启动
$  sudo systemctl enable kubelet && sudo systemctl start kubelet
```

- ~~为了实现Docker使用的cgroup drvier和kubelet使用的cgroup drver一致，建议修改"/etc/sysconfig/kubelet"文件的内容：~~

```
vim /etc/sysconfig/kubelet
# 修改
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"
KUBE_PROXY_MODE="ipvs"
```

- 启动
- 如果发现启动失败是正常的，因为在k8s master节点初始化之前，kubelet连不上api server，kubelet会定时尝试连接k8s api server，直到成功。

```
# 启动kubelet
$ sudo systemctl restart kubelet

# 查看状态
systemctl status kubelet
```



## 部署k8s的Master（主节点）

- 考虑k8s service和pod的网段划分，避免和主机节点的网段冲突，本文在安装过程中设计的三个网段划分如下，
  - 主机节点网段：10.0.2.0/8
  - k8s service网段：10.1.0.0/16
  - k8s pod网段：10.244.0.0/16
- --apiserver-advertise-address：Master节点ip，比如192.168.200.171
- --image-repository=registry.aliyuncs.com/google_containers 这个是镜像地址，由于国外地址无法访问，故使用的阿里云仓库地址：registry.aliyuncs.com/google_containers
- --kubernetes-version=v1.17.4  这个参数是下载的k8s软件版本号
- --service-cidr=10.96.0.0/12   # k8s service网段。这个参数后的IP地址直接就套用10.96.0.0/12 ,以后安装时也套用即可，不要更改
- --pod-network-cidr=10.244.0.0/16   k8s pod网段，不能和service-cidr写一样，默认10.244.0.0/16

```
kubeadm init --apiserver-advertise-address=192.168.200.171 --image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers --kubernetes-version v1.26.1 --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --node-name k8s-master --control-plane-endpoint=cluster-endpoint
```

- 配置kubeconfig

```
# 复制授权文件，以便 kubectl 可以有权限访问集群
# 如果你其他节点需要访问集群，需要从主节点复制这个文件过去其他节点
# 在其他机器上创建 ~/.kube/config 文件也能通过 kubectl 访问到集群
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

- 查看是否正常init

```
$ kubectl get componentstatus

Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok                              
controller-manager   Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""} 

# 查看kubelet的状态
$ systemctl status kubelet
● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/lib/systemd/system/kubelet.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/kubelet.service.d
             └─10-kubeadm.conf
     Active: active (running)
       Docs: https://kubernetes.io/docs/home/
   Main PID: 97961 (kubelet)
      Tasks: 17 (limit: 4650)
     Memory: 68.7M
     CGroup: /system.slice/kubelet.service
             └─97961 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubel>
             
# 查看k8s集群状态
$ kubectl cluster-info
Kubernetes control plane is running at https://10.0.2.15:6443
KubeDNS is running at https://10.0.2.15:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

# 查看控制平面的服务列表
$ kubectl get pods -n kube-system
NAMESPACE     NAME                                            READY   STATUS    RESTARTS   AGE
kube-system   coredns-7f89b7bc75-685w4                        0/1     Pending   0          3m47s
kube-system   coredns-7f89b7bc75-tcp2b                        0/1     Pending   0          3m47s
kube-system   etcd-michaelk8s-virtualbox                      1/1     Running   0          3m53s
kube-system   kube-apiserver-michaelk8s-virtualbox            1/1     Running   0          3m53s
kube-system   kube-controller-manager-michaelk8s-virtualbox   1/1     Running   0          3m53s
kube-system   kube-proxy-6pvcb                                1/1     Running   0          3m47s
kube-system   kube-scheduler-michaelk8s-virtualbox            1/1     Running   0          3m53s


# 查看集群初始化配置，在正式环境的搭建过程中，可以通过kubeadm config的方式来初始化master/worker节点
$ sudo kubeadm config print init-defaults
$ sudo kubeadm config print join-defaults
```

- 重新init：

```
kubeadm reset
rm -fr ~/.kube/  /etc/kubernetes/* /var/lib/etcd/* /etc/cni/net.d
rm -fr ~/.kube/ /etc/cni/net.d

lsof -i :6443|grep -v "PID"|awk '{print "kill -9",$2}'|sh
lsof -i :10250|grep -v "PID"|awk '{print "kill -9",$2}'|sh
lsof -i :10257|grep -v "PID"|awk '{print "kill -9",$2}'|sh
lsof -i :10259|grep -v "PID"|awk '{print "kill -9",$2}'|sh
lsof -i :2379|grep -v "PID"|awk '{print "kill -9",$2}'|sh
lsof -i :2380|grep -v "PID"|awk '{print "kill -9",$2}'|sh
```



## 在master部署Pod

- 在k8s中默认master是不允许部署pod的，原理就是每个主节点都存在污点。

```
# 查看node-name
kubectl get node
NAME         STATUS   ROLES                  AGE     VERSION
k8s-master   Ready    control-plane,master   2m45s   v1.23.9

# 查看污点
# 当看到他的NoSchedule参数表示他是一个有污点的节点，这样就不能部署Pod
$ kubectl describe nodes k8s-master | grep Taints
Taints:             node-role.kubernetes.io/master:NoSchedule
   
   
# 添加污点
kubectl taint node k8s-master <node-role.kubernetes.io/master>=:NoSchedule
- key:node-role.kubernetes.io/master
- value:空

# 去除污点
$ kubectl taint node k8s-master node-role.kubernetes.io/master:NoSchedule-
node/string untainted
```

## 设置kube-proxy的ipvs模式（master）

```
kubectl edit cm kube-proxy -n kube-system

# mode修改为ipvs
kind: KubeProxyConfiguration
metricsBindAddress: ""
mode: "ipvs" # 修改此处

# 验证修改成功
$ kubectl get cm kube-proxy -n kube-system -o yaml | grep mode

# 先查看
kubectl get pod -n kube-system | grep kube-proxy

# 再delete让它自拉起
kubectl get pod -n kube-system | grep kube-proxy |awk '{system("kubectl delete pod "$1" -n kube-system")}'

# 再查看
kubectl get pod -n kube-system | grep kube-proxy

# 测试接口
curl localhost:10249/proxyMode



# 查看 ipvs 转发规则
ipvsadm -L -n
```



## 部署网络插件（主节点）

- k8s支持多种网络插件：flannel、calico、canal

```
# 部署calio
$ kubectl apply -f calico.yaml

# 查看部署CNI网络插件进度：
watch kubectl get pods -n kube-system

# 再次在Master节点使用kubectl工具查看节点状态：
kubectl get nodes

# 查看集群健康状况：
kubectl get cs
kubectl cluster-info
```



## 部署k8s的Node（工作节点）

```
# 把工作节点加入集群（只在工作节点跑）
kubeadm join 192.168.200.171:6443 --token jdrgfi.jnro83uasp5870e9 --discovery-token-ca-cert-hash sha256:8407bbf4ee1a0a9e55e0dd103a88bddbb343946f717244db72531bf25d0237d9 --node-name k8s-master
```

- 默认的token有效期为2小时，当过期之后，该token就不能用了，这时可以使用如下的命令创建token：

```
kubeadm token create --print-join-command

# 生成一个永不过期的token
kubeadm token create --ttl 0 --print-join-command
```

- 让Node节点也能使用kubectl（将Master的.kube文件复制到Node上，在mster节点执行下面的命令：

```
scp -r $HOME/.kube k8s-node1:$HOME
scp /etc/kubernetes/admin.conf root@192.168.200.172:~/.kube/config
```

## 生成yaml文件

- 使用kubectl create命令生成yaml文件：

```
kubectl create deployment nginx --image=nginx:1.17.1 --dry-run=client -n dev -o yaml

# 如果yaml文件太长，可以写入到指定的文件中。
kubectl create deployment nginx --image=nginx:1.17.1 --dry-run=client -n dev -o yaml > test.yaml
```

# 资源管理

- 命令式对象管理

```
kubectl run nginx-pod --image=nginx:1.17.1 --port=80
```

- 命令式对象配置

```
kubectl create/patch -f nginx-pod.yaml
```

- 声明式对象配置（声明式对象配置和命令式对象配置类似，只不过它只有一个apply命令，通过apply命令和配置文件去操作kubernetes的资源）

```
kubectl apply -f nginx-pod.yaml
```

### 使用方式

- 创建和更新：声明式对象配置：kubectl apply -f xxx.yaml。

- 删除：命令式对象配置：kubectl delete -f xxx.yaml。

- 查询：命令式对象管理：kubectl get(describe) 资源名称

## 命令式对象管理

- Get

```
# 查看全部
kubectl get all

# 查看 deployment
kubectl get deployment

# 输出到文件
kubectl get deployment test-k8s -o yaml >> app2.yaml
```

- Scale

```
# 伸缩扩展副本
kubectl scale deployment test-k8s --replicas=5
```

- Port-forward

```
# 把集群内端口映射到节点
kubectl port-forward pod-name 8090:8080
```

- Rollout

```
# 查看历史
kubectl rollout history deployment test-k8s

# 回到上个版本
kubectl rollout undo deployment test-k8s

# 回到指定版本
kubectl rollout undo deployment test-k8s --to-revision=2

# 重新部署
kubectl rollout restart deployment test-k8s

# 暂停运行，暂停后，对 deployment 的修改不会立刻生效，恢复后才应用设置
kubectl rollout pause deployment test-k8s

# 恢复
kubectl rollout resume deployment test-k8s
```

- Delete

```
# 删除部署
kubectl delete deployment test-k8s

# 删除全部资源
kubectl delete all --all
```

- Set

```
# 命令修改镜像，--record 表示把这个命令记录到操作历史中
kubectl set image deployment test-k8s test-k8s=ccr.ccs.tencentyun.com/k8s-tutorial/test-k8s:v2-with-error --record
```

## 命令式对象配置

- 命令式对象配置的方式操作资源，可以简单的认为：命令+yaml配置文件（里面是命令需要的各种参数）。

- 创建nginspod.yaml

```
apiVersion: v1
kind: Namespace
metadata:
  name: dev
---
apiVersion: v1
kind: Pod
metadata:
  name: nginxpod
  namespace: dev
spec:
  containers:
    - name: nginx-containers
      image: nginx:1.17.1
```

- 资源

```
# 创建资源
kubectl create -f nginxpod.yaml

# 查看资源
kubectl get -f nginxpod.yaml

# 删除资源
kubectl delete -f nginxpod.yaml
```

## 声明式对象配置

- 声明式对象配置就是使用apply描述一个资源的**最终状态**（在yaml中定义状态）。

- 使用apply操作资源：

- - 如果资源不存在，就创建，相当于kubectl create。

- - 如果资源存在，就更新，相当于kubectl patch。

```
kubectl apply -f nginxpod.yaml
```

# 概念

## Namespace

- 命令式对象管理

```
# 创建一个namespace
kubectl create namespace dev
kubectl create ns dev

# 查看全部namespace
kubectl get namespace
kubectl get ns
NAME              STATUS   AGE
default           Active   18h # 没有指定ns的资源默认是default
kube-node-lease   Active   18h # 集群节点之间的心跳维护
kube-public       Active   18h # kube-public可以被全部人访问
kube-system       Active   18h # 保存kubernetes系统创建的资源

# 查看指定ns
kubectl get namespace default
kubectl get ns default

# 指定ns的输出格式
kubectl get ns default -o wide
kubectl get ns default -o json
kubectl get ns default -o yaml

# 查看ns详情
kubectl describe namespace default
kubectl describe ns default

# 删除namespace
kubectl delete namespace dev
kubectl delete ns dev
```

- 命令式对象配置

```
# 新建ns-dev.yaml：
apiVersion: v1
kind: Namespace
metadata:
  name: dev

kubectl create -f ns-dev.yaml

kubectl delete -f ns-dev.yaml
```

## Pod

- 命令式对象管理

```
# 创建Pod
kubectl run (Pod的名称) [参数]
# --image 指定Pod的镜像
# --port 指定端口
# --namespace 指定namespace
kubectl run nginx --image=nginx:1.17.1 --port=80 --namespace=dev

# 查看dev ns下所有pod，-n用于指定namespace
kubectl get pods -n dev

# 查看某个pod
kubectl get pod <pod_name>

# 查看某个pod，以yaml格式展示结果
kubectl get pod <pod_name> -o yaml

# 查看Pod的详细信息
kubectl describe pod <nginx> -n dev

# 查看 log
kubectl logs pod-name

# 访问pod
kubectl get pods -n dev -o wide
curl 10.244.2.7:80

# 进入 Pod 容器终端， -c container-name 可以指定进入哪个容器。
kubectl exec -it pod-name -- bash

# 删除指定ns下pod
kubectl delete pod nginx -n dev
```

- 命令式对象配置

```
# 新建pod-nginx.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: dev
spec:
  containers:
  - image: nginx:1.17.1
    imagePullPolicy: IfNotPresent
    name: pod
    ports: 
    - name: nginx-port
      containerPort: 80
      protocol: TCP
      
      
kubectl create -f pod-nginx.yaml

kubectl delete -f pod-nginx.yaml
```

## Pod的配置

k8s中所有资源的一级属性都是一样的，包含5个部分：

- apiVersion：版本号。`kubectl api-versions`
- kind：资源类型。`kubectl api-resources`
- metadata：元数据。包含资源名称，资源所属的命名空间，标签列表
- spec：配置详细描述。
  - containers：容器列表。
  - nodeName：根据nodeName的值将Pod调度到指定的Node节点上。
  - nodeSelector：根据NodeSelector中定义的信息选择该Pod调度到包含这些Label的Node上。
  - hostNetwork：是否使用主机网络模式，默认为false，如果设置为true，表示使用宿主机网络。
  - volumes：存储卷。定义Pod上面挂载的存储信息。
  - restartPolicy：重启策略。`[Always | Never | OnFailure]`
- status：状态。无需配置，由k8s生成。

### 镜像拉取策略

配置拉取策略imagePullPolicy：

- Always：总是从远程仓库拉取镜像（一直远程下载）。
- IfNotPresent：本地有则使用本地镜像，本地没有则从远程仓库拉取镜像（本地有就用本地，本地没有就使用远程下载）。
- Never：只使用本地镜像，从不去远程仓库拉取，本地没有就报错（一直使用本地，没有就报错）。

默认：

- 如果镜像tag为具体的版本号，默认策略是IfNotPresent。

- 如果镜像tag为latest（最终版本），默认策略是Always。

### 	启动命令

Pod的容器初始化完成后执行的命令commad：

```
command: ["/bin/sh","-c","touch /tmp/hello.txt;while true;do /bin/echo $(date +%T) >> /tmp/hello.txt;sleep 3;done;"]
```

- `"/bin/sh","-c"`：使用sh执行命令。
- `touch /tmp/hello.txt`：创建一个/tmp/hello.txt的文件。
- `while true;do /bin/echo $(date +%T) >> /tmp/hello.txt;sleep 3;done`：每隔3秒，向文件写入当前时间

### 资源配额

- cpu：core数，可以为整数或小数。

- memory：内存大小，可以使用Gi、Mi、G、M等形式。

```
resources: # 资源配额
  limits: # 限制资源的上限
    cpu: "2" # CPU限制，单位是core数
    memory: "10Gi" # 内存限制
  requests: # 限制资源的下限
    cpu: "1" # CPU限制，单位是core数 
    memory: "10Mi" # 内存限制
```



- 配置信息：

```yaml
apiVersion: v1     #必选，版本号，例如v1
kind: Pod       　 #必选，资源类型，例如 Pod
metadata:       　 #必选，元数据
  name: string     #必选，Pod名称
  namespace: string  #Pod所属的命名空间,默认为"default"
  labels:       　　  #自定义标签列表
    - name: string      　          
spec:  #必选，Pod中容器的详细定义
  containers:  #必选，Pod中容器列表
  - name: string   #必选，容器名称
    image: string  #必选，容器的镜像名称
    imagePullPolicy: [ Always|Never|IfNotPresent ]  # 用于设置镜像的拉取策略
    command: ["/bin/sh","-c","touch /tmp/hello.txt;while true;do /bin/echo $(date +%T) >> /tmp/hello.txt;sleep 3;done;"]   #容器的启动命令列表，如不指定，使用打包时使用的启动命令
    args: [string]      #容器的启动命令参数列表
    workingDir: string  #容器的工作目录
    volumeMounts:       #挂载到容器内部的存储卷配置
    - name: string      #引用pod定义的共享存储卷的名称，需用volumes[]部分定义的的卷名
      mountPath: string #存储卷在容器内mount的绝对路径，应少于512字符
      readOnly: boolean #是否为只读模式
    ports: #需要暴露的端口库号列表
    - name: string        #端口的名称
      containerPort: int  #容器需要监听的端口号(0~65536)
      hostPort: int       #容器所在主机需要监听的端口号，默认与Container相同
      protocol: string    #端口协议，支持TCP和UDP，默认TCP
    env:   #容器运行前需设置的环境变量列表
    - name: string  #环境变量名称
      value: string #环境变量的值
    resources: #资源限制和请求的设置
      limits:  #资源限制的设置
        cpu: string     #Cpu的限制，单位为core数，将用于docker run --cpu-shares参数
        memory: string  #内存限制，单位可以为Mib/Gib，将用于docker run --memory参数
      requests: #资源请求的设置
        cpu: string    #Cpu请求，容器启动的初始可用数量
        memory: string #内存请求,容器启动的初始可用数量
    lifecycle: #生命周期钩子
		postStart: #容器启动后立即执行此钩子,如果执行失败,会根据重启策略进行重启
		preStop: #容器终止前执行此钩子,无论结果如何,容器都会终止
    livenessProbe:  #对Pod内各容器健康检查的设置，当探测无响应几次后将自动重启该容器
      exec:       　 #对Pod容器内检查方式设置为exec方式
        command: [string]  #exec方式需要制定的命令或脚本
      httpGet:       #对Pod内个容器健康检查方法设置为HttpGet，需要制定Path、port
        path: string
        port: number
        host: string
        scheme: string
        HttpHeaders:
        - name: string
          value: string
      tcpSocket:     #对Pod内个容器健康检查方式设置为tcpSocket方式
         port: number
       initialDelaySeconds: 0       #容器启动完成后首次探测的时间，单位为秒
       timeoutSeconds: 0    　　    #对容器健康检查探测等待响应的超时时间，单位秒，默认1秒
       periodSeconds: 0     　　    #对容器监控检查的定期探测时间设置，单位秒，默认10秒一次
       successThreshold: 0
       failureThreshold: 0
       securityContext:
         privileged: false
  restartPolicy: [Always | Never | OnFailure]  #Pod的重启策略
  nodeName: <string> #设置NodeName表示将该Pod调度到指定到名称的node节点上
  nodeSelector: obeject #设置NodeSelector表示将该Pod调度到包含这个label的node上
  imagePullSecrets: #Pull镜像时使用的secret名称，以key：secretkey格式指定
  - name: string
  hostNetwork: false   #是否使用主机网络模式，默认为false，如果设置为true，表示使用宿主机网络
  volumes:   #在该pod上定义共享存储卷列表
  - name: string    #共享存储卷名称 （volumes类型有很多种）
    emptyDir: {}       #类型为emtyDir的存储卷，与Pod同生命周期的一个临时目录。为空值
    hostPath: string   #类型为hostPath的存储卷，表示挂载Pod所在宿主机的目录
      path: string      　　        #Pod所在宿主机的目录，将被用于同期中mount的目录
    secret:       　　　#类型为secret的存储卷，挂载集群与定义的secret对象到容器内部
      scretname: string  
      items:     
      - key: string
        path: string
    configMap:         #类型为configMap的存储卷，挂载预定义的configMap对象到容器内部
      name: string
      items:
      - key: string
        path: string
```

## Pod的生命周期

- Pod生命周期中会出现的5种状态：

  - Pending：API Server已经创建了Pod，但它尚未被调度完成或者仍处于下载镜像的过程中。
  - Running：Pod已经被调度到了某节点，且所有容器都已经被kubelet创建完成
  - Successed：Pod中所有容器都已经成功终止并且不会被重启
  - Failed：所有容器都已终止，但至少有一个容器终止失败，即容器返回了非0值的退出状态。
  - Unknown：API Server无法正常获取到Pod对象的状态，通常由于网络通信失败导致。

- Pod创建过程：

  - 用户通过kubectl或其他的api客户端提交需要创建的Pod信息给API Server。
  - **API Server**开始生成Pod对象的信息，并将信息存入**etcd**，然后返回确认信息至客户端。
  - API Server开始反映etcd中Pod对象的变化，其他组件使用watch机制来跟踪检测API Server上的变动。
  - **Schduler**发现有新的Pod对象要被创建，开始为Pod分配主机并将结果信息更新至API Server。
  - **Node**节点上的kubelet发现有Pod调度过来，尝试调度Docker启动容器，并将结果回传到API Server。
  - API Server将接收到的Pod状态信息存入etcd。

- Pod终止过程：

  - 用户向API Server发送删除Pod对象的命令。
  - API Server中的Pod对象信息会随着时间的推移而更新，在宽限期（30s）内，Pod被视为dead。API Server将Pod状态标记为**terminating**状态。
  - kubelet在监控到Pod对象转为terminating状态的同时，启动Pod关闭进程。
  - 端点控制器监控到Pod对象的关闭行为时，将其从所有匹配到此端点的Service资源的端点列表中移除。
  - 如果当前Pod对象定义了preStop钩子处理器，则在其标记为terminating后会以同步的方式启动执行。
  - Pod对象中的容器进程收到停止信号。
  - 宽限期结束后，如果Pod中还存在运行的进程，那么Pod对象会收到立即终止的信号。
  - kubectl请求API Server将此Pod资源的宽限期设置为0从而完成删除操作，此时Pod对于用户已经不可用了。

- 初始化容器

  - 要先于应用容器串行启动并运行完成

  - 必须按照定义的顺序执行，当且仅当前一个成功之后，后面的一个才能运行。

  - ```
     initContainers: # 初始化容器配置
        - name: test-mysql
          image: busybox:1.30
          command: ["sh","-c","until ping 192.168.18.103 -c 1;do echo waiting for mysql ...;sleep 2;done;"]
          securityContext:
            privileged: true # 使用特权模式运行容器
        - name: test-redis
          image: busybox:1.30
          command: ["sh","-c","until ping 192.168.18.104 -c 1;do echo waiting for redis ...;sleep 2;done;"]
    ```

- 钩子函数

  - 在主容器启动之后和停止之前提供了两个钩子函数：postStart、preStop

  - ```
    # exec 在容器内执行命令
    …… 
        lifecycle: # 生命周期配置
          postStart: # 容器创建之后执行，如果失败会重启容器
            exec: # 在容器启动的时候，执行一条命令，修改掉Nginx的首页内容
              command: ["/bin/sh","-c","echo postStart ... > /usr/share/nginx/html/index.html"]
          preStop: # 容器终止之前执行，执行完成之后容器将成功终止，在其完成之前会阻塞删除容器的操作
            exec: # 在容器停止之前停止Nginx的服务
              command: ["/usr/sbin/nginx","-s","quit"]
    ……
                
                
    # topSocket 在当前容器尝试访问指定的socket
    …… 
       lifecycle:
          postStart:
             tcpSocket:
                port: 8080
    ……
                
                
    # httpGet 在当前容器中向某url发起http请求
    …… 
       lifecycle:
          postStart:
             httpGet:
                path: / #URI地址
                port: 80 #端口号
                host: 192.168.109.100 #主机地址  
                scheme: HTTP #支持的协议，http或者https
    ……
    ```

- 容器探测

  - `liveness probes`：存活性探测，检测应用实例是否处于正常运行状态，如果不正常，k8s会重启容器。

  - `readiness probes`：就绪性探测，用于检测应用实例是否可以接受请求，如果不能，k8s不会转发流量。

  - ```
    # exec 	如果命令执行的退出码为0，程序正常
    ……
      livenessProbe:
         exec:
            command:
              -	cat
              -	/tmp/healthy
    ……
    
    # tcpSocket 如果能建立连接，程序正常
    ……
       livenessProbe:
          tcpSocket:
             port: 8080
    ……
    
    # httpGet 如果返回状态码在200和399之间，程序正常
    ……
       livenessProbe:
          httpGet:
             path: / #URI地址
             port: 80 #端口号
             host: 127.0.0.1 #主机地址
             scheme: HTTP #支持的协议，http或者https
    ……
    
    initialDelaySeconds # 容器启动后等待多少秒执行第一次探测
    timeoutSeconds      # 探测超时时间。默认1秒，最小1秒
    periodSeconds       # 执行探测的频率。默认是10秒，最小1秒
    failureThreshold    # 连续探测失败多少次才被认定为失败。默认是3。最小值是1
    successThreshold    # 连续探测成功多少次才被认定为成功。默认是1
    ```

## Pod的调度

- k8s四大类调度方法

  - 自动调度：运行在哪个Node节点上完全由Scheduler经过一系列算法计算出
  - 定向调度：NodeName、NodeSelector
  - 亲和性调度：Node Affinity、PodAffinity、PodAnti Affinity
  - 污点（容忍）调度：Taints、Toleration

- 定向调度

  - 利用在Pod上声明的`nodeName`或`nodeSelector`，以此将Pod调度到期望的Node节点上。这里的调度是强制的，这就意味着即使要调度的目标Node不存在，也会向上面进行调度，只不过Pod运行失败而已。

  - nodeName用于强制约束将Pod调度到指定的name的Node节点上。这种方式，其实是直接跳过Scheduler的调度逻辑，直接将Pod调度到指定名称的节点。

  - nodeSelector用于将Pod调度到添加了指定标签的Node节点上，它是通过kubernetes的label-selector机制实现的，换言之，在Pod创建之前，会由Scheduler使用MatchNodeSelector调度策略进行label匹配，找出目标node，然后将Pod调度到目标节点，该匹配规则是强制约束。

    ```
    # 给node添加标签
    kubectl label node k8s-node1 <nodeenv>=<pro>
    
    # yaml
      nodeSelector:
        nodeenv: pro # 指定调度到具有nodeenv=pro的Node节点上
    ```

- 亲和性调度

  - 在nodeSelector的基础之上进行了扩展，可以通过配置的形式，实现优先选择满足条件的Node进行调度，如果没有，也可以调度到不满足条件的节点上，使得调度更加灵活。

  - Affinity主要分为三类：

    - nodeAffinity（node亲和性）：以Node为目标，解决Pod可以调度到那些Node的问题。
    - podAffinity（pod亲和性）：以Pod为目标，解决Pod可以和那些已存在的Pod部署在同一个拓扑域中的问题。
    - podAntiAffinity（pod反亲和性）：以Pod为目标，解决Pod不能和那些已经存在的Pod部署在同一拓扑域中的问题。

  - >关于亲和性和反亲和性的使用场景的说明：
    >
    >- 亲和性：如果两个应用频繁交互，那么就有必要利用亲和性让两个应用尽可能的靠近，这样可以较少因网络通信而带来的性能损耗。
    >
    >- 反亲和性：当应用采用多副本部署的时候，那么就有必要利用反亲和性让各个应用实例打散分布在各个Node上，这样可以提高服务的高可用性。

  - node亲和性

    ```
    # requiredDuringSchedulingIgnoredDuringExecution 硬限制：Node必须满足的规则
    # preferredDuringSchedulingIgnoredDuringExecution 软限制：优先调度到满足指定规则的Node
    
    affinity: # 亲和性配置
        nodeAffinity: # node亲和性配置
          requiredDuringSchedulingIgnoredDuringExecution: # Node节点必须满足指定的所有规则才可以，相当于硬规则，类似于定向调度
            nodeSelectorTerms: # 节点选择列表
              - matchExpressions:
                  - key: nodeenv # 匹配存在标签的key为nodeenv的节点，并且value是"xxx"或"yyy"的节点
                    operator: In # 关系符 支持In, NotIn, Exists, DoesNotExist, Gt, Lt
                    values:
                      - "xxx"
                      - "yyy"
                      
                      
                      
    affinity: # 亲和性配置
      nodeAffinity: # node亲和性配置
        preferredDuringSchedulingIgnoredDuringExecution: # 优先调度到满足指定的规则的Node，相当于软限制 (倾向)
          - preference: # 一个节点选择器项，与相应的权重相关联
              matchExpressions:
                - key: nodeenv
                  operator: In
                  values:
                    - "xxx"
                    - "yyy"
            weight: 1
    ```

    nodeAffinity的注意事项：

    - 如果同时定义了nodeSelector和nodeAffinity，那么必须两个条件都满足，Pod才能运行在指定的Node上。

    - 如果nodeAffinity指定了多个nodeSelectorTerms，那么只需要其中一个能够匹配成功即可。

    - 如果一个nodeSelectorTerms中有多个matchExpressions，则一个节点必须满足所有的才能匹配成功。

    - 如果一个Pod所在的Node在Pod运行期间其标签发生了改变，不再符合该Pod的nodeAffinity的要求，则系统将忽略此变化。

  - pod亲和性

    - topologyKey用于指定调度的作用域，例如:

      - 如果指定为kubernetes.io/hostname，那就是以Node节点为区分范围。

      - 如果指定为beta.kubernetes.io/os，则以Node节点的操作系统类型来区分。

    ```
    pod.spec.affinity.podAffinity
      requiredDuringSchedulingIgnoredDuringExecution  硬限制
        namespaces 指定参照pod的namespace
        topologyKey 指定调度作用域。例如 kubernetes.io/hostname，以Node节点为区分范围。
        labelSelector 标签选择器
          matchExpressions  按节点标签列出的节点选择器要求列表(推荐)
            key    键
            values 值
            operator 关系符 支持In, NotIn, Exists, DoesNotExist.
          matchLabels    指多个matchExpressions映射的内容  
      preferredDuringSchedulingIgnoredDuringExecution 软限制    
        podAffinityTerm  选项
          namespaces
          topologyKey
          labelSelector
             matchExpressions 
                key    键  
                values 值  
                operator
             matchLabels 
        weight 倾向权重，在范围1-1
    ```

  - pod反亲和性

    - 以运行的pod为参照，让新创建的Pod和参照的Pod不在一个区域
  
  - 配置方式和podAffinity一样
  
- 污点

  - 前面的调度方式都是站在Pod的角度上，通过在Pod上添加属性，来确定Pod是否要调度到指定的Node上，其实我们也可以站在Node的角度上，通过在Node上添加`污点属性`，来决定是否运行Pod调度过来。
  - Node被设置了污点之后就和Pod之间存在了一种相斥的关系，进而拒绝Pod调度进来，甚至可以将已经存在的Pod驱逐出去。
  - 污点的格式为：`<key>=<value>:<effect>`，key和value是污点的标签，effect描述污点的作用，支持如下三个选项：

    - `PreferNoSchedule`：尽量避免把Pod调度到具有该污点的Node上，除非没有其他节点可以调度。

    - `NoSchedule`：不会把Pod调度到具有该污点的Node上，但是不会影响当前Node上已经存在的Pod。

    - `NoExecute`：不会把Pod调度到具有该污点的Node上，同时也会将Node上已经存在的Pod驱逐。

  - ```
    # 设置污点
    kubectl taint node xxx key=value:effect
    
    # 去除污点
    kubectl taint node xxx key:effect-
    
    # 去除所有污点
    kubectl taint node xxx key-
    
    # 查询所有节点的污点
    wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x ./jq
    cp jq /usr/bin
    
    kubectl get nodes -o json | jq '.items[].spec'
    kubectl get nodes -o json | jq '.items[].spec.taints'
    
    # 查看指定节点上的污点
    kubectl describe node 节点名称
    ```

- 容忍

  - 让一个Pod调度到一个有污点的Node上去。Node通过污点拒绝Pod调度上去，Pod通过容忍忽略拒绝。

  - ```
    kubectl explain pod.spec.tolerations
    ......
    FIELDS:
      key       # 对应着要容忍的污点的键，空意味着匹配所有的键
      value     # 对应着要容忍的污点的值
      operator  # key-value的运算符，支持Equal和Exists（默认）
      effect    # 对应污点的effect，空意味着匹配所有影响
      tolerationSeconds   # 容忍时间, 当effect为NoExecute时生效，表示pod在Node上的停留时间
    ```

  - 如果operator为Equal，如果Node节点有多个Taint，那么Pod每个Taint都要容忍才能部署上去。

  - 如果operator为Exists，有三种写法

    - ```
      # 容忍指定的污点，污点带有指定的effect
       tolerations: # 容忍
          - key: "tag" # 要容忍的污点的key
            operator: Exists # 操作符
            effect: NoExecute # 添加容忍的规则，这里必须和标记的污点规则相同
            
      # 容忍指定的污点，不考虑具体的effect
        tolerations: # 容忍
          - key: "tag" # 要容忍的污点的key
            operator: Exists # 操作符
            
      # 容忍一切污点
        tolerations: # 容忍
          - operator: Exists # 操作符
      ```





## 临时容器

- 作用

  - 容器崩溃，容器镜像不包含shell或其他调试工具，导致无法使用`kubectl exec`命令时，临时容器可以交互式排查故障
  - 使用临时容器的时候，启用[进程名字空间共享](https://kubernetes.io/zh/docs/tasks/configure-pod-container/share-process-namespace/) 很有帮助，可以查看其他容器中的进程。

- 配置

  - ```
    # 查看临时容器是否开启
    kubelet -h | grep EphemeralContainers
    
    # 在每个节点（不管Master节点还是Node节点）修改kubectl的参数
    vim /etc/sysconfig/kubelet
    # 修改增加--feature-gates EphemeralContainers=true
    KUBELET_EXTRA_ARGS="--cgroup-driver=systemd --feature-gates EphemeralContainers=true"
    KUBE_PROXY_MODE="ipvs"
    
    vim /var/lib/kubelet/config.yaml
    # 在末位追加
    featureGates:
      EphemeralContainers: true
      
    # 加载配置文件，重启kubelet
    systemctl daemon-reload
    systemctl stop kubelet
    systemctl start kubelet
    systemctl status kubelet
    
    # 在Master节点修改kube-apiserver.yaml和kube-scheduler.yaml：
    vim /etc/kubernetes/manifests/kube-apiserver.yaml
    # 在spec.containers.command追加
    - --feature-gates=EphemeralContainers=true
    
    vim /etc/kubernetes/manifests/kube-scheduler.yaml
    # 在spec.containers.command追加
    - --feature-gates=EphemeralContainers=true
    ```

- 创建临时容器（重新写）

  - ```
    # 部署一个nginx pod
    vim nginx.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx
    spec:
      shareProcessNamespace: true # 这个配置非常重要，一定要配置
      containers:
      - name: nginx
        image: nginx:1.17.1
       
    kubectl apply -f nginx.yaml
    
    # 创建ec.json
    {
        "apiVersion": "v1",
        "kind": "EphemeralContainers",
        "metadata": {
                # pod name
                "name": "nginx"
        },
        "ephemeralContainers": [{
            "command": [
                "sh"
            ],
            "image": "busybox",
            "imagePullPolicy": "IfNotPresent",
            "name": "debugger",
            "stdin": true,
            "tty": true,
            "terminationMessagePolicy": "File"
        }]
    }
    
    # 更新已运行的容器
    kubectl replace --raw /api/v1/namespaces/default/pods/nginx/ephemeralcontainers  -f ec.json
    ```

## 服务质量QoS

- k8s创建Pod时会指定QoS，Qos分为3类
  - Guaranted
    - Pod中每个容器必须指定内存requests和内存limits，并且两者相等
    - Pod中每个容器必须指定CPUrequests和CPUlimits，并且两者相等
  - Burstable
    - Pod不符合Guaranteed QoS类的标准
    - Pod中至少一个容器具有内存或CPUrequests，但值不想等
  - BestEffort
    - Pod中容器必须没设置内存和CPU的requests和limits。
- QoS作用
  - 一旦出现OOM，kubernetes为了保证服务的可用，会先删除QoS为BestEffort的Pod，然后删除QoS为Burstable的Pod，最后删除QoS为Guaranteed 的Pod。

# Pod控制器

- ReplicationController：比较原始的Pod控制器，已经被废弃，由ReplicaSet替代。

- ReplicaSet：保证指定数量的Pod运行，并支持Pod数量变更，镜像版本变更。

- Deployment：通过控制ReplicaSet来控制Pod，并支持滚动升级、版本回退。

- Horizontal Pod Autoscaler：可以根据集群负载自动调整Pod的数量，实现削峰填谷。

- DaemonSet：在集群中的指定Node上都运行一个副本，一般用于守护进程类的任务。

- Job：它创建出来的Pod只要完成任务就立即退出，用于执行一次性任务。

- CronJob：它创建的Pod会周期性的执行，用于执行周期性的任务。

- StatefulSet：管理有状态的应用。

## ReplicaSet（RS）

- 保证指定数量的Pod正常运行，RS会持续监听Pod的状态，一旦Pod发生故障，就会重启。

- 资源清单

  - ```
    apiVersion: apps/v1 # 版本号 
    kind: ReplicaSet # 类型 
    metadata: # 元数据 
      name: # rs名称
      namespace: dev# 所属命名空间 
      labels: #标签 
        controller: rs 
    spec: # 详情描述 
      replicas: 3 # 副本数量 
      selector: # 选择器，通过它指定该控制器管理哪些pod
        matchLabels: # Labels匹配规则 
          app: nginx-pod 
        matchExpressions: # Expressions匹配规则 
          - {key: app, operator: In, values: [nginx-pod]} 
    template: # 模板，当副本数量不足时，会根据下面的模板创建pod副本 
      metadata: 
        labels: 
          app: nginx-pod 
      spec: 
        containers: 
          - name: nginx 
            image: nginx:1.17.1 
            ports: 
            - containerPort: 80
    ```

- 创建/查看/删除

  - ```
    # 创建rs
    kubectl create -f pc-replicaset.yaml
    
    # 查看rs
    kubectl get rs pc-replicaset -n dev -o wide
    NAME            DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES         SELECTOR
    pc-replicaset   3         3         3       27s   nginx        nginx:1.17.1   app=nginx-pod    
    # DESIRED：期望的副本数
    # CURRENT：当前的副本数
    # READY：已经准备好提供的副本数
    
    # 查看当前控制器创建出的pod
    kubectl get pod -n dev
    
    # 删除rs和它管理的pod
    kubectl delete rs pc-replicaset -n dev
    
    # yaml删除
    kubectl delete -f pc-replicaset.yaml
    ```

- 扩缩容

  - ```
    # 修改rs副本数量
    kubectl edit rs pc-replicaset -n dev
    # 修改spec:replicas:6
    
    # 使用scale实现阔缩容
    kubectl scale rs pc-replicaset --replicas=<2> -n dev
    ```

- 镜像升级

  - ```
    # 修改容器镜像
    kubectl edit rs pc-replicaset -n dev
    spec:containers:image为nginx:1.17.2
    
    # 镜像升级
    kubectl set image rs <pc-replicaset> <nginx>=<nginx:1.17.1> -n dev
    ```

## Deployment（Deploy）

- Deployment控制器并不直接管理Pod，而是通过管理ReplicaSet来间接管理Pod，即：Deployment管理ReplicaSet，ReplicaSet管理Pod。所以Deployment的功能比ReplicaSet强大。

- 资源清单

  - ```
    apiVersion: apps/v1 # 版本号 
    kind: Deployment # 类型 
    metadata: # 元数据 
      name: # rs名称 
      namespace: # 所属命名空间 
      labels: #标签 
        controller: deploy 
    spec: # 详情描述 
      replicas: 3 # 副本数量 
      revisionHistoryLimit: 3 # 保留历史版本，默认为10 
      paused: false # 暂停部署，默认是false 
      progressDeadlineSeconds: 600 # 部署超时时间（s），默认是600 
      strategy: # 策略 
        type: RollingUpdate # 滚动更新策略 
        rollingUpdate: # 滚动更新 
          maxSurge: 30% # 最大额外可以存在的副本数，可以为百分比，也可以为整数 maxUnavailable: 30% # 最大不可用状态的    Pod 的最大值，可以为百分比，也可以为整数 
      selector: # 选择器，通过它指定该控制器管理哪些pod 
        matchLabels: # Labels匹配规则 
          app: nginx-pod 
        matchExpressions: # Expressions匹配规则 
          - {key: app, operator: In, values: [nginx-pod]} 
      template: # 模板，当副本数量不足时，会根据下面的模板创建pod副本 
        metadata: 
          labels: 
            app: nginx-pod 
        spec: 
          containers: 
          - name: nginx 
            image: nginx:1.17.1 
            ports: 
            - containerPort: 80
    ```

- 更新原理

  - 仅当deployment的Pod模版（spec.templeate）发送变化时，才会触发Deployment上线，其他更新（如扩缩容）不会触发上线操作。
  - 上线动作：创建新的ReplicaSet，准备就绪后，替换旧的ReplicaSet（此时不会删除，因为`revisionHistoryLimit: 3`指定了保留三个版本。

- 创建/查看/删除

  - ```
    # 创建名为nginx的deployment
    kubectl create deployment nginx --image=nginx:1.17.1 -n test
    kubectl create deploy nginx --image=nginx:1.17.1 -n test
    kubectl apply -f k8s-deploy.yaml
    
    # 根据名为nginx的deployment创建4个Pod
    kubectl scale deployment nginx --replicas=<4> -n test
    
    # 查看dev ns下的deployment
    kubectl get deployment -n dev
    
    # 查看dev ns下名为nginx的deployment详细信息
    kubectl describe deployment <nginx> -n dev
    
    # 删除deployment
    kubectl delete deployment <nginx> -n dev
    kubectl delete -f k8s-deploy.yaml
    ```

- 扩缩容

  - ```
    # 使用edit，修改spec:replicas:n
    kubectl edit deployment nginx-deployment
    
    # 使用scale
    kubectl scale deploy nginx-deployment --replicas=<3>
    
    # 修改yaml配置文件，重启apply
    vim k8s-deploy.yaml
    ...
    spec: # 规格，期望状态，必须字段
      replicas: 2 # 副本数
    ...
    kubectl apply -f k8s-deploy.yaml
    ```

- 镜像升级

  - Deployment支持两种镜像更新策略，重建更新和滚动更新，通过`strategy`配置。

  - deployment默认滚动更新，可以直接使用默认值。

  - 重建更新Recreate

    - ```
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: nginx
        revisionHistoryLimit: 15 # 旧副本集保留的数量，即可回滚的数量。默认为 10 。
        progressDeadlineSeconds: 600 # 处理的最终期限，如果超过了这个指定的时间就会给集群汇报错误。默认为 600s 。
        paused: false # 暂停更新，默认为 false 。
        strategy: # 更新策略
          type: Recreate # Recreate：在创建出新的Pod之前会先杀掉所有已经存在的Pod
        template:
          metadata:
            name: nginx
            labels:
              app: nginx
          spec:
            containers:
              - name: nginx
                image: nginx:1.17.1
                imagePullPolicy: IfNotPresent
            restartPolicy: Always
            
      # set image 更新镜像
      kubectl set image deployment nginx-deployment nginx=nginx:1.20.2
      
      # 修改配置文件 更新镜像
      spec.template.spec.image
      ```

  - 滚动更新RollingUpdate

    - ```
      spec:
        replicas: 6
        selector:
          matchLabels:
            app: nginx
        revisionHistoryLimit: 15 # 旧副本集保留的数量，即可回滚的数量。默认为 10 。
        progressDeadlineSeconds: 600 # 处理的最终期限，如果超过了这个指定的时间就会给集群汇报错误。默认为 600s 。
        paused: false # 暂停更新，默认为 false 。
        strategy: # 更新策略
          type: RollingUpdate # 滚动更新
          rollingUpdate:
            maxSurge: 25% # 最大增量：一次最多新建几个 Pod，可以写数字或百分比，maxUnavailable 为 0 的时候，maxSurge 不能为 0 。
            maxUnavailable: 25% # 最大不可用量：最大不可用的 Pod，可以写数字或百分比
        template:
          metadata:
            name: nginx
            labels:
              app: nginx
          spec:
            containers:
              - name: nginx
                image: nginx:1.17.1
                imagePullPolicy: IfNotPresent
            restartPolicy: Always
            
      # set image 更新镜像
      kubectl set image deployment nginx-deployment nginx=nginx:1.20.2
      
      # 修改配置文件 更新镜像
      spec.template.spec.image
      ```

- 版本回退

  - ```
     kubetl rollout 参数 deploy xx  # 支持下面的选择
    # status 显示当前升级的状态
    # history 显示升级历史记录
    # pause 暂停版本升级过程
    # resume 继续已经暂停的版本升级过程
    # restart 重启版本升级过程
    # undo 回滚到上一级版本 （可以使用--to-revision回滚到指定的版本）
    
    # 查看版本升级历史记录
    kubectl rollout history deployment nginx-deployment
    
    # 可以使用-to-revision=1回退到1版本，如果省略这个选项，就是回退到上个版本，即2版本
    kubectl rollout undo deployment nginx-deployment --to-revision=1
    kubectl rollout undo deployment nginx-deployment
    ```

- 金丝雀发布
  - 作用：优化滚动更新，控制老版本的存活时间
  - 流程
    - 将 service 的标签设置为 app=nginx ，这就意味着集群中的所有标签是 app=nginx 的 Pod 都会加入负载均衡网络。
    - 使用 Deployment v=v1 app=nginx 去筛选标签是 app=nginx 以及 v=v1 的 所有 Pod。
    - 同理，使用 Deployment v=v2 app=nginx 去筛选标签是 app=nginx 以及 v=v2 的所有 Pod 。
    - 逐渐加大 Deployment v=v2 app=nginx 控制的 Pod 的数量，根据轮询负载均衡网络的特点，必定会使得此 Deployment 控制的 Pod 的流量增大。
    - 当测试完成后，删除 Deployment v=v1 app=nginx 即可。

## Horizontal Pod Autoscaler（HPA）

- 适用场景：通过Pod的使用情况，自动扩缩容。

- 原理：HPA基于Deployment，HPA可以获取每个Pod的利用率，然后和HPA中定义的指标对比，计算出需要伸缩的具体值，实现Pod数量调整。

- 安装metrics-server

  - ```
    # 下载 components.yaml
    
    # 安装
    $ kubectl apply -f components.yaml
    
    # 查看安装是否成功
    $ kubectl top nodes --use-protocol-buffers
    NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
    k8s-master   191m         2%     5089Mi          21%
    
    $ kubectl top pods --use-protocol-buffers
    NAME                                CPU(cores)   MEMORY(bytes)
    nginx-deployment-76f9ff7485-crm8p   0m           2Mi
    ```

- HPA监控CPU使用率

  - ```
    # 创建 Deployment 和 Service 
    # 创建HPA
    vim k8s-hpa.yaml
    apiVersion: autoscaling/v1
    kind: HorizontalPodAutoscaler
    metadata:
      name: k8s-hpa
    spec:
      minReplicas: 1 # 最小 Pod 数量
      maxReplicas: 10 # 最大 Pod 数量
      targetCPUUtilizationPercentage: 3 # CPU 使用率指标，即 CPU 超过 3%（Pod 的 limit 的 cpu ） 就进行扩容
      scaleTargetRef:  # 指定要控制的Nginx的信息
        apiVersion: apps/v1
        kind: Deployment
        name: nginx-deploy
        
    # 测试
    kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://192.168.65.100:30010; done"
    ```

- HPA还可以监控内存，目前是bate版



## DeamonSet（DS）

- 适用场景：每个节点都需要一个Pod，这类pod适合用DeamonSet创建。

  - 在每个节点上运行集群的存储守护进程，如glusterd、ceph
  - 在每个节点上运行日志收集守护进程，如fluentd、logstash
  - 在每个节点上运行监控守护进程，如Prometheus Node Exporter

- DaemonSet控制器的特点：
  - 每向集群中添加一个节点的时候，指定的Pod副本也将添加到该节点上。
  - 当节点从集群中移除的时候，Pod也会被垃圾回收。

- DaemonSet的资源清单：

  - ```
    apiVersion: apps/v1 # 版本号
    kind: DaemonSet # 类型
    metadata: # 元数据
      name: # 名称
      namespace: #命名空间
      labels: #标签
        controller: daemonset
    spec: # 详情描述
      revisionHistoryLimit: 3 # 保留历史版本
      updateStrategy: # 更新策略
        type: RollingUpdate # 滚动更新策略
        rollingUpdate: # 滚动更新
          maxUnavailable: 1 # 最大不可用状态的Pod的最大值，可用为百分比，也可以为整数
      selector: # 选择器，通过它指定该控制器管理那些Pod
        matchLabels: # Labels匹配规则
          app: nginx-pod
        matchExpressions: # Expressions匹配规则
          - key: app
            operator: In
            values:
              - nginx-pod
      template: # 模板，当副本数量不足时，会根据下面的模板创建Pod模板
         metadata:
           labels:
             app: nginx-pod
         spec:
           containers:
             - name: nginx
               image: nginx:1.17.1
               ports:
                 - containerPort: 80
    ```

- 创建/查看/删除

  - ```
    # 创建
    vim k8s-ds.yaml
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: ds
      namespace: default
      labels:
        app: ds
    spec:
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          # tolerations: # 污点，后面讲
          # - key: node-role.kubernetes.io/master
          #   effect: NoSchedule
          containers:
          - name: nginx
            image: nginx:1.20.2
            resources:
              limits:
                memory: 200Mi
              requests:
                cpu: 100m
                memory: 200Mi
            volumeMounts:
            - name: localtime
              mountPath: /etc/localtime
          terminationGracePeriodSeconds: 30
          volumes:
          - name: localtime
            hostPath:
              path: /usr/share/zoneinfo/Asia/Shanghai
    kubectl apply -f k8s-ds.yaml
    
    # 查看
    kubectl get ds -n dev -o wide
    
    # 删除
    kubectl delete -f k8s-ds.yaml
    ```


## Stateful

- 无状态应用：

  - 认为Pod都是一样的
  - 没有启动顺序要求
  - 不用考虑在哪个Node节点上运行
  - 随意扩缩容
  - 比如：业务组件

- 有状态应用：

  -  认为每个Pod不一样
  - 有启动顺序要求
  - 需要考虑在哪个Node上运行
  - 需要按顺序进行扩缩容
  - 比如：RabbitMQ集群，Zookepper集群，MySQL集群，Eureka集群等

- 使用场景

  - 稳定，唯一的网络标识。需要使用无头服务（HeadLinessService）。因为Deployment部署时，每个pod名称是没有顺序的，是随机字符串，但是在StatefulSet中必须是有序，并且Pod重建后的名称也不能变化。Pod名称是Pod唯一的标识符，所以使用无头服务，可以给每个Pod一个唯一名称。
  - 稳定的存储：每个 Pod 始终对应各自的存储路径（PersistantVolumeClaimTemplate）。
  - 有序的部署和缩放：按顺序地增加副本、减少副本，并在减少副本时执行清理。
  - 有序、自动地滚动更新：按顺序自动执行滚动更新。

- 限制：

  - 当删除 StatefulSets 时，StatefulSet 不提供任何终止 Pod 的保证。 为了实现 StatefulSet 中的 Pod 可以有序地且体面地终止，可以在删除之前将 StatefulSet 缩放为 0。

- 部署/查看/使用/删除

  - ```
    # 部署
    kubectl apply -f k8s-sts.yaml
    
    # 查看
    kubectl get statefulset pc-statefulset -n dev -o wide
    
    # 创建pod，在pod中访问sts创建的Pod及无头服务
    kubectl run -it test --image=nginx /bin/sh
    curl stateful-nginx-0.nginx-svc
    curl nginx-svc
    
    # 删除
    kubectl delete -f k8s-sts.yaml
    ```

- 管理策略

  - `podManagementPolicy`：OrderedReady（有序启动，默认值），Parallel（并发启动）

- 更新策略

  - `updateStrategy`：OnDelete（删除之后更新），RollingUpdate（滚动更新，还需要设置更新索引）

  - ```
    ...
    spec:
      updateStrategy: # 更新策略
        type: RollingUpdate # OnDelete 删除之后才更新；RollingUpdate 滚动更新
        rollingUpdate:
          partition: 0 # 更新索引 >= partition 的 Pod ，默认为 0
    ...
    ```

## Job

- 适用场景：批量处理一次性任务，Pod运行完就停止的镜像

- 特定：

  - 当Job创建的Pod执行成功结束时，Job将记录成功执行的Pod数量
  - 当成功结束的Pod达到指定的数量时，Job执行完成。

- 资源清单

  - 重启策略（restartPolicy）：

    - OnFailure：Job会在pod出现故障时重启容器，而不创建Pod，failed次数不变
    - Never：Job会在pod出现故障时创建新pod，但故障pod不会消失也不会重启，failed次数+1

  - ```yaml
    apiVersion: batch/v1 # 版本号
    kind: Job # 类型
    metadata: # 元数据
      name:  # 名称
      namespace:  #命名空间
      labels: # 标签
        controller: job
    spec: # 详情描述
      completions: 1 # 指定Job需要成功运行Pod的总次数，默认为1
      parallelism: 1 # 指定Job在任一时刻应该并发运行Pod的数量，默认为1
      activeDeadlineSeconds: 30 # 指定Job可以运行的时间期限，超过时间还没结束，系统将会尝试进行终止
      backoffLimit: 6 # 指定Job失败后进行重试的次数，默认为6
      manualSelector: true # 是否可以使用selector选择器选择Pod，默认为false
      ttlSecondsAfterFinished: 0 # 如果是 0 表示执行完Job 时马上删除。如果是 100 ，就是执行完 Job ，等待 100s 后删除。TTL 机制由 TTL 控制器 提供，ttlSecondsAfterFinished 字段可激活该特性。当 TTL 控制器清理 Job 时，TTL 控制器将删除 Job 对象，以及由该 Job 创建的所 有 Pod 对象。
      selector: # 选择器，通过它指定该控制器管理那些Pod，非必须字段
        matchLabels: # Labels匹配规则
          app: counter-pod
        matchExpressions: # Expressions匹配规则
          - key: app
            operator: In
            values:
              - counter-pod
      template: # 模板，当副本数量不足时，会根据下面的模板创建Pod模板
         metadata:
           labels:
             app: counter-pod
         spec:
           restartPolicy: Never # 重启策略只能设置为Never或OnFailure
           containers:
             - name: counter
               image: busybox:1.30
               command: ["/bin/sh","-c","for i in 9 8 7 6 5 4 3 2 1;do echo $i;sleep 20;done"]
    ```

- 部署/查看/删除

  - ```
    # 创建job
    vim k8s-job.yaml
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: job-01
      labels:
        app: job-01
    spec:
      # backoffLimit: 6 # 指定 Job 失败后进行重试的次数，默认为 6 ；换言之，Job 失败 6 次后，就认为失败。
      # activeDeadlineSeconds: 30 # 指定 Job 可以运行的时间期限，超过时间还没结束，系统将会尝试进行终止。
      completions: 4 # 指定 Job 需要成功运行 Pod 的总次数，默认为 1
      template: # Pod 模板
        metadata:
          name: pod-job-test
          labels:
            app: job-01
        spec:
          containers:
          - name: alpine
            image: alpine # 坑：所有的 Job 类型的 Pod 不需要阻塞式镜像，如：nginx 等。Job 类型的 Pod 需要运行完成后就停止的镜像，如：alpine、busybox 等。
            command: ["/bin/sh","-c","for i in 9 8 7 6 5 4 3 2 1;do echo $i;done"]
          restartPolicy: Never
          
    # 部署
    kubectl apply -f k8s-job.yaml
    
    # 查看job
    kubectl get job -n dev -w
    
    # 查看pod
    kubectl get pod -n dev -w
    
    # 删除job
    kubectl delete -f k8s-job.yaml
    ```

## CronJob（CJ）

- 适用场景：CronJob基于Job，CronJob可以在特定时间反复去执行Job任务

- 资源清单

  - 并发策略（concurrencyPolicy）

    - Allow：Job并发运行
    - Forbid：禁止并发运行，如果上一次运行尚未完成，则跳过下一次运行。 
    - Replace：替换，取消当前运行的Job并使用新Job替换。

  - ```
    apiVersion: batch/v1beta1 # 版本号
    kind: CronJob # 类型
    metadata: # 元数据
      name: cronjob-test # 名称
      namespace: dev #命名空间
      labels:
        controller: cronjob
    spec: # 详情描述
      schedule: "*/1 * * * *"# cron表达式
      concurrencyPolicy: # 并发执行策略
      failedJobsHistoryLimit: # 为失败的任务执行保留的历史记录数，默认为1
      successfulJobsHistoryLimit: # 为成功的任务执行保留的历史记录数，默认为3
      jobTemplate: # job控制器模板，用于为cronjob控制器生成job对象，下面其实就是job的定义
        metadata: {}
        spec:
          completions: 1 # 指定Job需要成功运行Pod的总次数，默认为1
          parallelism: 1 # 指定Job在任一时刻应该并发运行Pod的数量，默认为1
          activeDeadlineSeconds: 30 # 指定Job可以运行的时间期限，超过时间还没结束，系统将会尝试进行终止
          backoffLimit: 6 # 指定Job失败后进行重试的次数，默认为6
          template: # 模板，当副本数量不足时，会根据下面的模板创建Pod模板
            spec:
              restartPolicy: Never # 重启策略只能设置为Never或OnFailure
              containers:
                - name: counter
                  image: busybox:1.30
                  command: [ "/bin/sh","-c","for i in 9 8 7 6 5 4 3 2 1;do echo $i;sleep 20;done" ]
    ```

- 创建/查看/删除

  - ```
    # 创建
    kubectl apply -f k8s-cronjob.yaml
    
    # 查看CrobJob
    kubectl get cronjob -n dev -w
    
    # 查看Job
    kubectl get job -n dev -w
    
    # 查看pod
    kubectl get pod -n dev -w
    
    # 删除
    kubectl delete -f k8s-cronjob.yaml
    ```

# Service

- Pod 的 IP 地址不是固定的，这就意味着不方便直接采用 Pod 的 IP 对服务进行访问，Service解决了这个问题，Service 会对提供同一个服务的多个 Pod 进行聚合（使用标签选择器），并且提供一个统一的入口地址，通过访问 Service 的入口地址就能访问到后面的 Pod 服务。 

## kube-proxy

- Service 在很多情况下只是一个概念，真正起作用的其实是 **kube-proxy** 服务进程，每个 Node 节点上都运行了一个 kube-proxy 的服务进程，当创建 Service 的时候会通过 API Server 向 etcd 写入创建的 Service 的信息，而 kube-proxy 会基于**监听**的机制发现这种 API Service 的变化，然后它会将最新的 Service 信息转换为对应的访问规则（就是 EndPoint），通过放过规则聚会Pod。

- ```
  # 10.96.0.1:443 是service提供的访问入口
  # 当访问这个入口的时候，可以发现后面有8个pod的服务在等待调用
  # kube-proxy会基于rr（轮询）的策略，将请求分发到其中一个pod上去
  # 这个规则会同时在集群内的所有节点上都生成，所以在任何一个节点上访问都可以
  # 测试ipvs模块是否开启成功
  $ ipvsadm -Ln
  IP Virtual Server version 1.2.1 (size=4096)
  Prot LocalAddress:Port Scheduler Flags
    -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
  TCP  10.96.0.1:443 rr
    -> 192.168.200.171:6443         Masq    1      7          0
  TCP  10.96.0.10:53 rr
    -> 10.244.235.193:53            Masq    1      0          0
    -> 10.244.235.194:53            Masq    1      0          0
  TCP  10.96.0.10:9153 rr
    -> 10.244.235.193:9153          Masq    1      0          0
    -> 10.244.235.194:9153          Masq    1      0          0
  TCP  10.101.54.211:443 rr
    -> 10.244.235.205:4443          Masq    1      2          0
  UDP  10.96.0.10:53 rr
    -> 10.244.235.193:53            Masq    1      0          0
    -> 10.244.235.194:53            Masq    1      0          0
  ```
  
- Kube-proxy支持的工作模式：

  - userspace模式：

    - kube-proxy为service创建端口并监听，clinet发向clusterIP的请求会被（iptables）重定向到kube-proxy上，kube-proxy会根据LB（负载均衡）算法选择一个Pod并建立连接，将请求转发到Pod上。
    - 缺点：由于kube-proxy运行在userspace中，在进行转发处理的时候会增加内核和用户空间之间的数据拷贝，虽然比较稳定，但是效率非常低下。

  - iptables模式：

    - kube-proxy为Service的每个Pod创建对应的iptables规则，直接将发向Cluster IP的请求重定向到一个Pod的IP上。
    - 缺点：不能提供灵活的LB策略，当后端Pod不可用的时候无法进行重试。

  - ipvs模式：
		- ipvs模式和iptables类似，kube-proxy监控Pod的变化并创建相应的ipvs规则。ipvs相对iptables转发效率更高，除此之外，ipvs支持更多的LB算法。



## Service类型

- Service 默认使用的协议是 TCP 协议，对应的是 OSI 网络模型中的第四层传输层，所以也有人称 Service 为四层网络负载均衡。Service  会基于 Pod 的探针机制（readinessProbe，就绪探针）完成 Pod 的自动剔除（没有就绪的 Pod）和上线工作。

- 资源清单：

  - ```
    apiVersion: v1 # 版本
    kind: Service # 类型
    metadata: # 元数据
      name: # 资源名称
      namespace: # 命名空间
    spec:
      selector: # 标签选择器，用于确定当前Service代理那些Pod
        app: nginx
      type: NodePort # Service的类型，指定Service的访问方式
      clusterIP: # 虚拟服务的IP地址
      sessionAffinity: # session亲和性，支持ClientIP、None两个选项，默认值为None
      ports: # 端口信息
        - port: 8080 # Service端口
          protocol: TCP # 协议
          targetPort : # Pod端口
          nodePort:  # 主机端口
    ```

- spec.type：

  - clusterIP（默认值）：默认值，它是kubernetes系统自动分配的虚拟IP，只能在集群内部访问。
  - NodePort：将Service通过指定的Node上的端口暴露给外部，通过此方法，就可以在集群外部访问服务。
  - LoadBalancer：使用外接负载均衡器完成到服务的负载分发，注意此模式需要外部云环境的支持。
  - ExternalName：把集群外部的服务引入集群内部，直接使用。



## ClusterIP类型的Service

- 创建Service

  - ```
    spec:
      selector:
        app: nginx
      type: ClusterIP # ClusterIP 指的是当前 Service 在 Kubernetes 集群内可以被所有 Kubernetes 资源发现，默认给这个 Service 分配一个集群内的网络。
      ports:
      - name: nginx
        port: 80 # service 的端口，访问到 service 的 80 端口
        targetPort: 80 # Pod 的端口，派发到 Pod 的 80 端口
    ```

- 查看service信息

  - ```
    # 查看service信息
    kubectl describe svc <cluster-ip-svc>
    
    kubectl get svc,deploy,pod -o wide
    ```

- Endpoint（记录一个Service对应的全部Pod访问地址）

  - ```
    kubectl get endpoint
    kubectl get ep
    
    # 自定义endpoint
    apiVersion: v1
    kind: Service
    metadata:
      name: cluster-svc-no-selector
      namespace: default
    spec:
      ports:
        - name: http
          port: 80
          targetPort: 80 # 此时的 targetPort 需要和 Endpoints 的 subsets.addresses.ports.port 相同  
    ---
    apiVersion: v1
    kind: Endpoints
    metadata:
      name: cluster-svc-no-selector # 此处的 name 需要和 Service 的 metadata 的 name 相同
      namespace: default
    subsets:
    - addresses:
      - ip: 220.181.38.251 # 百度
      - ip: 221.122.82.30 # 搜狗 
      - ip: 61.129.7.47 # QQ
      ports:
      - name: http # 此处的 name 需要和 Service 的 spec.ports.name 相同
        port: 80
        protocol: TCP
    ```

- 会话保持技术

  - 在 spec 中添加 `sessionAffinity: ClientIP` 选项。 

  - ```
    apiVersion: v1
    kind: Service
    metadata:
      name: k8s-session-affinity-svc
      namespace: default
    spec:
      selector:
        app: nginx
      type: ClusterIP 
      sessionAffinity: "ClientIP"
      sessionAffinityConfig:
        clientIP: 
           timeoutSeconds: 11800 # 30 分钟
      ports:
      - name: nginx
        protocol: TCP
        port: 80 
        targetPort: 80
    ```

## HandLiness IP类型的Service

- ```
  ...
  spec:
    type: ClusterIP # ClusterIP 指的是当前 Service 在集群内可以被所有人发现，默认给这个 Service 分配一个集群内的网络。
    clusterIp: None # k8s 不要给这个 service 分配 IP，headless service 无头服务配合 StatefulSet
  ...
  ```

## NodePort类型的Service

- 将Service的端口映射到Node的一个端口上，就可以在集群外部，通过个`NodeIP:NodePort`来访问Service。

- ```
  spec:
    ...
    type: NodePort # 每台机器都会为这个 service 随机分配一个指定的端口
    ports:
    - name: nginx
      protocol: TCP
      port: 80 # service 的端口，访问到 service 的 80 端口
      targetPort: 80 # Pod 的端口，派发到 Pod 的 80 端口
      nodePort: 31111 # 不指定，默认会在 30000 ~ 32767 范围内随机分配，集群中的所有机器都会打开这个端口，访问 K8s 集群中的任意一条机器都可以访问 Service 代理的 Pod 。
  ```

## LoadBalancer类型的Service

- 需要在集群外部部署一个负载均衡设备

- ```
  spec:
    ...  
    type: LoadBalancer # 负载均衡，开放给云平台实现的，阿里云、百度云等。
    ports:
    - name: nginx
      protocol: TCP
      port: 80 # service 的端口，访问到 service 的 80 端口
      targetPort: 80 # Pod 的端口，派发到 Pod 的 80 端口
      nodePort: 31111
  ```

## ExternalName类型的Service

- 引入外部服务，通过 externalName 属性指定一个服务的地址，然后在集群内部访问此 Service 就可以访问到外部的服务了。

- ```
  spec:
    type: ExternalName
    externalName: www.baidu.com # 其他的Pod可以通过访问这个service而访问其他的域名服务，但是需要注意目标服务的跨域问题。
  ```

# Ingress

- 我们已经知道，Service对集群之外暴露服务的主要方式有两种：NodePort和LoadBalancer，但是这两种方式，都有一定的缺点：

- - NodePort方式的缺点是会占用很多集群机器的端口，那么当集群服务变多的时候，这个缺点就愈发明显。

- - LoadBalancer的缺点是每个Service都需要一个LB，浪费，麻烦，并且需要kubernetes之外的设备的支持。

- 基于这种现状，kubernetes提供了Ingress资源对象，Ingress只需要一个NodePort或者一个LB就可以满足暴露多个Service的需求，工作机制大致如下图所示：

![22.png](https://cdn.nlark.com/yuque/0/2022/png/513185/1648106820246-30eb8f18-0886-4934-a0cd-1cdc1e114bbe.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_38%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)

## Ingress nginx 安装（Node）

- 创建deploy.yaml
- 给Node打标签
- 安装Ingress（关闭Node的80和443端口）
- 验证是否安装成功

## 工作原理

![Ingress工作原理.png](https://cdn.nlark.com/yuque/0/2021/png/513185/1609905668517-a82f7096-bfa4-44a6-b5d6-fac18efb4111.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_26%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)

- 用户编写Ingress规则，说明域名和k8s Service对应关系。

- Ingress 控制器动态感知Ingress服务规则的变化，然后生成一段对应的Nginx的反向代理配置。
- Ingress控制器会将生成的Nginx配置写入到运行的Nginx服务中，并动态更新。

## 实战

- pathType：

  - Prefix：Prefix：基于以 `/` 分隔的 URL 路径前缀匹配。匹配区分大小写，并且对路径中的元素逐个完成。 
  - Exact：精确匹配 URL 路径，且区分大小写。
  - ImplementationSpecific：对于这种路径类型，匹配方法取决于 IngressClass。 具体实现可以将其作为单独的 pathType 处理或者与 Prefix 或 Exact 类型作相同处理。


- ```
  apiVersion: networking.k8s.io/v1
  kind: Ingress 
  metadata:
    name: ingress-http
    namespace: default
    annotations: 
      kubernetes.io/ingress.class: "nginx"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"  
  spec:
    rules: # 规则
    - host: nginx.xudaxian.com # 指定的监听的主机域名，相当于 nginx.conf 的 server { xxx }
      http: # 指定路由规则
        paths:
        - path: /
          pathType: Prefix # 匹配规则，Prefix 前缀匹配 nginx.xudaxian.com/* 都可以匹配到
          backend: # 指定路由的后台服务的 service 名称
            service:
              name: nginx-svc # 服务名
              port:
                number: 80 # 服务的端口
    - host: tomcat.xudaxian.com # 指定的监听的主机域名，相当于 nginx.conf 的 server { xxx }
      http: # 指定路由规则
        paths:
        - path: /
          pathType: Prefix # 匹配规则，Prefix 前缀匹配 tomcat.xudaxian.com/* 都可以匹配到
          backend: # 指定路由的后台服务的 service 名称
            service:
              name: tomcat-svc # 服务名
              port:
                number: 8080 # 服务的端口
  ```

- 默认后端


  - ```
    # defaultBackend
    tomcat.com 域名的 非 /abc 开头的请求，都会转到 defaultBackend 。
    非 tomcat.com 域名下的所有请求，也会转到 defaultBackend 
    
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-http
      namespace: default
      annotations: 
        kubernetes.io/ingress.class: "nginx"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"  
    spec:
      defaultBackend: # 指定所有未匹配的默认后端
        service:
          name: nginx-svc
          port:
            number: 80
      rules: 
        - host: tomcat.com 
          http: 
            paths:
              - path: /abc
                pathType: Prefix 
                backend: 
                  service:
                    name: tomcat-svc
                    port:
                      number: 8080
    ```

- 全局配置


  - ```
    kubectl edit cm ingress-nginx-controller -n ingress-nginx
    
    # 配置项加上 
    data:
      map-hash-bucket-size: "128" # Nginx 的全局配置
      ssl-protocols: SSLv2
    ```

- 限流


  - ```
    # https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#rate-limiting
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: rate-ingress
      namespace: default
      annotations:
        kubernetes.io/ingress.class: "nginx"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"  
        nginx.ingress.kubernetes.io/limit-rps: "1" # 限流
    spec:
      rules:
      - host: nginx.xudaxian.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-svc
                port:
                  number: 80
    ```

- 路径重写


  - ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-rewrite
      namespace: default
      annotations:
       nginx.ingress.kubernetes.io/rewrite-target: /$2 # 路径重写
    spec:
      ingressClassName: nginx
      rules:
      - host: baidu.com
        http:
          paths:
          - path: /api(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: nginx-svc
                port:
                  number: 80
    ```

- 基于Cookie的会话保持


  - ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: rate-ingress
      namespace: default
      annotations: 
        kubernetes.io/ingress.class: "nginx"
        nginx.ingress.kubernetes.io/backend-protocol: "HTTP"  
        nginx.ingress.kubernetes.io/affinity: "cookie" # cookie会话保持
    spec:
      rules:
      - host: nginx.xudaxian.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-svc
                port:
                  number: 80
    ```

- SSL配置


  - ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-tls
      namespace: default
      annotations: 
        kubernetes.io/ingress.class: "nginx"  
    spec:
      # tls配置
      tls:
      - hosts:
          - nginx.xudaxian.com # 通过浏览器访问 https://nginx.xudaxian.com
          - tomcat.xudaxian.com # 通过浏览器访问 https://tomcat.xudaxian.com
        secretName: xudaxian-tls
      rules:
      - host: nginx.xudaxian.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-svc
                port:
                  number: 80
      - host: tomcat.xudaxian.com 
        http: 
          paths:
          - path: /
            pathType: Prefix 
            backend:
              service:
                name: tomcat-svc 
                port:
                  number: 8080
    ```


##  Ingress金丝雀发布

- 以前使用 Kubernetes 的 Service 配合 Deployment 进行金丝雀的部署，不能自定义灰度逻辑，Ingress金丝雀发布新版本上线时，配置新的Ingress-canary规则即可，canary验证通过后，移除旧的Ingress和Service，取消当前Ingress-canary的annotation，变为普通的Ingress。

- 基于Header的流量切分

  - ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-canary
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/canary: "true" # 开启金丝雀 
        nginx.ingress.kubernetes.io/canary-by-header: "Region" # 基于请求头
        # 如果 请求头 Region = always ，就路由到金丝雀版本；如果 Region = never ，就永远不会路由到金丝雀版本。
        nginx.ingress.kubernetes.io/canary-by-header-value: "sz" # 自定义值
        # 如果 请求头 Region = sz ，就路由到金丝雀版本；如果 Region != sz ，就永远不会路由到金丝雀版本。
        # nginx.ingress.kubernetes.io/canary-by-header-pattern: "sh|sz"
        # 如果 请求头 Region = sh 或 Region = sz ，就路由到金丝雀版本；如果 Region != sz 并且 Region != sz ，就永远不会路由到金丝雀版本。
    spec:
      ingressClassName: "nginx"
      rules:
      - host: nginx.xudaxian.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: v2-service
                port:
                  number: 80
    ```

  - ```
    # 测试
    curl -H "Host: nginx.xudaxian.com" http://192.168.65.101
    curl -H "Host: nginx.xudaxian.com" -H "Region: sz" http://192.168.65.101
    curl -H "Host: nginx.xudaxian.com" -H "Region: sh" http://192.168.65.101
    ```

- 基于Cookie的流量切分

  - ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-canary
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/canary: "true" # 开启金丝雀 
        nginx.ingress.kubernetes.io/canary-by-cookie: "vip" # 如果 cookie 是 vip = always ，就会路由到到金丝雀版本；如果 cookie 是 vip = never ，就永远不会路由到金丝雀的版本。
    spec:
      ingressClassName: "nginx"
      rules:
      - host: nginx.xudaxian.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: v2-service
                port:
                  number: 80
    ```

  - ```
    # 测试
    curl -H "Host: nginx.xudaxian.com" --cookie "vip=always" http://192.168.65.101
    ```

- 基于服务权重的流量切分

  - ```
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-canary
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/canary: "true" # 开启金丝雀 
        nginx.ingress.kubernetes.io/canary-weight: "10" # 基于服务权重
    spec:
      ingressClassName: "nginx"
      rules:
      - host: nginx.xudaxian.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: v2-service
                port:
                  number: 80
    ```

  - ```
    # test
    for i in {1..10}; do curl -H "Host: nginx.xudaxian.com" http://192.168.65.101; done;
    ```

## Label

- 一些常用的Label标签示例如下：
  - 版本标签：`“version”:”release”,”version”:”stable”`
  - 环境标签：`“environment”:”dev”,“environment”:”test”,“environment”:”pro”`
  - 架构标签：`“tier”:”frontend”,”tier”:”backend”`

- 命令式对象管理

```
# 为nginx的Pod打标签<key=value>
kubectl label pod nginx <key=value> -n dev

# 为nginx的Pod更新标签<key=value>
kubectl label pod nginx <key=value> -n dev --overwrite

# 显示nginx的Pod的标签
kubectl get pod nginx -n dev --show-labels

# 根据标签<key=value>、dev ns筛选pod
kubectl get pod -l <key=value> -n dev --show-labels

# 删除标签的key对应的nginx Pod上的标签
kubectl label pod nginx <key>- -n dev
```

- 命令式对象配置

```
# pod-nginx.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: dev
  labels:
    version: "3.0"
    env: "test"        
spec:
  containers:
  - image: nginx:1.17.1
    imagePullPolicy: IfNotPresent
    name: pod
    ports: 
    - name: nginx-port
      containerPort: 80
      protocol: TCP
      
# 创建      
kubectl create -f pod-nginx.yaml
# 删除
kubectl delete -f pod-nginx.yaml
```

# NetworkPolicy

- 默认情况下，Pod 都是非隔离的（non-isolated），可以接受来自任何请求方的网络请求。 如果一个 NetworkPolicy 的标签选择器选中了某个 Pod，则该 Pod 将变成隔离的（isolated），并将拒绝任何不被 NetworkPolicy 许可的网络连接。 

- ```
  
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: networkpol-01
    namespace: default
  spec:
    podSelector: # Pod 选择器
      matchLabels:
        app: nginx  # 选中的 Pod 就被隔离起来了
    policyTypes: # 策略类型
    - Ingress # Ingress 入站规则、Egress 出站规则
    - Egress 
    ingress: # 入站白名单，什么能访问我
    - from:
      - podSelector: # 选中的 Pod 可以访问 spec.matchLabels 中筛选的 Pod 
          matchLabels:
            access: granted
      ports:
      - protocol: TCP
        port: 80
    egress: # 出站白名单，我能访问什么
      - to:
         - podSelector: # spec.matchLabels 中筛选的 Pod 能访问的 Pod
            matchLabels:
              app: tomcat
         - namespaceSelector: 
            matchLabels:
              kubernetes.io/metadata.name: dev # spec.matchLabels 中筛选的 Pod 能访问 dev 命名空间下的所有
        ports:
        - protocol: TCP
          port: 8080
  ```

##  Service

- 命令式对象管理

```
# 创建集群内部可访问的Service
# 暴露名为nginx的deployment，并设置服务名为svc-nginx1
# --name:服务名
# --type:ClusterIP （ClusterIP是service的IP，在Service的生命周期内，这个地址是不会变化的）
# --port:暴露的端口
# --target-port:指向集群中的端口
kubectl expose deployment <nginx> --name=<svc-nginx1> --type=ClusterIP --port=<80> --target-port=<80> -n test


# 创建集群外部可访问的Service
# 暴露名为nginx的deployment，并设置服务名为svc-nginx2
kubectl expose deploy <nginx> --name=<svc-nginx2> --type=NodePort --port=<80> --target-port=<80> -n test

# 查看test ns下所有Service
kubectl get service -n test

# 删除Service
kubectl delete service <svc-nginx1> -n test
```

- 命令式对象配置

```
# svc-nginx.yaml
apiVersion: v1
kind: Service
metadata:
  name: svc-nginx
  namespace: dev
spec:
  clusterIP: 10.109.179.231
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    run: nginx
  type: ClusterIP
  
  
# 创建
kubectl  create  -f  svc-nginx.yaml

# 删除
kubectl  delete  -f  svc-nginx.yaml
```

# volume

- Kubernetes 的 Volume 支持多种类型，如下图所示：![2.png](https://cdn.nlark.com/yuque/0/2022/png/513185/1648538843251-3e1b92fa-f4a9-43ad-87e8-306789b291b3.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_25%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)

# 配置

## Secret

- Secret 对象类型用来保存敏感信息，如：密码、OAuth2 令牌以及 SSH 密钥等。将这些信息放到 Secret 中比放在 Pod 的定义或者容器镜像中更加安全和灵活。

- ```
  # 命令式资源管理
  kubectl create secret generic secret-1 --from-literal=username=admin --from-literal=password=123456
  
  # 命令式资源配置
  # 不用手动编码，让k8s进行编码（同时使用data和stringData，data会被忽略）
  apiVersion: v1
  kind: Secret
  metadata:
    name: k8s-secret-string-data
    namespace: default
  type: Opaque
  stringData: 
    username: admin
    password: "123456"
    
  kubectl apply -f k8s-secret.yaml
  
  # 查看Secret
  kubectl describe secret secret -n dev
  
  # 创建使用Secret的Pod
  vim pod-secret.yaml
  
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-secret
    namespace: dev
  spec:
    containers:
      - name: nginx
        image: nginx:1.17.1
        volumeMounts:
          - mountPath: /secret/config
            name: config
    volumes:
      - name: config
        secret:
          secretName: secret
          
  kubectl create -f pod-secret.yaml
  
  # 查看pod状态
  kubectl get pod pod-secret -n dev
  
  # 进入Pod
  kubectl exec -it pod-secret -n dev /bin/sh
  ls /secret/config
  # 可以看到被编码了
  more /secret/config/username
  more /secret/config/password
  ```

- 环境变量引用

  - ```
        env:
        - name: SECRET_USERNAME # 容器中的环境变量名称
          valueFrom:
            secretKeyRef: 
              name: my-secret #  指定 secret 的名称
              key: username # secret 中 key 的名称，会自动 base64 解码
        - name: SECRET_PASSWORD # 容器中的环境变量名称
          valueFrom:
            secretKeyRef:
              name: my-secret #  指定 secret 的名称
              key: password # secret 中 key 的名称
    ```

- ImagePullSecret：

  - ```
    # 创建ImagePullSecret
    kubectl create secret docker-registry docker-harbor-registrykey --docker-server=192.168.18.119:85 --docker-username=admin --docker-password=Harbor12345 --docker-email=1900919313@qq.com
    
    # 查看是否创建成功
    kubectl get secret docker-harbor-registrykey
    
    # 创建redis.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: redis
    spec:
      containers:
        - name: redis
          image: 192.168.18.119:85/yuncloud/redis # 这是Harbor的镜像私有仓库地址
      imagePullSecrets:
        - name: docker-harbor-registrykey
        
    # 创建pod
    kubectl apply -f redis.yaml
    ```

## ConfigMap

- ConfigMap 和 Secret 非常类似，只不过 Secret 会将信息进行 base64 编码和解码，而 ConfigMap 却不会。

- 资源清单文件

  - ```
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: configMap
      namespace: dev
    data: # <map[string]string>
      xxx
    ```

-  创建ConfigMap

  - ```
    #  创建ConfigMap
    vim configmap.yaml
    
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: configmap
      namespace: dev
    data:
      info:
        username:admin
        password:123456
    
    kubectl create -f configmap.yaml
    
    # 创建使用ConfigMap的Pod
    vim pod-configmap.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: pod-configmap
      namespace: dev
    spec:
      containers:
        - name: nginx
          image: nginx:1.17.1
          volumeMounts:
            - mountPath: /configmap/config
              name: config
      volumes:
        - name: config
          configMap:
            name: configmap
        
    # 查看pod状态
    # 进入pod
    kubectl exec -it pod-configmap -n dev /bin/sh
    cd /configmap/config
    ls
    more info
    # ConfigMap的key映射为一个文件，value映射为文件中的内容。
    # 热更新：如果更新了ConfigMap中的内容，Pod中的文件也会变化
    ```

- ```
  kubectl create configmap <map-name> <data-source>
  
  # 从一个目录中创建ConfigMap
  kubectl create configmap <cm1> --from-file=<configure-pod-container/configmap/?>
  
  # 从一个文件中创建ConfigMap
  # 默认情况下的key的名称是文件的名称
  kubectl create configmap <cm2> --from-file=<configure-pod-container/configmap/game.properties>
  
  # 从一个文件中创建ConfigMap，并自定义ConfigMap中key的名称
  kubectl create configmap <cm3> --from-file=<cm3>=<configure-pod-container/configmap/game.properties>
  
  # 从环境变量文件创建ConfigMap
  kubectl create cm <cm4> --from-env-file=c<onfigure-pod-container/configmap/env-file.properties>
  
  # 在命令行根据键值对创建ConfigMap
  kubectl create configmap <cm5> --from-literal=special.how=very --from-literal=special.type=charm
  
  # 使用ConfigMap定义容器环境变量
  kubectl create configmap <cm6> --from-literal=special.how=very --from-literal=special.type=charm
        env:
          # 定义环境变量
          - name: SPECIAL_LEVEL_KEY
            valueFrom:
              configMapKeyRef:
                # ConfigMap的名称
                name: cm6
                # ConfigMap的key
                key: special.how
  
  # 将 ConfigMap 中的所有键值对配置为容器环境变量
  kubectl create configmap <cm7> --from-literal=special.how=very --from-literal=special.type=charm
  ```

# 临时存储

## EmptyDir

![EmptyDir概述.png](https://cdn.nlark.com/yuque/0/2021/png/513185/1610067269031-747b1f35-dd83-4397-b841-7ebb32b4b5d7.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_28%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)

- EmptyDir是最基础的Volume类型，一个EmptyDir就是Host上的一个空目录。

- EmptyDir是在Pod被分配到Node时创建的，它的初始内容为空，并且**无须指定宿主机上对应的目录文件**，因为kubernetes会自动分配一个目录，当Pod销毁时，EmptyDir中的数据也会被永久删除。

- EmptyDir的用途如下：

- - 临时空间，例如用于某些应用程序运行时所需的临时目录，且无须永久保留。

- - 一个容器需要从另一个容器中获取数据的目录（多容器共享目录）。

- ```
  # 在一个Pod中准备两个容器nginx和busybox，然后声明一个volume分别挂载到两个容器的目录中，然后nginx容器负责向volume中写日志，busybox中通过命令将日志内容读到控制台。
  apiVersion: v1
  kind: Pod
  metadata:
    name: volume-emptydir
    namespace: dev
  spec:
    containers:
      - name: nginx
        image: nginx:1.17.1
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 80
        volumeMounts: # 将logs-volume挂载到nginx容器中对应的目录，该目录为/var/log/nginx
          - name: logs-volume
            mountPath: /var/log/nginx
      - name: busybox
        image: busybox:1.30
        imagePullPolicy: IfNotPresent
        command: ["/bin/sh","-c","tail -f /logs/access.log"] # 初始命令，动态读取指定文件
        volumeMounts: # 将logs-volume挂载到busybox容器中的对应目录，该目录为/logs
          - name: logs-volume
            mountPath: /logs
    volumes: # 声明volume，name为logs-volume，类型为emptyDir
      - name: logs-volume
        emptyDir: {}
  ```

## HostPath

![HostPath概述.png](https://cdn.nlark.com/yuque/0/2021/png/513185/1610067328325-2d2b96b2-026f-48b5-a204-25333fba6984.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_32%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)

- 我们已经知道EmptyDir中的数据不会被持久化，它会随着Pod的结束而销毁，如果想要简单的将数据持久化到主机中，可以选择HostPath。HostPath就是**将Node主机中的一个实际目录挂载到Pod中**，以供容器使用，这样的设计就可以保证Pod销毁了，但是数据依旧可以保存在Node主机上。

- ```
  apiVersion: v1
  kind: Pod
  metadata:
    name: volume-hostpath
    namespace: dev
  spec:
    containers:
      - name: nginx
        image: nginx:1.17.1
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 80
        volumeMounts: # 将logs-volume挂载到nginx容器中对应的目录，该目录为/var/log/nginx
          - name: logs-volume
            mountPath: /var/log/nginx
      - name: busybox
        image: busybox:1.30
        imagePullPolicy: IfNotPresent
        command: ["/bin/sh","-c","tail -f /logs/access.log"] # 初始命令，动态读取指定文件
        volumeMounts: # 将logs-volume挂载到busybox容器中的对应目录，该目录为/logs
          - name: logs-volume
            mountPath: /logs
    volumes: # 声明volume，name为logs-volume，类型为hostPath
      - name: logs-volume
        hostPath:
          path: /root/logs
          type: DirectoryOrCreate # 目录存在就使用，不存在就先创建再使用
  ```

- type的说明

  - ```
    type的值的说明：
    DirectoryOrCreate：目录存在就使用，不存在就先创建后使用。
    Directory：目录必须存在。
    FileOrCreate：文件存在就使用，不存在就先创建后使用。
    File：文件必须存在。
    Socket：unix套接字必须存在。
    CharDevice：字符设备必须存在。
    BlockDevice：块设备必须存在。
    ```

# 持久化存储

## NFS

![NFS概述.png](https://cdn.nlark.com/yuque/0/2021/png/513185/1610067394717-c50b7ae8-41fd-4f6d-bd90-f9c27d0183a5.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_37%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)

- HostPath虽然可以解决数据持久化的问题，但是一旦Node节点故障了，Pod如果转移到别的Node节点上，又会出现问题，此时需要准备单独的网络存储系统，比较常用的是NFS和CIFS。NFS是一个网络文件存储系统，可以搭建一台NFS服务器，然后将Pod中的存储直接连接到NFS系统上，这样，无论Pod在节点上怎么转移，只要Node和NFS的对接没有问题，数据就可以成功访问。

- 搭建NFS服务器

  - 在master节点搭建NFS服务器
  - 在Node节点上都安装NFS服务器，目的是为了Node节点可以驱动NFS设备

- 创建Pod

  - ```
    vim volume-nfs.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: volume-nfs
      namespace: dev
    spec:
      containers:
        - name: nginx
          image: nginx:1.17.1
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          volumeMounts: # 将logs-volume挂载到nginx容器中对应的目录，该目录为/var/log/nginx
            - name: logs-volume
              mountPath: /var/log/nginx
        - name: busybox
          image: busybox:1.30
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh","-c","tail -f /logs/access.log"] # 初始命令，动态读取指定文件
          volumeMounts: # 将logs-volume挂载到busybox容器中的对应目录，该目录为/logs
            - name: logs-volume
              mountPath: /logs
      volumes: # 声明volume
        - name: logs-volume
          nfs:
            server: 192.168.18.100 # NFS服务器地址
            path: /root/data/nfs # 共享文件路径
    ```



## PV和PVC

![PV和PVC概述.png](https://cdn.nlark.com/yuque/0/2021/png/513185/1610067446643-68eac8d4-685f-46d2-9ede-1d240f07f187.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_31%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)

- PV（Persistent Volume）：持久化卷，是对底层的共享存储的一种抽象。一般情况下PV由kubernetes管理员进行创建和配置，它和底层具体的共享存储技术有关，并通过插件完成和共享存储的对接。
- PVC（Persistent Volume Claim）：持久化卷声明，用户向kubernetes系统发出的一种资源需求申请。
- 使用了PV和PVC之后，工作可以得到进一步的提升：
  - 存储：存储工程师维护。
  - PV：kubernetes管理员维护。
  - PVC：kubernetes用户维护。


### PV

- 资源配置清单

  ```
  mkdir -pv /root/data/pv1
  
  apiVersion: v1
  kind: PersistentVolume
  metadata:
    name: pv1
  spec:
  	storageClassName: nfs-storage # 用于分组
    nfs: # 存储类型吗，和底层正则的存储对应
      path: /root/data/pv1
      server: 192.168.18.100
    capacity: # 存储能力，目前只支持存储空间的设置
      storage: 1Gi
    accessModes: # 访问模式
      - ReadWriteMany
    persistentVolumeReclaimPolicy: Retain # 回收策略
  ```

  > pv的关键配置参数说明：
  >
  > - 存储类型：底层实际存储的类型，kubernetes支持多种存储类型，每种存储类型的配置有所不同。
  >
  > - 存储能力（capacity）：目前只支持存储空间的设置（storage=1Gi），不过未来可能会加入IOPS、吞吐量等指标的配置。
  >
  > - 访问模式（accessModes）：
  >
  > - - 用来描述用户应用对存储资源的访问权限，访问权限包括下面几种方式：
  >
  > - - - ReadWriteOnce（RWO）：读写权限，但是只能被单个节点挂载。
  >     - ReadOnlyMany（ROX）：只读权限，可以被多个节点挂载。
  >     - ReadWriteMany（RWX）：读写权限，可以被多个节点挂载。
  >
  > - - 需要注意的是，底层不同的存储类型可能支持的访问模式不同。
  >
  > - 回收策略（ persistentVolumeReclaimPolicy）：
  >
  > - - 当PV不再被使用之后，对其的处理方式，目前支持三种策略：
  >
  > - - - Retain（保留）：保留数据，需要管理员手动清理数据。
  >
  > - - - Recycle（回收）：清除PV中的数据，效果相当于`rm -rf /volume/*`。
  >
  > - - - Delete（删除）：和PV相连的后端存储完成volume的删除操作，常见于云服务器厂商的存储服务。
  >
  > - - 需要注意的是，底层不同的存储类型可能支持的回收策略不同。
  >
  > - 存储类别（storageClassName）：PV可以通过storageClassName参数指定一个存储类别。
  >
  > - - 具有特定类型的PV只能和请求了该类别的PVC进行绑定。
  >   - 未设定类别的PV只能和不请求任何类别的PVC进行绑定。
  >
  > - 状态（status）：一个PV的生命周期，可能会处于4种不同的阶段。
  >
  > - - Available（可用）：表示可用状态，还未被任何PVC绑定。
  >
  > - - Bound（已绑定）：表示PV已经被PVC绑定。
  >
  > - - Released（已释放）：表示PVC被删除，但是资源还没有被集群重新释放。
  >
  > - - Failed（失败）：表示该PV的自动回收失败。

### PVC

- 资源配置清单

  - storageClassName  就相当于分组的组名，通过 storageClassName 可以区分不同类型的存储驱动，主要是为了方便管理。

  - ```
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: pvc1
      namespace: dev
    spec:
      accessModes: # 访客模式
        - ReadWriteMany
      selector: # 采用标签对对于系统中已存在的PV进行筛选。
      storageClassName: nfs-storage # 用于分组
      resources: # 请求空间
        requests:
          storage: 1Gi
    ```

- 创建pod使用PVC

  - ```
    apiVersion: v1
    kind: Pod
    metadata:
      name: pod1
      namespace: dev
    spec:
      containers:
      - name: busybox
        image: busybox:1.30
        command: ["/bin/sh","-c","while true;do echo pod1 >> /root/out.txt; sleep 10; done;"]
        volumeMounts:
        - name: volume
          mountPath: /root/
      volumes:
        - name: volume
          persistentVolumeClaim:
            claimName: pvc1
            readOnly: false
    ```

  - ```
    # 创建Pod
    kubectl get pod -n dev -o wide
    
    # 创建Pod使用PVC后查看PVC
    kubectl get pvc -n dev -o wide
    
    # 创建POd使用PVC后查看PV
    kubectl get pv -n dev -o wide
    
    # 查看nfs中的文件存储
    ls /root/data/pv1/out.txt
    ```

### 生命周期

- **![PVC的生命周期.png](https://cdn.nlark.com/yuque/0/2021/png/513185/1610067602846-ec97175f-5f8d-47f2-9f93-9fabb4621f0d.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_35%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10)**

1. 资源供应：管理员手动创建底层存储和PV。

2. 资源绑定：

- - 用户创建PVC，kubernetes负责根据PVC声明去寻找PV，并绑定在用户定义好PVC之后，系统将根据PVC对存储资源的请求在以存在的PV中选择一个满足条件的。

- - - 一旦找到，就将该PV和用户定义的PVC进行绑定，用户的应用就可以使用这个PVC了。

- - - 如果找不到，PVC就会无限期的处于Pending状态，直到系统管理员创建一个符合其要求的PV。

- - PV一旦绑定到某个PVC上，就会被这个PVC独占，不能再和其他的PVC进行绑定了。

3. 资源使用：用户可以在Pod中像volume一样使用PVC，Pod使用Volume的定义，将PVC挂载到容器内的某个路径进行使用。

4. 资源释放：

- - 用户删除PVC来释放PV。

- - 当存储资源使用完毕后，用户可以删除PVC，和该PVC绑定的PV将会标记为“已释放”，但是还不能立刻和其他的PVC进行绑定。通过之前PVC写入的数据可能还留在存储设备上，只有在清除之后该PV才能再次使用。

5. 资源回收：

- - kubernetes根据PV设置的回收策略进行资源的回收。

- - 对于PV，管理员可以设定回收策略，用于设置与之绑定的PVC释放资源之后如

## 动态供应

- 静态供应：集群管理员创建若干 PV 卷。这些卷对象带有真实存储的细节信息，并且对集群用户可用（可见）。PV 卷对象存在于 Kubernetes API 中，可供用户消费（使用）。

- 动态供应：集群自动根据 PVC 创建出对应 PV 进行使用。

### 动态供应完整流程

![41.png](https://cdn.nlark.com/yuque/0/2022/png/513185/1648539197723-ab90990e-7dab-492e-94ec-4e37d33583b4.png?x-oss-process=image%2Fwatermark%2Ctype_d3F5LW1pY3JvaGVp%2Csize_48%2Ctext_6K645aSn5LuZ%2Ccolor_FFFFFF%2Cshadow_50%2Ct_80%2Cg_se%2Cx_10%2Cy_10%2Fresize%2Cw_1500%2Climit_0)



# 网络

## Node网络

https://mp.weixin.qq.com/s/Q3GGV6mpZuYvGv5cwpN8ng

## Pod网络

https://mp.weixin.qq.com/s/eKcSIU9w-Q_AHumgbC8DUA

https://zhuanlan.zhihu.com/p/603605839

## service网络

https://zhuanlan.zhihu.com/p/590101553

https://mp.weixin.qq.com/s/aJHmi3-2UCobOt_GArMUbA

# 安全

## 访问控制

- api-server 是访问和管理资源对象的唯一入口。任何一个请求访问 api-server，都要经过下面的三个流程： 

- - ① Authentication（认证）：身份鉴别，只有正确的账号才能通过认证。

- - ② Authorization（授权）：判断用户是否有权限对访问的资源执行特定的动作。

- - ③ Admission Control（准入控制）：用于补充授权机制以实现更加精细的访问控制功能。

## 认证管理

- Kubernetes 集群安全的关键点在于如何识别并认证客户端身份，它提供了 3 种客户端身份认证方式：

-  ① HTTP Base 认证： 

- - 通过 `用户名+密码` 的方式进行认证。

- - 这种方式是把 `用户名:密码` 用 BASE64 算法进行编码后的字符串放在 HTTP 请求中的 Header 的 Authorization 域里面发送给服务端。服务端收到后进行解码，获取用户名和密码，然后进行用户身份认证的过程。

-  ② HTTP Token 认证： 

- - 通过一个 Token 来识别合法用户。

- - 这种认证方式是用一个很长的难以被模仿的字符串--Token 来表明客户端身份的一种方式。每个 Token 对应一个用户名，当客户端发起 API 调用请求的时候，需要在 HTTP 的 Header 中放入 Token，API Server 接受到 Token 后会和服务器中保存的 Token 进行比对，然后进行用户身份认证的过程。

-  ③ HTTPS 证书认证： 

- - 基于 CA 根证书签名的双向数字证书认证方式。

- - 这种认证方式是安全性最高的一种方式，但是同时也是操作起来最麻烦的一种方式。

## 授权管理

- API Server支持的授权策略：

  - AlwaysDeny：表示拒绝所有请求，一般用于测试。 

  -  AlwaysAllow：允许接收所有的请求，相当于集群不需要授权流程（Kubernetes 默认的策略）。 

  -  ABAC：基于属性的访问控制，表示使用用户配置的授权规则对用户请求进行匹配和控制。 

  -  Webhook：通过调用外部REST服务对用户进行授权。 

  -  Node：是一种专用模式，用于对 kubelet 发出的请求进行访问控制。 

  -  RBAC：基于角色的访问控制（ kubeadm 安装方式下的默认选项）。 

- RBAC 引入了 4 个顶级资源对象： 

- - Role：角色，用于指定一组权限，限定名称空间下的权限。

- - ClusterRole：集群角色，用于指定一组权限，限定集群范围下的权限。

- - RoleBinding：角色绑定，用于将角色 Role（权限的集合）赋予给对象（User、Group、ServiceAccount）。

- - ClusterRoleBinding：集群角色绑定，用于将集群角色 Role（权限的集合）赋予给对象（User、Group、ServiceAccount）。

## 准入控制

- 准入控制是一个可配置的控制器列表，可以通过在 API Server 上通过命令行设置选择执行哪些注入控制器。

```shell
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds
```

- 只有当所有的注入控制器都检查通过之后，API Server 才会执行该请求，否则返回拒绝。

# Helm

## Helm客户端

```
# 下载
wget https://get.helm.sh/helm-v3.2.1-linux-amd64.tar.gz

# 解压Helm到/usr/bin目录：
tar -zxvf helm-v3.2.1-linux-amd64.tar.gz
cd linux-amd64/
cp helm /usr/bin/

# 配置国内仓库 
# 添加微软仓库，并更新仓库
helm repo add stable http://mirror.azure.cn/kubernetes/charts
helm repo add aliyun https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
helm repo update

# 查看配置的存储库
helm repo list

# 删除存储库
helm repo remove 仓库名
```

## Helm基础

```
# 根据关键词搜索chart
helm search repo <weave>

# 查看chart信息
helm show chart <仓库名>/<mysql>

# 安装chart，生成release
helm install <安装之后的名称> <仓库名>/<chart name>

# 查看release列表
helm list

# 查看helm状态
helm status <安装之后的名称>

# 自定义chart配置
helm install <db> --set persistence.storageClass="managed-nfs-storage" <stable>/<mysql>

```

## 构建一个Helm Chart

- chart文件结构

  - ```
    wordpress/
    ├── charts # 包含chart依赖的其他chart
    ├── Chart.yaml # 用于描述这个 Chart 的基本信息，包括名字、描述信息以及版本等。
    ├── templates # 模板目录， 当和 values 结合时，可生成有效的Kubernetes manifest文件
    │   ├── deployment.yaml
    │   ├── _helpers.tpl # 放置可以通过 chart 复用的模板辅助对象
    │   ├── hpa.yaml
    │   ├── ingress.yaml
    │   ├── NOTES.txt # 用于介绍 Chart 帮助信息， helm install 部署后展示给用户。例如：如何使用这个 Chart、列出缺省的设置等。
    │   ├── serviceaccount.yaml
    │   ├── service.yaml
    │   └── tests
    │       └── test-connection.yaml
    └── values.yaml # chart 默认的配置值
    ```

- 创建自定义chart

  - ```
    # 创建chart
    helm create chart的名称
    
    # 安装自定义chart
    helm install nginxdemo nginx
    
    # 对自定义 chart 进行打包
    helm package nginx
    
    # 查看实际模板被渲染后的文件
    helm get manifest nginx-demo
    
    # 修改chart配置后，升级chart
    helm upgrade --set image.tag=1.17 nginx-demo nginx
    helm upgrade -f values.yaml nginx-demo nginx
    
    # 查看升级后的版本
    helm history nginx-demo
    
    # 回滚
    helm rollback nginx-demo 1
    
    # 卸载
    helm uninstall nginx-demo
    ```



# 项目部署

## 部署流程

1. 项目打包
2. 编写dockerfile
3. 通过docker build制作镜像
4. 将镜像推送到镜像仓库
5. k8s环境准备
6. 使用Pod控制器部署镜像
7. 创建Service或Ingress对外暴露服务
8. 对集群进行监控，升级等

# Dockerfile

ARG：指定镜像内使用的参数，可以在docker build时，使用--build-arg改变。

FROM：基础镜像

WORKDIR：工作目录

COPY：复制主机src路径下的内容到镜像的dest目录，但不会自动解压缩。

RUN：镜像构建过程中运行的命令

ENV：环境变量，可以在docker run时通过-e修改。

ENTRYPOINT：镜像默认入口及运行命令

## mysql

```
docker search mysql
docker pull mysql:latest
docker run --name mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=123456 -d mysql
docker exec -it mysql bash
mysql -u root -p
show databases;
create database venus_auth;
show databases;

create user 'user'@'ip' identified by '123456';#创建一个主机地址是ip登录密码是123456的user用户
grant all privileges on *.* to 'user'@'ip';#链接上一步，给他所有权限

use mysql;
alter user 'mysql'@'%' identified by '123456' password expire never;#修改加密规则
alter user 'mysql'@'%' identified by '123456' mysql_native_password by '123456';#再次重置密码
flush privilege；#刷新下数据权限
```

Deployment:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-pod
  template:
    metadata:
      labels:
        app: nginx-pod
    spec:
      containers:
      - name: nginx
        image: nginx:1.17.1
        ports:
        - containerPort: 80
        
kubectl create -f pc-deployment.yaml
```

Service：

```
apiVersion: v1
kind: Service
metadata:
  name: service-clusterip
  namespace: dev
spec:
  selector:
    app: nginx-pod
  type: ClusterIP
  clusterIP: 10.96.96.96  # service的ip地址，如果不写，默认会生成一个
  ports:
  - protocol: TCP
    port: 8080  # service的端口
    targetPort: 80  # pod的端口

```



## venus-auth

```
# Dockerfile
ARG RUNTIME_TAG=latest

FROM filvenus/venus-buildenv AS buildenv

WORKDIR /build

COPY ./go.mod /build/
COPY ./exter[n] ./go.mod  /build/extern/
ENV GOPROXY="https://goproxy.cn,direct"
RUN  go mod download

COPY . /build
RUN make


FROM filvenus/venus-runtime:${RUNTIME_TAG}

ARG BUILD_TARGET=
ENV VENUS_COMPONENT=${BUILD_TARGET}

# copy the app from build env
COPY --from=buildenv  /build/${BUILD_TARGET} /app/${BUILD_TARGET}

#ENTRYPOINT ["/script/init.sh", "run"]
ENTRYPOINT ["./venus-auth"]

# build、run
docker build --build-arg https_proxy=$(BUILD_DOCKER_PROXY) --build-arg BUILD_TARGET=venus-auth  -t venus-auth docker tag venus-auth filvenus/venus-auth:$(TAG)
docker run -d -p 8989:8989 --name venus-auth-container filvenus/venus-auth:test run --db-type="mysql" --mysql-dsn="root:123456@(127.0.0.1:3306)/venus_auth?parseTime=true&loc=Local&charset=utf8mb4&collation=utf8mb4_unicode_ci&readTimeout=10s&writeTimeout=10s"
```



```
1. 创建test环境
NewK8sEnvDeployer

2. 创建venus-auth Deployment
NewVenusAuthHADeployer

3. 转发pod apiserver 到本机，用于debug
PortForwardPod

4. 等待apiserver启动完成
WaitForAPIReady

5. 创建venus auth client
NewAuthClient

6. 使用authAPIClient进行交互
authAPIClient.CreateUser
authAPIClient.GenerateToken
```



