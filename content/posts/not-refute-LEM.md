+++
authors = ["Giorgio Dell'Immagine"]
title = "Intuitionism does not refute excluded middle"
date = "2021-09-17"
description = "Proof of non-refutation of the law of excluded middle in intuitionistic logic"
tags = [
    "Logic",
    "Intuitionism",
    "Curry-Howard",
    "Lambda calculus"
]
math = true
+++

[Intuitionistic logic](https://en.wikipedia.org/wiki/Intuitionistic_logic) refers to a system of symbolic logic that differs from classical logic by removing the law of excluded middle (that is $p \vee \neg p$) and the double negation elimination (that is $\neg \neg p \rightarrow p$).
When I first encountered this logic, I thought that the law of excluded middle was simply false, or that the inverse would hold, but as it turns out I was wrong.  
Indeed, one of the theorems that can be proved in intuitionistic logic, which will be our best friend in this post, is the non-refutation of the law of excluded middle, which looks something like this:

$$
\neg \neg (A \vee \neg A)
$$

Intuitionism focuses on the positive construction of proofs, so the theorem shall be read as **"Intuitionistic logic does not positively refute the law of excluded middle"**.

Remembering that $\neg A$ is defined as $A \rightarrow \bot$ the theorem is expressed equivalently like

$$
((A \vee (A \rightarrow  \bot)) \rightarrow \bot) \rightarrow \bot
$$
Ee will prove it with two different methods: using natural deduction and using lambda calculus.

## Proof using natural deduction
I assume some familiarity with the natural deduction proof style. You can read about it (more than enough to understand this derivation) on [Wikipedia](https://en.wikipedia.org/wiki/Natural_deduction).
For typographical purposes, I will split up the proof into two parts.

First, let's prove that under the assumption $w$ that $(A \vee (A \rightarrow \bot)) \rightarrow \bot$ the formula $A\rightarrow \bot$ holds.

$$
\dfrac{\dfrac{\dfrac{\dfrac{}{A \: \text{true}}u}{A \vee (A \rightarrow \bot)\: \text{true}} \vee _I \qquad \dfrac{}{(A \vee (A \rightarrow \bot)) \rightarrow \bot \: \text{true}}w}{\bot \: \text{true}} \rightarrow _E}{A \rightarrow \bot \: \text{true}}\rightarrow _I ^u
$$

In this proof, we have discharged the hypothesis $u$ but not $w$. I will call this proof $P^w$ to indicate that there is the non-discharged assumption $w$.

Now let's complete the proof.

$$
\dfrac{\dfrac{\dfrac{\dfrac{P^w}{A \rightarrow \bot \: \text{true}}}{A \vee (A \rightarrow \bot)\: \text{true}} \vee _I \qquad \dfrac{}{(A \vee (A \rightarrow \bot)) \rightarrow \bot \: \text{true}}w}{\bot \: \text{true}} \rightarrow _E}{((A \vee (A \rightarrow \bot)) \rightarrow \bot)\rightarrow \bot\: \text{true}} \rightarrow _I ^w
$$

And with that, we have proven the theorem!

Notice that we have used the assumption $w$ two times. This might seem strange at first, but it is allowed because the two assumptions are taken in the same subproof "above" the discharge.

## Proof using lambda calculus
By the [Curry-Howard correspondence](https://en.wikipedia.org/wiki/Curry%E2%80%93Howard_correspondence), we can try to find a lambda tem that has type

$$
((A \vee (A \rightarrow  \bot)) \rightarrow \bot) \rightarrow \bot
$$

and we would have our proof. Lambda terms like this are sometimes called **proof terms**.
It turns out that the term 

$$
\lambda f. \: f \: (\text{right}(\lambda a. \: f \: \text{left}(a))))
$$

has the desired type. We could check this by hand, but that would require a lot of work.
What we can instead do is try to import it into **Haskell** and let the type checker do the hard work.

```hs
import Data.Void

thm :: ((Either a (a -> Void)) -> Void) -> Void
thm f = f (Right (\a -> f (Left a)))
```
or, more elegantly

```hs
thm f = f (Right (f . Left))
```

This indeed typechecks, so that is also a proof of our theorem!

## Consequences
Even though the law of excluded middle does not hold in intuitionistic logic, it holds in this "double negated form".
Now recall that, while in intuitionistic logic it is not valid that $\neg \neg p \rightarrow p$, a very similar theorem holds: 

$$
p \rightarrow \neg \neg p
$$

Intuitively this means that everything that is provable in intuitionistic logic is then provable in this double negated form, so in some sense, all the theorems that are of the form $\neg \neg $ are all the theorems $p$ that hold in intuitionistic logic, plus the law of excluded middle.
The double negated form is then stronger than the "normal" form.
This central idea is formalized in the [double negation translation](https://en.wikipedia.org/wiki/Double-negation_translation), in particular in Glivenko's theorem, which states that This result has been further extended to first-order logic.