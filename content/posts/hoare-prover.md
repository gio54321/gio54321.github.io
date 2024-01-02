+++
authors = ["Giorgio Dell'Immagine"]
title = "A simple Hoare triple prover"
date = "2020-02-06"
description = "How I created a simple automatic Hoare triple prover using python."
tags = [
    "Logic",
    "Hoare logic",
    "Python",
]
math = true
+++


# Introduction: what is Hoare logic?
According to Wikipedia:
> Hoare logic (also known as Floyd–Hoare logic or Hoare rules) is a formal system with a set of logical rules for reasoning rigorously about the correctness of computer programs.

So this is a powerful system that lets us reason **formally** about the correctness of our program. The basic structure of Hoare logic is the **Hoare triple**. A triple describes how some properties of the state are modified by the execution of a program. A triple has the form of

$$ \lbrace P \rbrace \medspace C \medspace \lbrace Q \rbrace$$

where $P$ and $Q$ are assertions and $C$ is a program. $P$ is called **precondition** and $Q$ is called **postcondition**. A triple is said to be **valid** if, for each state that satisfies the precondition, the program **terminates** and the resulting state satisfies the postcondition.

As an example, take this triple ("$:=$" is the *assignment* operator):

$$\lbrace x=0\rbrace \medspace x:=x+1 \medspace \lbrace x=1\rbrace$$

the triple is valid because if before the execution it holds that $x=0$, then after the execution of the assignment command the assertion $x=1$ will hold as well.
An important condition for the validity of a triple is the termination, but since the command is an assignment, it always terminates.
There is a subtle edge case to this rule: when we have an expression on the right-hand side that has no evaluation, like $x/0$, the program will not terminate.
For simplicity, we will just assume that the program we will write will never try to evaluate an undefined expression, but in a real prover, this kind of thing have to be taken into consideration.

Take another triple:

$$\lbrace x=A \land y=B \rbrace \medspace z:=x; x:=y; y:=z \medspace \lbrace x=B \land y=A\rbrace$$

this is a variable swap, notice that this triple is completely **parametric**, as it uses two constants ($A$ and $B$) that are just symbols. In some sense, proving the validity of this triple is equivalent to proving the validity of an infinite number of triples, given by the instantiation of $A$ and $B$.

But we can have even more complicated triples, such as

$$\lbrace s=\sum_{k=0}^i k^2 \rbrace \medspace i:=i+1;s:=s+i*i \medspace \lbrace s=\sum_{k=0}^i k^2 \rbrace$$

or another one

$$\lbrace n \geq 1\rbrace \newline \text{while}(n \neq 1) \text{do if} (n \text{ mod } 2 = 0) \text{ then } n:=n/2\text{ else } n:= 3n+1 \text{ endif endwhile} \newline \lbrace n=1\rbrace$$

apart from the *slightly* cursed typesetting, you may have recognized this triple, as it is valid if and only if the Collatz conjecture is true. Also, this is an example where proving just the termination of the command is very important and not trivial at all: indeed managing to prove the termination is sufficient for proving the entire triple.

## What is an inference rule?

An inference rule is a very important concept in logic, that is the core for describing deduction systems. An inference rule is something of the form

$$\frac{\phi_1 \quad \phi_2 \quad \phi_3 \quad \dots \quad \phi_n}{\phi}$$

where $\phi_1 \dots \phi_n$ are the premises and $\phi$ is the conclusion. This can be read in two ways:

1. if $\phi_1 \dots \phi_n$ are all valid formulas, then we can infer (or derive) the formula $\phi$
2. to prove $\phi$ it is sufficient to prove that $\phi_1 \dots \phi_n$ are all valid formulas.

For our purpose, the second interpretation is what fits the best, so keep in mind this intuition behind inference rules.

An **axiom** is just an inference rule with no premises, so if $\psi$ is an axiom we will write

$$\frac{}{\psi}$$

Examples of inference rules in classical propositional calculus are

