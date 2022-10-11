#!/usr/bin/python

from AppKit import *
import sys


if __name__ == '__main__':
    icon = sys.argv[1]
    dest = sys.argv[2]
    ws = NSWorkspace.sharedWorkspace()

    image = NSImage.new().initByReferencingFile_(icon)
    success = ws.setIcon_forFile_options_(image, dest, 0)

    sys.exit(0 if success else 1)
