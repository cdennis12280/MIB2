#!/bin/bash
# MIB2_FEC_Generator.sh -f desired_fecs_comma_separated -n YOUR_VCRN -v YOUR_VIN -d output_dir (default ./)

# This script offers one-touch operation for generating FECs for your MIB2 (PCM4, VW Discover Pro, Bentley, Audi, Skoda, etc...) head unit.
# Place the files onto an SD card, insert it into MIB2, then use the RCC serial port to copy
# from /net/mmx/fs/sda0/{your filenames} to /mnt/efs-persist/FEC/FecContainer.fec 
# Because we do not have the original private key file, you will need to then patch your MIBRoot application to accept our new FEC file, since the signature will not match what MIBRoot expects.

#Known FECs
#00030000                  # AMI (Enables USB)
#00030001                  # Gracenote
#00040100                  # Navigation
#00050000                  # Bluetooth
#00060100                  # Vehicle Data Interface
#00060200                  # Infotainment Control?
#00060300                  # MirrorLink
#00060400                  # Performance Monitor (Sport HMI)
#00060500                  # ?
#00060600                  # Baidu CarLife?
#00060700                  # CarPlay (both need to be present?)
#00060800                  # CarPlay
#00060900                  # Android Auto
#00070100                  # SDS
#00070200                  # SDS for Nav

#Refer to your efs-persist ProdEL.txt or ExceptionList.txt files for your mfr and region specific map FEC IDs.
#If you see a semicolon between two hex values for one byte, use "99" in place of the last two digits.

usage='\nUsage: MIB2_FEC_Generator.sh -f desired_fecs_comma_separated -n vcrn -v vin -d output-dir (optional, default: ./) \nExample: MIB2_FEC_Generator.sh -f 00060800,00070100,00070200 -n 5C00990011 -v WP0CA1D10FZ964212\n';
PUBLIC_EXPONENT=3
KEYSIGN_PAD="0000000000000000000000000000000000000000000000000000000000000003"

