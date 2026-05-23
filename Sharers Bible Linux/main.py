#!/usr/bin/env python3
import json, os, configparser, threading, shutil, urllib.request, urllib.error
from pathlib import Path

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
gi.require_version('Gio', '2.0')
gi.require_version('Pango', '1.0')
from gi.repository import Gtk, GLib, Gdk, Gio, Pango

try:
    gi.require_version('Adw', '1')
    from gi.repository import Adw
    HAS_ADW = True
except (ValueError, ImportError):
    HAS_ADW = False

API_BASE = 'https://apibible.wbem.org/api'
MANIFEST_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'manifest.json')
CONFIG_DIR = os.path.expanduser('~/.config/sharers-bible')
CONFIG_FILE = os.path.join(CONFIG_DIR, 'config.ini')
CACHE_DIR = os.path.expanduser('~/.local/share/sharers-bible/bibles')

BASE_BOOKS = [
    ("Genesis",50),("Exodus",40),("Leviticus",27),("Numbers",36),
    ("Deuteronomy",34),("Joshua",24),("Judges",21),("Ruth",4),
    ("1 Samuel",31),("2 Samuel",24),("1 Kings",22),("2 Kings",25),
    ("1 Chronicles",29),("2 Chronicles",36),("Ezra",10),("Nehemiah",13),
    ("Esther",10),("Job",42),("Psalms",150),("Proverbs",31),
    ("Ecclesiastes",12),("Song of Solomon",8),("Isaiah",66),("Jeremiah",52),
    ("Lamentations",5),("Ezekiel",48),("Daniel",12),("Hosea",14),
    ("Joel",3),("Amos",9),("Obadiah",1),("Jonah",4),
    ("Micah",7),("Nahum",3),("Habakkuk",3),("Zephaniah",3),
    ("Haggai",2),("Zechariah",14),("Malachi",4),("Matthew",28),
    ("Mark",16),("Luke",24),("John",21),("Acts",28),
    ("Romans",16),("1 Corinthians",16),("2 Corinthians",13),("Galatians",6),
    ("Ephesians",6),("Philippians",4),("Colossians",4),("1 Thessalonians",5),
    ("2 Thessalonians",3),("1 Timothy",6),("2 Timothy",4),("Titus",3),
    ("Philemon",1),("Hebrews",13),("James",5),("1 Peter",5),
    ("2 Peter",3),("1 John",5),("2 John",1),("3 John",1),
    ("Jude",1),("Revelation",22)
]

ENGLISH_VERSION_NAMES = {
    "akjv":"American King James Version","amp":"Amplified Bible","ampc":"Amplified Bible (Classic)",
    "asv":"American Standard Version","brg":"BRG Bible","ceb":"Common English Bible",
    "cev":"Contemporary English Version","cevd":"CEV (Deuterocanon)","cjb":"Complete Jewish Bible",
    "csb":"Christian Standard Bible","darby":"Darby Translation","dlnt":"Disciples' Literal New Testament",
    "dra":"Douay-Rheims 1899 American","ehv":"EHV","erv":"Easy-to-Read Version",
    "esv":"English Standard Version","exb":"Expanded Bible","gnt":"Good News Translation",
    "gnv":"1599 Geneva Bible","gw":"God's Word Translation","hcsb":"Holman Christian Standard Bible",
    "icb":"International Children's Bible","isv":"International Standard Version",
    "jub":"Jubilee Bible 2000","kj21":"21st Century King James Version","kjv":"King James Version",
    "leb":"Lexham English Bible","mev":"Modern English Version","mounce":"Mounce Reverse-Interlinear NT",
    "msg":"The Message","nabre":"New American Bible (Revised)","nasb":"New American Standard Bible",
    "ncv":"New Century Version","net":"NET Bible","nirv":"New International Reader's Version",
    "niv1984":"New International Version (1984)","niv2011":"New International Version (2011)",
    "nivuk":"New International Version (UK)","nkjv":"New King James Version",
    "nlt":"New Living Translation","nlt2013":"New Living Translation (2013)",
    "nlv":"New Life Version","nog":"Names of God Bible","nrsv":"New Revised Standard Version",
    "nrsva":"New Revised Standard Version (Ang)","ojb":"Orthodox Jewish Bible",
    "phillips":"Phillips Translation","rsv":"Revised Standard Version",
    "rsvce":"Revised Standard Version (CE)","tlb":"The Living Bible",
    "tlv":"Tree of Life Version","voice":"The Voice","web":"World English Bible",
    "webbe":"World English Bible (British)","wyc":"Wycliffe Bible","ylt":"Young's Literal Translation"
}

ENGLISH_COPYRIGHTS = {
    "akjv":"American King James Version (AKJV) is in the public domain.",
    "amp":"Scripture quotations taken from the Amplified Bible, Copyright 2015 by The Lockman Foundation. Used by permission.",
    "ampc":"Scripture quotations taken from the Amplified Bible (Classic), Copyright 1954,1958,1962,1964,1965,1987 by The Lockman Foundation. Used by permission.",
    "asv":"American Standard Version (ASV) is in the public domain.",
    "brg":"BRG Bible is in the public domain.",
    "ceb":"Scripture quotations from the Common English Bible, Copyright 2011 Common English Bible. Used by permission.",
    "cev":"Scripture quotations from the Contemporary English Version, Copyright 1995 American Bible Society. Used by permission.",
    "cevd":"Scripture quotations from the Contemporary English Version, Copyright 1995 American Bible Society. Used by permission.",
    "cjb":"Scripture quotations from the Complete Jewish Bible, Copyright 1998 by David H. Stern. Used by permission.",
    "csb":"Scripture quotations from the Christian Standard Bible, Copyright 2017 by Holman Bible Publishers. Used by permission.",
    "darby":"Darby Translation (DARBY) is in the public domain.",
    "dlnt":"Disciples' Literal New Testament, Copyright 2011 by Michael J. Magill. Used by permission.",
    "dra":"Douay-Rheims 1899 American Edition (DRA) is in the public domain.",
    "ehv":"Scripture quotations from the Evangelical Heritage Version, Copyright 2019 Warburg Project. Used by permission.",
    "erv":"Scripture quotations from the Easy-to-Read Version, Copyright 2006 by Bible League International. Used by permission.",
    "esv":"Scripture quotations are from The ESV Bible (The Holy Bible, English Standard Version), copyright 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.",
    "exb":"Scripture quotations from The Expanded Bible, Copyright 2011 by Thomas Nelson. Used by permission.",
    "gnt":"Scripture quotations from the Good News Translation, Copyright 1992 by American Bible Society. Used by permission.",
    "gnv":"1599 Geneva Bible (GNV) is in the public domain.",
    "gw":"Scripture quotations from GODS WORD Translation, Copyright 1995 by God's Word to the Nations. Used by permission.",
    "hcsb":"Scripture quotations from the Holman Christian Standard Bible, Copyright 1999,2000,2002,2003,2009 by Holman Bible Publishers. Used by permission.",
    "icb":"Scripture quotations from the International Children's Bible, Copyright 1986,1988,1999 by Thomas Nelson. Used by permission.",
    "isv":"Scripture quotations from the International Standard Version, Copyright 1995-2014 by ISV Foundation. Used by permission.",
    "jub":"Jubilee Bible 2000 (JUB) is in the public domain.",
    "kj21":"21st Century King James Version (KJ21), Copyright 1994 by Deuel Enterprises. Used by permission.",
    "kjv":"King James Version (KJV) is in the public domain.",
    "leb":"Scripture quotations from the Lexham English Bible, Copyright 2012 Logos Bible Software. Used by permission.",
    "mev":"Scripture quotations from the Modern English Version, Copyright 2014 by Military Bible Association. Used by permission.",
    "mounce":"Scripture quotations from Mounce Reverse-Interlinear NT, Copyright 2011 by William D. Mounce. Used by permission.",
    "msg":"The Message (MSG) Copyright 1993,1994,1995,1996,2000,2001,2002. Used by permission of NavPress Publishing Group.",
    "nabre":"Scripture quotations from the New American Bible (Revised Edition), 2010,1991,1986,1970 Confraternity of Christian Doctrine. Used by permission.",
    "nasb":"Scripture taken from the NEW AMERICAN STANDARD BIBLE, Copyright 1960,1962,1963,1968,1971,1972,1973,1975,1977,1995 by The Lockman Foundation. Used by permission.",
    "ncv":"Scripture quotations from the New Century Version, Copyright 2005 by Thomas Nelson. Used by permission.",
    "net":"Scripture quotations from the NET Bible, Copyright 1996-2016 by Biblical Studies Press. Used by permission.",
    "nirv":"Scripture quotations from the New International Reader's Version, Copyright 1995,1996,1998,2014 by Biblica, Inc. Used by permission.",
    "niv1984":"Holy Bible, New International Version, NIV Copyright 1973,1978,1984 by Biblica, Inc. Used by permission. All rights reserved worldwide.",
    "niv2011":"Holy Bible, New International Version, NIV Copyright 1973,1978,1984,2011 by Biblica, Inc. Used by permission. All rights reserved worldwide.",
    "nivuk":"Holy Bible, New International Version, NIV Copyright 1973,1978,1984,2011 by Biblica, Inc. Used by permission. All rights reserved worldwide.",
    "nkjv":"Scripture quotations from the New King James Version, Copyright 1982 by Thomas Nelson. Used by permission.",
    "nlt":"Scripture quotations from the Holy Bible, New Living Translation, Copyright 1996,2004,2015 by Tyndale House Foundation. Used by permission.",
    "nlt2013":"Scripture quotations from the Holy Bible, New Living Translation, Copyright 1996,2004,2013 by Tyndale House Foundation. Used by permission.",
    "nlv":"Scripture quotations from the New Life Version, Copyright 1969 by Christian Literature International. Used by permission.",
    "nog":"Scripture quotations from The Names of God Bible, Copyright 2011 by Baker Publishing Group. Used by permission.",
    "nrsv":"New Revised Standard Version Bible, copyright 1989 the Division of Christian Education of the National Council of the Churches of Christ in the United States of America. Used by permission. All rights reserved.",
    "nrsva":"New Revised Standard Version Bible, copyright 1989 the Division of Christian Education of the National Council of the Churches of Christ in the United States of America. Used by permission. All rights reserved.",
    "ojb":"Orthodox Jewish Bible, Copyright 2002,2003,2008,2010,2011 by Artists for Israel International. Used by permission.",
    "phillips":"Scripture quotations from the Phillips Translation, Copyright 1960,1986 by J.B. Phillips. Used by permission.",
    "rsv":"Revised Standard Version (RSV) is in the public domain.",
    "rsvce":"Revised Standard Version Catholic Edition (RSVCE), Copyright 1965,1966 by Division of Christian Education of the National Council of the Churches of Christ. Used by permission.",
    "tlb":"Scripture quotations from The Living Bible, Copyright 1971 by Tyndale House Foundation. Used by permission.",
    "tlv":"Scripture quotations from the Tree of Life Version, Copyright 2015 by the Messianic Jewish Family Bible Society. Used by permission.",
    "voice":"Scripture quotations from The Voice, Copyright 2012 by Ecclesia Bible Society. Used by permission.",
    "web":"World English Bible (WEB) is in the public domain.",
    "webbe":"World English Bible British Edition (WEBBE) is in the public domain.",
    "wyc":"Wycliffe Bible (WYC) is in the public domain.",
    "ylt":"Young's Literal Translation (YLT) is in the public domain."
}

