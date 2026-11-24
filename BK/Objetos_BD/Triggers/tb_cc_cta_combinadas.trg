CREATE OR REPLACE TRIGGER IT.TB_CC_CTA_COMBINADAS
 BEFORE INSERT OR UPDATE
 OF nro_cta_ahorro, nro_cta_cte
 ON CC_CTA_COMBINADAS
 FOR EACH ROW

DECLARE
v_oficina1	 				 varchar2(2);
v_oficina2	 				 varchar2(2);

BEGIN
-- validaci�n cuenta b�sica
if fua_es_cta_basica(:new.nro_cta_ahorro) = 'S' then
   raise_application_error(-20000, 'La cuenta de ahorro no puede ser b�sica.');
end if;
if user <> 'IT' then -- no hace los controles por IT, para la interface
    --Controlar las oficinas de las cuentas combinadas, deben ser la misma oficina
		select cod_oficina
		into 	 v_oficina1
		from ge_cuentas
		where nro_cuenta = :new.nro_cta_ahorro;

		select cod_oficina
		into 	 v_oficina2
		from ge_cuentas
		where nro_cuenta = :new.nro_cta_cte;

		if v_oficina1 <> v_oficina2 then
         raise_application_error(-20000, 'No pueden combinarse cuentas de distintas oficinas');
		end if;
end if;
END;
/

