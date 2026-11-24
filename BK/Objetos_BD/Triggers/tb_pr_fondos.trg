CREATE OR REPLACE TRIGGER IT.TB_PR_FONDOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_FONDOS
 FOR EACH ROW
BEGIN
   --- validar la modalidad no sea tipo descuento de documentos
   if inserting or updating then
      if :new.par_modalidad is not null and  FUP_VER_ORI_FON_MODALIDAD(:new.par_modalidad) = 0 then
        raise_application_error(-20000,'Error: La Modalidad no es válida. Verifique...'||:new.par_modalidad);
     end if;
     --valida que se ingresen las dos transacciones
     if (:new.cod_tra_desembolso is not null and :new.cod_tra_cobro is null) or
        (:new.cod_tra_desembolso is null and :new.cod_tra_cobro is not null) then
        raise_application_error(-20000,'Debe ingresar las dos transacciones o ninguna de ellas');
     end if;
   end if;
END;
/

