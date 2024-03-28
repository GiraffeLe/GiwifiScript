#!/usr/bin/env bash

# Usage:  <username> <password> [baseurl]
cd $(
    cd "$(dirname "$0")"
    pwd
)

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.5.1.4 Safari/537.36"
baseUrl="http://10.53.1.3"

LOG_FILE="giwifi.log"
# 1 为开 0为关 日志
LOG_FLAG=1

log() {
    if [ $LOG_FLAG -eq 1 ]; then
        local datetime=$(date +'%Y-%m-%d %H:%M:%S')
        local script_name=$(basename "$0")
        local message="$@"

        echo "[$datetime] [$script_name] - $message" >>"$LOG_FILE"
    fi

}

# 可选参数处理
if [ "$#" -eq 3 ]; then
    baseUrl=$3
    log "use baseurl:$baseUrl"
fi

first_page=$baseUrl'/gportal/web/login'
post_url=$baseUrl'/gportal/web/authLogin?round='${RANDOM::3}
state_url=$baseUrl'/gportal/web/queryAuthState'
logout_url=$baseUrl'/gportal/web/authLogout'
test_url="http://nettest.gwifi.com.cn"

mywget() {
    log "wget" "$@" "-U" "$UA"
    resp_file=$(mktemp)
    if wget "$@" -qO $resp_file -U "$UA" --header "Origin:"$baseUrl --timeout 2 --tries 2; then
        # 请求成功，返回响应体
        cat $resp_file
    else
        # 请求失败，输出错误信息到日志
        log "wget error" $(cat $resp_file)
    fi
    rm $resp_file
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
        *)
            printf -v o '%%%02x' "'$c"
            o=$(echo $o | tr 'a-z' 'A-Z') # 小写字母转大写
            ;;
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

# 请求登录页面
get() {
    mywget $first_page
}

# 从$1拿到param $1 为html文本 $2 form的id
get_form_input_from_page() {

    # 形如 xxx=yyy 的字符'='两边urlencode
    line_urlencode() {
        params_urlencode() {
            echo $(urlencode $1)"="$(urlencode $2)
        }
        while read line; do
            new_line=$(echo $line |
                awk -F '=' '{
                print $1 " " $2
                }')
            echo $(params_urlencode $new_line)
        done
    }

    # 从htmln拿到表单，然后拿到所有input name value 并序列化
    echo $1 | grep -o '<form id=\"'$2'\"[^>]*>.*</form>' | sed 's/<\/form>.*//' |                       # 拿到第一个form标签内文本
        grep -o '<input[^>]*>' | grep -o 'name=\".*\" \([\w]*\(=\".*\"\)\? \)*value\(=\"[^\"]*\"\)\?' | # 拿到所有inout标签
        sed 's/ .* / /g' | sed 's/name=\"\([^"]*\)\" value\(=\"\([^\"]*\)\"\)\?/\1=\3/g' |              # 拿到带name value属性的input 并以name=value形式返回
        line_urlencode |                                                                                # 每行urlencode
        awk '{printf("%s&", $0)}' | sed 's/&$//' |                                                      # &连接并去除最后一个&
        sed 's/\(\&name=\)\(\&password=\)//g'                                                           # 去掉最后的name及password
}

# $1 json文本 $2 字段
json_get() {
    echo $1 | sed -n 's/.*\"'$2'\":[ ]*\([0-9]*\)[^},]*[,}].*/\1/p'
}

# $1 param
post() {
    iv=$(echo $1 | grep -o 'iv=[^\&]*' | sed 's/iv=//g')
    data=$(aes_128_cbc $1 "1234567887654321" $iv)
    msg="data="$(urlencode $data)"&iv=$iv"
    result=$(mywget $post_url --post-data $msg --header "Content-Type:application/x-www-form-urlencoded; charset=UTF-8" --header "Referer:$first_page")
    json_get "$result" "status"
}

# $1 param
queryAuthState() {
    sign=$(echo $1 | grep -o 'sign=[^\&]*' | sed 's/sign=//g')
    result=$(mywget $state_url --post-data "sign=$sign" --header "Content-Type:application/x-www-form-urlencoded; charset=UTF-8")
    json_get "$result" "status"
}

checkAccessInternet() {
    result=$(mywget $test_url)
    # json_get $result 'resultCode'
    if [ -n "$internetCheck" ]; then
        # online
        echo 1
    else
        echo 0
    fi
}

# $1 html文本
logout() {
    data=$(get_form_input_from_page "$1" "frmLogout")
    result=$(mywget $logout_url --post-data "$data" --header "Content-Type:application/x-www-form-urlencoded; charset=UTF-8")
    json_get "$result" "status"
}

# $1 username $2 password
login() {

    html=$(get)
    if [ -z "$html" ]; then
        log "get nothing"
        exit 1
    fi
    myparam=$(get_form_input_from_page "$html" "frmLogin")
    if [ -z "myparam" ]; then
        log "parse error"
        exit 1
    fi
    myparam=$myparam"&name=""$(urlencode $1)""&password=""$(urlencode $2)"

    authState=$(queryAuthState)
    if [ $authState -eq 1 ]; then
        # online
        log "already online"
        logoutBack=$(logout "$html")
        if [ $logoutBack -eq 1 ]; then
            log "logout success"
        fi
    fi
    echo $(post $myparam)
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
