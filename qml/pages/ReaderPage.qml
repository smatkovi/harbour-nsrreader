import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: reader
    property string path: ""
    property int currentPage: 1
    property real zoom: 1.0
    property int renderAhead: settings.renderAhead
    property string navBuffer: ""
    property bool navIsBar: false
    property string notice: ""
    property int rotation: 0
    property bool inverted: settings.invertedColors
    property bool fullscreen: settings.fullscreen
    property real renderZoom: 1.0
    property string shownSource: ""
    property real shownScale: 1.0

    property bool annotate: false
    property int tool: 0
    property string annColor: "#33aaff"

    allowedOrientations: Orientation.All
    focus: true

    function pointsW() { var s = pdf.pageSizePoints(currentPage, rotation); return (s && s.width > 0) ? s.width : 595 }
    function pointsH() { var s = pdf.pageSizePoints(currentPage, rotation); return (s && s.height > 0) ? s.height : 842 }
    function baseScale() { return reader.width / pointsW() }
    function effScale() { return baseScale() * zoom }
    function renderScale() { return baseScale() * renderZoom }
    function pxW() { return Math.round(pointsW() * effScale()) }
    function pxH() { return Math.round(pointsH() * effScale()) }
    function srcFor(pg) { return "image://pdf/" + pg + "/" + Math.round(renderScale() * 1000)
                                 + "/" + reader.rotation + "/" + (reader.inverted ? 1 : 0)
                                 + "/" + pdf.generation }
    function rotateBy(d) { reader.rotation = ((reader.rotation + d) % 360 + 360) % 360;
                           settings.setLastRotation(reader.path, reader.rotation) }

    function goToPage(pg) {
        if (pg < 1) pg = 1
        if (pg > pdf.pageCount) pg = pdf.pageCount
        currentPage = pg
        flick.contentX = 0; flick.contentY = 0
        annCanvas.requestPaint()
    }
    function fitPage() { reader.zoom = (reader.height / pointsH()) / (reader.width / pointsW()) }
    function showNotice(t) { reader.notice = t; noticeTimer.restart() }
    Timer { id: noticeTimer; interval: 4000; onTriggered: reader.notice = "" }
    Timer { id: zoomSettle; interval: 250; onTriggered: reader.renderZoom = reader.zoom }

    Component.onCompleted: { pdf.source = path; anns.setDocument(path) }
    onCurrentPageChanged: settings.setLastPage(reader.path, currentPage)
    onZoomChanged: { settings.setLastZoom(reader.path, zoom); zoomSettle.restart() }
    Connections {
        target: pdf
        onLoadedChanged: {
            reader.shownSource = ""
            reader.shownScale = 1.0
            if (!pdf.loaded) return
            scanner.scan(pdf)
            reader.rotation = settings.lastRotation(reader.path)
            reader.zoom = settings.lastZoom(reader.path)
            reader.renderZoom = reader.zoom
            settings.lastDoc = reader.path
            goToPage(settings.lastPage(reader.path))
            if (scanner.markerLabels.length > 0) reader.showNotice("Text jumps: " + scanner.markerLabels.join(", "))
            else if (scanner.hasBars) reader.showNotice("Bar jump available")
        }
    }
    Connections { target: anns; onChanged: annCanvas.requestPaint() }

    PinchArea {
        id: pinchArea
        anchors.fill: parent
        enabled: !reader.annotate
        property real startZoom: 1.0
        onPinchStarted: startZoom = reader.zoom
        onPinchUpdated: {
            var z = startZoom * pinch.scale
            if (z < 0.5) z = 0.5
            if (z > 6) z = 6
            reader.zoom = z
        }

        SilicaFlickable {
            id: flick
            anchors.fill: parent
            contentWidth: Math.max(width, pxW())
            contentHeight: Math.max(height, pxH())
            clip: true
            interactive: !reader.annotate

            PullDownMenu {
                MenuItem { text: "Open another"; onClicked: pageStack.pop() }
                MenuItem { text: reader.annotate ? "Stop annotating" : "Annotate"; onClicked: reader.annotate = !reader.annotate }
                MenuItem { text: "Go to bar / mark"; onClicked: reader.askBar() }
                MenuItem { text: "Go to page"; onClicked: reader.askPage() }
                MenuItem { text: "Fit page"; onClicked: reader.fitPage() }
                MenuItem { text: "Fit width"; onClicked: reader.zoom = 1.0 }
                MenuItem { text: reader.fullscreen ? "Show controls" : "Fullscreen"
                    onClicked: { reader.fullscreen = !reader.fullscreen; settings.fullscreen = reader.fullscreen } }
                MenuItem { text: reader.inverted ? "Normal colours" : "Invert colours"
                    onClicked: { reader.inverted = !reader.inverted; settings.invertedColors = reader.inverted } }
                MenuItem { text: "Rotate right"; onClicked: reader.rotateBy(90) }
                MenuItem { text: "Rotate left"; onClicked: reader.rotateBy(-90) }
                MenuItem { text: "Preferences"; onClicked: pageStack.push(Qt.resolvedUrl("PreferencesPage.qml")) }
            }

            Item {
                id: content
                width: flick.contentWidth
                height: flick.contentHeight

                Image {
                    id: pageImg
                    anchors.centerIn: parent
                    width: Math.max(1, Math.round(pointsW() * reader.shownScale))
                    height: Math.max(1, Math.round(pointsH() * reader.shownScale))
                    scale: reader.shownScale > 0 ? reader.effScale() / reader.shownScale : 1
                    transformOrigin: Item.Center
                    fillMode: Image.Stretch
                    asynchronous: false; cache: true
                    source: reader.shownSource
                    onWidthChanged: annCanvas.requestPaint()

                    Canvas {
                        id: annCanvas
                        anchors.fill: parent
                        property var tempPts: []
                        property real sx: 0
                        property real sy: 0
                        property real cx: 0
                        property real cy: 0
                        property bool drawing: false
                        property int editIdx: -1
                        property real editDx: 0
                        property real editDy: 0
                        property real editScaleX: 1
                        property real editScaleY: 1

                        function px(v) { return v * width }
                        function py(v) { return v * height }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var list = anns.forPage(reader.currentPage)
                            for (var i = 0; i < list.length; ++i) drawAnn(ctx, list[i], list[i].index === editIdx)
                            if (drawing) drawTemp(ctx)
                        }
                        function drawAnn(ctx, a, edited) {
                            ctx.save()
                            ctx.strokeStyle = a.color; ctx.fillStyle = a.color; ctx.lineWidth = 3
                            var dx = 0, dy = 0, ssx = 1, ssy = 1
                            if (edited) {
                                if (reader.tool === 5) { ssx = editScaleX; ssy = editScaleY }
                                else { dx = editDx; dy = editDy }
                            }
                            var ax = a.x, ay = a.y
                            if (a.type === 0) {
                                ctx.beginPath()
                                ctx.ellipse(px(ax + dx), py(ay + dy), px(a.w) * ssx, py(a.h) * ssy)
                                ctx.stroke()
                            } else if (a.type === 1) {
                                ctx.beginPath()
                                for (var k = 0; k < a.pts.length; ++k) {
                                    var X = px(ax + (a.pts[k].x - ax) * ssx + dx)
                                    var Y = py(ay + (a.pts[k].y - ay) * ssy + dy)
                                    if (k === 0) ctx.moveTo(X, Y); else ctx.lineTo(X, Y)
                                }
                                ctx.stroke()
                            } else if (a.type === 2) {
                                var fs = Math.max(10, py(a.h) * ssy * 1.6)
                                ctx.font = "bold italic " + fs + "px sans-serif"
                                ctx.fillText(a.text, px(ax + dx), py(ay + dy) + fs)
                            } else if (a.type === 3) {
                                var x0 = px(ax + dx), x1 = px(ax + a.w * ssx + dx)
                                var yt = py(ay + dy), yb = py(ay + dy) + py(a.h) * ssy, ym = (yt + yb) / 2
                                ctx.beginPath()
                                if (a.text === "d") { ctx.moveTo(x1, yt); ctx.lineTo(x0, ym); ctx.lineTo(x1, yb) }
                                else { ctx.moveTo(x0, yt); ctx.lineTo(x1, ym); ctx.lineTo(x0, yb) }
                                ctx.stroke()
                            }
                            ctx.restore()
                        }
                        function drawTemp(ctx) {
                            ctx.save(); ctx.strokeStyle = reader.annColor; ctx.lineWidth = 3
                            if (reader.tool === 1) {
                                ctx.beginPath()
                                for (var k = 0; k < tempPts.length; ++k) {
                                    if (k === 0) ctx.moveTo(tempPts[k].x, tempPts[k].y); else ctx.lineTo(tempPts[k].x, tempPts[k].y)
                                }
                                ctx.stroke()
                            } else if (reader.tool === 0) {
                                ctx.beginPath()
                                ctx.ellipse(Math.min(sx, cx), Math.min(sy, cy), Math.abs(cx - sx), Math.abs(cy - sy))
                                ctx.stroke()
                            } else if (reader.tool === 3) {
                                var ym = (sy + cy) / 2
                                ctx.beginPath()
                                if (cx >= sx) { ctx.moveTo(sx, sy); ctx.lineTo(cx, ym); ctx.lineTo(sx, cy) }
                                else { ctx.moveTo(sx, ym); ctx.lineTo(cx, sy); ctx.moveTo(sx, ym); ctx.lineTo(cx, cy) }
                                ctx.stroke()
                            }
                            ctx.restore()
                        }
                        function bbox(a) {
                            if (a.type === 1 && a.pts.length) {
                                var x0 = a.pts[0].x, y0 = a.pts[0].y, x1 = x0, y1 = y0
                                for (var k = 1; k < a.pts.length; ++k) {
                                    var p = a.pts[k]
                                    if (p.x < x0) x0 = p.x
                                    if (p.x > x1) x1 = p.x
                                    if (p.y < y0) y0 = p.y
                                    if (p.y > y1) y1 = p.y
                                }
                                return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
                            }
                            return { x: a.x, y: a.y, w: a.w, h: a.h }
                        }
                        function byIndex(idx) {
                            var list = anns.forPage(reader.currentPage)
                            for (var i = 0; i < list.length; ++i) if (list[i].index === idx) return list[i]
                            return null
                        }
                        function hit(fx, fy) {
                            var list = anns.forPage(reader.currentPage)
                            var m = 0.03, best = -1
                            for (var i = 0; i < list.length; ++i) {
                                var b = bbox(list[i])
                                if (fx >= b.x - m && fx <= b.x + b.w + m && fy >= b.y - m && fy <= b.y + b.h + m) best = list[i].index
                            }
                            return best
                        }

                        MouseArea {
                            id: annMouse
                            anchors.fill: parent
                            enabled: reader.annotate
                            property real fx: 0
                            property real fy: 0
                            onPressed: {
                                var rx = mouse.x / width, ry = mouse.y / height
                                annCanvas.sx = mouse.x; annCanvas.sy = mouse.y
                                annCanvas.cx = mouse.x; annCanvas.cy = mouse.y
                                if (reader.tool >= 4) {
                                    var idx = annCanvas.hit(rx, ry)
                                    if (idx < 0) return
                                    if (reader.tool === 6) { anns.deleteAnn(idx); return }
                                    if (reader.tool === 7) { anns.recolorAnn(idx, reader.annColor); return }
                                    annCanvas.editIdx = idx
                                    annCanvas.editDx = 0; annCanvas.editDy = 0
                                    annCanvas.editScaleX = 1; annCanvas.editScaleY = 1
                                    fx = rx; fy = ry
                                    annCanvas.drawing = true
                                } else if (reader.tool === 2) {
                                    reader.pickDynamic(rx, ry)
                                } else if (reader.tool === 3 && annCanvas.hit(rx, ry) >= 0
                                           && anns.typeOf(annCanvas.hit(rx, ry)) === 3) {
                                    anns.flipHairpin(annCanvas.hit(rx, ry))
                                } else {
                                    annCanvas.drawing = true
                                    annCanvas.tempPts = [{ x: mouse.x, y: mouse.y }]
                                }
                            }
                            onPositionChanged: {
                                annCanvas.cx = mouse.x; annCanvas.cy = mouse.y
                                if (reader.tool === 1) annCanvas.tempPts.push({ x: mouse.x, y: mouse.y })
                                else if (reader.tool === 4 && annCanvas.editIdx >= 0) {
                                    annCanvas.editDx = mouse.x / width - fx
                                    annCanvas.editDy = mouse.y / height - fy
                                } else if (reader.tool === 5 && annCanvas.editIdx >= 0) {
                                    var a = annCanvas.byIndex(annCanvas.editIdx)
                                    if (a) {
                                        var b = annCanvas.bbox(a)
                                        var w = Math.max(b.w, 0.001), h = Math.max(b.h, 0.001)
                                        var s1 = (mouse.x / width - b.x) / w
                                        var s2 = (mouse.y / height - b.y) / h
                                        annCanvas.editScaleX = Math.min(5, Math.max(0.2, s1))
                                        annCanvas.editScaleY = Math.min(5, Math.max(0.2, s2))
                                    }
                                }
                                annCanvas.requestPaint()
                            }
                            onReleased: {
                                var pg = reader.currentPage
                                if (reader.tool === 0) {
                                    var x = Math.min(annCanvas.sx, annCanvas.cx) / width
                                    var y = Math.min(annCanvas.sy, annCanvas.cy) / height
                                    var w = Math.abs(annCanvas.cx - annCanvas.sx) / width
                                    var h = Math.abs(annCanvas.cy - annCanvas.sy) / height
                                    if (w > 0.01 && h > 0.01) anns.addCircle(pg, x, y, w, h, reader.annColor)
                                } else if (reader.tool === 1) {
                                    var pts = []
                                    for (var k = 0; k < annCanvas.tempPts.length; ++k)
                                        pts.push({ x: annCanvas.tempPts[k].x / width, y: annCanvas.tempPts[k].y / height })
                                    if (pts.length >= 2) anns.addPen(pg, pts, reader.annColor)
                                } else if (reader.tool === 3) {
                                    var hx = Math.min(annCanvas.sx, annCanvas.cx) / width
                                    var hy = Math.min(annCanvas.sy, annCanvas.cy) / height
                                    var hw = Math.abs(annCanvas.cx - annCanvas.sx) / width
                                    var hh = Math.abs(annCanvas.cy - annCanvas.sy) / height
                                    if (hh < 0.025) { hy = Math.max(0, hy - 0.0125); hh = 0.025 }
                                    if (hw > 0.01) anns.addHairpin(pg, hx, hy, hw, hh, annCanvas.cx >= annCanvas.sx, reader.annColor)
                                } else if (reader.tool === 4 && annCanvas.editIdx >= 0) {
                                    anns.moveAnn(annCanvas.editIdx, annCanvas.editDx, annCanvas.editDy)
                                } else if (reader.tool === 5 && annCanvas.editIdx >= 0) {
                                    anns.resizeAnn(annCanvas.editIdx, annCanvas.editScaleX, annCanvas.editScaleY)
                                }
                                annCanvas.drawing = false; annCanvas.editIdx = -1; annCanvas.tempPts = []
                                annCanvas.editDx = 0; annCanvas.editDy = 0
                                annCanvas.editScaleX = 1; annCanvas.editScaleY = 1
                                annCanvas.requestPaint()
                            }
                        }
                    }
                }

                // renders the new resolution off-screen; swap in only when finished
                Image {
                    id: preloader
                    visible: false
                    asynchronous: true
                    cache: true
                    source: pdf.loaded ? reader.srcFor(reader.currentPage) : ""
                    sourceSize.width: Math.round(pointsW() * reader.renderScale())
                    sourceSize.height: Math.round(pointsH() * reader.renderScale())
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            reader.shownSource = source
                            reader.shownScale = reader.renderScale()
                            annCanvas.requestPaint()
                        }
                    }
                }

                // page-turn tap zones (inside the flickable content, above the image)
                MouseArea {
                    anchors.fill: parent
                    enabled: !reader.annotate
                    onClicked: {
                        var p = mapToItem(reader, mouse.x, mouse.y)
                        if (p.x < reader.width * 0.33) reader.goToPage(reader.currentPage - 1)
                        else if (p.x > reader.width * 0.67) reader.goToPage(reader.currentPage + 1)
                    }
                }
            }

            Repeater {
                model: reader.renderAhead
                Image {
                    visible: false; cache: true; asynchronous: true
                    property int pg: reader.currentPage + index + 1
                    source: (pdf.loaded && pg <= pdf.pageCount) ? srcFor(pg) : ""
                    sourceSize.width: pxW(); sourceSize.height: pxH()
                }
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: !pdf.loaded || preloader.status === Image.Loading || reader.shownSource === ""
    }

    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        color: Qt.rgba(0, 0, 0, 0.55); radius: 6
        width: pl.width + Theme.paddingMedium * 2
        height: pl.height + Theme.paddingSmall
        visible: pdf.loaded && !reader.fullscreen
        Label { id: pl; anchors.centerIn: parent; color: "white"
            text: reader.currentPage + " / " + pdf.pageCount; font.pixelSize: Theme.fontSizeSmall }
    }

    Rectangle {
        anchors { top: parent.top; topMargin: Theme.paddingLarge * 3; horizontalCenter: parent.horizontalCenter }
        visible: reader.navBuffer.length > 0
        color: Qt.rgba(0, 0, 0, 0.75); radius: 8
        width: navLbl.width + Theme.paddingLarge * 2
        height: navLbl.height + Theme.paddingMedium
        Label { id: navLbl; anchors.centerIn: parent; color: "white"
            text: (reader.navIsBar ? "Bar " : "Page ") + reader.navBuffer; font.pixelSize: Theme.fontSizeLarge }
    }

    Rectangle {
        anchors { bottom: parent.bottom; bottomMargin: Theme.itemSizeLarge; horizontalCenter: parent.horizontalCenter }
        visible: reader.notice.length > 0
        color: Qt.rgba(0, 0, 0, 0.8); radius: 8
        width: Math.min(reader.width - Theme.paddingLarge * 2, ntLbl.width + Theme.paddingLarge * 2)
        height: ntLbl.height + Theme.paddingMedium
        Label { id: ntLbl; anchors.centerIn: parent; color: "white"; text: reader.notice; font.pixelSize: Theme.fontSizeSmall }
    }

    Row {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Theme.paddingMedium }
        spacing: Theme.paddingSmall
        visible: !reader.annotate && !reader.fullscreen && scanner.scannedOk && scanner.markerLabels.length > 0
        Repeater {
            model: scanner.markerLabels
            Rectangle {
                width: mlab.width + Theme.paddingLarge
                height: mlab.height + Theme.paddingSmall
                radius: 6; color: "#0088cd"
                Label { id: mlab; anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: Theme.fontSizeSmall }
                MouseArea { anchors.fill: parent; onClicked: reader.goToPage(scanner.markerPages[index]) }
            }
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: toolFlow.height + Theme.paddingSmall * 2
        color: Qt.rgba(0, 0, 0, 0.75)
        visible: reader.annotate
        Flow {
            id: toolFlow
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.paddingSmall }
            spacing: Theme.paddingSmall
            Repeater {
                model: ["Circle", "Pen", "Text", "Hairpin", "Move", "Resize", "Delete"]
                Rectangle {
                    width: tl.width + Theme.paddingMedium
                    height: tl.height + Theme.paddingSmall
                    radius: 5
                    color: reader.tool === index ? "#0088cd" : "#555"
                    Label { id: tl; anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: Theme.fontSizeTiny }
                    MouseArea { anchors.fill: parent; onClicked: reader.tool = index }
                }
            }
            Rectangle {
                width: cl.width + Theme.paddingMedium
                height: cl.height + Theme.paddingSmall
                radius: 5; color: reader.annColor
                border.width: reader.tool === 7 ? 3 : 0
                border.color: "white"
                Label { id: cl; anchors.centerIn: parent; text: "Color"; color: "white"; font.pixelSize: Theme.fontSizeTiny }
                MouseArea { anchors.fill: parent; onClicked: reader.pickColor() }
            }
        }
    }

    function askPage() {
        var dlg = pageStack.push(Qt.resolvedUrl("GoToDialog.qml"), { title: "Go to page", numeric: true })
        dlg.accepted.connect(function() { var n = parseInt(dlg.value); if (!isNaN(n)) reader.goToPage(n) })
    }
    function askBar() {
        var dlg = pageStack.push(Qt.resolvedUrl("GoToDialog.qml"), { title: "Go to bar / mark", numeric: false })
        dlg.accepted.connect(function() {
            var v = dlg.value.trim()
            var n = parseInt(v)
            if (!isNaN(n) && String(n) === v) { var p = scanner.jumpToBar(n); if (p > 0) reader.goToPage(p) }
            else if (v.length === 1) { var q = scanner.jumpToLetter(v); if (q > 0) reader.goToPage(q) }
        })
    }
    property real pendingX: 0
    property real pendingY: 0
    function pickDynamic(fx, fy) {
        pendingX = fx; pendingY = fy
        var dlg = pageStack.push(Qt.resolvedUrl("PickListDialog.qml"),
            { title: "Dynamic", items: ["pp", "p", "mp", "mf", "f", "ff", "sf", "fp", "cresc.", "dim."] })
        dlg.accepted.connect(function() {
            if (dlg.selected.length) anns.addText(reader.currentPage, reader.pendingX, reader.pendingY, dlg.selected, reader.annColor)
        })
    }
    function pickColor() {
        var dlg = pageStack.push(Qt.resolvedUrl("PickListDialog.qml"),
            { title: "Color", items: ["Light blue", "Red", "Green", "Orange", "Black", "Magenta"] })
        dlg.accepted.connect(function() {
            var map = { "Light blue": "#33aaff", "Red": "#ff0000", "Green": "#00aa00",
                        "Orange": "#ff8800", "Black": "#000000", "Magenta": "#cc00cc" }
            if (map[dlg.selected]) { reader.annColor = map[dlg.selected]; reader.tool = 7 }
        })
    }

    function commitNav() {
        if (navBuffer.length === 0) return
        var n = parseInt(navBuffer)
        navBuffer = ""
        if (isNaN(n) || n < 1) return
        if (navIsBar) { var p = scanner.jumpToBar(n); if (p > 0) reader.goToPage(p) }
        else reader.goToPage(n)
    }
    function rowDigit(key, row) {
        var i = row.indexOf(key)
        if (i < 0) return -1
        return (i === 9) ? 0 : (i + 1)
    }

    Keys.onPressed: {
        var pageRow = [Qt.Key_Q, Qt.Key_W, Qt.Key_E, Qt.Key_R, Qt.Key_T, Qt.Key_Y, Qt.Key_U, Qt.Key_I, Qt.Key_O, Qt.Key_P]
        var barRow = [Qt.Key_A, Qt.Key_S, Qt.Key_D, Qt.Key_F, Qt.Key_G, Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L, Qt.Key_Apostrophe]
        var markRow = [Qt.Key_Z, Qt.Key_X, Qt.Key_C, Qt.Key_V]

        if ((event.modifiers & Qt.ShiftModifier) && event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
            var L = String.fromCharCode(65 + (event.key - Qt.Key_A))
            var lp = scanner.jumpToLetter(L)
            if (lp > 0) reader.goToPage(lp)
            event.accepted = true; return
        }
        var mi = markRow.indexOf(event.key)
        if (mi >= 0 && mi < scanner.markerLabels.length) {
            reader.goToPage(scanner.markerPages[mi]); event.accepted = true; return
        }
        var d = rowDigit(event.key, pageRow)
        if (d >= 0) {
            if (navBuffer.length === 0 || navIsBar) { navBuffer = ""; navIsBar = false }
            navBuffer += String(d); event.accepted = true; return
        }
        d = rowDigit(event.key, barRow)
        if (d >= 0) {
            if (navBuffer.length === 0 || !navIsBar) { navBuffer = ""; navIsBar = true }
            navBuffer += String(d); event.accepted = true; return
        }
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            if (navBuffer.length === 0) navIsBar = false
            navBuffer += String(event.key - Qt.Key_0); event.accepted = true; return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { commitNav(); event.accepted = true; return }
        if (event.key === Qt.Key_Backspace) { navBuffer = navBuffer.slice(0, -1); event.accepted = true; return }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) { reader.goToPage(reader.currentPage + 1); event.accepted = true; return }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) { reader.goToPage(reader.currentPage - 1); event.accepted = true; return }
        if (event.key === Qt.Key_Plus) { reader.zoom = Math.min(6, reader.zoom * 1.25); event.accepted = true; return }
        if (event.key === Qt.Key_Minus) { reader.zoom = Math.max(0.5, reader.zoom / 1.25); event.accepted = true; return }
    }
}
