CREATE OR REPLACE TRIGGER IT.TA_CC_CTA_COMBINADAS
 AFTER DELETE OR INSERT OR UPDATE
 ON CC_CTA_COMBINADAS
 FOR EACH ROW

DECLARE
  v_nro_referencia cc_cta_combinadas_his.nro_ref_cta_combinada%type;
BEGIN
   if inserting then
      update cc_cta_corrientes
         set cta_combinada = 'S'
       where nro_cuenta = :new.nro_cta_cte;
      if sql%notfound then
         raise_application_error(-20000,
         'No pudo actualizarse dato combinado de cuenta corriente');
      end if;
      update ah_cta_vistas
         set cta_combinada = 'S'
       where nro_cuenta = :new.nro_cta_ahorro;
      if sql%notfound then
         raise_application_error(-20000,
         'No pudo actualizarse dato combinado de cuenta vista');
      end if;
      begin
        select s_nro_ref_cta_combinada.nextval into v_nro_referencia from dual;
        insert into cc_cta_combinadas_his
          (nro_ref_cta_combinada, nro_cta_ahorro, nro_cta_cte, sal_minimo, fec_apertura, observaciones, tip_movimiento)
        values
          (v_nro_referencia, :new.nro_cta_ahorro, :new.nro_cta_cte, :new.sal_minimo, :new.fec_apertura, :new.observaciones, 'I');
      exception
         when others then
            null;
      end;
   elsif updating then	
      if :new.nro_cta_cte <> :old.nro_cta_cte then
         update cc_cta_corrientes
            set cta_combinada = 'S'
          where nro_cuenta = :new.nro_cta_cte;
         if sql%notfound then
            raise_application_error(-20000,
            'No pudo actualizarse dato combinado de cuenta corriente');
         end if;
         update cc_cta_corrientes
            set cta_combinada = 'N'
          where nro_cuenta = :old.nro_cta_cte;
         if sql%notfound then
            raise_application_error(-20000,
            'No pudo actualizarse dato combinado de cuenta corriente');
         end if;
      end if;
      if :new.nro_cta_ahorro <> :old.nro_cta_ahorro then
         update ah_cta_vistas
            set cta_combinada = 'S'
          where nro_cuenta = :new.nro_cta_ahorro;
         if sql%notfound then
            raise_application_error(-20000,
            'No pudo actualizarse dato combinado de cuenta vista');
         end if;
         update ah_cta_vistas
            set cta_combinada = 'N'
          where nro_cuenta = :old.nro_cta_ahorro;
         if sql%notfound then
            raise_application_error(-20000,
            'No pudo actualizarse dato combinado de cuenta vista');
         end if;
      end if;
      begin
        select s_nro_ref_cta_combinada.nextval into v_nro_referencia from dual;
        insert into cc_cta_combinadas_his
          (nro_ref_cta_combinada, nro_cta_ahorro, nro_cta_cte, sal_minimo, fec_apertura, observaciones, tip_movimiento)
        values
          (v_nro_referencia, :old.nro_cta_ahorro, :old.nro_cta_cte, :old.sal_minimo, :old.fec_apertura, :old.observaciones, 'A');
      exception
         when others then
            null;
      end;
   elsif deleting then
      update cc_cta_corrientes
         set cta_combinada = 'N'
       where nro_cuenta = :old.nro_cta_cte;
      if sql%notfound then
         raise_application_error(-20000,
         'No pudo actualizarse dato combinado de cuenta corriente');
      end if;
      update ah_cta_vistas
         set cta_combinada = 'N'
       where nro_cuenta = :old.nro_cta_ahorro;
      if sql%notfound then
         raise_application_error(-20000,
         'No pudo actualizarse dato combinado de cuenta vista');
      end if;
      begin
        select s_nro_ref_cta_combinada.nextval into v_nro_referencia from dual;
        insert into cc_cta_combinadas_his
          (nro_ref_cta_combinada, nro_cta_ahorro, nro_cta_cte, sal_minimo, fec_apertura, observaciones, tip_movimiento)
        values
          (v_nro_referencia, :old.nro_cta_ahorro, :old.nro_cta_cte, :old.sal_minimo, :old.fec_apertura, :old.observaciones, 'E');
      exception
         when others then
            null;
      end;
   end if;
END;
/

