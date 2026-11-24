create or replace function it.FUA_TAR_DEB_CTA_CONCATENADAS
 (p_nro_cuenta in varchar2,  p_cod_persona in varchar2,
  p_adherente  in varchar2) return varchar2 is
  v_resultado varchar2(60);
cursor ctas is
  select nro_cta_relacionada
    from ah_tar_deb_cuentas
   where nro_cuenta = p_nro_cuenta
     and cod_persona = p_cod_persona
   order by nro_cta_relacionada; 
--
v_cta_formateada varchar2(15);
v_tip_cuenta     varchar2(1); 
v_existe         varchar2(1) := 'N';
--   
procedure lp_obt_tip_cuenta(p_nro_cuenta in varchar2,
                            p_cta_formateada in out varchar2,
                            p_tip_cuenta in out varchar2) is 
v_cod_oficina number(5);                            
begin
   select decode(cod_modalidad,31,decode(cod_moneda,pag_gen.fu_obt_mon_local,'1','3'),
                 decode(cod_moneda,pag_gen.fu_obt_mon_local,'0','2')),
          cod_oficina       
     into p_tip_cuenta, v_cod_oficina
     from ge_cuentas
    where nro_cuenta = p_nro_cuenta;
   p_cta_formateada := lpad(v_cod_oficina,2,'0')||p_tip_cuenta||lpad(p_nro_cuenta,7,'0');
exception
   when no_data_found then
      raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no existe en ge_cuentas');
   when others then
      raise_application_error(-20000,'Error al leer ge_cuentas '||sqlerrm);
end;

begin
  v_resultado := fug_obt_cod_banco; --Obtener el codigo de la entidad
  lp_obt_tip_cuenta(p_nro_cuenta, v_cta_formateada, v_tip_cuenta);
  -- datos de la cuenta principal
  v_resultado := v_resultado||
                 v_cta_formateada||
                 p_adherente||
                 v_tip_cuenta;
  -- leo las cuentas relacionadas                 
  for ct in ctas loop
      v_existe := 'S';
      lp_obt_tip_cuenta(ct.nro_cta_relacionada, v_cta_formateada, v_tip_cuenta);
      -- datos de la cuenta principal
      v_resultado := v_resultado||
                     v_cta_formateada||
                     v_tip_cuenta;
  end loop;
  if v_existe = 'S' then
     v_resultado := rpad(rtrim(v_resultado),49,'0'); -- relleno con ceros hasta la pos 49
     return(v_resultado);
  else
     return null; -- no existen ctas relacionadas
  end if;      
end FUA_TAR_DEB_CTA_CONCATENADAS;
/

