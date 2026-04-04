================================================================================
MLisp 解释器
================================================================================

用 OCaml 实现的 Lisp 方言解释器。支持 S 表达式、词法作用域、闭包、hygienic
宏系统、模块系统和 REPL。

前置要求
--------
OCaml 5.0+ 和 opam

快速开始
--------
  cd packages/interpreter
  dune build
  dune exec mlisp               # 启动 REPL
  dune exec mlisp -- file.mlisp # 运行文件

构建
----
  dune build
  构建产物：_build/default/bin/mlisp.exe（原生）或 mlisp.bc（字节码）

  dune clean && dune build     # 清理后重新构建

测试
----
  四层测试架构：

  1. 模块测试（推荐）
     使用 module-test 和 deftest 宏
     cd packages/mlp && dune exec mlp -- test

  2. 回归测试
     ./run_tests.sh             # 运行所有 .mlisp 测试
     ./run_tests.sh -v          # 详细输出
     ./run_tests.sh -s          # 遇错即停

  3. 单元测试
     dune exec ./test/unit/test_object_runner.exe
     dune exec ./test/unit/test_lexer_runner.exe

  4. 集成测试
     dune test test/integration

  dune runtest                 # 运行全部四层测试

项目结构
--------
  packages/interpreter/
  ├── bin/
  │   └── mlisp.ml             主入口
  ├── lib/
  │   ├── ast/                 抽象语法树
  │   ├── lexer/               词法分析
  │   ├── eval/                求值器
  │   ├── object/              核心数据类型
  │   ├── macro/               宏系统
  │   ├── primitives/           内置函数
  │   ├── stdlib/              标准库
  │   ├── repl/                REPL 实现
  │   └── module_loader/       模块系统
  ├── test/                    测试文件
  └── stdlib/                  标准库文件

子库列表
--------
  mlisp_utils       工具函数
  mlisp_error       错误处理
  mlisp_object      数据类型
  mlisp_ast         抽象语法树
  mlisp_lexer       词法分析
  mlisp_eval        求值
  mlisp_macro       宏系统
  mlisp_primitives  内置函数
  mlisp_stdlib      标准库加载
  mlisp_repl        REPL
  mlisp_module_loader 模块加载

常见问题
--------
Q: dune: command not found
A: opam install dune

Q: 测试失败
A: 确认 OCaml 版本 5.0+，运行 opam install . --deps-only

文档
----
  语言规范：../../../docs/language-spec.txt
