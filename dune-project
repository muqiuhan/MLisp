(lang dune 3.3)

(name ocamlisp)

(generate_opam_files true)

(source
 (github muqiuhan/ocamlisp))

(authors "Muqiu Han")

(maintainers "Muqiu Han")

(license AGPL-v3)

(documentation https://github.com/muqiuhan/ocamlisp)

(package
 (name ocamlisp)
 (synopsis "A Lisp implementation in OCaml")
 (description "A Lisp implementation in OCaml")
 (depends ocaml dune)
 (tags
  (lisp interpreter compiler)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
