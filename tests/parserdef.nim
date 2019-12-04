
import mcmurry
export mcmurry

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