// urax-shell: the UraxOS Console Mode. A fullscreen Qt WebEngine window that runs the UraxOS
// interface and talks to the real system through Bridge (QWebChannel).
//   urax-shell            start (or bring back) Console Mode
//   urax-shell --desktop  PC Mode desktop: wallpaper/icons below windows, taskbar above (layer-shell)
//   urax-shell --dev      run in a window and quit instead of powering off (for development)
#include "bridge.h"
#include "windows.h"
#include <LayerShellQt/Window>
#include <QScreen>
#include <QRegion>
#include <QWindow>
#include <QApplication>
#include <QCloseEvent>
#include <QFile>
#include <QJsonDocument>
#include <QLocalServer>
#include <QLocalSocket>
#include <QWebChannel>
#include <QWebEnginePage>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#include <QWebEngineScriptCollection>
#include <QWebEngineSettings>
#include <QWebEngineView>

class ShellView : public QWebEngineView {
public:
  Bridge *bridge = nullptr;
protected:
  // Alt+F4 / compositor close requests go to the UI first (it decides what to close).
  void closeEvent(QCloseEvent *e) override {
    if (qEnvironmentVariableIsSet("URAX_DEV") && e->spontaneous() == false) { e->accept(); return; }
    e->ignore();
    if (bridge) emit bridge->altF4();
  }
};

static QString readFile(const QString &path) {
  QFile f(path);
  return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
}

static void addScript(QWebEnginePage *page, const QString &name, const QString &src, QWebEngineScript::InjectionPoint at) {
  QWebEngineScript s;
  s.setName(name);
  s.setSourceCode(src);
  s.setInjectionPoint(at);
  s.setWorldId(QWebEngineScript::MainWorld);
  s.setRunsOnSubFrames(false);
  page->scripts().insert(s);
}

// Virtual machines usually have no working 3D for Chromium; use software rendering there.
static bool runningInVm() {
  QFile f("/sys/class/dmi/id/sys_vendor");
  if (!f.open(QIODevice::ReadOnly)) return false;
  const QByteArray v = f.readAll().toLower();
  return v.contains("innotek") || v.contains("qemu") || v.contains("vmware") || v.contains("microsoft") || v.contains("oracle");
}

