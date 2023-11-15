
[TOC]


ps -aux | grep <name>

netstat -nap | grep <pid>

df -TH

## 组件默认端口

```
Auth 						8989		http:/127.0.0.1:8989
Gateway 				45132   /ip4/0.0,0.0/tcp/45132
Daemon / node 	3453  	/ip4/0.0.0.0/tcp/3453
Miner 					12308
Sealer 					2345
Worker 					3456
Messager				39812   /ip4/0.0.0.0/tcp/39812
Wallet          5678   	/ip4/0.0.0.0/tcp/5678/http
Market          41235   /ip4/0.0.0.0/tcp/41235
```

测试端口是否打开：`telnet 10.50.110.59 12308`

## venus

### 下载安装

```
git clone https://github.com/filecoin-project/venus.git
make deps
make
```



### 运行venus

1. 启动

   ```shell
   nohup ./venus daemon --network=force --auth-url=http://127.0.0.1:8989 > venus.log 2>&1 &
   
   nohup ./venus daemon --network=calibrationnet --auth-url=http://127.0.0.1:8989 > venus.log 2>&1 &
   
   ```

2. 检查节点的连接（venus swarm peers）

   1. 如果在force网络，需要连接创世节点，同步最新的链。

      ```
      # 查看创世节点（在创世节点服务器）
      ./lotus net listen
      
      /ip4/192.168.200.125/tcp/43391/p2p/12D3KooWENAnMn9aJL6xyox75snYnmytMusXWw8VA48XXR8Y2wFc
      
      # 连接创世节点（回到venus）
      ./venus swarm connect /ip4/192.168.200.125/tcp/43391/p2p/12D3KooWENAnMn9aJL6xyox75snYnmytMusXWw8VA48XXR8Y2wFc
      ```

3. 使用`tail -f venus.log` 或 `./venus sync status` 检查同步过程中是否有任何错误。

4. 查看钱包`./venus wallet ls`。如果没有，需要在venus-wallet创建wallet

5. 从其他wallet转账给当前wallet（./lotus send t01056<miner id> 10000）

6. 检查钱包余额（.venus wallet balance <wallet address>)

> 向当前节点的钱包转账，相当于在链后面添加，当前节点没有同步完成时，看不到这次转账，链同步完成后才能看到，所有需要在链同步完成后验证钱包余额。

7. 检查miner状态

   ```
   ./lotus state miner-info t01056
   ```

8. 检查message状态

   ```
   ./lotus state search-msg <msg id>
   ./lotus state search-msg wait-msg <msg id>
   ```

9. 获取actor

   ```
   ./lotus state get-actor <actor id>
   ```

   

## venus-auth

安装：

```
nohup ./venus-auth run > auth.log 2>&1 &
```



功能：

**管理其他venus组件使用的JWT令牌**

1. token：矿工请求链服务的通行证，具有权限级别的划分
2. user：venus链服务对象，接入链服务的某个或多个矿工的唯一身份标识（token通过user逻辑分组）
3. miner：可以为一个用户绑定多个miner
4. signer：具有签名功能的地址，与user绑定。一个user可以有多个signer。用于多用户间互相签名。

## user创建流程

1. 首先修改mysql配置
2. 创建一个admin user，用于云上组件
3. 创建一个sign user，用于链下组件（vsm，worker，wallet）

```
[db]
  # 支持: badger (默认), mysql
  type = "mysql"
  DSN = "root:admin123@(192.168.200.119:3306)/calib_venus_auth?parseTime=true&loc=Local&charset=utf8mb4&collation=utf8mb4_unicode_ci&readTimeout=10s&writeTimeout=10s"
  # conns 1500 concurrent
  maxOpenConns = 64
  maxIdleConns = 128
  maxLifeTime = "120s"
  maxIdleTime = "30s"
```



```
1. add user
./venus-auth user add test-user01

2. get
./venus-auth user get test-user01

3. gen token for user
./venus-auth token gen --perm <admin> <test-user01>

4.
./venus-auth token list

##5. gen miner

6. bind miner for user
./venus-auth user miner add <USER> <MINER_ID>


sign user need active
```



## venus-miner

#### address

```
1. update  有矿工加入或退出矿池，或者矿工信息变化时，需要重新从venus_auth拉取miner list
2. list     
3. state
4. start  <miner_id>  开始某个矿工的出块流程
5. stop   <miner_id>  暂停某个矿工的出块流程
6. warmup
```

### 初始化

Token: admin user token

```
./venus-miner init --api /ip4/127.0.0.1/tcp/3453 --gateway-api /ip4/127.0.0.1/tcp/45132 --auth-api http://127.0.0.1:8989 --token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoidXNlcjAxIiwicGVybSI6ImFkbWluIiwiZXh0IjoiIn0.zeaAgQcaPuVrEnOVMY2HQbREdjk9klQiJe7ORM4qnyY --slash-filter mysql --mysql-conn "root:admin123@(192.168.200.119:3306)/calib_venus_miner?parseTime=true&loc=Local&charset=utf8mb4&collation=utf8mb4_unicode_ci&readTimeout=10s&writeTimeout=10s"

./venus-miner init
--api=/ip4/<VENUS_DAEMON_IP>/tcp/PORT \
--gateway-api=/ip4/<VENUS_GATEWAY_IP>/tcp/PORT \
--auth-api <http://VENUS_AUTH_IP:PORT> \
--token <SHARED_ADMIN_AUTH_TOKEN> \
--slash-filter local
```

