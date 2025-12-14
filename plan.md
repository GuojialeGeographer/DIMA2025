【Dear sutdents,

as already mentioned, Huawei is interested in our course and they would like to propose the following. I hope you can be as interested as I am and that some good students can accept the challenge.

regards

--luciano baresi

# Introduction

OpenHarmony is emerging as the third mobile operating system alongside Android and iOS. Devices powered by this system have already sold in the millions on the Chinese market, even surpassing iOS. The first smartwatches with this system are now available in Europe, and the offering will likely expand soon. It’s a good moment to enter this ecosystem and learn to build your own applications. The Oniro project aims to provide European developers with a fully open and vendor neutral platform for app development.

# Challenge

Your task is to create an application for smartwatches or/and mobile phones that:
- focuses on sport, health and or well-being,
- creatively uses AI,
- can communicate with a network-accessible API.
You have full freedom of ideas, creativity counts.

# Tools & docs

To get started, review the following resources:
- YouTube tutorials on getting started with OpenHarmony and Oniro: https://www.youtube.com/playlist?list=PLy7t4z5SYNaT3VUbRGCoNH471N9sSs0uV
- OpenHarmony SDK API 18 documentation: https://docs.openharmony.cn/pages/v5.1.0/en/OpenHarmony-Overview.md
- Documentation available for the compatible distribution called Eclipse Oniro: https://docs.oniroproject.org/
- Sample applications: https://github.com/orgs/eclipse-oniro4openharmony/repositories
- DevEco Studio IDE: https://developer.huawei.com/consumer/en/deveco-studio/
The recommended programming language for building applications is ArkTS, an extension of TypeScript.
For interested students we will provide a Discord channel for easy communication with supporting mentors.


# Evaluation Criteria

The application should
- focus on sport, health or well-being, and creatively use AI;
- compile and run on the available emulator or on a real device with Oniro/OpenHarmony or HarmonyOS NEXT;
- for smartwatches use components tailored to small screens and watch interactions (touch, gestures, side buttons, sensors);
- for mobiles contain at least three screens that can be navigated using a tab component in the bottom bar (or other convenient navigation), have a slide-out menu, and support offline mode;
- have a well-defined architecture and be well documented (also inside the code).
The code should be readable, follow best programming practices, and be testable with unit tests.】






# DIMA Project Proposal: CityZen
**GeoAI-Powered Urban Well-being System**

**Date:** [20251212]
**To:** Prof. Luciano Baresi & Huawei Mentors
**Team:** [Jiale Guo], [Yang Wang], [Qingxuan Tuo] (MSc in Geoinformatics Engineering)

---

## 1. Executive Summary (项目摘要)

**CityZen** 是一款基于 **OpenHarmony/Oniro** 生态的创新型健康应用。不同于传统的运动追踪应用仅关注“量”（步数、距离），CityZen 核心关注“质”（环境质量）。

利用我们团队在 **地理信息工程 (Geoinformatics)** 领域的背景，CityZen 将城市环境数据（空气质量、噪音、热岛效应、绿地分布）与 AI 智能体融合，旨在解决**“数据孤岛”**与**“环境感知缺失”**的痛点。本项目将开发一个包含地图可视化、环境感知评分、AI 智能建议及离线轨迹记录的移动端 MVP（最小可行性产品），并展望基于鸿蒙生态的“超级终端”流转体验。
核心Slogan：基于地理空间人工智能（GeoAI）的城市运动增强系统。
核心理念：不仅仅记录运动数据，而是评估运动环境质量，利用 AI 为用户寻找城市中“最健康”的角落。
---

## 2. Motivation & Problem Statement (动机与痛点)

在当前的移动健康（mHealth）市场中，我们观察到以下显著痛点：

1.  **盲目运动 (Blind Exercise)**：用户在进行户外跑时，往往不知道自己正暴露在 PM2.5 高值区或高噪音的交通干道旁。研究表明，在重污染环境下运动可能弊大于利。
2.  **环境感知缺失 (Lack of Context Awareness)**：现有的智能手表和 APP 缺乏对“城市峡谷（Urban Canyon）”效应的考量，无法在 GPS 信号弱或环境恶劣时主动预警。
3.  **缺乏个性化指导**：大多数建议仅基于生理数据（如心率），缺乏结合**时间+空间+天气**的多维综合建议。

**我们的理念**：*Where you run matters as much as how much you run.* (在哪里跑，与跑了多少同样重要。)

---

## 3. Proposed Solution: CityZen (解决方案)

CityZen 是一个**城市感知计算系统**。它通过多源数据融合，为用户寻找城市中“最健康最适合运动”的角落。

### 3.1 核心功能架构 (App Structure)
本项目将严格遵循 DIMA 课程要求，采用 **ArkTS** 开发，包含底部 Tab 导航、侧滑菜单及以下三个核心模块：

#### **Tab 1: 仪表盘 - 城市感知 (Dashboard: Perception)**
*   **功能**：用户的“环境指挥舱”。
*   **数据展示**：实时显示当前位置的 **Environment Score (环境评分)**。该评分由 API 获取的天气数据（温度、湿度、风速）和 AQI（空气质量）加权计算得出。
*   **AI Smart Coach (AI 智能教练)**：
    *   **实现方式**：调用云端大模型 API (e.g., DeepSeek/OpenAI)。
    *   **场景逻辑**：将 `[时间, 位置, 天气, 环境评分]` 发送给 AI。
    *   **输出示例**：“下午2点米兰市中心紫外线较强（UV Index 7），且大教堂附近游客拥堵。建议您推迟到傍晚6点，前往 Sempione 公园进行低强度慢跑。”

