# Container GUI

Apple [container](https://github.com/apple/container) 的原生 macOS 桌面客户端(AppKit,Swift)。

`design/` 是设计原型(浏览器版,仅作视觉参考);`app/` 是正式产品。

## 目录结构

```
apple-container-gui/
├── design/                      # 浏览器原型(设计参考)
│   ├── index.html  shots.js
│   └── assets/
└── app/                         # 正式产品:AppKit 应用
    ├── Package.swift            # SPM;executableTarget 直接指向 ContainerGUI/
    ├── ExceptionCatcher/        # ObjC @try 捕获器(诊断 AppKit 吞异常)
    ├── Scripts/
    │   ├── build.sh             # swift build -c release → 组装 Container.app → ad-hoc 签名
    │   └── dev.sh               # 构建 + 启动
    └── ContainerGUI/
        ├── App/                 # main、AppDelegate、MainWindow(侧边栏 + 内容 + Inspector)
        ├── Core/
        │   ├── CLIRunner.swift  # Process 封装(同步/流式)
        │   ├── Models.swift     # CLI JSON 输出的 Codable 模型
        │   ├── Commands.swift   # 全部 CLI 命令的类型化封装
        │   └── Store.swift      # 状态中心:5s 轮询 + NotificationCenter 分发
        ├── UI/
        │   ├── Pages/           # 概览/容器/镜像/存储卷/网络/虚拟机/Kubernetes/设置
        │   ├── Sheets/          # 运行/拉取/构建/新建卷·网络·虚拟机·集群/登录/标签/导入
        │   ├── Inspector/       # 详情抽屉(信息/日志跟随/监控图表/PTY 终端)、系统日志
        │   ├── Components/      # 图表、KV 编辑器、Toast、空态、确认面板
        │   └── Support/         # 主题、本地化(L10n)、格式化
        └── Resources/           # Info.plist 由 build.sh 生成;en.lproj / zh-Hans.lproj
```

## 构建与运行

要求:macOS 15+,已安装 Apple `container` CLI(`/usr/local/bin/container`)。

```bash
cd app
./Scripts/dev.sh      # debug 构建 + 启动
# 或
./Scripts/build.sh    # release 构建 → app/build/Container.app
open build/Container.app
```

## 功能

- **概览**:统计磁贴、磁盘用量(可回收量)、服务状态(CLI/API 版本、默认注册表、DNS)
- **容器**:过滤/搜索、启停/强杀/删除/导出 FS、详情抽屉(信息 · 日志跟随 · 监控图表 · PTY 终端)
- **镜像**:拉取、构建、推送、标签、导出 tar、详情(含 CMD/摘要)、删除
- **存储卷**:创建(容量/journal 模式)、删除、占用保护
- **网络**:创建(v4/v6/internal)、删除(系统网络保护,需 macOS 26+)
- **虚拟机**:创建(CPU/内存/home-mount/嵌套虚拟化/设默认)、停止、删除
- **Kubernetes**:`container k8s` 集群管理(创建/启动/导入镜像/写 kubeconfig/删除,实验性)
- **设置**:主题、服务启停、系统日志、内核安装、DNS 域、注册表登录、属性表

界面语言跟随系统(简体中文 / English)。

## 实现说明

- 数据层零 mock:全部通过 `Process` 驱动真实 `container` CLI(`--format json` 解码)
- 终端标签使用 PTY(`openpty`)运行 `container exec -it <id> /bin/sh`
- 日志/系统日志通过流式子进程(`logs -f` / `system logs`)实时追加
- 监控图表轮询 `container stats --no-stream --format json` 自绘 CAShapeLayer 折线
