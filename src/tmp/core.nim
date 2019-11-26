
type
    Node* = ref object
        kind*: NodeKind
        value*: string
        children*: seq[Node]
    NodeKind* = enum
        nkVar
        nkIntLit
        nkAdd
        nkMul
    Lexer* =ref object
        program*: string
        i*: int

    Token* = ref object
        kind*: TokenKind
        value*: string
        pos*: (int, int)
        lbp*: int
    TokenKind* = enum
        tkName
        tkIntLit
        tkAdd
        tkMul
        tkEOF

    Parser* = ref object
        lexer*: Lexer
        token*: Token