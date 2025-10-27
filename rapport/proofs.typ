#import "utils.typ": comment, refneeded, todo
#show math.equation.where(block: true): set block(spacing: 2em)

== Cas dégénéré de $D_"KL" (Q, Q') = 0$ sans utilisation de $max$ <dkl-zero>

Soit $S$ (resp. $A subset bb(N)$) l'espace des états (resp. actions) de l'environnement. Soit $Q : S times A -> [0, 1]$ une distribution de probabilité du choix par l'agent d'une action dans un état tel que

$ forall s in S, Q(s, 1) = Q(s, 2) $ <dkl-zero-qeq>

Soit $Q' : S times A -> [0, 1]$ définit ainsi:

$ forall s in S, Q'(s, 1) := 2 Q(s, 1) $ <dkl-zero-a1>
$ forall s in S, Q'(s, 2) := 1/2 Q(s, 2) $ <dkl-zero-a2>
$ forall s in S, forall a in A - {1, 2}, Q'(s, a) := Q(s, a) $ <dkl-zero-else>

#let why = (content, reference) => {
  $underbracket(#content, "d'après " #ref(reference))$
}
#let crossout = (content, reference) => $why(cancel(#content), reference)$

On a

$
  D_"KL" ( Q || Q' )
  &= sum_((s, a) in S times A) Q(s, a) log Q(s, a) / (Q'(s, a)) \
  &"On découpe la somme selon les valeurs de " A ":" \
  &= sum_(s in S)
  sum_(a in A - {1, 2}) [ Q(s, a) log Q(s, a) / (Q'(s, a)) ]
  + Q(s, 1) log Q(s, 1) / (Q'(s, 1))
  + Q(s, 2) log Q(s, 2) / (Q'(s, 2)) \
  &= sum_(s in S)
  crossout(sum_(a in A - {1, 2}) Q(s, a) log Q(s, a) / (Q(s, a)), #<dkl-zero-else>)
  + Q(s, 1) log Q(s, 1) / why(2 Q(s, 1), #<dkl-zero-a1>)
  + Q(s, 2) log Q(s, 2) / why(1/2 Q(s, 2), #<dkl-zero-a2>) \
  &= sum_(s in S)
  Q(s, 1) lr([ log Q(s, 1) - log Q(s, 1) - log 2 ], size: #200%) + \
  & quad quad thick thick Q(s, 2) [ log Q(s, 2) - log Q(s, 2) - log 1/2 ] \
  &= sum_(s in S) - Q(s, 1) log 2 + Q(s, 2) log 2 \
  &= sum_(s in S) log 2 thin crossout((Q(s, 2) - Q(s, 1)), #<dkl-zero-qeq>) \
  &= sum_(s in S) 0 = 0
$

== $eta(p, r)$ comme une espérance <proof-eta-esperance>

Soit $r$ une fonction récompense et $p$ une politique. Soit $C$ une variable aléatoire à valeurs dans $cal(S)$, dont la loi de probabilité suit celle de $p$.


On a

$
  exp(sum_(t=0)^oo gamma^t r(C_t))
  &= sum_((c_t)_(t in NN) in cal(S)) (sum_(t=0)^oo gamma^t r(c_t)) bb(P)(sum_(t=0)^oo gamma^t r(C_t) = sum_(t=0)^oo gamma^t r(c_t)) \
  &= sum_((c_t)_(t in NN) in cal(S)) (sum_(t=0)^oo gamma^t r(c_t)) bb(P)(C = (c_t)_(t in NN)) \
  // &= sum_((c_t)_(t in NN) in cal(S)) (sum_(t=0)^oo gamma^t r(c_t)) bb(P)(inter.big_(t=0)^oo C_t = c_t) \
  // &= sum_((c_t)_(t in NN) in cal(S)) (sum_(t=0)^oo gamma^t r(c_t)) product_(t=0)^oo bb(P)(C_t = c_t) \
$



Soit $S$ (resp. $A$) la suite des premiers (resp. deuxièmes) éléments de $C$, c'est-à-dire $forall t in NN, (S_t, A_t) := C_t$.


Étant donné la définition de $cal(S)$:

- $S_t$ dépend de $A_(t-1)$ et $S_(t-1)$
- $A_t$ dépend de $S_t$

On a alors, pour toute suite $(c_t)_(t in NN) in cal(S)$ :

$
  P(C = (c_t)_(t in NN))
  = \
  bb(P)(S_0 = s_0)bb(P)(A_0 = a_0 | S_0 = s_0)
  product_(t=1)^oo
  // bb(P)(S_t = s_t mid(|) cases(S_(t-1) = s_(t-1), A_(t-1) = a_(t-1)))
  bb(P)(S_t = s_t mid(|) C_(t-1) = c_(t-1))
  bb(P)(A_t = a_t mid(|) S_t = s_t) \
$

On a

$
  bb(P)(S_0 = s_0) &= rho_0(s_0) \
  forall t in NN, quad bb(P)(A_t = a_t mid(|) S_t = s_t) &= Q_p (s_t, a_t) \
  forall t in NN^*, quad
  bb(P)(S_t = s_t | C_(t-1) = c_(t-1)) &= bb(P)(M(C_(t-1)) = M(c_(t-1)) | C_(t-1) = c_(t-1)) \
  &= bb(P)(C_(t-1) = c_(t-1) | C_(t-1) = c_(t-1)) = 1
$


Donc on a

$
  P(C = (c_t)_(t in NN))
  &= rho_0(s_0) Q_p (s_0, a_0) product_(t=1)^oo Q_p (s_t, a_t) \
  &= rho_0(s_0) product_(t=0)^oo Q_p (s_t, a_t)
$

Et ainsi

$
  exp(sum_(t=0)^oo gamma^t r(C_t))
  &= sum_((c_t)_(t in NN) in cal(S)) (sum_(t=0)^oo gamma^t r(c_t)) bb(P)(C = (c_t)_(t in NN)) \
  &= sum_((c_t)_(t in NN) in cal(S)) (sum_(t=0)^oo gamma^t r(c_t)) rho_0(s_0) product_(t=0)^oo Q_p (s_t, a_t) \
  &= eta(p, r) quad qed
$

== Simplification de l'expression de $L(s, a, Pi, Pi', R)$ dans PPO-Clip <proof-ppo-clip-simplify>

#let clip = $op("clip")$

Soit $(s, a) in S times A$, et $Pi'$ une politique. Posons $alpha &:= A_(Pi', R) (s, a)$, $q slash q' &:= Q_Pi (s, a) slash Q_Pi' (s, a)$ .

#let why = explanation => $\ & quad quad #[car #explanation]$

#{
  v(0.5em)
  set math.equation(numbering: none)
  show math.equation.where(block: true): set align(left)
  block(
    breakable: false, //stroke: 0.5pt+black,
    grid(
      columns: (1fr, 1fr),
      row-gutter: 1em,

      grid.cell(align: center)[ *Cas $alpha > 0$* ],
      grid.cell(align: center)[ *Cas $alpha < 0$* ],
      [

        $
          &L(s, a, Pi, Pi', R) \
          &= min(q/q' alpha, quad clip(q/q', thick 1-epsilon, thick 1+epsilon) alpha) \
          &= min(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha why(alpha > 0) \
        $
      ],
      [

        $
          &L(s, a, Pi, Pi', R) \
          &= min(q/q' alpha, quad clip(q/q', thick 1-epsilon, thick 1+epsilon) alpha) \
          &= max(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha why(alpha < 0) \
        $
      ],

      grid.hline(stroke: 0.5pt),
      grid.cell(
        colspan: 2,
        align: center,
        inset: 1em,
      )[*...et $q slash q' in [1-epsilon, 1+epsilon]$*],
      [

        $
          & = min(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha \
          & = min(q/q', quad q/q') alpha \
          & = min(q/q', 1+epsilon) alpha why(1+epsilon > q/q') \
        $


      ],
      [

        $
          & = max(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha \
          & = max(q/q', quad q/q') alpha \
          & = max(q/q', 1-epsilon) alpha why(1-epsilon < q/q') \
        $

      ],

      grid.hline(stroke: 0.5pt),
      grid.cell(
        colspan: 2,
        align: center,
        inset: 1em,
      )[*...et $q slash q' > 1+epsilon$*],
      [

        $
          & = min(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha \
          & = min(q/q', quad 1+epsilon) alpha \
        $

      ],
      [

        $
          & = max(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha \
          & = max(q/q', quad 1+epsilon) alpha \
          & = max(q/q', quad 1-epsilon) alpha why(1-epsilon < 1+epsilon < q / q') \
        $

      ],

      grid.hline(stroke: 0.5pt),
      grid.cell(
        colspan: 2,
        align: center,
        inset: 1em,
      )[*...et $q slash q' < 1-epsilon$*],
      [

        $
          & = min(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha \
          & = min(q/q', quad 1-epsilon) alpha \
          & = min(q/q', quad 1+epsilon) alpha why(1+epsilon > 1-epsilon > q / q') \
        $

      ],
      [


        $
          & = max(q/q', quad clip(q/q', thick 1-epsilon, thick 1+epsilon)) alpha \
          & = max(q/q', quad 1-epsilon) alpha
        $

      ],
    ),
  )
}
