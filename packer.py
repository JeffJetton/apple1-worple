
# Read in file of five-letter words and encode them into two groups
# of three-byte packed binary.
#
# Each letter is converted to a five-bit value, 0-25.
# The bits are put together into a 25 bits, which would normally take
# up four bytes of storage. Since bit 0 of the MSB (the right-most bit
# of our 25 bits) can only be 0 or 1, we'll just split the data
# into two groups and only store the least-significant 24 bits.
#
# In other words, if the first letter is A-P (0-15), we can store that
# first letter in only four bits.  Remaining letters are five bits each
# regardless, for a total of 24 bits (three bytes).
# If the first letter is P-Z (15-25), we'll still store it in four bits,
# but in separate list that we'll keep in a specific section of
# memory.  We'll just need to be aware that words from that part of the
# list will need to have that bit put back on (i.e., have that first
# letter shifted up the alphabet by 16 letters)

import random

INFILE = 'words.txt'
OUTFILE_0 = 'words_0.bin'
OUTFILE_1 = 'words_1.bin'


def pack(word):
    # Pack a five-letter word into three bytes.
    # Return binary bytes along with an overflow flag (1 or 0)
    word = word.strip().upper()
    if len(word) != 5:
        raise ValueError(f'"{word}" is not five letters long')
    b = 0
    for i in range(5):
        # Convert letter to 0-25 integer
        c = ord(word[i]) - 65
        if (c < 0) or (c > 25):
            raise ValueError('Character out of range A-Z in word ' + word)
        # Scoot current contents of b over by five bits,
        # then add new character
        b = b * 32
        b += c
    
    # Did we "overflow" into bit 24?
    if b & 0x1000000:
        # Mask off just the leftmost three bytes
        b &= 0xFFFFFF
        overflow = 1
    else:
        overflow = 0
        
    # Return as a three-byte bytes object
    return [b.to_bytes(3, 'big'), overflow]
    

def head_and_tail(list, size=6):
    print('Head: ' + str(list[0:size]))
    print('Tail: ' + str(list[-size:]))
    return
    

##############################################################################

# Read in list
print('\nReading ' + INFILE)
with open(INFILE, 'r') as infile:
    words = infile.readlines()
print('Words read: ' + str(len(words)))
head_and_tail(words)
print()

# Shuffle them up
print('Shuffling...')
random.seed(24601)
random.shuffle(words)
head_and_tail(words)
print()

# Pack into bytes (this also uppercases and strips whitespace/returns)
print('Packing words...')
packed_list = [[],[]]
for word in words:
    packed = pack(word)
    packed_list[packed[1]].append(packed[0])
print('Words with first bit = 0: ' + str(len(packed_list[0])))
print('Words with first bit = 1: ' + str(len(packed_list[1])))
print()

# Save as two separate list files
print('Saving word lists...')
with open(OUTFILE_0, 'wb') as outfile:
    for data in packed_list[0]:
        outfile.write(data)
with open(OUTFILE_1, 'wb') as outfile:
    for data in packed_list[1]:
        outfile.write(data)
print('Done\n')

    



