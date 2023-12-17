import sys

def hex_to_binary(hex_string):
    return bytes.fromhex(hex_string)

if len(sys.argv) != 2:
    print("Usage: python script.py input_file")
else:
    input_file = sys.argv[1]
    output_file = 'temp.txt'
    
    with open(input_file, 'r') as file:
        lines = file.readlines()

    # Remove the last line
    if lines:
        lines = lines[:-1]

    processed_lines = [line[9:-3] for line in lines]

    with open(output_file, 'w') as file:
        for line in processed_lines:
            file.write(line + '\n')

    input_file='temp.txt'
    output_file = 'eeprom.bin'
    
    with open(input_file, 'r') as file:
        hex_string = file.read().replace('\n', '').strip()

    if len(hex_string) % 2 != 0:
        print("Invalid input: Hexadecimal length should be even.")
    else:
        binary_data = b''
        for i in range(0, len(hex_string), 2):
            hex_value = hex_string[i:i+2]
            try:
                binary_data += hex_to_binary(hex_value)
            except ValueError:
                print(f"Illegal hex value: {hex_value}")
                break

        with open(output_file, 'wb') as file:
            file.write(binary_data)

        print(f"Binary data written to '{output_file}'")