int main(int argc, char *argv[]) {
  if (runningInVm() || qEnvironmentVariableIsSet("URAX_SOFTWARE")) {
    qputenv("QT_QUICK_BACKEND", "software");
    if (!qEnvironmentVariableIsSet("QTWEBENGINE_CHROMIUM_FLAGS")) qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu");
  }
  QApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
  qputenv("QTWEBENGINE_CHROMIUM_FLAGS", qgetenv("QTWEBENGINE_CHROMIUM_FLAGS") + " --autoplay-policy=no-user-gesture-required");
  QApplication app(argc, argv);
  app.setApplicationName("UraxOS");
  app.setDesktopFileName("uraxos-shell");
  const bool dev = app.arguments().contains("--dev");
  if (dev) qputenv("URAX_DEV", "1");

  const bool desktop = app.arguments().contains("--desktop");
  const QString mode = desktop ? "desktop" : "console";
  const QString instance = desktop ? "uraxos-desktop" : "uraxos-shell";

  // Single instance: a second start brings Console Mode back (desktop: does nothing).
  QLocalSocket probe;
  probe.connectToServer(instance);
  if (probe.waitForConnected(300)) { probe.write("show\n"); probe.waitForBytesWritten(300); return 0; }
  QLocalServer::removeServer(instance);
  QLocalServer server;
  server.listen(instance);

  const QString uiDir = qEnvironmentVariable("URAX_UI", "/usr/share/uraxos/ui");
  auto *profile = new QWebEngineProfile(desktop ? "uraxos-desktop" : "uraxos", &app);
  WindowTracker *tracker = desktop ? new WindowTracker(&app) : nullptr;

  // One web view = one surface. Console: one fullscreen window.
  // Desktop: "desk" (wallpaper + icons, below all windows) and "bar" (taskbar, Start, flyouts; above windows).
  auto makeView = [&](const QString &surface) {
    auto *page = new QWebEnginePage(profile, &app);
    auto *st = page->settings();
    st->setAttribute(QWebEngineSettings::LocalContentCanAccessFileUrls, true);
    st->setAttribute(QWebEngineSettings::PlaybackRequiresUserGesture, false);
    st->setAttribute(QWebEngineSettings::ShowScrollBars, false);
    st->setAttribute(QWebEngineSettings::FocusOnNavigationEnabled, true);
    auto *view = new ShellView;
    view->setPage(page);
    view->setWindowTitle(surface == "console" ? "UraxOS" : "UraxOS " + surface);
    if (surface == "bar") {
      view->setAttribute(Qt::WA_TranslucentBackground);
      view->setStyleSheet("background:transparent");
      page->setBackgroundColor(Qt::transparent);
    } else {
      view->setStyleSheet("background:#000");
    }
    auto *bridge = new Bridge(view, &app);
    if (tracker) bridge->setTracker(tracker);
    view->bridge = bridge;
    auto *channel = new QWebChannel(page);
    channel->registerObject("sys", bridge);
    page->setWebChannel(channel);
    QJsonObject info = Bridge::systemInfo();
    info["mode"] = mode;
    info["surface"] = surface;
    const QString sys = QString::fromUtf8(QJsonDocument(info).toJson(QJsonDocument::Compact));
    addScript(page, "qwebchannel", readFile(":/qtwebchannel/qwebchannel.js"), QWebEngineScript::DocumentCreation);
    addScript(page, "urax-bridge", "window.__URAX_SYS=" + sys + ";\n" + readFile(uiDir + "/bridge.js"), QWebEngineScript::DocumentCreation);
    addScript(page, "urax-host", readFile(uiDir + (desktop ? "/host-pc.js" : "/host.js")), QWebEngineScript::DocumentReady);
    page->load(QUrl::fromLocalFile(uiDir + "/index.html"));
    return view;
  };

  QList<ShellView *> views;
  if (desktop) {
    const QSize scr = app.primaryScreen()->size();
    auto *desk = makeView("desk"), *bar = makeView("bar");
    desk->winId();
    bar->winId();
    if (auto *ls = LayerShellQt::Window::get(desk->windowHandle())) {
      ls->setLayer(LayerShellQt::Window::LayerBackground);
      ls->setAnchors({LayerShellQt::Window::AnchorTop, LayerShellQt::Window::AnchorBottom,
                      LayerShellQt::Window::AnchorLeft, LayerShellQt::Window::AnchorRight});
      ls->setExclusiveZone(-1);
      ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
      ls->setScope("uraxos-desk");
    }
    if (auto *ls = LayerShellQt::Window::get(bar->windowHandle())) {
      ls->setLayer(LayerShellQt::Window::LayerTop);
      ls->setAnchors({LayerShellQt::Window::AnchorBottom, LayerShellQt::Window::AnchorLeft, LayerShellQt::Window::AnchorRight});
      ls->setExclusiveEdge(LayerShellQt::Window::AnchorBottom);
      ls->setExclusiveZone(48);
      ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
      ls->setScope("uraxos-bar");
    }
    desk->resize(scr);
    bar->resize(scr);
    bar->windowHandle()->setMask(QRegion(0, scr.height() - 48, scr.width(), 48));
    desk->show();
    bar->show();
    views << desk << bar;
  } else {
    auto *view = makeView("console");
    if (dev) view->resize(1600, 900), view->show(); else view->showFullScreen();
    view->setFocus();
    views << view;
  }

  QObject::connect(&server, &QLocalServer::newConnection, [&]() {
    while (auto *c = server.nextPendingConnection()) {
      c->waitForReadyRead(200);
      c->deleteLater();
      if (desktop) continue;
      auto *v = views.first();
      v->showFullScreen();
      v->raise();
      v->activateWindow();
      v->setFocus();
    }
  });

  return app.exec();
}
