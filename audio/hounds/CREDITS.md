# The hounds' voices

Every sound here is a real recording of a dog, cut from the recordings listed below by
`tools/cut_hound_audio.py` (which has the exact stretch of each recording that each file is),
faded in and out, brought to mono, 32 kHz, 16 bits, and brought to a common loudness for its kind.
They are imported uncompressed (`compress/mode=0` in each `.import`), because the game reads how loud
each is through its length to move the hound's jaw.

| Files | What it is | Recording | Author | Licence |
| --- | --- | --- | --- | --- |
| `bark_deep_1` to `_6` | Single deep barks (the bloodhound's) | "Barking Dog #2": a sled dog, outdoors. https://bigsoundbank.com/barking-dog-2-s2954.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 (public domain) |
| `bark_deep_7` | A longer, lower woof | "Barking dog #3". https://bigsoundbank.com/barking-dog-3-s2955.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `bark_sharp_1` to `_6` | Single sharper barks (the pharaoh hound's) | "Old dog barking #2". https://bigsoundbank.com/old-dog-barking-2-s2353.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `bark_sharp_7`, `_8` | Single barks, indoors | "Barking Dog Inside". https://bigsoundbank.com/barking-dog-inside-s0112.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `yap_1` to `_4` | A small dog's yap, for play | "Small dog barking". https://bigsoundbank.com/small-dog-barking-s0612.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `yap_5` | A spitz's bark | "Barking of a Spitz". https://bigsoundbank.com/barking-of-a-spitz-s0682.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `bay_1` | One dog howling | "Dog singing #2". https://bigsoundbank.com/dog-singing-2-s2451.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `bay_2` to `_4` | Howling, several sled dogs together | "Pack of Dogs". https://bigsoundbank.com/pack-of-dogs-s2953.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `bay_5` | A small dog (a chihuahua) howling | "Jem howls". https://commons.wikimedia.org/wiki/File:Jem_howls.ogg (from pdsounds.org) | amethysta | Public domain |
| `whine_1` | A high, drawn-out howl, used as a whine | "Dog singing #1". https://bigsoundbank.com/dog-singing-1-s2450.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `growl_1` | A growl | "Dog Growl". https://opengameart.org/content/dog-growl | bonebrah | CC0 1.0 |
| `growl_2`, `growl_3` | Growls of a large dog and of a small one | Audio S3 and S2 of the paper below. https://commons.wikimedia.org/wiki/File:Dogs'-Expectation-about-Signalers'-Body-Size-by-Virtue-of-Their-Growls-pone.0015175.s007.ogg and ...s006.ogg | Faragó T, Pongrácz P, Miklósi Á, Huber L, Virányi Z, Range F | CC BY 2.5 |
| `pant_1` to `_3` | Dogs panting | "Dogs Breathing". https://bigsoundbank.com/dogs-breathing-s1547.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `snap_1`, `snap_2` | A bark with a growl in it; a hard bark | "2 small dogs bark and growl". https://bigsoundbank.com/small-dogs-bark-growl-s1060.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |
| `snap_3` | A burst of barks | "Old dog barking #3". https://bigsoundbank.com/old-dog-barking-3-s2354.html | Joseph Sardin, BigSoundBank.com | CC0 1.0 |

BigSoundBank's licence page (https://bigsoundbank.com/licenses.html) gives its "Free and Royalty Free" sounds
under CC0 1.0; credit is not required but is asked for, and is given gladly:
**Additional sounds: Joseph SARDIN - BigSoundBank.com**

## Attribution required

`growl_2.wav` and `growl_3.wav` are adapted (cut, resampled, made louder) from Audio S3 and Audio S2 of:
Faragó T, Pongrácz P, Miklósi Á, Huber L, Virányi Z, Range F (2010). "Dogs' Expectation about Signalers' Body
Size by Virtue of Their Growls". PLOS ONE 5(12): e15175. https://doi.org/10.1371/journal.pone.0015175.
Licensed under Creative Commons Attribution 2.5 (https://creativecommons.org/licenses/by/2.5/).
To ship without any attribution duty, delete those two files: the game then uses `growl_1` alone.
