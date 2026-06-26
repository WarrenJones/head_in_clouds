import SwiftUI

struct WelcomeView: View {
    let onStartWriting: () -> Void
    let onAddFlight: () -> Void

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 52)

                brandBlock
                    .padding(.bottom, 28)

                PostcardAnchorView()
                    .frame(maxWidth: 308)
                    .padding(.bottom, 28)

                VStack(spacing: 8) {
                    Text("登机前 30 分钟，给这趟飞行留一句话")
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(HICTheme.cream)
                        .tracking(0.5)

                    Text("落地后，生成一张只属于云上的明信片")
                        .font(.system(size: 12))
                        .foregroundStyle(HICTheme.mist.opacity(0.56))
                        .tracking(0.3)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    PrimaryCloudButton(title: "写下这一趟", action: onStartWriting)
                        .accessibilityIdentifier("welcome.write")
                    SecondaryCloudButton(title: "添加航班信息", systemImage: "airplane.departure", action: onAddFlight)
                }
                .frame(maxWidth: 308)

                Spacer(minLength: 28)

                Text("票证原图默认不保存")
                    .font(.system(size: 10, weight: .regular))
                    .tracking(0.5)
                    .foregroundStyle(HICTheme.mist.opacity(0.34))
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 28)
        }
    }

    private var brandBlock: some View {
        VStack(spacing: 8) {
            Text("Head in the Clouds")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(HICTheme.cream)
                .tracking(-0.2)

            Text("云·上·心·事")
                .font(.system(size: 13, weight: .light, design: .serif))
                .tracking(7)
                .foregroundStyle(HICTheme.gold.opacity(0.66))
        }
        .accessibilityElement(children: .combine)
    }
}

struct PostcardAnchorView: View {
    var quote = "我把没有说出口的话，带过了云层。"
    var route = "航线待补"
    var meta = "航班待确认"
    var detail = "时间待补 · 私人明信片"

    private var routeEndpoints: (String, String) {
        let parts = route
            .components(separatedBy: "→")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count == 2 else { return ("起点", "终点") }
        return (parts[0], parts[1])
    }

    private var routeDetail: String {
        route == "航线待补" ? "航线坐标稍后补齐" : "\(route) · 坐标待补"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(meta)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    Text(route)
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                    Text(detail)
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                }
                .foregroundStyle(HICTheme.ink.opacity(0.82))

                Spacer()

                PostmarkView(size: 42, ink: HICTheme.ink)
            }
            .padding(.bottom, 10)

            Divider()
                .overlay(HICTheme.ink.opacity(0.16))
                .padding(.bottom, 12)

            Text(quote)
                .font(.system(size: quote.count <= 16 ? 21 : 18, weight: .semibold, design: .serif))
                .foregroundStyle(HICTheme.ink)
                .lineSpacing(7)
                .tracking(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)

            HStack(spacing: 6) {
                Text(routeEndpoints.0)
                DashedRouteLine()
                Text(routeEndpoints.1)
            }
            .font(.system(size: 7.5, weight: .regular, design: .monospaced))
            .foregroundStyle(HICTheme.ink.opacity(0.64))

            Text(routeDetail)
                .font(.system(size: 6.5, weight: .regular, design: .monospaced))
                .foregroundStyle(HICTheme.ink.opacity(0.36))
                .padding(.top, 5)
                .padding(.bottom, 12)

            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(HICTheme.ink.opacity(0.22), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Image(systemName: "cloud")
                            .font(.system(size: 6))
                            .foregroundStyle(HICTheme.ink.opacity(0.48))
                    }

                Text("Head in the Clouds / 云上心事")
                    .font(.system(size: 7, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(HICTheme.ink.opacity(0.42))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HICTheme.cream, HICTheme.paper],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperLines().opacity(0.55))
        }
        .padding(10)
        .background(HICTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(color: .black.opacity(0.58), radius: 30, y: 16)
    }
}

struct PermissionPrimerView: View {
    let onContinue: () -> Void