### 启动

`venus-miner`启动后会从`venus-auth`请求矿工列表，并对每个矿工执行出块的必要检查，如：钱包服务，WinningPoSt服务是否正常等。

```
$ nohup ./venus-miner run > miner.log 2>&1 &
```



### 检查矿工列表：

（如果没有在auth中配置的矿工，需要检查auth中，user是enabled，且user已绑定miner）

```
./venus-miner address state
[
	{
		"Addr": "<MINER_ID>",
		"IsMining": true,
		"Err": null
	}
]
```

## venus_messager

### 启动

```
nohup ./venus-messager run > msg.log 2>&1 &

./venus-messager run --auth-token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoidXNlcjAxIiwicGVybSI6ImFkbWluIiwiZXh0IjoiIn0.zeaAgQcaPuVrEnOVMY2HQbREdjk9klQiJe7ORM4qnyY --db-type mysql --mysql-dsn "root:admin123@(192.168.200.119:3306)/calib_venus_messager?parseTime=true&loc=Local&charset=utf8mb4&collation=utf8mb4_unicode_ci&readTimeout=10s&writeTimeout=10s"
```

### msg

```
1. search       # 查询消息 msg search --id=<messgae id> or --cid=<message cid>
2. list         # 列出相同address的msg msg list -- from <address>
3. list-fail    # 列出失败的消息 可能是签名失败或者gas估算失败
4. list-blocked  # 列出一段时间未连接的消息
5. update-filled-msg   # 更新一个已上链消息（但数据库的状态未更新）的状态 	msg update_filled_msg --id=<message id>
6. update-all-filled-mas  # 更新所有已上链消息（但数据库的状态未更新）的状态  msg update_all_filled_msg
7. replace    # 替换消息 ./venus-messager msg replace --gas-feecap=[gas-feecap] --gas-premium=[gas-premium] --gas-limit=[gas-limit] --auto=[auto] --max-fee=[max-fee] <message-id>

8. wait         # 等待消息的结果  msg wait <message id>
9. republish    # 通过id重新发布消息 msg republish <message id>
10. mark-bad    # 手动标记异常的消息
11, clear-unfill-msg
12. recover=failed-msg
```

### address

```
search
list
del
forbidden   # 冻结地址，不再接收推送消息
active      # 激活被冻结的地址
set-sel-msg-num  # 设置地址一轮推送消息的最大数量
set-fee-params   # 设置地址fee相关参数
```

## venus-gateway  

作用：

1. 连接 **需要签名的共享组件** 和 **提供签名服务的venus-wallet**

好处：

1. venus-wallet启动时，只需连接gateway，并告诉gateway其包含的地址私钥。这样就不需要向多个组件注册。
2. 共享组件需要签名时，只需向gateway发送签名请求，定位wellet服务这种操作完全托管给gateway

### 交互模式

auth管理的账号时生产者和消费者间的桥梁。venus-gateway从venus-auth获取对应 `miner` 或 `signer` 的账号，然后从维持的消费者列表中找到对应的消费者（`venus-wallet` 或 `venus-cluster`）处理消息。消费者在启动时将自身账号信息注册到 `venus-gateway`。

1. 与消息消费者交互（venus-wallet/venus-cluster）
   1. venus-cluster消费的消息是`ComputeProof`计算`WinningPoSt`证明数据。
2. 与消息生产者交互（venus-miner/venus-messenger）
   1. 对外提供api

### 启动

```
nohup ./venus-gateway --listen /ip4/0.0.0.0/tcp/45132 run  --auth-url http://127.0.0.1:8989 venus-gateway.log 2>&1 &
```

### miner

```
list
state <miner-id>
```

### wallet

```
list
state <wallet-account>
list-support
```





## venus-market

### 存储流程

1. 启动venus-market和market-client
2. 代理miners的libp2p监听服务
3. （通过market）为miners挂单
4. 指定miner发单（通过client导入待存储的数据；根据需求选择合适挂单；发起存储订单）

### 检索流程

1. 启动venus-market和market-client
2. 设置检索价格和收款地址（存储供应商通过venus-market设置检索挂单）
3. 提交数据检索订单

### 使用链服务和venus-wallet启动方式 

--signer-url= wallet url

--signer-token=wallet token（`./venus-wallet auth api-info --perm=sign）`

Token: admin user token

