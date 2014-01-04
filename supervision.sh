#!/bin/bash
#
# Copyright 2013-2014
# Développé par : Stéphane HACQUARD
# Date : 04-01-2014
# Version 1.0
# Pour plus de renseignements : stephane.hacquard@sargasses.fr



#############################################################################
# Variables d'environnement
#############################################################################


DIALOG=${DIALOG=dialog}

REPERTOIRE_CONFIG=/usr/local/scripts/config
FICHIER_CONFIG=config_centralisation_installation

NagiosLockFile=/usr/local/nagios/var/nagios.lock
Ndo2dbPidFile=/var/run/ndo2db/ndo2db.pid
NrpePidFile=/var/run/nrpe/nrpe.pid

CentenginePidFile=/var/run/centengine.pid
CbdbrokerPidFile=/var/run/cbd_central-broker.pid
CbdrrdPidFile=/var/run/cbd_central-rrd.pid
CentcorePidFile=/var/run/centreon/centcore.pid
CentstoragePidFile=/var/run/centreon/centstorage.pid


#############################################################################
# Fonction Verification installation de dialog
#############################################################################


if [ ! -f /usr/bin/dialog ] ; then
	echo "Le programme dialog n'est pas installé!"
	apt-get install dialog
else
	echo "Le programme dialog est déjà installé!"
fi


#############################################################################
# Fonction Activation De La Banner Pour SSH
#############################################################################


if grep "^#Banner" /etc/ssh/sshd_config > /dev/null ; then
	echo "Configuration de Banner en cours!"
	sed -i "s/#Banner/Banner/g" /etc/ssh/sshd_config 
	/etc/init.d/ssh reload
else 
	echo "Banner déjà activée!"
fi


#############################################################################
# Fonction Recherche Version PERL  
#############################################################################

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


if [ -d /usr/lib/perl ] ; then
	ls /usr/lib/perl/ >$fichtemp
	version_perl=$(sed '$!d' $fichtemp)
	rm -f $fichtemp
	echo "Version PERL est: $version_perl"
else
	echo "Le programme PERL n'est pas installé!"
fi


#############################################################################
# Fonction Parametrage Proxy pour wget   
#############################################################################


if [ -f /etc/apt/apt.conf ] ; then
 
	if grep "http::Proxy" /etc/apt/apt.conf > /dev/null ; then
	fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

	sed -n 's/.*Proxy\ \(.*\);.*/\1/ip' /etc/apt/apt.conf > $fichtemp

	adresse_ip=$(sed -n 's/.*@\(.*\)\/.*/\1/ip' $fichtemp)
	

	sed -n 's/.*http:\/\/\(.*\):.*/\1/ip' /etc/apt/apt.conf  > $fichtemp

	user_proxy=$(sed -n 's/^\(.*\):.*/\1/ip' $fichtemp)
	password_proxy=$(sed -n 's/.*:\(.*\)@.*/\1/ip' $fichtemp)

	echo "Adresse du Proxy: $adresse_ip"
	echo "Utilisateur Proxy: $user_proxy"
	echo "Password Proxy: $password_proxy"


	if grep "http and ftp" /etc/wgetrc > /dev/null ; then
		sed -i "s/http and ftp/http, https, and ftp/g" /etc/wgetrc
	fi

	if grep "http_proxy" /etc/wgetrc > /dev/null ; then
		ligne=$(sed -n '/http_proxy/=' /etc/wgetrc)
		sed -i ""$ligne"d" /etc/wgetrc
		sed -i "$ligne"i"\http_proxy = http://$user_proxy:$password_proxy@$adresse_ip/" /etc/wgetrc
	fi

	if ! grep "https_proxy" /etc/wgetrc > /dev/null ; then
		ligne=$(sed -n '/http_proxy/=' /etc/wgetrc)
		sed -i "$ligne"i"\https_proxy = http://$user_proxy:$password_proxy@$adresse_ip/" /etc/wgetrc
	else 
		ligne=$(sed -n '/https_proxy/=' /etc/wgetrc)
		sed -i ""$ligne"d" /etc/wgetrc
		sed -i "$ligne"i"\https_proxy = http://$user_proxy:$password_proxy@$adresse_ip/" /etc/wgetrc
	fi

	if grep "^#use_proxy" /etc/wgetrc > /dev/null ; then
		sed -i "s/#use_proxy = on/use_proxy = on/g" /etc/wgetrc 
	fi

	rm -f $fichtemp
	fi

else

	if grep "https_proxy" /etc/wgetrc > /dev/null ; then
		sed -i "s/https_proxy/#https_proxy/g" /etc/wgetrc 
	fi

	if grep "http_proxy" /etc/wgetrc > /dev/null ; then
		sed -i "s/http_proxy/#http_proxy/g" /etc/wgetrc 
	fi

	if grep "use_proxy" /etc/wgetrc > /dev/null ; then
		sed -i "s/use_proxy = on/#use_proxy = on/g" /etc/wgetrc 
	fi

fi

#############################################################################
# Fonction Lecture Fichier Configuration Gestion Centraliser
#############################################################################

lecture_config_centraliser()
{

if test -e $REPERTOIRE_CONFIG/$FICHIER_CONFIG ; then

num=10
while [ "$num" -le 15 ] 
	do
	VAR=VAR$num
	VAL1=`cat $REPERTOIRE_CONFIG/$FICHIER_CONFIG | grep $VAR=`
	VAL2=`expr length "$VAL1"`
	VAL3=`expr substr "$VAL1" 7 $VAL2`
	eval VAR$num="$VAL3"
	num=`expr $num + 1`
	done

else 

mkdir -p $REPERTOIRE_CONFIG

num=10
while [ "$num" -le 15 ] 
	do
	echo "VAR$num=" >> $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	num=`expr $num + 1`
	done

num=10
while [ "$num" -le 15 ] 
	do
	VAR=VALFIC$num
	VAL1=`cat $REPERTOIRE_CONFIG/$FICHIER_CONFIG | grep $VAR=`
	VAL2=`expr length "$VAL1"`
	VAL3=`expr substr "$VAL1" 7 $VAL2`
	eval VAR$num="$VAL3"
	num=`expr $num + 1`
	done

fi

if [ "$VAR10" = "" ] ; then
	REF10=`uname -n`
else
	REF10=$VAR10
fi

if [ "$VAR11" = "" ] ; then
	REF11=3306
else
	REF11=$VAR11
fi

if [ "$VAR12" = "" ] ; then
	REF12=installation
else
	REF12=$VAR12
fi

if [ "$VAR13" = "" ] ; then
	REF13=root
else
	REF13=$VAR13
fi

if [ "$VAR14" = "" ] ; then
	REF14=directory
else
	REF14=$VAR14
fi

}


#############################################################################
# Fonction Nettoyage De La Base De Données (table inventaire)
#############################################################################

nettoyage_table_installation()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

if [ "$VAR15" = "OUI" ] ; then

