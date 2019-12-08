
import os

import
    strutils,
    sequtils,
    algorithm
    
import
    sets,
    tables

import macros
import ast_pattern_matching

import regex

import private/utils
import private/parserdef

# export parserdef

var parser = Parser()

const license = staticRead("."/".."/".."/".."/"LICENSE")


template log(variable: untyped): untyped =
    stderr.write astToStr(variable) & ":\n" & ($variable).indent(4) & "\n"


# module@[]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="]]
#     └---directive@[[ ANNON5  : "filename"]]
#     └---name@[[RULENAME : "parser"]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="]]
#     └---directive@[[ ANNON4  : "toplevel"]]
#     └---name@[[RULENAME : "module"]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  integer:\x0A    intval:\x0A      int\x0AEND"]]
#     └---directive@[[ ANNON2  : "node"]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  INT:\x0A    intval:\x0A      int\x0AEND"]]
#     └---directive@[[ ANNON3  : "token"]]
# └---statement@[[   LF    : "\x0A"]]
# └---ruledef@[[RULENAME : "module"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---repeat_expr@[[ ANNON12 : "+"]]
#         └---name@[[RULENAME : "statement"]]
# └---ruledef@[[RULENAME : "statement"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_stmt"]]
#     └---name@[[RULENAME : "compound_stmt"]]
#     └---name@[[TOKENNAME: "LF"]]
# └---ruledef@[[RULENAME : "simple_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "small_stmt"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---pattern@[[   STR   : "\";\""]]
#                 └---name@[[RULENAME : "small_stmt"]]
# └---ruledef@[[RULENAME : "small_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "pass_stmt"]]
#     └---name@[[RULENAME : "expr_stmt"]]
# └---ruledef@[[RULENAME : "compound_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "if_stmt"]]
#     └---name@[[RULENAME : "while_stmt"]]
# └---ruledef@[[RULENAME : "if_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"if\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "suite"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---pattern@[[   STR   : "\"elif\""]]
#                 └---name@[[RULENAME : "expression"]]
#                 └---pattern@[[   STR   : "\":\""]]
#                 └---name@[[RULENAME : "suite"]]
#         └---expression@[[ ANNON15 : "["], [ ANNON14 : "]"]]
#             └---pattern@[[   STR   : "\"else\""]]
#             └---pattern@[[   STR   : "\":\""]]
#             └---name@[[RULENAME : "suite"]]
# └---ruledef@[[RULENAME : "while_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"while\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "suite"]]
# └---ruledef@[[RULENAME : "suite"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_stmt"]]
#     └---ruleright@[]
#         └---name@[[TOKENNAME: "INDENT"]]
#         └---repeat_expr@[[ ANNON12 : "+"]]
#             └---name@[[RULENAME : "statement"]]
#         └---name@[[TOKENNAME: "DEDENT"]]
# └---ruledef@[[RULENAME : "pass_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---pattern@[[   STR   : "\"pass\""]]
# └---ruledef@[[RULENAME : "expr_stmt"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_expr"]]
# └---ruledef@[[RULENAME : "expression"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "simple_expr"]]
#     └---name@[[RULENAME : "if_expr"]]
# └---ruledef@[[RULENAME : "simple_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---name@[[RULENAME : "arrow_expr"]]
# └---ruledef@[[RULENAME : "arrow_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "assign_expr"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---name@[[TOKENNAME: "OP0"]]
#                 └---name@[[RULENAME : "assign_expr"]]
# └---ruledef@[[RULENAME : "assign_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "plus_expr"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---name@[[TOKENNAME: "OP1"]]
#                 └---name@[[RULENAME : "plus_expr"]]
# └---ruledef@[[RULENAME : "plus_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---name@[[RULENAME : "atom"]]
#         └---repeat_expr@[[ ANNON11 : "*"]]
#             └---atom_expr@[[ ANNON10 : "("], [ ANNON9  : ")"]]
#                 └---name@[[TOKENNAME: "OP8"]]
#                 └---name@[[RULENAME : "atom"]]
# └---ruledef@[[RULENAME : "atom"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [   LF    : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "ident"]]
#         └---name@[[TOKENNAME: "NAME"]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "integer"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A    result.intval = parseInt([0].val)\x0A  END"]]
#         └---name@[[TOKENNAME: "INT"]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "true"]]
#         └---pattern@[[   STR   : "\"true\""]]
#     └---ruleright@[[ ANNON16 : "->"], [RULENAME : "false"]]
#         └---pattern@[[   STR   : "\"false\""]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"(\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\")\""]]
# └---ruledef@[[RULENAME : "if_expr"], [ ANNON17 : ":"], [ INDENT  : "\x0A  "], [ DEDENT  : "\x0A"]]
#     └---ruleright@[]
#         └---pattern@[[   STR   : "\"if\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "expression"]]
#         └---pattern@[[   STR   : "\"else\""]]
#         └---pattern@[[   STR   : "\":\""]]
#         └---name@[[RULENAME : "expression"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  import\x0A    strutils\x0A\x0A  var nIndent: seq[int] = @[0]\x0AEND"]]
#     └---directive@[[ ANNON0  : "nim"]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  if str in [\"aa\"]:\x0A    aiueo\x0A  TOKEN\x0AEND"], [   LF    : "\x0A"]]
#     └---pattern@[[   STR   : "\"aa\""]]
# └---tokendef@[[ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  if str in [\"+\", \"-\"]:\x0A    OP8\x0A  elif str in [\"==\", \"<=\", \">=\", \"<\", \">\"]:\x0A    OP5\x0A  elif str.endsWith(\"=\"):\x0A    OP1\x0A  elif str == \"=>\" or str == \"->\":\x0A    OP0\x0A  else:\x0A    OP10\x0AEND"], [   LF    : "\x0A"]]
#     └---pattern@[[  RSTR   : "r\"[\\+\\-\\*\\/\\^\\=\\~\\>]+\""]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "NAME"]]
#     └---pattern@[[  RSTR   : "r\"[a-zA-Z_][a-zA-z_0-9]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "INT"]]
#     └---pattern@[[  RSTR   : "r\"[1-9][0-9]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "STRING"]]
#     └---pattern@[[  RSTR   : "r\"(\"\")[^\"\"\\\\]*(\\\\.[^\"\"\\\\]*)*(\"\")\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "DOCSTR"]]
#     └---pattern@[[  RSTR   : "r\"\\n?\\s*##[^\\n]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "COMMENT"]]
#     └---pattern@[[  RSTR   : "r\"\\n?\\s*#[^\\n]*\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---tokendef@[[ ANNON6  : "="], [ NIMCODE : "NIM:\x0A  if len - 1 > nIndent[^1]:\x0A    nIndent.add len - 1\x0A    INDENT\x0A  elif len - 1 < nIndent[^1]:\x0A    while len - 1 != nIndent[^1]:\x0A      discard nIndent.pop()\x0A      kind_stack.add DEDENT\x0A      if nIndent.len == 0:\x0A        raise newException(SyntaxError, \"Invalid indent.\")\x0A    discard kind_stack.pop()\x0A    DEDENT\x0A  else:\x0A    LF\x0AEND"], [   LF    : "\x0A"]]
#     └---pattern@[[  RSTR   : "r\"\\n[ ]*\""]]
# └---tokendef@[[ ANNON6  : "="], [TOKENNAME: "SPACE"]]
#     └---pattern@[[  RSTR   : "r\"\\s+\""]]
# └---statement@[[   LF    : "\x0A"]]
# └---magic@[[ ANNON7  : "%"], [ ANNON6  : "="], [ ANNON8  : "/"]]
#     └---directive@[[ ANNON1  : "ignore"]]
#     └---name@[[TOKENNAME: "SPACE"]]
#     └---name@[[TOKENNAME: "COMMENT"]]

