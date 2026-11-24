CREATE OR REPLACE TRIGGER IT.TB_TA_CON_PROMOCIONES
BEFORE INSERT ON TA_CON_PROMOCIONES
FOR EACH ROW

DECLARE
	v_nro_convenio  ta_con_promociones.nro_convenio%type;
  v_text varchar2(100);
BEGIN
   Declare
     Cursor c_cursor is
     Select nro_convenio 
       from ta_con_promociones
      where TRIM(descripcion) = TRIM(:new.descripcion)
        and TRIM(comercio)    = TRIM(:new.comercio);
   Begin
     For reg in c_cursor loop
       If reg.nro_convenio <> :new.nro_convenio then
         if  v_text is null then
            v_text := 'Ya existen convenios con la misma Promocion y el mismo Comercio : '||reg.nro_convenio;
         else          
            v_text := v_text || '/'||reg.nro_convenio;
         end if;
       end if;  
     End loop;
     If v_text is not null then     
     	 raise_application_error(-20000,v_text);
     End if;  
   end;
END;
/

