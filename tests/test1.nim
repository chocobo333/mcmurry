
import unittest

import strutils

import parserdef
var parser = Parser()

proc eval(self: Parser.Node): float =
    var
        children = self.children
        tokens = self.tokens
    case self.kind
    of expression:
        result = children[0].eval()
    of arith_expr:
        if tokens[0].val == "+":
            return children[0].eval() + children[1].eval()
        elif tokens[0].val == "-":
            return children[0].eval() - children[1].eval()
        assert false
    of term:
        if tokens[0].val == "*":
            return children[0].eval() * children[1].eval()
        elif tokens[0].val == "/":
            return children[0].eval() / children[1].eval()
        assert false
    of factor:
        if tokens[0].val == "+":
            return children[0].eval()
        elif tokens[0].val == "-":
            return -children[0].eval()
        assert false
    of power:
        raise newException(ValueError, "Not Implement.")
    of atom:
        return tokens[0].val.parseFloat()


Visitor(Parser, inc_all):
    proc atom(self: Parser.Node) =
        var
            tmp = self.tokens[0].val.parseInt()
        self.tokens = @[Parser.Token(kind: INT, val: $(tmp+1))]
    proc visit_default(self: Parser.Node) =
        discard


test "lex":
    require true

    var
        test1 = parser.parse("1*2*3+4*5*6+7*8*9").simplify()
        test2 = parser.parse("4*4+2/4+1*4 - 12").simplify()
        # test3 = Parser.Node(kind: power, children: @[Parser.Node(kind: atom, tokens: @[Parser.Token(kind: FLOAT, val: "3")]), Parser.Node(kind: atom, tokens: @[Parser.Token(kind: FLOAT, val: "5")])], tokens: @[Parser.Token(kind: OP3, val: "**")])
    
    check test1.eval() == 1.0*2*3+4*5*6+7*8*9
    check test2.eval() == 4.0*4+2/4+1*4 - 12

    check test1.inc_all.eval() == 2.0*3*4+5*6*7+8*9*10
    check test2.inc_all.eval() == 5.0*5+3/5+2*5 - 13

    expect(SyntaxError):
        discard parser.parse("*3 + 5")
    expect(SyntaxError):
        discard parser.parse("3* * 5")

    # echo parser.parse("3 ** 5").simplify().children[0] == Parser.Node(kind: atom, tokens: @[Parser.Token(kind: FLOAT, val: "3")])
    # check parser.parse("3 ** 5").simplify == test3

    