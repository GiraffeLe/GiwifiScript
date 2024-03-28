目前已在虚拟机上测试成功,路由器尚未测试.

# 介绍

这是一个能够自动登录GiWifi校园网的shell脚本.


原作者: [TwiceTry](https://github.com/TwiceTry)

Node版见:[这里(本人写的)](https://github.com/GiraffeLe/Auto-Giwifi)

# 优点:

无需编译固件

配置相对简单

# 使用

```bash
./giwifi.sh <username> <password> [baseUrl]
```
示例
```bash
./giwifi.sh 123456789 23333333 192.166.xx.xx(不填的话默认为HPU的)
```

# 配置

路由器上面需要安装`bash`(脚本中存在busybox的shell不支持的语法)、`wget-ssl`(自带的`uclient-fetch`指令不全,会报错)和`openssl-util`
```
opkg update
opkg install bash
opkg install wget-ssl
opkg install openssl-util
```

获取最新版脚本
```
wget https://raw.githubusercontent.com/GiraffeLe/GiwifiScript/master/giwifi.sh
```



