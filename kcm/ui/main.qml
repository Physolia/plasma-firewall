// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
// SPDX-FileCopyrightText: 2018 Alexis Lopes Zubeta <contact@azubieta.net>
// SPDX-FileCopyrightText: 2020 Tomaz Canabrava <tcanabrava@kde.org>
// SPDX-FileCopyrightText: 2023 ivan tkachenko <me@ratijas.tk>

import QtQuick 2.6
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.9 as QQC2
import QtQuick.Controls 1.4 as QQC1 // for Table View.

import org.kde.kcmutils as KCMUtils
import org.kcm.firewall 1.0

import org.kde.kirigami 2.14 as Kirigami

KCMUtils.ScrollViewKCM {
    id: root

    implicitHeight: Kirigami.Units.gridUnit * 25
    implicitWidth: Kirigami.Units.gridUnit * 44

    extraFooterTopPadding: false

    property var policyChoices : [
        {text: i18n("Allow"), data: "allow", tooltip: i18n("Allow all connections")},
        {text: i18n("Ignore"), data: "deny", tooltip: i18n("Keeps the program waiting until the connection attempt times out, some short time later.")},
        {text: i18n("Reject"), data: "reject", tooltip: i18n("Produces an immediate and very informative 'Connection refused' message")}
    ]

    Kirigami.OverlaySheet {
        id: drawer

        parent: root.QQC2.Overlay.overlay

        onVisibleChanged: {
            if (visible) {
                ruleEdit.forceActiveFocus();
            } else {
                // FIXME also reset rule
                ruleEditMessage.visible = false;
            }
        }

        title: ruleEdit.newRule ? i18n("Create A New Firewall Rule") : i18n("Edit Firewall Rule")

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.InlineMessage {
                id: ruleEditMessage
                type: Kirigami.MessageType.Error
                Layout.fillWidth: true
            }

            RuleEdit {
                id: ruleEdit
                client: kcm.client
                height: childrenRect.height
                implicitWidth: 30 * Kirigami.Units.gridUnit

                Keys.onEnterPressed: event => accept()
                Keys.onReturnPressed: event => accept()

                function accept() {
                    var job = kcm.client[newRule ? "addRule" : "updateRule"](rule);
                    if (!job) {
                        ruleEditMessage.text = i18n("Please restart plasma firewall, the backend disconnected.");
                        ruleEditMessage.visible = true;
                        return;
                    }

                    busy = true;
                    kcm.needsSave = true;
                    job.result.connect(() => {
                        busy = false;

                        if (job.error) {
                            // don't show an error when user canceled…
                            if (job.error !== 4) { // FIXME magic number
                                if (newRule) {
                                    ruleEditMessage.text = i18n("Error creating rule: %1", job.errorString);
                                } else {
                                    ruleEditMessage.text = i18n("Error updating rule: %1", job.errorString);
                                }
                                ruleEditMessage.visible = true;

                            }
                            // …but also don't close in this case!
                            return;
                        }

                        drawer.close();
                    });
                }
            }

            InlineBusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: ruleEdit.busy
                visible: running
            }
        }

        footer: QQC2.DialogButtonBox {
            enabled: ruleEdit.ready

            QQC2.Button {
                text: ruleEdit.newRule ? i18n("Create") : i18n("Save")
                icon.name: ruleEdit.newRule ? "document-new" : "document-save"
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
            }

            onAccepted: {
                if (ruleEdit.simple.index > -1) {
                    ruleEdit.rule.sourceApplication = ruleEdit.simple.service[ruleEdit.simple.index]
                }
                ruleEdit.accept()
            }
        }
    }

    header: ColumnLayout {
        id: columnLayout

        Kirigami.InlineMessage {
            id: firewallInlineErrorMessage
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
        }
        Kirigami.FormLayout {
            RowLayout {
                Kirigami.FormData.label: i18n("Firewall Status:")
                QQC2.CheckBox {
                    id: enabledCheckBox
                    property QtObject activeJob: null
                    text: {
                        if (kcm.client.enabled) {
                            return activeJob ? i18n("Disabling…") : i18n("Enabled")
                        } else {
                            return activeJob ? i18n("Enabling…") : i18n("Disabled")
                        }
                    }
                    enabled: !activeJob && !connectEnableTimer.running

                    function bindCurrent() {
                        checked = Qt.binding(function() {
                            return kcm.client.enabled;
                        });
                    }
                    Component.onCompleted: bindCurrent()

                    // FirewallD has a delay after the request to disable, to accept
                    // enable actions, but the delay does not return with the job result
                    // this is an ugly hack.
                    Timer {
                        id: connectEnableTimer
                        interval: 4000
                        repeat: false
                    }

                    onToggled: {
                        const enable = checked; // store the state on job begin, not when it finished

                        const job = kcm.client.setEnabled(checked);
                        if (job === null) {
                            firewallInlineErrorMessage.text = i18n("The firewall application, please install %1", kcm.client.name);
                            firewallInlineErrorMessage.visible = true;
                            return;
                        }
                        enabledCheckBox.activeJob = job;
                        job.result.connect(function () {
                            enabledCheckBox.activeJob = null; // need to explicitly unset since gc will clear it non-deterministic
                            bindCurrent();

                            if (job.error && job.error !== 4) {
                                console.log(job.errorString);
                                var errorString = job.errorString;
                                // Firewalld is sending a typo to us.
                                if (errorString.indexOf("Permission denied") !== -1) {
                                    errorString = i18n("Permission denied");
                                }

                                if (errorString.indexOf("unable to initialize table") !== -1) {
                                    firewallInlineErrorMessage.text = i18n("You recently updated your kernel. Iptables is failing to initialize, please reboot.")
                                } else {
                                    firewallInlineErrorMessage.text = enabled
                                        ? i18n("Error enabling firewall: %1", errorString)
                                        : i18n("Error disabling firewall: %1", errorString)
                                }
                                firewallInlineErrorMessage.visible = true;
                            }
                            if (!enable && !job.error) {
                                connectEnableTimer.start();
                            }
                        });
                        job.start();
                    }
                }

                InlineBusyIndicator {
                    Layout.fillHeight: true
                    running: enabledCheckBox.activeJob !== null || connectEnableTimer.running
                }
            }

            Repeater {
                model: [
                    {label: i18n("Default Incoming Policy:"), key: "Incoming"},
                    {label: i18n("Default Outgoing Policy:"), key: "Outgoing"}
                ]

                RowLayout {
                    Kirigami.FormData.label: modelData.label

                    QQC2.ComboBox {
                        id: policyCombo

                        property QtObject activeJob: null
                        // TODO currentValue
                        readonly property string currentPolicy: policyChoices[currentIndex].data

                        model: policyChoices
                        textRole: "text"
                        enabled: !activeJob && kcm.client.enabled
                        QQC2.ToolTip.text: policyChoices[currentIndex].tooltip
                        QQC2.ToolTip.delay: 1000
                        QQC2.ToolTip.timeout: 5000
                        QQC2.ToolTip.visible: hovered

                        Binding { // :(
                            target: ruleEdit
                            property: "default" + modelData.key + "PolicyRule"
                            value: policyCombo.currentPolicy
                        }

                        function bindCurrent() {
                            currentIndex = Qt.binding(function() {
                                return policyChoices.findIndex((choice) => choice.data === kcm.client["default" + modelData.key + "Policy"]);
                            });
                        }
                        Component.onCompleted: bindCurrent()

                        onActivated: {
                            const job = kcm.client["setDefault" + modelData.key + "Policy"](currentPolicy)
                            if (!job) {
                                firewallInlineErrorMessage.text = i18n("Please restart plasma firewall, the backend disconnected.");
                                firewallInlineErrorMessage.visible = true;
                                return;
                           }
                            policyCombo.activeJob = job;
                            job.result.connect(function () {
                                policyCombo.activeJob = null;
                                bindCurrent();

                                if (job.error && job.error !== 4) { // TODO magic number
                                    firewallInlineErrorMessage.text = i18n("Error changing policy: %1", job.errorString)
                                    firewallInlineErrorMessage.visible = true;
                                }
                            });
                        }
                    }

                    InlineBusyIndicator {
                        Layout.fillHeight: true
                        running: policyCombo.activeJob !== null
                    }
                }
            }
        }
    }

    // Hack, TableView can't be in the 'view' as it's not flickable.
    view: Flickable  {
        QQC1.TableView {
            id: tableView
            property int currentHoveredRow: -1

            anchors.fill: parent
            model: kcm.client.rulesModel
            enabled: kcm.client.enabled
            // ScrollViewKCM does its own frame
            frameVisible: false

            function editRule(row) {
                ruleEdit.rule = kcm.client.ruleAt(row);
                ruleEdit.newRule = false;
                drawer.open();
            }

            onDoubleClicked: editRule(row)
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onReturnPressed: {
                if (tableView.selection.count === 1) {
                    tableView.selection.forEach(editRule);
                    event.accepted = true;
                }
            }

            rowDelegate: MouseArea {
                height: Kirigami.Units.gridUnit + 2 * Kirigami.Units.smallSpacing // fit action buttons
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: tableView.currentHoveredRow = styleData.row

                // Restore upstream TableView background…
                BorderImage {
                    visible: styleData.selected || styleData.alternate
                    source: "image://__tablerow/" + (styleData.alternate ? "alternate_" : "")
                            + (styleData.selected ? "selected_" : "")
                            + (tableView.activeFocus ? "active" : "")
                    anchors.fill: parent
                }
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - (Kirigami.Units.largeSpacing * 12)
                visible: tableView.rowCount === 0
                text: !kcm.client.enabled ? i18n("Firewall is disabled") : i18n("No firewall rules have been added")
                explanation: kcm.client.enabled ?
                    xi18nc("@info", "Click the <interface>Add Rule…</interface> button below to add one") :
                    xi18nc("@info", "Enable the firewall with the <interface>Firewall Status</interface> checkbox above, and then click the <interface>Add Rule…</interface> button below to add one")
            }

            QQC1.TableViewColumn {
                title: i18n("Action")
                role: "action"
                width: Kirigami.Units.gridUnit * 8
            }
            QQC1.TableViewColumn {
                title: i18n("From")
                role: "from"
                width: Kirigami.Units.gridUnit * 10
            }
            QQC1.TableViewColumn {
                title: i18n("To")
                role: "to"
                width: Kirigami.Units.gridUnit * 10
            }
            QQC1.TableViewColumn {
                title: i18n("IP")
                role: "ipVersion"
                width: Kirigami.Units.gridUnit * 4
            }
            QQC1.TableViewColumn {
                title: i18n("Logging")
                role: "logging"
                width: Kirigami.Units.gridUnit * 5
            }

            QQC1.TableViewColumn {
                width: Kirigami.Units.iconSizes.small * 6
                resizable: false
                delegate: RowLayout {
                    id: ruleActionsRow
                    property QtObject activeJob: null
                    spacing: 0
                    // TODO InlineBusyIndicator?
                    enabled: !activeJob
                    visible: tableView.currentHoveredRow === styleData.row || tableView.selection.contains(styleData.row)

                    Item {
                        Layout.fillWidth: true
                    }

                    QQC2.ToolButton {
                        Layout.fillHeight: true
                        icon.name: "edit-entry"
                        visible: kcm.client.supportsRuleUpdate
                        onClicked: tableView.editRule(styleData.row)
                        QQC2.ToolTip {
                            text: i18nc("@info:tooltip", "Edit Rule")
                        }
                    }
                    QQC2.ToolButton {
                        Layout.fillHeight: true
                        icon.name: "edit-delete"
                        onClicked: {
                            const job = kcm.client.removeRule(styleData.row);
                            if (!job) {
                                firewallInlineErrorMessage.text = i18n("Please restart plasma firewall, the backend disconnected.");
                                firewallInlineErrorMessage.visible = true;
                                return;
                            }

                            ruleActionsRow.activeJob = job;
                            kcm.needsSave = true;
                            job.result.connect(function () {
                                ruleActionsRow.activeJob = null;

                                if (job.error && job.error !== 4) { // TODO magic number
                                    firewallInlineErrorMessage.text = i18n("Error removing rule: %1", job.errorString);
                                    firewallInlineErrorMessage.visible = true;
                                }

                            });
                        }
                        QQC2.ToolTip {
                            text: i18nc("@info:tooltip", "Remove Rule")
                        }
                    }
                }
            }
        }
    }

    footer: RowLayout {
        QQC2.Button {
            text: i18nc("'view' is being used as a verb here", "View Connections")
            icon.name: "network-connect"
            onClicked: kcm.push("ConnectionsView.qml");
        }
        QQC2.Button {
            text: i18nc("'view' is being used as a verb here", "View Logs")
            icon.name: "viewlog"
            onClicked: kcm.push("LogsView.qml");
        }
        Item {
            Layout.fillWidth: true
        }

        QQC2.Button {
            enabled: !kcm.client.busy && kcm.client.enabled
            icon.name: "list-add"
            text: i18n("Add Rule…")
            onClicked: {
                ruleEdit.newRule = true
                drawer.open()
            }
        }

        QQC2.Button {
            icon.name: "help-about"
            text: i18n("About")
            onClicked: root.showAboutView()
        }

    }

    Component.onCompleted: {
        if (kcm.client.name === "") {
            firewallInlineErrorMessage.text = i18n("Please install a firewall, such as ufw or firewalld");
            firewallInlineErrorMessage.visible = true;
            enabledCheckBox.enabled = false;
        } else {
            // Initialize the client's status.
            kcm.client.refresh();
        }
    }

    function showAboutView() {
        const sheet = aboutComponent.createObject(this);
        sheet.open();
    }

    Component {
        id: aboutComponent
        About {
            parent: root.QQC2.Overlay.overlay

            onClosed: destroy()
        }
    }
}
