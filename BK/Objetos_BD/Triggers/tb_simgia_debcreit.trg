CREATE OR REPLACE TRIGGER IT.TB_SIMGIA_DEBCREIT
  before insert on simgia_debcreit
  for each row
declare
  -- local variables here
  -- procedure para registrar campos fec_proceso,cod_persona,nro_cuenta
  -- segun formato ITGF
  PROCEDURE LP_REG_INS;
PROCEDURE LP_REG_INS
 IS
begin
   if :new.fec_proceso is null then
     :new.fec_proceso := pae_cnf.fu_obt_fec_actual(1);
   end if;
   if :new.cod_persona is null then
      :new.cod_persona := to_char(:new.ITRIESGO);
   end if;
   if :new.nro_cuenta is null then
      select lpad(:new.ITSUC,2,'0')||
                         decode(:new.ITCTA,210100,'01',
                                      215000,'01',
                                      210500,'02',
                                      215500,'02')||
                         lpad(:new.ITSUB,6,'0') into :new.nro_cuenta
                         from dual;
   end if;
end;
begin
  lp_reg_ins;
end TB_SIMGIA_DEBCREIT;
/

