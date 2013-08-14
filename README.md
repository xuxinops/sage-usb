#### please follow this to initialize this project

- steps for making usb
>    # update repo from 192.168.1.5
>    sudo ./update_repo.sh
>    # fetch install.img and initrd.img from mirrors.163.com
>    # also, you could move your custom image into this dir
>    sudo ./gen_img.sh
>    # write to disk
>    sudo ./usb.sh /dev/sdb

- steps for making iso
>    # update repo from 192.168.1.5
>    sudo ./update_repo.sh
>    # fetch install.img and initrd.img from mirrors.163.com
>    # also, you could move your custom image into this dir
>    sudo ./gen_img.sh
>    # write to disk
>    sudo ./iso.sh
