
import unittest

import parserdef
var parser = Parser()
test "lex":
    require true

    for e in parser.lex("aa b+b\n    cc dd\n    ee ff\ngg hh"):
        echo e
    echo parser.parse("1*2*3+4*5*6+7*8*9")
    echo parser.parse("1(4+4)+2+3*4+5+6*7+8+9")
         