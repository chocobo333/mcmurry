

import unittest

import ../parserf

import os

const declare = declared(Tree) and declared(TreeKind) and declared(NodeKind) and declared(TokenKind)

var
    parser = Parser()

suite "mcmurry/compile":
    setup:
        echo "===== Starting tests. ====="
    teardown:
        echo "===== Finished tests. ====="
    test "Import created source file":
        require true
        check existsFile("parserf.nim")
        check declare
    
    test "lexer":
        require true

        var
            ast = parser.parse("1*2*3+4*5*6+7*8*9")
        echo ast.simplify()
    
    test "vistor":

        Tree.Visitor(visit):
            proc INT(self: Tree) =
                echo self

        var
            ast = parser.parse("1*2*3+4*5*6+7*8*9").simplify()
        ast.visit()