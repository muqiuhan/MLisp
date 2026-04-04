================================================================================
MLisp 包管理器 (mlp)
================================================================================

MLisp 的包管理工具，提供项目初始化、依赖安装和测试功能。

前置要求
--------
- OCaml 5.0+
- 解释器已构建

快速开始
--------
  cd packages/mlp
  dune build

  dune exec mlp -- init xxx     # 初始化新项目
  dune exec mlp -- install /path # 安装本地包
  dune exec mlp -- test         # 运行测试

命令说明
--------

mlp init [name]
  创建新的 MLisp 项目。生成目录结构：
    my-project/
    ├── package.mlisp     包配置
    ├── src/               源码
    ├── test/              测试
    └── modules/           本地模块

mlp install <path>
  从本地路径安装包
  包安装到 ~/.mlisp/packages/

mlp test
  运行 test/ 目录下的所有测试
  需要设置 MLISP_STDLIB_PATH 环境变量指向标准库

测试框架
--------

使用 Rust 风格的 module-test 宏组织测试。

基本用法：
  (module-test factorial
    (deftest "0 的阶乘是 1" (== (factorial 0) 1))
    (deftest "5 的阶乘是 120" (== (factorial 5) 120)))

语法：
  module-test  将测试分组命名
  deftest     定义测试用例

测试返回 #t 通过，#f 失败。

项目结构
--------
  packages/mlp/
  ├── src/
  │   └── mlp.ml          CLI 入口
  ├── lib/
  │   ├── test_runner.ml   测试执行
  │   ├── reporter.ml      输出格式化
  │   └── installer.ml     包安装
  └── test/
      └── *.mlisp          集成测试

依赖
----
  ocaml >= 5.0
  dune >= 3.0
  core
  sexplib

常见问题
--------

Q: "No test files found"
A: 确认 test/ 目录存在且包含 .mlisp 文件

Q: "Module not found"
A: 使用 load-module 时，模块文件必须存在

Q: stdlib 找不到
A: 设置 MLISP_STDLIB_PATH 环境变量

文档
----
  解释器文档：../interpreter/README_zh.txt
  语言规范：../../../docs/language-spec.txt