LOCALIZED_LABELS = {
    "af": {
        "addToDesign": "Voeg by ontwerp",
        "bible": "Bybel",
        "book": "Boek",
        "chapter": "Hoofstuk",
        "chapterNotFound": "Hoofstuk nie gevind in hierdie weergawe nie",
        "chapterPrefix": "Hoofstuk ",
        "chapterSuffix": "",
        "choosePassage": "Kies 'n boek en hoofstuk om te begin lees",
        "copy": "Kopieer",
        "copyAllText": "Kopieer Alle Teks",
        "deleteAllDownloads": "Verwyder Alles",
        "deleteDownload": "Verwyder Aflaai",
        "download": "Laai Af",
        "downloadComplete": "Aflaai Voltooi!",
        "downloadManager": "Aflaai Bestuurder",
        "downloaded": "Afgelaai",
        "downloading": "Laai af...",
        "exHtml": "Geëksporteer na HTML!",
        "exMarkdown": "Eksporteer na Markdown!",
        "exportHtml": "Eksporteer na HTML",
        "exportMarkdown": "Eksporteer na Markdown",
        "failedToLoad": "Kon nie verse laai nie",
        "fetchingWord": "Laai God se Woord...",
        "fontSize": "Lettergrootte",
        "fontSizePt": "%dpt",
        "from": "Vanaf",
        "language": "Taal",
        "loading": "Laai tans...",
        "passageCopied": "Hele gedeelte gekopieer!",
        "passageNotFound": "Gedeelte nie gevind nie",
        "referenceCopied": "Verwysing gekopieer!",
        "selectPassage": "Kies 'n boek en hoofstuk om te begin lees",
        "selectPrompt": "Kies 'n boek en hoofstuk om verse te sien",
        "settings": "Instellings",
        "theme": "Tema",
        "themeDark": "Donker",
        "themeLight": "Lig",
        "themeSepia": "Sepia",
        "themeSystem": "Stelsel",
        "to": "Tot",
        "unableToLoad": "Kon nie verse laai nie",
        "verse": "Vers",
        "verseCopied": "Teks gekopieer!",
        "versePrefix": "Vers ",
        "verseSuffix": "",
        "versesOptional": "Verse (Opsioneel)",
        "version": "Weergawe"
    },
    "ar": {
        "addToDesign": "إضافة إلى التصميم",
        "bible": "الكتاب المقدس",
        "book": "السفر",
        "chapter": "الأصحاح",
        "chapterNotFound": "لم يتم العثور على الأصحاح في هذا الإصدار",
        "choosePassage": "اختر سفرًا وأصحاحًا لبدء القراءة",
        "copy": "نسخ",
        "deleteAllDownloads": "حذف الكل",
        "deleteDownload": "حذف التحميل",
        "download": "تحميل",
        "downloadComplete": "اكتمل التحميل!",
        "downloadManager": "مدير التحميل",
        "downloaded": "تم التحميل",
        "downloading": "جارٍ التحميل...",
        "exHtml": "تم التصدير إلى HTML!",
        "exMarkdown": "تم التصدير إلى Markdown!",
        "exportHtml": "تصدير إلى HTML",
        "exportMarkdown": "تصدير إلى Markdown",
        "failedToLoad": "فشل تحميل الآيات",
        "fetchingWord": "جارٍ تحميل كلمة الله...",
        "fontSize": "حجم الخط",
        "fontSizePt": "%dpt",
        "from": "من",
        "language": "اللغة",
        "loading": "جارٍ التحميل...",
        "passageCopied": "تم نسخ المقطع بالكامل!",
        "referenceCopied": "تم نسخ المرجع!",
        "selectPassage": "اختر سفرًا وأصحاحًا لبدء القراءة",
        "settings": "الإعدادات",
        "theme": "المظهر",
        "themeDark": "داكن",
        "themeLight": "فاتح",
        "themeSepia": "سيبيا",
        "themeSystem": "النظام",
        "to": "إلى",
        "unableToLoad": "فشل تحميل الآيات",
        "verse": "الآية",
        "verseCopied": "تم نسخ نص الآية!",
        "version": "الإصدار"
    },
    "de": {
        "bible": "Bibel",
        "book": "Buch",
        "chapter": "Kapitel",
        "chapterNotFound": "Kapitel in dieser Übersetzung nicht gefunden",
        "choosePassage": "Wähle ein Buch und Kapitel zum Lesen",
        "copy": "Kopieren",
        "deleteAllDownloads": "Alle löschen",
        "deleteDownload": "Download löschen",
        "download": "Herunterladen",
        "downloadComplete": "Download abgeschlossen!",
        "downloadManager": "Download-Manager",
        "downloaded": "Heruntergeladen",
        "downloading": "Lädt herunter...",
        "exHtml": "Als HTML exportiert!",
        "exMarkdown": "Als Markdown exportiert!",
        "exportHtml": "Als HTML exportieren",
        "exportMarkdown": "Als Markdown exportieren",
        "failedToLoad": "Verse konnten nicht geladen werden",
        "fetchingWord": "Lade Gottes Wort...",
        "fontSize": "Schriftgröße",
        "fontSizePt": "%dpt",
        "from": "Von",
        "language": "Sprache",
        "loading": "Lädt...",
        "passageCopied": "Ganze Passage kopiert!",
        "referenceCopied": "Referenz kopiert!",
        "selectPassage": "Wähle ein Buch und Kapitel zum Lesen",
        "settings": "Einstellungen",
        "theme": "Design",
        "themeDark": "Dunkel",
        "themeLight": "Hell",
        "themeSepia": "Sepia",
        "themeSystem": "System",
        "to": "Bis",
        "unableToLoad": "Verse konnten nicht geladen werden",
        "verse": "Vers",
        "verseCopied": "Vers kopiert!",
        "version": "Übersetzung"
    },
    "es": {
        "bible": "Biblia",
        "book": "Libro",
        "chapter": "Capítulo",
        "chapterNotFound": "Capítulo no encontrado en esta versión",
        "choosePassage": "Selecciona un libro y capítulo para empezar a leer",
        "copy": "Copiar",
        "deleteAllDownloads": "Eliminar todo",
        "deleteDownload": "Eliminar descarga",
        "download": "Descargar",
        "downloadComplete": "¡Descarga completa!",
        "downloadManager": "Administrador de descargas",
        "downloaded": "Descargado",
        "downloading": "Descargando...",
        "exHtml": "¡Exportado a HTML!",
        "exMarkdown": "¡Exportado a Markdown!",
        "exportHtml": "Exportar a HTML",
        "exportMarkdown": "Exportar a Markdown",
        "failedToLoad": "Error al cargar los versículos",
        "fetchingWord": "Cargando la Palabra de Dios...",
        "fontSize": "Tamaño de fuente",
        "fontSizePt": "%dpt",
        "from": "Desde",
        "language": "Idioma",
        "loading": "Cargando...",
        "passageCopied": "¡Pasaje completo copiado!",
        "referenceCopied": "¡Referencia copiada!",
        "selectPassage": "Selecciona un libro y capítulo para empezar a leer",
        "settings": "Configuración",
        "theme": "Tema",
        "themeDark": "Oscuro",
        "themeLight": "Claro",
        "themeSepia": "Sepia",
        "themeSystem": "Sistema",
        "to": "Hasta",
        "unableToLoad": "Error al cargar los versículos",
        "verse": "Versículo",
        "verseCopied": "¡Texto del versículo copiado!",
        "version": "Versión"
    },
    "fi": {
        "bible": "Raamattu",
        "book": "Kirja",
        "chapter": "Luku",
        "chapterNotFound": "Lukua ei löydy tästä käännöksestä",
        "choosePassage": "Valitse kirja ja luku aloittaaksesi lukemisen",
        "copy": "Kopioi",
        "deleteAllDownloads": "Poista kaikki",
        "deleteDownload": "Poista lataus",
        "download": "Lataa",
        "downloadComplete": "Lataus valmis!",
        "downloadManager": "Latausten hallinta",
        "downloaded": "Ladattu",
        "downloading": "Ladataan...",
        "exHtml": "Viety HTML-muotoon!",
        "exMarkdown": "Viety Markdown-muotoon!",
        "exportHtml": "Vie HTML-muotoon",
        "exportMarkdown": "Vie Markdown-muotoon",
        "failedToLoad": "Jakeiden lataus epäonnistui",
        "fetchingWord": "Ladataan Jumalan sanaa...",
        "fontSize": "Fonttikoko",
        "fontSizePt": "%dpt",
        "from": "Alkaen",
        "language": "Kieli",
        "loading": "Ladataan...",
        "passageCopied": "Koko kohta kopioitu!",
        "referenceCopied": "Viite kopioitu!",
        "selectPassage": "Valitse kirja ja luku aloittaaksesi lukemisen",
        "settings": "Asetukset",
        "theme": "Teema",
        "themeDark": "Tumma",
        "themeLight": "Vaalea",
        "themeSepia": "Seepia",
        "themeSystem": "Järjestelmä",
        "to": "Saakka",
        "unableToLoad": "Jakeiden lataus epäonnistui",
        "verse": "Jae",
        "verseCopied": "Jae kopioitu!",
        "version": "Käännös"
    },
    "fr": {
        "bible": "Bible",
        "book": "Livre",
        "chapter": "Chapitre",
        "chapterNotFound": "Chapitre introuvable dans cette version",
        "choosePassage": "Sélectionnez un livre et un chapitre pour commencer à lire",
        "copy": "Copier",
        "deleteAllDownloads": "Tout supprimer",
        "deleteDownload": "Supprimer le téléchargement",
        "download": "Télécharger",
        "downloadComplete": "Téléchargement terminé !",
        "downloadManager": "Gestionnaire de téléchargements",
        "downloaded": "Téléchargé",
        "downloading": "Téléchargement...",
        "exHtml": "Exporté en HTML !",
        "exMarkdown": "Exporté en Markdown !",
        "exportHtml": "Exporter en HTML",
        "exportMarkdown": "Exporter en Markdown",
        "failedToLoad": "Échec du chargement des versets",
        "fetchingWord": "Chargement de la Parole de Dieu...",
        "fontSize": "Taille de police",
        "fontSizePt": "%dpt",
        "from": "De",
        "language": "Langue",
        "loading": "Chargement...",
        "passageCopied": "Passage entier copié !",
        "referenceCopied": "Référence copiée !",
        "selectPassage": "Sélectionnez un livre et un chapitre pour commencer à lire",
        "settings": "Paramètres",
        "theme": "Thème",
        "themeDark": "Sombre",
        "themeLight": "Clair",
        "themeSepia": "Sépia",
        "themeSystem": "Système",
        "to": "À",
        "unableToLoad": "Échec du chargement des versets",
        "verse": "Vers",
        "verseCopied": "Texte du verset copié !",
        "version": "Version"
    },
    "he": {
        "bible": "תנ\"ך",
        "book": "ספר",
        "chapter": "פרק",
        "chapterNotFound": "הפרק לא נמצא בגרסה זו",
        "choosePassage": "בחר ספר ופרק כדי להתחיל לקרוא",
        "copy": "העתק",
        "deleteAllDownloads": "מחק הכל",
        "deleteDownload": "מחק הורדה",
        "download": "הורד",
        "downloadComplete": "ההורדה הושלמה!",
        "downloadManager": "מנהל הורדות",
        "downloaded": "הורד",
        "downloading": "מוריד...",
        "exHtml": "יוצא ל-HTML!",
        "exMarkdown": "יוצא ל-Markdown!",
        "exportHtml": "ייצא ל-HTML",
        "exportMarkdown": "ייצא ל-Markdown",
        "failedToLoad": "טעינת הפסוקים נכשלה",
        "fetchingWord": "טוען את דבר אלוהים...",
        "fontSize": "גודל גופן",
        "fontSizePt": "%dpt",
        "from": "מ-",
        "language": "שפה",
        "loading": "טוען...",
        "passageCopied": "הקטע כולו הועתק!",
        "referenceCopied": "ההפניה הועתקה!",
        "selectPassage": "בחר ספר ופרק כדי להתחיל לקרוא",
        "settings": "הגדרות",
        "theme": "ערכת נושא",
        "themeDark": "כהה",
        "themeLight": "בהיר",
        "themeSepia": "ספיה",
        "themeSystem": "מערכת",
        "to": "עד",
        "unableToLoad": "טעינת הפסוקים נכשלה",
        "verse": "פסוק",
        "verseCopied": "טקסט הפסוק הועתק!",
        "version": "גרסה"
    },
    "hi": {
        "bible": "बाइबल",
        "book": "पुस्तक",
        "chapter": "अध्याय",
        "chapterNotFound": "इस संस्करण में अध्याय नहीं मिला",
        "choosePassage": "पढ़ना शुरू करने के लिए कोई पुस्तक और अध्याय चुनें",
        "copy": "कॉपी करें",
        "deleteAllDownloads": "सभी हटाएँ",
        "deleteDownload": "डाउनलोड हटाएँ",
        "download": "डाउनलोड",
        "downloadComplete": "डाउनलोड पूर्ण!",
        "downloadManager": "डाउनलोड प्रबंधक",
        "downloaded": "डाउनलोड हुआ",
        "downloading": "डाउनलोड हो रहा है...",
        "exHtml": "HTML में निर्यात हुआ!",
        "exMarkdown": "Markdown में निर्यात किया गया!",
        "exportHtml": "HTML में निर्यात करें",
        "exportMarkdown": "Markdown में निर्यात करें",
        "failedToLoad": "पद्य लोड करने में विफल",
        "fetchingWord": "परमेश्वर का वचन लोड हो रहा है...",
        "fontSize": "फ़ॉन्ट आकार",
        "fontSizePt": "%dpt",
        "from": "से",
        "language": "भाषा",
        "loading": "लोड हो रहा है...",
        "passageCopied": "पूरा अंश कॉपी हो गया!",
        "referenceCopied": "संदर्भ कॉपी हो गया!",
        "selectPassage": "पढ़ना शुरू करने के लिए कोई पुस्तक और अध्याय चुनें",
        "settings": "सेटिंग्स",
        "theme": "थीम",
        "themeDark": "गहरा",
        "themeLight": "हल्का",
        "themeSepia": "सेपिया",
        "themeSystem": "सिस्टम",
        "to": "तक",
        "unableToLoad": "पद्य लोड करने में विफल",
        "verse": "पद",
        "verseCopied": "पद्य टेक्स्ट कॉपी हो गया!",
        "version": "संस्करण"
    },
    "id": {
        "bible": "Alkitab",
        "book": "Kitab",
        "chapter": "Pasal",
        "chapterNotFound": "Pasal tidak ditemukan dalam versi ini",
        "choosePassage": "Pilih kitab dan pasal untuk mulai membaca",
        "copy": "Salin",
        "deleteAllDownloads": "Hapus Semua",
        "deleteDownload": "Hapus Unduhan",
        "download": "Unduh",
        "downloadComplete": "Unduhan Selesai!",
        "downloadManager": "Manajer Unduhan",
        "downloaded": "Terunduh",
        "downloading": "Mengunduh...",
        "exHtml": "Diekspor ke HTML!",
        "exMarkdown": "Diekspor ke Markdown!",
        "exportHtml": "Ekspor ke HTML",
        "exportMarkdown": "Ekspor ke Markdown",
        "failedToLoad": "Gagal memuat ayat",
        "fetchingWord": "Memuat Firman Tuhan...",
        "fontSize": "Ukuran Huruf",
        "fontSizePt": "%dpt",
        "from": "Dari",
        "language": "Bahasa",
        "loading": "Memuat...",
        "passageCopied": "Seluruh bagian disalin!",
        "referenceCopied": "Referensi disalin!",
        "selectPassage": "Pilih kitab dan pasal untuk mulai membaca",
        "settings": "Pengaturan",
        "theme": "Tema",
        "themeDark": "Gelap",
        "themeLight": "Terang",
        "themeSepia": "Sepia",
        "themeSystem": "Sistem",
        "to": "Sampai",
        "unableToLoad": "Gagal memuat ayat",
        "verse": "Ayat",
        "verseCopied": "Teks ayat disalin!",
        "version": "Versi"
    },
    "it": {
        "bible": "Bibbia",
        "book": "Libro",
        "chapter": "Capitolo",
        "chapterNotFound": "Capitolo non trovato in questa versione",
        "choosePassage": "Seleziona un libro e un capitolo per iniziare a leggere",
        "copy": "Copia",
        "deleteAllDownloads": "Elimina tutto",
        "deleteDownload": "Elimina download",
        "download": "Scarica",
        "downloadComplete": "Download completato!",
        "downloadManager": "Gestore download",
        "downloaded": "Scaricato",
        "downloading": "Download in corso...",
        "exHtml": "Esportato come HTML!",
        "exMarkdown": "Esportato in Markdown!",
        "exportHtml": "Esporta come HTML",
        "exportMarkdown": "Esporta in Markdown",
        "failedToLoad": "Impossibile caricare i versetti",
        "fetchingWord": "Caricamento della Parola di Dio...",
        "fontSize": "Dimensione carattere",
        "fontSizePt": "%dpt",
        "from": "Da",
        "language": "Lingua",
        "loading": "Caricamento...",
        "passageCopied": "Intero passo copiato!",
        "referenceCopied": "Riferimento copiato!",
        "selectPassage": "Seleziona un libro e un capitolo per iniziare a leggere",
        "settings": "Impostazioni",
        "theme": "Tema",
        "themeDark": "Scuro",
        "themeLight": "Chiaro",
        "themeSepia": "Seppia",
        "themeSystem": "Sistema",
        "to": "A",
        "unableToLoad": "Impossibile caricare i versetti",
        "verse": "Versetto",
        "verseCopied": "Testo del versetto copiato!",
        "version": "Versione"
    },
    "ja": {
        "bible": "聖書",
        "book": "書名",
        "chapter": "章",
        "chapterNotFound": "この翻訳では章が見つかりません",
        "choosePassage": "書と章を選択して読書を開始",
        "copy": "コピー",
        "deleteAllDownloads": "すべて削除",
        "deleteDownload": "ダウンロードを削除",
        "download": "ダウンロード",
        "downloadComplete": "ダウンロード完了！",
        "downloadManager": "ダウンロードマネージャー",
        "downloaded": "ダウンロード済み",
        "downloading": "ダウンロード中...",
        "exHtml": "HTMLにエクスポートしました！",
        "exMarkdown": "Markdownにエクスポートしました！",
        "exportHtml": "HTMLにエクスポート",
        "exportMarkdown": "Markdownにエクスポート",
        "failedToLoad": "聖句の読み込みに失敗しました",
        "fetchingWord": "神の言葉を読み込み中...",
        "fontSize": "フォントサイズ",
        "fontSizePt": "%dpt",
        "from": "から",
        "language": "言語",
        "loading": "読み込み中...",
        "passageCopied": "全文をコピーしました！",
        "referenceCopied": "参照をコピーしました！",
        "selectPassage": "書と章を選択して読書を開始",
        "settings": "設定",
        "theme": "テーマ",
        "themeDark": "ダーク",
        "themeLight": "ライト",
        "themeSepia": "セピア",
        "themeSystem": "システム",
        "to": "まで",
        "unableToLoad": "聖句の読み込みに失敗しました",
        "verse": "節",
        "verseCopied": "聖句テキストをコピーしました！",
        "version": "翻訳"
    },
    "nl": {
        "bible": "Bijbel",
        "book": "Boek",
        "chapter": "Hoofdstuk",
        "chapterNotFound": "Hoofdstuk niet gevonden in deze vertaling",
        "choosePassage": "Selecteer een boek en hoofdstuk om te beginnen lezen",
        "copy": "Kopieër",
        "deleteAllDownloads": "Alles verwijderen",
        "deleteDownload": "Download verwijderen",
        "download": "Downloaden",
        "downloadComplete": "Download voltooid!",
        "downloadManager": "Downloadbeheer",
        "downloaded": "Gedownload",
        "downloading": "Bezig met downloaden...",
        "exHtml": "Geëxporteerd naar HTML!",
        "exMarkdown": "Geëxporteerd naar Markdown!",
        "exportHtml": "Exporteren naar HTML",
        "exportMarkdown": "Exporteren naar Markdown",
        "failedToLoad": "Kon verzen niet laden",
        "fetchingWord": "Gods Woord laden...",
        "fontSize": "Lettergrootte",
        "fontSizePt": "%dpt",
        "from": "Van",
        "language": "Taal",
        "loading": "Laden...",
        "passageCopied": "Hele passage gekopieerd!",
        "referenceCopied": "Referentie gekopieerd!",
        "selectPassage": "Selecteer een boek en hoofdstuk om te beginnen lezen",
        "settings": "Instellingen",
        "theme": "Thema",
        "themeDark": "Donker",
        "themeLight": "Licht",
        "themeSepia": "Sepia",
        "themeSystem": "Systeem",
        "to": "Tot",
        "unableToLoad": "Kon verzen niet laden",
        "verse": "Vers",
        "verseCopied": "Vers tekst gekopieerd!",
        "version": "Vertaling"
    },
    "pl": {
        "bible": "Biblia",
        "book": "Księga",
        "chapter": "Rozdział",
        "chapterNotFound": "Nie znaleziono rozdziału w tym przekładzie",
        "choosePassage": "Wybierz księgę i rozdział, aby rozpocząć czytanie",
        "copy": "Kopiuj",
        "deleteAllDownloads": "Usuń wszystko",
        "deleteDownload": "Usuń pobieranie",
        "download": "Pobierz",
        "downloadComplete": "Pobieranie zakończone!",
        "downloadManager": "Menedżer pobierania",
        "downloaded": "Pobrano",
        "downloading": "Pobieranie...",
        "exHtml": "Wyeksportowano do HTML!",
        "exMarkdown": "Wyeksportowano do Markdown!",
        "exportHtml": "Eksportuj do HTML",
        "exportMarkdown": "Eksportuj do Markdown",
        "failedToLoad": "Nie udało się załadować wersetów",
        "fetchingWord": "Ładowanie Słowa Bożego...",
        "fontSize": "Rozmiar czcionki",
        "fontSizePt": "%dpt",
        "from": "Od",
        "language": "Język",
        "loading": "Ładowanie...",
        "passageCopied": "Cały fragment skopiowany!",
        "referenceCopied": "Referencja skopiowana!",
        "selectPassage": "Wybierz księgę i rozdział, aby rozpocząć czytanie",
        "settings": "Ustawienia",
        "theme": "Motyw",
        "themeDark": "Ciemny",
        "themeLight": "Jasny",
        "themeSepia": "Sepia",
        "themeSystem": "Systemowy",
        "to": "Do",
        "unableToLoad": "Nie udało się załadować wersetów",
        "verse": "Werset",
        "verseCopied": "Tekst wersetu skopiowany!",
        "version": "Przekład"
    },
    "pt": {
        "bible": "Bíblia",
        "book": "Livro",
        "chapter": "Capítulo",
        "chapterNotFound": "Capítulo não encontrado nesta versão",
        "choosePassage": "Selecione um livro e capítulo para começar a ler",
        "copy": "Copiar",
        "deleteAllDownloads": "Excluir tudo",
        "deleteDownload": "Excluir download",
        "download": "Baixar",
        "downloadComplete": "Download concluído!",
        "downloadManager": "Gerenciador de downloads",
        "downloaded": "Baixado",
        "downloading": "Baixando...",
        "exHtml": "Exportado para HTML!",
        "exMarkdown": "Exportado para Markdown!",
        "exportHtml": "Exportar para HTML",
        "exportMarkdown": "Exportar para Markdown",
        "failedToLoad": "Falha ao carregar versículos",
        "fetchingWord": "Carregando a Palavra de Deus...",
        "fontSize": "Tamanho da fonte",
        "fontSizePt": "%dpt",
        "from": "De",
        "language": "Idioma",
        "loading": "Carregando...",
        "passageCopied": "Passagem inteira copiada!",
        "referenceCopied": "Referência copiada!",
        "selectPassage": "Selecione um livro e capítulo para começar a ler",
        "settings": "Configurações",
        "theme": "Tema",
        "themeDark": "Escuro",
        "themeLight": "Claro",
        "themeSepia": "Sépia",
        "themeSystem": "Sistema",
        "to": "Até",
        "unableToLoad": "Falha ao carregar versículos",
        "verse": "Versículo",
        "verseCopied": "Texto do versículo copiado!",
        "version": "Versão"
    },
    "ro": {
        "bible": "Biblia",
        "book": "Cartea",
        "chapter": "Capitolul",
        "chapterNotFound": "Capitolul nu a fost găsit în această versiune",
        "choosePassage": "Selectează o carte și un capitol pentru a începe citirea",
        "copy": "Copiază",
        "deleteAllDownloads": "Șterge tot",
        "deleteDownload": "Șterge descărcarea",
        "download": "Descarcă",
        "downloadComplete": "Descărcare completă!",
        "downloadManager": "Manager de descărcări",
        "downloaded": "Descărcat",
        "downloading": "Se descarcă...",
        "exHtml": "Exportat ca HTML!",
        "exMarkdown": "Exportat în Markdown!",
        "exportHtml": "Exportă ca HTML",
        "exportMarkdown": "Exportă în Markdown",
        "failedToLoad": "Nu s-au putut încărca versetele",
        "fetchingWord": "Se încarcă Cuvântul lui Dumnezeu...",
        "fontSize": "Mărime font",
        "fontSizePt": "%dpt",
        "from": "De la",
        "language": "Limba",
        "loading": "Se încarcă...",
        "passageCopied": "Întregul pasaj copiat!",
        "referenceCopied": "Referință copiată!",
        "selectPassage": "Selectează o carte și un capitol pentru a începe citirea",
        "settings": "Setări",
        "theme": "Temă",
        "themeDark": "Întunecat",
        "themeLight": "Deschis",
        "themeSepia": "Sepia",
        "themeSystem": "Sistem",
        "to": "Până la",
        "unableToLoad": "Nu s-au putut încărca versetele",
        "verse": "Vers",
        "verseCopied": "Textul versetului copiat!",
        "version": "Versiunea"
    },
    "ru": {
        "bible": "Библия",
        "book": "Книга",
        "chapter": "Глава",
        "chapterNotFound": "Глава не найдена в этом переводе",
        "choosePassage": "Выберите книгу и главу, чтобы начать чтение",
        "copy": "Копировать",
        "deleteAllDownloads": "Удалить всё",
        "deleteDownload": "Удалить загрузку",
        "download": "Скачать",
        "downloadComplete": "Загрузка завершена!",
        "downloadManager": "Менеджер загрузок",
        "downloaded": "Загружено",
        "downloading": "Загрузка...",
        "exHtml": "Экспортировано в HTML!",
        "exMarkdown": "Экспортировано в Markdown!",
        "exportHtml": "Экспорт в HTML",
        "exportMarkdown": "Экспорт в Markdown",
        "failedToLoad": "Не удалось загрузить стихи",
        "fetchingWord": "Загрузка Слова Божьего...",
        "fontSize": "Размер шрифта",
        "fontSizePt": "%dpt",
        "from": "От",
        "language": "Язык",
        "loading": "Загрузка...",
        "passageCopied": "Весь отрывок скопирован!",
        "referenceCopied": "Ссылка скопирована!",
        "selectPassage": "Выберите книгу и главу, чтобы начать чтение",
        "settings": "Настройки",
        "theme": "Тема",
        "themeDark": "Тёмная",
        "themeLight": "Светлая",
        "themeSepia": "Сепия",
        "themeSystem": "Системная",
        "to": "До",
        "unableToLoad": "Не удалось загрузить стихи",
        "verse": "Стих",
        "verseCopied": "Текст стиха скопирован!",
        "version": "Перевод"
    },
    "sw": {
        "bible": "Biblia",
        "book": "Kitabu",
        "chapter": "Sura",
        "chapterNotFound": "Sura haijapatikana katika tafsiri hii",
        "choosePassage": "Chagua kitabu na sura kuanza kusoma",
        "copy": "Nakili",
        "deleteAllDownloads": "Futa Zote",
        "deleteDownload": "Futa Upakuaji",
        "download": "Pakua",
        "downloadComplete": "Upakuaji Umekamilika!",
        "downloadManager": "Kidhibiti Upakuaji",
        "downloaded": "Imepakuliwa",
        "downloading": "Inapakua...",
        "exHtml": "Imehamishwa kwa HTML!",
        "exMarkdown": "Imehamishwa kwa Markdown!",
        "exportHtml": "Hamisha kwa HTML",
        "exportMarkdown": "Hamisha kwa Markdown",
        "failedToLoad": "Imeshindwa kupakia aya",
        "fetchingWord": "Inapakia Neno la Mungu...",
        "fontSize": "Ukubwa wa Herufi",
        "fontSizePt": "%dpt",
        "from": "Kutoka",
        "language": "Lugha",
        "loading": "Inapakia...",
        "passageCopied": "Kifungu kizima kimenakiliwa!",
        "referenceCopied": "Rejea imenakiliwa!",
        "selectPassage": "Chagua kitabu na sura kuanza kusoma",
        "settings": "Mipangilio",
        "theme": "Mandhari",
        "themeDark": "Giza",
        "themeLight": "Mwanga",
        "themeSepia": "Sepia",
        "themeSystem": "Mfumo",
        "to": "Hadi",
        "unableToLoad": "Imeshindwa kupakia aya",
        "verse": "Aya",
        "verseCopied": "Maandishi ya aya yamenakiliwa!",
        "version": "Tafsiri"
    },
    "tl": {
        "bible": "Bibliya",
        "book": "Aklat",
        "chapter": "Kabanata",
        "chapterNotFound": "Hindi natagpuan ang kabanata sa bersyong ito",
        "choosePassage": "Pumili ng aklat at kabanata upang magsimulang magbasa",
        "copy": "Kopyahin",
        "deleteAllDownloads": "Burahin Lahat",
        "deleteDownload": "Burahin ang Pag-download",
        "download": "I-download",
        "downloadComplete": "Kumpleto ang Pag-download!",
        "downloadManager": "Tagapamahala ng Pag-download",
        "downloaded": "Na-download",
        "downloading": "Nagda-download...",
        "exHtml": "Na-export sa HTML!",
        "exMarkdown": "Na-export sa Markdown!",
        "exportHtml": "I-export sa HTML",
        "exportMarkdown": "I-export sa Markdown",
        "failedToLoad": "Hindi na-load ang mga talata",
        "fetchingWord": "Naglo-load ng Salita ng Diyos...",
        "fontSize": "Laki ng Font",
        "fontSizePt": "%dpt",
        "from": "Mula",
        "language": "Wika",
        "loading": "Naglo-load...",
        "passageCopied": "Ang buong talata ay nakopya!",
        "referenceCopied": "Ang reference ay nakopya!",
        "selectPassage": "Pumili ng aklat at kabanata upang magsimulang magbasa",
        "settings": "Mga Setting",
        "theme": "Tema",
        "themeDark": "Madilim",
        "themeLight": "Maliwanag",
        "themeSepia": "Sepia",
        "themeSystem": "Sistema",
        "to": "Hanggang",
        "unableToLoad": "Hindi na-load ang mga talata",
        "verse": "Talata",
        "verseCopied": "Ang teksto ng talata ay nakopya!",
        "version": "Bersyon"
    },
    "vi": {
        "bible": "Kinh Thánh",
        "book": "Sách",
        "chapter": "Chương",
        "chapterNotFound": "Không tìm thấy chương trong phiên bản này",
        "choosePassage": "Chọn sách và chương để bắt đầu đọc",
        "copy": "Sao chép",
        "deleteAllDownloads": "Xóa tất cả",
        "deleteDownload": "Xóa tải xuống",
        "download": "Tải xuống",
        "downloadComplete": "Tải xuống hoàn tất!",
        "downloadManager": "Trình quản lý tải xuống",
        "downloaded": "Đã tải xuống",
        "downloading": "Đang tải xuống...",
        "exHtml": "Đã xuất ra HTML!",
        "exMarkdown": "Đã xuất sang Markdown!",
        "exportHtml": "Xuất ra HTML",
        "exportMarkdown": "Xuất sang Markdown",
        "failedToLoad": "Không thể tải câu",
        "fetchingWord": "Đang tải Lời Chúa...",
        "fontSize": "Cỡ chữ",
        "fontSizePt": "%dpt",
        "from": "Từ",
        "language": "Ngôn ngữ",
        "loading": "Đang tải...",
        "passageCopied": "Đã sao chép toàn bộ đoạn!",
        "referenceCopied": "Đã sao chép tham chiếu!",
        "selectPassage": "Chọn sách và chương để bắt đầu đọc",
        "settings": "Cài đặt",
        "theme": "Chủ đề",
        "themeDark": "Tối",
        "themeLight": "Sáng",
        "themeSepia": "Nâu đỏ",
        "themeSystem": "Hệ thống",
        "to": "Đến",
        "unableToLoad": "Không thể tải câu",
        "verse": "Câu",
        "verseCopied": "Đã sao chép nội dung câu!",
        "version": "Phiên bản"
    },
    "zh": {
        "bible": "圣经",
        "book": "书卷",
        "chapter": "章",
        "chapterNotFound": "此版本中未找到该章节",
        "choosePassage": "选择书卷和章节开始阅读",
        "copy": "复制",
        "deleteAllDownloads": "全部删除",
        "deleteDownload": "删除下载",
        "download": "下载",
        "downloadComplete": "下载完成！",
        "downloadManager": "下载管理器",
        "downloaded": "已下载",
        "downloading": "下载中...",
        "exHtml": "已导出为HTML！",
        "exMarkdown": "已导出为Markdown！",
        "exportHtml": "导出为HTML",
        "exportMarkdown": "导出为Markdown",
        "failedToLoad": "加载经文失败",
        "fetchingWord": "正在加载神的话语...",
        "fontSize": "字号",
        "fontSizePt": "%dpt",
        "from": "从",
        "language": "语言",
        "loading": "加载中...",
        "passageCopied": "整段已复制！",
        "referenceCopied": "引用已复制！",
        "selectPassage": "选择书卷和章节开始阅读",
        "settings": "设置",
        "theme": "主题",
        "themeDark": "深色",
        "themeLight": "浅色",
        "themeSepia": "棕褐色",
        "themeSystem": "系统",
        "to": "至",
        "unableToLoad": "加载经文失败",
        "verse": "节",
        "verseCopied": "经文文本已复制！",
        "version": "版本"
    },
    "en": {
        "ap": "Appearance",
        "bible": "Bible",
        "book": "Book",
        "chapter": "Chapter",
        "chapterNotFound": "Chapter not found in this version",
        "choosePassage": "Choose a passage to begin.",
        "copy": "Copy",
        "deleteAllDownloads": "Delete All",
        "deleteDownload": "Delete Download",
        "done": "Done",
        "download": "Download",
        "downloadComplete": "Download Complete!",
        "downloadManager": "Download Manager",
        "downloaded": "Downloaded",
        "downloading": "Downloading...",
        "exHtml": "Exported to HTML!",
        "exMarkdown": "Exported to Markdown!",
        "exportHTML": "Export HTML",
        "exportHtml": "Export to HTML",
        "exportMD": "Export MD",
        "exportMarkdown": "Export to Markdown",
        "failedToLoad": "Failed to load verses",
        "fetchingWord": "Fetching God's Word...",
        "fontSize": "Font Size",
        "fontSizePt": "%dpt",
        "fontSizePtLabel": "%dpx",
        "from": "From",
        "generatedBy": "Generated by Sharer's Bible",
        "language": "Language",
        "loading": "Loading...",
        "passageCopied": "Entire passage copied!",
        "referenceCopied": "Reference copied!",
        "refresh": "Refresh",
        "retry": "Retry",
        "savePanelMessage": "Choose where to save your Bible passage",
        "selectPassage": "Select a passage to begin reading.",
        "settings": "Settings",
        "source": "Source",
        "theme": "Theme",
        "themeDark": "Dark",
        "themeLight": "Light",
        "themeSepia": "Sepia",
        "themeSystem": "System",
        "to": "To",
        "unableToLoad": "Unable to load passage",
        "verse": "Verse",
        "verseCopied": "Verse text copied!",
        "version": "Version"
    }
}


