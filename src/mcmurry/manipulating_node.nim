
import macros

import private/core

proc simplify*(self: NodeBase): NodeBase =
    ##[
        Simplify tree node.
        Nodes that have a child and no tokens are removed through this proc.
    ]##
    for i, e in self.children:
        self.children[i] = simplify(e)
    if self.children.len == 1 and self.tokens.len == 0:
        return self.children[0]
    else:
        return self

macro kindcase*[E: enum](self: untyped, nodekind: typedesc[E]): untyped =
    var
        casestmt = nnkCaseStmt.newTree(newDotExpr(self, ident"kind"))
        nodekinds = nodekind.getImpl[2][1..^1]
    for e in nodekinds:
        casestmt.add nnkOfBranch.newTree(
            newDotExpr(nodekind, e),
            newStmtList(
                nnkWhenStmt.newTree(
                    nnkElifBranch.newTree(
                        newCall(bindSym"declared", e),
                        newStmtList(
                            newCall(e, self)
                        )
                    ),
                    nnkElse.newTree(
                        newStmtList(
                            nnkWhenStmt.newTree(
                                nnkElifBranch.newTree(
                                    newCall(bindSym"declared", ident"visit_default"),
                                    newStmtList(
                                        newCall(ident"visit_default", self)
                                    )
                                ),
                                nnkElse.newTree(
                                    newStmtList(
                                        nnkDiscardStmt.newTree(newEmptyNode())
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    result = casestmt


template Visitor*(parsertype: typedesc, procname: untyped, body: untyped) =
    ##[
        A proc created by ``Visitor`` visit each children of the node, and run a suitable procedure according to a kind of the node.

        **exsample**

        .. code:: nim
        
            import strutils
            Visitor(Parser, visit):
                proc atom(self: Parser.Node) =
                    var
                        tmp = self.tokens[0].val.parseInt()
                    self.tokens = @[Parser.Token(kind: INT, val: $(tmp+1))]
    ]##
    proc `procname`(self: parsertype.Node): parsertype.Node =
        body
        kindcase(self, parsertype.NodeKind)
        for e in self.children:
            discard `procname`(e)
        self

# dumpTree:
#     proc visit(self: Parser.Node): Parser.Node =
#         case self.kind
#         of atom:
#             discard
#         else:
#             discard