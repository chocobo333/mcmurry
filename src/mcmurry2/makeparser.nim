
import mcmurry/compile

Mcmurry:
    %filename = rule_parser

    %toplevel = rule

    rule:
        +or_expr

    or_expr:
        expr *("|" expr)

    expr:
        RULENAME
        TOKENNAME
        "*" expr
        "+" expr
        "?" expr
        "(" +or_expr ")"
        # expr "|" expr
        "[" +or_expr "]"


    r"[a-z_][a-z_0-9]*" = RULENAME
    r"[A-Z_][A-Z0-9]*" = TOKENNAME