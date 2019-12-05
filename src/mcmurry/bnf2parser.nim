
import macros
import tables
from strutils import `%`, repeat, center, escape
import private/utils
from bitops import bitand

import re

import stack


type
    Term = string
    Item = object
        left: Term
        right: seq[Term]
        index: int
        la : seq[Term]
    ItemSet = seq[Item]
    DFA = object
        nodes: seq[ItemSet]
        edges: seq[(int, int, Term)]

    TokenBase[TK: enum] = ref object
        kind*: TK
        value*: string
        pos*: (int, int)
    LexerBase[TK: enum] = ref object
        i: int
        program: string
    LRopenum {.pure.} = enum
        SHIFT
        REDUCE
        GOTO
        ACC
    LRop = object
        op: LRopenum
        val: int
    LRTable = seq[Table[Term, LRop]]
    Rule[NK: enum] = tuple[kind: NK, right: seq[bool]]
    NodeBase*[NK: enum, T: TokenBase] = ref object
        kind*: NK
        children*: seq[NodeBase[NK, T]]
        tokens*: seq[T]
    ParserBase*[NK: enum, L: LexerBase, T: TokenBase] = ref object
        table*: LRTable
        stack*: Stack[int]
        rules*: seq[Rule[NK]]

    SyntaxError = object of Exception

const
    dbDfa = 1
    dbTable =  2
    dbCode = 4
    DebugFlags {.intdefine.} = 0

proc contains(a, b: int): bool =
    bitand(a, b) != 0

proc `$`*[NK, T](self: NodeBase[NK, T], indent=0): string =
    result = "$1" % [$self.kind] & $self.tokens
    for ch in self.children:
        result &= "\n" & ' '.repeat(indent * 4) & "└---" & `$`(ch, indent+1)

proc `$`(self: Item): string =
    result = self.left & ": "
    for i, e in self.right:
        if i == self.index:
            result &= "* "
        result &= e & ' '
    if self.index == self.right.len:
        result &= "* "
    result &= "[ "
    for e in self.la:
        result &= e & ' '
    # result = result[0..^1]
    result &= ']'

proc `$`(self: ItemSet): string =
    for e in self:
        result &= $e & '\n'

proc `$`(self: DFA): string =
    for i, e in self.nodes:
        var
            inn: seq[int]
            ou: seq[int]
            key: Term
        for e in self.edges:
            if e[1] == i:
                inn.add e[0]
                key = e[2]
            if e[0] == i:
                ou.add e[1]
            
        result &= "($3)[$2] -> $1 -> ($4)\n" % @[$i, key, ($inn)[2..^2], ($ou)[2..^2]]
        result &= $e & '\n'

proc `$`*(self: LRop): string =
    if self.op == ACC:
        return "ACC"
    result = ($self.op)[0..0] & $self.val

proc `$`*(self: LRTable): string =
    var
        tmp: seq[Term]
        l: int
        s: string
    result = "   |"
    for node in self:
        for key in node.keys:
            if key notin tmp:
                tmp.add key
                result &= "$1|" % @[center(key, 4, ' ')]
    result &= '\n'
    for i, node in self:
        result &= "$1|" % @[center($i, 3, ' ')]
        for key in tmp:
            l = max(key.len, 4)
            s = if key in node: $node[key] else: ""
            result &= "$1|" % @[center(s, l, ' ')]
        result &= '\n'

proc toNimNode(self: LRTable): NimNode =
    var
        tmpsec = nnkBracket.newNimNode()
        tmptable: NimNode
    for e in self:
        tmptable = nnkTableConstr.newNimNode()
        for key in e.keys:
            tmptable.add newColonExpr(newLit(key), newLit(e[key]))
        tmpsec.add newCall(bindSym"toTable", tmptable)
    result = prefix(tmpsec, "@")

proc concat[T](self: var seq[T], other: seq[T]) =
    for e in other:
        if e notin self:
            self.add e

proc concat(self: var ItemSet, other: Item) =
    var
        i = -1
    for j, e in self:
        if e.left == other.left and e.right == other.right and e.index == other.index:
            i = j
            break
    if i != -1:
        self[i].la.concat(other.la)
        return
    self.add other


proc raiseSyntaxError(program: string, pos: int, msg: string = "") =
    var
        str: string = "\n"
        n: int = min(pos, 5)
    for i, c in program[max(pos-5, 0)..pos]:
        if c == '\n':
            n = min(pos, 5)-i-1
    str &= "$1\n$2^\n" % @[program[max(pos-5, 0)..min(pos+5, program.len-1)], ' '.repeat(n)]
    raise newException(SyntaxError, str & msg)

