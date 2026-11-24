CREATE OR REPLACE TRIGGER IT.TB_PR_LIN_TIP_GARANTIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_LIN_TIP_GARANTIAS
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
BEGIN
	--No debe controlar cuando es el usuario IT porque es por interfaz
   /*raise_application_error(-20000,:new.mto_aplicado||'-'||:old.mto_aplicado||'-'||
                                  :new.mto_limite||'-'||:old.mto_limite);*/
   IF /*USER <> 'IT' AND*/  nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' THEN
      null;
      /*if inserting then
         if nvl(:new.mto_aplicado,0) > nvl(:new.mto_limite,0) then
            raise_application_error(-20000,
            'El monto aplicado no debe superar el monto del límite');
         end if;
      elsif updating then
            if  (nvl(:new.mto_aplicado,0) <> nvl(:old.mto_aplicado,0)
              or nvl(:new.mto_limite,0) <> nvl(:old.mto_limite,0))
            and nvl(:new.mto_aplicado,0) > nvl(:new.mto_limite,0) then
               --si el monto de límite es 0, se insertó por proceso, no debe controlar
               if :new.mto_limite > 0 then
                 raise_application_error(-20002,
                 'El monto aplicado '|| :new.mto_aplicado||'-'||:new.cod_garantia||'-'||
                 ' no debe superar el monto del límite '||:new.mto_limite);
               end if; 
           end if;
      end if;*/
   END IF;
END;
/

