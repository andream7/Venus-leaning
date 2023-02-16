# Poster迁移Venus-cluster wdPost 多机

[TOC]



## 迁移

* init初始化cluster

```bash
./venus-sector-manager daemon init
```

* 修改cluster配置文件，需要修改放开注释的部分

```toml
# Default config:
[Common]
[Common.API]
Chain = "/ip4/47.243.169.165/tcp/1234/ws"
Messager = "/dns/cali-messager.filincubator.com/tcp/82/wss"
Market = "/ip4/127.0.0.1/tcp/41235"
Gateway = ["/dns/cali-gateway.filincubator.com/tcp/83/wss"]
Token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoieXItdGVzdCIsInBlcm0iOiJzaWduIiwiZXh0IjoiIn0.Vdao6fFQkNDuLRzdayS6U4QwnbDyPLDrttYjAvbc0Rk"
ChainEventInterval = "1m0s"
[[Common.PieceStores]]
#Name = "{store_name}"
#Path = "{store_path}"
#Plugin = "path/to/objstore-plugin"
[Common.PieceStores.Meta]
#SomeKey = "SomeValue"
#
[[Common.PersistStores]]
#Name = "theduan1"
#Path = "/storage02/cluster-cailbnet/duan-force-sealer/nfs/192.168.200.35"
#Strict = false
#ReadOnly = false
#Weight = 0
#Plugin = "path/to/objstore-plugin"
AllowMiners = [1447]
#DenyMiners = [3, 4]
[Common.PersistStores.Meta]
#SomeKey = "SomeValue"
[Common.MongoKVStore]
#Enable = false
#DSN = "mongodb://127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000"
#DatabaseName = "test"
#
[[Miners]]
#Actor = 1447
#[Miners.Sector]
#InitNumber = 1301
#MinNumber = 10
#MaxNumber = 1000000
#Enabled = true
#EnableDeals = false
#LifetimeDays = 540
#Verbose = false
[Miners.SnapUp]
#Enabled = false
#Sender = "f1abjxfbp274xpdqcpuaykwkfb43omjotacm2p3za"
#SendFund = true
#GasOverEstimation = 1.2
#GasOverPremium = 0.0
#GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""
#MessageConfidence = 15
#ReleaseConfidence = 30
[Miners.SnapUp.Retry]
#MaxAttempts = 10
#PollInterval = "3m0s"
#APIFailureWait = "3m0s"
#LocalFailureWait = "3m0s"
[Miners.Commitment]
#Confidence = 10
[Miners.Commitment.Pre]
#Sender = "f3sc7rocifuabifirjul34bcpq2m2vvrg6yz2pghbbikd4aylnvhfs7dkeoaydmprzj7m4ptiff7k436x4slqa"
#SendFund = true
#GasOverEstimation = 1.2
#GasOverPremium = 0.0
#GasFeeCap = "5 nanoFIL"
#MaxFeeCap = "5 nanoFIL"
[Miners.Commitment.Pre.Batch]
#Enabled = false
#Threshold = 16
#MaxWait = "1h0m0s"
#CheckInterval = "1m0s"
#GasOverEstimation = 1.2
#GasOverPremium = 0.0
#GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""
[Miners.Commitment.Prove]
#Sender = "f3sc7rocifuabifirjul34bcpq2m2vvrg6yz2pghbbikd4aylnvhfs7dkeoaydmprzj7m4ptiff7k436x4slqa"
#SendFund = true
#GasOverEstimation = 1.2
#GasOverPremium = 0.0
#GasFeeCap = "5 nanoFIL"
#MaxFeeCap = "5 nanoFIL"
[Miners.Commitment.Prove.Batch]
#Enabled = false
#Threshold = 16
#MaxWait = "1h0m0s"
#CheckInterval = "1m0s"
#GasOverEstimation = 1.2
#GasOverPremium = 0.0
#GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""
[Miners.Commitment.Terminate]
#Sender = "f3sc7rocifuabifirjul34bcpq2m2vvrg6yz2pghbbikd4aylnvhfs7dkeoaydmprzj7m4ptiff7k436x4slqa"
#SendFund = true
#GasOverEstimation = 1.2
#GasOverPremium = 0.0
#GasFeeCap = "5 nanoFIL"
#MaxFeeCap = "5 nanoFIL"
[Miners.Commitment.Terminate.Batch]
#Enabled = false
#Threshold = 5
#MaxWait = "1h0m0s"
#CheckInterval = "1m0s"
#GasOverEstimation = 1.2
#GasOverPremium = 0.0
#GasFeeCap = "5 nanoFIL"
#MaxFeeCap = ""
[Miners.PoSt]
Sender = "f3sc7rocifuabifirjul34bcpq2m2vvrg6yz2pghbbikd4aylnvhfs7dkeoaydmprzj7m4ptiff7k436x4slqa"
Enabled = true
StrictCheck = false
Parallel = false
GasOverEstimation = 1.2
GasOverPremium = 0.0
GasFeeCap = "5 nanoFIL"
Confidence = 6
SubmitConfidence = 0
ChallengeConfidence = 0
MaxRecoverSectorLimit = 0
MaxPartitionsPerPoStMessage = 0 
MaxPartitionsPerRecoveryMessage = 0
[Miners.Proof]
Enabled = true
[Miners.Sealing]
#SealingEpochDuration = 0
```

