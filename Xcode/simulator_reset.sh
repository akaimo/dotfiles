instruments -s devices \
 | grep Simulator \
 | grep -o "[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}" \
 | while read -r line ; do
    echo "Reseting Simulator with UDID: $line"
    xcrun simctl erase $line
done
