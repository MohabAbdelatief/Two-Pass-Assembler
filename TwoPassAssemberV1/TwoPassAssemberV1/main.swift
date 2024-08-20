import Foundation

enum InstructionType {
    case MRI
    case nonMRI
    case IO
    case pseudo
}
// INSTRUCTION
struct Instruction {
    var label: String?
    var opcode: String?
    var operand: String?
    var type: InstructionType?
}

// SYMBOL TABLE
struct SymbolTable {
    var symbols: [String: Int] = [:]

    mutating func addSymbol(label: String, address: Int) {
        symbols[label] = address
    }

    func getAddress(label: String) -> Int? {
        return symbols[label]
    }
}

// TWO PASS ASSEMBLER
class TwoPassAssembler {
    var instructions: [Instruction] = []
    var symbolTable: SymbolTable = SymbolTable()
    var machineCode: [String] = []

    // 4-types of opcodes, these are the 4 types
    func determineType(opcode: String) -> InstructionType {
        switch opcode {
        case "AND", "ADD", "LDA", "STA", "BUN", "BSA", "ISZ":
            return .MRI
        case "CLA", "CLE", "CMA", "CME", "CIR", "CIL", "INC", "SPA", "SNA",
            "SZA", "SZE", "HLT":
            return .nonMRI
        case "INP", "OUT", "SKI", "SKO", "ION", "IOF":
            return .IO
        case "ORG", "END", "DEC", "HEX":
            return .pseudo
        default:
            fatalError("Unknown opcode: \(opcode)")
        }
    }
    // READ ASSEMBLY CODE AND EXTRACT INSTRUCTIONS
    func readInstructions(_ assemblyCode: [String]) {
        // FOR EACH LINE IN ASSEMBLY CODE
        for line in assemblyCode {
            // SEPERATE CODE BY SPACE AND MAKE EACH SUBSTRING TO BE CONVERTED TO A STRING
            let codePart = line.split(separator: " ").map { String($0) }
            // EXTRACT INSTRUCTION FROM CODE LINE
            var instruction: Instruction
            // LABEL IS FOUND
            if codePart.count == 3 {
                // Label is found
                instruction = Instruction(
                    label: codePart[0], opcode: codePart[1],
                    operand: codePart[2],
                    type: determineType(opcode: codePart[1]))
            } else if codePart.count == 2 {
                // No label
                instruction = Instruction(
                    label: nil, opcode: codePart[0], operand: codePart[1],
                    type: determineType(opcode: codePart[0]))
            } else if codePart.count == 1 {
                // Handle case where there is only an opcode (no operand or label)
                instruction = Instruction(
                    label: nil, opcode: codePart[0], operand: nil,
                    type: determineType(opcode: codePart[0]))
            } else {
                fatalError("Unexpected format in assembly line: \(line)")
            }
            instructions.append(instruction)
        }
    }
    // FIRST PASS
    func firstPass() {
        var locationCounter = 0

        // CHECK FOR LABELS IN EACH INSTRUCTION AND IF THE LABEL IN THE INSTRUCTION IS NOT EQUAL TO NULL THEN ADD THAT INSTRUCITON TO THE SYMBOL TABLE
        for instruction in instructions {
            if let label = instruction.label {
                symbolTable.addSymbol(label: label, address: locationCounter)
            }
            // CATCH ADDRESS NEXT TO ORG
            if instruction.type == .pseudo {
                if instruction.opcode == "ORG",
                    let operand = instruction.operand,
                    let decimalORGLocation = Int(operand, radix: 16)
                {  // CONVERT HEXADECIMAL ADDRESS TO DECIMAL FOR LATER CONVERSION
                    locationCounter = decimalORGLocation
                } else if instruction.opcode == "END" {
                    break  // Stop the first pass if END is encountered
                }
            } else {
                locationCounter += 1
            }
        }
    }

    // SECOND PASS
    func secondPass() {
        var locationCounter = 0
        // EACH INSTRUCITION CHECK
        for instruction in instructions {
            var machineInstruction = ""

            // Handle pseudo-instructions
            if instruction.type == .pseudo {
                if instruction.opcode == "ORG",
                    let operand = instruction.operand,
                    let newLocation = Int(operand, radix: 16)
                {
                    locationCounter = newLocation
                } else if instruction.opcode == "END" {
                    break
                } else if instruction.opcode == "DEC",
                    let operand = instruction.operand
                {
                    let binaryValue = String(format: "%016b", Int(operand)!)
                    storeMachineCode(binaryValue, at: locationCounter)
                } else if instruction.opcode == "HEX",
                    let operand = instruction.operand
                {
                    let binaryValue = String(
                        format: "%016b", Int(operand, radix: 16)!)
                    storeMachineCode(binaryValue, at: locationCounter)
                }
            }
            // Handle MRI instructions
            else if instruction.type == .MRI {
                let indirect = false  // Set this based on whether the instruction is indirect
                if let operand = instruction.operand,
                    let address = symbolTable.getAddress(label: operand)
                {
                    machineInstruction = convertMRIInstruction(
                        opcode: instruction.opcode!, operandAddress: address,
                        indirect: indirect)
                } else {
                    machineInstruction = convertMRIInstruction(
                        opcode: instruction.opcode!, operandAddress: 0,
                        indirect: indirect)
                }
                storeMachineCode(machineInstruction, at: locationCounter)
            }
            // Handle Non-MRI instructions
            else if instruction.type == .nonMRI {
                machineInstruction = getNonMRIInstructionBinary(
                    instruction.opcode!)
                storeMachineCode(machineInstruction, at: locationCounter)
            }
            // Handle I/O instructions
            else if instruction.type == .IO {
                machineInstruction = getIOInstructionBinary(instruction.opcode!)
                storeMachineCode(machineInstruction, at: locationCounter)
            }

            locationCounter += 1
        }
    }

