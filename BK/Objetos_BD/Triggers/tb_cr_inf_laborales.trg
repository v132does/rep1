CREATE OR REPLACE TRIGGER IT.TB_CR_INF_LABORALES
 BEFORE DELETE OR INSERT OR UPDATE
 ON CR_INF_LABORALES
 FOR EACH ROW

DECLARE
v_importe     number := 0;
v_nvo_importe number := 0;
v_fec_nacimiento date := null;
BEGIN
    IF inserting THEN
        IF :new.nro_secuencia is null then
            select nvl(max(nvl(nro_secuencia,0)),0) + 1
              into :new.nro_secuencia
              from cr_inf_laborales
             where cod_persona = :new.cod_persona;
        END IF;
    END IF;
    If inserting or updating then
       select fec_nacimiento
         into v_fec_nacimiento
         from BA_PER_FISICAS
        where cod_persona = :new.cod_persona;

       If :new.fec_ingreso > trunc(sysdate)+30 then
         raise_application_error(-20000,'Fecha debe ser menor a '||to_char(trunc(sysdate)+30,'dd/mm/yyyy'));
       End if;

       If v_fec_nacimiento is null  then
	     If to_char(:new.fec_ingreso,'yyyy') < '1900' then
           raise_application_error(-20001,'Fecha de ingreso debe ser mayor o igual a 1900');
         End if;
	   else
	     If :new.fec_ingreso < v_fec_nacimiento then
	  	   raise_application_error(-20002,'Fecha de ingreso debe ser mayor a la fecha de nacimiento');
	     End if;
	   End if;
    End if;
END;
/