create_keypair_and_sign () {
    metainfokeydir=$output_dir_keys'/MetainfoKey';
    feckeydir=$output_dir_keys'/FECKey';
    datakeydir=$output_dir_keys'/DataKey';

    if  [ ! -d $metainfokeydir ]; then
        mkdir $metainfokeydir;
    fi
    if  [ ! -d $feckeydir ]; then
        mkdir $feckeydir;
    fi
    if  [ ! -d $datakeydir ]; then
        mkdir $datakeydir;
    fi
    #create metainfo keypair
    openssl genrsa -3 -out $output_dir_keys/MIB-High_MI_private.pem 1024;
    stat=$?
    if [ $stat -ne 0 ]; then
        echo 'Failure. Unable to generate private key, is openssl installed?';
        exit
    else
        openssl rsa -in $output_dir_keys/MIB-High_MI_private.pem -pubout > $output_dir_keys/MIB-High_MI_public.der -outform DER;

        stat=$?
        if [ $stat -ne 0 ]; then
            echo 'Failure. Unable to generate public key.';
            exit;
        fi
        MODULUS_MI=$(openssl rsa -pubin -noout -inform der -in $output_dir_keys/MIB-High_MI_public.der -modulus | cut -d "=" -f 2);
    fi
    #copy MI key to DK
    cp $output_dir_keys/MIB-High_MI_private.pem $output_dir_keys/MIB-High_DK_private.pem
    cp $output_dir_keys/MIB-High_MI_public.der $output_dir_keys/MIB-High_DK_public.der
    #create FEC keypair
    openssl genrsa -3 -out $output_dir_keys/MIB-High_FEC_private.pem 1024;
    openssl rsa -in $output_dir_keys/MIB-High_FEC_private.pem -pubout > $output_dir_keys/MIB-High_FEC_public.der -outform DER
    MODULUS_FEC=$(openssl rsa -pubin -noout -inform der -in $output_dir_keys/MIB-High_FEC_public.der -modulus | cut -d "=" -f 2);
    echo "Public Exponent is $PUBLIC_EXPONENT. Now signing FEC, MetaInfo and Data keys with MetaInfo Key.";

    local MODPAD_FEC="\x"$(printf "$MODULUS_FEC$KEYSIGN_PAD" |  sed 's/.\{2\}/&\\x/g' | cut -c1-638)
    local MODPAD_MI="\x"$(printf "$MODULUS_MI$KEYSIGN_PAD" |  sed 's/.\{2\}/&\\x/g' | cut -c1-638)
    $(echo -n -e "$MODPAD_FEC" > "$output_dir_keys"/padded_feckey.tmp)
    $(echo -n -e "$MODPAD_MI" > "$output_dir_keys"/padded_mikey.tmp)

    #sign both keys and output to .bin files
    $(openssl dgst -sha1 -binary -sign "$output_dir_keys"/MIB-High_MI_private.pem "$output_dir_keys"/padded_feckey.tmp >> "$output_dir_keys"/padded_feckey.tmp)
    $(openssl dgst -sha1 -binary -sign "$output_dir_keys"/MIB-High_MI_private.pem "$output_dir_keys"/padded_mikey.tmp >> "$output_dir_keys"/padded_mikey.tmp)

    #create signed MI key files
    mv "$output_dir_keys"/padded_mikey.tmp $metainfokeydir/MIB-High_MI_public_signed.bin
    cp $metainfokeydir/MIB-High_MI_public_signed.bin $metainfokeydir/AU_MIB-High_MI_public_signed.bin
    cp $metainfokeydir/MIB-High_MI_public_signed.bin $metainfokeydir/SK_MIB-High_MI_public_signed.bin
    cp $metainfokeydir/MIB-High_MI_public_signed.bin $metainfokeydir/VW_MIB-High_MI_public_signed.bin
    cp $metainfokeydir/MIB-High_MI_public_signed.bin $metainfokeydir/PO_MIB-High_MI_public_signed.bin
    #create signed FEC key files
    mv "$output_dir_keys"/padded_feckey.tmp $feckeydir/MIB-High_FEC_public_signed.bin
    cp $feckeydir/MIB-High_FEC_public_signed.bin $feckeydir/AU_MIB-High_FEC_public_signed.bin
    cp $feckeydir/MIB-High_FEC_public_signed.bin $feckeydir/SK_MIB-High_FEC_public_signed.bin
    cp $feckeydir/MIB-High_FEC_public_signed.bin $feckeydir/VW_MIB-High_FEC_public_signed.bin
    cp $feckeydir/MIB-High_FEC_public_signed.bin $feckeydir/PO_MIB-High_FEC_public_signed.bin
    #copy metainfo key to datakey location
    cp $metainfokeydir/MIB-High_MI_public_signed.bin $datakeydir/MIB-High_DK_public_signed.bin
    cp $datakeydir/MIB-High_DK_public_signed.bin $datakeydir/AU_MIB-High_DK_public_signed.bin
    cp $datakeydir/MIB-High_DK_public_signed.bin $datakeydir/VW_MIB-High_DK_public_signed.bin
    cp $datakeydir/MIB-High_DK_public_signed.bin $datakeydir/SK_MIB-High_DK_public_signed.bin
    cp $datakeydir/MIB-High_DK_public_signed.bin $datakeydir/PO_MIB-High_DK_public_signed.bin


    #verify
    if [ -f "$metainfokeydir/MIB-High_MI_public_signed.bin" ] && [ -f "$feckeydir/MIB-High_FEC_public_signed.bin" ] && [ -f "$datakeydir/MIB-High_DK_public_signed.bin" ]; then
        echo "Successful temp key generation.";
        return 0;
    else
        echo 'Failed to generate signed public key files. Check output above for errors.';
		echo "Need files exist:"
		echo "$metainfokeydir/MIB-High_MI_public_signed.bin"
		echo "$feckeydir/MIB-High_FEC_public_signed.bin"
		echo "$datakeydir/MIB-High_DK_public_signed.bin"
        exit 1;
    fi
}