proc table*(self: ParserBase): LRTable = self.table

proc parse*[NK, L, T](self: ParserBase[NK, L, T], src: string): NodeBase[NK, T] =
    var
        lexer = L()
        op: LRop
        tkstack: Stack[T]
        retstack: Stack[NodeBase[NK, T]]
    self.stack.push 0
    # echo self.table
    for tk in lexer.lex(src):
        while true:
            op = self.table[self.stack.top][$tk.kind]
            # echo op
            # echo tk.kind
            # echo self.stack
            case op.op
            of LRopenum.SHIFT:
                self.stack.push op.val
                break
            of LRopenum.REDUCE:
                result = NodeBase[NK, T]()
                for e in self.rules[op.val].right:
                    self.stack.pop()
                    if e:
                        result.tokens.insert tkstack.pop(), 0
                    else:
                        result.children.insert retstack.pop(), 0
                result.kind = self.rules[op.val].kind
                retstack.push result
                op = self.table[self.stack.top][$self.rules[op.val].kind]
                doAssert op.op == LRopenum.GOTO
                self.stack.push op.val
            of LRopenum.GOTO:
                self.stack.push op.val
            of LRopenum.ACC:
                break
        tkstack.push tk

proc simplify_r(self: var NodeBase): NodeBase {.discardable.} =
    for i, e in self.children:
        self.children[i].simplify_r
    if self.children.len == 1 and self.tokens.len == 0:
        self = self.children[0]
    return self

proc simplify*(self: NodeBase): NodeBase {.discardable.} =
    self.children[0].simplify_r
    return self

template nodetype*[NK, L, T](self: ParserBase[NK, L, T]): untyped = NodeBase[NK, T]


proc newToken [TK: enum](kind: TK, value: string = "", pos: (int, int) = (0, 0)): TokenBase[TK] =
    TokenBase[TK](kind: kind, value: value, pos: pos)

proc maxlen(t: typedesc[enum]): int {.compiletime.} =
    for i in 0..<int(t.high):
        if result < len($t(i)):
            result = len($t(i))

proc `$`*[NK: enum](self: TokenBase[NK]): string =
    const l = maxlen(NK)
    "[$1: $2]" % [center(($self.kind), l, ' '), self.value.escape]

proc next [TK: enum](self: LexerBase[TK]): TokenBase[TK] = discard

iterator lex [TK: enum](self: LexerBase[TK]): TokenBase[TK] = discard

proc findUpperIdent(n: NimNode): seq[NimNode] =
    for e in n:
        if e.kind == nnkIdent:
            if ($e).isUpper(true):
                result.add(e)
        result.add(findUpperIdent(e))

proc findChildren(n: NimNode, kind: NimNodeKind): seq[NimNode] =
    if n.kind == kind:
        result.add n
    for e in n:
        # if e.kind == kind:
        #     result.add(e)
        result.add(findChildren(e, kind))

proc nextnlex(parserid: NimNode, grammer: Nimnode, tokendef: seq[(NimNode, NimNode)], directives: Table[string, seq[NimNode]]): (NimNode, NimNode) =
    var
        tid = ident("Token" & $parserid)
        lid = ident("Lexer" & $parserid)
        nt = bindSym"newToken"
        next = newProc(ident"next")
        lex: NimNode
    proc self(param: string): NimNode =
        newDotExpr(ident"self", ident(param))
    proc matchlen(regex: NimNode): NimNode =
        result = nnkCall.newTree(
            bindSym"matchLen",
            self("program"),
            regex,
            nnkExprEqExpr.newTree(
                ident"start",
                self("i")
            )
        )
    next.params = nnkFormalParams.newTree(
        tid,
        newIdentDefs(ident"self", lid)
    )
    lex = nnkIteratorDef.newTree(
        ident"lex",
        newEmptyNode(), newEmptyNode(),
        nnkFormalParams.newTree(tid, newIdentDefs(ident"self", lid), newIdentDefs(ident"program", ident"string", newLit(""))),
        newEmptyNode(), newEmptyNode(),
        parseStmt("""
self.i = 0
if program != "":
    self.program = program
var ret: $1
while true:
    ret = self.next()
    yield ret
    if ret.kind == $2:
        break""" % @[$tid, "EOF" & $parserid])
    )

    for e in directives["ignore"]:
        if e.kind == nnkRStrLit:
            discard

    next.body.add nnkIfStmt.newNimNode()
    next.body[0].add nnkElse.newTree(
        parseExpr("self.i >= self.program.len"),
        newStmtList(
            nnkReturnStmt.newTree(newCall(nt, ident("EOF" & $parserid), newLit("")))
        )
    )
    for (reg, token) in tokendef:
        next.body[0].add nnkElifBranch.newTree(
            infix(matchlen(reg), "!=", prefix(newLit(1), "-")),
            newStmtList(
                nnkVarSection.newTree( # var
                    nnkIdentDefs.newTree(
                        ident"len",
                        newEmptyNode(),
                        matchlen(reg)
                    ),
                    nnkIdentDefs.newTree(
                        ident"kind",
                        newEmptyNode(),
                        token
                    )
                ),
                nnkAsgn.newTree(
                    ident"result",
                    newCall(nt, ident"kind", parseExpr("self.program[self.i..self.i+len-1]")
                    )
                ),
                infix(self("i"), "+=", ident"len")
            )
        )
    next.body[0].add nnkElse.newTree(
        newStmtList(
            newCall(bindSym("raiseSyntaxError"), self("program"), self("i"), newLit("Unexpected character."))
        )
    )
    for e in directives["ignore"]:
        if e.kind == nnkIdent:
            next.body.add nnkIfStmt.newTree(
                nnkElifBranch.newTree(
                    infix(newDotExpr(ident"result", ident"kind"), "==", e),
                    parseStmt("return self.next()")
                )
            )

    
    result = (next, lex)

