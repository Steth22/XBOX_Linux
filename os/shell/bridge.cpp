#include "bridge.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QSysInfo>
#include <QThread>
#include <QDateTime>
#include <QWidget>
#include <QApplication>
#include <QSet>

static bool devMode() { return qEnvironmentVariableIsSet("URAX_DEV"); }

Bridge::Bridge(QWidget *window, QObject *parent) : QObject(parent), m_window(window) {}

QString Bridge::run(const QString &program, const QStringList &args, int timeoutMs) {
  QProcess p;
  p.start(program, args);
  if (!p.waitForFinished(timeoutMs)) { p.kill(); return QString(); }
  return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
}

QJsonObject Bridge::systemInfo() {
  QJsonObject o;
  QString cpu = "CPU";
  QFile f("/proc/cpuinfo");
  if (f.open(QIODevice::ReadOnly)) {
    for (const auto &line : QString::fromUtf8(f.readAll()).split('\n'))
      if (line.startsWith("model name")) { cpu = line.section(':', 1).simplified(); break; }
  }
  int threads = QThread::idealThreadCount();
  qint64 memKb = 0;
  QFile m("/proc/meminfo");
  if (m.open(QIODevice::ReadOnly)) {
    const auto first = QString::fromUtf8(m.readLine());
    memKb = first.section(':', 1).simplified().section(' ', 0, 0).toLongLong();
  }
  o["cpu"] = cpu;
  o["threads"] = threads;
  o["memGB"] = qMax<qint64>(1, qRound(memKb / 1048576.0));
  o["host"] = "UraxOS on Linux " + QSysInfo::kernelVersion();
  return o;
}

void Bridge::quit() {
  if (devMode()) { qApp->quit(); return; }
  QProcess::startDetached("systemctl", {"poweroff"});
}

void Bridge::reboot() {
  if (devMode()) { qApp->quit(); return; }
  QProcess::startDetached("systemctl", {"reboot"});
}

void Bridge::pcMode() { m_window->hide(); }

void Bridge::launch(const QString &command) {
  auto *p = new QProcess(this);
  p->setProgram("/bin/sh");
  p->setArguments({"-c", command});
  connect(p, &QProcess::finished, this, [this, p]() {
    p->deleteLater();
    m_window->showFullScreen();
    m_window->raise();
    m_window->activateWindow();
  });
  p->start();
  m_window->hide();
}

void Bridge::setVolume(int percent) {
  percent = qBound(0, percent, 100);
  run("wpctl", {"set-volume", "@DEFAULT_AUDIO_SINK@", QString::number(percent) + "%"});
  run("wpctl", {"set-mute", "@DEFAULT_AUDIO_SINK@", percent == 0 ? "1" : "0"});
}

int Bridge::volume() {
  const auto out = run("wpctl", {"get-volume", "@DEFAULT_AUDIO_SINK@"});   // "Volume: 0.60"
  bool ok = false;
  const double v = out.section(' ', 1, 1).toDouble(&ok);
  return ok ? qRound(v * 100) : 60;
}

void Bridge::setWifi(bool on) { run("nmcli", {"radio", "wifi", on ? "on" : "off"}); }

void Bridge::setBt(bool on) { run("bluetoothctl", {"power", on ? "on" : "off"}, 4000); }

