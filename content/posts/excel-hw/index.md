+++
authors = ["Giorgio Dell'Immagine"]
title = "Forget expensive hardware simulators, Microsoft Excel is all you need!"
date = "2024-10-19"
description = "Forget expensive hardware simulators, Microsoft Excel is all you need!"
tags = [
    "Excel",
    "Verilog",
    "Writeup"
]
math = true
+++


![asd](banner.png)
> **Fun fact** - The original experimentation spreadsheet was called `curso1` and was done in Google sheets. I nearly fused by PC twice running a heavy computation in the browser, and then I switched to Excel, which turns out is much more performant.

# The origin story
One day, I received a vocal message from a (probably drunk) [drw0if](https://x.com/drw0if) pitching me the idea of simulating hardware on Excel.
He explained to me some sort of circuit being run over a spreadsheet, potentailly being synthetized from a higher level HDL.
The idea was very silly, and we lacked ideas for upcoming CTF challenges, so we had to give it a shot!

The basic idea was simple: Excel can express quite easily combinatorial circuits.
Indeed, we can
- treat every wire as a cell,
- simulate logic gates by using formulas that reference other cells.

Fortunately, Excel comes with all the logic operators we wuold ever need in our lives, for example `AND`, `OR` and `NOT`!
Let's take this simple combinatorial verilog module: it just computes the negation of `a` and computes the conjunction with `b`.

```verilog
module example(a, b, out);
    input a, b;
    output out;

    assign out = ~a & b;
endmodule
```

We can easily convert it to an Excel spreadsheet.
The nice thing is that if we update the inputs, the output will be updated automatically, just like real hardware!

{{< rawhtml >}}
<img src="comb.gif" alt="DFF simulation" width="80%" class="dark" style="display:block;margin-left: auto;margin-right: auto;"/>
{{< / rawhtml >}}

Now, if you are following up until now I know what you are thinking: *boooooring*, we can just translate a circuit into an Excel formula and call it a day.
I promise, however, things will get interesting.

# Welcome, iterative computation

Iterative computation is a quite obscure feature of Excel. Normally, when trying to input formulas that have a reference cycle it will give an error, because there isn't anymore a clear data dependency between the cell values.
There is however one feature of Excel that is intended for computing things with iterative methods (like Newton't method for example), and can be enabled in the settings.

{{< rawhtml >}}
<img src="iterative.png" alt="DFF simulation" width="80%" class="dark" style="display:block;margin-left: auto;margin-right: auto;"/>
{{< / rawhtml >}}

The [calculation process](https://www.decisionmodels.com/calcsecretsc.htm) of Excel is quite straight forward in the normal case: all formulas references can be put into a dependency graph, and Excel will walk the dependency graph every time it needs to update something.
This enables only partial computation when some update only influences part of the formulas.
Also, Excel cleverly puts branches of this dependency graph into different threads to speed up the calculations.

What appens when **iterative computation** is enabled? There is no clear evaluation ordering anymore because there are cycles in the references (the dependency graph is not a DAG anymore), so Excel simply updates every cell with the current values, starting from the top row going left, then second row and so on.
Normally this process continues in a loop until either:
- the change of values between two iteration is less than some epsilon, or
- the iteration limit is reached.

For the rest of the post we will assume that the iteration number limit is set to `1`, so that Excel will do only one update at a time.

{{< notice tip >}}
A very nice trick to make Excel execute an update of the entire sheet while iterative computation is enabled is click on a random cell and press `Del`.
Excel will think that we just deleted something very important and will frantically update every cell in the sheet! 😆
{{< /notice >}}

{{< rawhtml >}}
<img src="iterative.gif" alt="DFF simulation" width="80%" class="dark" style="display:block;margin-left: auto;margin-right: auto;"/>
{{< / rawhtml >}}

# Synchronized hardware primitives

What happens for example when we say that a cell should be the negation of itself?
We get a nice **clock**!

{{< rawhtml >}}
<img src="clock.gif" alt="DFF simulation" width="80%" class="dark" style="display:block;margin-left: auto;margin-right: auto;"/>
{{< / rawhtml >}}

Do you see where this is going?
What we really want to achieve is having a working memory element in Excel to be able to run sequential logic with a clock!
In particular, we want to implement what's called a [D-Flip-Flop](https://en.wikipedia.org/wiki/Flip-flop_(electronics)#D_flip-flop), which has a clock and data inputs and one data output.
At the **rising edge** of the clock, it stores the current data input value, and it holds it until the next rising edge.
The truth table taken from Wikipedia is the following.

| Clock | D | Q_next |
|:---:|:---:|:---:|
Rising edge | 0 | 0
Rising edge | 1 | 1
Non-rising | X	| Q

The problem is: how to simulate the rising clock behavior?
Let's try to divide the clock cycle into micro-clocks, which are multiple discrete simulation steps doring which the main clock signal is not updated. The DFF will record the input value at the last micro-clock in which the clock signal is low, and will output the newly recorded value at the next micro-clock, which will be the first in which the clock is high.

{{< rawhtml >}}
<img src="block-diagram.svg" alt="DFF simulation" width="80%" class="dark" style="display:block;margin-left: auto;margin-right: auto;"/>
{{< / rawhtml >}}

This is implemented using a micro-clock counter and resolution. The clock signal updates only if the micro-clock counter is zero. The DFF will record the input value only if the clock signal is low, and the micro-clock value is the last one in the cycle.
In a circuit with multiple DFFs, every DFF is updated simultaneously in the same sheet update.

Using some Excel formulas, we can implement this behavior quite easily.
```py
clock_res = 10

# current micro-clock
micro_clk = MOD(micro_clk + 1, clock_res)

# clock is updated every clock_res micro-clocks
clk = IF(micro_clk = 0, NOT(clk), clk)

# DFF cell, updated only at the last micro-clock of low clk with data_in
dff = IF(AND(NOT(clk), micro_clk = clock_res - 1), data_in, dff)
```

Why does it have to be this complicated? Well, because in the end we want to simulate some sequential logic, with the input and output of DFFs feeding into each other in a loop.
It turns out that the ordering of the updates in Excel gives some weird glitching in a few occasions, so using this method ensures that all the inputs are sampled at the same sheet update.
Of course, if some inputs in the circuit change at this last micro-clock then we could have inconsistent behavior, but we will make the assumption that the network has stabilized before the last micro-clock.
Of course, we should choose a clock resolution that is small enough to capture the behavior of the circuit, but not too small to make the simulation slow.


# From Verilog to Excel

So far we have the following building blocks:
- a clock signal,
- the ability to simulate combinatorial logic,
- the ability to place DFFs in the circuit.

In principle, now we are ready to write a Verilog program, synthesize it into a netlist, and then convert the netlist into an Excel spreadsheet.
Fortunately this is way easier than I thought it would be thanks to [yosys](https://github.com/YosysHQ/yosys), an open source synthesis suite that can convert Verilog into a netlist.
This is also very similar to what Zellic have done in their [MPC from scratch](https://www.zellic.io/blog/mpc-from-scratch/) article, which I recommend checking out!

Let's write a `primitives.lib` file, which basically describes the set of hardware primitives we have available in the hardware (Excel).
We will support `NAND`, `NOR`, `NOT`, and `DFF` primitives.

```txt
library(demo) {
  cell(NOT) {
    area: 3;
    pin(A) { direction: input; }
    pin(Y) { direction: output;
              function: "A'"; }
  }
  cell(BUF) {
    area: 6;
    pin(A) { direction: input; }
    pin(Y) { direction: output;
              function: "A"; }
  }
  cell(NAND) {
    area: 4;
    pin(A) { direction: input; }
    pin(B) { direction: input; }
    pin(Y) { direction: output;
             function: "(A*B)'"; }
  }
  cell(NOR) {
    area: 4;
    pin(A) { direction: input; }
    pin(B) { direction: input; }
    pin(Y) { direction: output;
             function: "(A+B)'"; }
  }
  cell(DFF) {
    area: 18;
    ff(IQ, IQN) { clocked_on: C;
                  next_state: D; }
    pin(C) { direction: input;
                 clock: true; }
    pin(D) { direction: input; }
    pin(Q) { direction: output;
              function: "IQ"; }
  }
}
```

Then we can write a synthesizer script that will convert a generic Verilog code into another Verilog code, but only using the hardware primitives we have available.

```sh
# read design
read_verilog input.v
hierarchy -check
synth -auto-top -flatten
proc_prune

# high-level synthesis
proc; opt; fsm; opt; memory; opt

# low-level synthesis
techmap; opt

# map to target architecture
dfflibmap -liberty ../yosys-lib/primitives.lib
abc -liberty ../yosys-lib/primitives.lib


splitnets -ports; opt
setundef -zero -undriven -init
clean

# write synthesized design
write_verilog output.v
```

This script will take a `input.v` file, synthesize it into a netlist using the primitives we have available, and then write the result into `output.v`, which will look something like this.

{{< rawhtml >}}
<img src="sinth.gif" alt="DFF simulation" width="80%" class="dark" style="display:block;margin-left: auto;margin-right: auto;"/>
{{< / rawhtml >}}

Now, we can just convert that verilog file straight into Excel using a straight forward Python script, by assigning each wire to a cell, and implementing logic and memory gates.
If enough people are interested we can release the conversion script, but it's quite straight forward to implement.

# The epilogue

Our original idea was to create a CTF challenge where the participants would have to reverse engineer a circuit from an Excel spreadsheet.
We wrote a simple flag checker, tested that it worked fine, added a bit of styling, and this was the result.

{{< rawhtml >}}
<img src="sheet.webp" alt="DFF simulation" width="50%" class="dark" style="display:block;margin-left: auto;margin-right: auto;"/>
{{< / rawhtml >}}

We tested this method on a circuit that had around 14k wires when synthetized, and was running for 550 clock cycles more or less.
Running the flag checker takes about 4 minutes on my machine, which is quite a lot for only a few clock cycles, but it's still manageable.
You can download the original attachment [here](https://github.com/fibonhack/MOCA-2024-finals-challs/tree/main/misc/curso1/attachments).

The funny thing is that nobody in our team was able to solve it, even after some hints.
With the optimizaions and reorderings done by yosys, it was *very* hard to reverse engineer the circuit from the spreadsheet.
We ended up releasing as a meme challenge, explicitly saying to the participants that this was a meme challenge and that they should not waste a huge amount of time on it.
Unsurprisingly, no teams managed to solved it, so I guess there is a limit to the cursedness of a challenge! 😆

