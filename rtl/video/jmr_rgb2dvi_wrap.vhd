-- Thin VHDL wrap so SystemVerilog tops can use Digilent rgb2dvi without
-- fighting boolean generics across the language boundary.
-- LLM NOTE: Do not rewrite TMDS — this only instantiates Digilent rgb2dvi
-- from third_party/digilent_rgb2dvi with kClkRange=5 for ~25 MHz pixel clock.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity jmr_rgb2dvi_wrap is
   Port (
      TMDS_Clk_p  : out std_logic;
      TMDS_Clk_n  : out std_logic;
      TMDS_Data_p : out std_logic_vector(2 downto 0);
      TMDS_Data_n : out std_logic_vector(2 downto 0);
      aRst        : in  std_logic;
      vid_pData   : in  std_logic_vector(23 downto 0);
      vid_pVDE    : in  std_logic;
      vid_pHSync  : in  std_logic;
      vid_pVSync  : in  std_logic;
      PixelClk    : in  std_logic
   );
end jmr_rgb2dvi_wrap;

architecture Structural of jmr_rgb2dvi_wrap is
begin
   u_rgb2dvi : entity work.rgb2dvi
      generic map (
         kGenerateSerialClk => true,
         kClkPrimitive      => "MMCM",
         kClkRange          => 5,   -- >=25 MHz (ClockGen.vhd)
         kRstActiveHigh     => true
      )
      port map (
         TMDS_Clk_p  => TMDS_Clk_p,
         TMDS_Clk_n  => TMDS_Clk_n,
         TMDS_Data_p => TMDS_Data_p,
         TMDS_Data_n => TMDS_Data_n,
         aRst        => aRst,
         aRst_n      => '1',
         vid_pData   => vid_pData,
         vid_pVDE    => vid_pVDE,
         vid_pHSync  => vid_pHSync,
         vid_pVSync  => vid_pVSync,
         PixelClk    => PixelClk,
         SerialClk   => '0'
      );
end Structural;
