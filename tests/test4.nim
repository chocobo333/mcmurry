
import unittest

import times
import strformat

import mcmurry2/ebnf2parser

Mcmurry:
    %filename = parserf
    %parsername = Parser

    %tree = block:
        Integer:
            tr_val: int

    %node = block:
        nd_val: int

    %toplevel = expression


    expression:
        simple_expr

    simple_expr:
        arrow_expr
    arrow_expr:
        assign_expr *(OP0 assign_expr)
    assign_expr:
        late_expr *(OP1 late_expr)
    late_expr:
        or_expr *(OP2 or_expr)
    or_expr:
        and_expr *(OP3 and_expr)
    and_expr:
        cmp_expr *(OP4 cmp_expr)
    cmp_expr:
        plus_expr *(OP5 plus_expr)
    plus_expr:
        mul_expr *(OP6 mul_expr)
    mul_expr:
        fast_expr *(OP7 fast_expr)
    fast_expr:
        atom *(OP8 atom) = block:
            discard
    atom:
        INT -> integer = block:
            discard
        "(" expression ")"
    
    %nim = block:
        import strutils

    r"[$^*%\\/+\-~|&.=<>!@?]+":
        if str in ["=>", "->"]:
            OP0
        elif str.endsWith("="):
            OP1
        elif str.startsWith("@") or str.startsWith("?"):
            OP2
        elif str in ["or", "xor"]:
            OP3
        elif str in ["and"]:
            OP4
        elif str in ["is", "isnot", "not", "in", "notin", "of"] or str.startsWith("=") or str.startsWith("<") or str.startsWith(">") or str.startsWith("!"):
            OP5
        elif str.startsWith("+") or str.startsWith("-") or str.startsWith("~") or str.startsWith("|"):
            OP6
        elif str in ["div", "mod", "shl", "shr"] or str.startsWith("*") or str.startsWith("/") or str.startsWith("\\") or str.startsWith("%"):
            OP7
        elif str.startsWith("$") or str.startsWith("^"):
            OP8
        else:
            OP9
    r"[1-9][0-9]*": INT
    r"\s+": SPACE  
    %ignore = SPACE

suite "Mcmurry":
    var
        start = cpuTime()
    setup:
        start = cpuTime()
    teardown:
        echo fmt"It tooks about {(cpuTime()-start)*1e3} [ms]."

    test "Makeing `Parser` and `Lexer`":
        require true