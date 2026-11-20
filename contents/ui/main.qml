pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    readonly property Mpris.PlayerContainer spotify: {
        for (let index = 0; index < players.count; ++index) {
            const entry = players.objectAt(index)
            if (entry && entry.isSpotify)
                return entry.container
        }
        return null
    }
    readonly property bool playing: spotify?.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canToggle: playing ? !!spotify?.canPause : !!spotify?.canPlay
    readonly property string trackTitle: spotify?.track ||
        (spotify ? qsTr("Spotify") : qsTr("Spotify закрыт"))

    readonly property string artistAndTrack: spotify?.artist && spotify?.track
        ? qsTr("%1 - %2").arg(spotify.artist).arg(trackTitle)
        : trackTitle

    Mpris.Mpris2Model { id: mediaPlayers }

    Instantiator {
        id: players
        model: mediaPlayers
        delegate: QtObject {
            required property bool isMultiplexer
            required property Mpris.PlayerContainer container
            readonly property bool isSpotify: !isMultiplexer && container !== null &&
                (["spotify", "com.spotify.client"].includes(container.desktopEntry.toLowerCase()) ||
                 container.identity.toLowerCase() === "spotify")
        }
    }

    toolTipMainText: artistAndTrack
    toolTipTextFormat: Text.PlainText
    toolTipSubText: spotify
        ? qsTr("Громкость Spotify %1%").arg(Math.round(spotify.volume * 100))
        : qsTr("Откройте приложение Spotify")

    fullRepresentation: Item {
        id: controls

        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
        Layout.preferredWidth: verticalPanel ? Layout.minimumWidth : Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2

        readonly property bool verticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        PlasmaComponents.ToolButton {
            anchors.fill: parent
            padding: Kirigami.Units.smallSpacing
            enabled: root.canToggle
            Accessible.name: root.playing ? qsTr("Пауза Spotify") : qsTr("Воспроизвести Spotify")
            Accessible.description: root.artistAndTrack

            onClicked: {
                if (root.playing)
                    root.spotify.Pause()
                else
                    root.spotify.Play()
            }

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: Math.min(Kirigami.Units.iconSizes.smallMedium, parent.height)
                    Layout.preferredHeight: Layout.preferredWidth
                    source: root.playing ? "media-playback-pause" : "media-playback-start"
                }

                Item {
                    visible: !controls.verticalPanel && !!root.spotify?.track
                    Layout.preferredWidth: Math.min(Kirigami.Units.iconSizes.medium, parent.height)
                    Layout.preferredHeight: Layout.preferredWidth

                    Kirigami.Icon {
                        anchors.fill: parent
                        source: "media-optical-audio"
                        visible: albumArt.status !== Image.Ready
                    }

                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: root.spotify?.artUrl || ""
                        sourceSize.width: width * Screen.devicePixelRatio
                        sourceSize.height: height * Screen.devicePixelRatio
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                PlasmaComponents.Label {
                    visible: !controls.verticalPanel
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.artistAndTrack
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.BackButton | Qt.ForwardButton

            property real wheelRemainder: 0

            onClicked: mouse => {
                const player = root.spotify
                if (mouse.button === Qt.BackButton && player?.canGoPrevious)
                    player.Previous()
                else if (mouse.button === Qt.ForwardButton && player?.canGoNext)
                    player.Next()
            }

            onWheel: wheel => {
                const player = root.spotify
                if (!player?.canControl || wheel.angleDelta.y === 0) {
                    wheelRemainder = 0
                    wheel.accepted = false
                    return
                }

                wheel.accepted = true
                wheelRemainder += wheel.angleDelta.y
                const steps = Math.trunc(wheelRemainder / 120)
                wheelRemainder -= steps * 120
                if (steps !== 0)
                    player.changeVolume(steps * 0.05, true)
            }
        }
    }
}