proc parseToken(grammer: NimNode, parserid: NimNode): seq[NimNode] =
    var
        tkid = ident("TokenKind" & $parserid)
        tid = ident("Token" & $parserid)
        lid = ident("Lexer" & $parserid)
        tokens = @[newEmptyNode()]
        tokendef: seq[(NimNode, NimNode)]
        directives: Table[string, seq[NimNode]]
        letsec = nnkLetSection.newNimNode()
        varsec = nnkVarSection.newNimNode()
        typsec = nnkTypeSection.newNimNode()
    for i, e in pairs(grammer):
        if e.kind == nnkCall and e[0].kind == nnkRStrLit:
            tokens.add findUpperIdent(e[1])
            letsec.add nnkIdentDefs.newTree(
                ident("re" & $parserid & $i),
                newEmptyNode(),
                nnkCallStrLit.newTree(
                    bindSym"re",
                    e[0]
                )
            )
            tokendef.add (ident("re" & $parserid & $i), e[1][0])
        elif e.kind == nnkVarSection:
            for identdef in e:
                if isUpper($(identdef[0]), true):
                    warning "Upper case string is recognized as terminator. Use lower case characters instead.", identdef[0]
                varsec.add identdef
        elif e.kind == nnkPrefix:
            for dire in e[2]:
                if $e[1] notin directives:
                    directives[$e[1]] = newSeq[NimNode]()
                directives[$e[1]].add dire
    tokens.add ident("EOF" & $parserid)
    typsec.add nnkTypeDef.newTree(
        postfix(tkid, "*"),
        newEmptyNode(),
        nnkEnumTy.newTree(
            tokens
        )
    )
    typsec.add nnkTypeDef.newTree(
        postfix(tid, "*"),
        newEmptyNode(),
        nnkBracketExpr.newTree(
            bindSym"TokenBase",
            tkid
        )
    )
    typsec.add nnkTypeDef.newTree(
        postfix(lid, "*"),
        newEmptyNode(),
        nnkBracketExpr.newTree(
            bindSym"LexerBase",
            tkid
        )
    )
    var
        (next, lex) = nextnlex(parserid, grammer, tokendef, directives)
    result = @[letsec, varsec, typsec, next, lex]


