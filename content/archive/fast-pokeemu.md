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
CPU emulators are widely used in various fields.
Developing an emulator is challenging because processors are complicated, and the emulator must follow all the architecture specification for software compatibility.
Since developers may change the emulator quite often (231 commits to the X86 translator per year on average), an effective automatic testing is desirable.
For high coverage test we need to run a large number of test cases.
Therefore, it is important to execute each test efficiently if we want to finish the full test in a reasonable amount of time.


[PokeEMU]
(https://people.eecs.berkeley.edu/~dawnsong/papers/2012%20Path%20Exploration%20Lifting%20Hi%20Fi%20Tests%20for%20Lo%20Fi%20Emulators.pdf)
 is a emulator testing framework that can detect bugs by comparing the behaviors of the tested emulator with KVM, which run most instructions using host hardware.
It currently only support Bochs and QEMU with X86-32bit target, but the same approach can be applied to other emulators with additional engineering efforts.
It generate tests by exploring Bochs with symbolic execution, and then run those tests on both OEMU and KVM, dump the final machine state in a memory dump and compare them.
This test involves 76510 test cases, and it takes approximately 150 CPU hours to finish the full test.
Among the 150 hours, it spend most time booting QEMU & making memory dump (529/583 ms according to our measurement.)
To improve the performance this PokeEMU, we would like to minimize this part of time.

### Approach
#### Aggregation
The general idea is that, instead of starting QEMU, run only ONE test and dump the machine state, we run a large number of tests.
With this change, we only start QEMU and run tests for 1078 times, much less than the previous 76510 times.
The simplest implementation of this idea would be just run a group of test cases on after another and compare the final machine state.
One problem of this simple approach is that outputs of one test case can be overwritten by following test cases.
As a workaround, we copy the output to unused memory before the next test case.
In practical, we group tests by the instruction it tests, and aggregate each group.

#### Looping
Another way to increase the efficiency of PokeEMU is to reuse test case code.
If we re-run each test for multiple times with different inputs, the total time for running a full test almost doesn't change, while the coverage of PokeEMU may further increase:
When generating test cases using symbolic execution, we only set a essential subset of the whole machine state to symbolic (otherwise the symbolic execution phase will take forever.)
Therefore we probably can further increase the coverage by running each test case for multiple times with different random inputs e.q. a fuzz testing.

##### Reusing memory space with the Feistel Construction
In PokeEMU, QEMU runs with only 4 MBs memory to save time, while still be able to explore all 4GB memory address of 32-bit CPU.
This design has became a problem when we combine aggregation and looping.
A test case is usually 100+ bytes without Feistel and 200+ bytes with Feistel.
And each time we rerun a test, it occupies another 12 - 30 bytes of memory space.
The later is the real problem, since it can keep eating up memory space as we increase the number of times we repeat each test.

To save space storing the outputs, we would like to find a way to compress those outputs, while avoid losing data.
This is similar to the requirement of block ciphers.
Therefore, we integrate the Feistel construction with the execution of tests.

Since the Feistel construction is a bijection no matter whether round functions are invertible, this structure can guarantee that two cipher text with the same input will be different if there is only one different round function and everything else are the same.
The probability that 2 cipher text equals increase as more round function differences, but still low if there is only a small number of behavior differences.

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
In this experiment we compared the testing results of vanilla PokeEMU (column 1), Fast PokeEMU without aggregation (column 2) and Fast PokeEMU (column 3.)
Most time the results of all three cases should be the same if there is no bug in Fast PokeEMU, but Fast PokeEMU may detect additional bugs.

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

#### Historical bug experiment
Previous experiment doesn't evaluate the effect of looping.
In this experiment, We try to figure out whether Fast PokeEMU can find more real-world bugs with looping turned on.
Since it requires additional effort to add (Fast) PokeEMU support to QEMU, currently we run this experiment on QEMU version 1.0 through 2.4.
Bellow is a list of historical bugs that can be detected by vanilla and Fast PokeEMU, and are fixed before version 2.4.

| Fix | Instruction | PokeEMU | Fast PokeEMU |
| -----------|:---------:|:---------:| ---------:|
| [321c535](https://github.com/qemu/qemu/commit/321c535) | BSF_GdEdR | * | * |
| | BSR_GdEdR | * | * |
| [dc1823c](https://github.com/qemu/qemu/commit/dc1823c) | BTR_EdGdM | * | * |
| | BTR_EdGdR |  | * |
| | BTR_EdIbR |  | * |
| | BTC_EdGdR |  | * |
| | BTC_EdIbR |  | * |
| | BT_EdGdR |  | * |
| | BT_EdIbR |  | * |
| | BTS_EdGdR |  | * |
| | BTS_EdIbR |  | * |
| [5c73b75](https://github.com/qemu/qemu/commit/5c73b75) | MOV_CdRd | * | * |
| | MOV_DdRd | * | * |
| | MOV_RdCd | * | * |
| | MOV_RdDd | * | * |

### Future work
We are implementing task switching for exception handling, which can significantly increase the number of valid tests that didn't work on Fast PokeEMU.
One major reason of errors in the effectiveness results is bug in Fast PokeEMU, and we would like to improve our tool by fixing those bugs.
In addition, we also would perform the historical bug experiment on a larger range of QEMU versions.

