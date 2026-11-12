# 硬盘健康（Scrutiny）

每天检查家里服务器每块硬盘的 S.M.A.R.T. 健康数据，指标变差提前提醒，让你赶在数据丢之前备份、换盘。上游项目：[AnalogJ/scrutiny](https://github.com/AnalogJ/scrutiny)（MIT）。

## 现状：还不能装

硬盘授权已按设备 ADR（[wontonapp/wonton#335](https://github.com/wontonapp/wonton/pull/335)）的 `devices.disk` 写进清单：装的时候核心列出宿主硬盘让主人勾选，勾了的盘只读交给容器，并自动随盘给 `SYS_RAWIO`、只读挂宿主 `/run/udev`。

核心还没实现 `devices.disk` 和规范 0.13 的设备声明，这份清单过不了 `plugin check`，装上也扫不到硬盘（collector 扫不到盘，网页上是空仪表盘），所以没有进商店。其余部分（compose、健康检查、通知接线）已按上游文档写好，等核心落地后进开发栈实测。

## 权限

| 权限 | 为什么 |
| --- | --- |
| `devices.disk` | 装时主人勾选要监控的整盘，核心只读交给容器并随盘给 `SYS_RAWIO`（`smartctl` 读 S.M.A.R.T. 需要）。 |
| `cap.SYS_ADMIN` | NVMe 盘查 S.M.A.R.T. 上游额外要求（上游 README，issue #26）；是否必需待核心实测。它是"最高"级：现在所有安装都多一步确认、提示"能控制整台主机"，只有勾了 NVMe 盘的安装才真正用得上。 |
| `notify` | 硬盘告警经核心的内部邮箱发信，转进主人的 Wonton 私聊。 |
| `owner.identity` | 告警邮件的收件人用主人的内部邮箱。 |

不出网：数据采集、网页、通知都在本机完成（通知走核心内部邮箱），镜像里的 smartctl 硬盘库是构建时更新的。

## 说明

- 上游没有任何登录（本来的用法就是只在家庭网络里打开），插件按 `sso: none` 接入，网页在核心网关登录之后。
- 采集频率：上游 omnibus 镜像内置 cron，每天 0 点跑一次 collector，可用环境变量 `COLLECTOR_CRON_SCHEDULE` 改。
- 测试告警接线：`POST /api/health/notify`（网页打开后执行）。

## 图标

`icon.png` 用上游 Scrutiny 的官方标志，来源和许可见 [NOTICE](NOTICE)。
