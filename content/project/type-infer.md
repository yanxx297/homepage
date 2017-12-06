+++
date = "2017-11-13T19:25:24-06:00"
title = "Type Inference"

+++

Recovering variable types or other structural information from binaries is useful for reverse engineering in security, and to facilitate other kinds of analysis on binaries.
However such reverse engineering tasks often lack precise problem definitions; 
some information is lost during compilation, and existing tools can exhibit a variety of errors.  
As a step in the direction of more principled reverse engineering algorithms, we isolate a sub-task of type inference, namely determining whether each integer variable is declared as signed or unsigned.   
The difficulty of this task arises from the fact that signedness information in a binary, when present at all, is associated with operations rather than with data locations.  
We propose a graph-based algorithm in which variables represent nodes and edges connect variables with the same signedness.   
In a program without casts or conversions, signed and unsigned variables would form distinct connected components, but when casts are present, signed and unsigned variables will be connected.   
Reasoning that developers prefer source code without casts, we compute a minimum cut between signed and unsigned variables, which corresponds to a minimal set of casts required for a legal typing.   
We evaluate this algorithm by erasing signedness information from debugging symbols, and testing how well our tool can recover it.   
Applying an intra-procedural version of the algorithm to the GNU Coreutils, we observe that many variables are unconstrained as to signedness, but that it almost all cases our tool recovers either the type from the original source, or a type that yields the same program behavior.
