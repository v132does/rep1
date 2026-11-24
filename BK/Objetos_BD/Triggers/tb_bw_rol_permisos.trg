CREATE OR REPLACE TRIGGER IT.TB_BW_ROL_PERMISOS
 BEFORE DELETE OR INSERT OR UPDATE
     ON BW_ROL_PERMISOS
    FOR EACH ROW
DECLARE
 v_consulta varchar2(1);
 v_ingresa varchar2(1);
 v_autoriza varchar2(1);
BEGIN
  -- Controlar que tenga marcado por lo menos un acceso.
  if :new.consulta = 'N' and :new.ingresa = 'N' and :new.autoriza = 'N' then
    raise_application_error(-20001,'El mensaje '||:new.cod_tip_mensaje||
                                   ' debe tener marcardo por lo menos un Acceso.');
  end if;
  -- Controlar que tenga cargado el campo cantidad de Firmas si corresponde.
  if :new.ingresa = 'S' and nvl(:new.can_firmas,10) not between 0 and 9 then
    raise_application_error(-20002,'Para el mensaje '||:new.cod_tip_mensaje||' la cantidad de firmas debe estar entre 0 y 9.');
  end if;
  if nvl(:new.can_firmas,0) > 0 and :new.ingresa = 'N' and (:new.consulta = 'S' or :new.autoriza = 'S') then
    if :new.cod_tip_mensaje not in ('087','088', '034') then
       raise_application_error(-20003,'Para el mensaje '||:new.cod_tip_mensaje||' no debe tener cantidad de firmas.');
    end if;
  end if;
  -- Controlar que los accesos sean correctos.
  begin
    select nvl(consulta,'N'), nvl(ingresa,'N'), nvl(autoriza,'N')
      into v_consulta, v_ingresa, v_autoriza
      from bw_tip_mensajes
     where cod_tip_mensaje = :new.cod_tip_mensaje;
  exception
    when others then
     null;
  end;
  if v_consulta = 'N' and :new.consulta <> 'N' then
    raise_application_error(-20004,'Para el mensaje '||:new.cod_tip_mensaje||' no puede Consultar.');
  elsif v_ingresa  = 'N' and :new.ingresa  <> 'N' then
    raise_application_error(-20004,'Para el mensaje '||:new.cod_tip_mensaje||' no puede Ingresar. ');
  elsif v_autoriza = 'N' and :new.autoriza <> 'N' then
    raise_application_error(-20004,'Para el mensaje '||:new.cod_tip_mensaje||' no puede Autorizar.');
  end if;
END;
/

