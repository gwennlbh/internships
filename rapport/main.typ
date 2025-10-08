#import "template.typ": arkheion, arkheion-appendices, monospace
#import "utils.typ": cut-around, cut-between, dedent, include-function

#import "@preview/diagraph:0.3.2"
#show raw.where(lang: "dot"): it => diagraph.render(it.text)
#show raw.where(lang: "mermaid"): it => diagraph.render(
  it.text.replace("graph TD", "digraph {").replace("-->", "->") + "}",
)


#let imagefigure(path, caption, size: 100%) = figure(
  image(path, width: size),
  caption: caption,
)

#let diagram(caption: "", size: 100%, content) = figure(
  caption: caption,
  kind: image,
  scale(size, content, reflow: true),
)

#let breakout(content) = block(
  inset: 1em,
  fill: luma(95%),
  radius: 4pt,
  width: 100%,
  pad(x: 1em, align(center, text(size: 1.1em, content))),
)

#let codesnippet(caption: "", content, lang: "rust", size: 1em) = {
  let snip = text(
    size: size,
    block(
      inset: 1.5em,
      fill: luma(95%),
      radius: 4pt,
      width: 100%,
      // Figure itself is already non breakable, AFAIK
      breakable: caption != "",
      if type(content) == str {
        raw(
          lang: lang,
          content,
        )
      } else {
        content
      },
    ),
  )

  if caption != "" {
    figure(caption: caption, align(left, snip))
  } else {
    snip
  }
}

#show link: underline

#show: arkheion.with(
  title: [_gz-unitree_: Reinforcement learning en robotique avec validation par moteurs de physique multiples pour le H1v2 d'Unitree],
  headertitle: "gz-unitree",
  authors: (
    (
      name: "Gwenn Le Bihan",
      email: "gwenn.lebihan@etu.inp-n7.fr",
      affiliation: "ENSEEIHT",
    ),
  ),
  logo: [
    #stack(
      dir: ltr,
      spacing: 2em,
      image("../laas.jpeg", height: 10em),
      image(
        "../enseeiht.png",
        height: 10em,
        width: 11em,
        fit: "contain",
      ),
    )
  ],
  date: [#datetime.today().day() Novembre 2025],
)

#pagebreak()

= Remerciements

#outline()

= Contexte

#include "context.typ"

= Packaging reproductible avec Nix

#include "nix.typ"

= Étude du SDK d'Unitree et du bridge SDK #sym.arrows.lr MuJoCo

#include "sdk2-study.typ"

= Développement du bridge SDK #sym.arrows.lr Gazebo

#include "gz-unitree.typ"


#bibliography("../bib.yaml")

#show: arkheion-appendices

#heading(numbering: none)[Annexes]

