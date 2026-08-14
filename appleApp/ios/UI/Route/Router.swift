import SwiftUI
import KotlinSharedUI
import LazyPager
import Combine
import FlareAppleCore
import FlareAppleUI

@available(iOS 16.0, *)
struct Router<Root: View>: View {
    @Environment(\.openURL) private var openURL
    @ViewBuilder let root: (@escaping (Route) -> Void) -> Root
    @State private var backStack: [Route] = []
    @State private var sheet: Route? = nil
    @State private var cover: Route? = nil
    @State private var alertRoute: Route? = nil
    @StateObject private var deepLinkPresenter: KotlinPresenter<DeepLinkPresenterState>
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    
    init(@ViewBuilder root: @escaping (@escaping (Route) -> Void) -> Root) {
        self.root = root
        let handler = DeepLinkHandler()
        self._deepLinkHandler = .init(wrappedValue: handler)
        self._deepLinkPresenter = .init(wrappedValue: .init(presenter: DeepLinkPresenter(onRoute: { [weak handler] deeplinkRoute in
            if let route = Route.fromDeepLinkRoute(deeplinkRoute: deeplinkRoute){
                handler?.onRoute?(route)
            }
        }, onLink: { [weak handler] link in
            handler?.onLink?(link)
        })))
    }
    
    var body: some View {
        NavigationStack(path: $backStack) {
            root({ route in
                navigate(route: route)
            })
            .navigationDestination(for: Route.self) { route in
                route.view(
                    onNavigate: { route in navigate(route: route) },
                    goBack: { backStack.removeLast() }
                )
            }
        }
        .environment(\.timelineMediaActionHandler, IOSTimelineMediaActions.handler)
        .sheet(item: $sheet) { route in
            // Do not place this availability check directly in the sheet's
            // ViewBuilder. Swift 6 emits a buildLimitedAvailability warning for
            // that pattern, and the generated conditional metadata is evaluated
            // while SwiftUI builds the iOS 16/17 presentation graph.
            SheetRouteContainer(
                route: route,
                onNavigate: { route in navigate(route: route) },
                goBack: { backStack.removeLast() }
            )
        }
        .fullScreenCover(item: $cover) { route in
            NavigationStack {
                route.view(
                    onNavigate: { route in navigate(route: route) },
                    goBack: { backStack.removeLast() }
                )
            }
            .background(ClearFullScreenBackground())
            .colorScheme(.dark)
        }
        .alert(alertRoute?.alertTitle ?? "", isPresented: Binding(get: { alertRoute != nil }, set: { if !$0 { alertRoute = nil } })) {
            alertRoute?.alertActions()
        } message: {
            alertRoute?.alertMessage()
        }
        .environment(\.openURL, OpenURLAction { url in
            deepLinkPresenter.state.handle(url: url.absoluteString)
            return .handled
        })
        .onOpenURL { url in
            let targetURL = url.openInFlareTargetURL ?? url
            deepLinkPresenter.state.handle(url: targetURL.absoluteString)
        }
        .onAppear {
            deepLinkHandler.onRoute = { route in
                navigate(route: route)
            }
            deepLinkHandler.onLink = { link in
                if let url = URL(string: link) {
                    openURL(url)
                }
            }
        }
    }

    func navigate(route: Route) {
        if route.alertTitle != nil {
            alertRoute = route
        } else if isSheetRoute(route: route) {
            sheet = route
        } else if isFullScreenCover(route: route) {
            cover = route
        } else if backStack.last != route {
            backStack.append(route)
            sheet = nil
            cover = nil
        }
    }
    
    func isSheetRoute(route: Route) -> Bool {
        switch route {
        case .deepLinkAccountPicker,
                .composeNew,
                .composeCrossPost,
                .composeDraft,
                .composeQuote,
                .composeReply,
                .composeVVOReplyComment,
                .relogin,
                .tabSettings,
                .statusBlueskyReport,
                .statusMisskeyReport,
                .editUserList,
                .statusShareSheet,
                .secondaryMenu,
                .statusInsight,
                .profileInsight,
                .statusAddReaction:
            return true
        default:
            return false
        }
    }
    
    func isFullScreenCover(route: Route) -> Bool {
        switch route {
        case .mediaStatusMedia, .mediaImage, .mediaRaw:
            return true
        default:
            return false
        }
    }
}

class DeepLinkHandler : ObservableObject {
    var onRoute: ((Route) -> Void)?
    var onLink: ((String) -> Void)?
}

/// Erases the OS-specific sheet hierarchy before SwiftUI evaluates the
/// `.sheet` closure. This preserves the iOS 17 nested-navigation workaround
/// while preventing conditional-view metadata from entering the iOS 16 graph.
@available(iOS 16.0, *)
private struct SheetRouteContainer: View {
    let route: Route
    let onNavigate: (Route) -> Void
    let goBack: () -> Void

    var body: some View {
        sheetContent(for: route)
    }

    private func sheetContent(for route: Route) -> AnyView {
        if #available(iOS 18.0, *) {
            return AnyView(
                ModernSheetRoute(
                    route: route,
                    onNavigate: onNavigate,
                    goBack: goBack
                )
            )
        }

        return AnyView(
            LegacySheetRoute(
                route: route,
                onNavigate: onNavigate,
                goBack: goBack
            )
        )
    }
}

@available(iOS 18.0, *)
private struct ModernSheetRoute: View {
    let route: Route
    let onNavigate: (Route) -> Void
    let goBack: () -> Void

    var body: some View {
        NavigationStack {
            route.view(onNavigate: onNavigate, goBack: goBack)
        }
    }
}

@available(iOS 16.0, *)
private struct LegacySheetRoute: View {
    let route: Route
    let onNavigate: (Route) -> Void
    let goBack: () -> Void

    var body: some View {
        NavigationStack {
            route.view(onNavigate: onNavigate, goBack: goBack)
                .navigationDestination(for: Route.self) { destination in
                    destination.view(onNavigate: onNavigate, goBack: {})
                }
        }
    }
}

private extension URL {
    var openInFlareTargetURL: URL? {
        guard scheme?.lowercased() == "flare",
              host?.lowercased() == "open",
              let targetValue = URLComponents(
                  url: self,
                  resolvingAgainstBaseURL: false
              )?.queryItems?.first(where: { $0.name == "url" })?.value,
              let targetURL = URL(string: targetValue),
              let targetScheme = targetURL.scheme?.lowercased(),
              targetScheme == "https" || targetScheme == "http"
        else {
            return nil
        }
        return targetURL
    }
}