proc compile_parser*(src: string, classname: openArray[string], typsec: string) =
    type
        N = Parser.Node
        NK = Parser.NodeKind
        T = Parser.Token
        TK = Parser.TokenKind

    let
        nodetypename = classname[0]
        tokentypename = classname[1]
        treetypename = classname[2]

    var
        ret: seq[string]

        lic: string
        input: string

    block LICENCE:
        lic = "#[ LICENSE:\n"
        lic &= license.indent(4)
        lic &= "\n"
        lic &= "Created by mcmurry; module for generating lexer/parser.".indent(4)
        lic &= "\n]#\n\n"

    block INPUT:
        input = "# INPUT:\n"
        for e in src.splitLines:
            input.add "# $1\n" % [e]
        input.add "\n"
        
    #[
        var
            tokens: seq[string]
            rules: seq[string]

        Visitor(Parser, findtokenrule):
            proc name(self: N) =
                case self.tokens[0].kind
                of TOKENNAME:
                    tokens.add self.tokens[0].val
                of RULENAME:
                    rules.add self.tokens[0].val
                else:
                    assert false
            proc tokendef(self: N) =
                case self.tokens[1].kind
                of TOKENNAME:
                    tokens.add self.tokens[1].val
                of NIMCODE:
                    log self
                else:
                    assert false
        discard findtokenrule(node)

        log node
        log tokens
        log rules
    ]#

    var
        node = parser.parse(src).simplify()
        ind = 0

        filename = ""
        annons: HashSet[string]

    Visitor(Parser, findannon):
        proc pattern(self: N) =
            annons.incl self.tokens[0].val
        proc name(self: N) =
            discard

    Visitor(Parser, visit):
        proc name(self: N) =
            discard
        proc magic(self: N) =
            # directive
            case self.children[0].tokens[0].val
            of "filename":
                # name
                filename = self.children[1].tokens[0].val
        proc ruledef(self: N) =
            discard self.findannon()
    discard node.visit()

    ret.add lic         # add license
    ret.add input       # add input
    ret.add typsec      # add type section

    if filename == "":
        stdout.write(ret)
    else:
        var
            f = open((filename & ".nim"), fmWrite)
        defer:
            f.close()
        f.write(ret)