```
./venus-market run --auth-url=http://127.0.0.1:8989 --node-url=/ip4/0.0.0.0/tcp/3453 --messager-url=/ip4/127.0.0.1/tcp/39812 --cs-token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoidXNlcjAxIiwicGVybSI6ImFkbWluIiwiZXh0IjoiIn0.zeaAgQcaPuVrEnOVMY2HQbREdjk9klQiJe7ORM4qnyY --signer-url=/ip4/127.0.0.1/tcp/5678/http --signer-token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIiwiYWRtaW4iXX0.4ut5okvYCS60CyOcQCue4Jq9i2-N_tbHHStmtmNurcw --signer-type="wallet" --mysql-dsn "root:admin123@(192.168.200.119:3306)/calib_venus_market?parseTime=true&loc=Local&charset=utf8mb4&collation=utf8mb4_unicode_ci&readTimeout=10s&writeTimeout=10s"
```

启动脚本配置：

```
nohup ./venus-market run > venus-market.log 2>&1 &
```



### 通用配置

```
[[Miners]]
  Addr = "f04685"
  Account = "user02"
  
[API]
	ListenAddress = "/ip4/0.0.0.0/tcp/41235"
```

创建多层目录：mkdir -p /mnt/pieces

```
[PieceStorage]
  [[PieceStorage.Fs]]
    Name = "local"
    Enable = true
    # 自己创建一个存储目录
    Path = "/mnt/pieces"
# 以下如果为空，不用填写
#  [[PieceStorage.S3]]
#    Name = "oss"
#    Enable = false
#    EndPoint = ""
#    AccessKey = ""
#    SecretKey = ""
#    Token = ""
```

也可以通过命令配置：

```
# 本地文件系统存储
./venus-market piece-storage add-fs --path="/piece/storage/path" --name="local"

# 对象存储
./venus-market piece-storage add-s3 --endpoint=<url> --name="oss"
```

```
PublishMsgPeriod = "10s"
```





### 代理miners的libp2p监听服务

目标：将miner市场服务的入口设置为当前运行的`venus-market`实例

1. 查询venus-market的监听地址

```
./venus-market net listen

/ip4/127.0.0.1/tcp/58418/p2p/12D3KooWQftXTGFBKooKuyaNkugapUzi4VmjxEKTgkpsNCQufKBK
/ip4/192.168.19.67/tcp/58418/p2p/12D3KooWQftXTGFBKooKuyaNkugapUzi4VmjxEKTgkpsNCQufKBK
/ip6/::1/tcp/49770/p2p/12D3KooWQftXTGFBKooKuyaNkugapUzi4VmjxEKTgkpsNCQufKBK
```

2. 将market的Mutiaddrs和peerid赋值给miner

   ```
   ./venus-market actor set-addrs --miner=t01041 /ip4/192.168.19.67/tcp/58418
   Requested multiaddrs change in message bafy2bzaceceqgxmiledunzjwbajpghzzn4iibvxhoifsrz4q2grzsirgznzdg
   
   ./venus-market actor set-peer-id --miner=f01041 12D3KooWQftXTGFBKooKuyaNkugapUzi4VmjxEKTgkpsNCQufKBK
     Requested peerid change in message bafy2bzacea4ruzf4hvyezzhjkt6hnzz5tpk7ttuw6jmyoadqasqtujypqitp2
   ```

3. 等待消息上链后(./venus sync status)，查看miner的代理信息

   ```
   ./venus-market actor list
   
   ./venus-market actor info --miner t01041
   peers: 12D3KooWQftXTGFBKooKuyaNkugapUzi4VmjxEKTgkpsNCQufKBK
   addr: /ip4/192.168.19.67/tcp/58418
   ```

   ```
   ./venus state miner-info t01056
   
   Available Balance: 71993.891769530487839471 FIL
   Owner:	t01055
   Worker:	t01055
   PeerID:	<nil> #设置好之后会有值
   Multiaddrs:   #设置好之后会有值
   Consensus Fault End:	-1
   SectorSize:	8 MiB (8388608)
   Byte Power:   192 MiB / 3.539 GiB (5.2980%)
   Actual Power: 192 Mi / 30.5 Gi (0.6139%)
   
   Proving Period Start:	177048 (0 seconds ago)
   ```

### 存储挂单

```
./venus-market storage-deals set-ask --price=0.01fil --verified-price=0.02fil --min-piece-size=512b --max-piece-size=512M --miner=t04685
./venus-market storage-deals get-ask --miner=t04685
```

### 检索挂单

```
./venus-market retrieval-deals set-ask --price 0.0fil --unseal-price 0.0fil --payment-interval 1MiB --payment-addr <t04685>
./venus-market retrieval-deals get-ask --miner <t04685>
```



## market-client

wallet token：

```
./venus-wallet auth api-info --perm=sign
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIl19.RlrXvEThTRfIUKK3TbEdcyFkItSbF3NqvDfwoQqPpxU:/ip4/0.0.0.0/tcp/5678/http
```

查看wallet address：

```
./venus-wallet new bls

./venus-wallet list
```

运行（**droplet使用本地的venus-wallet进行签名**）：

- --addr: `./venus-wallet new bls`创建的钱包地址
- --auth-token、--messager-token和--node-token：使用`./sophon-auth token list`，找一个perm为sign/write/read权限的token，三个参数使用一样的token值。token的值类似`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoidGVzdC0xMiIsInBlcm0iOiJzaWduIiwiZXh0IjoiIn0.aKvU8GGC4FI4rZnDSWwkvLRjxuevVln1qXaPV70tKOA`
- --signer-toke：`./venus-wallet auth api-info --perm=sign`获取的wallet token（只需要“：”之前的）

