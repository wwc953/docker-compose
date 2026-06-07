#FROM kalilinux/kali-last-release

FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/kalilinux/kali-last-release:latest

RUN > /etc/apt/sources.list

RUN echo "deb http://mirrors.aliyun.com/kali kali-rolling main non-free contrib
    deb-src http://mirrors.aliyun.com/kali kali-rolling main non-free contrib" > /etc/apt/sources.list

#Wifi破解
RUN apt update && apt install -y pciutils net-tools procps crunch wordlists aircrack-ng reaver

WORKDIR /root/workspace

#启动容器
# docker run -it --net="host" --privileged swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/kalilinux/kali-rolling:latest