macro Mcmurry*(body: untyped): untyped =
    ##[
        This macro does not create a parser at compile-time but does a source file of the parser module.
    ]##

    # echo treeRepr body
    # echo repr body
    
    let
        directives = ["filename", "toplevel", "node", "token", "nim", "ignore", "nodename", "tokenname", "treename"]
        directives_allow_nim_code = ["node", "token", "tree", "nim"]

    # Checking structure of AST.
    var
        b_nimcode = false

        tokentype: NimNode = nil
        nodetype: NimNode = nil
        treetype: NimNode = nil

        nimsec: NimNode = newStmtList()
        lexersec: seq[NimNode]
        parsersec: seq[NimNode]

        rules: seq[NimNode] = @[newEmptyNode()]
        tokens: seq[NimNode] = @[newEmptyNode()]

        typsec = nnkTypeSection.newNimNode()

        nodename = "Node"
        tokenname = "Token"
        treename = "Tree"

        delast: seq[int]

        annons: HashSet[string]
    body.expectKind(nnkStmtList)
    for astind, ast in body:
        ast.matchAst(MatchingErrors):
        # magic
        of nnkAsgn(nnkPrefix(ident"%", `directive`@nnkIdent), `call`@{nnkIdent, nnkCall, nnkInfix}):
            if directive.strVal notin directives:
                error "Allowed directives only are $1" % [$directives], directive
            # NIMCODE
            if directive.strVal in directives_allow_nim_code:
                # parsing NIMCODE
                call.matchAst(CallMatchingErrors):
                of nnkCall(ident"NIM", `statement`@nnkStmtList):
                    case directive.strVal
                    of "node":
                        nodetype = statement
                    of "token":
                        tokentype = statement
                    of "tree":
                        treetype = statement
                    of "nim":
                        nimsec.add statement
                    else:
                        # cannot reach.
                        assert false
                else:
                    error $CallMatchingErrors[0], call
                b_nimcode = true
            # RULENAME
            else:
                let err = call.matchLengthKind(nnkIdent, 0)
                if err.kind != NoError:
                    if directive.strVal == "ignore":
                        call.expectKind(nnkInfix)
                    else:
                        error $err, call
                else:
                    case directive.strVal
                    of "filename":
                        discard
                    of "toplevel":
                        discard
                    of "ignore":
                        discard
                    # cut ast node.
                    of "nodename":
                        nodename = call.strVal
                        delast.add astind
                    of "tokenname":
                        tokenname = call.strVal
                        delast.add astind
                    of "treename":
                        treename = call.strVal
                        delast.add astind
                    else:
                        # cannot reach
                        assert false
        # tokendef
        of nnkAsgn({nnkStrLit, nnkRStrLit}, `call`@{nnkIdent, nnkCall}):
            case call.kind
            # TOKENNAME
            of nnkIdent:
                var
                    m: RegexMatch
                if not call.strVal.match(re(r"[A-Z][A-Z0-9]*"), m):
                    error "Token name must consist of upper case character or number.", call
                tokens.add call
            # NIMCODE
            of nnkCall:
                call.matchAst(CallMatchingErrors):
                of nnkCall(ident"NIM", `statement`@nnkStmtList):
                    b_nimcode = true
                    statement.matchAstRecursive:
                    of `tokenname`@nnkIdent:
                        var
                            m: RegexMatch
                        if tokenname.strVal.match(re(r"[A-Z][A-Z0-9]*"), m):
                           tokens.add tokenname
                    lexersec.add statement
                else:
                    error $CallMatchingErrors[0], call
            else:
                # cannot reach
                assert false
        # ruledef
        of nnkCall(`rulename`@nnkIdent, `statement`@nnkStmtList):
            var
                m: RegexMatch
            if not rulename.strVal.match(re(r"[a-z][a-z_0-9]*"), m):
                error "Rule name must consist of lower case character or number.", rulename
            rules.add rulename

            # -> RULENAME
            statement.matchAstRecursive:
            of nnkInfix(ident"->", _, `rulename2`@nnkIdent):
                rules.add rule_name2
            # = NIMCODE
            statement.matchAstRecursive:
            of nnkCall(ident"NIM", `statement2`@nnkStmtList):
                parsersec.add statement2
            of `annon`@{nnkStrLit, nnkRStrLit}:
                annons.incl annon.strVal
        # `END` marker
        of ident"END":
            let err = ast.matchIdent("END")
            if err.kind != NoError:
                if b_nimcode:
                    error $err, ast
            else:
                if not b_nimcode:
                    error "`END` marker is only allowed after `NIM` section.", ast
                else:
                    b_nimcode = false
        else:
            if b_nimcode:
                error $MatchingErrors[^1], ast
            error $MatchingErrors, ast

    # Checking Nim code section.
    for i, j in delast:
        body.del(j-i)

    # nimsec: NimNode = newStmtList()
    # lexersec: seq[NimNode]
    nimsec.add nnkVarSection.newTree(
        newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int")),
        newIdentDefs(ident"len", bindSym"int"),
        newIdentDefs(ident"str", bindSym"string"),
        newIdentDefs(ident"kind", ident(tokenname & "Kind")),
        newIdentDefs(ident"kind_stack", nnkBracketExpr.newTree(bindSym"seq", ident(tokenname & "Kind")))
    )
    var se = ident"SyntaxError"
    nimsec.add quote do:
        type
            `se` = object of Exception
    for e in lexersec:
        nimsec.add nnkAsgn.newTree(
            ident"kind",
            nnkBlockStmt.newTree(
                newEmptyNode(),
                e
            )
        )
    
    # tokentype: NimNode
    # nodetype: NimNode
    # treetype: NimNode
    # typsec: NimNode
    # rules: seq[NimNode]
    # tokens: seq[NimNode]
    # parsersec: seq[NimNode]

    var
        pure = nnkPragma.newTree(ident"pure")

    # TreeKind
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(ident(treename & "Kind"), "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(newEmptyNode(), ident(tokenname), ident(nodename))
    )
    # NodeKind
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(ident(nodename & "Kind"), "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(rules.deduplicate)
    )
    # TokenKind
    for i in 0..<annons.len:
        tokens.add ident("ANNON" & $i)
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(ident(tokenname & "Kind"), "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(tokens.deduplicate)
    )
    # TODO: add procedure
    # proc intval(self: Tree): auto =
    #     if self.kind == TK:
    #         result = self.tkintval
    #     elif self.kind == ND:
    #         result = self.ndintval
    # Token
    var
        token_rec = nnkRecList.newTree(
            # newIdentDefs(ident"tokenkind", ident(tokenname & "Kind")),
            newIdentDefs(ident"val", bindSym"string"),
            newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int"))
        )
        token_reccase = nnkRecCase.newTree(newIdentDefs(ident"tokenkind", ident(tokenname & "Kind")))
    if not tokentype.isNil:
        for e in tokentype:
            e.matchAst(TokenMatchingError):
            of nnkCall(`tokenname`@nnkIdent, `statement`@nnkStmtList):
                var
                    m: RegexMatch
                if not tokenname.strVal.match(re(r"[A-Z][A-Z0-9]*"), m):
                    error "Only token name can be placed here.", tokenname
                if tokenname notin tokens:
                    error "Undefined token.", tokenname
                var
                    token_inner_rec = nnkRecList.newNimNode()
                    token_of_branch = nnkOfBranch.newTree(tokenname)
                for ee in statement:
                    ee.matchAst(MatchingError):
                    of nnkCall(`field`@nnkIdent, nnkStmtList(`typ`@nnkIdent)):
                        token_inner_rec.add newIdentDefs(field, typ)
                    else:
                        error $MatchingError[0], e
                token_of_branch.add token_inner_rec
                token_reccase.add token_of_branch
            else:
                error $TokenMatchingError[0], e
        token_reccase.add nnkElse.newTree(nnkRecList.newTree(newNilLit()))
        token_rec.add token_reccase

    # Node
    var
        node_rec = nnkRecList.newTree(
            # newIdentDefs(ident"nodekind", ident(nodename & "Kind")),
            newIdentDefs(ident"children", nnkBracketExpr.newTree(bindSym"seq", ident(treename)))
            # newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int"))
        )
        node_reccase = nnkRecCase.newTree(newIdentDefs(ident"nodekind", ident(nodename & "Kind")))
    if not nodetype.isNil:
        for e in nodetype:
            e.matchAst(NodeMatchingError):
            of nnkCall(`rulename`@nnkIdent, `statement`@nnkStmtList):
                var
                    m: RegexMatch
                if not rulename.strVal.match(re(r"[a-z][a-z_0-9]*"), m):
                    error "Only rule name can be placed here.", rulename
                if rulename notin rules:
                    error "Undefined rule.", rulename
                var
                    node_inner_rec = nnkRecList.newNimNode()
                    node_of_branch = nnkOfBranch.newTree(rulename)
                for ee in statement:
                    ee.matchAst(MatchingError):
                    of nnkCall(`field`@nnkIdent, nnkStmtList(`typ`@nnkIdent)):
                        node_inner_rec.add newIdentDefs(field, typ)
                    else:
                        error $MatchingError[0], e
                node_of_branch.add node_inner_rec
                node_reccase.add node_of_branch
            else:
                error $NodeMatchingError[0], e
        node_reccase.add nnkElse.newTree(nnkRecList.newTree(newNilLit()))
        node_rec.add node_reccase

    # Tree
    typsec.add nnkTypeDef.newTree(
        postfix(ident(treename), "*"),
        newEmptyNode(),
        nnkRefTy.newTree(
            nnkObjectTy.newTree(
                newEmptyNode(),
                newEmptyNode(),
                nnkRecList.newTree(
                    nnkRecCase.newTree(
                        newIdentDefs(ident"kind", ident(treename & "Kind")),
                        nnkOfBranch.newTree(
                            ident(tokenname),
                            token_rec
                        ),
                        nnkOfBranch.newTree(
                            ident(nodename),
                            node_rec
                        )
                    )
                )
            )
        )
    )

    # for e in statement:
    #     e.matchAst(StatementMatchingErros):
    #     of nnkCall(`rulename`@nnkIdent, _):
    #         var
    #             m: RegexMatch
    #         if not rulename.strVal.match(re(r"[a-z][a-z_0-9]*"), m):
    #             error "Rule name must consist of lower case character or number.", rulename
    #     else:
    #         error $StatementMatchingErros[0], statement
    
    # returns: 
    # for e in compile_parser(astToStr(body)):
    #     echo e
    # when nimvm:
    #     when nimvm:
    #         discard
    #     else:
    #         typsec
    # else:
    #     discard
    result = newStmtList()
    result.add newCall(bindSym"compile_parser", newLit(repr(body)), newLit([nodename, tokenname, treename]), newLit(repr(typsec)))

    result.add nnkWhenStmt.newTree(
        nnkElifBranch.newTree(
            ident"nimvm",
            newStmtList(
                nnkWhenStmt.newTree(
                    nnkElifBranch.newTree(
                        ident"nimvm",
                        newStmtList(nnkDiscardStmt.newTree(newEmptyNode()))
                    ),
                    nnkElse.newTree(
                        newStmtList(
                            typsec,
                            nimsec
                        )
                    )
                )
            )
        ),
        nnkElse.newTree(
            newStmtList(nnkDiscardStmt.newTree(newEmptyNode()))
        )
    )
    