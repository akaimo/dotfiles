#!/usr/bin/env sh
UUID=$(defaults read /Applications/Xcode9.1.app/Contents/Info DVTPlugInCompatibilityUUID)
echo Xcode DVTPlugInCompatibilityUUID is $UUID
for MyPlugin in ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/*
do
    UUIDs=$(defaults read "$MyPlugin"/Contents/Info DVTPlugInCompatibilityUUIDs)
    echo $MyPlugin
    if echo "${UUIDs[@]}" | grep -w "$UUID" &>/dev/null; then
        echo "The plug-in's UUIDs has contained the Xcode's UUID."
    else
        defaults write "$MyPlugin"/Contents/Info DVTPlugInCompatibilityUUIDs -array-add $UUID
        echo "Refresh the plug-in completed."
    fi
done
echo "Done!"
