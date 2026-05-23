package main

import (
	"encoding/json"
	"fmt"
	"image/color"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

const apiBase = "https://apibible.wbem.org/api"

// Data types
type ManifestVersion struct {
	Code  string `json:"code"`
	Label string `json:"label"`
}

type ManifestEntry struct {
	Label    string            `json:"label"`
	Versions []ManifestVersion `json:"versions"`
}

type BibleData struct {
	Books  [][2]interface{}              `json:"books"`
	Verses map[string]map[string][]string `json:"verses"`
}

type BibleBook struct {
	ID       int
	Name     string
	Chapters int
}

type AppTheme int

const (
	ThemeLight AppTheme = iota
	ThemeDark
	ThemeSepia
)

type VerseData struct {
	Number int
	Text   string
}

// Theme implementations
type lightTheme struct {
	fontSize float32
}

func (t *lightTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	return theme.DefaultTheme().Color(name, variant)
}

func (t *lightTheme) Font(style fyne.TextStyle) fyne.Resource {
	return theme.DefaultTheme().Font(style)
}

func (t *lightTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

func (t *lightTheme) Size(name fyne.ThemeSizeName) float32 {
	if name == theme.SizeNameText {
		return t.fontSize
	}
	return theme.DefaultTheme().Size(name)
}

type darkTheme struct {
	fontSize float32
}

func (t *darkTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	return theme.DarkTheme().Color(name, variant)
}

func (t *darkTheme) Font(style fyne.TextStyle) fyne.Resource {
	return theme.DarkTheme().Font(style)
}

func (t *darkTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DarkTheme().Icon(name)
}

func (t *darkTheme) Size(name fyne.ThemeSizeName) float32 {
	if name == theme.SizeNameText {
		return t.fontSize
	}
	return theme.DarkTheme().Size(name)
}

type sepiaTheme struct {
	fontSize float32
}

func (t *sepiaTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNameBackground:
		return color.NRGBA{R: 0xf5, G: 0xf0, B: 0xe0, A: 0xff}
	case theme.ColorNameForeground:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0xff}
	case theme.ColorNamePrimary:
		return color.NRGBA{R: 0x8b, G: 0x45, B: 0x13, A: 0xff}
	case theme.ColorNameInputBackground:
		return color.NRGBA{R: 0xfc, G: 0xf8, B: 0xea, A: 0xff}
	case theme.ColorNameInputBorder:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x33}
	case theme.ColorNamePlaceHolder:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x66}
	case theme.ColorNameScrollBar:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x33}
	case theme.ColorNameDisabled:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x44}
	case theme.ColorNameDisabledButton:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x22}
	case theme.ColorNameButton:
		return color.NRGBA{R: 0xe8, G: 0xdc, B: 0xc0, A: 0xff}
	case theme.ColorNameHover:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x0c}
	case theme.ColorNameFocus:
		return color.NRGBA{R: 0x8b, G: 0x45, B: 0x13, A: 0x44}
	case theme.ColorNameSeparator:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x1a}
	case theme.ColorNameSelection:
		return color.NRGBA{R: 0x8b, G: 0x45, B: 0x13, A: 0x44}
	case theme.ColorNameMenuBackground:
		return color.NRGBA{R: 0xf5, G: 0xf0, B: 0xe0, A: 0xff}
	case theme.ColorNameOverlayBackground:
		return color.NRGBA{R: 0xf5, G: 0xf0, B: 0xe0, A: 0xee}
	case theme.ColorNameShadow:
		return color.NRGBA{R: 0x43, G: 0x34, B: 0x22, A: 0x33}
	case theme.ColorNameSuccess:
		return color.NRGBA{R: 0x2e, G: 0x7d, B: 0x32, A: 0xff}
	case theme.ColorNameWarning:
		return color.NRGBA{R: 0xf5, G: 0x7f, B: 0x17, A: 0xff}
	case theme.ColorNameError:
		return color.NRGBA{R: 0xd3, G: 0x2f, B: 0x2f, A: 0xff}
	case theme.ColorNameHeaderBackground:
		return color.NRGBA{R: 0xee, G: 0xe0, B: 0xc8, A: 0xff}
	default:
		return theme.DarkTheme().Color(name, variant)
	}
}

func (t *sepiaTheme) Font(style fyne.TextStyle) fyne.Resource {
	return theme.DefaultTheme().Font(style)
}

func (t *sepiaTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

func (t *sepiaTheme) Size(name fyne.ThemeSizeName) float32 {
	if name == theme.SizeNameText {
		return t.fontSize
	}
	return theme.DefaultTheme().Size(name)
}

var defaultBooks = []BibleBook{
	{1, "Genesis", 50}, {2, "Exodus", 40}, {3, "Leviticus", 27}, {4, "Numbers", 36},
	{5, "Deuteronomy", 34}, {6, "Joshua", 24}, {7, "Judges", 21}, {8, "Ruth", 4},
	{9, "1 Samuel", 31}, {10, "2 Samuel", 24}, {11, "1 Kings", 22}, {12, "2 Kings", 25},
	{13, "1 Chronicles", 29}, {14, "2 Chronicles", 36}, {15, "Ezra", 10}, {16, "Nehemiah", 13},
	{17, "Esther", 10}, {18, "Job", 42}, {19, "Psalms", 150}, {20, "Proverbs", 31},
	{21, "Ecclesiastes", 12}, {22, "Song of Solomon", 8}, {23, "Isaiah", 66}, {24, "Jeremiah", 52},
	{25, "Lamentations", 5}, {26, "Ezekiel", 48}, {27, "Daniel", 12}, {28, "Hosea", 14},
	{29, "Joel", 3}, {30, "Amos", 9}, {31, "Obadiah", 1}, {32, "Jonah", 4},
	{33, "Micah", 7}, {34, "Nahum", 3}, {35, "Habakkuk", 3}, {36, "Zephaniah", 3},
	{37, "Haggai", 2}, {38, "Zechariah", 14}, {39, "Malachi", 4}, {40, "Matthew", 28},
	{41, "Mark", 16}, {42, "Luke", 24}, {43, "John", 21}, {44, "Acts", 28},
	{45, "Romans", 16}, {46, "1 Corinthians", 16}, {47, "2 Corinthians", 13}, {48, "Galatians", 6},
	{49, "Ephesians", 6}, {50, "Philippians", 4}, {51, "Colossians", 4}, {52, "1 Thessalonians", 5},
	{53, "2 Thessalonians", 3}, {54, "1 Timothy", 6}, {55, "2 Timothy", 4}, {56, "Titus", 3},
	{57, "Philemon", 1}, {58, "Hebrews", 13}, {59, "James", 5}, {60, "1 Peter", 5},
	{61, "2 Peter", 3}, {62, "1 John", 5}, {63, "2 John", 1}, {64, "3 John", 1},
	{65, "Jude", 1}, {66, "Revelation", 22},
}

var englishVersionNames = map[string]string{
	"akjv": "American King James Version", "amp": "Amplified Bible",
	"ampc": "Amplified Bible (Classic)", "asv": "American Standard Version",
	"brg": "BRG Bible", "ceb": "Common English Bible",
	"cev": "Contemporary English Version", "cevd": "CEV (Deuterocanon)",
	"cjb": "Complete Jewish Bible", "csb": "Christian Standard Bible",
	"darby": "Darby Translation", "dlnt": "Disciples' Literal New Testament",
	"dra": "Douay-Rheims 1899 American", "ehv": "EHV",
	"erv": "Easy-to-Read Version", "esv": "English Standard Version",
	"exb": "Expanded Bible", "gnt": "Good News Translation",
	"gnv": "1599 Geneva Bible", "gw": "God's Word Translation",
	"hcsb": "Holman Christian Standard Bible", "icb": "International Children's Bible",
	"isv": "International Standard Version", "jub": "Jubilee Bible 2000",
	"kj21": "21st Century King James Version", "kjv": "King James Version",
	"leb": "Lexham English Bible", "mev": "Modern English Version",
	"mounce": "Mounce Reverse-Interlinear NT", "msg": "The Message",
	"nabre": "New American Bible (Revised)", "nasb": "New American Standard Bible",
	"ncv": "New Century Version", "net": "NET Bible",
	"nirv": "New International Reader's Version", "niv1984": "New International Version (1984)",
	"niv2011": "New International Version (2011)", "nivuk": "New International Version (UK)",
	"nkjv": "New King James Version", "nlt": "New Living Translation",
	"nlt2013": "New Living Translation (2013)", "nlv": "New Life Version",
	"nog": "Names of God Bible", "nrsv": "New Revised Standard Version",
	"nrsva": "New Revised Standard Version (Ang)", "ojb": "Orthodox Jewish Bible",
	"phillips": "Phillips Translation", "rsv": "Revised Standard Version",
	"rsvce": "Revised Standard Version (CE)", "tlb": "The Living Bible",
	"tlv": "Tree of Life Version", "voice": "The Voice",
	"web": "World English Bible", "webbe": "World English Bible (British)",
	"wyc": "Wycliffe Bible", "ylt": "Young's Literal Translation",
}

var englishCopyrights = map[string]string{
	"akjv": "American King James Version (AKJV) is in the public domain.",
	"amp": "Scripture quotations taken from the Amplified® Bible, Copyright © 2015 by The Lockman Foundation. Used by permission.",
	"ampc": "Scripture quotations taken from the Amplified® Bible (Classic), Copyright © 1954, 1958, 1962, 1964, 1965, 1987 by The Lockman Foundation. Used by permission.",
	"asv": "American Standard Version (ASV) is in the public domain.",
	"brg": "BRG Bible is in the public domain.",
	"ceb": "Scripture quotations from the Common English Bible, Copyright © 2011 Common English Bible. Used by permission.",
	"cev": "Scripture quotations from the Contemporary English Version, Copyright © 1995 American Bible Society. Used by permission.",
	"cevd": "Scripture quotations from the Contemporary English Version, Copyright © 1995 American Bible Society. Used by permission.",
	"cjb": "Scripture quotations from the Complete Jewish Bible, Copyright © 1998 by David H. Stern. Used by permission.",
	"csb": "Scripture quotations from the Christian Standard Bible®, Copyright © 2017 by Holman Bible Publishers. Used by permission.",
	"darby": "Darby Translation (DARBY) is in the public domain.",
	"dlnt": "Disciples' Literal New Testament, Copyright © 2011 by Michael J. Magill. Used by permission.",
	"dra": "Douay-Rheims 1899 American Edition (DRA) is in the public domain.",
	"ehv": "Scripture quotations from the Evangelical Heritage Version, Copyright © 2019 Warburg Project. Used by permission.",
	"erv": "Scripture quotations from the Easy-to-Read Version, Copyright © 2006 by Bible League International. Used by permission.",
	"esv": "Scripture quotations are from The ESV® Bible (The Holy Bible, English Standard Version®), copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.",
	"exb": "Scripture quotations from The Expanded Bible, Copyright © 2011 by Thomas Nelson. Used by permission.",
	"gnt": "Scripture quotations from the Good News Translation, Copyright © 1992 by American Bible Society. Used by permission.",
	"gnv": "1599 Geneva Bible (GNV) is in the public domain.",
	"gw": "Scripture quotations from GOD'S WORD® Translation, Copyright © 1995 by God's Word to the Nations. Used by permission.",
	"hcsb": "Scripture quotations from the Holman Christian Standard Bible®, Copyright © 1999, 2000, 2002, 2003, 2009 by Holman Bible Publishers. Used by permission.",
	"icb": "Scripture quotations from the International Children's Bible®, Copyright © 1986, 1988, 1999 by Thomas Nelson. Used by permission.",
	"isv": "Scripture quotations from the International Standard Version, Copyright © 1995-2014 by ISV Foundation. Used by permission.",
	"jub": "Jubilee Bible 2000 (JUB) is in the public domain.",
	"kj21": "21st Century King James Version (KJ21), Copyright © 1994 by Deuel Enterprises. Used by permission.",
	"kjv": "King James Version (KJV) is in the public domain.",
	"leb": "Scripture quotations from the Lexham English Bible, Copyright © 2012 Logos Bible Software. Used by permission.",
	"mev": "Scripture quotations from the Modern English Version, Copyright © 2014 by Military Bible Association. Used by permission.",
	"mounce": "Scripture quotations from Mounce Reverse-Interlinear NT, Copyright © 2011 by William D. Mounce. Used by permission.",
	"msg": "The Message (MSG) Copyright © 1993, 1994, 1995, 1996, 2000, 2001, 2002. Used by permission of NavPress Publishing Group.",
	"nabre": "Scripture quotations from the New American Bible (Revised Edition), © 2010, 1991, 1986, 1970 Confraternity of Christian Doctrine. Used by permission.",
	"nasb": "Scripture taken from the NEW AMERICAN STANDARD BIBLE®, Copyright © 1960, 1962, 1963, 1968, 1971, 1972, 1973, 1975, 1977, 1995 by The Lockman Foundation. Used by permission.",
	"ncv": "Scripture quotations from the New Century Version®, Copyright © 2005 by Thomas Nelson. Used by permission.",
	"net": "Scripture quotations from the NET Bible®, Copyright © 1996-2016 by Biblical Studies Press. Used by permission.",
	"nirv": "Scripture quotations from the New International Reader's Version®, Copyright © 1995, 1996, 1998, 2014 by Biblica, Inc. Used by permission.",
	"niv1984": "Holy Bible, New International Version®, NIV® Copyright © 1973, 1978, 1984 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",
	"niv2011": "Holy Bible, New International Version®, NIV® Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",
	"nivuk": "Holy Bible, New International Version®, NIV® Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",
	"nkjv": "Scripture quotations from the New King James Version®, Copyright © 1982 by Thomas Nelson. Used by permission.",
	"nlt": "Scripture quotations from the Holy Bible, New Living Translation®, Copyright © 1996, 2004, 2015 by Tyndale House Foundation. Used by permission.",
	"nlt2013": "Scripture quotations from the Holy Bible, New Living Translation®, Copyright © 1996, 2004, 2013 by Tyndale House Foundation. Used by permission.",
	"nlv": "Scripture quotations from the New Life Version, Copyright © 1969 by Christian Literature International. Used by permission.",
	"nog": "Scripture quotations from The Names of God Bible, Copyright © 2011 by Baker Publishing Group. Used by permission.",
	"nrsv": "New Revised Standard Version Bible, copyright © 1989 the Division of Christian Education of the National Council of the Churches of Christ in the United States of America. Used by permission. All rights reserved.",
	"nrsva": "New Revised Standard Version Bible, copyright © 1989 the Division of Christian Education of the National Council of the Churches of Christ in the United States of America. Used by permission. All rights reserved.",
	"ojb": "Orthodox Jewish Bible, Copyright © 2002, 2003, 2008, 2010, 2011 by Artists for Israel International. Used by permission.",
	"phillips": "Scripture quotations from the Phillips Translation, Copyright © 1960, 1986 by J.B. Phillips. Used by permission.",
	"rsv": "Revised Standard Version (RSV) is in the public domain.",
	"rsvce": "Revised Standard Version Catholic Edition (RSVCE), Copyright © 1965, 1966 by Division of Christian Education of the National Council of the Churches of Christ. Used by permission.",
	"tlb": "Scripture quotations from The Living Bible, Copyright © 1971 by Tyndale House Foundation. Used by permission.",
	"tlv": "Scripture quotations from the Tree of Life Version, Copyright © 2015 by the Messianic Jewish Family Bible Society. Used by permission.",
	"voice": "Scripture quotations from The Voice™, Copyright © 2012 by Ecclesia Bible Society. Used by permission.",
	"web": "World English Bible (WEB) is in the public domain.",
	"webbe": "World English Bible British Edition (WEBBE) is in the public domain.",
	"wyc": "Wycliffe Bible (WYC) is in the public domain.",
	"ylt": "Young's Literal Translation (YLT) is in the public domain.",
}

var langLabels = map[string]string{
	"af": "Afrikaans", "ar": "Arabic", "de": "German", "en": "English",
	"es": "Spanish", "fi": "Finnish", "fr": "French", "he": "Hebrew",
	"hi": "Hindi", "id": "Indonesian", "it": "Italian", "ja": "Japanese",
	"nl": "Dutch", "pl": "Polish", "pt": "Portuguese", "ro": "Romanian",
	"ru": "Russian", "sw": "Swahili", "tl": "Tagalog", "vi": "Vietnamese",
	"zh": "Chinese",
}

func loadManifest() map[string]ManifestEntry {
	var manifest map[string]ManifestEntry
	if err := json.Unmarshal([]byte(manifestJSON), &manifest); err != nil {
		return make(map[string]ManifestEntry)
	}
	return manifest
}

func manifestToVersions(manifest map[string]ManifestEntry, language string) map[string]string {
	entry, ok := manifest[language]
	if !ok {
		// fallback to English
		entry, ok = manifest["en"]
		if !ok {
			result := make(map[string]string)
			for k, v := range englishVersionNames {
				result[k] = v
			}
			return result
		}
	}
	result := make(map[string]string)
	for _, v := range entry.Versions {
		parts := strings.Split(v.Code, "/")
		key := parts[1]
		if parts[0] == "en" {
			if name, ok := englishVersionNames[key]; ok {
				result[key] = name
				continue
			}
		}
		result[key] = v.Label
	}
	return result
}

func cacheDir() string {
	base := os.Getenv("APPDATA")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), "Library", "Application Support")
	}
	dir := filepath.Join(base, "sharers-bible", "bibles")
	os.MkdirAll(dir, 0755)
	return dir
}

func cachedBiblePath(language, version string) string {
	return filepath.Join(cacheDir(), language, version+".json")
}

