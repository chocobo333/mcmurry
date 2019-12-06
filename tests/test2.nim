
import unittest

import mcmurry/compile

test "Create source file":
    require true

    GenerateParser:
        %toplevel = module
        %node = NIM:
            integer:
                intval: int
        END

        %token = NIM:
            INT:
                intval: int
        END

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
        if_stmt:
            "if" expression ":" suite *("elif" expression ":" suite) ["else" ":" suite]
        while_stmt:
            "while" expression ":" suite
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
            NAME -> ident
            INT -> integer = NIM:
                result.intval = parseInt([0].val)
            END
            "true" -> true
            "false" -> false
            "(" expression ")"
        if_expr:
            "if" expression ":" expression "else" ":" expression

        %nim = NIM:
            import strutils
            var nIndent: seq[int] = @[0]
        END

        "aa" = NIM:
            if str in ["aa"]:
                aiueo
            TOKEN
        END

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