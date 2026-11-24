#include "windows.h"
#include <KWayland/Client/connection_thread.h>
#include <KWayland/Client/plasmawindowmanagement.h>
#include <KWayland/Client/registry.h>
#include <QBuffer>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

using namespace KWayland::Client;

WindowTracker::WindowTracker(QObject *parent) : QObject(parent) {
  auto *conn = ConnectionThread::fromApplication(this);
  if (!conn) return;
  auto *reg = new Registry(this);
  reg->create(conn);
  connect(reg, &Registry::plasmaWindowManagementAnnounced, this, [this, reg](quint32 name, quint32 version) {
    m_pwm = reg->createPlasmaWindowManagement(name, version, this);
    connect(m_pwm, &PlasmaWindowManagement::windowCreated, this, &WindowTracker::add);
    connect(m_pwm, &PlasmaWindowManagement::activeWindowChanged, this, &WindowTracker::changed);
    for (auto *w : m_pwm->windows()) add(w);
  });
  reg->setup();
}

void WindowTracker::add(PlasmaWindow *w) {
  for (auto sig : {&PlasmaWindow::titleChanged, &PlasmaWindow::appIdChanged, &PlasmaWindow::activeChanged,
                   &PlasmaWindow::minimizedChanged, &PlasmaWindow::iconChanged, &PlasmaWindow::skipTaskbarChanged})
    connect(w, sig, this, &WindowTracker::changed);
  connect(w, &PlasmaWindow::unmapped, this, [this] { QTimer::singleShot(0, this, &WindowTracker::changed); });
  connect(w, &QObject::destroyed, this, &WindowTracker::changed);
  // Wayland does not let a window take focus by itself. When Console Mode comes back
  // (after PC Mode or after a game exits), the desktop hands it the keyboard.
  auto focusConsole = [w] {
    if (w->appId() != "uraxos-shell") return;
    for (int ms : {150, 500, 1000, 2000, 3500})
      QTimer::singleShot(ms, w, [w] { if (!w->isActive()) w->requestActivate(); });
  };
  connect(w, &PlasmaWindow::appIdChanged, w, focusConsole);
  focusConsole();
  emit changed();
}

static bool isOurs(const QString &appId) {
  return appId.startsWith("uraxos") || appId.startsWith("urax-shell") || appId == "org.kde.plasmashell";
}

QString WindowTracker::json() const {
  QJsonArray list;
  if (!m_pwm) return "[]";
  for (auto *w : m_pwm->windows()) {
    if (!w->isValid() || w->skipTaskbar() || isOurs(w->appId())) continue;
    QString icon = m_iconCache.value(w->appId());
    if (icon.isEmpty() && !w->icon().isNull()) {
      QByteArray png;
      QBuffer buf(&png);
      buf.open(QIODevice::WriteOnly);
      w->icon().pixmap(64, 64).save(&buf, "PNG");
      icon = "data:image/png;base64," + QString::fromLatin1(png.toBase64());
      m_iconCache.insert(w->appId(), icon);
    }
    list.append(QJsonObject{{"id", QString::fromLatin1(w->uuid())}, {"title", w->title()}, {"app", w->appId()},
                            {"active", w->isActive()}, {"min", w->isMinimized()}, {"icon", icon}});
  }
  return QString::fromUtf8(QJsonDocument(list).toJson(QJsonDocument::Compact));
}

PlasmaWindow *WindowTracker::find(const QString &id) const {
  if (!m_pwm) return nullptr;
  for (auto *w : m_pwm->windows())
    if (QString::fromLatin1(w->uuid()) == id) return w;
  return nullptr;
}

void WindowTracker::activate(const QString &id) {
  if (auto *w = find(id)) w->requestActivate();
}
void WindowTracker::toggle(const QString &id) {
  auto *w = find(id);
  if (!w) return;
  if (w->isActive() && !w->isMinimized()) w->requestToggleMinimized();
  else w->requestActivate();
}
void WindowTracker::minimize(const QString &id) {
  if (auto *w = find(id); w && !w->isMinimized()) w->requestToggleMinimized();
}
void WindowTracker::close(const QString &id) {
  if (auto *w = find(id)) w->requestClose();
}
void WindowTracker::showDesktop(bool on) {
  if (m_pwm) m_pwm->setShowingDesktop(on);
}

bool WindowTracker::hasVisible(const QString &appId) const {
  if (!m_pwm) return false;
  for (auto *w : m_pwm->windows())
    if (w->isValid() && w->appId() == appId && !w->isMinimized()) return true;
  return false;
}
