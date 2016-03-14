# fuel-6.1-multipath

This repo contains materials for feature __Support multipath devices in Fuel__.

The current implementation supports the Fibre Channel Multipathing.
Both target OS are supported for node deployment: CentOS and Ubuntu.

Follow and update submodules for actual code:
http://stackoverflow.com/questions/1777854/git-submodules-specify-a-branch-tag/18799234#18799234


## Notes

Upstream https://github.com/openstack/fuel-web after 6.1 release separates agents code:
  - https://github.com/openstack/fuel-agent
  - https://github.com/openstack/fuel-nailgun-agent

When porting this feature pay attention on multipath names and separator especially in different distro:
http://initrd.org/wiki/Device_Mapper_Multipath#Multipath_Names

This feature is planned for the upstream Fuel-9.0:
https://review.openstack.org/#/c/276745/


## Known issues

Finally it works on Ubuntu. At least with multipath-tools since 0.4.9-3ubuntu7.9.
In case of trouble, check the https://bugs.launchpad.net/ubuntu/+source/multipath-tools


## Custom Fuel iso

* Create the build env https://docs.fuel-infra.org/fuel-dev/buildsystem.html
* Checkout the __multipath__ branch of https://github.com/ymkins/fuel-main
* Run simple http server for extra RPM-repo
* Run __make iso__ with options NAILGUN_REPO, NAILGUN_COMMIT, EXTRA_RPM_REPOS

```
cd ./fuel-multipath/fuel-main.git
mkdir -p ../extra_rpm/centos/6/os/x86_64/Packages
cd ../extra_rpm/centos/6/os/x86_64/Packages/
wget http://mirror.centos.org/centos/6/os/x86_64/Packages/device-mapper-multipath-0.4.9-87.el6.x86_64.rpm
wget http://mirror.centos.org/centos/6/os/x86_64/Packages/device-mapper-multipath-libs-0.4.9-87.el6.x86_64.rpm
wget http://mirror.centos.org/centos/6/os/x86_64/Packages/kpartx-0.4.9-87.el6.x86_64.rpm
cd ../../../../../
createrepo -p --no-database --simple-md-filenames ./centos/6/os/x86_64/
```

```
cd ./fuel-multipath/extra_rpm/
python ../fuel-main.git/utils/simple_http_daemon.py
cd ./fuel-multipath/fuel-main.git
make iso ISO_NAME='fuel-6.1-multipath' NAILGUN_REPO='https://github.com/ymkins/fuel-web.git' NAILGUN_COMMIT='multipath' EXTRA_RPM_REPOS='m,http://127.0.0.1:9001/centos/6/os/x86_64/' 2>&1 | tee ../make_iso.log
kill `cat /var/run/simplehttpd.pid`
```

_Note: There are build issue on Ubuntu-12.04._

The __xorriso__ supports -isohybrid-gpt-basdat option since xorriso-1.2.4, but Ubuntu-12.04 has xorriso-1.1.8.

```
xorriso -as mkisofs \
		-V "OpenStack_Fuel" -p "Fuel team" \
		-J -R \
		-graft-points \
		-b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
		-isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin \
		-eltorito-alt-boot -e images/efiboot.img -no-emul-boot \
		-isohybrid-gpt-basdat \
		-o /root/rocket-multipath/fuel-main.git/build/artifacts/fuel-6.1-multipath.iso /root/rocket-multipath/fuel-main.git/build/iso/isoroot-mkisofs
xorriso 1.1.8 : RockRidge filesystem manipulator, libburnia project.

Drive current: -outdev 'stdio:/root/rocket-multipath/fuel-main.git/build/artifacts/fuel-6.1-multipath.iso'
Media current: stdio file, overwriteable
Media status : is blank
Media summary: 0 sessions, 0 data blocks, 0 data, 41.8g free
xorriso : WARNING : -volid text does not comply to ISO 9660 / ECMA 119 rules
xorriso : FAILURE : Cannot determine attributes of source file '/root/rocket-multipath/fuel-main.git/-isohybrid-gpt-basdat' : No such file or directory
xorriso : aborting : -abort_on 'FAILURE' encountered 'FAILURE'
make: *** [/root/rocket-multipath/fuel-main.git/build/artifacts/fuel-6.1-multipath.iso] Error 5
```

So, after xorriso fails, re-run it without -isohybrid-gpt-basdat option:

```
xorriso -as mkisofs \
		-V "OpenStack_Fuel" -p "Fuel team" \
		-J -R \
		-graft-points \
		-b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
		-isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin \
		-eltorito-alt-boot -e images/efiboot.img -no-emul-boot \
		-o /root/rocket-multipath/fuel-main.git/build/artifacts/fuel-6.1-multipath.iso /root/rocket-multipath/fuel-main.git/build/iso/isoroot-mkisofs \
		2>&1 | tee ../make_iso.log2
```


## Work-flow with the KVM-based environment

#### RTFM

* https://github.com/openstack/fuel-devops
* https://docs.fuel-infra.org/fuel-dev/devops.html

