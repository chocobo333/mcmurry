

import unittest

import ../parser

import os

const declare = declared(Tree) and declared(TreeKind) and declared(NodeKind) and declared(TokenKind)

suite "mcmurry/compile":
    test "Import created source file":
        require true
        check existsFile("parser.nim")
        check declare
    
    test "lexer":
        require true