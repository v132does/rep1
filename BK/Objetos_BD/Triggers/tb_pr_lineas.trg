CREATE OR REPLACE TRIGGER IT.TB_PR_LINEAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_LINEAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

v_existe varchar2(1);
BEGIN
	--Si es el usuario IT el que ejecuta el proceso no debe controlar el saldo porque es por interfaz
   IF USER <> 'IT' AND  nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' THEN
      if inserting then
         /*if nvl(:new.mto_aplicado,0) > nvl(:new.monto,0) then
            raise_application_error(-20000,
            'Monto a aplicar no debe superar el monto de la linea');
         end if;*/
           begin
           select 'S' into v_existe
             from pr_lineas
            where cod_persona = :new.cod_persona
              and estado = 'B';
           exception
              when too_many_rows then
                 v_existe := 'S';
              when others then
                 v_existe := 'N';
           end;
           if v_existe = 'S' then
             raise_application_error(-20000,'El cliente tiene una Linea Bloqueada. No puede solicitar nueva linea');
           end if;
      /*elsif updating then
         if nvl(:new.mto_aplicado,0) > nvl(:old.mto_aplicado,0) then
             if  (nvl(:new.mto_aplicado,0) <> nvl(:old.mto_aplicado,0)
               or nvl(:new.monto,0) <> nvl(:old.monto,0))
             and nvl(:new.mto_aplicado,0) > nvl(:new.monto,0)  then
                raise_application_error(-20000,
                'Monto a aplicar no debe superar el monto de la linea Nro. '||:new.nro_linea);
             end if;
         end if;*/
      end if;
   END IF;
END;
/

