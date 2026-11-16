# Pray Like Incense - Flutter App

这是一个基于Flutter开发的祈祷社区应用，实现了Web版本的界面和功能。

## 功能特性

### 1. UI界面优化
- 底部导航栏图标统一大小，避免对不齐问题
- 固定底部导航栏，不会随键盘弹起而移动
- 左上角用户头像显示
- 顶部通知图标和Y币显示

### 2. 通知功能
- 右上角通知图标可点击进入通知页面
- 通知页面支持分页加载
- 通知数量显示

### 3. 贴文功能
- 贴文分页加载（每页25条）
- 无限滚动加载更多贴文
- 发布新贴文（带标题和内容）
- 编辑已有贴文（铅笔图标）
- 贴文点赞功能
- 贴文评论功能
- Witness功能（文字和图片上传）

### 4. Y币系统
- Y币显示组件，避免抖动
- 各种操作自动增加Y币（发布、点赞、评论、Witness）
- Y币余额实时更新显示

### 5. CSRF保护
- 所有API请求都包含必要的CSRF保护头
- X-Requested-With请求头
- Referer请求头
- Origin请求头

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── home/
│   └── home_page.dart        # 主页
├── widgets/
│   ├── app_bottom_navigation_bar.dart  # 底部导航栏
│   ├── post_card.dart        # 贴文卡片
│   ├── ycoin_display.dart    # Y币显示
│   └── notification_badge.dart  # 通知徽章
├── pages/
│   └── notification_page.dart  # 通知页面
└── services/
    ├── api_client.dart       # API客户端
    ├── auth_service.dart     # 认证服务
    ├── posts_service.dart    # 贴文服务
    ├── ycoin_service.dart    # Y币服务
    └── witness_service.dart  # Witness服务
```

## 构建和运行

1. 确保已安装Flutter环境
2. 运行 `flutter pub get` 获取依赖
3. 运行 `flutter run` 启动应用

## 开发说明

所有功能都已根据Web版本界面要求实现，重点关注：
- UI布局统一性
- 功能完整性
- 用户体验优化
- CSRF安全防护
