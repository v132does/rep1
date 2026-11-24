CREATE OR REPLACE FUNCTION IT.fus_obt_lim_prestable(p_cod_moneda    in ge_movimientos.cod_moneda%type,
                                                    p_con_garantia  in varchar2 default 'N')
   RETURN NUMBER IS
  v_mto_lim_mon_local number := 0; 
BEGIN
  v_mto_lim_mon_local:=  fug_obt_pardinamico('MTO_MAX_LIM_PRESTABLE'); --379121618822; 
  return v_mto_lim_mon_local;
   
EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;
END;
/