func loadCachedBible(language, version string) *BibleData {
	path := cachedBiblePath(language, version)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var bible BibleData
	if err := json.Unmarshal(data, &bible); err != nil {
		return nil
	}
	return &bible
}

func saveCachedBible(language, version string, data *BibleData) error {
	dir := filepath.Join(cacheDir(), language)
	os.MkdirAll(dir, 0755)
	path := filepath.Join(dir, version+".json")
	j, err := json.Marshal(data)
	if err != nil {
		return err
	}
	return os.WriteFile(path, j, 0644)
}

func isCached(language, version string) bool {
	_, err := os.Stat(cachedBiblePath(language, version))
	return err == nil
}

func listCached() []string {
	base := cacheDir()
	entries, err := os.ReadDir(base)
	if err != nil {
		return nil
	}
	var result []string
	for _, lang := range entries {
		if !lang.IsDir() {
			continue
		}
		vers, err := os.ReadDir(filepath.Join(base, lang.Name()))
		if err != nil {
			continue
		}
		for _, ver := range vers {
			if !ver.IsDir() && strings.HasSuffix(ver.Name(), ".json") {
				key := lang.Name() + "/" + strings.TrimSuffix(ver.Name(), ".json")
				result = append(result, key)
			}
		}
	}
	return result
}
var localizedBooks = map[string][]string{
	"af": {"Genesis", "Eksodus", "Levitikus", "Numeri", "Deuteronomium", "Josua", "Rigters", "Rut", "1 Samuel", "2 Samuel", "1 Konings", "2 Konings", "1 Kronieke", "2 Kronieke", "Esra", "Nehemia", "Ester", "Job", "Psalms", "Spreuke", "Prediker", "Hooglied", "Jesaja", "Jeremia", "Klaagliedere", "Esegiël", "Daniël", "Hosea", "Joël", "Amos", "Obadja", "Jona", "Miga", "Nahum", "Habakuk", "Sefanja", "Haggai", "Sagaria", "Maleagi", "Matteus", "Markus", "Lukas", "Johannes", "Handelinge", "Romeine", "1 Korintiërs", "2 Korintiërs", "Galasiërs", "Efesiërs", "Filippense", "Kolossense", "1 Tessalonisense", "2 Tessalonisense", "1 Timoteus", "2 Timoteus", "Titus", "Filemon", "Hebreërs", "Jakobus", "1 Petrus", "2 Petrus", "1 Johannes", "2 Johannes", "3 Johannes", "Judas", "Openbaring"},
	"ar": {"تكوين", "خروج", "لاويين", "عدد", "تثنية", "يشوع", "قضاة", "راعوث", "1 صموئيل", "2 صموئيل", "1 ملوك", "2 ملوك", "1 أخبار", "2 أخبار", "عزرا", "نحميا", "أستير", "أيوب", "مزامير", "أمثال", "جامعة", "نشيد الأنشاد", "إشعياء", "إرميا", "مراثي إرميا", "حزقيال", "دانيال", "هوشع", "يوئيل", "عاموس", "عوبديا", "يونان", "ميخا", "ناحوم", "حبقوق", "صفنيا", "حجي", "زكريا", "ملاخي", "متى", "مرقس", "لوقا", "يوحنا", "أعمال", "رومية", "1 كورنثوس", "2 كورنثوس", "غلاطية", "أفسس", "فيلبي", "كولوسي", "1 تسالونيكي", "2 تسالونيكي", "1 تيموثاوس", "2 تيموثاوس", "تيتوس", "فليمون", "عبرانيين", "يعقوب", "1 بطرس", "2 بطرس", "1 يوحنا", "2 يوحنا", "3 يوحنا", "يهوذا", "رؤيا"},
	"de": {"1. Mose", "2. Mose", "3. Mose", "4. Mose", "5. Mose", "Josua", "Richter", "Rut", "1. Samuel", "2. Samuel", "1. Könige", "2. Könige", "1. Chronik", "2. Chronik", "Esra", "Nehemia", "Esther", "Hiob", "Psalmen", "Sprüche", "Prediger", "Hohelied", "Jesaja", "Jeremia", "Klagelieder", "Hesekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadja", "Jona", "Micha", "Nahum", "Habakuk", "Zephanja", "Haggai", "Sacharja", "Maleachi", "Matthäus", "Markus", "Lukas", "Johannes", "Apostelgeschichte", "Römer", "1. Korinther", "2. Korinther", "Galater", "Epheser", "Philipper", "Kolosser", "1. Thessalonicher", "2. Thessalonicher", "1. Timotheus", "2. Timotheus", "Titus", "Philemon", "Hebräer", "Jakobus", "1. Petrus", "2. Petrus", "1. Johannes", "2. Johannes", "3. Johannes", "Judas", "Offenbarung"},
	"en": {"Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"},
	"es": {"Génesis", "Éxodo", "Levítico", "Números", "Deuteronomio", "Josué", "Jueces", "Rut", "1 Samuel", "2 Samuel", "1 Reyes", "2 Reyes", "1 Crónicas", "2 Crónicas", "Esdras", "Nehemías", "Ester", "Job", "Salmos", "Proverbios", "Eclesiastés", "Cantares", "Isaías", "Jeremías", "Lamentaciones", "Ezequiel", "Daniel", "Oseas", "Joel", "Amós", "Abdías", "Jonás", "Miqueas", "Nahum", "Habacuc", "Sofonías", "Hageo", "Zacarías", "Malaquías", "Mateo", "Marcos", "Lucas", "Juan", "Hechos", "Romanos", "1 Corintios", "2 Corintios", "Gálatas", "Efesios", "Filipenses", "Colosenses", "1 Tesalonicenses", "2 Tesalonicenses", "1 Timoteo", "2 Timoteo", "Tito", "Filemón", "Hebreos", "Santiago", "1 Pedro", "2 Pedro", "1 Juan", "2 Juan", "3 Juan", "Judas", "Apocalipsis"},
	"fi": {"1. Mooseksen kirja", "2. Mooseksen kirja", "3. Mooseksen kirja", "4. Mooseksen kirja", "5. Mooseksen kirja", "Joosua", "Tuomarien kirja", "Ruutin kirja", "1. Samuelin kirja", "2. Samuelin kirja", "1. Kuninkaiden kirja", "2. Kuninkaiden kirja", "1. Aikakirja", "2. Aikakirja", "Esran kirja", "Nehemian kirja", "Esterin kirja", "Jobin kirja", "Psalmit", "Sananlaskut", "Saarnaaja", "Laulujen laulu", "Jesajan kirja", "Jeremian kirja", "Valitusvirret", "Hesekielin kirja", "Danielin kirja", "Hoosean kirja", "Joelin kirja", "Aamoksen kirja", "Obadjan kirja", "Joonan kirja", "Miikan kirja", "Nahumin kirja", "Habakukin kirja", "Sefanjan kirja", "Haggain kirja", "Sakarjan kirja", "Malakian kirja", "Matteuksen evankeliumi", "Markuksen evankeliumi", "Luukkaan evankeliumi", "Johanneksen evankeliumi", "Apostolien teot", "Roomalaiskirje", "1. Korinttolaiskirje", "2. Korinttolaiskirje", "Galatalaiskirje", "Efesolaiskirje", "Filippiläiskirje", "Kolossalaiskirje", "1. Tessalonikalaiskirje", "2. Tessalonikalaiskirje", "1. Timoteuskirje", "2. Timoteuskirje", "Tiituksen kirje", "Filemonin kirje", "Heprealaiskirje", "Jaakobin kirje", "1. Pietarin kirje", "2. Pietarin kirje", "1. Johanneksen kirje", "2. Johanneksen kirje", "3. Johanneksen kirje", "Juudaksen kirje", "Johanneksen ilmestys"},
	"fr": {"Genèse", "Exode", "Lévitique", "Nombres", "Deutéronome", "Josué", "Juges", "Ruth", "1 Samuel", "2 Samuel", "1 Rois", "2 Rois", "1 Chroniques", "2 Chroniques", "Esdras", "Néhémie", "Esther", "Job", "Psaumes", "Proverbes", "Ecclésiaste", "Cantique des Cantiques", "Ésaïe", "Jérémie", "Lamentations", "Ézéchiel", "Daniel", "Osée", "Joël", "Amos", "Abdias", "Jonas", "Michée", "Nahum", "Habacuc", "Sophonie", "Aggée", "Zacharie", "Malachie", "Matthieu", "Marc", "Luc", "Jean", "Actes", "Romains", "1 Corinthiens", "2 Corinthiens", "Galates", "Éphésiens", "Philippiens", "Colossiens", "1 Thessaloniciens", "2 Thessaloniciens", "1 Timothée", "2 Timothée", "Tite", "Philémon", "Hébreux", "Jacques", "1 Pierre", "2 Pierre", "1 Jean", "2 Jean", "3 Jean", "Jude", "Apocalypse"},
	"he": {"בראשית", "שמות", "ויקרא", "במדבר", "דברים", "יהושע", "שופטים", "רות", "שמואל א", "שמואל ב", "מלכים א", "מלכים ב", "דברי הימים א", "דברי הימים ב", "עזרא", "נחמיה", "אסתר", "איוב", "תהלים", "משלי", "קהלת", "שיר השירים", "ישעיהו", "ירמיהו", "איכה", "יחזקאל", "דניאל", "הושע", "יואל", "עמוס", "עובדיה", "יונה", "מיכה", "נחום", "חבקוק", "צפניה", "חגי", "זכריה", "מלאכי", "מתי", "מרקוס", "לוקס", "יוחנן", "מעשי השליחים", "אל הרומים", "1 אל הקורינתים", "2 אל הקורינתים", "אל הגלטים", "אל האפסים", "אל הפיליפים", "אל הקולוסים", "1 אל התסלוניקים", "2 אל התסלוניקים", "1 אל טימותיוס", "2 אל טימותיוס", "אל טיטוס", "אל פילימון", "אל העברים", "אגרת יעקב", "1 כיפא", "2 כיפא", "1 יוחנן", "2 יוחנן", "3 יוחנן", "אגרת יהודה", "חזון יוחנן"},
	"hi": {"उत्पत्ति", "निर्गमन", "लैव्यव्यवस्था", "गिनती", "व्यवस्थाविवरण", "यहोशू", "न्यायियों", "रूत", "1 शमूएल", "2 शमूएल", "1 राजा", "2 राजा", "1 इतिहास", "2 इतिहास", "एज्रा", "नहेम्याह", "एस्तेर", "अय्यूब", "भजन संहिता", "नीतिवचन", "सभोपदेशक", "श्रेष्ठगीत", "यशायाह", "यिर्मयाह", "विलापगीत", "यहेजकेल", "दानिय्येल", "होशे", "योएल", "आमोस", "ओबद्याह", "योना", "मीका", "नहूम", "हबक्कूक", "सपन्याह", "हाग्गै", "जकर्याह", "मलाकी", "मत्ती", "मरकुस", "लूका", "यूहन्ना", "प्रेरितों के काम", "रोमियों", "1 कुरिन्थियों", "2 कुरिन्थियों", "गलातियों", "इफिसियों", "फिलिप्पियों", "कुलुस्सियों", "1 थिस्सलुनीकियों", "2 थिस्सलुनीकियों", "1 तीमुथियुस", "2 तीमुथियुस", "तीतुस", "फिलेमोन", "इब्रानियों", "याकूब", "1 पतरस", "2 पतरस", "1 यूहन्ना", "2 यूहन्ना", "3 यूहन्ना", "यहूदा", "प्रकाशितवाक्य"},
	"id": {"Kejadian", "Keluaran", "Imamat", "Bilangan", "Ulangan", "Yosua", "Hakim-hakim", "Rut", "1 Samuel", "2 Samuel", "1 Raja-raja", "2 Raja-raja", "1 Tawarikh", "2 Tawarikh", "Ezra", "Nehemia", "Ester", "Ayub", "Mazmur", "Amsal", "Pengkhotbah", "Kidung Agung", "Yesaya", "Yeremia", "Ratapan", "Yehezkiel", "Daniel", "Hosea", "Yoel", "Amos", "Obaja", "Yunus", "Mikha", "Nahum", "Habakuk", "Zefanya", "Hagai", "Zakharia", "Maleakhi", "Matius", "Markus", "Lukas", "Yohanes", "Kisah Para Rasul", "Roma", "1 Korintus", "2 Korintus", "Galatia", "Efesus", "Filipi", "Kolose", "1 Tesalonika", "2 Tesalonika", "1 Timotius", "2 Timotius", "Titus", "Filemon", "Ibrani", "Yakobus", "1 Petrus", "2 Petrus", "1 Yohanes", "2 Yohanes", "3 Yohanes", "Yudas", "Wahyu"},
	"it": {"Genesi", "Esodo", "Levitico", "Numeri", "Deuteronomio", "Giosuè", "Giudici", "Rut", "1 Samuele", "2 Samuele", "1 Re", "2 Re", "1 Cronache", "2 Cronache", "Esdra", "Neemia", "Ester", "Giobbe", "Salmi", "Proverbi", "Ecclesiaste", "Cantico dei Cantici", "Isaia", "Geremia", "Lamentazioni", "Ezechiele", "Daniele", "Osea", "Gioele", "Amos", "Abdia", "Giona", "Michea", "Naum", "Abacuc", "Sofonia", "Aggeo", "Zaccaria", "Malachia", "Matteo", "Marco", "Luca", "Giovanni", "Atti", "Romani", "1 Corinzi", "2 Corinzi", "Galati", "Efesini", "Filippesi", "Colossesi", "1 Tessalonicesi", "2 Tessalonicesi", "1 Timoteo", "2 Timoteo", "Tito", "Filemone", "Ebrei", "Giacomo", "1 Pietro", "2 Pietro", "1 Giovanni", "2 Giovanni", "3 Giovanni", "Giuda", "Apocalisse"},
	"ja": {"創世記", "出エジプト記", "レビ記", "民数記", "申命記", "ヨシュア記", "士師記", "ルツ記", "サムエル記上", "サムエル記下", "列王記上", "列王記下", "歴代志上", "歴代志下", "エズラ記", "ネヘミヤ記", "エステル記", "ヨブ記", "詩篇", "箴言", "伝道者の書", "雅歌", "イザヤ書", "エレミヤ書", "哀歌", "エゼキエル書", "ダニエル書", "ホセア書", "ヨエル書", "アモス書", "オバデヤ書", "ヨナ書", "ミカ書", "ナホム書", "ハバクク書", "ゼパニヤ書", "ハガイ書", "ゼカリヤ書", "マラキ書", "マタイの福音書", "マルコの福音書", "ルカの福音書", "ヨハネの福音書", "使徒の働き", "ローマ人への手紙", "コリント人への手紙第一", "コリント人への手紙第二", "ガラテヤ人への手紙", "エペソ人への手紙", "ピリピ人への手紙", "コロサイ人への手紙", "テサロニケ人への手紙第一", "テサロニケ人への手紙第二", "テモテへの手紙第一", "テモテへの手紙第二", "テトスへの手紙", "ピレモンへの手紙", "ヘブル人への手紙", "ヤコブの手紙", "ペテロの手紙第一", "ペテロの手紙第二", "ヨハネの手紙第一", "ヨハネの手紙第二", "ヨハネの手紙第三", "ユダの手紙", "ヨハネの黙示録"},
	"nl": {"Genesis", "Exodus", "Leviticus", "Numeri", "Deuteronomium", "Jozua", "Rechters", "Ruth", "1 Samuel", "2 Samuel", "1 Koningen", "2 Koningen", "1 Kronieken", "2 Kronieken", "Ezra", "Nehemia", "Esther", "Job", "Psalmen", "Spreuken", "Prediker", "Hooglied", "Jesaja", "Jeremia", "Klaagliederen", "Ezechiël", "Daniël", "Hosea", "Joël", "Amos", "Obadja", "Jona", "Micha", "Nahum", "Habakuk", "Zefanja", "Haggai", "Zacharia", "Maleachi", "Matteüs", "Marcus", "Lucas", "Johannes", "Handelingen", "Romeinen", "1 Korintiërs", "2 Korintiërs", "Galaten", "Efeziërs", "Filippenzen", "Kolossenzen", "1 Tessalonicenzen", "2 Tessalonicenzen", "1 Timoteüs", "2 Timoteüs", "Titus", "Filemon", "Hebreeën", "Jakobus", "1 Petrus", "2 Petrus", "1 Johannes", "2 Johannes", "3 Johannes", "Judas", "Openbaring"},
	"pl": {"Księga Rodzaju", "Księga Wyjścia", "Księga Kapłańska", "Księga Liczb", "Księga Powtórzonego Prawa", "Księga Jozuego", "Księga Sędziów", "Księga Rut", "1 Księga Samuela", "2 Księga Samuela", "1 Księga Królewska", "2 Księga Królewska", "1 Księga Kronik", "2 Księga Kronik", "Księga Ezdrasza", "Księga Nehemiasza", "Księga Estery", "Księga Hioba", "Księga Psalmów", "Księga Przysłów", "Księga Koheleta", "Pieśń nad Pieśniami", "Księga Izajasza", "Księga Jeremiasza", "Lamentacje", "Księga Ezechiela", "Księga Daniela", "Księga Ozeasza", "Księga Joela", "Księga Amosa", "Księga Abdiasza", "Księga Jonasza", "Księga Micheasza", "Księga Nahuma", "Księga Habakuka", "Księga Sofoniasza", "Księga Aggeusza", "Księga Zachariasza", "Księga Malachiasza", "Ewangelia Mateusza", "Ewangelia Marka", "Ewangelia Łukasza", "Ewangelia Jana", "Dzieje Apostolskie", "List do Rzymian", "1 List do Koryntian", "2 List do Koryntian", "List do Galatów", "List do Efezjan", "List do Filipian", "List do Kolosan", "1 List do Tesaloniczan", "2 List do Tesaloniczan", "1 List do Tymoteusza", "2 List do Tymoteusza", "List do Tytusa", "List do Filemona", "List do Hebrajczyków", "List Jakuba", "1 List Piotra", "2 List Piotra", "1 List Jana", "2 List Jana", "3 List Jana", "List Judy", "Apokalipsa św. Jana"},
	"pt": {"Gênesis", "Êxodo", "Levítico", "Números", "Deuteronômio", "Josué", "Juízes", "Rute", "1 Samuel", "2 Samuel", "1 Reis", "2 Reis", "1 Crônicas", "2 Crônicas", "Esdras", "Neemias", "Ester", "Jó", "Salmos", "Provérbios", "Eclesiastes", "Cânticos", "Isaías", "Jeremias", "Lamentações", "Ezequiel", "Daniel", "Oseias", "Joel", "Amós", "Obadias", "Jonas", "Miqueias", "Naum", "Habacuque", "Sofonias", "Ageu", "Zacarias", "Malaquias", "Mateus", "Marcos", "Lucas", "João", "Atos", "Romanos", "1 Coríntios", "2 Coríntios", "Gálatas", "Efésios", "Filipenses", "Colossenses", "1 Tessalonicenses", "2 Tessalonicenses", "1 Timóteo", "2 Timóteo", "Tito", "Filemom", "Hebreus", "Tiago", "1 Pedro", "2 Pedro", "1 João", "2 João", "3 João", "Judas", "Apocalipse"},
	"ro": {"Geneza", "Exodul", "Leviticul", "Numerii", "Deuteronomul", "Iosua", "Judecătorii", "Rut", "1 Samuel", "2 Samuel", "1 Regi", "2 Regi", "1 Cronici", "2 Cronici", "Ezra", "Neemia", "Estera", "Iov", "Psalmii", "Proverbe", "Eclesiastul", "Cântarea Cântărilor", "Isaia", "Ieremia", "Plângerile", "Ezechiel", "Daniel", "Osea", "Ioel", "Amos", "Obadia", "Iona", "Mica", "Naum", "Habacuc", "Țefania", "Hagai", "Zaharia", "Maleahi", "Matei", "Marcu", "Luca", "Ioan", "Faptele Apostolilor", "Romani", "1 Corinteni", "2 Corinteni", "Galateni", "Efeseni", "Filipeni", "Coloseni", "1 Tesaloniceni", "2 Tesaloniceni", "1 Timotei", "2 Timotei", "Tit", "Filimon", "Evrei", "Iacov", "1 Petru", "2 Petru", "1 Ioan", "2 Ioan", "3 Ioan", "Iuda", "Apocalipsa"},
	"ru": {"Бытие", "Исход", "Левит", "Числа", "Второзаконие", "Иисус Навин", "Книга Судей", "Книга Руфь", "1-я Царств", "2-я Царств", "3-я Царств", "4-я Царств", "1-я Паралипоменон", "2-я Паралипоменон", "Книга Ездры", "Книга Неемии", "Книга Есфири", "Книга Иова", "Псалтирь", "Книга Притчей", "Книга Екклесиаста", "Песнь Песней", "Книга Исаии", "Книга Иеремии", "Плач Иеремии", "Книга Иезекииля", "Книга Даниила", "Книга Осии", "Книга Иоиля", "Книга Амоса", "Книга Авдия", "Книга Ионы", "Книга Михея", "Книга Наума", "Книга Аввакума", "Книга Софонии", "Книга Аггея", "Книга Захарии", "Книга Малахии", "Евангелие от Матфея", "Евангелие от Марка", "Евангелие от Луки", "Евангелие от Иоанна", "Деяния апостолов", "Послание к Римлянам", "1-е послание к Коринфянам", "2-е послание к Коринфянам", "Послание к Галатам", "Послание к Ефесянам", "Послание к Филиппийцам", "Послание к Колоссянам", "1-е послание к Фессалоникийцам", "2-е послание к Фессалоникийцам", "1-е послание к Тимофею", "2-е послание к Тимофею", "Послание к Титу", "Послание к Филимону", "Послание к Евреям", "Послание Иакова", "1-е послание Петра", "2-е послание Петра", "1-е послание Иоанна", "2-е послание Иоанна", "3-е послание Иоанна", "Послание Иуды", "Откровение Иоанна Богослова"},
	"sw": {"Mwanzo", "Kutoka", "Mambo ya Walawi", "Hesabu", "Kumbukumbu la Torati", "Yoshua", "Waamuzi", "Ruthu", "1 Samweli", "2 Samweli", "1 Wafalme", "2 Wafalme", "1 Mambo ya Nyakati", "2 Mambo ya Nyakati", "Ezra", "Nehemia", "Esta", "Ayubu", "Zaburi", "Mithali", "Mhubiri", "Wimbo Ulio Bora", "Isaya", "Yeremia", "Maombolezo", "Ezekieli", "Danieli", "Hosea", "Yoeli", "Amosi", "Obadia", "Yona", "Mika", "Nahumu", "Habakuki", "Sefania", "Hagai", "Zekaria", "Malaki", "Mathayo", "Marko", "Luka", "Yohana", "Matendo", "Waroma", "1 Wakorintho", "2 Wakorintho", "Wagalatia", "Waefeso", "Wafilipi", "Wakolosai", "1 Wathesalonike", "2 Wathesalonike", "1 Timotheo", "2 Timotheo", "Tito", "Filemon", "Waebrania", "Yakobo", "1 Petro", "2 Petro", "1 Yohana", "2 Yohana", "3 Yohana", "Yuda", "Ufunuo"},
	"tl": {"Genesis", "Exodo", "Levitico", "Mga Bilang", "Deuteronomio", "Josue", "Mga Hukom", "Ruth", "1 Samuel", "2 Samuel", "1 Mga Hari", "2 Mga Hari", "1 Mga Kronika", "2 Mga Kronika", "Ezra", "Nehemias", "Ester", "Job", "Mga Awit", "Mga Kawikaan", "Ang Mangangaral", "Awit ni Solomon", "Isaias", "Jeremias", "Mga Panaghoy", "Ezekiel", "Daniel", "Oseas", "Joel", "Amos", "Obadias", "Jonas", "Mikas", "Nahum", "Habacuc", "Sofonias", "Ageo", "Zacarias", "Malakias", "Mateo", "Marcos", "Lucas", "Juan", "Mga Gawa", "Mga Taga-Roma", "1 Mga Taga-Corinto", "2 Mga Taga-Corinto", "Mga Taga-Galacia", "Mga Taga-Efeso", "Mga Taga-Filipos", "Mga Taga-Colosas", "1 Mga Taga-Tesalonica", "2 Mga Taga-Tesalonica", "1 Timoteo", "2 Timoteo", "Tito", "Filemon", "Mga Hebreo", "Santiago", "1 Pedro", "2 Pedro", "1 Juan", "2 Juan", "3 Juan", "Judas", "Pahayag"},
	"vi": {"Sáng Thế Ký", "Xuất Ê-díp-tô Ký", "Lê-vi Ký", "Dân Số Ký", "Phục Truyền Luật Lệ Ký", "Giô-suê", "Các Quan Xét", "Ru-tơ", "1 Sa-mu-ên", "2 Sa-mu-ên", "1 Các Vua", "2 Các Vua", "1 Sử Ký", "2 Sử Ký", "E-xơ-ra", "Nê-hê-mi", "Ê-xơ-tê", "Gióp", "Thánh Thi", "Châm Ngôn", "Truyền Đạo", "Nhã Ca", "Ê-sai", "Giê-rê-mi", "Ca Thương", "Ê-xê-chi-ên", "Đa-ni-ên", "Ô-sê", "Giô-ên", "A-mốt", "Áp-đia", "Giô-na", "Mi-chê", "Na-hum", "Ha-ba-cúc", "Sô-phô-ni", "Ha-gai", "Xa-cha-ri", "Ma-la-chi", "Ma-thi-ơ", "Mác", "Lu-ca", "Giăng", "Công Vụ Các Sứ Đồ", "Rô-ma", "1 Cô-rinh-tô", "2 Cô-rinh-tô", "Ga-la-ti", "Ê-phê-sô", "Phi-líp", "Cô-lô-se", "1 Tê-sa-lô-ni-ca", "2 Tê-sa-lô-ni-ca", "1 Ti-mô-thê", "2 Ti-mô-thê", "Tít", "Phi-lê-môn", "Hê-bơ-rơ", "Gia-cơ", "1 Phi-e-rơ", "2 Phi-e-rơ", "1 Giăng", "2 Giăng", "3 Giăng", "Giu-đe", "Khải Huyền"},
	"zh": {"创世记", "出埃及记", "利未记", "民数记", "申命记", "约书亚记", "士师记", "路得记", "撒母耳记上", "撒母耳记下", "列王纪上", "列王纪下", "历代志上", "历代志下", "以斯拉记", "尼希米记", "以斯帖记", "约伯记", "诗篇", "箴言", "传道书", "雅歌", "以赛亚书", "耶利米书", "耶利米哀歌", "以西结书", "但以理书", "何西阿书", "约珥书", "阿摩司书", "俄巴底亚书", "约拿书", "弥迦书", "那鸿书", "哈巴谷书", "西番雅书", "哈该书", "撒迦利亚书", "玛拉基书", "马太福音", "马可福音", "路加福音", "约翰福音", "使徒行传", "罗马书", "哥林多前书", "哥林多后书", "加拉太书", "以弗所书", "腓立比书", "歌罗西书", "帖撒罗尼迦前书", "帖撒罗尼迦后书", "提摩太前书", "提摩太后书", "提多书", "腓利门书", "希伯来书", "雅各书", "彼得前书", "彼得后书", "约翰一书", "约翰二书", "约翰三书", "犹大书", "启示录"},
}

