library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- RISC-V Program Counter
-- Handles sequential instruction fetch and branch/jump operations
-- PC increments by 4 bytes (32-bit instructions) each cycle unless overridden
entity program_counter is
    port (
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        pc_write : in STD_LOGIC;                    -- enable PC update (for pipeline stalls)
        pc_src : in STD_LOGIC_VECTOR(31 downto 0);  -- new PC value from branch/jump
        branch_taken : in STD_LOGIC;                -- signal indicating branch/jump taken
        pc : out STD_LOGIC_VECTOR(31 downto 0)      -- current PC value
    );
end program_counter;

architecture Behavioral of program_counter is
    signal curr_pc : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    
    constant PC_INCREMENT : integer := 4;  -- 32-bit instructions = 4 bytes
    constant RESET_PC : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    
begin
    -- PC update process
    process(clk, rst)
    begin
        if rst = '1' then
            curr_pc <= RESET_PC;
        elsif rising_edge(clk) then
            if pc_write = '1' then
                if branch_taken = '1' then
                    -- branch or jump taken - overwrite existing PC
                    curr_pc <= pc_src;
                else
                    -- next sequential instruction
                    curr_pc <= STD_LOGIC_VECTOR(unsigned(curr_pc) + PC_INCREMENT);
                end if;
            end if;
            -- If pc_write = '0', PC stays the same
        end if;
    end process;
    
    -- Output current PC
    pc <= curr_pc;
    
end Behavioral;
