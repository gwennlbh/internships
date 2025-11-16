#let comment = content => text(fill: gray)[(Note: #content)]
#let todo = content => text(fill: red)[(TODO: #content)]
#let refneeded = text(fill: luma(100), [[Réf. nécessaire]])
#let dontbreak = content => block(breakable: false, content)

// https://github.com/typst/typst/issues/3147#issuecomment-2457554155
// Thanks @w1th0utnam3 !
#let trimmed-image = (path, trim: (:), alt: none) => context {
  let img = image(path)
  // Get dimensions of the source image
  let dims = measure(img)

  layout(size => {
    let left = trim.at("left", default: 0.0%)
    let right = trim.at("right", default: 0.0%)

    let top = trim.at("top", default: 0.0%)
    let bottom = trim.at("bottom", default: 0.0%)

    let width-rel-trimmed = 100.0% - left - right
    let height-rel-trimmed = 100.0% - top - bottom

    let width-source-trimmed = dims.width * width-rel-trimmed
    let height-source-trimmed = dims.height * height-rel-trimmed

    // Aspect ratio h/w of the layout (available space)
    let aspect-height-layout = size.height / size.width
    // Aspect ratio h/w of the trimmed image
    let aspect-height-trimmed = height-source-trimmed / width-source-trimmed

    let width-final-trimmed = none
    let height-final-trimmed = none

    // Compute final size of trimmed image
    // by expanding along dimension that first hits the layout constraints
    if aspect-height-layout >= aspect-height-trimmed {
      // Expand width of image
      width-final-trimmed = size.width
      height-final-trimmed = aspect-height-trimmed * width-final-trimmed
    } else {
      // Expand height of image
      height-final-trimmed = size.height
      width-final-trimmed = size.height / aspect-height-trimmed
    }

    // Compute the hypothetical size of the image without trimming
    let width-final-untrimmed = width-final-trimmed / float(width-rel-trimmed)
    let height-final-untrimmed = (
      height-final-trimmed / float(height-rel-trimmed)
    )

    box(
      clip: true,
      inset: (
        top: -(top * height-final-untrimmed),
        bottom: -(bottom * height-final-untrimmed),
        left: -(left * width-final-untrimmed),
        right: -(right * width-final-untrimmed),
      ),
      // TODO: Handle explicit sizing according to a parameter (e.g. don't scale over DPI limits)
      image(
        path,
        width: width-final-untrimmed,
        height: height-final-untrimmed,
        alt: alt,
      ),
    )
  })
}

#let cut-lines = (
  starts,
  ends,
  content,
  keep_delimiting: false,
) => {
  let lines = content.split(regex("\r?\n"))
  let predicate = pred => if type(pred) == str {
    it => it.trim() == str
  } else if type(pred) == function {
    pred
  } else if type(pred) == regex {
    it => it.find(pred) != none
  } else {
    panic("cut-between predicates must be strings or functions")
  }
  let start_index = lines.position(predicate(starts))

  if start_index == none {
    none
  } else {
    let lines_from_start = lines.slice(if keep_delimiting {
      start_index
    } else {
      calc.max(start_index + 1, 0)
    })

    lines_from_start
      .slice(
        0,
        lines_from_start.position(predicate(ends))
          + if keep_delimiting { 1 } else { 0 },
      )
      .join("\n")
  }
}

#let cut-between = (starts, ends, content) => cut-lines(
  starts,
  ends,
  content,
  keep_delimiting: false,
)
#let cut-around = (starts, ends, content) => cut-lines(
  starts,
  ends,
  content,
  keep_delimiting: true,
)

#let dedent = content => {
  let lines = content.split(regex("\r?\n"))
  let min_indent = lines
    .filter(it => it.trim() != "")
    .map(it => it.clusters().position(c => c != " "))
    .fold(99999, (a, b) => calc.min(a, b))

  lines.map(it => it.slice(calc.min(it.len(), min_indent))).join("\n")
}


#let include-function = (
  filepath,
  name,
  lang: none,
  is_method: false,
  transform: it => it,
) => {
  let start_pattern = if lang == "rust" {
    if is_method {
      regex("^    (pub )?fn " + name)
    } else {
      regex("^(pub )?fn " + name)
    }
  } else if lang == "python" {
    regex("^def " + name)
  } else if lang == none {
    panic("specify a source language")
  } else {
    panic(lang + " is not supported for now. Use cut-between directly.")
  }

  let end_pattern = if lang == "rust" {
    if is_method {
      regex("^    \}")
    } else {
      regex("^\}")
    }
  } else if lang == "python" {
    regex("^# end") // TODO pass next line to cut-between
  } else {
    none
  }

  let contents = cut-around(
    start_pattern,
    end_pattern,
    read(filepath),
  )

  if contents == none {
    [
      Woops! function #name not in #filepath .\_.
      Searched for a line beginning with #start_pattern in:

      #raw(lang: lang, read(filepath))
    ]
  } else {
    raw(lang: lang, dedent(transform(contents)))
  }
}
