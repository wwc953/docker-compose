#FROM kalilinux/kali-last-release

FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/kalilinux/kali-last-release:latest

#Wifi破解
RUN apt update && apt install -y pciutils net-tools procps crunch wordlists aircrack-ng reaver

WORKDIR /root/workspace