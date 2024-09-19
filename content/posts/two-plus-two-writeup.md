+++
authors = ["Giorgio Dell'Immagine"]
title = "MOCA CTF finals 2024 - 2+2=5 writeup"
date = "2024-09-18"
description = "MOCA CTF finals 2024 - 2+2=5 writeup"
tags = [
    "zkvm",
    "Jolt",
    "Writeup"
]
math = true
+++

Last weekend, together with my team we hosted a [CTF event](https://ctftime.org/event/2294) for the MOCA hacker camp.
It was a great event, and I managed to write two challenges.
One of them was about [Jolt](https://jolt.a16zcrypto.com/), a RISC-V based zkvm.

The overall idea while creating the challenge was to
- clone the Jolt repository
- remove some random line
- make players prove that $2+2=5$ (as the name implies!)

I thought that this could be a challenge with a quite funny theme, and in the end I think it came out pretty instructive as well!

# Challenge description

The complete challenge sources will be released in a few days, I will update the page to lik them.

The challenge attachments come with a couple of files

```sh
$ ls
diff.patch  Dockerfile  jolt  readme.txt  server
```

In particular the `readme.txt` file pretty much explains how we get the `jolt` folder.

```sh
git clone git@github.com:a16z/jolt.git
cd jolt

# just the latest commit at time of writing
git checkout 0cc7aa31981ff8503fe256706d2aa9c320abd1cd
git apply ../diff.patch
```

A patch has been applied to the Jolt zkvm, which is contained in `diff.patch`.
The patch removes a few of lines from the `jolt-core/src/r1cs/jolt_constraints.rs` file
```patch
diff --git a/jolt-core/src/r1cs/jolt_constraints.rs b/jolt-core/src/r1cs/jolt_constraints.rs
index 5fb0d871..295dce32 100644
--- a/jolt-core/src/r1cs/jolt_constraints.rs
+++ b/jolt-core/src/r1cs/jolt_constraints.rs
@@ -289,13 +289,8 @@ impl<F: JoltField> R1CSConstraintBuilder<F> for UniformJoltConstraints {
 
         // if (rd != 0 && update_rd_with_lookup_output == 1) constrain(rd_val == LookupOutput)
         // if (rd != 0 && is_jump_instr == 1) constrain(rd_val == 4 * PC)
-        let rd_nonzero_and_lookup_to_rd =
+        let _rd_nonzero_and_lookup_to_rd =
             cs.allocate_prod(JoltIn::Bytecode_RD, JoltIn::OpFlags_LookupOutToRd);
-        cs.constrain_eq_conditional(
-            rd_nonzero_and_lookup_to_rd,
-            JoltIn::RD_Write,
-            JoltIn::LookupOutput,
-        );
         let rd_nonzero_and_jmp = cs.allocate_prod(JoltIn::Bytecode_RD, JoltIn::OpFlags_IsJmp);
         let lhs = JoltIn::Bytecode_ELFAddress + (PC_START_ADDRESS - PC_NOOP_SHIFT);
         let rhs = JoltIn::RD_Write;
```

### The guest

The guest program is just a Rust program that computes $2+2$, and returns the result.
How hard could it be (I thought to myself)?
Well, I really wanted the guest program to do **only** two things:
- compute $2 + 2$
- return the result.

Ideally, the program would compile to an `add` instruction and a return.
To avoid optimizations, the guest is sligtly cursed.
I tried a bunch of other stuff, but the compiler was always smart enough to optimize out the `add` instruction, in the end I had to resort to unsafe inline assembly.
Jolt also needs to build the guest binary in x86-64, so the inline assembly needs to be multiarch!
All those things lead to the following overly complicated guest program 😀

```rust
#![cfg_attr(feature = "guest", no_std)]
#![no_main]

#[jolt::provable]
fn two_plus_two() -> u16 {
    let mut n: u16 = 2;

    #[cfg(any(target_arch = "riscv32", target_arch = "riscv64"))]
    unsafe {
        core::arch::asm!(
            "li {n}, 2",
            "add {n}, {n}, {n}",
            n = inout(reg) n,
        );
    }

    #[cfg(target_arch = "x86_64")]
    unsafe {
        core::arch::asm!(
            "mov {n}, 2",
            "add {n}, {n}, {n}",
            n = inout(reg) n,
        );
    }
    n
}
```
### The server

The server is just a Rust project which uses the patched Jolt crate to verify an execution proof for the guest, checking that the claimed output is 5 (indeed we are trying to prove that $2+2=5$)
If the user provides a valid proof with output 5, then the server will return the flag.

```rust
use jolt_sdk::RV32IHyraxProof;

pub fn main() {
    let (_prove_two_plus_two, verify_two_plus_two) = guest::build_two_plus_two();

    println!("Can you prove that 2+2=5?");

    let line = std::io::stdin().lines().next().unwrap().unwrap();
    if line.len() == 0 {
        println!("k thx bye");
        return;
    }

    let proof = RV32IHyraxProof::deserialize_from_bytes(&hex::decode(line).unwrap()).unwrap();

    let inputs = &proof.proof.program_io.inputs;
    println!("inputs: {:?}", inputs);
    assert_eq!(inputs.len(), 0);

    let outputs = &proof.proof.program_io.outputs;
    println!("outputs: {:?}", outputs);
    assert_eq!(outputs.len(), 1);
    assert_eq!(outputs[0], 5); // 2+2 is 5!

    let panics = &proof.proof.program_io.panic;
    println!("panics: {:?}", panics);
    assert!(!panics);

    println!("Verifying the proof...");
    let is_valid = verify_two_plus_two(proof);
    if is_valid {
        println!("The proof is valid!");
        println!("FLAG: {}", std::env::var("FLAG").unwrap());
    } else {
        println!("The proof is invalid! :(");
    }
}
```

TL;DR: to solve the challenge we need to provide a proof of execution of the guest program with output 5, exploiting the fact that Jolt has been patched and possibly not sound anymore.


# Jolt architecture

An overview of the architecture of Jolt is given in the [documentation](https://jolt.a16zcrypto.com/how/architecture.html), but I will briefly recp it here.
There are four main components that are interconnected for the overall execution checks.

- **Read-Write memory** which uses a memory checking argument to check that accesses to the registers and in memory are correct.
- **Instruction lookup** which uses a custom lookup argument called Lasso to check that the executions of the instructions are correct, e.g., that the result of the execution of an `add` instruction really is the sum of the operands.
- **Bytecode** which uses a read-only lookup argument to perform reads into the decoded instructions.
- **R1CS** which handle program counter updates, and serves as a glue for all the other modules.

The patch is in the R1CS component, let's look at the constraint that was removed

```c
cs.constrain_eq_conditional(
    rd_nonzero_and_lookup_to_rd,
    JoltIn::RD_Write,
    JoltIn::LookupOutput,
);
```

The function `constrain_eq_conditional` adds to the R1CS constraint system an equality of the second and third argument, if the first argument is set to 1.
Roughly, the emitted constraint is
```c
cs.constrain_eq_conditional(condition, left, right);
// condition  * (left - right) == 0
```

There is also a useful comment explaining the removed constraint
```c
// if (rd != 0 && update_rd_with_lookup_output == 1) constrain(rd_val == LookupOutput)
```
An intuitive explaination is the following: the value written in the output register should be equal to the result of the execution lookup argument, if the instruction is supposed to write its result into a register and if the output register is not zero.

With this constraint removed the exploitation idea is very simple: craft an execution trace in which the `add` instruction which sums 2 and 2, instead of writing back in the output register the value 4 writes the value 5.
In the trace:
- the lookup argument will return 4, as it is an `add` and the operands values are 2 and 2, but
- the written value in the output register will be 5 in the trace.

The constraint which imposes that these two values need to be equal has been removed, so the trace will be accepted!


# Crafting the proof

Once we understand all the moving parts, the exploitation is actually quite simple: we just need to patch Jolt in the `tracer` module, which is the module that generates the execution trace.
We modify the `jolt/tracer/src/emulator/cpu.rs` file, changing the semantics of the `ADD` operation emulation: if the operands are both 2 then write back in the output register the value 5.

```rust
    Instruction {
        mask: 0xfe00707f,
        data: 0x00000033,
        name: "ADD",
        operation: |cpu, word, _address| {
            let f = parse_format_r(word);
            // originally just
            // cpu.x[f.rd] = cpu.sign_extend(cpu.x[f.rs1].wrapping_add(cpu.x[f.rs2]))
            if cpu.x[f.rs1] == 2 && cpu.x[f.rs2] == 2 {
                cpu.x[f.rd] = cpu.sign_extend(5);
            } else {
                cpu.x[f.rd] = cpu.sign_extend(cpu.x[f.rs1].wrapping_add(cpu.x[f.rs2]));
            }
            Ok(())
        },
        disassemble: dump_format_r,
        trace: Some(trace_r),
    },
```

One insteresting thing we can do is print out the execution trace, at the exact step in which the `add {n}, {n}, {n}` instruction is executed:
```rust
Trace[5]
JoltTraceStep {
    instruction_lookup: Some(ADD(ADDInstruction(2, 2))),
    bytecode_row: BytecodeRow {
        address: 2147483672,
        bitflags: 17448304640,
        rd: 10,
        rs1: 10,
        rs2: 10,
        imm: 0,
        virtual_sequence_remaining: None
    },
    memory_ops: [Read(10), Read(10), Write(10, 5), Read(0), Read(0), Read(0), Read(0)]
}
```
The main bit to notice here are the memory operations: there are two read operations (for the add operands), and a write operation to the same register with value 5!
This is one way of approaching the challenge, but actually the removal of that constraint gives a much more powerful primitive: we can write arbitrary values into registers for each instruction which writes back its result into a register!

Putting it all together, the main solver Rust program is quite straight forward (using the modified Jolt library)

```rust
use jolt_sdk::RV32IHyraxProof;

pub fn main() {
    let (prove_two_plus_two, verify_two_plus_two) = guest::build_two_plus_two();
    let (output, proof_gen) = prove_two_plus_two();
    println!("Proof generated! {}", output);
    let proof_bytes = proof_gen.serialize_to_bytes().unwrap();
    println!("{}", hex::encode(&proof_bytes));
}
```

Of course sending the generated proof to the server gives back the flag
```txt
MOCA{k1dding_m3?_tw0_p1u5_tw0_1s_f0ur_WTF!!?!}
```

In the end, only one team managed to solve it during the CTF, so congrats guys!