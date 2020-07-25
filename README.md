# PorschePCMStuff
Porsche PCM4 (MIB2) and QNX Related Scripts
Just some random stuff for Porsche PCM analysis.

# extract_efs.py
Unpacks QNX EFS filesystem with output from dumpefs tool

Usage example: dumpefs -t ./efs-persist.efs > output.txt && python extract_efs.py output.txt ./extracted_efs

-> Source: https://www.defcon.org/images/defcon-22/dc-22-presentations/Such/DEFCON-22-Paul-Such-0x222-Playing-with-Car-Firmware.pdf

# MIB2_FEC_Generator.sh
This script offers one-touch operation for generating FECs for your MIB2 (PCM4, VW Discover Pro, Bentley, Audi, Skoda, etc...) head unit. It will generate a private RSA key, sign the public keys, and generate a signed FEC container based on the given command line options.

You will then need to upload the new FecContainer.fec file to your MIB2 efs-persist directory. Place the files onto an SD card, insert it into MIB2, then use the RCC serial port to copy from /net/mmx/fs/sda0/{your filenames} to /mnt/efs-persist/FEC/FecContainer.fec

After uploading your new FEC file, you need to patch MIBRoot to ignore the file signature, otherwise it will not work.

# This is the structure of a FecContainer.fec file

Bytes 0 - 3 = Header Bytes

Bytes 4 - 9 = Magic 11 07 FF FF FF FF

Bytes 10 - 13 = Hex filesize, for example BB 00 00 00 = BB, or 187 bytes (size from offset 0x8 to end of signature block)

Bytes 14 = Version, ex 03(?)

Bytes 15 - 19 = Vehicle Component Reference Number -> 5 bytes, not sure what this is calculated from but you can pull it from your existing fec file. See patent US9479329.

Bytes 20 - 36 = VIN

Byte  37 = 00 (padding)

Bytes 38 - 42 = Epoch in hex (Timestamp)

Byte  43 = FEC Count

Bytes 44 - 47, 48 - 51, etc... = FECs (4-digit hex ID)... we will assume 1 FEC ending at 40 for this example

Bytes 48 - 175 = RSA signed RMD160 checksum of data from offset 0x8 to end of big endian FEC block (byte 40 for this example)

Byte  176 = FEC count (again)

Bytes 177-179 = 00 00 00 (padding)

Bytes 180-183, 184-187, etc... = FEC #x in little endian

Bytes 188-199 = 01 00 00 00 03 00 00 00 FF 00 00 00 (file magic?)

# MKXFS Utility (Rebuild ifs-root)
MKXFS is used to re-build the root filesystem after unpacking and modification. The included attributes file (mkifs-attributes.txt) can be used with MKXFS to create a working ifs image. MKXFS is part of the QNX SDP + OpenQNX, but a pre-compiled binary is provided here for convenience.

The IFS image can then be loaded onto an SD card and flashed back onto your MIB2 with the following commands:
flashunlock

/usr/bin/flashit	-v -x -d -a{HEX_OFFSET} -f/net/mmx/fs/sda0/patchedroot.ifs

flashlock

The attributes file does not contain enough information to create a bootable ifs image. Thus, you should only use it to patch the stage 2 non-bootable ifs that is embedded within ifs-root.ifs file. This second stage image contains critical applications like MIBRoot, but not applications required to bring up QNX shell, meaning disaster recovery is easy (compared to screwing up the entire root fs).