    private let items: [PermissionItem] = [
        .init(icon: "camera", title: "相机", desc: "识别登机牌上的航班信息", trigger: "拍登机牌时申请", tint: Color(red: 0.48, green: 0.56, blue: 0.72)),
        .init(icon: "photo", title: "相册", desc: "从相册选截图，或把 Cloud Card 存到本机", trigger: "保存 Cloud Card 时申请", tint: Color(red: 0.49, green: 0.63, blue: 0.54)),
        .init(icon: "bell", title: "通知", desc: "登机前提醒你留下这一趟的心事", trigger: "添加登机提醒时申请", tint: HICTheme.gold)
    ]

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                StepDots(activeIndex: 1, count: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 54)
                    .padding(.bottom, 40)

                Text("为了你的飞行心事，\n我们需要：")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(8)
                    .padding(.bottom, 30)

                VStack(spacing: 12) {
                    ForEach(items) { item in
                        PermissionRow(item: item)
                    }
                }

                Spacer()

                Text("以上权限均在你实际用到时才申请，不提前索权")
                    .font(.system(size: 11))
                    .foregroundStyle(HICTheme.mist.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                SecondaryCloudButton(title: "继续，不现在授权", action: onContinue)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct PrivacyPromiseView: View {
    let onContinue: () -> Void

    private let items: [PermissionItem] = [
        .init(icon: "lock.shield", title: "票证原图默认不保存到云", desc: "OCR 完成后立即销毁，永远不上传原图", trigger: "", tint: Color(red: 0.48, green: 0.61, blue: 0.61)),
        .init(icon: "eye.slash", title: "卡片不显示任何敏感字段", desc: "只显示航班号、起降地、时间；不显示姓名、座位号、票号", trigger: "", tint: Color(red: 0.61, green: 0.56, blue: 0.63)),
        .init(icon: "bubble.left.and.bubble.right", title: "评论只在你那趟航班内可见", desc: "同机乘客才能看到评论，陌生人看不到你的任何细节", trigger: "", tint: Color(red: 0.49, green: 0.63, blue: 0.54))
    ]

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                StepDots(activeIndex: 2, count: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 54)
                    .padding(.bottom, 40)

                Image(systemName: "lock")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(HICTheme.gold.opacity(0.74))
                    .frame(width: 52, height: 52)
                    .background(HICTheme.gold.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(HICTheme.gold.opacity(0.18), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 20)

                Text("你的票，\n只在你手里")
                    .font(.system(size: 25, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(8)
                    .padding(.bottom, 30)

                VStack(spacing: 14) {
                    ForEach(items) { item in
                        PromiseRow(item: item)
                    }
                }

                Spacer()

                PrimaryCloudButton(title: "我知道了，继续", action: onContinue)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct GetStartedView: View {
    let onStart: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                StepDots(activeIndex: 3, count: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 54)

                Spacer()

                RouteArcView()
                    .frame(width: 52, height: 32)
                    .padding(.bottom, 26)

                Text("准备好了吗？")
                    .font(.system(size: 38, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .padding(.bottom, 16)

                Text("不需要注册，\n直接开始你的第一次")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HICTheme.mist.opacity(0.72))
                    .lineSpacing(9)
                    .padding(.bottom, 52)

                PrimaryCloudButton(title: "开始我的第一次飞行", action: onStart)
                    .padding(.bottom, 14)

                HStack(spacing: 4) {
                    Spacer()
                    Text("已有账号？")
                        .foregroundStyle(HICTheme.mist.opacity(0.45))
                    Button("登录", action: onSignIn)
                        .foregroundStyle(HICTheme.gold.opacity(0.72))
                        .underline(true, color: HICTheme.gold.opacity(0.72))
                    Spacer()
                }
                .font(.system(size: 12))
                .padding(.bottom, 12)

                Text("之后可以选择绑定微信或手机号\n换设备也能找回你的飞行记录")
                    .font(.system(size: 10))
                    .foregroundStyle(HICTheme.mist.opacity(0.40))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Spacer()

                Text("Head in the Clouds")
                    .font(.system(size: 9, weight: .regular, design: .serif))
                    .italic()
                    .tracking(3)
                    .foregroundStyle(HICTheme.gold.opacity(0.22))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
        }
    }
}

struct OpeningView: View {
    let onWrite: () -> Void
    let onAddFlight: () -> Void
    let onReminder: () -> Void
	let onMyFlights: () -> Void
	let onExplore: () -> Void
	let onSettings: () -> Void
	var flightRecordCount = 0

    var body: some View {
        ZStack {
            NightBackground()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Head in the Clouds")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundStyle(HICTheme.cream)
                        Text("今天这趟，先留一句话")
                            .font(.system(size: 12))
                            .tracking(0.4)
                            .foregroundStyle(HICTheme.gold.opacity(0.56))
                    }

                    Spacer()

                    Button {
                        HICFeedback.impact(.light)
                        onSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                            .foregroundStyle(HICTheme.mist.opacity(0.50))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(CloudPressButtonStyle(kind: .icon))
                    .accessibilityLabel("账号设置")
                    .accessibilityIdentifier("opening.settings")
                }
                .padding(.top, 54)
                .padding(.bottom, 28)

                PostcardAnchorView(
                    quote: "我在起飞前最后一次看见这座城市的灯。",
                    route: "航线待补",
                    meta: "航班待确认"
                )
                .padding(.bottom, 22)

                Divider()
                    .overlay(.white.opacity(0.06))
                    .padding(.bottom, 22)

                Text("准备好下一次\n飞行了吗？")
                    .font(.system(size: 25, weight: .medium, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(7)
                    .padding(.bottom, 8)

                Text("一句话就够，航班信息可以稍后补")
                    .font(.system(size: 14))
                    .foregroundStyle(HICTheme.mist.opacity(0.62))

                Spacer()

                VStack(spacing: 10) {
                    PrimaryCloudButton(title: "写下这一趟", action: onWrite)
                        .accessibilityIdentifier("opening.write")
                    SecondaryCloudButton(title: "添加航班号 / 扫登机牌", systemImage: "airplane.departure", action: onAddFlight)
                    SecondaryCloudButton(title: "添加登机提醒", systemImage: "bell", action: onReminder)
	                    SecondaryCloudButton(title: "我的飞行册 \(flightRecordCount)", systemImage: "book.closed", action: onMyFlights)
                    SecondaryCloudButton(title: "看看别人留下的", systemImage: "sparkles", action: onExplore)
                }
                .padding(.bottom, 10)

                Text("票证原图默认不保存")
                    .font(.system(size: 10))
                    .foregroundStyle(HICTheme.mist.opacity(0.40))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct PermissionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let desc: String
    let trigger: String
    let tint: Color
}

private struct PermissionRow: View {
    let item: PermissionItem

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: item.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(item.tint)
                .frame(width: 48, height: 48)
                .background(item.tint.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(item.tint.opacity(0.22), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(HICTheme.mist.opacity(0.92))
                Text(item.desc)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(HICTheme.mist.opacity(0.62))
                Text(item.trigger)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(HICTheme.mist.opacity(0.48))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.white.opacity(0.03))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PromiseRow: View {
    let item: PermissionItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(item.tint)
                .frame(width: 40, height: 40)
                .background(item.tint.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.tint.opacity(0.22), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HICTheme.mist.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.desc)
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .foregroundStyle(HICTheme.mist.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white.opacity(0.025))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PostmarkView: View {
    let size: CGFloat
    let ink: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(ink.opacity(0.30), lineWidth: 1.4)
            Circle()
                .stroke(ink.opacity(0.16), lineWidth: 1)
                .padding(5)
            VStack(spacing: -1) {
                Text("Head")
                Text("in the")
                Text("Clouds")
            }
            .font(.system(size: 6, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(ink.opacity(0.50))
        }
        .frame(width: size, height: size)
    }
}

private struct DashedRouteLine: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(HICTheme.ink.opacity(0.22))
                .frame(height: 1)
            Image(systemName: "airplane")
                .font(.system(size: 8))
                .foregroundStyle(HICTheme.ink.opacity(0.56))
                .background(HICTheme.paper)
        }
    }
}

struct PaperLines: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let height = proxy.size.height
                stride(from: CGFloat(18), through: height, by: 18).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(Color.black.opacity(0.025), lineWidth: 1)
        }
    }
}

struct RouteArcView: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 4, y: size.height - 8))
            path.addQuadCurve(
                to: CGPoint(x: size.width - 4, y: size.height - 8),
                control: CGPoint(x: size.width / 2, y: 4)
            )
            context.stroke(path, with: .color(HICTheme.gold.opacity(0.36)), lineWidth: 1)

            for point in [CGPoint(x: 4, y: size.height - 8), CGPoint(x: size.width / 2, y: 9), CGPoint(x: size.width - 4, y: size.height - 8)] {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(HICTheme.gold.opacity(0.58)))
            }
        }
    }
}
