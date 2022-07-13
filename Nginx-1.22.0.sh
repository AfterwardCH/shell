#!/bin/bash
#Automatic installation nginx service

#本地软件存放目录
localFile=/opt
#软件安装目录
installFile=/usr/local
#nginx 版本
nginxSoft=nginx-1.22.0.tar.gz
#安装日志存放目录
log_Ins=/var/log/install.log

#安装编译环境
echo " 开始安装编译环境，此步骤需要等待几分钟完成！"
yum install -y --setopt=protected_multilib=false gcc gcc-c++ make tar net-tools zlib zlib-devel pcre pcre-devel openssl openssl-devel zip unzip >>$log_Ins 2>&1
if [ $? -eq 0 ];then
	echo " 编译环境完成或已经编译好!"
	echo " 开始准备安装nginx ,检测本地是否运行了nginx 服务-------" 
	netstat -ntpl | grep nginx
	if [ $? -eq 1 ];then
		echo " 本地未发现正在运行的nginx 服务，正在检测本地是否已安装nginx----"
		if [ ! -d "$installFile"/nginx ];then
			echo " 本地/usr/local/目录下未检测到已安装nginx文件"
			if [ ! -f "$localFile"/"$nginxSoft" ];then
				echo " 本地/opt目录下未检测到nginx安装包，开始下载"
				wget -P /opt http://nginx.org/download/nginx-1.22.0.tar.gz --no-check-certificate
				if [ $? -eq 0 ];then
					echo " 文件下载成功"
					cd /opt/
					tar -zxvf $nginxSoft >/var/log/tmp.log
				else
					echo "文件下载失败，请检查网络是否畅通!"
					exit 1
				fi
			fi
			echo  $localFile/$nginxSoft
			if [ -f $localFile/$nginxSoft ];then
				echo " 本地/opt目录下已有nginx安装包，开始准备安装nginx!"
				cat /etc/passwd | grep nginx
				if [ $? -eq 1 ];then
					echo " 本地未创建nginx用户！开始创建nginx用户、组"
					groupadd nginx 
					useradd -g nginx -s /sbin/nologin -M nginx
				fi
				cd /opt
				tar -zxvf "$nginxSoft" >/var/log/tmp.log
				cd nginx-1.22.0
				./configure --user=nginx --group=nginx --prefix=/usr/local/nginx --with-http_stub_status_module --with-http_ssl_module --with-http_gzip_static_module 
				if [ $? -eq 0 ];then
					echo " 预编译成功---"
					make && make install
					if [ $? -eq 0 ];then
						echo "success! nginx安装成功"
						echo " 开始配置nginx----"
						cat > /etc/rc.d/init.d/nginx <<EOF
#!/bin/sh
# chkconfig:        2345 80 20
# Description:        Start and Stop Nginx
# Provides:        nginx
# Default-Start:    2 3 4 5
# Default-Stop:        0 1 6
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
NAME=nginx
NGINX_BIN=/usr/local/nginx/sbin/\$NAME
CONFIGFILE=/usr/local/nginx/conf/\$NAME.conf
PIDFILE=/usr/local/nginx/logs/\$NAME.pid
SCRIPTNAME=/etc/init.d/\$NAME
case "\$1" in
start)
echo -n "Starting \$NAME... "
if netstat -tnpl | grep -q nginx;then
echo "\$NAME (pid \`pidof \$NAME\`) already running."
exit 1
fi
\$NGINX_BIN -c \$CONFIGFILE
if [ "\$?" != 0 ] ; then
echo " failed"
exit 1
else
echo " done"
fi
;;
stop)
echo -n "Stoping \$NAME... "
if ! netstat -tnpl | grep -q nginx; then
echo "\$NAME is not running."
exit 1
fi
\$NGINX_BIN -s stop
if [ "\$?" != 0 ] ; then
echo " failed. Use force-quit"
exit 1
else
echo " done"
fi
;;
status)
if netstat -tnpl | grep -q nginx; then
PID=\`pidof nginx\`
echo "\$NAME (pid \$PID) is running..."
else
echo "\$NAME is stopped"
exit 0
fi
;;
force-quit)
echo -n "Terminating \$NAME... "
if ! netstat -tnpl | grep -q nginx; then
echo "\$NAME is not running."
exit 1
fi
kill \`pidof \$NAME\`
if [ "\$?" != 0 ] ; then
echo " failed"
exit 1
else
echo " done"
fi
;;
restart)
\$SCRIPTNAME stop
sleep 1
\$SCRIPTNAME start
;;
reload)
echo -n "Reload service \$NAME... "
if netstat -tnpl | grep -q nginx; then
\$NGINX_BIN -s reload
echo " done"
else
echo "\$NAME is not running, can't reload."
exit 1
fi
;;
configtest)
echo -n "Test \$NAME configure files... "
\$NGINX_BIN -t
;;
*)
echo "Usage: \$SCRIPTNAME {start|stop|force-quit|restart|reload|status|configtest}"
exit 1
;;
esac
EOF
						chmod 744 /etc/rc.d/init.d/nginx
						chkconfig nginx on
						mkdir -p /var/log/nginx
						mkdir /usr/local/nginx/conf/conf.d
						cat > /etc/logrotate.d/nginxlog <<EOF
/var/log/nginx/*.log {

daily

rotate 7

missingok

notifempty

dateext

sharedscripts

postrotate

	if [ -f /usr/local/nginx/logs/nginx.pid ];then

		kill -USR1 \`cat /usr/local/nginx/logs/nginx.pid\`
	fi

endscript

}
EOF
						service nginx start
						netstat -ntpl | grep nginx
						if [ $? -eq 0 ];then
							echo "success! nginx 服务启动成功!"
							echo " 请根据需求，自行调整站点目录、日志文件名称等！"
						else
							echo "Failed! nginx服务启动失败！请检查重新启动！"
							exit 1
						fi
					else
						echo "Failed! nginx安装失败！请检查重新安装!"
						exit 1
					fi	
						
				else
					echo " 预编译失败，请检查原因！重新预编译"
					exit 1
				fi
			fi	
		else
			echo " 本地已安装了nginx服务或未启动服务，无需重复安装！/usr/local/nginx下已发现nginx相关安装文件"
			ls /usr/local/nginx
			exit 1
		fi
	else
		echo "Waring！nginx服务已经在运行！"
		exit 1
	fi	
else
	echo " 编译环境失败，请检查编译环境"
	exit 1
fi
