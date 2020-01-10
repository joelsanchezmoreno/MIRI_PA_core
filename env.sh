# Source file for environment variables

export VERILATOR_ROOT="/home/jsanchez/new-verilator/verilator"

#Detect the path to the top of the repo from which we are calling the script
export REPOROOT=$( cd $(dirname "$1"); pwd -P)

#Add our scripts to the path
if [ -z ${OLD_PATH+x} ]; then
    export OLD_PATH=$PATH;
else
    export PATH=$OLD_PATH;
fi
export PATH="$REPOROOT/tools/scripts:$PATH"

#Specify the path f the rtl and testbenches
export RTLROOT="$REPOROOT/rtl"
export TBROOT="$REPOROOT/tb"
