=======
Mcmurry
=======

This module provides ebnf lexer/parser generator and supports to manipulate AST; Abstract Syntax Tree, in pure nim.
The parser generator is implemented as a macro.

Generating lexer/parser.
------------------------
This parser generator generates parser and lexer at the same time.
it accepts LR(1) grammar and supports ebnf (actually not all of).

**Grammer Definitions** and **Patterns**
""""""""""""""""""""""""""""""""""""""""

* ``rule: ...``
    Define a rule.
* .. code :nim
    rule:
        foo
        bar

    Match foo or bar
* ``[foo]``
    Match 0 or 1.
* ``(foo bar)``
    Group together (for an operator).
* ``*foo``
    Match 0 or more.
* ``+bar``
    Match 1 or more.

**Token Definitions**
"""""""""""""""""""""

**Usage**
^^^^^^^^^
.. code:: nim
    Mcmurry(id=Parser, toplevel=expression):
        parser:
            expression: arith_expr
            arith_expr: term *(OP1 term)
            term: atom *(OP2 atom)
            atom:
                INT
                FLOAT
        lexer:
            r"([0-9]*[\.])?[0-9]+": FLOAT
            r"[1-9][0-9]*": INT

Manipulating AST.
-----------------
**Visitor** *vs* **Transformer**
""""""""""""""""""""""""""""""""

**Note**: Using ``macro`` and computing in ``macro``, using editor/pc may be busy.

TODO

* supporting ``|`` operator in the parser section.
* implementation without using a macro. such as generating a parser dynamically since receiving a string as input.
* using pure regex.

:author: chocobo333