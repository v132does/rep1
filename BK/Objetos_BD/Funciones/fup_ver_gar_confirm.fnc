CREATE OR REPLACE FUNCTION IT.FUP_VER_GAR_CONFIRM
 (P_NRO_SOLICITUD IN NUMBER
 )
 RETURN BOOLEAN
 IS
  v_cantidad number(03);
  v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
begin
   select count(*)
   into v_cantidad
   from pr_sol_garantias a, pr_garantias b
   where a.nro_garantia = b.nro_garantia
   and a.nro_solicitud =p_nro_solicitud
   and ((a.cod_garantia not in (1,2) and v_tip_implementacion not in (1,7)) or
        (a.cod_garantia not in (1,2,3) and v_tip_implementacion in (1,7)))
   and nvl(b.estado,'X') <> 'C'
   and a.cod_garantia not in (31);--caución de cheques
   if v_cantidad = 0 then
      return true;
   else
      return false;
   end if;
exception
   when no_data_found then
      return true;
   when others then
      return false;
end;
/

