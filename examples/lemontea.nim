
from mcmurry import parse, `$`, simplify, table, nodetype

mcmurry.MakeParser(id=parser, toplevel=expression):
    expression:
        arith_expr
    arith_expr:
        term
        arith_expr OP1 term
    term:
        factor
        term OP2 factor
    factor:
        power
        OP1 factor
    power:
        atom
        atom OP3 factor
    atom:
        NAME
        INT
        STRING
    r"for": FOR
    r"if": IF
    r"in": IN
    r":": COL
    r"=": EQ
    r"\*\*": OP3
    r"[\+\-~]": OP1
    r"[\*/]": OP2
    r"[a-zA-Z_][a-zA-z_0-9]*": NAME
    r"[1-9][0-9]*": INT
    r"("").*("")": STRING
    var nIndent = 0
    r"\n?\s*#[^\n]*": COMMENT
    r"\n[ ]*":
        block:
            if len-1 > nIndent:
                nIndent = len-1
                INDENT
            elif len-1 < nIndent:
                nIndent = len-1
                DEDENT
            else:
                LF
    r"\s+": SPACE
    %ignore:
        SPACE
        COMMENT

proc visit(self: parser.nodetype): string {.discardable.} =
    var
        children = self.children
    case self.kind
    of expression:
        echo self
        result = children[0].visit
    of arith_expr, term:
        result = "(" & children[0].visit & self.tokens[0].value & children[1].visit & ")"
    of atom:
        result = self.tokens[0].value
    else:
        discard

when isMainModule:
    var
        ast = parser.parse("1 + 2*5 + 3 + 4/2")
    echo ast.simplify
    # echo ast.simplify.visit