LOCALIZED_BOOKS = {
    "en": ["Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi","Matthew","Mark","Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John","Jude","Revelation"],
    "af": ["Genesis","Eksodus","Levitikus","Numeri","Deuteronomium","Josua","Rigters","Rut","1 Samuel","2 Samuel","1 Konings","2 Konings","1 Kronieke","2 Kronieke","Esra","Nehemia","Ester","Job","Psalms","Spreuke","Prediker","Hooglied","Jesaja","Jeremia","Klaagliedere","Esegiël","Daniël","Hosea","Joël","Amos","Obadja","Jona","Miga","Nahum","Habakuk","Sefanja","Haggai","Sagaria","Maleagi","Matteus","Markus","Lukas","Johannes","Handelinge","Romeine","1 Korintiërs","2 Korintiërs","Galasiërs","Efesiërs","Filippense","Kolossense","1 Tessalonisense","2 Tessalonisense","1 Timoteus","2 Timoteus","Titus","Filemon","Hebreërs","Jakobus","1 Petrus","2 Petrus","1 Johannes","2 Johannes","3 Johannes","Judas","Openbaring"],
    "ar": ["تكوين","خروج","لاويين","عدد","تثنية","يشوع","قضاة","راعوث","1 صموئيل","2 صموئيل","1 ملوك","2 ملوك","1 أخبار","2 أخبار","عزرا","نحميا","أستير","أيوب","مزامير","أمثال","جامعة","نشيد الأنشاد","إشعياء","إرميا","مراثي إرميا","حزقيال","دانيال","هوشع","يوئيل","عاموس","عوبديا","يونان","ميخا","ناحوم","حبقوق","صفنيا","حجي","زكريا","ملاخي","متى","مرقس","لوقا","يوحنا","أعمال","رومية","1 كورنثوس","2 كورنثوس","غلاطية","أفسس","فيلبي","كولوسي","1 تسالونيكي","2 تسالونيكي","1 تيموثاوس","2 تيموثاوس","تيتوس","فليمون","عبرانيين","يعقوب","1 بطرس","2 بطرس","1 يوحنا","2 يوحنا","3 يوحنا","يهوذا","رؤيا"],
    "de": ["1. Mose","2. Mose","3. Mose","4. Mose","5. Mose","Josua","Richter","Rut","1. Samuel","2. Samuel","1. Könige","2. Könige","1. Chronik","2. Chronik","Esra","Nehemia","Esther","Hiob","Psalmen","Sprüche","Prediger","Hohelied","Jesaja","Jeremia","Klagelieder","Hesekiel","Daniel","Hosea","Joel","Amos","Obadja","Jona","Micha","Nahum","Habakuk","Zephanja","Haggai","Sacharja","Maleachi","Matthäus","Markus","Lukas","Johannes","Apostelgeschichte","Römer","1. Korinther","2. Korinther","Galater","Epheser","Philipper","Kolosser","1. Thessalonicher","2. Thessalonicher","1. Timotheus","2. Timotheus","Titus","Philemon","Hebräer","Jakobus","1. Petrus","2. Petrus","1. Johannes","2. Johannes","3. Johannes","Judas","Offenbarung"],
    "es": ["Génesis","Éxodo","Levítico","Números","Deuteronomio","Josué","Jueces","Rut","1 Samuel","2 Samuel","1 Reyes","2 Reyes","1 Crónicas","2 Crónicas","Esdras","Nehemías","Ester","Job","Salmos","Proverbios","Eclesiastés","Cantares","Isaías","Jeremías","Lamentaciones","Ezequiel","Daniel","Oseas","Joel","Amós","Abdías","Jonás","Miqueas","Nahum","Habacuc","Sofonías","Hageo","Zacarías","Malaquías","Mateo","Marcos","Lucas","Juan","Hechos","Romanos","1 Corintios","2 Corintios","Gálatas","Efesios","Filipenses","Colosenses","1 Tesalonicenses","2 Tesalonicenses","1 Timoteo","2 Timoteo","Tito","Filemón","Hebreos","Santiago","1 Pedro","2 Pedro","1 Juan","2 Juan","3 Juan","Judas","Apocalipsis"],
    "fi": ["1. Mooseksen kirja","2. Mooseksen kirja","3. Mooseksen kirja","4. Mooseksen kirja","5. Mooseksen kirja","Joosua","Tuomarien kirja","Ruutin kirja","1. Samuelin kirja","2. Samuelin kirja","1. Kuninkaiden kirja","2. Kuninkaiden kirja","1. Aikakirja","2. Aikakirja","Esran kirja","Nehemian kirja","Esterin kirja","Jobin kirja","Psalmit","Sananlaskut","Saarnaaja","Laulujen laulu","Jesajan kirja","Jeremian kirja","Valitusvirret","Hesekielin kirja","Danielin kirja","Hoosean kirja","Joelin kirja","Aamoksen kirja","Obadjan kirja","Joonan kirja","Miikan kirja","Nahumin kirja","Habakukin kirja","Sefanjan kirja","Haggain kirja","Sakarjan kirja","Malakian kirja","Matteuksen evankeliumi","Markuksen evankeliumi","Luukkaan evankeliumi","Johanneksen evankeliumi","Apostolien teot","Roomalaiskirje","1. Korinttolaiskirje","2. Korinttolaiskirje","Galatalaiskirje","Efesolaiskirje","Filippiläiskirje","Kolossalaiskirje","1. Tessalonikalaiskirje","2. Tessalonikalaiskirje","1. Timoteuskirje","2. Timoteuskirje","Tiituksen kirje","Filemonin kirje","Heprealaiskirje","Jaakobin kirje","1. Pietarin kirje","2. Pietarin kirje","1. Johanneksen kirje","2. Johanneksen kirje","3. Johanneksen kirje","Juudaksen kirje","Johanneksen ilmestys"],
    "fr": ["Genèse","Exode","Lévitique","Nombres","Deutéronome","Josué","Juges","Ruth","1 Samuel","2 Samuel","1 Rois","2 Rois","1 Chroniques","2 Chroniques","Esdras","Néhémie","Esther","Job","Psaumes","Proverbes","Ecclésiaste","Cantique des Cantiques","Ésaïe","Jérémie","Lamentations","Ézéchiel","Daniel","Osée","Joël","Amos","Abdias","Jonas","Michée","Nahum","Habacuc","Sophonie","Aggée","Zacharie","Malachie","Matthieu","Marc","Luc","Jean","Actes","Romains","1 Corinthiens","2 Corinthiens","Galates","Éphésiens","Philippiens","Colossiens","1 Thessaloniciens","2 Thessaloniciens","1 Timothée","2 Timothée","Tite","Philémon","Hébreux","Jacques","1 Pierre","2 Pierre","1 Jean","2 Jean","3 Jean","Jude","Apocalypse"],
    "he": ["בראשית","שמות","ויקרא","במדבר","דברים","יהושע","שופטים","רות","שמואל א","שמואל ב","מלכים א","מלכים ב","דברי הימים א","דברי הימים ב","עזרא","נחמיה","אסתר","איוב","תהלים","משלי","קהלת","שיר השירים","ישעיהו","ירמיהו","איכה","יחזקאל","דניאל","הושע","יואל","עמוס","עובדיה","יונה","מיכה","נחום","חבקוק","צפניה","חגי","זכריה","מלאכי","מתי","מרקוס","לוקס","יוחנן","מעשי השליחים","אל הרומים","1 אל הקורינתים","2 אל הקורינתים","אל הגלטים","אל האפסים","אל הפיליפים","אל הקולוסים","1 אל התסלוניקים","2 אל התסלוניקים","1 אל טימותיוס","2 אל טימותיוס","אל טיטוס","אל פילימון","אל העברים","אגרת יעקב","1 כיפא","2 כיפא","1 יוחנן","2 יוחנן","3 יוחנן","אגרת יהודה","חזון יוחנן"],
    "hi": ["उत्पत्ति","निर्गमन","लैव्यव्यवस्था","गिनती","व्यवस्थाविवरण","यहोशू","न्यायियों","रूत","1 शमूएल","2 शमूएल","1 राजा","2 राजा","1 इतिहास","2 इतिहास","एज्रा","नहेम्याह","एस्तेर","अय्यूब","भजन संहिता","नीतिवचन","सभोपदेशक","श्रेष्ठगीत","यशायाह","यिर्मयाह","विलापगीत","यहेजकेल","दानिय्येल","होशे","योएल","आमोस","ओबद्याह","योना","मीका","नहूम","हबक्कूक","सपन्याह","हाग्गै","जकर्याह","मलाकी","मत्ती","मरकुस","लूका","यूहन्ना","प्रेरितों के काम","रोमियों","1 कुरिन्थियों","2 कुरिन्थियों","गलातियों","इफिसियों","फिलिप्पियों","कुलुस्सियों","1 थिस्सलुनीकियों","2 थिस्सलुनीकियों","1 तीमुथियुस","2 तीमुथियुस","तीतुस","फिलेमोन","इब्रानियों","याकूब","1 पतरस","2 पतरस","1 यूहन्ना","2 यूहन्ना","3 यूहन्ना","यहूदा","प्रकाशितवाक्य"],
    "id": ["Kejadian","Keluaran","Imamat","Bilangan","Ulangan","Yosua","Hakim-hakim","Rut","1 Samuel","2 Samuel","1 Raja-raja","2 Raja-raja","1 Tawarikh","2 Tawarikh","Ezra","Nehemia","Ester","Ayub","Mazmur","Amsal","Pengkhotbah","Kidung Agung","Yesaya","Yeremia","Ratapan","Yehezkiel","Daniel","Hosea","Yoel","Amos","Obaja","Yunus","Mikha","Nahum","Habakuk","Zefanya","Hagai","Zakharia","Maleakhi","Matius","Markus","Lukas","Yohanes","Kisah Para Rasul","Roma","1 Korintus","2 Korintus","Galatia","Efesus","Filipi","Kolose","1 Tesalonika","2 Tesalonika","1 Timotius","2 Timotius","Titus","Filemon","Ibrani","Yakobus","1 Petrus","2 Petrus","1 Yohanes","2 Yohanes","3 Yohanes","Yudas","Wahyu"],
    "it": ["Genesi","Esodo","Levitico","Numeri","Deuteronomio","Giosuè","Giudici","Rut","1 Samuele","2 Samuele","1 Re","2 Re","1 Cronache","2 Cronache","Esdra","Neemia","Ester","Giobbe","Salmi","Proverbi","Ecclesiaste","Cantico dei Cantici","Isaia","Geremia","Lamentazioni","Ezechiele","Daniele","Osea","Gioele","Amos","Abdia","Giona","Michea","Naum","Abacuc","Sofonia","Aggeo","Zaccaria","Malachia","Matteo","Marco","Luca","Giovanni","Atti","Romani","1 Corinzi","2 Corinzi","Galati","Efesini","Filippesi","Colossesi","1 Tessalonicesi","2 Tessalonicesi","1 Timoteo","2 Timoteo","Tito","Filemone","Ebrei","Giacomo","1 Pietro","2 Pietro","1 Giovanni","2 Giovanni","3 Giovanni","Giuda","Apocalisse"],
    "ja": ["創世記","出エジプト記","レビ記","民数記","申命記","ヨシュア記","士師記","ルツ記","サムエル記上","サムエル記下","列王記上","列王記下","歴代志上","歴代志下","エズラ記","ネヘミヤ記","エステル記","ヨブ記","詩篇","箴言","伝道者の書","雅歌","イザヤ書","エレミヤ書","哀歌","エゼキエル書","ダニエル書","ホセア書","ヨエル書","アモス書","オバデヤ書","ヨナ書","ミカ書","ナホム書","ハバクク書","ゼパニヤ書","ハガイ書","ゼカリヤ書","マラキ書","マタイの福音書","マルコの福音書","ルカの福音書","ヨハネの福音書","使徒の働き","ローマ人への手紙","コリント人への手紙第一","コリント人への手紙第二","ガラテヤ人への手紙","エペソ人への手紙","ピリピ人への手紙","コロサイ人への手紙","テサロニケ人への手紙第一","テサロニケ人への手紙第二","テモテへの手紙第一","テモテへの手紙第二","テトスへの手紙","ピレモンへの手紙","ヘブル人への手紙","ヤコブの手紙","ペテロの手紙第一","ペテロの手紙第二","ヨハネの手紙第一","ヨハネの手紙第二","ヨハネの手紙第三","ユダの手紙","ヨハネの黙示録"],
    "nl": ["Genesis","Exodus","Leviticus","Numeri","Deuteronomium","Jozua","Rechters","Ruth","1 Samuel","2 Samuel","1 Koningen","2 Koningen","1 Kronieken","2 Kronieken","Ezra","Nehemia","Esther","Job","Psalmen","Spreuken","Prediker","Hooglied","Jesaja","Jeremia","Klaagliederen","Ezechiël","Daniël","Hosea","Joël","Amos","Obadja","Jona","Micha","Nahum","Habakuk","Zefanja","Haggai","Zacharia","Maleachi","Matteüs","Marcus","Lucas","Johannes","Handelingen","Romeinen","1 Korintiërs","2 Korintiërs","Galaten","Efeziërs","Filippenzen","Kolossenzen","1 Tessalonicenzen","2 Tessalonicenzen","1 Timoteüs","2 Timoteüs","Titus","Filemon","Hebreeën","Jakobus","1 Petrus","2 Petrus","1 Johannes","2 Johannes","3 Johannes","Judas","Openbaring"],
    "pl": ["Księga Rodzaju","Księga Wyjścia","Księga Kapłańska","Księga Liczb","Księga Powtórzonego Prawa","Księga Jozuego","Księga Sędziów","Księga Rut","1 Księga Samuela","2 Księga Samuela","1 Księga Królewska","2 Księga Królewska","1 Księga Kronik","2 Księga Kronik","Księga Ezdrasza","Księga Nehemiasza","Księga Estery","Księga Hioba","Księga Psalmów","Księga Przysłów","Księga Koheleta","Pieśń nad Pieśniami","Księga Izajasza","Księga Jeremiasza","Lamentacje","Księga Ezechiela","Księga Daniela","Księga Ozeasza","Księga Joela","Księga Amosa","Księga Abdiasza","Księga Jonasza","Księga Micheasza","Księga Nahuma","Księga Habakuka","Księga Sofoniasza","Księga Aggeusza","Księga Zachariasza","Księga Malachiasza","Ewangelia Mateusza","Ewangelia Marka","Ewangelia Łukasza","Ewangelia Jana","Dzieje Apostolskie","List do Rzymian","1 List do Koryntian","2 List do Koryntian","List do Galatów","List do Efezjan","List do Filipian","List do Kolosan","1 List do Tesaloniczan","2 List do Tesaloniczan","1 List do Tymoteusza","2 List do Tymoteusza","List do Tytusa","List do Filemona","List do Hebrajczyków","List Jakuba","1 List Piotra","2 List Piotra","1 List Jana","2 List Jana","3 List Jana","List Judy","Apokalipsa św. Jana"],
    "pt": ["Gênesis","Êxodo","Levítico","Números","Deuteronômio","Josué","Juízes","Rute","1 Samuel","2 Samuel","1 Reis","2 Reis","1 Crônicas","2 Crônicas","Esdras","Neemias","Ester","Jó","Salmos","Provérbios","Eclesiastes","Cânticos","Isaías","Jeremias","Lamentações","Ezequiel","Daniel","Oseias","Joel","Amós","Obadias","Jonas","Miqueias","Naum","Habacuque","Sofonias","Ageu","Zacarias","Malaquias","Mateus","Marcos","Lucas","João","Atos","Romanos","1 Coríntios","2 Coríntios","Gálatas","Efésios","Filipenses","Colossenses","1 Tessalonicenses","2 Tessalonicenses","1 Timóteo","2 Timóteo","Tito","Filemom","Hebreus","Tiago","1 Pedro","2 Pedro","1 João","2 João","3 João","Judas","Apocalipse"],
    "ro": ["Geneza","Exodul","Leviticul","Numerii","Deuteronomul","Iosua","Judecătorii","Rut","1 Samuel","2 Samuel","1 Regi","2 Regi","1 Cronici","2 Cronici","Ezra","Neemia","Estera","Iov","Psalmii","Proverbe","Eclesiastul","Cântarea Cântărilor","Isaia","Ieremia","Plângerile","Ezechiel","Daniel","Osea","Ioel","Amos","Obadia","Iona","Mica","Naum","Habacuc","Țefania","Hagai","Zaharia","Maleahi","Matei","Marcu","Luca","Ioan","Faptele Apostolilor","Romani","1 Corinteni","2 Corinteni","Galateni","Efeseni","Filipeni","Coloseni","1 Tesaloniceni","2 Tesaloniceni","1 Timotei","2 Timotei","Tit","Filimon","Evrei","Iacov","1 Petru","2 Petru","1 Ioan","2 Ioan","3 Ioan","Iuda","Apocalipsa"],
    "ru": ["Бытие","Исход","Левит","Числа","Второзаконие","Иисус Навин","Книга Судей","Книга Руфь","1-я Царств","2-я Царств","3-я Царств","4-я Царств","1-я Паралипоменон","2-я Паралипоменон","Книга Ездры","Книга Неемии","Книга Есфири","Книга Иова","Псалтирь","Книга Притчей","Книга Екклесиаста","Песнь Песней","Книга Исаии","Книга Иеремии","Плач Иеремии","Книга Иезекииля","Книга Даниила","Книга Осии","Книга Иоиля","Книга Амоса","Книга Авдия","Книга Ионы","Книга Михея","Книга Наума","Книга Аввакума","Книга Софонии","Книга Аггея","Книга Захарии","Книга Малахии","Евангелие от Матфея","Евангелие от Марка","Евангелие от Луки","Евангелие от Иоанна","Деяния апостолов","Послание к Римлянам","1-е послание к Коринфянам","2-е послание к Коринфянам","Послание к Галатам","Послание к Ефесянам","Послание к Филиппийцам","Послание к Колоссянам","1-е послание к Фессалоникийцам","2-е послание к Фессалоникийцам","1-е послание к Тимофею","2-е послание к Тимофею","Послание к Титу","Послание к Филимону","Послание к Евреям","Послание Иакова","1-е послание Петра","2-е послание Петра","1-е послание Иоанна","2-е послание Иоанна","3-е послание Иоанна","Послание Иуды","Откровение Иоанна Богослова"],
    "sw": ["Mwanzo","Kutoka","Mambo ya Walawi","Hesabu","Kumbukumbu la Torati","Yoshua","Waamuzi","Ruthu","1 Samweli","2 Samweli","1 Wafalme","2 Wafalme","1 Mambo ya Nyakati","2 Mambo ya Nyakati","Ezra","Nehemia","Esta","Ayubu","Zaburi","Mithali","Mhubiri","Wimbo Ulio Bora","Isaya","Yeremia","Maombolezo","Ezekieli","Danieli","Hosea","Yoeli","Amosi","Obadia","Yona","Mika","Nahumu","Habakuki","Sefania","Hagai","Zekaria","Malaki","Mathayo","Marko","Luka","Yohana","Matendo","Waroma","1 Wakorintho","2 Wakorintho","Wagalatia","Waefeso","Wafilipi","Wakolosai","1 Wathesalonike","2 Wathesalonike","1 Timotheo","2 Timotheo","Tito","Filemon","Waebrania","Yakobo","1 Petro","2 Petro","1 Yohana","2 Yohana","3 Yohana","Yuda","Ufunuo"],
    "tl": ["Genesis","Exodo","Levitico","Mga Bilang","Deuteronomio","Josue","Mga Hukom","Ruth","1 Samuel","2 Samuel","1 Mga Hari","2 Mga Hari","1 Mga Kronika","2 Mga Kronika","Ezra","Nehemias","Ester","Job","Mga Awit","Mga Kawikaan","Ang Mangangaral","Awit ni Solomon","Isaias","Jeremias","Mga Panaghoy","Ezekiel","Daniel","Oseas","Joel","Amos","Obadias","Jonas","Mikas","Nahum","Habacuc","Sofonias","Ageo","Zacarias","Malakias","Mateo","Marcos","Lucas","Juan","Mga Gawa","Mga Taga-Roma","1 Mga Taga-Corinto","2 Mga Taga-Corinto","Mga Taga-Galacia","Mga Taga-Efeso","Mga Taga-Filipos","Mga Taga-Colosas","1 Mga Taga-Tesalonica","2 Mga Taga-Tesalonica","1 Timoteo","2 Timoteo","Tito","Filemon","Mga Hebreo","Santiago","1 Pedro","2 Pedro","1 Juan","2 Juan","3 Juan","Judas","Pahayag"],
    "vi": ["Sáng Thế Ký","Xuất Ê-díp-tô Ký","Lê-vi Ký","Dân Số Ký","Phục Truyền Luật Lệ Ký","Giô-suê","Các Quan Xét","Ru-tơ","1 Sa-mu-ên","2 Sa-mu-ên","1 Các Vua","2 Các Vua","1 Sử Ký","2 Sử Ký","E-xơ-ra","Nê-hê-mi","Ê-xơ-tê","Gióp","Thánh Thi","Châm Ngôn","Truyền Đạo","Nhã Ca","Ê-sai","Giê-rê-mi","Ca Thương","Ê-xê-chi-ên","Đa-ni-ên","Ô-sê","Giô-ên","A-mốt","Áp-đia","Giô-na","Mi-chê","Na-hum","Ha-ba-cúc","Sô-phô-ni","Ha-gai","Xa-cha-ri","Ma-la-chi","Ma-thi-ơ","Mác","Lu-ca","Giăng","Công Vụ Các Sứ Đồ","Rô-ma","1 Cô-rinh-tô","2 Cô-rinh-tô","Ga-la-ti","Ê-phê-sô","Phi-líp","Cô-lô-se","1 Tê-sa-lô-ni-ca","2 Tê-sa-lô-ni-ca","1 Ti-mô-thê","2 Ti-mô-thê","Tít","Phi-lê-môn","Hê-bơ-rơ","Gia-cơ","1 Phi-e-rơ","2 Phi-e-rơ","1 Giăng","2 Giăng","3 Giăng","Giu-đe","Khải Huyền"],
    "zh": ["创世记","出埃及记","利未记","民数记","申命记","约书亚记","士师记","路得记","撒母耳记上","撒母耳记下","列王纪上","列王纪下","历代志上","历代志下","以斯拉记","尼希米记","以斯帖记","约伯记","诗篇","箴言","传道书","雅歌","以赛亚书","耶利米书","耶利米哀歌","以西结书","但以理书","何西阿书","约珥书","阿摩司书","俄巴底亚书","约拿书","弥迦书","那鸿书","哈巴谷书","西番雅书","哈该书","撒迦利亚书","玛拉基书","马太福音","马可福音","路加福音","约翰福音","使徒行传","罗马书","哥林多前书","哥林多后书","加拉太书","以弗所书","腓立比书","歌罗西书","帖撒罗尼迦前书","帖撒罗尼迦后书","提摩太前书","提摩太后书","提多书","腓利门书","希伯来书","雅各书","彼得前书","彼得后书","约翰一书","约翰二书","约翰三书","犹大书","启示录"]
}

