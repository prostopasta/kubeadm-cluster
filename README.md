# Here infrastructure template for kubeadm task uses Vagrant and ubuntu

## Deploy multi-masters HA cluster with `kubeadm`, `vagrant` and `ubuntu`

Скрипты из этого репозитория облегчают процесс установления кластера производственного уровня.

Итак, в курсе мы выяснили, что самый простой сетап с высокой доступностью состоит из 6 элементов:

- 1 балансировщика
- 3 мастер-нод
- 2 рабочих узлов

### Склонируй этот репо

В корне лежит `Vagrantfile`.

По умолчанию он настроен на создание 2 мастеров, 1 воркера и 1 лоадбаленсера.

```bash
git clone https://github.com/rotoro-cloud/kubeadm-cluster.git
cd kubeadm-cluster
vagrant up
```

Поднимутся VMs. Их адреса:

- 192.168.66.1X - для мастеров
- 192.168.66.2X - для рабочих
- 192.168.66.30 - для балансировщика

Т.е. `controlplane01` будет 192.168.66.11, `controlplane02` будет 192.168.66.12 и т.д.

Но сачала давай познакомимся с окружением

### Окружение

Ты можешь подключиться прямо к виртуальной машине с помощью

```bash
vagrant ssh node01
```

Или сделай команду:

```bash
vagrant ssh-config
```

Это покажет тебе адреса VMs, их порты ssh и пути к ключам, чтобы подключиться к ним из твоего любимого ssh-клиента.

### Балансировщик

Для сетапа высокой доступности необходимый элемент, без него не будет полноценной `HA`.
В этом сетапе мы используем `HAproxy`, давай ее настроим.

#### Выполняется в VM `lb`

```bash
sudo apt update
sudo apt install -y haproxy
```

Далее внесем правки в `/etc/haproxy/haproxy.cfg`, добавив в конец следующее:

```bash
frontend kubernetes-frontend
    bind 192.168.66.30:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server controlplane01 192.168.66.11:6443 check fall 3 rise 2
    server controlplane02 192.168.66.12:6443 check fall 3 rise 2
    server controlplane03 192.168.66.13:6443 check fall 3 rise 2
```

Теперь балансировщик будет пересылать трафик на один из трех мастеров. И он достаточно умный не послылать трафик, если мастер в данный момент недоступен.

```bash
sudo systemctl restart haproxy
```

Мы закончили с балансировщиком, он нам больше не понадобится.

### Выполняется во всех VMs-нодах, и мастерах и воркерах

[https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic)

```bash
lsmod | grep br_netfilter
```

Если пусто, то:

```bash
sudo modprobe br_netfilter
```

После этого:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

Ошибка «Содержимое файла /proc/sys/net/ipv4/ip_forward не равно 1» возникает при инициализации кластера Kubernetes с помощью kubeadm. Она указывает на то, что на хост-машине отключена переадресация IP. Это важно для маршрутизации сетевого трафика между модулями на разных узлах. Чтобы исправить ошибку, нужно включить переадресацию IP.
Выполнить команду:

```bash
sysctl -n net.ipv4.ip_forward
0

sudo sysctl -w net.ipv4.ip_forward=1
```

Чтобы изменение стало постоянным, добавить net.ipv4.ip_forward = 1 в файл /etc/sysctl.conf:

```bash
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
```

Применить изменения в системе:

```bash
sudo sysctl -p
```

Далее подготовка среды выполнения контейнера,
[https://kubernetes.io/docs/setup/production-environment/container-runtimes/](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

#### docker

https://docs.docker.com/engine/install/ubuntu/

У меня `docker`, поэтому:

```bash
wget get.docker.com
bash index.html
sudo systemctl enable docker
sudo usermod -aG docker vagrant
```

#### containerd

Official guide:

https://github.com/containerd/containerd/blob/main/docs/getting-started.md

or start from Docker install guide:

https://docs.docker.com/engine/install/ubuntu/

```bash
# Run the following command to uninstall all conflicting packages:
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install containerd.io -y
```

Затем проверить конфигурацию containerd:

```bash
containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's/pause:3.8/pause:3.10/' /etc/containerd/config.toml

egrep -i '(pause:|systemdc)' /etc/containerd/config.toml
    # sandbox_image = "registry.k8s.io/pause:3.10"
    #         SystemdCgroup = true

sudo systemctl restart containerd
```

Проверить версии пакетов:

```bash
containerd -v
# containerd containerd.io 1.7.27

runc -v
# runc version 1.2.5
# commit: v1.2.5-0-g59923ef
# spec: 1.2.0
# go: go1.23.7
# libseccomp: 2.5.3

```

Теперь поставим `kubeadm`, `kubelet` и `kubectl`
[https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl)

Добавим нужные утилиты, хотя `docker` уже их должен был добавить:

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
```

Добавим ключи репозитория `kubernetes` и сам репо:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Теперь поставим наши утилиты:

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Настройка ETCD в режиме HA

Set up a High Availability etcd Cluster with kubeadm - <https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm>


### Выполняется на самом первом мастере

[https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#initializing-your-control-plane-node)

Проинициализируем мастер:

```bash
sudo kubeadm init --control-plane-endpoint="192.168.56.30" --upload-certs --apiserver-advertise-address=192.168.56.11 --pod-network-cidr=10.244.0.0/16
```

Сразу сделаем себе доступ для `kubectl`:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Выполняется на других мастерах

Присоединим остальные мастера командой из вывода `kubeadm`

```bash
sudo kubeadm join 192.168.56.30:6443 --apiserver-advertise-address=192.168.56.11...
```

### Выполняется на воркерах

Присоединим воркеры командой из вывода `kubeadm`

```bash
sudo kubeadm join 192.168.56.30:6443...
```

### Последний шаг

Развернем сетевой плагин:

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Weave - https://rajch.github.io/weave/install/installing-weave
```
