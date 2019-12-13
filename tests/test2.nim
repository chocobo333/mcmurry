
import unittest

import mcmurry/compile


Mcmurry:
    %filename = parserf
    %parsername = Parser
    %toplevel = module

    %nodename = Node
    %node = NIM:
        integer:
            intval: int
    END

    %tokenname = Token
    %token = NIM:
        INT:
            tk_intval: int
    END

    %treename = Tree

    module:
        +statement
    statement:
        simple_stmt
        compound_stmt
        LF
    simple_stmt:
        small_stmt *(";" small_stmt)
    small_stmt:
        pass_stmt
        expr_stmt
    compound_stmt:
        if_stmt
        while_stmt
        for_stmt
    if_stmt:
        "if" expression ":" suite *("elif" expression ":" suite) ["else" ":" suite]
    while_stmt:
        "while" expression ":" suite
    for_stmt:
        "for" expression "in" expression ":" suite
    suite:
        simple_stmt
        INDENT +statement DEDENT
    pass_stmt:
        "pass"
    expr_stmt:
        simple_expr
    expression:
        simple_expr
        if_expr
    simple_expr:
        arrow_expr
    arrow_expr:
        assign_expr *(OP0 assign_expr)
    assign_expr:
        plus_expr *(OP1 plus_expr)
    plus_expr:
        atom *(OP8 atom)
    atom:
        r"[a-zA-Z_][a-zA-z_0-9]*" -> ident
        INT -> integer = NIM:
            result.intval = parseInt(children[0].val)
        END
        "true" -> true
        "false" -> false
        "(" expression ")"
    if_expr:
        "if" expression ":" expression "else" ":" expression

    %nim = NIM:
        import strutils
        var
            nIndent: seq[int] = @[0]
    END

    "fff" = FF

    r"[\+\-\*\/\^\=\~\>]+" = NIM:
        if str in ["+", "-"]:
            OP8
        elif str in ["==", "<=", ">=", "<", ">"]:
            OP5
        elif str.endsWith("="):
            OP1
        elif str == "=>" or str == "->":
            OP0
        else:
            OP10
    END
    r"[a-zA-Z_][a-zA-z_0-9]*" = NAME
    r"[1-9][0-9]*" = INT
    r"("")[^""\\]*(\\.[^""\\]*)*("")" = STRING
    r"\n?\s*##[^\n]*" = DOCSTR
    r"\n?\s*#[^\n]*" = COMMENT
    r"\n[ ]*" = NIM:
        if len-1 > nIndent[^1]:
            nIndent.add len-1
            INDENT
        elif len-1 < nIndent[^1]:
            while len-1 != nIndent[^1]:
                discard nIndent.pop()
                kind_stack.add DEDENT
                if nIndent.len == 0:
                    raise newException(SyntaxError, "Invalid indent.")
            discard kind_stack.pop()
            DEDENT
        else:
            LF
    END
    r"\s+" = SPACE  
    %ignore = SPACE / COMMENT
    
import os

suite "mcmurry/compile":
    test "Create source file":
        require true
        check existsFile("parserf.nim")