class Settings:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.add_section('settings')
        self.config['settings'] = {
            'language': 'en', 'version': 'esv', 'book': '42',
            'chapter': '1', 'start_verse': '', 'end_verse': '',
            'theme': 'System', 'font_size': '21'
        }
        self.load()

    def load(self):
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            if os.path.exists(CONFIG_FILE):
                self.config.read(CONFIG_FILE)
        except Exception:
            pass

    def save(self):
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(CONFIG_FILE, 'w') as f:
                self.config.write(f)
        except Exception:
            pass

    def get(self, key, default=''):
        return self.config.get('settings', key, fallback=default)

    def set(self, key, value):
        self.config['settings'][key] = str(value)
        self.save()


class BibleCache:
    def __init__(self):
        os.makedirs(CACHE_DIR, exist_ok=True)

    def _path(self, lang, version):
        safe = f"{lang}_{version}.json".replace('/', '_')
        return os.path.join(CACHE_DIR, safe)

    def get(self, lang, version):
        path = self._path(lang, version)
        try:
            if os.path.exists(path):
                with open(path, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception:
            pass
        return None

    def put(self, lang, version, data):
        path = self._path(lang, version)
        try:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False)
        except Exception:
            pass

    def remove(self, lang, version):
        path = self._path(lang, version)
        try:
            if os.path.exists(path):
                os.remove(path)
        except Exception:
            pass

    def list_cached(self):
        result = []
        try:
            for f in os.listdir(CACHE_DIR):
                if f.endswith('.json'):
                    parts = f[:-5].split('_', 1)
                    if len(parts) == 2:
                        result.append((parts[0], parts[1]))
        except Exception:
            pass
        return result


