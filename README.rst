Overview
========

Microsoft provides virtual machine disk images to facilitate website testing
in multiple versions of IE, regardless of the host operating system.
Unfortunately, setting these virtual machines up without Microsoft's VirtualPC
can be extremely difficult. The kvm-ievms scripts aim to facilitate that process using
KVM on Linux. With a single command, you can have IE6, IE7, IE8
and IE9 running in separate virtual machines.


Requirements
============

* KVM/qemu-img (Debian/Ubuntu: ``sudo apt-get install kvm``)
* virt-install/virsh (Debian/Ubuntu: ``sudo apt-get install libvirt-bin``)
* bridge-utils (Debian/Ubuntu: ``sudo apt-get install bridge-utils``)
* aria2 (Debian/Ubuntu: ``sudo apt-get install aria2``)
* unrar (nonfree) (Debian/Ubuntu: ``sudo apt-get install unrar``)
* sudo (along with superuser permissions, this is needed for libvirt operations)
* Patience


Installation
============

1. Install KVM.

3. Create ``br0`` network bridge interface. (http://wiki.debian.org/BridgeNetworkConnections)

3. Download and unpack ievms:

   * Install IE versions 6, 7, 8 and 9.

         sudo ./ievms.sh

   * Install specific IE versions (IE7 and IE9 only for example):

         sudo IEVMS_VERSIONS="7 9" ./ievms.sh

4. Connect to your virtual machines via vnc.

The VHD archives are massive and can take hours or tens of minutes to
download, depending on the speed of your internet connection. You might want
to start the install and then go catch a movie, or maybe dinner, or both.

Once available and started in KVM, the password for ALL VMs is "Password1".


Recovering from a failed installation
-------------------------------------

Each version is installed into a subdirectory of ``~/.ievms/vhd/``. If the installation fails
for any reason (corrupted download, for instance), delete the version-specific subdirectory
and rerun the install.

If nothing else, you can delete ``~/.ievms`` and rerun the install.


Specifying the install path
---------------------------

To specify where the VMs are installed, use the INSTALL_PATH variable:

    sudo INSTALL_PATH="/Path/to/.ievms" ./ievms.sh


Passing additional options to aria
----------------------------------

The ``aria2`` command is passed any options present in the ``ARIA_OPTS`` 
environment variable. For example, you can set a download speed limit:

    sudo ARIA_OPTS="--limit-rate 50k" ./ievms.sh


Features
========

Clean Snapshot
    A snapshot is automatically taken upon install, allowing rollback to the
    pristine virtual environment configuration. Anything can go wrong in
    Windows and rather than having to worry about maintaining a stable VM,
    you can simply revert to the first snapshot to reset your VM to the
    initial state.

    The VMs provided by Microsoft will not pass the Windows Genuine Advantage
    and cannot be activated. Unfortunately for us, that means our VMs will
    lock us out after 30 days of unactivated use. By reverting to the
    clean snapshot the countdown to the activation apocalypse is reset,
    effectively allowing your VM to work indefinitely.


Resuming Downloads
    If one of the comically large files fails to download, the ``aria2``
    command used will automatically attempt to resume where it left off.


License
=======
Copyright (c) 2012 Drew Peterson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