$$\frac{A \land B}{A}\quad (\land \text{ elimination})$$

$$\frac{A \to B \quad \neg B }{\neg A}\quad \text{(Modus Tollens)}$$

For example, the last one in our interpretation is read "to prove that $\neg A$ is valid it is sufficient to prove that $A \to B$ and $\neg B$ are both valid".

# A proof system for Hoare triples

We will discuss one of the possible formalizations of Hoare logic, applied to a toy programming language, that supports assignments, conditionals and while loops.

### Axioms

Let's start with some axioms: these are basic triples that are always valid.
The first axiom is the empty command axiom (or skip axiom):

$$\frac{}{\lbrace P\rbrace \medspace \text{skip} \medspace \lbrace P \rbrace} \quad (\text{SKIP-AX})$$

where $P$ is an arbitrary assertion and $\text{skip}$ is the empty command (aka *nop*). The intuition behind this axiom is that if a certain condition holds before the skip statement, then it will also hold after the execution because skip does not modify the state and always terminates.

The second axiom is the assignment axiom:

$$\frac{}{\lbrace P[x \mapsto E]\rbrace \medspace x:=E \medspace \lbrace P \rbrace}\quad (\text{ASSIGNMENT-AX})$$

where $P[x \mapsto E]$ means that we take the assertion $P$, replacing all the occurrences of $x$ with $E$. The intuition behind this axiom is that if an assertion must hold after the assignment statement, then it must hold also before the statement, but with the assigned identifier substituted by the expression.

### Basic inference rules

Now, let's talk about some serious stuff: inference rules. The first one is pretty straightforward, and it is the pre-post rule:

$$\frac{P\to P' \quad \lbrace P'\rbrace \medspace C \medspace \lbrace Q'\rbrace \quad Q' \to Q}{\lbrace P\rbrace \medspace C \medspace \lbrace Q \rbrace}\quad \text{(PRE-POST)}$$

The intuition behind this rule is that we can strengthen the precondition and we can weaken the postcondition at our will.
This rule is really important because with this and the two axioms we can derive the second and the third inference rules:

$$\frac{P \to Q}{\lbrace P \rbrace \medspace \text{skip}\medspace \lbrace Q\rbrace}\quad (\text{SKIP})$$

$$\frac{P \to Q[x \mapsto E]}{\lbrace P \rbrace \medspace x:=E \medspace \lbrace Q\rbrace}\quad (\text{ASSIGNMENT})$$

The next rule is the composition rule (or sequence rule):

$$\frac{\lbrace P \rbrace \medspace C_1 \medspace \lbrace R\rbrace \quad \lbrace R\rbrace \medspace C_2 \medspace \lbrace Q\rbrace }{\lbrace P\rbrace \medspace C_1;C_2 \medspace \lbrace Q\rbrace}\quad (\text{COMPOSITION})$$

The intuition behind this rule is that if it can be found an intermediate assertion (in this case $R$) so that the two single triples are valid, then the whole triple is also valid.

### Contditional and while rules

Now let's discuss the most involved rules: the if and the while rules. Let's start with the conditional one:

$$\frac{ \lbrace P \land E \rbrace \medspace C_1 \medspace \lbrace Q \rbrace  \quad  \lbrace P \land \neg E \rbrace \medspace C_2 \medspace \lbrace Q \rbrace }{ \lbrace P \rbrace \medspace \text{if } E \text{ then } C_1 \text{ else } C_2 \medspace \lbrace Q \rbrace }\quad (\text{IF})$$

The intuition behind this rule is that we have to prove the triple both in the case that the guard is satisfied and in the case that it is not satisfied so that in the general case the triple holds. This is *morally* the same as the proof by cases in propositional calculus:

$$\frac{P \to Q \quad \neg P \to Q}{Q}\quad \text{Proof by cases}$$

Let's now talk about the while rule. First, let's see it so that we can then break it down piece by piece:

