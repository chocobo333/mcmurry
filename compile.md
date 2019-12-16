# Generate parser file
You can make parser source file from nim's ``macro``.
The ``macro`` is only used to check syntax erros. No computation is at compile-time, and source file is generated at run-time.
In this way, your PC may be no louder than.

Because I rewrote source code for this, the resulted data structure is not the same as through ``macro``.

I implemented so roughly. So, checking syntax errors is weak.

# Contents
* [Example](#Example)
* [Usage](#Usage)
* [Magic](#Magic)
* [NIMCODE block](#NIMCODE-block)
* [Definition](#Definition)
    * [Token](#Definition-of-token)
    * [Rule](#Definition-of-rule)
* [Reference](#Reference)
* [TODO](#TODO)

# Example
I wrote some test codes.
See [them](./tests/).

[*test2.nim*](./tests/test2.nim) and [*test3.nim*](./tests/test3.nim) are samples of `Generating source file`.

# Usage
At first,
```nim
import mcmurry/compile
```
you must import ``mcmurry/compile`` instead ``mcmurry``.

# Magic
You can use the ``magic`` which tells some information to my program to help to constitute your parser.

``magic`` consists of prefix, directive and arugument.
for instance,
```nim
%ignore SPACE
```

Seeing `%`, my ``macro`` and parser recognize the following input as the ``magic``.

The following are all directives.
You shoud specify directive decorated with **bold** at least.
* **filename**

    Specifies the name of the file to be generated.

    If there is not filename directive, outputs to stdout.
* parsername

    The name of parser type.

    default: ``Parser``

* treename

    The name of tree type and kind of tree type.

    default: ``Tree``, ``TreeKind``
* nodename

    The name of node type and kind of node type.

    default: ``Node``, ``NodeKind``

* tokenname

    The name of token type and kind of token type.

    default: ``Token``, ``TokenKind``

# NIMCODE block
You can write code of ``Nim`` in certain locations such as after certain ``magic`` or definition of token.

# Definition

## Definition of Token

## Definition of Rule

# Reference

```nim
type
    TreeKind = enum
    TokenKind = enum
    NodeKind = enum
    Tree = object
        case kind: TreeKind
        of Token:
            val: string
            pos: (int, int)
            case tokenkind: TokenKind
            else:
                discard
        of Node:
            children: seq[Tree]
            case nodekind: NodeKind
            else:
                discard
```

# TODO
* more stronger checking erros.