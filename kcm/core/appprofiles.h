#ifndef UFW_APP_PROFILES_H
#define UFW_APP_PROFILES_H
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

#include <kcm_firewall_core_export.h>

#include <QList>
#include <QString>

struct KCM_FIREWALL_CORE_EXPORT Entry
{
    Entry(const QString &n, const QString &p=QString());
    bool operator<(const Entry &o) const  { return name.localeAwareCompare(o.name)<0; }
    bool operator==(const Entry &o) const { return name==o.name; }
    QString         name;
    QString         ports;
//     Types::Protocol protocol;
};

#endif
