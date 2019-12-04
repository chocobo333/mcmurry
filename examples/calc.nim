
import strutils

import mcmurry

Mcmurry(id=Parser, toplevel=expression):
    parser:
        expression:
            arith_expr
        arith_expr:
            [arith_expr OP1] term
        term:
            [term OP2] factor
        factor:
            power
            OP1 factor
        power:
            atom [OP3 factor]
        atom:
            INT
            FLOAT
    lexer:
        r"\*\*": OP3
        r"[\+\-~]": OP1
        r"[\*/]": OP2
        r"([0-9]*[\.])?[0-9]+": FLOAT
        r"[1-9][0-9]*": INT
        r"\s+": SPACE
        %ignore:
            SPACE

var parser = Parser()

proc visit(self: Parser.Node): string =
    var
        children = self.children
    case self.kind
    of expression:
        result = children[0].visit
    of arith_expr, term:
        result = "(" & children[0].visit & self.tokens[0].val & children[1].visit & ")"
    of atom:
        result = self.tokens[0].val
    else:
        discard

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


when isMainModule:
    import rdstdin

    var
        input: string
    while true:
        input = readLineFromStdin(">>> ")
        try:
            echo parser.parse(input).simplify.eval()
        except SyntaxError, TokenError:
            echo "Error!!"
            break
