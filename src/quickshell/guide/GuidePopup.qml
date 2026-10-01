import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/buttons"

Item {
    id: root
    focus: true

    readonly property bool isGuidePopup: true

    property int activationCounter: 0
    property var appPaths: Caching
    property int currentTab: 0
    property int currentSubTab: 0
    property int expandedTab: -1

    property real colorBlend: 0.0
    property color ambientPurple: Qt.tint(ThemeBackend.mauve, Qt.rgba(ThemeBackend.pink.r, ThemeBackend.pink.g, ThemeBackend.pink.b, colorBlend))
    property color ambientBlue: Qt.tint(ThemeBackend.blue, Qt.rgba(ThemeBackend.sapphire.r, ThemeBackend.sapphire.g, ThemeBackend.sapphire.b, colorBlend))
    property int chargingSoundHandle: -1

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0
    property real introTabs: 0.0
    property var tutorialSections: []

    property bool searchActive: false
    property string searchQuery: ""
    property int searchSelectedIndex: -1
    property string highlightedSettingId: ""
    property int highlightToken: 0
    property var pendingHighlightItem: null

    property var searchIndexMap: ({})
    property var searchIndex: []

    function resolveI18nText(text) {
        if (!text) return "";
        let s = String(text).trim();
        if (s === "") return "";
        if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
            try {
                let res = I18n.t(s);
                if (res && res !== s) return res;
            } catch(e) {}
        }
        return s;
    }

    function resolveTabTitle(tabKey) {
        if (!tabKey) return "";
        let s = String(tabKey).trim();
        let cleanKey = s.replace(/^guide\.tabs\./, "").toLowerCase();
        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.key && t.key.toLowerCase() === cleanKey) ||
                (t.id && t.id.toLowerCase() === cleanKey) ||
                (t.name && t.name.toLowerCase() === cleanKey)) {
                return I18n.t("guide.tabs." + (t.key || t.id).toLowerCase(), t.name || t.id);
            }
        }
        return resolveI18nText(s);
    }

    function resolveSubtabTitle(tabKey, subtabKey) {
        if (!subtabKey) return "";
        let s = String(subtabKey).trim();
        let cleanSub = s.replace(/^guide\.tabs\./, "").toLowerCase();
        let cleanTab = String(tabKey || "").replace(/^guide\.tabs\./, "").toLowerCase();

        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if (cleanTab === "" || (t.key && t.key.toLowerCase() === cleanTab) ||
                (t.id && t.id.toLowerCase() === cleanTab) ||
                (t.name && t.name.toLowerCase() === cleanTab)) {
                if (t.subtabs && Array.isArray(t.subtabs)) {
                    let st = t.subtabs.find(x =>
                        (x.key && x.key.toLowerCase() === cleanSub) ||
                        (x.id && x.id.toLowerCase() === cleanSub) ||
                        (x.name && x.name.toLowerCase() === cleanSub)
                    );
                    if (st) {
                        return I18n.t("guide.tabs." + (st.key || st.id).toLowerCase(), st.name || st.id);
                    }
                }
            }
        }
        return resolveI18nText(s);
    }

    function getTabIcon(tabKey, subtabKey) {
        let cleanSub = String(subtabKey || "").replace(/^guide\.tabs\./, "").toLowerCase();
        let cleanTab = String(tabKey || "").replace(/^guide\.tabs\./, "").toLowerCase();

        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.key && t.key.toLowerCase() === cleanTab) ||
                (t.id && t.id.toLowerCase() === cleanTab) ||
                (t.name && t.name.toLowerCase() === cleanTab)) {
                if (cleanSub && t.subtabs && Array.isArray(t.subtabs)) {
                    let st = t.subtabs.find(x =>
                        (x.key && x.key.toLowerCase() === cleanSub) ||
                        (x.id && x.id.toLowerCase() === cleanSub) ||
                        (x.name && x.name.toLowerCase() === cleanSub)
                    );
                    if (st && st.icon) return st.icon;
                }
                return t.icon || "󰒓";
            }
        }
        return "󰒓";
    }

    function resolveIndices(tabKey, subKey) {
        if (!tabKey) return { tabIndex: -1, subIndex: -1 };
        let lower = String(tabKey).toLowerCase().replace(/^guide\.tabs\./, "");
        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.id && t.id.toLowerCase() === lower) ||
                (t.name && t.name.toLowerCase() === lower) ||
                (t.key && t.key.toLowerCase() === lower)) {
                let sIdx = -1;
                if (subKey !== undefined && subKey !== null && subKey !== "") {
                    let sLower = String(subKey).toLowerCase().replace(/^guide\.tabs\./, "");
                    let sNum = parseInt(subKey);
                    if (!isNaN(sNum) && t.subtabs && sNum >= 0 && sNum < t.subtabs.length) {
                        sIdx = sNum;
                    } else if (t.subtabs) {
                        sIdx = t.subtabs.findIndex(st =>
                            (st.id && st.id.toLowerCase() === sLower) ||
                            (st.name && st.name.toLowerCase() === sLower) ||
                            (st.key && st.key.toLowerCase() === sLower)
                        );
                    }
                }
                return { tabIndex: i, subIndex: sIdx };
            }

            if (t.subtabs && Array.isArray(t.subtabs)) {
                let sIdx = t.subtabs.findIndex(st =>
                    (st.id && st.id.toLowerCase() === lower) ||
                    (st.name && st.name.toLowerCase() === lower) ||
                    (st.key && st.key.toLowerCase() === lower)
                );
                if (sIdx !== -1) {
                    return { tabIndex: i, subIndex: sIdx };
                }
            }
        }
        return { tabIndex: -1, subIndex: -1 };
    }

    function resolveTargetLocation(target) {
        let tabIdx = -1;
        let subIdx = -1;
        if (!target) return { tabIndex: tabIdx, subIndex: subIdx };
        try {
            let p = target.parent;
            while (p) {
                if (subIdx === -1 && p.subTabIndex !== undefined && p.subTabIndex !== null && p.subTabIndex >= 0) {
                    subIdx = p.subTabIndex;
                }
                if (tabIdx === -1 && p.tabIndex !== undefined && p.tabIndex !== null && p.tabIndex >= 0) {
                    tabIdx = p.tabIndex;
                }
                p = p.parent;
            }
        } catch(e) {
            return { tabIndex: -1, subIndex: -1 };
        }
        if (tabIdx >= tabsModel.length) tabIdx = -1;
        return { tabIndex: tabIdx, subIndex: subIdx };
    }

    function registerSearchItem(entry) {
        if (!entry) return;
        let id = String(entry.id || entry.settingId || entry.title || "").trim();
        if (!id) return;
        let map = Object.assign({}, searchIndexMap);
        map[id] = {
            id: id,
            title: String(entry.title || "").trim(),
            desc: String(entry.desc || entry.description || "").trim(),
            description: String(entry.description || entry.desc || "").trim(),
            tab: String(entry.tab || entry.searchTab || "").trim(),
            subtab: String(entry.subtab || entry.searchSubTab || "").trim(),
            icon: String(entry.icon || "󰒓").trim(),
            keywords: entry.keywords || entry.searchKeywords || "",
            target: entry.target || null,
            onSelected: entry.onSelected || null
        };
        searchIndexMap = map;
        rebuildSearchIndex();
    }

    function registerSearchItems(items) {
        if (!Array.isArray(items)) return;
        let map = Object.assign({}, searchIndexMap);
        for (let i = 0; i < items.length; i++) {
            let entry = items[i];
            if (!entry) continue;
            let id = String(entry.id || entry.settingId || entry.title || "").trim();
            if (!id) continue;
            map[id] = {
                id: id,
                title: String(entry.title || "").trim(),
                desc: String(entry.desc || entry.description || "").trim(),
                description: String(entry.description || entry.desc || "").trim(),
                tab: String(entry.tab || entry.searchTab || "").trim(),
                subtab: String(entry.subtab || entry.searchSubTab || "").trim(),
                icon: String(entry.icon || "󰒓").trim(),
                keywords: entry.keywords || entry.searchKeywords || "",
                target: entry.target || null,
                onSelected: entry.onSelected || null
            };
        }
        searchIndexMap = map;
        rebuildSearchIndex();
    }

    function unregisterSearchItem(id) {
        if (!id) return;
        let key = String(id).trim();
        if (searchIndexMap[key]) {
            let map = Object.assign({}, searchIndexMap);
            delete map[key];
            searchIndexMap = map;
            rebuildSearchIndex();
        }
    }

    function rebuildSearchIndex() {
        let list = [];
        for (let k in searchIndexMap) {
            list.push(searchIndexMap[k]);
        }
        searchIndex = list;
    }

    function registerTabSearchItems(tabItem) {
        if (!tabItem) return;
        if (tabItem.searchItems && Array.isArray(tabItem.searchItems)) {
            registerSearchItems(tabItem.searchItems);
        }
        if (tabItem.searchEntries && Array.isArray(tabItem.searchEntries)) {
            registerSearchItems(tabItem.searchEntries);
        }
    }

    readonly property var filteredSearchResults: {
        let q = searchQuery.trim().toLowerCase();
        if (q === "") return [];
        return searchIndex.filter(item => {
            let rawT = (item.title || "").toLowerCase();
            let trT = resolveI18nText(item.title).toLowerCase();
            let rawD = (item.desc || item.description || "").toLowerCase();
            let trD = resolveI18nText(item.desc || item.description).toLowerCase();
            let tabT = resolveTabTitle(item.tab).toLowerCase();
            let subT = resolveSubtabTitle(item.tab, item.subtab).toLowerCase();
            let rawTb = (item.tab || "").toLowerCase();
            let rawStb = (item.subtab || "").toLowerCase();
            let kw = String(item.keywords || "").toLowerCase();

            return trT.indexOf(q) !== -1 || rawT.indexOf(q) !== -1 ||
                   trD.indexOf(q) !== -1 || rawD.indexOf(q) !== -1 ||
                   tabT.indexOf(q) !== -1 || subT.indexOf(q) !== -1 ||
                   rawTb.indexOf(q) !== -1 || rawStb.indexOf(q) !== -1 ||
                   kw.indexOf(q) !== -1;
        });
    }

    readonly property var groupedSearchResults: {
        let results = filteredSearchResults;
        if (results.length === 0) return [];

        let tabGroupsMap = {};

        for (let i = 0; i < results.length; i++) {
            let item = results[i];
            let tKey = String(item.tab || "").trim();
            let sKey = String(item.subtab || "").trim();
            let indices = resolveIndices(tKey, sKey);
            let tIdx = indices.tabIndex !== -1 ? indices.tabIndex : 9999;
            let sIdx = indices.subIndex;

            if (!tabGroupsMap[tIdx]) {
                let isKnown = tIdx >= 0 && tIdx < tabsModel.length;
                let tModel = isKnown ? tabsModel[tIdx] : null;
                tabGroupsMap[tIdx] = {
                    tabKey: isKnown ? (tModel.key || tModel.id) : tKey,
                    tabIndex: tIdx,
                    title: isKnown ? resolveTabTitle(tModel.key || tModel.id) : I18n.t("guide.tabs.general", "General"),
                    icon: isKnown ? (tModel.icon || "󰒓") : "󰒓",
                    iconOffsetX: isKnown ? (tModel.iconOffsetX ?? 0) : 0,
                    directItems: [],
                    subgroupsMap: {}
                };
            }

            let tg = tabGroupsMap[tIdx];
            let isKnown = tIdx >= 0 && tIdx < tabsModel.length;
            let tModel = isKnown ? tabsModel[tIdx] : null;

            if (sIdx >= 0 && isKnown && tModel && tModel.subtabs && sIdx < tModel.subtabs.length) {
                let stModel = tModel.subtabs[sIdx];
                if (!tg.subgroupsMap[sIdx]) {
                    tg.subgroupsMap[sIdx] = {
                        subKey: stModel.key || stModel.id,
                        subIndex: sIdx,
                        title: resolveSubtabTitle(tModel.key || tModel.id, stModel.key || stModel.id),
                        icon: stModel.icon || "󰒓",
                        iconOffsetX: stModel.iconOffsetX ?? 0,
                        items: []
                    };
                }
                tg.subgroupsMap[sIdx].items.push(item);
            } else {
                tg.directItems.push(item);
            }
        }

        let sortedGroups = Object.values(tabGroupsMap).map(tg => {
            let subList = Object.values(tg.subgroupsMap);
            subList.sort((a, b) => a.subIndex - b.subIndex);
            return {
                tabKey: tg.tabKey,
                tabIndex: tg.tabIndex,
                title: tg.title,
                icon: tg.icon,
                iconOffsetX: tg.iconOffsetX,
                directItems: tg.directItems,
                subgroups: subList
            };
        });

        sortedGroups.sort((a, b) => a.tabIndex - b.tabIndex);
        return sortedGroups;
    }

    readonly property var flatSearchResults: {
        let groups = groupedSearchResults;
        if (!groups || groups.length === 0) return [];
        let list = [];
        for (let i = 0; i < groups.length; i++) {
            let tg = groups[i];
            if (tg.directItems && tg.directItems.length > 0) {
                for (let d = 0; d < tg.directItems.length; d++) {
                    list.push(tg.directItems[d]);
                }
            }
            if (tg.subgroups && tg.subgroups.length > 0) {
                for (let s = 0; s < tg.subgroups.length; s++) {
                    let sg = tg.subgroups[s];
                    if (sg.items && sg.items.length > 0) {
                        for (let k = 0; k < sg.items.length; k++) {
                            list.push(sg.items[k]);
                        }
                    }
                }
            }
        }
        return list;
    }

    function navigateSearch(dir) {
        let count = flatSearchResults.length;
        if (count === 0) return;
        if (searchSelectedIndex === -1) {
            searchSelectedIndex = dir > 0 ? 0 : count - 1;
        } else {
            searchSelectedIndex = (searchSelectedIndex + dir + count) % count;
        }
    }

    function activateSelectedSearch() {
        let count = flatSearchResults.length;
        if (count === 0) return;
        let item = (searchSelectedIndex >= 0 && searchSelectedIndex < count)
            ? flatSearchResults[searchSelectedIndex]
            : flatSearchResults[0];
        if (item) {
            selectSearchResult(item);
        }
    }

    function ensureSearchItemVisible(itemObj) {
        if (!itemObj || !searchResultsFlickable) return;
        try {
            let mapped = itemObj.mapToItem(searchResultsCol, 0, 0);
            let itemY = mapped.y;
            let itemH = itemObj.height;
            let viewTop = searchResultsFlickable.contentY;
            let viewHeight = searchResultsFlickable.height;
            let viewBottom = viewTop + viewHeight;

            if (itemY < viewTop) {
                searchResultsFlickable.contentY = Math.max(0, itemY - root.s(8));
            } else if (itemY + itemH > viewBottom) {
                let maxScroll = Math.max(0, searchResultsFlickable.contentHeight - viewHeight);
                searchResultsFlickable.contentY = Math.min(maxScroll, itemY + itemH - viewHeight + root.s(8));
            }
        } catch(e) {}
    }

    function triggerHighlight(settingId) {
        highlightedSettingId = settingId;
        highlightToken++;
    }

    function openSearch() {
        searchClearTimer.stop();
        searchActive = true;
        searchSelectedIndex = -1;
        searchFocusTimer.restart();
    }

    function closeSearch() {
        if (!searchActive) return;
        searchActive = false;
        searchSelectedIndex = -1;
        root.forceActiveFocus();
        searchClearTimer.restart();
    }

    function selectSearchResult(item) {
        if (!item) return;

        let loc = resolveTargetLocation(item.target);
        if (loc.tabIndex >= 0) {
            gotoTab(String(loc.tabIndex), loc.subIndex >= 0 ? String(loc.subIndex) : "");
        } else {
            gotoTab(item.tab, item.subtab);
        }

        pendingHighlightItem = item;
        highlightTimer.restart();

        if (typeof item.onSelected === "function") {
            try { item.onSelected(); } catch(e) {}
        }
        closeSearch();
    }

    function runPendingHighlight() {
        let item = pendingHighlightItem;
        pendingHighlightItem = null;
        if (!item) return;

        let handled = false;
        if (item.target) {
            try {
                if (typeof item.target.triggerHighlightAnimation === "function") {
                    item.target.triggerHighlightAnimation();
                    handled = true;
                }
            } catch(e) {
                handled = false;
            }
        }
        if (!handled) {
            triggerHighlight(item.id);
        }
    }

    property var tabsModel: [
        { id: "Welcome", key: "welcome", name: "Welcome", icon: "󰋜", file: "WelcomeTab.qml", iconOffsetX: -1 },
        { id: "General", key: "general", name: "General", icon: "󰒓", file: "general/GeneralTab.qml", iconOffsetX: -1 },
        {
            id: "Display",
            key: "display",
            name: "Display",
            icon: "󰃠",
            file: "display/DisplayMainTab.qml",
            iconOffsetX: -2,
            subtabs: [
                { id: "DisplayGeneral", key: "display_general", name: "Display", icon: "󰃠", file: "display/DisplayMainTab.qml", iconOffsetX: -2 },
                { id: "DisplayWidgets", key: "display_widgets", name: "Widgets", icon: "󰕰", file: "display/DisplayWidgetsTab.qml", iconOffsetX: 0 }
            ]
        },
        { id: "Theme", key: "theme", name: "Theme", icon: "✦", file: "theme/ThemeTab.qml", iconOffsetX: 0 },
        {
            id: "Bar",
            key: "bar",
            name: "Bar",
            icon: "󰹑",
            file: "bar/BarGeneralTab.qml",
            iconOffsetX: -2,
            subtabs: [
                { id: "BarGeneral", key: "bar_general", name: "General", icon: "󰒓", file: "bar/BarGeneralTab.qml", iconOffsetX: -1 },
                { id: "BarModules", key: "bar_modules", name: "Modules", icon: "󰮯", file: "bar/BarModulesTab.qml", iconOffsetX: -1 }
            ]
        },
        { id: "Launcher", key: "launcher", name: "Launcher", icon: "󰵆", file: "LauncherTab.qml", iconOffsetX: 0 },
        { id: "Dock", key: "dock", name: "Dock", icon: "󰮯", file: "DockTab.qml", iconOffsetX: 0 },
        { id: "On-Screen Display", key: "osd", name: "On-Screen Display", icon: "󰕾", file: "OnScreenDisplayTab.qml", iconOffsetX: 0 },
        { id: "Notifications", key: "notifications", name: "Notifications", icon: "󰂚", file: "notifications/NotificationsTab.qml", iconOffsetX: 0 },
        { id: "Wellbeing", key: "wellbeing", name: "Wellbeing", icon: "󰄉", file: "wellbeing/DigitalWellbeingTab.qml", iconOffsetX: 0 },
        { id: "Idle", key: "idle", name: "Idle", icon: "󰒲", file: "IdleTab.qml", iconOffsetX: -2 },
        { id: "About", key: "about", name: "About", icon: "", file: "AboutTab.qml", iconOffsetX: 0 }
    ]

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Active) {
            activationCounter++;
        }
    }

    function closePopup() {
        closeSearch();
        closeSequence.start();
    }

    function s(val) {
        return Scaler.s(val);
    }

    function getTabProgress(idx) {
        if (introTabs >= 1.0) return 1.0;
        if (introTabs <= 0.0) return 0.0;
        let start = idx * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introTabs - start) / 0.42));
        if (p <= 0.0) return 0.0;
        if (p >= 1.0) return 1.0;
        let c1 = 0.85;
        let c3 = c1 + 1;
        return 1 + c3 * Math.pow(p - 1, 3) + c1 * Math.pow(p - 1, 2);
    }

    function getTabOpacity(idx) {
        if (introTabs >= 1.0) return 1.0;
        if (introTabs <= 0.0) return 0.0;
        let start = idx * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introTabs - start) / 0.28));
        return p;
    }

    function gotoTab(tabName, subTabName) {
        if (tabName === undefined || tabName === null || tabName === "") return;
        let num = parseInt(tabName);
        if (!isNaN(num) && num >= 0 && num < tabsModel.length) {
            currentTab = num;
            expandedTab = (tabsModel[num].subtabs && tabsModel[num].subtabs.length > 0) ? num : -1;
            if (subTabName !== undefined && subTabName !== null && subTabName !== "") {
                let sNum = parseInt(subTabName);
                currentSubTab = !isNaN(sNum) ? sNum : 0;
            } else {
                currentSubTab = 0;
            }
            return;
        }
        let lower = String(tabName).toLowerCase().replace(/^guide\.tabs\./, "");
        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.id && t.id.toLowerCase() === lower) ||
                (t.name && t.name.toLowerCase() === lower) ||
                (t.key && t.key.toLowerCase() === lower)) {
                currentTab = i;
                expandedTab = (t.subtabs && t.subtabs.length > 0) ? i : -1;
                if (subTabName !== undefined && subTabName !== null && subTabName !== "") {
                    let sLower = String(subTabName).toLowerCase().replace(/^guide\.tabs\./, "");
                    let sNum = parseInt(subTabName);
                    if (!isNaN(sNum) && t.subtabs && sNum >= 0 && sNum < t.subtabs.length) {
                        currentSubTab = sNum;
                    } else if (t.subtabs) {
                        let sIdx = t.subtabs.findIndex(st =>
                            (st.id && st.id.toLowerCase() === sLower) ||
                            (st.name && st.name.toLowerCase() === sLower) ||
                            (st.key && st.key.toLowerCase() === sLower)
                        );
                        currentSubTab = sIdx !== -1 ? sIdx : 0;
                    } else {
                        currentSubTab = 0;
                    }
                } else {
                    currentSubTab = 0;
                }
                return;
            }

            if (t.subtabs && Array.isArray(t.subtabs)) {
                let sIdx = t.subtabs.findIndex(st =>
                    (st.id && st.id.toLowerCase() === lower) ||
                    (st.name && st.name.toLowerCase() === lower) ||
                    (st.key && st.key.toLowerCase() === lower)
                );
                if (sIdx !== -1) {
                    currentTab = i;
                    expandedTab = i;
                    currentSubTab = sIdx;
                    return;
                }
            }
        }
    }

    function resetAndPlayIntro() {
        introBase = 0.0;
        introSidebar = 0.0;
        introContent = 0.0;
        introTabs = 0.0;
        startupSequence.restart();
        Updater.checkUpdate();
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    Timer {
        id: searchFocusTimer
        interval: 40
        repeat: false
        onTriggered: {
            if (settingsSearchInput) {
                settingsSearchInput.forceActiveFocus();
            }
        }
    }

    Timer {
        id: highlightTimer
        interval: 160
        repeat: false
        onTriggered: root.runPendingHighlight()
    }

    Timer {
        id: searchClearTimer
        interval: 260
        repeat: false
        onTriggered: {
            searchQuery = "";
            if (settingsSearchInput) settingsSearchInput.text = "";
        }
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        } else {
            startupSequence.stop();
            closeSequence.stop();
            highlightTimer.stop();
            searchClearTimer.stop();
            pendingHighlightItem = null;
            introBase = 0.0;
            introSidebar = 0.0;
            introContent = 0.0;
            introTabs = 0.0;
            searchActive = false;
            searchQuery = "";
            searchSelectedIndex = -1;
            if (settingsSearchInput) settingsSearchInput.text = "";
            if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                Sounds.stopSfx(root.chargingSoundHandle);
                root.chargingSoundHandle = -1;
            }
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        }
    }

    function nextTab() {
        let parentTab = tabsModel[currentTab];
        if (parentTab && parentTab.subtabs && parentTab.subtabs.length > 0 && expandedTab === currentTab) {
            if (currentSubTab < parentTab.subtabs.length - 1) {
                currentSubTab++;
                return;
            }
        }
        currentTab = (currentTab + 1) % tabsModel.length;
        let nextParent = tabsModel[currentTab];
        if (nextParent && nextParent.subtabs && nextParent.subtabs.length > 0) {
            expandedTab = currentTab;
            currentSubTab = 0;
        } else {
            expandedTab = -1;
            currentSubTab = 0;
        }
    }

    function prevTab() {
        let parentTab = tabsModel[currentTab];
        if (parentTab && parentTab.subtabs && parentTab.subtabs.length > 0 && expandedTab === currentTab) {
            if (currentSubTab > 0) {
                currentSubTab--;
                return;
            }
        }
        currentTab = (currentTab - 1 + tabsModel.length) % tabsModel.length;
        let prevParent = tabsModel[currentTab];
        if (prevParent && prevParent.subtabs && prevParent.subtabs.length > 0) {
            expandedTab = currentTab;
            currentSubTab = prevParent.subtabs.length - 1;
        } else {
            expandedTab = -1;
            currentSubTab = 0;
        }
    }

    Shortcut {
        sequence: StandardKey.Find
        onActivated: root.openSearch()
    }

    Keys.onEscapePressed: (event) => {
        if (root.searchActive) {
            root.closeSearch();
            event.accepted = true;
            return;
        }
        closeSequence.start();
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(1);
            event.accepted = true;
        }
    }
    Keys.onUpPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(-1);
            event.accepted = true;
        }
    }
    Keys.onReturnPressed: (event) => {
        if (root.searchActive) {
            root.activateSelectedSearch();
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: (event) => {
        if (root.searchActive) {
            root.activateSelectedSearch();
            event.accepted = true;
        }
    }
    Keys.onTabPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(1);
            event.accepted = true;
            return;
        }
        nextTab();
        event.accepted = true;
    }
    Keys.onBacktabPressed: (event) => {
        if (root.searchActive) {
            root.navigateSearch(-1);
            event.accepted = true;
            return;
        }
        prevTab();
        event.accepted = true;
    }

    SequentialAnimation on colorBlend {
        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }

    function saveLastTab() {
        Quickshell.execDetached(["bash", "-c", "echo '" + currentTab + ":" + currentSubTab + "' > '" + Caching.getCacheDir("guide") + "/last_tab.txt'"]);
    }

    onCurrentTabChanged: saveLastTab()
    onCurrentSubTabChanged: saveLastTab()

    FileView {
        id: lastTabWatcher
        path: Caching.getCacheDir("guide") + "/last_tab.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let val = text().trim();
                if (val !== "") {
                    if (val.indexOf(":") !== -1) {
                        let parts = val.split(":");
                        root.gotoTab(parts[0], parts[1]);
                    } else {
                        root.gotoTab(val);
                    }
                }
            } catch(e) {}
        }
    }

    FileView {
        id: tutorialWatcher
        path: Caching.serpantinumDir ? (Caching.serpantinumDir + "/assets/tutorial.json") : ""
        onLoaded: {
            try {
                let data = JSON.parse(text().trim());
                if (Array.isArray(data)) {
                    root.tutorialSections = data;
                }
            } catch(e) {}
        }
    }

    ParallelAnimation {
        id: startupSequence
        running: false
        NumberAnimation {
            target: root
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: 650
            easing.type: Easing.OutExpo
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation {
                target: root
                property: "introSidebar"
                from: 0.0
                to: 1.0
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation {
                target: root
                property: "introTabs"
                from: 0.0
                to: 1.0
                duration: 550
                easing.type: Easing.Linear
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation {
                target: root
                property: "introContent"
                from: 0.0
                to: 1.0
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: closeSequence
        ScriptAction {
            script: {
                root.closeSearch();
                if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                    Sounds.stopSfx(root.chargingSoundHandle);
                    root.chargingSoundHandle = -1;
                }
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "introContent"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo
            }
            NumberAnimation {
                target: root
                property: "introSidebar"
                to: 0.0
                duration: 150
                easing.type: Easing.InExpo
            }
            NumberAnimation {
                target: root
                property: "introTabs"
                to: 0.0
                duration: 120
                easing.type: Easing.InQuad
            }
        }
        NumberAnimation {
            target: root
            property: "introBase"
            to: 0.0
            duration: 200
            easing.type: Easing.InQuart
        }
        ScriptAction {
            script: Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "close"])
        }
    }

    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.base

            property real time: 0
            NumberAnimation on time {
                from: 0
                to: Math.PI * 2
                duration: 20000
                loops: Animation.Infinite
                running: root.visible
            }

            Rectangle {
                id: sidebar
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.searchActive ? root.s(340) : root.s(260)

                topLeftRadius: ThemeBackend.clampedBorderRadius
                bottomLeftRadius: ThemeBackend.clampedBorderRadius
                topRightRadius: 0
                bottomRightRadius: 0

                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                opacity: introSidebar
                transform: Translate { x: root.s(-30) * (1.0 - introSidebar) }

                Behavior on width {
                    NumberAnimation {
                        id: sidebarWidthAnim
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(15)
                    spacing: root.s(10)

                    Item {
                        id: searchHeader
                        Layout.fillWidth: true
                        implicitHeight: root.s(36)
                        Layout.preferredHeight: root.s(36)

                        Text {
                            id: settingsTitleText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("guide.settings", "Settings")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(15)
                            font.bold: true
                            color: ThemeBackend.text
                            opacity: root.searchActive ? 0.0 : 1.0
                            scale: root.searchActive ? 0.92 : 1.0
                            visible: opacity > 0.001

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Item {
                            id: searchMorphBox
                            property real openProgress: root.searchActive ? 1.0 : 0.0
                            Behavior on openProgress { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.s(36) + (parent.width - root.s(36)) * openProgress
                            height: root.s(36)
                            clip: true

                            Input {
                                id: settingsSearchInput
                                anchors.fill: parent
                                implicitHeight: root.s(36)
                                placeholderText: I18n.t("guide.search.placeholder", "Search settings...")
                                fontPixelSize: root.s(12)
                                baseColor: Qt.alpha(ThemeBackend.surface0, 0.7)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.text
                                subTextColor: ThemeBackend.subtext0
                                borderColor: Qt.alpha(ThemeBackend.surface2, 0.5)
                                cornerRadius: ThemeBackend.borderRadius
                                opacity: root.searchActive ? 1.0 : 0.0
                                visible: opacity > 0.001
                                enabled: root.searchActive

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                onTextEdited: (txt) => {
                                    root.searchQuery = txt;
                                    root.searchSelectedIndex = -1;
                                }

                                Keys.onEscapePressed: (event) => {
                                    root.closeSearch();
                                    event.accepted = true;
                                }
                                Keys.onDownPressed: (event) => {
                                    root.navigateSearch(1);
                                    event.accepted = true;
                                }
                                Keys.onUpPressed: (event) => {
                                    root.navigateSearch(-1);
                                    event.accepted = true;
                                }
                                Keys.onReturnPressed: (event) => {
                                    root.activateSelectedSearch();
                                    event.accepted = true;
                                }
                                Keys.onEnterPressed: (event) => {
                                    root.activateSelectedSearch();
                                    event.accepted = true;
                                }
                            }

                            IconButton {
                                id: closeSearchBtn
                                anchors.right: parent.right
                                anchors.rightMargin: root.s(4)
                                anchors.verticalCenter: parent.verticalCenter
                                size: root.s(28)
                                cornerRadius: root.s(6)
                                buttonIcon: "󰅖"
                                iconFontSize: root.s(14)
                                accentColor: "transparent"
                                textColor: ThemeBackend.subtext0
                                visible: opacity > 0.001
                                opacity: root.searchActive ? 1.0 : 0.0
                                enabled: root.searchActive
                                z: 3

                                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                onClicked: root.closeSearch()
                            }

                            IconButton {
                                id: searchBtn
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: root.s(36)
                                size: root.s(36)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰍉"
                                iconFontSize: root.s(16)
                                accentColor: Qt.alpha(ThemeBackend.surface0, 0.7)
                                textColor: ThemeBackend.text
                                visible: opacity > 0.001
                                opacity: root.searchActive ? 0.0 : 1.0
                                enabled: !root.searchActive

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                onClicked: {
                                    root.openSearch();
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: searchResultsFlickable
                            anchors.fill: parent
                            visible: opacity > 0.001
                            opacity: root.searchActive ? 1.0 : 0.0
                            contentHeight: searchResultsCol.implicitHeight + root.s(10)
                            contentWidth: width
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            ScrollBar.vertical: ScrollBar {
                                active: searchResultsFlickable.moving || searchResultsFlickable.movingVertically
                                width: root.s(4)
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: root.s(4)
                                    radius: root.s(2)
                                    color: ThemeBackend.surface2
                                }
                            }

                            ColumnLayout {
                                id: searchResultsCol
                                width: parent.width
                                spacing: root.s(8)

                                Text {
                                    visible: root.searchActive && root.searchQuery.trim() === ""
                                    Layout.fillWidth: true
                                    Layout.topMargin: root.s(24)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: I18n.t("guide.search.prompt", "Type to search settings...")
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.subtext0
                                }

                                Text {
                                    visible: root.searchActive && root.searchQuery.trim() !== "" && root.filteredSearchResults.length === 0
                                    Layout.fillWidth: true
                                    Layout.topMargin: root.s(24)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: I18n.t("guide.search.no_results", "No settings found")
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.subtext0
                                }

                                Repeater {
                                    id: searchTabsRepeater
                                    model: root.groupedSearchResults
                                    delegate: ColumnLayout {
                                        id: tabGroup
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: root.s(4)

                                        Rectangle {
                                            id: tabHeaderItem
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: root.s(44)
                                            implicitHeight: root.s(44)
                                            radius: ThemeBackend.borderRadius
                                            z: 1

                                            color: tabHeaderItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            scale: tabHeaderItemMa.pressed ? 0.98 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: root.s(10)
                                                anchors.rightMargin: root.s(14)
                                                spacing: root.s(10)

                                                IconButton {
                                                    enabled: false
                                                    size: root.s(32)
                                                    Layout.preferredWidth: root.s(32)
                                                    Layout.preferredHeight: root.s(32)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    cornerRadius: ThemeBackend.borderRadius
                                                    buttonIcon: tabGroup.modelData.icon || "󰒓"
                                                    iconOffsetX: tabGroup.modelData.iconOffsetX ?? 0
                                                    iconFontSize: root.s(16)
                                                    accentColor: ThemeBackend.surface0
                                                    textColor: "#ffffff"
                                                }

                                                Text {
                                                    text: tabGroup.modelData.title
                                                    font.family: ThemeBackend.fontFamily
                                                    font.weight: Font.Medium
                                                    font.pixelSize: root.s(13)
                                                    color: tabHeaderItemMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                                    Layout.fillWidth: true
                                                    Layout.alignment: Qt.AlignVCenter
                                                    elide: Text.ElideRight
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                            }

                                            MouseArea {
                                                id: tabHeaderItemMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.gotoTab(tabGroup.modelData.tabKey);
                                                    root.closeSearch();
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: tabIndentRow
                                            visible: (tabGroup.modelData.directItems.length + tabGroup.modelData.subgroups.length) > 0
                                            Layout.fillWidth: true
                                            spacing: root.s(6)

                                            Item {
                                                Layout.preferredWidth: root.s(20)
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    anchors.topMargin: root.s(2)
                                                    anchors.bottomMargin: root.s(2)
                                                    width: Math.max(1, root.s(2))
                                                    radius: root.s(1)
                                                    color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: root.s(4)

                                                Repeater {
                                                    id: directItemsRepeater
                                                    model: tabGroup.modelData.directItems
                                                    delegate: Rectangle {
                                                        id: directItemRow
                                                        required property var modelData
                                                        required property int index

                                                        property bool isSelected: root.searchSelectedIndex >= 0 &&
                                                                                  root.searchSelectedIndex < root.flatSearchResults.length &&
                                                                                  (root.flatSearchResults[root.searchSelectedIndex] === directItemRow.modelData ||
                                                                                   (root.flatSearchResults[root.searchSelectedIndex] && root.flatSearchResults[root.searchSelectedIndex].id === directItemRow.modelData.id))

                                                        onIsSelectedChanged: {
                                                            if (isSelected) {
                                                                root.ensureSearchItemVisible(directItemRow);
                                                            }
                                                        }

                                                        Layout.fillWidth: true
                                                        implicitHeight: (directItemRow.modelData && (directItemRow.modelData.desc || directItemRow.modelData.description)) ? root.s(48) : root.s(38)
                                                        radius: ThemeBackend.borderRadius
                                                        color: directItemRow.isSelected
                                                            ? ThemeBackend.mauve
                                                            : (directItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35))
                                                        border.color: "transparent"

                                                        Behavior on color { ColorAnimation { duration: 150 } }

                                                        MouseArea {
                                                            id: directItemMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.selectSearchResult(directItemRow.modelData)
                                                        }

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: root.s(8) + (directItemRow.isSelected ? root.s(4) : 0)
                                                            anchors.rightMargin: root.s(8)
                                                            anchors.topMargin: root.s(6)
                                                            anchors.bottomMargin: root.s(6)
                                                            spacing: root.s(8)

                                                            Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                            IconButton {
                                                                enabled: false
                                                                size: root.s(28)
                                                                Layout.preferredWidth: root.s(28)
                                                                Layout.preferredHeight: root.s(28)
                                                                Layout.alignment: Qt.AlignVCenter
                                                                cornerRadius: root.s(6)
                                                                buttonIcon: directItemRow.modelData.icon || "󰒓"
                                                                iconFontSize: root.s(14)
                                                                accentColor: directItemRow.isSelected ? Qt.alpha(ThemeBackend.crust, 0.15) : ThemeBackend.surface1
                                                                textColor: directItemRow.isSelected ? ThemeBackend.crust : ThemeBackend.mauve

                                                                Behavior on accentColor { ColorAnimation { duration: 150 } }
                                                                Behavior on textColor { ColorAnimation { duration: 150 } }
                                                            }

                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                Layout.alignment: Qt.AlignVCenter
                                                                spacing: 0

                                                                Text {
                                                                    Layout.fillWidth: true
                                                                    text: root.resolveI18nText(directItemRow.modelData.title)
                                                                    font.family: ThemeBackend.fontFamily
                                                                    font.pixelSize: root.s(12)
                                                                    font.bold: true
                                                                    color: directItemRow.isSelected ? ThemeBackend.crust : ThemeBackend.text
                                                                    elide: Text.ElideRight

                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                }

                                                                Text {
                                                                    Layout.fillWidth: true
                                                                    text: root.resolveI18nText(directItemRow.modelData.desc || directItemRow.modelData.description || "")
                                                                    visible: text !== ""
                                                                    font.family: ThemeBackend.fontFamily
                                                                    font.pixelSize: root.s(10)
                                                                    color: directItemRow.isSelected ? Qt.alpha(ThemeBackend.crust, 0.75) : ThemeBackend.subtext0
                                                                    elide: Text.ElideRight

                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                Repeater {
                                                    id: subGroupRepeater
                                                    model: tabGroup.modelData.subgroups
                                                    delegate: ColumnLayout {
                                                        id: subGroup
                                                        required property var modelData
                                                        required property int index

                                                        Layout.fillWidth: true
                                                        spacing: root.s(4)

                                                        Rectangle {
                                                            id: subtabHeaderItem
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: root.s(36)
                                                            implicitHeight: root.s(36)
                                                            radius: ThemeBackend.borderRadius
                                                            z: 1

                                                            color: subtabHeaderItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                                            Behavior on color { ColorAnimation { duration: 150 } }

                                                            scale: subtabHeaderItemMa.pressed ? 0.98 : 1.0
                                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                            RowLayout {
                                                                anchors.fill: parent
                                                                anchors.leftMargin: root.s(8)
                                                                anchors.rightMargin: root.s(10)
                                                                spacing: root.s(8)

                                                                IconButton {
                                                                    enabled: false
                                                                    size: root.s(26)
                                                                    Layout.preferredWidth: root.s(26)
                                                                    Layout.preferredHeight: root.s(26)
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    cornerRadius: ThemeBackend.borderRadius
                                                                    buttonIcon: subGroup.modelData.icon || "󰒓"
                                                                    iconOffsetX: subGroup.modelData.iconOffsetX ?? 0
                                                                    iconFontSize: root.s(13)
                                                                    accentColor: ThemeBackend.surface0
                                                                    textColor: "#ffffff"
                                                                }

                                                                Text {
                                                                    text: subGroup.modelData.title
                                                                    font.family: ThemeBackend.fontFamily
                                                                    font.weight: Font.Medium
                                                                    font.pixelSize: root.s(12)
                                                                    color: subtabHeaderItemMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                                                    Layout.fillWidth: true
                                                                    Layout.alignment: Qt.AlignVCenter
                                                                    elide: Text.ElideRight
                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: subtabHeaderItemMa
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    root.gotoTab(tabGroup.modelData.tabKey, subGroup.modelData.subKey);
                                                                    root.closeSearch();
                                                                }
                                                            }
                                                        }

                                                        RowLayout {
                                                            id: subIndentRow
                                                            visible: subGroup.modelData.items.length > 0
                                                            Layout.fillWidth: true
                                                            spacing: root.s(6)

                                                            Item {
                                                                Layout.preferredWidth: root.s(20)
                                                                Layout.fillHeight: true

                                                                Rectangle {
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    anchors.top: parent.top
                                                                    anchors.bottom: parent.bottom
                                                                    anchors.topMargin: root.s(2)
                                                                    anchors.bottomMargin: root.s(2)
                                                                    width: Math.max(1, root.s(2))
                                                                    radius: root.s(1)
                                                                    color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                                                }
                                                            }

                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: root.s(4)

                                                                Repeater {
                                                                    id: subGroupItemsRepeater
                                                                    model: subGroup.modelData.items
                                                                    delegate: Rectangle {
                                                                        id: subItemRow
                                                                        required property var modelData
                                                                        required property int index

                                                                        property bool isSelected: root.searchSelectedIndex >= 0 &&
                                                                                                  root.searchSelectedIndex < root.flatSearchResults.length &&
                                                                                                  (root.flatSearchResults[root.searchSelectedIndex] === subItemRow.modelData ||
                                                                                                   (root.flatSearchResults[root.searchSelectedIndex] && root.flatSearchResults[root.searchSelectedIndex].id === subItemRow.modelData.id))

                                                                        onIsSelectedChanged: {
                                                                            if (isSelected) {
                                                                                root.ensureSearchItemVisible(subItemRow);
                                                                            }
                                                                        }

                                                                        Layout.fillWidth: true
                                                                        implicitHeight: (subItemRow.modelData && (subItemRow.modelData.desc || subItemRow.modelData.description)) ? root.s(48) : root.s(38)
                                                                        radius: ThemeBackend.borderRadius
                                                                        color: subItemRow.isSelected
                                                                            ? ThemeBackend.mauve
                                                                            : (subItemMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.6) : Qt.alpha(ThemeBackend.surface0, 0.35))
                                                                        border.color: "transparent"

                                                                        Behavior on color { ColorAnimation { duration: 150 } }

                                                                        MouseArea {
                                                                            id: subItemMa
                                                                            anchors.fill: parent
                                                                            hoverEnabled: true
                                                                            cursorShape: Qt.PointingHandCursor
                                                                            onClicked: root.selectSearchResult(subItemRow.modelData)
                                                                        }

                                                                        RowLayout {
                                                                            anchors.fill: parent
                                                                            anchors.leftMargin: root.s(8) + (subItemRow.isSelected ? root.s(4) : 0)
                                                                            anchors.rightMargin: root.s(8)
                                                                            anchors.topMargin: root.s(6)
                                                                            anchors.bottomMargin: root.s(6)
                                                                            spacing: root.s(8)

                                                                            Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                                            IconButton {
                                                                                enabled: false
                                                                                size: root.s(28)
                                                                                Layout.preferredWidth: root.s(28)
                                                                                Layout.preferredHeight: root.s(28)
                                                                                Layout.alignment: Qt.AlignVCenter
                                                                                cornerRadius: root.s(6)
                                                                                buttonIcon: subItemRow.modelData.icon || "󰒓"
                                                                                iconFontSize: root.s(14)
                                                                                accentColor: subItemRow.isSelected ? Qt.alpha(ThemeBackend.crust, 0.15) : ThemeBackend.surface1
                                                                                textColor: subItemRow.isSelected ? ThemeBackend.crust : ThemeBackend.mauve

                                                                                Behavior on accentColor { ColorAnimation { duration: 150 } }
                                                                                Behavior on textColor { ColorAnimation { duration: 150 } }
                                                                            }

                                                                            ColumnLayout {
                                                                                Layout.fillWidth: true
                                                                                Layout.alignment: Qt.AlignVCenter
                                                                                spacing: 0

                                                                                Text {
                                                                                    Layout.fillWidth: true
                                                                                    text: root.resolveI18nText(subItemRow.modelData.title)
                                                                                    font.family: ThemeBackend.fontFamily
                                                                                    font.pixelSize: root.s(12)
                                                                                    font.bold: true
                                                                                    color: subItemRow.isSelected ? ThemeBackend.crust : ThemeBackend.text
                                                                                    elide: Text.ElideRight

                                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                                }

                                                                                Text {
                                                                                    Layout.fillWidth: true
                                                                                    text: root.resolveI18nText(subItemRow.modelData.desc || subItemRow.modelData.description || "")
                                                                                    visible: text !== ""
                                                                                    font.family: ThemeBackend.fontFamily
                                                                                    font.pixelSize: root.s(10)
                                                                                    color: subItemRow.isSelected ? Qt.alpha(ThemeBackend.crust, 0.75) : ThemeBackend.subtext0
                                                                                    elide: Text.ElideRight

                                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Flickable {
                            id: tabsFlickable
                            anchors.fill: parent
                            visible: opacity > 0.001
                            opacity: root.searchActive ? 0.0 : 1.0
                            contentHeight: tabsCol.implicitHeight + root.s(20)
                            contentWidth: width
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            ScrollBar.vertical: ScrollBar {
                                active: tabsFlickable.moving || tabsFlickable.movingVertically
                                width: root.s(4)
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: root.s(4)
                                    radius: root.s(2)
                                    color: ThemeBackend.surface2
                                }
                            }

                            Rectangle {
                                id: activeHighlight
                                z: 0
                                visible: !root.searchActive || opacity > 0.001
                                radius: ThemeBackend.borderRadius
                                color: ThemeBackend.mauve

                                property Item activeGroupItem: (root.currentTab >= 0 && root.currentTab < tabsCol.tabItems.length) ? tabsCol.tabItems[root.currentTab] : null
                                property bool isSubActive: root.currentTab === root.expandedTab && root.expandedTab !== -1

                                property real targetX: isSubActive ? root.s(26) : 0
                                property real targetY: {
                                    let baseY = activeGroupItem ? activeGroupItem.y : (root.currentTab * (root.s(44) + root.s(4)));
                                    if (isSubActive) {
                                        return baseY + root.s(44) + root.s(4) + root.currentSubTab * (root.s(36) + root.s(4));
                                    }
                                    return baseY;
                                }
                                property real targetW: isSubActive ? (tabsCol.width - root.s(26)) : tabsCol.width
                                property real targetH: isSubActive ? root.s(36) : root.s(44)

                                x: targetX
                                y: targetY
                                width: targetW
                                height: targetH

                                opacity: root.getTabOpacity(root.currentTab)
                                transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(root.currentTab)) }

                                Behavior on x { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on y { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on width { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                Behavior on height { enabled: !sidebarWidthAnim.running; NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                            }

                            ColumnLayout {
                                id: tabsCol
                                width: tabsFlickable.width - (tabsFlickable.contentHeight > tabsFlickable.height ? root.s(6) : 0)
                                spacing: root.s(4)

                                readonly property var tabItems: [
                                    tabWelcome,
                                    tabGeneral,
                                    tabDisplay,
                                    tabTheme,
                                    tabBar,
                                    tabLauncher,
                                    tabDock,
                                    tabOsd,
                                    tabNotifications,
                                    tabWellbeing,
                                    tabIdle,
                                    tabAbout
                                ]

                                Rectangle {
                                    id: tabWelcome
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(0)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(0)) }

                                    property bool isDirectActive: root.currentTab === 0

                                    color: tabWelcomeMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabWelcomeMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabWelcome.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰋜"
                                            iconOffsetX: root.tabsModel[0].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.welcome", "Welcome")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabWelcome.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabWelcome.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabWelcomeMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabWelcomeMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 0;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabGeneral
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(1)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(1)) }

                                    property bool isDirectActive: root.currentTab === 1

                                    color: tabGeneralMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabGeneralMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabGeneral.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰒓"
                                            iconOffsetX: root.tabsModel[1].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.general", "General")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabGeneral.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabGeneral.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabGeneralMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabGeneralMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 1;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                ColumnLayout {
                                    id: tabDisplay
                                    Layout.fillWidth: true
                                    spacing: 0

                                    opacity: root.getTabOpacity(2)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(2)) }

                                    property bool isExpanded: root.expandedTab === 2
                                    property real fullSubtabsHeight: 2 * root.s(36) + root.s(4) + root.s(8)
                                    property real expandProgress: isExpanded ? 1.0 : 0.0
                                    Behavior on expandProgress {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        id: tabHeaderDisplay
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.s(44)
                                        implicitHeight: root.s(44)
                                        radius: ThemeBackend.borderRadius
                                        z: 1

                                        property bool isDirectActive: root.currentTab === 2 && !tabDisplay.isExpanded

                                        color: tabDisplayMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        scale: tabDisplayMa.pressed ? 0.98 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: root.s(10) + (tabHeaderDisplay.isDirectActive ? root.s(4) : 0)
                                            anchors.rightMargin: root.s(14)
                                            spacing: root.s(10)

                                            Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                            IconButton {
                                                enabled: false
                                                size: root.s(32)
                                                Layout.preferredWidth: root.s(32)
                                                Layout.preferredHeight: root.s(32)
                                                Layout.alignment: Qt.AlignVCenter
                                                cornerRadius: ThemeBackend.borderRadius
                                                buttonIcon: "󰃠"
                                                iconOffsetX: root.tabsModel[2].iconOffsetX ?? 0
                                                iconFontSize: root.s(16)
                                                accentColor: ThemeBackend.surface0
                                                textColor: "#ffffff"
                                            }

                                            Text {
                                                text: I18n.t("guide.tabs.display", "Display")
                                                font.family: ThemeBackend.fontFamily
                                                font.weight: tabHeaderDisplay.isDirectActive ? Font.Bold : Font.Medium
                                                font.pixelSize: root.s(13)
                                                color: tabHeaderDisplay.isDirectActive
                                                    ? ThemeBackend.crust
                                                    : (tabDisplayMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                elide: Text.ElideRight
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            Text {
                                                text: "󰅀"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: root.s(14)
                                                color: tabHeaderDisplay.isDirectActive
                                                    ? ThemeBackend.crust
                                                    : (tabDisplayMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                                Layout.alignment: Qt.AlignVCenter
                                                rotation: tabDisplay.expandProgress * 180 - 180
                                                Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        MouseArea {
                                            id: tabDisplayMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.expandedTab === 2) {
                                                    root.expandedTab = -1;
                                                } else {
                                                    root.expandedTab = 2;
                                                    if (root.currentTab !== 2) {
                                                        root.currentTab = 2;
                                                        root.currentSubTab = 0;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        id: displaySubtabsWrapper
                                        visible: tabDisplay.expandProgress > 0.001
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: tabDisplay.fullSubtabsHeight * tabDisplay.expandProgress
                                        implicitHeight: tabDisplay.fullSubtabsHeight * tabDisplay.expandProgress
                                        opacity: Math.max(0.0, (tabDisplay.expandProgress - 0.15) / 0.85)
                                        clip: true

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.topMargin: root.s(4)
                                            anchors.bottomMargin: root.s(4)
                                            spacing: root.s(6)

                                            Item {
                                                Layout.preferredWidth: root.s(20)
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    anchors.topMargin: root.s(2)
                                                    anchors.bottomMargin: root.s(2)
                                                    width: Math.max(1, root.s(2))
                                                    radius: root.s(1)
                                                    color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: root.s(4)

                                                Rectangle {
                                                    id: subtabDisplayGeneral
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: root.s(36)
                                                    implicitHeight: root.s(36)
                                                    radius: ThemeBackend.borderRadius
                                                    z: 1

                                                    property bool isSubActive: root.currentTab === 2 && tabDisplay.isExpanded && root.currentSubTab === 0

                                                    color: subtabDisplayGeneralMa.containsMouse && !isSubActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    scale: subtabDisplayGeneralMa.pressed ? 0.98 : 1.0
                                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: root.s(8) + (subtabDisplayGeneral.isSubActive ? root.s(4) : 0)
                                                        anchors.rightMargin: root.s(10)
                                                        spacing: root.s(8)

                                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                        IconButton {
                                                            enabled: false
                                                            size: root.s(26)
                                                            Layout.preferredWidth: root.s(26)
                                                            Layout.preferredHeight: root.s(26)
                                                            Layout.alignment: Qt.AlignVCenter
                                                            cornerRadius: ThemeBackend.borderRadius
                                                            buttonIcon: "󰃠"
                                                            iconOffsetX: root.tabsModel[2].subtabs[0].iconOffsetX ?? 0
                                                            iconFontSize: root.s(13)
                                                            accentColor: ThemeBackend.surface0
                                                            textColor: "#ffffff"
                                                        }

                                                        Text {
                                                            text: I18n.t("guide.tabs.display_general", "Display")
                                                            font.family: ThemeBackend.fontFamily
                                                            font.weight: subtabDisplayGeneral.isSubActive ? Font.Bold : Font.Medium
                                                            font.pixelSize: root.s(12)
                                                            color: subtabDisplayGeneral.isSubActive ? ThemeBackend.crust : ThemeBackend.subtext0
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            elide: Text.ElideRight
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: subtabDisplayGeneralMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.currentTab = 2;
                                                            root.expandedTab = 2;
                                                            root.currentSubTab = 0;
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    id: subtabDisplayWidgets
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: root.s(36)
                                                    implicitHeight: root.s(36)
                                                    radius: ThemeBackend.borderRadius
                                                    z: 1

                                                    property bool isSubActive: root.currentTab === 2 && tabDisplay.isExpanded && root.currentSubTab === 1

                                                    color: subtabDisplayWidgetsMa.containsMouse && !isSubActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    scale: subtabDisplayWidgetsMa.pressed ? 0.98 : 1.0
                                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: root.s(8) + (subtabDisplayWidgets.isSubActive ? root.s(4) : 0)
                                                        anchors.rightMargin: root.s(10)
                                                        spacing: root.s(8)

                                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                        IconButton {
                                                            enabled: false
                                                            size: root.s(26)
                                                            Layout.preferredWidth: root.s(26)
                                                            Layout.preferredHeight: root.s(26)
                                                            Layout.alignment: Qt.AlignVCenter
                                                            cornerRadius: ThemeBackend.borderRadius
                                                            buttonIcon: "󰕰"
                                                            iconOffsetX: root.tabsModel[2].subtabs[1].iconOffsetX ?? 0
                                                            iconFontSize: root.s(13)
                                                            accentColor: ThemeBackend.surface0
                                                            textColor: "#ffffff"
                                                        }

                                                        Text {
                                                            text: I18n.t("guide.tabs.display_widgets", "Widgets")
                                                            font.family: ThemeBackend.fontFamily
                                                            font.weight: subtabDisplayWidgets.isSubActive ? Font.Bold : Font.Medium
                                                            font.pixelSize: root.s(12)
                                                            color: subtabDisplayWidgets.isSubActive ? ThemeBackend.crust : ThemeBackend.subtext0
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            elide: Text.ElideRight
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: subtabDisplayWidgetsMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.currentTab = 2;
                                                            root.expandedTab = 2;
                                                            root.currentSubTab = 1;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabTheme
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(3)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(3)) }

                                    property bool isDirectActive: root.currentTab === 3

                                    color: tabThemeMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabThemeMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabTheme.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "✦"
                                            iconOffsetX: root.tabsModel[3].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.theme", "Theme")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabTheme.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabTheme.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabThemeMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabThemeMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 3;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                ColumnLayout {
                                    id: tabBar
                                    Layout.fillWidth: true
                                    spacing: 0

                                    opacity: root.getTabOpacity(4)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(4)) }

                                    property bool isExpanded: root.expandedTab === 4
                                    property real fullSubtabsHeight: 2 * root.s(36) + root.s(4) + root.s(8)
                                    property real expandProgress: isExpanded ? 1.0 : 0.0
                                    Behavior on expandProgress {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        id: tabHeaderBar
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: root.s(44)
                                        implicitHeight: root.s(44)
                                        radius: ThemeBackend.borderRadius
                                        z: 1

                                        property bool isDirectActive: root.currentTab === 4 && !tabBar.isExpanded

                                        color: tabBarMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        scale: tabBarMa.pressed ? 0.98 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: root.s(10) + (tabHeaderBar.isDirectActive ? root.s(4) : 0)
                                            anchors.rightMargin: root.s(14)
                                            spacing: root.s(10)

                                            Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                            IconButton {
                                                enabled: false
                                                size: root.s(32)
                                                Layout.preferredWidth: root.s(32)
                                                Layout.preferredHeight: root.s(32)
                                                Layout.alignment: Qt.AlignVCenter
                                                cornerRadius: ThemeBackend.borderRadius
                                                buttonIcon: "󰹑"
                                                iconOffsetX: root.tabsModel[4].iconOffsetX ?? 0
                                                iconFontSize: root.s(16)
                                                accentColor: ThemeBackend.surface0
                                                textColor: "#ffffff"
                                            }

                                            Text {
                                                text: I18n.t("guide.tabs.bar", "Bar")
                                                font.family: ThemeBackend.fontFamily
                                                font.weight: tabHeaderBar.isDirectActive ? Font.Bold : Font.Medium
                                                font.pixelSize: root.s(13)
                                                color: tabHeaderBar.isDirectActive
                                                    ? ThemeBackend.crust
                                                    : (tabBarMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                elide: Text.ElideRight
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            Text {
                                                text: "󰅀"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: root.s(14)
                                                color: tabHeaderBar.isDirectActive
                                                    ? ThemeBackend.crust
                                                    : (tabBarMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                                Layout.alignment: Qt.AlignVCenter
                                                rotation: tabBar.expandProgress * 180 - 180
                                                Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        MouseArea {
                                            id: tabBarMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.expandedTab === 4) {
                                                    root.expandedTab = -1;
                                                } else {
                                                    root.expandedTab = 4;
                                                    if (root.currentTab !== 4) {
                                                        root.currentTab = 4;
                                                        root.currentSubTab = 0;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        id: barSubtabsWrapper
                                        visible: tabBar.expandProgress > 0.001
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: tabBar.fullSubtabsHeight * tabBar.expandProgress
                                        implicitHeight: tabBar.fullSubtabsHeight * tabBar.expandProgress
                                        opacity: Math.max(0.0, (tabBar.expandProgress - 0.15) / 0.85)
                                        clip: true

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.topMargin: root.s(4)
                                            anchors.bottomMargin: root.s(4)
                                            spacing: root.s(6)

                                            Item {
                                                Layout.preferredWidth: root.s(20)
                                                Layout.fillHeight: true

                                                Rectangle {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    anchors.topMargin: root.s(2)
                                                    anchors.bottomMargin: root.s(2)
                                                    width: Math.max(1, root.s(2))
                                                    radius: root.s(1)
                                                    color: Qt.rgba(ThemeBackend.surface2.r, ThemeBackend.surface2.g, ThemeBackend.surface2.b, 0.7)
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: root.s(4)

                                                Rectangle {
                                                    id: subtabBarGeneral
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: root.s(36)
                                                    implicitHeight: root.s(36)
                                                    radius: ThemeBackend.borderRadius
                                                    z: 1

                                                    property bool isSubActive: root.currentTab === 4 && tabBar.isExpanded && root.currentSubTab === 0

                                                    color: subtabBarGeneralMa.containsMouse && !isSubActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    scale: subtabBarGeneralMa.pressed ? 0.98 : 1.0
                                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: root.s(8) + (subtabBarGeneral.isSubActive ? root.s(4) : 0)
                                                        anchors.rightMargin: root.s(10)
                                                        spacing: root.s(8)

                                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                        IconButton {
                                                            enabled: false
                                                            size: root.s(26)
                                                            Layout.preferredWidth: root.s(26)
                                                            Layout.preferredHeight: root.s(26)
                                                            Layout.alignment: Qt.AlignVCenter
                                                            cornerRadius: ThemeBackend.borderRadius
                                                            buttonIcon: "󰒓"
                                                            iconOffsetX: root.tabsModel[4].subtabs[0].iconOffsetX ?? 0
                                                            iconFontSize: root.s(13)
                                                            accentColor: ThemeBackend.surface0
                                                            textColor: "#ffffff"
                                                        }

                                                        Text {
                                                            text: I18n.t("guide.tabs.bar_general", "General")
                                                            font.family: ThemeBackend.fontFamily
                                                            font.weight: subtabBarGeneral.isSubActive ? Font.Bold : Font.Medium
                                                            font.pixelSize: root.s(12)
                                                            color: subtabBarGeneral.isSubActive ? ThemeBackend.crust : ThemeBackend.subtext0
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            elide: Text.ElideRight
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: subtabBarGeneralMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.currentTab = 4;
                                                            root.expandedTab = 4;
                                                            root.currentSubTab = 0;
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    id: subtabBarModules
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: root.s(36)
                                                    implicitHeight: root.s(36)
                                                    radius: ThemeBackend.borderRadius
                                                    z: 1

                                                    property bool isSubActive: root.currentTab === 4 && tabBar.isExpanded && root.currentSubTab === 1

                                                    color: subtabBarModulesMa.containsMouse && !isSubActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    scale: subtabBarModulesMa.pressed ? 0.98 : 1.0
                                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: root.s(8) + (subtabBarModules.isSubActive ? root.s(4) : 0)
                                                        anchors.rightMargin: root.s(10)
                                                        spacing: root.s(8)

                                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                                                        IconButton {
                                                            enabled: false
                                                            size: root.s(26)
                                                            Layout.preferredWidth: root.s(26)
                                                            Layout.preferredHeight: root.s(26)
                                                            Layout.alignment: Qt.AlignVCenter
                                                            cornerRadius: ThemeBackend.borderRadius
                                                            buttonIcon: "󰮯"
                                                            iconOffsetX: root.tabsModel[4].subtabs[1].iconOffsetX ?? 0
                                                            iconFontSize: root.s(13)
                                                            accentColor: ThemeBackend.surface0
                                                            textColor: "#ffffff"
                                                        }

                                                        Text {
                                                            text: I18n.t("guide.tabs.bar_modules", "Modules")
                                                            font.family: ThemeBackend.fontFamily
                                                            font.weight: subtabBarModules.isSubActive ? Font.Bold : Font.Medium
                                                            font.pixelSize: root.s(12)
                                                            color: subtabBarModules.isSubActive ? ThemeBackend.crust : ThemeBackend.subtext0
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignVCenter
                                                            elide: Text.ElideRight
                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: subtabBarModulesMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.currentTab = 4;
                                                            root.expandedTab = 4;
                                                            root.currentSubTab = 1;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabLauncher
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(5)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(5)) }

                                    property bool isDirectActive: root.currentTab === 5

                                    color: tabLauncherMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabLauncherMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabLauncher.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰵆"
                                            iconOffsetX: root.tabsModel[5].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.launcher", "Launcher")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabLauncher.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabLauncher.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabLauncherMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabLauncherMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 5;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabDock
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(6)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(6)) }

                                    property bool isDirectActive: root.currentTab === 6

                                    color: tabDockMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabDockMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabDock.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰮯"
                                            iconOffsetX: root.tabsModel[6].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.dock", "Dock")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabDock.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabDock.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabDockMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabDockMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 6;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabOsd
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(7)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(7)) }

                                    property bool isDirectActive: root.currentTab === 7

                                    color: tabOsdMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabOsdMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabOsd.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰕾"
                                            iconOffsetX: root.tabsModel[7].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.osd", "On-Screen Display")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabOsd.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabOsd.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabOsdMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabOsdMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 7;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabNotifications
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(8)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(8)) }

                                    property bool isDirectActive: root.currentTab === 8

                                    color: tabNotificationsMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabNotificationsMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabNotifications.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰂚"
                                            iconOffsetX: root.tabsModel[8].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.notifications", "Notifications")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabNotifications.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabNotifications.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabNotificationsMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabNotificationsMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 8;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabWellbeing
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(9)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(9)) }

                                    property bool isDirectActive: root.currentTab === 9

                                    color: tabWellbeingMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabWellbeingMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabWellbeing.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰄉"
                                            iconOffsetX: root.tabsModel[9].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.wellbeing", "Wellbeing")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabWellbeing.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabWellbeing.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabWellbeingMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabWellbeingMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 9;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabIdle
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(10)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(10)) }

                                    property bool isDirectActive: root.currentTab === 10

                                    color: tabIdleMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabIdleMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabIdle.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: "󰒲"
                                            iconOffsetX: root.tabsModel[10].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.idle", "Idle")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabIdle.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabIdle.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabIdleMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabIdleMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 10;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: tabAbout
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: root.s(44)
                                    implicitHeight: root.s(44)
                                    radius: ThemeBackend.borderRadius
                                    z: 1

                                    opacity: root.getTabOpacity(11)
                                    transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(11)) }

                                    property bool isDirectActive: root.currentTab === 11

                                    color: tabAboutMa.containsMouse && !isDirectActive ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    scale: tabAboutMa.pressed ? 0.98 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(10) + (tabAbout.isDirectActive ? root.s(4) : 0)
                                        anchors.rightMargin: root.s(14)
                                        spacing: root.s(10)

                                        Behavior on anchors.leftMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                                        IconButton {
                                            enabled: false
                                            size: root.s(32)
                                            Layout.preferredWidth: root.s(32)
                                            Layout.preferredHeight: root.s(32)
                                            Layout.alignment: Qt.AlignVCenter
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: ""
                                            iconOffsetX: root.tabsModel[11].iconOffsetX ?? 0
                                            iconFontSize: root.s(16)
                                            accentColor: ThemeBackend.surface0
                                            textColor: "#ffffff"
                                        }

                                        Text {
                                            text: I18n.t("guide.tabs.about", "About")
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: tabAbout.isDirectActive ? Font.Bold : Font.Medium
                                            font.pixelSize: root.s(13)
                                            color: tabAbout.isDirectActive
                                                ? ThemeBackend.crust
                                                : (tabAboutMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    MouseArea {
                                        id: tabAboutMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = -1;
                                            root.currentTab = 11;
                                            root.currentSubTab = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ClickButton {
                        visible: Updater.updateAvailable && !root.searchActive
                        Layout.fillWidth: true
                        implicitHeight: root.s(38)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonText: I18n.t("guide.update_available")
                        buttonIcon: "󰚰"
                        iconFontSize: root.s(16)
                        textFontSize: root.s(13)
                        accentColor: ThemeBackend.green
                        textColor: ThemeBackend.crust
                        opacity: root.getTabOpacity(12)
                        transform: Translate { x: root.s(-24) * (1.0 - root.getTabProgress(12)) }
                        onClicked: {
                            root.gotoTab("about");
                        }
                    }
                }
            }

            Item {
                id: contentArea
                anchors.left: sidebar.right
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 1
                anchors.rightMargin: 1
                anchors.topMargin: 4
                anchors.bottomMargin: 4

                opacity: introContent
                scale: 0.95 + (0.05 * introContent)
                transform: Translate { y: root.s(20) * (1.0 - introContent) }

                Repeater {
                    id: contentRepeater
                    model: root.tabsModel
                    delegate: Item {
                        id: tabContentWrapper
                        anchors.fill: parent
                        visible: root.currentTab === parentTabIndex

                        property int parentTabIndex: index
                        property int tabIndex: parentTabIndex
                        property var tabData: modelData
                        property bool hasSubtabs: Boolean(tabData.subtabs && tabData.subtabs.length > 0)

                        Loader {
                            id: singleTabLoader
                            anchors.fill: parent
                            asynchronous: false
                            active: !tabContentWrapper.hasSubtabs
                            visible: !tabContentWrapper.hasSubtabs && root.currentTab === tabContentWrapper.parentTabIndex
                            property int tabIndex: tabContentWrapper.parentTabIndex
                            property int subTabIndex: -1

                            function ensureLoaded() {
                                if (status === Loader.Null && tabData.file) {
                                    setSource(tabData.file, {
                                        "rootObj": root,
                                        "tabIndex": tabContentWrapper.parentTabIndex
                                    });
                                }
                            }

                            onLoaded: {
                                root.registerTabSearchItems(item);
                            }

                            Component.onCompleted: ensureLoaded()

                            Connections {
                                target: root
                                function onCurrentTabChanged() {
                                    if (root.currentTab === tabContentWrapper.parentTabIndex && !tabContentWrapper.hasSubtabs) singleTabLoader.ensureLoaded();
                                }
                            }
                        }

                        Repeater {
                            model: tabContentWrapper.hasSubtabs ? tabData.subtabs : []

                            delegate: Loader {
                                id: subTabLoader
                                anchors.fill: parent
                                asynchronous: false
                                property int subIndex: index
                                property int tabIndex: tabContentWrapper.parentTabIndex
                                property int subTabIndex: subIndex
                                property var subData: modelData
                                visible: root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex

                                function ensureLoaded() {
                                    if (status === Loader.Null && subData.file) {
                                        setSource(subData.file, {
                                            "rootObj": root,
                                            "tabIndex": tabContentWrapper.parentTabIndex,
                                            "subTabIndex": subIndex
                                        });
                                        if (item && "subTabIndex" in item) {
                                            item.subTabIndex = subIndex;
                                        }
                                    }
                                }

                                onLoaded: {
                                    if (item && "subTabIndex" in item) {
                                        item.subTabIndex = subIndex;
                                    }
                                    root.registerTabSearchItems(item);
                                }

                                Component.onCompleted: ensureLoaded()

                                Connections {
                                    target: root
                                    function onCurrentTabChanged() {
                                        if (root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                                    }
                                    function onCurrentSubTabChanged() {
                                        if (root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