$$\frac{\begin{gathered} P \to \text{inv} \quad \text{inv} \to Q \quad \text{inv} \to t \geq 0 \newline  \lbrace \text{inv} \land E \rbrace \medspace C \medspace \lbrace \text{inv} \rbrace  \quad  \lbrace \text{inv} \land E \land t=V \rbrace \medspace C \medspace \lbrace  t \lt V  \rbrace  \end{gathered}}{ \lbrace P \rbrace \medspace \text{while }E \text{ do } C \text{ endwhile} \medspace \lbrace Q \rbrace }\quad \text{(WHILE)}$$

Ok, so, let's break down this mess: we can think about the semantics of the while command is just a composition of the same command (that is the body of the while). So a while loop could be expanded as follows:

$$\overbrace{C;C;C;C;C \dots C}^{n \text{ times}}$$

where $n$ is the number of times the body of the while will be executed. Notice that the guard may never become false, in that case, the sequence of commands is infinite. To prove that this command terminates and the sequence of commands is finite, we assign a **natural** number (which is identified by the expression $t$) to each cycle, so that we create a sequence. Now to prove that this sequence terminates we just have to prove that this sequence is **strictly decreasing**. Of course, every strictly decreasing sequence of natural numbers is finite.
To do this we can give a **loop invariant** (often called only $\text{inv}$), which is an assertion that is true at the beginning of every iteration. With it, we can prove the termination and also we can be sure that the precondition and postcondition are satisfied.

Now, with everything settled in, let's discuss in some detail the 5 premises of the while rule:
1. $\lbrace \text{inv} \land E \rbrace \medspace C \medspace \lbrace \text{inv} \rbrace$: it makes sure that the $\text{inv}$ assertion is true at the beginning of each iteration.
2. $P \to \text{inv}$: it makes sure that the precondition is stronger than the invariant, so that the first time we enter the loop, the invariant holds.
3. $ \text{inv} \to Q$: it makes sure that, if the invariant is true, then also the postcondition is true. This is done so that at the end of the execution we can make sure that the postcondition holds since we know that the invariant holds.
4. $\lbrace \text{inv} \land E \land t=V \rbrace \medspace C \medspace \lbrace t \lt V  \rbrace$: it makes sure that each term of the sequence is strictly decreasing.
5. $\text{inv} \to t\geq 0$: it makes sure that our sequence identified by the expression $t$ has a lower bound, in this case $0$, so that we can make sure it is finite.

That was quite a journey! But now let's stop talking about theory and let's jump into the code!

# The automatic theorem prover

