# PCI-424
An application for editing Plist files. Channel switching is activated after a computer reboot.
The "Audio-Midi Setup" utility is hijacking the driver. To fix this, enter the following command in the terminal: sudo rm -rf /Library/Preferences/Audio/*
sudo killall coreaudiod . This will switch the default stereo input and output channels in real time.
