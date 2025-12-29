(lang dune 3.3)

(name mlisp)

(generate_opam_files true)

(source
 (github muqiuhan/MLisp))

(authors "Muqiu Han")

(maintainers "Muqiu Han")

(license MPL-2.0)

(documentation https://github.com/muqiuhan/MLisp)

(package
 (name mlisp)
 (version 0.0.44)
 (synopsis "A Lisp implementation in OCaml")
 (description "A Lisp implementation in OCaml")
 (depends ocaml dune core ocolor camlp-streams ocamline core_unix ppx_string)
 (tags
  (lisp interpreter compiler)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
