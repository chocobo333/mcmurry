# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import parserdef
var parser = Parser()
test "lex":
    require true
    # parser.program = "ff ff ff"
    # while true:
    #     var
    #         tok = parser.next()
    #     echo tok
    #     if tok.kind == EOF:
    #         break
    for e in parser.lex("aa b+b\n    cc dd\n    ee ff\ngg hh"):
        echo e