var localizedLabels = map[string]map[string]string{
	"af": {
		"addToDesign": "Voeg by ontwerp",
		"bible": "Bybel",
		"book": "Boek",
		"chapter": "Hoofstuk",
		"chapterNotFound": "Hoofstuk nie gevind in hierdie weergawe nie",
		"chapterPrefix": "Hoofstuk ",
		"chapterSuffix": "",
		"copyAllText": "Kopieer Alle Teks",
		"copyAsCsv": "Kopieer as CSV",
		"copyAsJson": "Kopieer as JSON",
		"csvCopied": "CSV gekopieer!",
		"exHtml": "Geëksporteer na HTML!",
		"exMarkdown": "Eksporteer na Markdown!",
		"exPlainText": "Geëksporteer na Plain Text!",
		"exportHtml": "Eksporteer na HTML",
		"exportMarkdown": "Eksporteer na Markdown",
		"exportPlainText": "Eksporteer na Plain Text",
		"failedToLoad": "Kon nie verse laai nie",
		"failedToSave": "Kon nie lêer stoor nie: %@",
		"fetchingWord": "Laai God se Woord...",
		"fontSize": "Lettergrootte",
		"fontSizePt": "%dpt",
		"from": "Vanaf",
		"invalidData": "Ongeldige dataformaat",
		"jsonCopied": "JSON gekopieer!",
		"language": "Taal",
		"loading": "Laai tans...",
		"passageCopied": "Hele gedeelte gekopieer!",
		"passageNotFound": "Gedeelte nie gevind nie",
		"referenceCopied": "Verwysing gekopieer!",
		"savePanelMessage": "Kies waar om jou Bybelgedeelte te stoor",
		"selectPassage": "Kies 'n boek en hoofstuk om te begin lees",
		"selectPrompt": "Kies 'n boek en hoofstuk om verse te sien",
		"settings": "Instellings",
		"share": "Deel",
		"theme": "Tema",
		"themeDark": "Donker",
		"themeLight": "Lig",
		"themeSepia": "Sepia",
		"themeSystem": "Stelsel",
		"to": "Tot",
		"verse": "Vers",
		"verseCopied": "Teks gekopieer!",
		"versePrefix": "Vers ",
		"verseSuffix": "",
		"versesOptional": "Verse (Opsioneel)",
		"version": "Weergawe",
		"bibleVersions": "Bybel Weergawes",
		"download": "Laai Af",
		"downloadComplete": "Laai Af Voltooi!",
		"downloadLanguage": "Laai Alle Weergawes Af",
		"downloadManager": "Laai Af Bestuurder",
		"downloadVersion": "Laai Weergawe Af",
		"downloaded": "Afgelaai",
		"downloading": "Laai Af...",
		"deleteDownload": "Verwyder Afgelaaide",
		"deleteAllDownloads": "Verwyder Alles",
		"notAvailableOffline": "Nie beskikbaar vanlyn nie. Laai hierdie weergawe af in Instellings.",
	},
	"ar": {
		"addToDesign": "إضافة إلى التصميم",
		"bible": "الكتاب المقدس",
		"book": "السفر",
		"chapter": "الأصحاح",
		"chapterNotFound": "لم يتم العثور على الأصحاح في هذا الإصدار",
		"chapterPrefix": "الأصحاح ",
		"chapterSuffix": "",
		"copyAllText": "نسخ كل النص",
		"copyAsCsv": "نسخ كـ CSV",
		"copyAsJson": "نسخ كـ JSON",
		"csvCopied": "تم نسخ CSV!",
		"exHtml": "تم التصدير إلى HTML!",
		"exMarkdown": "تم التصدير إلى Markdown!",
		"exPlainText": "تم التصدير إلى Plain Text!",
		"exportHtml": "تصدير إلى HTML",
		"exportMarkdown": "تصدير إلى Markdown",
		"exportPlainText": "تصدير إلى Plain Text",
		"failedToLoad": "فشل تحميل الآيات",
		"failedToSave": "فشل حفظ الملف: %@",
		"fetchingWord": "جارٍ تحميل كلمة الله...",
		"fontSize": "حجم الخط",
		"fontSizePt": "%dpt",
		"from": "من",
		"invalidData": "تنسيق بيانات غير صالح",
		"jsonCopied": "تم نسخ JSON!",
		"language": "اللغة",
		"loading": "جارٍ التحميل...",
		"passageCopied": "تم نسخ المقطع بالكامل!",
		"passageNotFound": "لم يتم العثور على المقطع",
		"referenceCopied": "تم نسخ المرجع!",
		"savePanelMessage": "اختر مكان حفظ مقطع الكتاب المقدس",
		"selectPassage": "اختر سفرًا وأصحاحًا لبدء القراءة",
		"selectPrompt": "اختر سفرًا وأصحاحًا لعرض الآيات",
		"settings": "الإعدادات",
		"share": "مشاركة",
		"theme": "المظهر",
		"themeDark": "داكن",
		"themeLight": "فاتح",
		"themeSepia": "سيبيا",
		"themeSystem": "النظام",
		"to": "إلى",
		"verse": "الآية",
		"verseCopied": "تم نسخ نص الآية!",
		"versePrefix": "الآية ",
		"verseSuffix": "",
		"versesOptional": "الآيات (اختياري)",
		"version": "الإصدار",
		"bibleVersions": "إصدارات الكتاب المقدس",
		"download": "تنزيل",
		"downloadComplete": "اكتمل التنزيل!",
		"downloadLanguage": "تنزيل جميع الإصدارات",
		"downloadManager": "مدير التنزيل",
		"downloadVersion": "تنزيل الإصدار",
		"downloaded": "تم التنزيل",
		"downloading": "جارٍ التنزيل...",
		"deleteDownload": "حذف التنزيل",
		"deleteAllDownloads": "حذف الكل",
		"notAvailableOffline": "غير متوفر بدون اتصال. قم بتنزيل هذا الإصدار في الإعدادات.",
	},
	"de": {
		"addToDesign": "Zum Design hinzufügen",
		"bible": "Bibel",
		"book": "Buch",
		"chapter": "Kapitel",
		"chapterNotFound": "Kapitel in dieser Übersetzung nicht gefunden",
		"chapterPrefix": "Kapitel ",
		"chapterSuffix": "",
		"copyAllText": "Gesamten Text kopieren",
		"copyAsCsv": "Als CSV kopieren",
		"copyAsJson": "Als JSON kopieren",
		"csvCopied": "CSV kopiert!",
		"exHtml": "Als HTML exportiert!",
		"exMarkdown": "Als Markdown exportiert!",
		"exPlainText": "Als Plain Text exportiert!",
		"exportHtml": "Als HTML exportieren",
		"exportMarkdown": "Als Markdown exportieren",
		"exportPlainText": "Als Plain Text exportieren",
		"failedToLoad": "Verse konnten nicht geladen werden",
		"failedToSave": "Datei konnte nicht gespeichert werden: %@",
		"fetchingWord": "Lade Gottes Wort...",
		"fontSize": "Schriftgröße",
		"fontSizePt": "%dpt",
		"from": "Von",
		"invalidData": "Ungültiges Datenformat",
		"jsonCopied": "JSON kopiert!",
		"language": "Sprache",
		"loading": "Lädt...",
		"passageCopied": "Ganze Passage kopiert!",
		"passageNotFound": "Passage nicht gefunden",
		"referenceCopied": "Referenz kopiert!",
		"savePanelMessage": "Wähle, wo die Bibelstelle gespeichert werden soll",
		"selectPassage": "Wähle ein Buch und Kapitel zum Lesen",
		"selectPrompt": "Wähle ein Buch und Kapitel, um Verse anzuzeigen",
		"settings": "Einstellungen",
		"share": "Teilen",
		"theme": "Design",
		"themeDark": "Dunkel",
		"themeLight": "Hell",
		"themeSepia": "Sepia",
		"themeSystem": "System",
		"to": "Bis",
		"verse": "Vers",
		"verseCopied": "Vers kopiert!",
		"versePrefix": "Vers ",
		"verseSuffix": "",
		"versesOptional": "Verse (optional)",
		"version": "Übersetzung",
		"bibleVersions": "Bibelübersetzungen",
		"download": "Herunterladen",
		"downloadComplete": "Download abgeschlossen!",
		"downloadLanguage": "Alle Übersetzungen herunterladen",
		"downloadManager": "Download-Manager",
		"downloadVersion": "Übersetzung herunterladen",
		"downloaded": "Heruntergeladen",
		"downloading": "Lädt herunter...",
		"deleteDownload": "Download löschen",
		"deleteAllDownloads": "Alle löschen",
		"notAvailableOffline": "Nicht offline verfügbar. Lade diese Übersetzung in den Einstellungen herunter.",
	},
	"en": {
		"addToDesign": "Add to design",
		"bible": "Bible",
		"book": "Book",
		"chapter": "Chapter",
		"chapterNotFound": "Chapter not found in this version",
		"chapterPrefix": "Chapter ",
		"chapterSuffix": "",
		"copyAllText": "Copy All Text",
		"copyAsCsv": "Copy as CSV",
		"copyAsJson": "Copy as JSON",
		"csvCopied": "CSV copied!",
		"exHtml": "Exported to HTML!",
		"exMarkdown": "Exported to Markdown!",
		"exPlainText": "Exported to Plain Text!",
		"exportHtml": "Export to HTML",
		"exportMarkdown": "Export to Markdown",
		"exportPlainText": "Export to Plain Text",
		"failedToLoad": "Failed to load verses",
		"failedToSave": "Failed to save file: %@",
		"fetchingWord": "Fetching God's Word...",
		"fontSize": "Font Size",
		"fontSizePt": "%dpt",
		"from": "From",
		"invalidData": "Invalid data format",
		"jsonCopied": "JSON copied!",
		"language": "Language",
		"loading": "Loading...",
		"passageCopied": "Entire passage copied!",
		"passageNotFound": "Passage not found",
		"referenceCopied": "Reference copied!",
		"savePanelMessage": "Choose where to save your Bible passage",
		"selectPassage": "Select a passage to begin reading.",
		"selectPrompt": "Select a book and chapter to view verses",
		"settings": "Settings",
		"share": "Share",
		"theme": "Theme",
		"themeDark": "Dark",
		"themeLight": "Light",
		"themeSepia": "Sepia",
		"themeSystem": "System",
		"to": "To",
		"verse": "Verse",
		"verseCopied": "Verse text copied!",
		"versePrefix": "Verse ",
		"verseSuffix": "",
		"versesOptional": "Verses (Optional)",
		"version": "Version",
		"bibleVersions": "Bible Versions",
		"download": "Download",
		"downloadComplete": "Download Complete!",
		"downloadLanguage": "Download All Versions",
		"downloadManager": "Download Manager",
		"downloadVersion": "Download Version",
		"downloaded": "Downloaded",
		"downloading": "Downloading...",
		"deleteDownload": "Delete Download",
		"deleteAllDownloads": "Delete All",
		"notAvailableOffline": "Not available offline. Download this version in Settings.",
	},
	"es": {
		"addToDesign": "Agregar al diseño",
		"bible": "Biblia",
		"book": "Libro",
		"chapter": "Capítulo",
		"chapterNotFound": "Capítulo no encontrado en esta versión",
		"chapterPrefix": "Capítulo ",
		"chapterSuffix": "",
		"copyAllText": "Copiar todo el texto",
		"copyAsCsv": "Copiar como CSV",
		"copyAsJson": "Copiar como JSON",
		"csvCopied": "¡CSV copiado!",
		"exHtml": "¡Exportado a HTML!",
		"exMarkdown": "¡Exportado a Markdown!",
		"exPlainText": "¡Exportado a texto plano!",
		"exportHtml": "Exportar a HTML",
		"exportMarkdown": "Exportar a Markdown",
		"exportPlainText": "Exportar a texto plano",
		"failedToLoad": "Error al cargar los versículos",
		"failedToSave": "Error al guardar el archivo: %@",
		"fetchingWord": "Cargando la Palabra de Dios...",
		"fontSize": "Tamaño de fuente",
		"fontSizePt": "%dpt",
		"from": "Desde",
		"invalidData": "Formato de datos inválido",
		"jsonCopied": "¡JSON copiado!",
		"language": "Idioma",
		"loading": "Cargando...",
		"passageCopied": "¡Pasaje completo copiado!",
		"passageNotFound": "Pasaje no encontrado",
		"referenceCopied": "¡Referencia copiada!",
		"savePanelMessage": "Elige dónde guardar tu pasaje bíblico",
		"selectPassage": "Selecciona un libro y capítulo para empezar a leer",
		"selectPrompt": "Selecciona un libro y capítulo para ver los versículos",
		"settings": "Configuración",
		"share": "Compartir",
		"theme": "Tema",
		"themeDark": "Oscuro",
		"themeLight": "Claro",
		"themeSepia": "Sepia",
		"themeSystem": "Sistema",
		"to": "Hasta",
		"verse": "Versículo",
		"verseCopied": "¡Texto del versículo copiado!",
		"versePrefix": "Versículo ",
		"verseSuffix": "",
		"versesOptional": "Versículos (Opcional)",
		"version": "Versión",
		"bibleVersions": "Versiones de la Biblia",
		"download": "Descargar",
		"downloadComplete": "¡Descarga Completa!",
		"downloadLanguage": "Descargar Todas las Versiones",
		"downloadManager": "Gestor de Descargas",
		"downloadVersion": "Descargar Versión",
		"downloaded": "Descargado",
		"downloading": "Descargando...",
		"deleteDownload": "Eliminar Descarga",
		"deleteAllDownloads": "Eliminar Todo",
		"notAvailableOffline": "No disponible sin conexión. Descarga esta versión en Configuración.",
	},
	"fi": {
		"addToDesign": "Lisää suunnitteluun",
		"bible": "Raamattu",
		"book": "Kirja",
		"chapter": "Luku",
		"chapterNotFound": "Lukua ei löydy tästä käännöksestä",
		"chapterPrefix": "Luku ",
		"chapterSuffix": "",
		"copyAllText": "Kopioi koko teksti",
		"copyAsCsv": "Kopioi CSV-muodossa",
		"copyAsJson": "Kopioi JSON-muodossa",
		"csvCopied": "CSV kopioitu!",
		"exHtml": "Viety HTML-muotoon!",
		"exMarkdown": "Viety Markdown-muotoon!",
		"exPlainText": "Viety tekstimuotoon!",
		"exportHtml": "Vie HTML-muotoon",
		"exportMarkdown": "Vie Markdown-muotoon",
		"exportPlainText": "Vie tekstimuotoon",
		"failedToLoad": "Jakeiden lataus epäonnistui",
		"failedToSave": "Tiedoston tallennus epäonnistui: %@",
		"fetchingWord": "Ladataan Jumalan sanaa...",
		"fontSize": "Fonttikoko",
		"fontSizePt": "%dpt",
		"from": "Alkaen",
		"invalidData": "Virheellinen tietomuoto",
		"jsonCopied": "JSON kopioitu!",
		"language": "Kieli",
		"loading": "Ladataan...",
		"passageCopied": "Koko kohta kopioitu!",
		"passageNotFound": "Kohtaa ei löytynyt",
		"referenceCopied": "Viite kopioitu!",
		"savePanelMessage": "Valitse minne haluat tallentaa raamatunkohtasi",
		"selectPassage": "Valitse kirja ja luku aloittaaksesi lukemisen",
		"selectPrompt": "Valitse kirja ja luku nähdäksesi jakeet",
		"settings": "Asetukset",
		"share": "Jaa",
		"theme": "Teema",
		"themeDark": "Tumma",
		"themeLight": "Vaalea",
		"themeSepia": "Seepia",
		"themeSystem": "Järjestelmä",
		"to": "Saakka",
		"verse": "Jae",
		"verseCopied": "Jae kopioitu!",
		"versePrefix": "Jae ",
		"verseSuffix": "",
		"versesOptional": "Jakeet (Valinnainen)",
		"version": "Käännös",
		"bibleVersions": "Raamattukäännökset",
		"download": "Lataa",
		"downloadComplete": "Lataus Valmis!",
		"downloadLanguage": "Lataa Kaikki Käännökset",
		"downloadManager": "Latausten Hallinta",
		"downloadVersion": "Lataa Käännös",
		"downloaded": "Ladattu",
		"downloading": "Ladataan...",
		"deleteDownload": "Poista Lataus",
		"deleteAllDownloads": "Poista Kaikki",
		"notAvailableOffline": "Ei saatavilla offline-tilassa. Lataa tämä käännös asetuksissa.",
	},
	"fr": {
		"addToDesign": "Ajouter au design",
		"bible": "Bible",
		"book": "Livre",
		"chapter": "Chapitre",
		"chapterNotFound": "Chapitre introuvable dans cette version",
		"chapterPrefix": "Chapitre ",
		"chapterSuffix": "",
		"copyAllText": "Copier tout le texte",
		"copyAsCsv": "Copier en CSV",
		"copyAsJson": "Copier en JSON",
		"csvCopied": "CSV copié !",
		"exHtml": "Exporté en HTML !",
		"exMarkdown": "Exporté en Markdown !",
		"exPlainText": "Exporté en texte brut !",
		"exportHtml": "Exporter en HTML",
		"exportMarkdown": "Exporter en Markdown",
		"exportPlainText": "Exporter en texte brut",
		"failedToLoad": "Échec du chargement des versets",
		"failedToSave": "Échec de l'enregistrement du fichier : %@",
		"fetchingWord": "Chargement de la Parole de Dieu...",
		"fontSize": "Taille de police",
		"fontSizePt": "%dpt",
		"from": "De",
		"invalidData": "Format de données invalide",
		"jsonCopied": "JSON copié !",
		"language": "Langue",
		"loading": "Chargement...",
		"passageCopied": "Passage entier copié !",
		"passageNotFound": "Passage introuvable",
		"referenceCopied": "Référence copiée !",
		"savePanelMessage": "Choisissez où enregistrer votre passage biblique",
		"selectPassage": "Sélectionnez un livre et un chapitre pour commencer à lire",
		"selectPrompt": "Sélectionnez un livre et un chapitre pour voir les versets",
		"settings": "Paramètres",
		"share": "Partager",
		"theme": "Thème",
		"themeDark": "Sombre",
		"themeLight": "Clair",
		"themeSepia": "Sépia",
		"themeSystem": "Système",
		"to": "À",
		"verse": "Vers",
		"verseCopied": "Texte du verset copié !",
		"versePrefix": "Vers ",
		"verseSuffix": "",
		"versesOptional": "Versets (Facultatif)",
		"version": "Version",
		"bibleVersions": "Versions de la Bible",
		"download": "Télécharger",
		"downloadComplete": "Téléchargement terminé !",
		"downloadLanguage": "Télécharger toutes les versions",
		"downloadManager": "Gestionnaire de téléchargements",
		"downloadVersion": "Télécharger la version",
		"downloaded": "Téléchargé",
		"downloading": "Téléchargement...",
		"deleteDownload": "Supprimer le téléchargement",
		"deleteAllDownloads": "Tout supprimer",
		"notAvailableOffline": "Non disponible hors ligne. Téléchargez cette version dans Paramètres.",
	},
	"he": {
		"addToDesign": "הוסף לעיצוב",
		"bible": "תנ\"ך",
		"book": "ספר",
		"chapter": "פרק",
		"chapterNotFound": "הפרק לא נמצא בגרסה זו",
		"chapterPrefix": "פרק ",
		"chapterSuffix": "",
		"copyAllText": "העתק את כל הטקסט",
		"copyAsCsv": "העתק כ-CSV",
		"copyAsJson": "העתק כ-JSON",
		"csvCopied": "CSV הועתק!",
		"exHtml": "יוצא ל-HTML!",
		"exMarkdown": "יוצא ל-Markdown!",
		"exPlainText": "יוצא לטקסט פשוט!",
		"exportHtml": "ייצא ל-HTML",
		"exportMarkdown": "ייצא ל-Markdown",
		"exportPlainText": "ייצא לטקסט פשוט",
		"failedToLoad": "טעינת הפסוקים נכשלה",
		"failedToSave": "שמירת הקובץ נכשלה: %@",
		"fetchingWord": "טוען את דבר אלוהים...",
		"fontSize": "גודל גופן",
		"fontSizePt": "%dpt",
		"from": "מ-",
		"invalidData": "פורמט נתונים לא חוקי",
		"jsonCopied": "JSON הועתק!",
		"language": "שפה",
		"loading": "טוען...",
		"passageCopied": "הקטע כולו הועתק!",
		"passageNotFound": "הקטע לא נמצא",
		"referenceCopied": "ההפניה הועתקה!",
		"savePanelMessage": "בחר היכן לשמור את קטע התנ\"ך שלך",
		"selectPassage": "בחר ספר ופרק כדי להתחיל לקרוא",
		"selectPrompt": "בחר ספר ופרק לצפייה בפסוקים",
		"settings": "הגדרות",
		"share": "שתף",
		"theme": "ערכת נושא",
		"themeDark": "כהה",
		"themeLight": "בהיר",
		"themeSepia": "ספיה",
		"themeSystem": "מערכת",
		"to": "עד",
		"verse": "פסוק",
		"verseCopied": "טקסט הפסוק הועתק!",
		"versePrefix": "פסוק ",
		"verseSuffix": "",
		"versesOptional": "פסוקים (אופציונלי)",
		"version": "גרסה",
		"bibleVersions": "גרסאות התנ\"ך",
		"download": "הורד",
		"downloadComplete": "ההורדה הושלמה!",
		"downloadLanguage": "הורד את כל הגרסאות",
		"downloadManager": "מנהל ההורדות",
		"downloadVersion": "הורד גרסה",
		"downloaded": "הורד",
		"downloading": "מוריד...",
		"deleteDownload": "מחק הורדה",
		"deleteAllDownloads": "מחק הכל",
		"notAvailableOffline": "לא זמין במצב לא מקוון. הורד גרסה זו בהגדרות.",
	},
	"hi": {
		"addToDesign": "डिज़ाइन में जोड़ें",
		"bible": "बाइबल",
		"book": "पुस्तक",
		"chapter": "अध्याय",
		"chapterNotFound": "इस संस्करण में अध्याय नहीं मिला",
		"chapterPrefix": "अध्याय ",
		"chapterSuffix": "",
		"copyAllText": "सभी टेक्स्ट कॉपी करें",
		"copyAsCsv": "CSV के रूप में कॉपी करें",
		"copyAsJson": "JSON के रूप में कॉपी करें",
		"csvCopied": "CSV कॉपी हुआ!",
		"exHtml": "HTML में निर्यात हुआ!",
		"exMarkdown": "Markdown में निर्यात किया गया!",
		"exPlainText": "Plain Text में निर्यात हुआ!",
		"exportHtml": "HTML में निर्यात करें",
		"exportMarkdown": "Markdown में निर्यात करें",
		"exportPlainText": "Plain Text में निर्यात करें",
		"failedToLoad": "पद्य लोड करने में विफल",
		"failedToSave": "फ़ाइल सहेजने में विफल: %@",
		"fetchingWord": "परमेश्वर का वचन लोड हो रहा है...",
		"fontSize": "फ़ॉन्ट आकार",
		"fontSizePt": "%dpt",
		"from": "से",
		"invalidData": "अमान्य डेटा प्रारूप",
		"jsonCopied": "JSON कॉपी हुआ!",
		"language": "भाषा",
		"loading": "लोड हो रहा है...",
		"passageCopied": "पूरा अंश कॉपी हो गया!",
		"passageNotFound": "अंश नहीं मिला",
		"referenceCopied": "संदर्भ कॉपी हो गया!",
		"savePanelMessage": "अपना बाइबल अंश सहेजने के लिए स्थान चुनें",
		"selectPassage": "पढ़ना शुरू करने के लिए कोई पुस्तक और अध्याय चुनें",
		"selectPrompt": "पद्य देखने के लिए कोई पुस्तक और अध्याय चुनें",
		"settings": "सेटिंग्स",
		"share": "शेयर करें",
		"theme": "थीम",
		"themeDark": "गहरा",
		"themeLight": "हल्का",
		"themeSepia": "सेपिया",
		"themeSystem": "सिस्टम",
		"to": "तक",
		"verse": "पद",
		"verseCopied": "पद्य टेक्स्ट कॉपी हो गया!",
		"versePrefix": "पद ",
		"verseSuffix": "",
		"versesOptional": "पद्य (वैकल्पिक)",
		"version": "संस्करण",
		"bibleVersions": "बाइबल संस्करण",
		"download": "डाउनलोड",
		"downloadComplete": "डाउनलोड पूर्ण!",
		"downloadLanguage": "सभी संस्करण डाउनलोड करें",
		"downloadManager": "डाउनलोड प्रबंधक",
		"downloadVersion": "संस्करण डाउनलोड करें",
		"downloaded": "डाउनलोड हुआ",
		"downloading": "डाउनलोड हो रहा है...",
		"deleteDownload": "डाउनलोड हटाएं",
		"deleteAllDownloads": "सभी हटाएं",
		"notAvailableOffline": "ऑफ़लाइन उपलब्ध नहीं। सेटिंग्स में इस संस्करण को डाउनलोड करें।",
	},
	"id": {
		"addToDesign": "Tambahkan ke desain",
		"bible": "Alkitab",
		"book": "Kitab",
		"chapter": "Pasal",
		"chapterNotFound": "Pasal tidak ditemukan dalam versi ini",
		"chapterPrefix": "Pasal ",
		"chapterSuffix": "",
		"copyAllText": "Salin Semua Teks",
		"copyAsCsv": "Salin sebagai CSV",
		"copyAsJson": "Salin sebagai JSON",
		"csvCopied": "CSV disalin!",
		"exHtml": "Diekspor ke HTML!",
		"exMarkdown": "Diekspor ke Markdown!",
		"exPlainText": "Diekspor ke Teks Biasa!",
		"exportHtml": "Ekspor ke HTML",
		"exportMarkdown": "Ekspor ke Markdown",
		"exportPlainText": "Ekspor ke Teks Biasa",
		"failedToLoad": "Gagal memuat ayat",
		"failedToSave": "Gagal menyimpan file: %@",
		"fetchingWord": "Memuat Firman Tuhan...",
		"fontSize": "Ukuran Huruf",
		"fontSizePt": "%dpt",
		"from": "Dari",
		"invalidData": "Format data tidak valid",
		"jsonCopied": "JSON disalin!",
		"language": "Bahasa",
		"loading": "Memuat...",
		"passageCopied": "Seluruh bagian disalin!",
		"passageNotFound": "Bagian tidak ditemukan",
		"referenceCopied": "Referensi disalin!",
		"savePanelMessage": "Pilih di mana menyimpan bagian Alkitab Anda",
		"selectPassage": "Pilih kitab dan pasal untuk mulai membaca",
		"selectPrompt": "Pilih kitab dan pasal untuk melihat ayat",
		"settings": "Pengaturan",
		"share": "Bagikan",
		"theme": "Tema",
		"themeDark": "Gelap",
		"themeLight": "Terang",
		"themeSepia": "Sepia",
		"themeSystem": "Sistem",
		"to": "Sampai",
		"verse": "Ayat",
		"verseCopied": "Teks ayat disalin!",
		"versePrefix": "Ayat ",
		"verseSuffix": "",
		"versesOptional": "Ayat (Opsional)",
		"version": "Versi",
		"bibleVersions": "Versi Alkitab",
		"download": "Unduh",
		"downloadComplete": "Unduhan Selesai!",
		"downloadLanguage": "Unduh Semua Versi",
		"downloadManager": "Manajer Unduhan",
		"downloadVersion": "Unduh Versi",
		"downloaded": "Terunduh",
		"downloading": "Mengunduh...",
		"deleteDownload": "Hapus Unduhan",
		"deleteAllDownloads": "Hapus Semua",
		"notAvailableOffline": "Tidak tersedia offline. Unduh versi ini di Pengaturan.",
	},
	"it": {
		"addToDesign": "Aggiungi al progetto",
		"bible": "Bibbia",
		"book": "Libro",
		"chapter": "Capitolo",
		"chapterNotFound": "Capitolo non trovato in questa versione",
		"chapterPrefix": "Capitolo ",
		"chapterSuffix": "",
		"copyAllText": "Copia tutto il testo",
		"copyAsCsv": "Copia come CSV",
		"copyAsJson": "Copia come JSON",
		"csvCopied": "CSV copiato!",
		"exHtml": "Esportato come HTML!",
		"exMarkdown": "Esportato in Markdown!",
		"exPlainText": "Esportato come testo semplice!",
		"exportHtml": "Esporta come HTML",
		"exportMarkdown": "Esporta in Markdown",
		"exportPlainText": "Esporta come testo semplice",
		"failedToLoad": "Impossibile caricare i versetti",
		"failedToSave": "Impossibile salvare il file: %@",
		"fetchingWord": "Caricamento della Parola di Dio...",
		"fontSize": "Dimensione carattere",
		"fontSizePt": "%dpt",
		"from": "Da",
		"invalidData": "Formato dati non valido",
		"jsonCopied": "JSON copiato!",
		"language": "Lingua",
		"loading": "Caricamento...",
		"passageCopied": "Intero passo copiato!",
		"passageNotFound": "Passo non trovato",
		"referenceCopied": "Riferimento copiato!",
		"savePanelMessage": "Scegli dove salvare il tuo passo biblico",
		"selectPassage": "Seleziona un libro e un capitolo per iniziare a leggere",
		"selectPrompt": "Seleziona un libro e un capitolo per vedere i versetti",
		"settings": "Impostazioni",
		"share": "Condividi",
		"theme": "Tema",
		"themeDark": "Scuro",
		"themeLight": "Chiaro",
		"themeSepia": "Seppia",
		"themeSystem": "Sistema",
		"to": "A",
		"verse": "Versetto",
		"verseCopied": "Testo del versetto copiato!",
		"versePrefix": "Versetto ",
		"verseSuffix": "",
		"versesOptional": "Versetti (Opzionale)",
		"version": "Versione",
		"bibleVersions": "Versioni della Bibbia",
		"download": "Scarica",
		"downloadComplete": "Download Completo!",
		"downloadLanguage": "Scarica Tutte le Versioni",
		"downloadManager": "Gestore Download",
		"downloadVersion": "Scarica Versione",
		"downloaded": "Scaricato",
		"downloading": "Scaricamento...",
		"deleteDownload": "Elimina Download",
		"deleteAllDownloads": "Elimina Tutto",
		"notAvailableOffline": "Non disponibile offline. Scarica questa versione nelle Impostazioni.",
	},
	"ja": {
		"addToDesign": "デザインに追加",
		"bible": "聖書",
		"book": "書名",
		"chapter": "章",
		"chapterNotFound": "この翻訳では章が見つかりません",
		"chapterPrefix": "第",
		"chapterSuffix": "章",
		"copyAllText": "すべてのテキストをコピー",
		"copyAsCsv": "CSVとしてコピー",
		"copyAsJson": "JSONとしてコピー",
		"csvCopied": "CSVをコピーしました！",
		"exHtml": "HTMLにエクスポートしました！",
		"exMarkdown": "Markdownにエクスポートしました！",
		"exPlainText": "プレーンテキストにエクスポートしました！",
		"exportHtml": "HTMLにエクスポート",
		"exportMarkdown": "Markdownにエクスポート",
		"exportPlainText": "プレーンテキストにエクスポート",
		"failedToLoad": "聖句の読み込みに失敗しました",
		"failedToSave": "ファイルの保存に失敗しました: %@",
		"fetchingWord": "神の言葉を読み込み中...",
		"fontSize": "フォントサイズ",
		"fontSizePt": "%dpt",
		"from": "から",
		"invalidData": "無効なデータ形式です",
		"jsonCopied": "JSONをコピーしました！",
		"language": "言語",
		"loading": "読み込み中...",
		"passageCopied": "全文をコピーしました！",
		"passageNotFound": "箇所が見つかりません",
		"referenceCopied": "参照をコピーしました！",
		"savePanelMessage": "聖句の保存場所を選択してください",
		"selectPassage": "書と章を選択して読書を開始",
		"selectPrompt": "書と章を選択して聖句を表示",
		"settings": "設定",
		"share": "共有",
		"theme": "テーマ",
		"themeDark": "ダーク",
		"themeLight": "ライト",
		"themeSepia": "セピア",
		"themeSystem": "システム",
		"to": "まで",
		"verse": "節",
		"verseCopied": "聖句テキストをコピーしました！",
		"versePrefix": "",
		"verseSuffix": "節",
		"versesOptional": "聖句（任意）",
		"version": "翻訳",
		"bibleVersions": "聖書翻訳",
		"download": "ダウンロード",
		"downloadComplete": "ダウンロード完了！",
		"downloadLanguage": "すべての翻訳をダウンロード",
		"downloadManager": "ダウンロードマネージャー",
		"downloadVersion": "翻訳をダウンロード",
		"downloaded": "ダウンロード済み",
		"downloading": "ダウンロード中...",
		"deleteDownload": "ダウンロードを削除",
		"deleteAllDownloads": "すべて削除",
		"notAvailableOffline": "オフラインでは利用できません。設定でこの翻訳をダウンロードしてください。",
	},
	"nl": {
		"addToDesign": "Toevoegen aan ontwerp",
		"bible": "Bijbel",
		"book": "Boek",
		"chapter": "Hoofdstuk",
		"chapterNotFound": "Hoofdstuk niet gevonden in deze vertaling",
		"chapterPrefix": "Hoofdstuk ",
		"chapterSuffix": "",
		"copyAllText": "Kopieer volledige tekst",
		"copyAsCsv": "Kopieer als CSV",
		"copyAsJson": "Kopieer als JSON",
		"csvCopied": "CSV gekopieerd!",
		"exHtml": "Geëxporteerd naar HTML!",
		"exMarkdown": "Geëxporteerd naar Markdown!",
		"exPlainText": "Geëxporteerd naar tekst!",
		"exportHtml": "Exporteren naar HTML",
		"exportMarkdown": "Exporteren naar Markdown",
		"exportPlainText": "Exporteren naar tekst",
		"failedToLoad": "Kon verzen niet laden",
		"failedToSave": "Kon bestand niet opslaan: %@",
		"fetchingWord": "Gods Woord laden...",
		"fontSize": "Lettergrootte",
		"fontSizePt": "%dpt",
		"from": "Van",
		"invalidData": "Ongeldig gegevensformaat",
		"jsonCopied": "JSON gekopieerd!",
		"language": "Taal",
		"loading": "Laden...",
		"passageCopied": "Hele passage gekopieerd!",
		"passageNotFound": "Passage niet gevonden",
		"referenceCopied": "Referentie gekopieerd!",
		"savePanelMessage": "Kies waar je je Bijbelpassage wilt opslaan",
		"selectPassage": "Selecteer een boek en hoofdstuk om te beginnen lezen",
		"selectPrompt": "Selecteer een boek en hoofdstuk om verzen te bekijken",
		"settings": "Instellingen",
		"share": "Delen",
		"theme": "Thema",
		"themeDark": "Donker",
		"themeLight": "Licht",
		"themeSepia": "Sepia",
		"themeSystem": "Systeem",
		"to": "Tot",
		"verse": "Vers",
		"verseCopied": "Vers tekst gekopieerd!",
		"versePrefix": "Vers ",
		"verseSuffix": "",
		"versesOptional": "Verzen (Optioneel)",
		"version": "Vertaling",
		"bibleVersions": "Bijbelvertalingen",
		"download": "Downloaden",
		"downloadComplete": "Download Voltooid!",
		"downloadLanguage": "Alle Vertalingen Downloaden",
		"downloadManager": "Download Manager",
		"downloadVersion": "Vertaling Downloaden",
		"downloaded": "Gedownload",
		"downloading": "Bezig met downloaden...",
		"deleteDownload": "Verwijder Download",
		"deleteAllDownloads": "Verwijder Alles",
		"notAvailableOffline": "Niet beschikbaar offline. Download deze vertaling in Instellingen.",
	},
	"pl": {
		"addToDesign": "Dodaj do projektu",
		"bible": "Biblia",
		"book": "Księga",
		"chapter": "Rozdział",
		"chapterNotFound": "Nie znaleziono rozdziału w tym przekładzie",
		"chapterPrefix": "Rozdział ",
		"chapterSuffix": "",
		"copyAllText": "Skopiuj cały tekst",
		"copyAsCsv": "Kopiuj jako CSV",
		"copyAsJson": "Kopiuj jako JSON",
		"csvCopied": "CSV skopiowany!",
		"exHtml": "Wyeksportowano do HTML!",
		"exMarkdown": "Wyeksportowano do Markdown!",
		"exPlainText": "Wyeksportowano do tekstu!",
		"exportHtml": "Eksportuj do HTML",
		"exportMarkdown": "Eksportuj do Markdown",
		"exportPlainText": "Eksportuj do tekstu",
		"failedToLoad": "Nie udało się załadować wersetów",
		"failedToSave": "Nie udało się zapisać pliku: %@",
		"fetchingWord": "Ładowanie Słowa Bożego...",
		"fontSize": "Rozmiar czcionki",
		"fontSizePt": "%dpt",
		"from": "Od",
		"invalidData": "Nieprawidłowy format danych",
		"jsonCopied": "JSON skopiowany!",
		"language": "Język",
		"loading": "Ładowanie...",
		"passageCopied": "Cały fragment skopiowany!",
		"passageNotFound": "Nie znaleziono fragmentu",
		"referenceCopied": "Referencja skopiowana!",
		"savePanelMessage": "Wybierz, gdzie zapisać fragment Biblii",
		"selectPassage": "Wybierz księgę i rozdział, aby rozpocząć czytanie",
		"selectPrompt": "Wybierz księgę i rozdział, aby zobaczyć wersety",
		"settings": "Ustawienia",
		"share": "Udostępnij",
		"theme": "Motyw",
		"themeDark": "Ciemny",
		"themeLight": "Jasny",
		"themeSepia": "Sepia",
		"themeSystem": "Systemowy",
		"to": "Do",
		"verse": "Werset",
		"verseCopied": "Tekst wersetu skopiowany!",
		"versePrefix": "Werset ",
		"verseSuffix": "",
		"versesOptional": "Wersety (Opcjonalnie)",
		"version": "Przekład",
		"bibleVersions": "Przekłady Biblii",
		"download": "Pobierz",
		"downloadComplete": "Pobieranie Zakończone!",
		"downloadLanguage": "Pobierz Wszystkie Przekłady",
		"downloadManager": "Menedżer Pobierania",
		"downloadVersion": "Pobierz Przekład",
		"downloaded": "Pobrano",
		"downloading": "Pobieranie...",
		"deleteDownload": "Usuń Pobranie",
		"deleteAllDownloads": "Usuń Wszystko",
		"notAvailableOffline": "Niedostępne offline. Pobierz ten przekład w Ustawieniach.",
	},
	"pt": {
		"addToDesign": "Adicionar ao design",
		"bible": "Bíblia",
		"book": "Livro",
		"chapter": "Capítulo",
		"chapterNotFound": "Capítulo não encontrado nesta versão",
		"chapterPrefix": "Capítulo ",
		"chapterSuffix": "",
		"copyAllText": "Copiar todo o texto",
		"copyAsCsv": "Copiar como CSV",
		"copyAsJson": "Copiar como JSON",
		"csvCopied": "CSV copiado!",
		"exHtml": "Exportado para HTML!",
		"exMarkdown": "Exportado para Markdown!",
		"exPlainText": "Exportado para texto simples!",
		"exportHtml": "Exportar para HTML",
		"exportMarkdown": "Exportar para Markdown",
		"exportPlainText": "Exportar para texto simples",
		"failedToLoad": "Falha ao carregar versículos",
		"failedToSave": "Falha ao salvar arquivo: %@",
		"fetchingWord": "Carregando a Palavra de Deus...",
		"fontSize": "Tamanho da fonte",
		"fontSizePt": "%dpt",
		"from": "De",
		"invalidData": "Formato de dados inválido",
		"jsonCopied": "JSON copiado!",
		"language": "Idioma",
		"loading": "Carregando...",
		"passageCopied": "Passagem inteira copiada!",
		"passageNotFound": "Passagem não encontrada",
		"referenceCopied": "Referência copiada!",
		"savePanelMessage": "Escolha onde salvar sua passagem bíblica",
		"selectPassage": "Selecione um livro e capítulo para começar a ler",
		"selectPrompt": "Selecione um livro e capítulo para ver os versículos",
		"settings": "Configurações",
		"share": "Compartilhar",
		"theme": "Tema",
		"themeDark": "Escuro",
		"themeLight": "Claro",
		"themeSepia": "Sépia",
		"themeSystem": "Sistema",
		"to": "Até",
		"verse": "Versículo",
		"verseCopied": "Texto do versículo copiado!",
		"versePrefix": "Versículo ",
		"verseSuffix": "",
		"versesOptional": "Versículos (Opcional)",
		"version": "Versão",
		"bibleVersions": "Versões da Bíblia",
		"download": "Baixar",
		"downloadComplete": "Download Completo!",
		"downloadLanguage": "Baixar Todas as Versões",
		"downloadManager": "Gerenciador de Downloads",
		"downloadVersion": "Baixar Versão",
		"downloaded": "Baixado",
		"downloading": "Baixando...",
		"deleteDownload": "Excluir Download",
		"deleteAllDownloads": "Excluir Tudo",
		"notAvailableOffline": "Não disponível offline. Baixe esta versão nas Configurações.",
	},
	"ro": {
		"addToDesign": "Adaugă la design",
		"bible": "Biblia",
		"book": "Cartea",
		"chapter": "Capitolul",
		"chapterNotFound": "Capitolul nu a fost găsit în această versiune",
		"chapterPrefix": "Capitolul ",
		"chapterSuffix": "",
		"copyAllText": "Copiază tot textul",
		"copyAsCsv": "Copiază ca CSV",
		"copyAsJson": "Copiază ca JSON",
		"csvCopied": "CSV copiat!",
		"exHtml": "Exportat ca HTML!",
		"exMarkdown": "Exportat în Markdown!",
		"exPlainText": "Exportat ca text simplu!",
		"exportHtml": "Exportă ca HTML",
		"exportMarkdown": "Exportă în Markdown",
		"exportPlainText": "Exportă ca text simplu",
		"failedToLoad": "Nu s-au putut încărca versetele",
		"failedToSave": "Nu s-a putut salva fișierul: %@",
		"fetchingWord": "Se încarcă Cuvântul lui Dumnezeu...",
		"fontSize": "Mărime font",
		"fontSizePt": "%dpt",
		"from": "De la",
		"invalidData": "Format de date invalid",
		"jsonCopied": "JSON copiat!",
		"language": "Limba",
		"loading": "Se încarcă...",
		"passageCopied": "Întregul pasaj copiat!",
		"passageNotFound": "Pasajul nu a fost găsit",
		"referenceCopied": "Referință copiată!",
		"savePanelMessage": "Alege unde să salvezi pasajul biblic",
		"selectPassage": "Selectează o carte și un capitol pentru a începe citirea",
		"selectPrompt": "Selectează o carte și un capitol pentru a vedea versetele",
		"settings": "Setări",
		"share": "Distribuie",
		"theme": "Temă",
		"themeDark": "Întunecat",
		"themeLight": "Deschis",
		"themeSepia": "Sepia",
		"themeSystem": "Sistem",
		"to": "Până la",
		"verse": "Vers",
		"verseCopied": "Textul versetului copiat!",
		"versePrefix": "Vers ",
		"verseSuffix": "",
		"versesOptional": "Versete (Opțional)",
		"version": "Versiunea",
		"bibleVersions": "Versiuni ale Bibliei",
		"download": "Descarcă",
		"downloadComplete": "Descărcare Completă!",
		"downloadLanguage": "Descarcă Toate Versiunile",
		"downloadManager": "Manager de Descărcări",
		"downloadVersion": "Descarcă Versiunea",
		"downloaded": "Descărcat",
		"downloading": "Se descarcă...",
		"deleteDownload": "Șterge Descărcarea",
		"deleteAllDownloads": "Șterge Tot",
		"notAvailableOffline": "Indisponibil offline. Descarcă această versiune în Setări.",
	},
	"ru": {
		"addToDesign": "Добавить в дизайн",
		"bible": "Библия",
		"book": "Книга",
		"chapter": "Глава",
		"chapterNotFound": "Глава не найдена в этом переводе",
		"chapterPrefix": "Глава ",
		"chapterSuffix": "",
		"copyAllText": "Копировать весь текст",
		"copyAsCsv": "Копировать как CSV",
		"copyAsJson": "Копировать как JSON",
		"csvCopied": "CSV скопирован!",
		"exHtml": "Экспортировано в HTML!",
		"exMarkdown": "Экспортировано в Markdown!",
		"exPlainText": "Экспортировано в текст!",
		"exportHtml": "Экспорт в HTML",
		"exportMarkdown": "Экспорт в Markdown",
		"exportPlainText": "Экспорт в текстовый файл",
		"failedToLoad": "Не удалось загрузить стихи",
		"failedToSave": "Не удалось сохранить файл: %@",
		"fetchingWord": "Загрузка Слова Божьего...",
		"fontSize": "Размер шрифта",
		"fontSizePt": "%dpt",
		"from": "От",
		"invalidData": "Неверный формат данных",
		"jsonCopied": "JSON скопирован!",
		"language": "Язык",
		"loading": "Загрузка...",
		"passageCopied": "Весь отрывок скопирован!",
		"passageNotFound": "Отрывок не найден",
		"referenceCopied": "Ссылка скопирована!",
		"savePanelMessage": "Выберите, куда сохранить библейский отрывок",
		"selectPassage": "Выберите книгу и главу, чтобы начать чтение",
		"selectPrompt": "Выберите книгу и главу для просмотра стихов",
		"settings": "Настройки",
		"share": "Поделиться",
		"theme": "Тема",
		"themeDark": "Тёмная",
		"themeLight": "Светлая",
		"themeSepia": "Сепия",
		"themeSystem": "Системная",
		"to": "До",
		"verse": "Стих",
		"verseCopied": "Текст стиха скопирован!",
		"versePrefix": "Стих ",
		"verseSuffix": "",
		"versesOptional": "Стихи (необязательно)",
		"version": "Перевод",
		"bibleVersions": "Переводы Библии",
		"download": "Скачать",
		"downloadComplete": "Загрузка Завершена!",
		"downloadLanguage": "Скачать Все Переводы",
		"downloadManager": "Менеджер Загрузок",
		"downloadVersion": "Скачать Перевод",
		"downloaded": "Загружено",
		"downloading": "Загрузка...",
		"deleteDownload": "Удалить Загрузку",
		"deleteAllDownloads": "Удалить Все",
		"notAvailableOffline": "Недоступно офлайн. Загрузите этот перевод в Настройках.",
	},
	"sw": {
		"addToDesign": "Ongeza kwenye muundo",
		"bible": "Biblia",
		"book": "Kitabu",
		"chapter": "Sura",
		"chapterNotFound": "Sura haijapatikana katika tafsiri hii",
		"chapterPrefix": "Sura ",
		"chapterSuffix": "",
		"copyAllText": "Nakili Maandishi Yote",
		"copyAsCsv": "Nakili kama CSV",
		"copyAsJson": "Nakili kama JSON",
		"csvCopied": "CSV imenakiliwa!",
		"exHtml": "Imehamishwa kwa HTML!",
		"exMarkdown": "Imehamishwa kwa Markdown!",
		"exPlainText": "Imehamishwa kwa Maandishi!",
		"exportHtml": "Hamisha kwa HTML",
		"exportMarkdown": "Hamisha kwa Markdown",
		"exportPlainText": "Hamisha kwa Maandishi",
		"failedToLoad": "Imeshindwa kupakia aya",
		"failedToSave": "Imeshindwa kuhifadhi faili: %@",
		"fetchingWord": "Inapakia Neno la Mungu...",
		"fontSize": "Ukubwa wa Herufi",
		"fontSizePt": "%dpt",
		"from": "Kutoka",
		"invalidData": "Muundo wa data si sahihi",
		"jsonCopied": "JSON imenakiliwa!",
		"language": "Lugha",
		"loading": "Inapakia...",
		"passageCopied": "Kifungu kizima kimenakiliwa!",
		"passageNotFound": "Kifungu hakijapatikana",
		"referenceCopied": "Rejea imenakiliwa!",
		"savePanelMessage": "Chagua mahali pa kuhifadhi kifungu chako cha Biblia",
		"selectPassage": "Chagua kitabu na sura kuanza kusoma",
		"selectPrompt": "Chagua kitabu na sura ili kuona aya",
		"settings": "Mipangilio",
		"share": "Shiriki",
		"theme": "Mandhari",
		"themeDark": "Giza",
		"themeLight": "Mwanga",
		"themeSepia": "Sepia",
		"themeSystem": "Mfumo",
		"to": "Hadi",
		"verse": "Aya",
		"verseCopied": "Maandishi ya aya yamenakiliwa!",
		"versePrefix": "Aya ",
		"verseSuffix": "",
		"versesOptional": "Aya (Hiari)",
		"version": "Tafsiri",
		"bibleVersions": "Matoleo ya Biblia",
		"download": "Pakua",
		"downloadComplete": "Kupakua Kukamilika!",
		"downloadLanguage": "Pakua Matoleo Yote",
		"downloadManager": "Meneja wa Kupakua",
		"downloadVersion": "Pakua Toleo",
		"downloaded": "Imepakuliwa",
		"downloading": "Inapakua...",
		"deleteDownload": "Futa Upakuaji",
		"deleteAllDownloads": "Futa Zote",
		"notAvailableOffline": "Haipatikani nje ya mtandao. Pakua toleo hili katika Mipangilio.",
	},
	"tl": {
		"addToDesign": "Idagdag sa disenyo",
		"bible": "Bibliya",
		"book": "Aklat",
		"chapter": "Kabanata",
		"chapterNotFound": "Hindi natagpuan ang kabanata sa bersyong ito",
		"chapterPrefix": "Kabanata ",
		"chapterSuffix": "",
		"copyAllText": "Kopyahin Lahat ng Teksto",
		"copyAsCsv": "Kopyahin bilang CSV",
		"copyAsJson": "Kopyahin bilang JSON",
		"csvCopied": "CSV ay nakopya!",
		"exHtml": "Na-export sa HTML!",
		"exMarkdown": "Na-export sa Markdown!",
		"exPlainText": "Na-export sa Plain Text!",
		"exportHtml": "I-export sa HTML",
		"exportMarkdown": "I-export sa Markdown",
		"exportPlainText": "I-export sa Plain Text",
		"failedToLoad": "Hindi na-load ang mga talata",
		"failedToSave": "Hindi na-save ang file: %@",
		"fetchingWord": "Naglo-load ng Salita ng Diyos...",
		"fontSize": "Laki ng Font",
		"fontSizePt": "%dpt",
		"from": "Mula",
		"invalidData": "Hindi wastong format ng data",
		"jsonCopied": "JSON ay nakopya!",
		"language": "Wika",
		"loading": "Naglo-load...",
		"passageCopied": "Ang buong talata ay nakopya!",
		"passageNotFound": "Hindi natagpuan ang talata",
		"referenceCopied": "Ang reference ay nakopya!",
		"savePanelMessage": "Pumili kung saan ise-save ang iyong talata sa Bibliya",
		"selectPassage": "Pumili ng aklat at kabanata upang magsimulang magbasa",
		"selectPrompt": "Pumili ng aklat at kabanata upang makita ang mga talata",
		"settings": "Mga Setting",
		"share": "Ibahagi",
		"theme": "Tema",
		"themeDark": "Madilim",
		"themeLight": "Maliwanag",
		"themeSepia": "Sepia",
		"themeSystem": "Sistema",
		"to": "Hanggang",
		"verse": "Talata",
		"verseCopied": "Ang teksto ng talata ay nakopya!",
		"versePrefix": "Talata ",
		"verseSuffix": "",
		"versesOptional": "Mga Talata (Opsyonal)",
		"version": "Bersyon",
		"bibleVersions": "Mga Bersyon ng Bibliya",
		"download": "I-download",
		"downloadComplete": "Kumpleto ang Download!",
		"downloadLanguage": "I-download Lahat ng Bersyon",
		"downloadManager": "Tagapamahala ng Download",
		"downloadVersion": "I-download ang Bersyon",
		"downloaded": "Na-download",
		"downloading": "Dina-download...",
		"deleteDownload": "Tanggalin ang Download",
		"deleteAllDownloads": "Tanggalin Lahat",
		"notAvailableOffline": "Hindi available offline. I-download ang bersyong ito sa Settings.",
	},
	"vi": {
		"addToDesign": "Thêm vào thiết kế",
		"bible": "Kinh Thánh",
		"book": "Sách",
		"chapter": "Chương",
		"chapterNotFound": "Không tìm thấy chương trong phiên bản này",
		"chapterPrefix": "Chương ",
		"chapterSuffix": "",
		"copyAllText": "Sao chép toàn bộ văn bản",
		"copyAsCsv": "Sao chép dạng CSV",
		"copyAsJson": "Sao chép dạng JSON",
		"csvCopied": "Đã sao chép CSV!",
		"exHtml": "Đã xuất ra HTML!",
		"exMarkdown": "Đã xuất sang Markdown!",
		"exPlainText": "Đã xuất ra văn bản thuần!",
		"exportHtml": "Xuất ra HTML",
		"exportMarkdown": "Xuất sang Markdown",
		"exportPlainText": "Xuất ra văn bản thuần",
		"failedToLoad": "Không thể tải câu",
		"failedToSave": "Không thể lưu tệp: %@",
		"fetchingWord": "Đang tải Lời Chúa...",
		"fontSize": "Cỡ chữ",
		"fontSizePt": "%dpt",
		"from": "Từ",
		"invalidData": "Định dạng dữ liệu không hợp lệ",
		"jsonCopied": "Đã sao chép JSON!",
		"language": "Ngôn ngữ",
		"loading": "Đang tải...",
		"passageCopied": "Đã sao chép toàn bộ đoạn!",
		"passageNotFound": "Không tìm thấy đoạn",
		"referenceCopied": "Đã sao chép tham chiếu!",
		"savePanelMessage": "Chọn nơi lưu đoạn Kinh Thánh của bạn",
		"selectPassage": "Chọn sách và chương để bắt đầu đọc",
		"selectPrompt": "Chọn sách và chương để xem câu",
		"settings": "Cài đặt",
		"share": "Chia sẻ",
		"theme": "Chủ đề",
		"themeDark": "Tối",
		"themeLight": "Sáng",
		"themeSepia": "Nâu đỏ",
		"themeSystem": "Hệ thống",
		"to": "Đến",
		"verse": "Câu",
		"verseCopied": "Đã sao chép nội dung câu!",
		"versePrefix": "Câu ",
		"verseSuffix": "",
		"versesOptional": "Câu (Tùy chọn)",
		"version": "Phiên bản",
		"bibleVersions": "Phiên bản Kinh Thánh",
		"download": "Tải xuống",
		"downloadComplete": "Tải xuống Hoàn tất!",
		"downloadLanguage": "Tải xuống Tất cả Phiên bản",
		"downloadManager": "Trình quản lý Tải xuống",
		"downloadVersion": "Tải xuống Phiên bản",
		"downloaded": "Đã tải xuống",
		"downloading": "Đang tải xuống...",
		"deleteDownload": "Xóa Tải xuống",
		"deleteAllDownloads": "Xóa Tất cả",
		"notAvailableOffline": "Không khả dụng ngoại tuyến. Tải xuống phiên bản này trong Cài đặt.",
	},
	"zh": {
		"addToDesign": "添加到设计",
		"bible": "圣经",
		"book": "书卷",
		"chapter": "章",
		"chapterNotFound": "此版本中未找到该章节",
		"chapterPrefix": "第",
		"chapterSuffix": "章",
		"copyAllText": "复制全部文本",
		"copyAsCsv": "复制为CSV",
		"copyAsJson": "复制为JSON",
		"csvCopied": "CSV已复制！",
		"exHtml": "已导出为HTML！",
		"exMarkdown": "已导出为Markdown！",
		"exPlainText": "已导出为纯文本！",
		"exportHtml": "导出为HTML",
		"exportMarkdown": "导出为Markdown",
		"exportPlainText": "导出为纯文本",
		"failedToLoad": "加载经文失败",
		"failedToSave": "保存文件失败：%@",
		"fetchingWord": "正在加载神的话语...",
		"fontSize": "字号",
		"fontSizePt": "%dpt",
		"from": "从",
		"invalidData": "无效的数据格式",
		"jsonCopied": "JSON已复制！",
		"language": "语言",
		"loading": "加载中...",
		"passageCopied": "整段已复制！",
		"passageNotFound": "未找到该段落",
		"referenceCopied": "引用已复制！",
		"savePanelMessage": "选择保存圣经段落的位置",
		"selectPassage": "选择书卷和章节开始阅读",
		"selectPrompt": "选择书卷和章节以查看经文",
		"settings": "设置",
		"share": "分享",
		"theme": "主题",
		"themeDark": "深色",
		"themeLight": "浅色",
		"themeSepia": "棕褐色",
		"themeSystem": "系统",
		"to": "至",
		"verse": "节",
		"verseCopied": "经文文本已复制！",
		"versePrefix": "",
		"verseSuffix": "节",
		"versesOptional": "经文（可选）",
		"version": "版本",
		"bibleVersions": "圣经版本",
		"download": "下载",
		"downloadComplete": "下载完成！",
		"downloadLanguage": "下载所有版本",
		"downloadManager": "下载管理器",
		"downloadVersion": "下载版本",
		"downloaded": "已下载",
		"downloading": "下载中...",
		"deleteDownload": "删除下载",
		"deleteAllDownloads": "删除全部",
		"notAvailableOffline": "离线不可用。请在设置中下载此版本。",
	},
}

