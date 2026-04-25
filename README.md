# 今天你打了吗 - 打卡提醒 App

一款专为上班族设计的 Android 打卡提醒应用。即使 App 被后台杀死或手机锁屏，也能准时弹出全屏提醒，确保你不会忘记打卡和待办事项。

## 功能特性

### 核心提醒
- **多种提醒类型**：每天、工作日、自定义星期、指定日期
- **快速模板**：一键创建"上班提醒"和"下班提醒"
- **滚轮时间选择器**：iOS 风格的 Cupertino 时间选择器
- **到点自动重复**：到时间后每 5 分钟继续提醒，直到处理
- **全屏提醒弹窗**：支持锁屏状态下弹出提醒界面
- **打卡记录**：记录每次打卡时间，方便回溯

### 待办事项
- **统一列表**：待办事项与打卡提醒共用一个列表，一目了然
- **到时提醒**：待办事项到指定时间自动发送通知提醒
- **标记完成**：点击复选框即可标记完成，已完成显示删除线
- **快速创建**：添加页面一键切换「打卡提醒 / 待办事项」
- **自动排序**：未完成待办排在前面，已完成排在最后

### 后台可靠性
- **前台服务（Foreground Service）**：保持进程常驻，防止系统杀死
- **自动重启**：App 被从最近任务划掉后，1 秒内自动重启服务
- **精确闹钟调度**：使用 Android AlarmManager 确保准时触发
- **开机自启**：设备重启后自动恢复所有提醒

### 权限管理
- **权限状态面板**：实时显示通知、精确闹钟、全屏通知、电池优化等权限状态
- **一键跳转设置**：自动引导用户到系统设置页开启所需权限
- **电池优化检测**：自动检测电池优化关闭状态

### 列表体验
- **下拉刷新**：支持下拉刷新列表数据
- **自动刷新**：切换 Tab、从弹窗返回、App 恢复前台时自动刷新

## 技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| Flutter | >=2.17.0 | 跨平台 UI 框架 |
| sqflite | ^2.0.0 | SQLite 本地数据库 |
| flutter_local_notifications | ^9.0.0 | 本地通知与定时调度 |
| audioplayers | ^1.0.0 | 提醒声音播放 |
| timezone | ^0.8.0 | 时区处理 |
| flutter_native_timezone | ^2.0.0 | 获取设备时区 |
| android_intent_plus | ^5.3.0 | 跳转系统设置页 |
| shared_preferences | ^2.0.0 | 轻量级本地存储 |

## 项目结构

```
lib/
├── main.dart                    # 应用入口、主页、设置页
├── models/
│   └── reminder.dart            # 提醒数据模型
├── screens/
│   ├── add_reminder_screen.dart # 添加/编辑提醒页
│   ├── reminder_list_screen.dart# 提醒列表页
│   ├── reminder_dialog.dart     # 全屏提醒弹窗
│   └── punch_record_screen.dart # 打卡记录页
└── services/
    ├── database_service.dart    # SQLite 数据库操作
    ├── notification_service.dart# 通知服务
    └── reminder_service.dart    # 提醒调度核心逻辑

android/
├── app/src/main/
│   ├── AndroidManifest.xml      # 权限声明与服务注册
│   ├── kotlin/.../MainActivity.kt       # 主 Activity + 原生方法
│   ├── kotlin/.../ReminderForegroundService.kt  # 前台服务
│   └── res/                     # 图标、主题、颜色资源
```

## Android 权限说明

| 权限 | 用途 | 是否必须 |
|------|------|----------|
| `POST_NOTIFICATIONS` | 显示通知（Android 13+） | 是 |
| `SCHEDULE_EXACT_ALARM` | 精确闹钟调度 | 是 |
| `USE_EXACT_ALARM` | 精确闹钟（Android 14+） | 是 |
| `USE_FULL_SCREEN_INTENT` | 锁屏全屏提醒 | 是 |
| `RECEIVE_BOOT_COMPLETED` | 开机自启恢复提醒 | 是 |
| `FOREGROUND_SERVICE` | 前台服务常驻 | 是 |
| `WAKE_LOCK` | 唤醒设备处理提醒 | 是 |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | 关闭电池优化 | 推荐 |
| `SYSTEM_ALERT_WINDOW` | 悬浮窗（部分机型需要） | 推荐 |

## 构建与运行

### 环境要求
- Flutter SDK >=2.17.0
- JDK 17
- Android SDK 33+

### 构建步骤

```bash
# 1. 安装依赖
flutter pub get

# 2. 构建 Release APK
flutter build apk --release

# 3. APK 输出路径
# build/app/outputs/flutter-apk/app-release.apk
```

### 安装到设备

