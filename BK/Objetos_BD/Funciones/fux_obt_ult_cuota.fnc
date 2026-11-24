CREATE OR REPLACE FUNCTION IT.fux_obt_ult_cuota (p_nro_cuenta IN varchar2) RETURN NUMBER IS
   v_nro_cuota cx_cuotas.nro_cuota%type;
BEGIN
	 --última cuota
   select max(nro_cuota)
   into v_nro_cuota
   from cx_cuotas
   where nro_cuenta = p_nro_cuenta;
   return v_nro_cuota;
exception
	when others then
		raise_application_error(-20000,'Recup.ult.cuota '||sqlerrm);
END;
/

