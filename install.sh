#!/bin/bash

info(){
	echo "***************$1********************"
}

#make sure mysql-server-5.7/mysql-client/libmysqlclient-dev installed, database taint_service created
#arg1 : password of mysql's root user
install_mysql(){
	info "begin check mysql"
	#check mysql 
	if [ `which mysql` ]
	then 
		echo "mysql had been installed!";
		if [[ `mysql -uroot -p$1 -e "show databases;"` =~ "taint_service" ]]
		then
			echo "taint_service database had been created";
		else
			mysql -uroot -p$1 -e "create database taint_service;show databases;"
			echo "taint_service database create successfully!"
		fi
	else

		if [ $# -ne 1 ]
		then 
			echo 'install_mysql function need a password arg'
		fi

		sudo debconf-set-selections <<< "mysql-server-5.7 mysql-server/root_password password $1"
		sudo debconf-set-selections <<< "mysql-server-5.7 mysql-server/root_password_again password $1"
		sudo apt-get -y install mysql-server-5.7
		echo "mysql install successfully!"
	
		if [ ! `which mysql` ]
		then 
			echo "mysql cannot use!!"
			exit 1
		else 
			echo "mysql can use!"
		fi
		mysql -uroot -p$1 -e "create database taint_service;show databases;"
		echo "taint_service database create successfully!"
	fi
	#install mysql-client/libmysqlclient-dev directly
	sudo apt-get -y install mysql-client
	sudo apt-get -y install libmysqlclient-dev
	info "end check mysql"
}

#check libs [libssl-dev/]
#check_libs(){
#	info "begin check libs"
#	sudo apt-get -y install libssl-dev
#	info "end check libs"
#}

#cmake will be used while install python package keystone-engine
check_cmake(){
	info "begin check cmake"
	if [[ `command -v cmake ` ]]
	then
		echo "cmake had been installed!!"
	else
		#echo "please install cmake first!<sudo apt-get install cmake>"
		#exit 1
		sudo apt-get -y install cmake
		if ! [ `command -v cmake` ]
		then
			echo "cmake install failed"
			exit 1
		fi
	fi
	info "end check cmake"
}


install_keystone_engine(){
	wget https://github.com/keystone-engine/keystone/archive/0.9.1.zip
	unzip 0.9.1.zip
	cd keystone-0.9.1/
	mkdir build
	cd build
	../make-share.sh
	sudo make install
	sudo ldconfig
	cd ../..
	rm 0.9.1.zip
	rm -rf keystone-0.9.1
}

#check python and some package Django/MySQL-python/tqdm/z3/keystone-engine
check_python(){
	info "begin check python"
	check_cmake

	if ! [[ `python --version 2>&1` =~ "Python 2.7" ]];then
		echo "please install python 2.7!"
		exit
	else
		echo "python had been installed!!"
	fi

	#check pip package
	if ! [ `command -v pip2` ]
	then
		sudo apt-get -y install python-pip
	fi

	#check Django package
	if [[ `python -c "import django" 2>&1` =~ "ImportError" ]];then
		#echo "please install python package Django!"
		#exit 1
		python -m pip install 'django<2'
	else
		echo "python Django package had been installed!!"
	fi

	#check MySQL-python package
	if [[ `python -m pip freeze` =~ "MySQL-python" ]]
	then
		echo "python package MySQL-python had been installed!"
	else
		#echo "please install python package MySQL-python first!!"
		#exit 1
		python -m pip install MySQL-python
	fi

	#check tqdm package
	if [[ `python -m pip freeze` =~ "tqdm" ]]
	then
		echo "python package tqdm had been installed!"
	else
		#echo "please install python package tqdm first!!<python -m pip install tqdm>"
		#exit 1
		python -m pip install tqdm
	fi

	#check z3 package
	if [[ `python -m pip freeze` =~ "z3" ]]
	then
		echo "python package z3 had been installed!"
	else
		#echo "please install python package z3 first!!<python -m pip install z3>"
		#exit 1
		python -m pip install z3
	fi

	#check keystone-engine package
	if [[ `python -m pip freeze` =~ "keystone-engine" ]]
	then
		echo "python package keystone had been installed!"
	else
		#echo "please install python package keystone first!!<python -m pip install keystone-engine>"
		#exit 1
		#python -m pip install keystone-engine
		install_keystone_engine
		python -m pip install keystone-engine
	fi
	info "end check python"
}



#start application
#arg1 : ip
#arg2 : port
start_app(){
	info "begin start app"
	python manage.py migrate
	if [ $# -eq 2 ]
	then
		python manage.py runserver $1:$2
	else
		python manage.py runserver
	fi
	info "end start app"
}

modify_settings_py(){
	info "begin modify settings.py"
	#local s=`cat ${settings_template_path}`
	#s=${s//---password---/$password}
	#cat <<<$s > $settings_path
	#python replace_file.py ${settings_template_path} ${settings_path} ---password--- $password
	cp ${settings_template_path} ${settings_path}
	sed -i 's/---password---/'$password'/g' $settings_path
	info "end modify settings.py"
}


main(){
	set -e
	install_mysql $password
	check_python
	modify_settings_py
	start_app $ip $port
	echo "exit successfully!"
}

usage="usage: ./install.sh <mysql_root_password> [<ip> <port>]"
settings_path='myblog/settings.py'
settings_template_path='myblog/settings.py.template'
if [ $# -eq 3 ] || [ $# -eq 1 ]
then
	password=$1
	ip=$2
	port=$3
	main
else
	echo $usage
fi
