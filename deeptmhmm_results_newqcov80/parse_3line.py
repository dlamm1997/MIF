def parse_file_into_blocks(filename):
    with open(filename, 'r') as file:
        block = []
        for counter, line in enumerate(file, start=1):
            block.append(line.rstrip('\n'))  # Append the line without the newline character
            if counter % 3 == 0:
                yield block
                block = []
        
        # If there are remaining lines that do not form a complete block at the end
        if block:
            yield block

blocks = []
for block in parse_file_into_blocks("predicted_topologies.3line"):
    id_string = str(block[0].split(" |")[0]).split(">")[1]
    residue_locs = block[2]
    if 'O' in residue_locs and  'S' in residue_locs:
        print(id_string, residue_locs)
        with open("deeptmhmm_extra_hits", "a+") as f_out:
                  f_out.write(id_string)
                  f_out.write("\n")
                    
    
