# 介绍

这是一个能够自动登录GiWifi校园网的shell脚本.

配合[UA2F](https://github.com/Zxilly/UA2F)或者[UA3F](https://github.com/SunBK201/UA3F)体验更佳

---
原作者: [TwiceTry](https://github.com/TwiceTry)

Node版见:[这里(本人写的)](https://github.com/GiraffeLe/Auto-Giwifi)

# 优点:

无需编译固件

配置相对简单

# 使用

先赋予权限
```
chmod +x giwifi.sh
```

然后(不给权限直接执行的话会提示`./giwifi.sh: Permission denied`)
```bash
./giwifi.sh <username> <password> [baseUrl]
```
示例
```bash
./giwifi.sh 123456789 23333333 192.166.xx.xx(不填的话默认为HPU的)
```

# 配置

路由器上面需要安装`wget-ssl`,`bash`(路由器自带的均为精简版,指令不全,会出现问题)和`openssl-util`
```
opkg update
opkg install wget-ssl
opkg install bash
opkg install openssl-util
```

获取最新版脚本
```
wget https://raw.githubusercontent.com/GiraffeLe/GiwifiScript/master/giwifi.sh
```