var manifestJSON = `{"af": {"label": "Afrikaans", "versions": [{"code": "af/aba", "label": "Afrikaans — aba"}, {"code": "af/afr53", "label": "Afrikaans — afr53"}, {"code": "af/afr83", "label": "Afrikaans — afr83"}]}, "ar": {"label": "Arabic", "versions": [{"code": "ar/alab", "label": "Arabic — alab"}, {"code": "ar/avddv", "label": "Arabic — avddv"}, {"code": "ar/ervar", "label": "Arabic — ervar"}, {"code": "ar/nav", "label": "Arabic — nav"}]}, "de": {"label": "German", "versions": [{"code": "de/ngude", "label": "German — ngude"}, {"code": "de/sch2000", "label": "German — sch2000"}]}, "en": {"label": "English", "versions": [{"code": "en/akjv", "label": "English — akjv"}, {"code": "en/amp", "label": "English — amp"}, {"code": "en/ampc", "label": "English — ampc"}, {"code": "en/asv", "label": "English — asv"}, {"code": "en/brg", "label": "English — brg"}, {"code": "en/ceb", "label": "English — ceb"}, {"code": "en/cev", "label": "English — cev"}, {"code": "en/cevd", "label": "English — cevd"}, {"code": "en/cjb", "label": "English — cjb"}, {"code": "en/csb", "label": "English — csb"}, {"code": "en/darby", "label": "English — darby"}, {"code": "en/dlnt", "label": "English — dlnt"}, {"code": "en/dra", "label": "English — dra"}, {"code": "en/ehv", "label": "English — ehv"}, {"code": "en/erv", "label": "English — erv"}, {"code": "en/esv", "label": "English — esv"}, {"code": "en/exb", "label": "English — exb"}, {"code": "en/gnt", "label": "English — gnt"}, {"code": "en/gnv", "label": "English — gnv"}, {"code": "en/gw", "label": "English — gw"}, {"code": "en/hcsb", "label": "English — hcsb"}, {"code": "en/icb", "label": "English — icb"}, {"code": "en/isv", "label": "English — isv"}, {"code": "en/jub", "label": "English — jub"}, {"code": "en/kj21", "label": "English — kj21"}, {"code": "en/kjv", "label": "English — kjv"}, {"code": "en/leb", "label": "English — leb"}, {"code": "en/mev", "label": "English — mev"}, {"code": "en/mounce", "label": "English — mounce"}, {"code": "en/msg", "label": "English — msg"}, {"code": "en/nabre", "label": "English — nabre"}, {"code": "en/nasb", "label": "English — nasb"}, {"code": "en/ncv", "label": "English — ncv"}, {"code": "en/net", "label": "English — net"}, {"code": "en/nirv", "label": "English — nirv"}, {"code": "en/niv1984", "label": "English — niv1984"}, {"code": "en/niv2011", "label": "English — niv2011"}, {"code": "en/nivuk", "label": "English — nivuk"}, {"code": "en/nkjv", "label": "English — nkjv"}, {"code": "en/nlt", "label": "English — nlt"}, {"code": "en/nlt2013", "label": "English — nlt2013"}, {"code": "en/nlv", "label": "English — nlv"}, {"code": "en/nog", "label": "English — nog"}, {"code": "en/nrsv", "label": "English — nrsv"}, {"code": "en/nrsva", "label": "English — nrsva"}, {"code": "en/ojb", "label": "English — ojb"}, {"code": "en/phillips", "label": "English — phillips"}, {"code": "en/rsv", "label": "English — rsv"}, {"code": "en/rsvce", "label": "English — rsvce"}, {"code": "en/tlb", "label": "English — tlb"}, {"code": "en/tlv", "label": "English — tlv"}, {"code": "en/voice", "label": "English — voice"}, {"code": "en/web", "label": "English — web"}, {"code": "en/webbe", "label": "English — webbe"}, {"code": "en/wyc", "label": "English — wyc"}, {"code": "en/ylt", "label": "English — ylt"}]}, "es": {"label": "Spanish", "versions": [{"code": "es/bhti", "label": "Spanish — bhti"}, {"code": "es/dhh", "label": "Spanish — dhh"}, {"code": "es/nblh", "label": "Spanish — nblh"}, {"code": "es/ntv", "label": "Spanish — ntv"}, {"code": "es/nvi", "label": "Spanish — nvi"}, {"code": "es/rvc", "label": "Spanish — rvc"}, {"code": "es/rvr1995", "label": "Spanish — rvr1995"}, {"code": "es/rvr60", "label": "Spanish — rvr60"}, {"code": "es/rvr95", "label": "Spanish — rvr95"}, {"code": "es/tla", "label": "Spanish — tla"}]}, "fi": {"label": "Finnish", "versions": [{"code": "fi/kr92", "label": "Finnish — kr92"}]}, "fr": {"label": "French", "versions": [{"code": "fr/bds", "label": "French — bds"}, {"code": "fr/frc97", "label": "French — frc97"}, {"code": "fr/lsg", "label": "French — lsg"}, {"code": "fr/neg1979", "label": "French — neg1979"}, {"code": "fr/sg21", "label": "French — sg21"}]}, "he": {"label": "Hebrew", "versions": [{"code": "he/hhh", "label": "Hebrew — hhh"}, {"code": "he/wlc", "label": "Hebrew — wlc"}]}, "hi": {"label": "Hindi", "versions": [{"code": "hi/ervhi", "label": "Hindi — ervhi"}]}, "id": {"label": "Indonesian", "versions": [{"code": "id/bimk", "label": "Indonesian — bimk"}, {"code": "id/tb", "label": "Indonesian — tb"}]}, "it": {"label": "Italian", "versions": [{"code": "it/nr2006", "label": "Italian — nr2006"}]}, "ja": {"label": "Japanese", "versions": [{"code": "ja/jlb", "label": "Japanese — jlb"}]}, "nl": {"label": "Dutch", "versions": [{"code": "nl/bb", "label": "Dutch — bb"}, {"code": "nl/htb", "label": "Dutch — htb"}, {"code": "nl/nbg51", "label": "Dutch — nbg51"}]}, "pl": {"label": "Polish", "versions": [{"code": "pl/szpl", "label": "Polish — szpl"}]}, "pt": {"label": "Portuguese", "versions": [{"code": "pt/arc09", "label": "Portuguese — arc09"}, {"code": "pt/bpt09", "label": "Portuguese — bpt09"}, {"code": "pt/nvipt", "label": "Portuguese — nvipt"}]}, "ro": {"label": "Romanian", "versions": [{"code": "ro/bdc", "label": "Romanian — bdc"}, {"code": "ro/ntlr", "label": "Romanian — ntlr"}]}, "ru": {"label": "Russian", "versions": [{"code": "ru/nrt", "label": "Russian — nrt"}, {"code": "ru/synod", "label": "Russian — synod"}]}, "sw": {"label": "Swahili", "versions": [{"code": "sw/bhn", "label": "Swahili — bhn"}, {"code": "sw/suv", "label": "Swahili — suv"}]}, "tl": {"label": "Tagalog", "versions": [{"code": "tl/abtag2001", "label": "Tagalog — abtag2001"}, {"code": "tl/adb1905", "label": "Tagalog — adb1905"}, {"code": "tl/fsv", "label": "Tagalog — fsv"}, {"code": "tl/mbb05", "label": "Tagalog — mbb05"}, {"code": "tl/mbbtag", "label": "Tagalog — mbbtag"}, {"code": "tl/snd", "label": "Tagalog — snd"}]}, "vi": {"label": "Vietnamese", "versions": [{"code": "vi/bpt", "label": "Vietnamese — bpt"}, {"code": "vi/rvv11", "label": "Vietnamese — rvv11"}, {"code": "vi/viet", "label": "Vietnamese — viet"}]}, "zh": {"label": "Chinese", "versions": [{"code": "zh/cn-ccb", "label": "Chinese — cn-ccb"}, {"code": "zh/cn-cnvs", "label": "Chinese — cn-cnvs"}, {"code": "zh/cn-csbs", "label": "Chinese — cn-csbs"}, {"code": "zh/cn-cunpss", "label": "Chinese — cn-cunpss"}, {"code": "zh/cn-cuvmps", "label": "Chinese — cn-cuvmps"}, {"code": "zh/cn-rcu17ss", "label": "Chinese — cn-rcu17ss"}, {"code": "zh/cn-rcuvss", "label": "Chinese — cn-rcuvss"}, {"code": "zh/tw-ccbt", "label": "Chinese — tw-ccbt"}, {"code": "zh/tw-cnvt", "label": "Chinese — tw-cnvt"}, {"code": "zh/tw-csbt", "label": "Chinese — tw-csbt"}, {"code": "zh/tw-cunpts", "label": "Chinese — tw-cunpts"}, {"code": "zh/tw-cuvmpt", "label": "Chinese — tw-cuvmpt"}, {"code": "zh/tw-rcu17ts", "label": "Chinese — tw-rcu17ts"}, {"code": "zh/tw-rcuvts", "label": "Chinese — tw-rcuvts"}]}}`

