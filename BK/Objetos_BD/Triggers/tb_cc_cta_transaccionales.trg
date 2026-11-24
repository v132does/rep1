CREATE OR REPLACE TRIGGER IT.TB_CC_CTA_TRANSACCIONALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_CTA_TRANSACCIONALES
 FOR EACH ROW 
 DECLARE
   v_tipo varchar2(1);
BEGIN
   begin
     select tipo 
       into v_tipo
       from cc_cta_corrientes c, ge_cta_clientes g, ba_personas p
      where c.nro_cuenta = :new.nro_cuenta
        and c.nro_cuenta = g.nro_cuenta
        and g.cod_persona = p.cod_persona
        and g.relacion = 'P';
   exception 
     when others then
        v_tipo := 'F';
   end;
   if nvl(v_tipo, 'F') <> 'J' then
      raise_application_error(-20000, 'La persona debe ser Jurídica.');
   end if;      
   if updating and (:new.nro_cuenta <> :old.nro_cuenta or :new.tip_cta_transaccional <> :old.tip_cta_transaccional) and :old.activo = 'S' then
      raise_application_error(-20000, 'No puede modificar el número de cuenta activo');
   end if;
END;
/

