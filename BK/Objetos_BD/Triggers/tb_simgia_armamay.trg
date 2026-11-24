CREATE OR REPLACE TRIGGER IT."TB_SIMGIA_ARMAMAY"
  before insert on simgia_armamay
  for each row
declare
  -- local variables here
  -- procedure para registrar campos fec_proceso,cod_persona,nro_cuenta
  -- segun formato ITGF
PROCEDURE LP_REG_INS;
PROCEDURE LP_REG_INS
 IS
begin
   if :new.fec_migracion is null then
     :new.fec_migracion := pae_cnf.fu_obt_fec_actual(2);
   end if;
end;
begin
  lp_reg_ins;
end TB_SIMGIA_ARMAMAY;
/

