# The camel's voice

Every sound here is a real recording of a camel, cut from the two recordings listed below by
`tools/cut_camel_audio.py` (which has the exact stretch of each recording that each file is),
faded in and out, brought to mono, 32 kHz, 16 bits, and brought to a common loudness for its kind.
They are imported uncompressed (`compress/mode=0` in each `.import`), as the hounds' are, so that the game
can read how loud each is through its length to open the camel's mouth.

| Files | What it is | Recording | Author | Licence |
| --- | --- | --- | --- | --- |
| `groan_1`, `grunt_1` | A camel's groan, and the start of it | "Camel Groan", `camel_01`. https://opengameart.org/content/camel-groan | AntumDeluge, extracted from a field recording by craigsmith (https://freesound.org/s/437937/) | CC0 1.0 (public domain) |
| `groan_2`, `groan_3`, `grunt_2`, `grunt_3` | A longer groan, in two halves, and two short stretches of it | "Camel Groan", `camel_02`. https://opengameart.org/content/camel-groan | AntumDeluge, extracted from a field recording by craigsmith (https://freesound.org/s/437937/) | CC0 1.0 |

CC0 asks for no credit; it is given gladly.

There are only these two recordings, so a camel here has one voice and not much to say with it. A bellow, the
gurgle of a bull in rut, and the quieter grumbling of a camel being loaded are not recorded: when free recordings
of them are found, add them here as `bellow_<n>.wav` and so on, and give `Camel.KINDS` their names.
