CREATE OR REPLACE FUNCTION IT.fux_obt_mto_embarque (p_nro_cuenta IN varchar2, p_nro_embarque in number) RETURN NUMBER IS
   v_monto cx_embarques.MTO_UTILIZADO%type;
BEGIN
	 --última cuota
   select MTO_UTILIZADO
   into v_monto
   from cx_embarques
   where nro_cuenta = p_nro_cuenta
     and nro_embarque = p_nro_embarque;
   return v_monto;
exception
	when others then
		raise_application_error(-20000,'Recup.embarque '||'nro. cuenta: '||p_nro_cuenta||'nro_embarque: '||p_nro_embarque||sqlerrm);
END;
/

