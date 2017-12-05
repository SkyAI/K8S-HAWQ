# 概述

该项目为kubernetes（简称k8s）的安装部署工程，其目录结构如下所示：

    [root@skyaxe-computing-0 k8s]# tree 
	.
	├── bin
	│   ├── load-all-images.sh
	│   └── save-all-images.sh
	├── conf
	│   ├── calico.yaml
	│   ├── deploy.conf
	│   ├── install_ip
	│   ├── kube-apiserver.yaml
	│   └── kubernetes-dashboard.yaml
	├── deploy.sh
	├── log
	└── pkgs
	    └── images.tar.gz
	
	3 directories, 10 files
	[root@skyaxe-computing-0 k8s]# 


其中，在gitlab上没有pkgs目录，考虑到pkgs目录内文件内容过大，所以将其放置在nfs上的develop\platform\SkyAXE\3.0.0-rc1\pkgs\kubernetes目录下。

# 步骤

- 配置install_ip文件，格式如下所示：

		master:10.0.0.14
		worker:10.0.0.15
		worker:10.0.0.16

注意：目前仅支持配置一个master，worker可以配置多个。  

- 配置deploy.conf文件，文件内容如下所示：

	    DEPLOY_DIR=/home/k8s
	    INSTALL_DIR=/root/deploy
	    DASHBOARD_ADMIN_USER=admin
	    DASHBOARD_ADMIN_PASSWD=admin123

其中，DEPLOY\_DIR代表的是安装部署程序所在的目录，INSTALL\_DIR表示的是要安装到每个节点上的目录，DASHBOARD\_ADMIN\_USER表示登陆dashboard时所使用admin账户的名称，DASHBOARD\_ADMIN\_PASSWD表示登陆dashboard时所使用用户对应的密码。

- 执行install操作，如下所示：

		sh deploy.sh install

可以实时查看log文件来跟踪详细的安装过程。

- 最终安装完成后会有如下提示：

        FINISH: install dashboard finished, now you can access https://10.0.0.14:6443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/ on browser