```bash
# 通过 ADB 安装
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 使用说明

### 添加打卡提醒
1. 点击主页右下角的 **+** 按钮
2. 选择 **"添加打卡提醒"**
3. 选择快速模板（上班/下班提醒）或手动设置
4. 设置提醒名称、时间、重复类型
5. 点击右上角保存

### 添加待办事项
1. 点击主页右下角的 **+** 按钮
2. 选择 **"添加待办事项"**
3. 输入待办事项名称、选择日期和时间
4. 点击右上角保存

### 处理提醒
- 打卡提醒到时间后会弹出全屏提醒界面
- 点击 **"立即打卡"** 记录打卡时间并关闭提醒
- 点击 **"关闭本轮提醒"** 仅关闭当前提醒
- 如果不处理，每 5 分钟会再次提醒

### 处理待办事项
- 待办事项到时间后会弹出全屏提醒界面
- 点击 **"标记完成"** 标记为已完成
- 点击 **"稍后处理"** 关闭当前提醒
- 在列表中点击复选框也可直接标记完成

### 列表操作
- **下拉刷新**：在列表页面下拉可刷新数据
- **自动刷新**：切换 Tab、从弹窗返回时自动刷新
- **编辑**：点击卡片可编辑提醒或待办事项
- **删除**：点击卡片右侧删除图标可删除

### 权限设置
1. 进入底部导航栏 **"设置"** 页面
2. 查看各项权限状态
3. 点击 **"去开启"** 跳转系统设置页
4. 授权后返回，状态会自动更新

## 工作原理

### 提醒调度
```
用户创建提醒 → SQLite 持久化 → 计算未来 7 天的触发时间
→ 每个时间点生成 5 条通知（间隔 5 分钟）
→ 通过 flutter_local_notifications 注册到 Android AlarmManager
```

### 后台保活
```
App 启动 → 启动 Foreground Service（START_STICKY）
→ 用户划掉 App → onTaskRemoved() 触发
→ AlarmManager 延迟 1 秒重启 Service
→ Service 恢复，继续监听提醒
```

### 提醒触发链路
```
AlarmManager 到时 → 系统发送通知 → 用户点击通知
→ App 拉起 → _handleNotificationSelection()
→ 弹出全屏 ReminderDialog → 用户处理
```

## 常见问题

### Q: 提醒不触发怎么办？
A: 请检查以下设置：
1. 通知权限是否已开启
2. 精确闹钟权限是否已开启（设置页 → 精确闹钟 → 去开启）
3. 是否已关闭电池优化
4. 是否已允许自启动

### Q: 锁屏时不弹出提醒？
A: 需要开启"全屏通知"权限，在设置页面可以一键跳转到系统设置。

### Q: 杀掉 App 后提醒失效？
A: 本 App 已内置前台服务和自动重启机制。如果仍然失效，请检查：
1. 系统是否允许自启动
2. 电池优化是否已关闭
3. 部分国产手机需要在系统设置中手动允许后台运行

### Q: 只有第一个提醒会响？
A: Android 系统对单个 App 的通知数量有限制（约 500 条）。本 App 已优化为每个提醒最多生成 56 条通知（7 天 x 8 次/天），正常使用不会触达上限。

## 开发说明

### 关键设计决策
- 使用 `flutter_local_notifications 9.x`（非 10+），保持 `onSelectNotification` 回调
- 通知 ID 编码规则：`reminderId * 1000 + occurrenceIndex * 100 + repeatIndex`
- 待办通知 ID 编码：`reminderId * 1000 + 999`（与打卡提醒不冲突）
- 前台服务使用 `specialUse` 类型，兼容 Android 14+
- 时间选择器使用 `CupertinoDatePicker` 替代 Material 弹窗
- 待办事项与打卡提醒共用 `reminders` 表，通过 `itemType` 字段区分

### 数据库表结构
```sql
-- 提醒/待办统一表
CREATE TABLE reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  hour INTEGER,
  minute INTEGER,
  days TEXT,          -- 逗号分隔的星期几 (1=周一, 7=周日)
  isEnabled INTEGER,  -- 0=禁用, 1=启用
  soundPath TEXT,
  type INTEGER,       -- 0=每天, 1=工作日, 2=自定义, 3=指定日期
  customDate INTEGER, -- 毫秒时间戳
  itemType INTEGER DEFAULT 0,   -- 0=打卡提醒, 1=待办事项
  isCompleted INTEGER DEFAULT 0, -- 0=未完成, 1=已完成
  dueDate INTEGER               -- 待办截止日期（毫秒时间戳）
);

-- 打卡记录表
CREATE TABLE punch_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reminderId INTEGER,
  punchTime INTEGER,  -- 毫秒时间戳
  FOREIGN KEY (reminderId) REFERENCES reminders(id)
);
```

## 许可证

本项目仅供个人学习使用。
