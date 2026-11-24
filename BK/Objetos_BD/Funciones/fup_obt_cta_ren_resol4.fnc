create or replace function it.fup_obt_cta_ren_resol4 (p_nro_cuenta in varchar2, p_tip_can_rrr in varchar2) return varchar2 is

  --Proyecto SDRES4COVI-134--
  --Funcion para obtener cadena de ctas renovadas--
  --Variables--
  v_det_cuentas varchar2(4000);
  v_contador    number(4);

  --Cursor--
  cursor c_cta_renovadas is
  select x.nro_cuenta
    from pr_cta_pre_ref_res4 x
   where x.nro_cta_nueva = p_nro_cuenta
     and x.tip_can_rrr = p_tip_can_rrr;
begin
  v_det_cuentas := null;
  v_contador    := 0;
  for det in c_cta_renovadas loop
      v_contador := v_contador + 1;
      if v_contador = 1 then
         v_det_cuentas := det.nro_cuenta||';';
      else
         v_det_cuentas := v_det_cuentas||' '||det.nro_cuenta||';';
      end if;
  end loop;
  return v_det_cuentas;
exception
   when others then
     raise_application_error(-20000,'Error en obtener cuentas renovadas Resol4-'||sqlerrm);
end;
/