type App struct {
	fyneApp            fyne.App
	window             fyne.Window
	mainContent        *fyne.Container

	prefs              fyne.Preferences

	theme              AppTheme
	fontSize           float64

	selectedLanguage   string
	selectedVersion    string
	selectedBook       BibleBook

	bookSelect         *widget.Select
	chapterSelect      *widget.Select
	fromEntry          *widget.Entry
	toEntry            *widget.Entry
	languageSelect     *widget.Select
	versionSelect      *widget.Select

	manifest           map[string]ManifestEntry
	bibleData          *BibleData
	versions           map[string]string
	copyrights         map[string]string

	readingScroll      *container.Scroll
	readingContainer   *fyne.Container
	refLabel           *widget.Label
	sourceLabel        *widget.Label
	copyrightLabel     *widget.Label

	isLoading          bool
	mu                 sync.Mutex
}

func (a *App) tr(key string) string {
	lang, ok := localizedLabels[a.selectedLanguage]
	if !ok {
		lang = localizedLabels["en"]
	}
	if val, ok := lang[key]; ok {
		return val
	}
	// fallback to English
	if en, ok := localizedLabels["en"][key]; ok {
		return en
	}
	return key
}

func (a *App) getBooks() []BibleBook {
	names, ok := localizedBooks[a.selectedLanguage]
	bibleBooks := defaultBooks
	if a.bibleData != nil && len(a.bibleData.Books) > 0 {
		bibleBooks = make([]BibleBook, len(a.bibleData.Books))
		for i, entry := range a.bibleData.Books {
			name := ""
			if len(entry) > 0 {
				name = fmt.Sprintf("%v", entry[0])
			}
			chapters := 0
			if len(entry) > 1 {
				chapters = int(entry[1].(float64))
			}
			localName := name
			if ok && i < len(names) {
				localName = names[i]
			}
			bibleBooks[i] = BibleBook{ID: i + 1, Name: localName, Chapters: chapters}
		}
		return bibleBooks
	}
	if ok && len(names) == len(defaultBooks) {
		result := make([]BibleBook, len(defaultBooks))
		for i, b := range defaultBooks {
			result[i] = BibleBook{ID: b.ID, Name: names[i], Chapters: b.Chapters}
		}
		return result
	}
	return defaultBooks
}

