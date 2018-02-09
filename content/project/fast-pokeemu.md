+++
date = "2016-09-01"
title = "Fast PokeEMU"

+++
PokeEMU is a automatic emulator testing tool with high coverage, while it is less practical considering the hundreds of CPU hours it takes for one full test.
To improve PokeEMU, we explore techniques for combining many tests into one program to amortize overheads such as booting an emulator (*aggregating*),
and reuse each test repeatly with random inputs (*looping*).
To ensure the results of each test are reflected in a final result, we use the outputs of one instruction test as an input to the next,
and adopt the [Feistel network](https://en.wikipedia.org/wiki/Feistel_cipher) construction from cryptography so that each step is invertible.
A [paper](vee18-fast-pokeemu.pdf) of this work has been accepted by [VEE'18](https://conf.researchr.org/home/vee-2018).
<!--more-->

------
### Motivation
Software that emulates a CPU are widely used in various fields, but it is impossible to develop an emulator that works correctly without high coverage testing.
Since a large number of test cases are required for full coverage, it is important that the tests execute efficiently.

Developing an Emulator is challenging because processors are complicated, and the emulator must follow all the architecture specification for software compatibility.
Since developers may change the emulator quite often (231 commits to the X86 translator per year on average), an effective automatic testing is desirable.

[PokeEMU]
(https://people.eecs.berkeley.edu/~dawnsong/papers/2012%20Path%20Exploration%20Lifting%20Hi%20Fi%20Tests%20for%20Lo%20Fi%20Emulators.pdf)
 is a emulator testing framework that can detect bugs by comparing the behaviors of the tested emulator with KVM(run most insn using host hardware).
Currently only support Bochs and QEMU with X86-32bit target, but can add support to other emulators.
It generate tests by exploring Bochs with symbolic execution, and then run those tests on both OEMU and KVM, dump the final machien state in a memdump and compare them.
It takes approximately 150 CPU hours for a full test, which involves 76510 test cases.
It spend most time booting QEMU & making memory dump (529/583 ms according to our measurement.)

### Approach
#### Aggregation
The general idea is that, instead of starting QEMU, run only ONE test and dump the machine state, we run a large number of tests.
With this change, we only start QEMU and run tests for 1078 times, much less than the previous 76510 times.
The simplest implementation of this idea would be just run a group of test cases on after another and compare the final machine state.
One problem of this simple approach is that outputs of one test case can be overwritten by following test cases.
As a workaround, we copy the output to unused memory before the next test case.
In practical, we group tests by the insn it tests, and aggregate each group.

#### Looping
Another way to increase the effeciency of PokeEMU is to reuse test case code.
If we re-run each test for multiple times with different inputs, the total time for running a full test almost doesn't change, while the coverage of PokeEMU may further increase:
When generating test cases using symbolic execution, we only set a essential subset of the whole machine state (to limit the number of tests).
Therefore we probably can further incresae the coverage by running each testcase for multiple times with different random inputs e.q. a fuzz testing.

##### Reusing memory space with the Feistel Construction
In PokeEMU, QEMU runs with only 4 MBs memory to save time, while still be able to explore all 4GM memory address of 32-bit CPU.
This design has became a problem when we combine aggregation and looping.
A test case is usually 100+ bytes without Feistel and 200 more bytes with Feistel.
And each time we rerun a test, it spends another 12 - 30 bytes.
The later is the real problem, since it can keep eating up memory space as we increase the number of times we repeat each test.

To save space storing the outputs, we would like to find a way to compress those outputs, while avoid losing data.
This is similar to the requirement of block ciphers.
Therefore, we integrate the Feistel construction with the execution of tests.

Since Feistel construction is a bijection no matter whether round functions are invertible or not, this structure can guarantee that two ciphertext with the same input will be different if there is only one different round function and everything else are the same.
The prob that 2 ciphertext equals increase as more round func diffs, but still low if there is a small number of ...

### Evaluation
#### Performance
| Mode | Total time (s) | Time per test (ms) |
| -----------|:---------:| ---------:|
| Separate  | 84871.8   | 583.528   |
| Simple    | 334.7     | 2.313     |
| Feistel   | 345.0     | 2.448     |
| Loop (1)  | 345.17    | 2.672     |
| Loop (10000)| 1635.45 | 0.002     |

#### Effectiveness
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

### Future work
We have implemented task switching for exception handling, which can significantly increase the number of valid tests that didn't work on Fast PokeEMU.
One major reason of errors in the effectiveness results is bug in Fast PokeEMU, and we would like to improve our tool by fixing those bugs.
In addition, we also would like to evaluate Fast PokeEMU using real work bugs.
Specifically, we would like to figure out whether Fast PokeEMU can reveal historical bugs of QEMU.
