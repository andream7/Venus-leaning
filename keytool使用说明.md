## keytool使用说明

在与keytool目录相同目录下下有一个fsign,是keytool某些命令下会使用到的第三方工具, 只需要和keytool保存在同一个目录即可.

## 主要流程需要使用到一下命令
### 硬件授权
在从运维人员处拿到硬件指纹文件后,通过如下命令在authorizer上对硬件进行授权
```shell script
./keytool fm submit_machine_code --mac=BNAIwLhAPPzWo5AqisZH/hMPUa6prm0ZKedi1pqroS6RH35Q7sOWNYcBOoDBJc5fw4LVpsq+e3/s0z7iRA1CgdLH76XMJxHufoQIordAjDEALZ0sC7VLBq4hQClZf4l+1+WBwTsobfni6T/cg9JROGbNyIBKY5wWYb0S1Flb3LJiXJmhilpYB64jcimwZDAo/Q==
authorizer endpoint: http://localhost:9528/rpc/v0
login account:
user: ipfsman
password:
______________________________result_______________________________
| detail:BCLX0B9KXIgUjNGYQVvPRfLAyUUu502mLg5XSjO2V0lq+koAqa7u4u8eExk2X7O9k7vA1KFDDOpg9dIJB69eIWbLz6JxEnJPJZ6WXqjIljNPkoy2nGpH1G5eNhQ7fnP3FqyS7R4dDS5orUJbuh2OiFdlIBYmi9duA0427jNWqOUXghpX0RYNkeOH3nKHWEazS2UUkhDah5y33sj9zrY/Mpk0h3QoKo6JvgoFHMbl+0wU
```

### 生成lotus-message需要的'fbls'私钥数据包:
需要硬件授权时生成的一段数据,
- 方式1: new
命令如下:
```shell script
./keytool fm new -t bls --count=2 --fp=BCLX0B9KXIgUjNGYQVvPRfLAyUUu502mLg5XSjO2V0lq+koAqa7u4u8eExk2X7O9k7vA1KFDDOpg9dIJB69eIWbLz6JxEnJPJZ6WXqjIljNPkoy2nGpH1G5eNhQ7fnP3FqyS7R4dDS5orUJbuh2OiFdlIBYmi9duA0427jNWqOUXghpX0RYNkeOH3nKHWEazS2UUkhDah5y33sj9zrY/Mpk0h3QoKo6JvgoFHMbl+0wU
excute command:
./fsign gen -m /Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/mc.txt -k /Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3s6rfrsyd5zqzt5tllf3jzet3eke35zj7emwphgi3oosdcdt732vmijt5qbsbbzyknenyh2xywm54n7oqyuta /Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3upkrazlmgdmpml5b7vxb37i7caj5w773czxd7l6sod5lj66tkpk5ko5xyyiinbeso4aot24nrkknmhds6bsa
______________________________result_______________________________
| detail:
| nonce:      uKLd7X8QUmB5dYltn3EhnmxoZuhZPh8N
| machineCode:65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3

| ››››› index: 0, address:f3s6rfrsyd5zqzt5tllf3jzet3eke35zj7emwphgi3oosdcdt732vmijt5qbsbbzyknenyh2xywm54n7oqyuta
| keyinfo:{"Type":"bls","PrivateKey":"ItIIpTla/KEgEMdIfILG9As/6kVOWDsaurmEd8T1AUs="}
| save keyinfo hex to:/Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3s6rfrsyd5zqzt5tllf3jzet3eke35zj7emwphgi3oosdcdt732vmijt5qbsbbzyknenyh2xywm54n7oqyuta
| ››››› index: 1, address:f3upkrazlmgdmpml5b7vxb37i7caj5w773czxd7l6sod5lj66tkpk5ko5xyyiinbeso4aot24nrkknmhds6bsa
| keyinfo:{"Type":"bls","PrivateKey":"SKbZLWlDUcvTR3oHUtrsm+F8iLiPOoW10+4+EpMcQRo="}
| save keyinfo hex to:/Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3upkrazlmgdmpml5b7vxb37i7caj5w773czxd7l6sod5lj66tkpk5ko5xyyiinbeso4aot24nrkknmhds6bsa| mcB64=ZaB8qbPKpvo4ErQg/nRvCjPouvH/5IPt+wIiAUWJFLM=, pksHashB64=iAgIJEP7ND0IZjM5+OcTazilKhG15EyFdRTSQ5vj7ew=

| save 'fbls' file:/Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/fbls.key
-------------------------------------------------------------------
```

