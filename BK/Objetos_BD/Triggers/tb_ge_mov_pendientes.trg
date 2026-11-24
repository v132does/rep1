CREATE OR REPLACE TRIGGER IT.TB_GE_MOV_PENDIENTES
  before insert or update or delete on ge_mov_pendientes
  for each row
declare
  -- local variables here
begin
   if inserting then
      if :new.cod_movimiento is null then
         --- Generar codigo de movimiento
         select s_cod_movimiento.nextval into :new.cod_movimiento from dual;
      end if;
   elsif updating then
      if nvl(:new.mto_exonerado,0) <> nvl(:old.mto_exonerado,0) then
         :new.cod_usu_exonerador := user;
         :new.saldo := nvl(:new.saldo,0) - ( nvl(:new.mto_exonerado,0) - nvl(:old.mto_exonerado,0) );
         if nvl(:new.saldo,0) <= 0 then
            -- Se termina el proceso
            :new.estado := 'E';
         end if;
         --- PCC-Exoneración y Extorno de Comisiones y Tasas
         prg_ins_exoneracion(:old.cod_transaccion,:old.cod_modulo,:old.cod_modalidad,
                             :old.cod_moneda,:old.nro_cuenta,null,:old.cod_tasa,
                             nvl(:new.mto_exonerado,0),:old.saldo,null,:old.saldo);
      end if;
   end if;
end TB_GE_MOV_PENDIENTES;
/

