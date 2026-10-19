import AppKit
import Localization
import Metrics
import SwiftUI

/// 主窗口。左侧切换页面，右侧是仪表盘、各指标详情与工具页；窗口宽高都可调整。
/// 整个窗口垫一层灰色底（系统侧边栏材质），侧边栏直接排在底上；右侧页面装在一张大的圆角卡片里，
/// 上、右、下三边与窗口留一圈边距，红绿灯按钮落在左上角的灰底上
public struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.isSnapshot) private var isSnapshot

    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            MainSidebar()
                .frame(width: DS.Size.sidebarWidth)
                .frame(maxHeight: .infinity)
                .environment(\.isInsideGlass, true)

            // 截图时页面取自身高度，卡片仍然撑满到底：侧边栏更高时，多出来的是卡片的空白
            content
                .frame(minWidth: DS.Size.panelWidth, maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .top)
                .modifier(ContentCard())
        }
        .frame(width: isSnapshot ? DS.Size.mainWindowMinWidth : nil)
        .fixedSize(horizontal: false, vertical: isSnapshot)
        // 卡片上方那一条灰底与侧边栏顶部都在标题栏里，按住可以拖动窗口；卡片本身挡在上面，不受影响
        .background(alignment: .top) {
            WindowDragArea().frame(height: DS.Size.windowHeader)
        }
        .background { WindowBase() }
        // 需要等待的任务进行中，整个窗口压暗并显示加载框
        .loadingHUD(isSnapshot ? nil : busyMessage)
        // 内容延伸到透明标题栏下方，由顶栏高度留出红绿灯按钮的位置
        .ignoresSafeArea()
        // 文案在各视图计算时翻译好，切换语言后整棵视图重建
        .id(model.settings.language)
    }

    /// 顶栏在上、页面在下。没有用 macOS 26 的 safeAreaBar 让页面从顶栏下面滚过：
    /// 它在 macOS 上会在交界处画一条分隔线，滚动边缘样式设成柔和或隐藏都去不掉
    private var content: some View {
        VStack(spacing: 0) {
            // 页面的滚动视图会自动向上延伸到标题栏下面，与顶栏重叠；顶栏必须在它之上，否则开关收不到点击
            PageHeader()
                .zIndex(1)
            page
        }
    }

    /// 需要等待、期间不宜继续操作的任务
    private var busyMessage: String? {
        if model.cleaner.phase == .cleaning { return tr("正在清理…") }
        if model.uninstaller.isRemoving { return tr("正在移除…") }
        if model.diagnostics.phase == .collecting { return tr("正在导出诊断信息…") }
        if model.maintenance.isApplyingDNS { return tr("正在修改 DNS…") }
        return nil
    }

    private var page: some View {
        Group {
            switch model.settings.panelTab {
            case .overview: OverviewPage()
            case .system: SystemInfoPage()
            case .history: HistoryPage()
            case .cpu: DetailPage { CPUPopover() }
            case .gpu: DetailPage { GPUPopover() }
            case .memory: DetailPage { MemoryPopover() }
            case .disk: DiskPage()
            case .network:
                DetailPage {
                    NetworkPopover()
                    NetworkSettings()
                }
            case .thermal: ThermalPage()
            case .battery: DetailPage { BatteryPopover() }
            case .processes: ProcessesPage()
            case .keepAwake: KeepAwakePage()
            case .cleaner: CleanerPage()
            case .uninstaller: UninstallerPage()
            case .startupItems: StartupItemsPage()
            case .settingsGeneral: SettingsTabPage { GeneralSettings() }
            case .settingsMenuBar: SettingsTabPage { MenuBarSettings() }
            case .settingsNotifications: SettingsTabPage { NotificationSettings() }
            case .settingsAccount: SettingsTabPage { AccountSettings() }
            case .settingsHelper: SettingsTabPage { HelperSettings() }
            case .settingsAbout: SettingsTabPage { AboutSettings() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: isSnapshot ? nil : .infinity, alignment: .top)
        // 截图时页面取自身高度：侧边栏更高时，多出的高度不能分给页面里可伸展的卡片
        .fixedSize(horizontal: false, vertical: isSnapshot)
    }
}

/// 右侧页面的大卡片：页面底色、圆角裁切，上、右、下三边让出一圈灰底。
/// 阴影只画在底板上，不让整棵页面（图表每秒刷新）参与阴影计算
private struct ContentCard: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
        content
            .clipShape(shape)
            .background {
                shape.fill(DS.Palette.background).dsShadow(DS.Shadow.level1)
            }
            .padding([.top, .trailing, .bottom], DS.Size.mainWindowInset)
    }
}

