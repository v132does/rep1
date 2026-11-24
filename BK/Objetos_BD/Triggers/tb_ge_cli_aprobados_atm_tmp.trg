CREATE OR REPLACE TRIGGER IT.TB_GE_CLI_APROBADOS_ATM_TMP
  BEFORE UPDATE ON ge_cli_aprobados_atm_tmp
  FOR EACH ROW
declare
  v_cantidad number(3);
BEGIN
  
 
  --Para no ofrecer en ambos canales, para campaña 144 Comportamental
  if updating and :new.acepta='S' and :new.cod_campana=144 then
     --Verificamos si tiene ofrecimiento tc pre-aprobada en el HB
       v_cantidad :=0;
       begin
        Select  nvl(count(*),0)
           into v_cantidad
             from ge_pro_pre_aprobados t
                where t.cod_persona = :new.cod_persona
                and   t.cod_campana = :new.cod_campana
                and   t.estado='V'
                and   t.cod_modulo=5;
       exception
         when no_data_found then
              v_cantidad:=0;
         when others then
            v_cantidad:=0;
       end;
       if nvl(v_cantidad,0) > 0 then
          --Cancelamos para que no vuelva a ofrecerle
          update  ge_pro_pre_aprobados t
               set t.estado='C',
                   t.nro_solicitud=null,
                   t.cod_causa=296 -- PRE_APROBADO UTILIZADO EN PROPUESTA
           where  t.cod_persona = :new.cod_persona
                and   t.cod_campana = :new.cod_campana
                and   t.estado='V'
                and   t.cod_modulo=5;
        end if;
   end if;
end;
/