For this project I chose Python as the main language because I was not aiming at a full-fledged and efficient prover, but more at a proof-of-concept or prototype program, in which Python is great.
In particular, I used [z3 theorem prover](https://github.com/Z3Prover/z3) to verify the logical formulas, and [lark](https://github.com/Z3Prover/z3) for parsing the input triple. The whole project is on [Github](https://github.com/gio54321/hoare-logic-prover).

## The parser

Using lark, parsing was surprisingly easy. I just defined the grammar into a big string and lark took care of everything. The grammar can be seen in the [source code for the parser](https://github.com/gio54321/hoare-logic-prover/blob/master/src/lpp_parser.py). An example triple that can be accepted by the parser is:

```text
[x, A]
{x==A}
x := x-3;
if (x >= 0) then
    x := x + 5
else
    x := -x + 5
fi
{x>A}
```

In the first line, we declare all the identifiers that we are going to use in the triple. Then we state the precondition, the command and the postcondition. The triple process by the parser produces a **parse tree**, which is perfect because we will need the syntax tree of the program to perform **structural induction**.

## The prover

The basic building block for the theorem prover is a function that takes in input a z3 formula and tries to prove it.
```python
def prove_formula(self, what_to_prove):
    s = z3.Solver()
    s.add(z3.Not(what_to_prove))
    res = s.check()
    if str(res) == "unsat":
        print("proved", what_to_prove)
        return True
    else:
        print("could not prove", what_to_prove)
        return False
```
The z3's `check` function can only give you 2 results: `sat`, which means that the formula is satisfiable, and `unsat`, which means the formula is unsatisfiable. We exploit this property: a formula $\phi$ is valid if and only if $\neg \phi$ is unsatisfiable, in other words, to prove the formula we can negate it and check for its satisfiability.

Now let's start implementing the main protagonist of this project: the `prove_triple()` function, which takes in input a precondition as a z3 formula, a command as a parse tree and a postcondition as a z3 formula and returns True if the triple is valid, False otherwise. The first inference rule we will implement is the simplest one: the **skip** rule.

$$\frac{P \to Q}{\lbrace P \rbrace \medspace \text{skip}\medspace \lbrace Q\rbrace}\quad (\text{SKIP})$$



```python
def prove_triple(self, precond, command, postcond):
    if command.data == "skip":
        formula_to_prove = z3.Implies(precond, postcond)
        print("found skip statement, trying to prove", formula_to_prove)
        res = self.prove_formula(formula_to_prove)
        return res
```
Here we state that for proving a skip triple it is sufficient to prove that the precondition implies the postcondition.

Now let's implement the **assignment** inference rule.

$$\frac{P \to Q[x \mapsto E]}{\lbrace P \rbrace \medspace x:=E \medspace \lbrace Q\rbrace}\quad (\text{ASSIGNMENT})$$

```python
elif command.data == "assignment":
    ide, exp = command.children
    formula_to_prove = z3.Implies(
        precond,
        z3.substitute(postcond, (self.env[ide], self.expr_to_z3_formula(exp)))
    )
    print("found assignment statement, trying to prove", formula_to_prove)
    res = self.prove_formula(formula_to_prove)
    return res
```

Now let's go on and implement the **conditional** inference rule. This is when `prove_triple` becomes **inductive**, as it calls itself on a subtree of the parse tree.

$$\frac{ \lbrace P \land E \rbrace \medspace C_1 \medspace \lbrace Q \rbrace  \quad  \lbrace P \land \neg E \rbrace \medspace C_2 \medspace \lbrace Q \rbrace }{ \lbrace P \rbrace \medspace \text{if } E \text{ then } C_1 \text{ else } C_2 \medspace \lbrace Q \rbrace }\quad (\text{IF})$$

```python
elif command.data == "if":
    guard, s1, s2 = command.children
    print("found if statement, trying to prove the first alternative")
    res_1 = self.prove_triple(z3.And(precond, self.expr_to_z3_formula(guard)), s1, postcond)
    if res_1:
        print("now trying to prove the second alternative")
        res_2 = self.prove_triple(z3.And(precond, z3.Not(self.expr_to_z3_formula(guard))), s2, postcond)
        return res_2
    else:
        return False
```

For now, there is nothing magical in the code yet: these three cases are the direct translation of the inference rule.
Now let's talk about **composition**: we know we have to **provide an intermediate assertion** so that both intermediate triples are valid.

$$\frac{\lbrace P \rbrace \medspace C_1 \medspace \lbrace R\rbrace \quad \lbrace R\rbrace \medspace C_2 \medspace \lbrace Q\rbrace }{\lbrace P\rbrace \medspace C_1;C_2 \medspace \lbrace Q\rbrace}\quad (\text{COMPOSITION})$$

There is no rule telling us how to find it, but we can use some heuristics to find it.
We try to find an assertion $R$ so that $\lbrace R\rbrace \medspace C_2 \medspace \lbrace Q\rbrace$ is an **axiom** (so is valid in our proof system) and then we delegate the validity of the whole triple to the validity of $\lbrace P \rbrace \medspace C_1 \medspace \lbrace R\rbrace$. To do this we need a new function called `find_axiom` that takes in input one command as a parse tree and a postcondition as a z3 formula and tries to find a precondition so that the triple is an axiom. Remember that there are only two axioms in our system, so we can implement only them.

{{< notice note >}}
This is a trivial heuristic that will probably fail to find such a formula, even in slightly more complex scenarios.
That's ok for this toy prover though 🙂
{{< /notice >}}



$$\frac{}{\lbrace P\rbrace \medspace \text{skip} \medspace \lbrace P \rbrace} \quad (\text{SKIP-AX})$$

$$\frac{}{\lbrace P[x \mapsto E]\rbrace \medspace x:=E \medspace \lbrace P \rbrace}\quad (\text{ASSIGNMENT-AX})$$

{{< highlight python >}}
def find_axiom(self, command, postcond):
    if command.data == "skip":
        print("found axiom for skip statement:", postcond)
        return (True, postcond)
    elif command.data == "assignment":
        ide, exp = command.children
        axiom = z3.substitute(postcond, (self.env[ide], self.expr_to_z3_formula(exp)))
        print("found axiom for assignment statement:", axiom)
        return (True, axiom)
    else:
        print("could not find axiom")
        return (False, None)
{{< / highlight >}}

Now we are all set for implementing the composition rule.

$$\frac{\lbrace P \rbrace \medspace C_1 \medspace \lbrace R\rbrace \quad \lbrace R\rbrace \medspace C_2 \medspace \lbrace Q\rbrace }{\lbrace P\rbrace \medspace C_1;C_2 \medspace \lbrace Q\rbrace}\quad (\text{COMPOSITION})$$

{{< highlight python >}}
elif command.data == "composition":
    c1, c2 = command.children
    print("found composition, trying to find axiom for the right side")
    (res, axiom) = self.find_axiom(c2, postcond)
    if res:
        return self.prove_triple(precond, c1, axiom)
    else:
        return False
{{< / highlight >}}
With these simple inference rules implemented, we can try our prover on a variable swap. So the input triple looks like this:
```text
[x, y, z, A, B]
{x==A and y==B}
z := x;
x := y;
y := z
{x==B and y==A}
```

The output of our prover is:
```text
What to prove: [x, y, z, A, B]
{x==A and y==B}
z := x;
x := y;
y := z
{x==B and y==A}

found composition, trying to find axiom for the right side
found axiom for assignment statement: And(x == B, z == A)
found composition, trying to find axiom for the right side
found axiom for assignment statement: And(y == B, z == A)
found assignment statement, trying to prove Implies(And(x == A, y == B), And(y == B, x == A))
proved Implies(And(x == A, y == B), And(y == B, x == A))

The triple is valid
```

Yay, the verdict is that this triple is valid!🎉
That means that so far our toy prover works! The great thing is that you can see the inferences made by the program by looking at the output, and we can see that the steps made by our prover are exactly what we expected.

Now we just have to implement the scary one: the **while** inference rule. Luckily, we got the hang of it, and now the code is pretty much a direct application of the inference rule.

$$\frac{\begin{gathered} P \to \text{inv} \quad \text{inv} \to Q \quad \text{inv} \to t \geq 0 \newline  \lbrace \text{inv} \land E \rbrace \medspace C \medspace \lbrace \text{inv} \rbrace  \quad  \lbrace \text{inv} \land E \land t=V \rbrace \medspace C \medspace \lbrace  t \lt V  \rbrace  \end{gathered}}{ \lbrace P \rbrace \medspace \text{while }E \text{ do } C \text{ endwhile} \medspace \lbrace Q \rbrace }\quad \text{(WHILE)}$$

```python
elif command.data == "while":
    e, t_expr, inv, c = command.children
    print("found while statement, trying to prove:")
    invariant = self.expr_to_z3_formula(inv)
    t = self.expr_to_z3_formula(t_expr)
    guard = self.expr_to_z3_formula(e)
    pre = z3.Implies(precond, invariant)
    post = z3.Implies(z3.And(precond, z3.Not(guard)), postcond)
    term = z3.Implies(z3.And(invariant, self.env["t"] == t), t>=0)
    print("1) [pre]", pre)
    res_pre = self.prove_formula(pre)
    if res_pre:
        print("2) [post]", post)
        res_post = self.prove_formula(post)
        if res_post:
            print("3) [term]", term)
            res_term = self.prove_formula(term)
            if res_term:
                print("4) [invariance]", term)
                res_inv = self.prove_triple(z3.And(invariant, guard), c, invariant)
                if res_inv:
                    print("5) [progress]", term)
                    v = z3.Int("V")
                    res=self.prove_triple(
                        z3.And(z3.And(invariant, guard), t==v),
                        c,
                        t<v
                    )
                    return res
    return False
```

So now we can finally prove some simple while triples, I have added some syntax to the while command to code the loop invariant and the expression for $t$. Here's an example triple that calculates $5 \cdot 10$ in a very stupid way:

```text
[i, s, t, r]
{i==0 and r==0}
while (i<10) where t is (10-i); inv is (r==5*i and 10-i>=0) do
    i := i+1;
    r := r+5
endw
{r==5*10}
```

This time the output is a bit more cluttered:

```text
What to prove: [i, s, t, r]
{i==0 and r==0}
while (i<10) where t is (10-i); inv is (r==5*i and 10-i>=0) do
    i := i+1;
    r := r+5
endw
{r==5*10}

found while statement, trying to prove:
1) [pre] Implies(And(0 == i, 0 == r), And(r == 5*i, 0 <= 10 - i))
proved Implies(And(0 == i, 0 == r), And(r == 5*i, 0 <= 10 - i))
2) [post] Implies(And(And(0 == i, 0 == r), Not(10 > i)), r == 5*10)
proved Implies(And(And(0 == i, 0 == r), Not(10 > i)), r == 5*10)
3) [term] Implies(And(And(r == 5*i, 0 <= 10 - i), t == 10 - i),
        10 - i >= 0)
proved Implies(And(And(r == 5*i, 0 <= 10 - i), t == 10 - i),
        10 - i >= 0)
4) [invariance] Implies(And(And(r == 5*i, 0 <= 10 - i), t == 10 - i),
        10 - i >= 0)
found composition, trying to find axiom for the right side
found axiom for assignment statement: And(r + 5 == 5*i, 0 <= 10 - i)
found assignment statement, trying to prove Implies(And(And(r == 5*i, 0 <= 10 - i), 10 > i),
        And(r + 5 == 5*(i + 1), 0 <= 10 - (i + 1)))
proved Implies(And(And(r == 5*i, 0 <= 10 - i), 10 > i),
        And(r + 5 == 5*(i + 1), 0 <= 10 - (i + 1)))
5) [progress] Implies(And(And(r == 5*i, 0 <= 10 - i), t == 10 - i),
        10 - i >= 0)
found composition, trying to find axiom for the right side
found axiom for assignment statement: 10 - i < V
found assignment statement, trying to prove Implies(And(And(And(r == 5*i, 0 <= 10 - i), 10 > i),
            10 - i == V),
        10 - (i + 1) < V)
proved Implies(And(And(And(r == 5*i, 0 <= 10 - i), 10 > i),
            10 - i == V),
        10 - (i + 1) < V)

The triple is valid
```
Great! We can see exactly that all 5 while premises have been proved, so it is fair to say that this loop has been proven formally that it **terminates** and r will contain the result of $5 \cdot 10$.

To experiment with this simple system (and maybe contribute to it) you can clone [the repository](https://github.com/gio54321/hoare-logic-prover), and you can run an example proof (for example the variable swap one) by:

```bash
$ python src/lpp_prover.py examples/var_swap.lpp
```

In the [examples folder](https://github.com/gio54321/hoare-logic-prover/tree/master/examples) on Github, there are a bunch of triples that should give you the feeling of the (very limited) capability of this system.