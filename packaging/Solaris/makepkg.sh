#!/bin/sh -e
#
# Copyright (C) Shirish A Kalele 2000
# Copyright (C) Gerald Carter    2004
#
# script for build solaris Samba package
#

INSTALL_BASE=/opt/samba

SBINPROGS="smbd nmbd winbindd"
BINPROGS="findsmb nmblookup eventlogadm pdbedit rpcclient smbclient smbcquotas smbspool smbtar tdbbackup testparm wbinfo net ntlm_auth profiles smbcacls smbcontrol smbpasswd smbstatus smbtree tdbdump"
MSGFILES="de.msg en.msg fi.msg fr.msg it.msg ja.msg nl.msg pl.msg tr.msg"
VFSLIBS="audit.so default_quota.so extd_audit.so full_audit.so readonly.so shadow_copy.so cap.so expand_msdfs.so fake_perms.so netatalk.so recycle.so"
CHARSETLIBS="CP437.so CP850.so"
AUTHLIBS="script.so"

add_dynamic_entries() 
{
	# Add the binaries and docs
	cd $TMPINSTALLDIR/$INSTALL_BASE

	echo "#\n# Server Binaries \n#"	
 	for file in $SBINPROGS; do
		echo f none sbin/$file 0755 root other
	done

	echo "#\n# User Binaries \n#"
 	for file in $BINPROGS; do
		echo f none bin/$file 0755 root other
	done
	
	echo "#\n# Libraries\n#"
 	for file in $MSGFILES; do
		echo f none lib/$file 0644 root other
	done
 	for file in $VFSLIBS; do
		echo f none lib/vfs/$file 0755 root other
	done
 	for file in $CHARSETLIBS; do
		echo f none lib/charset/$file 0755 root other
	done
 	for file in $AUTHLIBS; do
		echo f none lib/auth/$file 0755 root other
	done
	
	echo "#\n# libsmbclient\n#"
	echo f none lib/libsmbclient.so 0755 root other
	echo f none include/libsmbclient.h 0644 root other

	echo "#\n# libmsrpc\n#"

	if [ -f lib/smbwrapper.so -a -f bin/smbsh ]; then
		echo "#\n# smbwrapper\n#"
		echo f none lib/smbwrapper.so 0755 root other
		echo f none bin/smbsh 0755 root other
	fi

	echo "#\n# nss_winbind.so and nss_wins.so\n#"
	echo f none /lib/nss_winbind.so.1=lib/nss_winbind.so.1 0755 root other
	echo f none /lib/nss_wins.so.1=lib/nss_wins.so.1 0755 root other
	# echo s none /lib/nss_winbind.so.1=/usr/lib/nss_winbind.so.1 0755 root other
	# echo s none /lib/nss_wins.so.1=/usr/lib/nss_wins.so.1 0755 root other
	if [ -f lib/pam_winbind.so ]; then
		echo f none /usr/lib/security/pam_winbind.so=lib/pam_winbind.so 0755 root other
	fi

	echo "#\n# man pages \n#"

	# Create directories for man page sections if nonexistent
	cd share/man
	for i in 1 2 3 4 5 6 7 8 9; do
		set +e
		manpages=`ls man$i 2>/dev/null`
		set -e
		if [ $? -eq 0 ]; then
			echo d none share/man/man${i} ? ? ?
			for manpage in $manpages; do
				echo f none share/man/man${i}/${manpage} 0644 root other
			done
		fi
	done
}

#####################################################################
## BEGIN MAIN 
#####################################################################

# Try to guess the distribution base..
DISTR_BASE=`dirname \`pwd\` |sed -e 's@/packaging$@@'`
echo "Distribution base:  $DISTR_BASE"

TMPINSTALLDIR="/tmp/`basename $DISTR_BASE`-build"
echo "Temp install dir:   $TMPINSTALLDIR"
echo "Install directory:  $INSTALL_BASE"

##
## first build the source
##

cd $DISTR_BASE/source

if test "x$1" = "xbuild" -o ! -f bin/smbd ]; then
	./configure --prefix=$INSTALL_BASE \
		--localstatedir=/var/lib/samba \
		--with-piddir=/var/run \
		--with-logfilebase=/var/log/samba \
		--with-privatedir=/etc/samba/private \
		--with-configdir=/etc/samba \
		--with-lockdir=/var/lib/samba \
		--with-mandir=/usr/share/man \
		--with-pam --with-acl-support \
		--with-quotas --with-included-popt \
	&& make

	if [ $? -ne 0 ]; then
		echo "Build failed!  Exiting...."
		exit 1
	fi
