
import unittest

import strutils

import parserdef
var parser = Parser()


test "lex":
    require true

    for e in parser.lex("aa b+b\n    cc dd\n    ee ff\ngg hh"):
        echo e
    var
        tree = parser.parse("1*2*3+4*5*6+7*8*9").simplify()

    echo tree

    Visitor(Parser, visit):
        proc atom(self: Parser.Node) =
            var
                tmp = self.tokens[0].val.parseInt()
            self.tokens = @[Parser.Token(kind: INT, val: $(tmp+1))]
        proc visit_default(self: Parser.Node) =
            discard
    echo tree.visit()

    