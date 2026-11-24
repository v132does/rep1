CREATE OR REPLACE FUNCTION IT.fux_obt_ult_vto_cuota (p_nro_cuenta IN varchar2) RETURN date IS
   v_fecha date;
BEGIN
	 --última cuota
   select max(fec_vencimiento)
   into v_fecha
   from cx_cuotas
   where nro_cuenta = p_nro_cuenta;
   return v_fecha;
exception
	when others then
		raise_application_error(-20000,'Recup.ult.vto.cuota '||sqlerrm);
END;
/