    func getOpcodeBinary(_ opcode: String, indirect: Bool) -> String {
        switch opcode {
        case "AND":
            return indirect ? "1000" : "0000"
        case "ADD":
            return indirect ? "1001" : "0001"
        case "LDA":
            return indirect ? "1010" : "0010"
        case "STA":
            return indirect ? "1011" : "0011"
        case "BUN":
            return indirect ? "1100" : "0100"
        case "BSA":
            return indirect ? "1101" : "0101"
        case "ISZ":
            return indirect ? "1110" : "0110"
        default:
            return "0000"
        }
    }

    func getNonMRIInstructionBinary(_ opcode: String) -> String {
        switch opcode {
        case "CLA":
            return "0111100000000000"
        case "CLE":
            return "0111010000000000"
        case "CMA":
            return "0111001000000000"
        case "CME":
            return "0111000100000000"
        case "CIR":
            return "0111000010000000"
        case "CIL":
            return "0111000001000000"
        case "INC":
            return "0111000000100000"
        case "SPA":
            return "0111000000010000"
        case "SNA":
            return "0111000000001000"
        case "SZA":
            return "0111000000000100"
        case "SZE":
            return "0111000000000010"
        case "HLT":
            return "0111000000000001"
        default:
            return "0000000000000000"  // Error case or NOP
        }
    }

    func getIOInstructionBinary(_ opcode: String) -> String {
        switch opcode {
        case "INP":
            return "1111100000000000"  // F800
        case "OUT":
            return "1111010000000000"  // F400
        case "SKI":
            return "1111001000000000"  // F200
        case "SKO":
            return "1111000100000000"  // F100
        case "ION":
            return "1111000010000000"  // F080
        case "IOF":
            return "1111000001000000"  // F040
        default:
            return "0000000000000000"  // Error case or NOP
        }
    }

    func convertMRIInstruction(
        opcode: String, operandAddress: Int, indirect: Bool
    ) -> String {
        let opcodeBinary = getOpcodeBinary(opcode, indirect: indirect)
        let addressBinary = String(format: "%012b", operandAddress)  // 12-bit binary address
        return opcodeBinary + addressBinary
    }

    func storeMachineCode(_ binaryCode: String, at location: Int) {
        let hexLocation = String(format: "0x%X", location) // for presentation
        machineCode.append("Loction Counter: \(location), Memory Address: \(hexLocation), In Binary: " + binaryCode)
    }

    // Function to run the test cases
    func runTests() {
        let testCases = [
            [
                "START ORG 1000",
                "LABEL1 LDA VALUE",
                "ADD VALUE",
                "STA RESULT",
                "HLT",
                "VALUE DEC 5", "RESULT HEX 0",
                "END",
            ],
            [
                "START ORG 2000",
                "INP",
                "OUT",
                "HLT",
                "END",
            ],
            [
                "START ORG 5000",
                "LDA VALUE",
                "ORG 6000",
                "STA RESULT",
                "ORG 7000",
                "VALUE DEC 15",
                "RESULT HEX 1234",
                "END",
            ],
            // FAULTY TEST CASES
//            [
//                "START ORG 3000",
//                "LDA VALUE, I",
//                "STA RESULT",
//                "HLT",
//                "VALUE DEC 10",
//                "RESULT HEX FFFF",
//                "END",
//
//            ],
//            [
//                "START ORG 4000",
//                "LDA MISSING_LABEL",
//                "ADD WRONG",
//                "HLT",
//                "WRONG HEX ZZZZ",
//                "END",
//            ],
        ]

        for (index, testCase) in testCases.enumerated() {
            print("\nRunning Test Case \(index + 1):")
            instructions = []
            symbolTable = SymbolTable()
            machineCode = []

            readInstructions(testCase)
            firstPass()
            secondPass()

            print("Symbol Table:", symbolTable.symbols)
            print("Generated Machine Code:")
            for code in machineCode {
                print(code)
            }
        }
    }

}
let assembler = TwoPassAssembler()
assembler.runTests()
