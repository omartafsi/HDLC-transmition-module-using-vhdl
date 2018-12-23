

library IEEE;
use IEEE.std_logic_1164.all;

entity	TRANSMIT2 is 
port (  in0 : in std_logic;  --input data 0
	in1 : in std_logic;  --input data 1
	in2 : in std_logic;  --input data 2
	in3 : in std_logic;  --input data 3
	in4 : in std_logic;  --input data 4
	in5 : in std_logic;  --input data 5
	in6 : in std_logic;  --input data 6
        in7 : in std_logic;  --input data 7
	clk,rst: in std_logic; --Master Clock and Master Reset
	T_Start: in std_logic;	--Transmit Start : asserted before latching data to buffer for first time
	T_ABORT: in std_logic;	--Transmit Abort
	T_Enable: in std_logic;	--Transmit Enable
	T_last_octet: in std_logic;--Transmit last_octet : asserted when latching data into buffer
	T_READ : out std_logic;  --Transmit data read :asserted to the FIFO  to provide data 
	T_D    : out std_logic); -- serial output 
end TRANSMIT2;
  
architecture TRANSMIT_BEHAVIOR of TRANSMIT2 is
-------------------------------------------------------------------------------------SIGNALS------------------------------------------------------------------------------
--- F_INSERT -------
type state IS (f2,f3,f4,f7,f8,f9,f10,f11,abt,data);-- f _insert state machine
signal my_state: state ;
signal w_r_order :std_logic;
---------------------

----Z_STUFF----------
type octet_state is (s0,s1,s2,s3,s4,s5,ZI);-- z_stuff state machine
signal z_state : octet_state ;
signal z_input,z_output: std_logic;	
---------------------

----CRC_GEN----------
signal crc_temp : std_logic_vector(15 downto 0) :=(others=>'0') ;
signal crc_cache : std_logic := '0';
signal crc_counter : integer range 0 to 17 := 0;
signal crc_input,crc_output: std_logic;
---------------------

----T_SHIFT----------
signal T_SHIFT_counter : integer range 0 to 9 := 8;
signal t_shift_input: std_logic_vector(7 downto 0);
signal t_shift_output: std_logic;
signal t_shift_b_shift,t_shift_get_ready: std_logic;
---------------------

----T_BUFFER--------
signal buffer_output_temp_c : std_logic_vector(7 downto 0);
signal buffer_output :  std_logic_vector(7 downto 0);
signal t_buffer_first_start : std_logic;
signal t_buffer_s_b_shift :std_logic;
--------------------

----ABORT----------
signal abort_temp : std_logic;
signal abort_counter: integer range 0 to 9 :=0;
signal abort_output: std_logic;
--------------------

----T_CONTROL-------
signal first_start_temp : std_logic;
signal first_start_bool : boolean := false;
signal mux_manager_temp: std_logic;
signal buffer_start_temp: std_logic;
signal mux_counter: integer range 0 to 10 :=0;
signal mux_bool : boolean := false;
signal w_r_bool	:boolean := false;
signal w_r_counter : integer range 0 to 4 :=0;
signal fire_counter :integer range 0 to 5 :=0;
signal fire_bool:boolean := false;
signal end_bool:boolean := False;
signal control_w_r: std_logic; 
signal control_mux_manager:  std_logic := '1';
signal control_buffer_start: std_logic;
signal control_reset_everything: std_logic;
signal control_fire : std_logic;
---------------------

signal T_D_temp: std_logic;
begin 


--------------------------------------------------------------------F_INSERT------------------------------------------------------------------------------------------------------

T_D_proc: process (clk, rst)
begin
	if (rst='1') then 
		T_D<='1';
	elsif rising_edge(clk) then
		if (T_Enable='1') then
		  case my_state is 
			when f2 =>
				T_D<='0';
			when f11 =>
				T_D<='0';
			when data =>
				T_D<= z_output;
			when others =>
				T_D<='1';
		   end case;
                  end if;                                   
	end if;
end process T_D_proc;


--type state IS (f2,f3,f4,f7,f8,f9,f10,f11,abt,data);
--signal my_state: state ;

F_INSERT:process(clk,rst)

begin 

	if(rst='1') then 
		my_state<=f2;
	elsif rising_edge(clk) then 
	 if (T_Enable='1') then
	  case my_state is 	
		when  f2 => 
			my_state<=f3;
		when  f3 =>
			my_state<=f4;
		when  f4 =>
			my_state<=f7;
			w_r_order <='1';
		when  f7 =>
			my_state<=f8;
			w_r_order <='0';
		when  f8 =>
			my_state<=f9;
		when  f9 =>
			my_state<=f10;
		when   f10=>  
			if (abort_output='1') then
				my_state<=abt;
			else 
				my_state<=f11;
				
			end if;
		when   abt=>
			my_state <= f2;
		 
		when   f11=> 
			if (control_w_r='1') then 
				my_state <= data;
			else
				my_state <= f2;
			end if;
		when data =>
			if (control_w_r='0' or T_ABORT='1' ) then
				my_state <= f2;
			end if;
			
	end case;
       end if;
      end if;

