// Tracks the real application windows managed by KWin (for the PC Mode taskbar).
#pragma once
#include <QHash>
#include <QObject>
#include <QString>

namespace KWayland::Client {
class PlasmaWindowManagement;
class PlasmaWindow;
}

class WindowTracker : public QObject {
  Q_OBJECT
public:
  explicit WindowTracker(QObject *parent = nullptr);
  QString json() const;  // [{id,title,app,active,min,icon}]
  void activate(const QString &id);
  void toggle(const QString &id);  // taskbar click: focus, or minimize when already active
  void minimize(const QString &id);
  void close(const QString &id);
  void showDesktop(bool on);
  bool hasVisible(const QString &appId) const;  // e.g. Console Mode is on screen

signals:
  void changed();

private:
  void add(KWayland::Client::PlasmaWindow *w);
  KWayland::Client::PlasmaWindow *find(const QString &id) const;
  KWayland::Client::PlasmaWindowManagement *m_pwm = nullptr;
  mutable QHash<QString, QString> m_iconCache;  // appId -> data URL
};
