#!/usr/bin/env bash
#author:fengxuan


#显示菜单(单选)
display_menu(){
local soft=$1
local prompt="which ${soft} you'd select: "
eval local arr=(\${${soft}_arr[@]})
while true
do
    echo -e "#################### ${soft} setting ####################\n\n"
    for ((i=1;i<=${#arr[@]};i++ )); do echo -e "$i) ${arr[$i-1]}"; done
    echo
    read -p "${prompt}" $soft
    eval local select=\$$soft
    if [ "$select" == "" ] || [ "${arr[$soft-1]}" == ""  ];then
        prompt="input errors,please input a number: "
    else
        eval $soft=${arr[$soft-1]}
        eval echo "your selection: \$$soft"             
        break
    fi
done
}

#把带宽bit单位转换为人类可读单位
bit_to_human_readable(){
    #input bit value
    local trafficValue=$1
 
    if [[ ${trafficValue%.*} -gt 922 ]];then
        #conv to Kb
        trafficValue=`awk -v value=$trafficValue 'BEGIN{printf "%0.1f",value/1024}'`
        if [[ ${trafficValue%.*} -gt 922 ]];then
            #conv to Mb
            trafficValue=`awk -v value=$trafficValue 'BEGIN{printf "%0.1f",value/1024}'`
            echo "${trafficValue}Mb"
        else
            echo "${trafficValue}Kb"
        fi
    else
        echo "${trafficValue}b"
    fi
}
 
#判断包管理工具
check_package_manager(){
    local manager=$1
    local systemPackage=''
    if cat /etc/issue | grep -q -E -i "ubuntu|debian";then
        systemPackage='apt'
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat";then
        systemPackage='yum'
    elif cat /proc/version | grep -q -E -i "ubuntu|debian";then
        systemPackage='apt'
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat";then
        systemPackage='yum'
    else
        echo "unkonw"
    fi
 
    if [ "$manager" == "$systemPackage" ];then
        return 0
    else
        return 1
    fi   
}

returneth(){
    eth=""
    local nic_arr=(`ifconfig | grep -E -o "^[a-z0-9]+" | grep -v "lo" | uniq`)
    local nicLen=${#nic_arr[@]}
    if [[ $nicLen -eq 0 ]]; then
        echo "sorry,I can not detect any network device,please report this issue to author."
        exit 1
    elif [[ $nicLen -eq 1 ]]; then
        eth=$nic_arr
    else
        display_menu nic
        eth=$nic
    fi
    
    return 1
}
 
#流量和连接概览
trafficAndConnectionOverview(){
    tcpdumpfile=$1
    savepath=$2

    returneth
    echo "please wait for 10s to generate network data..."
    #获取IP正则表达式
    local regTcpdump=$(ifconfig | grep -A 1 $eth | awk -F'[: ]+' '$0~/inet addr:/{printf $4"|"}' | sed -e 's/|$//' -e 's/^/(/' -e 's/$/)\\\\\.[0-9]+:/')
  
    #新旧版本tcpdump输出格式不一样,分别处理
    if awk '/^IP/{print;exit}' $tcpdumpfile | grep -q ")$";then
        #处理tcpdump文件
        awk '/^IP/{print;getline;print}' $tcpdumpfile  > /tmp/tcpdump_temp2
    else
        #处理tcpdump文件
        awk '/^IP/{print}' $tcpdumpfile > /tmp/tcpdump_temp2
        sed -i -r 's#(.*: [0-9]+\))(.*)#\1\n    \2#' /tmp/tcpdump_temp2
    fi

    awk '{len=$NF;sub(/\)/,"",len);getline;print $0,len}' /tmp/tcpdump_temp2 > $tcpdumpfile


    awk -F'[ .:]+' -v regTcpdump=$regTcpdump  '
    {   if ($0 ~ regTcpdump){
            print "client "$12" "$NF*8     
        }else{
            print "server "$6" "$NF*8
        }
    } 
    ' $tcpdumpfile >> $savepath 

    rm -rf /tmp/tcpdump_temp2 $tcpdumpfile

    echo "done!"
}

runtcpdump(){
    tcpdumpfile=$1
    
    returneth

    if ! which tcpdump > /dev/null;then
        echo "tcpdump not found,going to install it."
        if check_package_manager apt;then
            apt-get -y install tcpdump
        elif check_package_manager yum;then
            yum -y install tcpdump
        fi
    fi

    tcpdump -v -i $eth -tnn > $tcpdumpfile 2>&1 & 
    echo -e "tcpdump running"

}

if [ $# -lt 2 ];then
    echo "usage: \n"$0" tcpdumpPath savepath"
    exit -1;
fi

tcpdumpfile=$1
savepath=$2
runtcpdump $tcpdumpfile
n=1
for((i=1;i<10;))
do
    sum=`expr $n % 10`
    if [[ $sum -eq 0  ]];then
        trafficAndConnectionOverview $tcpdumpfile $savepath
        n=0
    fi
    n=`expr $n + 1`
    sleep 1
done