```
./droplet-client run \
  --addr=<wallet address> \
  --auth-token=<sign token> \
  --messager-token=<sign token> \
  --messager-url=/ip4/127.0.0.1/tcp/39812 \
  --node-token=<sign token> \
  --node-url=/ip4/127.0.0.1/tcp/3453 \
  --signer-type=wallet \
  --signer-url=/ip4/127.0.0.1/tcp/5678/http \
  --signer-token=<wallet token>

```
```
nohup ./droplet-client run > market-client.log 2>&1 &
```

### 发起存储单

1. 导入待存储文件

   ```
   ./droplet-client data import <file path>
   ```

2. 选择挂单

   ```
   ./droplet-client storage asks query f04658
   ```

3. 发起存储单

   ```
   ./droplet-client storage deals init
   ```

4. 查看订单

   ```
   ./droplet-client storage deals list
   ```

### 发起检索单

1. 提交检索单

```
./droplet-client retrieval retrieve --provider t01020 bafk2bzacearla6en6crpouxo72d5lhr3buajbzjippl63bfsd2m7rsyughu42 test.txt
```



## venus-wallet

功能：钱包用于存储私钥，私钥加密后存储在本地数据库。

1. 第一次启动时需要设置钱包密码，所有私钥公用这一个密码加密。

2. 加密的私钥在使用之前需要unlock

3. 创建钱包后需要有fil的钱包为其转账，钱包地址必须有足够**余额**，才能进行后续同步链等操作。

   ### run

   ```
   nohup ./venus-wallet run > venus-wallet.log 2>&1 &
   
   # 修改配置文件:
   [API]
     # 本地进程http监听地址
     ListenAddress = "/ip4/0.0.0.0/tcp/5678/http"
     
   [APIRegisterHub]
     # gateway的URL，不配置就不会连接gateway
     RegisterAPI = ["/ip4/127.0.0.1/tcp/45132"]
     # wallet处于用户维度，应该使用sign用户
     Token = ""
     # sign user name
     SupportAccounts = ["user01"]
   ```

   ### ./venus-wallet auth（JWT）

   ```
   $ ./venus-wallet auth api-info --perm sign
   
   #res
   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIiwiYWRtaW4iXX0.q3xz5oucOoT3xwMTct8pWMBrvhi_gizOz6QBgK-nOwc:/ip4/0.0.0.0/tcp/5678/http
   ```


## venus-cluster

### 修改系统时间

https://www.jianshu.com/p/9e1be6ec5c83

```
date
tzselect
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date
```



### 安装

```
git clone https://github.com/ipfs-force-community/venus-cluster.git

apt install libssl-dev
apt install openssl-devel
apt install libidn11-dev

cd venus-cluster
make all
```

### 创建miner

1. 初始化

   ```
   ./dist/bin/venus-sector-manager daemon init
   ```

2. 修改配置文件

   ```
   vim ~/.venus-sector-manager/sector-manager.cfg
   ```

3. 创建矿工号

   如果不加--exid，每次创建出的都是相同miner id

   ```
   ./venus-sector-manager util miner create --from=f3vwcu7foxpdulvj2byp4yyls2w372x3qiizai3cbdvu6fyfgwu2mpaep2totrut4j2ikzfoqllnmyty4otwsq --sector-size=32GiB --exid <随机数>
   ```

   如果create miner时失败，需要到gateway查询：

   ```
   ./venus-gateway wallet list
   ```

   如果结果为空，说明venus没注册到gateway，查看日志：

   ```
   WalletSign error password not set
   ```

   可能原因是wallet重启后没有unlock，输入password解决。

4. 查看deadline开始时间，循环创建矿工，直到deadline满足要求。

   ```
   ./venus-sector-manager util sealer proving --miner 4682 deadlines
   ./venus-worker worker -c venus-worker.toml list
   ```

5. 运行

   ```
   nohup ./dist/bin/venus-sector-manager daemon run --poster --miner --listen 0.0.0.0:1789 --ext-prover >venus-sector-manager.log 2>&1 &
   ```

### 配置文件

```
# Default config:
[Common]
[Common.API]
Chain = "/ip4/0.0.0.0/tcp/3453"
Messager = "/ip4/0.0.0.0/tcp/39812"
Market = "/ip4/127.0.0.1/tcp/41235"
Gateway = ["/ip4/0.0.0.0/tcp/45132"]
# sign user token
Token = ""
```

本地订单piece存储：

```
# 每一个本地存储目录，对应一个Common.PieceStores配置块
[[Common.PieceStores]]
# 与market中配置保持一致
Name = "local"
Path = "/piece/storage/path"

# 扇区持久化存储
[[Common.PersistStores]]
Name = "storage"
Path = "/storage-nfs-3/zsk/<miner-id>"
# 允许进行分配的矿工列表
# 不设置时，相当于允许全部；设置时，相当于白名单
# 只需要设置数字位，无需字母
AllowMiners = [1056]
```

