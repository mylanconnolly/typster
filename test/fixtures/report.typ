#set page(width: 8.5in, height: 11in, margin: 1in)
#set text(size: 11pt)
#set heading(numbering: "1.")

#align(center)[
  #text(size: 24pt, weight: "bold")[#title]
  #v(0.5em)
  #text(size: 12pt)[#subtitle]
  #v(0.5em)
  #text(size: 10pt, style: "italic")[
    Author: #author\
    Date: #date
  ]
]

#pagebreak()

= Executive Summary

#summary

= Introduction

#introduction

= Findings

#for finding in findings [
  == #finding.title

  #finding.content

  #if finding.at("metrics", default: none) != none [
    *Key Metrics:*
    #for metric in finding.metrics [
      - #metric
    ]
  ]
]

= Conclusion

#conclusion

#pagebreak()

= Appendix

#appendix
