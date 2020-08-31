
import macros

import sequtils
import strutils
import strformat

import tables
import sets

import ast_pattern_matching
import regex

import private/lr_dfa
import private/visitor


const
    reTokenName = re"[A-Z][A-Z0-9]*"
    reRuleName = re"[a-z_][a-z_0-9]*"
    reElimBlock = re"[ ]*=[ ]*Block:\n"
    reElimAlias = re"[ ]*->[ ]*[a-z_][a-z_0-8]*"
    

proc elimAliasAndBlock(body: NimNode): NimNode =
    if body.kind == nnkInfix and body[0].eqIdent("->"):
        return body[1].elimAliasAndBlock()
    if body.kind == nnkAsgn and body[1].kind == nnkBlockStmt:
        return body[0].elimAliasAndBlock()
    var i = 0
    for e in body:
        body[i] = elimAliasAndBlock(e)
        inc i
    return body

template checkStructure() {.dirty.} =
    body.expectKind(nnkStmtList)

    let
        directives = ["filename", "parsername", "treename", "tokenname", "nodename", "tree", "token", "node", "toplevel", "nim", "ignore"]
        rule_operator = ["*", "+", "?", "|", "->"]
        reduce_str_annon = {
            ":"         : "COLON",
            ";"         : "SEMICORON",
            ","         : "COMMA",
            "("         : "LPAR",
            ")"         : "RPAR",
            "#"         : "SHARP",
            "&"         : "AMPERSAND",
            "?"         : "QUESTION",
            "!"         : "EXCLAMATION"
        }.toTable()

    var
        m: RegexMatch
        nannon = 0

    template checkRuleDef() {.dirty.} =
        let rule = rulename.strVal
        ruleKinds.add rulename
        if rule in rules:
            error fmt"Redefinition of `{rule}`.", rulename
        for e in ast:
            var
                hasAlias = false
                hasBlock = false
            e.matchAstRecursive:
            of `pattern`@nnkStrLit:
                let pat = pattern.strVal
                if pat in reduce_str_annon:
                    let id = ident(reduce_str_annon[pat])
                    if id notin tokenKinds:
                        str_token[pat] = newStmtList(id)
                        tokenKinds.add id
                    else:
                        str_annon.add pattern.strVal.escape()
                else:
                    str_annon.add pattern.strVal.escape()
            of `pattern`@nnkRStrLit:
                rstr_annon.add pattern.strVal.escape()
            of `token`@nnkIdent:
                let tokenname= token.strVal
                if not (tokenname.match(reTokenName, m) or tokenname.match(reRuleName, m)):
                    if tokenname notin rule_operator:
                        error "Invalid syntax.", token
            of nnkInfix(ident"->", _, `alias`@nnkIdent):
                let rule = alias.strVal
                if alias notin ruleKinds:
                    ruleKinds.add alias
                else:
                    warning fmt"Redifinition of {alias}: {alias.lineInfo}", alias
                hasAlias = true
            of nnkPrefix(ident"->", `alias`@nnkIdent):
                let rule = alias.strVal
                if alias notin ruleKinds:
                    ruleKinds.add alias
                else:
                    warning fmt"Redifinition of {alias}: {alias.lineInfo}", alias
                hasAlias = true
            of nnkAsgn(_, `blck`@nnkBlockStmt):
                hasBlock = true
            of nnkInfix("|", _, _):
                discard
            of `invalid`@{nnkCurly, nnkCurlyExpr, nnkBlockExpr, nnkAsgn, nnkInfix, nnkBlockStmt}:
                error "Invalid syntax.", invalid
            let
                ruleright = repr e.elimAliasAndBlock()
                ret = parseRule(ruleright, nannon)
            nannon += ret[2]
            for e in ret[0]:
                if rule notin rules:
                    rules[rule] = newSeq[Rule]()
                rules[rule].add Rule(left: rule, right: e)
            for e in ret[1]:
                if e.left notin rules:
                    rules[e.left] = newSeq[Rule]()
                rules[e.left].add e

    for ast in body:
        ast.matchAst(MatchingErrors):
        # Magic
        of nnkAsgn(nnkPrefix(ident"%", `directive`@nnkIdent), `arg`@{nnkIdent, nnkInfix, nnkBlockStmt}):
            var
                direc = directive.strVal
            if direc notin directives:
                error "Invalid directive.", directive
            case direc
            of "filename":
                onCompileTime = false
            of "parsername":
                arg.expectKind(nnkIdent)
                parsername = arg.strVal
            of "treename":
                arg.expectKind(nnkIdent)
                treename = arg.strVal
            of "tokenname":
                arg.expectKind(nnkIdent)
                tokenname = arg.strVal
            of "nodename":
                arg.expectKind(nnkIdent)
                nodename = arg.strVal
            of "tree", "token", "node":
                # TODO: implement here
                discard
            of "toplevel":
                if arg.kind != nnkIdent:
                    error "here is to be written rulename like `%toplevel = <rulename>`", toplevel
                toplevel = arg
            of "nim":
                arg.expectKind(nnkBlockStmt)
                nimsec = arg[1]
            of "ignore":
                arg.matchAstRecursive:
                of `tokenname`@nnkIdent:
                    let token = tokenname.strVal
                    if token == "/":
                        break
                    if tokenname.kind notin {nnkIdent, nnkInfix} or not token.match(reTokenName, m):
                        error "here is to be written tokenname like `%ignore = <TOKEN1> / <TOKEN2>`", tokenname
        # Definition of tokens or rules
        # Rule with `?`
        of nnkPrefix("?", `rulename`@nnkIdent, `ast`@nnkStmtList):
            checkRuleDef()
            priorities[rule] = 0
            removable.add rule
        # Rule with priority
        of nnkCall(`rulename`@nnkIdent, `n`@nnkIntLit, `ast`@nnkStmtList):
            checkRuleDef()
            priorities[rule] = cast[int](n.intVal)
        # Rule with `?` and priority
        of nnkPrefix("?", nnkCall(`rulename`@nnkIdent, `n`@nnkIntLit), `ast`@nnkStmtList):
            checkRuleDef()
            priorities[rule] = cast[int](n.intVal)
            removable.add rule
        # Rule
        of nnkCall(`rulename`@nnkIdent, `ast`@nnkStmtList):
            checkRuleDef()
            priorities[rule] = 0
            # Token
        of nnkCall(`pattern`@{nnkStrLit, nnkRStrLit}, `ast`@nnkStmtList):
            ast.matchAstRecursive:
            of `tokenname`@nnkIdent:
                let token = tokenname.strVal
                if token.match(reTokenName, m):
                    if tokenname notin tokenKinds:
                        tokenKinds.add tokenname
            if not ast.compiles():
                error "This code is invalid.", ast
            case pattern.kind
            of nnkStrLit:
                str_token[pattern.strVal.escape()] = ast
            of nnkRStrLit:
                rstr_token[pattern.strVal.escape()] = ast
            else:
                error "Unreachable", pattern
        else:
            error "Allowed only `magic` or definition of `rule` or `token`.", ast

    if toplevel.isNil:
        error "You should specify toplevel through `%toplevele = <rulename>`.", body
    if toplevel.strVal notin rules:
        error "here is  to be written rulename exists.", toplevel

    if @[] in map(rules[toplevel.strVal], proc(e:auto):seq[string]=e.right):
        error "toplevel mustn't allow empty pattern.", toplevel

    for key, val in mpairs(rules):
        var
            del_stack: seq[int]
        for i, e in val:
            if e.right == @[key]:
                del_stack.add i
        for i, e in del_stack:
            val.delete(e-i)
        # TODO: if the pattern allow empty, rule which include the pattern must change.
        

