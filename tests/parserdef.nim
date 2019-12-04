
import mcmurry
export mcmurry

Mcmurry(id=Parser, toplevel=expression):
    parser:
        expression:
            arith_expr
        arith_expr:
            term *(OP1 term)
        term:
            atom_expr *(OP2 atom_expr)
        atom_expr:
            atom *trailer
        trailer:
            r"\(" [expression] r"\)"
        atom:
            NAME
            INT
            r"nil"
            r"false"
            r"true"
    lexer:
        r"[\+\-]": OP1
        r"[\*/]": OP2
        r"[a-zA-Z_][a-zA-z_0-9]*": NAME
        r"[1-9][0-9]*": INT
        r"("").*("")": STRING
        var
            nIndent = 0
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
        r"\n?\s*#[^\n]*": COMMENT
        %ignore:
            SPACE
            COMMENT