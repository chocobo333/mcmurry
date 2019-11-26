import bnf2parser


MakeParser(id=parser, toplevel=a):
    a:
        e AS e
        NAME
    e:
        e OP1 t
        t
    t:
        INT
        NAME
    r"=": AS
    r"[a-zA-Z_][a-zA-z_0-9]*": NAME
    r"[1-9][0-9]*": INT
    r"[\+\-]": OP1
    r"[\*/]": OP2
    var nIndent = 0
    r"#[^\n]*": COMMENT
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
var
    lexer = Lexer1()
for tk in lexer.lex("3 + 3 * 2\n  a - 3 / b\n  3+2*1*1#nothing\nend"):
    echo tk

discard parser.parse("3+3")

# type
#     A[T: int] = object
#     B = A[0]

# proc `$`[T: int](self: A[T]): string = $T
# proc `$`(self: B): string = "B"

# var
#     x = A[1]()
#     y = B()
#     z = A[0]()