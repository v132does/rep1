create or replace function it.fup_obt_apl_renovada
(p_nro_linea in number,
 p_cod_garantia in number,
 p_cuentas in varchar2,
 p_cod_modalidad in number default null 
 )
 return number is
 v_mto_aplicado number := 0;
 cursor apl is 
  select * from pv_operaciones_det a
  where a.NRO_LINEA = p_nro_linea
    and instr(','||p_cuentas||',',','||a.NRO_CUENTA||',') > 0
    and a.cod_garantia = p_cod_garantia
    and (p_cod_modalidad is null or p_cod_modalidad = a.cod_modalidad);   
 v_cod_moneda varchar2(04);   
begin
   select cod_moneda
     into v_cod_moneda
     from pr_lineas
    where nro_linea = p_nro_linea; 
   for rr in apl loop
          v_mto_aplicado := v_mto_aplicado  + pag_gen.fu_con_mon_a_moneda( rr.cod_mon_apl,
                                                                           v_cod_moneda,
                                                                           nvl( rr.mto_aplicado, 0 ) );  
   end loop;
   return nvl(v_mto_aplicado,0);
end;
/