if [ ! -f /usr/bin/smistrip ] ||
   [ ! -f /usr/bin/download-mibs ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='snmp-mibs-downloader' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/bin/fping ] ||
   [ ! -f /usr/bin/mkpasswd ] ||
   [ ! -f /usr/include/gd.h ] ||
   [ ! -f /usr/include/libpng12/png.h ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='nagios-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/include/gnutls/gnutls.h ] ||
   [ ! -f /usr/include/krb5.h ] ||
   [ ! -f /usr/lib/libmcrypt.so ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/share/build-essential/list ] ||
   [ ! -f /usr/include/curl/curl.h ] ||
   [ ! -f /usr/include/openssl/ssl.h ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/share/build-essential/list ] ||
   [ ! -f /usr/bin/cmake ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-clib' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/lib/libperl.so ] ||
   [ ! -d /usr/share/doc/libperl-dev ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-perl-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/include/libssh2.h ] ||
   [ ! -f /usr/include/gcrypt.h ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-ssh-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/bin/cmake ] ||
   [ ! -d /usr/include/qt4 ] ||
   [ ! -f /usr/bin/soapcpp2 ] ||
   [ ! -f /usr/include/zlib.h ] ||
   [ ! -f /usr/include/openssl/aes.h ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/bin/cmake ] ||
   [ ! -d /usr/include/qt4 ] ||
   [ ! -d /usr/share/doc/libqt4-sql-mysql ] ||
   [ ! -f /usr/lib/librrd.so ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/lib/perl5/auto/RRDs/RRDs.so ] ||
   [ ! -f /usr/lib/perl5/auto/GD/GD.so ] ||
   [ ! -f /usr/lib/perl5/auto/SNMP/SNMP.so ] ||
   [ ! -f /usr/lib/perl5/XML/Parser.pm ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/bin/nagios ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nagios' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/libexec/check_ssh ] &&
   [ ! -f /usr/local/centreon-plugins/libexec/check_ssh ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/bin/ndomod.o ] ||
   [ ! -f /usr/local/nagios/bin/ndo2db ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='ndoutils' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/libexec/check_nrpe ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/centreon-clib/lib/libcentreon_clib.so ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-clib' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp
	
	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/centreon-connector/bin/centreon_connector_perl ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-perl-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp
	
	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/centreon-connector/bin/centreon_connector_ssh ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-ssh-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp
	
	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/centreon-engine/bin/centengine ] ||
   [ ! -f /usr/local/centreon-engine/etc/centengine.cfg ] ||
   [ ! -f /usr/local/centreon-engine/lib/centreon-engine/webservice.so ] ||
   [ ! -f /etc/init.d/centengine ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp
	
	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/centreon-broker/bin/cbd ] ||
   [ ! -f /usr/local/centreon-broker/etc/master.run ] ||
   [ ! -f /usr/local/centreon-broker/lib/cbmod.so ] ||
   [ ! -f /etc/init.d/cbd ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /etc/centreon/instCentCore.conf ] ||
   [ ! -f /etc/centreon/instCentPlugins.conf ] ||
   [ ! -f /etc/centreon/instCentStorage.conf ] ||
   [ ! -f /etc/centreon/instCentWeb.conf ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -d /usr/local/centreon/www/widgets/graph-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/hostgroup-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/host-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/servicegroup-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/service-monitoring ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-widgets' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp > /dev/null

	rm -f $fichtemp
fi

fi

}


#############################################################################
# Fonction Inventaire Composant & Logiciel 
#############################################################################

inventaire_composant_logiciel()
{


fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


if [ "$VAR15" = "OUI" ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='snmp-mibs-downloader' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_snmp_mibs_downloader=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='snmp-mibs-downloader' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_snmp_mibs_downloader=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='nagios-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_nagios_core=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_nagios_plugins=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_nrpe=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='centreon-clib' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_centreon_clib=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='centreon-perl-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_centreon_perl_connector=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='centreon-ssh-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_centreon_ssh_connector=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_centreon_engine=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_centreon_broker=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select composant
	from inventaire
	where composant='centreon-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/composant.txt

	composant_centreon_core=$(sed '$!d' /tmp/composant.txt)
	rm -f /tmp/composant.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nagios' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_nagios=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='nagios' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_nagios=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nagios-plugins' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_nagios_plugins=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_nagios_plugins=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='ndoutils' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_ndoutils=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='ndoutils' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_ndoutils=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nrpe' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_nrpe=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_nrpe=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-clib' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_clib=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-clib' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_clib=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-perl-connector' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_perl_connector=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-perl-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_perl_connector=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-ssh-connector' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_ssh_connector=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-ssh-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_ssh_connector=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-engine' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_engine=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_engine=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-broker' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_broker=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_broker=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-core' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_core=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_core=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp



	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-widgets' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_widgets=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-widgets' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_widgets=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp

fi

}

#############################################################################
# Fonction Message d'erreur
#############################################################################

message_erreur()
{
	
cat <<- EOF > /tmp/erreur
Veuillez vous assurer que les parametres saisie
                sont correcte
EOF

erreur=`cat /tmp/erreur`

$DIALOG --ok-label "Quitter" \
	 --colors \
	 --backtitle "Installation Serveur de Supervision" \
	 --title "Erreur" \
	 --msgbox  "\Z1$erreur\Zn" 6 52 

rm -f /tmp/erreur

}

#############################################################################
# Fonction Verification Couleur
#############################################################################

verification_installation()
{


# 0=noir, 1=rouge, 2=vert, 3=jaune, 4=bleu, 5=magenta, 6=cyan 7=blanc


if ! grep -w "OUI" $REPERTOIRE_CONFIG/$FICHIER_CONFIG > /dev/null ; then
	choix1="\Z1Gestion Centraliser des Installations\Zn" 
else
	choix1="\Z2Gestion Centraliser des Installations\Zn"  
fi

if [ ! -f /usr/bin/smistrip ] ||
   [ ! -f /usr/bin/download-mibs ] ; then
	choix2="\Z1Installation MIB SNMP Complementaire\Zn" 

elif [ "$version_reference_snmp_mibs_downloader" != "$version_installe_snmp_mibs_downloader" ] ; then
	choix2="\Zb\Z3Installation MIB SNMP Complementaire\Zn" 

else
	choix2="\Z2Installation MIB SNMP Complementaire\Zn" 
fi

if [ ! -f /usr/bin/fping ] ||
   [ ! -f /usr/bin/mkpasswd ] ||
   [ ! -f /usr/include/gd.h ] ||
   [ ! -f /usr/include/libpng12/png.h ] ||
   [ "$composant_nagios_core" != "nagios-core" ] ; then
	choix3="\Z1Installation Composant Nagios Core\Zn" 
else
	choix3="\Z2Installation Composant Nagios Core\Zn" 
fi

if [ ! -f /usr/include/gnutls/gnutls.h ] ||
   [ ! -f /usr/include/krb5.h ] ||
   [ ! -f /usr/lib/libmcrypt.so ] ||
   [ "$composant_nagios_plugins" != "nagios-plugins" ] ; then
	choix4="\Z1Installation Composant Nagios Plugins\Zn" 
else
	choix4="\Z2Installation Composant Nagios Plugins\Zn" 
fi

if [ ! -f /usr/share/build-essential/list ] ||
   [ ! -f /usr/include/curl/curl.h ] ||
   [ ! -f /usr/include/openssl/ssl.h ] ||
   [ "$composant_nrpe" != "nrpe" ] ; then
	choix5="\Z1Installation Composant NRPE\Zn" 
else
	choix5="\Z2Installation Composant NRPE\Zn" 
fi

if [ ! -f /usr/share/build-essential/list ] ||
   [ ! -f /usr/bin/cmake ] ||
   [ "$composant_centreon_clib" != "centreon-clib" ] ; then
	choix6="\Z1Installation Composant Centreon Clib\Zn" 
else
	choix6="\Z2Installation Composant Centreon Clib\Zn" 
fi

if [ ! -f /usr/lib/libperl.so ] ||
   [ ! -d /usr/share/doc/libperl-dev ] ||
   [ "$composant_centreon_perl_connector" != "centreon-perl-connector" ] ; then
	choix7="\Z1Installation Composant Centreon Perl Connector\Zn" 
else
	choix7="\Z2Installation Composant Centreon Perl Connector\Zn" 
fi

if [ ! -f /usr/include/libssh2.h ] ||
   [ ! -f /usr/include/gcrypt.h ] ||
   [ "$composant_centreon_ssh_connector" != "centreon-ssh-connector" ] ; then
	choix8="\Z1Installation Composant Centreon SSH Connector\Zn" 
else
	choix8="\Z2Installation Composant Centreon SSH Connector\Zn" 
fi

if [ ! -f /usr/bin/cmake ] ||
   [ ! -d /usr/include/qt4 ] ||
   [ ! -f /usr/bin/soapcpp2 ] ||
   [ ! -f /usr/include/zlib.h ] ||
   [ ! -f /usr/include/openssl/aes.h ] ||
   [ "$composant_centreon_engine" != "centreon-engine" ] ; then
	choix9="\Z1Installation Composant Centreon Engine\Zn" 
else
	choix9="\Z2Installation Composant Centreon Engine\Zn" 
fi

if [ ! -f /usr/bin/cmake ] ||
   [ ! -d /usr/include/qt4 ] ||
   [ ! -d /usr/share/doc/libqt4-sql-mysql ] ||
   [ ! -f /usr/lib/librrd.so ] ||
   [ "$composant_centreon_broker" != "centreon-broker" ] ; then
	choix10="\Z1Installation Composant Centreon Broker\Zn" 
else
	choix10="\Z2Installation Composant Centreon Broker\Zn" 
fi

if [ ! -f /usr/lib/perl5/auto/RRDs/RRDs.so ] ||
   [ ! -f /usr/lib/perl5/auto/GD/GD.so ] ||
   [ ! -f /usr/lib/perl5/auto/SNMP/SNMP.so ] ||
   [ ! -f /usr/lib/perl5/XML/Parser.pm ] ||
   [ "$composant_centreon_core" != "centreon-core" ] ; then
	choix11="\Z1Installation Composant Centreon Core\Zn" 
else
	choix11="\Z2Installation Composant Centreon Core\Zn" 
fi

if [ ! -f /usr/local/nagios/bin/nagios ] ; then
	choix12="\Z1Installation Nagios Core\Zn" 

elif [ "$version_reference_nagios" != "$version_installe_nagios" ] ; then
	choix12="\Zb\Z3Installation Nagios Core\Zn" 

else
	choix12="\Z2Installation Nagios Core\Zn" 
fi

if [ ! -f /usr/local/nagios/libexec/check_ssh ] && 
   [ ! -f /usr/local/centreon-plugins/libexec/check_ssh ] ; then
	choix13="\Z1Installation Nagios Plugins\Zn" 

elif [ "$version_reference_nagios_plugins" != "$version_installe_nagios_plugins" ] ; then
	choix13="\Zb\Z3Installation Nagios Plugins\Zn" 

else
	choix13="\Z2Installation Nagios Plugins\Zn" 
fi

if [ ! -f /usr/local/nagios/bin/ndomod.o ] ||
   [ ! -f /usr/local/nagios/bin/ndo2db ] ; then
	choix14="\Z1Installation NDOutils\Zn" 

elif [ "$version_reference_ndoutils" != "$version_installe_ndoutils" ] ; then
	choix14="\Zb\Z3Installation NDOutils\Zn" 

else
	choix14="\Z2Installation NDOutils\Zn" 
fi

if [ ! -f /usr/local/nagios/libexec/check_nrpe ] ; then
	choix15="\Z1Installation NRPE\Zn" 

elif [ "$version_reference_nrpe" != "$version_installe_nrpe" ] ; then
	choix15="\Zb\Z3Installation NRPE\Zn" 

else
	choix15="\Z2Installation NRPE\Zn" 
fi

if [ ! -f /usr/local/centreon-clib/lib/libcentreon_clib.so ] ; then
	choix16="\Z1Installation Centreon Clib\Zn" 

elif [ "$version_reference_centreon_clib" != "$version_installe_centreon_clib" ] ; then
	choix16="\Zb\Z3Installation Centreon Clib\Zn" 

else
	choix16="\Z2Installation Centreon Clib\Zn" 
fi

if [ ! -f /usr/local/centreon-connector/bin/centreon_connector_perl ] ; then
	choix17="\Z1Installation Centreon Perl Connector\Zn" 

elif [ "$version_reference_centreon_perl_connector" != "$version_installe_centreon_perl_connector" ] ; then
	choix17="\Zb\Z3Installation Centreon Perl Connector\Zn" 

else
	choix17="\Z2Installation Centreon Perl Connector\Zn" 
fi

if [ ! -f /usr/local/centreon-connector/bin/centreon_connector_ssh ] ; then
	choix18="\Z1Installation Centreon SSH Connector\Zn" 

elif [ "$version_reference_centreon_ssh_connector" != "$version_installe_centreon_ssh_connector" ] ; then
	choix18="\Zb\Z3Installation Centreon SSH Connector\Zn" 

else
	choix18="\Z2Installation Centreon SSH Connector\Zn" 
fi

if [ ! -f /usr/local/centreon-engine/bin/centengine ] ||
   [ ! -f /usr/local/centreon-engine/etc/centengine.cfg ] ||
   [ ! -f /usr/local/centreon-engine/lib/centreon-engine/webservice.so ] ||
   [ ! -f /etc/init.d/centengine ] ; then
	choix19="\Z1Installation Centreon Engine\Zn" 

elif [ "$version_reference_centreon_engine" != "$version_installe_centreon_engine" ] ; then
	choix19="\Zb\Z3Installation Centreon Engine\Zn" 

else
	choix19="\Z2Installation Centreon Engine\Zn" 
fi

if [ ! -f /usr/local/centreon-broker/bin/cbd ] ||
   [ ! -f /usr/local/centreon-broker/etc/master.run ] ||
   [ ! -f /usr/local/centreon-broker/lib/cbmod.so ] ||
   [ ! -f /etc/init.d/cbd ] ; then
	choix20="\Z1Installation Centreon Broker\Zn" 

elif [ "$version_reference_centreon_broker" != "$version_installe_centreon_broker" ] ; then
	choix20="\Zb\Z3Installation Centreon Broker\Zn"

else
	choix20="\Z2Installation Centreon Broker\Zn" 
fi

if [ ! -f /etc/centreon/instCentCore.conf ] ||
   [ ! -f /etc/centreon/instCentPlugins.conf ] ||
   [ ! -f /etc/centreon/instCentStorage.conf ] ||
   [ ! -f /etc/centreon/instCentWeb.conf ] ; then
	choix21="\Z1Installation Centreon Core\Zn"
 
elif [ "$version_reference_centreon_core" != "$version_installe_centreon_core" ] ; then
	choix21="\Zb\Z3Installation Centreon Core\Zn" 

else
	choix21="\Z2Installation Centreon Core\Zn" 
fi

if [ ! -d /usr/local/centreon/www/widgets/graph-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/hostgroup-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/host-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/servicegroup-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/service-monitoring ] ; then
	choix22="\Z1Installation Centreon Widgets\Zn" 

elif [ "$version_reference_centreon_widgets" != "$version_installe_centreon_widgets" ] ; then
	choix22="\Zb\Z3Installation Centreon Widgets\Zn" 

else
	choix22="\Z2Installation Centreon Widgets\Zn" 
fi

}

#############################################################################
# Fonction Menu 
#############################################################################

menu()
{

lecture_config_centraliser
nettoyage_table_installation
inventaire_composant_logiciel
verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Serveur de Supervision" \
	  --clear \
	  --colors \
	  --default-item "3" \
	  --menu "Quel est votre choix" 11 62 5 \
	  "1" "$choix1" \
	  "2" "Installation Serveur de Supervision" \
	  "3" "Quitter" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Gestion Centraliser des Installations
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
              menu_gestion_centraliser_installations
	fi

	# Installation Serveur de Supervision
	if [ "$choix" = "2" ]
	then
		if [ "$VAR15" = "OUI" ] ; then
			rm -f $fichtemp
			menu_installation_serveur_supervision
		else
			rm -f $fichtemp
			message_erreur
			menu
		fi
	fi

	# Quitter
	if [ "$choix" = "3" ]
	then
		clear
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

exit

}

#############################################################################
# Fonction Menu Gestion Centraliser des Installations
#############################################################################

menu_gestion_centraliser_installations()
{

lecture_config_centraliser

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --insecure \
	  --title "Gestion Centraliser des Installations" \
	  --mixedform "Quel est votre choix" 11 60 0 \
	  "Nom Serveur:"     1 1  "$REF10"  1 24  28 26 0  \
	  "Port Serveur:"    2 1  "$REF11"  2 24  28 26 0  \
	  "Base de Donnees:" 3 1  "$REF12"  3 24  28 26 0  \
	  "Compte Root:"     4 1  "$REF13"  4 24  28 26 0  \
	  "Password Root:"   5 1  "$REF14"  5 24  28 26 1  2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Gestion Centraliser des Installations
	VARSAISI10=$(sed -n 1p $fichtemp)
	VARSAISI11=$(sed -n 2p $fichtemp)
	VARSAISI12=$(sed -n 3p $fichtemp)
	VARSAISI13=$(sed -n 4p $fichtemp)
	VARSAISI14=$(sed -n 5p $fichtemp)
	

	sed -i "s/VAR10=$VAR10/VAR10=$VARSAISI10/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR11=$VAR11/VAR11=$VARSAISI11/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR12=$VAR12/VAR12=$VARSAISI12/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR13=$VAR13/VAR13=$VARSAISI13/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	sed -i "s/VAR14=$VAR14/VAR14=$VARSAISI14/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG

      
	cat <<- EOF > /tmp/databases.txt
	SHOW DATABASES;
	EOF

	mysql -h $VARSAISI10 -P $VARSAISI11 -u $VARSAISI13 -p$VARSAISI14 < /tmp/databases.txt &>/tmp/resultat.txt

	if grep -w "^$VARSAISI12" /tmp/resultat.txt > /dev/null ; then
	sed -i "s/VAR15=$VAR15/VAR15=OUI/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG

	else
	sed -i "s/VAR15=$VAR15/VAR15=NON/g" $REPERTOIRE_CONFIG/$FICHIER_CONFIG
	message_erreur
	fi

	rm -f /tmp/databases.txt
	rm -f /tmp/resultat.txt
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu

}

#############################################################################
# Fonction Menu Installation Serveur de Supervision
#############################################################################

menu_installation_serveur_supervision()
{

inventaire_composant_logiciel
verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Serveur de Supervision" \
	  --clear \
	  --colors \
	  --default-item "5" \
	  --menu "Quel est votre choix" 12 62 5 \
	  "1" "Installation Composant Complementaire" \
	  "2" "$choix2" \
	  "3" "Installation Suite Nagios" \
	  "4" "Installation Suite Centreon" \
	  "5" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Composant Complementaire
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		menu_installation_composant_complementaire
	fi

	# Installation MIB SNMP Complementaire
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		installation_mib_snmp
	fi

	# Installation Suite Nagios
	if [ "$choix" = "3" ]
	then
		rm -f $fichtemp
		menu_installation_suite_nagios
	fi

	# Installation Suite Centreon
	if [ "$choix" = "4" ]
	then
		rm -f $fichtemp
		menu_installation_suite_centreon
	fi

	# Retour
	if [ "$choix" = "5" ]
	then
		clear
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu
}

#############################################################################
# Fonction Menu Installation Composant Complementaire
#############################################################################

menu_installation_composant_complementaire()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Complementaire" \
	  --clear \
	  --colors \
	  --default-item "3" \
	  --menu "Quel est votre choix" 10 66 3 \
	  "1" "Installation Composant Complementaire Nagios" \
	  "2" "Installation Composant Complementaire Centreon" \
	  "3" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Composant Complementaire Nagios
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		menu_installation_composant_complementaire_nagios
	fi

	# Installation Composant Complementaire Centreon
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		menu_installation_composant_complementaire_centreon
	fi

	# Retour
	if [ "$choix" = "3" ]
	then
		clear
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu_installation_serveur_supervision
}

#############################################################################
# Fonction Menu Installation Composant Complementaire Nagios
#############################################################################

menu_installation_composant_complementaire_nagios()
{

inventaire_composant_logiciel
verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Complementaire Nagios" \
	  --clear \
	  --colors \
	  --default-item "4" \
	  --menu "Quel est votre choix" 12 62 4 \
	  "1" "$choix3" \
	  "2" "$choix4" \
	  "3" "$choix5" \
	  "4" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Composant Nagios Core
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		installation_composant_nagios_core
	fi

	# Installation Composant Nagios Plugins
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		installation_composant_nagios_plugins
	fi

	# Installation Composant NRPE
	if [ "$choix" = "3" ]
	then
		rm -f $fichtemp
		installation_composant_nrpe
	fi

	# Retour
	if [ "$choix" = "4" ]
	then
		clear
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu_installation_composant_complementaire
}

#############################################################################
# Fonction Menu Installation Composant Complementaire Centreon
#############################################################################

menu_installation_composant_complementaire_centreon()
{

inventaire_composant_logiciel
verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Complementaire Centreon" \
	  --clear \
	  --colors \
	  --default-item "7" \
	  --menu "Quel est votre choix" 14 72 7 \
	  "1" "$choix6" \
	  "2" "$choix7" \
	  "3" "$choix8" \
	  "4" "$choix9" \
	  "5" "$choix10" \
	  "6" "$choix11" \
	  "7" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Composant Centreon Clib
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		installation_composant_centreon_clib
	fi

	# Installation Composant Centreon Perl Connector
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		installation_composant_centreon_perl_connector
	fi

	# Installation Composant Centreon SSH Connector
	if [ "$choix" = "3" ]
	then
		rm -f $fichtemp
		installation_composant_centreon_ssh_connector
	fi

	# Installation Composant Centreon Engine
	if [ "$choix" = "4" ]
	then
		rm -f $fichtemp
		installation_composant_centreon_engine
	fi

	# Installation Composant Centreon Broker
	if [ "$choix" = "5" ]
	then
		rm -f $fichtemp
		installation_composant_centreon_broker
	fi

	# Installation Composant Centreon Core
	if [ "$choix" = "6" ]
	then
		rm -f $fichtemp
		installation_composant_centreon_core
	fi

	# Retour
	if [ "$choix" = "7" ]
	then
		clear
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu_installation_composant_complementaire
}

#############################################################################
# Fonction Menu Installation Suite Nagios
#############################################################################

menu_installation_suite_nagios()
{

inventaire_composant_logiciel
verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Suite Nagios" \
	  --clear \
	  --colors \
	  --default-item "5" \
	  --menu "Quel est votre choix" 12 52 5 \
	  "1" "$choix12" \
	  "2" "$choix13" \
	  "3" "$choix14" \
	  "4" "$choix15" \
	  "5" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Nagios Core
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		installation_nagios_core
	fi

	# Installation Nagios Plugins
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		installation_nagios_plugins
	fi

	# Installation NDOutils
	if [ "$choix" = "3" ]
	then
		rm -f $fichtemp
		installation_ndoutils
	fi

	# Installation NRPE
	if [ "$choix" = "4" ]
	then
		rm -f $fichtemp
		installation_nrpe
	fi

	# Retour
	if [ "$choix" = "5" ]
	then
		clear
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu_installation_serveur_supervision
}

#############################################################################
# Fonction Menu Installation Suite Centreon
#############################################################################

menu_installation_suite_centreon()
{

inventaire_composant_logiciel
verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Suite Centreon" \
	  --clear \
	  --colors \
	  --default-item "8" \
	  --menu "Quel est votre choix" 16 62 8 \
	  "1" "$choix16" \
	  "2" "$choix17" \
	  "3" "$choix18" \
	  "4" "$choix19" \
	  "5" "$choix20" \
	  "6" "$choix21" \
	  "7" "$choix22" \
	  "8" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Centreon Clib
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		installation_centreon_clib
	fi

	# Installation Centreon Perl Connector 
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		installation_centreon_perl_connector
	fi

	# Installation Centreon SSH Connector
	if [ "$choix" = "3" ]
	then
		rm -f $fichtemp
		installation_centreon_ssh_connector
	fi

	# Installation Centreon Engine
	if [ "$choix" = "4" ]
	then
		rm -f $fichtemp
		installation_centreon_engine
	fi

	# Installation Centreon Broker
	if [ "$choix" = "5" ]
	then
		rm -f $fichtemp
		installation_centreon_broker
	fi

	# Installation Centreon Core
	if [ "$choix" = "6" ]
	then
		rm -f $fichtemp
		installation_centreon_core
	fi

	# Installation Centreon Widgets
	if [ "$choix" = "7" ]
	then
		rm -f $fichtemp
		installation_centreon_widgets
	fi

	# Retour
	if [ "$choix" = "8" ]
	then
		clear
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

rm -f $fichtemp

menu_installation_serveur_supervision
}

#############################################################################
# Fonction Installation Composant Nagios
#############################################################################

installation_composant_nagios_core()
{

(

 echo "10" ; sleep 1
 echo "XXX" ; echo "apt-get -y install fping whois"; echo "XXX"
	apt-get -y install fping whois &> /dev/null

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libpng12-dev"; echo "XXX"
	apt-get -y install libpng12-dev &> /dev/null

 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libperl-dev libgd2-xpm-dev libltdl3-dev"; echo "XXX"
	apt-get -y install libperl-dev libgd2-xpm-dev libltdl3-dev &> /dev/null

 echo "60" ; sleep 1
 echo "XXX" ; echo "apt-get -y install build-essential"; echo "XXX"
	apt-get -y install build-essential &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install linux-headers-`uname -r`"; echo "XXX"
	apt-get -y install linux-headers-`uname -r` &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Nagios Core"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='nagios-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'nagios-core' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Nagios" \
	  --gauge "Installation Composant Nagios" 10 62 0 \

menu_installation_composant_complementaire_nagios
}

#############################################################################
# Fonction Installation Composant Nagios Plugins
#############################################################################

installation_composant_nagios_plugins()
{

(

 echo "10" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libgnutls-dev"; echo "XXX"
	apt-get -y install libgnutls-dev &> /dev/null

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libssl-dev"; echo "XXX"
	apt-get -y install libssl-dev &> /dev/null

 echo "30" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libkrb5-dev"; echo "XXX"
	apt-get -y install libkrb5-dev &> /dev/null

 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libldap2-dev"; echo "XXX"
	apt-get -y install libldap2-dev &> /dev/null

 echo "50" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libsnmp-dev"; echo "XXX"
	apt-get -y install libsnmp-dev &> /dev/null

 echo "60" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libwrap0-dev"; echo "XXX"
	apt-get -y install libwrap0-dev &> /dev/null

 echo "70" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libmcrypt-dev"; echo "XXX"
	apt-get -y install libmcrypt-dev &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install fping dnsutils"; echo "XXX"
	apt-get -y install fping dnsutils &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Nagios Plugins"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'nagios-plugins' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Nagios Plugins" \
	  --gauge "Installation Composant Nagios Plugins" 10 62 0 \

menu_installation_composant_complementaire_nagios
}

#############################################################################
# Fonction Installation Composant NRPE
#############################################################################

installation_composant_nrpe()
{

(

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install build-essential"; echo "XXX"
	apt-get -y install build-essential &> /dev/null

 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libcurl4-openssl-dev"; echo "XXX"
	apt-get -y install libcurl4-openssl-dev &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libssl-dev"; echo "XXX"
	apt-get -y install libssl-dev &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant NRPE"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'nrpe' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant NRPE" \
	  --gauge "Installation Composant NRPE" 10 62 0 \

menu_installation_composant_complementaire_nagios
}

#############################################################################
# Fonction Installation Composant Centreon Clib
#############################################################################

installation_composant_centreon_clib()
{

(

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install build-essential"; echo "XXX"
	apt-get -y install build-essential &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install cmake"; echo "XXX"
	apt-get -y install cmake &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Centreon Clib"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-clib' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'centreon-clib' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon Clib" \
	  --gauge "Installation Composant Centreon Clib" 10 62 0 \

menu_installation_composant_complementaire_centreon
}

#############################################################################
# Fonction Installation Composant Centreon Perl Connector
#############################################################################

installation_composant_centreon_perl_connector()
{

(

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libperl-dev"; echo "XXX"
	apt-get -y install libperl-dev &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Centreon Perl Connector"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-perl-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'centreon-perl-connector' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon Perl Connector" \
	  --gauge "Installation Composant Centreon Perl Connector" 10 62 0 \

menu_installation_composant_complementaire_centreon
}

#############################################################################
# Fonction Installation Composant Centreon SSH Connector
#############################################################################

installation_composant_centreon_ssh_connector()
{

(

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libssh2-1-dev"; echo "XXX"
	apt-get -y install libssh2-1-dev &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libgcrypt11-dev"; echo "XXX"
	apt-get -y install libgcrypt11-dev &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Centreon SSH Connector"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-ssh-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'centreon-ssh-connector' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon SSH Connector" \
	  --gauge "Installation Composant Centreon SSH Connector" 10 62 0 \

menu_installation_composant_complementaire_centreon
}

#############################################################################
# Fonction Installation Composant Centreon Engine
#############################################################################

installation_composant_centreon_engine()
{

(

 echo "10" ; sleep 1
 echo "XXX" ; echo "apt-get -y install build-essential"; echo "XXX"
	apt-get -y install build-essential &> /dev/null

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install cmake"; echo "XXX"
	apt-get -y install cmake &> /dev/null

 echo "30" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libqt4-dev"; echo "XXX"
	apt-get -y install libqt4-dev &> /dev/null

 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install gsoap"; echo "XXX"
	apt-get -y install gsoap &> /dev/null

 echo "50" ; sleep 1
 echo "XXX" ; echo "apt-get -y install zlib1g-dev"; echo "XXX"
	apt-get -y install zlib1g-dev &> /dev/null

 echo "60" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libssl-dev"; echo "XXX"
	apt-get -y install libssl-dev &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libxerces-c-dev"; echo "XXX"
	apt-get -y install libxerces-c-dev &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Centreon Engine"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'centreon-engine' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon Engine" \
	  --gauge "Installation Composant Centreon Engine" 10 62 0 \

menu_installation_composant_complementaire_centreon
}

#############################################################################
# Fonction Installation Composant Centreon Broker
#############################################################################

installation_composant_centreon_broker()
{

(

 echo "10" ; sleep 1
 echo "XXX" ; echo "apt-get -y install build-essential"; echo "XXX"
	apt-get -y install build-essential &> /dev/null

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install cmake"; echo "XXX"
	apt-get -y install cmake &> /dev/null

 echo "30" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libqt4-dev"; echo "XXX"
	apt-get -y install libqt4-dev &> /dev/null

 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libqt4-sql-mysql"; echo "XXX"
	apt-get -y install libqt4-sql-mysql &> /dev/null

 echo "50" ; sleep 1
 echo "XXX" ; echo "apt-get -y install librrd-dev"; echo "XXX"
	apt-get -y install librrd-dev &> /dev/null

 echo "60" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libgnutls28-dev"; echo "XXX"
	apt-get -y install libgnutls28-dev &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Centreon Broker"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'centreon-broker' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon Broker" \
	  --gauge "Installation Composant Centreon Broker" 10 62 0 \

menu_installation_composant_complementaire_centreon
}

#############################################################################
# Fonction Installation Composant Centreon Core
#############################################################################

installation_composant_centreon_core()
{

(

 echo "10" ; sleep 1
 echo "XXX" ; echo "apt-get -y install sudo tofrodos"; echo "XXX"
	apt-get -y install sudo tofrodos &> /dev/null

 echo "15" ; sleep 1
 echo "XXX" ; echo "apt-get -y install lsb-release"; echo "XXX"
	apt-get -y install lsb-release &> /dev/null

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libconfig-inifiles-perl"; echo "XXX"
	apt-get -y install libconfig-inifiles-perl &> /dev/null

 echo "25" ; sleep 1
 echo "XXX" ; echo "apt-get -y install php5-ldap php5-snmp php5-gd"; echo "XXX"
	apt-get -y install php5-ldap php5-snmp php5-gd &> /dev/null

 echo "30" ; sleep 1
 echo "XXX" ; echo "apt-get -y install rrdtool librrds-perl"; echo "XXX"
	apt-get -y install rrdtool librrds-perl &> /dev/null

 echo "35" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libcrypt-des-perl"; echo "XXX"
	apt-get -y install libcrypt-des-perl &> /dev/null

if grep "Debian GNU/Linux 6.0" /etc/issue.net > /dev/null ; then
 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libdigest-hmac-perl libdigest-sha1-perl"; echo "XXX"
	apt-get -y install libdigest-hmac-perl libdigest-sha1-perl &> /dev/null
fi

if grep "Debian GNU/Linux 7" /etc/issue.net > /dev/null ; then
 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libdigest-hmac-perl libdigest-sha-perl"; echo "XXX"
	apt-get -y install libdigest-hmac-perl libdigest-sha-perl &> /dev/null
fi

 echo "50" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libgd-gd2-perl"; echo "XXX"
	apt-get -y install libgd-gd2-perl &> /dev/null
	
 echo "60" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libnet-snmp-perl libsnmp-perl"; echo "XXX"
	apt-get -y install libnet-snmp-perl libsnmp-perl &> /dev/null

 echo "70" ; sleep 1
 echo "XXX" ; echo "apt-get -y install gettext"; echo "XXX"
	apt-get -y install gettext &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libxml-parser-perl"; echo "XXX"
	apt-get -y install libxml-parser-perl &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "Installation Composant Centreon Core"; echo "XXX"

	cat <<- EOF > $fichtemp
	delete from inventaire
	where composant='centreon-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( composant, uname, date, heure )
	values ( 'centreon-core' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by composant ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon Core" \
	  --gauge "Installation Composant Centreon Core" 10 62 0 \

menu_installation_composant_complementaire_centreon
}

#############################################################################
# Fonction Installation MIB SNMP Complementaire
#############################################################################

installation_mib_snmp()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation MIB SNMP Complementaire" \
	  --gauge "Installation MIB SNMP Complementaire" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='snmp-mibs-downloader' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation MIB SNMP Complementaire" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='snmp-mibs-downloader' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation MIB SNMP Complementaire" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_serveur_supervision			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_serveur_supervision
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_serveur_supervision
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation MIB SNMP Complementaire" \
	  --gauge "Installation MIB SNMP Complementaire" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='snmp-mibs-downloader' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='snmp-mibs-downloader' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation MIB SNMP Complementaire" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation MIB SNMP Complementaire" \
	  --gauge "Installation MIB SNMP Complementaire" 10 60 0 \


	apt-get -y install smistrip	&> /dev/null

	dpkg -i snmp-mibs-downloader_1.1_all.deb &> /dev/null
	download-mibs &> /dev/null

	rm -f /usr/share/mibs/ietf/IPATM-IPMC-MIB
	rm -f /usr/share/mibs/ietf/IPSEC-SPD-MIB
	rm -f /usr/share/mibs/ietf/SNMPv2-PDU
	rm -f /usr/share/mibs/iana/IANA-IPPM-METRICS-REGISTRY-MIB

	rm -f /root/$nom_fichier

	/etc/init.d/snmpd restart &> /dev/null

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation MIB SNMP Complementaire" \
	  --gauge "Installation MIB SNMP Complementaire" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='snmp-mibs-downloader' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'snmp-mibs-downloader' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation MIB SNMP Complementaire" \
	  --gauge "Terminer" 10 60 0 \

menu_installation_serveur_supervision
}

#############################################################################
# Fonction Installation Nagios Core
#############################################################################

installation_nagios_core()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --gauge "Installation Nagios Core" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nagios' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='nagios' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Nagios Core" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_nagios			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --gauge "Installation Nagios Core" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='nagios' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='nagios' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='nagios' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --gauge "Installation Nagios Core" 10 60 0 \

	if ! grep -w "^nagios" /etc/passwd > /dev/null ; then
		useradd --create-home --password  $(mkpasswd -H md5 nagios) --shell /bin/bash nagios
		groupadd nagcmd
		usermod -G nagcmd,nagios nagios
		usermod -G nagios,nagcmd www-data
	fi

	if [ -f $NagiosLockFile ] ; then
	/etc/init.d/nagios stop &> /dev/null
	fi
	
	tar xvzf $nom_fichier
	cd $nom_repertoire

	./configure

	if [ "$choix_version" = "3.3.1" ] ; then
		sed -i 's/for file in includes\/rss\/\*\;/for file in includes\/rss\/\*\.\*\;/g' ./html/Makefile
		sed -i 's/for file in includes\/rss\/extlib\/\*\;/for file in includes\/rss\/extlib\/\*\.\*\;/g' ./html/Makefile
	fi
	

	make all
	make install
	make install-init
	make install-commandmode
	make install-config
	make install-webconf


if [ "$choix_version" != "3.2.3" ] ; then
$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --default-item "1" \
	  --menu "Choix de l'interface Web de Nagios" 10 40 2 \
	  "1" "Interface Web Classique" \
	  "2" "Interface Web Exfoliation" 2> $fichtemp

valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Interface Web Classique
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		make install-classicui &> /dev/null
	fi

	# Interface Web Exfoliation
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		make install-exfoliation &> /dev/null
	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	;;

esac
fi

	cd ..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier
	
	htpasswd -c -b /usr/local/nagios/etc/htpasswd.users nagiosadmin nagios &> /dev/null

	/etc/init.d/apache2 restart &> /dev/null


(
 echo "80" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --gauge "Installation Daemon Nagios en cours" 10 60 0 \

	cat <<- EOF > /etc/init.d/nagios
	#!/bin/sh
	# 
	### BEGIN INIT INFO
	# Provides:          nagios
	# Required-Start:    sshd
	# Required-Stop:
	# Default-Start:     2 3 4 5
	# Default-Stop:      0 1 6
	# Short-Description: nagios
	# Description:       Nagios network monitor
	### END INIT INFO

	NagiosBin=/usr/local/nagios/bin/nagios
	NagiosCfg=/usr/local/nagios/etc/nagios.cfg
	NagiosLockFile=/usr/local/nagios/var/nagios.lock

	test -f \$NagiosBin || exit 0

	if [ -f \$NagiosLockFile ] ; then
	       NagiosPid=\`head -n 1 \$NagiosLockFile\`
	fi

	if ! ps -p \$NagiosPid > /dev/null 2>&1; then
	       rm -f \$NagiosLockFile
	fi

	case "\$1" in
	start)       echo "Starting nagios network monitor daemon: nagios"
	             \$NagiosBin -v \$NagiosCfg > /dev/null ;
	             if [ \$? -eq 0 ]; then
	                 if [ ! -f \$NagiosLockFile ] ; then
	                     \$NagiosBin -d \$NagiosCfg
	                 fi 
	             else
	                 echo "CONFIG ERROR!!!!!"
	                 echo "Check your Nagios configuration."
	             exit 1
	             fi
	             ;;
	stop)	      echo -n "Stopping nagios network monitor daemon: nagios"
	             if [ -f \$NagiosLockFile ] ; then
	                 kill \$NagiosPid
	             fi
	             echo "."
	             ;;
	restart)     echo "Restarting nagios network monitor daemon: nagios"
	             if [ -f \$NagiosLockFile ] ; then
	                 kill \$NagiosPid
	             fi
	             \$NagiosBin -v \$NagiosCfg > /dev/null ;
	             if [ \$? -eq 0 ]; then
	                 \$NagiosBin -d \$NagiosCfg
	             else
	                 echo "CONFIG ERROR!!!!!"
	                 echo "Check your Nagios configuration."
	             exit 1
	             fi
	             ;;
	status)      if [ -f \$NagiosLockFile ] ; then
	                 echo "nagios (pid \$NagiosPid) is running."
	             else
	                 echo "nagios is not running."
	             fi
	             ;;
	checkconfig) echo "Running configuration check....."
	             \$NagiosBin -v \$NagiosCfg > /dev/null ;
	             if [ \$? -eq 0 ]; then
	                 echo "Configuration is OK."
	             if [ -f \$NagiosLockFile ] ; then
	                 echo "nagios (pid \$NagiosPid) is running."
	             fi   
	             else
	             if [ -f \$NagiosLockFile ] ; then
	                 kill \$NagiosPid
	             fi
	                 echo "CONFIG ERROR!!!!!"
	                 echo "Check your Nagios configuration."
	             exit 1
	             fi
	             ;;
	*)           echo "Usage: /etc/init.d/nagios start|stop|restart|status|checkconfig"
	             exit 1
	             ;;
	esac
	exit 0
	EOF

	chmod 755 /etc/init.d/nagios

	update-rc.d nagios defaults &> /dev/null

	/etc/init.d/nagios start &> /dev/null

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --gauge "Installation Nagios Core" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nagios' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'nagios' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Core" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_nagios
}

#############################################################################
# Fonction Installation Nagios Plugins
#############################################################################

installation_nagios_plugins()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --gauge "Installation Nagios Plugins" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nagios-plugins' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='nagios-plugins' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Nagios Plugins" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_nagios			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --gauge "Installation Nagios Plugins" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='nagios-plugins' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='nagios-plugins' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='nagios-plugins' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --default-item "1" \
	  --menu "Quel est votre choix" 10 68 2 \
	  "1" "Installation Nagios Plugins Pour Nagios-Core" \
	  "2" "Installation Nagios Plugins Pour Centreon-Engine" 2> $fichtemp

valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Nagios Plugins Pour Nagios-Core
	if [ "$choix" = "1" ]
	then

	if [ -f $NagiosLockFile ] ; then
	/etc/init.d/nagios stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire
	
	./configure --with-nagios-user=nagios --with-nagios-group=nagios --prefix=/usr/local/nagios/
	make all
	make install

	cd ..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

	/etc/init.d/nagios start &> /dev/null	
	
	fi


	# Installation Nagios Plugins Pour Centreon-Engine
	if [ "$choix" = "2" ]
	then
	
	if ! grep -w "^centreon-engine" /etc/passwd > /dev/null ; then
		groupadd -g 6001 centreon-engine
		useradd -u 6001 -g centreon-engine -m -r -d /var/lib/centreon-engine -c "Centreon-engine Admin" centreon-engine
	fi

	if [ -f $CentenginePidFile ] ; then
	/etc/init.d/centengine stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire
	
	./configure --with-nagios-user=centreon-engine --with-nagios-group=centreon-engine --prefix=/usr/local/centreon-plugins 
	make all
	make install

	rm -rf /usr/local/centreon-plugins/include/
	rm -rf /usr/local/centreon-plugins/share/

	cd ..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

	/etc/init.d/centengine start &> /dev/null	

	fi
	
	;;


 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	;;

esac

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --gauge "Installation Nagios Plugins" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'nagios-plugins' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_nagios
}

#############################################################################
# Fonction Installation NDOutils
#############################################################################

installation_ndoutils()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --gauge "Installation NDOutils" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='ndoutils' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='ndoutils' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation NDOutils" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_nagios			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --gauge "Installation NDOutils" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='ndoutils' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='ndoutils' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='ndoutils' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='ndoutils-light' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier_patch=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='ndoutils-light' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier_patch=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp


(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --gauge "Installation NDOutils" 10 60 0 \

	if [ -f $NagiosLockFile ] ; then
	/etc/init.d/nagios stop &> /dev/null
	fi

	if [ -f $Ndo2dbPidFile ] ; then
	/etc/init.d/ndo2db stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --yesno "Installation du patch de NDOutils" 6 38


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation du patch de NDOutils (Oui)
	echo "Installation du patch de NDOutils (Oui)"
	wget --no-check-certificate -P /root/$nom_repertoire/ $url_fichier_patch &> /dev/null
	patch -p1 -N < $nom_fichier_patch	
	;;


 1)	# Installation du patch de NDOutils (Non)
	echo "Installation du patch de NDOutils (Non)"
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	;;

esac

	./configure --prefix=/usr/local/nagios/ --enable-mysql --disable-pgsql --with-ndo2db-user=nagios --with-ndo2db-group=nagios
	make

	cp ./src/ndomod-3x.o /usr/local/nagios/bin/ndomod.o
	cp ./src/ndo2db-3x /usr/local/nagios/bin/ndo2db
	cp ./config/ndo2db.cfg-sample /usr/local/nagios/etc/ndo2db.cfg
	cp ./config/ndomod.cfg-sample /usr/local/nagios/etc/ndomod.cfg

	chmod 774 /usr/local/nagios/bin/ndo*
	chown nagios:nagios /usr/local/nagios/bin/ndo*

	mkdir -p /var/run/ndo2db
	chown -R nagios /var/run/ndo2db

	if ! grep "lock_file=/var/run/ndo2db/ndo2db.pid" /usr/local/nagios/etc/ndo2db.cfg > /dev/null ; then
		ligne=$(sed -n '/lock_file/=' /usr/local/nagios/etc/ndo2db.cfg)
		sed -i ""$ligne"d" /usr/local/nagios/etc/ndo2db.cfg
		sed -i "$ligne"i"\lock_file=/var/run/ndo2db/ndo2db.pid" /usr/local/nagios/etc/ndo2db.cfg
	fi

	cd ..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

(
 echo "80" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --gauge "Installation Daemon NDOutils en cours" 10 60 0 \

	cat <<- EOF > /etc/init.d/ndo2db
	#!/bin/sh
	# 
	### BEGIN INIT INFO
	# Provides:          ndo2db
	# Required-Start:    sshd
	# Required-Stop:     
	# Default-Start:     2 3 4 5
	# Default-Stop:      0 1 6
	# Short-Description: Start/Stop the nagios data out daemon
	# Description: 	
	### END INIT INFO

	Ndo2dbBin=/usr/local/nagios/bin/ndo2db
	Ndo2dbCfg=/usr/local/nagios/etc/ndo2db.cfg
	Ndo2dbPidFile=/var/run/ndo2db/ndo2db.pid

	test -f \$Ndo2dbBin || exit 0

	if ! grep "^131072000" /proc/sys/kernel/msgmnb > /dev/null ; then
	echo 131072000 > /proc/sys/kernel/msgmnb
	fi

	if ! grep "^131072000" /proc/sys/kernel/msgmax > /dev/null ; then
	echo 131072000 > /proc/sys/kernel/msgmax
	fi

	creation_fichier_pid ()
	{
	if [ ! -f \$Ndo2dbPidFile ] && 
	   ! grep -w "^lock_file" /usr/local/nagios/etc/ndo2db.cfg ; then
	       Ndo2dbPID=\`pidof ndo2db\`
	       echo \$Ndo2dbPID > \$Ndo2dbPidFile
	fi
	}

	suppression_fichier_pid ()
	{
	if [ -f \$Ndo2dbPidFile ] && 
	   ! grep -w "^lock_file" /usr/local/nagios/etc/ndo2db.cfg ; then
	       rm -f \$Ndo2dbPidFile
	fi
	}

	if [ -f \$Ndo2dbPidFile ] ; then
              Ndo2dbPid=\`head -n 1 \$Ndo2dbPidFile\`
	fi

	if ! ps -p \$Ndo2dbPid > /dev/null 2>&1; then
	       rm -f \$Ndo2dbPidFile
	fi

	case "\$1" in
	start)   echo -n "Starting ndo2db daemon: ndo2db"
	         start-stop-daemon --start --quiet --exec \$Ndo2dbBin -- -c \$Ndo2dbCfg
	         creation_fichier_pid
	         echo "."
	         ;;
	stop)	  echo -n "Stopping ndo2db daemon: ndo2db"
	         start-stop-daemon --stop --quiet --exec \$Ndo2dbBin
	         suppression_fichier_pid
	         echo "."
	         ;;
	restart) echo -n "Restarting ndo2db daemon: ndo2db"
	         start-stop-daemon --stop --quiet --exec \$Ndo2dbBin
	         suppression_fichier_pid
	         start-stop-daemon --start --quiet --exec \$Ndo2dbBin -- -c \$Ndo2dbCfg
	         creation_fichier_pid
	         echo "."
	         ;;
	status)  if [ -f \$Ndo2dbPidFile ] ; then
	              echo "ndo2db (pid \$Ndo2dbPid) is running."
	         else
	              echo "ndo2db is not running."
	         fi
	         ;;
	*)       echo "Usage: /etc/init.d/ndo2db start|stop|restart|status"
	         exit 1
	         ;;
	esac
	exit 0
	EOF

	chmod 755 /etc/init.d/ndo2db

	update-rc.d ndo2db defaults &> /dev/null

	/etc/init.d/nagios start &> /dev/null
	/etc/init.d/ndo2db start &> /dev/null

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --gauge "Installation NDOutils" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='ndoutils' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'ndoutils' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NDOutils" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_nagios
}

#############################################################################
# Fonction Installation NRPE
#############################################################################

installation_nrpe()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --gauge "Installation NRPE" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nrpe' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Client NRPE" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='nrpe' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation NRPE" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_nagios			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche chap."
	rm -f $fichtemp
	menu_installation_suite_nagios
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --gauge "Installation NRPE" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='nrpe' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='nrpe' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='nrpe' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --gauge "Installation NRPE" 10 60 0 \

	if ! grep -w "^nagios" /etc/passwd > /dev/null ; then
		useradd --create-home --password  $(mkpasswd -H md5 nagios) --shell /bin/bash nagios
		groupadd nagcmd
		usermod -G nagcmd,nagios nagios
		usermod -G nagios,nagcmd www-data
	fi

	if [ -f $NrpePidFile ] ; then
	/etc/init.d/nrpe stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire

	if [ -d /usr/lib/x86_64-linux-gnu ] ; then
	./configure --enable-command-args --enable-ssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
	else
	./configure --enable-command-args --enable-ssl
	fi
	 
	make all
	make install

	make install-plugin
	make install-daemon
	make install-daemon-config

	cd ..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier



$DIALOG  --ok-label "Validation" \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --form "Quel est votre choix" 8 60 0 \
	  "Serveur Nagios:" 1 1 "192.168.4.60"  1 17 36 0 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Configuration du Serveur Nagios
	
	if ! grep "allowed_hosts=127.0.0.1," /usr/local/nagios/etc/nrpe.cfg > /dev/null ; then
		ligne=$(sed -n '/allowed_hosts=127.0.0.1/=' /usr/local/nagios/etc/nrpe.cfg)
		sed -i ""$ligne"d" /usr/local/nagios/etc/nrpe.cfg
		sed -i "$ligne"i"\allowed_hosts=127.0.0.1,$choix" /usr/local/nagios/etc/nrpe.cfg
	fi	

	rm -f $fichtemp
	;;

 1)	# Appuyé sur Touche Annuler
	echo "Appuyé sur Touche Annuler."
	rm -f $fichtemp
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	;;

esac

	mkdir -p /var/run/nrpe
	chown -R nagios /var/run/nrpe

	if ! grep "pid_file=/var/run/nrpe/nrpe.pid" /usr/local/nagios/etc/nrpe.cfg > /dev/null ; then
		ligne=$(sed -n '/nrpe.pid/=' /usr/local/nagios/etc/nrpe.cfg)
		sed -i ""$ligne"d" /usr/local/nagios/etc/nrpe.cfg
		sed -i "$ligne"i"\pid_file=/var/run/nrpe/nrpe.pid" /usr/local/nagios/etc/nrpe.cfg
	fi

	if ! grep "dont_blame_nrpe=1" /usr/local/nagios/etc/nrpe.cfg > /dev/null ; then
		ligne=$(sed -n '/dont_blame_nrpe=/=' /usr/local/nagios/etc/nrpe.cfg)
		sed -i ""$ligne"d" /usr/local/nagios/etc/nrpe.cfg
		sed -i "$ligne"i"\dont_blame_nrpe=1" /usr/local/nagios/etc/nrpe.cfg
	fi

(
 echo "80" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --gauge "Installation Daemon NRPE en cours" 10 60 0 \

	cat <<- EOF > /etc/init.d/nrpe
	#!/bin/sh
	# 
	### BEGIN INIT INFO
	# Provides:          nrpe
	# Required-Start:    sshd
	# Required-Stop:     
	# Default-Start:     2 3 4 5
	# Default-Stop:      0 1 6
	# Short-Description: Start/Stop the nagios remote plugin execution daemon
	# Description:
	### END INIT INFO

	NrpeBin=/usr/local/nagios/bin/nrpe
	NrpeCfg=/usr/local/nagios/etc/nrpe.cfg
	NrpePidFile=/var/run/nrpe/nrpe.pid

	test -f \$NrpeBin || exit 0

	if [ -f \$NrpePidFile ] ; then
		NrpePid=\`head -n 1 \$NrpePidFile\`
	fi

	if ! ps -p \$NrpePid > /dev/null 2>&1; then
	       rm -f \$NrpePidFile
	fi

	case "\$1" in
	start)   echo -n "Starting nagios remote plugin daemon: nrpe"
	         start-stop-daemon --start --quiet --exec \$NrpeBin -- -c \$NrpeCfg -d
	         echo "." 
	         ;;
	stop)	  echo -n "Stopping nagios remote plugin daemon: nrpe"
	         start-stop-daemon --stop --quiet --exec \$NrpeBin
	         echo "."
	         ;;
	restart) echo -n "Restarting nagios remote plugin daemon: nrpe"
	         start-stop-daemon --stop --quiet --exec \$NrpeBin
	         start-stop-daemon --start --quiet --exec \$NrpeBin -- -c \$NrpeCfg -d
	         echo "."
	         ;;
	status)  if [ -f \$NrpePidFile ] ; then
	              echo "nrpe (pid \$NrpePid) is running."
	         else
	              echo "nrpe is not running."
	         fi
	         ;;
	*)       echo "Usage: /etc/init.d/nrpe start|stop|restart|status"
	         exit 1
	         ;;
	esac
	exit 0
	EOF

	chmod 755 /etc/init.d/nrpe

	update-rc.d nrpe defaults &> /dev/null

	/etc/init.d/nrpe start &> /dev/null

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --gauge "Installation NRPE" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'nrpe' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_nagios
}

#############################################################################
# Fonction Installation Centreon Clib
#############################################################################

installation_centreon_clib()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Clib" \
	  --gauge "Installation Centreon Clib" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-clib' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Clib" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon-clib' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon Clib" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_centreon			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Clib" \
	  --gauge "Installation Centreon Clib" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-clib' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-clib' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-clib' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Clib" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier --output-document=$nom_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Clib" \
	  --gauge "Installation Centreon Clib" 10 60 0 \


	tar xvzf $nom_fichier
	cd $nom_repertoire/build
	
	cmake \
		-DWITH_TESTING=0 \
		-DWITH_PREFIX=/usr/local/centreon-clib \
		-DWITH_SHARED_LIB=1 \
		-DWITH_STATIC_LIB=0 \
		-DWITH_PKGCONFIG_DIR=/usr/lib/pkgconfig .

	make
	make install

	if ! grep "/usr/local/centreon-clib/lib" /etc/ld.so.conf.d/libc.conf > /dev/null ; then
		echo "/usr/local/centreon-clib/lib" >> /etc/ld.so.conf.d/libc.conf
		ldconfig -v &> /dev/null
	fi

	cd ../..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Clib" \
	  --gauge "Installation Centreon Clib" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-clib' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-clib' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Clib" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_centreon
}

#############################################################################
# Fonction Installation Centreon Perl Connector 
#############################################################################

installation_centreon_perl_connector()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Perl Connector" \
	  --gauge "Installation Centreon Perl Connector" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-perl-connector' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Perl Connector" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon-perl-connector' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon Perl Connector" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_centreon			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Perl Connector" \
	  --gauge "Installation Centreon Perl Connector" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-perl-connector' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-perl-connector' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-perl-connector' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Perl Connector" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier --output-document=$nom_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Perl Connector" \
	  --gauge "Installation Centreon Perl Connector" 10 60 0 \


	tar xvzf $nom_fichier
	cd $nom_repertoire/perl/build
	
	cmake \
		-DWITH_PREFIX=/usr/local/centreon-connector \
		-DWITH_CENTREON_CLIB_INCLUDE_DIR=/usr/local/centreon-clib/include \
		-DWITH_CENTREON_CLIB_LIBRARIES=/usr/local/centreon-clib/lib/libcentreon_clib.so \
		-DWITH_TESTING=0 .

	make
	make install

	cd ../../..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Perl Connector" \
	  --gauge "Installation Centreon Perl Connector" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-perl-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-perl-connector' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Perl Connector" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_centreon
}

#############################################################################
# Fonction Installation Centreon SSH Connector
#############################################################################

installation_centreon_ssh_connector()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon SSH Connector" \
	  --gauge "Installation Centreon SSH Connector" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-ssh-connector' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon SSH Connector" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon-ssh-connector' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon SSH Connector" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_centreon			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon SSH Connector" \
	  --gauge "Installation Centreon SSH Connector" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-ssh-connector' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-ssh-connector' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-ssh-connector' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon SSH Connector" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier --output-document=$nom_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon SSH Connector" \
	  --gauge "Installation Centreon SSH Connector" 10 60 0 \


	tar xvzf $nom_fichier
	cd $nom_repertoire/ssh/build
	
	cmake \
		-DWITH_PREFIX=/usr/local/centreon-connector \
		-DWITH_CENTREON_CLIB_INCLUDE_DIR=/usr/local/centreon-clib/include \
		-DWITH_CENTREON_CLIB_LIBRARIES=/usr/local/centreon-clib/lib/libcentreon_clib.so \
		-DWITH_TESTING=0 .

	make
	make install

	cd ../../..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon SSH Connector" \
	  --gauge "Installation Centreon SSH Connector" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-ssh-connector' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-ssh-connector' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon SSH Connector" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_centreon
}

#############################################################################
# Fonction Installation Centreon Engine
#############################################################################

installation_centreon_engine()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --gauge "Installation Centreon Engine" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-engine' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon-engine' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon Engine" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_centreon			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --gauge "Installation Centreon Engine" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-engine' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-engine' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-engine' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier --output-document=$nom_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --gauge "Installation Centreon Engine" 10 60 0 \


	if ! grep -w "^centreon-engine" /etc/passwd > /dev/null ; then
		groupadd -g 6001 centreon-engine
		useradd -u 6001 -g centreon-engine -m -r -d /var/lib/centreon-engine -c "Centreon-engine Admin" centreon-engine
	fi

	if [ -f $CentenginePidFile ] ; then
	/etc/init.d/centengine stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire/build
	
	cmake \
		-DWITH_CENTREON_CLIB_INCLUDE_DIR=/usr/local/centreon-clib/include \
		-DWITH_CENTREON_CLIB_LIBRARY_DIR=/usr/local/centreon-clib/lib \
		-DWITH_PREFIX=/usr/local/centreon-engine \
		-DWITH_USER=centreon-engine \
		-DWITH_GROUP=centreon-engine \
		-DWITH_LOGROTATE_SCRIPT=1 \
		-DWITH_VAR_DIR=/var/log/centreon-engine \
		-DWITH_RW_DIR=/var/lib/centreon-engine/rw \
		-DWITH_STARTUP_DIR=/etc/init.d \
		-DWITH_PKGCONFIG_SCRIPT=1 \
		-DWITH_PKGCONFIG_DIR=/usr/lib/pkgconfig \
		-DWITH_TESTING=0 \
		-DWITH_WEBSERVICE=1 .

	make
	make install

	cd ../..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

(
 echo "80" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --gauge "Installation Daemon Centreon Engine en cours" 10 60 0 \

	chmod 755 /etc/init.d/centengine

	update-rc.d centengine defaults &> /dev/null

	/etc/init.d/centengine start &> /dev/null

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --gauge "Installation Centreon Engine" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-engine' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Engine" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_centreon
}

#############################################################################
# Fonction Installation Centreon Broker
#############################################################################

installation_centreon_broker()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --gauge "Installation Centreon Broker" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-broker' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon-broker' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon Broker" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_centreon			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --gauge "Installation Centreon Broker" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-broker' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-broker' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-broker' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier --output-document=$nom_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --gauge "Installation Centreon Broker" 10 60 0 \


	if ! grep -w "^centreon-broker" /etc/passwd > /dev/null ; then
		groupadd -g 6002 centreon-broker
		useradd -u 6002 -g centreon-broker -m -r -d /var/lib/centreon-broker -c "Centreon-broker Admin" centreon-broker
	fi

	if [ -f $CbdbrokerPidFile ] || [ -f $CbdbrokerPidFile ] ; then	
	/etc/init.d/cbd stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire/build
	
	cmake \
		-DWITH_DAEMONS='central-broker;central-rrd' \
		-DWITH_GROUP=centreon-broker \
		-DWITH_PREFIX=/usr/local/centreon-broker \
		-DWITH_STARTUP_DIR=/etc/init.d \
		-DWITH_STARTUP_SCRIPT=auto \
		-DWITH_TESTING=0 \
		-DWITH_USER=centreon-broker .

	make
	make install

	cd ../..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

	if [ ! -d /var/log/centreon-broker ] ; then
	mkdir /var/log/centreon-broker
	fi

	chown centreon-broker:centreon-broker  /var/log/centreon-broker

	chmod 775 /var/log/centreon-broker

	chmod 775 /var/lib/centreon-broker

(
 echo "80" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --gauge "Installation Daemon Centreon Broker en cours" 10 60 0 \

	chmod 755 /etc/init.d/cbd

	update-rc.d cbd defaults &> /dev/null

	if [ -f /usr/local/centreon-broker/etc/central-broker.xml ] ; then
	/etc/init.d/cbd start &> /dev/null
	fi

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --gauge "Installation Centreon Broker" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-broker' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Broker" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_centreon
}

#############################################################################
# Fonction Installation Centreon Core
#############################################################################

installation_centreon_core()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Core" \
	  --gauge "Installation Centreon Core" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-core' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Core" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 10 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon-core' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon Core" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_centreon			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Core" \
	  --gauge "Installation Centreon Core" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-core' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-core' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-core' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp


	version_translations=`expr $choix_version | sed 's/..$//'`
	version_choix=`expr $choix_version | sed 's/..$//'`

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-translations-messages' and version='$version_translations.x' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier_messages=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-translations-messages' and version='$version_translations.x' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier_messages=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-translations-help' and version='$version_translations.x' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier_help=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-translations-help' and version='$version_translations.x' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier_help=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Core" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null
	wget --no-check-certificate -P /root/ $url_fichier_messages &> /dev/null
	wget --no-check-certificate -P /root/ $url_fichier_help &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Core" \
	  --gauge "Installation Centreon Core" 10 60 0 \


	if ! grep -w "Centreon Admin" /etc/passwd > /dev/null ; then
		groupadd -g 6000 centreon
		useradd -u 6000 -g centreon -m -r -d /var/lib/centreon -c "Centreon Admin" centreon
	fi

	if [ -f $NagiosLockFile ] ; then
	/etc/init.d/nagios stop &> /dev/null
	fi

	if [ -f $Ndo2dbPidFile ] ; then
	/etc/init.d/ndo2db stop &> /dev/null
	fi

	if [ -f $CentenginePidFile ] ; then
	/etc/init.d/centengine stop &> /dev/null
	fi

	if [ -f $CbdbrokerPidFile ] || [ -f $CbdrrdPidFile ] ; then	
	/etc/init.d/cbd stop &> /dev/null
	fi

	if [ -f $CentcorePidFile ] ; then
	/etc/init.d/centcore stop &> /dev/null
	fi

	if [ -f $CentstoragePidFile ] ; then
	/etc/init.d/centstorage stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire

	if [ "$version_choix" = "2.3" ] ; then

	if grep "DEFAULT_NDO2DB_BINARY" /root/$nom_repertoire/varinstall/vars > /dev/null ; then
		ligne=$(sed -n '/DEFAULT_NDO2DB_BINARY/=' /root/$nom_repertoire/varinstall/vars)
		sed -i ""$ligne"d" /root/$nom_repertoire/varinstall/vars
		sed -i "$ligne"i'\DEFAULT_NDO2DB_BINARY="/usr/local/nagios/bin/ndo2db"' /root/$nom_repertoire/varinstall/vars
	fi

	if grep "DEFAULT_NDOMOD_BINARY" /root/$nom_repertoire/varinstall/vars > /dev/null ; then
		ligne=$(sed -n '/DEFAULT_NDOMOD_BINARY/=' /root/$nom_repertoire/varinstall/vars)
		sed -i ""$ligne"d" /root/$nom_repertoire/varinstall/vars
		sed -i "$ligne"i'\DEFAULT_NDOMOD_BINARY="/usr/local/nagios/bin/ndomod.o"' /root/$nom_repertoire/varinstall/vars
	fi

	if grep "# Required-Start:" /root/$nom_repertoire/tmpl/install/centcore.init.d > /dev/null ; then
		ligne=$(sed -n '/# Required-Start:/=' /root/$nom_repertoire/tmpl/install/centcore.init.d)
		sed -i ""$ligne"d" /root/$nom_repertoire/tmpl/install/centcore.init.d
		sed -i "$ligne"i'\# Required-Start:	$local_fs $network' /root/$nom_repertoire/tmpl/install/centcore.init.d
	fi

	if grep "# Default-Start:" /root/$nom_repertoire/tmpl/install/centcore.init.d > /dev/null ; then
		ligne=$(sed -n '/# Default-Start:/=' /root/$nom_repertoire/tmpl/install/centcore.init.d)
		sed -i ""$ligne"d" /root/$nom_repertoire/tmpl/install/centcore.init.d
		sed -i "$ligne"i'\# Default-Start:  2 3 4 5' /root/$nom_repertoire/tmpl/install/centcore.init.d
	fi

	if grep "# Required-Start:" /root/$nom_repertoire/tmpl/install/centstorage.init.d > /dev/null ; then
		ligne=$(sed -n '/# Required-Start:/=' /root/$nom_repertoire/tmpl/install/centstorage.init.d)
		sed -i ""$ligne"d" /root/$nom_repertoire/tmpl/install/centstorage.init.d
		sed -i "$ligne"i'\# Required-Start:	$local_fs $network' /root/$nom_repertoire/tmpl/install/centstorage.init.d
	fi

	if grep "# Default-Start:" /root/$nom_repertoire/tmpl/install/centstorage.init.d > /dev/null ; then
		ligne=$(sed -n '/# Default-Start:/=' /root/$nom_repertoire/tmpl/install/centstorage.init.d)
		sed -i ""$ligne"d" /root/$nom_repertoire/tmpl/install/centstorage.init.d
		sed -i "$ligne"i'\# Default-Start:  2 3 4 5' /root/$nom_repertoire/tmpl/install/centstorage.init.d
	fi

	fi

	
	if [ "$version_choix" = "2.4" ] ; then

	if ! grep "innodb_file_per_table=1" /etc/mysql/my.cnf > /dev/null ; then
	ligne=$(sed -n '/# Read the manual for more InnoDB/=' /etc/mysql/my.cnf)
	sed -i "`expr $ligne + 1`"i"\#" /etc/mysql/my.cnf
	sed -i "`expr $ligne + 2`"i"\innodb_file_per_table=1" /etc/mysql/my.cnf

	/etc/init.d/mysql restart &> /dev/null
	fi
	
	if grep "INSTALL_DIR_NAGIOS" /root/$nom_repertoire/www/install/var/engines/nagios > /dev/null ; then
		ligne=$(sed -n '/INSTALL_DIR_NAGIOS/=' /root/$nom_repertoire/www/install/var/engines/nagios)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/engines/nagios
		sed -i "$ligne"i'\INSTALL_DIR_NAGIOS;Nagios directory;1;0;/usr/local/nagios' /root/$nom_repertoire/www/install/var/engines/nagios
	fi

	if grep "NAGIOSTATS_BINARY" /root/$nom_repertoire/www/install/var/engines/nagios > /dev/null ; then
		ligne=$(sed -n '/NAGIOSTATS_BINARY/=' /root/$nom_repertoire/www/install/var/engines/nagios)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/engines/nagios
		sed -i "$ligne"i'\NAGIOSTATS_BINARY;Nagiostats binary;1;1;/usr/local/nagios/bin/nagiostats' /root/$nom_repertoire/www/install/var/engines/nagios
	fi

	if grep "NAGIOS_IMG" /root/$nom_repertoire/www/install/var/engines/nagios > /dev/null ; then
		sed -i "s/usr\/share\/nagios\/html\/images/usr\/local\/nagios\/share\/images/g" /root/$nom_repertoire/www/install/var/engines/nagios
	fi


	if grep "INSTALL_DIR_ENGINE" /root/$nom_repertoire/www/install/var/engines/centreon-engine > /dev/null ; then
		ligne=$(sed -n '/INSTALL_DIR_ENGINE/=' /root/$nom_repertoire/www/install/var/engines/centreon-engine)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/engines/centreon-engine
		sed -i "$ligne"i'\INSTALL_DIR_ENGINE;Centreon Engine directory;1;0;/usr/local/centreon-engine' /root/$nom_repertoire/www/install/var/engines/centreon-engine
	fi

	if grep "CENTREON_ENGINE_STATS_BINARY" /root/$nom_repertoire/www/install/var/engines/centreon-engine > /dev/null ; then
		ligne=$(sed -n '/CENTREON_ENGINE_STATS_BINARY/=' /root/$nom_repertoire/www/install/var/engines/centreon-engine)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/engines/centreon-engine
		sed -i "$ligne"i'\CENTREON_ENGINE_STATS_BINARY;Centreon Engine Stats binary;1;1;/usr/local/centreon-engine/bin/centenginestats' /root/$nom_repertoire/www/install/var/engines/centreon-engine
	fi

	if grep "MONITORING_VAR_LIB" /root/$nom_repertoire/www/install/var/engines/centreon-engine > /dev/null ; then
		ligne=$(sed -n '/MONITORING_VAR_LIB/=' /root/$nom_repertoire/www/install/var/engines/centreon-engine)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/engines/centreon-engine
		sed -i "$ligne"i'\MONITORING_VAR_LIB;Centreon Engine var lib directory;1;0;/var/lib/centreon-engine' /root/$nom_repertoire/www/install/var/engines/centreon-engine
	fi

	if grep "CENTREON_ENGINE_CONNECTORS" /root/$nom_repertoire/www/install/var/engines/centreon-engine > /dev/null ; then
		ligne=$(sed -n '/CENTREON_ENGINE_CONNECTORS/=' /root/$nom_repertoire/www/install/var/engines/centreon-engine)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/engines/centreon-engine
		sed -i "$ligne"i'\CENTREON_ENGINE_CONNECTOR;Centreon Engine Connector path;0;0;/usr/local/centreon-connector' /root/$nom_repertoire/www/install/var/engines/centreon-engine
	fi

	if grep "CENTREON_ENGINE_LIB" /root/$nom_repertoire/www/install/var/engines/centreon-engine > /dev/null ; then
		ligne=$(sed -n '/CENTREON_ENGINE_LIB/=' /root/$nom_repertoire/www/install/var/engines/centreon-engine)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/engines/centreon-engine
		sed -i "$ligne"i'\CENTREON_ENGINE_LIB;Centreon Engine Library (*.so) directory;1;0;/usr/local/centreon-engine/lib/centreon-engine' /root/$nom_repertoire/www/install/var/engines/centreon-engine
	fi


	if grep "CENTREONBROKER_ETC" /root/$nom_repertoire/www/install/var/brokers/centreon-broker > /dev/null ; then
		ligne=$(sed -n '/CENTREONBROKER_ETC/=' /root/$nom_repertoire/www/install/var/brokers/centreon-broker)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/brokers/centreon-broker
		sed -i "$ligne"i'\CENTREONBROKER_ETC;Centreon Broker etc directory;1;0;/usr/local/centreon-broker/etc' /root/$nom_repertoire/www/install/var/brokers/centreon-broker
	fi

	if grep "CENTREONBROKER_CBMOD" /root/$nom_repertoire/www/install/var/brokers/centreon-broker > /dev/null ; then
		ligne=$(sed -n '/CENTREONBROKER_CBMOD/=' /root/$nom_repertoire/www/install/var/brokers/centreon-broker)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/brokers/centreon-broker
		sed -i "$ligne"i'\CENTREONBROKER_CBMOD;Centreon Broker module (cbmod.so);0;1;/usr/local/centreon-broker/lib/cbmod.so' /root/$nom_repertoire/www/install/var/brokers/centreon-broker
	fi

	if grep "CENTREONBROKER_LOG" /root/$nom_repertoire/www/install/var/brokers/centreon-broker > /dev/null ; then
		ligne=$(sed -n '/CENTREONBROKER_LOG/=' /root/$nom_repertoire/www/install/var/brokers/centreon-broker)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/brokers/centreon-broker
		sed -i "$ligne"i'CENTREONBROKER_LOG;Centreon Broker log directory;1;0;/var/log/centreon-broker' /root/$nom_repertoire/www/install/var/brokers/centreon-broker
	fi

	if grep "CENTREONBROKER_VARLIB" /root/$nom_repertoire/www/install/var/brokers/centreon-broker > /dev/null ; then
		ligne=$(sed -n '/CENTREONBROKER_VARLIB/=' /root/$nom_repertoire/www/install/var/brokers/centreon-broker)
		sed -i ""$ligne"d" /root/$nom_repertoire/www/install/var/brokers/centreon-broker
		sed -i "$ligne"i'CENTREONBROKER_VARLIB;Retention file directory;1;0;/var/lib/centreon-broker' /root/$nom_repertoire/www/install/var/brokers/centreon-broker
	fi

	if grep "CENTREONBROKER_LIB" /root/$nom_repertoire/www/install/var/brokers/centreon-broker > /dev/null ; then
		sed -i "s/usr\/share\/centreon\/lib\/centreon-broker/usr\/local\/centreon-broker\/lib\/centreon-broker/g" /root/$nom_repertoire/www/install/var/brokers/centreon-broker
	fi


	if grep "NDOMOD_BINARY" /root/$nom_repertoire/www/install/var/brokers/ndoutils > /dev/null ; then
		sed -i "s/usr\/lib64\/nagios\/ndomod.o/usr\/local\/nagios\/bin\/ndomod.o/g" /root/$nom_repertoire/www/install/var/brokers/ndoutils
	fi

	fi



	if [ -f /usr/local/nagios/bin/nagios ] ; then

	if [ ! -f /etc/centreon/instCentCore.conf ] ||
	   [ ! -f /etc/centreon/instCentPlugins.conf ] ||
	   [ ! -f /etc/centreon/instCentStorage.conf ] ||
	   [ ! -f /etc/centreon/instCentWeb.conf ] ; then

	cat <<- EOF > $fichtemp
	BROKER_ETC=/usr/local/nagios/etc
	BROKER_USER=nagios
	BROKER_INIT_SCRIPT=/etc/init.d/ndo2db
	MONITORINGENGINE_ETC=/usr/local/nagios/etc
	MONITORINGENGINE_INIT_SCRIPT=/etc/init.d/nagios
	MONITORINGENGINE_BINARY=/usr/local/nagios/bin/nagios
	MONITORINGENGINE_LOG=/usr/local/nagios/var
	MONITORINGENGINE_USER=nagios
	PLUGIN_DIR=/usr/local/nagios/libexec
	EOF

	./install.sh -i -f $fichtemp

	rm -f $fichtemp
	
	else

	./install.sh -u /etc/centreon/

	fi
	fi


	if [ -f /usr/local/centreon-engine/bin/centengine ] ; then

	if [ ! -f /etc/centreon/instCentCore.conf ] ||
	   [ ! -f /etc/centreon/instCentPlugins.conf ] ||
	   [ ! -f /etc/centreon/instCentStorage.conf ] ||
	   [ ! -f /etc/centreon/instCentWeb.conf ] ; then

	cat <<- EOF > $fichtemp
	MONITORINGENGINE_USER=centreon-engine
	BROKER_USER=centreon-broker
	MONITORINGENGINE_LOG=/var/log/centreon-engine
	PLUGIN_DIR=/usr/local/centreon-plugins/libexec
	MONITORINGENGINE_INIT_SCRIPT=/etc/init.d/centengine
	MONITORINGENGINE_BINARY=/usr/local/centreon-engine/bin/centengine
	MONITORINGENGINE_ETC=/usr/local/centreon-engine/etc
	BROKER_ETC=/usr/local/centreon-broker/etc
	BROKER_INIT_SCRIPT=/etc/init.d/cbd
	EOF

	./install.sh -i -f $fichtemp

	rm -f $fichtemp
	
	else

	./install.sh -u /etc/centreon/

	fi
	fi


	cd ..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier


	if [ -d /usr/local/centreon ] ; then

	mkdir -p /usr/local/centreon/www/locale/fr_FR.UTF-8/ 
	mkdir -p /usr/local/centreon/www/locale/fr_FR.UTF-8/LC_MESSAGES/ 

	msgfmt $nom_fichier_messages -o /usr/local/centreon/www/locale/fr_FR.UTF-8/LC_MESSAGES/messages.mo 
	msgfmt $nom_fichier_help -o /usr/local/centreon/www/locale/fr_FR.UTF-8/LC_MESSAGES/help.mo	

	fi

	rm -f /root/$nom_fichier_messages
	rm -f /root/$nom_fichier_help

	if [ -f /usr/local/nagios/bin/nagios ] ; then
	/etc/init.d/nagios start &> /dev/null
	fi

	if [ -f /usr/local/nagios/bin/ndo2db ] ; then
	/etc/init.d/ndo2db start &> /dev/null
	fi

	if [ -f /usr/local/centreon-engine/bin/centengine ] ; then
	/etc/init.d/centengine start &> /dev/null
	fi

	if [ -f /usr/local/centreon-broker/etc/central-broker.xml ] ; then
	/etc/init.d/cbd start &> /dev/null
	fi

	/etc/init.d/centcore start &> /dev/null

	if [ ! -d /usr/local/centreon-broker ] ; then
	/etc/init.d/centstorage start &> /dev/null
	fi

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Core" \
	  --gauge "Installation Centreon Core" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-core' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-core' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Core" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_centreon
}

#############################################################################
# Fonction Installation Centreon Widgets
#############################################################################

installation_centreon_widgets()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Widgets" \
	  --gauge "Installation Centreon Widgets" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp

	version_installe_centreon=`expr $version_installe_centreon | sed 's/..$//'`


	if [ "$version_installe_centreon" = "2.3" ] ; then

	cat <<- EOF > /tmp/erreur
	Veuillez Installer Centreon Version 2.4.x
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon Widgets" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 46 

	rm -f /tmp/erreur
	menu_installation_suite_centreon
	fi

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-widgets' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Widgets" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 7 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon-widgets' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/liste-version.txt


	if grep -w "$choix_version" /tmp/liste-version.txt > /dev/null ; then

	rm -f /tmp/liste-version.txt
	rm -f $fichtemp

	else
	cat <<- EOF > /tmp/erreur
	Veuillez vous assurer que la version saisie
	               est correcte
	EOF

	erreur=`cat /tmp/erreur`

	$DIALOG --ok-label "Quitter" \
		 --colors \
		 --backtitle "Installation Centreon Widgets" \
		 --title "Erreur" \
		 --msgbox  "\Z1$erreur\Zn" 6 50 
	
	rm -f /tmp/liste-version.txt
	rm -f /tmp/erreur
	rm -f $fichtemp
	menu_installation_suite_centreon			
	fi
	;;

 1)	# Appuyé sur Touche CTRL C
	echo "Appuyé sur Touche CTRL C."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

 255)	# Appuyé sur Touche Echap
	echo "Appuyé sur Touche Echap."
	rm -f $fichtemp
	menu_installation_suite_centreon
	;;

esac

(
 echo "20" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Widgets" \
	  --gauge "Installation Centreon Widgets" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-widgets' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-widgets' and version='$choix_version' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Widgets" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier --output-document=$nom_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Widgets" \
	  --gauge "Installation Centreon Widgets" 10 60 0 \

	mv centreon-widgets-1.0.0.tar.gz /usr/local/centreon/www/widgets/

	cd /usr/local/centreon/www/widgets/
	tar xvzf $nom_fichier
	
	rm -f /usr/local/centreon/www/widgets/$nom_fichier

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Widgets" \
	  --gauge "Installation Centreon Widgets" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-widgets' and uname='`uname -n`' ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-widgets' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $VAR10 -P $VAR11 -u $VAR13 -p$VAR14 $VAR12 < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon Widgets" \
	  --gauge "Terminer" 10 60 0 \


menu_installation_suite_centreon
}

#############################################################################
# Demarrage du programme
#############################################################################


menu
