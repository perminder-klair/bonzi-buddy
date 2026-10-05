import QtQuick
import Quickshell.Services.Mpris

Item {
    readonly property var players: Mpris.players.values
    readonly property var player: {
        for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
        return players.length ? players[0] : null
    }
    readonly property var snapshot: ({
        available: player !== null,
        playing: player ? player.isPlaying : false,
        player: player ? player.identity : "",
        title: player ? player.trackTitle : "",
        artist: player ? player.trackArtist : ""
    })
}