class Manifest:
    def __init__(self):
        self.data = {}
        self.load()

    def load(self):
        try:
            if os.path.exists(MANIFEST_PATH):
                with open(MANIFEST_PATH, 'r', encoding='utf-8') as f:
                    self.data = json.load(f)
        except Exception:
            pass

    def get_languages(self):
        return {k: v['label'] for k, v in self.data.items()}

    def get_versions(self, lang):
        entry = self.data.get(lang)
        if not entry:
            return {}
        label = entry['label']
        result = {}
        for v in entry['versions']:
            parts = v['code'].split('/')
            key = parts[1] if len(parts) > 1 else parts[0]
            if lang == 'en' and key in ENGLISH_VERSION_NAMES:
                result[key] = ENGLISH_VERSION_NAMES[key]
            else:
                name = v['label'].replace(f"{label} — ", '').strip()
                result[key] = name
        return result

    def get_version_codes(self, lang):
        entry = self.data.get(lang)
        if not entry:
            return []
        return [v['code'] for v in entry['versions']]


class SharersBibleApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='org.sharersbible.app')
        self.settings = Settings()
        self.cache = BibleCache()
        self.manifest = Manifest()
        self.bible_data = None
        self.current_versions = {}
        self.languages = {}
        self.selected_language = self.settings.get('language', 'en')
        self.selected_version = self.settings.get('version', 'esv')
        self.selected_book_idx = int(self.settings.get('book', '42')) - 1
        self.selected_chapter = int(self.settings.get('chapter', '1'))
        self.start_verse = self.settings.get('start_verse', '')
        self.end_verse = self.settings.get('end_verse', '')
        self.current_theme = self.settings.get('theme', 'System')
        self.font_size = int(self.settings.get('font_size', '21'))
        self.is_loading = False
        self.settings_popover = None
        self.download_progress = {}

    def do_activate(self):
        if HAS_ADW:
            self.win = Adw.ApplicationWindow(application=self)
        else:
            self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_title("Sharer's Bible")
        self.win.set_default_size(1200, 800)

        css_provider = Gtk.CssProvider()
        css_provider.load_from_string(self._get_css())
        Gtk.StyleContext.add_provider_for_display(
            self.win.get_display(), css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.win.set_child(main_box)

        self._build_toolbar(main_box)
        self._build_reading_area(main_box)

        self.languages = self.manifest.get_languages()
        self._populate_languages()
        self._on_language_changed()
        self._apply_theme()
        self._on_version_or_language_changed()
        self._setup_accels()

        self.win.present()

    def _get_css(self):
        return """
header { background: @theme_header_bg_color; }
toolbar { background: @theme_header_bg_color; border-bottom: 1px solid @borders; padding: 4px; }
.control-label { font-size: 11px; font-weight: 600; opacity: 0.7; margin-bottom: 2px; }
.reading-content { max-width: 720px; margin: 0 auto; padding: 48px 24px; }
.reference-title { font-size: 42px; font-weight: 800; margin: 0 0 48px 0; }
.reference-title:hover { opacity: 0.8; }
.verse-row { margin-bottom: 6px; }
.verse-number { font-weight: 700; font-size: 13px; color: @accent_color; margin-right: 8px; min-width: 24px; }
.verse-text { cursor: pointer; }
.verse-text:hover { opacity: 0.8; }
.passage-footer { margin-top: 80px; padding-top: 40px; border-top: 1px solid @borders; font-style: italic; font-size: 14px; }
.loading-text { text-align: center; margin-top: 160px; font-weight: 600; opacity: 0.5; font-size: 24px; }
.error-view { text-align: center; margin-top: 120px; }
.error-title { font-size: 28px; font-weight: 800; }
.error-message { opacity: 0.7; margin-top: 12px; max-width: 450px; margin-left: auto; margin-right: auto; font-size: 18px; }
.empty-view { text-align: center; margin-top: 200px; opacity: 0.1; }
.empty-title { margin-top: 32px; font-size: 28px; font-weight: 800; }
.settings-panel { padding: 20px; min-width: 320px; }
.settings-title { font-size: 20px; font-weight: 700; margin: 0 0 16px 0; }
.settings-section { margin-bottom: 20px; }
.theme-btn-active { background: @accent_color; color: white; border-color: @accent_color; }
.fs-label { font-size: 14px; font-weight: 600; }
.download-manager { max-height: 300px; overflow-y: auto; }
"""

    def _build_toolbar(self, parent):
        toolbar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        toolbar.add_css_class('toolbar')
        parent.append(toolbar)

        inner = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        inner.set_margin_start(8)
        inner.set_margin_end(8)
        inner.set_margin_top(4)
        inner.set_margin_bottom(4)
        toolbar.append(inner)

        lang_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        lang_lbl = Gtk.Label(label=get_label('en', 'language'))
        lang_lbl.add_css_class('control-label')
        lang_box.append(lang_lbl)
        self.lang_dropdown = Gtk.DropDown()
        self.lang_dropdown.connect('notify::selected-item', self._on_lang_dropdown_change)
        lang_box.append(self.lang_dropdown)
        inner.append(lang_box)

        inner.append(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL))

        ver_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        ver_lbl = Gtk.Label(label=get_label('en', 'version'))
        ver_lbl.add_css_class('control-label')
        ver_box.append(ver_lbl)
        self.ver_dropdown = Gtk.DropDown()
        self.ver_dropdown.connect('notify::selected-item', self._on_ver_dropdown_change)
        ver_box.append(self.ver_dropdown)
        inner.append(ver_box)

        inner.append(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL))

        book_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        book_lbl = Gtk.Label(label=get_label('en', 'book'))
        book_lbl.add_css_class('control-label')
        book_box.append(book_lbl)
        self.book_dropdown = Gtk.DropDown()
        self.book_dropdown.set_size_request(160, -1)
        self.book_dropdown.connect('notify::selected-item', self._on_book_dropdown_change)
        book_box.append(self.book_dropdown)
        inner.append(book_box)

        ch_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        ch_lbl = Gtk.Label(label=get_label('en', 'chapter'))
        ch_lbl.add_css_class('control-label')
        ch_box.append(ch_lbl)
        self.ch_dropdown = Gtk.DropDown()
        self.ch_dropdown.connect('notify::selected-item', self._on_ch_dropdown_change)
        ch_box.append(self.ch_dropdown)
        inner.append(ch_box)

        inner.append(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL))

        vf_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        vf_lbl = Gtk.Label(label=get_label('en', 'from'))
        vf_lbl.add_css_class('control-label')
        vf_box.append(vf_lbl)
        self.verse_from = Gtk.Entry()
        self.verse_from.set_placeholder_text('1')
        self.verse_from.set_width_chars(4)
        self.verse_from.connect('changed', self._on_verse_range_changed)
        vf_box.append(self.verse_from)
        inner.append(vf_box)

        vt_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        vt_lbl = Gtk.Label(label=get_label('en', 'to'))
        vt_lbl.add_css_class('control-label')
        vt_box.append(vt_lbl)
        self.verse_to = Gtk.Entry()
        self.verse_to.set_placeholder_text('All')
        self.verse_to.set_width_chars(4)
        self.verse_to.connect('changed', self._on_verse_range_changed)
        vt_box.append(self.verse_to)
        inner.append(vt_box)

        refresh_btn = Gtk.Button(label=get_label('en', 'refresh'))
        refresh_btn.connect('clicked', self._on_refresh)
        inner.append(refresh_btn)

        inner.append(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL))

        self.copy_btn = Gtk.Button(label=get_label('en', 'copy'))
        self.copy_btn.connect('clicked', self._on_copy)
        inner.append(self.copy_btn)

        self.md_btn = Gtk.Button(label=get_label('en', 'exportMD'))
        self.md_btn.connect('clicked', self._on_export_md)
        inner.append(self.md_btn)

        self.html_btn = Gtk.Button(label=get_label('en', 'exportHTML'))
        self.html_btn.connect('clicked', self._on_export_html)
        inner.append(self.html_btn)

        self.settings_btn = Gtk.Button(label=get_label('en', 'settings'))
        self.settings_btn.connect('clicked', self._on_settings)
        inner.append(self.settings_btn)

    def _build_reading_area(self, parent):
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_hexpand(True)
        scrolled.set_vexpand(True)
        parent.append(scrolled)

        self.reading_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.reading_box.set_halign(Gtk.Align.CENTER)
        scrolled.set_child(self.reading_box)

        self.content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.content_box.add_css_class('reading-content')
        self.reading_box.append(self.content_box)

    def _populate_languages(self):
        sorted_langs = sorted(self.languages.items(), key=lambda x: x[1])
        model = Gtk.StringList()
        for code, label in sorted_langs:
            model.append(label)
        self.lang_dropdown.set_model(model)
        for i, (code, _) in enumerate(sorted_langs):
            if code == self.selected_language:
                self.lang_dropdown.set_selected(i)
                break

    def _get_selected_lang_code(self):
        i = self.lang_dropdown.get_selected()
        sorted_langs = sorted(self.languages.items(), key=lambda x: x[1])
        if 0 <= i < len(sorted_langs):
            return sorted_langs[i][0]
        return 'en'

    def _on_lang_dropdown_change(self, *args):
        code = self._get_selected_lang_code()
        if code != self.selected_language:
            self.selected_language = code
            self.settings.set('language', code)
            self._on_language_changed()
            self._on_version_or_language_changed()

    def _on_language_changed(self):
        self.current_versions = self.manifest.get_versions(self.selected_language)
        sorted_vers = sorted(self.current_versions.items(), key=lambda x: x[1])
        model = Gtk.StringList()
        for key, label in sorted_vers:
            model.append(label)
        self.ver_dropdown.set_model(model)
        found = False
        for i, (key, _) in enumerate(sorted_vers):
            if key == self.selected_version:
                self.ver_dropdown.set_selected(i)
                found = True
                break
        if not found and sorted_vers:
            self.ver_dropdown.set_selected(0)
            self.selected_version = sorted_vers[0][0]

    def _on_ver_dropdown_change(self, *args):
        i = self.ver_dropdown.get_selected()
        sorted_vers = sorted(self.current_versions.items(), key=lambda x: x[1])
        if 0 <= i < len(sorted_vers):
            key = sorted_vers[i][0]
            if key != self.selected_version:
                self.selected_version = key
                self.settings.set('version', key)
                self._on_version_or_language_changed()

    def _populate_books(self):
        books = LOCALIZED_BOOKS.get(self.selected_language, LOCALIZED_BOOKS['en'])
        if len(books) != len(BASE_BOOKS):
            books = [b[0] for b in BASE_BOOKS]
        model = Gtk.StringList()
        for name in books:
            model.append(name)
        self.book_dropdown.set_model(model)
        if 0 <= self.selected_book_idx < len(books):
            self.book_dropdown.set_selected(self.selected_book_idx)
        else:
            self.book_dropdown.set_selected(0)
            self.selected_book_idx = 0

    def _on_book_dropdown_change(self, *args):
        i = self.book_dropdown.get_selected()
        books = LOCALIZED_BOOKS.get(self.selected_language, LOCALIZED_BOOKS['en'])
        if len(books) != len(BASE_BOOKS):
            books = [b[0] for b in BASE_BOOKS]
        if 0 <= i < len(books):
            self.selected_book_idx = i
            self.settings.set('book', str(i + 1))
            self._populate_chapters()
            self._display_passage()

    def _populate_chapters(self):
        chapters = BASE_BOOKS[self.selected_book_idx][1] if self.selected_book_idx < len(BASE_BOOKS) else 1
        model = Gtk.StringList()
        for c in range(1, chapters + 1):
            model.append(str(c))
        self.ch_dropdown.set_model(model)
        if 1 <= self.selected_chapter <= chapters:
            self.ch_dropdown.set_selected(self.selected_chapter - 1)
        else:
            self.ch_dropdown.set_selected(0)
            self.selected_chapter = 1

    def _on_ch_dropdown_change(self, *args):
        i = self.ch_dropdown.get_selected()
        self.selected_chapter = i + 1
        self.settings.set('chapter', str(self.selected_chapter))
        self._display_passage()

    def _on_verse_range_changed(self, *args):
        self.start_verse = self.verse_from.get_text()
        self.end_verse = self.verse_to.get_text()
        self.settings.set('start_verse', self.start_verse)
        self.settings.set('end_verse', self.end_verse)
        self._display_passage()

    def _on_refresh(self, *args):
        self._on_version_or_language_changed()

    def _on_version_or_language_changed(self):
        self._populate_books()
        self._populate_chapters()
        self._fetch_bible_data()

    def _fetch_bible_data(self):
        if not self.selected_version or not self.selected_language:
            return
        self.is_loading = True
        self._update_loading()

        def fetch():
            try:
                cached = self.cache.get(self.selected_language, self.selected_version)
                if cached:
                    GLib.idle_add(self._on_data_loaded, cached)
                    return
                url = f"{API_BASE}/download/{self.selected_language}/{self.selected_version}"
                req = urllib.request.Request(url)
                with urllib.request.urlopen(req, timeout=30) as resp:
                    data = json.loads(resp.read().decode('utf-8'))
                self.cache.put(self.selected_language, self.selected_version, data)
                GLib.idle_add(self._on_data_loaded, data)
            except Exception as e:
                GLib.idle_add(self._on_data_error, str(e))

        threading.Thread(target=fetch, daemon=True).start()

    def _on_data_loaded(self, data):
        self.bible_data = data
        self.is_loading = False
        self._display_passage()

    def _on_data_error(self, error_msg):
        self.is_loading = False
        self._show_error(error_msg)

    def _update_loading(self):
        self._clear_content()
        label = Gtk.Label(label=get_label(self.selected_language, 'fetchingWord'))
        label.add_css_class('loading-text')
        self.content_box.append(label)

    def _show_error(self, msg):
        self._clear_content()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.add_css_class('error-view')
        title = Gtk.Label(label=get_label(self.selected_language, 'unableToLoad'))
        title.add_css_class('error-title')
        box.append(title)
        emsg = Gtk.Label(label=msg)
        emsg.add_css_class('error-message')
        emsg.set_wrap(True)
        box.append(emsg)
        retry_btn = Gtk.Button(label=get_label(self.selected_language, 'retry'))
        retry_btn.connect('clicked', lambda b: self._fetch_bible_data())
        box.append(retry_btn)
        self.content_box.append(box)

    def _show_empty(self, msg):
        self._clear_content()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        box.add_css_class('empty-view')
        label = Gtk.Label(label=msg)
        label.add_css_class('empty-title')
        box.append(label)
        self.content_box.append(box)

    def _clear_content(self):
        child = self.content_box.get_first_child()
        while child:
            self.content_box.remove(child)
            child = self.content_box.get_first_child()

    def _display_passage(self):
        self._clear_content()
        if self.is_loading:
            self._update_loading()
            return
        if not self.bible_data:
            self._show_empty(get_label(self.selected_language, 'choosePassage'))
            return

        book_id = str(self.selected_book_idx + 1)
        chapter_key = str(self.selected_chapter)
        verses_data = self.bible_data.get('verses', {}).get(book_id, {}).get(chapter_key, None)
        if verses_data is None:
            self._show_empty(get_label(self.selected_language, 'chapterNotFound'))
            return

        s = int(self.start_verse) if self.start_verse else 1
        e = int(self.end_verse) if self.end_verse else len(verses_data)
        s = max(1, s)
        e = min(len(verses_data), e if e >= s else len(verses_data))

        verses = []
        for i in range(s - 1, e):
            if i < len(verses_data):
                verses.append({'verse': i + 1, 'text': verses_data[i].strip()})
        if not verses:
            self._show_empty(get_label(self.selected_language, 'passageNotFound'))
            return

        first = verses[0]['verse']
        last = verses[-1]['verse']
        books = LOCALIZED_BOOKS.get(self.selected_language, LOCALIZED_BOOKS['en'])
        if len(books) != len(BASE_BOOKS):
            books = [b[0] for b in BASE_BOOKS]
        book_name = books[self.selected_book_idx] if self.selected_book_idx < len(books) else BASE_BOOKS[self.selected_book_idx][0]
        ref = f"{book_name} {self.selected_chapter}:{first}"
        if first != last:
            ref = f"{book_name} {self.selected_chapter}:{first}-{last}"

        ref_label = Gtk.Label()
        ref_label.set_markup(f"<big><b>{ref}</b></big>")
        ref_label.add_css_class('reference-title')
        ref_label.set_halign(Gtk.Align.START)
        ref_label.set_selectable(True)
        self.content_box.append(ref_label)

        for v in verses:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            row.add_css_class('verse-row')
            vnum = Gtk.Label(label=str(v['verse']))
            vnum.add_css_class('verse-number')
            row.append(vnum)
            vtext = Gtk.Label(label=v['text'])
            vtext.set_wrap(True)
            vtext.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
            vtext.set_xalign(0)
            vtext.set_selectable(True)
            vtext.add_css_class('verse-text')
            row.set_hexpand(True)
            vtext.set_hexpand(True)
            row.append(vtext)
            self.content_box.append(row)

        footer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        footer.add_css_class('passage-footer')
        ver_name = self.current_versions.get(self.selected_version, self.selected_version)
        src = Gtk.Label()
        src.set_markup(f"<b>{ref} (<i>{ver_name}</i>)</b>")
        src.set_selectable(True)
        src.set_halign(Gtk.Align.START)
        footer.append(src)
        cr_text = ENGLISH_COPYRIGHTS.get(self.selected_version, '')
        if cr_text:
            cr = Gtk.Label(label=cr_text)
            cr.set_wrap(True)
            cr.set_selectable(True)
            cr.set_halign(Gtk.Align.START)
            footer.append(cr)
        self.content_box.append(footer)

    def _get_displayed_verses(self):
        if not self.bible_data:
            return []
        book_id = str(self.selected_book_idx + 1)
        chapter_key = str(self.selected_chapter)
        verses_data = self.bible_data.get('verses', {}).get(book_id, {}).get(chapter_key, None)
        if not verses_data:
            return []
        s = int(self.start_verse) if self.start_verse else 1
        e = int(self.end_verse) if self.end_verse else len(verses_data)
        s = max(1, s)
        e = min(len(verses_data), e if e >= s else len(verses_data))
        return [{'verse': i+1, 'text': verses_data[i].strip()} for i in range(s-1, e) if i < len(verses_data)]

    def _get_current_ref(self):
        books = LOCALIZED_BOOKS.get(self.selected_language, LOCALIZED_BOOKS['en'])
        if len(books) != len(BASE_BOOKS):
            books = [b[0] for b in BASE_BOOKS]
        book_name = books[self.selected_book_idx] if self.selected_book_idx < len(books) else BASE_BOOKS[self.selected_book_idx][0]
        return f"{book_name} {self.selected_chapter}"

    def _copy_to_clipboard(self, text, message):
        clipboard = self.win.get_clipboard()
        clipboard.set(text)
        self._show_toast(message)

    def _show_toast(self, message):
        toast = Gtk.Label(label=message)
        toast.set_halign(Gtk.Align.CENTER)
        toast.set_valign(Gtk.Align.END)
        toast.set_margin_bottom(24)
        toast.set_opacity(0.0)
        over = Gtk.Overlay()
        child = self.win.get_child()
        if child:
            self.win.set_child(over)
            over.set_child(child)
            over.add_overlay(toast)
            toast.set_halign(Gtk.Align.CENTER)
            toast.set_valign(Gtk.Align.END)
        toast.set_opacity(1.0)
        GLib.timeout_add_seconds(2, lambda: self._hide_toast(toast, over))

    def _hide_toast(self, toast, over):
        over.remove_overlay(toast)
        child = over.get_child()
        if child:
            self.win.set_child(child)
        return False

    def _on_copy(self, *args):
        verses = self._get_displayed_verses()
        if not verses:
            return
        text = '\n\n'.join(f"{v['verse']}. {v['text']}" for v in verses)
        self._copy_to_clipboard(text, get_label(self.selected_language, 'copy'))

    def _on_export_md(self, *args):
        verses = self._get_displayed_verses()
        if not verses:
            return
        ref = self._get_current_ref()
        ver_name = self.current_versions.get(self.selected_version, self.selected_version)
        cr = ENGLISH_COPYRIGHTS.get(self.selected_version, '')
        md = f"# {ref}\n\n"
        md += '\n\n'.join(f"### Verse {v['verse']}\n{v['text']}" for v in verses)
        md += f"\n\n---\n*Source: {ver_name}*\n"
        if cr:
            md += f"\n*{cr}*"
        self._save_file(md, f"{ref.replace(':', '-')}.md", 'text/markdown')

    def _on_export_html(self, *args):
        verses = self._get_displayed_verses()
        if not verses:
            return
        ref = self._get_current_ref()
        ver_name = self.current_versions.get(self.selected_version, self.selected_version)
        cr = ENGLISH_COPYRIGHTS.get(self.selected_version, '')

        is_dark = self.current_theme == 'Dark'
        is_sepia = self.current_theme == 'Sepia'
        if is_dark:
            bg, txt = '#1a1a1a', '#f5f5f7'
        elif is_sepia:
            bg, txt = '#f5f0e0', '#433422'
        else:
            bg, txt = '#ffffff', '#000000'
        border = 'rgba(255,255,255,0.15)' if is_dark else 'rgba(0,0,0,0.1)'

        vhtml = '\n'.join(f'<div class="verse"><span class="vnum">{v["verse"]}</span>{v["text"]}</div>' for v in verses)
        html = f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>{ref}</title>
