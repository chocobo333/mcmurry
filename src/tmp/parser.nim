
import core
import lexer

proc parseExpression(self: Parser, rbp: int = 0): Node

proc newNode(kind: NodeKind, value: string): Node =
    Node(kind: kind, value: value)

iterator items(self: Node): Node =
    for ch in self.children:
        yield ch

proc add(self: Node, other: Node): Node =
    self.children.add(other)
    return self

proc left(self: Node): Node =
    self.children[0]

proc right(self: Node): Node =
    self.children[^1]

from strutils import `%`, repeat
proc `$`(self: Node, indent: int=1): string =
    result = "[$1: $2" % [$self.kind, self.value]
    for ch in self.children:
        result &= "\n" & ' '.repeat(indent * 4) & `$`(ch, indent+1)
    result &= "]"


proc next(self: Parser) =
    self.token = self.lexer.next()

proc nud(self: Token): Node =
    case self.kind
    of tkName:
        result = nkVar.newNode(self.value)
    of tkIntLit:
        result = nkIntLit.newNode(self.value)
    of tkAdd:
        result = nkAdd.newNode(self.value)
    of tkMul:
        result = nkMul.newNode(self.value)
    of tkEOF:
        discard
    # else: discard

proc led(self: Token, left: Node, parser: Parser): Node =
    var
        right: Node
    case self.kind
    of tkName:
        discard
    of tkIntLit:
        discard
    of tkAdd:
        right = parser.parseExpression(tkAdd.lbp)
        result = nkAdd.newNode(self.value).add(left).add(right)
    of tkMul:
        right = parser.parseExpression(tkAdd.lbp)
        result = nkAdd.newNode(self.value).add(left).add(right)
    of tkEOF:
        discard
    # else: discard

proc parse*(self: Parser, programm: string): Node =
    self.lexer = newLexer(programm)
    self.next()
    self.parseExpression()

proc parseExpression(self: Parser, rbp: int = 0): Node =
    var
        tk: Token
        left: Node
    tk = self.token
    self.next()
    left = tk.nud()
    while rbp < self.token.lbp:
        tk = self.token
        self.next()
        left = tk.led(left, self)
    return left

when isMainModule:
    var
        parser = Parser()
    while true:
        var
            programm = stdin.readLine()
        if programm == "":
            break
        echo parser.parse(programm)
