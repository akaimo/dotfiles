#!/bin/sh

find ./ -name "*.storyboard" -or -name "*.xib"  |xargs -IFILE xcrun ibtool --upgrade FILE --write FILE
