#!/bin/bash
#
# Copyright 2013 
# Développé par : Stéphane HACQUARD
# Date : 29-08-2013
# Version 1.0
# Pour plus de renseignements : stephane.hacquard@sargasses.fr



#############################################################################
# Variables d'environnement
#############################################################################


DIALOG=${DIALOG=dialog}

serveur_installation=192.168.4.10
utilisateur_installation=installation
password_installation=installation
base_installation=installation


NagiosLockFile=/usr/local/nagios/var/nagios.lock
Ndo2dbPidFile=/var/run/ndo2db/ndo2db.pid
NrpePidFile=/var/run/nrpe/nrpe.pid
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
# Fonction Nettoyage De La Base De Données (table inventaire)
#############################################################################

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


if [ ! -f /usr/bin/smistrip ] ||
   [ ! -f /usr/bin/download-mibs ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='snmp-mibs-downloader' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/bin/nagios ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nagios' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/libexec/check_ping ] ||
   [ ! -f /usr/local/nagios/libexec/check_fping ] ||
   [ ! -f /usr/local/nagios/libexec/check_ssh ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/bin/ndomod.o ] ||
   [ ! -f /usr/local/nagios/bin/ndo2db ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='ndoutils' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /usr/local/nagios/libexec/check_nrpe ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -d /usr/local/centreon/test ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp
	
	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -d /usr/local/centreon/test ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi

if [ ! -f /etc/centreon/instCentCore.conf ] ||
   [ ! -f /etc/centreon/instCentPlugins.conf ] ||
   [ ! -f /etc/centreon/instCentStorage.conf ] ||
   [ ! -f /etc/centreon/instCentWeb.conf ] ; then

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	optimize table inventaire ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp > /dev/null

	rm -f $fichtemp
fi


#############################################################################
# Fonction Inventaire Nouvelle Version D'installation
#############################################################################

inventaire_nouvelle_version_installation()
{


fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


if [ -f /usr/bin/smistrip ] ||
   [ -f /usr/bin/download-mibs ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='snmp-mibs-downloader' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_snmp_mibs_downloader=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='snmp-mibs-downloader' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_snmp_mibs_downloader=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -f /usr/local/nagios/bin/nagios ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nagios' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_nagios=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='nagios' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_nagios=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -f /usr/local/nagios/libexec/check_ping ] ||
   [ -f /usr/local/nagios/libexec/check_fping ] ||
   [ -f /usr/local/nagios/libexec/check_ssh ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nagios-plugins' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_nagios_plugins=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='nagios-plugins' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_nagios_plugins=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -f /usr/local/nagios/bin/ndomod.o ] ||
   [ -f /usr/local/nagios/bin/ndo2db ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='ndoutils' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_ndoutils=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='ndoutils' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_ndoutils=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -f /usr/local/nagios/libexec/check_nrpe ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nrpe' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_nrpe=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='nrpe' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_nrpe=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -d /usr/local/centreon/test ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-engine' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_engine=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-engine' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_engine=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -d /usr/local/centreon/test ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-broker' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_broker=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-broker' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_broker=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -f /etc/centreon/instCentCore.conf ] ||
   [ -f /etc/centreon/instCentPlugins.conf ] ||
   [ -f /etc/centreon/instCentStorage.conf ] ||
   [ -f /etc/centreon/instCentWeb.conf ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

if [ -d /usr/local/centreon/www/widgets/graph-monitoring ] ||
   [ -d /usr/local/centreon/www/widgets/hostgroup-monitoring ] ||
   [ -d /usr/local/centreon/www/widgets/host-monitoring ] ||
   [ -d /usr/local/centreon/www/widgets/servicegroup-monitoring ] ||
   [ -d /usr/local/centreon/www/widgets/service-monitoring ] ; then

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon-widgets' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference_centreon_widgets=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp


	cat <<- EOF > $fichtemp
	select version
	from inventaire
	where logiciel='centreon-widgets' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

	version_installe_centreon_widgets=$(sed '$!d' /tmp/version-installe.txt)
	rm -f /tmp/version-installe.txt
	rm -f $fichtemp
fi

}

#############################################################################
# Fonction Verification Couleur
#############################################################################

verification_installation()
{

inventaire_nouvelle_version_installation

# 0=noir, 1=rouge, 2=vert, 3=jaune, 4=bleu, 5=magenta, 6=cyan 7=blanc


if [ ! -f /usr/bin/smistrip ] ||
   [ ! -f /usr/bin/download-mibs ] ; then
	choix1="\Z1Installation MIB SNMP Complementaire\Zn" 

elif [ "$version_reference_snmp_mibs_downloader" != "$version_installe_snmp_mibs_downloader" ] ; then
	choix1="\Zb\Z3Installation MIB SNMP Complementaire\Zn" 

else
	choix1="\Z2Installation MIB SNMP Complementaire\Zn" 
fi

if [ ! -f /usr/bin/fping ] ||
   [ ! -f /usr/bin/mkpasswd ] ||
   [ ! -f /usr/include/libpng12/png.h ] ; then
	choix2="\Z1Installation Composant Nagios\Zn" 
else
	choix2="\Z2Installation Composant Nagios\Zn" 
fi

if [ ! -f /usr/include/gnutls/gnutls.h ] ||
   [ ! -f /usr/include/krb5.h ] ||
   [ ! -f /usr/lib/libmcrypt.so ] ; then
	choix3="\Z1Installation Composant Nagios Plugins\Zn" 
else
	choix3="\Z2Installation Composant Nagios Plugins\Zn" 
fi

if [ ! -f /usr/share/build-essential/list ] ||
   [ ! -f /usr/include/curl/curl.h ] ||
   [ ! -f /usr/include/openssl/ssl.h ] ; then
	choix4="\Z1Installation Composant NRPE\Zn" 
else
	choix4="\Z2Installation Composant NRPE\Zn" 
fi

if [ ! -f /usr/bin/cmake ] ||
   [ ! -d /usr/include/qt4 ] ||
   [ ! -f /usr/bin/soapcpp2 ] ||
   [ ! -f /usr/include/zlib.h ] ||
   [ ! -f /usr/include/openssl/aes.h ] ; then
	choix5="\Z1Installation Composant Centreon Engine\Zn" 
else
	choix5="\Z2Installation Composant Centreon Engine\Zn" 
fi

if [ ! -f /usr/bin/cmake ] ||
   [ ! -d /usr/include/qt4 ] ||
   [ ! -d /usr/share/doc/libqt4-sql-mysql ] ||
   [ ! -f /usr/lib/librrd.so ] ; then
	choix6="\Z1Installation Composant Centreon Broker\Zn" 
else
	choix6="\Z2Installation Composant Centreon Broker\Zn" 
fi

if [ ! -f /usr/lib/perl5/auto/RRDs/RRDs.so ] ||
   [ ! -f /usr/lib/perl5/auto/GD/GD.so ] ||
   [ ! -f /usr/lib/perl5/auto/SNMP/SNMP.so ] ||
   [ ! -f /usr/lib/perl5/XML/Parser.pm ] ; then
	choix7="\Z1Installation Composant Centreon\Zn" 
else
	choix7="\Z2Installation Composant Centreon\Zn" 
fi

if [ ! -f /usr/local/nagios/bin/nagios ] ; then
	choix8="\Z1Installation Nagios\Zn" 

elif [ "$version_reference_nagios" != "$version_installe_nagios" ] ; then
	choix8="\Zb\Z3Installation Nagios\Zn" 

else
	choix8="\Z2Installation Nagios\Zn" 
fi

if [ ! -f /usr/local/nagios/libexec/check_ping ] ||
   [ ! -f /usr/local/nagios/libexec/check_fping ] ||
   [ ! -f /usr/local/nagios/libexec/check_ssh ] ; then
	choix9="\Z1Installation Nagios Plugins\Zn" 

elif [ "$version_reference_nagios_plugins" != "$version_installe_nagios_plugins" ] ; then
	choix9="\Zb\Z3Installation Nagios Plugins\Zn" 

else
	choix9="\Z2Installation Nagios Plugins\Zn" 
fi

if [ ! -f /usr/local/nagios/bin/ndomod.o ] ||
   [ ! -f /usr/local/nagios/bin/ndo2db ] ; then
	choix10="\Z1Installation NDOutils\Zn" 

elif [ "$version_reference_ndoutils" != "$version_installe_ndoutils" ] ; then
	choix10="\Zb\Z3Installation NDOutils\Zn" 

else
	choix10="\Z2Installation NDOutils\Zn" 
fi

if [ ! -f /usr/local/nagios/libexec/check_nrpe ] ; then
	choix11="\Z1Installation NRPE\Zn" 

elif [ "$version_reference_nrpe" != "$version_installe_nrpe" ] ; then
	choix11="\Zb\Z3Installation NRPE\Zn" 

else
	choix11="\Z2Installation NRPE\Zn" 
fi

if [ ! -d /usr/local/centreon/test ] ; then
	choix12="\Z1Installation Centreon Engine\Zn" 

elif [ "$version_reference_centreon_engine" != "$version_installe_centreon_engine" ] ; then
	choix12="\Zb\Z3Installation Centreon Engine\Zn" 

else
	choix12="\Z2Installation Centreon Engine\Zn" 
fi

if [ ! -d /usr/local/centreon/test ] ; then
	choix13="\Z1Installation Centreon Broker\Zn" 

elif [ "$version_reference_centreon_broker" != "$version_installe_centreon_broker" ] ; then
	choix13="\Zb\Z3Installation Centreon Broker\Zn"

else
	choix13="\Z2Installation Centreon Broker\Zn" 
fi

if [ ! -f /etc/centreon/instCentCore.conf ] ||
   [ ! -f /etc/centreon/instCentPlugins.conf ] ||
   [ ! -f /etc/centreon/instCentStorage.conf ] ||
   [ ! -f /etc/centreon/instCentWeb.conf ] ; then
	choix14="\Z1Installation Centreon\Zn"
 
elif [ "$version_reference_centreon" != "$version_installe_centreon" ] ; then
	choix14="\Zb\Z3Installation Centreon\Zn" 

else
	choix14="\Z2Installation Centreon\Zn" 
fi

if [ ! -d /usr/local/centreon/www/widgets/graph-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/hostgroup-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/host-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/servicegroup-monitoring ] ||
   [ ! -d /usr/local/centreon/www/widgets/service-monitoring ] ; then
	choix15="\Z1Installation Centreon Widgets\Zn" 

elif [ "$version_reference_centreon_widgets" != "$version_installe_centreon_widgets" ] ; then
	choix15="\Zb\Z3Installation Centreon Widgets\Zn" 

else
	choix15="\Z2Installation Centreon Widgets\Zn" 
fi

}

#############################################################################
# Fonction Menu 
#############################################################################

menu()
{


fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Serveur de Supervision" \
	  --clear \
	  --colors \
	  --default-item "2" \
	  --menu "Quel est votre choix" 11 54 5 \
	  "1" "Installation Serveur de Supervision" \
	  "2" "Quitter" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Serveur de Supervision
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
              menu_installation_serveur_supervision
	fi

	# Quitter
	if [ "$choix" = "2" ]
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
# Fonction Menu Installation Serveur de Supervision
#############################################################################

menu_installation_serveur_supervision()
{

verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Serveur de Supervision" \
	  --clear \
	  --colors \
	  --default-item "5" \
	  --menu "Quel est votre choix" 12 62 5 \
	  "1" "Installation Composant Complementaire" \
	  "2" "$choix1" \
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

verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Complementaire" \
	  --clear \
	  --colors \
	  --default-item "7" \
	  --menu "Quel est votre choix" 14 64 7 \
	  "1" "$choix2" \
	  "2" "$choix3" \
	  "3" "$choix4" \
	  "4" "$choix5" \
	  "5" "$choix6" \
	  "6" "$choix7" \
	  "7" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Composant Nagios
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		installation_composant_nagios
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

	# Installation Composant Centreon
	if [ "$choix" = "6" ]
	then
		rm -f $fichtemp
		installation_composant_centreon
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

menu_installation_serveur_supervision
}

#############################################################################
# Fonction Menu Installation Suite Nagios
#############################################################################

menu_installation_suite_nagios()
{

verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Suite Nagios" \
	  --clear \
	  --colors \
	  --default-item "5" \
	  --menu "Quel est votre choix" 12 52 5 \
	  "1" "$choix8" \
	  "2" "$choix9" \
	  "3" "$choix10" \
	  "4" "$choix11" \
	  "5" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Nagios
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		installation_nagios
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

verification_installation

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$


$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Suite Centreon" \
	  --clear \
	  --colors \
	  --default-item "5" \
	  --menu "Quel est votre choix" 12 54 5 \
	  "1" "$choix12" \
	  "2" "$choix13" \
	  "3" "$choix14" \
	  "4" "$choix15" \
	  "5" "\Z4Retour\Zn" 2> $fichtemp


valret=$?
choix=`cat $fichtemp`
case $valret in

 0)	# Installation Centreon Engine
	if [ "$choix" = "1" ]
	then
		rm -f $fichtemp
		installation_centreon_engine
	fi

	# Installation Centreon Broker
	if [ "$choix" = "2" ]
	then
		rm -f $fichtemp
		installation_centreon_broker
	fi

	# Installation Centreon
	if [ "$choix" = "3" ]
	then
		rm -f $fichtemp
		installation_centreon
	fi

	# Installation Centreon Widgets
	if [ "$choix" = "4" ]
	then
		rm -f $fichtemp
		installation_centreon_widgets
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
# Fonction Installation Composant Nagios
#############################################################################

installation_composant_nagios()
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

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Nagios" \
	  --gauge "Installation Composant Nagios" 10 62 0 \


menu_installation_composant_complementaire
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

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libmcrypt-dev"; echo "XXX"
	apt-get -y install libmcrypt-dev &> /dev/null

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Nagios Plugins" \
	  --gauge "Installation Composant Nagios Plugins" 10 62 0 \


menu_installation_composant_complementaire
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

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant NRPE" \
	  --gauge "Installation Composant NRPE" 10 62 0 \


menu_installation_composant_complementaire
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

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon Engine" \
	  --gauge "Installation Composant Centreon Engine" 10 62 0 \

menu_installation_composant_complementaire
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

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon Broker" \
	  --gauge "Installation Composant Centreon Broker" 10 62 0 \

menu_installation_composant_complementaire
}

#############################################################################
# Fonction Installation Composant Centreon
#############################################################################

installation_composant_centreon()
{

(

 echo "10" ; sleep 1
 echo "XXX" ; echo "apt-get -y install rrdtool librrds-perl"; echo "XXX"
	apt-get -y install rrdtool librrds-perl &> /dev/null

 echo "20" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libconfig-inifiles-perl"; echo "XXX"
	apt-get -y install libconfig-inifiles-perl &> /dev/null

 echo "30" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libcrypt-des-perl"; echo "XXX"
	apt-get -y install libcrypt-des-perl &> /dev/null

 echo "40" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libdigest-hmac-perl libdigest-sha1-perl"; echo "XXX"
	apt-get -y install libdigest-hmac-perl libdigest-sha1-perl &> /dev/null

 echo "50" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libgd-gd2-perl"; echo "XXX"
	apt-get -y install libgd-gd2-perl &> /dev/null
	
 echo "60" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libnet-snmp-perl libsnmp-perl"; echo "XXX"
	apt-get -y install libnet-snmp-perl libsnmp-perl &> /dev/null

 echo "80" ; sleep 1
 echo "XXX" ; echo "apt-get -y install gettext"; echo "XXX"
	apt-get -y install gettext &> /dev/null

 echo "90" ; sleep 1
 echo "XXX" ; echo "apt-get -y install libxml-parser-perl"; echo "XXX"
	apt-get -y install libxml-parser-perl &> /dev/null

 echo "100" ; sleep 1
 echo "XXX" ; echo "Terminer"; echo "XXX"
 sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Composant Centreon" \
	  --gauge "Installation Composant Centreon" 10 62 0 \

menu_installation_composant_complementaire
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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='snmp-mibs-downloader' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'snmp-mibs-downloader' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

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
# Fonction Installation Nagios
#############################################################################

installation_nagios()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios" \
	  --gauge "Installation Nagios" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='nagios' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios" \
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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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
		 --backtitle "Installation Nagios" \
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
	  --title "Installation Nagios" \
	  --gauge "Installation Nagios" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='nagios' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='nagios' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='nagios' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios" \
	  --gauge "Installation Nagios" 10 60 0 \

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
	  --title "Installation Nagios" \
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
	  --title "Installation Nagios" \
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
	  --title "Installation Nagios" \
	  --gauge "Installation Nagios" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='nagios' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'nagios' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios" \
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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='nagios-plugins' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='nagios-plugins' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-repertoire.txt

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
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Nagios Plugins" \
	  --gauge "Installation Nagios Plugins" 10 60 0 \

	if [ -f $NagiosLockFile ] ; then
	/etc/init.d/nagios stop &> /dev/null
	fi

	tar xvzf $nom_fichier
	cd $nom_repertoire
	
	./configure
	make all
	make install

	cd ..

	rm -rf /root/$nom_repertoire/
	rm -f /root/$nom_fichier

	/etc/init.d/nagios start &> /dev/null

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'nagios-plugins' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='ndoutils' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='ndoutils' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-repertoire.txt

	nom_repertoire=$(sed '$!d' /tmp/nom-repertoire.txt)
	rm -f /tmp/nom-repertoire.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='ndoutils-light' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier_patch=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='ndoutils-light' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'ndoutils' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation NRPE" \
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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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
	echo "Appuyé sur Touche Echap."
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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='nrpe' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='nrpe' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-repertoire.txt

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
	
	./configure --enable-command-args --enable-ssl 
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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'nrpe' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-engine' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-engine' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-repertoire.txt

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


	#if [ -f $NrpePidFile ] ; then
	#/etc/init.d/nrpe stop &> /dev/null
	#fi

	#groupadd centreon-broker
	#useradd -g centreon-broker -m -r -d /var/lib/centreon-broker centreon-broker

	tar xvzf $nom_fichier
	cd $nom_repertoire
	
	#cmake \ 
	#make
	#make install

	cd ..

	#rm -rf /root/$nom_repertoire/
	#rm -f /root/$nom_fichier

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-engine' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-broker' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon-broker' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-repertoire.txt

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


	#if [ -f $NrpePidFile ] ; then
	#/etc/init.d/nrpe stop &> /dev/null
	#fi

	#groupadd centreon-broker
	#useradd -g centreon-broker -m -r -d /var/lib/centreon-broker centreon-broker

	tar xvzf $nom_fichier
	cd $nom_repertoire
	
	#cmake \ 
	#make
	#make install

	cd ..

	#rm -rf /root/$nom_repertoire/
	#rm -f /root/$nom_fichier

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-broker' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

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
# Fonction Installation Centreon
#############################################################################

installation_centreon()
{

fichtemp=`tempfile 2>/dev/null` || fichtemp=/tmp/test$$

(
 echo "10" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon" \
	  --gauge "Installation Centreon" 10 60 0 \

	cat <<- EOF > $fichtemp
	select version
	from version
	where logiciel='centreon' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

	version_reference=$(sed '$!d' /tmp/version-reference.txt)
	rm -f /tmp/version-reference.txt
	rm -f $fichtemp
	

$DIALOG  --ok-label "Validation" \
	  --nocancel \
	  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon" \
	  --form "Quel est votre choix" 10 50 1 \
	  "Version:"  1 1  "$version_reference"   1 10 10 0  2> $fichtemp

valret=$?
choix_version=`cat $fichtemp`
case $valret in

 0)    # Choix Version

	cat <<- EOF > $fichtemp
	select version
	from application
	where logiciel='centreon' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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
		 --backtitle "Installation Centreon" \
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
	  --title "Installation Centreon" \
	  --gauge "Installation Centreon" 10 60 0 \

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select repertoire
	from application
	where logiciel='centreon' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-repertoire.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier_messages=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-translations-messages' and version='$version_translations.x' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier_messages=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select url
	from application
	where logiciel='centreon-translations-help' and version='$version_translations.x' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier_help=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-translations-help' and version='$version_translations.x' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

	nom_fichier_help=$(sed '$!d' /tmp/nom-fichier.txt)
	rm -f /tmp/nom-fichier.txt
	rm -f $fichtemp

(
 echo "40" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon" \
	  --gauge "Telechargement en cours" 10 60 0 \

	wget --no-check-certificate -P /root/ $url_fichier &> /dev/null
	wget --no-check-certificate -P /root/ $url_fichier_messages &> /dev/null
	wget --no-check-certificate -P /root/ $url_fichier_help &> /dev/null

(
 echo "60" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon" \
	  --gauge "Installation Centreon" 10 60 0 \

	if [ -f $Ndo2dbPidFile ] ; then
	/etc/init.d/ndo2db stop &> /dev/null
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
		sed -i "$ligne"i'\# Required-Start: sshd' /root/$nom_repertoire/tmpl/install/centcore.init.d
	fi

	if grep "# Default-Start:" /root/$nom_repertoire/tmpl/install/centcore.init.d > /dev/null ; then
		ligne=$(sed -n '/# Default-Start:/=' /root/$nom_repertoire/tmpl/install/centcore.init.d)
		sed -i ""$ligne"d" /root/$nom_repertoire/tmpl/install/centcore.init.d
		sed -i "$ligne"i'\# Default-Start:  2 3 4 5' /root/$nom_repertoire/tmpl/install/centcore.init.d
	fi

	if grep "# Required-Start:" /root/$nom_repertoire/tmpl/install/centstorage.init.d > /dev/null ; then
		ligne=$(sed -n '/# Required-Start:/=' /root/$nom_repertoire/tmpl/install/centstorage.init.d)
		sed -i ""$ligne"d" /root/$nom_repertoire/tmpl/install/centstorage.init.d
		sed -i "$ligne"i'\# Required-Start: sshd' /root/$nom_repertoire/tmpl/install/centstorage.init.d
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

	if grep "NDOMOD_BINARY" /root/$nom_repertoire/www/install/var/brokers/ndoutils > /dev/null ; then
		sed -i "s/usr\/lib64\/nagios\/ndomod.o/usr\/local\/nagios\/bin\/ndomod.o/g" /root/$nom_repertoire/www/install/var/brokers/ndoutils
	fi

	fi



	if [ "$version_choix" = "2.3" ] ; then
	if [ ! -f /etc/centreon/instCentCore.conf ] ||
	   [ ! -f /etc/centreon/instCentPlugins.conf ] ||
	   [ ! -f /etc/centreon/instCentStorage.conf ] ||
	   [ ! -f /etc/centreon/instCentWeb.conf ] ; then

	./install.sh -i
	
	else

	./install.sh -u /etc/centreon/

	fi
	fi

	if [ "$version_choix" = "2.4" ] ; then
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

	if [ -f /etc/centreon/conf.pm ] ; then

	/etc/init.d/ndo2db start &> /dev/null
	/etc/init.d/centcore start &> /dev/null
	/etc/init.d/centstorage start &> /dev/null

	fi

(
 echo "90" ; sleep 1
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon" \
	  --gauge "Installation Centreon" 10 60 0 \

	cat <<- EOF > $fichtemp
	delete from inventaire
	where logiciel='centreon' and uname='`uname -n`' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

(
 echo "100" ; sleep 2
) |
$DIALOG  --backtitle "Installation Serveur de Supervision" \
	  --title "Installation Centreon" \
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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-installe.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/version-reference.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/liste-version.txt


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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/url-fichier.txt

	url_fichier=$(sed '$!d' /tmp/url-fichier.txt)
	rm -f /tmp/url-fichier.txt
	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	select fichier
	from application
	where logiciel='centreon-widgets' and version='$choix_version' ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp >/tmp/nom-fichier.txt

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

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	insert into inventaire ( logiciel, version, uname, date, heure )
	values ( 'centreon-widgets' , '$choix_version' , '`uname -n`' , '`date +%d.%m.%Y`' , '`date +%Hh%M`' ) ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

	rm -f $fichtemp

	cat <<- EOF > $fichtemp
	alter table inventaire order by logiciel ;
	alter table inventaire order by uname ;
	EOF

	mysql -h $serveur_installation -u $utilisateur_installation -p$password_installation $base_installation < $fichtemp

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
