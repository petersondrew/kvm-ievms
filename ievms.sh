#!/usr/bin/env bash

# Caution is a virtue
set -o nounset
set -o errtrace
set -o errexit
set -o pipefail

# Needs root
if [ "$(id -u)" != "0" ]; then
  echo "Sorry, you are not root. Please run this command with sudo or su to root."
  exit 1
fi

aria_opts=${ARIA_OPTS:-""}

log()  { printf "$*\n" ; return $? ;  }

fail() { log "\nERROR: $*\n" ; exit 1 ; }

create_home() {
  def_ievms_home="${HOME}/.ievms"
  ievms_home=${INSTALL_PATH:-$def_ievms_home}

  mkdir -p "${ievms_home}"
  cd "${ievms_home}"
}

check_system() {
  # Check for supported system
  kernel=$(uname -s)
  case $kernel in
    Linux) ;;
    *) fail "Sorry, $kernel is not supported." ;;
  esac
}

check_kvm() {
  log "Checking for KVM"
  which kvm 2>&- || fail "kvm is not installed"
  log "Checking for virt-install"
  which virt-install 2>&- || fail "virt-install is not installed"
  log "Checking for virsh"
  which virsh 2>&- || fail "virsh is not installed"
}

check_unrar() {
  log "Checking for unrar"
  which unrar 2>&- || fail "unrar is not installed (unrar-free will not work either)"
}

check_aria() {
 log "Checking for aria2"
 which aria2c 2>&- || fail "aria2 is not installed"
}

build_ievm() {
  case $1 in
    6)
      # IE6 vm only
      log "Checking for virt-win-reg"
      which virt-win-reg 2>&- || fail "virt-win-reg is not installed"
      urls="http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_XP_IE6.exe"
      vhd="Windows XP.vhd"
      os_variant="winxp"
      # https://www.virtualbox.org/attachment/wiki/Migrate_Windows/MergeIDE.zip
      merge_ide=true
      ;;
    7)
      urls=$(echo http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_Vista_IE7.part0{1.exe,2.rar,3.rar,4.rar,5.rar,6.rar})
      vhd="Windows Vista.vhd"
      os_variant="vista"
      merge_ide=false
      ;;
    8)
      urls=$(echo http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_7_IE8.part0{1.exe,2.rar,3.rar,4.rar})
      vhd="Win7_IE8.vhd"
      os_variant="win7"
      merge_ide=false
      ;;
    9)
      urls=$(echo http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_7_IE9.part0{1.exe,2.rar,3.rar,4.rar,5.rar,6.rar,7.rar})
      vhd="Windows 7.vhd"
      os_variant="win7"
      merge_ide=false
      ;;
    *)
      fail "Invalid IE version: ${1}"
      ;;
  esac

  vm="IE${1}"
  img_path="${ievms_home}/images/${vm}"
  img="${os_variant}.qcow2"
  mkdir -p "${img_path}"
  cd "${img_path}"

  virtio_url="https://alt.fedoraproject.org/pub/alt/virtio-win/latest/images/bin/virtio-win-0.1-59.iso"
  virtio_iso=$(basename $virtio_url)

  # Download if it doesn't exist in the root, each VM needs its own copy since it complains about sharing media
  if [[ ! -f "${ievms_home}/${virtio_iso}" ]]
  then
    log "Downloading latest VirtIO drivers from ${virtio_url}"
    if ! aria2c -c -d ${ievms_home} "${virtio_url}"
    then
      fail "Failed to download "${virtio_url}" to ${ievms_home}/ using 'aria2', error code ($?)"
    fi
  fi

  if [[ ! -f "${img_path}/${virtio_iso}" ]]
  then
    log "Copying virtio driver image to ${img_path}"
    cp "${ievms_home}/${virtio_iso}" "${img_path}/"
  fi

  log "Checking for existing VHD at ${img_path}/${vhd}"
  if [[ ! -f "${vhd}" ]]
  then

    log "Checking for downloaded VHDs at ${img_path}/"
    for url in $urls
    do
      archive=$(basename $url)
      log "Downloading VHD from ${url} to ${img_path}/"
      if ! aria2c ${aria_opts} -c -d ${img_path} "${url}"
      then
        fail "Failed to download ${url} to ${img_path}/ using 'aria2', error code ($?)"
      fi
    done

    rm -f "${img_path}/"*.vmc

    log "Extracting VHD from ${img_path}/${archive}"
    if ! unrar e -y "${archive}"
    then
      fail "Failed to extract ${archive} to ${img_path}/${vhd}," \
        "unrar command returned error code $?"
    fi
  fi

  log "Checking for existing ${vm} VM"
  if ! virsh dominfo "${vm}" 2>&-
  then

    log "Converting disk image to QCOW2 format to support snapshots (this may take a while)"
    qemu-img convert "${img_path}/${vhd}" -O qcow2 "${img_path}/${img}" > /dev/null
    [ -f "${img_path}/${vhd}" ] && rm "${img_path}/${vhd}"
    log "Creating clean snapshot for later restoration"
    qemu-img snapshot -c clean "${img_path}/${img}"
    log "Creating ${vm} VM"
    virt-install --connect=qemu:///system -n "${vm}" --import --hvm --os-type=windows --os-variant=${os_variant} -r 256 \
      --disk "${img_path}/${img}",device=disk,bus=ide,format=qcow2 \
      --disk "${img_path}/${virtio_iso}",device=cdrom,bus=ide \
      --network bridge=br0,model=virtio \
      --vnc --vnclisten=0.0.0.0 --noautoconsole \
      --autostart > /dev/null

    # Workaround for http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=600017
    # https://bugs.launchpad.net/ubuntu/+source/virtinst/+bug/655392
    # Shouldn't adversely effect patched versions
    log "Migrating libvirt domain definition for ${vm} from raw to qcow2 if necessary"
    log "See http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=600017 and https://bugs.launchpad.net/ubuntu/+source/virtinst/+bug/655392"
    virsh destroy "${vm}" > /dev/null
    [ -f "${img_path}/${vm}.xml" ] && rm "${img_path}/${vm}.xml"
    # Loop through definition and try to rewrite the driver line for the hd
    in_hd_tag=false
    found_driver=false
    virsh dumpxml "${vm}" 2>/dev/null | while read line ; do
      if ! $in_hd_tag && echo "$line" | grep -q "<disk type='file' device='disk'" ; then
        log "Found hard drive"
        in_hd_tag=true
      elif $in_hd_tag && ! $found_driver ; then
        if echo "$line" | grep -q "<driver" ; then
          log "Found driver"
          found_driver=true
          continue
        fi
        in_hd_tag=false
      elif $found_driver ; then
        log "Writing new driver"
        echo "<driver name='qemu' type='qcow2'/>" >> "${img_path}/${vm}.xml"
        found_driver=false
        in_hd_tag=false
      fi

      # Write line to new definition
      echo "$line" >> "${img_path}/${vm}.xml"
      if [ "$line" = "</domain>" ]; then
        # Redefine domain with new definition
        virsh define "${img_path}/${vm}.xml" > /dev/null
        break
      fi
    done

    # XP fix for IDE drivers
    if $merge_ide ; then
      log "Merging IDE devices to avoid BSOD on first boot"
      virt-win-reg --merge "${img_path}/${img}" "${ievms_home}/MergeIDE.reg"
    fi

    virsh start "${vm}"
  fi

}


check_system
create_home
check_kvm
check_aria
check_unrar

all_versions="6 7 8 9"
for ver in ${IEVMS_VERSIONS:-$all_versions}
do
  log "Building IE${ver} VM"
  build_ievm $ver
done

log "Done!"