/// 窗口底层：系统侧边栏材质，浅色是透出一点桌面颜色的浅灰，深色是深灰，窗口失焦时变为实色。
/// 离屏截图拍不出材质，画相近的实色
private struct WindowBase: View {
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            DS.Palette.windowBase
        } else {
            SidebarMaterial()
        }
    }
}

private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// 指标详情页：复用菜单栏弹窗的内容，显示全部区块
private struct DetailPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        PageScroll { content }
            .environment(\.isDetailPage, true)
    }
}

private struct MainSidebar: View {
    @Environment(AppModel.self) private var model

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s3) {
            // 三组导航加起来较高，窗口矮时侧边栏自己滚动，底部按钮始终可见
            if isSnapshot {
                navigation
            } else {
                ScrollView { navigation.overlayScrollers() }
                    .scrollBounceBehavior(.basedOnSize)
            }

            // 固定在导航下面，切到哪一页都在，不用进防休眠、温度与风扇页
            SidebarQuickSwitches()
                .padding(.leading, DS.Space.s2)

            HStack(spacing: DS.Space.s1) {
                ThemeToggle()
                Spacer(minLength: 0)
                IconButton(systemName: "power", help: tr("退出 OpenStats")) { model.quit() }
            }
            .padding(.leading, DS.Space.s2)
        }
        .padding(.leading, DS.Space.s1)
        .padding(.trailing, DS.Space.s3)
        // 顶部让出标题栏的高度，红绿灯按钮在这一条里
        .padding(.top, DS.Size.windowHeader)
        .padding(.bottom, DS.Space.s3)
    }

    private var navigation: some View {
        VStack(alignment: .leading, spacing: DS.Space.s1) {
            group(tr("监控"), PanelTab.monitors)
            group(tr("工具"), PanelTab.tools)
            group(tr("设置"), PanelTab.settings)
        }
        .sidebarGlider()
        // 光条的发光向左溢出几个点，留出空间避免被滚动区域裁掉
        .padding(.leading, DS.Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badge(for tab: PanelTab) -> Tone? {
        switch tab {
        case .settingsAbout: model.updates.release != nil ? .primary : nil
        case .settingsHelper: model.helper.isReady && model.helper.isOutdated ? .warning : nil
        case .settingsAccount:
            if model.sync.conflict != nil { .primary } else if case .failed = model.sync.phase { .warning } else { nil }
        default: nil
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ tabs: [PanelTab]) -> some View {
        Text(title)
            .dsFont(.xs, weight: .medium)
            .foregroundStyle(DS.Palette.textTertiary)
            .padding(.horizontal, DS.Space.s2)
            .padding(.top, DS.Space.s2)
        ForEach(tabs) { tab in
            SidebarButton(title: tab.title, symbol: tab.symbol, isSelected: model.settings.panelTab == tab, badge: badge(for: tab)) {
                model.settings.panelTab = tab
            }
        }
    }
}

/// 侧边栏底部的快捷开关：防休眠与风扇调速，点开关即生效。
/// 点名称进入对应页面调细项；右键直接选防休眠时长、开关合盖运行，或选风扇档位。没有风扇的 Mac 只显示防休眠
private struct SidebarQuickSwitches: View {
    @Environment(AppModel.self) private var model

    private static let durations: [KeepAwakeController.Duration] = [.hour1, .hours2, .hours4, .hours8, .hours12, .unlimited]
    private static let fanModes: [FanController.Mode] = [.automatic, .cooling, .maximum]

    var body: some View {
        let keepAwake = model.keepAwake
        let fans = model.fans

        VStack(alignment: .leading, spacing: 0) {
            Text(tr("快捷开关"))
                .dsFont(.xs, weight: .medium)
                .foregroundStyle(DS.Palette.textTertiary)
                .padding(.horizontal, DS.Space.s2)
                .padding(.bottom, DS.Space.s1)

            SidebarSwitchRow(icon: keepAwake.isActive ? "cup.and.saucer.fill" : "cup.and.saucer",
                             title: tr("防休眠"), detail: keepAwakeDetail,
                             help: tr("点名称打开防休眠页设置屏幕是否常亮；右键直接选时长或开启合盖运行"),
                             isOn: Binding(get: { keepAwake.isActive },
                                           set: { value in Task { await keepAwake.setActive(value) } })) {
                model.settings.panelTab = .keepAwake
            } menu: {
                ForEach(Self.durations) { duration in
                    Toggle(duration.title, isOn: Binding(get: { keepAwake.isActive && keepAwake.duration == duration }, set: { _ in
                        keepAwake.setDuration(duration)
                        if !keepAwake.isActive { Task { await keepAwake.start() } }
                    }))
                }
                Divider()
                // 打开时一并开启防休眠；没装辅助工具时跳到防休眠页引导安装
                Toggle(tr("合盖后继续运行"), isOn: Binding(get: { keepAwake.lidClosedRequested }, set: { model.requestLidMode($0) }))
                if keepAwake.isActive {
                    Divider()
                    Button(tr("关闭防休眠")) { Task { await keepAwake.setActive(false) } }
                }
            }

            if hasFans {
                SidebarSwitchRow(icon: "fan", title: tr("风扇调速"),
                                 detail: fans.mode == .automatic ? tr("系统自动") : tr("\(fans.mode.title)中"),
                                 help: tr("打开时沿用上次选的档位；点名称打开温度与风扇页设置自定义转速，右键直接选档位"),
                                 isOn: Binding(get: { fans.mode != .automatic }, set: { model.requestFanControl($0) })) {
                    model.settings.panelTab = .thermal
                } menu: {
                    ForEach(Self.fanModes) { mode in
                        Toggle(mode.title, isOn: Binding(get: { fans.mode == mode }, set: { if $0 { model.requestFanMode(mode) } }))
                    }
                }
            }
        }
        .task { await model.fans.loadFansIfNeeded() }
    }

    private var hasFans: Bool { !(model.store.sensors?.fans.isEmpty ?? true) }

    /// 开启时显示结束时间而不是倒计时：侧边栏窄，也不用每分钟刷新
    private var keepAwakeDetail: String {
        let keepAwake = model.keepAwake
        guard keepAwake.isActive else { return tr("按系统休眠") }
        guard let end = keepAwake.endDate else { return tr("不限时") }
        return tr("\(end.formatted(date: .omitted, time: .shortened)) 结束")
    }
}

/// 快捷开关的一行：图标与缩进和导航项对齐，名称下面一行是当前状态，右侧是开关
private struct SidebarSwitchRow<MenuItems: View>: View {
    let icon: String
    let title: String
    let detail: String
    let help: String
    @Binding var isOn: Bool
    let open: () -> Void
    @ViewBuilder var menu: MenuItems
    @State private var hovering = false

    var body: some View {
        HStack(spacing: DS.Space.s2) {
            Button(action: open) {
                HStack(spacing: DS.Space.s2) {
                    Image(systemName: icon)
                        .dsFont(.sm, weight: .medium)
                        .foregroundStyle(isOn ? DS.Palette.primary : hovering ? DS.Palette.textPrimary : DS.Palette.textSecondary)
                        .frame(width: DS.Size.iconStandalone)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .dsFont(.sm)
                            .foregroundStyle(hovering ? DS.Palette.textPrimary : DS.Palette.textSecondary)
                        Text(detail)
                            .dsFont(.xs)
                            .monospacedDigit()
                            .foregroundStyle(isOn ? DS.Palette.primary : DS.Palette.textTertiary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .animation(DS.Motion.quick, value: hovering)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(help)

            DSToggle(isOn: $isOn, label: title)
        }
        // 开关贴齐侧边栏右边缘，给名称多留一点宽度（英文的 Keep Awake）
        .padding(.leading, DS.Space.s3)
        .padding(.vertical, DS.Space.s1)
        .contextMenu { menu }
    }
}

private struct PageHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let settings = model.settings
        let tab = settings.panelTab

        HStack(spacing: DS.Space.s3) {
            // 拖动窗口的区域只覆盖标题和空白，按钮与开关不在拖动层上
            HStack(spacing: 0) {
                Text(tab.headerTitle)
                    .dsFont(.base, weight: .semibold)
                    .foregroundStyle(DS.Palette.textPrimary)
                Spacer(minLength: DS.Space.s3)
            }
            .frame(maxHeight: .infinity)
            .background(WindowDragArea())

            if tab == .memory { PurgeMemoryButton() }
            if tab == .network {
                Button { model.openSpeedTestWindow() } label: {
                    HStack(spacing: DS.Space.s1) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                        Text(tr("网络测速")).lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(DSButtonStyle(kind: .secondary))
                .help(tr("测本机宽带、国内分省三网延迟与全球节点"))
            }
            if tab == .network {
                Button { model.openEgressWindow() } label: {
                    HStack(spacing: DS.Space.s1) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(tr("出口与分流")).lineLimit(1).fixedSize()
                    }
                }
                .buttonStyle(DSButtonStyle(kind: .secondary))
                .help(tr("检查 VPN 与代理是否生效、各网站从哪个出口出去"))
            }
            // 每个监控页都能在这里开关自己的菜单栏项目；温度与风扇页有两项，各带一个小标签
            let items = tab.menuBarItems
            if !items.isEmpty {
                // macOS 26 上这一组收进一块超椭圆圆角的玻璃
                HStack(spacing: DS.Space.s3) {
                    Text(tr("在菜单栏显示")).dsFont(.xs).foregroundStyle(DS.Palette.textSecondary)
                    ForEach(items) { item in
                        if items.count > 1 {
                            Text(item.popoverTitle).dsFont(.xs).foregroundStyle(DS.Palette.textTertiary)
                        }
                        DSToggle(isOn: Binding(get: { settings.isEnabled(item) }, set: { settings.setEnabled(item, $0) }),
                                 label: tr("在菜单栏显示\(item.title)"))
                            .help(tr("开启后图标出现在菜单栏；按住 ⌘ 键拖动图标可以调整位置"))
                    }
                }
                .modifier(HeaderControlGroup())
            }
        }
        .padding(.horizontal, DS.Space.s3 + DS.Space.s1)
        // 52pt 高的顶栏里，32pt 的按钮与开关组上下各留 10pt
        .frame(height: DS.Size.windowHeader)
    }
}

/// 顶栏右侧的一组控件：macOS 26 上收进一块超椭圆圆角的玻璃，更早的系统直接排开
private struct HeaderControlGroup: ViewModifier {
    func body(content: Content) -> some View {
        if DS.Glass.isAvailable {
            content
                .padding(.leading, DS.Space.s4)
                .padding(.trailing, DS.Space.s2)
                .frame(height: DS.Size.controlHeight)
                .dsGlass(in: ControlShape())
        } else {
            content
        }
    }
}

/// 在浅色与深色之间切换；当前跟随系统时，切到与系统相反的那一种
private struct ThemeToggle: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        IconButton(systemName: isDark ? "sun.max" : "moon", help: isDark ? tr("切换到浅色") : tr("切换到深色")) {
            model.settings.appearance = isDark ? .light : .dark
        }
    }
}

struct AppGlyph: View {
    var size: CGFloat = DS.Size.controlHeight

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
