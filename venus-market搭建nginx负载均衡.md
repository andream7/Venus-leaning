# venus-market搭建负载均衡

[TOC]

## 安装MongoDB

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install mongodb

sudo systemctl status mongodb




root@nginx:~# sudo systemctl status mongodb
● mongodb.service - An object/document-oriented database
     Loaded: loaded (/lib/systemd/system/mongodb.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2022-06-07 15:53:36 CST; 1 day 21h ago
       Docs: man:mongod(1)
   Main PID: 117215 (mongod)
      Tasks: 29 (limit: 19105)
     Memory: 151.6M
     CGroup: /system.slice/mongodb.service
             └─117215 /usr/bin/mongod --unixSocketPrefix=/run/mongodb --config /etc/mongodb.conf # 配置文件路径

Jun 07 15:53:36 nginx systemd[1]: Started An object/document-oriented database.
```

* 修改配置文件

```bash
vim /etc/mongodb.conf

bind_ip = 0.0.0.0  # 监听所有端口
```

* mongodb用于记录可检索文件的信息，再不配置的情况下默认使用本地，如果做负载均衡就必须保证所有的venus-mraket读取的数据一致

## 初始化配置

```bash
./venus-market pool-run --node-url /ip4/127.0.0.1/tcp/3453/ws --node-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4tdXNlciIsInBlcm0iOiJhZG1pbiIsImV4dCI6IiJ9.34HiClG8eQVQclVUWHSIbVxbtg4AsiMxWMgilhwGrsw --auth-url http://127.0.0.1:8989 --auth-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4tdXNlciIsInBlcm0iOiJhZG1pbiIsImV4dCI6IiJ9.34HiClG8eQVQclVUWHSIbVxbtg4AsiMxWMgilhwGrsw --messager-url /ip4/0.0.0.0/tcp/39812 --gateway-url /ip4/127.0.0.1/tcp/45132 --gateway-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4tdXNlciIsInBlcm0iOiJhZG1pbiIsImV4dCI6IiJ9.34HiClG8eQVQclVUWHSIbVxbtg4AsiMxWMgilhwGrsw
```

## 修改配置venus-market配置

* 配置示例

```bash
# Default config:
ConsiderOnlineStorageDeals = true
ConsiderOfflineStorageDeals = true
ConsiderOnlineRetrievalDeals = true
ConsiderOfflineRetrievalDeals = true
ConsiderVerifiedStorageDeals = true
ConsiderUnverifiedStorageDeals = true
PieceCidBlocklist = []
ExpectedSealDuration = "24h0m0s"
MaxDealStartDelay = "336h0m0s"
PublishMsgPeriod = "0h0m5s"   # 消息等待时间
MaxDealsPerPublishMsg = 8
MaxProviderCollateralMultiplier = 2
SimultaneousTransfersForStorage = 20
SimultaneousTransfersForStoragePerClient = 20
SimultaneousTransfersForRetrieval = 20
Filter = ""
RetrievalFilter = ""
TransfePath = ""
MaxPublishDealsFee = "0 FIL"
MaxMarketBalanceAddFee = "0 FIL"

[API]
  ListenAddress = "/ip4/0.0.0.0/tcp/41235"
  RemoteListenAddress = ""
  Secret = "a1a8b7b3075a43a221df1ce4ede55ac9c4e2e0d7186f9b23a6a8193a640ecf4a"
  Timeout = "30s"

[Libp2p]
  ListenAddresses = ["/ip4/0.0.0.0/tcp/58419", "/ip6/::/tcp/0"]
  AnnounceAddresses = []
  NoAnnounceAddresses = []
  PrivateKey = "080112403718a1c3d332bed3237dfc67a6f0668ec7a464ab710997b10400a9b43aeb1026504411b8597d84d69f3f8a2b76979ba9278f15fdcc434f281a7fa3c9985434aa"

[Node]
  Url = "/ip4/127.0.0.1/tcp/3453/ws"
  Token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4iLCJwZXJtIjoiYWRtaW4iLCJleHQiOiIifQ.fgdluPDm5RIOKWig9ZVv8OK4NUdayQycBtsgljE-nw8"

[Messager]
  Url = "/ip4/0.0.0.0/tcp/39812"
  Token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4iLCJwZXJtIjoiYWRtaW4iLCJleHQiOiIifQ.fgdluPDm5RIOKWig9ZVv8OK4NUdayQycBtsgljE-nw8"

[Signer]
  Type = "gateway"
  Url = "/ip4/127.0.0.1/tcp/45132"
  Token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4iLCJwZXJtIjoiYWRtaW4iLCJleHQiOiIifQ.fgdluPDm5RIOKWig9ZVv8OK4NUdayQycBtsgljE-nw8"

[AuthNode]
  Url = "http://127.0.0.1:8989"
  Token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4iLCJwZXJtIjoiYWRtaW4iLCJleHQiOiIifQ.fgdluPDm5RIOKWig9ZVv8OK4NUdayQycBtsgljE-nw8"

[Mysql]
  ConnectionString = "root:kuangfengjuexizhan@tcp(192.168.200.2:3308)/venus-market-vm-105?parseTime=true&loc=Local"
  MaxOpenConn = 100
  MaxIdleConn = 100
  ConnMaxLifeTime = "1m"
  Debug = false

[PieceStorage]
  [[PieceStorage.Fs]]
    ReadOnly = false
    Path = "/storage-nfs-2/theduan/vm-calib-market"
    
 [PieceStorage]
  [[PieceStorage.Fs]]
    ReadOnly = false
    Path = "/storage-nfs-2/theduan/vm-calib-market"

[Journal]
  Path = "journal"

[AddressConfig]
  DisableWorkerFallback = false

[DAGStore]
  RootDir = "/root/.venusmarket/dagstore"
  MaxConcurrentIndex = 5
  MaxConcurrentReadyFetches = 0
  MaxConcurrencyStorageCalls = 100
  GCInterval = "1m0s"
  Transient = ""
  Index = ""
  UseTransient = false
  [DAGStore.MongoTopIndex]
        url="mongodb://192.168.200.105" # Mongodb地址，用于存放可以检索文件信息

[RetrievalPaymentAddress]
  Addr = "t3ss4g66knxijaju6rotq7fy4bearig2ihfo43btivpxee4hc2nxpaxhu4xlt44oat37sc7gmmcdicmzul4jjq" # 收款地址
  Account = "admin"

[RetrievalPricing]
  Strategy = "default"
  [RetrievalPricing.Default]
    VerifiedDealsFreeTransfer = true
  [RetrievalPricing.External]
    Path = ""
```



* 拷贝配置文件到另一台机器上

* 注意事项

  1. 需要启动多个venus-market
  2. 多个venus-mrket中的key和Secret部分必须保持一致
  3. 多个venus-market必须链接到同一套云组件当中
  4. 多个venus-market必须保持多Piece路径一致且都能访问

## Nginx配置

* Ubuntu20.04

```bash
sudo apt update

sudo apt install nginx

sudo systemctl status nginx
```

* 配置文件

```bash
load_module /usr/lib/nginx/modules/ngx_stream_module.so;

#user  nobody;
worker_processes  2;

error_log   /etc/nginx/error.log  info; # 错误日志

pid         /run/nginx.pid; # 启动时自动生成


events {
    worker_connections  1024;
}

stream {
    upstream backend {
        hash $remote_addr consistent;   #负载方法
        server 192.168.200.34:58419 max_fails=2 fail_timeout=30s ; # venus-market地址和端口
        server 127.0.0.1:58419 max_fails=2 fail_timeout=30s ; # venus-market地址和端口
    }

    server {
        listen 58418;   #服务器监听端口
        proxy_connect_timeout 60;
        proxy_timeout 300s;    #设置客户端和代理服务之间的超时时间，如果5分钟内没操作将自动断开。

        proxy_pass backend;
   }

}


# http的配置
http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  info  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    sendfile        on;
    #keepalive_timeout  0;
    keepalive_timeout  65;

    upstream backend {
        server 192.168.200.34:58418 max_fails=2 fail_timeout=30s ;
        server 127.0.0.1:58419 max_fails=2 fail_timeout=30s ;
    }

    upstream ws_backend {
        server 192.168.200.34:58418 max_fails=2 fail_timeout=30s ;
        server 127.0.0.1:58419 max_fails=2 fail_timeout=30s ;
    }

    server {
        listen       5843;
        server_name  venus-market;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm;
            proxy_pass http://backend;
            proxy_redirect off;

            #proxy_pass http://ws_backend;
            #proxy_set_header Upgrade $http_upgrade;
            #proxy_set_header Connection "Upgrade";
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
```

* 如果启动出现pid文件找不到

```bash
cat /usr/lib/systemd/system/nginx.service

# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target

[Service]
Type=forking
PIDFile=/run/nginx.pid # 检查这里和nginx配置中的pid是否一致
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid # 检查这里和nginx配置中的pid是否一致
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
```



## venus-market设置

```bash
./venus-market storage-deals set-ask --price 0.000000001 --verified-price 0 --min-piece-size 256B --max-piece-size 32GiB --miner f036816 # 设置费用

./venus-market actor set-addrs --miner=f01177 /ip4/192.168.200.34/tcp/58418 # 地址为nginx负载的地址和端口

./venus-market net  listen # 查看preeid

./venus-market actor set-peer-id --miner=f036816 12D3KooWFDgz77oqCuNGu3JqXFMWruuWnogLjRZw36fHVQmdxFoo # 设置preeid


./venus-market retrieval-deals set-ask --price 0.0000001 --unseal-price 0.0000001 --payment-interval 100MiB --payment-interval-increase 100MiB --payment-addr t3ss4g66knxijaju6rotq7fy4bearig2ihfo43btivpxee4hc2nxpaxhu4xlt44oat37sc7gmmcdicmzul4jjq
```

## market-client设置

```bash
./market-client run --node-url /ip4/192.168.200.104/tcp/39812 --node-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4iLCJwZXJtIjoiYWRtaW4iLCJleHQiOiIifQ.fgdluPDm5RIOKWig9ZVv8OK4NUdayQycBtsgljE-nw8 --messager-url /ip4/192.168.200.104/tcp/39812 --messager-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4iLCJwZXJtIjoiYWRtaW4iLCJleHQiOiIifQ.fgdluPDm5RIOKWig9ZVv8OK4NUdayQycBtsgljE-nw8 --auth-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiYWRtaW4iLCJwZXJtIjoiYWRtaW4iLCJleHQiOiIifQ.fgdluPDm5RIOKWig9ZVv8OK4NUdayQycBtsgljE-nw8 --wallet-url /ip4/0.0.0.0/tcp/5678/http --wallet-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIiwiYWRtaW4iXX0.aJFHKVId_uPbVa3r2pBvDL8xym3faf6bhXFD-11bcis # 初始化

./market-client retrieval retrieve --provider t036816 --maxPrice 0.001fil bafykbzaceaz2muq5uw3l5xsgzvunlfbpu3avuev6ohna55eig7im5clcl6mgo aaa # 检索文件

./market-client retrieval cancel-retrieval --deal-id  1654593434600505342 # 检索异常中断需要主动cancel
```

