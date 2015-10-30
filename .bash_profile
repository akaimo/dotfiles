
alias javac='javac -J-Dfile.encoding=UTF-8'
alias java='java -Dfile.encoding=UTF-8'
alias byword='open -a Byword'

if [ -f ~/.bashrc ] ; then
. ~/.bashrc
fi

##
# Your previous /Users/akaimo/.bash_profile file was backed up as /Users/akaimo/.bash_profile.macports-saved_2015-02-15_at_15:28:04
##

PATH=$HOME/Python/python3/bin:$PATH

# MacPorts Installer addition on 2015-02-15_at_15:28:04: adding an appropriate PATH variable for use with MacPorts.
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.

alias ls='/opt/local/bin/gls --color=auto'

eval $(/opt/local/bin/gdircolors /Users/akaimo/Public/solarized/dircolors-solarized-master/dircolors.ansi-universal)

JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_31.jdk/Contents/Home
export JAVA_HOM

PATH=$PATH:/Users/akaimo/Library/Android/sdk/platform-tools:/Users/akaimo/Library/Android/sdk/tools
export PATH

# Add environment variable COCOS_CONSOLE_ROOT for cocos2d-x
export COCOS_CONSOLE_ROOT=/Users/akaimo/cocos2d-x-3.6/tools/cocos2d-console/bin
export PATH=$COCOS_CONSOLE_ROOT:$PATH

# Add environment variable COCOS_TEMPLATES_ROOT for cocos2d-x
export COCOS_TEMPLATES_ROOT=/Users/akaimo/cocos2d-x-3.6/templates
export PATH=$COCOS_TEMPLATES_ROOT:$PATH

# Add environment variable ANDROID_SDK_ROOT for cocos2d-x
export ANDROID_SDK_ROOT=/Users/akaimo/Library/Android/sdk
export PATH=$ANDROID_SDK_ROOT:$PATH
export PATH=$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH

# Golang
export GOROOT=/usr/local/opt/go/libexec
export GOPATH=$HOME/Golang:$HOME/vagrant/src/golang-centos/go
export PATH=$GOPATH/bin:$PATH
