#!/bin/bash
# Usage:  <username> <password> [baseurl]
cd $(
    cd "$(dirname "$0")"
    pwd
)
pwd=$(pwd)

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.5.1.4 Safari/537.36"
baseUrl="http://10.53.1.3"
log_file="giwifi.log"
# 1 为开 0为关 日志
log_flag=1

log() {
    if [ $log_flag -eq 1 ]; then
        local datetime=$(date +'%Y-%m-%d %H:%M:%S')
        local script_name=$(basename "$0")
        local message="$@"

        echo "[$datetime] [$script_name] - $message" >>"$log_file"
    fi

}

# 可选参数处理
if [ "$#" -eq 3 ]; then
    baseUrl=$3
    log "use baseurl:$baseUrl"
fi

mywget() {
    log "$@"
    res=$(wget $@ -q -O- -U "$UA" --timeout 2 --tries 2)
    if [ -z "$res" ]; then
        log "$baseUrl timeout"
    else
        #log "${res}" #第一次返回的是get的html元素,非常占空间,故注释掉了
        echo "${res}"
    fi

}

urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for ((pos = 0; pos < strlen; pos++)); do
        c=${string:$pos:1}
        case "$c" in
        [-_.~a-zA-Z0-9]) o="${c}" ;;
        *) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}
urldecode() {
    # 将%替换为ASCII码\x，并使用printf进行解码
    printf '%b' "$(echo $1 | sed 's/+/ /g; s/%\(..\)/\\x\1/g;')"
}

# aes-128-cbc 加密 $1 data $2 key $3 iv 均为字符串 加密后base64编码
# 依赖外部 openssl命令行工具
aes_128_cbc() {
    # 将第一个参数转换成16进制字符串
    str2hex() {
        # echo -n $1 | xxd -p
        echo -n $1 | hexdump -v -e '/1 "%02x"'
    }

    # 将第一个参数16进制字符串转换成字符串
    hex2str() {
        # echo -n $1 | xxd -r -p
        printf "%b" "$(echo -e $1 | sed 's/.\{2\}/\\x&/g')"
    }

    # 将第一个参数16进制字符串进行0填充
    zeropadding() {
        hex=$1
        # printf '\x00' 空字符到文件，cat 或openssl -in 读取文件加密也可
        blocksize=16
        padlen=$((($blocksize - ${#hex} / 2 % $blocksize) % $blocksize))
        for ((i = 1; i <= padlen; i++)); do
            hex+='00'
        done
        echo $hex
    }

    # key
    hex_key=$(str2hex $2)

    # IV
    hex_iv=$(str2hex $3)

    # 要加密的数据
    hex_data=$(str2hex $1)

    # zeropadding
    hex_data_padding=$(zeropadding $hex_data)

    # 最后-A表示结果不自动添加换行
    hex2str $hex_data_padding | openssl enc -aes-128-cbc -e -K $hex_key -iv $hex_iv -nopad -base64 -A
}

# 从登录页拿到param
get_param_from_page() {

    #字符串urlencode

    # 获取登录页html
    html=$(mywget "$baseUrl""/gportal/web/login")
    # 从表单中拿到所有input name value 并序列化
    param=$(echo $html | grep -o '<input[^>]*>' | grep -o 'name=\".*\" \([\w]*\(=\".*\"\)\? \)*value\(=\"[^\"]*\"\)\?' | sed 's/ .* / /g' | sed 's/name=\"\([^"]*\)\" value\(=\"\([^\"]*\)\"\)\?/\1=\3/g' | awk '{printf("%s&", $0)}' | sed 's/&$//')
    # 删去name password
    echo $param | sed 's/\(\&name=\)\(\&password=\)//g'
}

# $1 json文本
get_status() {
    echo $1 | sed -n 's/.*\"status\": \([0-9]*\)[^}]*}/\1/p'
}

# $1 param
post() {
    iv=$(echo $1 | grep -o 'iv=[^\&]*' | sed 's/iv=//g')
    data=$(aes_128_cbc $1 "1234567887654321" $iv)
    result=$(mywget "$baseUrl""/gportal/web/authLogin?round=114" --post-data "data="$(urlencode $data)"&iv=$iv" --header "Content-Type:application/x-www-form-urlencoded")
    get_status "$result"
}

# $1 param
queryAuthState() {
    sign=$(echo $1 | grep -o 'sign=[^\&]*' | sed 's/sign=//g')
    result=$(mywget "$baseUrl""/gportal/web/queryAuthState" --post-data "sign=$sign" --header "Content-Type:application/x-www-form-urlencoded")
    get_status "$result"
}

# $1 username $2 password
login() {
    myparam=$(get_param_from_page)
    sleep 1
    myparam=$myparam"&name=""$(urlencode $1)""&password=""$(urlencode $2)"
    echo $(post $myparam)
    sleep 1
    echo $(queryAuthState $myparam)
}

## 从这里开始主执行顺序
# 检查参数数量
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <username> <password> [baseurl]"
    exit 1
fi

# 获取必填参数
username=$1
password=$2
login $username $password
