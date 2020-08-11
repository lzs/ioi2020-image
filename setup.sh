#!/bin/bash

error() {
	local lineno="$1"
	local message="$2"
	local code="${3:-1}"
	if [[ -n "$message" ]] ; then
		echo "Error at or near line ${lineno}: ${message}; exiting with status ${code}"
	else
		echo "Error at or near line ${lineno}; exiting with status ${code}"
	fi
	exit "${code}"
}
trap 'error ${LINENO}' ERR

VERSION="beta2"

# Fix up date/time

timedatectl set-timezone Asia/Singapore
vmware-toolbox-cmd timesync enable
hwclock -w

# Update packages

apt update
apt -y upgrade

# Convert server install into a minimuam desktop install

apt -y install tasksel
tasksel install ubuntu-desktop-minimal ubuntu-desktop-minimal-default-languages

# Install tools needed for management and monitoring

apt -y install net-tools openssh-server ansible xvfb tinc i3lock oathtool imagemagick

# Install packages needed by contestants

apt -y install openjdk-11-jdk-headless codeblocks emacs \
	geany gedit joe kate kdevelop nano vim vim-gtk3 \
	ddd valgrind visualvm ruby python3-pip konsole

# Install snap packages needed by contestants

snap install --classic atom
snap install --classic intellij-idea-community
snap install --classic code
snap install --classic sublime-text

# Fix Atom application menu bug
sudo sed -i 's/Exec=env BAMF_DESKTOP_FILE_HINT=\/var\/lib\/snapd\/desktop\/applications\/atom_atom.desktop \/snap\/bin\/atom ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT=false \/usr\/bin\/atom %F/Exec=env BAMF_DESKTOP_FILE_HINT=\/var\/lib\/snapd\/desktop\/applications\/atom_atom.desktop ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT=false \/snap\/bin\/atom %F/' /var/lib/snapd/desktop/applications/atom_atom.desktop

# Install Eclipse
wget -O /tmp/eclipse.tar.gz "http://mirrors.neusoft.edu.cn/eclipse/technology/epp/downloads/release/2020-06/R/eclipse-java-2020-06-R-linux-gtk-x86_64.tar.gz"
tar zxf /tmp/eclipse.tar.gz -C /opt
rm /tmp/eclipse.tar.gz
/opt/eclipse/eclipse -nosplash \
        -application org.eclipse.equinox.p2.director \
        -repository http://download.eclipse.org/releases/indigo/,http://download.eclipse.org/tools/cdt/releases/helios/ \
        -destination /opt/eclipse \
        -installIU org.eclipse.cdt.feature.group
wget -O /usr/share/pixmaps/eclipse.png "https://icon-icons.com/downloadimage.php?id=94656&root=1381/PNG/64/&file=eclipse_94656.png"
cat - <<EOM > /usr/share/applications/eclipse.desktop
[Desktop Entry]
Name=Eclipse
Exec=/opt/eclipse/eclipse
Type=Application
Icon=eclipse
EOM

# Install python3 libraries

pip3 install matplotlib

# Change default shell for useradd
sed -i '/^SHELL/ s/\/sh$/\/bash/' /etc/default/useradd

# Copy IOI stuffs into /opt

mkdir /opt/ioi
cp -a bin sbin misc /opt/ioi/
mkdir /opt/ioi/run
mkdir /opt/ioi/store
mkdir /opt/ioi/store/log
mkdir /opt/ioi/store/screenshots
mkdir /opt/ioi/store/submissions

wget -O /tmp/cpptools-linux.vsix "https://github.com/microsoft/vscode-cpptools/releases/download/0.29.0/cpptools-linux.vsix"
wget -O /tmp/vscode-java-pack.vsix.gz "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/vscjava/vsextensions/vscode-java-pack/0.9.1/vspackage"
#wget -O /tmp/ms-python.vsix.gz "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/python/2020.7.96456/vspackage"
gunzip /tmp/vscode-java-pack.vsix.gz
#gunzip /tmp/ms-python.vsix.gz
mkdir /tmp/vscode
code --install-extension /tmp/cpptools-linux.vsix --extensions-dir /opt/ioi/misc/vscode-extensions --user-data-dir /tmp/vscode
code --install-extension /tmp/vscode-java-pack.vsix --extensions-dir /opt/ioi/misc/vscode-extensions --user-data-dir /tmp/vscode
#code --install-extension /tmp/ms-python.vsix --extensions-dir /opt/ioi/misc/vscode-extensions --user-data-dir /tmp/vscode

# Create IOI account
/opt/ioi/sbin/mkioiuser.sh

# Set IOI user's initial password
echo "ioi:ioi" | chpasswd

# Fix permission and ownership
chown ioi.ioi /opt/ioi/store/submissions
chown ansible.syslog /opt/ioi/store/log
chmod 770 /opt/ioi/store/log

# Add our own syslog facility

echo "local0.* /opt/ioi/store/log/local.log" >> /etc/rsyslog.d/10-ioi.conf