There is the special edition with multipath emulation support:
https://review.openstack.org/#/c/286804/

#### Setup the __fuel-devops__ virtualenv

```
$ sudo apt-get install python-pip virtualenvwrapper
$ mkvirtualenv fuel-devops
```

#### Install requerements
https://github.com/openstack/fuel-devops#installation

*Note: You can use __sqlite__ instead of __postgres__. Just edit the __virtualenv postactivate__ script:*

```
#!/bin/bash
# This hook is run after every virtualenv is activated.

export DEVOPS_DB_ENGINE="django.db.backends.sqlite3"
export DEVOPS_DB_NAME="${HOME}/.devops/fuel_devops.sqlite"
```

#### Install the fuel-devops
Try the regular version.
```
$ pip install git+https://github.com/openstack/fuel-devops.git@2.9.15 --upgrade
```

#### Create env __m61__ with nodes:
  - admin - Fuel master node
  - slave-01 - controller node
  - slave-02 - compute node
  - slave-03 - multipathed node

```
$ dos.py create -C 3 --admin-ram 2048 --second-disk-size 0 --third-disk-size 0 --iso-path ./fuel-6.1-multipath.iso m61
$ dos.py slave-change -N slave-01 --ram 2048 m61
$ dos.py admin-setup m61
$ dos.py destroy m61;  dos.py snapshot m61 master
```

##### Optional, create the repo mirror on master node
* https://docs.mirantis.com/openstack/fuel/fuel-6.1/operations.html#accessing-the-shell-on-the-nodes
* https://docs.mirantis.com/openstack/fuel/fuel-6.1/operations.html#troubleshooting-partial-mirror
* https://bugs.launchpad.net/fuel/+bug/1528498/comments/8

```
[root@nailgun ~]# echo 'multipath-tools-boot' >> /etc/fuel-createmirror/requirements-deb.txt
[root@nailgun ~]# fuel-createmirror
```
then take a snapshot
```
$ dos.py destroy m61;  dos.py snapshot m61 mirror
```


#### Deploy CentOS-based cloud
Deploy __c1__ cloud on slave-01 and slave-02 from Fuel UI http://10.21.0.2:8000/ . Use networking settings:
```
$ dos.py net-list m61
```

#### Take the snapshot
```
$ dos.py destroy m61;  dos.py snapshot m61 c1
```

#### Create and attach multipath devices to slave-03.
Modern (since 1.2.8) __virsh__ has --serial option, use virt-manager UI if you have older version.

```
$ qemu-img create -f qcow2 _160GB.qcow2 160G
$ virsh vol-clone _160GB.qcow2 m61-scsi1 --pool default
$ virsh vol-clone _160GB.qcow2 m61-scsi2 --pool default

## add 2 scsi disks
$ az=({a..z}); for i in {1..2}; do virsh attach-disk m61_slave-03 "/var/lib/libvirt/images/m61-scsi${i}" "sd${az[$i-1]}" --targetbus scsi --sourcetype file --type disk --driver qemu --subdriver qcow2 --serial "SCSISERIAL${i}" --persistent; done;
## add scsi doubles
$ az=({c..z}); for i in {1..2}; do virsh attach-disk m61_slave-03 "/var/lib/libvirt/images/m61-scsi${i}" "sd${az[$i-1]}" --targetbus scsi --sourcetype file --type disk --driver qemu --subdriver qcow2 --serial "SCSISERIAL${i}" --persistent; done;

$ dos.py snapshot m61 c1_mpath
```
_Note: At this point we have clean multipath devices._

#### Add multipathed node into cloud. Case 1 "OS"
Don't set cloud role, just install operation system on the __local drive__. Use disk configurator in Fuel UI.

##### Check the multipath service
```
# ll /dev/mapper; multipath -l; lsblk
```

##### Optional, take the snapshot
```
$ dos.py destroy m61;  dos.py snapshot m61 c1_mpath_os
```

#### Revert env to snapshot
```
$ dos.py destroy m61;  dos.py revert m61 c1_mpath
```

#### Add multipathed node into cloud. Case 2 "Compute"
Set cloud role as Compute. Use disk configurator in Fuel UI to install operation system on the __local drive__.

##### Check the multipath service
```
# ll /dev/mapper; multipath -l; lsblk
```

##### Optional, take the snapshot
```
$ dos.py destroy m61;  dos.py snapshot m61 c1_mpath_compute
```

#### Revert env to snapshot
```
$ dos.py destroy m61;  dos.py revert m61 c1_mpath
```

#### Add multipathed node into cloud. Case 3 "RootFS"
Set cloud role as Compute. Use disk configurator in Fuel UI to install operation system on the __multipath device__.

##### Optional, take the snapshot
```
$ dos.py destroy m61;  dos.py snapshot m61 c1_mpath_root
```

#### Revert env to snapshot and repeat with cloud based on Ubuntu.
```
$ dos.py destroy m61;  dos.py revert m61 master
```
