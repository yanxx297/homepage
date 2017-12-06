+++
date = "2017-11-13T23:52:36-06:00"
title = "Fast PokeEMU"

+++

Software that emulates a CPU are widely used in various fields, but it is 
impossible to develop an emulator that works correctly without high coverage
testing.
Existing testing tools are either not fully automatic or not efficient enough 

to run a large number of tests required for extensive testing.
In this paper, we explore techniques for combining a large number of tests into
one program to reduce overheads such as booting emulators.
To save memory space while still be able to capture each bug with high
probability, we chain the output of one test case with the input of the next,
and integrate the Feistel construction with those tests so that each step is
invertible.
In addition, we further reuse code space by repeating each test case with 
randomly changed inputs.
We implement those techniques on PokeEMU, a tool that generates tests using
symbolic execution.
According to our evaluation, the improved PokeEMU run tests much faster, but
still can capture most different behaviors detected by original PokeEMU.
