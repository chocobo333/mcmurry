

import unittest

import ../parserf

import os

const declare = declared(Tree) and declared(TreeKind) and declared(NodeKind) and declared(TokenKind)

var
    parser = Parser()

suite "mcmurry/compile":
    test "Import created source file":
        require true
        check existsFile("parserf.nim")
        check declare
    
    test "lexer":
        require true

        for e in parser.lex("34 + 55\n 1+2\n3+3\n55\n"):
            echo e