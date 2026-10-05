function focusReason(desktop, dnd, prefs) {
    if (desktop.available === false && (prefs.fullscreenQuiet || prefs.focusApps)) return "Desktop unavailable";
    if (prefs.dndQuiet && dnd === true) return "Do Not Disturb";
    if (prefs.fullscreenQuiet && desktop.fullscreen) return "Fullscreen";
    if (desktop.blockedApp) return "Chosen app";
    return "";
}
function canReact(state) {
    return !state.hidden && !state.sleeping && !state.focus && state.personality !== "quiet"
        && (state.last === 0 || state.now - state.last >= state.cooldown * 1000);
}
function overlap(a, size, b) {
    return Math.max(0, Math.min(a.x + size, b.x + b.width) - Math.max(a.x, b.x))
        * Math.max(0, Math.min(a.y + size, b.y + b.height) - Math.max(a.y, b.y));
}
function avoidWindow(home, size, screen, rect) {
    if (!rect || overlap(home, size, rect) === 0) return home;
    var right = Math.max(12, screen.width - size - 12);
    var bottom = Math.max(48, screen.height - size - 16);
    var candidates = [{x:12,y:48}, {x:right,y:48}, {x:12,y:bottom}, {x:right,y:bottom}];
    var best = home, bestArea = overlap(home, size, rect), bestDistance = Infinity;
    for (var i = 0; i < candidates.length; i++) {
        var point = candidates[i], area = overlap(point, size, rect);
        var distance = Math.pow(point.x-home.x, 2) + Math.pow(point.y-home.y, 2);
        if (area < bestArea || (area === bestArea && best !== home && distance < bestDistance)) {
            best = point; bestArea = area; bestDistance = distance;
        }
    }
    return best;
}

function canAvoid(state) {
    if (state.menu || state.dragging || state.hovered || state.now < state.dragUntil
        || state.now - state.lastMove < 30000 || state.sampleAge > 750 || !state.cursor) return false;
    return Math.abs(state.cursor.x - state.x - state.size / 2) >= state.size / 2 + 240
        || Math.abs(state.cursor.y - state.y - state.size / 2) >= state.size / 2 + 240;
}
