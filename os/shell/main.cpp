// urax-shell: the UraxOS Console Mode. A fullscreen Qt WebEngine window that runs the UraxOS
// interface and talks to the real system through Bridge (QWebChannel).
//   urax-shell            start (or bring back) Console Mode
//   urax-shell --dev      run in a window and quit instead of powering off (for development)
#include "bridge.h"
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

  // Single instance: a second start just brings Console Mode back.
  QLocalSocket probe;
  probe.connectToServer("uraxos-shell");
  if (probe.waitForConnected(300)) { probe.write("console\n"); probe.waitForBytesWritten(300); return 0; }
  QLocalServer::removeServer("uraxos-shell");
  QLocalServer server;
  server.listen("uraxos-shell");

  const QString uiDir = qEnvironmentVariable("URAX_UI", "/usr/share/uraxos/ui");
  auto *profile = new QWebEngineProfile("uraxos", &app);
  auto *page = new QWebEnginePage(profile, &app);
  auto *st = page->settings();
  st->setAttribute(QWebEngineSettings::LocalContentCanAccessFileUrls, true);
  st->setAttribute(QWebEngineSettings::PlaybackRequiresUserGesture, false);
  st->setAttribute(QWebEngineSettings::ShowScrollBars, false);
  st->setAttribute(QWebEngineSettings::FocusOnNavigationEnabled, true);

  ShellView view;
  view.setPage(page);
  view.setWindowTitle("UraxOS");
  view.setStyleSheet("background:#000");
  auto *bridge = new Bridge(&view, &app);
  view.bridge = bridge;
  auto *channel = new QWebChannel(page);
  channel->registerObject("sys", bridge);
  page->setWebChannel(channel);

  const QString sys = QString::fromUtf8(QJsonDocument(Bridge::systemInfo()).toJson(QJsonDocument::Compact));
  addScript(page, "qwebchannel", readFile(":/qtwebchannel/qwebchannel.js"), QWebEngineScript::DocumentCreation);
  addScript(page, "urax-bridge", "window.__URAX_SYS=" + sys + ";\n" + readFile(uiDir + "/bridge.js"), QWebEngineScript::DocumentCreation);
  addScript(page, "urax-host", readFile(uiDir + "/host.js"), QWebEngineScript::DocumentReady);

  QObject::connect(&server, &QLocalServer::newConnection, [&]() {
    while (auto *c = server.nextPendingConnection()) {
      c->waitForReadyRead(200);
      c->deleteLater();
      view.showFullScreen();
      view.raise();
      view.activateWindow();
      view.setFocus();
    }
  });

  page->load(QUrl::fromLocalFile(uiDir + "/index.html"));
  if (dev) view.resize(1600, 900), view.show(); else view.showFullScreen();
  view.setFocus();
  return app.exec();
}
