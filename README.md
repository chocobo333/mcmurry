# Mcmurry

This module provides ebnf lexer/parser generator and supports to manipulate AST; Abstract Syntax Tree, in pure nim.
The parser generator is implemented as a macro.

#  Contents
* [Installation](#Installation)
* [Document](#Document)
* [TODO](#TODO)

# Installation
```
nimble install mcmurry
```

# Document
* [Generating Parser](#Usage)
* [Example](#Example)
* [Tree type](#TreeReference)
* [Token type](TokenReference)
* [Manipulating AST](#ManipulatingAST)
    * [Visitor](#Visitor)
    * [Transformer](#Transformer)

# Usage

## **Generating lexer/parser**
This parser generator generates parser and lexer at the same time.
it accepts LR(1) grammar and supports ebnf (actually not all of).

### **Defining parser class**
By using a macro named ``Mcmurry``, you can define a parser class includes a lexer.

### **Mcmurry arguments**

* ``id``
: Set name of created parser class.

* ``toplevel``
: Set starting rule.

### **Grammer Definitions** and **Patterns**

* ``rule: ...``

    Define a rule.
    Name of rule must matche re"[a-z][a-z0-9_]*"
* ``[foo]``

    Match 0 or 1.
* ``(foo bar)``

    Group together (for an operator).
* ``*foo``

    Match 0 or more.
* ``+bar``

    Match 1 or more.
* ```nim
    rule:
        foo
        bar
    ```

    Match ``foo`` or ``bar``.

### **Token Definitions**
* ``r"token": TOKEN``

    Define a token.
    right part is a raw string as a regular expression.
    left part is expression returns a sort of token.
    You can use ``block:`` in right part.

    Name of token must matche re"[A-Z][A-Z0-9]*"
* ``var variable``

    Define a variable used in deciding a sort of token that returned by the lexer.
    Used postlex.

    * Predefined variables

        * ``len``: int

            Indicates the length of string that matched the regular expression.

### **Example**

```nim: exsample.nim
Mcmurry(id=Parser, toplevel=expression):
    parser:
        expression: arith_expr
        arith_expr: term *(r"\+" term)
        term: atom *(r"\*" atom)
        atom:
            INT
            FLOAT
    lexer:
        r"([0-9]*[\.])?[0-9]+": FLOAT
        r"[1-9][0-9]*": INT
var parser = Parser()
echo parser.parse("3+4*2")
```

# TreeReference
* ``kind``
* ``children``
* ``tokens``

# TokenReference
* ``kind``
* ``val``
* ``pos``

# Manipulating AST

# *Not Implemented.*

### **Visitor** *vs* **Transformer**

``Visitor`` and ``Transformer`` are interfaces to manipulate AST that the generated parser returns.

* #### **Visitor**

* #### **Transformer**


**Note**:
Using ``macro`` and computing in ``macro``, using editor/pc may be busy.

## TODO
* supporting ``|`` operator in the parser section.
* supporting all of ebnf
* implementation without using a macro. such as generating a parser dynamically since receiving a string as input.
* using pure regex.
* implementation of ``Visitor`` and ``Transformer``.
* variation of parser algorithm.
* more predefined variables.

**author**: chocobo333