
import unittest

import mcmurry/compile


Mcmurry:
    %filename = parserf
    %parsername = Parser
    %toplevel = expression

    %nodename = Node

    %tokenname = Token
    %token = NIM:
        INT:
            intval: int
    END

    %treename = Tree

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
        atom *(OP8 atom)
    atom:
        r"[a-zA-Z_][a-zA-z_0-9]*" -> ident
        INT -> integer
        "(" expression ")"

    %nim = NIM:
        import strutils
    END

    r"[$^*%\\/+\-~|&.=<>!@?]+" = NIM:
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
    END
    r"[1-9][0-9]*" = NIM:
        INT
    END
    r"\s+" = SPACE  
    %ignore = SPACE
    
import os

suite "mcmurry/compile":
    setup:
        echo "===== Starting tests. ====="
    teardown:
        echo "===== Finished tests. ====="
    test "Create source file":
        require true
        check existsFile("parserf.nim")