func (a *App) updateSelectors() {
	books := a.getBooks()
	bookNames := make([]string, len(books))
	var currentBookID int
	if a.selectedBook.ID > 0 {
		currentBookID = a.selectedBook.ID
	} else if len(books) > 0 {
		currentBookID = books[0].ID
		a.selectedBook = books[0]
	}

	found := false
	for i, b := range books {
		bookNames[i] = b.Name
		if b.ID == currentBookID {
			bookNames[i] = b.Name
			a.selectedBook = b
			found = true
		}
	}
	if !found && len(books) > 0 {
		a.selectedBook = books[0]
	}
	a.bookSelect.Options = bookNames
	a.bookSelect.Selected = a.selectedBook.Name
	a.bookSelect.Refresh()

	a.updateChapterSelect()

	langKeys := make([]string, 0, len(langLabels))
	for k := range langLabels {
		langKeys = append(langKeys, k)
	}
	sort.Strings(langKeys)
	langNames := make([]string, len(langKeys))
	for i, k := range langKeys {
		langNames[i] = langLabels[k]
	}
	// Preserve current selection
	cl := a.selectedLanguage
	a.languageSelect.Options = langNames
	for i, k := range langKeys {
		if k == cl {
			a.languageSelect.Selected = langNames[i]
			break
		}
	}
	a.languageSelect.Refresh()

	verKeys := make([]string, 0, len(a.versions))
	for k := range a.versions {
		verKeys = append(verKeys, k)
	}
	sort.Strings(verKeys)
	verNames := make([]string, len(verKeys))
	for i, k := range verKeys {
		verNames[i] = a.versions[k]
	}
	cv := a.selectedVersion
	a.versionSelect.Options = verNames
	for i, k := range verKeys {
		if k == cv {
			a.versionSelect.Selected = verNames[i]
			break
		}
	}
	a.versionSelect.Refresh()
}