使用mysql存储sector：

```
# 配置插件存在的目录
# plugins: plugin-qiniu-store.so、plugin-sqlxdb.so
[Common.Plugins]
Dir = "/root/venus-cluster/dist/bin/dist/bin"

[Common.DB]
Driver = "plugin"

# 已弃用
#[Common.DB.Mongo]
#DSN = "mongodb://192.168.200.164:27017/duan-cluster-139?directConnection=true&serverSelectionTimeoutMS=2000"
#DatabaseName = "duan-cluster-139"

[Common.DB.Plugin]
PluginName = "sqlxdb"
[Common.DB.Plugin.Meta]
dsn = "root:admin123@(192.168.200.119:3306)/calib_venus_sector_manager?parseTime=true&loc=Local&charset=utf8mb4&collation=utf8mb4_unicode_ci&readTimeout=10s&writeTimeout=10s"
```

如果之前存储在本地数据库，需要迁移到mysql：

```
从本地数据库导入mysql

./venus-sector-manager util migrate --from badger --to plugin
```

Miners：

```
[[Miners]]
# SP` actor id
Actor = 1056
```

Sector：控制扇区的分配策略

`MinNumber:`扇区的最小编号，与InitNumber区别：

1. 任何时刻，都不会分配`<=MinNumber`的扇区编号
2. `MinNumer`在集群运行过程中调整，可以提高`MinNumber`，降低不会产生效果

```
[Miners.Sector]
InitNumber = 0
# 见上文
MinNumber = 0
# 扇区编号上限
MaxNumber = 1000000
# 是否允许分配扇区
Enabled = true
# 是否允许分配订单
EnableDeals = true
# cc扇区的生命周期，单位为天
LifetimeDays = 540
# Sector模块日志的详细程度，false为精简日志
Verbose = false
```

Snap：控制 `Snapdeal` 生产策略

```
[Miners.SnapUp]
Enabled = false
# wallet address
# miner belonged to chain, all block knowd this miner
Sender = "t3xep7oywbmwseqwrqbkzhsuzhb2c7huhlj3g37p3eohbla35qyebj2z3ytlolh6ogrxc746jveqzs73xlhqwa"
SendFund = true
GasOverEstimation = 1.2
GasOverPremium = 0.0
GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""
MessageConfidence = 15
ReleaseConfidence = 30
# SnapUp 提交重试策略
[Miners.SnapUp.Retry]
MaxAttempts = 10
PollInterval = "3m0s"
APIFailureWait = "3m0s"
LocalFailureWait = "3m0s"
```

Commitment：通用消息提交策略

```
[Miners.Commitment]
Confidence = 10
```

Pre：Pre消息提交策略

```
[Miners.Commitment.Pre]
# wallet address
Sender = "t3xep7oywbmwseqwrqbkzhsuzhb2c7huhlj3g37p3eohbla35qyebj2z3ytlolh6ogrxc746jveqzs73xlhqwa"
# 提交上链消息时是否从 Sender 发送必要的资金
SendFund = false
# 单条提交消息 Gas 估算倍数
GasOverEstimation = 1.2
# 单条提交消息 GasPremium 估算倍数
GasOverPremium = 0.0
# 单条提交消息 GasFeeCap 限制
GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""

# 聚合提交的策略配置块
[Miners.Commitment.Pre.Batch]
# 是否启用聚合提交
Enabled = false
Threshold = 16
MaxWait = "1h0m0s"
CheckInterval = "1m0s"
GasOverEstimation = 1.2
GasOverPremium = 0.0
GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""
```

Prove：Prove消息提交策略

- 配置项和作用与 `Miners.Commitment.Pre`内的完全一致。

Terminate：TerminateSectors消息提交策略

- 配置项和作用与 `Miners.Commitment.Pre` 内的基本一致。实际场景中发送此类消息不会很频繁，建议配置单条提交模式，使用聚合提交模式时，`Threshold` 建议配置较小的值，保证消息及时上链。

PoSt：配置windowPoSt

```
[Miners.PoSt]
# wallet address
Sender = "t3xep7oywbmwseqwrqbkzhsuzhb2c7huhlj3g37p3eohbla35qyebj2z3ytlolh6ogrxc746jveqzs73xlhqwa"
Enabled = true
# 是否对扇区文件强校验
StrictCheck = true
# 是否开启并行证明
Parallel = false
# WindowPoSt 消息的Gas估算倍数
GasOverEstimation = 1.2
GasOverPremium = 0.0
GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""
# 消息的稳定高度
Confidence = 10

# 提交 WindowPoSt 证明结果的稳定高度，选填项，数字类型
# 这个值决定了需要等待多少个高度才认定链进入稳定状态，可以提交 WindowPoSt 证明结果
# 提交高度为 deadline.Open + SubmitConfidence
# 此值设定越小，会越早启动，但同时也越容易受到分叉影响
# 当设置为 0 时，会使用默认值 4
SubmitConfidence = 0

