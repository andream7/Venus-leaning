​                                                                     多机wdpost：worker-prover模式 

**之前：多机wdpost由vsm去做 **

启动 damocles-manager 进程: BELLMAN_NO_GPU=1 RUST_LOG=debug RUST_BACKTRACE=1 ./damocles-manager  daemon run --poster --miner --listen 0.0.0.0:1789 --ext-prover

```
root@200-18:~/.damocles-manager# cat ext-prover.cfg
# Default config:
[[WdPost]]
Bin = "/root/baiyu/damocles/dist/bin/wdpost"
Args = ["master", "daemon", "-c","/root/baiyu/damocles/dist/bin/wdpost_master.toml"]
Concurrent = 1
#Weight = 1
#ReadyTimeoutSecs = 5
[WdPost.Envs]
RUST_LOG = "debug"
#ENV_KEY = "ENV_VAL"
```



```
root@200-18:~/baiyu/damocles/dist/bin# cat wdpost_master.toml
# rpc 配置
[server]
# rpc 的监听地址
listen = '0.0.0.0:4698'
# rpc server 最大连接数
max_connections = 200

# 数据库配置
[db]
# 数据库 url
url = "mysql://root:kuangfengjuexizhan@192.168.200.2:3308/venus-cluster-wdpost"
# 数据库连接池最小连接数
min_connections = 3
# 数据库连接池最大连接数
max_connections = 20
# 数据库连接池中连接空闲时长（空闲超过此时间会断开连接）
idle_timeout = '10m'

# 任务相关配置
[task]
# 任务超时时间
timeout = '30m'
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
```

```
root@200-25:~/baiyu/wdpost_slave# cat wdpost_salve.toml
[master]
# master rpc 地址
server_addr = '192.168.200.18:4698'
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



**现在：wdpost由damocles-worker 去计算 window post 证明，通过 RPC 的方式从 damocles-manager 获取 window post 任务和返回计算的结果。**



![image-20230908163250174](/Users/zhangxingmei/Library/Application Support/typora-user-images/image-20230908163250174.png)

#### 1.damocles-manager 配置：

```toml
# ~/.damocles-manager/sector-manager.cfg

# ...

[Common.Proving.WorkerProver]
# WindowPoSt 任务的最大尝试次数, 可选项, 数字类型
# 默认值为 2
# 尝试次数超过 JobMaxTry 的 WindowPoSt 任务只能通过手动 reset 的方式被重新执行
JobMaxTry = 2
# WindowPoSt 任务的心跳超时时间, 可选项, 时间字符串类型
# 默认值为 15s
# 超过此时间没有发送心跳的任务将会被设置为失败并重试
HeartbeatTimeout = "15s"
# WindowPoSt 任务的过期时间, 可选项, 时间字符串类型
# 默认值为 25h
# 创建时间超过此时间的 WindowPoSt 任务将会被删除
JobLifetime = "25h0m0s"

# ...
```

启动 damocles-manager 进程: 

```toml
# --worker-prover 必须添加，表示使用 WorkerProver 模块执行 WindowPoSt
./damocles-manager daemon run --miner --poster --worker-prover
```

#### 2. damocles-worker 配置：

```toml
[[sealing_thread]]
# 配置使用 wdpost plan
plan = "wdpost"
# 配置只允许执行指定矿工号的任务, 为空则表示不限制
# sealing.allowed_miners = [6666, 7777]
# 配置只允许运行指定 size 的扇区的任务
# allowed_sizes = ["32GiB", "64GiB"]

[[attached]]
# 配置此 worker 执行 window post 任务过程中会用到的永久存储
name = "miner-6666-store"
location = "/mnt/miner-6666-store"

# 控制 window_post 任务并发 (可选)，不配置则不限制
[processors.limitation.concurrent]
window_post = 2


[[processors.window_post]]
# 使用自定义 wdpost 算法 (可选)， 如果不配置 bin，则默认使用内置算法
bin="/root/baiyu/damocles/dist/bin/force-ext-processors"
args = ["processor", "window_post"]
# 配置自定义算法的环境变量 (可选)
envs = { BELLMAN_GPU_INDEXS="0", CUDA_VISIBLE_DEVICES="0"}
# 配置本进程最大并发数量 (可选)，不配置则不限制
concurrent = 1
# 限制子进程可使用的 cpu
cgroup.cpuset = "xx-xx"

```

#### 3.管理 window post 任务：

1）显示任务列表

```toml
# 默认显示未完成的任务和失败的任务， 其中 DDL 字段表示任务的 deadline Index, Try 字段是任务的尝试次数
./damocles-manager util worker wdpost list
JobID           MinerID  DDL Partitions  Worker        State       Try  CreateAt        Elapsed      Heartbeat  Error
3FgfEnvrub1     1037     3   1,2         xx.xxx.xx.xx  ReadyToRun  1    08-27 16:37:31  -            -
CrotWCLaXLa     1037     1   1,2         xx.xxx.xx.xx  Succeed     1    08-27 17:19:04  6m38s(done)  -

# 显示全部任务
./damocles-manager util worker wdpost list --all

# 显示 window post 任务详细信息
./damocles-manager util worker wdpost list --detail
```

2）重置任务：

当 window post 任务执行失败且自动重试次数达到上限时，可以手动重置任务状态，使其可以继续被 damocles-worker 领取并执行。

```toml
./damocles-manager util worker wdpost reset xxx
```

3）删除任务：

删除任务和重置任务能达到的效果类似。执行删除任务的命令后，damocles-manager 的重试机制会检测当前 deadline 的 window post 任务是否存在于数据库中，如果不存在则会重新下发一遍任务，并记录到数据库中。

另外 worker-prover 会自动的定时删除创建时间超过一定时间的任务 (默认为 25 小时，时间可配置)。

```toml
# 删除指定的任务
./damocles-manager util worker wdpost remove gbCVH4TUgEf 3FgfEnvrub1

# 删除全部任务
./damocles-manager util worker wdpost remove-all --really-do-it
```