func (a *App) updateChapterSelect() {
	chapters := a.selectedBook.Chapters
	chOpts := make([]string, chapters)
	for i := 0; i < chapters; i++ {
		chOpts[i] = strconv.Itoa(i + 1)
	}
	chapStr := strconv.Itoa(a.prefs.Int("selectedChapter"))
	if _, err := strconv.Atoi(chapStr); err != nil || chapStr == "0" {
		chapStr = "1"
	}
	a.chapterSelect.Options = chOpts
	a.chapterSelect.Selected = chapStr
	a.chapterSelect.Refresh()
}

func (a *App) loadPassage() {
	lang := a.selectedLanguage
	ver := a.selectedVersion

	a.mu.Lock()
	a.isLoading = true
	a.mu.Unlock()

	a.refLabel.SetText(a.tr("fetchingWord"))
	a.sourceLabel.SetText("")
	a.copyrightLabel.SetText("")

	go func() {
		bible := loadCachedBible(lang, ver)
		if bible == nil {
			url := fmt.Sprintf("%s/download/%s/%s", apiBase, lang, ver)
			resp, err := http.Get(url)
			if err != nil {
				a.mu.Lock()
				a.isLoading = false
				a.mu.Unlock()
				a.refLabel.SetText(a.tr("failedToLoad"))
				return
			}
			defer resp.Body.Close()
			body, err := io.ReadAll(resp.Body)
			if err != nil {
				a.mu.Lock()
				a.isLoading = false
				a.mu.Unlock()
				a.refLabel.SetText(a.tr("failedToLoad"))
				return
			}
			var b BibleData
			if err := json.Unmarshal(body, &b); err != nil {
				a.mu.Lock()
				a.isLoading = false
				a.mu.Unlock()
				a.refLabel.SetText(a.tr("invalidData"))
				return
			}
			bible = &b
			saveCachedBible(lang, ver, bible)
		}

		a.mu.Lock()
		a.bibleData = bible
		a.isLoading = false
		a.mu.Unlock()

		books := a.getBooks()
		bookNames := make([]string, len(books))
		for i, b := range books {
			bookNames[i] = b.Name
		}
		a.bookSelect.Options = bookNames
		found := false
		for _, b := range books {
			if b.ID == a.selectedBook.ID {
				found = true
				break
			}
		}
		if !found && len(books) > 0 {
			a.selectedBook = books[0]
		}
		a.bookSelect.Selected = a.selectedBook.Name
		a.bookSelect.Refresh()

		a.updateChapterSelect()

		a.displayPassage()
	}()
}

func (a *App) displayPassage() {
	a.mu.Lock()
	bible := a.bibleData
	book := a.selectedBook
	chapStr := a.chapterSelect.Selected
	var chapter int
	if c, err := strconv.Atoi(chapStr); err == nil {
		chapter = c
	} else {
		chapter = 1
	}
	fromStr := a.fromEntry.Text
	toStr := a.toEntry.Text
	a.mu.Unlock()

	if bible == nil {
		a.refLabel.SetText(a.tr("selectPassage"))
		return
	}

	bookKey := strconv.Itoa(book.ID)
	chapterKey := strconv.Itoa(chapter)

	chapVerses, ok := bible.Verses[bookKey]
	if !ok {
		chapVerses, ok = bible.Verses[bookKey]
		if !ok {
			a.refLabel.SetText(a.tr("chapterNotFound"))
			a.sourceLabel.SetText("")
			a.copyrightLabel.SetText("")
			return
		}
	}
	verses, ok := chapVerses[chapterKey]
	if !ok {
		a.refLabel.SetText(a.tr("chapterNotFound"))
		a.sourceLabel.SetText("")
		a.copyrightLabel.SetText("")
		return
	}

	startVerse := 1
	if fromStr != "" {
		if v, err := strconv.Atoi(fromStr); err == nil && v >= 1 {
			startVerse = v
		}
	}
	endVerse := len(verses)
	if toStr != "" {
		if v, err := strconv.Atoi(toStr); err == nil && v >= startVerse && v <= len(verses) {
			endVerse = v
		}
	}
	if startVerse > len(verses) {
		startVerse = 1
	}
	if endVerse > len(verses) {
		endVerse = len(verses)
	}

	ref := fmt.Sprintf("%s %d", book.Name, chapter)
	if startVerse == endVerse {
		ref = fmt.Sprintf("%s %d:%d", book.Name, chapter, startVerse)
	} else {
		ref = fmt.Sprintf("%s %d:%d-%d", book.Name, chapter, startVerse, endVerse)
	}

		copyright := ""
	if cr, ok := englishCopyrights[a.selectedVersion]; ok {
		copyright = cr
	}

	verName := a.selectedVersion
	if name, ok := a.versions[a.selectedVersion]; ok {
		verName = name
	}

	// Build verse display
	a.readingContainer.Objects = nil

	refLabel := widget.NewLabelWithStyle(ref, fyne.TextAlignLeading, fyne.TextStyle{Bold: true})
	refLabel.Wrapping = fyne.TextWrapWord
	a.readingContainer.Add(refLabel)
	a.readingContainer.Add(widget.NewSeparator())

	for i := startVerse - 1; i < endVerse && i < len(verses); i++ {
		vNum := i + 1
		vText := strings.TrimSpace(verses[i])

		numLbl := canvas.NewText(fmt.Sprintf("%d  ", vNum), color.NRGBA{R: 0, G: 0x7a, B: 0xff, A: 0xff})
		numLbl.TextStyle = fyne.TextStyle{Bold: true}

		textLbl := widget.NewLabel(vText)
		textLbl.Wrapping = fyne.TextWrapWord

		row := container.NewHBox(numLbl, textLbl)
		a.readingContainer.Add(row)
	}

	a.readingContainer.Add(widget.NewSeparator())
	srcLbl := widget.NewLabelWithStyle(fmt.Sprintf("Source: %s", verName), fyne.TextAlignLeading, fyne.TextStyle{Italic: true})
	srcLbl.Wrapping = fyne.TextWrapWord
	a.readingContainer.Add(srcLbl)

	if copyright != "" {
		crLbl := widget.NewLabel(copyright)
		crLbl.Wrapping = fyne.TextWrapWord
		crLbl.TextStyle = fyne.TextStyle{Italic: true}
		a.readingContainer.Add(crLbl)
	}

	a.readingScroll.Refresh()
}

func (a *App) copyPassage() {
	// Build passage text
	passage := a.readingContainer.Objects
	if len(passage) == 0 {
		return
	}
	var text strings.Builder
	for _, obj := range passage {
		switch o := obj.(type) {
		case *widget.Label:
			text.WriteString(o.Text)
			text.WriteString("\n")
		case *fyne.Container:
			for _, child := range o.Objects {
				if lbl, ok := child.(*widget.Label); ok {
					text.WriteString(lbl.Text)
					text.WriteString("\n")
				}
				if ct, ok := child.(*canvas.Text); ok {
					text.WriteString(ct.Text)
				}
			}
			text.WriteString("\n")
		}
	}
	a.window.Clipboard().SetContent(text.String())
}

