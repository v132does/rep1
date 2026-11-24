CREATE OR REPLACE TRIGGER IT.ta_ta_plasticos_mov
AFTER  INSERT ON ta_plasticos_mov
FOR EACH ROW

DECLARE
  v_stock_pr   ta_plasticos.cantidad%type:= 0;
  v_stock      ta_plasticos.cantidad%type:= 0;
  v_existe_pr  varchar2(1);
  v_existe     varchar2(1);
BEGIN
  --siempre se inserta la procesadora, salvo el mov.1 q envía null
  if :NEW.cod_ent_procesadora is not null then
    --busca stock por procesadora
    begin
      Select cantidad
        into v_stock_pr
        from ta_plasticos
       where cod_ent_procesadora = :NEW.cod_ent_procesadora
         and cod_modalidad = :NEW.cod_modalidad
         and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
         and cod_modulo = :NEW.cod_modulo;
      v_existe_pr := 'S';
    exception
      when no_data_found then
        v_existe_pr := 'N';
      when others then
        raise_application_error(-20002,'Ins.Ta_plasticos_mov ' || sqlerrm);
    end;
  end if;
    --busca stock global
    begin
      Select cantidad
        into v_stock
        from ta_plasticos
       where cod_ent_procesadora is null
         and cod_modalidad = :NEW.cod_modalidad
         and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
         and cod_modulo = :NEW.cod_modulo;
      v_existe := 'S';
    exception
      when no_data_found then
        v_existe := 'N';
      when others then
        raise_application_error(-20003,'Ins.Ta_plasticos_mov ' || sqlerrm);
    end;

  ------------------------------------------------------------
  -- Ejecutar las actualizaciones segun el tipo de movimiento
  ------------------------------------------------------------
  --mov.1 no envía procesadora
  if :NEW.tipo = 1 then
    /* Recepcion de plasticos nuevos */
    if v_existe = 'S' then  --suma al stock global
      update ta_plasticos
         set cantidad = cantidad + :NEW.cantidad
       where cod_ent_procesadora is null
         and cod_modalidad = :NEW.cod_modalidad
         and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
         and cod_modulo = :NEW.cod_modulo;
    else --inserta para stock global
      insert into ta_plasticos
      ( cod_modulo,cod_modalidad,cod_tip_tarjeta,cantidad,cod_ent_procesadora )
      values
      (:NEW.cod_modulo,
       :NEW.cod_modalidad,
       :NEW.cod_tip_tarjeta,
       :NEW.cantidad,
        null ); -- sin procesadora
    end if;
  elsif :NEW.tipo = 2 then
    /* Envio a la procesadora */
    if v_stock < :NEW.cantidad then
      raise_application_error(-20000,'La cantidad a enviar no puede ser superior a la existente.');
    end if;
    update ta_plasticos   --descuenta del stock global
       set cantidad = cantidad - :NEW.cantidad
       where cod_ent_procesadora is null
         and cod_modalidad = :NEW.cod_modalidad
         and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
         and cod_modulo = :NEW.cod_modulo;
    if v_existe_pr = 'S' then  --suma al stock de la procesadora
      update ta_plasticos
         set cantidad = cantidad + :NEW.cantidad
       where cod_ent_procesadora = :NEW.cod_ent_procesadora
         and cod_modalidad = :NEW.cod_modalidad
         and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
         and cod_modulo = :NEW.cod_modulo;
    else --inserta para stock de la procesadora
      insert into ta_plasticos
      (cod_modulo,cod_modalidad,cod_tip_tarjeta,cantidad,cod_ent_procesadora )
      values
      (:NEW.cod_modulo,
       :NEW.cod_modalidad,
       :NEW.cod_tip_tarjeta,
       :NEW.cantidad,
       :NEW.cod_ent_procesadora );
    end if;
  elsif :NEW.tipo = 3 then
    /* Recepcion de la procesadora */
    if v_stock_pr >= :NEW.cantidad then  --descuenta del stock de la procesadora
      update ta_plasticos
         set cantidad = cantidad - :NEW.cantidad
       where cod_ent_procesadora = :NEW.cod_ent_procesadora
         and cod_modalidad = :NEW.cod_modalidad
         and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
         and cod_modulo = :NEW.cod_modulo;
    else
       RAISE_APPLICATION_ERROR(-20001,'La cantidad supera la existencia en la procesadora.');
/*
      update ta_plasticos
         set cantidad = 0
       where cod_ent_procesadora = :NEW.cod_ent_procesadora
         and cod_modalidad = :NEW.cod_modalidad
         and cod_modulo = :NEW.cod_modulo;
*/
    end if;
  elsif :NEW.tipo = 4 then
    /* Descarga por deterioro */
    if v_stock_pr < :NEW.cantidad then
      raise_application_error(-20002,' La cantidad supera la existencia en la procesadora.');
    end if;
    update ta_plasticos       --descuenta del stock de la procesadora
       set cantidad = cantidad - :NEW.cantidad
    where cod_ent_procesadora = :NEW.cod_ent_procesadora
      and cod_modalidad = :NEW.cod_modalidad
      and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
      and cod_modulo = :NEW.cod_modulo;
  elsif :NEW.tipo = 5 then
    /* Ajuste positivo por recuento fisico */
    update ta_plasticos       --suma al stock de la procesadora
       set cantidad = cantidad + :NEW.cantidad
    where cod_ent_procesadora = :NEW.cod_ent_procesadora
      and cod_modalidad = :NEW.cod_modalidad
      and cod_tip_tarjeta = :NEW.cod_tip_Tarjeta
      and cod_modulo = :NEW.cod_modulo;
  elsif :NEW.tipo = 6 then
    /* Ajuste negativo por recuento fisico */
    update ta_plasticos       --descuenta del stock de la procesadora
       set cantidad = cantidad - :NEW.cantidad
    where cod_ent_procesadora = :NEW.cod_ent_procesadora
      and cod_modalidad = :NEW.cod_modalidad
      and cod_tip_tarjeta = :NEW.cod_tip_tarjeta
      and cod_modulo = :NEW.cod_modulo;
  end if;
 exception
   when others then
     if sqlcode < -20000  then
     	  raise;
     else
        raise_application_error(-20000,'Act.Plásticos ' || sqlerrm);
     end if;
END;
/