proc parseRule(grammer: NimNode, toplevel: NimNode, id: NimNode): seq[NimNode] =
    var
        parserid = id
        rules: ItemSet
        tokens: seq[NimNode]
        top: Term = "_top"
        fin: Term = "EOF" & $parserid
        typsec = nnkTypeSection.newNimNode()
        varsec = nnkVarSection.newNimNode()
        tid = ident("Token" & $parserid)
        lid = ident("Lexer" & $parserid)
        pid = ident("Parser" & $parserid)
        nid = ident("Node" & $parserid)
        rid = ident("rule" & $parserid)
        nkid = ident("NodeKind" & $parserid)
        nks = @[newEmptyNode()]
        ruleseq = nnkBracket.newNimNode()
    rules.add Item(left: top, right: @[$toplevel], la: @[fin])
    for e in grammer:
        if e.kind == nnkCall:
            if e[0].kind == nnkIdent:
                expectKind(e[1], nnkStmtList)
                nks.add e[0]
                for a in e[1]:
                    var
                        item: Item
                        r = a.findChildren(nnkIdent)
                    item.left = $e[0]
                    for b in r:
                        item.right.add $b
                    rules.add item
            elif e[0].kind == nnkRStrLit:
                tokens.add findUpperIdent(e[1])

    var
        missing: seq[Term]
    # Confirms rules
    for rule in rules:
        for rig in rule.right:
            block b:
                for innerrule in rules:
                    if innerrule.left == rig:
                        break b
                for token in tokens:
                    if $token == rig:
                        break b
                missing.add rig
    for e in missing:
        for a in grammer.findChildren(nnkIdent):
            if $a == e:
                error "$1 is not defined, but used." % @[e], a

    # Closure Expansion
    var
        lritemset: DFA

    proc first(self: varargs[Term]): seq[Term] =
        var
            rett {.global.} : Table[Term, seq[Term]]
            e = self[0]
        if e.isUpper(true):
            return @[e]
        elif e == "$":
            return @["$"]
        else:
            if e in rett:
                return rett[e]
            else:
                rett[e] = @[]
                for rule in rules:
                    if rule.left == e:
                        # if rule.right[0] == e:
                        #     continue
                        for f in first(rule.right):
                            if f notin rett[e]:
                                rett[e].add f
                return rett[e]

    proc next(self: Item): ItemSet =
        var
            tmp: Item
        if self.index == self.right.len:
            return
        if self.right[self.index].isUpper(true):
            return @[]
        else:
            var
                term = self.right[self.index]
            for rule in rules:
                if rule.left == term:
                    tmp = rule
                    if self.right[self.index+1..^1] == @[]:
                        tmp.la.add self.la
                    else:
                        tmp.la.add first(self.right[self.index+1..^1])
                    # tmp.la.add first(self.right[self.index+1..^1] & self.la)
                    result.add tmp

    proc compression(self: var ItemSet) =
        var
            tmpitem: Item
            tmp: ItemSet
        # for e in self:
        #     tmp.concat(e)
        for e in self:
            if e notin tmp:
                tmp.add e
        self = tmp
    
    proc expansion(self: var ItemSet, i=0) =
        if i == self.len:
            return
        self.add self[i].next()
        self.compression()
        self.expansion(i+1)
    
    proc next(self: var DFA, i: int) =
        var
            l = self.nodes.len
            tmpt: Table[string, ItemSet]
            tmp: ItemSet
            tmpitem: Item
            key: Term
            j = -1
        for item in self.nodes[i]:
            tmpitem = item
            if tmpitem.index == tmpitem.right.len:
                continue
            key = tmpitem.right[tmpitem.index]
            tmpitem.index += 1
            if key notin tmpt:
                tmpt[key] = @[]
            tmpt[key].add tmpitem
        for key in tmpt.keys:
            l = self.nodes.len
            j = -1
            tmp = tmpt[key]
            tmp.expansion()
            for k, node in self.nodes:
                if tmp == node:
                    j = k
                    break
            if j != -1:
                self.edges.add (i, j, key)
                continue
            self.nodes.add tmp
            self.edges.add (i, l, key)

    proc compression(self: var DFA) =
        discard
    
    proc expansion(self: var DFA, i=0) =
        if i == self.nodes.len:
            return
        self.next(i)
        self.compression()
        self.expansion(i+1)

    discard first($toplevel)

    lritemset.nodes.add @[rules[0]]
    lritemset.nodes[0].expansion()

    lritemset.expansion()

    # Makes parser object
    # Makes LRTable
    var
        lrtable: LRTable = newSeq[Table[Term, LRop]](lritemset.nodes.len)
        key: Term
        op: LRop
    for edge in lritemset.edges:
        key = edge[2]
        op = LRop(op: if key.isUpper(true): LRopenum.SHIFT else: LRopenum.GOTO, val: edge[1])
        lrtable[edge[0]][key] = op
    for nn, node in lritemset.nodes:
        for item in node:
            if item.right.len == item.index:
                if item.left == top:
                    lrtable[nn][fin] = LRop(op: ACC)
                    continue
                for nr, rule in rules:
                    if rule.left == item.left and rule.right == item.right:
                        for key in item.la:
                            # if there is shift/reduce conflict, raise error
                            if key in lrtable[nn]:
                                for a in grammer.findChildren(nnkIdent):
                                    if $a == item.left:
                                        error "not lr(1)", a
                                # echo lrtable[nn][key]
                                # echo LRop(op: LRopenum.REDUCE, val: nr)
                            lrtable[nn][key] = LRop(op: LRopenum.REDUCE, val: nr-1)

    # Define parser
    typsec.add nnkTypeDef.newTree(
        postfix(nkid, "*"),
        newEmptyNode(),
        nnkEnumTy.newTree(
            nks
        )
    )
    typsec.add nnkTypeDef.newTree(
        postfix(pid, "*"),
        newEmptyNode(),
        nnkBracketExpr.newTree(
            bindSym"ParserBase",
            nkid,
            lid,
            tid
        )
    )

    for i, rule in rules[1..^1]:
        ruleseq.add nnkPar.newTree(
            ident(rule.left),
            nnkPrefix.newTree(
                ident"@",
                nnkBracket.newNimNode()
            )
        )
        for r in rule.right:
            ruleseq[i][1][1].add newLit(r.isUpper(true))
    varsec.add nnkIdentDefs.newTree(
        postfix(id, "*"),
        pid,
        nnkObjConstr.newTree(
            pid,
            newColonExpr(ident"rules", prefix(ruleseq, "@")),
            newColonExpr(ident"table", lrtable.toNimNode())
        )
    )

    result.add typsec
    result.add varsec

    # echo rules
    if dbDfa in DebugFlags:
        echo lritemset
    # echo first($toplevel)
    if dbTable in DebugFlags:
        echo lrtable