func (a *App) exportMarkdown() {
	dialog.ShowFileSave(func(writer fyne.URIWriteCloser, err error) {
		if err != nil || writer == nil {
			return
		}
		defer writer.Close()

		passage := a.readingContainer.Objects
		if len(passage) == 0 {
			return
		}

		var ref string
		var verses []string
		for _, obj := range passage {
			switch o := obj.(type) {
			case *widget.Label:
				if ref == "" {
					ref = o.Text
				}
			case *fyne.Container:
				var line string
				for _, child := range o.Objects {
					if ct, ok := child.(*canvas.Text); ok {
						line += strings.TrimSpace(ct.Text) + " "
					}
					if lbl, ok := child.(*widget.Label); ok {
						line += lbl.Text
					}
				}
				if strings.TrimSpace(line) != "" {
					verses = append(verses, strings.TrimSpace(line))
				}
			}
		}

		verName := a.selectedVersion
		if name, ok := a.versions[a.selectedVersion]; ok {
			verName = name
		}
		copyright := ""
		if cr, ok := englishCopyrights[a.selectedVersion]; ok {
			copyright = cr
		}

		var md strings.Builder
		md.WriteString(fmt.Sprintf("# %s\n\n", ref))
		for _, v := range verses {
			// Extract verse number
			parts := strings.SplitN(v, " ", 2)
			if len(parts) == 2 {
				md.WriteString(fmt.Sprintf("### Verse %s\n%s\n\n", parts[0], strings.TrimSpace(parts[1])))
			} else {
				md.WriteString(fmt.Sprintf("%s\n\n", v))
			}
		}
		md.WriteString(fmt.Sprintf("---\n*Source: %s*\n", verName))
		if copyright != "" {
			md.WriteString(fmt.Sprintf("*%s*\n", copyright))
		}

		writer.Write([]byte(md.String()))
	}, a.window)
}

func (a *App) exportHTML() {
	dialog.ShowFileSave(func(writer fyne.URIWriteCloser, err error) {
		if err != nil || writer == nil {
			return
		}
		defer writer.Close()

		passage := a.readingContainer.Objects
		if len(passage) == 0 {
			return
		}

		var bgColor, textColor string
		switch a.theme {
		case ThemeDark:
			bgColor = "#1a1a1a"
			textColor = "#f5f5f7"
		case ThemeSepia:
			bgColor = "#f5f0e0"
			textColor = "#433422"
		default:
			bgColor = "#ffffff"
			textColor = "#000000"
		}

		var ref string
		var verses []string
		for _, obj := range passage {
			switch o := obj.(type) {
			case *widget.Label:
				if ref == "" {
					ref = o.Text
				}
			case *fyne.Container:
				var line string
				for _, child := range o.Objects {
					if ct, ok := child.(*canvas.Text); ok {
						line += strings.TrimSpace(ct.Text) + " "
					}
					if lbl, ok := child.(*widget.Label); ok {
						line += lbl.Text
					}
				}
				if strings.TrimSpace(line) != "" {
					verses = append(verses, strings.TrimSpace(line))
				}
			}
		}

		verName := a.selectedVersion
		if name, ok := a.versions[a.selectedVersion]; ok {
			verName = name
		}
		copyright := ""
		if cr, ok := englishCopyrights[a.selectedVersion]; ok {
			copyright = cr
		}

		var html strings.Builder
		html.WriteString("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n")
		html.WriteString("<meta charset=\"UTF-8\">\n")
		html.WriteString("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n")
		html.WriteString(fmt.Sprintf("<title>%s</title>\n", ref))
		html.WriteString(fmt.Sprintf("<style>\n  body { background: %s; color: %s; font-family: 'Iowan Old Style', 'Palatino', 'Georgia', serif; max-width: 700px; margin: 40px auto; padding: 0 20px; line-height: 1.7; }\n", bgColor, textColor))
		html.WriteString("  h1 { font-size: 42px; font-weight: 800; margin-bottom: 48px; }\n")
		html.WriteString("  .verse { margin-bottom: 8px; }\n")
		html.WriteString("  .vnum { font-weight: 700; font-size: 13px; color: #007aff; margin-right: 8px; }\n")
		html.WriteString(fmt.Sprintf("  .footer { margin-top: 80px; padding-top: 40px; border-top: 1px solid %s; font-style: italic; font-size: 14px; }\n", map[bool]string{true: "rgba(255,255,255,0.15)", false: "rgba(0,0,0,0.1)"}[a.theme == ThemeDark]))
		html.WriteString("</style>\n</head>\n<body>\n")
		html.WriteString(fmt.Sprintf("<h1>%s</h1>\n", ref))

		for _, v := range verses {
			parts := strings.SplitN(v, " ", 2)
			if len(parts) == 2 {
				html.WriteString(fmt.Sprintf("<div class=\"verse\"><span class=\"vnum\">%s</span>%s</div>\n", parts[0], parts[1]))
			} else {
				html.WriteString(fmt.Sprintf("<div class=\"verse\">%s</div>\n", v))
			}
		}

		html.WriteString("<div class=\"footer\">\n")
		html.WriteString(fmt.Sprintf("  <p><strong>%s (%s)</strong></p>\n", ref, verName))
		if copyright != "" {
			html.WriteString(fmt.Sprintf("  <p>%s</p>\n", copyright))
		}
		html.WriteString("  <p>Generated by Sharer's Bible</p>\n</div>\n</body>\n</html>")

		writer.Write([]byte(html.String()))
	}, a.window)
}

func (a *App) showSettings() {
	win := a.fyneApp.NewWindow(a.tr("settings"))
	win.Resize(fyne.NewSize(400, 500))

	themeLbl := widget.NewLabel(a.tr("theme"))
	themeSelect := widget.NewSelect(
		[]string{a.tr("themeLight"), a.tr("themeDark"), a.tr("themeSepia")},
		func(s string) {
			switch s {
			case a.tr("themeLight"):
				a.theme = ThemeLight
			case a.tr("themeDark"):
				a.theme = ThemeDark
			case a.tr("themeSepia"):
				a.theme = ThemeSepia
			}
			a.applyTheme()
		},
	)
	switch a.theme {
	case ThemeLight:
		themeSelect.Selected = a.tr("themeLight")
	case ThemeDark:
		themeSelect.Selected = a.tr("themeDark")
	case ThemeSepia:
		themeSelect.Selected = a.tr("themeSepia")
	}

	fontLbl := widget.NewLabel(a.tr("fontSize"))
	fontSizeSlider := widget.NewSlider(14, 40)
	fontSizeSlider.Value = a.fontSize
	fontSizeLabel := widget.NewLabel(fmt.Sprintf("%dpt", int(a.fontSize)))
	fontSizeSlider.OnChanged = func(v float64) {
		a.fontSize = v
		fontSizeLabel.SetText(fmt.Sprintf("%dpt", int(v)))
		a.prefs.SetFloat("fontSize", v)
		a.applyTheme()
	}

	dlLbl := widget.NewLabelWithStyle(a.tr("downloadManager"), fyne.TextAlignLeading, fyne.TextStyle{Bold: true})

	dlScroll := container.NewVBox()
	dlList := container.NewScroll(dlScroll)
	dlList.SetMinSize(fyne.NewSize(380, 200))

	// Populate download manager
	langKeys := make([]string, 0, len(a.manifest))
	for k := range a.manifest {
		langKeys = append(langKeys, k)
	}
	sort.Strings(langKeys)

	for _, lk := range langKeys {
		entry := a.manifest[lk]
		label := entry.Label
		langLbl := widget.NewLabelWithStyle(label, fyne.TextAlignLeading, fyne.TextStyle{Bold: true})
		dlScroll.Add(langLbl)

		verKeys := make([]string, 0)
		verLabels := make(map[string]string)
		for _, v := range entry.Versions {
			parts := strings.Split(v.Code, "/")
			if len(parts) >= 2 {
				verKeys = append(verKeys, parts[1])
				verLabels[parts[1]] = v.Label
			}
		}
		sort.Strings(verKeys)

		for _, vk := range verKeys {
			vLbl := verLabels[vk]
			cached := isCached(lk, vk)

			row := container.NewHBox(
				widget.NewLabel(vLbl),
			)
			if cached {
				row.Add(widget.NewLabel("[" + a.tr("downloaded") + "]"))
				row.Add(widget.NewButton(a.tr("deleteDownload"), func() {
					os.Remove(cachedBiblePath(lk, vk))
				}))
			} else {
				row.Add(widget.NewButton(a.tr("download"), func() {
					go func() {
						url := fmt.Sprintf("%s/download/%s/%s", apiBase, lk, vk)
						resp, err := http.Get(url)
						if err != nil {
							return
						}
						defer resp.Body.Close()
						data, err := io.ReadAll(resp.Body)
						if err != nil {
							return
						}
						var b BibleData
						if err := json.Unmarshal(data, &b); err != nil {
							return
						}
						saveCachedBible(lk, vk, &b)
					}()
				}))
			}
			dlScroll.Add(row)
		}
	}

	content := container.NewVBox(
		themeLbl, themeSelect,
		fontLbl, container.NewBorder(nil, nil, nil, fontSizeLabel, fontSizeSlider),
		widget.NewSeparator(),
		dlLbl, dlList,
	)

	win.SetContent(container.NewBorder(
		nil, widget.NewButton(a.tr("settings"), func() { win.Close() }),
		nil, nil, container.NewScroll(content),
	))
	win.Show()
}

func (a *App) applyTheme() {
	switch a.theme {
	case ThemeLight:
		a.fyneApp.Settings().SetTheme(&lightTheme{fontSize: float32(a.fontSize)})
	case ThemeDark:
		a.fyneApp.Settings().SetTheme(&darkTheme{fontSize: float32(a.fontSize)})
	case ThemeSepia:
		a.fyneApp.Settings().SetTheme(&sepiaTheme{fontSize: float32(a.fontSize)})
	}
	a.prefs.SetInt("theme", int(a.theme))
}

func main() {
	a := &App{}
	a.fyneApp = app.NewWithID("com.sharersbible.windows")
	a.window = a.fyneApp.NewWindow("Sharer's Bible")
	a.window.Resize(fyne.NewSize(1200, 800))
	a.prefs = a.fyneApp.Preferences()

	// Load preferences
	themeVal := a.prefs.Int("theme")
	themeLabels := map[int]AppTheme{0: ThemeLight, 1: ThemeDark, 2: ThemeSepia}
	if t, ok := themeLabels[themeVal]; ok {
		a.theme = t
	} else {
		a.theme = ThemeLight
	}
	a.fontSize = a.prefs.Float("fontSize")
	if a.fontSize < 14 || a.fontSize > 40 {
		a.fontSize = 21
	}

	a.selectedLanguage = a.prefs.String("selectedLanguage")
	if a.selectedLanguage == "" {
		a.selectedLanguage = "en"
	}
	a.selectedVersion = a.prefs.String("selectedVersion")
	if a.selectedVersion == "" {
		a.selectedVersion = "esv"
	}

	bookID := a.prefs.Int("selectedBookId")
	if bookID >= 1 && bookID <= 66 {
		a.selectedBook = defaultBooks[bookID-1]
	} else {
		a.selectedBook = defaultBooks[42] // John
	}

	a.applyTheme()

	// Load manifest
	a.manifest = loadManifest()

	// Get versions for current language
	a.versions = manifestToVersions(a.manifest, a.selectedLanguage)
	a.copyrights = make(map[string]string)
	for k := range a.versions {
		if cr, ok := englishCopyrights[k]; ok {
			a.copyrights[k] = cr
		}
	}

	populateVersions := func(lang string) {
		a.versions = manifestToVersions(a.manifest, lang)
		a.copyrights = make(map[string]string)
		for k := range a.versions {
			if cr, ok := englishCopyrights[k]; ok {
				a.copyrights[k] = cr
			}
		}
		if _, ok := a.versions[a.selectedVersion]; !ok {
			for k := range a.versions {
				a.selectedVersion = k
				break
			}
		}
	}

	// Create selectors
	a.languageSelect = widget.NewSelect([]string{}, func(s string) {
		langKeys := make([]string, 0, len(langLabels))
		for k := range langLabels {
			langKeys = append(langKeys, k)
		}
		sort.Strings(langKeys)
		for _, k := range langKeys {
			if langLabels[k] == s {
				a.selectedLanguage = k
				a.prefs.SetString("selectedLanguage", k)
				populateVersions(k)
				a.updateSelectors()
				a.loadPassage()
				return
			}
		}
	})

	// Populate version list initially
	verKeys := make([]string, 0, len(a.versions))
	for k := range a.versions {
		verKeys = append(verKeys, k)
	}
	sort.Strings(verKeys)
	verNames := make([]string, len(verKeys))
	for i, k := range verKeys {
		verNames[i] = a.versions[k]
	}

	a.versionSelect = widget.NewSelect(verNames, func(s string) {
		for k, v := range a.versions {
			if v == s {
				a.selectedVersion = k
				a.prefs.SetString("selectedVersion", k)
				a.loadPassage()
				return
			}
		}
	})
	if len(verNames) > 0 {
		if vn, ok := a.versions[a.selectedVersion]; ok {
			a.versionSelect.Selected = vn
		} else {
			a.versionSelect.Selected = verNames[0]
		}
	}

	books := a.getBooks()
	bookNames := make([]string, len(books))
	for i, b := range books {
		bookNames[i] = b.Name
	}

	a.bookSelect = widget.NewSelect(bookNames, func(s string) {
		books2 := a.getBooks()
		for _, b := range books2 {
			if b.Name == s {
				a.selectedBook = b
				a.prefs.SetInt("selectedBookId", b.ID)
				break
			}
		}
		a.updateChapterSelect()
		a.loadPassage()
	})
	a.bookSelect.Selected = a.selectedBook.Name

	chapOpts := make([]string, a.selectedBook.Chapters)
	for i := 0; i < a.selectedBook.Chapters; i++ {
		chapOpts[i] = strconv.Itoa(i + 1)
	}

	chapStr := strconv.Itoa(a.prefs.Int("selectedChapter"))
	if _, err := strconv.Atoi(chapStr); err != nil || chapStr == "0" {
		chapStr = "1"
	}

	a.chapterSelect = widget.NewSelect(chapOpts, func(s string) {
		a.prefs.SetString("selectedChapter", s)
		a.loadPassage()
	})
	a.chapterSelect.Selected = chapStr

	a.fromEntry = widget.NewEntry()
	a.fromEntry.SetText(a.prefs.String("startVerse"))
	a.fromEntry.SetPlaceHolder("1")
	a.fromEntry.OnChanged = func(s string) { a.prefs.SetString("startVerse", s) }

	sepLabel := widget.NewLabel("-")

	a.toEntry = widget.NewEntry()
	a.toEntry.SetText(a.prefs.String("endVerse"))
	a.toEntry.SetPlaceHolder(a.tr("chapter"))
	a.toEntry.OnChanged = func(s string) { a.prefs.SetString("endVerse", s) }

	refreshBtn := widget.NewButton(a.tr("loading"), func() {
		a.loadPassage()
	})

	langKeys := make([]string, 0, len(langLabels))
	for k := range langLabels {
		langKeys = append(langKeys, k)
	}
	sort.Strings(langKeys)
	langNames := make([]string, len(langKeys))
	for i, k := range langKeys {
		langNames[i] = langLabels[k]
	}
	a.languageSelect.Options = langNames
	for i, k := range langKeys {
		if k == a.selectedLanguage {
			a.languageSelect.Selected = langNames[i]
			break
		}
	}

	copyBtn := widget.NewButton(a.tr("copyAllText"), a.copyPassage)

	mdBtn := widget.NewButton(a.tr("exportMarkdown"), a.exportMarkdown)

	htmlBtn := widget.NewButton(a.tr("exportHtml"), a.exportHTML)

	settingsBtn := widget.NewButton(a.tr("settings"), a.showSettings)

	// Navigation row
	navRow := container.NewHBox(
		widget.NewLabel(a.tr("book")+":"),
		a.bookSelect,
		widget.NewLabel(a.tr("chapter")+":"),
		a.chapterSelect,
		widget.NewLabel(a.tr("from")+":"),
		a.fromEntry,
		sepLabel,
		a.toEntry,
		refreshBtn,
	)

	actionRow := container.NewHBox(
		widget.NewLabel(a.tr("language")+":"),
		a.languageSelect,
		widget.NewLabel(a.tr("version")+":"),
		a.versionSelect,
		container.NewHBox(),
		copyBtn, mdBtn, htmlBtn, settingsBtn,
	)

	topBar := container.NewVBox(navRow, actionRow)

	// Reading area
	a.readingContainer = container.NewVBox()
	a.readingScroll = container.NewScroll(a.readingContainer)

	a.refLabel = widget.NewLabel(a.tr("selectPassage"))
	a.sourceLabel = widget.NewLabel("")
	a.copyrightLabel = widget.NewLabel("")

	split := container.NewBorder(topBar, nil, nil, nil, a.readingScroll)

	a.window.SetContent(split)

	// Load initial passage
	a.loadPassage()

	// Set window close handler
	a.window.SetCloseIntercept(func() {
		a.prefs.SetInt("selectedBookId", a.selectedBook.ID)
		a.window.Close()
	})

	a.window.ShowAndRun()
}