build_fec_container () {
    local HDR="\x01\x00\x00\x00";
        local FECLEN=$((4*$FEC_COUNT))
    local FILESIZE="\x"$(printf "%x\n" $((35+$FECLEN+128)))"\x00\x00\x00"
    local MAGIC="\x11\x07\xFF\xFF\xFF\xFF"
    local VER="\x03"
    # local VCRNHEX=$(printf "$VCRN_O" | cut -c1-24)
    local VINHEX="\x"$(printf "$VIN" | xxd -pu |  sed 's/.\{2\}/&\\x/g' | cut -c1-66)"\x00"
    local EPOCH_HEX="\x"$(printf "%x\n" $EPOCH |  sed 's/.\{2\}/&\\x/g' | cut -c1-14)
    local FECCOUNTN="\x"$(printf "%02s" $FEC_COUNT)
        local FECS_NOCSV=$(tr -d ',' <<< $FECS_CSV)
    local FECSHEX="\x"$(printf "$FECS_NOCSV" |  sed 's/.\{2\}/&\\x/g')
    local FECSHEX=${FECSHEX::${#FECSHEX}-2}
    local LEFECSHEX="\x"$(printf "$LEFECS" |  sed 's/.\{2\}/&\\x/g')
    local LEFECSHEX=${LEFECSHEX::${#LEFECSHEX}-2}
    #echo -n -e "$FILESIZE$MAGIC$VER" > $output_dir/FecContainer.tmp  && cat vcrn.tmp >> $output_dir/FecContainer.tmp && echo -n -e "$VINHEX$EPOCH_HEX$FECCOUNTN$FECSHEX" >> $output_dir/FecContainer.tmp
	echo -n -e "$MAGIC$VER" > $output_dir/FecContainer.tmp  && cat vcrn.tmp >> $output_dir/FecContainer.tmp && echo -n -e "$VINHEX$EPOCH_HEX$FECCOUNTN$FECSHEX" >> $output_dir/FecContainer.tmp

    echo "Now signing incomplete FEC container."
    $(openssl dgst -ripemd160 -binary -sign "$output_dir_keys"/MIB-High_FEC_private.pem $output_dir/FecContainer.tmp >> $output_dir/FecContainer.tmp)

    stat=$?
    if [ $stat -ne 0 ]; then
        echo 'Failure. Unable to sign FEC container.';
        exit;
    else
        echo 'Done. Generating little endian FECs and completing container file.';
    fi

    echo -n -e "$FECCOUNTN\x00\x00\x00"$LEFECSHEX"\x01\x00\x00\x00\x03\x00\x00\x00\xFF\x00\x00\x00">> $output_dir/FecContainer.tmp
    echo -n -e '\x01\x00\x00\x00'$FILESIZE > $output_dir/FecContainer.fec & cat $output_dir/FecContainer.tmp >> $output_dir/FecContainer.fec

    #verify
    if [ -f "$output_dir/FecContainer.tmp" ]; then
        return 0;
    else
        echo 'Failed to generate FEC temp file. Check output above for errors.';
        exit 1;
    fi
}

while getopts ":f:n:v:d:"  opt; do
    case "$opt" in
        f)
            FECS_CSV=$OPTARG
            LEN=$(printf "$FECS_CSV" | wc -c)
            if [[ $LEN -lt 8 ]]; then
                echo "Failure. You didn't specify any FECs to generate"; exit 1;
            else
                FEC_COUNT=0;
                for i in $(printf $FECS_CSV | sed "s/,/ /g")
                do
                    if [ ${#i} -ne 8 ]; then
                        echo 'One or more of your FECs is an invalid length. FECs must be 8 digits.';
                        exit 1;
                    fi
                    #LEFECS=$LEFECS$(printf $i | grep -o .. | tail -r | echo "$(tr -d '\n')")
					LEFECS=$LEFECS$(printf $i | echo "$(tr -d '\n')" | cut -c7-8)$(printf $i | echo "$(tr -d '\n')" | cut -c5-6)$(printf $i | echo "$(tr -d '\n')" | cut -c3-4)$(printf $i | echo "$(tr -d '\n')" | cut -c1-2)
                    FEC_COUNT=$((FEC_COUNT+1));
                done
                echo "Generating feature codes: $FECS_CSV. FEC count: $FEC_COUNT";
                VALIDFEC=1;
            fi
        ;;
        n)
            if ! [[ $OPTARG =~ ^[0-9A-Fa-f]{1,}$ ]] ; then
                echo "Failure. Invalid VCRN, input must be hex."
                exit 1
            fi
            VCRN_O="0x"$(printf $(tr -d ' ' <<< "$OPTARG") |  sed 's/.\{2\}/& 0x/g');
            VCRN=$(printf "$VCRN_O" | xxd -r > vcrn.tmp);
            if [ ! -f "vcrn.tmp" ]; then
                echo "Could not create vcrn.tmp in this directory, please check permissions."
                exit 1;
            fi
            LEN=$(printf "$VCRN_O" | wc -w)
            if [ $LEN  != 6 ]; then
                echo "Failure. Invalid VCRN, must be 5 bytes exactly but you only gave $(($LEN-1))."; exit 1;
            else
                echo 'Continuing with VCRN (post validation hexdump): '$(hexdump  -e '16/1 "%02x " "\n"' vcrn.tmp)
                VALIDVCRN=1;
            fi
        ;;
        v)
            VIN=$OPTARG
            LEN=$(printf "$VIN" | wc -c)
            if [ $LEN  != 17 ]; then
                echo "Failure. Invalid VIN, must be 17 digits exactly but you only gave $LEN"; exit 1;
            else
                echo "Continuing with VIN: $VIN";
                VALIDVIN=1;
            fi
        ;;
        d)
            output_dir=$OPTARG
            output_dir_keys=$output_dir'/Keys';
            if  [ ! -d $output_dir ]; then
                mkdir $output_dir
            fi
            if  [ ! -d $output_dir_keys ]; then
                mkdir $output_dir_keys
            fi
        ;;
        :)
        echo "Option -$OPTARG requires an argument" >&2
        exit 1;;
        \?) ;;
    esac
