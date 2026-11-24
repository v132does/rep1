CREATE OR REPLACE TRIGGER IT.TB_AH_CER_GRUPOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AH_CER_GRUPOS
 FOR EACH ROW
DECLARE

   v_max      number;
   v_anulado  varchar2(1) := 'N';
   v_sig_nro  number;
   v_contador number := 0;
begin
  If inserting then
     begin
         select max(nvl(nro_final,0))
           into v_max
           from ah_cer_grupos
          where serie         = :new.serie
            and cod_modalidad = :new.cod_modalidad
            and tip_moneda    = :new.tip_moneda
            and :new.cod_cer_gru_origen is null;
         If nvl(v_max,0) <> 0 then
            If :new.nro_inicial <= v_max then
               raise_application_error(-20000, 'Número inicial debe ser mayor al número final del último grupo generado');
            End if;
         End if;
     exception
       when no_data_found then
         null;
     end;
     begin
         v_max := 0;
         select max(nvl(nro_final,0))
           into v_max
           from ah_cer_grupos
          where serie         = :new.serie
            and cod_modalidad = :new.cod_modalidad
            and tip_moneda    = :new.tip_moneda
            and cod_cer_gru_origen = :new.cod_cer_gru_origen;
         If nvl(v_max,0) <> 0 then
            If :new.nro_inicial <= v_max then
               raise_application_error(-20000, 'Número inicial debe ser mayor al número final del último grupo generado');
            End if;
         End if;
     exception
       when no_data_found then
         null;
     end;
  End if;

  If updating then
    If :old.can_disponibles <> :new.can_disponibles then
      If :new.can_disponibles= 0 then
        If nvl(:new.can_entregados,0) <> nvl(:old.can_entregados,0) then
           :new.estado := 'E';  -- totalmente entregado
        else
           :new.estado := 'T' ;  -- totalmente utilizado
        end if;   
      End if;
      If :new.can_disponibles < 0 then
        raise_application_error(-20000, 'Error al actualizar la cantidad de disponibles');
      End if;
    End if;
  End if;
end;
/