* `MaxPartitionsPerPoStMessage` 设置为0表示全部的Partition聚合为一条消息
* 当实际的`Partition`有14个，聚合设置为5时，会产生三条聚合消息，前两条聚合5`个Partition`，4个`Partition`产生一条
* Confidence = 15 -- 消息的稳定高度， 默认值为 10
* ChallengeConfidence = 0    --启动 WindowPoSt 的稳定高度，这个值决定了需要等待多少个高度才认定链进入稳定状态，可以启动 WindowPoSt 任务启动高度为 deadline.Challenge + ChallengeConfidence当设置为 0 时，会使用默认值 10，值设定的越小，会越早启动，但同时也越容易受到分叉影响
* SubmitConfidence = 0  --提交 WindowPoSt 证明结果的稳定高度这个值决定了需要等待多少个高度才认定链进入稳定状态，可以提交 WindowPoSt 证明结果提交高度为 deadline.Open + SubmitConfidence 当设置为 0 时，会使用默认值 4，此值设定的越小，会越早启动，但同时也越容易受到分叉影响 
* MaxRecoverSectorLimit  单次 Recover 允许包含的扇区数量上限， 默认值为0，设置为 0 时，不会进行限制

* 迁移

```bash
# 目录结构示例

nfs
└─|─ 0.0.0.1
  | ├── cache
  |  │   └── s-t01008-9999
  |  │       ├── p_aux
  |  │       ├── sc-02-data-tree-r-last.dat
  |  │       └── t_aux
  |  └── sealed
  |      ├── s-t01008-1
  |      
  └── 0.0.0.2
    ├── cache
    │   └── s-t01008-9998
    │       ├── p_aux
    │       ├── sc-02-data-tree-r-last.dat
    │       └── t_aux
    └── sealed
        ├── s-t01008-2
        
        
        
        

./venus-sector-manager util storage attach --verbose --name=storage1  /mnt/mount/nfs/0.0.0.0/

> # 输出
[[Common.PersistStores]]
Name = "storage1"
Path = "/mnt/mount/nfs/0.0.0.0/"
Strict = false
ReadOnly = false



./venus-sector-manager util storage attach --verbose --name=storage2  /mnt/mount/nfs/0.0.0.1/

> # 输出
[[Common.PersistStores]]
Name = "storage2"
Path = "/mnt/mount/nfs/0.0.0.1/"
Strict = false
ReadOnly = false
```

* 路径仅需要到cache和sealed上一级
* 修改路径

```bash
[[Common.PersistStores]]
Name = "storage1"										# 存储名称
Path = "/mnt/mount/nfs/0.0.0.0/"		# 存储路径
Strict = false
ReadOnly = false
Weight = 0
#Plugin = "path/to/objstore-plugin"
AllowMiners = [1008]								# 矿工ID
#DenyMiners = [3, 4]

[[Common.PersistStores]]
Name = "storage2"										# 存储名称
Path = "/mnt/mount/nfs/0.0.0.1/"		# 存储路径
Strict = false
ReadOnly = false
Weight = 0
#Plugin = "path/to/objstore-plugin"
AllowMiners = [1008]								# 矿工ID
#DenyMiners = [3, 4]
```

* 存储名称和路径必须要和导入时一致

## 环境准备

* 修改ext-prover.cfg配置文件

```toml
[[WdPost]]
# Bin配置wdpost-master-daemon插件路径
Bin = "/root/venus-cluster/dist/bin/wdpost-master-daemon"

# Args配置wdpost_master配置文件的路径
Args = ["-c", "/root/venus-cluster/dist/bin/wdpost_master.toml"]

# WD任务池的任务数设置，建议设置显卡数量的3～4倍
Concurrent = 50

# 任务权重配置
Weight = 1

# 超时时间
ReadyTimeoutSecs = 5

[WdPost.Envs]
RUST_LOG = "info"
```

* 创建WD数据库和表

