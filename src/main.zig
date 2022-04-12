const print = std.debug.print;
const std = @import("std");
const assert = std.debug.assert;
const stdin = std.io.getStdIn().reader();
const math = std.math;

// memory consists of 100 mailboxes
// each mailbox has an opcode and oprand

// i.e an LMC instruction could be:
// 145 which would be :
// opcode : 1
// oprand : 45
// so 1 is the opcode for add
// so add the contents of address 45 to the ACC

const mailbox = struct {
    opcode: i16,
    oprand: i16,
};

const memory = struct {
    address: [100]mailbox,

    pub fn fetch(self: memory, at: i16) i16 {
        print("Fetching address : {d}\n\r", .{at});
        return self.address[@intCast(u16, at)].opcode * 100 + self.address[@intCast(u16, at)].oprand;
    }
};

const registers = struct {
    ACC: i16, // 8 bit accumulator
    PC: i16, // 8 bit program counter
    IR: i16, // 8 bit instruction register
    AR: i16, // 8 bit instruction register
};

const IO = struct {
    input: i16, // 8 bit input register
    output: i16,
};

pub fn load_program(path: []const u8, mem: *memory) anyerror!void {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var pointer: u16 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        print("{s}\n", .{line});

        // adjust for ascii.
        // so -48 iirc

        mem.address[pointer] = mailbox{
            .opcode = (line[0] - 48),
            .oprand = (@as(i16, (line[1] - 48)) * 10) + (line[2] - 48),
        };

        pointer = pointer + 1;
    }
}

pub fn add(address: i16, acc: *i16, mem: *memory) void {
    acc.* += mem.fetch(address);
}

pub fn sub(address: i16, acc: *i16, mem: *memory) void {
    acc.* -= mem.fetch(address);
}

// TODO generate mailbox and store mailbox rather than whatever I was doing here...
pub fn sta(acc: *i16, addr: i16, mem: *memory) void {
    //mem.* = value.*;

    // split acc into opcode and oprand

    var t_opcode: i16 = @as(i16, @divFloor(acc.*, 100));
    print("Storing {d} in {d}\n\r", .{ acc.*, addr });
    mem.address[@intCast(u16, addr)] = mailbox{
        .opcode = t_opcode,
        .oprand = acc.* - (t_opcode * 100),
    };
}

pub fn lda(acc: *i16, mem: *memory, addr: i16) void {
    acc.* = mem.fetch(addr);
}

pub fn bra(pc: *i16, new_val: i16) void {
    pc.* = new_val;
}

pub fn brz(pc: *i16, acc: i16, new_val: i16) void {
    if (acc == 0) {
        pc.* = new_val;
    }
}

pub fn brp(pc: *i16, acc: i16, new_val: i16) void {
    if (acc > 0) {
        pc.* = new_val;
    }
}

pub fn get_input() !i16 {
    var buf: [3]u8 = undefined;

    print("Input required [3]: ", .{});

    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        return std.fmt.parseInt(i16, user_input, 10);
    } else {
        return @as(i16, 0);
    }
}

pub fn noop() void {
    //print("--noop called--\n\r", .{});
    return;
}

pub fn handle_io(input: *i16, output: *i16, acc: *i16, oprand: i16) void {
    if (oprand == 1) {
        input.* = get_input() catch 0;
        acc.* = input.*;
    } else if (oprand == 2) {
        output.* = acc.*;
        print("Out: {d}\n\r", .{output.*});
    } else {
        noop();
    }
}

pub fn hlt(flag: *bool) void {
    //print("Program Halted!\n\r", .{});
    flag.* = false;
}

pub fn execute(mem: *memory, reg: *registers, io: *IO) void {

    // iterate through memory looking in each mail box
    var halt: bool = false;
    while (!halt and reg.PC < 100) {
        var pc_usize = @intCast(u8, reg.PC);

        var target_opc: i16 = mem.address[pc_usize].opcode;
        var target_opr: i16 = mem.address[pc_usize].oprand;

        //print("Current instruction : {d}{d}\n\r", .{ target_opc, target_opr });

        var instruction: void = switch (target_opc) {
            1 => add(target_opr, &reg.ACC, mem),
            2 => sub(target_opr, &reg.ACC, mem),
            3 => sta(&reg.ACC, target_opr, mem),
            5 => lda(&reg.ACC, mem, target_opr),
            6 => bra(&reg.PC, target_opr),
            7 => brz(&reg.PC, reg.ACC, target_opr),
            8 => brp(&reg.PC, reg.ACC, target_opr),
            9 => handle_io(&io.input, &io.output, &reg.ACC, target_opr),
            0 => hlt(&halt),
            else => noop(),
        };

        _ = instruction;
        reg.PC = reg.PC + 1;
        print("Acc =  {}\n", .{reg.ACC});
    }
}

pub fn main() anyerror!void {
    var my_mem: memory = undefined;
    var my_io = IO{
        .input = undefined,
        .output = undefined,
    };
    var my_reg = registers{
        .ACC = 0,
        .PC = 0,
        .IR = 0,
        .AR = 0,
    };

    // Load the program into RAM.
    // Since the RAM is mutable we can assume that the program can just be the entire RAM
    try load_program("program.tbin", &my_mem);

    //
    //for (my_mem.address) |mb| {
    //    print("opcode:{d} oprand:{d} \n\r", .{ mb.opcode, mb.oprand });
    //}

    execute(&my_mem, &my_reg, &my_io);
}
