class_name InscriptionTexts
## Texts to carve, for a level to pick by name: `Hieroglyphs.write("@offering")`,
## or `Inscription.text = "@offering"`, or the "Text" of an Inscription in the
## level editor. Each has
##     write    the signs, as `Hieroglyphs.write` takes them
##     says     how an Egyptologist would write it out in letters
##     means    what it says, which is what `Hieroglyphs.read` gives back
##
## The offering formula, the king's titles and the phrases of the filler are
## as they stand on thousands of monuments. The curse is the one Old Kingdom
## tomb owners (Harkhuf at Aswan, Khentika at Saqqara, about 2300 BC) put at
## their doors, and the hymns are the opening of the Great Hymn to the Aten
## (tomb of Ay at Amarna) and the heading of the sun hymn in the Book of the
## Dead. The hints are made up for the game, in the grammar of Middle Egyptian
## (the verb first, then who does it), from words the Egyptians had.

## The names, in the order the level editor lists them (a level keeps the place in this list).
const ORDER: Array[String] = ["offering", "curse", "king", "khufu", "hymn", "praise", "door_light", "follow_water", "dead_live", "sun_pyramid", "filler"]
## What the level editor calls them, in that order, after "what is typed" (which is no text of these).
const TITLES := ["What is typed", "Offering formula", "Tomb curse", "A king's titles", "Khufu's name", "Hymn to the sun", "Praise of Ra", "Hint: the door and the light",
	"Hint: follow the water", "Hint: the dead live here", "Hint: the sun and the pyramid", "Common phrases (for long walls)"]

const TEXTS := {
	"offering": {
		"write": "{sw*t:Htp-di st:ir-A40 nb Dd-Dd-w-niwt nTr-aA nb Ab-b-Dw:niwt di-f pr:r-t-xrw 1000-X4:W22 1000-F1*H1 x:t-nb:t-nfr-t n-kA:Z1-n mr-i*i-A1 mAa-xrw}",
		"says": "ḥtp di nsw wsir nb ḏdw nṯr ꜥꜣ nb ꜣbḏw di.f prt-ḫrw ḫꜣ t ḥnqt ḫꜣ kꜣ ꜣpd ḫt nbt nfrt n kꜣ n mry mꜣꜥ-ḫrw",
		"means": "An offering which the king gives to Osiris, lord of Djedu, the great god, lord of Abydos, that he may give a voice-offering: a thousand of bread and beer, a thousand of oxen and fowl, and every good thing, for the spirit of Mery, true of voice.",
	},
	"curse": {
		"write": "{i:r z:Z1-A1 nb a:q-D54-t:f r i-s-pr p:n m a-b-w-mw-f i-w r i-T:t-a T:z-f mi A-p:d-sA i-w-f r w-D:a-Y1 Hr:s i-n nTr-aA}",
		"says": "ir z nb ꜥq.ty.fy r is pn m ꜥbw.f iw r iṯt ṯz.f mi ꜣpd iw.f r wḏꜥ ḥr.s in nṯr ꜥꜣ",
		"means": "As for any man who shall enter this tomb in his impurity: I shall seize his neck like a bird's, and he shall be judged for it by the great god.",
	},
	"king": {
		"write": "{sw*t-bit:t nb-tA:tA <ra-xpr-Z2:nb> sA-ra nb-xa:Z2 <i-mn:n-t-w-t-anx> di-anx mi-ra D:t:tA}",
		"says": "nsw-bity nb tꜣwy nb-ḫprw-rꜥ sꜣ rꜥ nb ḫꜥw twt-ꜥnḫ-imn di ꜥnḫ mi rꜥ ḏt",
		"means": "The King of Upper and Lower Egypt, Lord of the Two Lands, Nebkheperure; the Son of Ra, Lord of Crowns, Tutankhamun, given life like Ra for ever.",
	},
	"khufu": {
		"write": "{sw*t-bit:t <x-w-f-w> di-anx D:t:tA}",
		"says": "nsw-bity ḫwfw di ꜥnḫ ḏt",
		"means": "The King of Upper and Lower Egypt, Khufu, given life for ever.",
	},
	"hymn": {
		"write": "{xa:a-k nfr-f:r m Axt:t*pr n:t p*t:pt i-t:n-ra anx-n:x S-A-a anx-n:x}",
		"says": "ḫꜥ.k nfr m ꜣḫt nt pt itn ꜥnḫ šꜣꜥ ꜥnḫ",
		"means": "You rise in beauty on the horizon of heaven, O living sun-disc, who first gave life.",
	},
	"praise": {
		"write": "{dwA-A-A2 ra:Z1-A40 x:f:t w-b-n:N8-f m Axt:t*pr n:t p*t:pt}",
		"says": "dwꜣ rꜥ ḫft wbn.f m ꜣḫt nt pt",
		"means": "Praising Ra when he rises on the horizon of heaven.",
	},
	"door_light": {
		"write": "{w-n:O31 aA:O31 n di s-S:p-N8}",
		"says": "wn ꜥꜣ n di sšp",
		"means": "The door opens to him who gives light.",
	},
	"follow_water": {
		"write": "{S-m-s-D54 mw r pr:nbw}",
		"says": "šms mw r pr-nbw",
		"means": "Follow the water to the house of gold.",
	},
	"dead_live": {
		"write": "{anx-n:x m-t-A14-Z2 m i-s-pr p:n}",
		"says": "ꜥnḫ mwtw m is pn",
		"means": "The dead live in this tomb.",
	},
	"sun_pyramid": {
		"write": "{a:q-D54 ra:Z1 r Ab-r-O24 m h:r-w-ra:Z1}",
		"says": "ꜥq rꜥ r mr m hrw",
		"means": "The sun enters the pyramid by day.",
	},
	"filler": {
		"write": "{anx-DA-s di-anx Dd wAs mi-ra D:t:tA nTr-nfr nb-tA:tA sA-ra nb-xa:Z2 D:d-mdw i-n st:ir-A40 mr-i*i i-mn:n-A40 anx D:t:tA}",
		"says": "ꜥnḫ wḏꜣ snb di ꜥnḫ ḏd wꜣs mi rꜥ ḏt nṯr nfr nb tꜣwy sꜣ rꜥ nb ḫꜥw ḏd mdw in wsir mry imn ꜥnḫ ḏt",
		"means": "Life, prosperity, health! Given life, stability and power like Ra for ever. The good god, lord of the two lands, son of Ra, lord of crowns. Words spoken by Osiris. Beloved of Amun, living for ever.",
	},
}
