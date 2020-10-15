// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
// SPDX-FileCopyrightText: 2018 Alexis Lopes Zubeta <contact@azubieta.net>
// SPDX-FileCopyrightText: 2020 Tomaz Canabrava <tcanabrava@kde.org>

#ifndef CONECTIONSMODEL_H
#define CONECTIONSMODEL_H

#include <QAbstractListModel>
#include <QTimer>

#include <KAuth>

#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(ConnectionsModelDebug)

struct ConnectionsData {
    QString protocol;
    QString localAddress;
    QString foreignAddress;
    QString status;
    QString pid;
    QString program;

    bool operator==(const ConnectionsData &other) const
    {
        return other.protocol == protocol
            && other.localAddress == localAddress
            && other.foreignAddress == foreignAddress
            && other.status == status
            && other.pid == pid
            && other.program == program;
    }
};

class ConnectionsModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum ConnectionsModelRoles { ProtocolRole = Qt::UserRole + 1, LocalAddressRole, ForeignAddressRole, StatusRole, PidRole, ProgramRole };
    Q_ENUM(ConnectionsModelRoles)

    explicit ConnectionsModel(QObject *parent = nullptr);

    bool busy() const;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;

    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;

    QHash<int, QByteArray> roleNames() const override;

signals:
    void countChanged();
    void busyChanged();
    void showErrorMessage(const QString &message);

protected slots:
    void refreshConnections();

private:
    void setBusy(bool busy);

    bool m_busy = false;
    QVector<ConnectionsData> m_connectionsData;
    KAuth::Action m_queryAction;
    QTimer timer;
};

#endif // CONECTIONSMODEL_H
