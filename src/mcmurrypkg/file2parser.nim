
import parseopt


const version = "v0.2.0"

# these are placeholders, of course
proc writeHelp() = discard
proc writeVersion() = discard

var filename: string
var p = initOptParser("--left --debug:3 -l -r:2")

for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
        filename = key
    of cmdLongOption, cmdShortOption:
        case key
        of "help", "h": writeHelp()
        of "version", "v": writeVersion()
    of cmdEnd: assert(false) # cannot happen
if filename == "":
    # no filename has been given, so we show the help
    writeHelp()