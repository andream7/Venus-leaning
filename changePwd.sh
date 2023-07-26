if [ $# -ne 1 ]; then
  echo 需要指定 authorizer 服务地址
  echo 示例:
  echo ./changePwd.sh http://localhost:9528
  exit 1
fi

endpoint=$1

echo 输入用户名:
read user
echo 输入密码:
read -s pwd
echo 输入新密码:
read -s newPwd
echo 确认密码:
read -s confirmedPwd
echo

if [ "$newPwd" != "$confirmedPwd" ]; then
  echo 密码输入不一致
  exit 1
fi


token=$(echo '{"User":"'$user'","Pwd":"'$pwd'"}' | base64)

curl $endpoint/rpc/v0 \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: $token" \
  -d '{"method": "LMAuthor.ChangePwd", "id":0, "jsonrpc":"2.0", "params":["'$newPwd'"]}'
