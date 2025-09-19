library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity riscv_processor is
    port ( 
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        seg : out STD_LOGIC_VECTOR (6 downto 0);
        ade : out STD_LOGIC_VECTOR (3 downto 0);
        led : out STD_LOGIC_VECTOR (11 downto 0)
    );
end riscv_processor;

architecture Structural of riscv_processor is
    component adder is
        port (
            op1 : in STD_LOGIC_VECTOR(31 downto 0);
            op2 : in STD_LOGIC_VECTOR(31 downto 0);
            sum : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component mux is
        port (
            input1 : in STD_LOGIC_VECTOR(31 downto 0);
            input2 : in STD_LOGIC_VECTOR(31 downto 0);
            sel : in STD_LOGIC;
            mux_output : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component program_counter is
        port (
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            enable : in STD_LOGIC;
            pc_src : in STD_LOGIC_VECTOR(31 downto 0);
            pc : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component instruction_memory is
        port (
            pc : in STD_LOGIC_VECTOR(11 downto 0);
            instruction : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component register_file is
        port (
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            read_addr1 : in STD_LOGIC_VECTOR(4 downto 0);
            read_addr2 : in STD_LOGIC_VECTOR(4 downto 0);
            write_addr : in STD_LOGIC_VECTOR(4 downto 0);
            write_data : in STD_LOGIC_VECTOR(31 downto 0);
            reg_write : in STD_LOGIC;
            read_data1 : out STD_LOGIC_VECTOR(31 downto 0);
            read_data2 : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component immediate_generator is
        port (
            instruction : in STD_LOGIC_VECTOR(31 downto 0);
            immediate : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component control_unit is
        port (
            opcode : in STD_LOGIC_VECTOR(6 downto 0);
            funct3 : in STD_LOGIC_VECTOR(2 downto 0);
            funct7 : in STD_LOGIC_VECTOR(6 downto 0);
            RegWrite : out STD_LOGIC;
            MemRead : out STD_LOGIC;
            MemWrite : out STD_LOGIC;
            BranchEq : out STD_LOGIC;
            memToReg : out STD_LOGIC;
            AluSrc : out STD_LOGIC;
            ALUCont : out STD_LOGIC_VECTOR(2 downto 0);
            jmp : out STD_LOGIC;
            print : out STD_LOGIC
        );
    end component;
    
    component alu is
        port (
            op1 : in STD_LOGIC_VECTOR(31 downto 0);
            op2 : in STD_LOGIC_VECTOR(31 downto 0);
            opcode : in STD_LOGIC_VECTOR(2 downto 0);
            res : out STD_LOGIC_VECTOR(31 downto 0);
            zero_flag : out STD_LOGIC
        );
    end component;
    
    component data_memory is
        port (
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            address : in STD_LOGIC_VECTOR(31 downto 0);
            write_data : in STD_LOGIC_VECTOR(31 downto 0);
            mem_write : in STD_LOGIC;
            mem_read : in STD_LOGIC;
            read_data : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component seven_seg_mux is
        port (
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            print : in STD_LOGIC;
            val : in STD_LOGIC_VECTOR(31 downto 0);  
            seg : out STD_LOGIC_VECTOR(6 downto 0);  
            ade : out STD_LOGIC_VECTOR(3 downto 0)   
        );
    end component;
    
    signal pc_enable : STD_LOGIC := '0';
    signal pc_i : STD_LOGIC_VECTOR(31 downto 0);
    signal pc_next : STD_LOGIC_VECTOR(31 downto 0);
    signal branch_target : STD_LOGIC_VECTOR(31 downto 0);
    signal pc_src_reg : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    
    signal curr_inst : STD_LOGIC_VECTOR(31 downto 0);
    signal immediate_i : STD_LOGIC_VECTOR(31 downto 0);
    signal write_data_i, read_data1_i, read_data2_i : STD_LOGIC_VECTOR(31 downto 0);
    
    signal cu_regwrite, memread_i, memwrite_i, brancheq_i, memtoreg_i, alusrc_i, jmp_i, print_i : STD_LOGIC;
    signal alucont_i : STD_LOGIC_VECTOR(2 downto 0);
    signal alu_op2 : STD_LOGIC_VECTOR(31 downto 0);
    signal res_i : STD_LOGIC_VECTOR(31 downto 0);
    signal zero_flag_i : STD_LOGIC;  
    
    signal dm_read_data : STD_LOGIC_VECTOR(31 downto 0);

begin
    clk_enable_gen : process(clk, rst) 
        variable clk_cnt : integer range 0 to 25_000_000 := 0;
    begin
        if rst = '1' then
            clk_cnt := 0;
            pc_enable <= '0';
        elsif rising_edge(clk) then
            if clk_cnt = 25_000_000 then  
                clk_cnt := 0;
                pc_enable <= '1';
            else
                pc_enable <= '0';
                clk_cnt := clk_cnt + 1;
            end if;
        end if;
    end process clk_enable_gen;
    
    branch_decision : process(clk, rst)
    begin
        if rst = '1' then
            pc_src_reg <= (others => '0');
        elsif rising_edge(clk) then
            if (brancheq_i and zero_flag_i) = '1' then
                pc_src_reg <= branch_target;  
            else
                pc_src_reg <= pc_next;        
            end if;
        end if;
    end process branch_decision;

PC : program_counter 
    port map (
        clk => clk,         
        rst => rst,
        enable => pc_enable,
        pc_src => pc_src_reg,
        pc => pc_i
    );
    
    PC_ADDER : adder
        port map (
            op1 => pc_i,
            op2 => X"00000001",  
            sum => pc_next
        );
    
    BRANCH_ADDER : adder
        port map (
            op1 => pc_i,
            op2 => immediate_i,
            sum => branch_target
        );
        
    IM : instruction_memory
        port map (
            pc => pc_i(11 downto 0),
            instruction => curr_inst
        );
        
    RF : register_file
        port map (
            clk => clk,
            rst => rst,
            read_addr1 => curr_inst(19 downto 15), -- rs1
            read_addr2 => curr_inst(24 downto 20), -- rs2
            write_addr => curr_inst(11 downto 7),  -- rd
            write_data => write_data_i,
            reg_write => cu_regwrite,  
            read_data1 => read_data1_i,
            read_data2 => read_data2_i
        );
    
    IG : immediate_generator 
        port map (
            instruction => curr_inst,
            immediate => immediate_i
        );
        
    CU : control_unit
        port map (
            opcode => curr_inst(6 downto 0),
            funct3 => curr_inst(14 downto 12),
            funct7 => curr_inst(31 downto 25),
            RegWrite => cu_regwrite,
            MemRead => memread_i,
            MemWrite => memwrite_i,
            BranchEq => brancheq_i,
            memToReg => memtoreg_i,
            ALUSrc => alusrc_i,
            ALUCont => alucont_i,
            jmp => jmp_i,
            print => print_i
        );

    ALU_MUX : mux
        port map (
            input1 => read_data2_i,
            input2 => immediate_i,   
            sel => alusrc_i,
            mux_output => alu_op2
        );
        
    ALU_INST : alu 
        port map (
            op1 => read_data1_i,
            op2 => alu_op2,
            opcode => alucont_i,
            res => res_i,
            zero_flag => zero_flag_i
        );
        
    DM : data_memory 
        port map (
            clk => clk,
            rst => rst,
            address => res_i,
            write_data => read_data2_i,
            mem_write => memwrite_i,
            mem_read => memread_i,
            read_data => dm_read_data
        );
    
    WB_MUX : mux
        port map (
            input1 => res_i,        
            input2 => dm_read_data, 
            sel => memtoreg_i,
            mux_output => write_data_i
        );
    
    DISPLAY : seven_seg_mux
        port map (
            clk => clk,
            rst => rst,
            print => print_i,
            val => read_data1_i,
            seg => seg,
            ade => ade
        );
    
    -- LED output shows lower 12 bits of PC
    led <= pc_i(11 downto 0);

end Structural;