QString Bridge::net() {
  QJsonObject o;
  QString wired = "none", wifiDev;
  for (const auto &line : run("nmcli", {"-t", "-f", "DEVICE,TYPE,STATE", "device"}).split('\n')) {
    const auto f = line.split(':');
    if (f.size() < 3) continue;
    if (f[1] == "ethernet" && wired != "connected") wired = f[2];
    if (f[1] == "wifi") wifiDev = f[0];
  }
  o["wired"] = wired;
  o["wifiDevice"] = !wifiDev.isEmpty();
  QJsonArray nets;
  QString current;
  if (!wifiDev.isEmpty()) {
    const auto out = run("nmcli", {"-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"}, 12000);
    for (const auto &line : out.split('\n')) {
      const auto f = line.split(':');
      if (f.size() < 4 || f[1].isEmpty()) continue;
      QJsonObject n;
      n["s"] = f[1];
      n["sig"] = qBound(1, f[2].toInt() / 25 + 1, 4);
      n["lock"] = f[3].isEmpty() || f[3] == "--" ? 0 : 1;
      if (f[0] == "*") current = f[1];
      nets.append(n);
    }
  }
  o["current"] = current;
  o["nets"] = nets;
  return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

QString Bridge::wifiConnect(const QString &ssid, const QString &password) {
  QProcess p;
  QStringList args{"device", "wifi", "connect", ssid};
  if (!password.isEmpty()) args << "password" << password;
  p.start("nmcli", args);
  p.waitForFinished(30000);
  return p.exitCode() == 0 ? "ok" : QString::fromUtf8(p.readAllStandardError()).trimmed();
}

// Curated desktop apps that UraxOS shows in its Library, plus every installed Steam game.
QString Bridge::apps() {
  struct App { const char *desktop; const char *name; const char *kind; const char *exec; };
  const App known[] = {
    {"firefox.desktop", "Firefox", "app", "firefox"},
    {"steam.desktop", "Steam", "app", "steam -gamepadui"},
    {"org.kde.dolphin.desktop", "Files", "app", "dolphin"},
    {"org.kde.konsole.desktop", "Terminal", "app", "konsole"},
    {"org.kde.kwrite.desktop", "Text Editor", "app", "kwrite"},
    {"org.kde.gwenview.desktop", "Photos", "app", "gwenview"},
    {"org.kde.plasma-systemmonitor.desktop", "System Monitor", "app", "plasma-systemmonitor"},
    {"systemsettings.desktop", "System Settings", "app", "systemsettings"},
  };
  QJsonArray list;
  const QStringList dirs = {"/usr/share/applications", QDir::homePath() + "/.local/share/flatpak/exports/share/applications",
                            "/var/lib/flatpak/exports/share/applications"};
  for (const auto &a : known) {
    for (const auto &d : dirs) {
      if (QFile::exists(d + "/" + a.desktop)) {
        QJsonObject o{{"n", a.name}, {"k", a.kind}, {"exec", a.exec}, {"src", "local"}};
        list.append(o);
        break;
      }
    }
  }
  // Flatpak apps (Brave, Discord, ...): add anything exported that we do not already list.
  for (const auto &d : dirs.mid(1)) {
    QDir dir(d);
    for (const auto &fi : dir.entryInfoList({"*.desktop"}, QDir::Files)) {
      QSettings s(fi.absoluteFilePath(), QSettings::IniFormat);
      s.beginGroup("Desktop Entry");
      const QString name = s.value("Name").toString();
      if (name.isEmpty()) continue;
      QJsonObject o{{"n", name}, {"k", "app"}, {"src", "local"}, {"exec", "flatpak run " + fi.completeBaseName()}};
      list.append(o);
    }
  }
  // Steam games from every library folder's appmanifest_*.acf.
  QStringList steamApps = {QDir::homePath() + "/.local/share/Steam/steamapps", QDir::homePath() + "/.steam/steam/steamapps"};
  QSet<QString> seen;
  const QRegularExpression kv("\"(\\w+)\"\\s+\"([^\"]*)\"");
  for (const auto &sa : steamApps) {
    QDir dir(sa);
    for (const auto &fi : dir.entryInfoList({"appmanifest_*.acf"}, QDir::Files)) {
      QFile f(fi.absoluteFilePath());
      if (!f.open(QIODevice::ReadOnly)) continue;
      QString appid, name; double size = 0;
      auto it = kv.globalMatch(QString::fromUtf8(f.readAll()));
      while (it.hasNext()) {
        auto m = it.next();
        if (m.captured(1) == "appid") appid = m.captured(2);
        else if (m.captured(1) == "name") name = m.captured(2);
        else if (m.captured(1) == "SizeOnDisk") size = m.captured(2).toDouble();
      }
      if (appid.isEmpty() || name.isEmpty() || seen.contains(appid) || name.startsWith("Steamworks") || name.startsWith("Proton")) continue;
      seen.insert(appid);
      QJsonObject o{{"n", name}, {"k", "game"}, {"src", "steam"}, {"sid", appid}, {"gb", qRound(size / 1e8) / 10.0},
                    {"exec", "steam steam://rungameid/" + appid}};
      list.append(o);
    }
  }
  return QString::fromUtf8(QJsonDocument(list).toJson(QJsonDocument::Compact));
}

static QString shotsDir() {
  const QString d = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + "/Screenshots";
  QDir().mkpath(d);
  return d;
}

QString Bridge::screenshot() {
  const QString path = shotsDir() + "/UraxOS " + QDateTime::currentDateTime().toString("yyyy-MM-dd HH-mm-ss") + ".png";
  QProcess p;
  p.start("spectacle", {"--background", "--nonotify", "--fullscreen", "--output", path});
  p.waitForFinished(15000);
  return QFile::exists(path) ? path : QString();
}

QString Bridge::pictures() {
  QJsonArray list;
  QDir dir(shotsDir());
  for (const auto &fi : dir.entryInfoList({"*.png", "*.jpg", "*.jpeg"}, QDir::Files, QDir::Time)) {
    QJsonObject o{{"path", fi.absoluteFilePath()}, {"mtime", fi.lastModified().toMSecsSinceEpoch()}, {"size", fi.size()}};
    list.append(o);
  }
  return QString::fromUtf8(QJsonDocument(list).toJson(QJsonDocument::Compact));
}
