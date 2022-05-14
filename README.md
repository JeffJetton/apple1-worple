# Apple 1 "Worple"
    
<img src="https://github.com/JeffJetton/apple1-worple/blob/main/img/screenshot.png" width="400">

A Wordle-style puzzle game for the Apple 1. Features over 850 words, but small enough to run on systems with as little as 4K of RAM.


## Files in the Repo:

* **worple.asm**
    * The 6502 assembly language source code
    * I used [dasm](https://dasm-assembler.github.io/) to assemble this, but other 6502 assemblers should work without too much tweaking
    
* **worple.bin**
    * Assembled binary file
    * The first two bytes in the file are the (little-endian) origin address of the code: $0300
* **worple.js**
    * Javascript "tape file" format, compatible with Will Scullin's [Apple 1js emulator](https://www.scullinsteel.com/apple1/)
    * You can use this with a local copy of the emulator by putting the file in the `/tapes` directory and adding a reference to it in `apple1.htm`
    
* **worple.txt**
    * Typed version of program in "Woz Monitor" hex format
    * Many emulators will let you copy/paste or otherwise load this in
    * You can also send this over to a real Apple 1 (or replica/clone) via serial connection
    * Once loaded in, enter `300R` to run

* **words.txt**
    * Text file of words used by the game

* **words_0.bin and words_1.bin**
    * Compressed binary versions of the word list, split into two parts (A-P and Q-Z)

* **packer.py**
    * Python utility that creates the compressed binary word files 

## Modifying the Word List

* Edit `words.txt` as you see fit. (If your list exceeds 866 words, more than 4K of RAM will be required.)
* Run `packer.py` to shuffle the word list and rebuild the two binary word files
* Reassemble `worple.asm` to build a new executable binary with the new words in it