#### **Tab 2: 智图 - 空间规划 (Smart Map: Planning)**
*   **功能**：基于 **Huawei Map Kit** 的全屏交互式地图。
*   **GIS 核心优势 (Geo-Intelligence)**：
    *   我们将在地图上叠加预处理的 **GeoJSON 图层**，直观展示城市环境：
        *   🟢 **绿色区域**：优质运动区（公园、绿道），标记为“推荐”。
        *   🔴 **红色区域**：压力区域（主干道、高噪音区），标记为“警示”。
        *   ⚪ **灰色区域**：GPS 信号弱区（模拟城市高楼峡谷数据）。
*   **交互**：用户点击不同颜色区域，弹窗显示该区域的环境特征分析。

#### **Tab 3: 运动日记 - 数据沉淀 (History: Retention)**
*   **功能**：运动轨迹与历史数据的归档。
*   **离线模式 (Offline Mode)**：
    *   利用 **RelationalStore (SQLite)** 实现本地数据持久化。
    *   即使在无网络环境下，用户依然可以开始运动、记录轨迹点（GPS 坐标数组）、保存记录，并查看过往的历史列表。
    *   网络恢复后，支持（模拟）数据云端同步。

#### **侧滑菜单 (Slide-out Menu)**
*   包含：个人资料设置、离线地图包下载开关（模拟）、关于我们、隐私政策。

---

## 4. Technical Architecture (技术架构)

我们将采用 **MVVM (Model-View-ViewModel)** 架构模式，确保代码的可测试性和模块化。

### 4.1 技术栈 (Tech Stack)
*   **Language**: ArkTS (TypeScript extension).
*   **SDK**: OpenHarmony API 18 / HarmonyOS NEXT.
*   **IDE**: DevEco Studio.
*   **Map Engine**: Huawei Map Kit (用于底图加载、Polyline 绘制、Polygon 图层渲染).
*   **Location**: Location Kit (获取实时 GNSS 坐标).
*   **Database**: Ark Data / RelationalStore (本地 SQLite 存储).
*   **Network**: `http` module (用于访问 OpenWeatherMap API 和 LLM API).
*   **AI Integration**: RESTful API 调用云端大模型 (DeepSeek/OpenAI/Huawei Cloud).

### 4.2 数据流向 (Data Flow)
1.  **Sensing**: APP 启动 -> Location Kit 获取经纬度 -> HTTP 请求天气 API。
2.  **Processing**: 将经纬度与本地 GeoJSON 进行空间匹配（Point-in-Polygon 算法逻辑） -> 判定当前处于“绿区”还是“红区”。
3.  **Reasoning**: 组装 Context Prompt -> 发送给 AI -> 获取自然语言建议。
4.  **Rendering**: 更新 UI 组件 -> 用户看到建议与地图图层。

### 4.3 鸿蒙生态愿景 (Super Device Vision)
*虽然本次课程主要交付手机端 MVP，但我们的架构设计支持鸿蒙分布式流转：在家用 Tablet 规划路线，一键流转至 Watch 查看导航。*

---

## 5. Feasibility Analysis (可行性分析)

作为地理信息工程的学生，我们对本项目的可行性进行了深入评估，特别是考虑到我们处于 ArkTS 入门阶段：

1.  **GIS 能力迁移**：这是我们的核心竞争力。复杂的空间分析（如噪音传播模型、适宜性评价）将在 PC 端使用 ArcGIS/QGIS 完成预处理，并导出为标准的 **GeoJSON** 格式。APP 端仅需负责“渲染”和简单的“点面判断”，极大降低了端侧开发的算法难度。
2.  **AI 辅助开发**：我们将采用 **Spec-Driven (规格驱动)** 的开发模式。利用 Kiro/Cursor 等 AI 编程工具，结合 Huawei 官方文档和 Sample Code，加速 UI 布局和基础逻辑代码的生成。
3.  **API 优先策略**：
    *   天气数据：使用成熟的 OpenWeatherMap API。
    *   智能建议：使用 LLM API，避免在端侧训练模型的复杂性。
4.  **团队分工**：
    *   **Member A (UI/Architecture)**: 负责 App 骨架、Tab 导航、侧滑菜单及 Dashboard UI。
    *   **Member B (GIS/Data)**: 负责 Map Kit 集成、GeoJSON 数据可视化及数据库离线存储。
    *   **Member C (Logic/AI)**: 负责 API 通信、AI Prompt 调试及业务逻辑串联。

---

## 6. Implementation Roadmap (实施计划)

*   **Week 1**: 环境搭建，跑通 Hello World，完成 TabBar 和侧滑菜单的基础 UI 框架。
*   **Week 1**: 集成 Map Kit，实现 GeoJSON 图层（公园、道路）在地图上的静态展示。
*   **Week 2**: 实现 Location Kit 定位，完成 API 接入（天气 + AI），实现 Dashboard 动态数据展示。
*   **Week 3**: 实现 RelationalStore 数据库，完成“开始运动-保存记录-查看历史”的离线闭环，进行单元测试与文档编写。

---

## 7. Conclusion (结语)

CityZen 不仅仅是一个作业，它是地理信息科学与现代移动操作系统的一次融合尝试。我们相信，通过发挥 GIS 专业的特长，结合 Huawei OpenHarmony 强大的分布式能力和 AI 特性，我们能够交付一个既符合 DIMA 课程高标准，又具有实际社会价值的创新应用。

我们期待能接受这个挑战。

---

