+++
date = "2016-09-01"
title = "Fast PokeEMU"

+++
PokeEMU is a automatic emulator testing tool with high coverage, while it is less practical considering the hundreds of CPU hours it takes for one full test.
To improve PokeEMU, we explore techniques for combining many tests into one program to amortize overheads such as booting an emulator (*aggregating*),
and reuse each test repeatly with random inputs (*looping*).
To ensure the results of each test are reflected in a final result, we use the outputs of one instruction test as an input to the next, 
and adopt the [Feistel network](https://en.wikipedia.org/wiki/Feistel_cipher) construction from cryptography so that each step is invertible.
<!--more-->

------
Software that emulates a CPU are widely used in various fields, but it is impossible to develop an emulator that works correctly without high coverage testing.
Since a large number of test cases are required for full coverage, it
is important that the tests execute efficiently.

Existing testing tools are either not fully automatic or not efficient enough to run a large number of tests required for extensive testing.
### Motivation
#### Emulators
- def: software running on one platform (host) to provide another platform (guest)
- VMware, Virtualbox, QEMU, etc
- application
    - software developing (e.g. ARM CPU, widely used by android phones )
    - isolation (e.g. malware detecting)

#### Developing an Emulator is challenging
- because processors are complicated, and the emulator must follow all the arch specification for software compatibility
- Effective automatic testing is desirable
    - Effectiveness: overnight testing
        - 231 commits per year to the software translator part of QEMU according to is git repo
    - high coverage

### PokeEMU
PokeEMU is a emulator testing framework that can detect bugs by comparing the behaviors of the tested emulator with KVM(run most insn using host hardware).
Currently only support QEMU & X86 32bit, but can add support to other emulators with minor work.
It generate tests by exploring Bochs (a highly reliable but slow emulator) with symbolic execution, and then run those tests on both OEMU and KVM, dump the final machien state in a memdump and compare them.
- a testcase := set parameters + run the instruction
    - 76510 test cases in total
- 4 MBs memory to save time, while still be able to explore all 4GM memory address of 32-bit CPU

- Bochs, QEMU, KVM

#### Cause of slowness
spend most time booting QEMU & making memory dump
529/583 ms according to our measurement

### Approach
#### Aggregation
The general idea is that, instead of starting QEMU, run only ONE test and dump the machine state, we run a large number of tests.
With this change, we only start QEMU and run tests for 1078 times v.s. 76510 times.

##### Simplest
The simplest implementation of this idea would be just run a group of test cases on after another and compare the final machine state.
One problem of this simple approach is that outputs of one test case can be overwritten by following test cases.
As a workaround, we copy the output to unused memory before the next test case.

Another problem of this simple solution is that memory usage increase as we aggregate more test cases, while we only have 4 MBs.
- output
- test case code

We would like to handle both of those 2 source of memory cost

##### Reusing memory space with the Feistel Construction
To save space storing the outputs, we would like to find a way to compress those outputs, while avoid losing data.
This is similar to the requirement of block ciphers.
we integrate the Feistel construction with aggregated tests.

The Feistel construction is a structure widely used in cryptography, used by block ciphers include DES and RC5.
In Feistel construction, the data to be encrypt is split to two blocks of the same size (R & L blocks), and do the following conmupation for several rounds

- Li+1 = Ri
- Ri+1 = Li⊕Fi(Ri)

where F_i is the round functioin. 
Since Feistel construction is a bijection no matter whether round functions are invertible or not, this structure can guarantee that two ciphertext with the same input will be different if there is only one different round function and everything else are the same.
The prob that 2 ciphertext equals increase as more round func diffs, but still low if there is a small number of ...

In out implementation of Feistel aggregation testcase, the R_0 corresponds to the input of the first test case, and each tested instruction (with different paramter) corresponds to a round function. 
After the 1st round, we use the Feistel ciphertext as the input to the next test case, and repeat this operation for all following rounds.

In practical, we group tests by the insn it tests, and aggregate each group.
 
##### code reusing
Outputs is in fact not the largest source of memory cost.
e.g. 12 - 30 bytes.
But a test case is usually 100+ bytes without Feistel and 200 more bytes with Feistel. 
It may be a good idea to also reuse the code.

When generating test cases using symbolic execution, we only set a essential subset of the whole machine state (to limit the number of tests).
Therefore we probably can further incresae the coverage by running each testcase for multiple times with different random inputs e.q. a fuzz testing.
Thanks to the Feistel construction, we don't need another random number generator, since Feistel itself provide some level of randomness:
If all the round functions are pseudorandom (which is unfortunately not true in our case), the Feistel cipher is also pseudorandom.

Note that although code is bigger than outputs, it doesn't increase with loop count.
And the outputs (which DO increase with loop count without Feistel) only take a fix amount of space.  
That's how Feistel save a large amount of mem space.

#### Implementation Challenge of Feistel Constructions
More complicated test cases leads to more problems
- detect the input & output of the tested insn (automatically)
    - Intel XED: a encoder & decoder lib
- diff in code other than the one we want to test
- Exceptions become a problem    

### Experiment & Evaluation
| Mode | Total time (s) | Time per test (ms) |
| -----------|:---------:| ---------:|
| Separate  | 84871.8   | 583.528   |
| Simple    | 334.7     | 2.313     |
| Feistel   | 345.0     | 2.448     |
| Loop (1)  | 345.17    | 2.672     |
| Loop (10000)| 1635.45 | 0.002     |

|Separated result | Separated result with extra code | Aggregated result |# of instructions |
| -----------|:---------:|:---------:| ---------:|
|	Match     | Match    	| Match		| 577 |
|	Mismatch  | Mismatch 	| Mismatch 	| 273 |
|	Match     | Match	| Mismatch 	| 8 |
|	Match     | Mismatch    | Match		| 10 |
|	Match     | Mismatch	| Mismatch 	| 28 |
|	Mismatch  | Match    	| Match		| 25 |
|	Mismatch  | Match 	| Mismatch 	| 28 |
|	Mismatch  | Mismatch    | Match		| 9 |

Symbolic execution: We use FuzzBALL becuase KLEE is source based 

### Future work
#### fix bugs
#### More evaluations

---
### Appendix (hidden slides)
#### Classic PokeEMU Memory structure
- 3 level paging
- 1024 PDE, all of with point to the same page table (which contains 1024 PTE), so that it can cover all 4 GBs memory address using 4 MBs

#### detail of tests generation using symbolic execution
- Symbolic Execution    
    - def: replace concrete values with symbolic variables and execute the binary with those sym vals, so that the output are symbolic expressions; 
    - if branch, one expression for each path, 2^(branch number) experssions in total
- Example: For each instruction variation (1078 in total), set mahcine state to symbolic and explore