template typedef() {.dirty.} =
    # TreeKind = enum
    result.add newEnum(
        treekind,
        treekinds,
        true, true
    )

    # TokenKind = enum
    result.add newEnum(
        tokenkind,
        tokenKinds,
        true, true
    )

    # NodeKind = enum
    result.add newEnum(
        nodekind,
        ruleKinds,
        true, true
    )

    # Parser = ref object
    result.add quote do:
        type
            `parser` = ref object
                input: string
                inputlen: int
                i: int
                pos: (int, int)

template generate() {.dirty.} =
    result.add imprtsec
    result.add nimsec
    result.add newCall("echo", newLit("OK"))

macro Mcmurry*(body: untyped): untyped =
    ##[
        Generating parser/lexer.
        ------------------------
        This parser generator generates parser and lexer at the same time.
        it accepts LR(1) grammar and supports ebnf (actually not all of).

        **Mcmurry**

        This macro generates code or file woking as parser/lexer.

        Args:

            * ``parsername``: untyped
                Indicates the name of the generated type of parser.
            * ``onCompileTime``: static[bool]
                Indicates whether to compute at compile-time.
                if it is ``false``, the file will be made.

        Returns:

            NimNode (code) or nothing (file).
    ]##
    
    result = newStmtList()

    # Only at compile time
    var
        onCompileTime: bool

        treekinds: seq[NimNode]
        tokenKinds: seq[NimNode]
        ruleKinds: seq[NimNode]

    var
        filename: string
        parsername = "Parser"
        treename = "Tree"
        tokenname = "Token"
        nodename = "Node"

        toplevel: NimNode = nil

        str_token: Table[string, NimNode]
        rstr_token: Table[string, NimNode]
        str_annon: seq[string]
        rstr_annon: seq[string]

        ignores: seq[NimNode]
        
        rules: Table[string, seq[Rule]]
        priorities: Table[string, int]
        removable: seq[string]
        reduce_callback: Table[(string, int), NimNode]

        nimsec: NimNode = nil

    # check whether structure of `body` is valid.
    checkStructure()

    var
        parser = ident(parsername)
        tree = ident(treename)
        token = ident(tokenname)
        node = ident(nodename)
        treekind = ident(treename & "kind")
        tokenkind = ident(tokenname & "kind")
        nodekind = ident(nodename & "kind")

        imprtsec = nnkImportStmt.newTree(
            ident"re"
        )
    treekinds.add token
    treekinds.add node

    # generate types
    typedef()

    # generate code
    if onCompileTime:
        generate()

    echo treeRepr body
    echo repr body

    for e in rules.values:
        echo e


when isMainModule:
    Mcmurry:
        %parsername = Parser
        %filename = parserf

        %toplevel = arglist

        a: b
        b: c | b
        c:
            b -> q
            c -> w
            d -> e = block:
                discard
            e = block:
                discard
        ?arglist:
            argument *("," argument) -> abc
        argument(1):
            [ident "="] expr
        ?subscriptlist(2):
            subscript *("," subscript) -> def = block:
                discard
        subscript:
            expr
            [expr] ":" [expr] [sliceop]
        sliceop:
            ":" [expr]
    
        r"\n[ ]*":
            if len-1 > nIndent[^1]:
                nIndent.add len-1
                kind_stack.add INDENT
                LF
            elif len-1 < nIndent[^1]:
                while len-1 != nIndent[^1]:
                    discard nIndent.pop()
                    kind_stack.add DEDENT
                    if nIndent.len == 0:
                        raise newException(SyntaxError, "Invalid indent.")
                discard kind_stack.pop()
                kind_stack.add DEDENT
                LF
            else:
                LF
    
        r"\s+": SPACE
        %ignore = SPACE / COMMENT
    
