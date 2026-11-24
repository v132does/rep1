CREATE OR REPLACE TRIGGER IT.TA_CR_AGENDAS
  AFTER DELETE OR UPDATE
     ON CR_AGENDAS
    FOR EACH ROW
declare
v_estado varchar2(4);

BEGIN
  if updating then
     if nvl(:new.cod_respuesta,0) <> nvl(:old.cod_respuesta,0) then
        if :new.nro_referencia is not null then
           --buscar respuesta, en la descripción se guarda entre corchetes el estado
           begin 
             select substr(descripcion,instr(descripcion,'[')+1,(instr(descripcion,']')-instr(descripcion,'[')-1))
               into v_estado
               from cr_age_res_actividades
              where cod_actividad = :new.cod_actividad
                and cod_respuesta = :new.cod_respuesta;
             --por defecto Pendiente
             if v_estado is null then
                v_estado := 'PE';
             end if;
            exception
               when others then
                  v_estado := 'PE';
            end;            
           --actualizar el estado de la transferencia
           update lc_transferencias
              set estado = v_estado
            where nro_ref_externa = :new.nro_referencia;
        end if;
     end if;
  end if;
END;
/

