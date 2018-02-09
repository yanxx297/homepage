+++
date = "2015-09-01"
title = "Loop Summarization"

+++

Path explosion is one of the most challenging issues of symbolic execution, and loops can cause this problem very often.
To mitigate this problem, previous work has introduces various algorithms to generate a summarization of a loop
instead of executing it ever time.
Among those algorithms we chose SAGE's [trace based loop summarizaion algorithm](https://patricegodefroid.github.io/public_psfiles/issta2011.pdf)
and implement a execution based version of it on [FuzzBALL](http://bitblaze.cs.berkeley.edu/fuzzball.html).
This project is supported by a grant under DARPA CGC program.
<!--more-->

------

### Motivation
Despite that the loop summarization code was turned off in the actual competition,
this project is supposed to be part of the [FuzzBOMB](http://www.sift.net/research/artificial-intelligence/fuzzbomb),
an automatic vulnerability detecting & reparing system based on AI and symbolic execution.
To trigger certain types of bugs, adversaries use loops very often.
e.g. keep writing to an array to triger buffer overflow.
Consequently, a bug finding tool cannot detect those vulnerabilities unless it can analyze loops.
However, FuzzBOMB relies on symbolic execution to detect vulnerabilities, while it is challenging for a symbolic execution tool to analyze loops since doing that can cause path explosion.
In order to detect bugs hidden in loops, we would like to mitigate the path explosion issue of FuzzBALL, the symbolic execution engine part of FuzzBOMB.

### What's New
We mostly follow the approach described in [Autonatic Partial Loop Summarization in Dynamic Test Generation]
(https://patricegodefroid.github.io/public_psfiles/issta2011.pdf)
while also adjust the algorithm according to the difference between SAGE and FuzzBALL.
SAGE is a trace based symbolic execution engine, while FuzzBALL generate symbolic expressions while executing the binary.
Therefore, the algorithm to build dynamic CFGs and detect loops still works, but we need to update CFGs as we execute new code.

In addition, we generate multiple summarizations for branching loops.
A branching loop is a loop with if statement or other types of branches in it.
When we enter a loop for the first time, we create the first summarization no mater whether it is a branching loop.
Then we decide whether to repeat this loop by a heuristic in [statically-directed dynamic automated test generation]
(http://bitblaze.cs.berkeley.edu/papers/testgen-issta11.pdf),
and attempt to find more branches if exist.
At the beginning of each iteration, we check whether the existing summarization applies this time by evaluating the pre-condition.
If the existing summarization doesn't work, we then generate another summarization.

We have done some preliminary evaluation of the loop summarization algorithm using CGC competition binaries (CBs).
To

### Ongoing work
Since the DARPA CGC has ended, we would like to
Instead of
evaluate with multi-OS CBs ported by
[Veritesting](https://users.ece.cmu.edu/~aavgerin/papers/veritesting-icse-2014.pdf)

