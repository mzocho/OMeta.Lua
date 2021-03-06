# OMeta/Lua
Here it is an implementation of OMeta language in Lua.

## OMeta
Citing [OMeta Homepage](http://www.tinlizzie.org/ometa/):
> OMeta is a new object-oriented language for pattern matching. It is based on a variant of Parsing Expression Grammars (PEGs) which we have extended to handle arbitrary data types. 
OMeta's general-purpose pattern matching facilities provide a natural and convenient way for programmers to implement tokenizers, parsers, visitors, and tree transformers, all of which can be extended in interesting ways using familiar object-oriented mechanisms.

Most of the features of the original OMeta and in particular OMeta/JS implementation also apply to OMeta/Lua. [Ph.D. dissertation](http://www.vpri.org/pdf/tr2008003_experimenting.pdf) of Alessandro Warth, author of OMeta is the best source of information in the subject.

If you want to better feel the ideas behind OMeta see this [presentation](http://www.tinlizzie.org/ometa/sts08-slides.pdf). In large part, these are ideas that guide OMeta/Lua implementation also.

## PEG
If you need more information about parsing and about Parsing Expression Grammars in particular I highly recommend great paper by Roberto Ierusalimschy [A Text Pattern-Matching Tool based on Parsing Expression Grammars](http://www.inf.puc-rio.br/~roberto/docs/peg.pdf).

*Why another PEG for Lua - there is great [LPeg](http://www.inf.puc-rio.br/~roberto/lpeg/)?*

This project is a part of greater effort - to create an object-oriented platform for Computer-Aided Software Engineering. 
In brief: I need a very general parsing solution, modular, extensible, working on any type of input, etc. I know that most of this requirements are possible to fulfill with LPeg, but the workload would be similar and the level of control would be much worse. Moreover I already know OMeta/JS and JavaScript but my knowledge of C (needed for LPeg extending) is definitely insufficient.

One more reason for porting OMeta was its solution for the [*left recursion* issue](http://www.vpri.org/pdf/tr2007002_packrat.pdf) and [memoization](https://en.wikipedia.org/wiki/Memoization) in general.
Eventually, I want to develop a solution that will be usable by non-programmers (at least to read and understand), without worrying about issues in field of parser building. Therefore, PEG and especially OMeta seems like the perfect base.

## Installation
OMeta is implemented in OMeta itself and works as an extension to Lua syntax. This means that any Grammar, including OMeta Grammar itself, must be compiled to plain Lua before usage. The project sources include both OMeta sources and compiled Lua sources. If you need to experiment, there is a *build.lua* package containing building scripts. Building OMeta sources uses the same process which is used to compile user Grammars.

### Requirements
Project requires Lua 5.1 or newer.

### Version
See [changelog](./changelog.md)

### Using OMeta/Lua
Compiled Grammar packages are normal Lua modules that can be required.
```lua
local LuaGrammar = require 'lua52_grammar'
local luaAst = LuaGrammar.block:matchFile('some_lua_source.lua')
print(luaAst) -- prints textual representation of abstract syntax tree parsed from file
```
The following chapters bring subject of writing the Grammars closer. If you need firstly to find out how to use the predefined Grammars by means of provided API, jump to chapter [API](#api).

## Writing Grammars
OMeta/Lua extends Lua syntax with some new statements for defining Grammars and Rules and a new expression kind to interpolate strings which helps to translate abstract syntax trees and sources.

The next sections refer to this extensions and describe the syntax that should be used in order to properly write the user defined Grammars.

### Grammar
Grammar in OMeta/Lua is a  kind of logical package containing the Rules (and perhaps other elements as plain Lua tables).
The Grammar must have a name and it can only be defined as a statement.
```lua
-- local Grammar
local ometa NameOfLocalGrammar {...}
-- Grammar in a namespace
ometa SomePackage.SomeGrammar {...}
```
Grammars can be extended in natural way by the means of merging. Grammar class provides one predefined method ([*Grammar::merge*](#grammar-api)) for merging rules, so you can build a derived Grammar from many base Grammars.
```lua
ometa Grammar1 {...}
ometa Grammar2 {...}
ometa Grammar3 {...}
Grammar3:merge(Grammar1)
Grammar3:merge(Grammar2)
```
One thing you should be aware of is the name conflicts resolution - the Rule with conflicting name will not be merged.
  
### Rule
The Rule in OMeta/Lua is a kind of classifier. The Rule is a named element introduced within the Grammar or individually as a statement.
```lua
ometa Grammar {
  rule1 = ...,
  rule2 = ...
}

rule Grammar:rule3() -- Lua method syntax is reused
  ...
end
```
The Rule in OMeta is build as an ordered Choice where every alternative is a Sequence of Nodes. An important thing about the Rule application is that, it gives a dual result - a boolean indicator of success and a value returned by the Rule behavior (implemented as a Lua function).
The boolean result, pass or fail, indicates a success of the application as a whole, but the value of the result depends on a specific alternative of the Rule that succeeded.

### Hello World Grammar
A basic information on defining Rules can be summarized by the "Hello World" example - an elemental algebraic operations parser. 
```lua
local ometa Calc {
  exp     = addexp,
  addexp  = addexp '+' mulexp
          | addexp '-' mulexp
          | mulexp
          , 
  mulexp  = mulexp '*' primexp
          | mulexp '/' primexp
          | primexp
          , 
  primexp = '(' exp ')'
          | numstr
          , 
  numstr  = '-'? digit+
} 
Calc:merge(require'grammar_commons') 
```
Since this Grammar doesn't have any [semantic action](#semantic-actions), it does not do very much. It is able to simply consume input stream as far as it is matching Rules.

### Rule features 
Below, there is an overview of the basic means used to build a Rule.

|Construct|Syntax|Notes|
|:-------:|-----:|-----|
|Rule structure|`a \| b \| c`<br>`a b c`<br>`a ( b \| d ) c`|an ordered Choice - a sequence of alternatives<br>a Sequence of Nodes<br>a Node can be an ordered Choice again|
|Lookahead|<br>`&a`<br>`~a`|to parse without consuming input:<br>- And Predicate<br>- Not Predicate|
|Modifiers|`a?`<br>`a*`<br>`a+`<br>`a**min`, `a**min..max`<br>`a/num`|optional<br>zero to many<br>one to many<br>*min* to *max* (or many)<br>repeat *num* times|
|Grouping|`( a \| b c )`<br>`< a b c >`<br>`{ a b ; prop=c }`|to group nodes and create scope<br>consumed input stream<br>an object - [matches complex structures](#parsing-complex-data)|
|Literals|`"keyword"`, `"("`, `")"`<br>`[[abc]]`<br>`'abc'`<br>`5`, `0xFF`, `-1.2e3`<br>`false`, `true`<br>`nil`<br>|[tokens](#tokens)<br>a sequence of characters (`'a' 'b' 'c'`)<br>a string literal<br>number literals<br>boolean literals<br>a nil literal|
|Rule application|`.`<br>`number`<br>`list(exp, ",")`<br>`LuaGrammar.exp`<br>`Grammar.stat@Grammar`|Anything - a single element of any kind<br>matches a named Rule *number*<br>an [application with arguments](#parametrized-rules)<br>a [foreign application](#foreign-rules)<br>a foreign application with a context switch|
|[Host Nodes](#semantic-actions)|`[string.rep('.', n)]`<br>`[! print('hello')]`<br>`[? #str == 5]`|[Host Expressions](#host-expression) - pass and return a value<br>[Host Statement](#host-statement) - pass without a value<br>[Host Predicate](#host-predicate) - no value but can fail|
|[Binding](#binding)|`variable:a`<br>`num:[10]`<br>`{; prop:=string }`|to bind a result of *a* to the *variable*<br>to bind `10` (Host Expression) to the *num*<br>a binding combined with parsing property|

### Semantic Actions
The PEG's *semantic actions* in OMeta/Lua are generalized to the **Host Nodes**.
A Host Node is included in a Rule body using square brackets (`[]`). A specific kind of the Host Node and its impact on the result of a whole Rule are determined by its content.

The current implementation provides three kinds of the Host Nodes:
 - **Host Expression** and **Host Statement** are corresponding to PEG's *semantic actions*, 
 - **Host Predicate** is corresponding to *semantic predicate*.

#### Host Expression
The most important kind of the Host Node is the Host Expression denoted simply by square brackets containing single Lua expression (function call, calculation, literal, etc.).
Examples:
```lua
['hello'] -- a string literal
a:[(1 + 20) * 2] -- Lua expression bound to a variable
[string.rep('.', a)] -- a function call
```
The Host Expressions always pass and return its value.

#### Host Statement
The  Host Statement allows to execute an arbitrary Lua code (one or more statements) without a direct result (but maybe with side effects). From OMeta point of view, evaluation of the Host Statement always results in a success (pass) without any value (`nil`).

The Host Statement is marked with the exclamation mark at the beginning of a Node content:
```lua
[! print('hello')] -- a function call, the result doesn't matters (is ignored)
[! local v = 42; local s = tostring(v); error(s) ] -- there is no result but the side effect is "fatal"
```
#### Host Predicate
The Host Predicate is very similar to the Host Expression with only difference that a result of its evaluation determines a success of the Rule instead of a value of the result.

Everything what is truthy in Lua gives the Rule a pass and everything, what is falsy, gives the Rule a fail.

The Host predicate is marked with the question mark at the beginning. For example:
```lua
[? type(head) == 'string']
[? char:byte() == 32]
[? false] -- always fails
```

### Binding
In OMeta you can bind a return value of any Node to a chosen name:
```lua
concatenate = "(" left:digit+ "," right:<digit+> ")" [left:concat() .. '/' .. right],
innerResult = "[" inner:(~"]" .)* "]"
```

#### Scoping
The scope of a variable is lexical. For the Rule parameters this is a whole Rule body, but for the user defined variables the scope begins from a point of name binding and it lasts until (first of the below):
- the end of the Rule body,
- the end of scope designated by round brackets,
- or the end of current ordered Choice alternative;
```lua
embedded = outer:(inner:applySomething [inner]) [outer],
alts     = val1:alt1 | val2:alt2 | [val1 or val2] -- val1 and val2 are unbound (out of scope)
```
In OMeta/Lua variables can contain Rules and those Rules can be applied directly by a variable name:
```lua
higherOrderRule(what) = what+
```
Above the Rule applies another Rule (provided as an argument) one or more times.
Such a behavior in combination with lexical scoping is associated with the thing you should note. Once a value is bound to the variable, this variable overrides any other Rule of the same name which could exist in the given context.
```lua
strangeRule = name:name name2:name -- bad idea
```
The above Rule will not work as you might expect - the first occurrence of the *name* application will work correctly, but result will be bound to the *name* and the second occurrence of the *name* application will fail (because there is no correct Rule under the name *name*, actually there is some string value).

### Host Nodes & binding - Hello World - continued
It is the time for our Grammar update, so:
```lua
local ometa TableTreeCalc {
  exp     = addexp,
  addexp  = l:addexp '+' r:mulexp   [{'+', l, r}] 
          | l:addexp '-' r:mulexp   [{'-', l, r}] 
          | mulexp
          , 
  mulexp  = l:mulexp '*' r:primexp  [{'*', l, r}] 
          | l:mulexp '/' r:primexp  [{'/', l, r}] 
          | primexp
          , 
  primexp = '(' exp:exp ')'         [exp] 
          | numstr
          , 
  numstr  = digits:<'-'? digit+>    [tonumber(digits)]
} 
TableTreeCalc:merge(require'grammar_commons') 
return TableTreeCalc
```
This Grammar is now able to build a simple parse tree (Lua tables hierarchy) from the expressions provided as strings, eg.:
```lua
local OMeta = require 'ometa'
local Calc = OMeta.doFile('calc.lpp') -- a name of a file containing the TableTreeCalc package
local tree = Calc.exp:matchString('2*(5+6)')
```

### Tokens
The Token is built in syntax construct in OMeta (denoted by quotation marks - `"`), however its semantics is not determined in advance.

Lua and OMeta Grammars in OMeta implementation use the Tokens to conveniently parse the Keywords and the Special characters in language syntaxes (see *lua_grammar.lpp*, *lua52_grammar.lpp* - new keywords in Lua 5.2, *ometa_grammar.lpp*). The Token firstly skips any number of white-spaces, then tries to match the sequence of characters that was passed to it as an argument.

If you want to use the Tokens the same way in your language Grammar, then simply merge the GrammarCommons package and provide sets of Keywords and Special characters from your language. After that, you can simply use the Token syntax in the Rules:
```lua
local ometa SomeLanguage {
  -- definition of Tokens
  keyword = 'fn' | 'ret', -- only string literals
  special = [[=>]] | '(' | ')' | '{' | '}' | ',', -- single characters and sequences ([[...]])
  -- following Rules use defined Tokens
  stat    = "fn" name "(" list(name, ",") ")" "=>" exp -- "arrow" fn
          | "fn" name "(" list(name, ",") ")" "{"
              ... -- grammar of fn body
              "ret" exp
            "}"
          | ...
          ,
  exp     = ...
}
SomeLanguage:merge(require 'grammar_commons')
```
The definition of a Token in GrammarCommons automatically takes into account all literals defined by the *keyword* and *special* Rules. The only thing you should note is the kind of literals in that Rules: the *keyword* accepts only string literals, however, *special* accepts string literals **for single characters only** and sequences of characters (directly or in double square brackets: `'=' '>'` == `[[=>]]`) other times. It results from the way the Token works internally.

### Parametrized Rules
The Rules in OMeta can have parameters. The Rule declares formal parameters and the Rule application may provide actual arguments values. One important thing to know is, how OMeta treats extra arguments not declared as formal parameters. Any such argument is prepended to the input stream, so the Rule has access to its value.

Example:
```lua
ometa Spec {
  somecode = varchar([5]) '-' varchar([5]) '-' varchar([10]),
  varchar  = char/number --repeats char number of times
}
```
The Rule *varchar* is applied three times with the number of characters to parse. But there is no suitable formal parameter in the Rule *varchar*. Instead of, the Rule uses predefined Rule *number* to match Lua number prepended to the input stream by the preceding Rule application. The same effect can be achieved directly by: `varchar(num) = char/[num]`.

### Higher-order Rules
A specific case of parametrized Rule is higher-order Rule - the Rule that accepts other Rules (actually any kind of OMeta expressions) as parameters.

Here is a simple example of such kind of Rule - a predefined Rule *list*:
```lua
list(pattern, delim, minimum?)
```
where:
- a *pattern* is any kind of OMeta pattern,
- a *delim* - the same as above,
- a *minimum* - the Host Expression - a minimum number of elements in a matched list (default `0`).

For example:
- `list(exp, ',')` - any number of *exp*s separated by commas (as a single char) - it is not the same as...
- `list(exp, ",")` - ...where commas are tokens;
- `list(number | boolean | string, ";" | ",", [num or 1])` - matches at least *num* (or `1` if *num* is "falsy") primitive Lua values delimited by semicolons or commas.

A higher order Rule may be user defined, e.g.:
```lua
ometa G {
  triple(what) = what what what,
  useTriple    = triple(triple(char)) --matches 9 (3*3) chars
}
```
### Foreign Rules
A Parsing always progress in the context of some provided Grammar. The Rule is searched by a name in namespace designated by this Grammar. If you need to apply a Rule from other Grammar, just use qualified name:

`Commons.number` - to apply a Rule *number* from the Grammar *Commons*

Such an application allows to use a single foreign Rule without merging it directly or switching to another Grammar. But sometimes there is a need to interweave two or more Grammars with free context switching. This is a common situation in the language embedding case, such as OMeta in Lua and Lua in OMeta:
```lua
ometa LuaInOmetaGrammar {
  ...
  primexp       = "[" OMetaInLuaGrammar.exp@OMetaInLuaGrammar "]"
  ...
}
```
In this case, there is a context switch and everything between square brackets is parsed in context of other Grammar than outside brackets (*LuaInOmetaGrammar* <--> *OMetaInLuaGrammar*).

### Parsing complex data
The important OMeta feature is an ability to parse any kind of input.

The current implementation of OMeta/Lua provides construct to parse Lua tables, including free access to array part and map part (the named properties).
To parse a table in the input stream (the head element) use curly brackets (`{ }`). The open bracket denotes a table in the input stream and parser context switch to the content of this table. The closing bracket denotes the end of the table parsing and a switch of context back to the "main" stream. Switching can be embedded (the embedded Lua tables) and the parsing table content (the array part) does not vary from parsing input as a whole.
```lua
parseArray = { number* }
```
The above rule parses a table containing any number of Lua numbers in its array part.

The important thing in the parsing tables is that, the array part behaves the same way as the complete input stream - it is parsed completely. Closing curly bracket (or semicolon if there is a map part also) must match the EOS (the end of stream which is the end of array in this case - nothing else to consume).

Things become slightly different in the case of parsing named properties:
```lua
parseTable = { number* ; kind=string, length=number }
```
The above rule parses any number of Lua numbers in the array part of table again. Then it expects the EOS (the end of array part). Next, it freely switches between indicated properties (by name): *kind*, which must be a string value and a *length* of number value.

In the case of parsing map part of a table, there is no expectation of a number of properties in a table. There may be many properties in a table but at least all indicated by the Rule must be present. This approach allows an easy parsing of different "objects" implemented as the Lua tables.

The last unique thing related to table parsing is a shorthand for combined property parsing and binding:
```lua
parseAndBind = {.* ; kind:=string, length:=number}
```
This form automatically binds a result value to the same name as a property name. In the other words: `length:=number` has the same effect as `length=length:number`.

### Mixed streams - Hello World - continued 2
If OMeta parses input of any kind, why not try to parse a stream comprising mixed content, for example string fragments interwoven with already parsed trees and other "objects"?

OMeta/Lua uses internally such a mixed streams to translate abstract syntax trees (OMeta AST into Lua AST).

To give a taste of what mixed streams can be, let's return to our Calc Grammar example. Assume that we already have some expression parsed:
```lua
local exp = {'*', 2, {'+', 5, 6}}
```
...and we need to use this intermediate result in parsing greater expression. If we did this "traditionally", we would need to translate *exp* back to the text form, would concatenate it to other string and would reparse whole expression.
But with OMeta we can do this better.

Firstly, for convenience reason we need to rewrite our Grammar to use something more object-oriented. This is not necessary at all, but this will be helpful.
```lua
local Types = require'types'
local class, Any, Array = Types.class, Types.Any, Types.Array
local OMeta = require'ometa' 

local BinOp = class {name = 'BinOp', super = {Any}} -- our new AST node type

local ometa OpTreeCalc {
  exp       = addexp,
  addexp    = l:addexp "+" r:mulexp       [BinOp {operator = 'add', left = l, right = r}] 
            | l:addexp "-" r:mulexp       [BinOp {operator = 'sub', left = l, right = r}] 
            | mulexp
            , 
  mulexp    = l:mulexp "*" r:primexp      [BinOp {operator = 'mul', left = l, right = r}] 
            | l:mulexp "/" r:primexp      [BinOp {operator = 'div', left = l, right = r}] 
            | primexp
            , 
  primexp   = "(" exp:exp ")"             [exp] 
            | numstr
            , 
  numstr    = ws* digits:<"-"? digit+>    [tonumber(digits)],
  special   = '+' | '-' | '*' | '/' 
            | '(' | ')' 
} 
OpTreeCalc:merge(require'grammar_commons') 
```
BTW the Grammar uses the Tokens now, so white-space management is improved.

Next, let's write a new derived (by means of merge) Grammar for parsing mixed content:
```lua
local Aux = require 'auxiliary'

local ometa MixedOTCalc {
  primexp   = BinOp
            | OpTreeCalc.primexp  -- "super" apply
            ,
  numstr    = number 
            | OpTreeCalc.numstr  -- "super" apply
            ,
  eval      = opr:&BinOp                  Aux.apply([opr.operator], unknown)
            | num:number                  [num]
            | any:.                       [? error('unexpected expression: ' .. tostring(any))]
            , 
  add       = {; left:=eval, right:=eval} [! print('+', left, right)] [left + right],
  sub       = {; left:=eval, right:=eval} [! print('-', left, right)] [left - right],
  mul       = {; left:=eval, right:=eval} [! print('*', left, right)] [left * right],
  div       = {; left:=eval, right:=eval} [! print('/', left, right)] [left / right],
  unknown   = {; operator:=.}             [? error('unexpected operator: ' .. operator)]
} 
MixedOTCalc:merge(OpTreeCalc)
MixedOTCalc.BinOp = BinOp
return MixedOTCalc
```
The above Grammar is able to accept not only string expressions and digit sequences (by "inheriting" and extending *OpTreeCalc.primexp* and *OpTreeCalc.numstr*) but *BinOp* AST nodes and *number* Lua numbers, too.

Additionally, the Rule *eval* accepts parsed expressions (the AST nodes), applies an appropriate Rule to evaluate calculation and returns a result. So, our solution begins to do "something".

We can try our Grammar:
```lua
local MixedCalc = OMeta.doFile('calc.lpp')
local BinOp = MixedCalc.BinOp

-- exp has intermediate result - already parsed expression
local exp = BinOp {operator='mul', left=2, right=BinOp {operator='add', left=5, right=6}}
local ast = MixedCalc.exp:matchMixed('2 * (', exp, ' - 1)')

-- we can print string representation of AST - feature of OMeta types
print(ast)

-- let's evaluate parsed tree
print(MixedCalc.eval:matchMixed(ast)) -- 42
```

## Other extensions to Lua syntax
Currently there is one more extension to Lua syntax provided. Moreover, the architecture of OMeta/Lua is deliberately opened to future extensions.

### String interpolation
This extension extends Lua expressions with a new form of string notation `` `string` ``, where a sequence of characters is delimited by backticks (`` ` ``).

That string can contain embedded Lua expressions, eg.:
```lua
local interpolated = `hello ${'World'}`
interpolated = `${interpolated}!!!`
```
The embedded expression can be a string interpolation itself:
```lua
str = `${`${'str'}`}`
```
#### Function call with interpolated string
When a string interpolation is used as the only argument to a function call / method send, the function receives sequence of "slices" of the string interwoven with (results of) the expressions. This means that:
```lua
fn`string ${var} string ${othervar} string` == fn([[string ]], var, [[ string ]], othervar, [[ string]])
```
As you see, the string slices are translated to Lua "long strings" delimited by double square brackets. This allows to write multi-line interpolated strings.

This feature is massively used in OMeta implementation everywhere something is translated:
- see *lua_ast2source.lpp* - Lua AST to Lua source translator depending on simple strings interpolations;
- see *ometa_ast2lua_ast_\*.lpp* - any of OMeta AST to Lua AST translators, where complex interpolated expressions are used, eg.:
```lua
return exp`OMeta.Rule {
    behavior = function(${self.arguments:prepend(Name {'input'})})
      ${body}
    end;
    arity = ${RealLiteral {arity}},
    grammar = ${ns},
    name = ${index};
  }`
```
Above, there is an example of "AST interpolation" - an interpolated string is used to build the input stream consisting of heterogeneous elements: string slices, OMeta class instances, Lua tables. Such a stream is directed (by function call to *exp*) to parser accepting mixed content (see *[Rule](#rule-api)::matchMixed* and *[OMeta](#ometa-api)::forMixed*). What is a key is that the Rule returns the AST assembled from parsed string slices and "objects" (not string).

### Interpolation - Hello World - continued 3
Eventually, let's try to utilize string interpolation to improve our Hello World, the Grammar and parsing of mixed input.

If you decide to compile your source files before usage, you can do something like this:
```lua
local Calc = OMeta.doFile('calc.lpp')
local calcexp = function(...)
  return Calc.exp:matchMixed(...)
end

local subexp = calcexp `2 * (5 + 6)`
local ast = calcexp `2 * (${subexp} - 1)`

print(Calc.eval:matchMixed(ast)) -- 42
```
But remember, above source must be compiled to plain Lua source before you can execute it (try for example `OMeta.doString([[...]])`).

## API

### OMeta API
```lua
local OMeta = require 'ometa'
```
___
```lua
static OMeta::use(grammar : Grammar) : OMeta
```
It is a class (static) method. 
It accepts the Grammar package and returns an instance of OMeta used as parsing context, e.g.:
```lua
local LuaGrammar = require'lua_grammar'
local luaCtx = OMeta.use(LuaGrammar)
luaCtx:forString('local mess = "hello" return mess')
local luaAst = luaCtx:match(LuaGrammar.block)
print(luaAst)
```
___
```lua
static OMeta::doFile(path : string, translator : string [0..1]) : Grammar
``` 
Class (static) method.
Load, parse, translate, generate and evaluate Lua source for OMeta source file.
For example:
```lua
local calc = OMeta.doFile('calc.lpp')
local result = calc.add:matchString('5+6')
```
An optional parameter translator can be used to change the default translation of OMeta AST into Lua AST.
___
```lua
static OMeta::doString(str : string, translator : string [0..1]) : Grammar
```
Class (static) method.
The same as `doFile` but it accepts source string directly.
___
```lua
OMeta::apply(ruleImpl : Rule|function|Any) : boolean, any
OMeta::applyWithArgs(ruleImpl : Rule|function|Any, ...) : boolean, any
OMeta::applyForeign(target : Grammar, ruleImpl : Rule|function|Any) : boolean, any
OMeta::applyForeignWithArgs(target : Grammar, ruleImpl : Rule|function|Any, ...) : boolean, any
```
Methods accepting the Rule to apply, optionally the target Grammar that would be used as context (*...Foreign...*) and possibly some additional arguments (*...WithArgs*).

Note that, besides the context Grammar OMeta instance must have the input stream properly set (see below methods *for...*).

The Rule implementation provided as an argument *ruleImpl* can be one of following:
- the Rule class instance - an instance of standard OMeta/Lua type (*OMeta::Rule*), such as an effect of compiling OMeta source Grammar;
- the Lua function fulfilling the [Rule::behavior API](#rule-api);
- the type specializing OMeta/Lua base type *Types::Any*. In this case, instead of the Rule application, a behavior consists of a type inclusion test - the input stream head is tested against the provided type (in pseudocode: `head instaneOf type`)

As a result, methods return two values - a boolean indicator of success and a value returned by the Rule behavior (Lua function) of any type (possibly `nil`).
___
```lua
OMeta::next() : boolean, any
OMeta::collect(count : number) : boolean, any
```
This consumes and returns (as second return parameter) `1` or a *count* elements from the input stream.
If there are too few elements, it returns a `false` as the first return parameter (fails).
___
```lua
OMeta::match(ruleImpl : Rule|function|Any, ...) : any
```
It is a wrapper for the *apply...* methods, where an appropriate target method is automatically chosen depending on a number of the arguments.

There is only one return parameter. If the application fails, the method simply returns nothing but additionally prints some error messages on the output.
___
```lua
OMeta::forString(str : string) : OMeta
OMeta::forTable(tab : table) : OMeta
OMeta::forMixed(...) : OMeta
OMeta::forFile(path : string, binary : boolean [0..1] = false) : OMeta
```
Above methods are for setting the input stream in OMeta instance. All of them return *self*.

The *forMixed* method accepts any number of elements of any type and builds the input stream from this sequence.

The *forFile* method accepts additional argument *binary*, which is switching the input stream into binary mode. In this mode the elements of the stream are bytes instead of characters. Some Grammars strictly depend on this mode (see example PNG Grammar).

### Stream API
*TBD*

### Grammar API
```lua
Grammar::merge(source : Grammar) : Grammar
```
This merges Rules in the *source* Grammar into *self* Grammar. This is a "physical" process not a virtual - any Rule in the *source* is cloned to the "target".

The method returns *self*.
### Rule API
```lua
Rule::behavior(input : OMeta, ...) : boolean, any
```
The Rule behavior accepts the *input* parameter (`OMeta` instance) providing a runtime state of parsing (current Grammar, the input Stream state) and returns two parameters: a `boolean` success indicator and a Rule result value of any type.
There can be any number of additional *in* parameters.
___
```lua
Rule::matchString(str : string) : any
Rule::matchTable(tab : table) : any
Rule::matchMixed(...) : any
Rule::matchFile(path : string, binary : boolean [0..1] = false) : any
```
The methods above accept some kind of the input and return a result of the Rule application to this input. Every method corresponds to OMeta method *for...*.

Methods return only one value - the result of the Rule application if the Rule passed or `nil` (and possibly some error messages) if the Rule failed.

## License
This project is licensed under the [MIT License](license.txt)

## Acknowledgments
- Alessandro Warth for inspirations
- my girlfriend for sponsorship :)
