import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: reader
    property string path: ""
    property int currentPage: 1
    property real zoom: 1.0
    property int renderAhead: 2

    // annotation state
    property bool annotate: false
    property int tool: 0            // 0 circle,1 pen,2 text,3 hairpin,4 move,5 resize,6 recolor,7 delete
    property string annColor: "#33aaff"

    allowedOrientations: Orientation.All

    function pointsW() { var s = pdf.pageSizePoints(currentPage); return s.width > 0 ? s.width : 595; }
    function pointsH() { var s = pdf.pageSizePoints(currentPage); return s.height > 0 ? s.height : 842; }
    function baseScale() { return reader.width / pointsW(); }
    function effScale() { return baseScale() * zoom; }
    function pxW() { return Math.round(pointsW() * effScale()); }
    function pxH() { return Math.round(pointsH() * effScale()); }
    function srcFor(pg) { return "image://pdf/" + pg + "/" + Math.round(effScale() * 1000); }

    function goToPage(pg) {
        if (pg < 1) pg = 1;
        if (pg > pdf.pageCount) pg = pdf.pageCount;
        currentPage = pg;
        flick.contentX = 0; flick.contentY = 0;
        annCanvas.requestPaint();
    }

    Component.onCompleted: { pdf.source = path; anns.setDocument(path); }
    Connections {
        target: pdf
        onLoadedChanged: { if (pdf.loaded) { scanner.scan(pdf); goToPage(1); } }
    }
    Connections { target: anns; onChanged: annCanvas.requestPaint() }

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
            MenuItem { text: "Fit width"; onClicked: reader.zoom = 1.0 }
        }

        PinchArea {
            id: pinch
            width: Math.max(flick.width, pxW())
            height: Math.max(flick.height, pxH())
            enabled: !reader.annotate
            property real startZoom: 1.0
            onPinchStarted: startZoom = reader.zoom
            onPinchUpdated: { var z = startZoom * pinch.scale; if (z < 0.5) z = 0.5; if (z > 6) z = 6; reader.zoom = z }

            Image {
                id: pageImg
                anchors.centerIn: parent
                width: pxW(); height: pxH()
                fillMode: Image.Stretch
                asynchronous: true; cache: true
                sourceSize.width: pxW(); sourceSize.height: pxH()
                source: pdf.loaded ? srcFor(currentPage) : ""
                onWidthChanged: annCanvas.requestPaint()
                BusyIndicator { anchors.centerIn: parent; running: pageImg.status !== Image.Ready; size: BusyIndicatorSize.Large }

                // ---------- annotation overlay ----------
                Canvas {
                    id: annCanvas
                    anchors.fill: parent
                    property var tempPts: []
                    property real sx: 0; property real sy: 0
                    property real cx: 0; property real cy: 0
                    property bool drawing: false
                    property int editIdx: -1
                    property real editDx: 0; property real editDy: 0
                    property real editScaleX: 1; property real editScaleY: 1

                    function px(v) { return v * width; }
                    function py(v) { return v * height; }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var list = anns.forPage(reader.currentPage);
                        for (var i = 0; i < list.length; ++i) drawAnn(ctx, list[i], i === editIdx);
                        if (drawing) drawTemp(ctx);
                    }
                    function drawAnn(ctx, a, edited) {
                        ctx.save();
                        ctx.strokeStyle = a.color; ctx.fillStyle = a.color; ctx.lineWidth = 3;
                        var dx = 0, dy = 0, ssx = 1, ssy = 1, ax = a.x, ay = a.y;
                        if (edited) {
                            if (reader.tool === 5) { ssx = editScaleX; ssy = editScaleY; }
                            else { dx = editDx; dy = editDy; }
                        }
                        if (a.type === 0) {
                            ctx.beginPath();
                            ctx.ellipse(px(ax+dx), py(ay+dy), px(a.w)*ssx, py(a.h)*ssy); ctx.stroke();
                        } else if (a.type === 1) {
                            ctx.beginPath();
                            for (var k = 0; k < a.pts.length; ++k) {
                                var X = px(ax + (a.pts[k].x - ax)*ssx + dx), Y = py(ay + (a.pts[k].y - ay)*ssy + dy);
                                if (k === 0) ctx.moveTo(X, Y); else ctx.lineTo(X, Y);
                            }
                            ctx.stroke();
                        } else if (a.type === 2) {
                            ctx.font = "bold italic " + Math.max(12, px(0.03)) + "px sans-serif";
                            ctx.fillText(a.text, px(ax+dx), py(ay+dy) + px(0.03));
                        } else if (a.type === 3) {
                            var x0 = px(ax+dx), x1 = px(ax+a.w*ssx+dx), ym = py(ay+dy) + py(a.h)/2;
                            ctx.beginPath();
                            if (a.text === "d") { ctx.moveTo(x1, py(ay+dy)); ctx.lineTo(x0, ym); ctx.lineTo(x1, py(ay+dy)+py(a.h)); }
                            else { ctx.moveTo(x0, py(ay+dy)); ctx.lineTo(x1, ym); ctx.lineTo(x0, py(ay+dy)+py(a.h)); }
                            ctx.stroke();
                        }
                        ctx.restore();
                    }
                    function drawTemp(ctx) {
                        ctx.save(); ctx.strokeStyle = reader.annColor; ctx.lineWidth = 3;
                        if (reader.tool === 1) {
                            ctx.beginPath();
                            for (var k = 0; k < tempPts.length; ++k) { if (k===0) ctx.moveTo(tempPts[k].x, tempPts[k].y); else ctx.lineTo(tempPts[k].x, tempPts[k].y); }
                            ctx.stroke();
                        } else if (reader.tool === 0) {
                            ctx.beginPath(); ctx.ellipse(Math.min(sx,cx), Math.min(sy,cy), Math.abs(cx-sx), Math.abs(cy-sy)); ctx.stroke();
                        } else if (reader.tool === 3) {
                            var ym=(sy+cy)/2; ctx.beginPath();
                            if (cx>=sx) { ctx.moveTo(sx,sy); ctx.lineTo(cx,ym); ctx.lineTo(sx,cy); }
                            else { ctx.moveTo(sx,ym); ctx.lineTo(cx,sy); ctx.lineTo(cx,cy); ctx.moveTo(sx,ym); ctx.lineTo(cx,cy); }
                            ctx.stroke();
                        }
                        ctx.restore();
                    }
                    function bbox(a) {
                        if (a.type === 1 && a.pts.length) {
                            var x0=a.pts[0].x,y0=a.pts[0].y,x1=x0,y1=y0;
                            for (var k=1;k<a.pts.length;++k){var p=a.pts[k]; if(p.x<x0)x0=p.x; if(p.x>x1)x1=p.x; if(p.y<y0)y0=p.y; if(p.y>y1)y1=p.y;}
                            return {x:x0,y:y0,w:x1-x0,h:y1-y0};
                        }
                        return {x:a.x,y:a.y,w:a.w,h:a.h};
                    }
                    function hit(fx, fy) {
                        var list = anns.forPage(reader.currentPage); var m=0.03; var best=-1;
                        for (var i=0;i<list.length;++i){ var b=bbox(list[i]);
                            if (fx>=b.x-m && fx<=b.x+b.w+m && fy>=b.y-m && fy<=b.y+b.h+m) best=list[i].index; }
                        return best;
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: reader.annotate
                        property real fx: 0; property real fy: 0
                        onPressed: {
                            var f = { x: mouse.x/width, y: mouse.y/height };
                            annCanvas.sx = mouse.x; annCanvas.sy = mouse.y; annCanvas.cx = mouse.x; annCanvas.cy = mouse.y;
                            if (reader.tool >= 4) {
                                var idx = annCanvas.hit(f.x, f.y);
                                if (idx < 0) return;
                                if (reader.tool === 7) { anns.deleteAnn(idx); return; }
                                if (reader.tool === 6) { anns.recolorAnn(idx, reader.annColor); return; }
                                annCanvas.editIdx = idx; annCanvas.editDx = 0; annCanvas.editDy = 0;
                                annCanvas.editScaleX = 1; annCanvas.editScaleY = 1; fx = f.x; fy = f.y;
                                annCanvas.drawing = true;
                            } else {
                                annCanvas.drawing = true; annCanvas.tempPts = [{x:mouse.x,y:mouse.y}];
                                if (reader.tool === 2) { annCanvas.drawing = false; reader.pickDynamic(f.x, f.y); }
                            }
                        }
                        onPositionChanged: {
                            annCanvas.cx = mouse.x; annCanvas.cy = mouse.y;
                            if (reader.tool === 1) annCanvas.tempPts.push({x:mouse.x,y:mouse.y});
                            else if (reader.tool === 4 && annCanvas.editIdx>=0) { annCanvas.editDx = mouse.x/width - fx; annCanvas.editDy = mouse.y/height - fy; }
                            else if (reader.tool === 5 && annCanvas.editIdx>=0) {
                                var b = annCanvas.bbox(anns.forPage(reader.currentPage).filter(function(o){return o.index===annCanvas.editIdx})[0]);
                                var w=Math.max(b.w,0.001), h=Math.max(b.h,0.001);
                                var s1=(mouse.x/width-b.x)/w, s2=(mouse.y/height-b.y)/h;
                                annCanvas.editScaleX = Math.min(5,Math.max(0.2,s1)); annCanvas.editScaleY = Math.min(5,Math.max(0.2,s2));
                            }
                            annCanvas.requestPaint();
                        }
                        onReleased: {
                            var pg = reader.currentPage;
                            if (reader.tool === 0) {
                                var x=Math.min(annCanvas.sx,annCanvas.cx)/width, y=Math.min(annCanvas.sy,annCanvas.cy)/height;
                                var w=Math.abs(annCanvas.cx-annCanvas.sx)/width, h=Math.abs(annCanvas.cy-annCanvas.sy)/height;
                                if (w>0.01&&h>0.01) anns.addCircle(pg,x,y,w,h,reader.annColor);
                            } else if (reader.tool === 1) {
                                var pts=[]; for (var k=0;k<annCanvas.tempPts.length;++k) pts.push({x:annCanvas.tempPts[k].x/width,y:annCanvas.tempPts[k].y/height});
                                if (pts.length>=2) anns.addPen(pg, pts, reader.annColor);
                            } else if (reader.tool === 3) {
                                var hx=Math.min(annCanvas.sx,annCanvas.cx)/width, hy=Math.min(annCanvas.sy,annCanvas.cy)/height;
                                var hw=Math.abs(annCanvas.cx-annCanvas.sx)/width, hh=Math.abs(annCanvas.cy-annCanvas.sy)/height;
                                if (hw>0.01) anns.addHairpin(pg,hx,hy,hw,hh,annCanvas.cx>=annCanvas.sx,reader.annColor);
                            } else if (reader.tool === 4 && annCanvas.editIdx>=0) {
                                anns.moveAnn(annCanvas.editIdx, annCanvas.editDx, annCanvas.editDy);
                            } else if (reader.tool === 5 && annCanvas.editIdx>=0) {
                                anns.resizeAnn(annCanvas.editIdx, annCanvas.editScaleX, annCanvas.editScaleY);
                            }
                            annCanvas.drawing=false; annCanvas.editIdx=-1; annCanvas.tempPts=[];
                            annCanvas.editDx=0; annCanvas.editDy=0; annCanvas.editScaleX=1; annCanvas.editScaleY=1;
                            annCanvas.requestPaint();
                        }
                    }
                }
            }

            Repeater {
                model: renderAhead
                Image { visible:false; cache:true; asynchronous:true
                    property int pg: currentPage + index + 1
                    source: (pdf.loaded && pg <= pdf.pageCount) ? srcFor(pg) : ""
                    sourceSize.width: pxW(); sourceSize.height: pxH() }
            }
        }
    }

    MouseArea {
        anchors.fill: parent; z: -1; enabled: !reader.annotate
        onClicked: { if (mouse.x < reader.width*0.33) reader.goToPage(currentPage-1); else if (mouse.x > reader.width*0.67) reader.goToPage(currentPage+1); }
    }

    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        color: Qt.rgba(0,0,0,0.55); radius: 6
        width: pl.width + Theme.paddingMedium*2; height: pl.height + Theme.paddingSmall; visible: pdf.loaded
        Label { id: pl; anchors.centerIn: parent; color:"white"; text: currentPage + " / " + pdf.pageCount; font.pixelSize: Theme.fontSizeSmall }
    }

    // marker bar (hidden while annotating)
    Row {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Theme.paddingMedium }
        spacing: Theme.paddingSmall
        visible: !reader.annotate && scanner.scannedOk && scanner.markerLabels.length > 0
        Repeater { model: scanner.markerLabels
            Rectangle { width: mlab.width + Theme.paddingLarge; height: mlab.height + Theme.paddingSmall; radius:6; color:"#0088cd"
                Label { id: mlab; anchors.centerIn: parent; text: modelData; color:"white"; font.pixelSize: Theme.fontSizeSmall }
                MouseArea { anchors.fill: parent; onClicked: reader.goToPage(scanner.markerPages[index]) } } }
    }

    // annotate tool bar
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: toolFlow.height + Theme.paddingSmall*2
        color: Qt.rgba(0,0,0,0.75); visible: reader.annotate
        Flow {
            id: toolFlow
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.paddingSmall }
            spacing: Theme.paddingSmall
            Repeater {
                model: ["Circle","Pen","Text","Hairpin","Move","Resize","Recolor","Delete"]
                Rectangle {
                    width: tl.width + Theme.paddingMedium; height: tl.height + Theme.paddingSmall; radius:5
                    color: reader.tool === index ? "#0088cd" : "#555"
                    Label { id: tl; anchors.centerIn: parent; text: modelData; color:"white"; font.pixelSize: Theme.fontSizeTiny }
                    MouseArea { anchors.fill: parent; onClicked: reader.tool = index }
                }
            }
            Rectangle {
                width: cl.width + Theme.paddingMedium; height: cl.height + Theme.paddingSmall; radius:5; color: reader.annColor
                Label { id: cl; anchors.centerIn: parent; text:"Color"; color:"white"; font.pixelSize: Theme.fontSizeTiny }
                MouseArea { anchors.fill: parent; onClicked: reader.pickColor() }
            }
        }
    }

    function askPage() {
        var dlg = pageStack.push(Qt.resolvedUrl("GoToDialog.qml"), { title:"Go to page", numeric:true })
        dlg.accepted.connect(function() { var n = parseInt(dlg.value); if (!isNaN(n)) reader.goToPage(n) })
    }
    function askBar() {
        var dlg = pageStack.push(Qt.resolvedUrl("GoToDialog.qml"), { title:"Go to bar / mark", numeric:false })
        dlg.accepted.connect(function() {
            var v = dlg.value.trim(); var n = parseInt(v);
            if (!isNaN(n) && String(n) === v) { var p = scanner.jumpToBar(n); if (p>0) reader.goToPage(p) }
            else if (v.length === 1) { var q = scanner.jumpToLetter(v); if (q>0) reader.goToPage(q) }
        })
    }
    property real pendingX: 0; property real pendingY: 0
    function pickDynamic(fx, fy) {
        pendingX = fx; pendingY = fy;
        var dlg = pageStack.push(Qt.resolvedUrl("PickListDialog.qml"),
            { title:"Dynamic", items:["pp","p","mp","mf","f","ff","sf","fp","cresc.","dim."] })
        dlg.accepted.connect(function() { if (dlg.selected.length) anns.addText(reader.currentPage, pendingX, pendingY, dlg.selected, reader.annColor) })
    }
    function pickColor() {
        var dlg = pageStack.push(Qt.resolvedUrl("PickListDialog.qml"),
            { title:"Color", items:["Light blue","Red","Green","Orange","Black","Magenta"] })
        dlg.accepted.connect(function() {
            var map = {"Light blue":"#33aaff","Red":"#ff0000","Green":"#00aa00","Orange":"#ff8800","Black":"#000000","Magenta":"#cc00cc"};
            if (map[dlg.selected]) reader.annColor = map[dlg.selected];
        })
    }

    // hardware-keyboard navigation (BT keyboard): PageUp/Down + digits jump page, arrows page
    Keys.onPressed: {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) { reader.goToPage(currentPage+1); event.accepted=true; }
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) { reader.goToPage(currentPage-1); event.accepted=true; }
        else if (event.key === Qt.Key_Plus) { reader.zoom = Math.min(6, reader.zoom*1.25); event.accepted=true; }
        else if (event.key === Qt.Key_Minus) { reader.zoom = Math.max(0.5, reader.zoom/1.25); event.accepted=true; }
    }
    focus: true
}
