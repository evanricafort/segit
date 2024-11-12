# SegIt!
SegIt! is a shell script for automating networking segmentation test.

# Installation

git clone https://github.com/evanricafort/segit.git && cd segit && sudo chmod +x segit.sh && sudo ./segit.sh -h

# Usage
./segtest.sh [-f target_file] [-T4] [-open] <target(s)>

# Example: 
./segtest.sh 192.168.1.0/24 | ./segtest.sh -f targets.txt | ./segtest.sh -T4 -f targets.txt | ./segtest.sh -f targets.txt -T4 -open
