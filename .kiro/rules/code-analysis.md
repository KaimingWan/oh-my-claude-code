# Code Analysis

代码阅读、分析、导航场景必须优先使用 LSP 工具（search_symbols, find_references, goto_definition, get_hover 等），而非 grep/fs_read 逐行搜索。

理由：LSP 提供语义级分析（类型、引用链、定义跳转），grep 只做文本匹配，容易漏掉或误匹配。

适用：
- 查找符号定义/引用 → search_symbols + find_references
- 理解类型/签名 → get_hover
- 文件结构概览 → get_document_symbols
- 架构理解 → generate_codebase_overview
- 调试/debug → get_diagnostics 为首选工具，获取编译器错误和警告后再用 search_symbols + find_references 定位根因

例外：
- 搜索注释/字符串中的文本 → grep
- 读取非代码文件（markdown、config）→ fs_read