# 启动 WindowPoSt 的稳定高度，选填项，数字类型
# 这个值决定了需要等待多少个高度才认定链进入稳定状态，可以启动 WindowPoSt 任务
# 启动高度为 deadline.Challenge + ChallengeConfidence
# 此值设定越小，会越早启动，但同时也越容易受到分叉影响
# 当设置为 0 时，会使用默认值 10
ChallengeConfidence = 0

# 单次 Recover 允许包含的扇区数量上限，选填项，数字类型
# 设置为 0 时，不会进行限制
MaxRecoverSectorLimit = 0

# 单条 PoSt 消息中允许的最大 Parition 数量
MaxPartitionsPerPoStMessage = 0

# 单 Recover 消息中允许的最大 Parition 数量
MaxPartitionsPerRecoveryMessage = 0
```

Proof：配置 WinningPoSt Proof

```
[Miners.Proof]
Enabled = true
```

Sealing：配置sealing策略

```
[Miners.Sealing]
# sealing过程需要持续的高度，在筛选订单的时候会将订单的开始限定为当前高度+该值
SealingEpochDuration = 0
```

# venus-worker

```
htop
nvtop
numactl -H
df -TH
```

## 设置大页内存

分配320G的内存空间，且内存挂载到磁盘（`/mnt/huge/`）。

机器重启后需要重新生成大页内存。

```
mount -t hugetlbfs -o mode=0777,pagesize=1G none /mnt/huge/
cd /mnt/huge/

# 创建10个32G大小到文件，用于填充刚才分配的内存空间。
echo 80 > /sys/devices/system/node/node0/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node2/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node3/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node4/hugepages/hugepages-1048576kB/nr_hugepages

# 可以看到创建出的5个文件
ls /mnt/huge

# 再次创建5个32G文件，填充剩余内存
echo 80 > /sys/devices/system/node/node5/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node6/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node7/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node8/hugepages/hugepages-1048576kB/nr_hugepages
echo 80 > /sys/devices/system/node/node9/hugepages/hugepages-1048576kB/nr_hugepages
```

## gen_cache_and_param生成param

下载`proof-utils-846a66-2021-11-29_17-04-30-md5-a7b9067a424151eb7cdc6166638e2424.tar.gz`

使用tar包里面的`gen_cache_and_param`和`p3out-blst-32g.dat`这两个可执行文件

gen_cache_and_param创建出的文件放在`/dev/shm`

```
# 以下命令执行时间长
     hugepage --num 10 --size 32GiB
./gen_cache_and_param p4-param --size 32GiB
./gen_cache_and_param wdpost-param --size 32GiB
./gen_cache_and_param parent-cache --size 32GiB
./gen_cache_and_param p4-lcs -h
./gen_cache_and_param p4-lcs --p3-output p3out-blst-32g.dat --size 32GiB

# 查看通过gen_cache_and_param创建出的文件
ls /dev/shm
```

## 创建`/mnt/mount/wenjie/{miner_id}`目录

```
df -TH

lsblk

# 查看占用空间最大的目录
cd /mnt/mount
du -sh *
# 进入占用空间最大的目录，删除目录下的内容

# 创建worker配置文件
vim venus-worker.toml
# 修改sealing_thread文件个数

mkdir /mnt/mount/wenjie/4682
root@200-6:/mnt/mount/wenjie# ll /dev/shm

# 将venus-worker上传到当前目录（~/wenjie）
gen_cache_and_param  p3out-blst-32g.dat  venus-worker
```

创建test.sh脚本

```
for i in {1..20}
do
   ./venus-worker store sealing-init -l "/mnt/mount/wenjie/4685/test$i"
done
```

## venus-worker.toml

```
vim venus-worker.toml

# 需要与sector-manager.cfg中的配置保持一致
[[attached]]
name = "storage"
location = "/storage-nfs-3/zsk/4682"
[attached_selection]
# enable_space_weighted = false
```

```
vim ~/.venus-sector-manager/sector-manager.cfg

# 与venus-worker.toml保持一致
[[Common.PersistStores]]
Name = "storage"
Path = "/storage-nfs-3/zsk/4682"
Strict = false
ReadOnly = false
Weight = 0
AllowMiners = [4682]
#DenyMiners = [3, 4]
#Plugin = ""
#PluginName = "s3store"
[Common.PersistStores.Meta]
#SomeKey = "SomeValue"
```

启动

```
nohup ./venus-worker daemon -c venus-worker.toml >venus-worker.log 2>&1 &
```

查看deadlines：

```
./venus-sector-manager util sealer proving --miner 4685 deadlines
```

查看扇区状态：

```
 ./venus-sector-manager util sealer proving --miner 4685 check 31
