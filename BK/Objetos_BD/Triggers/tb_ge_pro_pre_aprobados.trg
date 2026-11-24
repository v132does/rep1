CREATE OR REPLACE TRIGGER IT.TB_GE_PRO_PRE_APROBADOS
  BEFORE INSERT OR UPDATE ON ge_pro_pre_aprobados
  FOR EACH ROW
declare
  v_cantidad number(3);
  v_fecha date;
BEGIN
  
  if inserting or updating then
    if nvl(:new.max_monto, 0) > nvl(:new.lin_nueva_tc, 0) and
       :new.cod_modulo = 5 then
      raise_application_error(-20000,
                              'El monto máximo no puede ser mayor a Lin_nueva_TC');

    end if;

  end if;
  --Para no ofrecer en ambos canales, para campaña 144 Comportamental
  if updating and :new.cod_modulo = 5 and :new.cod_campana=144
        and :new.estado='C' and :new.nro_solicitud is not null then
     --Verificamos si tiene ofrecimiento tc pre-aprobada en el HB
       v_cantidad :=0;
       v_fecha:= pag_cal.FU_OBT_FEC_ACTUAL(1);
       begin
        Select  nvl(count(*),0)
           into v_cantidad
             from GE_CLI_APROBADOS_ATM_TMP t
                where t.cod_persona = :new.cod_persona
                and   t.cod_campana = :new.cod_campana
                and   t.acepta = 'N'
                and   t.fec_baja>= v_fecha;
       exception
         when no_data_found then
              v_cantidad:=0;
         when others then
              v_cantidad:=0;
       end;
       if nvl(v_cantidad,0) > 0 then
          --Borramos de la tabla para que no vuelva a ofrecerle
           Delete from GE_CLI_APROBADOS_ATM_TMP t
                where t.cod_persona = :new.cod_persona
                     and   t.cod_campana = :new.cod_campana
                     and   t.acepta = 'N'
                     and   t.fec_baja >= v_fecha;
        end if;
  end if;




end;
/

