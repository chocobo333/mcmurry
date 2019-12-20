

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

    test "transformer":
        Tree.Transformer(visit):
            proc INT(self: Tree): Tree =
                return Tree(kind: Token, tokenkind: TokenKind.INT, val: "0")

        # let visit: proc (self_477845: Tree): Tree = block:
        #     proc INT(self: Tree): Tree =
        #         return Tree(kind: Token, tokenkind: TokenKind.INT, val: "0")

        #     proc default(self_477845: Tree): Tree =
        #         result = self_477845

        #     proc p_477844(self_477845: Tree): Tree =
        #         let kind_477846 = self_477845.getKind()
        #         if not kind_477846.isUpper(true):
        #             for i, e in self_477845.children:
        #                 `[]=`(self_477845.children, i, p_477844(e))
        #         case kind_477846
        #         of "INT":
        #             result = INT(self_477845)
        #         else:
        #             result = default(self_477845)
            
        #     p_477844
        
        var
            ast = parser.parse("1*2*3+4*5*6+7*8*9").simplify()
        discard ast.visit()
        echo ast