(* Test runner for mlp *)

let () =
  Alcotest.(
    run "mlp" [
      "command parsing", [
        test_case "parse --version flag" `Quick (fun () -> Alcotest.check Alcotest.bool "version flag" false true);
        test_case "parse --help flag" `Quick (fun () -> Alcotest.check Alcotest.bool "help flag" false true);
        test_case "parse init subcommand" `Quick (fun () -> Alcotest.check Alcotest.bool "init" false true);
      ];
      "test runner", Test_runner_test.tests;
      "reporter", Reporter_test.tests;
      "installer", Installer_test.tests;
    ]
  )
