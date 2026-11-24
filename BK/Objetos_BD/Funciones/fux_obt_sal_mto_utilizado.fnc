CREATE OR REPLACE FUNCTION IT.fux_obt_sal_mto_utilizado (p_nro_cuenta IN varchar2, p_nro_embarque in number default null)
RETURN NUMBER IS
   v_monto cx_embarques.MTO_UTILIZADO%type;
BEGIN
	 --última cuota
   select nvl(sum(saldo),0)
   into v_monto
   from cx_embarques
   where nro_cuenta = p_nro_cuenta
     and (nro_embarque = p_nro_embarque or p_nro_embarque is null);
   return v_monto;
exception
  when no_data_found then
     return 0;
	when others then
		raise_application_error(-20000,'Recup.embarque '||'nro. cuenta: '||p_nro_cuenta||'nro_embarque: '||p_nro_embarque||sqlerrm);
END;
/