end process F_INSERT;



------------------------------------------------------------------------------------- Z_STUFF--------------------------------------------------------------------------------------

--type octet_state is (s0,s1,s2,s3,s4,s5,ZI);
--signal z_state : octet_state ;

Z_STUFF:process(clk , rst)
      begin


       if (rst='1' or control_reset_everything='1') then
        z_state<=s0;
  else
    if (clk'event and clk='1') then
   if (T_Enable='1') and (control_w_r='1' or w_r_counter=1) then	  
    case z_state is 
		when s0=>
			if (z_input='1') then 
			z_state<= s1;
			end if;
		when s1=>
			if (z_input='1') then 
			z_state <= s2 ;
			else
			z_state<= s0 ;
   			end if;
		when s2=>
			if (z_input='1') then
			z_state <= s3 ;
			else
			z_state<= s0 ;
			end if;
		when s3=>
			if (z_input='1') then
			z_state<= s4 ;
			else
			z_state<= s0 ;
			end if;
    		when s4=>
			if (z_input='1') then
			z_state<= s5 ;
			else
			z_state<= s0 ;
			end if;
    	  	when s5=>
			z_state<=ZI ;
		when ZI=>
			if (z_input='1') then
			z_state<=s1 ;
			else
			z_state<=s0 ;
			end if;
		when others =>
			z_state<=s0;
    	
       	end case ;
	end if;
	end if;
	end if;
	end process Z_STUFF;

	z_output <= '0' when (z_state = ZI) else
                    '0' when (z_state= s0) else
              	    '1';

	                                          z_input <= t_shift_output when control_mux_manager='1' else
							     crc_output;






------------------------------------------------------------------------------- CRC_SUBMOD--------------------------------------------------------------------------------------------

 

     								crc_input<=t_shift_output;
CRC_SUBMOD:process(clk,rst)
variable cache : std_logic := '0';	
	begin 
	if (rst = '1' or control_reset_everything='1') then
		crc_temp<=(others=>'0');
		crc_counter <= 0 ;
		cache := '0' ; 
		crc_output<='0'; 
		
	else 
		if (rising_edge(clk) ) then 
				
				if (T_Enable='1') and (z_state /= s5) then
					-- the control submodule should assert fire for four clk_t only
					if ( control_fire='1') then 
						--if (crc_counter < 4) then
				                if (crc_counter < 16) then		
						crc_output<= crc_temp(crc_counter);
						end if;
						crc_counter <= crc_counter + 1;
						if crc_counter = 16 then
							crc_counter<=0;
							crc_temp<=(others=>'0');
							crc_output<='0';
						end if;
					else
						if (control_w_r='1') then
						cache  := crc_temp(1);
						crc_temp(1) <= crc_temp(2);
						crc_temp(2) <= crc_temp(3);
						crc_temp(3) <= crc_temp(4) xor crc_temp(0);
						crc_temp(4) <= crc_temp(5);
						crc_temp(5) <= crc_temp(6);
						crc_temp(6) <= crc_temp(7);
						crc_temp(7) <= crc_temp(8);
						crc_temp(8) <= crc_temp(9);
						crc_temp(9) <= crc_temp(10);
						crc_temp(10) <= crc_temp(11) xor crc_temp(0);
						crc_temp(11) <= crc_temp(12);
						crc_temp(12) <= crc_temp(13);
						crc_temp(13) <= crc_temp(14);
						crc_temp(14) <= crc_temp(15);
						crc_temp(15) <= crc_input xor crc_temp(0);
						crc_temp(0) <= cache;

						end if;
					end if;
				end if;
				
		
		end if;
	end if;
	end process CRC_SUBMOD;




--------------------------------------------------------------------------------- T_SHIFT---------------------------------------------------------------------------------------------



					t_shift_input<=buffer_output;
T_SHIFT:process (clk,rst) 
	begin 
		if (rst = '1' or control_reset_everything='1') then
			--s<='0';
			T_SHIFT_counter<=8;
			t_shift_get_ready<='0';
			t_shift_b_shift<='0';
		elsif( rising_edge(clk) ) then 
			  if (T_Enable='1') and (z_state/= s5) and (control_w_r='1' or w_r_counter=1) then		   
			   t_shift_output <= t_shift_input(T_SHIFT_counter-1);
			   if ( T_SHIFT_counter >= 1 ) then
			   T_SHIFT_counter <= T_SHIFT_counter - 1;
			   -- you can put this part inside the if counter >1 and replace >=		
				if (T_SHIFT_counter= 1 ) then
					T_SHIFT_counter <= 8;
				end if;
				-- commanding our buffer to shift us the data  while we're shifting the last bit 
				if(T_SHIFT_counter = 3) then 
					t_shift_b_shift<='1';
				else
					t_shift_b_shift<='0'; 
				end if;
                              --telling our fifo to get ready 
				if (T_SHIFT_counter = 8) then 
				 	t_shift_get_ready<='1';
				elsif (T_SHIFT_counter = 3) then 
					t_shift_get_ready<='0';
				end if;
				
			end if;
		   end if;
			if (end_bool=True)then 
			T_SHIFT_counter<=8;
			end if;
		end if;
	end process T_SHIFT;



					
                                         T_READ<=(t_shift_get_ready or first_start_temp) ;



----------------------------------------------------------------------------------- T_BUFFER------------------------------------------------------------------------------------------


	
 	buffer_output_temp_c <= in7 & in6 & in5 & in4 & in3 & in2 & in1 & in0;

T_BUFFER:process (clk,rst) 
		begin
			if (rst = '1' or control_reset_everything='1') then
				buffer_output <= (others=>'0');
	
			elsif rising_edge(clk) then 
				if (t_shift_b_shift= '1' or control_buffer_start='1' ) then 
					buffer_output <= buffer_output_temp_c(7 downto 0);
				end if;
			end if;
end process; 


------------------------------------------------------------------------------------- ABORT---------------------------------------------------------------------------------------------
-------

ABORT_pro:process(rst,clk)

begin  
   
	if (rst = '1') then 
			abort_temp<='0';
	elsif ( rising_edge(clk) ) then 
		if  (T_Enable='1')  then
			if (T_ABORT='1')then
			abort_output<='1';
			elsif(my_state=abt) then
			abort_output<='0';	
			end if;	
		end if;
	end if;


end process ABORT_pro;




----------------------------------------------------------------------------------- T_CONTROL-----------------------------------------------------------------------------------------


w_randbstart:process(clk,rst) 
begin 
	if (rst = '1') then
 
		first_start_temp<='0';
	elsif rising_edge(clk) then
	   if  (T_Enable='1')  then
		if (T_Start='1') then
			first_start_temp<='1';
			first_start_bool<=true;
		else
			first_start_temp<='0';
		end if;
		if(control_buffer_start='1') then 
			first_start_bool<=false;
		end if;
	    end if;
	end if;
end process w_randbstart;


startingbufferforfirsttme:process(clk,rst)
begin 	
	if (rst = '1') then 
		control_buffer_start<='0';
	elsif rising_edge(clk) then
	  if  (T_Enable='1')  then
		if (first_start_bool=true and w_r_order='1' ) then
			control_buffer_start<='1';
			
		else 
			control_buffer_start<='0' ;
		end if;
	  end if;
	end if;
end process startingbufferforfirsttme ;



  
reseteverything:process(clk,rst)
begin 
	if(rst='1')then
		control_reset_everything<='0';
	elsif(rising_edge(clk)) then
	    if  (T_Enable='1')  then
		if (T_ABORT='1') then 
			control_reset_everything<='1';
		else 
			control_reset_everything<='0';
		end if;
            end if;
	end if;
end process reseteverything;


muxmanage1:process(clk,rst)
begin 
	if(rst='1')then
		mux_bool<= false;
	elsif (rising_edge(clk)) then
	   if  (T_Enable='1' )  then
		if (T_last_octet='1') then
			mux_bool<= true ;
		end if ;
		if(crc_counter = 16)then
			mux_bool<= false ;
		end if;
	   end if;
	end if;
end process muxmanage1;	


muxmanage2:process(clk,rst)
begin 
	if(rst='1')then  
		control_mux_manager<='0'; 
		mux_counter<=0;
	elsif (rising_edge(clk)) then
	     if  (T_Enable='1' and (z_state/= s5))  then
		if (mux_bool = true) then----- treating the last octet
			mux_counter<=mux_counter+1;
				if(mux_counter=9)then
					control_mux_manager<='0';
					mux_counter<=0;
				elsif(crc_counter = 16) then
					control_mux_manager<='1';
					mux_counter<=0;
				end if;
	 	 end if;	
	     end if;
	end if;
end process muxmanage2;


w_rprocess:process(clk,rst)
begin
	if(rst='1')then
			 control_w_r <='0';	
 		         w_r_bool <= false;
			 w_r_counter <=0 ;
		
	elsif (rising_edge(clk)) then   
		if  (T_Enable='1')  then
			if   control_buffer_start='1' then
				w_r_bool <= true;
			end if;
			if  w_r_bool = true then
				w_r_counter<=w_r_counter+1;  
			end if;
			if  (w_r_counter=1) then 
				w_r_counter<=0;
				w_r_bool <= false;
				control_w_r<='1';
			elsif ( T_ABORT='1' ) then
				control_w_r <='0';
			elsif(crc_counter=15 )then
				end_bool<=True;
			elsif(end_bool=True and T_SHIFT_counter=8 ) then --- here is the problem
				control_w_r <='0';
				end_bool<=False;
				
			end if;
		end if;
	end if;

end process w_rprocess;



fireprocess : process(clk,rst)
begin
	if(rst='1')then
			 control_fire<='0'; 
	elsif(rising_edge(clk)) then
		if  (T_Enable='1')  then
			 if mux_counter=8 then 
				control_fire<='1';
			elsif crc_counter = 16 then
				control_fire<='0';
			 end if;
		end if;
	end if ;
end process fireprocess;





   
  
end TRANSMIT_BEHAVIOR ;