- 方式2: encode
如果想要使用已经存在的私钥, 需要用'encode'来生成:
```shell script
./keytool fm encode --fpre=BCLX0B9KXIgUjNGYQVvPRfLAyUUu502mLg5XSjO2V0lq+koAqa7u4u8eExk2X7O9k7vA1KFDDOpg9dIJB69eIWbLz6JxEnJPJZ6WXqjIljNPkoy2nGpH1G5eNhQ7fnP3FqyS7R4dDS5orUJbuh2OiFdlIBYmi9duA0427jNWqOUXghpX0RYNkeOH3nKHWEazS2UUkhDah5y33sj9zrY/Mpk0h3QoKo6JvgoFHMbl+0wU --keys=./.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3s6rfrsyd5zqzt5tllf3jzet3eke35zj7emwphgi3oosdcdt732vmijt5qbsbbzyknenyh2xywm54n7oqyuta --keys=./.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3upkrazlmgdmpml5b7vxb37i7caj5w773czxd7l6sod5lj66tkpk5ko5xyyiinbeso4aot24nrkknmhds6bsa
hashb64=oQILeSpSvvV+ly10NW1eJwW3OjZyWCx0l/TGo6+gx8s=
excute command:
./fsign gen -m /Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/mc.txt -k /Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3s6rfrsyd5zqzt5tllf3jzet3eke35zj7emwphgi3oosdcdt732vmijt5qbsbbzyknenyh2xywm54n7oqyuta /Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3upkrazlmgdmpml5b7vxb37i7caj5w773czxd7l6sod5lj66tkpk5ko5xyyiinbeso4aot24nrkknmhds6bsa
______________________________result_______________________________
| detail:
| nonce:      uKLd7X8QUmB5dYltn3EhnmxoZuhZPh8N
| machineCode:65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3

| ››››› index: 0, address:f3s6rfrsyd5zqzt5tllf3jzet3eke35zj7emwphgi3oosdcdt732vmijt5qbsbbzyknenyh2xywm54n7oqyuta
| keyinfo:{"Type":"bls","PrivateKey":"ItIIpTla/KEgEMdIfILG9As/6kVOWDsaurmEd8T1AUs="}
| save keyinfo hex to:/Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3s6rfrsyd5zqzt5tllf3jzet3eke35zj7emwphgi3oosdcdt732vmijt5qbsbbzyknenyh2xywm54n7oqyuta
| ››››› index: 1, address:f3upkrazlmgdmpml5b7vxb37i7caj5w773czxd7l6sod5lj66tkpk5ko5xyyiinbeso4aot24nrkknmhds6bsa
| keyinfo:{"Type":"bls","PrivateKey":"SKbZLWlDUcvTR3oHUtrsm+F8iLiPOoW10+4+EpMcQRo="}
| save keyinfo hex to:/Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/f3upkrazlmgdmpml5b7vxb37i7caj5w773czxd7l6sod5lj66tkpk5ko5xyyiinbeso4aot24nrkknmhds6bsa| mcB64=ZaB8qbPKpvo4ErQg/nRvCjPouvH/5IPt+wIiAUWJFLM=, pksHashB64=fLcDmqMtXOEGLN4UrEwmnuhoM8G3VFkHFPz+dIGDBAg=

| save 'fbls' file:/Users/zl/workspace/go/src/ipfsforce/force-messager/bins/.keytool/65a07ca9b3caa6fa3812b420fe746f0a33e8baf1ffe483edfb022201458914b3/fbls.key
-------------------------------------------------------------------
````
参数'--keys':
- 多次指定的时候是编码多个地址的私钥到数据包中.
- 指向了一个文件,文件为keyinfo原始私钥的16进制编码后的字符串
                                          
### 其它命令                                          

#### 创建运维人员账号:
```shell script
./keytool fm create_user --normalUser zl --normalUserPwd ipfsforce
login account:
user: ipfsman
password:
______________________________result_______________________________
| detail:create normal user:zl success
-------------------------------------------------------------------
```

#### 查看用户和授权机器状态:
```shell script
./keytool fm listUser
login account:
user: ipfsman
password:
______________________________result_______________________________
| detail:
index:0, user:zl, machineCode:ZaB8qbPKpvo4ErQg/nRvCjPouvH/5IPt+wIiAUWJFLM=
index:1, user:zl, machineCode:oQILeSpSvvV+ly10NW1eJwW3OjZyWCx0l/TGo6+gx8s=
index:2, user:ipfsman, machineCode:
-------------------------------------------------------------------
```

#### 修改管理员账号密码:
```shell script
/keytool fm changePwd
login account:
user: ipfsman
password:Zaq12wsXCde3
confirm new password:
repeat password::
______________________________result_______________________________
| detail:change password success
-------------------------------------------------------------------
```