fi
	
rm -rf $TMPINSTALLDIR
mkdir -p $TMPINSTALLDIR
make DESTDIR=$TMPINSTALLDIR install

## clear out *.old
find $TMPINSTALLDIR -name \*.old |while read x; do rm -rf "$x"; done
 
##
## Now get the install locations
##
LD_LIBRARY_PATH=$DISTR_BASE/source/bin
export LD_LIBRARY_PATH
SBINDIR=`bin/smbd -b | grep SBINDIR | awk '{print $2}'`
BINDIR=`bin/smbd -b | grep BINDIR | grep -v SBINDIR |  awk '{print $2}'`
CONFIGFILE=`bin/smbd -b | grep CONFIGFILE | awk '{print $2}'`
LOCKDIR=`bin/smbd -b | grep LOCKDIR | awk '{print $2}'`
CONFIGDIR=`dirname $CONFIGFILE`
LOGFILEBASE=`bin/smbd -b | grep LOGFILEBASE | awk '{print $2}'`
LIBDIR=`bin/smbd -b | grep LIBDIR | awk '{print $2}'`
PIDDIR=`bin/smbd -b | grep PIDDIR | awk '{print $2}'`
PRIVATE_DIR=`bin/smbd -b | grep PRIVATE_DIR | awk '{print $2}'`
DOCDIR=$INSTALL_BASE/docs

## 
## copy some misc files that are not done as part of 'make install'
##
cp -fp nsswitch/libnss_wins.so $TMPINSTALLDIR/$LIBDIR/nss_wins.so.1
cp -fp nsswitch/libnss_winbind.so $TMPINSTALLDIR/$LIBDIR/nss_winbind.so.1
if [ -f bin/pam_winbind.so ]; then
	cp -fp bin/pam_winbind.so $TMPINSTALLDIR/$LIBDIR/pam_winbind.so
fi
if [ -f bin/smbwrapper.so ]; then
	cp -fp bin/smbwrapper.so $TMPINSTALLDIR/$INSTALL_BASE/lib
fi
if [ -f bin/smbsh ]; then
	cp -fp bin/smbsh $TMPINSTALLDIR/$INSTALL_BASE/bin
fi

mkdir -p $TMPINSTALLDIR/$INSTALL_BASE/docs
cp -p ../docs/*pdf $TMPINSTALLDIR/$INSTALL_BASE/docs


cd $DISTR_BASE/packaging/Solaris

##
## Main driver 
##

# Setup version from smbd -V

VERSION=`$TMPINSTALLDIR/$SBINDIR/smbd -V | awk '{print $2}'`
sed -e "s|__VERSION__|$VERSION|" -e "s|__ARCH__|`uname -p`|" -e "s|__BASEDIR__|$INSTALL_BASE|g" pkginfo.master > pkginfo

sed -e "s|__BASEDIR__|$INSTALL_BASE|g" inetd.conf.master   > inetd.conf
sed -e "s|__BASEDIR__|$INSTALL_BASE|g" samba.init.master > samba.init

##
## copy over some scripts need for packagaing
##
mkdir -p $TMPINSTALLDIR/$INSTALL_BASE/scripts
for i in samba.init smb.conf.default; do
	cp -fp $i $TMPINSTALLDIR/$INSTALL_BASE/scripts
done

##
## Start building the prototype file
##
echo "CONFIGDIR=$CONFIGDIR" >> pkginfo
echo "LOGFILEBASE=$LOGFILEBASE" >> pkginfo
echo "LOCKDIR=$LOCKDIR" >> pkginfo
echo "PIDDIR=$PIDDIR" >> pkginfo
echo "PRIVATE_DIR=$PRIVATE_DIR" >> pkginfo

cp prototype.master prototype

# Add the dynamic part to the prototype file
(add_dynamic_entries >> prototype)

##
## copy packaging files 
##
for i in prototype pkginfo copyright preremove postinstall request; do
	cp $i $TMPINSTALLDIR/$INSTALL_BASE
done

# Create the package
pkgmk -o -d /tmp -b $TMPINSTALLDIR/$INSTALL_BASE -f prototype

if [ $? = 0 ]; then
	pkgtrans /tmp samba.pkg samba
fi

echo The samba package is in /tmp
