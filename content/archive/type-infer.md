+++
date = "2014-06-01"
title = "Type Inference"

+++
Recovering variable types or other structural information from binaries is useful for reverse engineering in security, and to facilitate other kinds of analysis on binaries.
In this project, we statically infer the signedess of variables using a graph-based algorithm and heuristics about variable types.
A [technical report](https://www.cs.umn.edu/research/technical_reports/view/14-006) for this project is available.
<!--more-->

------
### Approaches

#### Minimum Cut
The core of our approach is to infer the signedness using minimum cut algorithm.
Imagine that we have a graph, in which each node is a variable, and we add an edge between node *A* to node *B* if variable *A* may have the same signedness as variable *B* (e.g. *A* and *B* are two operands of the same instruction.)
If we split such a graph to two parts, one involves all *signed* variables and another involves all *unsigned* ones, the edges we cut are where signedness casting happen.
And since developers prefer source code with a minimum number of casts, we would like to compute a [minimum cut]
(https://en.wikipedia.org/wiki/Minimum_cut)
between signed and unsigned variables, which corresponds to a minimal set of casts required for a legal typing.

#### Signedness Instructions
A graph can have multiple sets of minimum cuts if we don't have any other limitating factors.
To find the most accurate one, we would like to infer the signedness of as many variables as possible before we cut the graph.
We perform the first round of signedness inference based on heuristics about signedness instructions/operations.

A signedness instruction (operation) is an instruction that can reveal the signedness of its operands.
Bellow is a list of signedness instructions we collected.

- When performing **conditional jump**, signed variables use *jg* and *jl*, while unsigned variables use *ja* and *jb*.
- A signed variable is **right shifted** using arithmetic right shift.
- Variable using different **modulo and divide** instructions according to their signedness.

Using those signedness instructions, we can identify variables that are obviously signed/unsigned, and only compute minimum cuts between the of known signed group and known unsigned group.

### Implementation Details
As mentioned above, we perform static analysis to infer signedness.
To begin with, we disassemble binaries, and translate X86 assembly instrcutions to [Vine IR](http://bitblaze.cs.berkeley.edu/vine.html).
We than build a graph for each function of the binary, and perform minimum cut algorithm on it.

Since our goal is only to infer the type of variables, we simplify the data structure inference by using knowledges in debugging information directly.
For this purpose, all the binaries to analyze are compiled with -g option on,
and we parse debugging information using [libdwarf](https://www.prevanders.net/dwarf.html).
With the debugging information, we can associate each variable described in C to a location described in X86 assembly.

In practical, not only variables but also registers and memory locations are added to the graph as nodes.
Furthermore, since the same location can be either signed or unsigned at different time,
In addition, we also applies [static single assignment (SSA)](https://en.wikipedia.org/wiki/Static_single_assignment_form) in our analysis, which requires building a CFG for the analyzed binary.


### Evaluation
We evaluate this algorithm by erasing signedness information from debugging symbols, and testing how well our tool can recover it.
Applying an intra-procedural version of the algorithm to the GNU Coreutils, we observe that many variables are unconstrained as to signedness, but that it almost all cases our tool recovers either the type from the original source, or a type that yields the same program behavior.
Different signedness can compile to the same binary or different binaries with the same behavior