```

查看/mnt/mount/wenjie/<miner id>/test1~test20的20个文件state：

```
./venus-worker worker -c venus-worker.toml list
```

force-ext-processors:

```
[processors.limitation.concurrent]
add_pieces = 2
tree_d = 2
pc1 = 4
pc2 = 1
c2 = 1
```

venus_worker:

```
[processors.limitation.concurrent]
add_pieces = 100
pc1 = 100
pc2 = 1
c2 = 20
tree_d = 1
snap_encode = 1
snap_prove = 1
```

准备数据：

```
venus-worker processor add_pieces
venus-worker processor tree_d
force-ext-processors processor pc1 --huge_mem_path_32g /mnt/huge --huge_mem_page_count_32g 10
force-ext-processors processor pc1 --huge_mem_path_32g /mnt/huge --huge_mem_page_count_32g 10
force-ext-processors processor pc2
```

## 各阶段日志

Pre-commit:

```
2023-04-23T16:59:14.526+0800	DEBUG	commitmgr	commitmgr/commitmgr.go:776	handle message receipt	{"sector-id": {"Miner":1007,"Number":366}, "stage": "pre-commit", "msg-cid": "bafk4bzacidjgoezzqvqzah7l4xpu3w5j3jk7ngwyy262hd5vuwtlhbizxfnionxisow47ekolg3rowullveopxgnjalqb4jmi7ywprks65wsvcgb", "msg-state": "OnChainMsg", "msg-signed-cid": "bafy2bzacec5zqhuh6ruqtyknqhcdqxna2g2k4ow6ww5mvl6xoeru5xcxq6mmw"}
```

Prove-commit

```
2023-04-23T16:59:21.623+0800	DEBUG	commitmgr	commitmgr/commitmgr.go:776	handle message receipt	{"sector-id": {"Miner":1007,"Number":358}, "stage": "prove-commit", "msg-cid": "bafk4bzacidqtxakdmgy3juei5mp5gbjqlmy2w5xfk7soogzvhojcucwtq2islyapsw5ugyudejxdeujldgh2n4ve4yrmtb7elkfecyy67usok3lv", "msg-state": "OnChainMsg", "msg-signed-cid": "bafy2bzacear3zwk3o3d3afidh6t4kbujcwruhuvrinwbb7ejhmjv2ut77lg3e"}
```

Submitted window post:

```
2023-04-23T16:59:05.091+0800	INFO	poster	poster/runner.go:176	Submitted window post: bafy2bzacebeukpscmz3rb2werpgs7n2qbouxveybcg4hnlbiqt5memx4bqvmq	{"mid": "1007", "ddl-idx": 30, "ddl-open": "8722", "ddl-close": "8782", "ddl-challenge": "8702", "stage": "submit-post", "posts": 1, "tsk": "{ bafy2bzaced2cctgxqxko6tj5n4vbkas4a7hghx3vhu2mzdnoilil2zim4zy6g }", "tsh": "8727", "comm-epoch": "8702", "msg-id": "bafy2bzacebeukpscmz3rb2werpgs7n2qbouxveybcg4hnlbiqt5memx4bqvmq"}
```

declare faults recovered message published:

````
2023-04-23T13:36:35.050+0800    WARN    poster  poster/runner.go:573    declare faults recovered message published      {"mid": "1005", "ddl-idx": 45, "ddl-open": "8332", "ddl-close": "8392", "ddl-challenge": "8312", "tsk": "{ bafy2bzacedyvvt4tafhwbwx7xjd3554ay72rtgalkdc63ki2awcq6zryitt3y }", "tsh": "8322", "decl-index": 47, "stage": "check-recoveries", "partitions": "6", "mid": "bafy2bzacedtzdyngfgyrro7w2a2ecztueqfj2bg7tyt3pntl2ku5j5acaka6w-45-8332"}
````

## force-ext-processors配置

#### pc1:

- bin：外部执行器 可执行文件路径
- args：外部执行器 参数
- numa_preferred：0/1，希望集中numa 0区域完成pc1
- env：外部执行器 附加环境变量
- concurrent：并发任务数量上限

### 环境变量：

- FORCE_SECTOR_SIZE="34359738368"：32GiB
- FIL_PROOFS_HUGEPAGE_START_INDEX="0" / “10”
- FIL_PROOFS_CORE_START_INDEX="0" / “24”

```
[[processors.pc1]]
bin="/root/wenjie/force-ext-processors"
args = ["processor", "pc1", "--huge_mem_path_32g", "/mnt/huge", "--huge_mem_page_count_32g", "10"]
numa_preferred = 0
envs = { FORCE_SECTOR_SIZE="34359738368", FIL_PROOFS_HUGEPAGE_START_INDEX="0", FIL_PROOFS_CORE_START_INDEX="0", FIL_PROOFS_USE_MULTICORE_SDR="1", FIL_PROOFS_MULTICORE_SDR_PRODUCERS="1", FORCE_HUGE_PAGE="1" }
concurrent = 5

[[processors.pc1]]
bin="/root/wenjie/force-ext-processors"
args = ["processor", "pc1", "--huge_mem_path_32g", "/mnt/huge", "--huge_mem_page_count_32g", "10"]
numa_preferred = 1
envs = { FORCE_SECTOR_SIZE="34359738368", FIL_PROOFS_HUGEPAGE_START_INDEX="10",FIL_PROOFS_CORE_START_INDEX="24",  FIL_PROOFS_USE_MULTICORE_SDR="1", FIL_PROOFS_MULTICORE_SDR_PRODUCERS="1", FORCE_HUGE_PAGE="1" }
concurrent = 5

