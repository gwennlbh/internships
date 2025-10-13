#show ref: it => {
  let eq = math.equation
  let el = it.element
  if el != none and el.func() == eq {
    // Override equation references.
    link(el.location(),numbering(
      el.numbering,
      ..counter(eq).at(el.location())
    ))
  } else {
    // Other references as usual.
    it
  }
}

== Cas dégénéré de $D_"KL" (Q, Q') = 0$ sans utilisation de $max$ <dkl-zero>

Soit $S$ (resp. $A subset bb(N)$) l'espace des états (resp. actions) de l'environnement. Soit $Q : S times A -> [0, 1]$ une distribution de probabilité du choix par l'agent d'une action dans un état tel que

$ forall s in S, Q(s, 1) = Q(s, 2) $ <dkl-zero-qeq>

Soit $Q' : S times A -> [0, 1]$ définit ainsi:

$ forall s in S, Q'(s, 1) = 2 Q(s, 1) $ <dkl-zero-a1>
$ forall s in S, Q'(s, 2) = 1/2 Q(s, 2) $ <dkl-zero-a2>
$ forall s in S, forall a in A - {1, 2}, Q'(s, a) = Q(s, a) $ <dkl-zero-else>

#let kl = (a, b) => $#a log #a / #b$

#let crossout = (content, why) => $underbracket(cancel(#content), "d'après " #why)$

On a

$

D_"KL" ( Q || Q' ) 
&= sum_((s, a) in S times A) kl(Q(s, a), Q'(s, a)) \
&"On découpe la somme selon les valeurs de " A ":" \
&= sum_(s in S) 
crossout(
  sum_(a in A - {1, 2})  kl(Q(s, a), Q(s, a)) , 
  #[@dkl-zero-else]
) 
+ kl(Q(s, 1), 2Q(s, 1)) + kl(Q(s, 2), 1/2 Q(s, 2)) \
&= sum_(s in S) 
Q(s, 1) lr([ log Q(s, 1) - log Q(s, 1) - log 2   ], size: #200%) + 
Q(s, 2)    [ log Q(s, 2) - log Q(s, 2) - log 1/2 ] \
&= sum_(s in S) - Q(s, 1) log 2 + Q(s, 2) log 2 wide "d'après" #[@dkl-zero-a1 et @dkl-zero-a2] \
&= sum_(s in S) log 2 thin (cancel(Q(s, 2) - Q(s, 1))) wide wide thin "d'après" #[@dkl-zero-qeq] \
&= sum_(s in S) 0 = 0

$
