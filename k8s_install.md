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
# 关闭 swap 
sudo swapoff -a

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
$ systemctl start docker

# 开启自动启动
$ systemctl enable docker

# 验证 Docker 是否安装成功：
$ docker version

# 设置阿里云Docker镜像加速器
$ cat <<EOF | sudo tee /etc/docker/daemon.json
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

# 重启和查看状态
$ sudo systemctl restart docker
$ sudo systemctl status docker
```

## 安装containerd

```
$ sudo apt-get update && sudo apt-get install -y containerd
$ systemctl start containerd
```



## 安装kubeadm、kubelet、kubectl（全节点）

```
# 使用阿里云镜像
$ apt-get update && apt-get install -y apt-transport-https
$ curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
$ cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
$ apt-get update
$ apt-get install -y kubelet kubeadm kubectl

# 查看可安装版本
$ apt-cache madison kubelet

# 安装指定版本
$ apt-get install -y kubelet=1.27.3-00 kubeadm=1.27.3-00 kubectl=1.27.3-00

# 设置开机启动
$ sudo systemctl enable kubelet && sudo systemctl start kubelet
```

- ~~为了实现Docker使用的cgroup drvier和kubelet使用的cgroup drver一致，建议修改"/etc/sysconfig/kubelet"文件的内容：~~

```
vim /etc/sysconfig/kubelet
# 修改
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"
KUBE_PROXY_MODE="ipvs"
```

- 启动，如果发现启动失败是正常的，因为在k8s master节点初始化之前，kubelet连不上api server，kubelet会定时尝试连接k8s api server，直到成功。

```
# 启动kubelet
$ sudo systemctl start kubelet

# 查看状态
$ systemctl status kubelet
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
kubeadm init --apiserver-advertise-address=192.168.200.103 --image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers --kubernetes-version v1.26.1 --service-cidr=10.96.0.0/12 --pod-network-cidr=10.244.0.0/16 --node-name k8s-master --control-plane-endpoint=cluster-endpoint
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

- k8s支持多种网络插件：flannel

```
# 查看部署CNI网络插件进度：
watch kubectl get pods -n kube-system

# 再次在Master节点使用kubectl工具查看节点状态：
kubectl get nodes

# 查看集群健康状况：
kubectl get cs
kubectl cluster-info
```



## 部署k8s的Node（工作节点）

1.  在 master 节点上，生成一个加入令牌：
  
```
kubeadm token create --print-join-command
```
此命令将生成一个包含加入命令的输出，如：

```
kubeadm join <master-node-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash <hash>
```
在新的节点上，运行上面生成的 kubeadm join 命令。此命令会安装必要的组件并将新节点加入到集群中。

2. 让Node节点也能使用kubectl（将Master的.kube文件复制到Node上，在mster节点执行下面的命令：

```
scp -r $HOME/.kube k8s-node1:$HOME
scp /etc/kubernetes/admin.conf root@192.168.200.172:~/.kube/config
```
3.  新增网络插件的配置文件，内容参考其他节点的同文件

```
/etc/cni/net.d/10-flannel.conflist
```

4. 验证节点已加入集群:
在 master 节点或已连接到集群的任何计算机上运行：
```
kubectl get nodes
```
您应该能看到新节点的状态为 NotReady。一旦所有的系统 pods 运行起来（如网络插件），它将变为 Ready 状态。


## 生成yaml文件

- 使用kubectl create命令生成yaml文件：

```
kubectl create deployment nginx --image=nginx:1.17.1 --dry-run=client -n dev -o yaml

# 如果yaml文件太长，可以写入到指定的文件中。
kubectl create deployment nginx --image=nginx:1.17.1 --dry-run=client -n dev -o yaml > test.yaml
```