<style>
body {{ background:{bg}; color:{txt}; font-family:'Iowan Old Style','Palatino','Georgia',serif; max-width:700px; margin:40px auto; padding:0 20px; line-height:1.7; }}
h1 {{ font-size:42px; font-weight:800; margin-bottom:48px; }}
.verse {{ margin-bottom:8px; }}
.vnum {{ font-weight:700; font-size:13px; color:#007aff; margin-right:8px; }}
.footer {{ margin-top:80px; padding-top:40px; border-top:1px solid {border}; font-style:italic; font-size:14px; }}
</style></head><body>
<h1>{ref}</h1>
{vhtml}
<div class="footer">
<p><strong>{ref} ({ver_name})</strong></p>
<p>{cr}</p>
<p>Generated by Sharer's Bible</p>
</div></body></html>"""
        self._save_file(html, f"{ref.replace(':', '-')}.html", 'text/html')

    def _save_file(self, content, filename, mime_type):
        try:
            dialog = Gtk.FileDialog()
            dialog.set_title(get_label(self.selected_language, 'savePanelMessage'))
            dialog.set_initial_name(filename)
            dialog.save(self.win, None, lambda d, res: self._on_save_result(d, res, content))
        except Exception as e:
            self._show_toast(f"Error: {e}")

    def _on_save_result(self, dialog, result, content):
        try:
            file = dialog.save_finish(result)
            if file:
                path = file.get_path()
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
                self._show_toast(get_label(self.selected_language, 'exMarkdown') if content.startswith('#') else get_label(self.selected_language, 'exHtml'))
        except GLib.Error as e:
            if e.domain != 'gtk-dialog-error-quark':
                self._show_toast(f"Error: {e.message}")

    def _apply_theme(self):
        style = self.win.get_style_context()
        for cls in ['theme-system', 'theme-light', 'theme-dark', 'theme-sepia']:
            style.remove_class(cls)
        theme_map = {'System': 'theme-system', 'Light': 'theme-light', 'Dark': 'theme-dark', 'Sepia': 'theme-sepia'}
        cls = theme_map.get(self.current_theme, 'theme-system')
        style.add_class(cls)

        bg_map = {'System': '', 'Light': '#ffffff', 'Dark': '#1a1a1a', 'Sepia': '#f5f0e0'}
        txt_map = {'System': '', 'Light': '#000000', 'Dark': '#f5f5f7', 'Sepia': '#433422'}
        bg = bg_map.get(self.current_theme, '')
        txt = txt_map.get(self.current_theme, '')
        if bg:
            css = f"window {{ background-color: {bg}; color: {txt}; }} .reading-content label {{ color: {txt}; }}"
            provider = Gtk.CssProvider()
            provider.load_from_string(css)
            Gtk.StyleContext.add_provider_for_display(
                self.win.get_display(), provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
            )

    def _on_settings(self, *args):
        if self.settings_popover and self.settings_popover.is_visible():
            self.settings_popover.popdown()
            return
        self.settings_popover = Gtk.Popover()
        self.settings_popover.set_position(Gtk.PositionType.BOTTOM)
        self.settings_popover.set_has_arrow(False)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        box.add_css_class('settings-panel')
        self.settings_popover.set_child(box)

        title = Gtk.Label()
        title.set_markup(f"<b>{get_label(self.selected_language, 'settings')}</b>")
        title.add_css_class('settings-title')
        box.append(title)

        theme_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        theme_box.add_css_class('settings-section')
        theme_lbl = Gtk.Label(label=get_label(self.selected_language, 'theme'))
        theme_lbl.add_css_class('settings-label')
        theme_lbl.set_halign(Gtk.Align.START)
        theme_box.append(theme_lbl)

        theme_grid = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        theme_grid.set_homogeneous(True)
        self.theme_btns = {}
        for t in ['System', 'Light', 'Dark', 'Sepia']:
            btn = Gtk.ToggleButton(label=get_label(self.selected_language, f'theme{t}'))
            btn.set_active(t == self.current_theme)
            btn.connect('toggled', self._on_theme_toggled, t)
            theme_grid.append(btn)
            self.theme_btns[t] = btn
        theme_box.append(theme_grid)
        box.append(theme_box)

        fs_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        fs_box.add_css_class('settings-section')
        fs_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        fs_lbl = Gtk.Label(label=get_label(self.selected_language, 'fontSize'))
        fs_lbl.add_css_class('settings-label')
        fs_header.append(fs_lbl)
        self.fs_value_label = Gtk.Label(label=f"{self.font_size}px")
        self.fs_value_label.add_css_class('fs-label')
        fs_header.append(self.fs_value_label)
        fs_box.append(fs_header)

        adj = Gtk.Adjustment(value=self.font_size, lower=14, upper=40, step_increment=1, page_increment=5)
        scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
        scale.set_digits(0)
        scale.set_hexpand(True)
        scale.connect('value-changed', self._on_font_size_changed)
        fs_box.append(scale)
        box.append(fs_box)

        lang_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        lang_box.add_css_class('settings-section')
        lang_lbl = Gtk.Label(label=get_label(self.selected_language, 'language'))
        lang_lbl.add_css_class('settings-label')
        lang_lbl.set_halign(Gtk.Align.START)
        lang_box.append(lang_lbl)

        ui_lang_drop = Gtk.DropDown()
        sorted_langs = sorted(self.languages.items(), key=lambda x: x[1])
        model = Gtk.StringList()
        for code, label in sorted_langs:
            model.append(label)
        ui_lang_drop.set_model(model)
        for i, (code, _) in enumerate(sorted_langs):
            if code == self.selected_language:
                ui_lang_drop.set_selected(i)
                break
        ui_lang_drop.connect('notify::selected-item', lambda d, *a: self._on_ui_lang_change(d))
        lang_box.append(ui_lang_drop)
        box.append(lang_box)

        dm_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        dm_box.add_css_class('settings-section')
        dm_lbl = Gtk.Label(label=get_label(self.selected_language, 'downloadManager'))
        dm_lbl.add_css_class('settings-label')
        dm_lbl.set_halign(Gtk.Align.START)
        dm_box.append(dm_lbl)

        dm_scroll = Gtk.ScrolledWindow()
        dm_scroll.set_max_content_height(250)
        dm_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        dm_scroll.set_child(dm_list)

        cached = set(self.cache.list_cached())
        for code, label in sorted(self.languages.items(), key=lambda x: x[1]):
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            vbox.add_css_class('download-item')
            hbox2 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            lang_item = Gtk.Label(label=label)
            lang_item.set_halign(Gtk.Align.START)
            lang_item.set_hexpand(True)
            hbox2.append(lang_item)

            has_cached = any(l == code for l, _ in cached)
            status_lbl = Gtk.Label(label='')
            status_lbl.add_css_class('fs-label')
            hbox2.append(status_lbl)

            dl_btn = Gtk.Button(label=get_label(self.selected_language, 'download'))
            dl_btn.set_size_request(100, -1)

            versions_for_lang = self.manifest.get_versions(code)
            version_codes = self.manifest.get_version_codes(code)
            if has_cached:
                status_lbl.set_markup(f"<span color='green'>{get_label(self.selected_language, 'downloaded')}</span>")
                dl_btn.set_label(get_label(self.selected_language, 'deleteDownload'))
                dl_btn.connect('clicked', lambda b, c=code, vl=versions_for_lang: self._delete_download(c, vl))
            else:
                dl_btn.connect('clicked', lambda b, c=code, sl=status_lbl, vl=version_codes: self._start_download(c, sl, vl))
            hbox2.append(dl_btn)
            vbox.append(hbox2)

            progress_bar = Gtk.ProgressBar()
            progress_bar.set_visible(False)
            vbox.append(progress_bar)

            dm_list.append(vbox)

        box.append(dm_scroll)

        done_btn = Gtk.Button(label=get_label(self.selected_language, 'done'))
        done_btn.add_css_class('suggested-action')
        done_btn.connect('clicked', lambda b: self.settings_popover.popdown())
        box.append(done_btn)

        self.settings_popover.set_parent(self.settings_btn)
        self.settings_popover.popup()

    def _on_theme_toggled(self, btn, theme):
        if btn.get_active():
            for t, b in self.theme_btns.items():
                if t != theme:
                    b.set_active(False)
            self.current_theme = theme
            self.settings.set('theme', theme)
            self._apply_theme()

    def _on_ui_lang_change(self, dropdown):
        i = dropdown.get_selected()
        sorted_langs = sorted(self.languages.items(), key=lambda x: x[1])
        if 0 <= i < len(sorted_langs):
            code = sorted_langs[i][0]
            if code != self.selected_language:
                self.selected_language = code
                self.settings.set('language', code)
                self._on_language_changed()
                self._on_version_or_language_changed()
                if self.settings_popover:
                    self.settings_popover.popdown()
                self._on_settings()

    def _on_font_size_changed(self, scale):
        self.font_size = int(scale.get_value())
        self.fs_value_label.set_label(f"{self.font_size}px")
        self.settings.set('font_size', str(self.font_size))
        css = f".reading-content {{ font-size: {self.font_size}px; }}"
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            self.win.get_display(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 2
        )

    def _start_download(self, lang, status_label, version_codes):
        status_label.set_markup(f"<span color='orange'>{get_label(lang, 'downloading')}</span>")

        def download():
            try:
                for vcode in version_codes:
                    parts = vcode.split('/')
                    ver = parts[1] if len(parts) > 1 else parts[0]
                    cached = self.cache.get(lang, ver)
                    if cached:
                        continue
                    url = f"{API_BASE}/download/{vcode}"
                    req = urllib.request.Request(url)
                    with urllib.request.urlopen(req, timeout=60) as resp:
                        data = json.loads(resp.read().decode('utf-8'))
                    self.cache.put(lang, ver, data)
                GLib.idle_add(lambda: self._on_download_complete(lang, status_label))
            except Exception as e:
                GLib.idle_add(lambda: status_label.set_markup(f"<span color='red'>Error: {str(e)[:30]}</span>"))

        threading.Thread(target=download, daemon=True).start()

    def _on_download_complete(self, lang, status_label):
        status_label.set_markup(f"<span color='green'>{get_label(lang, 'downloadComplete')}</span>")
        if self.settings_popover:
            self.settings_popover.popdown()
        self._on_settings()

    def _delete_download(self, lang, versions):
        for key in versions:
            self.cache.remove(lang, key)
        if self.settings_popover:
            self.settings_popover.popdown()
        self._on_settings()

    def _setup_accels(self):
        pass


def main():
    app = SharersBibleApp()
    app.run()

if __name__ == '__main__':
    main()