[[processors.pc2]]
bin="/root/wenjie/force-ext-processors"
concurrent = 1
envs = { FIL_PROOFS_USE_GPU_COLUMN_BUILDER="1", FIL_PROOFS_USE_GPU_TREE_BUILDER="1", CUDA_VISIBLE_DEVICES="0",BELLMAN_CUSTOM_GPU="NVIDIA GeForce RTX 3080:8704",FIL_PROOFS_MAX_GPU_COLUMN_BATCH_SIZE="4000000",FIL_PROOFS_MAX_GPU_TREE_BATCH_SIZE="4000000" }
```

- **CUDA_VISIBLE_DEVICES=1(选择使用哪个gpu，GPU1，2的默认编号为为0，1)**
- BELLMAN_CUSTOM_GPU：指定GPU型号

```
[[processors.c2]]
bin="/root/wenjie/force-ext-processors"
args = ["processor", "c2", "--sector_size", "32GiB"]
concurrent = 1
envs = { BELLMAN_LOAD_SHM="1", BELLMAN_USE_MAP_BUFFER="1", BELLMAN_CIRCUIT_N="1", BELLMAN_PROOF_N="1", CUDA_VISIBLE_DEVICES="0",BELLMAN_CUSTOM_GPU="NVIDIA GeForce RTX 3080:8704" }
envs = {"RUST_LOG"="info"}
```

## c2外包

### worker.toml

```
[[processors.c2]]
bin="/cluster_c2_plugin"
args = ["run", "--gpuproxy-url", "http://192.168.200.18:18888","--log-level", "trace"]
```

### 运行gpuproxy

1. Gpuproxy

   ```
   # 1. 创建fs-resource-path目录
   mkdir -p /storage-nfs-4/wenjie/fs-gpuproxy-25
   
   # 2. 创建mysql数据库calib_gpuproxy
   
   # 3. 运行脚本
   vim gpuproxy.sh
   nohup ./gpuproxy --url 0.0.0.0:18888 --log-level info run --db-dsn="mysql://root:admin123@192.168.200.119:3306/calib_gpuproxy" --disable-worker --fs-resource-path=/storage-nfs-4/wenjie/fs-gpuproxy-25 --resource-type=fs > gpuproxy.log 2>&1 &
   
   # 4. 查看task
   ./gpuproxy task list
   ```

2. Gpuproxy_worker

   注意：CUDA_VISIBLE_DEVICES=1(选择使用哪个gpu，枚举为0，1)

   ```
   # 1. 创建一个空文件，用于记录 worker-id
   touch gpuproxy-worker.db
   
   # 2. 运行脚本
   vim gpuproxy-worker.sh
   FORCE_SECTOR_SIZE=34359738368 RUST_BACKTRACE=full RUST_LOG=info BELLMAN_LOAD_SHM=1 BELLMAN_USE_MAP_BUFFER=1 BELLMAN_CIRCUIT_N=1 BELLMAN_PROOF_N=1 CUDA_VISIBLE_DEVICES=1 ./gpuproxy_worker run --gpuproxy-url http://127.0.0.1:18888 --max-tasks=1 --allow-type=0  --resource-type=fs --fs-resource-path=/storage-nfs-4/wenjie/fs-gpuproxy-25
   
   
   --max-tasks=1 # worker同时并行的任务量
   --allow-type=0 # 指定C2
   ```



## gpuproxy每阶段时间统计

| acquired name/No | 0      | 1      |      | 3      |      | 5      |      |
| ---------------- | ------ | ------ | ---- | ------ | ---- | ------ | ---- |
| add_pieces       | <1s    | <1s    |      | <1s    |      | <1s    |      |
| tree_d           | <1s    | <1s    |      | <1s    |      | <1s    |      |
| pc1              | 152.2m | 152.1m |      | 152.3m |      | 152.3m |      |
| pc2              | 10.25m | 10.27m |      | 10.17m |      | 10.27m |      |
| c1               | <1s    | <1s    |      | <1s    |      | <1s    |      |
| C2               | 5.05m  | 5.05m  |      | 5.03m  |      |        |      |





## NV18升级

```
git brach
git pull
git checkout master
git checkout <version>
git log

make
ps -aux | grep venus_xxx
kill -9 <pid>

./venus_xxx.sh
tail -f venus_xxx.log
```

git reblog, git log

https://blog.csdn.net/COCOLI_BK/article/details/103344407

git fetch, git pull

https://blog.csdn.net/weixin_42343307/article/details/121239170



切换到commit：87705f4

```
git reflog
```

![image-20230222142917004](/Users/shukzhang/Library/Application Support/typora-user-images/image-20230222142917004.png)

```
git checkout 87705f4
git log # 可以看到最上面的commit开头是87705f4……，说明moving成功
git reflog # 再次查看，发现“moving from main to 87705f4
```

![image-20230222143036455](/Users/shukzhang/Library/Application Support/typora-user-images/image-20230222143036455.png)makr
