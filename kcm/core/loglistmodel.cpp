/*
 * UFW KControl Module
 *
 * Copyright 2011 Craig Drummond <craig.p.drummond@gmail.com>
 * Copyright 2018 Alexis Lopes Zubeta <contact@azubieta.net>
 * Copyright 2020 Tomaz Canabrava <tcanabrava@kde.org>
 *
 * ----
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include "loglistmodel.h"

#include <QDebug>
#include <QDateTime>
#include <QRegularExpression>

LogListModel::LogListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

bool LogListModel::busy() const
{
    return m_busy;
}

void LogListModel::setBusy(bool busy)
{
    if (m_busy != busy) {
        m_busy = busy;
        emit busyChanged();
    }
}

int LogListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return m_logsData.size();
}

QVariant LogListModel::data(const QModelIndex &index, int role) const
{
    const auto checkIndexFlags =  QAbstractItemModel::CheckIndexOption::IndexIsValid
                               | QAbstractItemModel::CheckIndexOption::ParentIsInvalid;

    if (!checkIndex(index, checkIndexFlags)) {
        return {};
    }

    LogData data = m_logsData.at(index.row());
    switch(role) {
        case SourceAddressRole: return data.sourceAddress;
        case SourcePortRole: return data.sourcePort;
        case DestinationAddressRole: return data.destinationAddress;
        case DestinationPortRole: return data.destinationPort;
        case ProtocolRole: return data.protocol;
        case InterfaceRole: return data.interface;
        case ActionRole: return data.action;
        case TimeRole: return data.time;
        case DateRole: return data.date;
    };

    return {};
}

void LogListModel::addRawLogs(const QStringList &rawLogsList)
{
    static QRegularExpression regex(
        R"((.*)\s(.*)\s(.*):\s\[(.*)\]\s\[(.*)\].*)"
        R"(IN=([\w|\d]*).*)"
        R"(SRC=([\w|\.|\:\d]*).*)"
        R"(DST=([\w|\.|\:\d]*).*)"
        R"(PROTO=([\w|\.|\d]*)\s)"
        R"((SPT=(\d*)\sDPT=(\d*))?.*)"
    );

    QVector<LogData> newLogs;
    newLogs.reserve(rawLogsList.count());
    for (const QString &log : rawLogsList) {
        auto match = regex.match(log);
        if (!match.hasMatch()) {
            continue;
        }
        QDateTime date = QDateTime::fromString(match.captured(1), "MMM d HH:mm:ss");
        const QString host = match.captured(2);
        const QString id = match.captured(4);

        QString protocol = match.captured(9);
        if (protocol == QLatin1String("1")) {
            protocol = QStringLiteral("ICMP");
        } else if (protocol == QLatin1String("2")) {
            protocol = QStringLiteral("IGMP");
        }

        LogData logDetails {
            .sourceAddress = match.captured(7),
            .sourcePort = match.captured(11),
            .destinationAddress = match.captured(8),
            .destinationPort = match.captured(12),
            .protocol = protocol,
            .interface = match.captured(6),
            .action = match.captured(5),
            .time = date.toString("HH:mm:ss"),
            .date = date.toString("MMM dd")
        };
        newLogs.append(logDetails);
    }

    if (!newLogs.isEmpty()) {
        beginInsertRows(QModelIndex(), rowCount(), rowCount() + newLogs.count() - 1);
        m_logsData << newLogs;
        endInsertRows();

        emit countChanged();
    }
}

QHash<int, QByteArray> LogListModel::roleNames() const
{
    return {
        {SourceAddressRole, "sourceAddress"},
        {SourcePortRole, "sourcePort"},
        {DestinationAddressRole, "destinationAddress"},
        {DestinationPortRole, "destinationPort"},
        {ProtocolRole, "protocol"},
        {InterfaceRole, "interface"},
        {ActionRole, "action"},
        {TimeRole, "time"},
        {DateRole, "date"},
    };
}
