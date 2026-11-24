CREATE OR REPLACE TRIGGER IT.TB_BA_COD_REFERENCIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON BA_COD_REFERENCIAS
 FOR EACH ROW
Declare
 v_cantidad number(10) := 0;
BEGIN
   --DYDMR-1937: ITCAJA - Presiona F2 y no Ocurre Nada - Reversión de Operacion SC 16650
   if inserting or updating then
      If :new.dominio = 'MOT_REVERSION' then
         if length(:new.significado) > 40 then
            raise_application_error(-20000, 'La longitud del Significado no puede ser superior de 40');
         end if;
         
         if INSTR(:new.significado,CHR(39))> 0 then
            raise_application_error(-20000, 'Ha ingresado un caracter especial no válido.');
         end if;  
         
         if nvl(fug_val_es_numerico(:new.val_minimo),'N') = 'N' then
            raise_application_error(-20000, 'El valor mínimo debe ser numérico.');
         end if;   
      end if;
      
      if :new.dominio = 'COR_HOR_CTA_BATCH' and (nvl(:new.val_maximo, '00:00:00') IN ('00:00:00', '24:00:00') or
         nvl(:new.val_maximo, '00:00:00') >= '24:00:00') THEN
         raise_application_error(-20000, 'Valor de corte de hora no válido.');
      end if;
   end if;
   if deleting then
      -- Antes de borrar debe verificar si es que se utilizando o no...
      If :old.dominio = 'TIP_DOC_GARANTIA' then
         select count(*)
           into v_cantidad
           from pr_gar_documentos
          where tip_documento = :old.val_minimo;
         If v_cantidad > 0 then
            raise_application_error(-20000, 'Tipo de Documento utilizado');
         End If;
      ElsIf :old.dominio = 'SIT_GARANTIA' then
         select count(*)
           into v_cantidad
           from pr_garantias
          where situacion = :old.val_minimo;
         If v_cantidad > 0 then
            raise_application_error(-20000, 'Situación de Garantía utilizado');
         End If;
      End if;
   end if;
end;
/