```sql
CREATE DATABASE 数据库名;

CREATE TABLE IF NOT EXISTS tasks (
    id CHAR(32) PRIMARY KEY NOT NULL,
    in_body LONGBLOB NOT NULL,
    created_at BIGINT NOT NULL,
    started_at BIGINT DEFAULT NULL,
    finished_at BIGINT DEFAULT NULL,
    retry_count SMALLINT NOT NULL DEFAULT 0,
    error_reason TEXT DEFAULT NULL,
    out_body LONGBLOB DEFAULT NULL,
    slave VARCHAR(100) DEFAULT NULL,
    heartbeat_at BIGINT DEFAULT NULL
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS tasks_archived (
    id CHAR(32) PRIMARY KEY NOT NULL,
    in_body LONGBLOB NOT NULL,
    created_at BIGINT NOT NULL,
    started_at BIGINT DEFAULT NULL,
    finished_at BIGINT DEFAULT NULL,
    retry_count SMALLINT NOT NULL DEFAULT 0,
    error_reason TEXT DEFAULT NULL,
    out_body LONGBLOB DEFAULT NULL,
    slave VARCHAR(100) DEFAULT NULL,
    heartbeat_at BIGINT DEFAULT NULL
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_general_ci;

CREATE VIEW tasks_view AS
SELECT id,
    in_body,
    FROM_UNIXTIME(created_at, '%Y-%m-%d %H:%i:%s') AS created_at,
    FROM_UNIXTIME(started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
    FROM_UNIXTIME(finished_at, '%Y-%m-%d %H:%i:%s') AS finished_at,
    retry_count,
    error_reason,
    out_body,
    slave,
    FROM_UNIXTIME(heartbeat_at, '%Y-%m-%d %H:%i:%s') AS heartbeat_at
    FROM tasks;
```

* wdpost_master 配置

````toml
# rpc 配置
[server]
# rpc 的监听地址
listen = '0.0.0.0:4698'

# rpc server 最大连接数
max_connections = 200

# 数据库配置
[db]
# 数据库 url
url = 'mysql://root:password@localhost/wdpost'

# 数据库连接池最小连接数
min_connections = 3

# 数据库连接池最大连接数
max_connections = 20

# 数据库连接池中连接空闲时长（空闲超过此时间会断开连接）
idle_timeout = '10m'

# 任务相关配置
[task]
# 任务超时时间
timeout = '5m'

# 任务失败重试次数
max_retry = 2

# 任务心跳超时时间（超过此时间可能是slave进程挂了）
heartbeat_timeout = '15s'

# 任务失败重试间隔时间
retry_job_interval = '10s'

# 归档任务扫描的间隔（每隔此配置的时间扫描一次需要归档的任务）
archive_job_interval = '1h'

# 应该被归档的任务的时长（超过此时间的任务应该被归档）
should_archive = '2days'
````

* wdpost salve配置

```toml
[master]
# master rpc 地址
server_addr = '192.168.200.113:4698'

# rpc 断开重连间隔时间
reconnect_interval = '3s'

# 任务心跳间隔时间
heartbeat_interval = '5s'

[slave]
# wdpost 任务并发数
concurrent = 1

# 拉取任务的间隔时间
pull_interval = '5s'
```

* 预生成WD文件

```bash
./gen_cache_and_param_blst wdpost-param --size 32GiB
```

## 启动

* 启动`venus-sector-manager`	

```bash
./venus-sector-manager daemon run --poster --miner --listen 0.0.0.0:1789 --ext-prover
```

* 启动`slave`

```bash
FORCE_SECTOR_SIZE=34359738368 BELLMAN_LOAD_SHM=1 BELLMAN_GPU_INDEXS=1 CUDA_VISIBLE_DEVICES=1  RUST_LOG=trace ./wdpost-slave-daemon -c=slave.toml
```

* FORCE_SECTOR_SIZE 指定扇区大小 34359738368，68719476736
* BELLMAN_LOAD_SHM=1 BELLMAN_GPU_INDEXS=1 启用 /dev/shm 文件
* CUDA_VISIBLE_DEVICES 指定GPU

## 排查信息和逻辑说明

* 目前的扇区检查是由`venus-sector-manager`完成的，只会检查文件是否存在，如果检查文件内存会引起大量的随机读取瓶颈，所以不会检查文件的内容。
* `venus-sector-manager`扇区检查日志关键字`Checked sectors`
* `venus-sector-manager`recovered日志关键字`declare faults recovered message published`
* `venus-sector-manager`提交WD日志关键字`Submitted window post:`
* `wdpost-slave-daemon`领取WD任务日志关键字`got task:`
* `wdpost-slave-daemon`上报WD任务日志关键字`slave: task:`

## 注意事项

1. NFS需要设置超时机制，如果不设置超时机制导致读取扇区卡住，程序会因为系统无任何返回而一直等待，错过WD的提交时间
2. WD只能够找到已经迁移过的扇区，对于没有迁移过的新增扇区是找不到的，没有通过cluster做算力的任何新增扇区都要迁移，所以更换cluster多机poster集群必须为不增长算力的集群