macro MakeParser*(id: untyped, toplevel: untyped, grammer: untyped): untyped =
    for e in grammer:
        case e.kind
        of nnkCall, nnkVarSection:
            discard
        of nnkPrefix:
            if $e[0] != "%":
                error "Directivs are started from '%'.", e[0]
            let
                directives = @["ignore"]
            if $e[1] notin directives:
                error "% directives are allowed only " & $directives, e[1]
        of nnkCommand:
            e.expectKind(nnkCall)
        else:
            error "Wrong syntax.", e
    result = newStmtList()
    result.add parseToken(grammer, id)
    result.add parseRule(grammer, toplevel, id)
    
    # echo treeRepr(grammer)
    if dbCode in DebugFlags:
        echo repr(result)

let rean = re"a[0-9]+"

proc remove_annon(self: var NodeBase): NodeBase {.discardable.} =
    var
        tmpch: type(self.children)
        tmptk: type(self.tokens)
    for e in mitems(self.children):
        remove_annon(e)
    for e in self.children:
        if match($e.kind, rean):
            tmpch.add e.children
            tmptk.add e.tokens
            # echo "e.tokens\n", e.tokens
        else:
            tmpch.add e
    if tmpch.len != 0:
        self.children = tmpch
    if tmptk.len != 0:
        self.tokens.add tmptk
    return self
    

when isMainModule:
    MakeParser(id=parser, toplevel=expression):
        expression: arith_expr 
        annon0:
            OP1 term
            annon0 OP1 term 
        arith_expr:
            term annon0
            term 
        annon1:
            OP2 atom_expr
            annon1 OP2 atom_expr 
        term:
            atom_expr annon1
            atom_expr 
        annon2:
            trailer
            annon2 trailer 
        atom_expr:
            atom annon2
            atom
        trailer:
            PL expression PR
            PL PR
        atom:
            NAME
            INT
        r"[a-zA-Z_][a-zA-z_0-9]*": NAME
        r"[1-9][0-9]*": INT
        r"("").*("")": STRING
        r"\(": PL
        r"\)": PR
        r"[\+\-]": OP1
        r"[\*/]": OP2
        var nIndent = 0
        r"\n?\s*#[^\n]*": COMMENT
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
            r"\s"
            SPACE
            COMMENT
    var
        ast = parser.parse(r"3 + 2 * 4 + 9")
    echo ast
    # echo ast.simplify
    echo ast.remove_annon

when false:
    addexpr:
        term
        a0 term
    term:
        atomexpr
        atomexpr a1
    a0:
        term OP1
        a0 term OP1
    a1:
        OP2 atomexpr
        a1 OP2 atomexpr
    atomexpr:
        atom
        atom a2
    trailer:
        PL atom PR
    a2:
        trailer
        a2 trailer
    atom:
        INT
        NAME
        STRING

when false:
    addexpr:
        atom
        a0 atom
    a0:
        atom OP1
        a0 atom OP1
    atom:
        INT
        NAME
        STRING
when false:
    expression:
        addexpr
    addexpr:
        mulexpr
        addexpr OP1 mulexpr
    mulexpr:
        unaryexpr
        mulexpr OP2 unaryexpr
    unaryexpr:
        atom
        OP1 unaryexpr
    atom:
        INT
        NAME
        STRING