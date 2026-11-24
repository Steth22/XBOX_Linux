// Bridge between the UraxOS web UI and the real Linux system (power, audio, network,
// Bluetooth, apps, screenshots). Exposed to JavaScript through QWebChannel as "sys".
#pragma once
#include <QObject>
#include <QString>
#include <QJsonObject>

class QWidget;
class WindowTracker;

class Bridge : public QObject {
  Q_OBJECT
public:
  explicit Bridge(QWidget *window, QObject *parent = nullptr);
  void setTracker(WindowTracker *t);
  static QJsonObject systemInfo();

public slots:
  void quit();                                  // power off the machine
  void reboot();
  void pcMode();                                // hide the shell, reveal the desktop (PC Mode)
  void launch(const QString &command);          // start an app; the shell returns when it exits
  void setVolume(int percent);
  int volume();
  void setWifi(bool on);
  void setBt(bool on);
  QString net();                                // JSON: wired/wifi state and visible networks
  QString wifiConnect(const QString &ssid, const QString &password);
  QString apps();                               // JSON: installed apps and Steam games
  QString screenshot();                         // returns the saved file path ("" on failure)
  QString pictures();                           // JSON list of screenshots
  // PC Mode (desktop surfaces)
  void spawn(const QString &command);           // start an app detached (PC Mode)
  void consoleMode();                           // bring Console Mode to the front
  QString windows();                            // JSON list of real app windows
  void winToggle(const QString &id);
  void winActivate(const QString &id);
  void winMinimize(const QString &id);
  void winClose(const QString &id);
  void showDesktop(bool on);
  void setInput(const QString &rectsJson);      // clickable areas of this surface (CSS px)
  void setExclusive(int px);                    // space reserved at the bottom (taskbar)

signals:
  void altF4();
  void windowsChanged();

private:
  QWidget *m_window;
  WindowTracker *m_tracker = nullptr;
  QString run(const QString &program, const QStringList &args, int timeoutMs = 8000);
};