# Add custom NTP to timesyncd config

cat - <<EOM > /etc/systemd/timesyncd.conf
[Time]
NTP=172.31.39.161 time.windows.com time.nist.gov
EOM

# Don't list ansible user at login screen

cat - <<EOM > /var/lib/AccountsService/users/ansible
[User]
Language=
XSession=gnome
SystemAccount=true
EOM

chmod 644 /var/lib/AccountsService/users/ansible

# ADD QUIET SPLASH

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/ s/"$/ quiet splash"/' /etc/default/grub
update-grub2

# Setup SSH authorized keys and passwordless sudo for ansible

mkdir ~ansible/.ssh
cp misc/id_ansible.pub ~ansible/.ssh/authorized_keys
chown -R ansible.ansible ~ansible/.ssh

sed -i '/%sudo/ s/ALL$/NOPASSWD:ALL/' /etc/sudoers
echo "ioi ALL=NOPASSWD: /opt/ioi/bin/ioiconf.sh, /opt/ioi/bin/ioiexec.sh, /opt/ioi/bin/lockscreen.sh" >> /etc/sudoers.d/01-ioi
chmod 440 /etc/sudoers.d/01-ioi

# Documentation

apt -y install stl-manual openjdk-11-doc python3-doc

# CPP Reference

wget -O /tmp/html_book_20190607.zip http://upload.cppreference.com/mwiki/images/b/b2/html_book_20190607.zip
mkdir /opt/cppref
unzip /tmp/html_book_20190607.zip -d /opt/cppref
rm -f /tmp/html_book_20190607.zip

# Mark some packages as needed so they wont' get auto-removed

apt -y install `dpkg-query -Wf '${Package}\n' | grep linux-image-`
apt -y install `dpkg-query -Wf '${Package}\n' | grep linux-modules-`

# Remove unneeded packages

apt -y remove gnome-power-manager
apt -y remove linux-firmware
apt -y remove memtest86+
apt -y remove network-manager-openvpn network-manager-openvpn-gnome openvpn
apt -y remove gnome-getting-started-docs-it gnome-getting-started-docs-ru \
	gnome-getting-started-docs-es gnome-getting-started-docs-fr gnome-getting-started-docs-de
apt -y remove manpages-dev
apt -y remove `dpkg-query -Wf '${Package}\n' | grep linux-header`
apt -y autoremove

apt clean

# Create local HTML

cp -a html /opt/ioi/html
mkdir -p /opt/ioi/html/fonts
wget -O /tmp/fira-sans.zip "https://google-webfonts-helper.herokuapp.com/api/fonts/fira-sans?download=zip&subsets=latin&variants=regular"
wget -O /tmp/share.zip "https://google-webfonts-helper.herokuapp.com/api/fonts/share?download=zip&subsets=latin&variants=regular"
unzip -o /tmp/fira-sans.zip -d /opt/ioi/html/fonts
unzip -o /tmp/share.zip -d /opt/ioi/html/fonts
rm /tmp/fira-sans.zip
rm /tmp/share.zip

# Tinc Setup and Configuration

# Setup tinc skeleton config

mkdir /etc/tinc/vpn
mkdir /etc/tinc/vpn/hosts
cat - <<'EOM' > /etc/tinc/vpn/tinc-up
#!/bin/sh

ifconfig $INTERFACE "$(cat /etc/tinc/vpn/ip.conf)" netmask "$(cat /etc/tinc/vpn/mask.conf)"
route add -net 172.31.0.0/16 gw "$(cat /etc/tinc/vpn/ip.conf)"
EOM
chmod 755 /etc/tinc/vpn/tinc-up

cat - <<'EOM' > /etc/tinc/vpn/host-up
#!/bin/sh

# Force time resync as soon as VPN starts
systemctl restart systemd-timesyncd

# Fix up DNS resolution
resolvectl dns vpn 172.31.0.2
resolvectl domain vpn ioi2020.sg
systemd-resolve --flush-cache
EOM
chmod 755 /etc/tinc/vpn/host-up

# Configure systemd for tinc
systemctl enable tinc@vpn

systemctl disable multipathd

# Configure systemd for i3lock
cat - <<EOM > /etc/systemd/system/i3lock.service
[Unit]
Description=Lock screen

[Service]
User=ansible
Type=simple
Restart=always
RestartSec60
Environment=DISPLAY=':0.0'
ExecStart=/opt/ioi/sbin/i3lock.sh
EOM

# Create rc.local file
cp misc/rc.local /etc/rc.local
chmod 755 /etc/rc.local

# Modify hosts file
echo "172.31.4.51 test.ioi2020.sg" >> /etc/hosts

# Add contest schedule
/opt/ioi/sbin/contest.sh schedule

# Add default timezone
echo "Asia/Singapore" > /opt/ioi/store/timezone

# Embed version number
if [ -n "$VERSION" ] ; then
	echo "$VERSION" > /opt/ioi/misc/VERSION
fi

# vim: ts=4
