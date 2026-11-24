// Bridge between the UraxOS web UI and the real Linux system (power, audio, network,
// Bluetooth, apps, screenshots). Exposed to JavaScript through QWebChannel as "sys".
#pragma once
#include <QObject>
#include <QString>
#include <QJsonObject>

class QWidget;

class Bridge : public QObject {
  Q_OBJECT
public:
  explicit Bridge(QWidget *window, QObject *parent = nullptr);
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

signals:
  void altF4();

private:
  QWidget *m_window;
  QString run(const QString &program, const QStringList &args, int timeoutMs = 8000);
};