done
if [ $OPTIND -eq 1 ]; then echo $usage; exit 1; fi;

if [[ $VALIDVIN != 1 ]] || [[ $VALIDVCRN != 1 ]] || [[ $VALIDFEC != 1 ]]; then
    echo "Failed due to missing argument."
    printf "$usage"; exit 1;
fi
if [ -z $output_dir ]; then
    output_dir='./';
    output_dir_keys='./Keys';
    if  [ ! -d $output_dir_keys ]; then
        mkdir $output_dir_keys
    fi
else
    echo "Using user specified directory: $output_dir"
fi

EPOCH=$(date +%s)

echo "Using epoch: $EPOCH.";

if [ ! -e $output_dir_keys/MIB-High_FEC_private.pem ]
then
echo "================================================================================================";
echo "Now generating signing keys...";
create_keypair_and_sign;
else
echo "Key already exist. Ignore";
fi

echo "================================================================================================";
echo "Now building FEC container.";
build_fec_container;

echo "================================================================================================";
echo "Success! Your FEC files are located in $output_dir.";
echo "Remember to also copy your public keys to the appropriate location in efs-persist.";
echo "================================================================================================";
rm -rf vcrn.tmp && rm -rf $output_dir/fecwap.tmp && rm -rf $output_dir/fecwapped.tmp && rm -rf $output_dir/FecContainer.tmp

exit 1;
